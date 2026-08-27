# DevAgent

A four-stage development harness for Claude Code: five agents (surveyor,
architect, plan-critic, implementer, reviewer) plus an outer-loop navigator,
run in *target* repositories as a plugin. The engine stays here; each target
holds its own backlog, config, north star, and loop state.

**How it works:** [docs/diagrams.md](docs/diagrams.md) — the inner loop, the
outer loop, and the autonomy promotion machine, in three figures.

- `agents/` `commands/` `hooks/` — the plugin: stage prompts, slash
  commands, session-wide enforcement.
- `scripts/` — guards, status derivation, test audit, event log, trajectory,
  autonomy derivation, target init.
- `templates/` — state-file shapes and target scaffolds.
- `docs/roadmap.md` — this engine's own backlog.
- `CLAUDE.md` — conventions, invariants, the operating model.
- `HANDOFF.md`, `README-harness.md` — original design provenance
  (superseded notes at top).

Point it at a repo: `scripts/harness-init.sh /path/to/repo`, then open a
Claude Code session there and run `/next` — or `/cycle` to let earned
autonomy decide where it stops.
