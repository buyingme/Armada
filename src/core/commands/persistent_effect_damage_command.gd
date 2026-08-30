## PersistentEffectDamageCommand
##
## Deals one facedown damage card to a ship as a consequence of a
## persistent damage-card effect (Ruptured Engine, Damaged Controls,
## Thruster Fissure, or Crew Panic).
##
## The card is pre-drawn by the presentation layer and serialized into
## the payload so the command is deterministic on replay.
##
## Payload:
##   [code]owner_player[/code] — int — ship owner index
##   [code]ship_index[/code]   — int — index in the player's fleet
##   [code]effect_id[/code]    — String — which persistent effect triggered
##   [code]card_data[/code]    — Dictionary — serialized DamageCard, or
##   [code]draw_from_deck[/code] — bool — draw deterministically in execute()
##
## Rules Reference: "Ruptured Engine", "Damaged Controls",
## "Thruster Fissure", "Crew Panic" card texts.
class_name PersistentEffectDamageCommand
extends GameCommand


const FLOW_SPEC_SCRIPT: GDScript = preload("res://src/core/state/flow_spec.gd")


## Valid persistent-damage-dealing effect ids.
const VALID_EFFECTS: Array[String] = [
	"ruptured_engine",
	"damaged_controls",
	"thruster_fissure",
	"crew_panic",
]


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("persistent_effect_damage", func(
			player: int, pl: Dictionary) -> GameCommand:
		return PersistentEffectDamageCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "persistent_effect_damage", p_payload)


## Validates that the ship exists and card data is provided.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if game_state.current_phase != Constants.GamePhase.SHIP:
		return "Not in Ship Phase."
	var effect_id: String = str(payload.get("effect_id", ""))
	if effect_id not in VALID_EFFECTS:
		return "Unknown persistent effect: '%s'." % effect_id
	var owner: int = int(payload.get("owner_player", -1))
	var idx: int = int(payload.get("ship_index", -1))
	var ship: ShipInstance = game_state.get_ship(owner, idx)
	if ship == null:
		return "Ship not found."
	if _has_card_payload():
		return ""
	if bool(payload.get("draw_from_deck", false)):
		return _validate_damage_deck(game_state)
	return "Missing card_data."


## Deals one facedown damage card, checks for destruction.
func execute(game_state: GameState) -> Dictionary:
	var owner: int = int(payload.get("owner_player", -1))
	var idx: int = int(payload.get("ship_index", -1))
	var ship: ShipInstance = game_state.get_ship(owner, idx)
	var card: DamageCard = _damage_card_for_payload(game_state)
	if card == null:
		return {}
	card.is_faceup = false
	var was_active_ship: bool = ship.has_active_ship_activation()
	var ended_selection_turn: bool = _ends_current_selection_turn(
			game_state, ship)
	ship.add_facedown_damage(card)
	var new_hull: int = ship.ship_data.hull - ship.get_total_damage()
	var destroyed: bool = ship.is_destroyed()
	var ship_phase_turn_terminated: bool = false
	var next_ship_phase_controller: int = -1
	if destroyed:
		ship.mark_destroyed()
		ship_phase_turn_terminated = was_active_ship or ended_selection_turn
		if ship_phase_turn_terminated:
			next_ship_phase_controller = _next_ship_phase_controller(
					game_state, owner)
			game_state.interaction_flow = FLOW_SPEC_SCRIPT.make_interaction_flow(
					Constants.InteractionFlow.SHIP_ACTIVATION,
					Constants.InteractionStep.WAIT_FOR_SHIP_SELECT,
					game_state,
					{"active_player": next_ship_phase_controller},
					Constants.Visibility.ALL)
	return {
		"effect_id": payload.get("effect_id", ""),
		"owner_player": owner,
		"ship_index": idx,
		"cards_added": 1,
		"card_title": card.title,
		"card_data": card.serialize(),
		"new_hull": new_hull,
		"destroyed": destroyed,
		"ship_phase_turn_terminated": ship_phase_turn_terminated,
		"next_ship_phase_controller": next_ship_phase_controller,
	}


## Returns whether this destruction ends the current Ship Phase turn before a
## ship activation identity has been established (Crew Panic's pre-reveal
## boundary).  It reads only the canonical interaction flow and target state.
func _ends_current_selection_turn(game_state: GameState,
		ship: ShipInstance) -> bool:
	if game_state == null or ship == null \
			or game_state.current_phase != Constants.GamePhase.SHIP \
			or ship.activated_this_round:
		return false
	var flow: InteractionFlow = game_state.interaction_flow
	return flow != null \
			and flow.flow_type == Constants.InteractionFlow.SHIP_ACTIVATION \
			and flow.step_id == Constants.InteractionStep.WAIT_FOR_SHIP_SELECT \
			and flow.controller_player == ship.owner_player


## Derives the ordinary alternating controller after a Ship Phase turn ends.
## This is intentionally a query over canonical ships, matching the existing
## GameManager turn owner; it creates no durable continuation state.
func _next_ship_phase_controller(game_state: GameState,
		ending_player: int) -> int:
	var other_player: int = Constants.PLAYER_COUNT - 1 - ending_player
	if _has_unactivated_ship(game_state, other_player):
		return other_player
	if _has_unactivated_ship(game_state, ending_player):
		return ending_player
	return ending_player


func _has_unactivated_ship(game_state: GameState, player: int) -> bool:
	var player_state: PlayerState = game_state.get_player_state(player)
	if player_state == null:
		return false
	for raw_ship: Variant in player_state.ships:
		if raw_ship is ShipInstance:
			var candidate: ShipInstance = raw_ship as ShipInstance
			if not candidate.is_destroyed() and not candidate.activated_this_round:
				return true
	return false


func _has_card_payload() -> bool:
	var raw_card: Variant = payload.get("card_data", {})
	return raw_card is Dictionary and not (raw_card as Dictionary).is_empty()


func _validate_damage_deck(game_state: GameState) -> String:
	if game_state.damage_deck == null:
		return "Missing damage deck."
	if game_state.damage_deck.get_total_count() <= 0:
		return "Damage deck is empty."
	return ""


func _damage_card_for_payload(game_state: GameState) -> DamageCard:
	if _has_card_payload():
		return DamageCard.deserialize(payload.get("card_data", {}))
	if bool(payload.get("draw_from_deck", false)) and game_state.damage_deck:
		return game_state.damage_deck.draw_card()
	return null
