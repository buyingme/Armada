## Unit tests for [InteractionFlow] domain type and [GameState] integration.
##
## Covers:
##   * Default field values
##   * [code]make()[/code] and [code]empty()[/code] factories
##   * Round-trip serialise / deserialise (incl. payload deep-copy)
##   * Forward compat: missing keys → defaults
##   * [code]is_actor()[/code] semantics
##   * [GameState] wires the field through serialize / deserialize
##   * [StateFilter] strips OWNER payload from non-controllers
##   * Constants enum coverage matches legacy id maps
##
## Phase I — see [code]docs/refactoring_phase_i_plan.md[/code], step I1.
extends GutTest


# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------

func test_new_flow_type_is_none() -> void:
	var f: InteractionFlow = InteractionFlow.new()
	assert_eq(f.flow_type, Constants.InteractionFlow.NONE,
			"Default flow_type must be NONE.")


func test_new_step_id_is_none() -> void:
	var f: InteractionFlow = InteractionFlow.new()
	assert_eq(f.step_id, Constants.InteractionStep.NONE,
			"Default step_id must be NONE.")


func test_new_controller_player_is_minus_one() -> void:
	var f: InteractionFlow = InteractionFlow.new()
	assert_eq(f.controller_player, -1,
			"Default controller_player must be -1.")


func test_new_visible_to_is_all() -> void:
	var f: InteractionFlow = InteractionFlow.new()
	assert_eq(f.visible_to, Constants.Visibility.ALL,
			"Default visible_to must be ALL.")


func test_new_payload_is_empty() -> void:
	var f: InteractionFlow = InteractionFlow.new()
	assert_eq(f.payload.size(), 0, "Default payload must be empty.")


# ---------------------------------------------------------------------------
# Factories
# ---------------------------------------------------------------------------

func test_make_assigns_all_fields() -> void:
	var f: InteractionFlow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			1,
			Constants.Visibility.OWNER,
			{"attack_id": 42})
	assert_eq(f.flow_type, Constants.InteractionFlow.ATTACK)
	assert_eq(f.step_id, Constants.InteractionStep.ATTACK_ROLL)
	assert_eq(f.controller_player, 1)
	assert_eq(f.visible_to, Constants.Visibility.OWNER)
	assert_eq(f.payload.get("attack_id", -1), 42)


func test_make_deep_copies_payload() -> void:
	var src: Dictionary = {"k": [1, 2, 3]}
	var f: InteractionFlow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			0, Constants.Visibility.ALL, src)
	src["k"].append(4)
	assert_eq((f.payload.get("k", []) as Array).size(), 3,
			"make() must deep-copy the payload.")


func test_empty_returns_default_flow() -> void:
	var f: InteractionFlow = InteractionFlow.empty()
	assert_eq(f.flow_type, Constants.InteractionFlow.NONE)
	assert_eq(f.controller_player, -1)


# ---------------------------------------------------------------------------
# Serialisation round-trip
# ---------------------------------------------------------------------------

func test_serialize_default_yields_expected_keys() -> void:
	var data: Dictionary = InteractionFlow.new().serialize()
	for key in ["flow_type", "step_id", "controller_player",
			"visible_to", "payload"]:
		assert_true(data.has(key), "serialize() must include key %s" % key)


func test_round_trip_preserves_all_fields() -> void:
	var original: InteractionFlow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.MANEUVER_STEP,
			0,
			Constants.Visibility.OWNER,
			{"ship_index": 2, "speed": 3})
	var clone: InteractionFlow = InteractionFlow.deserialize(
			original.serialize())
	assert_true(clone.equals(original), "Round-trip must preserve all fields.")


func test_round_trip_preserves_nested_payload() -> void:
	var original: InteractionFlow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			1,
			Constants.Visibility.OWNER,
			{"tokens": [{"type": "evade", "state": "ready"}]})
	var clone: InteractionFlow = InteractionFlow.deserialize(
			original.serialize())
	var tokens: Array = clone.payload.get("tokens", [])
	assert_eq(tokens.size(), 1)
	assert_eq((tokens[0] as Dictionary).get("type", ""), "evade")


func test_payload_deep_copied_on_serialize() -> void:
	var f: InteractionFlow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			0, Constants.Visibility.ALL, {"k": [1]})
	var data: Dictionary = f.serialize()
	(data["payload"]["k"] as Array).append(2)
	assert_eq((f.payload["k"] as Array).size(), 1,
			"serialize() output must not alias internal payload.")


func test_deserialize_missing_keys_uses_defaults() -> void:
	var f: InteractionFlow = InteractionFlow.deserialize({})
	assert_eq(f.flow_type, Constants.InteractionFlow.NONE)
	assert_eq(f.step_id, Constants.InteractionStep.NONE)
	assert_eq(f.controller_player, -1)
	assert_eq(f.visible_to, Constants.Visibility.ALL)
	assert_eq(f.payload.size(), 0)


func test_deserialize_handles_non_dictionary_payload() -> void:
	# Belt-and-braces: malformed input should not crash.
	var f: InteractionFlow = InteractionFlow.deserialize({"payload": "oops"})
	assert_eq(f.payload.size(), 0,
			"Non-dictionary payload must be coerced to {}.")


# ---------------------------------------------------------------------------
# is_actor()
# ---------------------------------------------------------------------------

func test_is_actor_true_for_controller() -> void:
	var f: InteractionFlow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DECLARE,
			1)
	assert_true(f.is_actor(1), "Player 1 is the controller — should act.")


func test_is_actor_false_for_other_player() -> void:
	var f: InteractionFlow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DECLARE,
			1)
	assert_false(f.is_actor(0))


func test_is_actor_false_for_minus_one_default() -> void:
	var f: InteractionFlow = InteractionFlow.new()
	assert_false(f.is_actor(0))
	assert_false(f.is_actor(1))


# ---------------------------------------------------------------------------
# equals()
# ---------------------------------------------------------------------------

func test_equals_returns_false_for_null() -> void:
	var f: InteractionFlow = InteractionFlow.new()
	assert_false(f.equals(null))


func test_equals_detects_payload_difference() -> void:
	var a: InteractionFlow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			0, Constants.Visibility.ALL, {"x": 1})
	var b: InteractionFlow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			0, Constants.Visibility.ALL, {"x": 2})
	assert_false(a.equals(b))


# ---------------------------------------------------------------------------
# GameState integration
# ---------------------------------------------------------------------------

func test_game_state_initialize_creates_default_flow() -> void:
	var state: GameState = GameState.new()
	state.initialize()
	assert_not_null(state.interaction_flow,
			"GameState.initialize() must create an InteractionFlow.")
	assert_eq(state.interaction_flow.flow_type,
			Constants.InteractionFlow.NONE)


func test_game_state_round_trip_preserves_flow() -> void:
	var state: GameState = GameState.new()
	state.initialize()
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.REVEAL_DIAL,
			0,
			Constants.Visibility.OWNER,
			{"ship_index": 1})
	var clone: GameState = GameState.deserialize(state.serialize())
	assert_true(clone.interaction_flow.equals(state.interaction_flow),
			"GameState round-trip must preserve interaction_flow.")


func test_game_state_deserialize_missing_flow_uses_default() -> void:
	var data: Dictionary = {
		"current_round": 1,
		"current_phase": 0,
		"initiative_player": 0,
		"player_states": [],
	}
	var clone: GameState = GameState.deserialize(data)
	assert_not_null(clone.interaction_flow)
	assert_eq(clone.interaction_flow.flow_type,
			Constants.InteractionFlow.NONE)


# ---------------------------------------------------------------------------
# StateFilter integration
# ---------------------------------------------------------------------------

func test_state_filter_strips_owner_payload_from_non_controller() -> void:
	var state: GameState = GameState.new()
	state.initialize()
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			1,
			Constants.Visibility.OWNER,
			{"secret_canary": "hidden_data"})
	var filtered: Dictionary = StateFilter.filter_for_player(
			state.serialize(), 0)  # Player 0 is NOT the controller
	var flow_data: Dictionary = filtered.get("interaction_flow", {})
	var payload: Dictionary = flow_data.get("payload", {})
	assert_false(payload.has("secret_canary"),
			"OWNER payload must be stripped from non-controller view.")
	# Public fields still present
	assert_eq(int(flow_data.get("flow_type", -1)),
			int(Constants.InteractionFlow.ATTACK))
	assert_eq(int(flow_data.get("controller_player", -1)), 1)


func test_state_filter_keeps_owner_payload_for_controller() -> void:
	var state: GameState = GameState.new()
	state.initialize()
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			1,
			Constants.Visibility.OWNER,
			{"secret_canary": "hidden_data"})
	var filtered: Dictionary = StateFilter.filter_for_player(
			state.serialize(), 1)  # Player 1 IS the controller
	var payload: Dictionary = (filtered["interaction_flow"]
			as Dictionary)["payload"]
	assert_eq(payload.get("secret_canary", ""), "hidden_data",
			"Controller must still see their own OWNER payload.")


func test_state_filter_keeps_all_visibility_payload() -> void:
	var state: GameState = GameState.new()
	state.initialize()
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.COMMAND_PHASE,
			Constants.InteractionStep.SELECT_DIALS,
			-1,
			Constants.Visibility.ALL,
			{"public_data": 42})
	var filtered_p0: Dictionary = StateFilter.filter_for_player(
			state.serialize(), 0)
	var filtered_p1: Dictionary = StateFilter.filter_for_player(
			state.serialize(), 1)
	for filtered in [filtered_p0, filtered_p1]:
		var p: Dictionary = (filtered["interaction_flow"]
				as Dictionary).get("payload", {})
		assert_eq(p.get("public_data", -1), 42,
				"ALL payload must always pass through filter.")


# ---------------------------------------------------------------------------
# Legacy maps (used by I2 invariant test)
# ---------------------------------------------------------------------------

func test_legacy_flow_type_map_is_complete() -> void:
	var values: Array = Constants.LEGACY_FLOW_TYPE_MAP.values()
	# Every InteractionFlow value (except duplicates) should be reachable.
	var expected: Array = [
		Constants.InteractionFlow.NONE,
		Constants.InteractionFlow.COMMAND_PHASE,
		Constants.InteractionFlow.SHIP_ACTIVATION,
		Constants.InteractionFlow.SQUADRON_ACTIVATION,
		Constants.InteractionFlow.ATTACK,
		Constants.InteractionFlow.STATUS_CLEANUP,
		Constants.InteractionFlow.GAME_OVER,
	]
	for v in expected:
		assert_true(values.has(v),
				"LEGACY_FLOW_TYPE_MAP missing flow %d" % v)


func test_legacy_step_id_map_round_trip() -> void:
	# Each step value in the map must round-trip through the enum.
	for key in Constants.LEGACY_STEP_ID_MAP.keys():
		var step_value: int = int(Constants.LEGACY_STEP_ID_MAP[key])
		assert_true(step_value >= 0,
				"Step id %s must map to non-negative enum int." % key)
