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

**After it returns green** (skip this entirely if it wrote blockers): run the
built-in `simplify` skill on the branch's changed code — a polish pass for
reuse, simplification, and efficiency. It applies fixes directly. Then:

1. Re-run the full suite (`HARNESS_TEST_CMD` from `.harness/config.env`).
2. Green → commit the polish as its own commit on the task branch, message
   `<ID>: simplify pass (engine-applied)`, so the reviewer sees the
   implementer's work and the machine polish as separable diffs.
3. Red → revert exactly the files the simplify pass touched (`git restore`
   on those paths — nothing else in the tree), and report the pass as
   dropped, with the failure output. Never leave the branch red, and never
   revert anything the simplify pass did not write.

When done, show me the implementer's handoff verbatim — what it built, tests
added, **anything it did differently from the plan**, and the final suite
status — plus one line on the simplify outcome: applied (files touched),
dropped (why), or no findings. Do not editorialise the handoff or smooth
over a deviation.

If the implementer hit its attempt budget and wrote
`.harness/state/blockers.md`, show me that instead and stop.

Log via `. .harness/config.env && "$HARNESS_ENGINE_ROOT"/scripts/harness-event.sh <task> <event> [detail]`: `plan-approved` when I confirm at pre-flight; then
`build-green attempts=N` or `build-blocked`; then `simplify-applied`,
`simplify-dropped`, or `simplify-none`.
