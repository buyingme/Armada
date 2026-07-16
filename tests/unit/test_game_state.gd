## Test: Game State
##
## Unit tests for GameState and PlayerState classes.
extends GutTest


const TimingWindowStateScript: GDScript = preload(
		"res://src/core/state/timing_window_state.gd")

# --- GameState Initialization ---

func test_initialize_sets_round_to_zero() -> void:
	var state := GameState.new()
	state.initialize()
	assert_eq(state.current_round, 0, "Initial round should be 0")


func test_initialize_sets_phase_to_setup() -> void:
	var state := GameState.new()
	state.initialize()
	assert_eq(state.current_phase, Constants.GamePhase.SETUP, "Initial phase should be SETUP")


func test_initialize_creates_two_player_states() -> void:
	var state := GameState.new()
	state.initialize()
	assert_eq(state.player_states.size(), 2, "Should have 2 player states")


func test_initialize_sets_player_indices() -> void:
	var state := GameState.new()
	state.initialize()
	assert_eq(state.player_states[0].player_index, 0, "First player index should be 0")
	assert_eq(state.player_states[1].player_index, 1, "Second player index should be 1")


func test_initialize_sets_initiative_to_zero() -> void:
	var state := GameState.new()
	state.initialize()
	assert_eq(state.initiative_player, 0, "Initial initiative player should be 0")


func test_initialize_clears_objectives() -> void:
	var state := GameState.new()
	state.objectives = {"selected_objective": {"data_key": "opening_salvo"}}
	state.initialize()
	assert_true(state.objectives.is_empty(),
			"Initialize should clear stale setup/objective payloads")


func test_initialize_creates_inactive_timing_window_state() -> void:
	var state := GameState.new()
	state.initialize()

	assert_not_null(state.timing_window_state,
			"GameState should own timing-window lifecycle state")
	assert_true(state.timing_window_state.is_inactive(),
			"Fresh GameState timing-window state should be inactive")


# --- Player State Access ---

func test_get_player_state_valid_index() -> void:
	var state := GameState.new()
	state.initialize()
	var ps := state.get_player_state(0)
	assert_not_null(ps, "Should return valid player state for index 0")
	assert_eq(ps.player_index, 0)


func test_get_player_state_invalid_index() -> void:
	var state := GameState.new()
	state.initialize()
	var ps := state.get_player_state(5)
	assert_null(ps, "Should return null for invalid index")
	assert_push_error(1, "Should produce exactly 1 push_error for invalid index")


func test_get_initiative_player_state() -> void:
	var state := GameState.new()
	state.initialize()
	state.initiative_player = 1
	var ps := state.get_initiative_player_state()
	assert_eq(ps.player_index, 1, "Should return player 1 when they have initiative")


func test_get_non_initiative_player_state() -> void:
	var state := GameState.new()
	state.initialize()
	state.initiative_player = 0
	var ps := state.get_non_initiative_player_state()
	assert_eq(ps.player_index, 1, "Non-initiative player should be player 1")


# --- Serialization ---

func test_serialize_round_trip() -> void:
	var state := GameState.new()
	state.initialize()
	state.current_round = 3
	state.current_phase = Constants.GamePhase.SHIP
	state.initiative_player = 1

	var data := state.serialize()
	var restored := GameState.deserialize(data)

	assert_eq(restored.current_round, 3, "Round should survive serialization")
	assert_eq(restored.current_phase, Constants.GamePhase.SHIP, "Phase should survive serialization")
	assert_eq(restored.initiative_player, 1, "Initiative should survive serialization")
	assert_eq(restored.player_states.size(), 2, "Player states should survive serialization")


func test_serialize_round_trip_preserves_objectives() -> void:
	var state: GameState = GameState.new()
	state.initialize()
	state.objectives = {
		"selected_objective": {"data_key": "obj_ass_opening_salvo"},
		"setup_package_hash": "abc123",
	}

	var restored: GameState = GameState.deserialize(state.serialize())

	assert_eq(restored.objectives, state.objectives,
		"Objectives/setup payload should survive serialization")


func test_timing_window_state_default_is_inactive() -> void:
	var timing_state = TimingWindowStateScript.new()

	assert_true(timing_state.is_inactive(),
			"New TimingWindowState should default inactive")


func test_serialize_round_trip_preserves_inactive_timing_window_state() -> void:
	var state := GameState.new()
	state.initialize()

	var restored := GameState.deserialize(state.serialize())

	assert_not_null(restored.timing_window_state,
			"Round-trip should restore timing-window state")
	assert_true(restored.timing_window_state.is_inactive(),
			"Inactive timing-window state should round-trip")


func test_serialize_round_trip_preserves_active_timing_window_state() -> void:
	var state := GameState.new()
	state.initialize()
	assert_true(state.set_timing_window_state(_make_active_timing_window(
			"attack_modify",
			"modify_attack_dice",
			"tw-0001",
			0,
			{"continuation_id": "confirm_attack_dice"})),
			"GameState should accept a valid timing-window lifecycle state")

	var restored := GameState.deserialize(state.serialize())

	assert_true(restored.timing_window_state.equals(state.timing_window_state),
			"Active lifecycle identity and continuation context should round-trip")


func test_timing_window_state_serializes_json_safe_values() -> void:
	var state = _make_active_timing_window(
			"status_cleanup",
			"ready_cost",
			"tw-0002",
			1,
			{"continuation_id": "start_round"})

	assert_true(_is_json_safe(state.serialize()),
			"TimingWindowState serialization must be JSON-safe")


func test_missing_timing_window_state_deserializes_inactive() -> void:
	var state := GameState.new()
	state.initialize()
	var data := state.serialize()
	data.erase("timing_window_state")

	var restored := GameState.deserialize(data)

	assert_not_null(restored, "Missing older timing-window state should load")
	assert_true(restored.timing_window_state.is_inactive(),
			"Missing older timing-window state should reconstruct inactive")


func test_malformed_timing_window_state_deserialize_returns_null() -> void:
	var state := GameState.new()
	state.initialize()
	var data := state.serialize()
	data["timing_window_state"] = ["not", "a", "dictionary"]

	var restored := GameState.deserialize(data)

	assert_null(restored,
			"Malformed present timing-window state should fail closed")


func test_semantically_unsupported_timing_window_state_returns_null() -> void:
	var state := GameState.new()
	state.initialize()
	var data := state.serialize()
	data["timing_window_state"] = {
		"active": true,
		"timing_window_id": "attack_modify",
		"lifecycle_stage": "modify_attack_dice",
		"lifecycle_id": "tw-0003",
		"controller_player": 0,
		"continuation_context": {},
		"status": "unsupported",
	}

	var restored := GameState.deserialize(data)

	assert_null(restored,
			"Unsupported present timing-window state should fail closed")


func test_timing_window_state_rejects_projection_or_rule_state_fields() -> void:
	var state := GameState.new()
	state.initialize()
	var data := state.serialize()
	data["timing_window_state"] = {
		"active": false,
		"status": "inactive",
		"payload": {"modal_kind": "derived"},
	}

	var restored := GameState.deserialize(data)

	assert_null(restored,
			"TimingWindowState must not accept projection or rule-state payloads")


func test_timing_window_state_rejects_invalid_controller_value() -> void:
	var state := GameState.new()
	state.initialize()
	var data := state.serialize()
	data["timing_window_state"] = {
		"active": true,
		"timing_window_id": "attack_modify",
		"lifecycle_stage": "modify_attack_dice",
		"lifecycle_id": "tw-invalid-controller",
		"controller_player": Constants.PLAYER_COUNT,
		"continuation_context": {},
		"status": "open",
	}

	var restored := GameState.deserialize(data)

	assert_null(restored,
			"TimingWindowState should reject controllers outside player domain")


func test_configure_active_rejects_runtime_json_unsafe_continuation() -> void:
	var timing_state = TimingWindowStateScript.new()

	var ok: bool = timing_state.configure_active(
			"attack_modify",
			"modify_attack_dice",
			"tw-runtime-json-unsafe",
			0,
			{"continuation_id": Vector2(1.0, 2.0)})

	assert_false(ok,
			"Runtime construction should reject JSON-unsafe continuation values")
	assert_true(timing_state.is_inactive(),
			"Rejected runtime construction should leave state inactive")


func test_configure_active_rejects_runtime_invalid_controller() -> void:
	var timing_state = TimingWindowStateScript.new()

	var ok: bool = timing_state.configure_active(
			"attack_modify",
			"modify_attack_dice",
			"tw-runtime-invalid-controller",
			Constants.PLAYER_COUNT,
			{})

	assert_false(ok,
			"Runtime construction should reject invalid controller identifiers")
	assert_true(timing_state.is_inactive(),
			"Rejected invalid controller should not create active state")


func test_failed_reconfiguration_preserves_existing_active_state() -> void:
	var timing_state = _make_active_timing_window(
			"attack_modify",
			"modify_attack_dice",
			"tw-stable-before-rejection",
			0,
			{"continuation_id": "confirm_attack_dice"})
	var before: Dictionary = timing_state.serialize()

	var ok: bool = timing_state.configure_active(
			"attack_modify",
			"modify_attack_dice",
			"tw-invalid-reconfiguration",
			0,
			{"continuation_id": false})

	assert_false(ok, "Invalid reconfiguration should fail")
	assert_eq(timing_state.serialize(), before,
			"Failed reconfiguration must leave active lifecycle state unchanged")


func test_timing_window_state_rejects_forbidden_continuation_context() -> void:
	var state := GameState.new()
	state.initialize()
	var data := state.serialize()
	data["timing_window_state"] = {
		"active": true,
		"timing_window_id": "attack_modify",
		"lifecycle_stage": "modify_attack_dice",
		"lifecycle_id": "tw-forbidden-continuation",
		"controller_player": 0,
		"continuation_context": {
			"rule_state": {"pending_authorization": true},
		},
		"status": "open",
	}

	var restored := GameState.deserialize(data)

	assert_null(restored,
			"Continuation context must not accept rule state or nested data")


func test_timing_window_state_rejects_nested_continuation_values() -> void:
	var timing_state = TimingWindowStateScript.new()

	var ok: bool = timing_state.configure_active(
			"attack_modify",
			"modify_attack_dice",
			"tw-nested-continuation",
			0,
			{"continuation_id": {"id": "confirm_attack_dice"}})

	assert_false(ok,
			"Continuation context should use governed scalar semantic fields")
	assert_true(timing_state.is_inactive(),
			"Nested continuation data should not become authoritative state")


func test_timing_window_state_requires_semantic_continuation_value_types() -> void:
	var invalid_contexts: Array[Dictionary] = [
		{"continuation_id": false},
		{"resume_point": 3},
		{"source_id": NAN},
		{"source_type": INF},
		{"owner_player": 1.0},
	]
	for continuation: Dictionary in invalid_contexts:
		var timing_state = TimingWindowStateScript.new()
		assert_false(timing_state.configure_active(
				"attack_modify",
				"modify_attack_dice",
				"tw-invalid-continuation",
				0,
				continuation),
				"Continuation context must reject invalid semantic values")
		assert_true(timing_state.is_inactive(),
				"Rejected continuation context must not mutate lifecycle state")


func test_timing_window_state_normalizes_allowed_continuation_context() -> void:
	var timing_state = _make_active_timing_window(
			"attack_modify",
			"modify_attack_dice",
			"tw-continuation-shape",
			0,
			{
				"continuation_id": "confirm_attack_dice",
				"resume_point": "attack_modify",
				"source_id": "upgrade-h9-1",
				"source_type": "runtime_upgrade",
				"owner_player": 1,
			})

	assert_eq(timing_state.continuation_context,
			{
				"continuation_id": "confirm_attack_dice",
				"resume_point": "attack_modify",
				"source_id": "upgrade-h9-1",
				"source_type": "runtime_upgrade",
				"owner_player": 1,
			},
			"Continuation context should retain only its fixed semantic shape")


func test_active_terminal_timing_window_statuses_are_rejected() -> void:
	for terminal_status: String in [
			TimingWindowStateScript.STATUS_CANCELLED,
			TimingWindowStateScript.STATUS_REPLACED]:
		var timing_state = TimingWindowStateScript.new()
		assert_false(timing_state.configure_active(
				"attack_modify",
				"modify_attack_dice",
				"tw-terminal-status",
				0,
				{},
				terminal_status),
				"Active terminal timing-window status must be rejected")
		assert_true(timing_state.is_inactive(),
				"Rejected active terminal status must preserve inactive state")
		assert_null(GameState.deserialize({
			"timing_window_state": {
				"active": true,
				"timing_window_id": "attack_modify",
				"lifecycle_stage": "modify_attack_dice",
				"lifecycle_id": "tw-terminal-status",
				"controller_player": 0,
				"continuation_context": {},
				"status": terminal_status,
			},
		}), "Serialized active terminal status must fail closed")


func test_same_type_timing_windows_have_distinct_lifecycle_identities() -> void:
	var first = _make_active_timing_window(
			"attack_modify",
			"modify_attack_dice",
			"tw-same-type-001",
			0,
			{"continuation_id": "confirm_attack_dice"})
	var second = _make_active_timing_window(
			"attack_modify",
			"modify_attack_dice",
			"tw-same-type-002",
			0,
			{"continuation_id": "confirm_attack_dice"})

	var restored_first := GameState.deserialize(
			{"timing_window_state": first.serialize()})
	var restored_second := GameState.deserialize(
			{"timing_window_state": second.serialize()})

	assert_false(first.equals(second),
			"Same-type windows should remain distinct by lifecycle identity")
	assert_eq(
			restored_first.timing_window_state.lifecycle_id,
			"tw-same-type-001",
			"First same-type lifecycle identity should round-trip")
	assert_eq(
			restored_second.timing_window_state.lifecycle_id,
			"tw-same-type-002",
			"Second same-type lifecycle identity should round-trip")


func test_timing_window_state_nested_dictionary_does_not_alias() -> void:
	var state := GameState.new()
	state.initialize()
	assert_true(state.set_timing_window_state(_make_active_timing_window(
			"attack_modify",
			"modify_attack_dice",
			"tw-0004",
			0,
			{"continuation_id": "confirm_attack_dice"})),
			"GameState should accept valid timing-window state")
	var data := state.serialize()

	var restored := GameState.deserialize(data)
	data["timing_window_state"]["continuation_context"]["continuation_id"] = "changed"

	assert_eq(
			restored.timing_window_state.continuation_context["continuation_id"],
			"confirm_attack_dice",
			"Deserialized timing-window state must not alias serialized dictionaries")


func test_timing_window_state_input_and_output_do_not_alias() -> void:
	var input_context: Dictionary = {"continuation_id": "confirm_attack_dice"}
	var timing_state = _make_active_timing_window(
			"attack_modify",
			"modify_attack_dice",
			"tw-aliasing",
			0,
			input_context)
	input_context["continuation_id"] = "changed-input"
	var exposed_context: Dictionary = timing_state.continuation_context
	exposed_context["continuation_id"] = "changed-output"
	var serialized: Dictionary = timing_state.serialize()
	serialized["continuation_context"]["continuation_id"] = "changed-serialized"

	assert_eq(timing_state.continuation_context["continuation_id"],
			"confirm_attack_dice",
			"Input, property output, and serialized output must not alias state")


func test_game_state_clones_timing_window_state_replacements() -> void:
	var game_state := GameState.new()
	game_state.initialize()
	var replacement = _make_active_timing_window(
			"attack_modify",
			"modify_attack_dice",
			"tw-game-state-replacement",
			0,
			{"continuation_id": "confirm_attack_dice"})

	assert_true(game_state.set_timing_window_state(replacement),
			"GameState should accept a valid replacement")
	assert_not_same(game_state.timing_window_state, replacement,
			"GameState should own an isolated validated lifecycle state")
	assert_false(game_state.set_timing_window_state(null),
			"GameState should reject a null timing-window replacement")
	assert_eq(game_state.timing_window_state.lifecycle_id,
			"tw-game-state-replacement",
			"Rejected replacement must leave authoritative lifecycle state unchanged")


func test_legacy_interaction_flow_does_not_create_active_timing_window() -> void:
	var state := GameState.new()
	state.initialize()
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			1,
			Constants.Visibility.ALL,
			{"legacy_payload": true})
	var data := state.serialize()
	data.erase("timing_window_state")

	var restored := GameState.deserialize(data)

	assert_not_null(restored, "Legacy InteractionFlow state should still load")
	assert_true(restored.timing_window_state.is_inactive(),
			"InteractionFlow must not become timing-window lifecycle authority")


# --- Player State ---

func test_player_state_default_faction() -> void:
	var ps := PlayerState.new()
	assert_eq(ps.faction, Constants.Faction.REBEL_ALLIANCE, "Default faction should be Rebel Alliance")


func test_player_state_serialize_round_trip() -> void:
	var ps := PlayerState.new()
	ps.player_index = 1
	ps.faction = Constants.Faction.GALACTIC_EMPIRE
	ps.fleet_points = 385
	ps.score = 120

	var data := ps.serialize()
	var restored := PlayerState.deserialize(data)

	assert_eq(restored.player_index, 1)
	assert_eq(restored.faction, Constants.Faction.GALACTIC_EMPIRE)
	assert_eq(restored.fleet_points, 385)
	assert_eq(restored.score, 120)


func _make_active_timing_window(
		window_id: String,
		stage: String,
		lifecycle_id: String,
		controller: int,
		continuation: Dictionary):
	var state = TimingWindowStateScript.new()
	assert_true(state.configure_active(
			window_id, stage, lifecycle_id, controller, continuation),
			"Test helper should build valid timing-window state")
	return state


func _is_json_safe(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return true
		TYPE_ARRAY:
			var array_value: Array = value as Array
			for item: Variant in array_value:
				if not _is_json_safe(item):
					return false
			return true
		TYPE_DICTIONARY:
			var dict: Dictionary = value as Dictionary
			for key: Variant in dict.keys():
				if typeof(key) != TYPE_STRING:
					return false
				if not _is_json_safe(dict[key]):
					return false
			return true
		_:
			return false
