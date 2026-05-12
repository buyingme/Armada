#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# run_baseline_traces.sh — Phase L0.5 regression-trace harness.
#
# Replays a captured GameReplay through the ReplayDriver autoload and
# diffs the resulting per-process baseline-trace JSONL against the
# committed fixture in tests/fixtures/baseline_traces/.  Exits 0 if
# every diff is empty, non-zero otherwise.
#
# Two modes:
#
#   ./scripts/run_baseline_traces.sh                # hot-seat only (default)
#   ./scripts/run_baseline_traces.sh --hot-seat     # hot-seat only (explicit)
#   ./scripts/run_baseline_traces.sh --network      # network only
#   ./scripts/run_baseline_traces.sh --all          # both
#
# Network requires the fixtures captured manually once:
#   - tests/fixtures/baseline_traces/replay_network.json
#       (the GameReplay produced by playing LS R1-R2 in network mode)
#   - tests/fixtures/baseline_traces/baseline_trace_network_host.jsonl
#   - tests/fixtures/baseline_traces/baseline_trace_network_client.jsonl
#       (the per-peer traces produced by ./scripts/run_network_test.sh --logging)
#
# Hot-seat fixtures (already committed):
#   - tests/fixtures/baseline_traces/replay_hot_seat_solo.json
#   - tests/fixtures/baseline_traces/baseline_trace_hot_seat_solo.jsonl
# ------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FIXTURE_DIR="$PROJECT_DIR/tests/fixtures/baseline_traces"
TMP_DIR="$(mktemp -d -t armada_baseline_XXXXXX)"
PORT=7350

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

# Parse mode.
MODE="hot-seat"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --hot-seat) MODE="hot-seat"; shift ;;
        --network)  MODE="network"; shift ;;
        --all)      MODE="all"; shift ;;
        -h|--help)
            sed -n '2,25p' "$0"
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# Background pids for cleanup.
PIDS=()
cleanup() {
    for pid in "${PIDS[@]:-}"; do
        if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
    done
    wait 2>/dev/null || true
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

# diff_or_fail <expected> <actual> <label>
diff_or_fail() {
    local expected="$1" actual="$2" label="$3"
    if ! [[ -f "$actual" ]]; then
        echo "FAIL [$label] — replay produced no trace at $actual" >&2
        return 1
    fi
    if diff -q "$expected" "$actual" >/dev/null; then
        echo "PASS [$label]"
        return 0
    fi
    echo "FAIL [$label] — trace differs from $expected:" >&2
    diff -u "$expected" "$actual" | head -60 >&2
    return 1
}

run_hot_seat() {
    local replay="$FIXTURE_DIR/replay_hot_seat_solo.json"
    local expected="$FIXTURE_DIR/baseline_trace_hot_seat_solo.jsonl"
    local actual="$TMP_DIR/hot_seat_solo.jsonl"
    if ! [[ -f "$replay" ]]; then
        echo "ERROR: missing fixture $replay" >&2
        return 1
    fi
    echo "=== Hot-seat ==="
    "$GODOT" --headless --path "$PROJECT_DIR" -- \
            --replay "$replay" \
            --baseline-output "$actual" \
            >"$TMP_DIR/hot_seat.log" 2>&1
    diff_or_fail "$expected" "$actual" "hot-seat"
}

run_network() {
    local replay="$FIXTURE_DIR/replay_network.json"
    local expected_host="$FIXTURE_DIR/baseline_trace_network_host.jsonl"
    local expected_client="$FIXTURE_DIR/baseline_trace_network_client.jsonl"
    local actual_host="$TMP_DIR/network_host.jsonl"
    local actual_client="$TMP_DIR/network_client.jsonl"
    if ! [[ -f "$replay" ]]; then
        echo "SKIP [network] — missing $replay (capture manually via run_network_test.sh; see docs)" >&2
        return 0
    fi
    if ! [[ -f "$expected_host" && -f "$expected_client" ]]; then
        echo "SKIP [network] — missing per-peer fixtures (capture manually first)" >&2
        return 0
    fi
    echo "=== Network ==="
    # Start headless host with replay loaded.
    "$GODOT" --headless --path "$PROJECT_DIR" -- \
            --server --port "$PORT" \
            --replay "$replay" \
            --baseline-output "$actual_host" \
            >"$TMP_DIR/network_host.log" 2>&1 &
    PIDS+=($!)
    sleep 2
    # Start client.
    "$GODOT" --headless --path "$PROJECT_DIR" -- \
            --connect "127.0.0.1:$PORT" \
            --replay "$replay" \
            --baseline-output "$actual_client" \
            >"$TMP_DIR/network_client.log" 2>&1 &
    PIDS+=($!)
    # Wait for both.
    wait "${PIDS[@]}" || true
    PIDS=()
    local rc=0
    diff_or_fail "$expected_host" "$actual_host" "network-host" || rc=1
    diff_or_fail "$expected_client" "$actual_client" "network-client" || rc=1
    return $rc
}

EXIT=0
case "$MODE" in
    hot-seat) run_hot_seat || EXIT=1 ;;
    network)  run_network || EXIT=1 ;;
    all)      run_hot_seat || EXIT=1; run_network || EXIT=1 ;;
esac

if [[ $EXIT -eq 0 ]]; then
    echo "All baseline traces match."
else
    echo "Baseline trace regression detected. See diffs above." >&2
fi
exit $EXIT
