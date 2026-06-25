"""Entrypoint for the Room Voter A2A agent.

One process serves the agent card at /.well-known/agent-card.json, a JSON-RPC
endpoint at '/', and a /health probe on 0.0.0.0:8000. ContextForge registers the
five fixed voter entries that all point here (distinguished by a ?agent= query
suffix that this server ignores), so they share one backend.
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

from agent_executor import RoomVoterExecutor

HOST = "0.0.0.0"
PORT = 8000


def build_agent_card() -> AgentCard:
    skill = AgentSkill(
        id="vote_expense",
        name="vote_expense",
        description=(
            "Votes approve/reject on an expense per a voting stance carried in "
            "the request (strict / lenient / random)."
        ),
        tags=["vote", "expense", "quorum"],
        examples=[
            "Vote on expense. payee=Acme LLC amount=50000 stance=strict",
            "Vote on expense. payee=Corner Cafe amount=500 stance=lenient",
        ],
        input_modes=["text/plain"],
        output_modes=["text/plain"],
    )
    return AgentCard(
        name="Room Voter Agent",
        description="A governed voter in the expense-approval quorum.",
        version="0.1.0",
        default_input_modes=["text/plain"],
        default_output_modes=["text/plain"],
        capabilities=AgentCapabilities(streaming=True),
        supported_interfaces=[
            AgentInterface(
                protocol_binding="JSONRPC",
                url=f"http://{HOST}:{PORT}",
            )
        ],
        skills=[skill],
    )


async def health(_request: Request) -> JSONResponse:
    return JSONResponse({"status": "ok", "server": "room-agent"})


def build_app() -> Starlette:
    public_agent_card = build_agent_card()
    request_handler = DefaultRequestHandler(
        agent_executor=RoomVoterExecutor(),
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
