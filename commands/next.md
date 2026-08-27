---
description: "Harness stage 1 — survey the repo and emit the next task packet"
argument-hint: "[optional roadmap ID to force]"
allowed-tools: Read, Grep, Glob, Bash, Agent
---

Run stage 1 of the development harness.

**Pre-step:** `. .harness/config.env` and run
`"$HARNESS_ENGINE_ROOT"/scripts/harness-trajectory.sh`. If any tripwire is
FIRED, stop before delegating: show me the tripwires and tell me to run
`/chart`. A drifting loop should not be handed another task.

No process narration — never announce what you are about to do. But
decisions surface the moment they exist: when the surveyor returns, print
the **survey digest** immediately —

- **Task:** `<ID>` — title, and why it was picked over the others
- **Fit:** the packet's fit line, verbatim
- **Budget:** estimated lines / files / tests vs the limits
- **Discrepancies:** one line each, or "none"
- **Split:** proposed slices, or "not needed"

Delegate to the `surveyor` subagent. Give it this task:

> Establish true repository status, reconcile it against the roadmap (path in `HARNESS_ROADMAP` in
> `.harness/config.env`, default `docs/roadmap.md`), and
> emit exactly one task packet to `.harness/state/current-task.md`.
> $ARGUMENTS
>
> If `$ARGUMENTS` names a roadmap ID, survey for that item specifically, but
> still report any discrepancies you find elsewhere and still enforce the size
> budget — if that item is too large, emit slice 1 and propose the split.

When the surveyor returns, show me:

1. The chosen task ID and title, and why that one.
2. Every discrepancy it found between the roadmap, the tests, and the code.
3. Whether a split was required, and the proposed split if so.

Before stopping, log the outcome via `. .harness/config.env && "$HARNESS_ENGINE_ROOT"/scripts/harness-event.sh <task> <event> [detail]`:
`survey-done milestone=<M>` when a packet was written, or
`survey-exhausted` (task `-`) when the milestone is spent.

Then stop. Do not proceed to planning. I will read the packet and run `/plan`.
