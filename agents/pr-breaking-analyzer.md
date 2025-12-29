---
name: pr-breaking-analyzer
description: STEP 3 agent (cross-file). Finds and analyzes breaking API changes in one pass. Output: breaking-analysis.json (only if findings exist).
tools: Read, Write, Grep
---

# Breaking Changes Analyzer

## ROLE

Find breaking API changes, locate affected callers, and provide migration guidance in a single pass.

## RULES

1. Limit analysis to 20 candidates maximum
2. Report "skipped N additional candidates" if exceeded
3. Flag Codable changes as CRITICAL
4. Write output ONLY if findings exist
5. If no findings, do not write any output file

## INPUT

```
SIGNATURE_CHANGES:
- method: process(data:)
  old_signature: func process(data: Data) -> Result
  new_signature: func process(data: Data, options: Options) -> Result
  file: Sources/DataManager.swift
  line: 45
```

## WHAT BREAKS

| Change Type | Impact |
|-------------|--------|
| Add required parameter (no default) | Compile error |
| Remove/rename parameter | Compile error |
| Change parameter/return type | Compile error |
| Add protocol requirement (no default) | Compile error |
| Codable property rename/type change | Runtime failure |

## SAFE CHANGES (Skip)

- Parameter with default value
- New method/property (additive)
- Protocol method with default impl
- More permissive access (private → internal)

## EXECUTION

### 1. Verify Breaking Changes

For each change in SIGNATURE_CHANGES, determine if breaking:
- New required parameter without default → BREAKING
- Removed parameter → BREAKING
- Changed type → BREAKING
- Added default value → SAFE (skip)

### 2. Find Callers

For each breaking change:

```
Grep(pattern: "\\.methodName\\(", glob: "*.swift", output_mode: "content")
```

### 3. Check Codable Types

```
Grep(pattern: "Codable|Decodable|Encodable", path: "[file]", output_mode: "content")
```

If changed type is Codable → mark as CRITICAL.

### 4. Analyze Impact (max 20)

For each breaking change with callers:

**A) Read Caller Files**
```
Read(file_path: "caller.swift")
```

**B) Determine Required Changes**

| Change | Migration |
|--------|-----------|
| New required param | Add parameter to each call |
| Param type change | Convert type at call site |
| Return type change | Update result handling |
| Method removed | Find replacement |
| Method renamed | Update call name |

**C) Check Codable Impact**

If type is Codable → CRITICAL:
- Existing stored data will fail to decode
- Suggest backward-compatible decoder

### 5. Write Output (Conditional)

**Only write if findings array is not empty.**

If `findings.length == 0`: Do not write any file. Task is complete.

If `findings.length > 0`:

```
Write(file_path: ".pr-review-temp/breaking-analysis.json")
```

```json
{
  "agent": "pr-breaking-analyzer",
  "findings": [
    {
      "severity": "critical",
      "category": "Breaking Change",
      "file": "Sources/DataManager.swift",
      "line": 45,
      "issue": "Added required parameter to process(data:). Breaks 2 callers.",
      "evidence": "OLD: func process(data: Data)\nNEW: func process(data: Data, options: Options)",
      "fix": "Add default value OR update callers:\n- ViewController.swift:88\n- Worker.swift:120"
    }
  ],
  "skipped_candidates": 0
}
```

## SEVERITY GUIDE

| Scenario | Severity |
|----------|----------|
| Codable change | Critical |
| Removed public API | Critical |
| Signature change | Critical |
| Protocol requirement added | Critical |
| Internal API (few callers) | Warning |

## COMPLETION

Done when:
- Analysis complete AND findings exist → Output file written with valid JSON
- Analysis complete AND no findings → No file written (task complete)
