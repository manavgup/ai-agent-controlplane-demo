"""Corpus MCP server — serves each attendee's private note over MCP.

The Companion writes notes here at Join time (POST /set); agents read them
through the ContextForge gateway via get_corpus(owner), where PII redaction +
injection neutralization + audit apply. In-memory, ephemeral by design (demo).
"""

from fastmcp import FastMCP

mcp = FastMCP("corpus")
STORE = {}  # owner (UPPER-cased) -> note text


@mcp.tool
def get_corpus(owner: str) -> str:
    """Return the private note the given owner contributed (empty string if none)."""
    return STORE.get((owner or "").upper(), "")


@mcp.custom_route("/set", methods=["POST"])
async def set_corpus(request):
    """The Companion writes an attendee's note here at Join time."""
    from starlette.responses import JSONResponse

    try:
        body = await request.json()
    except Exception:
        body = {}
    owner = str(body.get("owner", "")).upper()
    note = str(body.get("note", ""))
    if owner:
        STORE[owner] = note
    return JSONResponse({"ok": bool(owner), "owner": owner, "count": len(STORE)})


@mcp.custom_route("/health", methods=["GET"])
async def health(request):
    from starlette.responses import JSONResponse

    return JSONResponse({"status": "ok", "server": "corpus", "count": len(STORE)})


if __name__ == "__main__":
    mcp.run(transport="http", host="0.0.0.0", port=8000)
