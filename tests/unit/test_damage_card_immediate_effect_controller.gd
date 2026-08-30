## DBG-001 no-active-attack damage-card presentation coverage.
extends GutTest

const ControllerScript: GDScript = preload(
		"res://src/scenes/game_board/damage_card_immediate_effect_controller.gd")

var _state: GameState
var _controller: Node
var _defense_token_refreshes: int = 0


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_state.current_phase = Constants.GamePhase.SHIP
	GameManager.current_game_state = _state
	_controller = ControllerScript.new()
	add_child_autofree(_controller)
	_controller.initialize(null, null)
	EventBus.ship_defense_token_changed.connect(_on_defense_token_changed)


func after_each() -> void:
	if EventBus.ship_defense_token_changed.is_connected(_on_defense_token_changed):
		EventBus.ship_defense_token_changed.disconnect(_on_defense_token_changed)
	GameManager.current_game_state = null


func test_mismatched_result_identity_does_not_create_presentation() -> void:
	var ship := _add_ship(0)
	ship.add_faceup_damage(_immediate_card("injured_crew"))
	_controller.react_to_debug_damage_result(null, {
		"owner_player": 0, "ship_index": 0, "card_index": 0,
		"effect_id": "comm_noise"})
	assert_null(_controller.get_node_or_null("DebugDamageImmediateEffectModalLayer"))
	assert_false(_state.current_attack_state.active)


func test_owner_choice_is_presented_without_attack_flow() -> void:
	var ship := _add_ship(0)
	ship.add_faceup_damage(_immediate_card("injured_crew"))
	_controller.react_to_debug_damage_result(null, {
		"owner_player": 0, "ship_index": 0, "card_index": 0,
		"effect_id": "injured_crew"})
	var layer: CanvasLayer = _controller.get_node_or_null(
			"DebugDamageImmediateEffectModalLayer") as CanvasLayer
	assert_not_null(layer)
	var modal: OpponentChoiceModal = layer.get_node("DebugDamageImmediateEffectModal") \
			as OpponentChoiceModal
	assert_true(modal.visible)
	assert_false(_state.current_attack_state.active)
	assert_eq(_state.interaction_flow.flow_type, Constants.InteractionFlow.NONE)


func test_injured_crew_choice_projects_canonical_token_discard_in_hot_seat() -> void:
	var ship := _add_ship(0)
	ship.add_faceup_damage(_immediate_card("injured_crew"))
	ResolveImmediateEffectCommand.register()
	_controller.react_to_debug_damage_result(null, {
		"owner_player": 0, "ship_index": 0, "card_index": 0,
		"effect_id": "injured_crew"})
	var modal_layer: CanvasLayer = _controller.get_node(
			"DebugDamageImmediateEffectModalLayer") as CanvasLayer
	var modal: OpponentChoiceModal = modal_layer.get_node(
		"DebugDamageImmediateEffectModal") as OpponentChoiceModal
	modal.choice_confirmed.emit({"id": "discard_defense_0"})
	assert_eq(int(ship.defense_tokens[0].get("state", -1)),
			Constants.DefenseTokenState.DISCARDED,
			"Injured Crew must discard the canonical defense token.")
	assert_eq(_defense_token_refreshes, 1,
			"Hot-seat must project the command result through the normal token refresh signal.")


func _on_defense_token_changed(_ship: RefCounted) -> void:
	_defense_token_refreshes += 1


func _add_ship(player: int) -> ShipInstance:
	var data := ShipData.new()
	data.hull = 5
	data.command_value = 2
	data.engineering_value = 3
	data.shields = {"FRONT": 3}
	data.defense_tokens = ["brace"]
	var ship := ShipInstance.create_from_data("test", data, 2, player)
	_state.get_player_state(player).ships.append(ship)
	return ship


func _immediate_card(effect_id: String) -> DamageCard:
	var card := DamageCard.new()
	card.effect_id = effect_id
	card.is_faceup = true
	card.timing = "immediate"
	return card
