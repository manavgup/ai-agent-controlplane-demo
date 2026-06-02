# fx-rates (TARGET / FALLBACK) — the version with the `convert` tool that Bob is
# asked to build in the "Bob the builder" showcase beat.
#
# The repo ships mcp-servers/fx-rates/server.py as the BASE (get_fx_rate +
# list_currencies). On stage, Bob edits server.py to add `convert`. If Bob's
# live edit wobbles, `make fxrates-convert` copies THIS file over server.py and
# rebuilds — a one-keystroke fallback. `make fxrates-reset` restores the base.
from fastmcp import FastMCP

mcp = FastMCP("fx-rates")

# Static demo rates (USD base).
_RATES = {"EUR": 0.92, "GBP": 0.79, "JPY": 156.3, "CAD": 1.37, "USD": 1.0}


@mcp.tool
def get_fx_rate(quote: str, base: str = "USD") -> dict:
    """Return the demo FX rate to convert 1 unit of `base` into `quote`."""
    b, q = base.upper(), quote.upper()
    if q not in _RATES or b not in _RATES:
        return {"error": "unknown_currency", "base": b, "quote": q, "known": sorted(_RATES)}
    return {"base": b, "quote": q, "rate": round(_RATES[q] / _RATES[b], 6)}


@mcp.tool
def list_currencies() -> list[str]:
    """List the supported quote currencies."""
    return sorted(_RATES)


@mcp.tool
def convert(amount: float, base: str = "USD", quote: str = "EUR") -> dict:
    """Convert `amount` from `base` currency into `quote` using the demo rates."""
    b, q = base.upper(), quote.upper()
    if b not in _RATES or q not in _RATES:
        return {"error": "unknown_currency", "base": b, "quote": q, "known": sorted(_RATES)}
    rate = _RATES[q] / _RATES[b]
    return {"amount": amount, "base": b, "quote": q,
            "rate": round(rate, 6), "converted": round(amount * rate, 2)}


@mcp.custom_route("/health", methods=["GET"])
async def health(request):
    """Plain REST health probe (for the gateway's connectivity test + containers)."""
    from starlette.responses import JSONResponse
    return JSONResponse({"status": "ok", "server": "fx-rates"})


if __name__ == "__main__":
    mcp.run(transport="http", host="0.0.0.0", port=8000)
