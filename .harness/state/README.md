# Loop state

Live state for the current task. One writer per file — see the ownership
table in `CLAUDE.md`.

| File | Written by | Stage |
|---|---|---|
| `current-task.md` | surveyor | 1 |
| `plan.md` | architect | 2 |
| `plan-critique.md` | plan-critic | 2 |
| `review.md` | reviewer | 4 |
| `blockers.md` | whichever agent is blocked | any |

`/land` archives these to `.harness/logs/<ID>-<date>/` and resets them from
`.harness/templates/`.
