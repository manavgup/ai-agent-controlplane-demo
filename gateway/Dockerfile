# ContextForge gateway with our curated plugin config + the FinByteGuard plugin
# BAKED IN (instead of bind-mounted from the host). This removes the only host
# file dependencies for the gateway, so the demo runs from ANY clone path —
# including paths Docker's VM can't share (e.g. /tmp on macOS) that otherwise
# fail with "mount … config.yaml … Not a directory".
#
# Base is the pinned ContextForge v1.0.2 image (bundles the plugins + cpex).
# To change the config/plugin you now rebuild (`docker compose build gateway`)
# rather than restart — fine for the demo; the files are stable.
FROM ghcr.io/ibm/mcp-context-forge@sha256:cfeaf233bd6376ac4410309aba7c81a9c5380324f62337e144523179c062eb44

# our curated config selects FinByteGuard + the cpex PII filter (overrides the bundled config)
COPY plugins/config.yaml /app/plugins/config.yaml
# the custom plugin, on the gateway's import path (/app is the working dir)
COPY custom/finbyte_guard.py /app/finbyte_guard.py
