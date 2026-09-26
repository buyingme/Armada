extends GutTest


const ORDER: GDScript = preload(
		"res://src/core/commands/candidate_commit_maneuver_obstacle_order_command.gd")
const ASTEROID: GDScript = preload(
		"res://src/core/commands/candidate_resolve_asteroid_overlap_command.gd")
const DEBRIS: GDScript = preload(
		"res://src/core/commands/candidate_resolve_debris_overlap_command.gd")
const STATION: GDScript = preload(
		"res://src/core/commands/candidate_resolve_station_overlap_command.gd")
const IMMEDIATE: GDScript = preload(
		"res://src/core/commands/candidate_resolve_immediate_effect_command.gd")
const EVALUATOR: GDScript = preload(
		"res://src/core/movement/maneuver_execution_evaluator.gd")
const OVERLAP: GDScript = preload(
		"res://src/core/geometry/obstacle_overlap_authority.gd")
const PROCESSOR: GDScript = preload("res://src/autoload/command_processor.gd")


class DirectSubmitter:
	extends CommandSubmitter

	var next_sequence: int = 900

	func submit(command: GameCommand) -> Dictionary:
		command.sequence = next_sequence
		next_sequence += 1
		return command.execute(GameManager.current_game_state)

const ACTIVATION_ID := "ship-activation:70"
const EXECUTION_ID := "maneuver:70"

var _saved_state: GameState
var _saved_submitter: CommandSubmitter
var _saved_game_active: bool
var _saved_active_player: int
var _saved_registry: Dictionary


func before_each() -> void:
	_saved_state = GameManager.current_game_state
	_saved_submitter = GameManager.get_command_submitter()
	_saved_game_active = GameManager.is_game_active
	_saved_active_player = GameManager.active_player
	_saved_registry = GameCommand._registry.duplicate()


func after_each() -> void:
	GameManager.current_game_state = _saved_state
	GameManager.set_command_submitter(_saved_submitter)
	GameManager.is_game_active = _saved_game_active
	GameManager.active_player = _saved_active_player
	GameCommand._registry = _saved_registry


func test_asteroid_delegates_every_legal_immediate_card_and_returns_once() -> void:
	for effect: String in [
		"structural_damage", "projector_misaligned",
		"life_support_failure", "injured_crew", "shield_failure",
		"comm_noise",
	]:
		var fixture: Dictionary = _fixture("asteroid_1", [
				_card("damage:%s" % effect, effect, "immediate_persistent" \
						if effect == "life_support_failure" else "immediate")])
		var state: GameState = fixture["state"]
		var ship: ShipInstance = fixture["ship"]
		if effect == "projector_misaligned":
			ship.current_shields = {
				"front": 2, "left": 1, "right": 1, "rear": 1}
		var overlaps: Array[Dictionary] = OVERLAP.overlapping_obstacles(
				state, 0, 0)
		assert_false(overlaps.is_empty(), "%s %s" % [effect, overlaps])
		assert_false(_commit_order(state).execute(state).is_empty(), effect)
		var asteroid: GameCommand = ASTEROID.new(0, _base("obstacle:0"))
		asteroid.sequence = 71
		assert_eq(asteroid.validate(state), "", effect)
		var dealt: Dictionary = asteroid.execute(state)
		assert_false(dealt.is_empty(), effect)
		assert_true(ship.has_active_immediate_resolution(), effect)
		assert_true(not ship.active_asteroid_resolution_snapshot().is_empty(),
				effect)
		var recovered: ShipInstance = ShipInstance.deserialize(
				ship.serialize(), ship.ship_data)
		assert_not_null(recovered, effect)
		assert_eq(recovered.active_immediate_resolution_snapshot(),
				ship.active_immediate_resolution_snapshot(), effect)
		assert_eq(recovered.active_asteroid_resolution_snapshot(),
				ship.active_asteroid_resolution_snapshot(), effect)
		var record: Dictionary = ship.active_immediate_resolution_snapshot()
		var payload: Dictionary = {
			"owner_player": 0,
			"ship_index": 0,
			"public_card_ref": record["public_card_ref"],
			"immediate_resolution_id": record["immediate_resolution_id"],
			"enclosing_kind": "maneuver",
			"ship_activation_identity": ACTIVATION_ID,
			"maneuver_execution_id": EXECUTION_ID,
			"maneuver_source_kind": "asteroid",
			"maneuver_source_id": "obstacle:0",
		}
		if effect == "shield_failure":
			payload["shield_zones"] = []
		elif effect == "comm_noise":
			payload["comm_noise_action"] = "speed"
		var actor: int = int(record["actor_player"])
		var resolution: GameCommand = IMMEDIATE.new(
				0 if actor == -1 else actor, payload)
		assert_eq(resolution.validate(state), "", effect)
		resolution.sequence = 72
		var replayed: GameCommand = GameCommand.deserialize(
				resolution.serialize())
		assert_not_null(replayed, effect)
		assert_false(replayed.execute(state).is_empty(), effect)
		assert_false(ship.has_active_immediate_resolution(), effect)
		assert_true(ship.active_asteroid_resolution_snapshot().is_empty(),
				effect)
		assert_eq(state.obstacle_placement("obstacle:0")[
				"last_maneuver_execution_id"], EXECUTION_ID, effect)
		assert_eq(EVALUATOR.next_action(state, 0, 0)["command_type"],
				"complete_maneuver", effect)


func test_asteroid_non_immediate_card_completes_without_fabricated_prompt() -> void:
	var fixture: Dictionary = _fixture("asteroid_1", [
		_card("damage:ordinary", "ordinary", "persistent"),
	])
	var state: GameState = fixture["state"]
	var ship: ShipInstance = fixture["ship"]
	ship.current_speed = 0
	assert_false(_commit_order(state).execute(state).is_empty())
	var command: GameCommand = ASTEROID.new(0, _base("obstacle:0"))
	command.sequence = 73
	var result: Dictionary = command.execute(state)
	assert_eq(result["immediate_resolution_id"], "")
	assert_false(ship.has_active_immediate_resolution())
	assert_true(ship.active_asteroid_resolution_snapshot().is_empty())
	assert_eq(state.obstacle_placement("obstacle:0")[
			"last_maneuver_execution_id"], EXECUTION_ID)
	assert_eq(EVALUATOR.next_action(state, 0, 0)["command_type"],
			"complete_maneuver")


func test_production_debug_damage_does_not_poison_later_asteroid_authority() \
		-> void:
	var fixture: Dictionary = _fixture("asteroid_1", [
		_card("damage:asteroid", "ordinary", "persistent"),
		_card("damage:debug", "capacitor_failure", "persistent"),
	])
	var state: GameState = fixture["state"]
	var ship: ShipInstance = fixture["ship"]
	GameManager.current_game_state = state
	GameManager.set_command_submitter(DirectSubmitter.new())
	var debug_result: Dictionary = GameManager.submit_debug_deal_damage(
			ship, "capacitor_failure")
	assert_false(debug_result.is_empty())
	assert_true(debug_result.has("damage_application"))
	assert_true(state.validate_damage_state_for_save7())
	assert_false(_commit_order(state).execute(state).is_empty())
	var asteroid: GameCommand = ASTEROID.new(0, _base("obstacle:0"))
	asteroid.sequence = 902
	assert_eq(asteroid.validate(state), "")
	assert_false(asteroid.execute(state).is_empty())


func test_lethal_asteroid_after_speed_three_displacement_is_terminal_and_convergent() \
		-> void:
	var authority_fixture: Dictionary = _lethal_asteroid_sequence(false)
	var authority_state: GameState = authority_fixture["state"]
	var authority_ship: ShipInstance = authority_fixture["ship"]
	var authority_command: GameCommand = authority_fixture["command"]
	assert_eq(authority_ship.get_total_damage(), 3)
	assert_eq(authority_command.validate(authority_state), "")
	var result: Dictionary = authority_command.execute(authority_state)
	assert_false(result.is_empty())
	assert_true(bool(result["damage_application"]["destroyed"]))
	assert_eq(authority_ship.get_total_damage(), 4)
	assert_eq(authority_ship.faceup_damage.size(), 1)
	assert_eq(authority_state.damage_deck.get_total_count(), 0)
	_assert_lethal_maneuver_cleanup(authority_state, authority_ship)

	# The same accepted result must terminate the passive peer at the same
	# boundary without a second hidden draw or a fabricated continuation.
	var passive_fixture: Dictionary = _lethal_asteroid_sequence(true)
	var passive_state: GameState = passive_fixture["state"]
	var passive_ship: ShipInstance = passive_fixture["ship"]
	var passive_command: GameCommand = passive_fixture["command"]
	var projected: Dictionary = authority_command.project_application_result(
			result, 1)
	assert_eq(passive_command.execute_with_application_result(
			passive_state, projected), projected)
	assert_eq(passive_ship.get_total_damage(), 4)
	assert_eq(passive_ship.faceup_damage.size(), 1)
	assert_eq(passive_state.passive_damage_ledger.draw_count, 0)
	_assert_lethal_maneuver_cleanup(passive_state, passive_ship)

	# Exact-once: neither side can apply the Asteroid consequence again.
	assert_ne(authority_command.validate(authority_state), "")
	assert_true(authority_command.execute(authority_state).is_empty())
	assert_ne(passive_command.validate(passive_state), "")
	assert_true(passive_command.execute_with_application_result(
			passive_state, projected).is_empty())
	assert_eq(authority_ship.get_total_damage(), 4)
	assert_eq(passive_ship.get_total_damage(), 4)

	# The accepted cleanup command carries the exceptional composed return to
	# both authority and passive peers without reviving the dead Maneuver.
	var authority_cleanup := DestroyUnitCommand.new(0, {
		"owner_player": 0,
		"ship_index": 0,
		"terminate_ship_phase_turn": true,
	})
	assert_eq(authority_cleanup.validate(authority_state), "")
	var cleanup_result: Dictionary = authority_cleanup.execute(authority_state)
	var passive_cleanup := DestroyUnitCommand.new(0,
			authority_cleanup.payload.duplicate(true))
	var cleanup_projection: Dictionary = authority_cleanup \
			.project_application_result(cleanup_result, 1)
	assert_eq(passive_cleanup.validate(passive_state), "")
	assert_false(passive_cleanup.execute_with_application_result(
			passive_state, cleanup_projection).is_empty())
	for converged_state: GameState in [authority_state, passive_state]:
		assert_eq(converged_state.interaction_flow.flow_type,
				Constants.InteractionFlow.SHIP_ACTIVATION)
		assert_eq(converged_state.interaction_flow.step_id,
				Constants.InteractionStep.WAIT_FOR_SHIP_SELECT)
		assert_eq(converged_state.interaction_flow.controller_player, 0)
	assert_eq(authority_ship.get_total_damage(), 0)
	assert_eq(passive_ship.get_total_damage(), 0)


func test_lethal_asteroid_last_ship_composes_cleanup_and_existing_end_game() \
		-> void:
	var fixture: Dictionary = _lethal_asteroid_sequence(false)
	var state: GameState = fixture["state"]
	var destroyed_ship: ShipInstance = fixture["ship"]
	_add_flow_ship(state, 1, false)
	var processor: Node = _game_flow_processor(state)
	var asteroid: GameCommand = fixture["command"]
	asteroid.sequence = -1
	var result: Dictionary = processor.submit(asteroid)
	assert_true(bool(result["damage_application"]["destroyed"]))
	assert_true(destroyed_ship.has_finalized_destruction())
	assert_false(destroyed_ship.has_active_ship_activation())
	assert_false(destroyed_ship.has_active_maneuver_execution())
	assert_eq(_history_types(processor), [
		"resolve_asteroid_overlap", "destroy_unit",
	])
	assert_false(GameManager.is_game_active,
			"The existing elimination owner must end the match after cleanup.")
	assert_eq(destroyed_ship.get_total_damage(), 0)


func test_lethal_asteroid_non_last_ship_returns_to_legal_selection_once() \
		-> void:
	var fixture: Dictionary = _lethal_asteroid_sequence(false)
	var state: GameState = fixture["state"]
	var destroyed_ship: ShipInstance = fixture["ship"]
	var next_ship: ShipInstance = _add_flow_ship(state, 0, false)
	_add_flow_ship(state, 1, true)
	var processor: Node = _game_flow_processor(state)
	var asteroid: GameCommand = fixture["command"]
	asteroid.sequence = -1
	assert_false(processor.submit(asteroid).is_empty())
	assert_true(GameManager.is_game_active)
	assert_eq(_history_types(processor), [
		"resolve_asteroid_overlap", "destroy_unit",
	], "No Maneuver completion or duplicate continuation may follow death.")
	assert_false(destroyed_ship.has_active_ship_activation())
	assert_eq(state.interaction_flow.flow_type,
			Constants.InteractionFlow.SHIP_ACTIVATION)
	assert_eq(state.interaction_flow.step_id,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT)
	assert_eq(state.interaction_flow.controller_player, 0)
	assert_eq(GameManager.active_player, 0)
	assert_eq(ActivateShipCommand.new(0, {"ship_index": 1}).validate(state), "",
			"The surviving friendly ship must be the next legal gameplay state.")
	assert_false(next_ship.is_destroyed())
	assert_eq(destroyed_ship.get_total_damage(), 0)


func test_debris_applies_two_points_to_one_zone_and_returns() -> void:
	var fixture: Dictionary = _fixture("debris_1", [
		_card("damage:debris:0", "ordinary", "persistent"),
		_card("damage:debris:1", "ordinary", "persistent"),
	])
	var state: GameState = fixture["state"]
	var ship: ShipInstance = fixture["ship"]
	ship.current_shields["front"] = 0
	assert_false(_commit_order(state).execute(state).is_empty())
	assert_true(not ship.active_debris_resolution_snapshot().is_empty())
	var command: GameCommand = DEBRIS.new(0, _base("obstacle:0").merged({
		"hull_zone": "front",
	}))
	assert_eq(command.validate(state), "")
	var result: Dictionary = command.execute(state)
	assert_eq(result["damage_application"]["facedown_delta"], 2)
	assert_eq(ship.get_facedown_damage_count(), 2)
	assert_true(ship.active_debris_resolution_snapshot().is_empty())
	assert_eq(state.obstacle_placement("obstacle:0")[
			"last_maneuver_execution_id"], EXECUTION_ID)


func test_debris_stops_after_first_damage_point_destroys_ship() -> void:
	var fixture: Dictionary = _fixture("debris_1", [
		_card("damage:debris:lethal", "ordinary", "persistent"),
		_card("damage:debris:unused", "ordinary", "persistent"),
	])
	var state: GameState = fixture["state"]
	var ship: ShipInstance = fixture["ship"]
	ship.ship_data.hull = 1
	ship.current_shields["front"] = 0
	assert_false(_commit_order(state).execute(state).is_empty())
	var command: GameCommand = DEBRIS.new(0, _base("obstacle:0").merged({
		"hull_zone": "front",
	}))
	assert_eq(command.validate(state), "")
	var result: Dictionary = command.execute(state)
	assert_true(bool(result["damage_application"]["destroyed"]))
	assert_eq(result["damage_application"]["facedown_delta"], 1,
			"The second debris point must not draw after point one destroys.")
	assert_eq(ship.get_facedown_damage_count(), 1)
	assert_eq(state.damage_deck.get_total_count(), 1)
	assert_false(ship.has_active_maneuver_execution())


func test_debris_passive_application_matches_lethal_first_point_result() -> void:
	var authority_fixture: Dictionary = _fixture("debris_1", [
		_card("damage:debris:lethal", "ordinary", "persistent"),
		_card("damage:debris:unused", "ordinary", "persistent"),
	])
	var authority_state: GameState = authority_fixture["state"]
	var authority_ship: ShipInstance = authority_fixture["ship"]
	authority_ship.ship_data.hull = 1
	authority_ship.current_shields["front"] = 0
	assert_false(_commit_order(authority_state).execute(authority_state).is_empty())
	var authority_command: GameCommand = DEBRIS.new(
			0, _base("obstacle:0").merged({"hull_zone": "front"}))
	var result: Dictionary = authority_command.execute(authority_state)

	var passive_fixture: Dictionary = _fixture("debris_1", [])
	var passive_state: GameState = passive_fixture["state"]
	var passive_ship: ShipInstance = passive_fixture["ship"]
	passive_ship.ship_data.hull = 1
	passive_ship.current_shields["front"] = 0
	passive_state.damage_deck = null
	passive_state.rng = null
	passive_state.passive_damage_ledger = PassiveDamageLedger.deserialize({
		"schema_version": 1,
		"draw_count": 2,
		"discard_pile": [],
		"facedown_counts": {"0:obstacle-ship": 0},
	}, ["0:obstacle-ship"])
	assert_true(passive_ship.bind_passive_damage_ledger(
			passive_state.passive_damage_ledger, "0:obstacle-ship"))
	assert_false(_commit_order(passive_state).execute(passive_state).is_empty())
	var passive_command: GameCommand = DEBRIS.new(
			0, authority_command.payload.duplicate(true))
	var projected: Dictionary = passive_command.project_application_result(
			result, 1)
	assert_eq(passive_command.execute_with_application_result(
			passive_state, projected), projected)
	assert_true(passive_ship.is_destroyed())
	assert_eq(passive_ship.get_facedown_damage_count(), 1)
	assert_eq(passive_state.passive_damage_ledger.draw_count, 1)
	assert_false(passive_ship.has_active_maneuver_execution())


func test_debris_second_point_can_destroy_after_first_point_removes_shield() -> void:
	var fixture: Dictionary = _fixture("debris_1", [
		_card("damage:debris:second", "ordinary", "persistent"),
	])
	var state: GameState = fixture["state"]
	var ship: ShipInstance = fixture["ship"]
	ship.ship_data.hull = 1
	ship.current_shields["front"] = 1
	assert_false(_commit_order(state).execute(state).is_empty())
	var result: Dictionary = DEBRIS.new(
			0, _base("obstacle:0").merged({"hull_zone": "front"})).execute(state)
	assert_true(bool(result["damage_application"]["destroyed"]))
	assert_eq(result["damage_application"]["shield_changes"], [
		{"zone": "front", "new_shields": 0},
	])
	assert_eq(result["damage_application"]["facedown_delta"], 1)


func test_station_use_decline_no_option_and_unsupported_objective() -> void:
	var fixture: Dictionary = _fixture("station", [])
	var state: GameState = fixture["state"]
	var ship: ShipInstance = fixture["ship"]
	var source: DamageCard = _card(
			"damage:station:0", "ruptured_engine", "persistent")
	source.flip_faceup()
	source.public_card_ref = "faceup:station:0"
	ship.add_faceup_damage(source)
	assert_false(_commit_order(state).execute(state).is_empty())
	var use_command: GameCommand = STATION.new(0, _base("obstacle:0").merged({
		"action": "use_faceup",
		"public_card_ref": "faceup:station:0",
	}))
	assert_eq(use_command.validate(state), "")
	assert_false(use_command.execute(state).is_empty())
	assert_true(ship.faceup_damage.is_empty())
	assert_eq(state.damage_deck.get_discard_count(), 1)
	assert_eq(EVALUATOR.next_action(state, 0, 0)["command_type"],
			"complete_maneuver")

	fixture = _fixture("station", [])
	state = fixture["state"]
	ship = fixture["ship"]
	assert_false(_commit_order(state).execute(state).is_empty())
	var no_option: GameCommand = STATION.new(0, _base("obstacle:0").merged({
		"action": "no_option",
	}))
	assert_eq(no_option.validate(state), "")
	assert_false(no_option.execute(state).is_empty())

	fixture = _fixture("station", [])
	state = fixture["state"]
	state.objectives["selected_objective"] = {
		"data_key": "obj_def_contested_outpost"}
	assert_ne(_commit_order(state).validate(state), "")
	assert_true((fixture["ship"] as ShipInstance) \
			.active_station_resolution_snapshot().is_empty())


func test_station_decline_preserves_damage_and_completes_exactly_once() -> void:
	var fixture: Dictionary = _fixture("station", [])
	var state: GameState = fixture["state"]
	var ship: ShipInstance = fixture["ship"]
	var source: DamageCard = _card(
			"damage:station:decline", "ordinary", "persistent")
	source.flip_faceup()
	source.public_card_ref = "faceup:station:decline"
	ship.add_faceup_damage(source)
	assert_false(_commit_order(state).execute(state).is_empty())
	var command: GameCommand = STATION.new(0, _base("obstacle:0").merged({
		"action": "decline",
	}))
	assert_eq(command.validate(state), "")
	var result: Dictionary = command.execute(state)
	assert_false(result.is_empty())
	assert_eq(ship.faceup_damage.size(), 1)
	assert_true(ship.active_station_resolution_snapshot().is_empty())
	assert_ne(command.validate(state), "")
	assert_eq(EVALUATOR.next_action(state, 0, 0)["command_type"],
			"complete_maneuver")


func test_station_facedown_selection_converges_on_passive_peer() -> void:
	var authority_fixture: Dictionary = _fixture("station", [])
	var authority_state: GameState = authority_fixture["state"]
	var authority_ship: ShipInstance = authority_fixture["ship"]
	authority_ship.add_facedown_damage(_card(
			"damage:station:hidden", "ordinary", "persistent"))
	assert_false(_commit_order(authority_state).execute(
			authority_state).is_empty())
	var authority_command: GameCommand = STATION.new(
			0, _base("obstacle:0").merged({
				"action": "use_facedown", "facedown_ordinal": 0,
			}))
	var result: Dictionary = authority_command.execute(authority_state)
	assert_eq(result["damage_application"]["facedown_delta"], -1)
	assert_eq((result["damage_application"]["public_discards"] as Array).size(), 1)

	var passive_fixture: Dictionary = _fixture("station", [])
	var passive_state: GameState = passive_fixture["state"]
	var passive_ship: ShipInstance = passive_fixture["ship"]
	passive_state.damage_deck = null
	passive_state.rng = null
	passive_state.passive_damage_ledger = PassiveDamageLedger.deserialize({
		"schema_version": 1,
		"draw_count": 0,
		"discard_pile": [],
		"facedown_counts": {"0:obstacle-ship": 1},
	}, ["0:obstacle-ship"])
	assert_true(passive_ship.bind_passive_damage_ledger(
			passive_state.passive_damage_ledger, "0:obstacle-ship"))
	assert_false(_commit_order(passive_state).execute(passive_state).is_empty())
	var passive_command: GameCommand = STATION.new(
			0, authority_command.payload.duplicate(true))
	var projected: Dictionary = passive_command.project_application_result(
			result, 1)
	assert_eq(passive_command.execute_with_application_result(
			passive_state, projected), projected)
	assert_eq(passive_ship.get_facedown_damage_count(), 0)
	assert_eq(passive_state.passive_damage_ledger.discard_pile.size(), 1)
	assert_true(passive_ship.active_station_resolution_snapshot().is_empty())


func test_nested_asteroid_state_round_trips_and_mismatches_fail_closed() -> void:
	var fixture: Dictionary = _fixture("asteroid_1", [
		_card("damage:save:0", "shield_failure", "immediate")])
	var state: GameState = fixture["state"]
	var ship: ShipInstance = fixture["ship"]
	assert_false(_commit_order(state).execute(state).is_empty())
	var asteroid: GameCommand = ASTEROID.new(0, _base("obstacle:0"))
	asteroid.sequence = 72
	assert_eq(asteroid.validate(state), "")
	assert_false(asteroid.execute(state).is_empty())
	var serialized: Dictionary = ship.serialize()
	var restored: ShipInstance = ShipInstance.deserialize(
			serialized, ship.ship_data)
	assert_not_null(restored)
	assert_eq(restored.active_asteroid_resolution_snapshot(),
			ship.active_asteroid_resolution_snapshot())
	var invalid: Dictionary = serialized.duplicate(true)
	invalid["active_asteroid_resolution"]["immediate_resolution_id"] = \
			"immediate:stale"
	assert_null(ShipInstance.deserialize(invalid, ship.ship_data))


func test_debris_and_station_pending_recovery_and_completed_non_reopening() -> void:
	for obstacle_key: String in ["debris_1", "station"]:
		var cards: Array[DamageCard] = []
		if obstacle_key == "debris_1":
			cards = [_card("damage:recovery", "ordinary", "persistent")]
		var fixture: Dictionary = _fixture(obstacle_key, cards)
		var state: GameState = fixture["state"]
		var ship: ShipInstance = fixture["ship"]
		assert_false(_commit_order(state).execute(state).is_empty(), obstacle_key)
		var pending: Dictionary = ship.active_debris_resolution_snapshot() \
				if obstacle_key == "debris_1" \
				else ship.active_station_resolution_snapshot()
		var restored: ShipInstance = ShipInstance.deserialize(
				ship.serialize(), ship.ship_data)
		assert_not_null(restored, obstacle_key)
		assert_eq(restored.active_debris_resolution_snapshot() \
				if obstacle_key == "debris_1" \
				else restored.active_station_resolution_snapshot(),
				pending, obstacle_key)
		var command: GameCommand = DEBRIS.new(
				0, _base("obstacle:0").merged({"hull_zone": "front"})) \
				if obstacle_key == "debris_1" else STATION.new(
						0, _base("obstacle:0").merged({"action": "no_option"}))
		assert_false(command.execute(state).is_empty(), obstacle_key)
		restored = ShipInstance.deserialize(ship.serialize(), ship.ship_data)
		assert_not_null(restored, obstacle_key)
		assert_true(restored.active_debris_resolution_snapshot().is_empty(),
				obstacle_key)
		assert_true(restored.active_station_resolution_snapshot().is_empty(),
				obstacle_key)


func _fixture(obstacle_key: String,
		deck_cards: Array[DamageCard]) -> Dictionary:
	var state := GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SHIP
	state.damage_deck = _deck(deck_cards)
	var ship := ShipInstance.create_from_data("obstacle", _ship_data(), 1, 0)
	ship.roster_entry_id = "obstacle-ship"
	ship.pos_x = 0.5
	ship.pos_y = 0.5
	ship.current_speed = 1
	state.get_player_state(0).ships.append(ship)
	assert_true(ship.establish_ship_activation(ACTIVATION_ID))
	assert_true(ship.open_maneuver_opportunity(ACTIVATION_ID))
	assert_true(ship.commit_maneuver_execution(
			ACTIVATION_ID, EXECUTION_ID, false, {
				"yaw_clicks": [0], "yaw_bonus_joint": -1,
				"pos_x": 0.5, "pos_y": 0.5, "rotation_deg": 0.0,
			}, {"kind": "none"}))
	assert_false(ship.apply_maneuver_final_transform(
			ACTIVATION_ID, EXECUTION_ID).is_empty())
	state.objectives["obstacles"] = [{
		"obstacle_id": "obstacle:0",
		"data_key": obstacle_key,
		"pos_x": 0.5,
		"pos_y": 0.5,
		"rotation_deg": 0.0,
		"placing_player": 0,
		"placement_order": 0,
		"last_maneuver_execution_id": "",
	}]
	return {"state": state, "ship": ship}


func _lethal_asteroid_sequence(passive: bool) -> Dictionary:
	var state := GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SHIP
	var ship := ShipInstance.create_from_data("obstacle", _lethal_ship_data(), 3, 0)
	ship.roster_entry_id = "lethal-obstacle-ship"
	ship.pos_x = 0.5
	ship.pos_y = 0.75
	ship.current_speed = 3
	state.get_player_state(0).ships.append(ship)
	if passive:
		state.damage_deck = null
		state.rng = null
		state.passive_damage_ledger = PassiveDamageLedger.deserialize({
			"schema_version": 1,
			"draw_count": 1,
			"discard_pile": [],
			"facedown_counts": {"0:lethal-obstacle-ship": 3},
		}, ["0:lethal-obstacle-ship"])
		assert_true(ship.bind_passive_damage_ledger(
				state.passive_damage_ledger, "0:lethal-obstacle-ship"))
	else:
		state.damage_deck = _deck([
			_card("damage:asteroid", "ordinary", "persistent"),
			_card("damage:structural-extra", "ordinary", "persistent"),
			_card("damage:shield", "shield_failure", "immediate"),
			_card("damage:structural", "structural_damage", "immediate"),
		])
		_resolve_debug_immediate(state, ship, "shield_failure", 6,
				{"shield_zones": []})
		_resolve_debug_immediate(state, ship, "structural_damage", 8, {})
		assert_eq(ship.get_facedown_damage_count(), 3)
		assert_true(state.validate_damage_state_for_save7())

	assert_true(ship.establish_ship_activation("ship-activation:11"))
	assert_true(ship.open_maneuver_opportunity("ship-activation:11"))
	var execute := CandidateExecuteManeuverCommand.new(0, {
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:11",
		"speed": 3,
		"yaw_clicks": [0, 0, 0],
		"yaw_bonus_joint": -1,
	})
	execute.sequence = 15
	var committed: Dictionary = execute.execute(state)
	assert_false(committed.is_empty())
	state.objectives["obstacles"] = [{
		"obstacle_id": "obstacle:0",
		"data_key": "asteroid_1",
		"pos_x": float(committed["pos_x"]),
		"pos_y": float(committed["pos_y"]),
		"rotation_deg": 0.0,
		"placing_player": 0,
		"placement_order": 0,
		"last_maneuver_execution_id": "",
	}]
	var squadron := SquadronInstance.create_from_data(
			"displaced", _squadron_data(), 1)
	squadron.pos_x = float(committed["pos_x"])
	squadron.pos_y = float(committed["pos_y"])
	state.get_player_state(1).squadrons.append(squadron)
	var identity: Dictionary = {
		"owner_player": 0,
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:11",
		"maneuver_execution_id": "maneuver:15",
	}
	var apply := CandidateApplyManeuverTransformCommand.new(
			0, identity.duplicate(true))
	apply.sequence = 16
	assert_false(apply.execute(state).is_empty())
	var displaced: Array[Dictionary] = [{"owner": 1, "squadron_index": 0}]
	var start_payload: Dictionary = identity.duplicate(true)
	start_payload["displaced_squadrons"] = displaced
	var start := CandidateStartDisplacementCommand.new(0, start_payload)
	start.sequence = 17
	assert_false(start.execute(state).is_empty())
	var point: Vector2 = _direct_displacement_point(ship)
	var commit_payload: Dictionary = identity.duplicate(true)
	commit_payload["placements"] = [{
		"owner": 1,
		"squadron_index": 0,
		"pos_x": point.x / GameScale.play_area_size_px.x,
		"pos_y": point.y / GameScale.play_area_size_px.y,
	}]
	commit_payload["excluded_squadrons"] = []
	var commit := CandidateCommitDisplacementCommand.new(1, commit_payload)
	commit.sequence = 18
	assert_false(commit.execute(state).is_empty())
	var order := ORDER.new(0, identity.merged({
		"obstacle_ids": ["obstacle:0"],
	}))
	order.sequence = 19
	assert_false(order.execute(state).is_empty())
	var asteroid := ASTEROID.new(0, identity.merged({
		"obstacle_id": "obstacle:0",
	}))
	asteroid.sequence = 20
	return {"state": state, "ship": ship, "command": asteroid}


func _resolve_debug_immediate(state: GameState, ship: ShipInstance,
		effect_id: String, sequence: int, choice: Dictionary) -> void:
	var debug := CandidateDebugDealDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": 0,
		"effect_id": effect_id,
	})
	debug.sequence = sequence
	assert_false(debug.execute(state).is_empty())
	var record: Dictionary = ship.active_immediate_resolution_snapshot()
	var payload: Dictionary = {
		"owner_player": 0,
		"ship_index": 0,
		"public_card_ref": record["public_card_ref"],
		"immediate_resolution_id": record["immediate_resolution_id"],
		"enclosing_kind": "debug",
		"debug_application_id": "debug:%d" % sequence,
	}
	for key: String in choice:
		payload[key] = choice[key]
	var actor: int = int(record["actor_player"])
	var resolve := CandidateResolveImmediateEffectCommand.new(
			0 if actor == -1 else actor, payload)
	resolve.sequence = sequence + 1
	assert_false(resolve.execute(state).is_empty())


func _assert_lethal_maneuver_cleanup(
		state: GameState, ship: ShipInstance) -> void:
	assert_true(ship.has_finalized_destruction())
	assert_false(ship.has_active_ship_activation())
	assert_false(ship.has_active_maneuver_execution())
	assert_false(ship.has_active_obstacle_resolution())
	assert_false(ship.has_active_immediate_resolution())
	assert_eq(state.interaction_flow.flow_type, Constants.InteractionFlow.NONE)
	assert_true(EVALUATOR.next_action(state, 0, 0).is_empty())
	var complete := CandidateCompleteManeuverCommand.new(0, {
		"owner_player": 0,
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:11",
		"maneuver_execution_id": "maneuver:15",
	})
	assert_ne(complete.validate(state), "")
	assert_true(complete.execute(state).is_empty())


func _game_flow_processor(state: GameState) -> Node:
	if not state.has_valid_match_player_control_binding():
		assert_true(state.install_match_player_control_binding(
				MatchPlayerControlBinding.create_hot_seat_human()))
	GameManager.current_game_state = state
	GameManager.is_game_active = true
	GameManager.active_player = 0
	var processor: Node = PROCESSOR.new()
	add_child_autofree(processor)
	processor.command_executed.connect(
			GameManager._on_ship_phase_turn_terminated)
	processor.command_executed.connect(GameManager._on_destroy_unit_committed)
	return processor


func _add_flow_ship(state: GameState, owner: int,
		activated: bool) -> ShipInstance:
	var ship := ShipInstance.create_from_data(
			"flow-ship", _ship_data(), 1, owner)
	ship.roster_entry_id = "flow-ship:%d:%d" % [
		owner, state.get_player_state(owner).ships.size()]
	ship.activated_this_round = activated
	ship.command_dial_stack.assign_dials(
			[Constants.CommandType.NAVIGATE], 1)
	state.get_player_state(owner).ships.append(ship)
	return ship


func _history_types(processor: Node) -> Array[String]:
	var types: Array[String] = []
	for command: GameCommand in processor.get_history():
		types.append(command.command_type)
	return types


func _direct_displacement_point(ship: ShipInstance) -> Vector2:
	var base := ShipBase.new(ship.ship_data.ship_size,
			Transform2D(ship.get_rotation_rad(), ship.get_pixel_position(
					GameScale.play_area_size_px)))
	return base.ship_transform * Vector2(0.0,
			-base.half_length_px
			- GameScale.squadron_base_diameter_px * 0.5 - 1.0)


func _commit_order(state: GameState) -> GameCommand:
	return ORDER.new(0, _identity_base().merged({
		"obstacle_ids": ["obstacle:0"],
	}))


func _base(obstacle_id: String) -> Dictionary:
	return _identity_base().merged({
		"obstacle_id": obstacle_id,
	})


func _identity_base() -> Dictionary:
	return {
		"owner_player": 0,
		"ship_index": 0,
		"ship_activation_identity": ACTIVATION_ID,
		"maneuver_execution_id": EXECUTION_ID,
	}


func _deck(cards: Array[DamageCard]) -> DamageDeck:
	var draw: Array[Dictionary] = []
	for card: DamageCard in cards:
		draw.append(card.serialize_for_save7("draw"))
	return DamageDeck.deserialize_for_save7({
		"draw_pile": draw,
		"discard_pile": [],
	})


func _card(physical_id: String, effect: String,
		timing: String) -> DamageCard:
	var card := DamageCard.new()
	card.physical_card_id = physical_id
	card.effect_id = effect
	card.title = effect
	card.trait_type = "Ship"
	card.timing = timing
	return card


func _ship_data() -> ShipData:
	var data := ShipData.new()
	data.ship_size = Constants.ShipSize.SMALL
	data.hull = 8
	data.max_speed = 3
	data.command_value = 1
	data.navigation_chart = [[1], [1, 1], [1, 1, 1]]
	data.shields = {"front": 1, "left": 1, "right": 1, "rear": 1}
	return data


func _lethal_ship_data() -> ShipData:
	var data: ShipData = _ship_data()
	data.hull = 4
	return data


func _squadron_data() -> SquadronData:
	var data := SquadronData.new()
	data.hull = 3
	return data
