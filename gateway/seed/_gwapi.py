"""Shared helpers for talking to the ContextForge gateway admin API.

Run via `uv run --with httpx` so a full Python stdlib + httpx is always present
(some demo hosts ship python3-minimal without the stdlib `json` module).

Env:
    GATEWAY_URL   gateway base (default http://localhost:4444)
    ADMIN_TOKEN   admin bearer token (required for mutating calls)
"""

import os

import httpx

BASE = os.environ.get("GATEWAY_URL", "http://localhost:4444").rstrip("/")
TOKEN = os.environ.get("ADMIN_TOKEN", "")
H = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}


def client():
    return httpx.Client(base_url=BASE, headers=H, timeout=60)


def jget(c, path):
    """GET path and return parsed JSON, or [] on any error."""
    try:
        return c.get(path).json()
    except Exception:
        return []


def api(c, method, path, **kw):
    return c.request(method, path, **kw)


def norm(s):
    """Normalize a tool name for fuzzy matching: lowercase, drop _ and -."""
    return (s or "").lower().replace("_", "").replace("-", "")


def match_tool_ids(tools, names):
    """Resolve tool *names* to gateway tool ids via normalized matching.

    `tools` is the /tools list (dicts with 'name'/'originalName' and 'id').
    Returns ids in request order, de-duplicated, skipping names with no match.
    """
    tmap = {}
    for t in tools:
        n = t.get("name") or t.get("originalName") or ""
        tid = t.get("id")
        if n and tid:
            tmap[n] = tid
    out = []
    for name in names:
        want = norm(name)
        for tn, tid in tmap.items():
            tnn = norm(tn)
            if tnn == want or tnn.endswith(want) or want in tnn:
                if tid not in out:
                    out.append(tid)
                break
    return out
