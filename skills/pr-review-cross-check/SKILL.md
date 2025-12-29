---
name: pr-review-cross-check
description: Cross-file analysis for DRY violations, breaking changes, and SOLID/architecture issues. Triggers on "Check cross-file issues for PR <number>".
tools: Task, Read, Glob
---

# PR Review: Cross-Check

## ROLE

Third step of PR review pipeline. Analyze cross-file issues: duplicate functions, breaking API changes, and SOLID/architecture violations.

## TRIGGERS

- "Check cross-file issues for PR 170"
- "Cross-check PR 170"
- "Find duplicates in PR 170"

## PREREQUISITES

`.pr-review-temp/pr-context.json` must exist. Run "Extract context for PR <number>" first.

## EXECUTION

### 1. Load Context

```
Read(file_path: ".pr-review-temp/pr-context.json")
```

If missing: `Run "Extract context for PR <number>" first.`

Extract:
- `new_functions` array
- `new_types` array
- `signature_changes` array

### 2. Check Existing Outputs

```
Glob(pattern: ".pr-review-temp/dry-analysis.json")
Glob(pattern: ".pr-review-temp/breaking-analysis.json")
Glob(pattern: ".pr-review-temp/solid-analysis.json")
```

Skip analyzers whose outputs exist (presence means findings were found previously).

### 3. Spawn Analyzers

**Spawn ALL in ONE message (if needed):**

If `new_functions` is non-empty and `dry-analysis.json` missing:
```
Task(
  description: "DRY analysis",
  subagent_type: "pr-review:pr-dry-analyzer",
  prompt: "NEW_FUNCTIONS:\n[FORMAT: - name: X\n  file: Y\n  line: Z]"
)
```

If `signature_changes` is non-empty and `breaking-analysis.json` missing:
```
Task(
  description: "Breaking changes",
  subagent_type: "pr-review:pr-breaking-analyzer",
  prompt: "SIGNATURE_CHANGES:\n[FORMAT: - method: X\n  old_signature: Y\n  new_signature: Z\n  file: F\n  line: L]"
)
```

If (`new_types` is non-empty OR `new_functions` is non-empty) and `solid-analysis.json` missing:
```
Task(
  description: "SOLID analysis",
  subagent_type: "pr-review:pr-single-responsibility",
  prompt: "NEW_TYPES:\n[FORMAT: - name: X\n  file: Y\n  line: Z]\nNEW_FUNCTIONS:\n[FORMAT: - name: X\n  file: Y\n  line: Z]"
)
```

### 4. Track Progress

Agents only write output if findings exist. Track completion by counting returned agents, not output files.

### 5. Retry Failed (Max 1)

Re-spawn failed tasks with same data.

### 6. Report

```
Cross-check complete.
DRY analysis: [done/skipped/failed]
Breaking analysis: [done/skipped/failed]
SOLID analysis: [done/skipped/failed]

Next: "Create review report for PR <number>"
```

## SKIP CONDITIONS

| Condition | Action |
|-----------|--------|
| No new functions | Skip DRY analyzer |
| No signature changes | Skip breaking analyzer |
| No new types AND no new functions | Skip SOLID analyzer |
| Output file exists | Skip (previous run found issues) |

## IDEMPOTENCY

Re-running may re-analyze if no findings were found (no output file = no findings OR not run). Safe to resume.

## ERROR HANDLING

| Error | Action |
|-------|--------|
| Context missing | "Run extract first" |
| Analyzer fails | Retry once, then continue |

## COMPLETION

Done when all three analyses complete (or skipped/retried).
