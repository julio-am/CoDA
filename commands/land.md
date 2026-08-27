---
description: "Commit the reviewed task and its documentation updates"
allowed-tools: Read, Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*), Bash(git merge:*), Bash(git branch:*), Bash(git checkout:*)
disable-model-invocation: true
---

Land the current task. I have read the review and accepted it.

Diff summary: !`git diff --stat $(git merge-base HEAD @{u} 2>/dev/null || echo HEAD~1)...HEAD`
Status: !`git status --porcelain`

Steps:

1. Show me the full list of files that will be committed, split into code,
   tests, and documentation. Wait for my confirmation before committing.
2. Stage and commit on the task branch. Two commits, in this order:
   - the code and test changes
   - the documentation and roadmap reconciliation
   Reference the roadmap ID in both messages. Plain messages, no marketing.
3. Merge the task branch into the default branch with `--no-ff`.
4. Archive the loop state: copy `.harness/state/*.md` to
   `.harness/logs/<ID>-<date>/`, then reset the state files from the engine's
   templates (`$HARNESS_ENGINE_ROOT/templates/`, per `.harness/config.env`).
5. Report the merge commit and tell me the default branch is ready to push.

**Do not push the default branch.** I push that, by hand, every time. The
reviewer may already have pushed the `task/*` branch to origin — that is
expected and is the only push an agent performs. If `git push` targeting the
default branch appears anywhere in your plan for this command, you have
misread it.
