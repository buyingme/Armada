#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# open_log.sh — Open a game log file in the default editor.
#
# By default opens the most recent log. Pass a number to open an older one,
# or --list to see all available logs.
#
# Usage:
#   ./scripts/open_log.sh            Open the latest log
#   ./scripts/open_log.sh 2          Open the 2nd most recent log
#   ./scripts/open_log.sh --list     List all logs (newest first)
#   ./scripts/open_log.sh --dir      Print the logs directory path
# ------------------------------------------------------------------------------
set -euo pipefail

# Godot user:// path on macOS for this project
LOG_DIR="$HOME/Library/Application Support/Godot/app_userdata/Star Wars Armada/logs"

# --- Handle --dir flag ---
if [[ "${1:-}" == "--dir" ]]; then
    echo "$LOG_DIR"
    exit 0
fi

# --- Verify the logs directory exists ---
if [[ ! -d "$LOG_DIR" ]]; then
    echo "No logs directory found at:"
    echo "  $LOG_DIR"
    echo ""
    echo "Run the game with --logging first:"
    echo "  ./scripts/run_board.sh --logging"
    exit 1
fi

# --- Collect log files, newest first ---
LOGS=()
while IFS= read -r f; do
    LOGS+=("$f")
done < <(ls -1t "$LOG_DIR"/game_*.log 2>/dev/null)

if [[ ${#LOGS[@]} -eq 0 ]]; then
    echo "No log files found in:"
    echo "  $LOG_DIR"
    echo ""
    echo "Run the game with --logging first:"
    echo "  ./scripts/run_board.sh --logging"
    exit 1
fi

# --- Handle --list flag ---
if [[ "${1:-}" == "--list" ]]; then
    echo "Available game logs (newest first):"
    echo ""
    for i in "${!LOGS[@]}"; do
        local_name=$(basename "${LOGS[$i]}")
        size=$(wc -c < "${LOGS[$i]}" | tr -d ' ')
        lines=$(wc -l < "${LOGS[$i]}" | tr -d ' ')
        printf "  %2d) %-40s  %s bytes, %s lines\n" "$((i + 1))" "$local_name" "$size" "$lines"
    done
    echo ""
    echo "Open one with:  ./scripts/open_log.sh <number>"
    exit 0
fi

# --- Determine which log to open ---
INDEX="${1:-1}"

if ! [[ "$INDEX" =~ ^[0-9]+$ ]]; then
    echo "Usage: ./scripts/open_log.sh [number|--list|--dir]"
    exit 1
fi

if [[ "$INDEX" -lt 1 || "$INDEX" -gt ${#LOGS[@]} ]]; then
    echo "Log #$INDEX does not exist. Available: 1–${#LOGS[@]}"
    echo "Use --list to see all logs."
    exit 1
fi

TARGET="${LOGS[$((INDEX - 1))]}"
BASENAME=$(basename "$TARGET")

echo "Opening: $BASENAME"

# --- Open in editor (prefer $EDITOR, fall back to VS Code, then open) ---
if [[ -n "${EDITOR:-}" ]]; then
    "$EDITOR" "$TARGET"
elif command -v code &>/dev/null; then
    code "$TARGET"
else
    open "$TARGET"
fi
