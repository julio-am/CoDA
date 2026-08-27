---
description: "Commit the reviewed task and its documentation updates"
allowed-tools: Read, Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*), Bash(git merge:*), Bash(git branch:*), Bash(git checkout:*)
disable-model-invocation: true
---

Land the current task. I have read the review and accepted it.

Work without narration — no play-by-play. Your visible output is each
confirmation checkpoint and the final state.

Diff summary: !`. .harness/config.env 2>/dev/null; git diff --stat $(git merge-base HEAD "${HARNESS_BASE_BRANCH:-main}" 2>/dev/null || echo HEAD~1)...HEAD`
Status: !`git status --porcelain`

Steps:

1. Show me the full list of files that will be committed, split into code,
   tests, and documentation. Wait for my confirmation before committing.
2. Normally there is nothing new to stage — the implementer and reviewer
   committed during their stages (code+tests, then docs+reconciliation). If
   anything reviewed remains uncommitted, commit it in that order,
   referencing the roadmap ID; plain messages, no marketing.
3. Merge the task branch into the default branch with `--no-ff`.
4. Archive the loop state:
   `. .harness/config.env && "$HARNESS_ENGINE_ROOT"/scripts/harness-land-state.sh <ID>`
5. **Judge whether the merge is safe to push, then push it.** All four
   gates must pass, mechanically verified, before pushing:
   - On the default branch with a clean working tree.
   - The archived review's verdict is Accept (read it from the archive
     just written).
   - The full suite is green on the merged result (`HARNESS_TEST_CMD`).
   - `origin/<default>` is an ancestor of HEAD — the push fast-forwards,
     no force of any kind.
   All pass → `git push origin <default>`, plain, exactly that form.
   Any gate fails → do not push; report which gate and why, and stop. Never
   work around a failed gate, never force, never push any other ref here
   (the reviewer already pushed the `task/*` branch — that is expected).
6. Report: the merge commit, each gate's result, the push result, and the
   archive location.
7. Log via `. .harness/config.env && "$HARNESS_ENGINE_ROOT"/scripts/harness-event.sh <task> <event> [detail]`: `land-pushed <merge-sha>`, or `land-gate-failed <gate>`
   when a gate stopped the push.
