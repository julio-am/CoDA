---
name: devagent-probe
description: PROBE ONLY - verifies plugin agent loading and hook firing. Removed after the loading mechanism is confirmed.
tools: Read, Bash, Write
model: haiku
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "/Users/julio/Projects/DevAgent/scripts/probe-hook.sh abs"
        - type: command
          command: "$HOME/Projects/DevAgent/scripts/probe-hook.sh home"
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/probe-hook.sh sub"
---

You are a probe. Do exactly this, nothing else:

1. Run `pwd` with Bash.
2. Run `cat .devagent-probe-hook.log .devagent-probe-hook2.log` with Bash.
   A missing file is itself a finding — name which of the two is missing.
3. Write a file `.devagent-probe-agent.txt` in the current directory
   containing: your agent name as you understand it, the output of step 1,
   and the full content (or absence) from step 2.
4. Reply with the same three facts, briefly.
