#!/usr/bin/env bash
# Copy the harness into a repository. Run from the unzipped harness directory:
#   ./INSTALL.sh /path/to/your/repo
# Never overwrites an existing file — it reports collisions and stops.
set -euo pipefail

DEST="${1:?usage: ./INSTALL.sh /path/to/repo}"
SRC="$(cd "$(dirname "$0")" && pwd)"

[ -d "$DEST/.git" ] || { echo "error: $DEST is not a git repository" >&2; exit 1; }

collisions=()
while IFS= read -r f; do
  rel="${f#"$SRC"/}"
  [ "$rel" = "INSTALL.sh" ] && continue
  [ -e "$DEST/$rel" ] && collisions+=("$rel")
done < <(find "$SRC" -type f)

if [ ${#collisions[@]} -gt 0 ]; then
  echo "These files already exist in $DEST:"
  printf '  %s\n' "${collisions[@]}"
  echo
  echo "Nothing was copied. Merge them by hand, or move them aside and re-run."
  exit 1
fi

while IFS= read -r f; do
  rel="${f#"$SRC"/}"
  [ "$rel" = "INSTALL.sh" ] && continue
  mkdir -p "$DEST/$(dirname "$rel")"
  cp "$f" "$DEST/$rel"
done < <(find "$SRC" -type f)

chmod +x "$DEST/scripts/"*.sh
echo "Installed into $DEST"
echo
echo "Next:"
echo "  1. Fill in the command table in $DEST/CLAUDE.md"
echo "  2. Fill in $DEST/.harness/config.env (same commands)"
echo "  3. cd $DEST && ./scripts/harness-status.sh    # must run clean"
echo "  4. Write real items into $DEST/docs/roadmap.md"
echo "  5. Open Claude Code, trust the folder, then run /next"
