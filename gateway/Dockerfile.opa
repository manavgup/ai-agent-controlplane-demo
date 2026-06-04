# OPA with the FinByte Rego policies BAKED IN (instead of bind-mounted), so the
# policy decision point also needs no host file-sharing — the demo runs from any
# clone path. `command:` in docker-compose.yml still points OPA at /policies.
#
# Use the `-static` tag: it's a MULTI-ARCH (linux/amd64 + linux/arm64) scratch
# build. The plain `:0.70.0` tag is amd64-ONLY, which crash-loops (exit 255) on a
# bare arm64 Linux host (e.g. an Apple-silicon VM) that has no amd64 emulation —
# the gateway then reports "policy engine unavailable". `-static` runs natively on
# both arches (and avoids the emulation tax on Apple-silicon Docker Desktop).
FROM openpolicyagent/opa:0.70.0-static
COPY policies /policies
