#!/usr/bin/env bats
# The outer loop's instruments: durable event log and derived trajectory.

REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
EVENT="$REPO/scripts/harness-event.sh"
TRAJ="$REPO/scripts/harness-trajectory.sh"

setup() {
  T="$BATS_TEST_TMPDIR/target"
  mkdir -p "$T/.harness" "$T/docs"
  git -C "$T" init -q -b main 2>/dev/null || true
  printf 'HARNESS_ROADMAP="docs/backlog.md"\n' > "$T/.harness/config.env"
  echo "# backlog" > "$T/docs/backlog.md"
  cd "$T"
}

# @harness:R-011
@test "event script appends single-line tab-separated records" {
  run "$EVENT" R-001 survey-done "milestone=M1"
  [ "$status" -eq 0 ]
  run "$EVENT" R-001 review-verdict "reject stage=3"
  [ "$(wc -l < .harness/logs/loop-events.log)" -eq 2 ]
  run awk -F'\t' 'NF != 4 {exit 1}' .harness/logs/loop-events.log
  [ "$status" -eq 0 ]
}

# @harness:R-011
@test "event script refuses shell metacharacters in task and event" {
  run "$EVENT" 'R-001;rm' survey-done
  [ "$status" -eq 1 ]
  run "$EVENT" R-001 'done$(x)'
  [ "$status" -eq 1 ]
}

# @harness:R-011
@test "trajectory derives rates and tripwires from the event log" {
  "$EVENT" R-001 survey-done "milestone=M1"
  "$EVENT" R-001 review-verdict "reject stage=3"
  "$EVENT" R-001 review-verdict "accept"
  "$EVENT" R-001 land-pushed "abc1234"
  run "$TRAJ" 5
  [ "$status" -eq 0 ]
  [[ "$output" == *"RATES"* && "$output" == *"review rejections: 1"* ]]
  [[ "$output" == *"landed: 1"* ]]
  [[ "$output" == *"TRIPWIRES"* && "$output" == *"AUTONOMY"* ]]
}

# @harness:R-011
@test "trajectory without an event log says so and exits 0" {
  rm -rf .harness/logs
  run "$TRAJ"
  [ "$status" -eq 0 ]
  [[ "$output" == *"has not recorded events"* ]]
}
