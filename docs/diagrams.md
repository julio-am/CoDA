# System diagrams

How the harness runs: the file-mediated inner loop, the north-star-steered
outer loop, and the promotion state machine that decides how much of it runs
without a human. Amber marks what only the human moves; green edges are
earned trust and sanctioned pushes; red edges are demotions and drift
interrupts.

## The inner loop — files are the interfaces

Every stage starts cold: its prompt, the state files, and the repository.
Nothing passes through conversation — packet, plan, critique, and review are
files with exactly one writer each, enforced by a session-wide hook that
identifies the acting agent from the tool call itself.

![Fig. A — The inner loop. Solid boxes act; dashed boxes are the single-writer state files they communicate through. The reviewer never sees the implementer's account of its own work — only the packet, plan, diff, and repository. Green edges are the only pushes that exist, and both are gated.](diagrams/inner-loop.svg)

Fig. A — The inner loop. Solid boxes act; dashed boxes are the single-writer state files they communicate through. The reviewer never sees the implementer's account of its own work — only the packet, plan, diff, and repository. Green edges are the only pushes that exist, and both are gated.

## The outer loop — steering against the north star

The inner loop lands tasks; the outer loop decides which tasks deserve to
exist. The anchor is `docs/northstar.md` in the target repo — human-owned and
hook-denied to every agent, so the loop cannot move the thing it is steered
by.

![Fig. B — The outer loop. Amber marks everything only a human may move: the north star, and the application of an approved chart proposal. Red edges are the drift interrupts — a fired tripwire routes to /chart, and /next refuses to survey until it is answered. Green closes the feedback: derived autonomy decides how much the cycle may do alone.](diagrams/outer-loop.svg)

Fig. B — The outer loop. Amber marks everything only a human may move: the north star, and the application of an approved chart proposal. Red edges are the drift interrupts — a fired tripwire routes to /chart, and /next refuses to survey until it is answered. Green closes the feedback: derived autonomy decides how much the cycle may do alone.

## Promotion — trust is derived, never stored

There is no autonomy variable anywhere in the system's state.
`harness-autonomy.sh` recomputes the level from the event log on every read,
and the human ceiling clamps it. Promotion is slow and evidence-backed;
demotion is a single bad event.

![Fig. C — The promotion state machine. Green edges are earned with evidence and move one level at a time; the red edges fire from any level on a single bad event. The amber ceiling is the human's standing order and always wins — the loop can never out-derive it.](diagrams/autonomy.svg)

Fig. C — The promotion state machine. Green edges are earned with evidence and move one level at a time; the red edges fire from any level on a single bad event. The amber ceiling is the human's standing order and always wins — the loop can never out-derive it.

## What the human touches, per level

| Level | Human touchpoints | The loop alone | Earned by |
|---|---|---|---|
| 0 | Approve each plan; accept each review; run /chart | Survey, plan+critique, build, review, gated land-push | — (start state) |
| 1 | Approve each plan; run /chart | + lands clean adjudicated Accepts without asking | ≥ 3 clean tasks in window |
| 2 | /chart milestone gates; tripwire responses | + proceeds past fully-CLEARED plan gates, task after task | + proven zero interventions |
| 3 | North-star edits; feature direction | Navigator translates direction into milestones | Sustained level 2 + a /chart record the human trusts |

Two invariants hold at every level: the four mechanical push gates at `/land`
never relax, and a fired tripwire stops the cycle no matter how much trust
has accrued — drift outranks momentum.
