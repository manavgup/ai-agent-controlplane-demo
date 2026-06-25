"""Approval Chair agent executor.

A real A2A agent that ORCHESTRATES the expense-approval quorum: it discovers the
room voter agents from the ContextForge /a2a registry, delegates a vote to each
THROUGH the gateway (so every agent-to-agent call is governed + audited), tallies
the result, then attempts the wire (which OPA blocks). Returns the outcome as a
single text artifact. Deterministic — no LLM. Mirrors a2a-agents/auditor.
"""

import asyncio
import json
import os
import re

import httpx

from a2a.helpers import (
    get_message_text,
    new_task_from_user_message,
    new_text_message,
    new_text_part,
)
from a2a.server.agent_execution import AgentExecutor, RequestContext
from a2a.server.events import EventQueue
from a2a.server.tasks import TaskUpdater
from a2a.types.a2a_pb2 import TaskState

GATEWAY_URL = os.environ.get("GATEWAY_URL", "http://gateway:4444")
GATEWAY_TOKEN = os.environ.get("GATEWAY_TOKEN", "")
H = {"Authorization": f"Bearer {GATEWAY_TOKEN}", "Content-Type": "application/json"}


def _stance_of(name: str) -> str:
    for s in ("strict", "lenient", "random"):
        if s in name:
            return s
    return "random"


def parse_amount(text: str) -> float:
    m = re.search(r"\$?\s*(\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?)", text or "")
    return float(m.group(1).replace(",", "")) if m else 50000.0


def parse_payee(text: str) -> str:
    m = re.search(
        r"to\s+([A-Z][A-Za-z0-9&.'-]*(?:\s+[A-Z][A-Za-z0-9&.'-]*)*)", text or ""
    )
    return m.group(1).strip() if m else "Acme LLC"


class ChairAgent:
    """Discovers voters, delegates votes via the gateway, tallies, attempts the wire."""

    async def run_quorum(self, payee: str, amount: float) -> str:
        base = GATEWAY_URL.rstrip("/")
        votes = []  # (name, stance, vote)
        async with httpx.AsyncClient(timeout=10.0) as client:
            # 1) discover the room voter agents from the /a2a registry
            try:
                r = await client.get(f"{base}/a2a", headers=H)
                data = r.json()
                names = sorted(
                    a.get("name", "")
                    for a in (data if isinstance(data, list) else [])
                    if isinstance(a, dict) and a.get("name", "").startswith("room-")
                )
            except Exception:
                names = []

            # 2) delegate a vote to each voter THROUGH the gateway (governed),
            #    CONCURRENTLY so the quorum scales to a roomful of attendee agents.
            names = names[:75]  # defensive cap on fan-out width

            async def _one(name):
                stance = _stance_of(name)
                prompt = (
                    f"Vote on expense. payee={payee} amount={amount:.0f} "
                    f"approval=false stance={stance} agent={name}."
                )
                body = {
                    "jsonrpc": "2.0",
                    "id": 1,
                    "method": "tools/call",
                    "params": {
                        "name": f"a2a-{name}",
                        "arguments": {
                            "message": {
                                "role": "ROLE_USER",
                                "parts": [{"text": prompt}],
                                "messageId": f"chair-{name}",
                            }
                        },
                    },
                }
                try:
                    rr = await client.post(f"{base}/rpc", headers=H, json=body)
                    blob = json.dumps(rr.json())
                    vote = (
                        "approve"
                        if "VOTE=approve" in blob
                        else ("reject" if "VOTE=reject" in blob else "abstain")
                    )
                except Exception:
                    vote = "abstain"
                return (name, stance, vote)

            # each _one catches its own errors, so gather never raises
            votes = list(await asyncio.gather(*[_one(n) for n in names]))

            # 3) attempt the wire — OPA blocks it at the $10k cap regardless
            wire_body = {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "tools/call",
                "params": {
                    "name": "erp-payments-wire",
                    "arguments": {"payee": payee, "amount": amount, "approval": False},
                },
            }
            try:
                wr = await client.post(f"{base}/rpc", headers=H, json=wire_body)
                wblob = json.dumps(wr.json())
                blocked = "Plugin Violation" in wblob
                m = re.search(r"Wire amount [^\"\\]+", wblob)
                wdetail = m.group(0) if m else ("blocked" if blocked else "executed")
            except Exception as e:  # noqa: BLE001
                blocked = False
                wdetail = f"wire error: {e}"

        ap = sum(1 for _, _, v in votes if v == "approve")
        rj = sum(1 for _, _, v in votes if v == "reject")
        ab = sum(1 for _, _, v in votes if v == "abstain")
        vote_line = " ".join(f"{n}={v}" for n, _, v in votes)
        return (
            f"QUORUM agent_approve={ap} agent_reject={rj} agent_abstain={ab} "
            f"wire_blocked={'true' if blocked else 'false'} voters={len(votes)}\n"
            f"{vote_line}\n"
            f"wire_detail: {wdetail}"
        )


class ChairAgentExecutor(AgentExecutor):
    """A2A executor for the Approval Chair agent."""

    def __init__(self) -> None:
        self.agent = ChairAgent()

    async def execute(self, context: RequestContext, event_queue: EventQueue) -> None:
        if context.current_task:
            task = context.current_task
        else:
            task = new_task_from_user_message(context.message)
            await event_queue.enqueue_event(task)

        task_updater = TaskUpdater(
            event_queue=event_queue, task_id=task.id, context_id=task.context_id
        )
        await task_updater.update_status(
            state=TaskState.TASK_STATE_WORKING,
            message=new_text_message("Running approval quorum..."),
        )

        query = get_message_text(context.message) or ""
        amount = parse_amount(query)
        payee = parse_payee(query)
        result = await self.agent.run_quorum(payee=payee, amount=amount)
        print("Chair result:", result)

        await task_updater.add_artifact(
            parts=[new_text_part(text=result, media_type="text/plain")]
        )
        await task_updater.update_status(
            state=TaskState.TASK_STATE_COMPLETED,
            message=new_text_message("Quorum complete."),
        )

    async def cancel(self, context: RequestContext, event_queue: EventQueue) -> None:
        raise NotImplementedError("Cancel is not supported.")
