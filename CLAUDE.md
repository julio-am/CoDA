# Project conventions

Every agent in this repository reads this file. Claude Code loads the whole
`CLAUDE.md` hierarchy into every subagent's context automatically, so this is
the one place where a rule reaches all five stages of the harness.

Keep it short and factual. Commands, invariants, hard rules. Not prose.

**This repository is the harness developing itself.** The product is the set
of scripts, agent prompts, and state conventions that run the four-stage loop.
The loop that builds it is the same loop it implements.

---

## Commands

Agents run exactly these commands. They do not improvise, and they do not
guess a test runner.

| Purpose | Command |
|---|---|
| Build | (none — interpreted bash; the syntax gate is the Typecheck row) |
| Test — full suite | `bats tests` |
| Test — single file | `bats {file}` |
| Test — by marker/name | `bats tests --filter {pattern}` |
| Lint | `shellcheck -S error scripts/*.sh INSTALL.sh` |
| Typecheck / static analysis | `bash -n scripts/*.sh INSTALL.sh` |
| Format | (none — match the surrounding style; see Style) |

The suite is seconds long; there is no separate fast subset. The Lint row
gates at `-S error` because pre-existing sub-error findings exist; tightening
to default severity is roadmap item R-005 and flips this row when it lands.

## Repository map

- `scripts/` — the product. Status derivation (`harness-status.sh`), test
  audit (`verify-new-tests.sh`), and the enforcement guards (`guard-*.sh`).
  **Guards are human-owned:** the implementer's write scope excludes
  `scripts/guard-*` by hook, so a task that changes a guard is implemented by
  the human, never by an agent inside the loop the guard constrains.
- `tests/` — bats suite. Acceptance tests carry a `# @harness:R-NNN` marker.
- `docs/roadmap.md` — intent. Only the reviewer writes to it.
- `.claude/agents/`, `.claude/commands/` — the five stage prompts and the
  slash commands. Edited only by the human, between loops, one change at a
  time — prompt edits are the harness's only tuning knob, and changing two
  things at once destroys the only eval available (re-running the same task).
- `.harness/config.env` — the commands above, machine-readable for scripts.
- `.harness/state/` — live loop state. One writer per file; table below.
- `.harness/templates/` — the shape of each state file.
- `.harness/logs/` — untracked. Archived loops and `git-push.log`.
- `INSTALL.sh` — copies the harness into a target repo; refuses collisions.
- `HANDOFF.md`, `README-harness.md` — installation and design rationale.

## Invariants

These are what the plan-critic checks plans against. Violating one is a
blocking finding, not a style preference.

1. **Guards fail closed.** Hook input that cannot be parsed exits 2. No parse
   path may fall through to "no path found, allow". (R-001 exists because the
   sed fallback violates this today.)
2. **Hook exit codes are the contract.** 0 allows, 2 blocks with a stderr
   message the agent sees. Nothing else. A guard must never exit 1 — Claude
   Code treats non-2 as a non-blocking error and the write proceeds.
3. **Guards assume only git + POSIX userland at hook time.** `jq` and
   `python3` are opportunistic accelerators; `bats` and `shellcheck` are
   dev-time tools and must never be required for enforcement to work.
4. **One writer per artifact.**
   | Artifact | Writer |
   |---|---|
   | `.harness/state/current-task.md` | surveyor |
   | `.harness/state/plan.md` | architect |
   | `.harness/state/plan-critique.md` | plan-critic |
   | `scripts/**` (minus `guard-*`), `tests/**` | implementer |
   | `docs/**`, `.harness/state/review.md` | reviewer |
   | `scripts/guard-*`, `.claude/**` | human only |
   | `.harness/state/blockers.md` | whichever agent is blocked |
5. **Every push attempt is logged** — allowed or blocked — to
   `.harness/logs/git-push.log` before the guard returns its verdict.
6. **`@harness:R-NNN` markers are plain grep targets.** Status derivation is
   `grep -rl`; nothing may require a parser to decide whether an item is done.
7. **`CLAUDE.md` and `.harness/config.env` state the same commands.** Agents
   read the table, scripts read the file. A change to one changes both.
8. **stdout/stderr discipline:** stderr is for humans, exit codes and stdout
   are for machines.

## Style

- Bash, not POSIX sh. `set -uo pipefail` in hook guards (a guard must reach
  its own fail-closed exit, not die mid-parse on `-e`); `set -euo pipefail`
  everywhere else.
- Two-space indent. Lowercase locals, UPPERCASE for config/environment.
- shellcheck-clean at `-S error` now, default severity once R-005 lands.
  Deliberate word-splitting (e.g. `$TEST_PATHS`) gets a directive comment,
  not quotes.
- Comments explain why, not what.

---

## Hard rules for every agent

1. **Never commit to the default branch.** All work happens on `task/<ID>`.
2. **Never run `git push`.** The human pushes. (The reviewer is the single
   exception, task branches only, enforced by `scripts/guard-git-push.sh`.)
3. **Never run `git reset --hard`, `git checkout .`, `git clean`, or anything
   else that discards uncommitted work.** There may be human edits in the tree.
4. **Never rewrite history** (`rebase`, `commit --amend`, `push --force`).
