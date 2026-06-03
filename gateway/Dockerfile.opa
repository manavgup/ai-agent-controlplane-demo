# OPA with the FinByte Rego policies BAKED IN (instead of bind-mounted), so the
# policy decision point also needs no host file-sharing — the demo runs from any
# clone path. `command:` in docker-compose.yml still points OPA at /policies.
FROM openpolicyagent/opa:0.70.0
COPY policies /policies
