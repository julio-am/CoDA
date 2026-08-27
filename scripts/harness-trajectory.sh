#!/usr/bin/env bash
# harness-trajectory.sh [N]
#
# Derive the outer loop's steering numbers from what the loop already
# records: the event log, the backlog's git history, and (when readable)
# the session transcripts for human-intervention counts. Prints rates,
# tripwire verdicts, and a suggested autonomy level. Mechanical only —
# nothing here is a model's impression. Run from the target repo.
set -euo pipefail

WINDOW="${1:-5}"
LOG=".harness/logs/loop-events.log"
# shellcheck disable=SC1091
[ -f .harness/config.env ] && . .harness/config.env
ROADMAP="${HARNESS_ROADMAP:-docs/roadmap.md}"

[ -f "$LOG" ] || { echo "no $LOG yet — the loop has not recorded events"; exit 0; }

python3 - "$LOG" "$WINDOW" "$ROADMAP" <<'PYEOF'
import sys, os, glob, json, subprocess, re, collections

log, window, roadmap = sys.argv[1], int(sys.argv[2]), sys.argv[3]
events = []
for line in open(log):
    parts = line.rstrip("\n").split("\t")
    if len(parts) >= 3:
        events.append((parts[0], parts[1], parts[2], parts[3] if len(parts) > 3 else ""))

landed = [e for e in events if e[2] == "land-pushed"]
tasks = collections.OrderedDict()
for ts, task, ev, detail in events:
    if task != "-":
        tasks.setdefault(task, []).append((ts, ev, detail))

print("== EVENTS ======================================================")
for task, evs in tasks.items():
    summary = " → ".join(e for _, e, _ in evs)
    print(f"  {task}: {summary}")

recent = list(tasks.items())[-window:]
n = len(recent)
rejects = sum(1 for _, evs in recent for _, e, d in evs if e == "review-verdict" and "reject" in d.lower())
accepts = sum(1 for _, evs in recent for _, e, d in evs if e == "review-verdict" and "accept" in d.lower())
blocked = sum(1 for _, evs in recent for _, e, _ in evs if e == "build-blocked")
rework  = sum(1 for t, evs in recent
              if any(e == "land-pushed" for _, e, _ in evs)
              and [e for _, e, _ in evs][-1] != "land-pushed"
              for _ in [0])
gate_fail = sum(1 for _, evs in recent for _, e, _ in evs if e == "land-gate-failed")

print(f"\n== RATES (last {n} task(s)) ====================================")
print(f"  landed: {sum(1 for _, evs in recent for _, e, _ in evs if e == 'land-pushed')}")
print(f"  review rejections: {rejects}  accepts: {accepts}")
print(f"  build blockers hit: {blocked}   land gates failed: {gate_fail}")
print(f"  reopened after landing (rework): {rework}")

# Defect inflow vs burn: new '## R-' headings added to the roadmap in git
# history since the window's first event vs tasks landed in the window.
inflow = "n/a"
try:
    since = recent[0][1][0][0] if recent else None
    if since:
        out = subprocess.run(["git", "log", f"--since={since}", "-p", "--", roadmap],
                             capture_output=True, text=True, timeout=30).stdout
        inflow = sum(1 for l in out.splitlines() if re.match(r"^\+## R-[0-9]+", l))
except Exception:
    pass
landed_n = sum(1 for _, evs in recent for _, e, _ in evs if e == "land-pushed")
print(f"  backlog inflow (new items since window start): {inflow}")

# Interventions: user messages in this repo's loop sessions that are neither
# command invocations nor bare approvals. Heuristic, transcript-derived.
APPROVE = re.compile(r"^(y|yes|ok|okay|go|go ahead|proceed|approved?|accept(ed)?|defaults are fine|push it( please)?|lgtm|ship it|done)[.!]*$", re.I)
slug = os.getcwd().replace("/", "-")
store = os.path.join(os.environ.get("CLAUDE_CONFIG_DIR", os.path.expanduser("~/.claude")), "projects", slug)
interventions = "n/a (no transcript store)"
if os.path.isdir(store) and recent:
    since_ts = recent[0][1][0][0]
    count = 0; sessions = 0
    for f in glob.glob(os.path.join(store, "*.jsonl")):
        try:
            body = open(f, errors="replace").read()
            if "devagent" not in body: continue
            sessions += 1
            for line in body.splitlines():
                try: d = json.loads(line)
                except Exception: continue
                if d.get("type") != "user" or (d.get("timestamp") or "") < since_ts: continue
                m = d.get("message") or {}
                if m.get("role") != "user": continue
                c = m.get("content")
                txt = c if isinstance(c, str) else " ".join(b.get("text", "") for b in c if isinstance(b, dict) and b.get("type") == "text")
                txt = txt.strip()
                if not txt or txt.startswith("<command-message>") or "<command-name>" in txt: continue
                if "tool_result" in str(c)[:80]: continue
                if APPROVE.match(txt): continue
                count += 1
        except Exception:
            continue
    interventions = f"{count} across {sessions} loop session(s)"
print(f"  human interventions (non-approval messages): {interventions}")

print("\n== TRIPWIRES ===================================================")
fired = []
if rejects >= 2: fired.append(f"{rejects} rejections in window — packets or plans degrading")
if isinstance(inflow, int) and landed_n and inflow > 2 * landed_n:
    fired.append(f"backlog inflow {inflow} > 2x landed {landed_n} — churn; milestone may be mis-scoped")
if rework: fired.append(f"{rework} task(s) reopened after landing — reviewer rubber-stamping")
if gate_fail: fired.append(f"{gate_fail} land gate failure(s)")
if fired:
    for t in fired: print(f"  FIRED: {t}")
    print("  → run /chart before the next /next")
else:
    print("  none fired")

print("\n== AUTONOMY ====================================================")
iv = 0 if isinstance(interventions, str) and interventions.startswith("0 ") else 1
clean = (rejects == 0 and rework == 0 and gate_fail == 0 and not fired)
if n < 3:
    lvl, why = 0, f"only {n} task(s) of history — not enough evidence"
elif clean and iv == 0:
    lvl, why = 2, f"{n} clean tasks, zero interventions — gates could auto-pass on clean verdicts"
elif clean:
    lvl, why = 1, "clean verdicts but human interventions occurred — plan gate stays"
else:
    lvl, why = 0, "tripwires or rejections in window"
print(f"  suggested level: {lvl}  ({why})")
print("  0 = both gates human · 1 = review gate auto on clean Accept ·")
print("  2 = both gates auto when mechanical conditions hold · ceiling is yours")
PYEOF
