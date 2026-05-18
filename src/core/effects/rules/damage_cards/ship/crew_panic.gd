## Crew Panic
##
## Static rule hook for the Crew Panic damage card.
## Rules Reference: Damage Card "Crew Panic" — "Before you reveal a
## command dial, you must either suffer 1 damage or discard that dial. If you
## discard it, do not reveal a dial this round."
class_name CrewPanic
extends RefCounted


const RULE_ID: String = "damage_card.crew_panic"
const EFFECT_ID: String = "crew_panic"
const TARGET_COMMAND_DIAL_REVEAL: String = "command_dial_reveal"
const AFFORDANCE_KEY: String = "crew_panic_choices"
const OPTION_DISCARD_DIAL: String = "discard_dial"
const OPTION_SUFFER_DAMAGE: String = "suffer_damage"

static var _rule_instance: CrewPanic = null


## Registers the pre-reveal command-dial choice enabler.
static func register() -> void:
	if _rule_instance == null:
		_rule_instance = CrewPanic.new()
	RuleRegistry.register_rule(RULE_ID, [
		FlowHook.enabler(RULE_ID,
				Constants.InteractionFlow.SHIP_ACTIVATION,
				Constants.InteractionStep.WAIT_FOR_SHIP_SELECT,
				TARGET_COMMAND_DIAL_REVEAL,
				Callable(_rule_instance, "project_pre_reveal_affordance")),
	])


## Projects mandatory Crew Panic choices for the active player's hidden dials.
## Active state is derived from [member ShipInstance.faceup_damage], so the
## rule survives save/load without a legacy [EffectRegistry] bridge.
## Rules Reference: Damage Card "Crew Panic" — "Before you reveal a command
## dial..."
func project_pre_reveal_affordance(state: GameState,
		flow: InteractionFlow,
		viewer_player: int) -> Dictionary:
	if not _can_project_for_viewer(state, flow, viewer_player):
		return {}
	var choices: Array[Dictionary] = _choices_for_player(
			state, flow.controller_player)
	if choices.is_empty():
		return {}
	return {AFFORDANCE_KEY: {
		"rule_id": RULE_ID,
		"target": TARGET_COMMAND_DIAL_REVEAL,
		"ships": choices,
	}}


func _can_project_for_viewer(state: GameState,
		flow: InteractionFlow,
		viewer_player: int) -> bool:
	if state == null or flow == null:
		return false
	if state.current_phase != Constants.GamePhase.SHIP:
		return false
	if viewer_player != flow.controller_player:
		return false
	return flow.controller_player >= 0


func _choices_for_player(state: GameState,
		player_index: int) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	var player_state: PlayerState = state.get_player_state(player_index)
	if player_state == null:
		return choices
	for ship_index: int in range(player_state.ships.size()):
		var ship: ShipInstance = player_state.ships[ship_index] as ShipInstance
		if _is_active_for_ship(ship):
			choices.append(_choice_for_ship(player_index, ship_index))
	return choices


func _is_active_for_ship(ship: ShipInstance) -> bool:
	if ship == null or ship.is_destroyed() or ship.activated_this_round:
		return false
	if not _has_hidden_dial(ship):
		return false
	return _has_faceup_crew_panic(ship)


func _has_hidden_dial(ship: ShipInstance) -> bool:
	if ship.command_dial_stack == null:
		return false
	return ship.command_dial_stack.get_hidden_count() > 0


func _has_faceup_crew_panic(ship: ShipInstance) -> bool:
	for card_var: Variant in ship.faceup_damage:
		if not card_var is DamageCard:
			continue
		var card: DamageCard = card_var as DamageCard
		if card.is_faceup and card.effect_id == EFFECT_ID:
			return true
	return false


func _choice_for_ship(owner_player: int,
		ship_index: int) -> Dictionary:
	return {
		"owner_player": owner_player,
		"ship_index": ship_index,
		"choice_info": _choice_info(owner_player, ship_index),
	}


func _choice_info(owner_player: int,
		ship_index: int) -> Dictionary:
	return {
		"choice_type": "crew_panic",
		"chooser": "owner",
		"multi_select": false,
		"max_selections": 1,
		"rule_id": RULE_ID,
		"effect_id": EFFECT_ID,
		"owner_player": owner_player,
		"ship_index": ship_index,
		"card_title": "Crew Panic",
		"effect_text": "Before you reveal a command dial, you must either " \
				+"suffer 1 damage or discard that dial. If you discard it, " \
				+"do not reveal a dial this round.",
		"options": [
			{"id": OPTION_DISCARD_DIAL, "label": "Discard command dial",
					"available": true},
			{"id": OPTION_SUFFER_DAMAGE, "label": "Suffer 1 damage",
					"available": true},
		],
	}
