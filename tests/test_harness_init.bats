#!/usr/bin/env bats
# harness-init.sh: pointing the engine at a target repo.

REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
INIT="$REPO/scripts/harness-init.sh"

setup() {
  T="$BATS_TEST_TMPDIR/target"
  mkdir -p "$T"
  git -C "$T" init -q -b main
}

# @harness:R-006
@test "init scaffolds config, state, logs, roadmap, and settings" {
  run "$INIT" "$T"
  [ "$status" -eq 0 ]
  [ -f "$T/.harness/config.env" ]
  grep -q "HARNESS_ENGINE_ROOT=\"$REPO\"" "$T/.harness/config.env"
  [ -f "$T/.harness/logs/.gitignore" ]
  for f in blockers current-task plan review plan-critique README; do
    [ -f "$T/.harness/state/$f.md" ]
  done
  [ -f "$T/docs/roadmap.md" ]
  [ -f "$T/docs/northstar.md" ]
  python3 - "$T" <<'PY'
import json, sys
s = json.load(open(sys.argv[1] + "/.claude/settings.json"))
assert s["enabledPlugins"]["devagent@devagent-local"] is True
assert s["extraKnownMarketplaces"]["devagent-local"]["source"]["source"] == "directory"
assert s["env"]["CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH"] == "1"
assert any("harness-status.sh" in a for a in s["permissions"]["allow"])
assert any("harness-land-state.sh" in a for a in s["permissions"]["allow"])
assert any("harness-event.sh" in a for a in s["permissions"]["allow"])
assert any("harness-trajectory.sh" in a for a in s["permissions"]["allow"])
assert any("harness-autonomy.sh" in a for a in s["permissions"]["allow"])
assert "Bash(git push origin main:*)" in s["permissions"]["allow"]
assert not any(":*origin" in d for d in s["permissions"]["deny"])
PY
}

# @harness:R-006
@test "init is idempotent and never clobbers existing files" {
  run "$INIT" "$T"; [ "$status" -eq 0 ]
  echo 'HARNESS_TEST_CMD="my-real-tests"' > "$T/.harness/config.env"
  python3 - "$T" <<'PY'
import json, sys
p = sys.argv[1] + "/.claude/settings.json"
s = json.load(open(p))
s["permissions"]["allow"].append("Bash(my-custom:*)")
json.dump(s, open(p, "w"))
PY
  run "$INIT" "$T"; [ "$status" -eq 0 ]
  grep -q 'my-real-tests' "$T/.harness/config.env"
  grep -q 'my-custom' "$T/.claude/settings.json"
  [[ "$output" == *"kept    $T/.harness/config.env"* ]]
}

# @harness:R-006
@test "init refuses a non-git target and refuses the engine itself" {
  N="$BATS_TEST_TMPDIR/notrepo"; mkdir -p "$N"
  run "$INIT" "$N"
  [ "$status" -eq 1 ]
  run "$INIT" "$REPO"
  [ "$status" -eq 1 ]
  [[ "$output$stderr" == *"refusing"* ]] || [[ "$output" == *"refusing"* ]]
}

# @harness:R-006
@test "init honours a pre-existing HARNESS_ROADMAP path" {
  mkdir -p "$T/.harness"
  printf 'HARNESS_ROADMAP="docs/backlog.md"\n' > "$T/.harness/config.env"
  run "$INIT" "$T"
  [ "$status" -eq 0 ]
  [ -f "$T/docs/backlog.md" ]
  [ ! -f "$T/docs/roadmap.md" ]
}
