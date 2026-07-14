#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# run_tests.sh — Run the automated GUT test suite headless.
#
# Usage:
#   ./scripts/run_tests.sh            Run all tests
#   ./scripts/run_tests.sh unit       Run only tests/unit/
#   ./scripts/run_tests.sh integration Run only tests/integration/
#   ./scripts/run_tests.sh -f path    Run a single test file
#
# Exit code: 0 = all passed, 1 = failures or parse errors.
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

# ---  Parse arguments  --------------------------------------------------------
TEST_DIR="res://tests"
SINGLE_FILE=""

case "${1:-}" in
    "unit")
        TEST_DIR="res://tests/unit"
        shift ;;
    "integration")
        TEST_DIR="res://tests/integration"
        shift ;;
    "-f" | "--file")
        SINGLE_FILE="${2:-}"
        if [[ -z "$SINGLE_FILE" ]]; then
            echo "ERROR: -f requires a file path argument." >&2
            exit 1
        fi
        shift 2 ;;
    "") ;;  # default: all tests
    *)
        echo "Usage: $0 [unit|integration|-f <test_file>]" >&2
        exit 1 ;;
esac

# --- Build GUT command --------------------------------------------------------
GUT_CMD=("$GODOT" --headless -s addons/gut/gut_cmdln.gd)

if [[ -n "$SINGLE_FILE" ]]; then
    # Accept both res:// paths and local filesystem paths.
    if [[ "$SINGLE_FILE" != res://* ]]; then
        SINGLE_FILE="res://${SINGLE_FILE#$PROJECT_DIR/}"
    fi
    GUT_CMD+=(-gtest="$SINGLE_FILE")
else
    GUT_CMD+=(-gdir="$TEST_DIR" -ginclude_subdirs)
fi

GUT_CMD+=(-gexit)

# --- Run tests ----------------------------------------------------------------
echo "========================================"
echo "  Armada — Automated Test Suite"
echo "========================================"
echo "  Project : $PROJECT_DIR"
echo "  Godot   : $("$GODOT" --version 2>&1 | head -1)"
echo "  Target  : ${SINGLE_FILE:-$TEST_DIR}"
echo "========================================"
echo ""

set +e
OUTPUT=$("${GUT_CMD[@]}" 2>&1)
EXIT_CODE=$?
set -e

echo "$OUTPUT"

if [[ "$EXIT_CODE" -ne 0 ]]; then
    echo ""
    echo "❌  GUT exited with status $EXIT_CODE — see output above"
    exit "$EXIT_CODE"
fi

# --- Interpret result ---------------------------------------------------------
SUMMARY=$(echo "$OUTPUT" | grep -E "^Passing Tests|^Tests|^Scripts|^---- " || true)

if echo "$OUTPUT" | grep -q "All tests passed"; then
    echo ""
    echo "✅  ALL TESTS PASSED"
else
    echo ""
    echo "❌  FAILURES DETECTED — see output above"
    exit 1
fi

# Warn if the script count looks unexpectedly low (silent GUT drops).
SCRIPT_COUNT=$(echo "$OUTPUT" | grep -E "^Scripts" | grep -oE "[0-9]+" || echo "0")
MIN_SCRIPT_COUNT=5
if [[ -n "$SINGLE_FILE" ]]; then
    MIN_SCRIPT_COUNT=1
fi
if [[ "$SCRIPT_COUNT" -lt "$MIN_SCRIPT_COUNT" ]]; then
    echo "⚠️  WARNING: Only $SCRIPT_COUNT scripts loaded — check for parse errors."
    exit 1
fi

exit 0
