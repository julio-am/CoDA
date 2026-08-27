# Project roadmap

**This file is intent, not status.** Code is the source of truth for what
exists; tests are the source of truth for what is done. The reviewer
reconciles this file against both at the end of every task.

Only the reviewer writes to this file.

---

## How to read an item

Every item has a stable ID (`R-NNN`) that never changes and is never reused.
An item is **done** when every test listed under **Acceptance** exists and
passes. Nothing else counts as done — not "the code looks finished", not "it
was in the last commit".

Tests are linked to an item with a marker comment placed next to the test:

```
# @harness:R-001
```

The marker is a plain grep target so it works in any language. Put it directly
above the test function, or in the test's docstring.

**Status values:** `todo` · `in-progress` · `blocked` · `done` · `deferred`

---

## R-001 — Guard path extraction fails closed without jq/python3

- **Status:** done
- **Intent:** `guard-write-paths.sh` promises to fail closed, but its sed
  fallback double-escapes the capture group (`\\(` where sed needs `\(`),
  extracts an empty path, and the guard treats "no path" as "nothing to
  guard" — allowing every write precisely in the degraded environment the
  fallback exists for (no `jq`, no `python3`). The sibling extractor in
  `guard-git-push.sh:27` shows the correct escaping. Restore fail-closed
  behaviour in the sed path.
- **Acceptance:**
  - [x] `sed fallback extracts file_path when jq and python3 are absent`
  - [x] `guard blocks out-of-scope write via sed fallback alone`
  - [x] `guard with jq present still blocks out-of-scope write`
- **Constraints:** No new runtime dependencies. Keep the jq → python3 → sed
  fallback order. Exit codes 0/2 only (CLAUDE.md invariant 2). Tests may
  simulate a jq/python3-free machine via a restricted `PATH` fixture.
- **Depends on:** —
- **Out of scope:** `guard-git-push.sh`'s extractor (already correct);
  factoring the two extractors into a shared library; any change to the
  role→scope table.
- **Notes:** Done 2026-08-26, directly by the overseer session — Julio directed engine bugs to be fixed outside the loop while the harness is brought up. Acceptance tests tagged and passing.

---

## R-002 — verify-new-tests.sh supports test-only tasks

- **Status:** todo
- **Intent:** The anti-tautology check assumes every task changes behaviour,
  so a task whose entire point is locking *existing* behaviour in tests
  (characterization) gets every new test flagged as tautological and cannot
  pass review cleanly. Add an explicit, auditable way for a task to declare
  itself test-only, under which the script expects new tests to pass at base
  and reports them as such instead of failing.
- **Acceptance:**
  - [ ] `test-only mode accepts characterization tests that pass at base`
  - [ ] `default mode still fails a new test that passes at base`
- **Constraints:** Default behaviour unchanged. The declaration must be
  visible in the task packet and in the script's invocation (auditable),
  never inferred from the diff.
- **Depends on:** —
- **Out of scope:** Auto-detecting characterization tests; reviewer prompt
  changes beyond reading the declaration.
- **Notes:** —

---

## R-003 — Write-guard role scoping locked by tests

- **Status:** done
- **Intent:** The role→path matrix in `guard-write-paths.sh` is currently
  verified once, by hand, at install time (HANDOFF step 3). Promote it to a
  characterization suite so a later edit to the guard or its message cannot
  silently change enforcement.
- **Acceptance:**
  - [x] `write guard matrix: each role allows its scope and blocks outside it`
  - [x] `write guard: blockers.md is writable by every role`
  - [x] `write guard: unknown role is blocked`
  - [x] `write guard: unparseable hook input is blocked`
  - [x] `write guard: implementer cannot modify scripts/guard-*`
- **Constraints:** Tests invoke the real script with real hook JSON on stdin;
  no reimplementation of its logic in the test.
- **Depends on:** R-002 (these tests pass at base by design)
- **Out of scope:** The push guard (R-004).
- **Notes:** Done 2026-08-26, directly by the overseer session — Julio directed engine bugs to be fixed outside the loop while the harness is brought up. Acceptance tests tagged and passing.

---

## R-004 — Push-guard policy locked by tests

- **Status:** done
- **Intent:** Same promotion as R-003, for `guard-git-push.sh`: the role
  gate, the flag gate, the branch gate, the refspec gate, and the log line.
- **Acceptance:**
  - [x] `push guard: non-reviewer roles are blocked`
  - [x] `push guard: force, delete, mirror, prune, tags are blocked`
  - [x] `push guard: reviewer on a non-task branch is blocked`
  - [x] `push guard: refspec naming another branch is blocked`
  - [x] `push guard: every attempt appends one line to git-push.log`
- **Constraints:** Tests run inside a throwaway git repo fixture so branch
  names are controlled; never against this repo's live state.
- **Depends on:** R-002
- **Out of scope:** The permission-prompt layer (`permissions.allow`) — that
  is Claude Code's, not the guard's.
- **Notes:** Done 2026-08-26, directly by the overseer session — Julio directed engine bugs to be fixed outside the loop while the harness is brought up. Acceptance tests tagged and passing.

---

## R-005 — shellcheck-clean at default severity

- **Status:** done
- **Intent:** The Lint row gates at `-S error` because two warnings
  (SC2221/SC2222, a redundant case pattern in `guard-git-push.sh:66`) and a
  handful of info-level findings predate the suite. Fix the real redundancy,
  add directives for the deliberate patterns (word-splitting of
  `$TEST_PATHS`/`$CHANGED` is by design; the trap'd `cleanup` is invoked),
  then tighten the CLAUDE.md Lint row and this repo's gate to default
  severity.
- **Acceptance:**
  - [x] `shellcheck at default severity exits 0 for scripts and INSTALL.sh`
- **Constraints:** Directives over rewrites for deliberate patterns —
  quoting `$TEST_PATHS` would break multi-directory support. Guard behaviour
  must not change (R-003/R-004 suites, once they exist, must stay green).
- **Depends on:** —
- **Out of scope:** `shfmt`/formatting; restyling beyond what a directive or
  the named fix requires.
- **Notes:** Done 2026-08-26, directly by the overseer session — Julio directed engine bugs to be fixed outside the loop while the harness is brought up. Acceptance tests tagged and passing.

---

## R-006 — harness-init points the engine at a target repo

- **Status:** done
- **Intent:** ~~INSTALL.sh copies the harness into a repo~~ Superseded by the
  pointing model: `scripts/harness-init.sh` scaffolds a target's
  `.harness/` (config with the engine root stamped, state, logs), a backlog
  at the configured roadmap path, and additively merges the plugin pointer
  and permission floor into the target's `.claude/settings.json`. Idempotent;
  never overwrites; refuses non-repos and the engine itself.
- **Acceptance:**
  - [x] `init scaffolds config, state, logs, roadmap, and settings`
  - [x] `init is idempotent and never clobbers existing files`
  - [x] `init refuses a non-git target and refuses the engine itself`
  - [x] `init honours a pre-existing HARNESS_ROADMAP path`
- **Constraints:** Additive settings merge only — existing keys always win.
- **Depends on:** R-007
- **Out of scope:** Un-pointing (removal); multi-engine setups.
- **Notes:** Rewritten 2026-08-26 when INSTALL.sh was retired; done the same
  day, directly by the overseer. Original INSTALL.sh remains in git history.

## R-007 — Loading and enforcement mechanism (plugin + agent_type hooks)

- **Status:** done
- **Intent:** DevAgent is self-contained and pointable: the repo is a Claude
  Code plugin, loaded into target-repo sessions via a settings-declared
  local marketplace. Enforcement is session-wide PreToolUse hooks
  (`hooks/hooks.json`, `${CLAUDE_PLUGIN_ROOT}` expansion) because plugin
  agents' frontmatter hooks never fire — established empirically by two
  probe rounds on 2026-08-26. Guards identify the actor from the hook
  input's `agent_type` field, which is stronger than the original argv role
  tag: an agent cannot invoke itself into a wider scope.
- **Acceptance:**
  - [x] `plugin, marketplace, and hooks manifests are valid JSON`
  - [x] `every hook command resolves to an existing executable script`
  - [x] `all five agents exist with frontmatter and no dead hooks blocks`
  - [x] `all five commands exist; build and land are human-trigger only`
- **Constraints:** Hook commands reference scripts via
  `${CLAUDE_PLUGIN_ROOT}` only; agents reach engine scripts via
  `HARNESS_ENGINE_ROOT` from the target's config — never a relative path.
- **Depends on:** —
- **Out of scope:** Distribution beyond this machine; multi-user
  marketplaces.
- **Notes:** Entry restored 2026-08-26 after the reconciliation log below
  caught it missing; the tests existed first.

---

## R-008 — Agent output discipline and transcript trace tooling

- **Status:** done
- **Intent:** Agents narrated step-by-step in chat, drowning the signal at a
  glance. Chat output is now restricted to results, load-bearing reasoning,
  and questions-with-context (Communication block in every agent preamble,
  anti-narration line in every command); the full thought process stays
  accessible for meta-analysis via `scripts/harness-trace.sh`, which lists a
  target repo's loop sessions and agent runs and renders any transcript —
  thinking, tool calls, truncated results (`--full` for untruncated).
- **Acceptance:**
  - [x] `trace renders thinking, tool calls, results, and final text from a transcript`
  - [x] `trace list mode fails informatively outside a repo with transcripts`
- **Constraints:** Dev-time tool (python3 fine — invariant 3 binds guards
  only). Prompt-side discipline is a tuning knob, deliberately untested.
- **Depends on:** —
- **Out of scope:** Token accounting in the trace; cross-repo search.
- **Notes:** Done 2026-08-26 by the overseer at Julio's direction.

---

## Reconciliation log

The reviewer appends one line here whenever the repository disagreed with this
document. This is the record that tells you whether your bookkeeping is
drifting, and it is the first thing to read if the harness starts producing
bad tasks.

| Date | Item | Roadmap said | Repository showed | Resolution |
|---|---|---|---|---|
| 2026-08-26 | R-007 | (no entry) | 4 tests tagged @harness:R-007, passing | Entry restored; insert had failed silently (unasserted replace) |
| | | | | |
