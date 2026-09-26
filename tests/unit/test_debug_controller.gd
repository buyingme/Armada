## DBG-001 bounded DEBUG controller interaction coverage.
extends GutTest

const ControllerScript: GDScript = preload(
		"res://src/scenes/game_board/debug_controller.gd")
const DebugDamageScript: GDScript = preload(
		"res://src/core/commands/candidate_debug_deal_damage_command.gd")

var _board: Node2D
var _controller: DebugController
var _saved_state: GameState


func before_each() -> void:
	_saved_state = GameManager.current_game_state
	DebugMode.enabled = false
	DebugMode.deselect_token()
	_board = Node2D.new()
	add_child_autofree(_board)
	_controller = ControllerScript.new()
	add_child_autofree(_controller)


func after_each() -> void:
	GameManager.current_game_state = _saved_state
	DebugMode.enabled = false
	DebugMode.deselect_token()


func test_f12_respects_board_eligibility() -> void:
	_controller.initialize(_board, func() -> Array: return [],
			func() -> Array: return [], func() -> bool: return false)
	assert_true(_controller.try_handle_input(_key(KEY_F12)))
	assert_false(DebugMode.enabled)


func test_escape_cancels_reposition_preview_without_a_command() -> void:
	_controller.initialize(_board, func() -> Array: return [],
			func() -> Array: return [], func() -> bool: return true)
	DebugMode.enabled = true
	var token := Node2D.new()
	add_child_autofree(token)
	_controller.handle_token_click(token)
	assert_true(_controller.is_reposition_preview_active())
	assert_true(_controller.try_handle_input(_key(KEY_ESCAPE)))
	assert_false(_controller.is_reposition_preview_active())
	assert_null(DebugMode.selected_token)


func test_damage_targeting_clears_reposition_preview() -> void:
	_controller.initialize(_board, func() -> Array: return [],
			func() -> Array: return [], func() -> bool: return true)
	DebugMode.enabled = true
	var token := Node2D.new()
	add_child_autofree(token)
	_controller.handle_token_click(token)
	assert_true(_controller.is_reposition_preview_active())
	var shortcut := _key(KEY_D)
	shortcut.shift_pressed = true
	assert_true(_controller.try_handle_input(shortcut))
	assert_false(_controller.is_reposition_preview_active())
	assert_null(DebugMode.selected_token)
	assert_true(_controller.is_damage_targeting())


func test_candidate_debug_result_retires_debug_mode_for_immediate_handoff() \
		-> void:
	var state := GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SHIP
	var data := ShipData.new()
	data.hull = 5
	data.command_value = 1
	data.shields = {"FRONT": 3}
	var ship := ShipInstance.create_from_data("debug", data, 1, 0)
	ship.roster_entry_id = "debug-controller-ship"
	state.get_player_state(0).ships.append(ship)
	var card := DamageCard.new()
	card.physical_card_id = "damage:debug-controller"
	card.effect_id = "structural_damage"
	card.title = "Structural Damage"
	card.trait_type = "Ship"
	card.timing = "immediate"
	state.damage_deck = DamageDeck.deserialize_for_save7({
		"draw_pile": [card.serialize_for_save7("draw")],
		"discard_pile": [],
	})
	GameManager.current_game_state = state
	_controller.initialize(_board, func() -> Array: return [],
			func() -> Array: return [], func() -> bool: return true)
	var command: GameCommand = DebugDamageScript.new(0, {
		"owner_player": 0, "ship_index": 0,
		"effect_id": "structural_damage",
	})
	command.sequence = 31
	var result: Dictionary = command.execute(state)
	assert_false(result.is_empty())
	DebugMode.enabled = true
	_controller.react_to_command(command, result)
	assert_false(DebugMode.enabled)


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	return event
