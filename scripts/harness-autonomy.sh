#!/usr/bin/env bash
# harness-autonomy.sh [window]
#
# Derive the loop's effective autonomy level. Never stored, always derived:
# the loop cannot remember its way into unearned trust.
#
#   level 0  both gates human
#   level 1  review gate may auto-land on a clean Accept
#   level 2  plan gate may also auto-pass on a fully CLEARED re-check
#
# derived level comes from the event log; effective = min(derived, ceiling).
# Ceiling is the human's (HARNESS_AUTONOMY_CEILING in config, default 0).
# Promotion needs >=3 tasks of clean history; level 2 additionally needs
# PROOF of zero human interventions (unknown counts against promotion).
# Any rejection, rework, blocked build, or land-gate failure in the window
# derives 0 — demotion is instant and cheaper than promotion, by design.
#
# stdout line 1: "level=N derived=M ceiling=C" — parse that; the rest is why.
set -euo pipefail

WINDOW="${1:-5}"
LOG=".harness/logs/loop-events.log"
# shellcheck disable=SC1091
[ -f .harness/config.env ] && . .harness/config.env
CEILING="${HARNESS_AUTONOMY_CEILING:-0}"

if [ ! -f "$LOG" ]; then
  echo "level=0 derived=0 ceiling=$CEILING"
  echo "no event log — no history, no trust"
  exit 0
fi

python3 - "$LOG" "$WINDOW" "$CEILING" <<'PYEOF'
import sys, os, glob, json, re, collections

log, window, ceiling = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
tasks = collections.OrderedDict()
for line in open(log):
    p = line.rstrip("\n").split("\t")
    if len(p) >= 3 and p[1] != "-":
        tasks.setdefault(p[1], []).append((p[0], p[2], p[3] if len(p) > 3 else ""))

recent = list(tasks.items())[-window:]
n = len(recent)
bad = []
for t, evs in recent:
    for _, e, d in evs:
        if e == "review-verdict" and "reject" in d.lower(): bad.append(f"{t}: rejection")
        if e in ("build-blocked", "land-gate-failed"): bad.append(f"{t}: {e}")
    names = [e for _, e, _ in evs]
    if "land-pushed" in names and names[-1] != "land-pushed":
        bad.append(f"{t}: reopened after landing")

# interventions: provable zero required for level 2
APPROVE = re.compile(r"^(y|yes|ok|okay|go|go ahead|proceed|approved?|accept(ed)?|defaults are fine|push it( please)?|lgtm|ship it|done)[.!]*$", re.I)
iv = None
store = os.path.join(os.environ.get("CLAUDE_CONFIG_DIR", os.path.expanduser("~/.claude")),
                     "projects", os.getcwd().replace("/", "-"))
if os.path.isdir(store) and recent:
    since = recent[0][1][0][0]
    iv = 0
    for f in glob.glob(os.path.join(store, "*.jsonl")):
        try:
            body = open(f, errors="replace").read()
            if "devagent" not in body: continue
            for line in body.splitlines():
                try: d = json.loads(line)
                except Exception: continue
                if d.get("type") != "user" or (d.get("timestamp") or "") < since: continue
                m = d.get("message") or {}
                if m.get("role") != "user": continue
                c = m.get("content")
                txt = c if isinstance(c, str) else " ".join(b.get("text","") for b in c if isinstance(b, dict) and b.get("type") == "text")
                txt = txt.strip()
                if not txt or txt.startswith("<command-message>") or "<command-name>" in txt: continue
                if "tool_result" in str(c)[:80]: continue
                if not APPROVE.match(txt): iv += 1
        except Exception:
            iv = None; break

if n < 3:
    derived, why = 0, f"only {n} task(s) in window — promotion needs >=3"
elif bad:
    derived, why = 0, "; ".join(bad[:4])
elif iv == 0:
    derived, why = 2, f"{n} clean tasks, zero interventions (proven)"
else:
    derived, why = 1, f"{n} clean tasks; interventions " + ("unproven (no transcript store)" if iv is None else f"= {iv}")

level = min(derived, ceiling)
print(f"level={level} derived={derived} ceiling={ceiling}")
print(why)
if level < derived:
    print(f"ceiling holds the level at {level}; raise HARNESS_AUTONOMY_CEILING to use derived {derived}")
PYEOF
