#!/usr/bin/env bash
# harness-trace.sh [--full] [session-or-agent-id-prefix | transcript.jsonl]
#
# Deterministic access to the loop's recorded thinking. Agents are told not
# to narrate in chat because everything is on disk; this is the reader.
#
#   harness-trace.sh              list this repo's sessions and agent runs
#   harness-trace.sh a48e4        render the matching agent transcript
#   harness-trace.sh --full a48e4 ...with untruncated tool results
#   harness-trace.sh file.jsonl   render an explicit transcript file
#
# Dev-time tool: requires python3. Reads Claude Code's transcript store at
# ~/.claude/projects/<slug-of-cwd>/. Run it from the target repo.
set -euo pipefail

FULL=0
[ "${1:-}" = "--full" ] && { FULL=1; shift; }
ARG="${1:-}"

SLUG="$(pwd | tr '/' '-')"
ROOT="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/$SLUG"

python3 - "$ROOT" "$ARG" "$FULL" <<'PYEOF'
import json, os, sys, glob, datetime

root, arg, full = sys.argv[1], sys.argv[2], sys.argv[3] == "1"

def mtime(p): return datetime.datetime.fromtimestamp(os.path.getmtime(p))

def render(path):
    print(f"### {path}\n")
    for line in open(path):
        try: d = json.loads(line)
        except Exception: continue
        m = d.get("message") or {}
        c = m.get("content")
        if d.get("type") == "assistant" and isinstance(c, list):
            for b in c:
                t = b.get("type")
                if t == "thinking":
                    print("┌─ thinking")
                    for ln in (b.get("thinking") or "").splitlines(): print(f"│ {ln}")
                    print("└─")
                elif t == "text" and b.get("text","").strip():
                    print(f"\n■ SAYS: {b['text'].strip()}\n")
                elif t == "tool_use":
                    inp = b.get("input") or {}
                    key = inp.get("command") or inp.get("file_path") or inp.get("prompt") or json.dumps(inp)
                    key = " ".join(str(key).split())
                    print(f"→ {b.get('name','?')}: {key if full else key[:160]}")
        elif d.get("type") == "user" and isinstance(c, list):
            for b in c:
                if isinstance(b, dict) and b.get("type") == "tool_result":
                    rc = b.get("content")
                    txt = rc if isinstance(rc, str) else " ".join(x.get("text","") for x in (rc or []) if isinstance(x, dict))
                    txt = txt.strip()
                    flag = " [ERROR]" if b.get("is_error") else ""
                    if full:
                        print(f"←{flag} {txt}")
                    else:
                        print(f"←{flag} {' '.join(txt.split())[:300]}{' …(%d chars)' % len(txt) if len(txt) > 300 else ''}")

if arg and os.path.isfile(arg):
    render(arg); sys.exit(0)

if not os.path.isdir(root):
    print(f"no transcript store at {root} — run from the target repo", file=sys.stderr); sys.exit(1)

sessions = sorted(glob.glob(os.path.join(root, "*.jsonl")), key=os.path.getmtime, reverse=True)

if not arg:
    for s in sessions[:8]:
        sid = os.path.basename(s)[:-6]
        print(f"{mtime(s):%m-%d %H:%M}  session {sid[:8]}  ({os.path.getsize(s)//1024}KB)")
        for a in sorted(glob.glob(os.path.join(root, sid, "subagents", "agent-*.jsonl")), key=os.path.getmtime):
            meta = {}
            mp = a[:-6] + ".meta.json"
            if os.path.exists(mp):
                try: meta = json.load(open(mp))
                except Exception: pass
            aid = os.path.basename(a)[6:-6]
            print(f"    {mtime(a):%H:%M}  {aid[:12]}  {meta.get('agentType','?'):28s} {os.path.getsize(a)//1024}KB  — {meta.get('description','')}")
    sys.exit(0)

# prefix match against session ids and agent ids, newest first
for s in sessions:
    sid = os.path.basename(s)[:-6]
    if sid.startswith(arg): render(s); sys.exit(0)
    for a in glob.glob(os.path.join(root, sid, "subagents", "agent-*.jsonl")):
        if os.path.basename(a)[6:-6].startswith(arg): render(a); sys.exit(0)
print(f"nothing matching '{arg}'", file=sys.stderr); sys.exit(1)
PYEOF
