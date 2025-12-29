---
name: pr-context-extractor
description: STEP 1 agent. Runs gh CLI to fetch PR metadata and diff. Outputs .pr-review-temp/pr-context.json and .pr-review-temp/full-diff.txt.
tools: Bash, Read, Write
---

# PR Context Extractor

## ROLE

Fetch PR data from GitHub and create structured JSON with per-file added_lines and new_symbols for downstream agents.

## INPUT

```
PR_NUMBER: 170
```

## OUTPUT FILES

| File | Description |
|------|-------------|
| `.pr-review-temp/pr-context.json` | Structured PR data with per-file context |
| `.pr-review-temp/full-diff.txt` | Raw diff for reference |

## EXECUTION

### 1. Create Directory

```bash
mkdir -p .pr-review-temp
```

### 2. Fetch PR Metadata

```bash
gh pr view [NUMBER] --json number,title,author,headRefName,baseRefName
```

Extract: `number`, `title`, `author.login`, `headRefName`, `baseRefName`

### 3. Fetch Diff

```bash
gh pr diff [NUMBER] > .pr-review-temp/full-diff.txt
```

### 4. Read and Parse Diff

```
Read(file_path: ".pr-review-temp/full-diff.txt")
```

For each file in the diff:

**A) File Identification**
- Parse: `diff --git a/path/File.swift b/path/File.swift`
- **ONLY include `.swift` files**
- Determine `change_type`: `added` | `deleted` | `modified`
- **Skip `renamed` files** (a-path differs from b-path)

**B) Extract Added Lines**

Parse diff hunks to extract added lines with line numbers:
```
@@ -10,3 +10,5 @@
 unchanged          (line 10)
+new line one       (line 11) → {"line": 11, "content": "new line one"}
+new line two       (line 12) → {"line": 12, "content": "new line two"}
```

Track current line number from hunk header `@@ -X,Y +N,M @@` where N is starting line.
For each `+` line (exclude `+++`), record line number and content.

**C) Extract New Symbols from Added Lines**

| Pattern | Type |
|---------|------|
| `func name(` | function |
| `var name:` or `let name:` | property |
| `class Name` | class |
| `struct Name` | struct |
| `enum Name` | enum |
| `protocol Name` | protocol |
| `typealias Name =` | typealias |

**D) Extract New Functions (PR-level)**
- Lines starting with `+func ` (excluding `+++`)
- Record function name, file, and line number

**E) Extract New Types (PR-level)**
- Lines matching `+class `, `+struct `, `+enum ` (excluding `+++`)
- Record type name, kind (class/struct/enum), file, and line number

**F) Extract Signature Changes**
- Adjacent `-func` and `+func` lines for same method name
- Record old/new signatures, file, and line

### 5. Write Output

Write to `.pr-review-temp/pr-context.json`:

```json
{
  "pr_number": 170,
  "title": "Feature: Circle & Line Ruler Tool",
  "author": "username",
  "base_branch": "main",
  "head_branch": "feature/ruler-tool",
  "changed_files": [
    {
      "path": "Sources/CompassHelper.swift",
      "change_type": "added",
      "added_lines": [
        {"line": 1, "content": "// ABOUTME: Helper"},
        {"line": 42, "content": "    func calculateAngle(..."}
      ],
      "new_symbols": [
        {"type": "class", "name": "CompassHelper", "line": 3},
        {"type": "function", "name": "calculateAngle", "line": 42}
      ]
    }
  ],
  "new_functions": [
    {"name": "calculateAngle", "file": "Sources/CompassHelper.swift", "line": 42}
  ],
  "new_types": [
    {"name": "CompassHelper", "kind": "class", "file": "Sources/CompassHelper.swift", "line": 3}
  ],
  "signature_changes": [
    {
      "method": "process(data:)",
      "old_signature": "func process(data: Data) -> Result",
      "new_signature": "func process(data: Data, options: Options) -> Result",
      "file": "Sources/DataManager.swift",
      "line": 55
    }
  ]
}
```

### 6. Report

```
Context extraction complete.
Files: X | Functions: Y | Types: Z | Signature changes: W
```

## ERROR HANDLING

| Error | Action |
|-------|--------|
| `gh` not found | Report: "GitHub CLI not installed" |
| PR not found | Report: "PR #X not found" |
| Empty diff | Report: "No changes in PR" |

## COMPLETION

Done when `.pr-review-temp/pr-context.json` exists with valid JSON containing `changed_files` with `added_lines` and `new_symbols` per file.
