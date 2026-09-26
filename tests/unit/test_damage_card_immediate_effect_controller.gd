## Application-contract-v2 no-active-attack immediate-card presentation.
extends GutTest

const ControllerScript: GDScript = preload(
		"res://src/scenes/game_board/damage_card_immediate_effect_controller.gd")
class DirectSubmitter:
	extends CommandSubmitter

	var next_sequence: int = 200
	var submitted: Array[GameCommand] = []

	func submit(command: GameCommand) -> Dictionary:
		command.sequence = next_sequence
		next_sequence += 1
		submitted.append(command)
		return command.execute(GameManager.current_game_state)


var _state: GameState
var _controller: Node
var _submitter: DirectSubmitter
var _saved_state: GameState
var _saved_submitter: CommandSubmitter
var _defense_token_refreshes: int = 0


func before_each() -> void:
	_saved_state = GameManager.current_game_state
	_saved_submitter = GameManager.get_command_submitter()
	_state = GameState.new()
	_state.initialize()
	_state.current_phase = Constants.GamePhase.SHIP
	GameManager.current_game_state = _state
	_submitter = DirectSubmitter.new()
	GameManager.set_command_submitter(_submitter)
	_controller = ControllerScript.new()
	add_child_autofree(_controller)
	_controller.initialize(null, null)
	EventBus.ship_defense_token_changed.connect(_on_defense_token_changed)


func after_each() -> void:
	if EventBus.ship_defense_token_changed.is_connected(
			_on_defense_token_changed):
		EventBus.ship_defense_token_changed.disconnect(
				_on_defense_token_changed)
	GameManager.current_game_state = _saved_state
	GameManager.set_command_submitter(_saved_submitter)


func test_mismatched_v2_public_addition_does_not_create_presentation() -> void:
	var fixture: Dictionary = _debug_result("injured_crew", 10)
	var result: Dictionary = (fixture["result"] as Dictionary).duplicate(true)
	result["damage_application"]["faceup_additions"][0]["effect_id"] = \
			"comm_noise"
	_controller.react_to_debug_damage_result(fixture["command"], result)
	assert_null(_controller.get_node_or_null(
			"DebugDamageImmediateEffectModalLayer"))
	assert_false(_state.current_attack_state.active)


func test_v2_public_ref_presents_owner_choice_without_attack_flow() -> void:
	var fixture: Dictionary = _debug_result("injured_crew", 11)
	_controller.react_to_debug_damage_result(
			fixture["command"], fixture["result"])
	var layer: CanvasLayer = _controller.get_node_or_null(
			"DebugDamageImmediateEffectModalLayer") as CanvasLayer
	assert_not_null(layer)
	var modal: OpponentChoiceModal = layer.get_node(
			"DebugDamageImmediateEffectModal") as OpponentChoiceModal
	assert_true(modal.visible)
	assert_false(_state.current_attack_state.active)
	assert_eq(_state.interaction_flow.flow_type,
			Constants.InteractionFlow.NONE)


func test_v2_choice_submits_candidate_command_and_projects_token_discard() -> void:
	var fixture: Dictionary = _debug_result("injured_crew", 12)
	var ship: ShipInstance = fixture["ship"]
	_controller.react_to_debug_damage_result(
			fixture["command"], fixture["result"])
	var modal_layer: CanvasLayer = _controller.get_node(
			"DebugDamageImmediateEffectModalLayer") as CanvasLayer
	var modal: OpponentChoiceModal = modal_layer.get_node(
			"DebugDamageImmediateEffectModal") as OpponentChoiceModal
	modal.choice_confirmed.emit({"id": "discard_defense_0"})
	assert_eq(_submitter.submitted.size(), 1)
	assert_true(_submitter.submitted[0] \
			is CandidateResolveImmediateEffectCommand)
	assert_eq(_submitter.submitted[0].payload.keys(), [
		"owner_player", "ship_index", "public_card_ref",
		"immediate_resolution_id", "enclosing_kind",
		"debug_application_id", "defense_token_index",
	])
	assert_eq(int(ship.defense_tokens[0].get("state", -1)),
			Constants.DefenseTokenState.DISCARDED)
	assert_false(ship.has_active_immediate_resolution())
	assert_eq(_defense_token_refreshes, 1)


func test_production_debug_shield_failure_applies_selected_shield_loss() -> void:
	var fixture: Dictionary = _debug_result("shield_failure", 13)
	var damaged_ship: ShipInstance = fixture["ship"]
	_controller.react_to_debug_damage_result(
			fixture["command"], fixture["result"])
	var modal_layer: CanvasLayer = _controller.get_node(
			"DebugDamageImmediateEffectModalLayer") as CanvasLayer
	var modal: OpponentChoiceModal = modal_layer.get_node(
			"DebugDamageImmediateEffectModal") as OpponentChoiceModal
	modal.choice_confirmed.emit({"zones": ["FRONT"]})
	assert_eq(damaged_ship.current_shields["FRONT"], 2)
	assert_false(damaged_ship.has_active_immediate_resolution())
	assert_eq(damaged_ship.get_facedown_damage_count(), 1)


func test_v2_automatic_branch_resolves_without_legacy_array_index() -> void:
	var fixture: Dictionary = _debug_result("structural_damage", 14)
	var result: Dictionary = fixture["result"]
	_controller.react_to_debug_damage_result(fixture["command"], result)
	assert_eq(_submitter.submitted.size(), 1)
	assert_true(_submitter.submitted[0] \
			is CandidateResolveImmediateEffectCommand)
	assert_false(_submitter.submitted[0].payload.has("card_index"))
	assert_false(_submitter.submitted[0].payload.has("choice"))
	assert_false((fixture["ship"] as ShipInstance) \
			.has_active_immediate_resolution())
	assert_eq((fixture["ship"] as ShipInstance).get_facedown_damage_count(), 2)
	assert_eq(_state.damage_deck.get_total_count(), 0)


func _debug_result(effect_id: String, sequence: int) -> Dictionary:
	var ship := _add_ship(0)
	_state.damage_deck = _deck(effect_id)
	_submitter.next_sequence = sequence
	var result: Dictionary = GameManager.submit_debug_deal_damage(
			ship, effect_id)
	assert_eq(_submitter.submitted.size(), 1)
	var command: GameCommand = _submitter.submitted.pop_back()
	assert_true(command is CandidateDebugDealDamageCommand)
	assert_false(result.is_empty())
	assert_true(result.has("damage_application"))
	assert_false(result.has("card_index"))
	return {"ship": ship, "command": command, "result": result}


func _on_defense_token_changed(_ship: RefCounted) -> void:
	_defense_token_refreshes += 1


func _add_ship(player: int) -> ShipInstance:
	var data := ShipData.new()
	data.hull = 5
	data.command_value = 2
	data.engineering_value = 3
	data.shields = {"FRONT": 3}
	data.defense_tokens = ["brace", "redirect"]
	var ship := ShipInstance.create_from_data("test", data, 2, player)
	ship.roster_entry_id = "debug-immediate"
	_state.get_player_state(player).ships.append(ship)
	return ship


func _deck(effect_id: String) -> DamageDeck:
	var source := DamageCard.new()
	source.physical_card_id = "damage:%s" % effect_id
	source.effect_id = effect_id
	source.title = effect_id
	source.trait_type = "Ship"
	source.timing = "immediate"
	var extra := DamageCard.new()
	extra.physical_card_id = "damage:extra"
	extra.effect_id = "ordinary"
	extra.title = "ordinary"
	extra.trait_type = "Ship"
	extra.timing = "persistent"
	return DamageDeck.deserialize_for_save7({
		"draw_pile": [
			source.serialize_for_save7("draw"),
			extra.serialize_for_save7("draw"),
		],
		"discard_pile": [],
	})
