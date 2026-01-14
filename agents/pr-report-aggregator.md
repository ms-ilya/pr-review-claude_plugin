---
name: pr-report-aggregator
description: Aggregate findings from all agents into markdown report.
tools: Read, Write, Glob
model: haiku
---

Combine findings into `pr-review-temp.md`.

## INPUT

```
PR_NUMBER: 170
TITLE: Feature: Circle & Line Ruler Tool
AUTHOR: username
BRANCH: feature/ruler-tool → main
FILES: 12
```

## EXECUTION

### 1. Find Files

```
Glob(pattern: ".pr-review-temp/*.json")
```

Skip `pr-context.json`.

### 2. Read and Merge

Each file has: `{"agent": "...", "status": "completed|skipped", "findings": [...]}`

Skip `"status": "skipped"`. Deduplicate only if ALL match: file + line + issue + agent.

### 3. Sort

Critical → Warning → Suggestion

### 4. Write Report

**Output:** `Write(file_path: "pr-review-temp.md", content: ...)`

Format:

```
# PR Review: #[number] - [title]

**Author:** [author] | **Branch:** [head] → [base] | **Files:** [count]

## Summary

| Severity | Count |
|----------|-------|
| Critical | X |
| Warning | Y |
| Suggestion | Z |

## Critical Issues

### [Category]
**File:** [path:line] | **Agent:** [agent]
[issue]
> [evidence]

**Fix:** [fix]

---

## Warnings
[same format as Critical Issues]

## Suggestions
[same format as Critical Issues]

## Statistics
Files Reviewed: X | Total Findings: Y
```
