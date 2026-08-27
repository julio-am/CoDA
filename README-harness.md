> **Superseded 2026-08-26.** This document is the original design rationale
> for the copy-into-repo model. DevAgent now loads as a Claude Code plugin
> pointed at target repos (`scripts/harness-init.sh`); enforcement is
> session-wide hooks keyed on the hook input's `agent_type`. See CLAUDE.md.
> Kept as design provenance.

# Coding harness

A four-stage loop for agent-assisted development, with two human gates.

```
  /next     surveyor      repo + roadmap  ->  one task packet
              |
  /plan     architect     packet + code   ->  plan
            plan-critic   packet + plan   ->  findings        [HUMAN GATE]
              |
  /build    implementer   plan            ->  code + tests on task/<ID>
              |
  /review   reviewer      packet + diff   ->  verdict + doc reconciliation
              |                                               [HUMAN GATE]
  /land     you           merge, archive state
```

## The three ideas it is built on

**Tests decide what is done.** The roadmap records intent, the code records
what exists, and only a passing test tagged `@harness:R-NNN` makes an item
done. Status is derived by running a command, not by a model forming an
impression of the code. This is what stops project bookkeeping from drifting.

**Pointers, not paraphrase.** The task packet carries file paths, line ranges,
and verbatim interface excerpts. Downstream agents re-read the real files.
Summarising an interface into prose and then implementing against the prose is
how features go missing.

**One writer per artifact.** Enforced by a `PreToolUse` hook rather than
requested in a prompt. The implementer cannot touch the roadmap; the reviewer
cannot touch source. When two agents can write the same file, one of them
silently loses.

## Layout

```
CLAUDE.md                       conventions; loaded into every subagent
docs/roadmap.md                 intent, with IDs and acceptance criteria
.claude/agents/*.md             the five agent definitions
.claude/commands/*.md           /next /plan /build /review /land
.claude/settings.json           permission denies
.harness/config.env             test commands the scripts use
.harness/state/                 live loop state, one owner per file
.harness/templates/             the shape of each state file
.harness/logs/<ID>-<date>/      archived state, written by /land
scripts/harness-status.sh       mechanical status for the surveyor
scripts/verify-new-tests.sh     anti-tautology check for the reviewer
scripts/guard-write-paths.sh    write-scope enforcement hook
scripts/guard-git-push.sh       push policy enforcement hook
HANDOFF.md                      installation instructions for Claude Code
```

## Models

| Stage | Model | Why |
|---|---|---|
| surveyor | opus | reconciliation judgment; the status itself is script-derived |
| architect | opus | design judgment |
| plan-critic | opus | adversarial detection — finding what is absent |
| implementer | sonnet | execution against a spec |
| reviewer | opus | adversarial detection, and the last check before merge |

If one stage ever justifies a stronger model, it is `plan-critic` or
`reviewer` — absence is harder to spot than error, and a miss there propagates
into merged code. The surveyor is the weakest candidate despite being first:
`harness-status.sh` does its actual status derivation.

## Push policy

Only the reviewer pushes, only a `task/*` branch, only after an Accept verdict.
Blocked for everyone: the default branch, `--force`, `--delete`, `--mirror`,
`--tags`, and any refspec other than the current branch.

`Bash(git push:*)` is deliberately absent from `permissions.allow`, so every
push also raises a permission prompt naming the subagent. Every attempt is
logged to `.harness/logs/git-push.log`. The default branch is pushed by hand.

## Budgets

These are the numbers that keep the loop's failure rate down. Change them
deliberately, in the agent files, not case by case.

| Budget | Value | Where |
|---|---|---|
| Task size | 400 lines / 5 files / 5 tests | `surveyor.md` |
| Open questions in a plan | 3, each with a default | `architect.md` |
| Minimum critic findings | 3, or name what you checked | `plan-critic.md` |
| Implementer attempts at green | 6, then write blockers | `implementer.md` |
| Rejections before re-planning | 2nd rejection goes to stage 2 | `reviewer.md` |
| Subagent nesting depth | 1 | `.claude/settings.json` |

## Measuring the harness

`/land` archives each loop's state under `.harness/logs/`. Four numbers are
worth tracking across a dozen tasks:

- **rejection rate** — reviewer rejections per task
- **rework rate** — tasks reopened after being accepted
- **interventions per task** — how often you had to step in beyond the two gates
- **budget breaches** — tasks that blew the size budget

Rising rejection rate usually means the packets are getting vaguer. Rising
rework rate means the reviewer is rubber-stamping. Both are prompt problems,
and both are invisible without the log.

## Caveats worth knowing

- **The `/build` gate is real.** `/build` is marked `disable-model-invocation`,
  so only you can trigger it. Do not remove that.
- **Subagents do not see your conversation.** Each starts with its own context:
  its system prompt, the delegation message, and the `CLAUDE.md` hierarchy.
  Anything an agent needs must be in a file, not in the chat above it.
- **`verify-new-tests.sh` needs `HARNESS_TEST_ONE_CMD`** to tell you *which*
  test is tautological. Without it you get a yes/no for the whole suite.
- **The guard fails closed.** If it cannot parse the hook input, it blocks.
- **Project-level frontmatter hooks require trusting the folder** when you
  first open the repo in Claude Code. Until you do, the guard silently does not
  run — verify it works before relying on it.
