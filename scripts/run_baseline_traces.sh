#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# run_baseline_traces.sh - Phase L0.5 replay regression harness.
#
# Replays a captured GameReplay through the ReplayDriver autoload and
# compares the resulting oracle files against committed fixtures in
# tests/fixtures/baseline_traces/.  Hot-seat is deterministic at the
# per-command level and diffs the JSONL trace.  Network uses the real
# ENet transport; valid RPC timing races make per-command JSONL order
# and interleaving unstable, so network gates on the final serialized
# GameState hash written next to each diagnostic trace.  The network
# gate requires host and client to end on the same hash; it does not
# compare against a committed network hash because valid localhost
# packet timing can still choose different but peer-consistent command
# interleavings.
#
# Two modes:
#
#   ./scripts/run_baseline_traces.sh                # hot-seat only (default)
#   ./scripts/run_baseline_traces.sh --hot-seat     # hot-seat only (explicit)
#   ./scripts/run_baseline_traces.sh --network      # network only
#   ./scripts/run_baseline_traces.sh --all          # both
#
# Network requires fixtures captured manually once:
#   - tests/fixtures/baseline_traces/replay_network.json
#       (the GameReplay produced by playing LS R1-R2 in network mode)
# Network has no committed state-hash oracle yet.  The gate verifies
# host/client equivalence and prints the observed hash for diagnosis.
#
# Hot-seat fixtures (already committed):
#   - tests/fixtures/baseline_traces/replay_hot_seat_solo.json
#   - tests/fixtures/baseline_traces/baseline_trace_hot_seat_solo.jsonl
#   - tests/fixtures/baseline_traces/baseline_state_hash_hot_seat_solo.txt
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

# diff_or_fail <expected> <actual> <label> <kind>
diff_or_fail() {
    local expected="$1" actual="$2" label="$3" kind="$4"
    if ! [[ -f "$actual" ]]; then
        echo "FAIL [$label] - replay produced no $kind at $actual" >&2
        return 1
    fi
    if diff -q "$expected" "$actual" >/dev/null; then
        echo "PASS [$label]"
        return 0
    fi
    echo "FAIL [$label] - $kind differs from $expected:" >&2
    diff -u "$expected" "$actual" | head -60 >&2
    return 1
}

run_hot_seat() {
    local replay="$FIXTURE_DIR/replay_hot_seat_solo.json"
    local expected="$FIXTURE_DIR/baseline_trace_hot_seat_solo.jsonl"
    local expected_hash="$FIXTURE_DIR/baseline_state_hash_hot_seat_solo.txt"
    local actual="$TMP_DIR/hot_seat_solo.jsonl"
    if ! [[ -f "$replay" ]]; then
        echo "ERROR: missing fixture $replay" >&2
        return 1
    fi
    if ! [[ -f "$expected" && -f "$expected_hash" ]]; then
        echo "ERROR: missing hot-seat baseline fixture(s)" >&2
        return 1
    fi
    echo "=== Hot-seat ==="
    if ! "$GODOT" --headless --path "$PROJECT_DIR" -- \
            --replay "$replay" \
            --baseline-output "$actual" \
            >"$TMP_DIR/hot_seat.log" 2>&1; then
        echo "FAIL [hot-seat] - Godot process exited non-zero:" >&2
        tail -60 "$TMP_DIR/hot_seat.log" >&2
        return 1
    fi
    local rc=0
    diff_or_fail "$expected" "$actual" "hot-seat-trace" "trace" || rc=1
    diff_or_fail "$expected_hash" "${actual}.state_hash" \
            "hot-seat-state" "state hash" || rc=1
    return $rc
}

run_network() {
    local replay="$FIXTURE_DIR/replay_network.json"
    local actual_host="$TMP_DIR/network_host.jsonl"
    local actual_client="$TMP_DIR/network_client.jsonl"
    if ! [[ -f "$replay" ]]; then
        echo "SKIP [network] - missing $replay (capture manually via run_network_test.sh; see docs)" >&2
        return 0
    fi
    echo "=== Network ==="
    # Start headless host with replay loaded.
    "$GODOT" --headless --path "$PROJECT_DIR" -- \
            --server --port "$PORT" \
            --replay "$replay" \
            --baseline-output "$actual_host" \
            >"$TMP_DIR/network_host.log" 2>&1 &
    local host_pid=$!
    PIDS+=("$host_pid")
    sleep 2
    # Start client.
    "$GODOT" --headless --path "$PROJECT_DIR" -- \
            --connect "127.0.0.1:$PORT" \
            --replay "$replay" \
            --baseline-output "$actual_client" \
            >"$TMP_DIR/network_client.log" 2>&1 &
    local client_pid=$!
    PIDS+=("$client_pid")
    # Wait for both.
    set +e
    wait "$host_pid"
    local host_rc=$?
    wait "$client_pid"
    local client_rc=$?
    set -e
    PIDS=()
    local rc=0
    if [[ $host_rc -ne 0 || $client_rc -ne 0 ]]; then
        echo "FAIL [network] - Godot exited host=$host_rc client=$client_rc" >&2
        echo "--- host log ---" >&2
        tail -60 "$TMP_DIR/network_host.log" >&2
        echo "--- client log ---" >&2
        tail -60 "$TMP_DIR/network_client.log" >&2
        return 1
    fi
    diff_or_fail "${actual_host}.state_hash" "${actual_client}.state_hash" \
            "network-state-peer-equality" "state hash" || rc=1
    if [[ $rc -eq 0 ]]; then
        echo "INFO [network-state] $(cat "${actual_host}.state_hash")"
    fi
    return $rc
}

EXIT=0
case "$MODE" in
    hot-seat) run_hot_seat || EXIT=1 ;;
    network)  run_network || EXIT=1 ;;
    all)      run_hot_seat || EXIT=1; run_network || EXIT=1 ;;
esac

if [[ $EXIT -eq 0 ]]; then
    echo "All replay baselines match."
else
    echo "Replay baseline regression detected. See diffs above." >&2
fi
exit $EXIT
