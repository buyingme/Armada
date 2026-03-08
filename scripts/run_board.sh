#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# run_board.sh — Launch the GameBoard scene directly for Phase 2 manual testing.
#
# Bypasses the main menu and opens the board with all Learning Scenario tokens
# already placed. Use this to run through the MT-2.x checks in
# docs/test_plan_manual.md.
#
# Controls (in-game):
#   Right-click drag   Pan camera
#   Scroll wheel       Zoom in / out
#
# To test the firing arc overlay (MT-2.8), add the temporary input handler
# documented in docs/test_plan_manual.md and rerun this script.
#
# Usage:
#   ./scripts/run_board.sh
#   ./scripts/run_board.sh --debug    Launch with remote debugger enabled
# ------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BOARD_SCENE="res://src/scenes/game_board/game_board.tscn"

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

# Verify the scene file exists.
BOARD_PATH="$PROJECT_DIR/src/scenes/game_board/game_board.tscn"
if [[ ! -f "$BOARD_PATH" ]]; then
    echo "ERROR: game_board.tscn not found at $BOARD_PATH" >&2
    echo "       Has Phase 2 been implemented?" >&2
    exit 1
fi

EXTRA_ARGS=()
if [[ "${1:-}" == "--debug" ]]; then
    EXTRA_ARGS+=(--remote-debug "tcp://127.0.0.1:6007")
    echo "Remote debug enabled on tcp://127.0.0.1:6007"
fi

echo "Launching board scene for manual testing"
echo "Scene   : $BOARD_SCENE"
echo "Godot   : $("$GODOT" --version 2>&1 | head -1)"
echo ""
echo "Manual tests to run: docs/test_plan_manual.md § Phase 2 (MT-2.1 – MT-2.9)"
echo ""

exec "$GODOT" --path "$PROJECT_DIR" "$BOARD_SCENE" "${EXTRA_ARGS[@]}"
