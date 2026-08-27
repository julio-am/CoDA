---
description: "Harness stage 4 — independently review the diff and reconcile the docs"
allowed-tools: Read, Grep, Glob, Bash, Agent
---

Run stage 4 of the development harness.

Work without narration — no play-by-play, no announcing steps. Your
visible output is the gate summary specified at the end.

**First**, delegate to the `reviewer` subagent:

> Review the current task branch against `.harness/state/current-task.md` and
> `.harness/state/plan.md`. Audit the new tests with the engine's
> `verify-new-tests.sh` (via `$HARNESS_ENGINE_ROOT` from `.harness/config.env`).
> Reconcile the roadmap (path in `HARNESS_ROADMAP`) and the affected docs
> against the code. Write `.harness/state/review.md`.

**Do not** give the reviewer the implementer's handoff, your summary of the
implementation, anything from this session's conversation about how the work
went, **or the instrument findings below**. It gets the packet, the plan, the
diff, and the repository. Its first pass is independent; that is deliberate.

**While the reviewer works** (or immediately after delegating), run the
built-in `code-review` skill on the current branch at medium effort — it is a
second, independently-built reviewer with its own adversarial verification;
its typed findings are instrument evidence, not a verdict. If the diff
touches authentication, credentials, network, or file-permission code, also
run the `security-review` skill. Do not apply fixes from either (`--fix`
stays off — source changes go through the implementer or not at all).

**When the reviewer returns**, compare its review against the instrument
findings. For any instrument finding the reviewer did not already address,
resume the reviewer (continue the same agent, context intact) with the
findings verbatim and this instruction: "Independent instrument findings —
adjudicate each in the code: confirm with `path:line` evidence or refute
with a reason. Fold what you confirm into your verdict and update
`.harness/state/review.md`." The reviewer owns the final verdict; the
instrument never overrules it, and an unadjudicated finding never reaches
the gate silently.

Then show me:

1. The verdict, and for a rejection, which stage it goes back to.
2. Each success criterion with its verdict and evidence.
3. Every test flagged as passing against the unchanged code — by name.
4. What changed in the roadmap and docs.
5. Any split-out defect entries it wrote, with its ordering opinion — fix
   next (or before landing), or later.
6. The instrument findings table: each finding, the reviewer's adjudication
   (confirmed/refuted, with its evidence), and — separately — anything one
   reviewer caught that the other missed, in both directions. That
   discrepancy line is the standing quality measure of the reviewer itself.

Then stop. I decide whether to `/land` or send it back.
