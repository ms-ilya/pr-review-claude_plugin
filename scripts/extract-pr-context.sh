#!/bin/bash
# ABOUTME: Extracts PR context from GitHub and outputs minimal JSON with line ranges.

set -e

PR_NUMBER="$1"
OUTPUT_DIR=".pr-review-temp"
OUTPUT_FILE="$OUTPUT_DIR/pr-context.json"

if [ -z "$PR_NUMBER" ]; then
    echo "Usage: $0 <pr_number>" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Fetch metadata
META=$(gh pr view "$PR_NUMBER" --json number,title,author,headRefName,baseRefName)
TITLE=$(echo "$META" | jq -r '.title')
AUTHOR=$(echo "$META" | jq -r '.author.login')
HEAD=$(echo "$META" | jq -r '.headRefName')
BASE=$(echo "$META" | jq -r '.baseRefName')

# Initialize arrays
declare -a CHANGED_FILES
declare -a SIGNATURE_CHANGES

# Parse diff - process file by file
CURRENT_FILE=""
CURRENT_CHANGE_TYPE=""
CURRENT_LINES=()
CURRENT_SYMBOLS=()
CURRENT_LINE_NUM=0
IN_HUNK=0
PREV_MINUS_FUNC=""

# Function to collapse consecutive lines into ranges
collapse_to_ranges() {
    local lines=("$@")
    local ranges=()
    local start=""
    local prev=""

    for line in "${lines[@]}"; do
        if [ -z "$start" ]; then
            start=$line
            prev=$line
        elif [ $((prev + 1)) -eq "$line" ]; then
            prev=$line
        else
            if [ "$start" -eq "$prev" ]; then
                ranges+=("$start")
            else
                ranges+=("$start-$prev")
            fi
            start=$line
            prev=$line
        fi
    done

    if [ -n "$start" ]; then
        if [ "$start" -eq "$prev" ]; then
            ranges+=("$start")
        else
            ranges+=("$start-$prev")
        fi
    fi

    # Output as JSON array
    printf '%s\n' "${ranges[@]}" | jq -R . | jq -s .
}

# Function to output current file as JSON
output_file() {
    if [ -n "$CURRENT_FILE" ] && [[ "$CURRENT_FILE" == *.swift ]]; then
        local lines_json="[]"
        local symbols_json="[]"

        if [ ${#CURRENT_LINES[@]} -gt 0 ]; then
            lines_json=$(collapse_to_ranges "${CURRENT_LINES[@]}")
        fi

        if [ ${#CURRENT_SYMBOLS[@]} -gt 0 ]; then
            symbols_json=$(printf '%s\n' "${CURRENT_SYMBOLS[@]}" | jq -s .)
        fi

        CHANGED_FILES+=("$(jq -n \
            --arg path "$CURRENT_FILE" \
            --arg change_type "$CURRENT_CHANGE_TYPE" \
            --argjson added_lines "$lines_json" \
            --argjson new_symbols "$symbols_json" \
            '{path: $path, change_type: $change_type, added_lines: $added_lines, new_symbols: $new_symbols}')")
    fi
}

# Process diff line by line
while IFS= read -r line || [ -n "$line" ]; do
    # New file header
    if [[ "$line" =~ ^diff\ --git\ a/(.+)\ b/(.+)$ ]]; then
        output_file

        A_PATH="${BASH_REMATCH[1]}"
        B_PATH="${BASH_REMATCH[2]}"

        # Skip renamed files
        if [ "$A_PATH" != "$B_PATH" ]; then
            CURRENT_FILE=""
            continue
        fi

        CURRENT_FILE="$B_PATH"
        CURRENT_LINES=()
        CURRENT_SYMBOLS=()
        CURRENT_CHANGE_TYPE="modified"
        IN_HUNK=0
        PREV_MINUS_FUNC=""
        continue
    fi

    # Skip non-swift files
    if [ -z "$CURRENT_FILE" ] || [[ "$CURRENT_FILE" != *.swift ]]; then
        continue
    fi

    # Detect new file
    if [[ "$line" =~ ^new\ file\ mode ]]; then
        CURRENT_CHANGE_TYPE="added"
        continue
    fi

    # Detect deleted file
    if [[ "$line" =~ ^deleted\ file\ mode ]]; then
        CURRENT_CHANGE_TYPE="deleted"
        continue
    fi

    # Hunk header - extract starting line number
    if [[ "$line" =~ ^@@\ -[0-9]+(,[0-9]+)?\ \+([0-9]+)(,[0-9]+)?\ @@ ]]; then
        CURRENT_LINE_NUM="${BASH_REMATCH[2]}"
        IN_HUNK=1
        continue
    fi

    if [ "$IN_HUNK" -eq 0 ]; then
        continue
    fi

    # Context line (no prefix or space prefix)
    if [[ "$line" =~ ^[\ ] ]] || [[ ! "$line" =~ ^[-+] ]]; then
        ((CURRENT_LINE_NUM++)) || true
        PREV_MINUS_FUNC=""
        continue
    fi

    # Removed line - check for function signature
    if [[ "$line" =~ ^\- ]]; then
        CONTENT="${line:1}"
        if [[ "$CONTENT" =~ func[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)\( ]]; then
            PREV_MINUS_FUNC="${BASH_REMATCH[1]}|$CONTENT"
        fi
        continue
    fi

    # Added line
    if [[ "$line" =~ ^\+ ]]; then
        CONTENT="${line:1}"
        CURRENT_LINES+=("$CURRENT_LINE_NUM")

        # Check for signature change (paired with previous minus)
        if [ -n "$PREV_MINUS_FUNC" ] && [[ "$CONTENT" =~ func[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)\( ]]; then
            FUNC_NAME="${BASH_REMATCH[1]}"
            OLD_FUNC_NAME="${PREV_MINUS_FUNC%%|*}"
            if [ "$FUNC_NAME" = "$OLD_FUNC_NAME" ]; then
                OLD_SIG="${PREV_MINUS_FUNC#*|}"
                SIGNATURE_CHANGES+=("$(jq -n \
                    --arg method "$FUNC_NAME" \
                    --arg old_signature "$OLD_SIG" \
                    --arg new_signature "$CONTENT" \
                    --arg file "$CURRENT_FILE" \
                    --argjson line "$CURRENT_LINE_NUM" \
                    --arg change_type "modified" \
                    '{method: $method, old_signature: $old_signature, new_signature: $new_signature, file: $file, line: $line, change_type: $change_type}')")
            fi
        fi
        PREV_MINUS_FUNC=""

        # Extract symbols from added lines
        # Function
        if [[ "$CONTENT" =~ func[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)\( ]]; then
            CURRENT_SYMBOLS+=("$(jq -n --arg type "function" --arg name "${BASH_REMATCH[1]}" --argjson line "$CURRENT_LINE_NUM" '{type: $type, name: $name, line: $line}')")
        fi

        # Property (var/let)
        if [[ "$CONTENT" =~ (var|let)[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*: ]]; then
            CURRENT_SYMBOLS+=("$(jq -n --arg type "property" --arg name "${BASH_REMATCH[2]}" --argjson line "$CURRENT_LINE_NUM" '{type: $type, name: $name, line: $line}')")
        fi

        # Class/struct/enum/protocol
        if [[ "$CONTENT" =~ (class|struct|enum|protocol)[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
            TYPE="${BASH_REMATCH[1]}"
            NAME="${BASH_REMATCH[2]}"
            CURRENT_SYMBOLS+=("$(jq -n --arg type "$TYPE" --arg name "$NAME" --argjson line "$CURRENT_LINE_NUM" '{type: $type, name: $name, line: $line}')")
        fi

        # Typealias
        if [[ "$CONTENT" =~ typealias[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*= ]]; then
            CURRENT_SYMBOLS+=("$(jq -n --arg type "typealias" --arg name "${BASH_REMATCH[1]}" --argjson line "$CURRENT_LINE_NUM" '{type: $type, name: $name, line: $line}')")
        fi

        ((CURRENT_LINE_NUM++)) || true
        continue
    fi
done < <(gh pr diff "$PR_NUMBER")

# Output last file
output_file

# Build final JSON
CHANGED_FILES_JSON="[]"
if [ ${#CHANGED_FILES[@]} -gt 0 ]; then
    CHANGED_FILES_JSON=$(printf '%s\n' "${CHANGED_FILES[@]}" | jq -s .)
fi

SIGNATURE_CHANGES_JSON="[]"
if [ ${#SIGNATURE_CHANGES[@]} -gt 0 ]; then
    SIGNATURE_CHANGES_JSON=$(printf '%s\n' "${SIGNATURE_CHANGES[@]}" | jq -s .)
fi

jq -n \
    --argjson pr_number "$PR_NUMBER" \
    --arg title "$TITLE" \
    --arg author "$AUTHOR" \
    --arg base_branch "$BASE" \
    --arg head_branch "$HEAD" \
    --argjson changed_files "$CHANGED_FILES_JSON" \
    --argjson signature_changes "$SIGNATURE_CHANGES_JSON" \
    '{
        pr_number: $pr_number,
        title: $title,
        author: $author,
        base_branch: $base_branch,
        head_branch: $head_branch,
        changed_files: $changed_files,
        signature_changes: $signature_changes
    }' > "$OUTPUT_FILE"

# Output summary
FILE_COUNT=$(echo "$CHANGED_FILES_JSON" | jq 'length')
SYMBOL_COUNT=$(echo "$CHANGED_FILES_JSON" | jq '[.[].new_symbols | length] | add // 0')
SIG_COUNT=$(echo "$SIGNATURE_CHANGES_JSON" | jq 'length')

echo "Files: $FILE_COUNT | Symbols: $SYMBOL_COUNT | Signatures: $SIG_COUNT"
