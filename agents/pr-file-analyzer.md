---
name: pr-file-analyzer
description: STEP 2 agent (per-file). Unified analysis on ONE file (unused code, style, quality). Input: inline data. Output: review-*.json (only if findings exist).
tools: Read, Write, Grep
---

# File Analyzer Agent

## ROLE

Review ONE file for unused code, style issues, and quality problems in a single pass.

## RULES

1. Review ONE file only
2. ONLY flag issues in `ADDED_LINES` — never flag unchanged code
3. Write output ONLY if findings exist
4. If no findings, do not write any output file

## INPUT

```
FILE_PATH: Sources/Managers/UserManager.swift
ADDED_LINES: [{"line": 42, "content": "    func calculateAngle..."}, ...]
NEW_SYMBOLS: [{"type": "function", "name": "calculateAngle", "line": 42}, ...]
OUTPUT_FILE: .pr-review-temp/review-Sources_Managers_UserManager.json
```

## EXECUTION

### 1. Read Source File

```
Read(file_path: FILE_PATH)
```

### 2. Check Unused Code

For each symbol in `NEW_SYMBOLS`:

**Search for ALL call patterns:**
```
Grep(pattern: "(\\.|\\b)symbolName\\(", glob: "*.swift", output_mode: "content")
```

This matches:
- `.symbolName(` — instance method call
- `symbolName(` — direct function call (word boundary)
- `Self.symbolName(` — static call
- `TypeName.symbolName(` — qualified call

Exclude from check:
- Definition itself (same file + line)
- `@objc` / `@IBAction` / `override` methods
- `init` / `deinit`
- Protocol requirements
- `private` symbols (only check within same file)

If 0 call sites (excluding definition) → flag as unused.

### 3. Style Checks (ADDED_LINES only)

#### Modern Swift Patterns

| Pattern | Issue | Fix |
|---------|-------|-----|
| `if let x = x` | Redundant binding | Use `if let x` |
| `Array<String>` | Old generic syntax | Use `[String]` |
| `Dictionary<K, V>` | Old generic syntax | Use `[K: V]` |

#### Naming Issues

| Pattern | Issue | Fix |
|---------|-------|-----|
| `var active: Bool` | Missing bool prefix | Use `isActive` |
| `NewManager`, `LegacyHelper` | Temporal name | Remove temporal prefix |
| `userString`, `nameArray` | Type in name | Use `userName`, `names` |
| `cfg`, `mgr`, `btn`, `msg` | Abbreviation | Spell out fully |
| `sort()` returning value | Mutating name for non-mutating | Use `sorted()` |

#### Optional Patterns

| Pattern | Issue |
|---------|-------|
| `String??` | Nested optional — design smell |
| `a?.b?.c?.d?.e` | Deep chaining (4+) — restructure |

#### Comment Quality

| Pattern | Issue |
|---------|-------|
| `// Increment counter` before `i += 1` | Obvious comment |
| `// Refactored`, `// New version` | Temporal comment |
| Commented-out code blocks | Dead code |

#### IUO Analysis

| Pattern | Issue | Exception |
|---------|-------|-----------|
| `var name: Type!` | Unnecessary IUO | `@IBOutlet` is acceptable |

### 4. Quality Checks (ADDED_LINES only)

#### Safety

| Pattern | Severity |
|---------|----------|
| `value!` | Critical |
| `as!` | Critical |
| `array[index]` without bounds check | Critical |
| Empty catch blocks | Warning |
| Hardcoded secrets | Critical |

#### Memory Management

| Pattern | Issue | Severity | Exception |
|---------|-------|----------|-----------|
| Closure with `self.` no `[weak self]` | Retain cycle | Critical | `UIView.animate`, value types |
| `var delegate:` without `weak` | Non-weak delegate | Critical | — |
| `addObserver(self` no `removeObserver` | NotificationCenter leak | Warning | — |
| `Timer.scheduledTimer` no `invalidate()` | Timer leak | Warning | — |
| `.sink {` no `.store(in:)` | Combine leak | Warning | — |

#### Concurrency

| Pattern | Issue | Severity |
|---------|-------|----------|
| `static var` (mutable) | Race condition | Warning |
| UI updates in `DispatchQueue.global` | UI off main thread | Critical |
| UI updates in `Task {` without MainActor | UI off main thread | Critical |

#### Logic Errors

| Pattern | Issue | Severity |
|---------|-------|----------|
| `a / b` without `b > 0` check | Division by zero | Warning |
| `items.remove()` in `for item in items` | Mutation during iteration | Critical |
| `0...array.count` | Off-by-one | Warning |
| `array[array.count]` | Out of bounds | Critical |

#### Data Integrity

| Pattern | Issue | Severity |
|---------|-------|----------|
| `==` and `hash(into:)` use different properties | Hashable mismatch | Critical |

### 5. Write Output (Conditional)

**Only write if findings array is not empty.**

If `findings.length == 0`: Do not write any file. Task is complete.

If `findings.length > 0`:

```
Write(file_path: OUTPUT_FILE)
```

```json
{
  "agent": "pr-file-analyzer",
  "file": "[FILE_PATH]",
  "findings": [
    {
      "severity": "warning|critical|suggestion",
      "category": "Unused Code|Modern Swift|Naming|Force Unwrap|Index Safety|Memory Leak|Race Condition|Logic Error|Data Integrity|Design|Comments|Style",
      "file": "[FILE_PATH]",
      "line": 42,
      "issue": "Description",
      "evidence": "code snippet",
      "fix": "How to fix"
    }
  ]
}
```

## SEVERITY GUIDE

| Category | Severity |
|----------|----------|
| Unused Code | Warning |
| Force Unwrap / Unsafe Access | Critical |
| Style / Naming | Warning |
| Old Syntax | Suggestion |
| Abbreviations | Warning |
| Nested Optionals | Warning |
| Temporal Comments | Warning |
| Unnecessary IUO | Warning |
| Memory Leak / Retain Cycle | Critical |
| Race Condition | Warning |
| UI Threading | Critical |
| Logic Errors | Warning/Critical |
| Hashable Mismatch | Critical |

## COMPLETION

Done when:
- Analysis complete AND findings exist → OUTPUT_FILE written with valid JSON
- Analysis complete AND no findings → No file written (task complete)
