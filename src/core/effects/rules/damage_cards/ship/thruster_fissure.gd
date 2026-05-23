## Thruster Fissure
##
## Static rule hook for the Thruster Fissure damage card.
## Rules Reference: Damage Card "Thruster Fissure" — "When you change your
## speed by 1 or more, suffer 1 damage." FAQ: Admiral Konstantine's external
## speed change does not trigger this effect.
class_name ThrusterFissure
extends RefCounted


const RULE_ID: String = "damage_card.thruster_fissure"
const EFFECT_ID: String = "thruster_fissure"

static var _rule_instance: ThrusterFissure = null


## Registers the execute-maneuver speed-change observer hook.
static func register() -> void:
	if _rule_instance == null:
		_rule_instance = ThrusterFissure.new()
	RuleRegistry.register_rule(RULE_ID, [
		FlowHook.observer(RULE_ID,
				Constants.InteractionFlow.SHIP_ACTIVATION,
				Constants.InteractionStep.MANEUVER_STEP,
				RuleSurface.COMMAND_EXECUTE_MANEUVER,
				Callable(_rule_instance, "observe_execute_maneuver")),
	])


## Returns a facedown-damage follow-up for player-authored speed changes.
func observe_execute_maneuver(game_state: GameState,
		command: GameCommand,
		result: Dictionary) -> Array[GameCommand]:
	var followups: Array[GameCommand] = []
	var ship: ShipInstance = _ship_from_result(game_state, command, result)
	if ship == null or not _has_faceup_damage(ship):
		return followups
	if int(result.get("speed_delta", 0)) == 0:
		return followups
	followups.append(_damage_command(game_state, ship))
	return followups


func _ship_from_result(game_state: GameState,
		command: GameCommand,
		result: Dictionary) -> ShipInstance:
	if game_state == null or command == null:
		return null
	return game_state.get_ship(command.player_index,
			int(result.get("ship_index", -1)))


func _damage_command(game_state: GameState, ship: ShipInstance) -> GameCommand:
	return PersistentEffectDamageCommand.new(ship.owner_player, {
		"owner_player": ship.owner_player,
		"ship_index": game_state.find_ship_index(ship),
		"effect_id": EFFECT_ID,
		"draw_from_deck": true,
	})


func _has_faceup_damage(ship: ShipInstance) -> bool:
	for card_var: Variant in ship.faceup_damage:
		if not card_var is DamageCard:
			continue
		var card: DamageCard = card_var as DamageCard
		if card.is_faceup and card.effect_id == EFFECT_ID:
			return true
	return false