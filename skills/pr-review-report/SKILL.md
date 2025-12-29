---
name: pr-review-report
description: Generate final PR review report. Triggers on "Create review report for PR <number>". Outputs pr-review-temp.md.
tools: Task, Read, Glob
---

# PR Review: Report

## ROLE

Final step of PR review pipeline. Aggregate all findings into a markdown report.

## TRIGGERS

- "Create review report for PR 170"
- "Generate PR 170 report"
- "Finish PR 170 review"

## PREREQUISITES

`.pr-review-temp/pr-context.json` must exist. Run "Extract context for PR <number>" first.

## EXECUTION

### 1. Load Context

```
Read(file_path: ".pr-review-temp/pr-context.json")
```

If missing: `Run "Extract context for PR <number>" first.`

Extract: `pr_number`, `title`, `author`, `head_branch`, `base_branch`, `changed_files.length`

### 2. Count Available Findings

```
Glob(pattern: ".pr-review-temp/*.json")
```

Exclude `pr-context.json`. Count finding files available.

### 3. Spawn Report Aggregator

```
Task(
  description: "Generate report",
  subagent_type: "pr-review:pr-report-aggregator",
  prompt: "PR_NUMBER: [NUMBER]\nTITLE: [TITLE]\nAUTHOR: [AUTHOR]\nBRANCH: [HEAD] -> [BASE]\nFILES: [COUNT]"
)
```

### 4. Verify Output

```
Read(file_path: "pr-review-temp.md")
```

Check report contains:
- Summary table
- Findings sections

### 5. Retry If Failed (Max 2)

Re-spawn aggregator if report missing or malformed.

### 6. Report

```
PR Review complete.
Report: pr-review-temp.md

Summary:
- Critical: X
- Warning: Y
- Suggestion: Z
```

## OUTPUT

| File | Location |
|------|----------|
| `pr-review-temp.md` | Project root |

## ERROR HANDLING

| Error | Action |
|-------|--------|
| Context missing | "Run extract first" |
| No findings | Generate report with "No issues found" |
| Aggregator fails | Retry twice, then STOP |

## COMPLETION

Done when `pr-review-temp.md` exists in project root.
