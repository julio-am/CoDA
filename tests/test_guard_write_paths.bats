#!/usr/bin/env bats
# Write-guard enforcement, invoked exactly as Claude Code invokes it:
# hook JSON on stdin, role as argv, CWD = the repo being developed.

REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
GUARD="$REPO/scripts/guard-write-paths.sh"

guard() { # guard <role> <path>
  printf '{"tool_input":{"file_path":"%s"}}' "$2" | "$GUARD" "$1"
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

# --- R-001: the sed fallback must fail closed, and must actually work ---

# @harness:R-001
@test "sed fallback extracts file_path when jq and python3 are absent" {
  run env PATH="$FIXBIN" bash -c \
    'printf "%s" "{\"tool_input\":{\"file_path\":\"scripts/x.sh\"}}" | bash '"$GUARD"' implementer'
  [ "$status" -eq 0 ]
}

# @harness:R-001
@test "guard blocks out-of-scope write via sed fallback alone" {
  run env PATH="$FIXBIN" bash -c \
    'printf "%s" "{\"tool_input\":{\"file_path\":\"docs/roadmap.md\"}}" | bash '"$GUARD"' implementer'
  [ "$status" -eq 2 ]
}

# @harness:R-001
@test "guard with jq present still blocks out-of-scope write" {
  run guard implementer docs/roadmap.md
  [ "$status" -eq 2 ]
}

# @harness:R-001
@test "input with no extractable path is blocked, not allowed" {
  run bash -c 'printf "%s" "{\"tool_input\":{}}" | "'"$GUARD"'" implementer'
  [ "$status" -eq 2 ]
}

# --- R-003: the role matrix ---

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
@test "unknown role and unparseable input are blocked" {
  run guard intruder scripts/foo.sh
  [ "$status" -eq 2 ]
  run bash -c 'echo "not json" | "'"$GUARD"'" implementer'
  [ "$status" -eq 2 ]
}

# @harness:R-003
@test "implementer cannot modify enforcement guards" {
  run guard implementer scripts/guard-write-paths.sh
  [ "$status" -eq 2 ]
  run guard implementer scripts/guard-git-push.sh
  [ "$status" -eq 2 ]
}

# --- per-repo configuration ---

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
