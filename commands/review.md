---
description: "Harness stage 4 — independently review the diff and reconcile the docs"
allowed-tools: Read, Grep, Glob, Bash, Agent
---

Run stage 4 of the development harness.

Delegate to the `reviewer` subagent:

> Review the current task branch against `.harness/state/current-task.md` and
> `.harness/state/plan.md`. Audit the new tests with
> `./scripts/verify-new-tests.sh`. Reconcile the roadmap (path in `HARNESS_ROADMAP`) and the affected
> docs against the code. Write `.harness/state/review.md`.

**Do not** give the reviewer the implementer's handoff, your summary of the
implementation, or anything else from this session's conversation about how the
work went. It gets the packet, the plan, the diff, and the repository. That is
deliberate.

When it returns, show me:

1. The verdict, and for a rejection, which stage it goes back to.
2. Each success criterion with its verdict and evidence.
3. Every test flagged as passing against the unchanged code — by name.
4. What changed in the roadmap and docs.

Then stop. I decide whether to `/land` or send it back.
