#!/usr/bin/env bash
# harness-land-state.sh <task-id>
#
# The /land archive step, deterministically: copy the loop's state files to
# .harness/logs/<ID>-<UTC date>/ and reset the live state from the engine's
# templates. Run from the target repo. Refuses to overwrite an existing
# archive — landing the same ID twice on one day is a signal, not a workflow.
set -euo pipefail

ID="${1:?usage: harness-land-state.sh <task-id, e.g. R-001>}"
case "$ID" in
  *[!A-Za-z0-9_-]*) echo "error: task id '$ID' has characters outside [A-Za-z0-9_-]" >&2; exit 1 ;;
esac

[ -d .harness/state ] || { echo "error: no .harness/state here — run from the target repo" >&2; exit 1; }
# shellcheck disable=SC1091  # target-repo config, resolved at runtime
[ -f .harness/config.env ] && . .harness/config.env
ENGINE="${HARNESS_ENGINE_ROOT:?HARNESS_ENGINE_ROOT not set in .harness/config.env}"

DEST=".harness/logs/$ID-$(date -u +%Y-%m-%d)"
[ -e "$DEST" ] && { echo "error: $DEST already exists — refusing to overwrite an archive" >&2; exit 1; }

mkdir -p "$DEST"
cp .harness/state/*.md "$DEST/"

for f in blockers current-task plan review; do
  cp "$ENGINE/templates/$f.md" ".harness/state/$f.md"
done
printf '# Plan critique\n\n(Written by the plan-critic each loop.)\n' > .harness/state/plan-critique.md

echo "archived $(find "$DEST" -name '*.md' | wc -l | tr -d ' ') state files to $DEST; live state reset from $ENGINE/templates"
