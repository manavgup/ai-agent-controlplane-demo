# notify — FastMCP v3 MCP server (notification stub).
from fastmcp import FastMCP

mcp = FastMCP("notify")

_SENT: list[dict] = []


@mcp.tool
def notify(channel: str, message: str) -> dict:
    """Send a notification to a channel (stub: records and echoes it)."""
    entry = {"channel": channel, "message": message}
    _SENT.append(entry)
    return {"status": "sent", **entry}


@mcp.custom_route("/health", methods=["GET"])
async def health(request):
    """Plain REST health probe (for the gateway's connectivity test + containers)."""
    from starlette.responses import JSONResponse

    return JSONResponse({"status": "ok", "server": "notify"})


if __name__ == "__main__":
    mcp.run(transport="http", host="0.0.0.0", port=8000)
