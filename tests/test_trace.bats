#!/usr/bin/env bats
# harness-trace.sh: the recorded-thinking reader that lets agent prompts
# forbid chat narration without losing debuggability.

REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

# @harness:R-008
@test "trace renders thinking, tool calls, results, and final text from a transcript" {
  run "$REPO/scripts/harness-trace.sh" "$REPO/tests/fixtures/trace-sample.jsonl"
  [ "$status" -eq 0 ]
  [[ "$output" == *"thinking"* && "$output" == *"the plan lacks a stop rule"* ]]
  [[ "$output" == *"→ Bash: grep -n stop plan.md"* ]]
  [[ "$output" == *"← 113: break on empty results"* ]]
  [[ "$output" == *"SAYS: Finding: stop rule contradicts the fixture."* ]]
}

# @harness:R-008
@test "trace list mode fails informatively outside a repo with transcripts" {
  cd "$BATS_TEST_TMPDIR"
  run "$REPO/scripts/harness-trace.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no transcript store"* ]]
}
