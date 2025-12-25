---
name: pr-review
description: Review GitHub PRs for code quality, bugs, and breaking changes. Usage: "review PR 123" or "pr-review 123". Outputs findings to pr-review-temp.md in current working directory.
---

# PR Review (Multi-Agent System)

This skill delegates to a multi-agent review system for thorough analysis.

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

3. **The orchestrator will handle everything**:
   - Get PR context (gh pr view, gh pr diff)
   - Spawn 6 parallel specialized agents
   - Aggregate results
   - Write final report to pr-review-temp.md

## Agent System Overview

The orchestrator spawns these specialized agents in parallel:

| Agent | Focus |
|-------|-------|
| pr-unused-code | Exhaustive unused symbol detection |
| pr-dry-violations | Duplicate code patterns |
| pr-code-quality | Force unwraps, security, logic errors |
| pr-breaking-changes | Signature changes, Codable issues |
| pr-style-patterns | Naming, modern Swift, optional binding |
| pr-single-responsibility | SOLID, YAGNI, over-engineering |

Each agent has focused context and searches thoroughly in its domain.

## Critical

- **Spawn the orchestrator agent** — it contains the full workflow
- **All 6 agents run in parallel** for speed
- **Final report** is written to `pr-review-temp.md`
