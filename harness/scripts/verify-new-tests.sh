#!/usr/bin/env bash
# verify-new-tests.sh [base-commit]
#
# The anti-tautology check. A test written after the code, that has never been
# seen to fail, usually asserts whatever the code happens to do. This script
# checks out the parent commit into a temporary worktree, copies in the new and
# modified test files, and runs them there. Each one is EXPECTED TO FAIL.
#
# A new test that passes against unchanged code tests nothing.
#
# A compile or import error at the parent commit counts as a failure and is the
# correct result: the test references something that did not exist yet.
#
# Config (.harness/config.env or environment):
#   HARNESS_TEST_CMD      full test command
#   HARNESS_TEST_ONE_CMD  per-file command, with {file} placeholder (optional
#                         but strongly preferred — gives per-test granularity)
#   HARNESS_BASE_BRANCH   default branch (default: main)
#   HARNESS_TEST_PATHS    space-separated test dirs (default: tests test)
set -uo pipefail

[ -f .harness/config.env ] && . .harness/config.env

BASE_BRANCH="${HARNESS_BASE_BRANCH:-main}"
TEST_PATHS="${HARNESS_TEST_PATHS:-tests test}"
BASE="${1:-$(git merge-base HEAD "$BASE_BRANCH" 2>/dev/null)}"

if [ -z "${BASE:-}" ]; then
  echo "FATAL: could not determine base commit (base branch '$BASE_BRANCH')." >&2
  exit 1
fi
if [ -z "${HARNESS_TEST_CMD:-}" ]; then
  echo "FATAL: HARNESS_TEST_CMD is not set. See .harness/config.env." >&2
  exit 1
fi

echo "base commit: $(git log -1 --format='%h %s' "$BASE")"

CHANGED="$(git diff --name-only --diff-filter=AM "$BASE"...HEAD -- $TEST_PATHS 2>/dev/null)"
if [ -z "$CHANGED" ]; then
  echo "No new or modified test files under: $TEST_PATHS"
  echo "RESULT: FAIL — a task that changes behaviour with no test change is a finding."
  exit 1
fi

echo "new/modified test files:"
printf '  %s\n' $CHANGED

WT="$(mktemp -d)"
cleanup() { git worktree remove --force "$WT" >/dev/null 2>&1 || true; }
trap cleanup EXIT

if ! git worktree add --detach "$WT" "$BASE" >/dev/null 2>&1; then
  echo "FATAL: could not create worktree at base commit." >&2
  exit 1
fi

# Copy the current versions of the changed test files over the base checkout.
for f in $CHANGED; do
  mkdir -p "$WT/$(dirname "$f")"
  cp "$f" "$WT/$f"
done

PASSED_AT_BASE=""
FAILED_AT_BASE=""
RC=0

pushd "$WT" >/dev/null || exit 1

if [ -n "${HARNESS_TEST_ONE_CMD:-}" ]; then
  for f in $CHANGED; do
    cmd="${HARNESS_TEST_ONE_CMD//\{file\}/$f}"
    printf '\n--- %s\n$ %s\n' "$f" "$cmd"
    out="$(eval "$cmd" 2>&1)"; rc=$?
    printf '%s\n' "$out" | tail -15
    if [ $rc -eq 0 ]; then
      echo "  >> PASSED at base — this test does not test the new behaviour."
      PASSED_AT_BASE="$PASSED_AT_BASE $f"
      RC=1
    else
      echo "  >> failed at base (expected)"
      FAILED_AT_BASE="$FAILED_AT_BASE $f"
    fi
  done
else
  echo
  echo "HARNESS_TEST_ONE_CMD not set — running the whole suite once."
  echo "This gives a coarse answer only: it cannot tell you WHICH new test is"
  echo "tautological. Set HARNESS_TEST_ONE_CMD for per-file granularity."
  echo "\$ $HARNESS_TEST_CMD"
  out="$(eval "$HARNESS_TEST_CMD" 2>&1)"; rc=$?
  printf '%s\n' "$out" | tail -30
  if [ $rc -eq 0 ]; then
    echo "  >> SUITE PASSED at base with the new tests copied in."
    echo "  >> At least one new test asserts nothing new."
    RC=1
  else
    echo "  >> suite failed at base (expected)"
  fi
fi

popd >/dev/null || true

echo
echo "================ RESULT ================"
if [ $RC -eq 0 ]; then
  echo "PASS — every new test fails against the unchanged code."
else
  echo "FAIL — tests that passed against unchanged code:"
  for f in $PASSED_AT_BASE; do echo "  $f"; done
  echo
  echo "Each is a blocking review finding. Either the test asserts pre-existing"
  echo "behaviour, or it asserts on a mock rather than on the change."
fi
exit $RC
