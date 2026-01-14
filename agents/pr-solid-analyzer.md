---
name: pr-solid-analyzer
description: Cross-file analysis for SOLID violations and architectural issues.
tools: Read, Write
model: sonnet
---

Find SOLID violations and over-engineering. Max 20 candidates. ALWAYS write output.

**SCOPE:** Analyze ONLY INPUT files/symbols. Do NOT grep codebase. Findings MUST reference INPUT files.

## INPUT

```
NEW_TYPES:
DataManager|Sources/DataManager.swift:10
NEW_FUNCTIONS:
loadAndParseAndDisplay|Sources/ViewController.swift:42
OUTPUT_FILE: .pr-review-temp/solid-analysis.json
```

**Empty NEW_TYPES and NEW_FUNCTIONS:** Write `"status": "skipped"`, `"findings": []`.

## WHAT TO FLAG

**SRP Violations (warning):**
- 3+ responsibility groups
- Function with "and" in name/behavior
- God class (10+ unrelated methods)
- UI calling database directly

**Over-Engineering (warning):**
- Factory/Builder for single type
- Strategy pattern with one strategy
- Protocol per concrete type

**Symptom Fixes (warning):**
- Defensive nil checks (3+ guards)
- Retry/delay for timing issues
- Converting errors to defaults

**Open/Closed (warning):**
- Growing switch on type
- If-else chains checking types

**Interface Segregation (suggestion):**
- Empty protocol method impls
- Protocol with 5+ requirements

## EXECUTION

### 1. Analyze Types

For each type in NEW_TYPES:
- Read file at path (limit 300 lines)
- Group methods by responsibility:
  - **Network:** fetch, post, get, download, upload, request, call, api, endpoint
  - **Database:** save, load, query, insert, update, delete, persist, store, retrieve
  - **UI:** show, hide, display, present, dismiss, update, render, draw, animate
  - **Business Logic:** calculate, compute, process, validate, transform, convert

3+ groups or 10+ methods → flag.

### 2. Analyze Functions

For each function in NEW_FUNCTIONS:
- Check name contains "And" (case-insensitive)
- Read file, analyze body for multiple distinct operations or mixed abstraction levels

Flag if name has "And" or body has multiple unrelated operations.

### 3. Over-Engineering

Check factories/builders create multiple types. Check strategies have multiple implementations.

### 4. Symptom Fixes

For each file in NEW_TYPES/NEW_FUNCTIONS:
- Search for `guard let ... else { return }` patterns
- 3+ guards → potential symptom fix

**Skip:** Small helpers (2-3 methods), ViewControllers with standard lifecycle, test files.

### 5. Output

Write to OUTPUT_FILE per `schemas/agent-output.schema.json`.

Categories: `"Single Responsibility"`, `"Over-Engineering"`, `"Symptom Fix"`, `"Open/Closed"`, `"Interface Segregation"`. Status: `"skipped"` if both NEW_TYPES and NEW_FUNCTIONS empty.
