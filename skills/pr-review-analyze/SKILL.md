---
name: pr-review-analyze
description: Per-file analysis for PR review. Triggers on "Analyse PR <number> files". Requires extract step first.
tools: Task, Read, Glob
---

# PR Review: Analyze

## ROLE

Second step of PR review pipeline. Spawn per-file review agents for each changed file.

## TRIGGERS

- "Analyse PR 170 files"
- "Analyze PR 170 files"
- "Review PR 170 files"

## PREREQUISITES

`.pr-review-temp/pr-context.json` must exist. Run "Extract context for PR <number>" first.

## EXECUTION

### 1. Load Context

```
Read(file_path: ".pr-review-temp/pr-context.json")
```

If missing: `Run "Extract context for PR <number>" first.`

Extract `changed_files` array.

### 2. Check Existing Progress

```
Glob(pattern: ".pr-review-temp/review-*.json")
```

Skip files that already have output (note: files with no findings won't have output).

### 3. Process Files in Batches

Batch size: 5 files (5 agents per batch).

For each file, convert path to SafePath:
- Replace `/` with `_`
- Replace spaces with `_`
- Remove `.swift` extension

**Spawn 1 agent per file in ONE message:**

```
Task(
  description: "Analyze: [FILENAME]",
  subagent_type: "pr-review:pr-file-analyzer",
  prompt: "FILE_PATH: [path]\nADDED_LINES: [JSON]\nNEW_SYMBOLS: [JSON]\nOUTPUT_FILE: .pr-review-temp/review-[SAFEPATH].json"
)
```

### 4. Track Progress

Agents only write output if findings exist. Track completion by counting returned agents, not output files.

### 5. Retry Failed Files (Max 1)

Re-spawn agents for failed tasks using same format.

### 6. Report

```
Analysis complete.
Files processed: X/Y
Review outputs: Z files with findings

Next: "Check cross-file issues for PR <number>"
```

## IDEMPOTENCY

Re-running may re-analyze files with no findings (no way to distinguish from unprocessed). Safe to resume after interruption.

## ERROR HANDLING

| Error | Action |
|-------|--------|
| Context missing | "Run extract first" |
| Agent fails | Retry once, then continue |
| Partial completion | Report counts, continue |

## COMPLETION

Done when all files have been processed (agents completed or retries exhausted).
