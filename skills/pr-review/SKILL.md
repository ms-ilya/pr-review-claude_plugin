---
name: pr-review
description: Review GitHub PRs for code quality, bugs, and breaking changes. Usage: "review PR 123" or "pr-review 123". Optimized for large PRs (60+ files). Outputs findings to pr-review-temp.md.
tools: Task
---

# PR Review (Multi-Agent System v2)

This skill delegates to a multi-agent review system optimized for large PRs.

## How to Use

User says: "Review PR 170" or "pr-review 170"

## Your Task

1. **Extract PR number** from user input

2. **Use the Task tool to spawn the orchestrator**:
   ```
   Task(
     description: "PR review orchestration",
     subagent_type: "pr-review-orchestrator",
     prompt: "Review PR #[NUMBER]"
   )
   ```

3. **The orchestrator handles everything** using a phased approach:
   - Phase 1: File-level review (3 agents per file, all in parallel)
   - Phase 2: Cross-file analysis (DRY and Breaking Changes dispatchers)
   - Phase 3: Aggregation into final report

## Architecture (v2 - Large PR Optimized)

```
Phase 1: File-Level Review (3 agents per file, all parallel)
├── For each file:
│   ├── pr-file-review       → file-*.json
│   ├── pr-file-style-deep   → style-deep-*.json
│   └── pr-file-quality-deep → quality-deep-*.json

Phase 2: Cross-File Analysis (dispatchers spawn sub-agents)
├── DRY Dispatcher → comparison sub-agents → dry-*.json
└── Breaking Changes Dispatcher → impact sub-agents → breaking-*.json

Phase 3: Aggregation
└── Aggregator → pr-review-temp.md
```

## Agent System

### Phase 1: File-Level Agents (3 per file)
| Agent | Focus |
|-------|-------|
| pr-file-review | Unused code, basic style, basic quality, single responsibility |
| pr-file-style-deep | Naming details, modern Swift syntax, optional patterns, comment quality |
| pr-file-quality-deep | Memory management, concurrency, logic errors, data integrity |

Three agents per file run in parallel. Each writes findings immediately (no context overflow).

### Phase 2: Cross-File Dispatchers
| Agent | Focus |
|-------|-------|
| pr-dry-dispatcher | Finds potential duplicates, spawns comparison agents |
| pr-breaking-dispatcher | Finds signature changes, spawns impact agents |

Dispatchers stay lightweight — they search for patterns and delegate detailed analysis.

### Phase 2 Sub-Agents
| Agent | Focus |
|-------|-------|
| pr-dry-comparison | Compares two functions for duplication |
| pr-breaking-impact | Analyzes impact of breaking change on callers |

Sub-agents are short-lived and write findings immediately.

### Phase 3: Aggregator
| Agent | Focus |
|-------|-------|
| pr-report-aggregator | Combines all JSON files into final markdown report |

## Why This Architecture?

The v2 architecture solves context overflow on large PRs:

| Problem | Solution |
|---------|----------|
| 60+ files exhaust agent context | Three lightweight agents per file |
| Agents crash before writing output | Write findings immediately |
| Thoroughness vs scalability | Split checks across specialized agents |
| Cross-file analysis needs full codebase | Dispatchers search patterns, sub-agents do detailed work |
| All or nothing results | Partial results saved even if some agents fail |

## Critical

- **Spawn the orchestrator agent** — it contains the full workflow
- **Each file gets dedicated review** — no skipping due to context limits
- **Final report** is written to `pr-review-temp.md`
- **Temp files** are preserved in `pr-review-temp/` for debugging
