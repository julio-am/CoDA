#!/usr/bin/env bash
# PROBE ONLY — removed once the loading mechanism is confirmed.
# Appends one record per firing so we can see: did the hook run at all,
# did ${CLAUDE_PLUGIN_ROOT} expand, and what CWD hooks run in.
{
  printf 'fired=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'plugin_root=%s\n' "${CLAUDE_PLUGIN_ROOT:-unset}"
  printf 'project_dir=%s\n' "${CLAUDE_PROJECT_DIR:-unset}"
  printf 'cwd=%s\n' "$(pwd)"
  printf -- '---\n'
} >> .devagent-probe-hook.log
exit 0
