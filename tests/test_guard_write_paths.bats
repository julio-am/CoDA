#!/usr/bin/env bats
# Write-guard enforcement, invoked exactly as Claude Code invokes it: the
# full hook JSON on stdin (role in agent_type), CWD = the repo being
# developed. No arguments — production passes none.

REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
GUARD="$REPO/scripts/guard-write-paths.sh"

hook_json() { # hook_json <agent_type-or-empty> <file_path>
  if [ -n "$1" ]; then
    printf '{"hook_event_name":"PreToolUse","tool_name":"Write","agent_type":"%s","tool_input":{"file_path":"%s"}}' "$1" "$2"
  else
    printf '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"%s"}}' "$2"
  fi
}

guard() { # guard <role> <path>   (role -> devagent:<role>)
  hook_json "devagent:$1" "$2" | "$GUARD"
}

setup() {
  cd "$REPO"
  # A bin dir holding only the tools the sed fallback path needs — no jq, no
  # python3. Simulates the degraded machine the fallback exists for.
  FIXBIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$FIXBIN"
  for t in bash cat sed head grep; do
    ln -s "$(command -v $t)" "$FIXBIN/$t"
  done
}

# --- who is acting -------------------------------------------------------

# @harness:R-003
@test "the human session (no agent_type) is never blocked" {
  run bash -c "$(printf 'printf %%s %q | "%s"' "$(hook_json "" docs/roadmap.md)" "$GUARD")"
  [ "$status" -eq 0 ]
}

# @harness:R-003
@test "agents outside the devagent namespace are not policed" {
  run bash -c "$(printf 'printf %%s %q | "%s"' "$(hook_json "other-plugin:helper" docs/roadmap.md)" "$GUARD")"
  [ "$status" -eq 0 ]
}

# @harness:R-003
@test "an unknown devagent role is blocked" {
  run guard mystery-role tests/foo.bats
  [ "$status" -eq 2 ]
}

# --- R-001: parsing must fail closed, and the sed fallback must work -----

# @harness:R-001
@test "sed fallback resolves role and path when jq and python3 are absent" {
  run env PATH="$FIXBIN" bash -c \
    'printf "%s" "$0" | bash "$1"' "$(hook_json devagent:implementer scripts/x.sh)" "$GUARD"
  [ "$status" -eq 0 ]
  run env PATH="$FIXBIN" bash -c \
    'printf "%s" "$0" | bash "$1"' "$(hook_json devagent:implementer docs/roadmap.md)" "$GUARD"
  [ "$status" -eq 2 ]
}

# @harness:R-001
@test "sed fallback blocks input that does not look like hook JSON" {
  run env PATH="$FIXBIN" bash -c \
    'printf "%s" "{\"agent_type\":\"devagent:implementer\"}" | bash "$0"' "$GUARD"
  [ "$status" -eq 2 ]
}

# @harness:R-001
@test "guard with jq present still blocks out-of-scope write" {
  run guard implementer docs/roadmap.md
  [ "$status" -eq 2 ]
}

# @harness:R-001
@test "devagent agent with no extractable path is blocked, not allowed" {
  run bash -c 'printf "%s" "{\"hook_event_name\":\"PreToolUse\",\"agent_type\":\"devagent:implementer\",\"tool_input\":{}}" | "'"$GUARD"'"'
  [ "$status" -eq 2 ]
  run bash -c 'echo "not json" | "'"$GUARD"'"'
  [ "$status" -eq 2 ]
}

# --- R-003: the role matrix ---------------------------------------------

# @harness:R-003
@test "each role allows its scope and blocks outside it" {
  run guard surveyor .harness/state/current-task.md;   [ "$status" -eq 0 ]
  run guard surveyor scripts/foo.sh;                   [ "$status" -eq 2 ]
  run guard architect .harness/state/plan.md;          [ "$status" -eq 0 ]
  run guard architect tests/foo.bats;                  [ "$status" -eq 2 ]
  run guard plan-critic .harness/state/plan-critique.md; [ "$status" -eq 0 ]
  run guard plan-critic docs/roadmap.md;               [ "$status" -eq 2 ]
  run guard implementer scripts/harness-status.sh;     [ "$status" -eq 0 ]
  run guard implementer tests/foo.bats;                [ "$status" -eq 0 ]
  run guard implementer docs/roadmap.md;               [ "$status" -eq 2 ]
  run guard reviewer docs/roadmap.md;                  [ "$status" -eq 0 ]
  run guard reviewer .harness/state/review.md;         [ "$status" -eq 0 ]
  run guard reviewer scripts/anything.sh;              [ "$status" -eq 2 ]
}

# @harness:R-003
@test "blockers.md is writable by every role" {
  for role in surveyor architect plan-critic implementer reviewer; do
    run guard "$role" .harness/state/blockers.md
    [ "$status" -eq 0 ]
  done
}

# @harness:R-003
@test "implementer cannot modify enforcement guards in the engine repo" {
  run guard implementer scripts/guard-write-paths.sh
  [ "$status" -eq 2 ]
  run guard implementer scripts/guard-git-push.sh
  [ "$status" -eq 2 ]
}

# --- per-repo configuration ---------------------------------------------

# @harness:R-003
@test "implementer scope comes from the target repo's config.env" {
  T="$BATS_TEST_TMPDIR/target"
  mkdir -p "$T/.harness"
  printf 'HARNESS_IMPLEMENTER_SCOPE="^(brain|tools|tests)/"\n' > "$T/.harness/config.env"
  cd "$T"
  run guard implementer brain/client.py;  [ "$status" -eq 0 ]
  run guard implementer scripts/x.sh;     [ "$status" -eq 2 ]
}

# @harness:R-003
@test "implementer with no configured scope is blocked entirely" {
  T="$BATS_TEST_TMPDIR/bare"
  mkdir -p "$T"
  cd "$T"
  run guard implementer src/anything.c
  [ "$status" -eq 2 ]
  [[ "$output" == *HARNESS_IMPLEMENTER_SCOPE* ]]
}

# --- scratch areas ---

# @harness:R-003
@test "every role may write to the session scratchpad" {
  run guard architect /private/tmp/claude-501/-proj/sess-id/scratchpad/probe.py
  [ "$status" -eq 0 ]
  run guard implementer /tmp/claude-501/x/notes.txt
  [ "$status" -eq 0 ]
}

# @harness:R-003
@test "absolute paths outside repo and scratch stay blocked - engine included" {
  run guard implementer /Users/julio/Projects/DevAgent/scripts/guard-write-paths.sh
  [ "$status" -eq 2 ]
  run guard implementer /etc/hosts
  [ "$status" -eq 2 ]
}
