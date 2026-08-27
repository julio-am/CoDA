#!/usr/bin/env bash
# PROBE ONLY — removed once the loading mechanism is confirmed.
# $1 tags which hook variant invoked us (abs / home / json).
{
  printf 'fired=%s variant=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${1:-untagged}"
  printf 'plugin_root=%s\n' "${CLAUDE_PLUGIN_ROOT:-unset}"
  printf 'cwd=%s\n' "$(pwd)"
  printf -- '---\n'
} >> .devagent-probe-hook.log
exit 0
