package mcpgateway

import rego.v1

# UnifiedPDP (OPA engine) POSTs {"input": {subject, action, resource, context}}
# to /v1/data/mcpgateway and reads result.allow (bool) + result.deny ([]string).
# tool args land at input.context.tool_args.* ; action is "tools.invoke.<tool>".
#
# Two-tier wire posture:
#   amount <  $10,000              -> auto-approve (allow)
#   $10,000 <= amount < $100,000   -> needs approval=true (a governed QUORUM
#                                     majority or dual approval can provide it)
#   amount >= $100,000             -> HARD CEILING: always denied, even with
#                                     approval=true. Policy beats consensus — not
#                                     even a unanimous quorum can authorize it.

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

auto_approve_limit := 10000
hard_ceiling := 100000

# Hard ceiling: a wire at/above the ceiling is denied no matter what — approval
# (from a quorum majority or otherwise) cannot override it.
over_ceiling if {
	is_wire_call
	amount >= hard_ceiling
}

# Dual-approval band: a wire in [$10k, ceiling) needs an explicit approval flag.
# The governed quorum supplies approval=true when its majority approves.
needs_approval if {
	is_wire_call
	amount >= auto_approve_limit
	amount < hard_ceiling
	not approved
}

deny contains msg if {
	over_ceiling
	msg := sprintf("Wire amount %v exceeds the $%v hard ceiling and cannot be approved by a quorum or dual approval. FinByte T&E policy §3.", [amount, hard_ceiling])
}

deny contains msg if {
	needs_approval
	msg := sprintf("Wire amount %v requires approval (a quorum majority or dual approval, approval=true). FinByte T&E policy §2.", [amount])
}

# Allow anything that is neither over the ceiling nor missing required approval.
allow if {
	not over_ceiling
	not needs_approval
}
