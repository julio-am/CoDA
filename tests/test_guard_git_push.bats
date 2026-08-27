#!/usr/bin/env bats
# Push-guard policy, run inside throwaway git repos so branch state is
# controlled and the log lands in the fixture, never in this repo.

REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
GUARD="$REPO/scripts/guard-git-push.sh"

pguard() { # pguard <role> <command>
  printf '{"tool_input":{"command":"%s"}}' "$2" | "$GUARD" "$1"
}

setup() {
  FIX="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FIX"
  cd "$FIX"
  git init -q -b main
  git -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
}

# @harness:R-004
@test "non-reviewer roles are blocked from pushing" {
  for role in surveyor architect plan-critic implementer; do
    run pguard "$role" "git push"
    [ "$status" -eq 2 ]
  done
}

# @harness:R-004
@test "force, delete, mirror, prune, tags are blocked even for reviewer" {
  git checkout -q -b task/T
  for cmd in "git push --force" "git push --force-with-lease" "git push --delete origin task/T" \
             "git push --mirror" "git push --prune" "git push --tags"; do
    run pguard reviewer "$cmd"
    [ "$status" -eq 2 ]
  done
}

# @harness:R-004
@test "reviewer on a non-task branch is blocked; on a task branch allowed" {
  run pguard reviewer "git push -u origin main"
  [ "$status" -eq 2 ]
  git checkout -q -b task/T
  run pguard reviewer "git push -u origin task/T"
  [ "$status" -eq 0 ]
}

# @harness:R-004
@test "refspec naming another branch is blocked" {
  git checkout -q -b task/T
  run pguard reviewer "git push origin task/OTHER"
  [ "$status" -eq 2 ]
}

# @harness:R-004
@test "a chained push is still caught" {
  run pguard implementer "echo done && git push"
  [ "$status" -eq 2 ]
}

# @harness:R-004
@test "every attempt appends exactly one single-line record" {
  run pguard implementer "git push"
  [ "$(wc -l < .harness/logs/git-push.log)" -eq 1 ]
  git checkout -q -b task/T
  run pguard reviewer "git push -u origin task/T"
  [ "$(wc -l < .harness/logs/git-push.log)" -eq 2 ]
  # 5 tab-separated fields per record, no wrapped lines
  run awk -F'\t' 'NF != 5 {exit 1}' .harness/logs/git-push.log
  [ "$status" -eq 0 ]
}

# @harness:R-004
@test "log record stays single-line even on an unborn branch" {
  U="$BATS_TEST_TMPDIR/unborn"
  mkdir -p "$U"
  cd "$U"
  git init -q -b main
  run pguard implementer "git push"
  [ "$status" -eq 2 ]
  [ "$(wc -l < .harness/logs/git-push.log)" -eq 1 ]
}

# @harness:R-004
@test "non-push commands pass through untouched and unlogged" {
  run pguard implementer "git status"
  [ "$status" -eq 0 ]
  [ ! -e .harness/logs/git-push.log ]
}
