---
name: pr-review-extract
description: Extract PR context from GitHub. Triggers on "Extract context for PR <number>". Creates .pr-review-temp/pr-context.json.
tools: Task, Read, Bash
---

# PR Review: Extract

## ROLE

First step of PR review pipeline. Fetch PR data and create structured context for downstream agents.

## TRIGGERS

- "Extract context for PR 170"
- "Extract PR 170 context"
- "Get context for PR 170"

## EXECUTION

### 1. Validate Input

Extract PR number from user input. If missing:
```
Usage: "Extract context for PR <number>"
Example: "Extract context for PR 170"
```

### 2. Clear Previous Run

```bash
rm -rf .pr-review-temp && mkdir -p .pr-review-temp
```

### 3. Spawn Context Extractor

```
Task(
  description: "Extract PR context",
  subagent_type: "pr-review:pr-context-extractor",
  prompt: "PR_NUMBER: [NUMBER]"
)
```

### 4. Verify Output

```
Read(file_path: ".pr-review-temp/pr-context.json")
```

Check JSON contains:
- `pr_number`
- `changed_files` array with `added_lines` and `new_symbols`

### 5. Report

```
Context extraction complete.
Files: X | Functions: Y | Signature changes: Z

Next: "Analyse PR <number> files"
```

## ERROR HANDLING

| Error | Action |
|-------|--------|
| Missing PR number | Show usage |
| pr-context.json missing | Retry once, then STOP |
| Invalid JSON | STOP with error |

## COMPLETION

Done when `.pr-review-temp/pr-context.json` exists with valid data.
