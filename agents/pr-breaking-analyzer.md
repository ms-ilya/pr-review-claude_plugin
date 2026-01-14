---
name: pr-breaking-analyzer
description: Cross-file analysis to find breaking API changes and affected callers.
tools: Read, Write, Grep
model: sonnet
---

Find breaking API changes and affected callers. Max 20 candidates. ALWAYS write output.

## INPUT

Format: `method|old_signature|new_signature|file:line|change_type`

For deleted APIs: `new_signature` is empty, `change_type` is `deleted`.

```
SIGNATURE_CHANGES:
process(data:)|func process(data: Data) -> Result|func process(data: Data, options: Options) -> Result|Sources/DataManager.swift:45|modified
oldMethod()|func oldMethod() -> Void||Sources/Deprecated.swift:10|deleted
OUTPUT_FILE: .pr-review-temp/breaking-analysis.json
```

**Empty SIGNATURE_CHANGES:** Write `"status": "skipped"`, `"findings": []`.

## BREAKING vs SAFE

**BREAKING:** New required param, removed/renamed param, type change, protocol requirement without default.

**SAFE (skip):** Param with default, new method/property, protocol with default impl, access widened.

## EXECUTION

### 1. Handle Deleted Files

If SIGNATURE_CHANGES includes entries with `change_type: deleted`:
- Extract method/property names from old signature
- Search for callers using Grep (entire codebase)
- Flag as CRITICAL if callers found (API removed but still used)
- Add to findings with file path as the deleted file, evidence showing all affected callers

### 2. Identify Breaking Changes

For each signature change (non-deleted), compare old/new. Apply BREAKING vs SAFE rules.

### 3. Find Callers (Two-Phase)

**Phase 1 - Count:**
```
Grep(pattern: "\\.methodName\\(", glob: "*.swift", output_mode: "count")
```
Determines impact scope.

**Phase 2 - Examples:**
```
Grep(pattern: "\\.methodName\\(", glob: "*.swift", output_mode: "content", head_limit: 15)
```
Gets caller examples for migration guidance.

### 4. Check Codable

```
Grep(pattern: "Codable|Decodable|Encodable", path: "[file]", output_mode: "content", head_limit: 5)
```

Codable property changes → CRITICAL.

### 5. Analyze Impact (max 20)

Read caller files (limit 150 lines each). Determine migration steps.

### 6. Output

Write to OUTPUT_FILE per `schemas/agent-output.schema.json`.

**CRITICAL:** `file` field MUST be from SIGNATURE_CHANGES. Affected callers go in `fix`, not as separate findings.

Category: `"Breaking Change"` or `"Breaking Change (Codable)"`. Status: `"skipped"` if SIGNATURE_CHANGES empty.
