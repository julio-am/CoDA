#!/usr/bin/env bash
# guard-git-push.sh <role>
#
# PreToolUse hook on Bash. Only the reviewer may push, and only a task branch.
# Every push attempt — allowed or blocked — is logged to
# .harness/logs/git-push.log so nothing reaches a remote unnoticed.
#
# Exit 2 blocks the command and returns the message to the agent.
# Exit 0 allows it; Claude Code still raises its own permission prompt because
# `Bash(git push:*)` is deliberately absent from permissions.allow.
set -uo pipefail

ROLE="${1:-unknown}"
INPUT="$(cat)"
LOG=".harness/logs/git-push.log"

extract_cmd() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r '.tool_input.command // empty'
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$INPUT" | python3 -c 'import sys,json
try:
    print((json.load(sys.stdin).get("tool_input") or {}).get("command") or "")
except Exception:
    sys.exit(3)'
  else
    printf '%s' "$INPUT" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
  fi
}

CMD="$(extract_cmd)"; RC=$?
if [ $RC -ne 0 ]; then
  echo "guard-git-push.sh: could not parse hook input; blocking to fail closed" >&2
  exit 2
fi
[ -z "$CMD" ] && exit 0

# Not a push? Nothing to guard. Matches `git push` at a command boundary so a
# chained `foo && git push` is caught too.
printf '%s' "$CMD" | grep -Eq '(^|[;&|(]|[[:space:]])git[[:space:]]+push\b' || exit 0

# head -1 guarantees a single-line field even on an unborn branch, where
# rev-parse prints HEAD to stdout AND fails (so `|| echo` would append a
# second line and wrap the tab-separated log record).
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null | head -1)"
[ -n "$BRANCH" ] || BRANCH=unknown
BASE="${HARNESS_BASE_BRANCH:-main}"
# shellcheck disable=SC1091  # target-repo config, resolved at runtime
[ -f .harness/config.env ] && . .harness/config.env 2>/dev/null
BASE="${HARNESS_BASE_BRANCH:-main}"

log() {
  mkdir -p "$(dirname "$LOG")" 2>/dev/null
  printf '%s\t%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$ROLE" "$BRANCH" "$1" "$CMD" >> "$LOG"
}

deny() { log "BLOCKED:$1"; printf '%s\n' "$2" >&2; exit 2; }

if [ "$ROLE" != "reviewer" ]; then
  deny "role" "Blocked: the '$ROLE' agent may not push to a remote.

Only the reviewer pushes, and only the task branch, after it has written its
verdict. Every other stage's work stays local until then.

Attempted: $CMD
Logged to: $LOG"
fi

# Reviewer, but still narrowly scoped.
case "$CMD" in
  *--force*|*" -f"*|*--mirror*|*--delete*|*--prune*|*--tags*)
    deny "flags" "Blocked: force, delete, mirror, prune, and tag pushes are never permitted.

Attempted: $CMD
Logged to: $LOG" ;;
esac

case "$BRANCH" in
  task/*) : ;;
  *) deny "branch" "Blocked: pushes are only permitted from a task branch.

Current branch is '$BRANCH'. The default branch ('$BASE') is pushed by the
human after /land, never by an agent.

Attempted: $CMD
Logged to: $LOG" ;;
esac

# Reject an explicit refspec that names anything other than the current branch.
REFS="$(printf '%s' "$CMD" | sed -E 's/.*git[[:space:]]+push[[:space:]]*//' \
        | tr ' ' '\n' | grep -vE '^(-|origin$|upstream$|--set-upstream$|-u$|$)')"
if [ -n "$REFS" ]; then
  while IFS= read -r r; do
    [ -z "$r" ] && continue
    if [ "$r" != "$BRANCH" ] && [ "$r" != "HEAD" ]; then
      deny "refspec" "Blocked: refspec '$r' is not the current task branch ('$BRANCH').

Attempted: $CMD
Logged to: $LOG"
    fi
  done <<< "$REFS"
fi

log "ALLOWED"
echo "git push allowed for reviewer on '$BRANCH' — logged to $LOG"
exit 0
