"""Entrypoint for the Approval Chair A2A agent.

Serves the agent card at /.well-known/agent-card.json, a JSON-RPC endpoint at '/',
and a /health probe, on 0.0.0.0:8000. The chair orchestrates the room voter agents
(discover via /a2a, delegate via the gateway) and attempts the governed wire.
"""

import uvicorn

from starlette.applications import Starlette
from starlette.requests import Request
from starlette.responses import JSONResponse
from starlette.routing import Route

from a2a.server.request_handlers import DefaultRequestHandler
from a2a.server.routes import create_agent_card_routes, create_jsonrpc_routes
from a2a.server.tasks import InMemoryTaskStore
from a2a.types import AgentCapabilities, AgentCard, AgentInterface, AgentSkill

from agent_executor import ChairAgentExecutor

HOST = "0.0.0.0"
PORT = 8000


def build_agent_card() -> AgentCard:
    skill = AgentSkill(
        id="run_quorum",
        name="run_quorum",
        description=(
            "Discovers the room voter agents, delegates an expense vote to each "
            "through the control-plane gateway, tallies the result, and attempts "
            "the payment (which policy may block)."
        ),
        tags=["quorum", "orchestration", "expense", "a2a"],
        examples=[
            "Run the approval quorum for a $50000 wire to Acme LLC",
        ],
        input_modes=["text/plain"],
        output_modes=["text/plain"],
    )
    return AgentCard(
        name="Approval Chair Agent",
        description=(
            "Orchestrates the expense-approval quorum across the room voter agents "
            "over A2A, through the control-plane gateway."
        ),
        version="0.1.0",
        default_input_modes=["text/plain"],
        default_output_modes=["text/plain"],
        capabilities=AgentCapabilities(streaming=True),
        supported_interfaces=[
            AgentInterface(protocol_binding="JSONRPC", url=f"http://{HOST}:{PORT}")
        ],
        skills=[skill],
    )


async def health(_request: Request) -> JSONResponse:
    return JSONResponse({"status": "ok", "server": "chair"})


def build_app() -> Starlette:
    public_agent_card = build_agent_card()
    request_handler = DefaultRequestHandler(
        agent_executor=ChairAgentExecutor(),
        task_store=InMemoryTaskStore(),
        agent_card=public_agent_card,
    )
    routes = [Route("/health", health, methods=["GET"])]
    routes.extend(create_agent_card_routes(public_agent_card))
    routes.extend(create_jsonrpc_routes(request_handler, "/"))
    return Starlette(routes=routes)


def main() -> None:
    uvicorn.run(build_app(), host=HOST, port=PORT)


if __name__ == "__main__":
    main()
