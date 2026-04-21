#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# run_network_test.sh — Launch a local network test session on one computer.
#
# Starts a headless server and one or two client instances on localhost.
# All instances connect via 127.0.0.1 on the configured port.
#
# Usage:
#   ./scripts/run_network_test.sh              Server + 1 client (default)
#   ./scripts/run_network_test.sh --two        Server + 2 clients
#   ./scripts/run_network_test.sh --gui-host   2 GUI instances (no headless server)
#   ./scripts/run_network_test.sh --logging    Enable file logging on all instances
#   ./scripts/run_network_test.sh --port 7351  Use custom port
#
# To stop: press Ctrl+C — all background processes are cleaned up automatically.
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

# Defaults.
PORT=7350
TWO_CLIENTS=false
GUI_HOST=false
LOGGING=false

# Parse arguments.
while [[ $# -gt 0 ]]; do
    case "$1" in
        --two)       TWO_CLIENTS=true; shift ;;
        --gui-host)  GUI_HOST=true; shift ;;
        --logging)   LOGGING=true; shift ;;
        --port)      PORT="$2"; shift 2 ;;
        *)           echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Track background PIDs for cleanup.
PIDS=()

cleanup() {
    echo ""
    echo "Shutting down all instances..."
    for pid in "${PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
    done
    wait 2>/dev/null || true
    echo "Done."
}
trap cleanup EXIT INT TERM

# Build user args.
LOG_ARGS=()
if $LOGGING; then
    LOG_ARGS=(-- --logging)
fi

echo "=========================================="
echo "  Armada — Local Network Test"
echo "=========================================="
echo "Port:        $PORT"
echo "Godot:       $("$GODOT" --version 2>&1 | head -1)"
echo ""

if $GUI_HOST; then
    # Mode: Two GUI instances — player 1 hosts via menu, player 2 joins.
    echo "Mode:        Two GUI instances (host via menu)"
    echo ""
    echo "Instructions:"
    echo "  Instance 1: Click 'Host Game' to create a lobby"
    echo "  Instance 2: Click 'Join Game', enter 127.0.0.1"
    echo ""

    echo "[Instance 1] Launching (host)..."
    "$GODOT" --path "$PROJECT_DIR" ${LOG_ARGS[@]+"${LOG_ARGS[@]}"} &
    PIDS+=($!)
    sleep 2

    echo "[Instance 2] Launching (client)..."
    "$GODOT" --path "$PROJECT_DIR" ${LOG_ARGS[@]+"${LOG_ARGS[@]}"} &
    PIDS+=($!)

else
    # Mode: Headless server + client(s).
    echo "Mode:        Headless server + client(s)"
    if $TWO_CLIENTS; then
        echo "Clients:     2"
    else
        echo "Clients:     1"
    fi
    echo ""

    # Start headless server.
    SERVER_ARGS=(--headless -- --server --port "$PORT")
    if $LOGGING; then
        SERVER_ARGS=(--headless -- --server --port "$PORT" --logging)
    fi
    echo "[Server] Starting on port $PORT..."
    "$GODOT" --path "$PROJECT_DIR" "${SERVER_ARGS[@]}" &
    PIDS+=($!)
    sleep 2

    # Start client 1.
    echo "[Client 1] Launching..."
    "$GODOT" --path "$PROJECT_DIR" ${LOG_ARGS[@]+"${LOG_ARGS[@]}"} &
    PIDS+=($!)

    # Start client 2 (optional).
    if $TWO_CLIENTS; then
        sleep 1
        echo "[Client 2] Launching..."
        "$GODOT" --path "$PROJECT_DIR" ${LOG_ARGS[@]+"${LOG_ARGS[@]}"} &
        PIDS+=($!)
    fi
fi

echo ""
echo "All instances running. Press Ctrl+C to stop all."
echo ""

# Wait for any child to exit.
wait
