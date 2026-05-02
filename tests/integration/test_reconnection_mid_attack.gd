## I7 — Reconnection acceptance gate for Phase I.
##
## Validates the architectural promise of Phase I: because
## [member GameState.interaction_flow] is a serializable domain field,
## a client that disconnects mid-attack and receives one filtered
## state snapshot can render the **exact** modal of the active client,
## with no further messages on the wire.
##
## The test operates at the function-call boundary
## ([code]GameState.serialize → StateFilter.filter_for_player →
## GameState.deserialize → UIProjector.project[/code]) which is the
## same chain the production reconnection path will use; it is
## deliberately RPC-free so it cannot be defeated by transport timing.
##
## Plan: [code]docs/refactoring_phase_i_plan.md[/code] §I7.
extends GutTest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Builds a server-side [GameState] mid-attack at the
## [constant Constants.InteractionStep.ATTACK_DEFENSE_TOKENS] step,
## with player 0 as attacker and player 1 as defender (controller of
## the defense-tokens step).
func _server_state_mid_attack() -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	var payload: Dictionary = {
		"attacker_player": 0,
		"defender_player": 1,
		"attacker_kind": "ship",
		"attacker_ship_index": 0,
		"target_kind": "ship",
		"target_ship_index": 0,
		"defender_zone": int(Constants.HullZone.FRONT),
		"dice_pool": {"red": 2, "blue": 1, "black": 0},
		"dice_results": [
			{"colour": "red", "face": "HIT"},
			{"colour": "red", "face": "CRIT"},
			{"colour": "blue", "face": "HIT"},
		],
		"modified_damage": 3,
		"defense_tokens": [],
	}
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			1,                                           # controller = defender
			Constants.Visibility.ALL,
			payload)
	return state


## Performs the full reconnection projection chain for [param viewer]
## against [param server_state] and returns the resulting
## [UIProjector.UIIntent].
func _project_after_reconnect(server_state: GameState,
		viewer: int) -> UIProjector.UIIntent:
	var raw: Dictionary = server_state.serialize()
	var filtered: Dictionary = StateFilter.filter_for_player(raw, viewer)
	var client_state: GameState = GameState.deserialize(filtered)
	return UIProjector.project(client_state, viewer)


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_defender_reconnect_renders_interactive_defense_tokens_modal() -> void:
	var server_state: GameState = _server_state_mid_attack()

	var intent: UIProjector.UIIntent = _project_after_reconnect(
			server_state, 1)

	assert_eq(intent.flow_type, Constants.InteractionFlow.ATTACK,
			"Defender reconnects: flow_type should be ATTACK.")
	assert_eq(intent.step_id,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			"Defender reconnects: step_id should be ATTACK_DEFENSE_TOKENS.")
	assert_eq(intent.modal_kind,
			Constants.ModalKind.ATTACK_DEFENSE_TOKENS,
			"Defender reconnects: modal_kind should drive AttackSimPanel.")
	assert_eq(intent.controller_player, 1,
			"Defender reconnects: controller is the defender (player 1).")
	assert_true(intent.is_interactive,
			"Defender reconnects: viewer is the controller, must be interactive.")


func test_attacker_reconnect_renders_readonly_defense_tokens_modal() -> void:
	var server_state: GameState = _server_state_mid_attack()

	var intent: UIProjector.UIIntent = _project_after_reconnect(
			server_state, 0)

	assert_eq(intent.modal_kind,
			Constants.ModalKind.ATTACK_DEFENSE_TOKENS,
			"Attacker reconnects: same modal kind on both peers.")
	assert_eq(intent.controller_player, 1,
			"Attacker reconnects: controller is still the defender.")
	assert_false(intent.is_interactive,
			"Attacker reconnects: non-controller peer must be read-only.")


func test_reconnect_payload_carries_dice_state() -> void:
	# The defender's reconnected projection must surface the dice pool +
	# dice results so the AttackSimPanel populates without a second RPC.
	var server_state: GameState = _server_state_mid_attack()

	var intent: UIProjector.UIIntent = _project_after_reconnect(
			server_state, 1)

	assert_true(intent.payload.has("dice_pool"),
			"Reconnected payload must carry dice_pool for panel population.")
	assert_true(intent.payload.has("dice_results"),
			"Reconnected payload must carry dice_results for panel population.")
	assert_eq(int(intent.payload.get("modified_damage", -1)), 3,
			"Reconnected payload must preserve modified_damage.")
	var results: Array = intent.payload.get("dice_results", [])
	assert_eq(results.size(), 3,
			"Reconnected payload must preserve dice_results length.")


func test_reconnect_filter_strips_owner_only_payload_for_opponent() -> void:
	# When a flow is OWNER-visible the StateFilter must strip the payload
	# from the opponent's snapshot — the Phase I information-hiding
	# guarantee.  Use an OWNER-visible flow (e.g. command-dial selection).
	var state: GameState = GameState.new()
	state.initialize()
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.COMMAND_PHASE,
			Constants.InteractionStep.SELECT_DIALS,
			0,                                           # controller = player 0
			Constants.Visibility.OWNER,
			{"chosen_command": int(Constants.CommandType.NAVIGATE)})

	var owner_intent: UIProjector.UIIntent = _project_after_reconnect(state, 0)
	var opponent_intent: UIProjector.UIIntent = _project_after_reconnect(state, 1)

	assert_true(owner_intent.payload.has("chosen_command"),
			"Owner reconnect: OWNER-visible payload must reach the controller.")
	assert_false(opponent_intent.payload.has("chosen_command"),
			"Opponent reconnect: OWNER-visible payload must be stripped.")


func test_reconnect_no_flow_yields_empty_intent() -> void:
	# Sanity: when no flow is active the projection is a benign empty
	# UIIntent — same contract as a fresh client connecting before any
	# command runs.
	var state: GameState = GameState.new()
	state.initialize()

	var intent: UIProjector.UIIntent = _project_after_reconnect(state, 0)

	assert_eq(intent.flow_type, Constants.InteractionFlow.NONE,
			"No active flow: flow_type is NONE.")
	assert_eq(intent.modal_kind, Constants.ModalKind.NONE,
			"No active flow: no modal renders.")
	assert_false(intent.is_interactive,
			"No active flow: nothing is interactive.")
