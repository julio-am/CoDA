#!/usr/bin/env bats
# The plugin layout is the loading mechanism. Lock its structure: valid
# manifests, hooks that point at real scripts, agents with no dead
# frontmatter hooks (plugin agents' frontmatter hooks never fire — probed
# empirically 2026-08-26).

REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

# @harness:R-007
@test "plugin, marketplace, and hooks manifests are valid JSON" {
  for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json hooks/hooks.json; do
    python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$REPO/$f"
  done
}

# @harness:R-007
@test "every hook command resolves to an existing executable script" {
  python3 - "$REPO" <<'PY'
import json, os, sys
repo = sys.argv[1]
h = json.load(open(os.path.join(repo, "hooks/hooks.json")))
cmds = [hh["command"]
        for entries in h["hooks"].values()
        for e in entries for hh in e["hooks"]]
assert cmds, "no hook commands found"
for c in cmds:
    path = c.replace("${CLAUDE_PLUGIN_ROOT}", repo)
    assert os.path.isfile(path) and os.access(path, os.X_OK), f"missing or not executable: {c}"
PY
}

# @harness:R-007
@test "all five agents exist with frontmatter and no dead hooks blocks" {
  for a in surveyor architect plan-critic implementer reviewer; do
    f="$REPO/agents/$a.md"
    [ -f "$f" ]
    head -1 "$f" | grep -q '^---$'
    grep -q "^name: $a$" "$f"
    ! grep -q '^hooks:' "$f"
  done
}

# @harness:R-007
@test "all five commands exist; build and land are human-trigger only" {
  for c in next plan build review land; do
    [ -f "$REPO/commands/$c.md" ]
  done
  grep -q 'disable-model-invocation: true' "$REPO/commands/build.md"
  grep -q 'disable-model-invocation: true' "$REPO/commands/land.md"
}
