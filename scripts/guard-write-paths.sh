#!/usr/bin/env bash
# guard-write-paths.sh
#
# PreToolUse hook on Write|Edit, wired session-wide by the plugin's
# hooks/hooks.json. Enforces one-writer-per-artifact for the harness agents.
#
# The acting agent is identified from the hook input's agent_type field —
# never from an argument, so an agent cannot invoke itself into a wider
# scope. Calls with no agent_type are the human's own session and pass.
# Calls from agents outside the devagent: namespace are not ours to police.
#
# Exit 0 allows, exit 2 blocks and feeds stderr back to the agent.
# Anything unparseable fails closed.
set -uo pipefail

INPUT="$(cat)"

# --- field extraction: jq, then python3, then sed ------------------------
extract() { # extract <field>
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r --arg f "$1" \
      'if $f == "file_path"
       then (.tool_input.file_path // .tool_input.path // empty)
       else (.[$f] // empty) end'
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$INPUT" | python3 -c 'import sys,json
try:
    d = json.load(sys.stdin)
    f = sys.argv[1]
    if f == "file_path":
        ti = d.get("tool_input") or {}
        print(ti.get("file_path") or ti.get("path") or "")
    else:
        print(d.get(f) or "")
except Exception:
    sys.exit(3)' "$1"
  else
    # Last resort. Only trustworthy if this even looks like hook JSON.
    printf '%s' "$INPUT" | grep -q '"hook_event_name"' || return 3
    printf '%s' "$INPUT" | sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
  fi
}

AGENT_TYPE="$(extract agent_type)" || {
  echo "guard-write-paths.sh: could not parse hook input; refusing to allow an unguarded write" >&2
  exit 2
}

# The human's own session, or another plugin's agent: not ours to guard.
[ -z "$AGENT_TYPE" ] && exit 0
case "$AGENT_TYPE" in
  devagent:*) ROLE="${AGENT_TYPE#devagent:}" ;;
  *) exit 0 ;;
esac

PATH_ARG="$(extract file_path)" || {
  echo "guard-write-paths.sh: could not parse hook input; refusing to allow an unguarded write" >&2
  exit 2
}

# Write|Edit always carry a target path; an empty extraction is a parse
# failure, and parse failures fail closed.
if [ -z "$PATH_ARG" ]; then
  echo "guard-write-paths.sh: no target path could be extracted from the hook input; refusing to allow an unguarded write" >&2
  exit 2
fi

# Normalise to a repo-relative path.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
case "$PATH_ARG" in
  /*) REL="${PATH_ARG#"$REPO_ROOT"/}" ;;
  *)  REL="$PATH_ARG" ;;
esac

# Session scratch areas are not repository artifacts. Probes and working
# files there are legitimate for every role — the one-writer rule guards the
# repo, not the sandbox. Anything else absolute and outside the repo stays
# blocked (that includes the engine checkout).
case "$REL" in
  /private/tmp/claude-[0-9]*/*|/tmp/claude-[0-9]*/*) exit 0 ;;
esac

# Per-repo scope configuration. When the hook fires, CWD is the repo being
# developed, so this reads the target repo's config — the engine stays
# generic, the repo says which directories are source.
# shellcheck disable=SC1091  # target-repo config, resolved at runtime
[ -f .harness/config.env ] && . .harness/config.env 2>/dev/null

# Every role may always write its own blocker report.
ALWAYS='^\.harness/state/blockers\.md$'
DENY=''

case "$ROLE" in
  surveyor)    ALLOW='^\.harness/state/current-task\.md$' ;;
  architect)   ALLOW='^\.harness/state/plan\.md$' ;;
  plan-critic) ALLOW='^\.harness/state/plan-critique\.md$' ;;
  navigator)   ALLOW='^\.harness/state/chart-proposal\.md$' ;;
  implementer)
    # The one scope that differs per repo. No configured scope, no writes:
    # an implementer pointed at an uninitialised repo must not guess.
    ALLOW="${HARNESS_IMPLEMENTER_SCOPE:-}"
    DENY="${HARNESS_IMPLEMENTER_DENY:-}"
    if [ -z "$ALLOW" ]; then
      echo "guard-write-paths.sh: HARNESS_IMPLEMENTER_SCOPE is not set in .harness/config.env — blocking all implementer writes (fail closed). Initialise this repo for the harness first." >&2
      exit 2
    fi ;;
  reviewer)
    ALLOW="${HARNESS_REVIEWER_SCOPE:-^(docs/|\.harness/state/review\.md$)}"
    # The north star anchors the loop; the loop may not move its own anchor.
    DENY="${HARNESS_REVIEWER_DENY:-^docs/northstar\.md$}" ;;
  *)
    echo "guard-write-paths.sh: unknown devagent role '$ROLE'. Blocking write to $REL." >&2
    exit 2
    ;;
esac

if printf '%s' "$REL" | grep -Eq "$ALWAYS"; then exit 0; fi
if [ -n "$DENY" ] && printf '%s' "$REL" | grep -Eq "$DENY"; then
  cat >&2 <<MSG
Blocked: the '$ROLE' agent may not write to '$REL' — it matches this
repository's deny pattern ($DENY). In the engine repo that means the
enforcement guards themselves: they are human-owned, and an agent editing
its own enforcement is the failure mode, not a workflow.

Report the needed change in .harness/state/blockers.md instead.
MSG
  exit 2
fi
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
