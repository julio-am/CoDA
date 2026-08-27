---
description: "Harness stage 2 — produce an implementation plan and critique it"
allowed-tools: Read, Grep, Glob, Bash, Agent
---

Run stage 2 of the development harness. This is two delegations in sequence.

Work without narration — no play-by-play, no announcing steps. Your
visible output is the gate summary specified at the end.

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
3. **Proposed split-out tasks**, if any — the defect, the critic's ruling on
   the split, and the ordering opinion (fix first vs. proceed).
4. A one-line summary of the change set: file count, test count.

Log via `. .harness/config.env && "$HARNESS_ENGINE_ROOT"/scripts/harness-event.sh <task> <event> [detail]`: `critique-done blocking=N gaps=N questions=N` after the
critic's first pass, and `recheck-done cleared=N notcleared=N` after a
re-check.

Then stop and wait. Do not implement anything, and do not revise the plan on
your own initiative. When I ask for revisions: delegate **once** to the
`architect` (my directives plus the critic's rulings), then **once** to the
`plan-critic` to re-check — it verdicts each prior finding CLEARED or NOT
CLEARED and may add only Blocking findings the revision itself introduced.
Present the verdicts and any contested rulings, then stop. One revision +
re-check cycle per instruction from me; disagreement that survives it is
mine to settle, not the loop's.
