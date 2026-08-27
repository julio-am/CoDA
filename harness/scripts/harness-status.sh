#!/usr/bin/env bash
# harness-status.sh
#
# Mechanical project status. The surveyor grounds its assessment in this
# output rather than in an impression formed by reading source files.
#
# Config (set in .harness/config.env or the environment):
#   HARNESS_TEST_CMD      full test command
#   HARNESS_BASE_BRANCH   default branch name (default: main)
#   HARNESS_TEST_PATHS    space-separated test dirs (default: tests test)
set -uo pipefail

[ -f .harness/config.env ] && . .harness/config.env

BASE_BRANCH="${HARNESS_BASE_BRANCH:-main}"
TEST_PATHS="${HARNESS_TEST_PATHS:-tests test}"
ROADMAP="${HARNESS_ROADMAP:-docs/roadmap.md}"

hr() { printf '\n== %s %s\n' "$1" "$(printf '=%.0s' $(seq 1 $((60 - ${#1}))))"; }

hr "GIT"
echo "branch:        $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '(not a repo)')"
echo "base branch:   $BASE_BRANCH"
echo "head:          $(git log -1 --format='%h %s' 2>/dev/null)"
echo
echo "recent commits:"
git log -12 --format='  %h  %ad  %s' --date=short 2>/dev/null

hr "WORKING TREE"
if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
  echo "clean"
else
  echo "DIRTY — uncommitted changes present. Do not discard these."
  git status --short
fi

hr "DIFF VS BASE"
if git rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1; then
  BASE="$(git merge-base HEAD "$BASE_BRANCH" 2>/dev/null)"
  echo "merge-base: ${BASE:-unknown}"
  [ -n "${BASE:-}" ] && git diff --stat "$BASE"...HEAD
else
  echo "base branch '$BASE_BRANCH' not found"
fi

hr "TESTS"
if [ -z "${HARNESS_TEST_CMD:-}" ]; then
  echo "HARNESS_TEST_CMD is not set. Set it in .harness/config.env."
  echo "STATUS UNKNOWN — do not treat any roadmap item as done."
else
  echo "\$ $HARNESS_TEST_CMD"
  TEST_OUT="$(eval "$HARNESS_TEST_CMD" 2>&1)"; TEST_RC=$?
  printf '%s\n' "$TEST_OUT" | tail -40
  echo
  echo "exit code: $TEST_RC"
fi

hr "ROADMAP ITEMS vs TAGGED TESTS"
if [ -f "$ROADMAP" ]; then
  printf '%-8s %-14s %s\n' "ID" "ROADMAP SAYS" "TESTS TAGGED @harness:<ID>"
  grep -oE '^## (R-[0-9]+)' "$ROADMAP" | awk '{print $2}' | while read -r id; do
    said="$(awk -v id="$id" '
      $0 ~ "^## " id " " {f=1; next}
      f && /^\*\*Status:\*\*|^- \*\*Status:\*\*/ {gsub(/.*Status:\*\* */,""); print; exit}
      f && /^## / {exit}
    ' "$ROADMAP")"
    n=$(grep -rl "@harness:$id" $TEST_PATHS 2>/dev/null | wc -l | tr -d ' ')
    printf '%-8s %-14s %s file(s)\n' "$id" "${said:-?}" "$n"
  done
  echo
  echo "An item is done only when its tagged tests exist AND pass."
  echo "'done' in the roadmap with 0 tagged files is a discrepancy."
else
  echo "no roadmap at $ROADMAP"
fi

hr "MARKERS IN CODE"
grep -rn -E '\b(TODO|FIXME|XXX|HACK)\b' . 2>/dev/null \
  --exclude-dir=.git --exclude-dir=.harness --exclude-dir=scripts \
  --exclude-dir=node_modules --exclude-dir=build --exclude-dir=target \
  --exclude-dir=dist --exclude-dir=vendor --exclude-dir=.venv \
  | head -25
echo "(first 25; excludes build dirs and the harness itself)"

hr "LOOP STATE"
for f in .harness/state/*.md; do
  [ -e "$f" ] || continue
  printf '%-40s %s bytes  %s\n' "$f" "$(wc -c < "$f" | tr -d ' ')" \
    "$(git log -1 --format=%ad --date=short -- "$f" 2>/dev/null)"
done
