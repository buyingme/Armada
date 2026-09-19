extends GutTest


const PROCESSOR_SCRIPT: GDScript = preload(
		"res://src/autoload/command_processor.gd")

var _processor: Node
var _state: GameState
var _ship: ShipInstance
var _saved_registry: Dictionary


func before_each() -> void:
	_saved_registry = GameCommand._registry.duplicate()
	_processor = PROCESSOR_SCRIPT.new()
	add_child_autofree(_processor)
	_state = GameState.new()
	_state.initialize()
	_state.current_phase = Constants.GamePhase.SHIP
	_state.objectives["obstacles"] = []
	_ship = ShipInstance.create_from_data("processor", _ship_data(), 1, 0)
	_ship.roster_entry_id = "processor-ship"
	_ship.pos_x = 0.5
	_ship.pos_y = 0.5
	_ship.current_speed = 1
	_state.get_player_state(0).ships.append(_ship)
	assert_true(_ship.establish_ship_activation("ship-activation:90"))
	assert_true(_ship.open_maneuver_opportunity("ship-activation:90"))
	GameManager.current_game_state = _state


func after_each() -> void:
	GameManager.current_game_state = null
	GameCommand._registry = _saved_registry


func test_live_authority_rederives_apply_and_complete_without_persisted_route() -> void:
	var command := CandidateExecuteManeuverCommand.new(0, {
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:90",
		"speed": 1,
		"yaw_clicks": [0],
		"yaw_bonus_joint": -1,
	})
	var result: Dictionary = _processor.submit(command)
	assert_false(result.is_empty())
	assert_eq(command.sequence, 0)
	assert_false(_ship.has_active_maneuver_execution())
	assert_eq(_ship.maneuver_opportunity_disposition,
			ShipInstance.ACTIVATION_DISPOSITION_CONSUMED)
	var types: Array[String] = []
	for history_command: GameCommand in _processor.get_history():
		types.append(history_command.command_type)
	assert_eq(types, [
		"execute_maneuver", "apply_maneuver_transform", "complete_maneuver"])
	assert_eq(_processor.get_pending_observer_followup_count(), 0)


func test_player_decision_stops_rederivation_without_partial_activation() -> void:
	var source := DamageCard.new()
	source.physical_card_id = "damage:thruster"
	source.effect_id = "thruster_fissure"
	source.title = "Thruster Fissure"
	source.trait_type = "Ship"
	source.timing = "persistent"
	source.flip_faceup()
	source.public_card_ref = "faceup:thruster"
	_ship.add_faceup_damage(source)
	_state.damage_deck = DamageDeck.deserialize_for_save7({
		"draw_pile": [], "discard_pile": []})
	var command := CandidateExecuteManeuverCommand.new(0, {
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:90",
		"speed": 0,
		"yaw_clicks": [],
		"yaw_bonus_joint": -1,
	})
	# A Navigate speed change is required for Thruster Fissure applicability.
	_ship.command_tokens = CommandTokenManager.create(1)
	_ship.command_tokens.add_token(Constants.CommandType.NAVIGATE)
	command.payload["speed"] = 0
	var result: Dictionary = _processor.submit(command)
	assert_false(result.is_empty())
	assert_true(_ship.has_active_maneuver_execution())
	assert_false(bool(_ship.active_maneuver_execution_snapshot()[
			"final_transform_applied"]))
	assert_eq(_processor.get_history().size(), 1)
	assert_eq(_processor.get_pending_observer_followup_count(), 0)


func _ship_data() -> ShipData:
	var data := ShipData.new()
	data.ship_size = Constants.ShipSize.SMALL
	data.hull = 5
	data.max_speed = 3
	data.command_value = 1
	data.navigation_chart = [[1], [1, 1], [1, 1, 1]]
	data.shields = {"front": 1, "left": 1, "right": 1, "rear": 1}
	return data
