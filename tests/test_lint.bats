#!/usr/bin/env bats
# The lint gate, as a test — so "shellcheck-clean" is a derived status, not a claim.

REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

# @harness:R-005
@test "shellcheck at default severity exits 0 for all engine scripts" {
  run shellcheck "$REPO"/scripts/*.sh
  [ "$status" -eq 0 ]
}
