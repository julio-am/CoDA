#!/usr/bin/env bats
# harness-land-state.sh: the /land archive step, scripted.

REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
LAND="$REPO/scripts/harness-land-state.sh"

setup() {
  T="$BATS_TEST_TMPDIR/target"
  mkdir -p "$T/.harness/state"
  printf 'HARNESS_ENGINE_ROOT="%s"\n' "$REPO" > "$T/.harness/config.env"
  for f in blockers current-task plan review plan-critique; do
    echo "loop content $f" > "$T/.harness/state/$f.md"
  done
  cd "$T"
}

# @harness:R-009
@test "archives all state files and resets live state from engine templates" {
  run "$LAND" R-001
  [ "$status" -eq 0 ]
  d=(.harness/logs/R-001-*)
  [ -d "${d[0]}" ]
  grep -q "loop content plan" "${d[0]}/plan.md"
  grep -q "loop content review" "${d[0]}/review.md"
  ! grep -q "loop content" .harness/state/current-task.md
  diff -q "$REPO/templates/plan.md" .harness/state/plan.md
}

# @harness:R-009
@test "refuses a second archive of the same id on the same day" {
  run "$LAND" R-001; [ "$status" -eq 0 ]
  run "$LAND" R-001
  [ "$status" -eq 1 ]
  [[ "$output" == *"refusing to overwrite"* ]]
}

# @harness:R-009
@test "refuses malformed ids and non-target directories" {
  run "$LAND" "R-001; rm -rf /"
  [ "$status" -eq 1 ]
  cd "$BATS_TEST_TMPDIR"
  run "$LAND" R-001
  [ "$status" -eq 1 ]
}
