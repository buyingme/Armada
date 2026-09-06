## Regression coverage for BUG-039: a persistent damage-card effect may destroy
## the ship whose Ship Phase turn is current, but may not leave that turn or
## its activation projection stranded.
extends GutTest


const CmdProcessor: GDScript = preload("res://src/autoload/command_processor.gd")

var _saved_state: GameState = null
var _saved_registry: Dictionary = {}


func before_each() -> void:
	_saved_state = GameManager.current_game_state
	_saved_registry = GameCommand._registry.duplicate()


func after_each() -> void:
	GameManager.current_game_state = _saved_state
	GameCommand._registry = _saved_registry


func test_ruptured_engine_destruction_ends_active_activation_and_advances_phase() -> void:
	var state: GameState = _state_with_active_ship_at_final_hull()
	GameManager.current_game_state = state
	var processor: Node = CmdProcessor.new()
	add_child_autofree(processor)
	var result: Dictionary = processor.submit(_lethal_damage_command(
			"ruptured_engine", 0))
	var ship: ShipInstance = state.get_ship(0, 0)
	assert_true(bool(result.get("destroyed", false)))
	assert_true(bool(result.get("ship_phase_turn_terminated", false)))
	assert_true(ship.is_destroyed())
	assert_false(ship.has_active_ship_activation(),
			"Exceptional destruction must clear the active activation boundary.")
	assert_eq(state.current_phase, Constants.GamePhase.SQUADRON,
			"The existing recorded phase transition must converge when no ships remain.")
	assert_eq(_history_types(processor), [
			"persistent_effect_damage", "destroy_unit", "advance_phase"],
			"Cleanup must precede the existing phase transition.")


func test_crew_panic_destruction_at_pre_reveal_boundary_advances_phase() -> void:
	var state: GameState = _state_with_pre_reveal_ship_at_final_hull()
	GameManager.current_game_state = state
	var processor: Node = CmdProcessor.new()
	add_child_autofree(processor)
	var result: Dictionary = processor.submit(_lethal_damage_command(
			"crew_panic", 0))
	assert_true(bool(result.get("destroyed", false)))
	assert_true(bool(result.get("ship_phase_turn_terminated", false)))
	assert_eq(state.current_phase, Constants.GamePhase.SQUADRON,
			"Crew Panic destruction must not leave Ship Phase waiting for a dead ship.")
	assert_eq(_history_types(processor), [
			"persistent_effect_damage", "destroy_unit", "advance_phase"])


func test_destruction_with_another_legal_ship_projects_next_controller() -> void:
	var state: GameState = _state_with_active_ship_at_final_hull()
	_add_ship(state, 1, false)
	GameManager.current_game_state = state
	var processor: Node = CmdProcessor.new()
	add_child_autofree(processor)
	var result: Dictionary = processor.submit(_lethal_damage_command(
			"ruptured_engine", 0))
	assert_true(bool(result.get("ship_phase_turn_terminated", false)))
	assert_eq(state.current_phase, Constants.GamePhase.SHIP)
	assert_eq(state.interaction_flow.flow_type,
			Constants.InteractionFlow.SHIP_ACTIVATION)
	assert_eq(state.interaction_flow.step_id,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT)
	assert_eq(state.interaction_flow.controller_player, 1,
			"The surviving opponent must receive the next canonical Ship Phase choice.")
	assert_eq(_history_types(processor), ["persistent_effect_damage", "destroy_unit"])


func _state_with_active_ship_at_final_hull() -> GameState:
	var state := _base_state()
	var ship: ShipInstance = _add_ship(state, 0, true)
	for i: int in range(ship.ship_data.hull - 1):
		ship.add_facedown_damage(_damage_card("prior_%d" % i))
	assert_true(ship.establish_ship_activation("ship-activation:bug-039"))
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.MANEUVER_STEP, 0,
			Constants.Visibility.ALL,
			{"ship_index": 0,
				"ship_activation_identity": ship.ship_activation_identity})
	return state


func _state_with_pre_reveal_ship_at_final_hull() -> GameState:
	var state := _base_state()
	var ship: ShipInstance = _add_ship(state, 0, false)
	for i: int in range(ship.ship_data.hull - 1):
		ship.add_facedown_damage(_damage_card("prior_%d" % i))
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT, 0)
	return state


func _base_state() -> GameState:
	var state := GameState.new()
	state.initialize()
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()))
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.damage_deck = DamageDeck.new()
	state.damage_deck.initialize()
	return state


func _add_ship(state: GameState, owner: int,
		activate: bool) -> ShipInstance:
	var data := ShipData.new()
	data.hull = 4
	data.command_value = 1
	data.engineering_value = 2
	data.max_speed = 2
	data.shields = {"FRONT": 1}
	data.defense_tokens = ["brace"]
	var ship := ShipInstance.create_from_data("bug_039_ship", data, 2, owner)
	if activate:
		ship.command_dial_stack.assign_dials([Constants.CommandType.NAVIGATE], 1)
	state.get_player_state(owner).ships.append(ship)
	return ship


func _lethal_damage_command(effect_id: String,
		owner: int) -> PersistentEffectDamageCommand:
	return PersistentEffectDamageCommand.new(owner, {
		"owner_player": owner,
		"ship_index": 0,
		"effect_id": effect_id,
	})


func _damage_card(title: String) -> DamageCard:
	var card := DamageCard.create("Ship", title)
	card.is_faceup = false
	return card


func _history_types(processor: Node) -> Array[String]:
	var types: Array[String] = []
	for command: GameCommand in processor.get_history():
		types.append(command.command_type)
	return types
