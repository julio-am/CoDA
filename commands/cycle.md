---
description: "Run the loop task-after-task, stopping only at gates autonomy has not earned"
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, Agent
disable-model-invocation: true
---

Drive the harness loop. I am invoking this deliberately: you may run every
stage below without asking again, and my gates are enforced by the autonomy
level, which you must consult rather than assume.

Work without narration — no play-by-play. Your visible output is gate
summaries, stop reports, and the end-of-cycle report.

Setup: `. .harness/config.env`; read the autonomy level:
`"$HARNESS_ENGINE_ROOT"/scripts/harness-autonomy.sh` (first line). Cap this
run at `${HARNESS_CYCLE_MAX:-3}` landed tasks.

Repeat, per task:

1. **Tripwires**: run `"$HARNESS_ENGINE_ROOT"/scripts/harness-trajectory.sh`.
   Any FIRED tripwire → stop the cycle and report: run `/chart`.
2. **Survey**: follow `${CLAUDE_PLUGIN_ROOT}/commands/next.md` (its
   procedure, not its stop — this command is the invocation). Milestone
   exhausted → stop: run `/chart`.
3. **Plan**: follow `${CLAUDE_PLUGIN_ROOT}/commands/plan.md`'s procedure.
   Gate: if level >= 2 AND the critic's findings are fully resolved (a
   re-check with every finding CLEARED, zero Questions, zero contested
   rulings, zero proposed splits) → log
   `harness-event.sh <ID> gate-auto plan` and continue. Otherwise stop and
   present the gate-1 summary; the cycle ends here for my answer.
4. **Build**: follow `${CLAUDE_PLUGIN_ROOT}/commands/build.md`'s procedure
   (the plan gate above stands in for my per-plan approval at level >= 2).
   Blockers written → stop and show them.
5. **Review**: follow `${CLAUDE_PLUGIN_ROOT}/commands/review.md`'s
   procedure. Gate: if level >= 1 AND the verdict is Accept AND every
   instrument finding is adjudicated → log
   `harness-event.sh <ID> gate-auto review` and continue. A rejection
   routes per the reviewer's verdict (stage 2 or 3) and counts as this
   task's retry — more than one rejection in a cycle → stop and report.
   Otherwise (verdict fine, level < 1) stop and present the gate-2 summary.
6. **Land**: follow `${CLAUDE_PLUGIN_ROOT}/commands/land.md`'s procedure —
   its four push gates are mechanical and always apply. A failed land gate
   → stop and report.

After each landed task: if the cap is reached, stop. Otherwise loop.

End-of-cycle report, always: tasks landed (IDs, merge commits), where and
why the cycle stopped, gates auto-passed (from the event log), tripwire
state, and the autonomy line. Never exceed the cap, never skip a stage,
never push anything but what land.md's own gates allow.
