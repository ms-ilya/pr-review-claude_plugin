# PR Review Plugin

Multi-agent PR review for Swift codebases.

## Installation

Add to Claude Code plugins.

## Usage

Run commands in order using natural language:

```
# 1. Extract PR context
Extract context for PR 170

# 2. Analyze each file
Analyse PR 170 files

# 3. Check cross-file issues
Check cross-file issues for PR 170

# 4. Generate report
Create review report for PR 170
```

## Commands

| Stage | Trigger | Description |
|-------|---------|-------------|
| 1. Extract | "Extract context for PR 170" | Fetch PR metadata and diff from GitHub |
| 2. Analyze | "Analyse PR 170 files" | Run per-file review (style, quality, unused code) |
| 3. Cross-check | "Check cross-file issues for PR 170" | Find DRY violations, breaking API changes, SOLID issues |
| 4. Report | "Create review report for PR 170" | Generate final markdown report |

## Output

- Temp files: `.pr-review-temp/`
- Final report: `pr-review-temp.md`

## Resumption

If interrupted, re-run the same command to continue:
- Analyze skips already-processed files
- Cross-check skips if outputs exist
- Report can be re-run safely

## Requirements

- GitHub CLI (`gh`) authenticated
- Swift files in PR
