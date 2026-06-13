"""Register (or RE-register) a backend MCP server into the gateway.

Unlike a bare POST that treats "already exists" as success, this DELETEs any
existing gateway record of the same name first, so the gateway re-discovers the
backend's current tool list (e.g. a freshly-added `convert`). Mirrors seed.py.

Usage:
    ADMIN_TOKEN=... uv run --with httpx python gateway/seed/register.py \
        <name> <url> [transport]
Example:
    register.py sales-tax http://sales-tax:8000/mcp STREAMABLEHTTP
"""

import sys

from _gwapi import api, client, jget


def main():
    if len(sys.argv) < 3:
        sys.exit("usage: register.py <name> <url> [transport]")
    name, url = sys.argv[1], sys.argv[2]
    transport = sys.argv[3] if len(sys.argv) > 3 else "STREAMABLEHTTP"

    with client() as c:
        for g in jget(c, "/gateways"):
            if g.get("name") == name and g.get("id"):
                d = api(c, "DELETE", f"/gateways/{g['id']}")
                print(f"[gw] delete existing {name}: {d.status_code}")
        r = api(
            c,
            "POST",
            "/gateways",
            json={
                "name": name,
                "url": url,
                "transport": transport,
                "description": f"{name} MCP server",
            },
        )
        print(f"[gw] register {name}: {r.status_code} {r.text[:160]}")
        if r.status_code not in (200, 201):
            sys.exit(1)


if __name__ == "__main__":
    main()
