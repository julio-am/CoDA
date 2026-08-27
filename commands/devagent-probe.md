---
description: "PROBE ONLY — round 2: hook firing variants, hook input contents, symlink agent"
allowed-tools: Read, Bash, Agent
---

This is round 2 of the DevAgent loading-mechanism probe. Do these in order,
report without embellishment:

1. Run with Bash: `echo main-loop-bash-ran`
2. Delegate to the `devagent-probe` agent with the task: "Run your probe
   procedure."
3. Delegate to the `symlink-probe` agent with the task: "Report in." If it
   is not available, say exactly that.
4. Then run with Bash:
   `cat .devagent-probe-hook.log 2>/dev/null; echo ===; cat .devagent-probe-hook2.log 2>/dev/null; echo ===END`
   and show me the output verbatim.
