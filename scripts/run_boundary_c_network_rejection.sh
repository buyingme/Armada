#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/armada-boundary-c.XXXXXX")"
host_pid=""
client_pid=""
cleanup() {
  for pid in "$host_pid" "$client_pid"; do
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
  done
}
trap cleanup EXIT
for viewer in 0 1; do
  port=$((20000 + RANDOM % 20000))
  host_log="$run_dir/host-$viewer.log"
  client_log="$run_dir/client-$viewer.log"
  "${GODOT_BIN:-godot}" --headless --path "$project_dir" \
    res://tests/acceptance/network_resume/boundary_c_rejection_driver.tscn -- \
    host "$port" "$viewer" >"$host_log" 2>&1 &
  host_pid=$!
  sleep 1
  "${GODOT_BIN:-godot}" --headless --path "$project_dir" \
    res://tests/acceptance/network_resume/boundary_c_rejection_driver.tscn -- \
    client "$port" "$viewer" >"$client_log" 2>&1 &
  client_pid=$!

  deadline=$((SECONDS + 20))
  while { kill -0 "$client_pid" 2>/dev/null \
      || kill -0 "$host_pid" 2>/dev/null; } && ((SECONDS < deadline)); do
    sleep 1
  done
  if ((SECONDS >= deadline)) \
      || ! wait "$client_pid" || ! wait "$host_pid" \
      || ! grep -q "BOUNDARY_C_PASS control_staged viewer=$viewer" "$host_log" \
      || ! grep -q "BOUNDARY_C_PASS receiver_control viewer=$viewer" "$client_log" \
      || ! grep -q "BOUNDARY_C_PASS negative_ack_authority_unchanged viewer=$viewer" "$host_log" \
      || ! grep -q "BOUNDARY_C_PASS rejection_no_stage_no_commit viewer=$viewer" "$client_log"; then
    cat "$host_log" "$client_log" >&2
    echo "Boundary C ENet control/rejection failed; logs: $run_dir" >&2
    exit 1
  fi
  host_pid=""
  client_pid=""
  echo "Boundary C ENet mapping $viewer: valid stage, negative ack, no commit PASS"
done
