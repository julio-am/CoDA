#!/usr/bin/env bash
# harness-event.sh <task-id|-> <event> [detail...]
#
# Append one record to the loop's durable event log. State files are
# overwritten every loop; this log is what survives — rejections, attempts,
# verdicts, gate outcomes — and it is what harness-trajectory.sh derives
# rates and tripwires from. Append-only, tab-separated, one line each.
set -euo pipefail

TASK="${1:?usage: harness-event.sh <task-id|-> <event> [detail...]}"
EVENT="${2:?usage: harness-event.sh <task-id|-> <event> [detail...]}"
shift 2
DETAIL="$*"
case "$TASK$EVENT" in
  *[!A-Za-z0-9_.-]*) echo "error: task/event must be [A-Za-z0-9_.-]" >&2; exit 1 ;;
esac
LOG=".harness/logs/loop-events.log"
mkdir -p "$(dirname "$LOG")"
printf '%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$TASK" "$EVENT" "${DETAIL//$'\t'/ }" >> "$LOG"
