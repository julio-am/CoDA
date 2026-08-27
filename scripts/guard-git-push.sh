#!/usr/bin/env bash
# guard-git-push.sh
#
# PreToolUse hook on Bash, wired session-wide by the plugin's hooks/hooks.json.
# Only the reviewer role may push, and only a task branch. Every push attempt
# in the session — human, harness agent, or any other agent — is logged to
# .harness/logs/git-push.log so nothing reaches a remote unnoticed.
#
# The acting agent is identified from the hook input's agent_type field.
# No agent_type means the human's own session: allowed, and still logged.
#
# Exit 2 blocks the command and returns the message to the agent.
set -uo pipefail

INPUT="$(cat)"
LOG=".harness/logs/git-push.log"

extract() { # extract <field>  (field is a top-level string, or tool_input.command)
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r --arg f "$1" \
      'if $f == "command" then (.tool_input.command // empty) else (.[$f] // empty) end'
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$INPUT" | python3 -c 'import sys,json
try:
    d = json.load(sys.stdin)
    f = sys.argv[1]
    if f == "command":
        print((d.get("tool_input") or {}).get("command") or "")
    else:
        print(d.get(f) or "")
except Exception:
    sys.exit(3)' "$1"
  else
    printf '%s' "$INPUT" | grep -q '"hook_event_name"' || return 3
    printf '%s' "$INPUT" | sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
  fi
}

CMD="$(extract command)" || {
  echo "guard-git-push.sh: could not parse hook input; blocking to fail closed" >&2
  exit 2
}
[ -z "$CMD" ] && exit 0

# Not a push? Nothing to guard. Matches `git push` at a command boundary so a
# chained `foo && git push` is caught too.
printf '%s' "$CMD" | grep -Eq '(^|[;&|(]|[[:space:]])git[[:space:]]+push\b' || exit 0

AGENT_TYPE="$(extract agent_type)" || {
  echo "guard-git-push.sh: could not parse hook input; blocking to fail closed" >&2
  exit 2
}
case "$AGENT_TYPE" in
  "")          ROLE="human" ;;
  devagent:*)  ROLE="${AGENT_TYPE#devagent:}" ;;
  *)           ROLE="$AGENT_TYPE" ;;
esac

# head -1 guarantees a single-line field even on an unborn branch, where
# rev-parse prints HEAD to stdout AND fails (so `|| echo` would append a
# second line and wrap the tab-separated log record).
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null | head -1)"
[ -n "$BRANCH" ] || BRANCH=unknown
# shellcheck disable=SC1091  # target-repo config, resolved at runtime
[ -f .harness/config.env ] && . .harness/config.env 2>/dev/null
BASE="${HARNESS_BASE_BRANCH:-main}"

log() {
  mkdir -p "$(dirname "$LOG")" 2>/dev/null
  printf '%s\t%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$ROLE" "$BRANCH" "$1" "$CMD" >> "$LOG"
}

deny() { log "BLOCKED:$1"; printf '%s\n' "$2" >&2; exit 2; }

# The human's own session pushes at will — logged, never blocked here.
# (Claude Code's own permission prompt still applies to the session.)
if [ "$ROLE" = "human" ]; then
  log "ALLOWED:human"
  exit 0
fi

# Agents outside the devagent namespace are not harness roles, but "no push
# from any agent except the reviewer" is the policy for the whole session.
if [ "$ROLE" != "reviewer" ]; then
  deny "role" "Blocked: the '$ROLE' agent may not push to a remote.

Only the devagent reviewer pushes, and only the task branch, after it has
written its verdict. Every other agent's work stays local until then.

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
