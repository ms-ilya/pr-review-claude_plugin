---
name: pr-report-aggregator
description: STEP 4 agent. Reads all agent outputs, creates pr-review-temp.md report.
tools: Read, Write, Glob
---

# Report Aggregator

## ROLE

Combine findings from all agents into a single markdown report.

## INPUT

```
PR_NUMBER: 170
TITLE: Feature: Circle & Line Ruler Tool
AUTHOR: username
BRANCH: feature/ruler-tool → main
FILES: 12
```

## OUTPUT

`pr-review-temp.md`

## EXPECTED FILES

| Pattern | Source |
|---------|--------|
| `.pr-review-temp/review-*.json` | pr-file-analyzer |
| `.pr-review-temp/dry-analysis.json` | pr-dry-analyzer |
| `.pr-review-temp/breaking-analysis.json` | pr-breaking-analyzer |
| `.pr-review-temp/solid-analysis.json` | pr-single-responsibility |

Files only exist if findings were found. Missing files = no issues (not an error).

## EXECUTION

### 1. Find All JSON Files

```
Glob(pattern: ".pr-review-temp/*.json")
```

### 2. Filter and Read Files

Skip:
- `pr-context.json`

Read remaining files. Each has structure:
```json
{
  "agent": "agent-name",
  "findings": [
    {
      "severity": "critical|warning|suggestion",
      "category": "Category",
      "file": "path/to/File.swift",
      "line": 42,
      "issue": "Description",
      "evidence": "code",
      "fix": "Suggested fix"
    }
  ]
}
```

### 3. Combine and Deduplicate

Merge all findings. Deduplicate only if ALL match:
- Same `file`
- Same `line`
- Same `issue` (exact)
- Same `agent`

DO NOT deduplicate different agents on same line.

### 4. Sort by Severity

1. Critical
2. Warning
3. Suggestion

### 5. Generate Report

Write to `pr-review-temp.md`:

```markdown
# PR Review: #[number] - [title]

**Author:** [author] | **Branch:** [head] → [base] | **Files:** [count]

## Summary

| Severity | Count |
|----------|-------|
| Critical | X |
| Warning | Y |
| Suggestion | Z |

---

## Critical Issues

### [Category] - [Brief]
**File:** [path:line]
**Agent:** [agent]
**Issue:** [description]
**Evidence:**
\`\`\`
[code]
\`\`\`
**Fix:** [suggestion]

---

## Warnings

[Same format]

---

## Suggestions

[Same format]

---

## Statistics

| Metric | Value |
|--------|-------|
| Files Reviewed | X |
| Total Findings | Y |
```

## ERROR HANDLING

| Error | Action |
|-------|--------|
| No JSON files found | Report "No findings - all checks passed" |
| Invalid JSON | Skip file, note error |
| Missing findings array | Skip file |

Missing output files are expected when no issues were found. Treat as clean.

## COMPLETION

Done when `pr-review-temp.md` is written.
