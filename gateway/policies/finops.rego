package mcpgateway

import rego.v1

# UnifiedPDP (OPA engine) POSTs {"input": {subject, action, resource, context}}
# to /v1/data/mcpgateway and reads result.allow (bool) + result.deny ([]string).
# tool args land at input.context.tool_args.* ; action is "tools.invoke.<tool>".
#
# Posture: ALLOW everything except a large wire/payment with no approval flag.
# (Default-allow keeps every benign tool call working even though the PDP runs
#  on every tool_pre_invoke; only the dangerous wire is denied.)

default allow := false

# A wire/payment-style call is any tool whose id or action mentions wire or
# payment (covers erp-payments `wire` and the bridged `a2a_payments` agent tool,
# regardless of any server-name prefix the gateway adds).
is_wire_call if { regex.match(`(?i)(wire|payment)`, input.resource.id) }
is_wire_call if { regex.match(`(?i)(wire|payment)`, input.action) }

# Amount as a number whether the caller sent a JSON number or a string.
amount := a if {
	a := input.context.tool_args.amount
	is_number(a)
}
amount := to_number(input.context.tool_args.amount) if {
	not is_number(input.context.tool_args.amount)
}

approved if input.context.tool_args.approval == true

# The one thing we block: a >= $10,000 wire without an explicit approval flag.
is_blocked_wire if {
	is_wire_call
	amount >= 10000
	not approved
}

deny contains msg if {
	is_blocked_wire
	msg := sprintf("Wire amount %v exceeds the $10,000 auto-approve limit and requires dual approval (approval=true). FinByte T&E policy §2.", [amount])
}

# Allow anything that is not the blocked wire.
allow if { not is_blocked_wire }
