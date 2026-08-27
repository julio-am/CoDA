#!/usr/bin/env bash
# PROBE ONLY — removed once the loading mechanism is confirmed.
# Fired from the plugin's hooks/hooks.json. Dumps everything we might ever
# want: claude-related env, cwd, and the verbatim hook input JSON — the
# point is to learn whether hook input identifies the agent that is acting.
{
  printf '=== fired=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'cwd=%s\n' "$(pwd)"
  env | grep -i -E 'claude|plugin' | sort
  printf -- '--- stdin ---\n'
  cat
  printf '\n=== end\n'
} >> .devagent-probe-hook2.log
exit 0
