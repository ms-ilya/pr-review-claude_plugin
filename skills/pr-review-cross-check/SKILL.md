---
name: pr-review-cross-check
description: Cross-file analysis. Triggers on "Check cross-file issues for PR <number>".
tools: Task, Bash, Glob, TaskOutput
---

## EXECUTION

### 1. Load (Minimal Context)

Use jq to extract only needed data:

```bash
# Functions (name|file:line)
jq -r '.changed_files[] | .path as $p | .new_symbols[] | select(.type == "function") | "\(.name)|\($p):\(.line)"' .pr-review-temp/pr-context.json

# Types (name|file:line)
jq -r '.changed_files[] | .path as $p | .new_symbols[] | select(.type != "function" and .type != "property") | "\(.name)|\($p):\(.line)"' .pr-review-temp/pr-context.json

# Signature changes (method|old_sig|new_sig|file:line|change_type)
jq -r '.signature_changes[] | "\(.method)|\(.old_signature)|\(.new_signature // "")|\(.file):\(.line)|\(.change_type)"' .pr-review-temp/pr-context.json
```

### 2. Resume

`Glob(".pr-review-temp/*-analysis.json")` → check existing outputs.

Skip agent if file exists: `dry-analysis.json` → pr-dry-analyzer, `breaking-analysis.json` → pr-breaking-analyzer, `solid-analysis.json` → pr-solid-analyzer.

If all exist: report "All cross-checks already complete" → exit.

### 3. Spawn Agents

Spawn ALL applicable agents (not skipped) in ONE message with `run_in_background: true`:

```
Task(run_in_background: true,
     subagent_type: "pr-review:pr-dry-analyzer",
     prompt: "NEW_FUNCTIONS:\n[list]\nOUTPUT_FILE: .pr-review-temp/dry-analysis.json")

Task(run_in_background: true,
     subagent_type: "pr-review:pr-breaking-analyzer",
     prompt: "SIGNATURE_CHANGES:\n[list]\nOUTPUT_FILE: .pr-review-temp/breaking-analysis.json")

Task(run_in_background: true,
     subagent_type: "pr-review:pr-solid-analyzer",
     prompt: "NEW_TYPES:\n[list]\nNEW_FUNCTIONS:\n[list]\nOUTPUT_FILE: .pr-review-temp/solid-analysis.json")
```

Spawn if: new_functions → pr-dry-analyzer, signature_changes → pr-breaking-analyzer, new_types OR new_functions → pr-solid-analyzer.

Collect returned `task_id` for each spawned agent.

Report: `Spawned N cross-check agents`

### 4. Poll for Completion

For each `task_id` from step 3:

```
TaskOutput(task_id: [id], block: false, timeout: 5000)
```

**Poll loop:**
- Initial wait: 2 seconds before first poll
- Poll interval: 2 seconds
- Per-agent timeout: 5 minutes (300s)

**Completion criteria (TaskOutput status):**
- `status: "completed"` → Task finished
- `status: "failed"` → Task crashed, record error

Report during polling: `Polling... X/Y complete`

### 5. Final Report

```
DRY: done/skipped/failed | Breaking: done/skipped/failed | SOLID: done/skipped/failed
```

**Next step:** To generate the final report, run: `Create review report for PR [N]`
