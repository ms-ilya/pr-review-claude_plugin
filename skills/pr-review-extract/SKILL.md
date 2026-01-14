---
name: pr-review-extract
description: Extract PR context from GitHub. Triggers on "Extract context for PR <number>".
tools: Bash
---

## EXECUTION

1. **Validate:** Extract PR number from input. Error if missing.

2. **Clear and Extract:**
   ```bash
   rm -rf .pr-review-temp && ./scripts/extract-pr-context.sh [PR_NUMBER]
   ```

3. **Verify:** Check file exists:
   ```bash
   test -f .pr-review-temp/pr-context.json && echo "OK" || echo "FAILED"
   ```

4. **Report:** Script outputs `Files: X | Symbols: Y | Signatures: Z`

**Next step:** To analyze the files, run: `Analyse PR [N] files`
