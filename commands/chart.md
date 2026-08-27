---
description: "Outer loop — audit the milestone, chart the next one, set autonomy"
allowed-tools: Read, Grep, Glob, Bash, Agent, Edit, Write
disable-model-invocation: true
---

Run the outer loop's judgment stage.

No process narration. Print the trajectory's tripwire and autonomy lines
as soon as you have them, and the proposal digest the moment the navigator
returns.

**First**, mechanically:
`. .harness/config.env && "$HARNESS_ENGINE_ROOT"/scripts/harness-event.sh - chart-run`
then run `"$HARNESS_ENGINE_ROOT"/scripts/harness-trajectory.sh` yourself and
keep the output at hand.

**Then** delegate to the `navigator` subagent:

> Run your procedure: audit the closing milestone, audit alignment, and
> write `.harness/state/chart-proposal.md`.

When it returns, show me: the milestone audit verdict with its evidence, the
proposed next milestone and exit condition, new/deferred/killed items (titles
only), the autonomy recommendation, and its questions. Then stop and wait.

**On my approval** (I may approve sections selectively):
1. Apply the approved backlog changes verbatim from the proposal — you write
   the backlog here as my hands, outside the loop.
2. Apply approved north-star changes the same way. Unapproved sections are
   dropped, not deferred silently — tell me what was not applied.
3. If I approved an autonomy ceiling change, set
   `HARNESS_AUTONOMY_CEILING` in `.harness/config.env`.
4. Log: `harness-event.sh - chart-approved "milestone=<M> items+<n>-<k>"`,
   then commit the backlog/north-star/config changes on the default branch
   with a plain message, and stop. I push.
