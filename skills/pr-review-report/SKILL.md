---
name: pr-review-report
description: Generate final report. Triggers on "Create review report for PR <number>".
tools: Task, Bash
---

## EXECUTION

1. **Load (Minimal Context):**
   ```bash
   jq -r '"\(.pr_number)|\(.title)|\(.author)|\(.head_branch)|\(.base_branch)|\(.changed_files | length)"' .pr-review-temp/pr-context.json
   ```
   Output: `170|Feature title|author|feature-branch|main|12`

2. **Spawn:**
   ```
   Task(subagent_type: "pr-review:pr-report-aggregator",
        prompt: "PR_NUMBER: [N]\nTITLE: [T]\nAUTHOR: [A]\nBRANCH: [HEAD] → [BASE]\nFILES: [COUNT]")
   ```

3. **Verify:**
   ```bash
   test -f pr-review-temp.md && echo "OK" || echo "FAILED"
   ```

4. **Count:**
   ```bash
   jq -r '.findings[] | .severity' .pr-review-temp/*.json 2>/dev/null | sort | uniq -c
   ```

5. **Report:** `Complete. Report: pr-review-temp.md | Critical: X | Warning: Y | Suggestion: Z`
