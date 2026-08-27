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
    # Try file_path first, then path — mirrors the jq/python3 branches.
    p="$(printf '%s' "$INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
    [ -z "$p" ] && p="$(printf '%s' "$INPUT" | sed -n 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
    printf '%s' "$p"
  fi
}

PATH_ARG="$(extract_path)"
EXTRACT_RC=$?

if [ $EXTRACT_RC -ne 0 ]; then
  echo "guard-write-paths.sh: could not parse hook input; refusing to allow an unguarded write" >&2
  exit 2
fi

# This guard only runs under a Write|Edit matcher, and those tools always
# carry a target path. An empty extraction is a parse failure, and a parse
# failure fails closed (CLAUDE.md invariant 1) — the R-001 bug was exactly
# this case falling through to allow.
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
  implementer)
    # The one scope that differs per repo. No configured scope, no writes:
    # an implementer pointed at an uninitialised repo must not guess.
    ALLOW="${HARNESS_IMPLEMENTER_SCOPE:-}"
    DENY="${HARNESS_IMPLEMENTER_DENY:-}"
    if [ -z "$ALLOW" ]; then
      echo "guard-write-paths.sh: HARNESS_IMPLEMENTER_SCOPE is not set in .harness/config.env — blocking all implementer writes (fail closed). Initialise this repo for the harness first." >&2
      exit 2
    fi ;;
  reviewer)    ALLOW="${HARNESS_REVIEWER_SCOPE:-^(docs/|\.harness/state/review\.md$)}" ;;
  *)
    echo "guard-write-paths.sh: unknown role '$ROLE'. Blocking write to $REL." >&2
    exit 2
    ;;
esac

if printf '%s' "$REL" | grep -Eq "$ALWAYS"; then exit 0; fi
if [ -n "$DENY" ] && printf '%s' "$REL" | grep -Eq "$DENY"; then
  cat >&2 <<MSG
Blocked: the '$ROLE' agent may not modify an enforcement guard ('$REL').

The guards are what make this harness a harness, and they are human-owned: a
task that changes one is implemented by the human, outside the loop the guard
constrains. An agent editing its own enforcement is the failure mode, not a
workflow.

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
