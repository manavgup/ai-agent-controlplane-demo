# ContextForge gateway with our curated plugin config + the FinByteGuard plugin
# BAKED IN (instead of bind-mounted from the host). This removes the only host
# file dependencies for the gateway, so the demo runs from ANY clone path —
# including paths Docker's VM can't share (e.g. /tmp on macOS) that otherwise
# fail with "mount … config.yaml … Not a directory".
#
# Base is the ContextForge image (bundles the plugins + cpex), pinned by the
# digest of the MULTI-ARCH manifest index for `latest`. Pinning the index (not
# an arch-specific child) keeps the build reproducible AND lets Docker select
# the host's architecture at build time — so the demo runs on amd64, arm64,
# s390x and ppc64le, not just the Apple-Silicon machine it was authored on.
# (The previous pin was an arm64-only child digest, which broke every non-arm64
# host — including x86 CI runners and attendees' laptops.)
# To change the config/plugin you now rebuild (`docker compose build gateway`)
# rather than restart — fine for the demo; the files are stable.
FROM ghcr.io/ibm/mcp-context-forge@sha256:2fc64229a4b67bb0f0305ece8d4377364a60a6504ca6e8f95c833ccb15625aaa

# our curated config selects FinByteGuard + the cpex PII filter (overrides the bundled config)
COPY plugins/config.yaml /app/plugins/config.yaml
# the custom plugin, on the gateway's import path (/app is the working dir)
COPY custom/finbyte_guard.py /app/finbyte_guard.py
