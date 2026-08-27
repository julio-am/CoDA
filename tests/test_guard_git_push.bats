#!/usr/bin/env bats
# Push-guard policy, invoked as production does: full hook JSON on stdin,
# role in agent_type. Run inside throwaway git repos so branch state is
# controlled and the log lands in the fixture, never in this repo.

REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
GUARD="$REPO/scripts/guard-git-push.sh"

pguard() { # pguard <agent_type-or-empty> <command>
  if [ -n "$1" ]; then
    printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","agent_type":"%s","tool_input":{"command":"%s"}}' "$1" "$2" | "$GUARD"
  else
    printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s"}}' "$2" | "$GUARD"
  fi
}

setup() {
  FIX="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FIX"
  cd "$FIX"
  git init -q -b main
  git -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
}

# @harness:R-004
@test "non-reviewer devagent roles are blocked from pushing" {
  for role in surveyor architect plan-critic implementer; do
    run pguard "devagent:$role" "git push"
    [ "$status" -eq 2 ]
  done
}

# @harness:R-004
@test "agents outside the devagent namespace are blocked from pushing too" {
  run pguard "other-plugin:helper" "git push"
  [ "$status" -eq 2 ]
}

# @harness:R-004
@test "the human session may push, and the attempt is logged" {
  run pguard "" "git push -u origin main"
  [ "$status" -eq 0 ]
  grep -q "ALLOWED:human" .harness/logs/git-push.log
}

# @harness:R-004
@test "force, delete, mirror, prune, tags are blocked even for reviewer" {
  git checkout -q -b task/T
  for cmd in "git push --force" "git push --force-with-lease" "git push --delete origin task/T" \
             "git push --mirror" "git push --prune" "git push --tags"; do
    run pguard devagent:reviewer "$cmd"
    [ "$status" -eq 2 ]
  done
}

# @harness:R-004
@test "reviewer on a non-task branch is blocked; on a task branch allowed" {
  run pguard devagent:reviewer "git push -u origin main"
  [ "$status" -eq 2 ]
  git checkout -q -b task/T
  run pguard devagent:reviewer "git push -u origin task/T"
  [ "$status" -eq 0 ]
}

# @harness:R-004
@test "refspec naming another branch is blocked" {
  git checkout -q -b task/T
  run pguard devagent:reviewer "git push origin task/OTHER"
  [ "$status" -eq 2 ]
}

# @harness:R-004
@test "a chained push is still caught" {
  run pguard devagent:implementer "echo done && git push"
  [ "$status" -eq 2 ]
}

# @harness:R-004
@test "every attempt appends exactly one single-line record" {
  run pguard devagent:implementer "git push"
  [ "$(wc -l < .harness/logs/git-push.log)" -eq 1 ]
  git checkout -q -b task/T
  run pguard devagent:reviewer "git push -u origin task/T"
  [ "$(wc -l < .harness/logs/git-push.log)" -eq 2 ]
  run awk -F'\t' 'NF != 5 {exit 1}' .harness/logs/git-push.log
  [ "$status" -eq 0 ]
}

# @harness:R-004
@test "log record stays single-line even on an unborn branch" {
  U="$BATS_TEST_TMPDIR/unborn"
  mkdir -p "$U"
  cd "$U"
  git init -q -b main
  run pguard devagent:implementer "git push"
  [ "$status" -eq 2 ]
  [ "$(wc -l < .harness/logs/git-push.log)" -eq 1 ]
}

# @harness:R-004
@test "unparseable input is blocked" {
  run bash -c 'echo "not json" | "'"$GUARD"'"'
  [ "$status" -eq 2 ]
}

# @harness:R-004
@test "non-push commands pass through untouched and unlogged" {
  run pguard devagent:implementer "git status"
  [ "$status" -eq 0 ]
  [ ! -e .harness/logs/git-push.log ]
}
