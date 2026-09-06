#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RUN_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/armada-match003.XXXXXX")"
SHARED="$RUN_ROOT/evidence"
LOGS="$RUN_ROOT/logs"
mkdir -p "$SHARED" "$LOGS"
RESULT="failed"
CHILD_PIDS=()
cleanup() {
  for pid in "${CHILD_PIDS[@]:-}"; do
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
  done
  wait 2>/dev/null || true
  if [[ "$RESULT" == "passed" ]]; then
    rm -rf "$RUN_ROOT"
  else
    echo "MATCH-003 ENet acceptance failed; retained diagnostics: $RUN_ROOT" >&2
  fi
}
trap cleanup EXIT INT TERM
GODOT_BIN="${GODOT_BIN:-godot}"
RUN_SECTION_D_ONLY=false
RUN_BUG031_ONLY=false
if [[ "${1:-}" == "--section-d-only" ]]; then
  RUN_SECTION_D_ONLY=true
elif [[ "${1:-}" == "--bug-031-only" ]]; then
  RUN_BUG031_ONLY=true
elif [[ $# -ne 0 ]]; then
  echo "Usage: $0 [--section-d-only|--bug-031-only]" >&2
  exit 2
fi
wait_for_child() {
  local pid="$1" label="$2" deadline=$((SECONDS + 30))
  while kill -0 "$pid" 2>/dev/null; do
    if (( SECONDS >= deadline )); then
      echo "Timed out waiting for $label (pid $pid)." >&2
      kill "$pid" 2>/dev/null || true
      wait "$pid" || true
      return 1
    fi
    sleep 1
  done
  wait "$pid"
}
run_compatibility_network() {
  local port="$1"
  local host_home="$RUN_ROOT/home-compat-network-host"
  local client_home="$RUN_ROOT/home-compat-network-client"
  mkdir -p "$host_home" "$client_home"
  HOME="$host_home" "$GODOT_BIN" --headless --path "$PROJECT_DIR" \
    res://tests/acceptance/network_resume/driver.tscn -- \
    --role=host --scenario=compatibility_network --port="$port" --shared="$SHARED" \
    >"$LOGS/compat-network-host.log" 2>&1 &
  local host=$!
  CHILD_PIDS+=("$host")
  sleep 1
  HOME="$client_home" "$GODOT_BIN" --headless --path "$PROJECT_DIR" \
    res://tests/acceptance/network_resume/driver.tscn -- \
    --role=client --scenario=compatibility_network --port="$port" --shared="$SHARED" \
    >"$LOGS/compat-network-client.log" 2>&1 &
  local client=$!
  CHILD_PIDS+=("$client")
  wait_for_child "$client" "Network same-live compatibility client"
  wait_for_child "$host" "Network same-live compatibility host"
}
run_compatibility_hot_seat() {
  local home="$RUN_ROOT/home-compat-hot-seat"
  mkdir -p "$home"
  HOME="$home" "$GODOT_BIN" --headless --path "$PROJECT_DIR" \
    res://tests/acceptance/network_resume/driver.tscn -- \
    --role=hot_seat --scenario=compatibility_hot_seat --shared="$SHARED" \
    >"$LOGS/compat-hot-seat.log" 2>&1
}
run_network_replay() {
  local port="$1"
  local replay="$PROJECT_DIR/tests/fixtures/baseline_traces/replay_network.json"
  local host_home="$RUN_ROOT/home-compat-replay-host"
  local client_home="$RUN_ROOT/home-compat-replay-client"
  if [[ ! -f "$replay" ]]; then
    echo "Missing persisted Network replay artifact: $replay" >&2
    return 1
  fi
  mkdir -p "$host_home" "$client_home"
  HOME="$host_home" "$GODOT_BIN" --headless --path "$PROJECT_DIR" -- \
    --server --port "$port" --replay "$replay" \
    --baseline-output "$SHARED/network-replay-host.jsonl" \
    >"$LOGS/compat-replay-host.log" 2>&1 &
  local host=$!
  CHILD_PIDS+=("$host")
  sleep 1
  HOME="$client_home" "$GODOT_BIN" --headless --path "$PROJECT_DIR" -- \
    --connect "127.0.0.1:$port" --replay "$replay" \
    --baseline-output "$SHARED/network-replay-client.jsonl" \
    >"$LOGS/compat-replay-client.log" 2>&1 &
  local client=$!
  CHILD_PIDS+=("$client")
  wait_for_child "$client" "Network replay client"
  wait_for_child "$host" "Network replay host"
}
run_mapping() {
  local mapping="$1" port="$2"
  local host_home="$RUN_ROOT/home-host-$mapping"
  local client_home="$RUN_ROOT/home-client-$mapping"
  mkdir -p "$host_home" "$client_home"
  HOME="$host_home" "$GODOT_BIN" --headless --path "$PROJECT_DIR" \
    res://tests/acceptance/network_resume/driver.tscn -- \
    --role=host --mapping="$mapping" --port="$port" --shared="$SHARED" \
    >"$LOGS/host-$mapping.log" 2>&1 &
  local host=$!
  CHILD_PIDS+=("$host")
  sleep 1
  HOME="$client_home" "$GODOT_BIN" --headless --path "$PROJECT_DIR" \
    res://tests/acceptance/network_resume/driver.tscn -- \
    --role=client --mapping="$mapping" --port="$port" --shared="$SHARED" \
    >"$LOGS/client-$mapping.log" 2>&1 &
  local client=$!
  CHILD_PIDS+=("$client")
  wait_for_child "$client" "client mapping $mapping"
  wait_for_child "$host" "host mapping $mapping"
}
run_commanded_squadron() {
  local port="$1"
  local host_home="$RUN_ROOT/home-commanded-host"
  local client_home="$RUN_ROOT/home-commanded-client"
  mkdir -p "$host_home" "$client_home"
  HOME="$host_home" "$GODOT_BIN" --headless --path "$PROJECT_DIR" \
    res://tests/acceptance/network_resume/driver.tscn -- \
    --role=host --scenario=commanded_squadron --mapping=0 --port="$port" \
    --shared="$SHARED" >"$LOGS/commanded-host.log" 2>&1 &
  local host=$!
  CHILD_PIDS+=("$host")
  sleep 1
  HOME="$client_home" "$GODOT_BIN" --headless --path "$PROJECT_DIR" \
    res://tests/acceptance/network_resume/driver.tscn -- \
    --role=client --scenario=commanded_squadron --mapping=0 --port="$port" \
    --shared="$SHARED" >"$LOGS/commanded-client.log" 2>&1 &
  local client=$!
  CHILD_PIDS+=("$client")
  wait_for_child "$client" "commanded-squadron ordering client"
  wait_for_child "$host" "commanded-squadron ordering host"
}
run_bug031_scenario() {
  local scenario="$1" label="$2" port="$3"
  local host_home="$RUN_ROOT/home-$scenario-host"
  local client_home="$RUN_ROOT/home-$scenario-client"
  mkdir -p "$host_home" "$client_home"
  HOME="$host_home" "$GODOT_BIN" --headless --path "$PROJECT_DIR" \
    res://tests/acceptance/network_resume/driver.tscn -- \
    --role=host --scenario="$scenario" --mapping=0 --port="$port" \
    --shared="$SHARED" >"$LOGS/$scenario-host.log" 2>&1 &
  local host=$!
  CHILD_PIDS+=("$host")
  sleep 1
  HOME="$client_home" "$GODOT_BIN" --headless --path "$PROJECT_DIR" \
    res://tests/acceptance/network_resume/driver.tscn -- \
    --role=client --scenario="$scenario" --mapping=0 --port="$port" \
    --shared="$SHARED" >"$LOGS/$scenario-client.log" 2>&1 &
  local client=$!
  CHILD_PIDS+=("$client")
  wait_for_child "$client" "$label client"
  wait_for_child "$host" "$label host"
}
run_ship_end_activation() {
  local port="$1"
  local host_home="$RUN_ROOT/home-end-activation-host"
  local client_home="$RUN_ROOT/home-end-activation-client"
  mkdir -p "$host_home" "$client_home"
  HOME="$host_home" "$GODOT_BIN" --headless --path "$PROJECT_DIR" \
    res://tests/acceptance/network_resume/driver.tscn -- \
    --role=host --scenario=ship_end_activation --mapping=0 --port="$port" \
    --shared="$SHARED" >"$LOGS/end-activation-host.log" 2>&1 &
  local host=$!
  CHILD_PIDS+=("$host")
  sleep 1
  HOME="$client_home" "$GODOT_BIN" --headless --path "$PROJECT_DIR" \
    res://tests/acceptance/network_resume/driver.tscn -- \
    --role=client --scenario=ship_end_activation --mapping=0 --port="$port" \
    --shared="$SHARED" >"$LOGS/end-activation-client.log" 2>&1 &
  local client=$!
  CHILD_PIDS+=("$client")
  wait_for_child "$client" "client End Activation control"
  wait_for_child "$host" "authoritative End Activation"
}
run_reconnect() {
  local port="$1" host_home="$RUN_ROOT/home-reconnect-host"
  mkdir -p "$host_home"
  HOME="$host_home" "$GODOT_BIN" --headless --path "$PROJECT_DIR" \
    res://tests/acceptance/network_resume/driver.tscn -- \
    --role=host --scenario=reconnect --port="$port" --shared="$SHARED" \
    >"$LOGS/reconnect-host.log" 2>&1 &
  local host=$!
  CHILD_PIDS+=("$host")
  sleep 1
  HOME="$RUN_ROOT/home-reconnect-incumbent" "$GODOT_BIN" --headless --path "$PROJECT_DIR" \
    res://tests/acceptance/network_resume/driver.tscn -- \
    --role=incumbent --scenario=reconnect --port="$port" --shared="$SHARED" \
    >"$LOGS/reconnect-incumbent.log" 2>&1 &
  local incumbent=$!
  CHILD_PIDS+=("$incumbent")
  wait_for_child "$incumbent" "reconnect incumbent"
  sleep 1
  HOME="$RUN_ROOT/home-reconnect-failed" "$GODOT_BIN" --headless --path "$PROJECT_DIR" \
    res://tests/acceptance/network_resume/driver.tscn -- \
    --role=failed_reconnect --scenario=reconnect --port="$port" --shared="$SHARED" \
    >"$LOGS/reconnect-failed.log" 2>&1 &
  local failed=$!
  CHILD_PIDS+=("$failed")
  wait_for_child "$failed" "failed reconnect endpoint"
  sleep 1
  HOME="$RUN_ROOT/home-reconnect-clean" "$GODOT_BIN" --headless --path "$PROJECT_DIR" \
    res://tests/acceptance/network_resume/driver.tscn -- \
    --role=reconnect --scenario=reconnect --port="$port" --shared="$SHARED" \
    >"$LOGS/reconnect-clean.log" 2>&1 &
  local reconnect=$!
  CHILD_PIDS+=("$reconnect")
  wait_for_child "$reconnect" "clean reconnect endpoint"
  wait_for_child "$host" "reconnect host"
}
if [[ "$RUN_SECTION_D_ONLY" == false && "$RUN_BUG031_ONLY" == false ]]; then
  run_mapping 0 $((26000 + ($$ % 1000)))
  run_mapping 1 $((27000 + ($$ % 1000)))
  run_commanded_squadron $((27500 + ($$ % 400)))
fi
if [[ "$RUN_SECTION_D_ONLY" == false ]]; then
  run_bug031_scenario commanded_decline \
    "BUG-031 commanded Move decline" $((27700 + ($$ % 120)))
  run_bug031_scenario commanded_activation_gate \
    "BUG-031 activation acceptance gate" $((27820 + ($$ % 60)))
  run_bug031_scenario commanded_activation_reject \
    "BUG-031 activation rejection recovery" $((27880 + ($$ % 20)))
fi
if [[ "$RUN_SECTION_D_ONLY" == false && "$RUN_BUG031_ONLY" == false ]]; then
  run_ship_end_activation $((27900 + ($$ % 80)))
  run_reconnect $((28000 + ($$ % 1000)))
fi
if [[ "$RUN_BUG031_ONLY" == false ]]; then
  run_compatibility_network $((29000 + ($$ % 1000)))
  run_compatibility_hot_seat
  run_network_replay $((30000 + ($$ % 1000)))
fi
HOME="$RUN_ROOT/home-assertions" "$GODOT_BIN" --headless --path "$PROJECT_DIR" --script \
  res://tests/acceptance/network_resume/assertions.gd -- --shared="$SHARED" \
	--replay="$PROJECT_DIR/tests/fixtures/baseline_traces/replay_network.json" \
  --logs="$LOGS" \
  --section-d-only="$RUN_SECTION_D_ONLY" --bug-031-only="$RUN_BUG031_ONLY"
echo "PASS: MATCH-003 real ENet fresh-resume and compatibility scenarios completed."
RESULT="passed"
