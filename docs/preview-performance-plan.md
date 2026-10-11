# Attachment preview performance

Scope: Presentation.lua only; leave authoritative validation and provider ownership unchanged.

The current rebuild solves the cart once, solves it again for its already selected option, and runs native attachment/tool checks even when the solver has already rejected an option. The latter repeats provider work for missing parts and invalid dependency combinations on every selection.

Before editing, add regression assertions for invalid-option reason precedence, skipped redundant native checks, and selected-cart solver reuse. Preserve existing nearby-tool, owned-only, installed-part, and prerequisite behavior. Optimize within one rebuild only: group candidates by slot, reuse the selected cart result, and short-circuit native/tool checks for rejected plans. Do not retain inventory, tool, or plan state across rebuilds.

Verification: run the installed game's Kahlua source suite, including presentation and planner tests. Report deterministic solver/native-call reductions rather than claiming measured in-game latency improvements. Connected-client timing remains an in-game verification gap.
