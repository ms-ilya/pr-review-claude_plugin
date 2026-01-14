---
name: pr-review-analyze
description: Per-file analysis with parallel background agents. Triggers on "Analyse PR <number> files".
tools: Task, Bash, Glob, TaskOutput
---

## EXECUTION

### 1. Load (Minimal Context)

Use jq to extract only file list (NOT full JSON):

```bash
jq -r '.changed_files[] | select(.change_type != "deleted") | "\(.path)|\(.added_lines | @json)|\(.new_symbols | @json)"' .pr-review-temp/pr-context.json
```

Output format per line: `path|["42-50","88"]|[symbols json]`

If file missing: report "Run 'Extract context for PR [N]' first" → exit.

If output empty: report "No analyzable files" → exit.

### 2. Resume

`Glob(".pr-review-temp/review-*.json")` → build set of completed SafePaths.

SafePath: replace `/` with `--`, spaces with `__`, dots with `_DOT_`, remove `.swift` extension only.

Filter `changed_files` to only files WITHOUT existing `review-[SAFEPATH].json`.

If all files processed: report "All files already processed" → exit.

### 3. Batch

Group remaining files into batches of 5.

### 4. Process Each Batch (Parallel)

**Spawn ALL files in batch in ONE message with `run_in_background: true`:**

```
Task(run_in_background: true,
     subagent_type: "pr-review:pr-file-analyzer",
     prompt: "FILE_PATH: [path]
ADDED_LINES: [\"42-50\", \"88\"]
NEW_SYMBOLS: [JSON array]
OUTPUT_FILE: .pr-review-temp/review-[SAFEPATH].json")
```

Collect returned `task_id` for each spawned agent.

Report: `Spawned batch X/Y (N files)`

### 5. Poll for Completion

For each `task_id` from step 4:

```
TaskOutput(task_id: [id], block: false, timeout: 5000)
```

**Poll loop:**
- Initial wait: 2 seconds before first poll
- Poll interval: 2 seconds
- Per-task timeout: 5 minutes (300s)
- Batch timeout: 10 minutes (600s)

**Completion criteria (TaskOutput status):**
- `status: "completed"` → Task finished
- `status: "failed"` → Task crashed, mark for retry

Report during polling: `Polling... X/Y complete`

### 6. Handle Failures

Failed files requeued to next batch. Max retries per file: 2. After max retries: record in final report, continue.

Report on failure: `Batch X/Y: N file(s) failed, requeuing`

### 7. Count Findings

After batch completes, count using jq (NOT Read):

```bash
jq -s '[.[].findings | length] | add' .pr-review-temp/review-*.json
```

Report: `Batch X/Y complete | Files: A/B | Findings: C`

### 8. Next Batch

Repeat steps 4-7 for remaining batches.

### 9. Final Report

```
Complete. Files: X/Y | Findings: Z | Failed: F
```

If failures exist after all retries:
```
Failed files:
- [path]: [error reason]
```

**Next step:** To check cross-file issues, run: `Check cross-file issues for PR [N]`
