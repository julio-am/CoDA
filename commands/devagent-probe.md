---
description: "PROBE ONLY — verify plugin command loading, path substitution, and agent delegation"
allowed-tools: Read, Bash, Agent
---

This is a loading-mechanism probe for the DevAgent harness.

Report the following, exactly and without embellishment:

1. The literal rendering of the plugin root in this command's text:
   `${CLAUDE_PLUGIN_ROOT}`
2. Then run with Bash: `echo "cmd-cwd=$(pwd)" >> .devagent-probe-cmd.log`
3. Then delegate to the `devagent-probe` agent with the task: "Run your
   probe procedure." If that agent is not available, say exactly which agent
   names are available to you instead.
4. Show me the probe agent's reply verbatim.
