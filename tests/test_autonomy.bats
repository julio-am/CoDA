#!/usr/bin/env bats
# Autonomy is derived, never stored; promotion earned, demotion instant.

REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
EVENT="$REPO/scripts/harness-event.sh"
AUTO="$REPO/scripts/harness-autonomy.sh"

setup() {
  T="$BATS_TEST_TMPDIR/t"; mkdir -p "$T/.harness"; cd "$T"
}

land_clean() { # land_clean <id>
  "$EVENT" "$1" survey-done m=M1; "$EVENT" "$1" review-verdict accept; "$EVENT" "$1" land-pushed abc
}

# @harness:R-012
@test "no history derives level 0" {
  run "$AUTO"
  [[ "${lines[0]}" == "level=0 derived=0 ceiling=0" ]]
}

# @harness:R-012
@test "three clean tasks derive 1 (interventions unproven), ceiling gates effective level" {
  printf 'HARNESS_AUTONOMY_CEILING="2"\n' > .harness/config.env
  land_clean R-001; land_clean R-002; land_clean R-003
  run "$AUTO"
  [[ "${lines[0]}" == "level=1 derived=1 ceiling=2" ]]
  printf 'HARNESS_AUTONOMY_CEILING="0"\n' > .harness/config.env
  run "$AUTO"
  [[ "${lines[0]}" == "level=0 derived=1 ceiling=0" ]]
}

# @harness:R-012
@test "one rejection in the window demotes derived to 0 instantly" {
  printf 'HARNESS_AUTONOMY_CEILING="2"\n' > .harness/config.env
  land_clean R-001; land_clean R-002
  "$EVENT" R-003 survey-done m=M1
  "$EVENT" R-003 review-verdict "reject stage=3"
  "$EVENT" R-003 review-verdict accept
  "$EVENT" R-003 land-pushed abc
  run "$AUTO"
  [[ "${lines[0]}" == "level=0 derived=0 ceiling=2" ]]
  [[ "$output" == *rejection* ]]
}

# @harness:R-012
@test "fewer than three tasks never promotes" {
  printf 'HARNESS_AUTONOMY_CEILING="2"\n' > .harness/config.env
  land_clean R-001; land_clean R-002
  run "$AUTO"
  [[ "${lines[0]}" == "level=0 derived=0 ceiling=2" ]]
}
