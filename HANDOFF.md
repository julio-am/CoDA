# Handoff — coding harness installation

**Read this first, then `README-harness.md` for the design rationale.**

You are installing a four-stage agent harness into this repository. It is
already written; nothing here needs to be designed. Your job is to install it,
fill in the project-specific gaps, verify the enforcement actually fires, and
run one loop end to end.

Julio is an experienced C++/distributed-systems engineer. Do not explain what
git or subagents are. Do surface anything that looks wrong.

---

## What the harness is

```
  /next     surveyor      repo + roadmap  ->  one task packet
              |
  /plan     architect     packet + code   ->  plan
            plan-critic   packet + plan   ->  findings        [HUMAN GATE 1]
              |
  /build    implementer   plan            ->  code + tests on task/<ID>
              |
  /review   reviewer      packet + diff   ->  verdict, docs, push task branch
              |                                               [HUMAN GATE 2]
  /land     human-run     merge, archive state
```

Three load-bearing ideas. Preserve all three:

1. **Tests decide what is done.** The roadmap holds intent, the code holds what
   exists, a passing test tagged `@harness:R-NNN` is the only thing that makes
   an item done. Status is derived by running a command, never by a model
   forming an impression from reading source.
2. **Pointers, not paraphrase.** The task packet carries paths, line ranges,
   and verbatim interface excerpts. Downstream agents re-read the real files. A
   packet that summarises a signature into prose has already lost the
   information the implementer needs.
3. **One writer per artifact.** Enforced by a `PreToolUse` hook, not requested
   in a prompt. The implementer cannot touch the roadmap; the reviewer cannot
   touch source.

---

## Inventory

| Path | What |
|---|---|
| `CLAUDE.md` | Conventions. Loaded into every subagent automatically. **Has TODOs.** |
| `docs/roadmap.md` | Intent, with IDs and test-backed acceptance. **Has a placeholder item.** |
| `.claude/agents/*.md` | surveyor, architect, plan-critic, implementer, reviewer |
| `.claude/commands/*.md` | `/next` `/plan` `/build` `/review` `/land` |
| `.claude/settings.json` | Permission denies, subagent nesting cap |
| `.harness/config.env` | Test commands the scripts read. **Has TODOs.** |
| `.harness/state/` | Live loop state, one owner per file |
| `.harness/templates/` | Shape of each state file |
| `.harness/logs/` | Archived loops, plus `git-push.log` |
| `scripts/harness-status.sh` | Mechanical status for the surveyor |
| `scripts/verify-new-tests.sh` | Anti-tautology check for the reviewer |
| `scripts/guard-write-paths.sh` | Write-scope enforcement |
| `scripts/guard-git-push.sh` | Push policy enforcement |

---

## Step 1 — Install

If the harness is not yet in the repo, run `./INSTALL.sh /path/to/repo` from
the unzipped directory. It refuses to overwrite anything and reports collisions
instead.

If the repo already has a `CLAUDE.md`, **do not replace it.** Merge in two
sections by hand: the command table and "Hard rules for every agent". Ask
before touching anything else in it.

```bash
chmod +x scripts/*.sh
```

---

## Step 2 — Fill in the project-specific gaps

This is the only part that needs real input, and it is the part that determines
whether the harness works at all. **Ask Julio rather than guessing.** A wrong
test command silently produces a surveyor that reports "status unknown" and a
reviewer whose test audit cannot run.

### 2a. `CLAUDE.md` command table

Fill every row. Agents run these commands literally; they do not improvise a
test runner.

```
| Build | ... |
| Test — full suite | ... |
| Test — single file | ... {file} |
| Test — by marker/name | ... {pattern} |
| Lint | ... |
| Typecheck / static analysis | ... |
| Format | ... |
```

If the full suite takes more than ~90 seconds, define a fast subset and add it
as a `Test — fast` row. The implementer's inner loop dies on a slow suite.

### 2b. `.harness/config.env`

Same commands, machine-readable. `HARNESS_TEST_CMD` is required.

**`HARNESS_TEST_ONE_CMD` matters more than it looks.** Without it,
`verify-new-tests.sh` can only report that *some* new test is tautological, not
which one — which makes the finding nearly unactionable. Set it. Examples for
common runners are in the file's comments.

### 2c. `CLAUDE.md` repository map, invariants, style

- Repository map: one line per top-level directory.
- Invariants: things that are true and must stay true. These are what the
  plan-critic checks plans against, so vague entries produce vague critiques.
  Be specific and concrete.
- Style: language version, formatter, naming, error-handling convention.

### 2d. `docs/roadmap.md`

Delete the `R-001` placeholder. Write real items. Each needs an ID, an intent
paragraph, named acceptance tests, and a filled-in **Out of scope** — that
last field prevents more rework than the rest combined.

If Julio has an existing roadmap in another format, **convert it, don't
replace it.** Preserve every item's original text; add IDs and acceptance
criteria around it. Flag any item you cannot write acceptance tests for — that
is usually a sign the item is underspecified, not that the format is wrong.

---

## Step 3 — Verify enforcement actually fires

Do not skip this. The guards are the difference between a harness and five
prompts that ask nicely.

**Accept the workspace trust prompt when you first open the repo.** Project
frontmatter hooks do not run until the folder is trusted, and until then the
guards silently do nothing. This is the single most likely way for the install
to look fine and be broken.

Run each of these and confirm the stated result:

```bash
# 1. Status runs clean and reports real test results.
./scripts/harness-status.sh
#    -> TESTS section shows an exit code, not "HARNESS_TEST_CMD is not set"
#    -> ROADMAP section lists your real IDs

# 2. Write guard blocks out-of-scope writes. Expect exit 2.
echo '{"tool_input":{"file_path":"docs/roadmap.md"}}' \
  | ./scripts/guard-write-paths.sh implementer; echo "exit=$?"   # want 2
echo '{"tool_input":{"file_path":"src/anything"}}' \
  | ./scripts/guard-write-paths.sh reviewer; echo "exit=$?"      # want 2
echo '{"tool_input":{"file_path":"src/anything"}}' \
  | ./scripts/guard-write-paths.sh implementer; echo "exit=$?"   # want 0

# 3. Push guard. Expect 2, 2, then 0 only on a task branch.
echo '{"tool_input":{"command":"git push"}}' \
  | ./scripts/guard-git-push.sh implementer; echo "exit=$?"      # want 2
echo '{"tool_input":{"command":"git push origin main"}}' \
  | ./scripts/guard-git-push.sh reviewer; echo "exit=$?"         # want 2
```

Adjust the `implementer` allow pattern in `scripts/guard-write-paths.sh` if
this repo's source directories are not `src|tests|test|lib|include|app`.

`verify-new-tests.sh` can only be tested against a real diff, so it gets
exercised in step 5.

---

## Step 4 — Confirm the agents loaded

In Claude Code, check that all five subagents are visible. If they are not,
restart — the directory watcher only covers directories that existed at session
start, and `.claude/agents/` is new.

Expected: `surveyor`, `architect`, `plan-critic`, `implementer`, `reviewer`.

Run `claude plugin validate .claude/agents` to catch frontmatter that fails to
parse. A file whose YAML is broken is skipped silently.

---

## Step 5 — First loop

Pick a **small, boring task Julio could do himself in an hour.** The point is
to test the harness, not to get work done. A task that is interesting will make
it hard to tell whether a bad result came from the harness or the problem.

Run `/next`, `/plan`, `/build`, `/review`, `/land` in order, stopping at each
gate. What to watch for, in priority order:

| Stage | Failure signal |
|---|---|
| `/next` | Packet paraphrases signatures instead of quoting them with `path:line` |
| `/next` | Reports no discrepancies on a repo that obviously has some |
| `/plan` | Open questions with no proposed defaults |
| `/plan` | Critic finds nothing and doesn't say what it checked |
| `/build` | Deviates from the plan without saying so in the handoff |
| `/review` | Verdicts without `path:line` or test-name evidence |
| `/review` | `verify-new-tests.sh` was not actually run |

Fix these in the agent prompt files, **one change at a time**, and re-run the
same task. Re-running one task after one prompt change is the only real eval
available here.

---

## Decisions already made — do not change without asking

| Decision | Why |
|---|---|
| Implementer on Sonnet, other four on Opus | Planning and review are the judgment-heavy stages; implementation is mostly execution against a spec |
| Subagent nesting capped at 1 | Keeps the loop sequential and debuggable. Easy to raise later in `settings.json` |
| Reviewer is read-only on `src/` and `tests/` | A reviewer that quietly fixes what it finds destroys the signal that the problem occurred |
| Reviewer does not see the implementer's handoff | An author's account of their own work is a rationalisation; reading it first is how reviewers agree with code they should reject |
| `/build` and `/land` are `disable-model-invocation` | Only Julio triggers the side-effectful stages |
| Task budget: 400 lines / 5 files / 5 tests | Oversized tasks are the root cause of vague plans and rubber-stamp reviews |
| Implementer stops after 6 attempts at green | Grinding past this usually means the plan was wrong; the fix is at stage 2 |
| 2nd rejection routes to stage 2, not stage 3 | Same reason |

---

## Push policy

Only the **reviewer** pushes, and only a `task/*` branch, and only after
writing an Accept verdict. Enforced by `scripts/guard-git-push.sh`, wired as a
`PreToolUse` Bash hook on all five agents.

Blocked for everyone including the reviewer: pushing the default branch,
`--force`, `--force-with-lease`, `--delete`, `--mirror`, `--prune`, `--tags`,
pushing from a non-task branch, and any refspec naming something other than the
current branch.

`Bash(git push:*)` is deliberately **absent from `permissions.allow`**, so every
push also raises a permission prompt in the main session naming the subagent
that asked. Do not add it to the allow list — the prompt is the notification.

Every attempt, allowed or blocked, appends a line to
`.harness/logs/git-push.log`. Check it after the first loop:

```bash
cat .harness/logs/git-push.log
```

The default branch is pushed by Julio, by hand, every time. `/land` merges
locally and stops.

---

## On Fable

Julio asked whether Fable belongs in the surveyor or plan stage. Two things
worth knowing before spending anything on it:

**The surveyor is the wrong place.** It is the most mechanically grounded stage
in the loop — `harness-status.sh` does the actual status derivation, and the
surveyor's job is largely transcription and reconciliation against script
output. Raising the model there buys little, because the work is not
reasoning-bound.

**If any stage justifies it, it is `plan-critic` or `reviewer`.** Both are
adversarial detection tasks: finding what is *absent* — the missing boundary
case, the test that would pass against unchanged code, the criterion nobody
mapped a test to. Absence is harder to spot than error, and those two stages
are also where a miss is most expensive, because it propagates into merged code
and reconciled docs.

**Recommendation: stay on Opus everywhere for now.** Get a dozen loops of data
first. If the reviewer turns out to be the weak link — rework rate climbing,
bugs landing that the review should have caught — that is the moment to try
`model: fable` on `reviewer.md` alone and compare. One line, one file:

```yaml
model: fable   # was: opus
```

Note that Fable requests on some topics are routed to Opus by safeguards, so
occasional stage runs will be Opus regardless.

---

## Open items to raise with Julio

- [ ] Which repository is this being installed into?
- [ ] Existing roadmap to convert, or start fresh?
- [ ] Confirm the build/test/lint commands rather than inferring them
- [ ] Does the source layout match the guard's `src|tests|test|lib|include|app`?
- [ ] Is `main` the default branch, or something else? (`HARNESS_BASE_BRANCH`)
- [ ] Which small task should the first loop use?

---

## After a dozen loops

`/land` archives each loop's state to `.harness/logs/<ID>-<date>/`. Four
numbers are worth pulling out of that history:

- **rejection rate** — reviewer rejections per task
- **rework rate** — tasks reopened after acceptance
- **interventions per task** — how often Julio stepped in outside the two gates
- **budget breaches** — tasks that blew the size budget

Rising rejection rate usually means packets are getting vaguer: fix the
surveyor. Rising rework rate means the reviewer is rubber-stamping: fix the
reviewer. Both are prompt problems, and both are invisible without the log.
