#!/usr/bin/env bats
# Harness smoke suite. Infrastructure, not acceptance — carries no @harness tag.

REPO="$BATS_TEST_DIRNAME/.."

@test "every script parses (bash -n)" {
  for f in "$REPO"/scripts/*.sh "$REPO"/INSTALL.sh; do
    bash -n "$f"
  done
}

@test "every script is executable" {
  for f in "$REPO"/scripts/*.sh "$REPO"/INSTALL.sh; do
    [ -x "$f" ]
  done
}

@test "config.env declares the required test command" {
  grep -q '^HARNESS_TEST_CMD="bats tests"$' "$REPO/.harness/config.env"
  grep -q '^HARNESS_TEST_ONE_CMD="bats {file}"$' "$REPO/.harness/config.env"
}
