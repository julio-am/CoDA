#!/usr/bin/env bash
# guard-write-paths.sh <role>
#
# PreToolUse hook. Enforces one-writer-per-artifact for the harness agents.
# Reads Claude Code's hook JSON on stdin, extracts the target path, and exits
# 2 to block a write outside the role's scope. Exit 2 blocks the tool call and
# feeds the stderr message back to the agent.
#
# Uses jq if available, else python3, else sed. Fails closed.
set -uo pipefail

ROLE="${1:-unknown}"
INPUT="$(cat)"

# Extract the target path. jq if present, python3 next, sed as a last resort.
extract_path() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty'
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$INPUT" | python3 -c 'import sys,json
try:
    d = json.load(sys.stdin).get("tool_input", {}) or {}
    print(d.get("file_path") or d.get("path") or "")
except Exception:
    sys.exit(3)'
  else
    printf '%s' "$INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\\([^"]*\\)".*/\\1/p' | head -1
  fi
}

PATH_ARG="$(extract_path)"
EXTRACT_RC=$?

if [ $EXTRACT_RC -ne 0 ]; then
  echo "guard-write-paths.sh: could not parse hook input; refusing to allow an unguarded write" >&2
  exit 2
fi

# No path in this tool call (e.g. a Write variant without one) — nothing to guard.
[ -z "$PATH_ARG" ] && exit 0

# Normalise to a repo-relative path.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
case "$PATH_ARG" in
  /*) REL="${PATH_ARG#"$REPO_ROOT"/}" ;;
  *)  REL="$PATH_ARG" ;;
esac

# Every role may always write its own blocker report.
ALWAYS='^\.harness/state/blockers\.md$'

case "$ROLE" in
  surveyor)    ALLOW='^\.harness/state/current-task\.md$' ;;
  architect)   ALLOW='^\.harness/state/plan\.md$' ;;
  plan-critic) ALLOW='^\.harness/state/plan-critique\.md$' ;;
  implementer) ALLOW='^(src|tests|test|lib|include|app)/' ;;
  reviewer)    ALLOW='^(docs/|\.harness/state/review\.md$)' ;;
  *)
    echo "guard-write-paths.sh: unknown role '$ROLE'. Blocking write to $REL." >&2
    exit 2
    ;;
esac

if printf '%s' "$REL" | grep -Eq "$ALWAYS"; then exit 0; fi
if printf '%s' "$REL" | grep -Eq "$ALLOW";  then exit 0; fi

cat >&2 <<MSG
Blocked: the '$ROLE' agent may not write to '$REL'.

This harness gives every artifact exactly one writer. Writing outside your
scope is how project state drifts, so the restriction is enforced rather than
requested.

Your write scope: $ALLOW (plus .harness/state/blockers.md)

If this task genuinely requires a change outside your scope, stop and report it
to the human instead of working around it.
MSG
exit 2
