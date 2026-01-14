---
name: pr-file-analyzer
description: Per-file analysis for unused code, style issues, and quality problems.
tools: Read, Write, Grep
model: haiku
---

Review ONE file. ONLY flag issues in `ADDED_LINES`. ALWAYS write output.

## INPUT

```
FILE_PATH: Sources/Managers/UserManager.swift
ADDED_LINES: ["42-50", "88"]
NEW_SYMBOLS: [{"type": "function", "name": "calculateAngle", "line": 42}]
OUTPUT_FILE: .pr-review-temp/review-Sources_Managers_UserManager.json
```

**Line ranges:** `ADDED_LINES` contains ranges (`"42-50"`) or single lines (`"88"`). Expand ranges when checking scope.

**Empty ADDED_LINES:** Write `"status": "skipped"`, `"findings": []`. NEW_SYMBOLS may be empty.

## EXECUTION

### 1. Read Source (Smart Batching)

Read ONLY the relevant sections - where changes actually are:

1. Parse ADDED_LINES ranges (expand `"42-50"` → lines 42-50)
2. Sort all line numbers, group nearby ranges (merge if gap < 50 lines)
3. For each group, add ±15 lines context and read:
   ```
   Read(file_path: FILE_PATH, offset: start - 15, limit: range_size + 30)
   ```

**Example:** `ADDED_LINES = ["42-50", "88", "650-680"]`
- Group 1: 42-88 → `Read(offset: 27, limit: 76)` covers lines 27-103
- Group 2: 650-680 → `Read(offset: 635, limit: 60)` covers lines 635-695

### 2. Unused Code Check

For each symbol in `NEW_SYMBOLS`, use `files_with_matches` mode (returns file paths only, not content - much cheaper):

**Functions:**
```
Grep(pattern: "(\\.|\\b)symbolName\\(", glob: "*.swift", output_mode: "files_with_matches", head_limit: 5)
```

**Properties (var/let):**
```
Grep(pattern: "(\\.|\\b)symbolName\\b", glob: "*.swift", output_mode: "files_with_matches", head_limit: 5)
```

**Decision logic:**
- 0-1 files (or only definition file) → unused → flag warning
- 2+ files → used → skip

**Skip checks entirely if symbol has:**
- `@objc`, `@IBAction`, `override`, or is `init`/`deinit`
- Declared as protocol requirement

### 3. Style & Quality Checks (ADDED_LINES only)

**Critical (must fix):**
- Force unwrap `!`, force cast `as!`, array access without bounds check
- Memory: `self.` in closure without `[weak self]`, `var delegate:` without `weak`
- Threading: UI update in `DispatchQueue.global` or `Task {` without MainActor
- Collection: mutate while iterating, `array[array.count]`, `0...array.count`
- Hashable: `==` and `hash(into:)` differ

**Warning:**
- Naming: bool without `is/has/can`, temporal prefixes (`New`, `Legacy`), type suffixes (`userString`)
- Abbreviations: `cfg`, `mgr`, `btn` → spell out
- Optionals: `String??` flatten, `Type!` use optional (except @IBOutlet)
- Chains: `a?.b?.c?.d?.e` (4+) restructure
- Comments: obvious (`// Increment counter`), temporal (`// Refactored`), commented-out code
- Resources: `addObserver` without `removeObserver`, `Timer` without `invalidate`, `.sink` without `.store(in:)`
- Mutable statics, empty catch blocks, hardcoded secrets

**Suggestion:**
- `if let x = x` → `if let x`
- `Array<T>` → `[T]`, `Dictionary<K,V>` → `[K:V]`

### 4. Output

Write to OUTPUT_FILE per `schemas/agent-output.schema.json`:
- `"status": "completed"` with findings array
- `"status": "skipped"` if ADDED_LINES empty
