---
description: "Harness stage 3 — create the task branch and implement the approved plan"
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, Agent
disable-model-invocation: true
---

Run stage 3 of the development harness.

Work without narration — no play-by-play, no announcing steps. Your
visible output is the pre-flight questions (if any) and the handoff report.

Current branch: !`git rev-parse --abbrev-ref HEAD`
Working tree: !`git status --porcelain | head -20`

**Before delegating:**

1. Confirm the plan has been approved — `.harness/state/plan.md` exists and I
   have said to proceed. If I have not explicitly approved it, ask me first.
2. If the working tree has uncommitted changes that are not mine to keep, stop
   and ask. Never discard them.
3. Create and check out the task branch `task/<ID>` from the default branch,
   using the ID in `.harness/state/current-task.md`. If the branch already
   exists, check it out and say so rather than recreating it.

**Then** delegate to the `implementer` subagent:

> Implement `.harness/state/plan.md` for the task in
> `.harness/state/current-task.md`. Honour the resolutions recorded in
> `.harness/state/plan-critique.md`. Write the planned tests, drive the suite
> green, and commit on the task branch.

When it returns, show me its handoff verbatim — what it built, tests added,
**anything it did differently from the plan**, and the final suite status. Do
not editorialise the handoff or smooth over a deviation.

If it hit its attempt budget and wrote `.harness/state/blockers.md`, show me
that instead and stop.
