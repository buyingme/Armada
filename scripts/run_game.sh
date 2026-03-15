#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# run_game.sh — Launch the game from its configured main scene.
#
# Opens the Godot project in player mode (no editor UI).
# Use this to do full end-to-end manual testing from the main menu.
#
# Usage:
#   ./scripts/run_game.sh
#   ./scripts/run_game.sh --debug    Launch with remote debugger enabled
#   ./scripts/run_game.sh --logging  Enable file logging to user://logs/
#   ./scripts/run_game.sh --debug --logging  Both flags can be combined
# ------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Locate Godot binary.
GODOT="${GODOT_BIN:-}"
if [[ -z "$GODOT" ]]; then
    if command -v godot &>/dev/null; then
        GODOT="godot"
    elif [[ -f "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
        GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
    else
        echo "ERROR: Godot binary not found. Set GODOT_BIN or add godot to PATH." >&2
        exit 1
    fi
fi

cd "$PROJECT_DIR"

EXTRA_ARGS=()
USER_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --debug)
            EXTRA_ARGS+=(--remote-debug "tcp://127.0.0.1:6007")
            echo "Remote debug enabled on tcp://127.0.0.1:6007"
            ;;
        --logging)
            USER_ARGS+=(--logging)
            echo "File logging enabled — logs written to user://logs/"
            ;;
    esac
done
if [[ ${#USER_ARGS[@]} -gt 0 ]]; then
    EXTRA_ARGS+=(-- "${USER_ARGS[@]}")
fi

echo "Launching game: $PROJECT_DIR"
echo "Godot: $("$GODOT" --version 2>&1 | head -1)"
echo ""

exec "$GODOT" --path "$PROJECT_DIR" ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
