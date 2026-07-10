## Test: FlowSpec
##
## Unit tests for the Phase M machine-readable interaction-flow skeleton.
extends GutTest


const FlowSpecScript: GDScript = preload("res://src/core/state/flow_spec.gd")


# ---------------------------------------------------------------------------
# Inventory
# ---------------------------------------------------------------------------

func test_controller_role_enum_phase_m_contract_matches_expected_values() -> void:
	assert_eq(Constants.ControllerRole.size(), 8,
			"Phase M ControllerRole enum should expose exactly eight roles.")
	assert_eq(Constants.ControllerRole.NONE, 0, "NONE should keep ordinal 0.")
	assert_eq(Constants.ControllerRole.ACTIVE_PLAYER, 1,
			"ACTIVE_PLAYER should keep ordinal 1.")
	assert_eq(Constants.ControllerRole.OPPOSING_PLAYER, 2,
			"OPPOSING_PLAYER should keep ordinal 2.")
	assert_eq(Constants.ControllerRole.ATTACKER, 3,
			"ATTACKER should keep ordinal 3.")
	assert_eq(Constants.ControllerRole.DEFENDER_OR_ATTACKER, 4,
			"DEFENDER_OR_ATTACKER should keep ordinal 4.")
	assert_eq(Constants.ControllerRole.PAYLOAD_CONTROLLER, 5,
			"PAYLOAD_CONTROLLER should keep ordinal 5.")
	assert_eq(Constants.ControllerRole.EITHER_PLAYER, 6,
			"EITHER_PLAYER should keep ordinal 6.")
	assert_eq(Constants.ControllerRole.SYSTEM, 7,
			"SYSTEM should keep ordinal 7.")


func test_has_spec_documented_pairs_returns_true() -> void:
	for pair: Dictionary in _documented_pairs():
		assert_true(FlowSpecScript.has_spec(
				int(pair["flow_id"]), int(pair["step_id"])),
				"FlowSpec should include documented pair %s." % _pair_key(pair))


func test_all_pairs_documented_inventory_returns_exact_pairs() -> void:
	var expected_keys: Array[String] = []
	for pair: Dictionary in _documented_pairs():
		expected_keys.append(_pair_key(pair))
	var actual_keys: Array[String] = []
	for pair: Dictionary in FlowSpecScript.all_pairs():
		actual_keys.append(_pair_key(pair))
	assert_eq(actual_keys.size(), expected_keys.size(),
			"FlowSpec should not gain or lose valid documented pairs.")
	for expected_key: String in expected_keys:
		assert_true(actual_keys.has(expected_key),
				"FlowSpec missing documented pair %s." % expected_key)


func test_documented_pairs_cover_each_interaction_step_once() -> void:
	var seen_steps: Array[int] = []
	for pair: Dictionary in _documented_pairs():
		var step_id: int = int(pair["step_id"])
		assert_false(seen_steps.has(step_id),
				"Documented FlowSpec inventory should not duplicate step %d." % step_id)
		seen_steps.append(step_id)
	assert_eq(seen_steps.size(), Constants.InteractionStep.size(),
			"Every InteractionStep enum value should have one documented FlowSpec pair.")


func test_has_spec_invalid_pair_returns_false() -> void:
	assert_false(FlowSpecScript.has_spec(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT),
			"Attack flow should not accept ship-selection steps.")


func test_get_spec_invalid_pair_returns_empty_dictionary() -> void:
	var spec: Dictionary = FlowSpecScript.get_spec(
			Constants.InteractionFlow.SQUADRON_ACTIVATION,
			Constants.InteractionStep.ATTACK_ROLL)
	assert_true(spec.is_empty(),
			"Invalid flow/step pairs should return an empty Dictionary.")


func test_get_spec_valid_pair_returns_deep_copy() -> void:
	var spec: Dictionary = FlowSpecScript.get_spec(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL)
	(spec["allowed_commands"] as Array).append("mutated_test_command")
	var fresh_spec: Dictionary = FlowSpecScript.get_spec(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL)
	assert_false((fresh_spec["allowed_commands"] as Array).has(
			"mutated_test_command"),
			"get_spec() should deep-copy nested arrays from the static table.")


func test_get_spec_projection_only_rows_mark_source() -> void:
	for pair: Dictionary in _projection_only_pairs():
		var spec: Dictionary = FlowSpecScript.get_spec(
				int(pair["flow_id"]), int(pair["step_id"]))
		assert_eq(spec.get("source", ""), FlowSpecScript.SOURCE_PROJECTION_ONLY,
				"Projection-only pair %s should be marked as such." % _pair_key(pair))


func test_get_spec_modal_metadata_matches_projector_contract() -> void:
	for row: Dictionary in _modal_rows():
		var spec: Dictionary = FlowSpecScript.get_spec(
				int(row["flow_id"]), int(row["step_id"]))
		var modals: Array = spec.get("modals", [])
		assert_true(modals.has(row["modal_kind"]),
				"Pair %s should expose modal kind %d." % [
						_pair_key(row), int(row["modal_kind"])])


func test_controller_role_displacement_place_is_opposing_player() -> void:
	assert_eq(FlowSpecScript.controller_role(
			Constants.InteractionFlow.SQUADRON_DISPLACEMENT,
			Constants.InteractionStep.DISPLACEMENT_PLACE),
			Constants.ControllerRole.OPPOSING_PLAYER,
			"Displacement placement should be controlled by the non-moving player.")


# ---------------------------------------------------------------------------
# Controller Resolution
# ---------------------------------------------------------------------------

func test_resolve_controller_player_active_player_context_returns_active() -> void:
	var controller: int = FlowSpecScript.resolve_controller_player(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT,
			null,
			{"active_player": 1})
	assert_eq(controller, 1,
			"ACTIVE_PLAYER should resolve to the supplied active_player.")


func test_resolve_controller_player_opposing_player_returns_non_moving() -> void:
	var controller: int = FlowSpecScript.resolve_controller_player(
			Constants.InteractionFlow.SQUADRON_DISPLACEMENT,
			Constants.InteractionStep.DISPLACEMENT_PLACE,
			null,
			{"moving_player": 0})
	assert_eq(controller, 1,
			"OPPOSING_PLAYER should resolve to the non-moving player.")


func test_resolve_controller_player_attacker_context_returns_attacker() -> void:
	var controller: int = FlowSpecScript.resolve_controller_player(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			null,
			{"attacker_player": 0})
	assert_eq(controller, 0,
			"ATTACKER should resolve to the supplied attacker_player.")


func test_resolve_controller_player_defender_or_attacker_prefers_defender() -> void:
	var controller: int = FlowSpecScript.resolve_controller_player(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			null,
			{"attacker_player": 0, "defender_player": 1})
	assert_eq(controller, 1,
			"DEFENDER_OR_ATTACKER should prefer a valid defender_player.")


func test_resolve_controller_player_defender_or_attacker_falls_back_to_attacker() -> void:
	var controller: int = FlowSpecScript.resolve_controller_player(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			null,
			{"attacker_player": 0, "defender_player": - 1})
	assert_eq(controller, 0,
			"DEFENDER_OR_ATTACKER should fall back to attacker_player.")


func test_resolve_controller_player_payload_controller_context_returns_controller() -> void:
	var controller: int = FlowSpecScript.resolve_controller_player(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_CRITICAL_CHOICE,
			null,
			{"controller_player": 1})
	assert_eq(controller, 1,
			"PAYLOAD_CONTROLLER should use the validated payload controller.")


func test_resolve_controller_player_either_player_context_returns_player() -> void:
	var controller: int = FlowSpecScript.resolve_controller_player(
			Constants.InteractionFlow.COMMAND_PHASE,
			Constants.InteractionStep.SELECT_DIALS,
			null,
			{"viewer_player": 0})
	assert_eq(controller, 0,
			"EITHER_PLAYER should resolve when the caller supplies a local player.")


func test_resolve_controller_player_none_returns_unresolved() -> void:
	var none_controller: int = FlowSpecScript.resolve_controller_player(
			Constants.InteractionFlow.NONE,
			Constants.InteractionStep.NONE,
			null,
			{"active_player": 0})
	assert_eq(none_controller, -1, "NONE role should resolve to -1.")


func test_resolve_controller_player_status_cleanup_accepts_either_player_context() -> void:
	var controller: int = FlowSpecScript.resolve_controller_player(
			Constants.InteractionFlow.STATUS_CLEANUP,
			Constants.InteractionStep.STATUS_CLEANUP_STEP,
			null,
			{"viewer_player": 1})
	assert_eq(controller, 1,
			"STATUS_CLEANUP should resolve an either-player controller context.")


func test_resolve_controller_player_missing_context_returns_minus_one() -> void:
	var controller: int = FlowSpecScript.resolve_controller_player(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			null,
			{})
	assert_eq(controller, -1,
			"Resolvable roles should return -1 when required context is missing.")


func test_resolve_controller_player_matching_flow_state_returns_controller() -> void:
	var game_state: GameState = GameState.new()
	game_state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE,
			0)
	var controller: int = FlowSpecScript.resolve_controller_player(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE,
			game_state,
			{})
	assert_eq(controller, 0,
			"Resolver may use a matching InteractionFlow controller as fallback.")


func test_make_interaction_flow_resolves_controller_and_copies_payload() -> void:
	var payload: Dictionary = {"ship_index": 2}
	var flow: InteractionFlow = FlowSpecScript.make_interaction_flow(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.ACTIVATION_MODAL_OPEN,
			null,
			{"active_player": 1},
			Constants.Visibility.ALL,
			payload)
	payload["ship_index"] = 99
	assert_eq(flow.controller_player, 1,
			"make_interaction_flow() should resolve the semantic controller role.")
	assert_eq(int(flow.payload.get("ship_index", -1)), 2,
			"make_interaction_flow() should preserve InteractionFlow's payload copy contract.")


func _documented_pairs() -> Array[Dictionary]:
	return [
		_pair(Constants.InteractionFlow.NONE, Constants.InteractionStep.NONE),
		_pair(Constants.InteractionFlow.COMMAND_PHASE, Constants.InteractionStep.SELECT_DIALS),
		_pair(Constants.InteractionFlow.COMMAND_PHASE, Constants.InteractionStep.WAIT_FOR_OPPONENT_DIALS),
		_pair(Constants.InteractionFlow.SHIP_ACTIVATION, Constants.InteractionStep.TARKIN_COMMAND_CHOICE),
		_pair(Constants.InteractionFlow.SHIP_ACTIVATION, Constants.InteractionStep.WAIT_FOR_SHIP_SELECT),
		_pair(Constants.InteractionFlow.SHIP_ACTIVATION, Constants.InteractionStep.ACTIVATION_MODAL_OPEN),
		_pair(Constants.InteractionFlow.SHIP_ACTIVATION, Constants.InteractionStep.REVEAL_DIAL),
		_pair(Constants.InteractionFlow.SHIP_ACTIVATION, Constants.InteractionStep.SPEND_DIAL),
		_pair(Constants.InteractionFlow.SHIP_ACTIVATION, Constants.InteractionStep.MANEUVER_STEP),
		_pair(Constants.InteractionFlow.SHIP_ACTIVATION, Constants.InteractionStep.SQUADRON_STEP),
		_pair(Constants.InteractionFlow.SHIP_ACTIVATION, Constants.InteractionStep.REPAIR_STEP),
		_pair(Constants.InteractionFlow.SHIP_ACTIVATION, Constants.InteractionStep.ATTACK_STEP),
		_pair(Constants.InteractionFlow.SHIP_ACTIVATION, Constants.InteractionStep.ACTIVATION_DONE),
		_pair(Constants.InteractionFlow.SQUADRON_ACTIVATION, Constants.InteractionStep.WAIT_FOR_SQUAD_SELECT),
		_pair(Constants.InteractionFlow.SQUADRON_ACTIVATION, Constants.InteractionStep.ACTION_CHOICE),
		_pair(Constants.InteractionFlow.SQUADRON_ACTIVATION, Constants.InteractionStep.SQUAD_MOVE),
		_pair(Constants.InteractionFlow.SQUADRON_ACTIVATION, Constants.InteractionStep.SQUAD_ATTACK),
		_pair(Constants.InteractionFlow.ATTACK, Constants.InteractionStep.ATTACK_DECLARE),
		_pair(Constants.InteractionFlow.ATTACK, Constants.InteractionStep.ATTACK_ROLL),
		_pair(Constants.InteractionFlow.ATTACK, Constants.InteractionStep.ATTACK_MODIFY),
		_pair(Constants.InteractionFlow.ATTACK, Constants.InteractionStep.ATTACK_DEFENSE_TOKENS),
		_pair(Constants.InteractionFlow.ATTACK, Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE),
		_pair(Constants.InteractionFlow.ATTACK, Constants.InteractionStep.ATTACK_COUNTER_CHOICE),
		_pair(Constants.InteractionFlow.ATTACK, Constants.InteractionStep.ATTACK_CRITICAL_CHOICE),
		_pair(Constants.InteractionFlow.SETUP, Constants.InteractionStep.SETUP_OBSTACLE_PLACEMENT),
		_pair(Constants.InteractionFlow.SETUP, Constants.InteractionStep.SETUP_SHIP_DEPLOYMENT),
		_pair(Constants.InteractionFlow.SETUP, Constants.InteractionStep.SETUP_SQUADRON_DEPLOYMENT),
		_pair(Constants.InteractionFlow.SETUP, Constants.InteractionStep.SETUP_REVIEW),
		_pair(Constants.InteractionFlow.STATUS_CLEANUP, Constants.InteractionStep.STATUS_CLEANUP_STEP),
		_pair(Constants.InteractionFlow.GAME_OVER, Constants.InteractionStep.GAME_OVER_STEP),
		_pair(Constants.InteractionFlow.SQUADRON_DISPLACEMENT, Constants.InteractionStep.DISPLACEMENT_PLACE),
	]


func _projection_only_pairs() -> Array[Dictionary]:
	return [
		_pair(Constants.InteractionFlow.COMMAND_PHASE, Constants.InteractionStep.SELECT_DIALS),
		_pair(Constants.InteractionFlow.COMMAND_PHASE, Constants.InteractionStep.WAIT_FOR_OPPONENT_DIALS),
		_pair(Constants.InteractionFlow.SHIP_ACTIVATION, Constants.InteractionStep.REVEAL_DIAL),
		_pair(Constants.InteractionFlow.SHIP_ACTIVATION, Constants.InteractionStep.SPEND_DIAL),
		_pair(Constants.InteractionFlow.SQUADRON_ACTIVATION, Constants.InteractionStep.SQUAD_MOVE),
		_pair(Constants.InteractionFlow.SQUADRON_ACTIVATION, Constants.InteractionStep.SQUAD_ATTACK),
		_pair(Constants.InteractionFlow.STATUS_CLEANUP, Constants.InteractionStep.STATUS_CLEANUP_STEP),
		_pair(Constants.InteractionFlow.GAME_OVER, Constants.InteractionStep.GAME_OVER_STEP),
	]


func _modal_rows() -> Array[Dictionary]:
	return [
		_modal_row(Constants.InteractionFlow.NONE, Constants.InteractionStep.NONE, Constants.ModalKind.NONE),
		_modal_row(Constants.InteractionFlow.COMMAND_PHASE, Constants.InteractionStep.SELECT_DIALS, Constants.ModalKind.COMMAND_DIALS),
		_modal_row(Constants.InteractionFlow.SHIP_ACTIVATION, Constants.InteractionStep.TARKIN_COMMAND_CHOICE, Constants.ModalKind.TARKIN_COMMAND_CHOICE),
		_modal_row(Constants.InteractionFlow.SHIP_ACTIVATION, Constants.InteractionStep.WAIT_FOR_SHIP_SELECT, Constants.ModalKind.NONE),
		_modal_row(Constants.InteractionFlow.SHIP_ACTIVATION, Constants.InteractionStep.ACTIVATION_MODAL_OPEN, Constants.ModalKind.ACTIVATION),
		_modal_row(Constants.InteractionFlow.SHIP_ACTIVATION, Constants.InteractionStep.SQUADRON_STEP, Constants.ModalKind.SQUADRON),
		_modal_row(Constants.InteractionFlow.SQUADRON_ACTIVATION, Constants.InteractionStep.WAIT_FOR_SQUAD_SELECT, Constants.ModalKind.NONE),
		_modal_row(Constants.InteractionFlow.SQUADRON_ACTIVATION, Constants.InteractionStep.ACTION_CHOICE, Constants.ModalKind.SQUADRON),
		_modal_row(Constants.InteractionFlow.ATTACK, Constants.InteractionStep.ATTACK_DECLARE, Constants.ModalKind.ATTACK_DECLARE),
		_modal_row(Constants.InteractionFlow.ATTACK, Constants.InteractionStep.ATTACK_ROLL, Constants.ModalKind.ATTACK_ROLL),
		_modal_row(Constants.InteractionFlow.ATTACK, Constants.InteractionStep.ATTACK_MODIFY, Constants.ModalKind.ATTACK_MODIFY),
		_modal_row(Constants.InteractionFlow.ATTACK, Constants.InteractionStep.ATTACK_DEFENSE_TOKENS, Constants.ModalKind.ATTACK_DEFENSE_TOKENS),
		_modal_row(Constants.InteractionFlow.ATTACK, Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE, Constants.ModalKind.ATTACK_RESOLVE_DAMAGE),
		_modal_row(Constants.InteractionFlow.ATTACK, Constants.InteractionStep.ATTACK_COUNTER_CHOICE, Constants.ModalKind.ATTACK_COUNTER_CHOICE),
		_modal_row(Constants.InteractionFlow.ATTACK, Constants.InteractionStep.ATTACK_CRITICAL_CHOICE, Constants.ModalKind.ATTACK_CRITICAL_CHOICE),
		_modal_row(Constants.InteractionFlow.SETUP, Constants.InteractionStep.SETUP_OBSTACLE_PLACEMENT, Constants.ModalKind.SETUP_OBSTACLE_PLACEMENT),
		_modal_row(Constants.InteractionFlow.SETUP, Constants.InteractionStep.SETUP_SHIP_DEPLOYMENT, Constants.ModalKind.SETUP_SHIP_DEPLOYMENT),
		_modal_row(Constants.InteractionFlow.SETUP, Constants.InteractionStep.SETUP_SQUADRON_DEPLOYMENT, Constants.ModalKind.SETUP_SQUADRON_DEPLOYMENT),
		_modal_row(Constants.InteractionFlow.SETUP, Constants.InteractionStep.SETUP_REVIEW, Constants.ModalKind.SETUP_REVIEW),
		_modal_row(Constants.InteractionFlow.SQUADRON_DISPLACEMENT, Constants.InteractionStep.DISPLACEMENT_PLACE, Constants.ModalKind.DISPLACEMENT),
		_modal_row(Constants.InteractionFlow.STATUS_CLEANUP, Constants.InteractionStep.STATUS_CLEANUP_STEP, Constants.ModalKind.STATUS_CLEANUP),
		_modal_row(Constants.InteractionFlow.GAME_OVER, Constants.InteractionStep.GAME_OVER_STEP, Constants.ModalKind.GAME_OVER),
	]


func _pair(
		flow_id: Constants.InteractionFlow,
		step_id: Constants.InteractionStep) -> Dictionary:
	return {"flow_id": int(flow_id), "step_id": int(step_id)}


func _modal_row(
		flow_id: Constants.InteractionFlow,
		step_id: Constants.InteractionStep,
		modal_kind: Constants.ModalKind) -> Dictionary:
	return {
		"flow_id": int(flow_id),
		"step_id": int(step_id),
		"modal_kind": int(modal_kind),
	}


func _pair_key(pair: Dictionary) -> String:
	return "%d:%d" % [int(pair["flow_id"]), int(pair["step_id"])]
