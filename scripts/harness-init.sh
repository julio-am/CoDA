#!/usr/bin/env bash
# harness-init.sh /path/to/target-repo
#
# Point the DevAgent harness at a repository. Idempotent: existing files are
# never overwritten; each is reported as created or kept. The engine stays
# where it is — the target gets only its own config, state, backlog scaffold,
# and the two settings keys that load the plugin.
set -euo pipefail

TARGET="${1:?usage: harness-init.sh /path/to/target-repo}"
ENGINE="$(cd "$(dirname "$0")/.." && pwd)"

[ -d "$TARGET/.git" ] || { echo "error: $TARGET is not a git repository" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"
[ "$TARGET" = "$ENGINE" ] && { echo "error: refusing to point the engine at itself" >&2; exit 1; }

put() { # put <dest> <how>  — $how writes to stdout
  if [ -e "$1" ]; then echo "  kept    $1"; else
    mkdir -p "$(dirname "$1")"
    "$2" > "$1"
    echo "  created $1"
  fi
}

emit_config()   { sed "s|__ENGINE_ROOT__|$ENGINE|" "$ENGINE/templates/config.env"; }
emit_roadmap()  { cat "$ENGINE/templates/roadmap.md"; }
emit_gitignore(){ printf '*\n!.gitignore\n'; }
emit_state_readme() {
  cat <<'EOF'
# Loop state

Live state for the current task. One writer per file, enforced by the
engine's write guard: current-task.md (surveyor), plan.md (architect),
plan-critique.md (plan-critic), review.md (reviewer), blockers.md (whichever
agent is blocked). /land archives these to .harness/logs/<ID>-<date>/ and
resets them from the engine's templates/.
EOF
}
tmpl() { cat "$ENGINE/templates/$1"; }

echo "Pointing DevAgent at $TARGET"
put "$TARGET/.harness/config.env" emit_config
put "$TARGET/.harness/logs/.gitignore" emit_gitignore
put "$TARGET/.harness/state/README.md" emit_state_readme
for f in blockers current-task plan review; do
  eval "emit_$f() { tmpl $f.md; }"
  put "$TARGET/.harness/state/$f.md" "emit_$f"
done
emit_critique() { printf '# Plan critique\n\n(Written by the plan-critic each loop.)\n'; }
put "$TARGET/.harness/state/plan-critique.md" emit_critique

# Roadmap scaffold, at the configured location (or the default).
# shellcheck disable=SC1091  # the file we may have just written
. "$TARGET/.harness/config.env" 2>/dev/null || true
put "$TARGET/${HARNESS_ROADMAP:-docs/roadmap.md}" emit_roadmap

# Settings: additive deep-merge of the plugin pointer, permission floor, and
# nesting cap. Existing keys always win; we only fill gaps.
python3 - "$TARGET" "$ENGINE" <<'PYEOF'
import json, pathlib, sys, re
target, engine = sys.argv[1], sys.argv[2]
base = "main"
cfg = pathlib.Path(target) / ".harness" / "config.env"
if cfg.exists():
    m = re.search(r'^HARNESS_BASE_BRANCH="([^"]+)"', cfg.read_text(), re.M)
    if m: base = m.group(1)
p = pathlib.Path(target) / ".claude" / "settings.json"
existing = json.loads(p.read_text()) if p.exists() else {}

want = {
    "extraKnownMarketplaces": {
        "devagent-local": {"source": {"source": "directory", "path": engine}}
    },
    "enabledPlugins": {"devagent@devagent-local": True},
    "permissions": {
        "allow": [
            f"Bash({engine}/scripts/harness-status.sh)",
            f"Bash({engine}/scripts/verify-new-tests.sh:*)",
            f"Bash({engine}/scripts/harness-land-state.sh:*)",
            f"Bash(git push origin {base}:*)",
            "Bash(git status:*)", "Bash(git diff:*)", "Bash(git log:*)",
            "Bash(git show:*)", "Bash(git branch:*)", "Bash(git merge-base:*)",
            "Bash(git worktree:*)",
        ],
        "deny": [
            "Bash(git reset --hard:*)", "Bash(git checkout .:*)",
            "Bash(git clean:*)", "Bash(git rebase:*)",
            "Bash(git commit --amend:*)", "Bash(rm -rf:*)",
        ],
    },
    "env": {"CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH": "1"},
}

added = []
def merge(dst, src, path=""):
    for k, v in src.items():
        here = f"{path}.{k}" if path else k
        if k not in dst:
            dst[k] = v
            added.append(here)
        elif isinstance(dst[k], dict) and isinstance(v, dict):
            merge(dst[k], v, here)
        elif isinstance(dst[k], list) and isinstance(v, list):
            for item in v:
                if item not in dst[k]:
                    dst[k].append(item)
                    added.append(f"{here}[{item}]")
        # scalar conflict: theirs wins, silently — never fight the repo

merge(existing, want)
p.parent.mkdir(parents=True, exist_ok=True)
p.write_text(json.dumps(existing, indent=2) + "\n")
print(f"  merged  {p} (+{len(added)} entries)" if added else f"  kept    {p} (nothing to add)")
PYEOF

cat <<EOF

Next steps:
  1. Fill the TODOs in $TARGET/.harness/config.env
     (test commands, HARNESS_IMPLEMENTER_SCOPE — the guard fails closed
     without the scope).
  2. Put real items in $TARGET/${HARNESS_ROADMAP:-docs/roadmap.md}.
  3. Make sure this repo's CLAUDE.md command table states the same commands.
  4. Open a NEW Claude Code session in $TARGET, accept the trust and
     marketplace prompts, and run /next.
EOF
