"""Room voter agent executor.

Reads the vote prompt from the user message, computes a vote with the pure
decide_vote() logic, and returns it as a single text artifact. The stance and
expense travel inside the prompt, so this agent holds no per-voter state — one
process backs all five fixed catalog entries.

When the prompt names an attendee voter (room-<stance>-<INITIALS>), the executor
reads the owner's private note from the corpus MCP server *through the gateway*
(governed: PII-redacted, injection-neutralised, audited) and votes per that rule.
Fixed voters (room-strict-1) have a numeric suffix → no note → fall back to stance.
"""

import os

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

from vote import decide_vote, decide_with_corpus, parse_owner

GATEWAY_URL = os.environ.get("GATEWAY_URL", "http://gateway:4444")
GATEWAY_TOKEN = os.environ.get("GATEWAY_TOKEN", "")
H = {"Authorization": f"Bearer {GATEWAY_TOKEN}", "Content-Type": "application/json"}


async def _read_corpus(owner: str) -> str:
    """Read the owner's note over MCP THROUGH the gateway (governed: PII redacted,
    injection neutralized, audited). Returns '' on any error so the voter can fall
    back to its stance."""
    if not owner or owner.isdigit() or not GATEWAY_TOKEN:
        return ""
    body = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {"name": "corpus-get-corpus", "arguments": {"owner": owner}},
    }
    try:
        async with httpx.AsyncClient(timeout=6.0) as client:
            r = await client.post(
                f"{GATEWAY_URL.rstrip('/')}/rpc", headers=H, json=body
            )
            data = r.json()
            res = data.get("result", {}) if isinstance(data, dict) else {}
            content = res.get("content") or []
            if content and isinstance(content, list):
                return content[0].get("text", "") or ""
    except Exception:
        return ""
    return ""


class RoomVoterExecutor(AgentExecutor):
    """A2A executor: turns a vote prompt into 'VOTE=approve|reject :: reason'."""

    async def execute(
        self,
        context: RequestContext,
        event_queue: EventQueue,
    ) -> None:
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
            message=new_text_message("Voting on expense..."),
        )

        query = get_message_text(context.message) or ""
        owner = parse_owner(query)
        note = await _read_corpus(owner)
        result = decide_with_corpus(query, note) if note else decide_vote(query)
        print("Room voter result:", result, "| owner:", owner, "| note:", bool(note))

        await task_updater.add_artifact(
            parts=[new_text_part(text=result, media_type="text/plain")]
        )
        await task_updater.update_status(
            state=TaskState.TASK_STATE_COMPLETED,
            message=new_text_message("Vote complete."),
        )

    async def cancel(self, context: RequestContext, event_queue: EventQueue) -> None:
        raise NotImplementedError("Cancel is not supported.")
