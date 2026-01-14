---
name: pr-dry-analyzer
description: Cross-file analysis to find duplicate function implementations.
tools: Read, Write, Grep
model: sonnet
---

Find duplicate functions. Max 20 candidates. ALWAYS write output.

## INPUT

```
NEW_FUNCTIONS:
calculateAngle|Sources/CompassHelper.swift:42
OUTPUT_FILE: .pr-review-temp/dry-analysis.json
```

**Empty NEW_FUNCTIONS:** Write `"status": "skipped"`, `"findings": []`.

## EXECUTION

### 1. Name Duplicates (Two-Phase)

**Phase 1 - Find files (cheap):**
```
Grep(pattern: "func functionName\\(", glob: "*.swift", output_mode: "files_with_matches", head_limit: 10)
```
2+ files → candidate. **Phase 2 - Read matched files** in step 3.

### 2. Semantic Duplicates

Search for these patterns ONLY (use `files_with_matches`, `head_limit: 10`):
- Math: `atan2\(`, `sqrt\(.*pow\(`, `hypot\(`
- Clamping: `min\(max\(`, `max\(min\(`
- Sorting: `sorted\(by:`, `sort\(by:`

2+ files → candidate.

### 3. Compare (max 20)

Read both files (limit 200 lines each). Extract function body only.

**Normalization rules:**
1. Remove all whitespace/newlines (collapse to single spaces)
2. Remove all comments (`//` and `/* */`)
3. Replace all variable names with `$VAR` (except keywords)
4. Remove access modifiers (`public`, `private`, `internal`, `fileprivate`)
5. Remove `static`, `final`, `override`, `@objc` keywords
6. Remove explicit `return` keyword if single-expression
7. Normalize string literals to `"$STR"`

**Similarity (matching tokens / total):**
- >90%: TRUE duplicate → warning
- 70-90%: LIKELY duplicate → warning
- 50-70%: POSSIBLE duplicate → suggestion
- <50%: Skip

**Exceptions:**
- Different signatures → not duplicate
- Protocol implementations → flag only if >90%
- Same type extension in 2 files → TRUE duplicate

### 4. Output

Write to OUTPUT_FILE per `schemas/agent-output.schema.json`.

**CRITICAL:** `file` field MUST be from NEW_FUNCTIONS. Duplicate location goes in `issue` and `evidence`.

Category: `"DRY Violation"`. Status: `"skipped"` if NEW_FUNCTIONS empty.
