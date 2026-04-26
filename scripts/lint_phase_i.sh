#!/usr/bin/env bash
# Phase I freeze lint — enforces non-increasing ceilings on the parallel
# NetworkInteractionState channel. See docs/interaction_flow_inventory.md.
#
# Exit codes:
#   0 = OK
#   1 = a ceiling was exceeded
#
# Run from repo root.

set -uo pipefail

cd "$(dirname "$0")/.."

fail=0

check() {
	local name="$1"
	local ceiling="$2"
	local actual="$3"
	if (( actual > ceiling )); then
		echo "  FAIL: ${name}: ${actual} (ceiling ${ceiling})"
		fail=1
	else
		echo "    ok: ${name}: ${actual} (ceiling ${ceiling})"
	fi
}

count_pattern() {
	local pattern="$1"
	shift
	grep -rE "${pattern}" "$@" --include='*.gd' 2>/dev/null | wc -l | tr -d ' '
}

echo "Phase I freeze lint (docs/interaction_flow_inventory.md)"

# --- Producer / channel ceilings (shrink at each phase boundary) -----------
broadcast_step=$(count_pattern '_broadcast_interaction_step\b' src/)
broadcast_state=$(count_pattern 'broadcast_interaction_state\b' src/)
signal_changed=$(count_pattern 'interaction_state_changed' src/)
nis_class=$(count_pattern 'NetworkInteractionState' src/)
is_network_in_pres=$(count_pattern 'PlayMode\.is_network\(\)|NetworkManager\.is_server\(\)|NetworkManager\.is_client\(\)' src/scenes src/ui)

# Phase I0 baseline ceilings — never increase these.
check "_broadcast_interaction_step calls"           9  "$broadcast_step"
check "broadcast_interaction_state calls"           4  "$broadcast_state"
check "interaction_state_changed references"       5  "$signal_changed"
check "NetworkInteractionState references"        21  "$nis_class"
check "is_network()/is_server() in scenes+ui"     13  "$is_network_in_pres"

if (( fail )); then
	echo
	echo "Phase I freeze lint FAILED. See docs/interaction_flow_inventory.md."
	exit 1
fi

echo
echo "Phase I freeze lint OK."
exit 0
