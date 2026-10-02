## PersistentEffectDamageCommand
##
## Deals one facedown damage card to a ship as a consequence of a
## persistent damage-card effect (Ruptured Engine, Damaged Controls,
## Thruster Fissure, or Crew Panic).
##
## Authority and replay draw inside this command; a passive Network peer
## consumes one aggregate hidden draw without learning its identity.
##
## Payload:
##   [code]owner_player[/code] — int — ship owner index
##   [code]ship_index[/code]   — int — index in the player's fleet
##   [code]effect_id[/code]    — String — which persistent effect triggered
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


func application_contract_id() -> String:
	return "persistent_effect_damage"


func application_contract_version() -> int:
	return 2


func project_application_result(authority_result: Dictionary,
		viewer_player: int) -> Dictionary:
	return authority_result.duplicate(true) \
			if viewer_player in [0, 1] and _result_valid(authority_result) else {}


func execute_with_application_result(game_state: GameState,
		application_result: Dictionary) -> Dictionary:
	if not _result_valid(application_result) \
			or game_state.passive_damage_ledger == null:
		return {}
	var ship: ShipInstance = game_state.get_ship(
			int(payload.get("owner_player", -1)),
			int(payload.get("ship_index", -1)))
	var ledger: PassiveDamageLedger = game_state.passive_damage_ledger
	var owner: int = int(payload["owner_player"])
	var idx: int = int(payload["ship_index"])
	var expected_hull: int = ship.ship_data.hull - ship.get_total_damage() - 1
	var destroyed: bool = expected_hull <= 0
	var interrupted: bool = destroyed and (ship.has_active_ship_activation()
			or _ends_current_selection_turn(game_state, ship))
	var cleanup: Dictionary = application_result["destruction_cleanup"] \
			as Dictionary
	var next_controller: int = DestroyUnitCommand.next_controller_after_source(
			game_state, owner, [{"owner_player": owner,
				"ship_index": idx}]) if interrupted else -1
	if application_result["effect_id"] != payload["effect_id"] \
			or application_result["owner_player"] != owner \
			or application_result["ship_index"] != idx \
			or application_result["cards_added"] != 1 \
			or application_result["new_hull"] != expected_hull \
			or application_result["destroyed"] != destroyed \
			or application_result["ship_phase_turn_terminated"] != interrupted \
			or application_result["next_ship_phase_controller"] \
				!= next_controller \
			or (destroyed and not DestroyUnitCommand.prevalidate_source_cleanup(
					cleanup, ship.get_facedown_damage_count() + 1,
					interrupted, next_controller)) \
			or (not destroyed and not cleanup.is_empty()):
		return {}
	if not ledger.consume_hidden_draws(1) \
			or not ledger.increment_facedown(ship.passive_damage_key()):
		return {}
	return _finish_damage(game_state, ship, cleanup, true)


## Validates that the public effect source, ship, and draw are available.
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
	return _validate_damage_deck(game_state)


## Deals one facedown damage card, checks for destruction.
func execute(game_state: GameState) -> Dictionary:
	var owner: int = int(payload.get("owner_player", -1))
	var idx: int = int(payload.get("ship_index", -1))
	var ship: ShipInstance = game_state.get_ship(owner, idx)
	var card: DamageCard = game_state.damage_deck.draw_card()
	if card == null:
		return {}
	card.is_faceup = false
	ship.add_facedown_damage(card)
	return _finish_damage(game_state, ship)


func _finish_damage(game_state: GameState, ship: ShipInstance,
		projected_cleanup: Dictionary = {}, passive: bool = false) -> Dictionary:
	var owner: int = int(payload.get("owner_player", -1))
	var idx: int = int(payload.get("ship_index", -1))
	var was_active_ship: bool = ship.has_active_ship_activation()
	var ended_selection_turn: bool = _ends_current_selection_turn(
			game_state, ship)
	var new_hull: int = ship.ship_data.hull - ship.get_total_damage()
	var destroyed: bool = ship.is_destroyed()
	var ship_phase_turn_terminated: bool = destroyed \
			and (was_active_ship or ended_selection_turn)
	var cleanup: Dictionary = {}
	if destroyed:
		ship.mark_destroyed()
		if passive:
			if not DestroyUnitCommand.install_cleanup_in_source(game_state,
					owner, idx, ship_phase_turn_terminated, projected_cleanup):
				return {}
			cleanup = projected_cleanup
		else:
			cleanup = DestroyUnitCommand.cleanup_in_source(game_state,
					owner, idx, ship_phase_turn_terminated)
	var next_ship_phase_controller: int = int(cleanup.get(
			"next_ship_phase_controller", -1))
	return {
		"effect_id": payload.get("effect_id", ""),
		"owner_player": owner,
		"ship_index": idx,
		"cards_added": 1,
		"new_hull": new_hull,
		"destroyed": destroyed,
		"ship_phase_turn_terminated": ship_phase_turn_terminated,
		"next_ship_phase_controller": next_ship_phase_controller,
		"destruction_cleanup": cleanup,
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


func _validate_damage_deck(game_state: GameState) -> String:
	if game_state.passive_damage_ledger != null:
		return "" if game_state.passive_damage_ledger.can_consume_hidden_draws(1) \
				else "Passive damage ledger is empty."
	if game_state.damage_deck == null:
		return "Missing damage deck."
	if game_state.damage_deck.get_total_count() <= 0:
		return "Damage deck is empty."
	return ""


static func _result_valid(result: Dictionary) -> bool:
	var keys: Array[String] = ["effect_id", "owner_player", "ship_index",
		"cards_added", "new_hull", "destroyed",
		"ship_phase_turn_terminated", "next_ship_phase_controller",
		"destruction_cleanup"]
	if result.size() != keys.size():
		return false
	for key: String in keys:
		if not result.has(key):
			return false
	return typeof(result["effect_id"]) == TYPE_STRING \
			and str(result["effect_id"]) in VALID_EFFECTS \
			and typeof(result["owner_player"]) == TYPE_INT \
			and typeof(result["ship_index"]) == TYPE_INT \
			and typeof(result["cards_added"]) == TYPE_INT \
			and typeof(result["new_hull"]) == TYPE_INT \
			and typeof(result["destroyed"]) == TYPE_BOOL \
			and typeof(result["ship_phase_turn_terminated"]) == TYPE_BOOL \
			and typeof(result["next_ship_phase_controller"]) == TYPE_INT \
			and result["destruction_cleanup"] is Dictionary
