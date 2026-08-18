## Model C-S production protocol evidence for one canonical individual attack.
extends GutTest


const SHIP_ACTIVATION_ID: String = "ship-activation:fixture"
const SQUADRON_ACTIVATION_ID: String = "squadron-activation:fixture"
const CONTEXT_NON_ROGUE_PHASE: String = "non_rogue_squadron_phase"
const CONTEXT_ROGUE_PHASE: String = "rogue_squadron_phase"


const PROCESSOR_SCRIPT: GDScript = preload(
		"res://src/autoload/command_processor.gd")
const SAVE_MANAGER_SCRIPT: GDScript = preload(
		"res://src/autoload/save_game_manager.gd")
const CURRENT_ATTACK_FIXTURE: GDScript = preload(
		"res://tests/fixtures/current_attack_state_fixture.gd")
const ECM_SCRIPT: GDScript = preload(
		"res://src/core/effects/rules/upgrades/defensive_retrofit/electronic_countermeasures.gd")
const REPLAY_DRIVER_SCRIPT: GDScript = preload(
		"res://src/autoload/replay_driver.gd")
const GAME_BOARD_SCENE: PackedScene = preload(
		"res://src/scenes/game_board/game_board.tscn")
const CF_RULE: GDScript = preload(
		"res://src/core/effects/rules/concentrate_fire_token.gd")
const CF_DECLINE: GDScript = preload(
		"res://src/core/commands/decline_concentrate_fire_token_reroll_command.gd")

const SHIP_KEY: String = "cr90_corvette_a"
const SQUADRON_KEY: String = "x_wing_squadron"
const ATTACKER_SHIP_KEY: String = "victory_ii_class_star_destroyer"
const ATTACKER_SQUADRON_KEY: String = "tie_fighter_squadron"
const UNIQUE_SQUADRON_KEY: String = "x_wing_luke_skywalker"
const TEST_SAVE: String = "_gut_slice_8a_current_attack"
const TEST_REPLAY_PATH: String = \
		"res://tests/fixtures/_gut_slice_8a_replay_roundtrip.json"
const EXACT_REPLAY_SEED: int = 8707258039180871004

var _saved_registry: Dictionary = {}
var _saved_state: GameState = null
var _saved_active: bool = false
var _saved_submitter: CommandSubmitter = null
var _saved_play_mode: PlayMode.Mode
var _saved_network_role: NetworkManager.Role
var _saved_local_player: int = -1
var _saved_log_level: GameLogger.Level
var _broadcast_results: Array[Dictionary] = []


func before_each() -> void:
	_saved_registry = GameCommand._registry.duplicate()
	_saved_state = GameManager.current_game_state
	_saved_active = GameManager.is_game_active
	_saved_submitter = GameManager.get_command_submitter()
	_saved_play_mode = PlayMode.current_mode
	_saved_network_role = NetworkManager.role
	_saved_local_player = NetworkManager._local_player_index
	_saved_log_level = GameLogger.min_level
	GameLogger.min_level = GameLogger.Level.WARNING
	_broadcast_results.clear()
	RuleRegistry.clear()
	ConfirmAttackDiceCommand.register()
	CommandProcessor.reset()


func after_each() -> void:
	var capture: Callable = Callable(self, "_capture_network_result")
	if NetworkManager.command_result_received.is_connected(capture):
		NetworkManager.command_result_received.disconnect(capture)
	var cleanup_manager: Node = SAVE_MANAGER_SCRIPT.new()
	cleanup_manager.delete_save(TEST_SAVE)
	cleanup_manager.free()
	if FileAccess.file_exists(TEST_REPLAY_PATH):
		DirAccess.remove_absolute(TEST_REPLAY_PATH)
	RuleRegistry.clear()
	GameCommand._registry = _saved_registry
	GameManager.current_game_state = _saved_state
	GameManager.is_game_active = _saved_active
	GameManager.set_command_submitter(_saved_submitter)
	PlayMode.current_mode = _saved_play_mode
	NetworkManager.role = _saved_network_role
	NetworkManager._local_player_index = _saved_local_player
	GameLogger.min_level = _saved_log_level
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()


func test_local_semantic_sequence_opens_and_completes_production_timing() -> void:
	var state: GameState = _make_state()
	var processor: Node = _make_processor(state)
	var begin_result: Dictionary = processor.submit(
			BeginAttackCommand.new(0, _ship_attack_payload()))
	assert_eq(begin_result.get("attack_id"), "attack:0")
	assert_eq(state.current_attack_state.stage,
			CurrentAttackState.STAGE_PRE_ROLL)
	assert_false(state.timing_window_state.active)

	var roll_result: Dictionary = processor.submit(
			RollDiceCommand.new(0, {"attack_id": "attack:0"}))
	assert_false(roll_result.is_empty())
	assert_eq(state.current_attack_state.stage,
			CurrentAttackState.STAGE_ACCURACY)
	assert_false(state.timing_window_state.active,
			"A blocker-free production lifecycle must confirm and close once.")
	_assert_finish_attack(processor, state, "attack:0")
	assert_eq(_history_types(processor.serialize_history()), [
		"begin_attack", "roll_dice", "confirm_attack_dice",
		"commit_accuracy", "commit_defense", "resolve_damage",
		"complete_attack",
	])
	assert_true(state.current_attack_state.is_inactive())


func test_standard_ship_begin_fails_without_enclosing_attack_opportunity() -> void:
	var state: GameState = _make_state()
	state.get_ship(0, 0).end_attack_step()
	var command := BeginAttackCommand.new(0, _ship_attack_payload())

	assert_eq(command.validate(state),
			"No active authoritative ship Attack-step opportunity.")
	assert_true(command.execute(state).is_empty(),
			"Direct execution must also fail closed without the owner state.")
	assert_true(state.current_attack_state.is_inactive())
	assert_eq(state.get_ship(0, 0).committed_attack_count, 0)


func test_distinct_attacks_and_squadron_targets_use_fresh_sequence_identity() -> void:
	var state: GameState = _make_state()
	var processor: Node = _make_processor(state)
	var payloads: Array[Dictionary] = [
		_ship_attack_payload(0),
		_ship_attack_payload(1),
		_anti_squadron_payload(0),
		_anti_squadron_payload(1),
	]
	var identities: Array[String] = []
	for payload: Dictionary in payloads:
		var ship: ShipInstance = state.get_ship(0, 0)
		ship.end_attack_step()
		ship.begin_attack_step()
		var result: Dictionary = processor.submit(BeginAttackCommand.new(0, payload))
		identities.append(str(result.get("attack_id", "")))
		var cancelled: Dictionary = processor.submit(SkipAttackCommand.new(0, {
			"attack_id": state.current_attack_state.attack_id,
			"reason": "cancelled",
		}))
		assert_true(bool(cancelled.get("skipped", false)))
	assert_eq(identities, ["attack:0", "attack:2", "attack:4", "attack:6"])
	assert_true(state.current_attack_state.is_inactive())


func test_bug_002_step6_uses_authoritative_history_without_consuming_second_attack() -> void:
	var state: GameState = _make_state()
	var ship: ShipInstance = state.get_ship(0, 0)
	ship.begin_attack_step()
	var same_zone: Array[Dictionary] = _two_same_zone_squadron_candidates(state)
	assert_eq(same_zone.size(), 2,
			"Fixture must expose two same-zone anti-squadron targets.")
	if same_zone.size() < 2:
		return
	var processor: Node = _make_processor(state)
	var first: Dictionary = _payload_from_ship_candidate(same_zone[0])
	var second: Dictionary = _payload_from_ship_candidate(same_zone[1])

	_submit_resolved_attack(processor, state, first)
	assert_eq(ship.committed_attack_count, 1)
	assert_eq(ship.anti_squadron_attack_zone,
			int(first.get("attacker_zone", -1)))
	assert_true(ship.has_anti_squadron_target(
			int(first.get("defender_player", -1)),
			int(first.get("defender_index", -1))))
	assert_ne(BeginAttackCommand.new(0, first).validate(state), "",
			"The first Step 6 target cannot be declared twice.")

	_submit_resolved_attack(processor, state, second)
	assert_eq(ship.committed_attack_count, 1,
			"A Step 6 repetition remains part of one normal attack.")
	assert_eq(ship.used_attack_hull_zones,
			[int(first.get("attacker_zone", -1))])
	assert_eq(ship.anti_squadron_attack_zone, -1,
			"Exhausting eligible same-zone targets closes Step 6.")
	assert_true(ship.anti_squadron_target_history.is_empty())


func test_bug_002_step6_decline_retains_legal_different_zone_attack() -> void:
	var state: GameState = _make_state()
	var ship: ShipInstance = state.get_ship(0, 0)
	ship.begin_attack_step()
	var sequence: Dictionary = _step6_and_different_zone_ship_candidates(state)
	var same_zone: Array[Dictionary] = []
	same_zone.assign(sequence.get("squadrons", []))
	assert_eq(same_zone.size(), 2)
	if same_zone.size() < 2:
		return
	var processor: Node = _make_processor(state)
	var first: Dictionary = _payload_from_ship_candidate(same_zone[0])
	_submit_resolved_attack(processor, state, first)
	var first_zone: int = int(first.get("attacker_zone", -1))

	var declined: Dictionary = processor.submit(SkipAttackCommand.new(0, {
		"reason": "squadron_done",
		"ship_index": 0,
	}))
	assert_eq(declined.get("continuation", ""),
			CompleteAttackCommand.CONTINUATION_NORMAL_ATTACK)
	assert_eq(ship.committed_attack_count, 1)
	assert_eq(ship.anti_squadron_attack_zone, -1)
	assert_ne(BeginAttackCommand.new(0, first).validate(state), "",
			"The used hull zone remains unavailable after Step 6 ends.")

	var second_candidate: Dictionary = sequence.get("ship", {}) as Dictionary
	assert_false(second_candidate.is_empty(),
			"Fixture must expose a legal different-zone ship target.")
	if second_candidate.is_empty():
		return
	_submit_resolved_attack(processor, state,
			_payload_from_ship_candidate(second_candidate))
	assert_eq(ship.committed_attack_count, 2)
	assert_eq(ship.used_attack_hull_zones.size(), 2)
	assert_ne(ship.used_attack_hull_zones[0], ship.used_attack_hull_zones[1])
	var third: Dictionary = _different_zone_candidate(
			state, first_zone, "")
	if not third.is_empty():
		assert_ne(BeginAttackCommand.new(0,
				_payload_from_ship_candidate(third)).validate(state), "",
				"No third normal ship attack remains.")


func test_bug_002_progress_matches_hotseat_host_client_replay_and_restore() -> void:
	var initial: GameState = _make_state()
	initial.get_ship(0, 0).begin_attack_step()
	var candidates: Array[Dictionary] = _two_same_zone_squadron_candidates(initial)
	assert_eq(candidates.size(), 2)
	if candidates.size() < 2:
		return
	var payload: Dictionary = _payload_from_ship_candidate(candidates[0])
	var initial_data: Dictionary = initial.serialize()

	PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
	NetworkManager.role = NetworkManager.Role.NONE
	var hotseat_state: GameState = GameState.deserialize(initial_data)
	var hotseat: Node = _make_processor(hotseat_state)
	_submit_resolved_attack(hotseat, hotseat_state, payload)
	var hotseat_history: Array[Dictionary] = hotseat.serialize_history()
	var hotseat_final: Dictionary = hotseat_state.serialize()

	var authority_state: GameState = GameState.deserialize(initial_data)
	GameManager.current_game_state = authority_state
	GameManager.is_game_active = true
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.SERVER
	NetworkManager._local_player_index = 0
	NetworkManager._host_match_principal_id = authority_state.principal_id_for_player(
			0)
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()
	_broadcast_results.clear()
	var host := NetworkHostCommandSubmitter.new()
	GameManager.set_command_submitter(host)
	NetworkManager.command_result_received.connect(_capture_network_result)
	_submit_resolved_attack(host, authority_state, payload)
	var authority_history: Array[Dictionary] = _broadcast_command_data()
	var authority_final: Dictionary = authority_state.serialize()
	assert_eq(authority_history, hotseat_history)
	assert_eq(authority_final, hotseat_final)

	var client_state: GameState = GameState.deserialize(initial_data)
	GameManager.current_game_state = client_state
	NetworkManager.role = NetworkManager.Role.CLIENT
	NetworkManager._local_player_index = 1
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()
	GameManager.set_command_submitter(NetworkCommandSubmitter.new())
	for index: int in range(_broadcast_results.size()):
		_apply_broadcast_to_client(index)
	assert_eq(client_state.serialize(), authority_final)
	assert_eq(CommandProcessor.serialize_history(), authority_history)

	var replay_state: GameState = GameState.deserialize(initial_data)
	var replay: Node = _make_processor(replay_state)
	for command_data: Dictionary in authority_history:
		assert_false(replay.submit_replay(
				GameCommand.deserialize(command_data)).is_empty())
	assert_eq(replay_state.serialize(), authority_final)
	assert_eq(replay.serialize_history(), authority_history)

	var persistence_data: Dictionary = authority_final.duplicate(true)
	persistence_data["interaction_flow"] = InteractionFlow.empty().serialize()
	var restored: GameState = GameState.deserialize(
			JSON.parse_string(JSON.stringify(persistence_data)))
	assert_not_null(restored)
	assert_eq(restored.get_ship(0, 0).attack_progress_snapshot(),
			authority_state.get_ship(0, 0).attack_progress_snapshot())


func test_bug_002_second_anti_squadron_attack_can_repeat_surviving_target() -> void:
	var state: GameState = _make_state()
	var ship: ShipInstance = state.get_ship(0, 0)
	ship.begin_attack_step()
	var pair: Array[Dictionary] = \
			_same_squadron_different_zone_candidates(state)
	assert_eq(pair.size(), 2,
			"Fixture must expose one squadron to two attacking hull zones.")
	if pair.size() < 2:
		return
	var processor: Node = _make_processor(state)
	var first: Dictionary = _payload_from_ship_candidate(pair[0])
	var second: Dictionary = _payload_from_ship_candidate(pair[1])
	_submit_resolved_attack(processor, state, first)
	var target: SquadronInstance = state.get_squadron(
			int(first.get("defender_player", -1)),
			int(first.get("defender_index", -1)))
	assert_false(target.is_destroyed(),
			"The selected target must survive for the second-attack regression.")
	if ship.anti_squadron_attack_zone >= 0:
		assert_false(processor.submit(SkipAttackCommand.new(0, {
			"reason": "squadron_done",
			"ship_index": 0,
		})).is_empty())

	assert_eq(BeginAttackCommand.new(0, second).validate(state), "",
			"A different-zone attack may target the same surviving squadron.")
	_submit_resolved_attack(processor, state, second)
	assert_eq(ship.committed_attack_count, 2)
	assert_ne(ship.used_attack_hull_zones[0], ship.used_attack_hull_zones[1])


func test_production_composed_cross_kind_matrix_uses_canonical_capabilities() -> void:
	var cases: Array[Dictionary] = [
		{"attacker_kind": CurrentAttackState.KIND_SHIP,
			"defender_kind": CurrentAttackState.KIND_SHIP},
		{"attacker_kind": CurrentAttackState.KIND_SHIP,
			"defender_kind": CurrentAttackState.KIND_SQUADRON},
		{"attacker_kind": CurrentAttackState.KIND_SQUADRON,
			"defender_kind": CurrentAttackState.KIND_SHIP},
		{"attacker_kind": CurrentAttackState.KIND_SQUADRON,
			"defender_kind": CurrentAttackState.KIND_SQUADRON},
	]
	for spec: Dictionary in cases:
		var state: GameState = _make_cross_kind_state(
				str(spec["attacker_kind"]), str(spec["defender_kind"]),
				SQUADRON_KEY)
		var processor: Node = _make_processor(state)
		var payload: Dictionary = _first_authoritative_payload(
				state, str(spec["attacker_kind"]),
				str(spec["defender_kind"]))
		assert_false(payload.is_empty(), "Each 2x2 pair must be targetable.")
		var begin: Dictionary = processor.submit(
				BeginAttackCommand.new(0, payload))
		assert_false(begin.is_empty())
		assert_eq(state.current_attack_state.attacker_kind,
				str(spec["attacker_kind"]))
		assert_eq(state.current_attack_state.attacker_index, 0)
		assert_eq(state.current_attack_state.defender_kind,
				str(spec["defender_kind"]))
		assert_eq(state.current_attack_state.defender_index, 0)
		assert_eq(state.current_attack_state.dice_pool,
				_expected_source_pool(state, payload),
				"The canonical pool must come from the pair-specific armament.")
		_submit_through_accuracy(processor, state)
		if str(spec["defender_kind"]) == CurrentAttackState.KIND_SHIP:
			assert_true(state.current_attack_state.accuracy_complete)
			assert_eq(state.current_attack_state.accuracy_locked_tokens, [])
			assert_eq(state.current_attack_state.defense_stage,
					CurrentAttackState.DEFENSE_PENDING)
			assert_false(processor.submit(CommitDefenseCommand.new(1, {
				"attack_id": state.current_attack_state.attack_id,
				"defender_kind": CurrentAttackState.KIND_SHIP,
				"defender_index": 0,
				"ship_index": 0,
				"selected_indices": [],
			})).is_empty())
		else:
			assert_true(state.get_squadron(1, 0).defense_tokens.is_empty())
			assert_true(state.current_attack_state.is_inactive(),
					"A generic squadron bypasses unavailable token input "
					+"through the authoritative damage continuation.")
		assert_true(state.current_attack_state.is_inactive())
		var types: Array[String] = _history_types(
				processor.serialize_history())
		assert_eq(types.slice(types.size() - 2),
				["resolve_damage", "complete_attack"])
		assert_eq(state.current_phase,
				Constants.GamePhase.SHIP \
				if str(spec["attacker_kind"]) == CurrentAttackState.KIND_SHIP \
				else Constants.GamePhase.SQUADRON)


func test_unique_squadron_defense_tokens_survive_ship_and_squadron_attacks() -> void:
	for attacker_kind: String in [
			CurrentAttackState.KIND_SHIP,
			CurrentAttackState.KIND_SQUADRON]:
		var state: GameState = _make_cross_kind_state(
				attacker_kind, CurrentAttackState.KIND_SQUADRON,
				UNIQUE_SQUADRON_KEY)
		var processor: Node = _make_processor(state)
		var payload: Dictionary = _first_authoritative_payload(
				state, attacker_kind, CurrentAttackState.KIND_SQUADRON)
		assert_false(payload.is_empty())
		assert_false(processor.submit(
				BeginAttackCommand.new(0, payload)).is_empty())
		_submit_through_accuracy(processor, state)
		var unique: SquadronInstance = state.get_squadron(1, 0)
		assert_true(unique.squadron_data.is_unique)
		assert_eq(unique.defense_tokens.size(), 2)
		assert_eq(state.current_attack_state.defense_stage,
				CurrentAttackState.DEFENSE_PENDING,
				"A unique squadron's runtime tokens must retain defense input.")
		assert_false(processor.submit(CommitDefenseCommand.new(1, {
			"attack_id": state.current_attack_state.attack_id,
			"defender_kind": CurrentAttackState.KIND_SQUADRON,
			"defender_index": 0,
			"selected_indices": [0],
		})).is_empty())
		assert_eq(unique.defense_tokens[0].get("state"),
				Constants.DefenseTokenState.EXHAUSTED)
		assert_true(state.current_attack_state.is_inactive())
		assert_eq(_history_types(processor.serialize_history()).slice(-4),
				["commit_defense", "spend_defense_token",
					"resolve_damage", "complete_attack"])


func test_host_attacker_remote_defender_rejects_remote_defense_submission() -> void:
	_assert_network_evade_redirect_topology(0, 1)


func test_remote_attacker_host_defender_rejects_remote_defense_submission() -> void:
	_assert_network_evade_redirect_topology(1, 0)


func test_bug_014_refreshed_evade_click_submits_semantic_command_once() -> void:
	PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
	NetworkManager.role = NetworkManager.Role.NONE
	NetworkManager._local_player_index = -1
	var state: GameState = _make_state()
	GameManager.current_game_state = state
	GameManager.is_game_active = true
	CommandProcessor.reset()
	var submitter := LocalCommandSubmitter.new(
			state.principal_id_for_player(0))
	GameManager.set_command_submitter(submitter)
	var begin: Dictionary = submitter.submit(
			BeginAttackCommand.new(0, _ship_attack_payload()))
	assert_false(begin.is_empty())
	_submit_through_accuracy(CommandProcessor, state)
	var defender: ShipInstance = state.get_ship(1, 0)
	var evade_index: int = _defense_token_index(
			defender, Constants.DefenseToken.EVADE)
	assert_gte(evade_index, 0)
	assert_false(submitter.submit(CommitDefenseCommand.new(1, {
		"attack_id": state.current_attack_state.attack_id,
		"defender_kind": CurrentAttackState.KIND_SHIP,
		"defender_index": 0,
		"ship_index": 0,
		"selected_indices": [evade_index],
	})).is_empty())
	assert_eq(CommandProcessor.get_history()[-1].command_type,
			"spend_defense_token")

	var panel := AttackSimPanel.new()
	add_child_autofree(panel)
	panel.show_initial_attack_exec("Defender")
	panel.show_dice_results(state.current_attack_state.dice_results)
	panel.show_evade_die_selection(state.current_attack_state.range_band)
	panel.evade_die_confirmed.connect(func(die_index: int) -> void:
		GameManager.submit_select_evade_die(defender, die_index))
	panel.show_dice_results(state.current_attack_state.dice_results)
	assert_eq(panel._dice_textures[0].mouse_filter,
			Control.MOUSE_FILTER_STOP)

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	panel._dice_textures[0].gui_input.emit(click)
	var history_types: Array[String] = _history_types(
			CommandProcessor.serialize_history())
	assert_eq(history_types.count("select_evade_die"), 1)
	assert_true(state.current_attack_state.is_inactive(),
			"The accepted Evade command must continue through attack completion.")


func test_begin_attack_rejects_tampered_authoritative_entry_facts() -> void:
	var state: GameState = _make_state()
	var valid: Dictionary = _ship_attack_payload()
	assert_eq(BeginAttackCommand.new(0, valid).validate(state), "")

	var wrong_range: Dictionary = valid.duplicate(true)
	wrong_range["range_band"] = Constants.RANGE_BAND_LONG
	assert_ne(BeginAttackCommand.new(0, wrong_range).validate(state), "",
			"Caller-provided range cannot replace authoritative geometry.")
	var wrong_obstruction: Dictionary = valid.duplicate(true)
	wrong_obstruction["obstructed"] = true
	assert_ne(BeginAttackCommand.new(0, wrong_obstruction).validate(state), "",
			"Caller-provided obstruction cannot replace authoritative LOS.")
	var friendly: Dictionary = valid.duplicate(true)
	friendly["defender_player"] = 0
	friendly["defender_index"] = 1
	assert_ne(BeginAttackCommand.new(0, friendly).validate(state), "",
			"Target ownership is validated by authoritative fleet state.")


func test_reconstruction_rejects_inactive_ship_attack_modify_only() -> void:
	var ship_state: GameState = _make_state()
	ship_state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			0, Constants.Visibility.ALL, {"attacker_player": 0})
	assert_not_null(CURRENT_ATTACK_FIXTURE.install(ship_state, {
		"attack_id": "attack:40",
		"stage": CurrentAttackState.STAGE_ATTACK_MODIFY,
		"attacker_kind": CurrentAttackState.KIND_SHIP,
		"defender_kind": CurrentAttackState.KIND_SHIP,
		"dice_results": [{
			"color": int(Constants.DiceColor.RED),
			"face": int(Constants.DiceFace.HIT),
		}],
	}))
	assert_null(GameState.deserialize(ship_state.serialize()),
			"A stale pre-activation ship snapshot must fail before projection.")

	var squadron_state: GameState = _make_state()
	squadron_state.current_phase = Constants.GamePhase.SQUADRON
	squadron_state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			0, Constants.Visibility.ALL, {"attacker_player": 0})
	assert_not_null(CURRENT_ATTACK_FIXTURE.install(squadron_state, {
		"attack_id": "attack:41",
		"stage": CurrentAttackState.STAGE_ATTACK_MODIFY,
		"attacker_kind": CurrentAttackState.KIND_SQUADRON,
		"defender_kind": CurrentAttackState.KIND_SHIP,
		"dice_results": [{
			"color": int(Constants.DiceColor.BLUE),
			"face": int(Constants.DiceFace.HIT),
		}],
	}))
	assert_not_null(GameState.deserialize(squadron_state.serialize()),
			"The accepted inactive squadron confirmation path must reconstruct.")


func test_stale_or_duplicate_commands_leave_state_and_cursor_unchanged() -> void:
	var state: GameState = _make_state()
	var processor: Node = _make_processor(state)
	processor.submit(BeginAttackCommand.new(0, _ship_attack_payload()))
	var before: Dictionary = state.serialize()
	assert_eq(processor.submit(BeginAttackCommand.new(0,
			_ship_attack_payload())), {})
	assert_eq(processor.get_next_sequence(), 1)
	assert_eq(state.serialize(), before)
	processor.submit(RollDiceCommand.new(0, {"attack_id": "attack:0"}))
	before = state.serialize()
	assert_eq(processor.submit(ConfirmAttackDiceCommand.new(0, {
		"attack_id": "attack:stale",
	})), {})
	assert_eq(processor.get_next_sequence(), 3)
	assert_eq(state.serialize(), before)
	assert_engine_error(2,
			"Both rejected commands should diagnose without advancing authority.")


func test_production_opened_lifecycle_continues_same_canonical_attack() -> void:
	CF_RULE.register()
	CF_DECLINE.register()
	var state: GameState = _make_state()
	assert_true(state.get_ship(0, 0).command_tokens.add_token(
			Constants.CommandType.CONCENTRATE_FIRE))
	var processor: Node = _make_processor(state)
	processor.submit(BeginAttackCommand.new(0, _ship_attack_payload()))
	processor.submit(RollDiceCommand.new(0, {"attack_id": "attack:0"}))
	assert_true(state.timing_window_state.active)
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			0, Constants.Visibility.ALL, {"attacker_player": 0})
	processor.submit(CF_DECLINE.new(0, _cf_identity_payload(state)))
	assert_eq(state.current_attack_state.attack_id, "attack:0")
	assert_eq(state.current_attack_state.stage,
			CurrentAttackState.STAGE_ACCURACY)
	assert_true(state.timing_window_state.is_inactive())
	assert_eq(_history_types(processor.serialize_history()), [
		"begin_attack", "roll_dice", CF_DECLINE.TYPE,
		ConfirmAttackDiceCommand.TYPE,
	])


func test_host_client_mirror_and_replay_preserve_identity_and_state() -> void:
	var initial: GameState = _make_state()
	var authority_state: GameState = GameState.deserialize(initial.serialize())
	var registrar: Node = _make_processor(authority_state)
	assert_not_null(registrar,
			"Production command factories must be registered for mirror execution.")
	GameManager.current_game_state = authority_state
	GameManager.is_game_active = true
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.SERVER
	NetworkManager._local_player_index = 0
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()
	var host_submitter := NetworkHostCommandSubmitter.new()
	GameManager.set_command_submitter(host_submitter)
	NetworkManager.command_result_received.connect(_capture_network_result)
	_submit_full_attack(host_submitter)
	var authoritative_history: Array[Dictionary] = _broadcast_command_data()
	assert_eq(_history_sequences(authoritative_history), [0, 1, 2, 3, 4, 5, 6])
	assert_eq(CommandProcessor.serialize_history(), authoritative_history)
	var replay_file := GameReplay.new()
	replay_file.capture_header("twi-002-production", 8108, [0, 1], 0, 0,
			initial.serialize().get("match_player_control_binding", {}))
	replay_file.set_commands(authoritative_history)
	assert_not_null(GameReplay.deserialize(replay_file.serialize()),
			"The production semantic history must load as format 6.")
	var authority_final: Dictionary = authority_state.serialize()

	var client_state: GameState = GameState.deserialize(initial.serialize())
	GameManager.current_game_state = client_state
	NetworkManager.role = NetworkManager.Role.CLIENT
	NetworkManager._local_player_index = 1
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()
	GameManager.set_command_submitter(NetworkCommandSubmitter.new())
	_apply_broadcast_to_client(2)
	assert_eq(CommandProcessor.get_next_sequence(), 0)
	for index: int in [0, 1, 3, 4, 5, 6]:
		_apply_broadcast_to_client(index)
	assert_eq(CommandProcessor.serialize_history(), authoritative_history)
	assert_eq(client_state.serialize(), authority_final)

	var replay_state: GameState = GameState.deserialize(initial.serialize())
	var replay: Node = _make_processor(replay_state)
	for command_data: Dictionary in authoritative_history:
		replay.submit_replay(GameCommand.deserialize(command_data))
	assert_eq(replay_state.serialize(), authority_final)
	assert_eq(replay.serialize_history(), authoritative_history)


func test_confirmed_replacement_target_matches_hotseat_host_client_and_replay() -> void:
	var initial: GameState = _make_replacement_protocol_state()
	var initial_data: Dictionary = initial.serialize()
	var payloads: Dictionary = _replacement_protocol_payloads(initial)
	assert_false(payloads.is_empty())

	PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
	NetworkManager.role = NetworkManager.Role.NONE
	var hotseat_state: GameState = GameState.deserialize(initial_data)
	var hotseat: Node = _make_processor(hotseat_state)
	_submit_replacement_unique_attack(hotseat, payloads)
	var hotseat_history: Array[Dictionary] = hotseat.serialize_history()
	var hotseat_final: Dictionary = hotseat_state.serialize()
	var hotseat_hash: String = CanonicalJson.hash(hotseat_final)
	assert_eq(_history_types(hotseat_history), [
		"begin_attack", "roll_dice", "confirm_attack_dice",
		"commit_accuracy", "commit_defense", "spend_defense_token",
		"resolve_damage", "complete_attack",
	])
	assert_ne(payloads["old"], payloads["new"],
			"Preview candidates must be distinct before one is confirmed.")
	assert_eq(hotseat_history[0]["payload"].get("defender_kind"),
			CurrentAttackState.KIND_SQUADRON)

	var authority_state: GameState = GameState.deserialize(initial_data)
	GameManager.current_game_state = authority_state
	GameManager.is_game_active = true
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.SERVER
	NetworkManager._local_player_index = 0
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()
	_broadcast_results.clear()
	GameManager.set_command_submitter(NetworkHostCommandSubmitter.new())
	NetworkManager.command_result_received.connect(_capture_network_result)
	_submit_replacement_unique_attack(
			GameManager.get_command_submitter(), payloads)
	var authoritative_history: Array[Dictionary] = _broadcast_command_data()
	var authority_final: Dictionary = authority_state.serialize()
	assert_eq(authoritative_history, hotseat_history)
	assert_eq(authority_final, hotseat_final)
	assert_eq(CanonicalJson.hash(authority_final), hotseat_hash)

	var client_state: GameState = GameState.deserialize(initial_data)
	GameManager.current_game_state = client_state
	NetworkManager.role = NetworkManager.Role.CLIENT
	NetworkManager._local_player_index = 1
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()
	GameManager.set_command_submitter(NetworkCommandSubmitter.new())
	_apply_broadcast_to_client(2)
	assert_true(client_state.current_attack_state.is_inactive(),
			"Out-of-order fresh Begin cannot invent a client retarget.")
	for index: int in [0, 1, 3, 4, 5, 6, 7]:
		_apply_broadcast_to_client(index)
	assert_eq(CommandProcessor.serialize_history(), authoritative_history)
	assert_eq(client_state.serialize(), authority_final)
	assert_eq(CanonicalJson.hash(client_state.serialize()), hotseat_hash)

	var replay_state: GameState = GameState.deserialize(initial_data)
	var replay: Node = _make_processor(replay_state)
	for command_data: Dictionary in authoritative_history:
		assert_false(replay.submit_replay(
				GameCommand.deserialize(command_data)).is_empty())
	assert_eq(replay.serialize_history(), authoritative_history)
	assert_eq(replay_state.serialize(), authority_final)
	assert_eq(CanonicalJson.hash(replay_state.serialize()), hotseat_hash)


func test_squadron_to_ship_matches_hotseat_host_client_and_replay() -> void:
	var initial: GameState = _make_cross_kind_state(
			CurrentAttackState.KIND_SQUADRON,
			CurrentAttackState.KIND_SHIP, SQUADRON_KEY)
	var initial_data: Dictionary = initial.serialize()
	var payload: Dictionary = _first_authoritative_payload(
			initial, CurrentAttackState.KIND_SQUADRON,
			CurrentAttackState.KIND_SHIP)
	assert_false(payload.is_empty())

	PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
	NetworkManager.role = NetworkManager.Role.NONE
	var hotseat_state: GameState = GameState.deserialize(initial_data)
	var hotseat: Node = _make_processor(hotseat_state)
	_submit_standard_attack(hotseat, payload, true)
	var hotseat_history: Array[Dictionary] = hotseat.serialize_history()
	var hotseat_final: Dictionary = hotseat_state.serialize()
	var hotseat_hash: String = CanonicalJson.hash(hotseat_final)

	var authority_state: GameState = GameState.deserialize(initial_data)
	GameManager.current_game_state = authority_state
	GameManager.is_game_active = true
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.SERVER
	NetworkManager._local_player_index = 0
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()
	_broadcast_results.clear()
	GameManager.set_command_submitter(NetworkHostCommandSubmitter.new())
	NetworkManager.command_result_received.connect(_capture_network_result)
	_submit_standard_attack(GameManager.get_command_submitter(), payload, true)
	var authoritative_history: Array[Dictionary] = _broadcast_command_data()
	var authority_final: Dictionary = authority_state.serialize()
	assert_eq(authoritative_history, hotseat_history)
	assert_eq(authority_final, hotseat_final)
	assert_eq(CanonicalJson.hash(authority_final), hotseat_hash)

	var client_state: GameState = GameState.deserialize(initial_data)
	GameManager.current_game_state = client_state
	NetworkManager.role = NetworkManager.Role.CLIENT
	NetworkManager._local_player_index = 1
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()
	GameManager.set_command_submitter(NetworkCommandSubmitter.new())
	for index: int in range(authoritative_history.size()):
		_apply_broadcast_to_client(index)
	assert_eq(client_state.serialize(), authority_final)
	assert_eq(CanonicalJson.hash(client_state.serialize()), hotseat_hash)

	var replay_state: GameState = GameState.deserialize(initial_data)
	var replay: Node = _make_processor(replay_state)
	for command_data: Dictionary in authoritative_history:
		assert_false(replay.submit_replay(
				GameCommand.deserialize(command_data)).is_empty())
	assert_eq(replay_state.serialize(), authority_final)
	assert_eq(CanonicalJson.hash(replay_state.serialize()), hotseat_hash)


func test_all_declaration_contexts_match_filtered_host_client_replay() \
		-> void:
	var capture: Callable = Callable(self, "_capture_network_result")
	if not NetworkManager.command_result_received.is_connected(capture):
		NetworkManager.command_result_received.connect(capture)
	for context: String in _declaration_protocol_contexts():
		for begin: bool in [true, false]:
			var initial: GameState = _make_declaration_protocol_state(context)
			var initial_data: Dictionary = initial.serialize()
			var payload: Dictionary = _declaration_protocol_payload(
					initial, context, begin)

			PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
			NetworkManager.role = NetworkManager.Role.NONE
			var hotseat_state: GameState = GameState.deserialize(initial_data)
			_apply_protocol_static_context(hotseat_state, context)
			assert_eq(_declaration_protocol_snapshot(hotseat_state, context),
					_declaration_protocol_snapshot(initial, context))
			var hotseat: Node = _make_processor(hotseat_state)
			var hotseat_command: GameCommand = BeginAttackCommand.new(0, payload) \
					if begin else SkipAttackCommand.new(0, payload)
			assert_false(hotseat.submit(hotseat_command).is_empty())
			var hotseat_history: Array[Dictionary] = hotseat.serialize_history()
			var hotseat_final: Dictionary = hotseat_state.serialize()

			var authority_state: GameState = GameState.deserialize(initial_data)
			_apply_protocol_static_context(authority_state, context)
			assert_eq(_declaration_protocol_snapshot(authority_state, context),
					_declaration_protocol_snapshot(initial, context))
			GameManager.current_game_state = authority_state
			GameManager.is_game_active = true
			PlayMode.set_mode(PlayMode.Mode.NETWORK)
			NetworkManager.role = NetworkManager.Role.SERVER
			NetworkManager._local_player_index = 0
			CommandProcessor.reset()
			GameManager._reset_network_result_ordering()
			_broadcast_results.clear()
			var host := NetworkHostCommandSubmitter.new()
			GameManager.set_command_submitter(host)
			var host_command: GameCommand = BeginAttackCommand.new(0, payload) \
					if begin else SkipAttackCommand.new(0, payload)
			assert_false(host.submit(host_command).is_empty())
			var authoritative_history: Array[Dictionary] = \
					_broadcast_command_data()
			var authority_final: Dictionary = authority_state.serialize()
			assert_eq(authoritative_history, hotseat_history)
			assert_eq(authority_final, hotseat_final)

			var filtered_initial: Dictionary = StateFilter.filter_for_player(
					initial_data, 1)
			var client_state: GameState = GameState.deserialize(filtered_initial)
			assert_not_null(client_state)
			_apply_protocol_static_context(client_state, context)
			assert_eq(_declaration_protocol_snapshot(client_state, context),
					_declaration_protocol_snapshot(initial, context))
			GameManager.current_game_state = client_state
			NetworkManager.role = NetworkManager.Role.CLIENT
			NetworkManager._local_player_index = 1
			CommandProcessor.reset()
			GameManager._reset_network_result_ordering()
			GameManager.set_command_submitter(NetworkCommandSubmitter.new())
			for index: int in range(_broadcast_results.size()):
				_apply_broadcast_to_client(index)
			assert_true(client_state.validate_declaration_adjacent_state())
			assert_eq(_declaration_protocol_snapshot(client_state, context),
					_declaration_protocol_snapshot(authority_state, context))
			assert_eq(CommandProcessor.serialize_history(), authoritative_history)

			var replay_state: GameState = GameState.deserialize(initial_data)
			_apply_protocol_static_context(replay_state, context)
			assert_eq(_declaration_protocol_snapshot(replay_state, context),
					_declaration_protocol_snapshot(initial, context))
			var replay: Node = _make_processor(replay_state)
			for command_data: Dictionary in authoritative_history:
				assert_false(replay.submit_replay(
						GameCommand.deserialize(command_data)).is_empty())
			assert_eq(replay_state.serialize(), authority_final)
			var replay_file := GameReplay.new()
			replay_file.capture_header("twi-003-%s" % context, 8841,
					[0, 1], 0, 0,
					initial.serialize().get("match_player_control_binding", {}))
			replay_file.set_commands(authoritative_history)
			assert_not_null(GameReplay.deserialize(replay_file.serialize()))


func test_declaration_state_matrix_round_trips_save_filter_and_reconnect() \
		-> void:
	var manager: Node = SAVE_MANAGER_SCRIPT.new()
	for context: String in _declaration_protocol_contexts():
		for outcome: String in ["before_begin", "after_begin", "after_skip"]:
			var source: GameState = _make_declaration_protocol_state(context)
			GameManager.current_game_state = source
			GameManager.is_game_active = true
			PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
			NetworkManager.role = NetworkManager.Role.NONE
			NetworkManager._local_player_index = -1
			CommandProcessor.reset()
			if outcome != "before_begin":
				var begin: bool = outcome == "after_begin"
				var command: GameCommand = BeginAttackCommand.new(
						0, _declaration_protocol_payload(source, context, true)) \
						if begin else SkipAttackCommand.new(
								0, _declaration_protocol_payload(
										source, context, false))
				assert_false(CommandProcessor.submit(command).is_empty())
			var expected: Dictionary = _declaration_protocol_snapshot(
					source, context)
			var next_sequence: int = CommandProcessor.get_next_sequence()

			assert_true(manager.save_game(source, TEST_SAVE))
			var loaded: Dictionary = manager.load_game(TEST_SAVE)
			assert_true(bool(loaded.get("ok", false)))
			var restored: GameState = loaded.get("state") as GameState
			_apply_protocol_static_context(restored, context)
			_assert_declaration_protocol_snapshot(
					restored, context, expected, "%s %s save/load" % [
						context, outcome])

			var filtered: Dictionary = StateFilter.filter_for_player(
					source.serialize(), 1)
			var reconnect: GameState = GameState.deserialize(filtered)
			assert_not_null(reconnect)
			_apply_protocol_static_context(reconnect, context)
			PlayMode.set_mode(PlayMode.Mode.NETWORK)
			NetworkManager.role = NetworkManager.Role.CLIENT
			NetworkManager._local_player_index = 1
			assert_true(GameManager.start_new_game_from_state(
					reconnect, "twi-003-%s-%s" % [context, outcome],
					next_sequence))
			_assert_declaration_protocol_snapshot(
					GameManager.current_game_state, context, expected,
					"%s %s filtered reconnect" % [context, outcome])
			assert_true(CommandProcessor.serialize_history().is_empty(),
					"Reconnect must not synthesize a semantic command.")
			manager.delete_save(TEST_SAVE)
	manager.free()


func test_packed_scene_recreation_derives_every_declaration_outcome() -> void:
	for context: String in _declaration_protocol_contexts():
		for outcome: String in ["before_begin", "after_begin", "after_skip"]:
			var state: GameState = _make_declaration_protocol_state(context)
			GameManager.current_game_state = state
			GameManager.is_game_active = true
			PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
			NetworkManager.role = NetworkManager.Role.NONE
			NetworkManager._local_player_index = -1
			CommandProcessor.reset()
			if outcome != "before_begin":
				var begin: bool = outcome == "after_begin"
				var command: GameCommand = BeginAttackCommand.new(
						0, _declaration_protocol_payload(state, context, true)) \
						if begin else SkipAttackCommand.new(
								0, _declaration_protocol_payload(
										state, context, false))
				assert_false(CommandProcessor.submit(command).is_empty())
				assert_eq(_history_types(CommandProcessor.serialize_history()),
						[BeginAttackCommand.TYPE if begin else "skip_attack"])
			var next_sequence: int = CommandProcessor.get_next_sequence()
			assert_true(GameManager.start_new_game_from_state(
					state, LearningScenarioSetup.DEFAULT_SCENARIO_ID,
					next_sequence))
			var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
			add_child(board)
			_assert_declaration_scene_projection(
					board, state, context, outcome)
			assert_true(CommandProcessor.serialize_history().is_empty(),
					"Packed-scene reconstruction must not synthesize commands.")
			board.queue_free()
			await get_tree().process_frame


func test_production_disk_replay_is_exact_and_replay_driver_compatible() -> void:
	var authority_state: GameState = _make_state()
	authority_state.rng = GameRng.new(EXACT_REPLAY_SEED)
	var initial_state: Dictionary = authority_state.serialize()
	GameManager.current_game_state = authority_state
	GameManager.is_game_active = true
	PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
	NetworkManager.role = NetworkManager.Role.NONE
	GameManager.set_command_submitter(LocalCommandSubmitter.new(
			authority_state.principal_id_for_player(0)))
	CommandProcessor.reset()
	_submit_full_attack(GameManager.get_command_submitter())
	var authority_final: Dictionary = authority_state.serialize()
	var authority_history: Array[Dictionary] = \
			CommandProcessor.serialize_history()
	var replay_file: GameReplay = CommandProcessor.create_replay()
	assert_not_null(replay_file,
			"Production replay creation must capture the semantic history.")
	assert_eq(replay_file.save_to_file(TEST_REPLAY_PATH), OK,
			"Production GameReplay persistence must succeed.")

	var loaded: GameReplay = GameReplay.load_from_file(TEST_REPLAY_PATH)
	assert_not_null(loaded, "The persisted format-5 replay must load.")
	assert_typeof(loaded.header["rng_seed"], TYPE_INT)
	assert_eq(loaded.header["rng_seed"], EXACT_REPLAY_SEED,
			"The exact 64-bit replay seed must survive disk JSON.")
	assert_typeof(loaded.header["initial_command_sequence"], TYPE_INT)
	assert_eq(loaded.header["initial_command_sequence"], 0)
	assert_eq(_history_sequences(loaded.commands), [0, 1, 2, 3, 4, 5, 6])
	var persisted_begin: Dictionary = loaded.commands[0]["payload"]
	for field: String in [
			"attacker_player", "attacker_index", "attacker_zone",
			"defender_player", "defender_index", "defender_zone"]:
		assert_typeof(persisted_begin[field], TYPE_INT,
				"ReplayDriver must receive canonical %s." % field)
	var persisted_defense: Dictionary = loaded.commands[4]["payload"]
	assert_typeof(persisted_defense["ship_index"], TYPE_INT)

	var replay_state: GameState = GameState.deserialize(initial_state)
	assert_not_null(replay_state)
	var registrar: Node = _make_processor(replay_state)
	assert_not_null(registrar,
			"Production command factories must remain registered for playback.")
	var driver: Node = REPLAY_DRIVER_SCRIPT.new()
	add_child_autofree(driver)
	driver._replay = loaded
	driver.pending_replay_seed = int(loaded.header["rng_seed"])
	assert_eq(replay_state.rng.initial_seed, driver.pending_replay_seed,
			"Replay bootstrap seed must equal the exact persisted authority.")
	GameManager.current_game_state = replay_state
	GameManager.set_command_submitter(LocalCommandSubmitter.new(
			replay_state.principal_id_for_player(0)))
	CommandProcessor.reset()
	assert_true(CommandProcessor.restore_next_sequence(
			int(loaded.header["initial_command_sequence"])))
	CommandProcessor.command_executed.connect(driver._on_command_executed)
	for command_data: Dictionary in loaded.commands:
		var snapshot: int = driver._observed_count
		assert_true(await driver._submit_local_step(
				command_data, snapshot, true),
				"ReplayDriver must reconstruct and submit each persisted command.")
		assert_eq(driver._observed_count, snapshot + 1,
				"Each accepted command must advance ReplayDriver's cursor once.")
	assert_eq(CommandProcessor.get_next_sequence(), loaded.commands.size(),
			"Replay cursor must remain exact through the persisted sequence.")
	assert_eq(CommandProcessor.serialize_history(), authority_history,
			"ReplayDriver must retain the exact authoritative command history.")
	assert_eq(replay_state.serialize(), authority_final,
			"Exact seed and canonical commands must reproduce final state.")


func test_ecm_completion_cleanup_matches_hotseat_host_mirror_and_replay() -> void:
	var initial: GameState = _make_terminal_ecm_state("attack:80")
	var runtime_upgrade_id: String = str(initial.get_ship(
			1, 0).runtime_upgrades[0].get("runtime_upgrade_id", ""))

	PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
	NetworkManager.role = NetworkManager.Role.NONE
	var hotseat_state: GameState = GameState.deserialize(initial.serialize())
	var hotseat: Node = _make_processor(hotseat_state)
	var hotseat_result: Dictionary = hotseat.submit(
			CompleteAttackCommand.new(0, {"attack_id": "attack:80"}))
	assert_true((hotseat_result.get(
			"ecm_cleared_runtime_upgrade_ids", []) as Array).has(
				runtime_upgrade_id))
	_assert_ecm_pending_empty(hotseat_state, runtime_upgrade_id)
	assert_eq(_history_types(hotseat.serialize_history()), ["complete_attack"])
	var hotseat_final: Dictionary = hotseat_state.serialize()

	var authority_state: GameState = GameState.deserialize(initial.serialize())
	GameManager.current_game_state = authority_state
	GameManager.is_game_active = true
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.SERVER
	NetworkManager._local_player_index = 0
	NetworkManager._host_match_principal_id = authority_state.principal_id_for_player(0)
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()
	GameManager.set_command_submitter(NetworkHostCommandSubmitter.new())
	NetworkManager.command_result_received.connect(_capture_network_result)
	var authority_result: Dictionary = GameManager.get_command_submitter().submit(
			CompleteAttackCommand.new(0, {"attack_id": "attack:80"}))
	assert_true((authority_result.get(
			"ecm_cleared_runtime_upgrade_ids", []) as Array).has(
				runtime_upgrade_id))
	assert_eq(_broadcast_results.size(), 1)
	assert_eq(_history_types(CommandProcessor.serialize_history()),
			["complete_attack"])
	_assert_ecm_pending_empty(authority_state, runtime_upgrade_id)
	var authority_final: Dictionary = authority_state.serialize()
	assert_eq(authority_final, hotseat_final,
			"Host authority and hot-seat must produce the same semantic state.")

	var client_state: GameState = GameState.deserialize(initial.serialize())
	GameManager.current_game_state = client_state
	NetworkManager.role = NetworkManager.Role.CLIENT
	NetworkManager._local_player_index = 1
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()
	GameManager.set_command_submitter(NetworkCommandSubmitter.new())
	_apply_broadcast_to_client(0)
	_assert_ecm_pending_empty(client_state, runtime_upgrade_id)
	assert_eq(client_state.serialize(), authority_final)
	assert_eq(_history_types(CommandProcessor.serialize_history()),
			["complete_attack"])

	var replay_state: GameState = GameState.deserialize(initial.serialize())
	var replay: Node = _make_processor(replay_state)
	var recorded: GameCommand = GameCommand.deserialize(
			_broadcast_results[0].get("command", {}))
	assert_false(replay.submit_replay(recorded).is_empty())
	_assert_ecm_pending_empty(replay_state, runtime_upgrade_id)
	assert_eq(replay_state.serialize(), authority_final)
	assert_eq(_history_types(replay.serialize_history()), ["complete_attack"])


func test_save_load_and_reconnect_resume_production_stages_and_cursor() -> void:
	var state: GameState = _make_state()
	GameManager.current_game_state = state
	CommandProcessor.reset()
	CommandProcessor.submit(BeginAttackCommand.new(0, _ship_attack_payload()))
	CommandProcessor.submit(RollDiceCommand.new(0, {"attack_id": "attack:0"}))
	_assert_round_trip_stage(state, CurrentAttackState.STAGE_ACCURACY)
	CommandProcessor.submit(CommitAccuracyCommand.new(0, {
		"attack_id": "attack:0", "locked_tokens": [],
	}))
	_assert_round_trip_stage(state, CurrentAttackState.STAGE_DEFENSE)

	var manager: Node = SAVE_MANAGER_SCRIPT.new()
	assert_true(manager.save_game(state, TEST_SAVE))
	var loaded: Dictionary = manager.load_game(TEST_SAVE)
	assert_true(bool(loaded.get("ok", false)))
	var restored: GameState = loaded.get("state") as GameState
	var metadata: SaveGameMetadata = loaded.get("meta") as SaveGameMetadata
	assert_eq(metadata.save_format_version, SaveGameMetadata.CURRENT_VERSION)
	assert_eq(metadata.next_command_sequence, 4)
	assert_true(GameManager.start_new_game_from_state(
			restored, "twi-002-production", metadata.next_command_sequence))
	assert_eq(CommandProcessor.get_next_sequence(), 4)
	assert_eq(GameManager._next_network_result_sequence, 4)
	assert_eq(restored.current_attack_state.stage,
			CurrentAttackState.STAGE_DEFENSE)
	manager.delete_save(TEST_SAVE)
	manager.free()


func _assert_finish_attack(processor: Node, state: GameState,
		attack_id: String) -> void:
	if state.current_attack_state.stage == CurrentAttackState.STAGE_ATTACK_MODIFY:
		assert_false(processor.submit(ConfirmAttackDiceCommand.new(0, {
			"attack_id": attack_id,
		})).is_empty())
	assert_false(processor.submit(CommitAccuracyCommand.new(0, {
		"attack_id": attack_id, "locked_tokens": [],
	})).is_empty())
	assert_false(processor.submit(CommitDefenseCommand.new(1, {
		"attack_id": attack_id, "ship_index": 0,
		"selected_indices": [],
	})).is_empty())
	assert_true(state.current_attack_state.is_inactive())


func _submit_full_attack(submitter: Variant) -> void:
	if submitter is NetworkHostCommandSubmitter \
			and GameManager.current_game_state != null:
		NetworkManager._host_match_principal_id = \
			GameManager.current_game_state.principal_id_for_player(0)
	assert_false(submitter.submit(BeginAttackCommand.new(
			0, _ship_attack_payload())).is_empty())
	assert_false(submitter.submit(RollDiceCommand.new(
			0, {"attack_id": "attack:0"})).is_empty())
	if GameManager.current_game_state.current_attack_state.stage \
			== CurrentAttackState.STAGE_ATTACK_MODIFY:
		assert_false(submitter.submit(ConfirmAttackDiceCommand.new(
				0, {"attack_id": "attack:0"})).is_empty())
	assert_false(submitter.submit(CommitAccuracyCommand.new(0, {
		"attack_id": "attack:0", "locked_tokens": [],
	})).is_empty())
	assert_false(submitter.submit(CommitDefenseCommand.new(1, {
		"attack_id": "attack:0", "ship_index": 0,
		"selected_indices": [],
	})).is_empty())


func _submit_through_accuracy(processor: Node, state: GameState) -> void:
	var attack_id: String = state.current_attack_state.attack_id
	assert_false(processor.submit(RollDiceCommand.new(0, {
		"attack_id": attack_id,
	})).is_empty())
	if state.current_attack_state.stage == CurrentAttackState.STAGE_ATTACK_MODIFY:
		assert_false(processor.submit(ConfirmAttackDiceCommand.new(0, {
			"attack_id": attack_id,
		})).is_empty())
	assert_false(processor.submit(CommitAccuracyCommand.new(0, {
		"attack_id": attack_id,
		"locked_tokens": [],
	})).is_empty())


func _submit_resolved_attack(processor: Variant, state: GameState,
		payload: Dictionary) -> void:
	if processor is NetworkHostCommandSubmitter:
		NetworkManager._host_match_principal_id = state.principal_id_for_player(0)
	var begin: Dictionary = processor.submit(BeginAttackCommand.new(0, payload))
	assert_false(begin.is_empty())
	if begin.is_empty():
		return
	var attack_id: String = str(begin.get("attack_id", ""))
	assert_false(processor.submit(RollDiceCommand.new(0, {
		"attack_id": attack_id,
	})).is_empty())
	if state.current_attack_state.stage == CurrentAttackState.STAGE_ATTACK_MODIFY:
		assert_false(processor.submit(ConfirmAttackDiceCommand.new(0, {
			"attack_id": attack_id,
		})).is_empty())
	assert_false(processor.submit(CommitAccuracyCommand.new(0, {
		"attack_id": attack_id,
		"locked_tokens": [],
	})).is_empty())
	if str(payload.get("defender_kind", "")) == CurrentAttackState.KIND_SHIP:
		assert_false(processor.submit(CommitDefenseCommand.new(
				int(payload.get("defender_player", -1)), {
			"attack_id": attack_id,
			"defender_kind": CurrentAttackState.KIND_SHIP,
			"defender_index": int(payload.get("defender_index", -1)),
			"ship_index": int(payload.get("defender_index", -1)),
			"selected_indices": [],
		})).is_empty())
	assert_true(state.current_attack_state.is_inactive())


func _submit_standard_attack(submitter: Variant, payload: Dictionary,
		commit_ship_defense: bool) -> void:
	if submitter is NetworkHostCommandSubmitter \
			and GameManager.current_game_state != null:
		NetworkManager._host_match_principal_id = \
			GameManager.current_game_state.principal_id_for_player(0)
	var begin: Dictionary = submitter.submit(BeginAttackCommand.new(0, payload))
	assert_false(begin.is_empty())
	var attack_id: String = str(begin.get("attack_id", ""))
	assert_false(submitter.submit(RollDiceCommand.new(0, {
		"attack_id": attack_id,
	})).is_empty())
	if GameManager.current_game_state.current_attack_state.stage \
			== CurrentAttackState.STAGE_ATTACK_MODIFY:
		assert_false(submitter.submit(ConfirmAttackDiceCommand.new(0, {
			"attack_id": attack_id,
		})).is_empty())
	assert_false(submitter.submit(CommitAccuracyCommand.new(0, {
		"attack_id": attack_id,
		"locked_tokens": [],
	})).is_empty())
	if commit_ship_defense:
		if submitter is NetworkHostCommandSubmitter:
			NetworkManager._host_match_principal_id = \
					GameManager.current_game_state.principal_id_for_player(1)
		assert_false(submitter.submit(CommitDefenseCommand.new(1, {
			"attack_id": attack_id,
			"defender_kind": CurrentAttackState.KIND_SHIP,
			"defender_index": 0,
			"ship_index": 0,
			"selected_indices": [],
		})).is_empty())


func _submit_replacement_unique_attack(
		submitter: Variant, payloads: Dictionary) -> void:
	# Preview churn is transient and absent from the semantic command stream.
	var new_begin: Dictionary = submitter.submit(BeginAttackCommand.new(
			0, payloads["new"]))
	assert_false(new_begin.is_empty())
	var attack_id: String = str(new_begin.get("attack_id", ""))
	assert_false(submitter.submit(RollDiceCommand.new(0, {
		"attack_id": attack_id,
	})).is_empty())
	if GameManager.current_game_state.current_attack_state.stage \
			== CurrentAttackState.STAGE_ATTACK_MODIFY:
		assert_false(submitter.submit(ConfirmAttackDiceCommand.new(0, {
			"attack_id": attack_id,
		})).is_empty())
	assert_false(submitter.submit(CommitAccuracyCommand.new(0, {
		"attack_id": attack_id,
		"locked_tokens": [],
	})).is_empty())
	assert_false(submitter.submit(CommitDefenseCommand.new(1, {
		"attack_id": attack_id,
		"defender_kind": CurrentAttackState.KIND_SQUADRON,
		"defender_index": 0,
		"selected_indices": [0],
	})).is_empty())


func _cf_identity_payload(state: GameState) -> Dictionary:
	var attack: CurrentAttackState = state.current_attack_state
	var ship_id: String = CF_RULE.attacking_ship_identity(attack)
	return {
		TimingWindowOrchestrator.COMMAND_KEY_TIMING_WINDOW_ID:
				state.timing_window_state.timing_window_id,
		TimingWindowOrchestrator.COMMAND_KEY_LIFECYCLE_ID:
				state.timing_window_state.lifecycle_id,
		TimingWindowOpportunity.KEY_SOURCE_OWNER_KIND:
				CF_RULE.SOURCE_OWNER_KIND,
		TimingWindowOpportunity.KEY_RUNTIME_SOURCE_ID:
				CF_RULE.token_source_identity(ship_id),
		TimingWindowOpportunity.KEY_SEMANTIC_KEY: CF_RULE.SEMANTIC_KEY,
		CF_RULE.PAYLOAD_ATTACK_ID: attack.attack_id,
		CF_RULE.PAYLOAD_ATTACKING_SHIP_ID: ship_id,
	}


func _assert_network_evade_redirect_topology(
		attacker_player: int, defender_player: int) -> void:
	var state: GameState = _make_network_topology_state(
			attacker_player, defender_player)
	var payload: Dictionary = _first_ship_payload_for_players(
			state, attacker_player, defender_player)
	assert_false(payload.is_empty())
	var registrar: Node = _make_processor(state)
	assert_not_null(registrar,
			"Production command factories must be registered for authority checks.")
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.SERVER
	NetworkManager._local_player_index = attacker_player
	NetworkManager._host_match_principal_id = state.principal_id_for_player(
			attacker_player)
	GameManager.current_game_state = state
	GameManager.is_game_active = true
	CommandProcessor.reset()
	var host_submitter := NetworkHostCommandSubmitter.new()
	GameManager.set_command_submitter(host_submitter)
	var begin: Dictionary = host_submitter.submit(
			BeginAttackCommand.new(attacker_player, payload))
	assert_false(begin.is_empty())
	var attack_id: String = str(begin.get("attack_id", ""))
	assert_false(host_submitter.submit(RollDiceCommand.new(attacker_player, {
		"attack_id": attack_id,
	})).is_empty())
	if state.current_attack_state.stage == CurrentAttackState.STAGE_ATTACK_MODIFY:
		assert_false(host_submitter.submit(ConfirmAttackDiceCommand.new(
				attacker_player, {"attack_id": attack_id})).is_empty())
	assert_false(host_submitter.submit(CommitAccuracyCommand.new(attacker_player, {
		"attack_id": attack_id,
		"locked_tokens": [],
	})).is_empty())
	var defender: ShipInstance = state.get_ship(defender_player, 0)
	var evade_index: int = _defense_token_index(
			defender, Constants.DefenseToken.EVADE)
	assert_gte(evade_index, 0)
	assert_true(host_submitter.submit(CommitDefenseCommand.new(defender_player, {
		"attack_id": attack_id,
		"defender_kind": CurrentAttackState.KIND_SHIP,
		"defender_index": 0,
		"ship_index": 0,
		"selected_indices": [evade_index],
	})).is_empty(),
			"The host principal must not submit a remote player's defense command.")
	assert_engine_error(1,
			"Rejected remote-player submission must diagnose the authorization boundary.")


func _submit_evade_redirect_decisions(
		submitter: CommandSubmitter,
		state: GameState,
		payload: Dictionary,
		attacker_player: int,
		defender_player: int) -> void:
	var begin: Dictionary = submitter.submit(
			BeginAttackCommand.new(attacker_player, payload))
	assert_false(begin.is_empty())
	var attack_id: String = str(begin.get("attack_id", ""))
	assert_false(submitter.submit(RollDiceCommand.new(attacker_player, {
		"attack_id": attack_id,
	})).is_empty())
	if state.current_attack_state.stage == CurrentAttackState.STAGE_ATTACK_MODIFY:
		assert_false(submitter.submit(ConfirmAttackDiceCommand.new(
				attacker_player, {"attack_id": attack_id})).is_empty())
	assert_false(submitter.submit(CommitAccuracyCommand.new(attacker_player, {
		"attack_id": attack_id,
		"locked_tokens": [],
	})).is_empty())
	if submitter is NetworkHostCommandSubmitter:
		NetworkManager._host_match_principal_id = \
				state.principal_id_for_player(defender_player)
	var defender: ShipInstance = state.get_ship(defender_player, 0)
	var evade_index: int = _defense_token_index(
			defender, Constants.DefenseToken.EVADE)
	var redirect_index: int = _defense_token_index(
			defender, Constants.DefenseToken.REDIRECT)
	assert_gte(evade_index, 0)
	assert_gte(redirect_index, 0)
	assert_false(submitter.submit(CommitDefenseCommand.new(
			defender_player, {
				"attack_id": attack_id,
				"defender_kind": CurrentAttackState.KIND_SHIP,
				"defender_index": 0,
				"ship_index": 0,
				"selected_indices": [evade_index, redirect_index],
			})).is_empty())
	assert_eq(_history_types(CommandProcessor.serialize_history()), [
		"begin_attack", "roll_dice", "confirm_attack_dice",
		"commit_accuracy", "commit_defense", "spend_defense_token",
	])
	assert_eq(CommandProcessor.get_history()[-1].player_index,
			defender_player)
	_assert_resume_decision(state, AttackExecutor.RESUME_EVADE,
			defender_player)

	if submitter is NetworkHostCommandSubmitter:
		NetworkManager._host_match_principal_id = \
				state.principal_id_for_player(defender_player)
	assert_false(GameManager.submit_select_evade_die(
			defender, 0).is_empty())
	assert_eq(_history_types(CommandProcessor.serialize_history()).slice(-2),
			["select_evade_die", "spend_defense_token"])
	_assert_resume_decision(state, AttackExecutor.RESUME_REDIRECT,
			defender_player)

	if submitter is NetworkHostCommandSubmitter:
		NetworkManager._host_match_principal_id = \
				state.principal_id_for_player(defender_player)
	assert_false(GameManager.submit_redirect_done(defender).is_empty())
	var expected: Array[String] = [
		"begin_attack", "roll_dice", "confirm_attack_dice",
		"commit_accuracy", "commit_defense", "spend_defense_token",
		"select_evade_die", "spend_defense_token", "redirect_done",
		"resolve_damage", "complete_attack",
	]
	var history: Array[Dictionary] = CommandProcessor.serialize_history()
	var types: Array[String] = _history_types(history)
	assert_eq(types, expected)
	assert_eq(_history_sequences(history),
			[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
	assert_eq(types.count("spend_defense_token"), 2)
	assert_eq(types.count("resolve_damage"), 1)
	assert_eq(types.count("complete_attack"), 1)
	assert_true(state.current_attack_state.is_inactive())


func _assert_resume_decision(state: GameState,
		expected_transition: String,
		expected_controller: int) -> void:
	var executor := AttackExecutor.new()
	var plan: Dictionary = executor._derive_resume_plan(
			state, state.current_attack_state)
	assert_true(bool(plan.get(AttackExecutor.RESUME_KEY_OK, false)))
	assert_eq(plan.get(AttackExecutor.RESUME_KEY_TRANSITION),
			expected_transition)
	assert_true(bool(plan.get(
			AttackExecutor.RESUME_KEY_REQUIRES_INPUT, false)))
	assert_eq(int(plan.get("controller_player", -1)),
			expected_controller)
	executor.free()


func _defense_token_index(
		defender: ShipInstance,
		token_type: Constants.DefenseToken) -> int:
	if defender == null:
		return -1
	for index: int in range(defender.defense_tokens.size()):
		if int(defender.defense_tokens[index].get("type", -1)) \
				== int(token_type):
			return index
	return -1


func _make_processor(state: GameState) -> Node:
	GameManager.current_game_state = state
	if state != null:
		NetworkManager._host_match_principal_id = state.principal_id_for_player(0)
	var processor: Node = PROCESSOR_SCRIPT.new()
	add_child_autofree(processor)
	return processor


func _make_state() -> GameState:
	var state := GameState.new()
	state.initialize()
	_install_hot_seat_binding(state)
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.rng = GameRng.new(8108)
	state.damage_deck = DamageDeck.new()
	state.damage_deck.initialize()
	for owner: int in range(Constants.PLAYER_COUNT):
		for index: int in range(2):
			var ship: ShipInstance = _make_ship(owner)
			var squadron: SquadronInstance = _make_squadron(owner)
			_set_protocol_position(ship, squadron, owner, index)
			if owner == 0 and index == 0:
				assert_true(ship.establish_ship_activation(
						SHIP_ACTIVATION_ID))
				ship.begin_attack_step()
			state.player_states[owner].ships.append(ship)
			state.player_states[owner].squadrons.append(squadron)
	return state


func _make_cross_kind_state(attacker_kind: String,
		defender_kind: String, defender_squadron_key: String) -> GameState:
	var state := GameState.new()
	state.initialize()
	_install_hot_seat_binding(state)
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP \
			if attacker_kind == CurrentAttackState.KIND_SHIP \
			else Constants.GamePhase.SQUADRON
	state.rng = GameRng.new(8841)
	state.damage_deck = DamageDeck.new()
	state.damage_deck.initialize()
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION \
			if attacker_kind == CurrentAttackState.KIND_SHIP \
			else Constants.InteractionFlow.SQUADRON_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT \
			if attacker_kind == CurrentAttackState.KIND_SHIP \
			else Constants.InteractionStep.WAIT_FOR_SQUAD_SELECT,
			0)
	if attacker_kind == CurrentAttackState.KIND_SHIP:
		var ship: ShipInstance = _make_ship_with_key(ATTACKER_SHIP_KEY, 0)
		ship.pos_x = 0.50
		ship.pos_y = 0.65
		assert_true(ship.establish_ship_activation(SHIP_ACTIVATION_ID))
		ship.begin_attack_step()
		state.get_player_state(0).ships.append(ship)
	else:
		assert_true(state.initialize_squadron_phase_progress(0))
		var squadron: SquadronInstance = _make_squadron_with_key(
				ATTACKER_SQUADRON_KEY, 0)
		squadron.pos_x = 0.50
		squadron.pos_y = 0.58
		assert_true(squadron.initialize_activation_action_state(
				SQUADRON_ACTIVATION_ID,
				SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE))
		state.get_player_state(0).squadrons.append(squadron)
	if defender_kind == CurrentAttackState.KIND_SHIP:
		var ship: ShipInstance = _make_ship_with_key(SHIP_KEY, 1)
		ship.pos_x = 0.50
		ship.pos_y = 0.46
		ship.rotation_deg = 180.0
		state.get_player_state(1).ships.append(ship)
	else:
		var squadron: SquadronInstance = _make_squadron_with_key(
				defender_squadron_key, 1)
		squadron.pos_x = 0.50
		squadron.pos_y = 0.50
		state.get_player_state(1).squadrons.append(squadron)
	return state


func _make_commanded_squadron_protocol_state() -> GameState:
	var state := GameState.new()
	state.initialize()
	_install_hot_seat_binding(state)
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.rng = GameRng.new(8841)
	state.damage_deck = DamageDeck.new()
	state.damage_deck.initialize()
	var ship := ShipInstance.create_from_data(
			SHIP_KEY, AssetLoader.load_ship_data(SHIP_KEY), 2, 0)
	ship.pos_x = 0.50
	ship.pos_y = 0.60
	assert_true(ship.command_dial_stack.assign_dials(
			[Constants.CommandType.SQUADRON], 1))
	assert_false(ship.command_dial_stack.reveal_top().is_empty())
	assert_true(ship.establish_ship_activation(SHIP_ACTIVATION_ID))
	assert_true(ship.open_squadron_command_opportunity(SHIP_ACTIVATION_ID))
	assert_true(ship.commit_squadron_command_activation(SHIP_ACTIVATION_ID))
	state.get_player_state(0).ships.append(ship)
	var attacker := SquadronInstance.create_from_data(
			SQUADRON_KEY, AssetLoader.load_squadron_data(SQUADRON_KEY), 0)
	attacker.pos_x = 0.50
	attacker.pos_y = 0.55
	assert_true(attacker.initialize_activation_action_state(
			SQUADRON_ACTIVATION_ID,
			SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND,
			0, 0))
	state.get_player_state(0).squadrons.append(attacker)
	var defender := SquadronInstance.create_from_data(
			ATTACKER_SQUADRON_KEY,
			AssetLoader.load_squadron_data(ATTACKER_SQUADRON_KEY), 1)
	defender.pos_x = 0.50
	defender.pos_y = 0.48
	state.get_player_state(1).squadrons.append(defender)
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.SQUADRON_STEP, 0)
	assert_true(state.validate_declaration_adjacent_state())
	return state


func _declaration_protocol_contexts() -> Array[String]:
	return [
		SkipAttackCommand.CONTEXT_SHIP_ATTACK,
		CONTEXT_NON_ROGUE_PHASE,
		CONTEXT_ROGUE_PHASE,
		SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND,
	]


func _make_declaration_protocol_state(context: String) -> GameState:
	var state: GameState
	match context:
		SkipAttackCommand.CONTEXT_SHIP_ATTACK:
			state = _make_cross_kind_state(
					CurrentAttackState.KIND_SHIP,
					CurrentAttackState.KIND_SHIP, SQUADRON_KEY)
		SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND:
			state = _make_commanded_squadron_protocol_state()
		CONTEXT_NON_ROGUE_PHASE, CONTEXT_ROGUE_PHASE:
			state = _make_cross_kind_state(
					CurrentAttackState.KIND_SQUADRON,
					CurrentAttackState.KIND_SQUADRON, SQUADRON_KEY)
			_apply_protocol_static_context(state, context)
		_:
			assert_true(false, "Unsupported declaration protocol context.")
			return null
	assert_true(state.validate_declaration_adjacent_state())
	return state


func _apply_protocol_static_context(state: GameState, context: String) -> void:
	if state == null or context != CONTEXT_ROGUE_PHASE:
		return
	var squadron: SquadronInstance = state.get_squadron(0, 0)
	if squadron == null or SquadronKeywordRuleHelper.has_keyword(
			squadron, "Rogue"):
		return
	# The test catalog has no Rogue fixture. Supply that static rule fact to each
	# independently reconstructed peer; canonical runtime state is never repaired
	# from a presentation cache.
	var rogue_data: SquadronData = squadron.squadron_data.duplicate(true) \
			as SquadronData
	rogue_data.keywords.append({"name": "Rogue"})
	squadron.squadron_data = rogue_data


func _declaration_protocol_payload(state: GameState, context: String,
		begin: bool) -> Dictionary:
	if context \
			== SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND:
		return _commanded_squadron_protocol_payload(state, begin)
	if not begin:
		if context == SkipAttackCommand.CONTEXT_SHIP_ATTACK:
			return {
				"reason": "voluntary",
				"declaration_context": SkipAttackCommand.CONTEXT_SHIP_ATTACK,
				"ship_index": 0,
				"ship_activation_identity": SHIP_ACTIVATION_ID,
			}
		var squadron: SquadronInstance = state.get_squadron(0, 0)
		return {
			"reason": "voluntary",
			"declaration_context":
					SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE,
			"squadron_index": 0,
			"activation_id": squadron.activation_id,
			"activation_context": squadron.activation_context,
		}
	var attacker_kind: String = CurrentAttackState.KIND_SHIP \
			if context == SkipAttackCommand.CONTEXT_SHIP_ATTACK \
			else CurrentAttackState.KIND_SQUADRON
	var payload: Dictionary = _first_authoritative_payload(
			state, attacker_kind, attacker_kind)
	assert_false(payload.is_empty())
	return payload


func _declaration_protocol_snapshot(
		state: GameState, context: String) -> Dictionary:
	var snapshot: Dictionary = {
		"current_attack": state.current_attack_state.serialize(),
		"phase_controller": state.squadron_phase_controller_player,
		"phase_committed": state.squadron_phase_activations_committed,
		# Route payload is presentation data and may be normalized by JSON. The
		# production route identity/controller must still agree with canonical
		# owners after each distribution boundary.
		"projected_route": {
			"flow_type": state.interaction_flow.flow_type,
			"step_id": state.interaction_flow.step_id,
			"controller_player": state.interaction_flow.controller_player,
		},
	}
	if context == SkipAttackCommand.CONTEXT_SHIP_ATTACK:
		var ship: ShipInstance = state.get_ship(0, 0)
		snapshot["ship_activation"] = ship.ship_activation_boundary_snapshot()
		snapshot["attack_progress"] = ship.attack_progress_snapshot()
		return snapshot
	var squadron: SquadronInstance = state.get_squadron(0, 0)
	snapshot["squadron_action"] = squadron.activation_action_state_snapshot()
	snapshot["activated"] = squadron.activated_this_round
	snapshot["movement_remains"] = squadron.has_remaining_move_action(
			context == CONTEXT_ROGUE_PHASE)
	if context \
			== SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND:
		snapshot["ship_activation"] = state.get_ship(
				0, 0).ship_activation_boundary_snapshot()
	return snapshot


func _assert_declaration_protocol_snapshot(state: GameState, context: String,
		expected: Dictionary, evidence_label: String) -> void:
	var actual: Dictionary = _declaration_protocol_snapshot(state, context)
	for key: Variant in expected.keys():
		assert_eq(actual.get(key), expected.get(key),
				"%s must preserve %s." % [evidence_label, str(key)])


func _assert_declaration_scene_projection(board: GameBoard, state: GameState,
		context: String, outcome: String) -> void:
	if context == SkipAttackCommand.CONTEXT_SHIP_ATTACK:
		assert_eq(GameManager.get_activating_ship(), state.get_ship(0, 0))
		if outcome == "after_begin":
			assert_true(state.current_attack_state.active)
			assert_true(board._attack_executor.is_in_exec_mode())
			return
		assert_true(
				board._ship_activation_controller.is_activation_modal_open())
		assert_true(board._activation_ctx.ship_activation_state.is_at_step(
				ShipActivationState.Step.ATTACK \
				if outcome == "before_begin" \
				else ShipActivationState.Step.MANEUVER))
		return
	var squadron: SquadronInstance = state.get_squadron(0, 0)
	var modal: SquadronActivationModal = \
			board._squadron_phase_controller.get_modal()
	assert_eq(modal.is_command_mode(), context \
			== SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND,
			"%s %s must reconstruct the correct activation mode." % [
				context, outcome])
	if outcome == "after_begin":
		assert_true(state.current_attack_state.active)
		assert_eq(modal.get_state(), SquadronActivationModal.State.ATTACKING)
		assert_true(board._attack_executor.is_in_exec_mode())
		return
	assert_true(state.current_attack_state.is_inactive())
	if outcome == "after_skip" and context == CONTEXT_NON_ROGUE_PHASE:
		assert_true(squadron.activated_this_round)
		assert_eq(modal.get_state(),
				SquadronActivationModal.State.WAITING_FOR_SELECTION)
		assert_null(modal.get_selected_token())
		return
	assert_eq(modal.get_state(), SquadronActivationModal.State.ACTION_CHOICE)
	assert_eq(modal.get_selected_token().get_squadron_instance(), squadron)
	if outcome == "after_skip":
		assert_eq(squadron.attack_action_disposition,
				SquadronInstance.ATTACK_ACTION_DECLINED)
		assert_true(modal._has_attacked)


func _commanded_squadron_protocol_payload(state: GameState,
		begin: bool) -> Dictionary:
	var squadron: SquadronInstance = state.get_squadron(0, 0)
	if not begin:
		return {
			"reason": "voluntary",
			"declaration_context": SquadronInstance \
					.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND,
			"squadron_index": 0,
			"activation_id": squadron.activation_id,
			"activation_context": squadron.activation_context,
			"ship_activation_identity": SHIP_ACTIVATION_ID,
		}
	var candidates: Array[Dictionary] = TargetingListBuilder \
			.authoritative_squadron_target_entries(state, 0, 0)
	assert_false(candidates.is_empty())
	var candidate: Dictionary = candidates[0]
	return {
		"attacker_player": 0,
		"attacker_kind": CurrentAttackState.KIND_SQUADRON,
		"attacker_index": 0,
		"attacker_zone": -1,
		"defender_player": int(candidate.get("target_owner", -1)),
		"defender_kind": str(candidate.get("target_kind", "")),
		"defender_index": int(candidate.get("target_index", -1)),
		"defender_zone": int(candidate.get("target_zone", -1)),
		"attack_kind": SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD,
		"range_band": str(candidate.get("range_band", "")),
		"obstructed": bool(candidate.get("obstructed", false)),
		"dice_pool": (candidate.get("dice", {}) as Dictionary).duplicate(true),
		"activation_id": squadron.activation_id,
		"activation_context": squadron.activation_context,
		"ship_activation_identity": SHIP_ACTIVATION_ID,
	}


func _make_network_topology_state(
		attacker_player: int,
		defender_player: int) -> GameState:
	var state := GameState.new()
	state.initialize()
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_two_human()))
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.rng = GameRng.new(8841)
	state.damage_deck = DamageDeck.new()
	state.damage_deck.initialize()
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT,
			attacker_player)
	var attacker: ShipInstance = _make_ship_with_key(
			ATTACKER_SHIP_KEY, attacker_player)
	attacker.pos_x = 0.50
	attacker.pos_y = 0.65
	assert_true(attacker.establish_ship_activation(SHIP_ACTIVATION_ID))
	attacker.begin_attack_step()
	var defender: ShipInstance = _make_ship_with_key(
			SHIP_KEY, defender_player)
	defender.pos_x = 0.50
	defender.pos_y = 0.46
	defender.rotation_deg = 180.0
	for zone: String in defender.current_shields.keys():
		defender.current_shields[zone] = 20
	state.get_player_state(attacker_player).ships.append(attacker)
	state.get_player_state(defender_player).ships.append(defender)
	return state


func _first_ship_payload_for_players(
		state: GameState,
		attacker_player: int,
		defender_player: int) -> Dictionary:
	for attacker_zone: int in range(4):
		for defender_zone: int in range(4):
			var entry: Dictionary = \
					TargetingListBuilder.authoritative_attack_entry(
							state,
							attacker_player,
							CurrentAttackState.KIND_SHIP,
							0,
							attacker_zone,
							defender_player,
							CurrentAttackState.KIND_SHIP,
							0,
							defender_zone)
			if entry.is_empty():
				continue
			return {
				"attacker_player": attacker_player,
				"attacker_kind": CurrentAttackState.KIND_SHIP,
				"attacker_index": 0,
				"attacker_zone": attacker_zone,
				"defender_player": defender_player,
				"defender_kind": CurrentAttackState.KIND_SHIP,
				"defender_index": 0,
				"defender_zone": defender_zone,
				"attack_kind":
						SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD,
				"range_band": str(entry.get("range_band", "")),
				"obstructed": bool(entry.get("obstructed", false)),
				"ship_activation_identity": SHIP_ACTIVATION_ID,
			}
	return {}


func _make_replacement_protocol_state() -> GameState:
	var state: GameState = _make_cross_kind_state(
			CurrentAttackState.KIND_SHIP,
			CurrentAttackState.KIND_SHIP, SQUADRON_KEY)
	var unique: SquadronInstance = _make_squadron_with_key(
			UNIQUE_SQUADRON_KEY, 1)
	unique.pos_x = 0.56
	unique.pos_y = 0.56
	state.get_player_state(1).squadrons.append(unique)
	return state


func _install_hot_seat_binding(state: GameState) -> void:
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()))


func _first_authoritative_payload(state: GameState,
		attacker_kind: String, defender_kind: String) -> Dictionary:
	var attacker_zones: Array[int] = []
	if attacker_kind == CurrentAttackState.KIND_SQUADRON:
		attacker_zones.append(-1)
	else:
		attacker_zones.assign([0, 1, 2, 3])
	var defender_zones: Array[int] = []
	if defender_kind == CurrentAttackState.KIND_SQUADRON:
		defender_zones.append(-1)
	else:
		defender_zones.assign([0, 1, 2, 3])
	for attacker_zone: int in attacker_zones:
		for defender_zone: int in defender_zones:
			var payload: Dictionary = _authoritative_payload_for(
					state, attacker_kind, attacker_zone,
					defender_kind, defender_zone)
			if not payload.is_empty():
				return payload
	return {}


func _replacement_protocol_payloads(state: GameState) -> Dictionary:
	for attacker_zone: int in range(4):
		var new_payload: Dictionary = _authoritative_payload_for(
				state, CurrentAttackState.KIND_SHIP, attacker_zone,
				CurrentAttackState.KIND_SQUADRON, -1)
		if new_payload.is_empty():
			continue
		for defender_zone: int in range(4):
			var old_payload: Dictionary = _authoritative_payload_for(
					state, CurrentAttackState.KIND_SHIP, attacker_zone,
					CurrentAttackState.KIND_SHIP, defender_zone)
			if not old_payload.is_empty():
				return {"old": old_payload, "new": new_payload}
	return {}


func _authoritative_payload_for(state: GameState, attacker_kind: String,
		attacker_zone: int, defender_kind: String,
		defender_zone: int) -> Dictionary:
	var entry: Dictionary = TargetingListBuilder.authoritative_attack_entry(
			state, 0, attacker_kind, 0, attacker_zone,
			1, defender_kind, 0, defender_zone)
	if entry.is_empty():
		return {}
	var payload: Dictionary = {
		"attacker_player": 0,
		"attacker_kind": attacker_kind,
		"attacker_index": 0,
		"attacker_zone": attacker_zone,
		"defender_player": 1,
		"defender_kind": defender_kind,
		"defender_index": 0,
		"defender_zone": defender_zone,
		"attack_kind": SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD,
		"range_band": str(entry.get("range_band", "")),
		"obstructed": bool(entry.get("obstructed", false)),
	}
	if attacker_kind == CurrentAttackState.KIND_SHIP:
		payload["ship_activation_identity"] = SHIP_ACTIVATION_ID
	else:
		payload["activation_id"] = SQUADRON_ACTIVATION_ID
		payload["activation_context"] = \
				SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE
	return payload


func _two_same_zone_squadron_candidates(
		state: GameState) -> Array[Dictionary]:
	var by_zone: Dictionary = {}
	for candidate: Dictionary in \
			TargetingListBuilder.authoritative_ship_target_entries(state, 0, 0):
		if str(candidate.get("target_kind", "")) \
				!= CurrentAttackState.KIND_SQUADRON:
			continue
		var zone: int = int(candidate.get("attacker_zone", -1))
		if not by_zone.has(zone):
			by_zone[zone] = []
		var group: Array = by_zone[zone] as Array
		group.append(candidate)
		if group.size() >= 2:
			var result: Array[Dictionary] = []
			result.append((group[0] as Dictionary).duplicate(true))
			result.append((group[1] as Dictionary).duplicate(true))
			return result
	return []


func _step6_and_different_zone_ship_candidates(state: GameState) -> Dictionary:
	var attacker: ShipInstance = state.get_ship(0, 0)
	var target: ShipInstance = state.get_ship(1, 0)
	var other_ship: ShipInstance = state.get_ship(1, 1)
	other_ship.pos_x = 0.95
	other_ship.pos_y = 0.05
	var offsets: Array[Vector2] = [
		Vector2(0.0, -0.14), Vector2(-0.14, 0.0),
		Vector2(0.14, 0.0), Vector2(0.0, 0.14),
	]
	for offset: Vector2 in offsets:
		target.pos_x = attacker.pos_x + offset.x
		target.pos_y = attacker.pos_y + offset.y
		target.rotation_deg = 180.0
		var squadrons: Array[Dictionary] = \
				_two_same_zone_squadron_candidates(state)
		if squadrons.size() < 2:
			continue
		var used_zone: int = int(squadrons[0].get("attacker_zone", -1))
		var ship_candidate: Dictionary = _different_zone_candidate(
				state, used_zone, CurrentAttackState.KIND_SHIP)
		if not ship_candidate.is_empty():
			return {"squadrons": squadrons, "ship": ship_candidate}
	return {}


func _same_squadron_different_zone_candidates(
		state: GameState) -> Array[Dictionary]:
	var first_by_target: Dictionary = {}
	for candidate: Dictionary in \
			TargetingListBuilder.authoritative_ship_target_entries(state, 0, 0):
		if str(candidate.get("target_kind", "")) \
				!= CurrentAttackState.KIND_SQUADRON:
			continue
		var key: String = "%d:%d" % [
			int(candidate.get("target_owner", -1)),
			int(candidate.get("target_index", -1)),
		]
		if not first_by_target.has(key):
			first_by_target[key] = candidate
			continue
		var first: Dictionary = first_by_target[key] as Dictionary
		if int(first.get("attacker_zone", -1)) \
				== int(candidate.get("attacker_zone", -1)):
			continue
		return [first.duplicate(true), candidate.duplicate(true)]
	return []


func _different_zone_candidate(state: GameState, used_zone: int,
		target_kind: String) -> Dictionary:
	for candidate: Dictionary in \
			TargetingListBuilder.authoritative_ship_target_entries(state, 0, 0):
		if int(candidate.get("attacker_zone", -1)) == used_zone:
			continue
		if not target_kind.is_empty() \
				and str(candidate.get("target_kind", "")) != target_kind:
			continue
		var target: RefCounted = state.get_ship(
				int(candidate.get("target_owner", -1)),
				int(candidate.get("target_index", -1))) \
				if str(candidate.get("target_kind", "")) \
						== CurrentAttackState.KIND_SHIP \
				else state.get_squadron(
						int(candidate.get("target_owner", -1)),
						int(candidate.get("target_index", -1)))
		if target != null and not bool(target.call("is_destroyed")):
			return candidate.duplicate(true)
	return {}


func _payload_from_ship_candidate(candidate: Dictionary) -> Dictionary:
	return {
		"attacker_player": 0,
		"attacker_kind": CurrentAttackState.KIND_SHIP,
		"attacker_index": 0,
		"attacker_zone": int(candidate.get("attacker_zone", -1)),
		"defender_player": int(candidate.get("target_owner", -1)),
		"defender_kind": str(candidate.get("target_kind", "")),
		"defender_index": int(candidate.get("target_index", -1)),
		"defender_zone": int(candidate.get("target_zone", -1)),
		"attack_kind": SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD,
		"range_band": str(candidate.get("range_band", "")),
		"obstructed": bool(candidate.get("obstructed", false)),
		"ship_activation_identity": SHIP_ACTIVATION_ID,
	}


func _expected_source_pool(state: GameState,
		payload: Dictionary) -> Dictionary:
	var armament: Dictionary = {}
	if str(payload["attacker_kind"]) == CurrentAttackState.KIND_SHIP:
		var ship: ShipInstance = state.get_ship(0, 0)
		if str(payload["defender_kind"]) == CurrentAttackState.KIND_SHIP:
			var zone_name: String = Constants.hull_zone_to_string(
					int(payload["attacker_zone"]) as Constants.HullZone)
			armament = (ship.ship_data.battery_armament.get(
					zone_name, {}) as Dictionary)
		else:
			armament = ship.ship_data.anti_squadron_armament
	else:
		var squadron: SquadronInstance = state.get_squadron(0, 0)
		armament = squadron.squadron_data.battery_armament \
				if str(payload["defender_kind"]) == CurrentAttackState.KIND_SHIP \
				else squadron.squadron_data.anti_squadron_armament
	return DicePool.get_attack_pool(armament, str(payload["range_band"]))


func _make_terminal_ecm_state(attack_id: String) -> GameState:
	var state: GameState = _make_state()
	assert_not_null(CURRENT_ATTACK_FIXTURE.install(state, {
		"attack_id": attack_id,
		"stage": CurrentAttackState.STAGE_RESOLVED,
		"dice_results": [{
			"color": int(Constants.DiceColor.RED),
			"face": int(Constants.DiceFace.HIT),
		}],
		"defense_stage": CurrentAttackState.DEFENSE_COMPLETE,
	}))
	var defender: ShipInstance = state.get_ship(1, 0)
	defender.roster_entry_id = "protocol-defender"
	var runtime_upgrade: Dictionary = defender.add_runtime_upgrade(
			"electronic_countermeasures", "ecm-terminal",
			"DEFENSIVE_RETROFIT", 0)
	runtime_upgrade["rule_state"] = {
		ECM_SCRIPT.RULE_STATE_PENDING_AUTHORIZATION: {
			"runtime_upgrade_id": str(runtime_upgrade.get(
					"runtime_upgrade_id", "")),
			"attack_scope": {"attack_id": attack_id},
		},
	}
	return state


func _assert_ecm_pending_empty(state: GameState,
		runtime_upgrade_id: String) -> void:
	var runtime_upgrade: Dictionary = state.get_ship(
			1, 0).get_runtime_upgrade(runtime_upgrade_id)
	assert_true(ECM_SCRIPT.pending_authorization(runtime_upgrade).is_empty(),
			"Terminal command must clear matching ECM runtime state.")


func _set_protocol_position(ship: ShipInstance,
		squadron: SquadronInstance, owner: int, index: int) -> void:
	if owner == 0 and index == 0:
		ship.pos_x = 0.5
		ship.pos_y = 0.65
		squadron.pos_x = 0.15
		squadron.pos_y = 0.85
		return
	if owner == 0:
		ship.pos_x = 0.12
		ship.pos_y = 0.88
		squadron.pos_x = 0.25
		squadron.pos_y = 0.85
		return
	ship.pos_x = 0.46 if index == 0 else 0.54
	ship.pos_y = 0.5
	ship.rotation_deg = 180.0
	squadron.pos_x = 0.44 if index == 0 else 0.56
	squadron.pos_y = 0.57


func _make_ship(owner: int) -> ShipInstance:
	return _make_ship_with_key(SHIP_KEY, owner)


func _make_squadron(owner: int) -> SquadronInstance:
	return _make_squadron_with_key(SQUADRON_KEY, owner)


func _make_ship_with_key(key: String, owner: int) -> ShipInstance:
	return ShipInstance.create_from_data(
			key, AssetLoader.load_ship_data(key), 2, owner)


func _make_squadron_with_key(key: String, owner: int) -> SquadronInstance:
	return SquadronInstance.create_from_data(
			key, AssetLoader.load_squadron_data(key), owner)


func _ship_attack_payload(defender_index: int = 0) -> Dictionary:
	return {
		"attacker_player": 0,
		"attacker_kind": CurrentAttackState.KIND_SHIP,
		"attacker_index": 0,
		"attacker_zone": int(Constants.HullZone.FRONT),
		"defender_player": 1,
		"defender_kind": CurrentAttackState.KIND_SHIP,
		"defender_index": defender_index,
		"defender_zone": int(Constants.HullZone.FRONT),
		"attack_kind": "standard",
		"range_band": Constants.RANGE_BAND_CLOSE,
		"obstructed": false,
		"ship_activation_identity": SHIP_ACTIVATION_ID,
	}


func _anti_squadron_payload(defender_index: int) -> Dictionary:
	var payload: Dictionary = _ship_attack_payload()
	payload["defender_kind"] = CurrentAttackState.KIND_SQUADRON
	payload["defender_index"] = defender_index
	payload["defender_zone"] = -1
	return payload


func _assert_round_trip_stage(state: GameState, expected_stage: String) -> void:
	var restored: GameState = GameState.deserialize(
			JSON.parse_string(JSON.stringify(state.serialize())))
	assert_not_null(restored)
	assert_eq(restored.current_attack_state.attack_id, "attack:0")
	assert_eq(restored.current_attack_state.stage, expected_stage)


func _capture_network_result(command_data: Dictionary,
		result: Dictionary) -> void:
	_broadcast_results.append({
		"command": command_data.duplicate(true),
		"result": result.duplicate(true),
	})


func _broadcast_command_data() -> Array[Dictionary]:
	var commands: Array[Dictionary] = []
	for entry: Dictionary in _broadcast_results:
		commands.append((entry.get("command") as Dictionary).duplicate(true))
	return commands


func _apply_broadcast_to_client(index: int) -> void:
	var entry: Dictionary = _broadcast_results[index]
	GameManager._on_network_command_result(
			entry.get("command") as Dictionary,
			entry.get("result") as Dictionary)


func _history_sequences(commands: Array[Dictionary]) -> Array[int]:
	var result: Array[int] = []
	for command: Dictionary in commands:
		result.append(int(command.get("sequence", -1)))
	return result


func _history_types(commands: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for command: Dictionary in commands:
		result.append(str(command.get("type", "")))
	return result
