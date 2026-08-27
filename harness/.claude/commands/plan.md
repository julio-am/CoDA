---
description: "Harness stage 2 — produce an implementation plan and critique it"
allowed-tools: Read, Grep, Glob, Bash, Agent
---

Run stage 2 of the development harness. This is two delegations in sequence.

**First**, delegate to the `architect` subagent:

> Read `.harness/state/current-task.md`, open every file it points at, and
> write an implementation and testing plan to `.harness/state/plan.md`.

**Then**, delegate to the `plan-critic` subagent:

> Read `.harness/state/current-task.md` and `.harness/state/plan.md` and the
> repository. Write findings to `.harness/state/plan-critique.md`.

Do **not** pass the architect's reply, reasoning, or summary to the critic. The
critic gets the files and the repository only. Its independence is the whole
point of the stage.

When both have returned, present to me in this order:

1. **Open questions** from the plan — each with its proposed default, so I can
   answer "defaults are fine".
2. **Blocking findings** and **gaps** from the critic, with their evidence.
3. A one-line summary of the change set: file count, test count.

Then stop and wait. Do not implement anything, and do not revise the plan on
your own initiative. If I ask for revisions, delegate them back to the
`architect`, then re-run the `plan-critic` on the revised plan.
