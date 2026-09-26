## DestroyUnitCommand
##
## Handles the game-state cleanup when a ship is destroyed:
##
##   1. Unregisters all persistent effects owned by the ship.
##   2. Clears all damage cards (faceup + facedown) from the ship.
##   3. Returns cleared cards to the damage deck discard pile.
##
## The actual [method ShipInstance.mark_destroyed] call and the visual
## destruction (fade-out, EventBus signal) remain in the presentation
## layer — this command only covers mutable GameState changes.
##
## Payload:
##   - "owner_player": int — player index (0 or 1)
##   - "ship_index":   int — index into PlayerState.ships
##   - "terminate_ship_phase_turn": bool — the destroyed ship owned the
##     interrupted Ship Phase activation
##
## Rules Reference: "Winning and Losing", RRG p.21; DM-030 —
## destroyed ships return damage cards to the discard pile.
class_name DestroyUnitCommand
extends GameCommand


const FLOW_SPEC_SCRIPT: GDScript = preload("res://src/core/state/flow_spec.gd")


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("destroy_unit",
			func(player: int, pl: Dictionary) -> GameCommand:
		return DestroyUnitCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "destroy_unit", p_payload)


func application_contract_id() -> String:
	return "destroy_unit"


func project_application_result(authority_result: Dictionary,
		_viewer_player: int) -> Dictionary:
	return {
		"facedown_discards": authority_result.get(
				"facedown_discards", []).duplicate(true),
		"ship_phase_turn_terminated": bool(authority_result.get(
				"ship_phase_turn_terminated", false)),
		"next_ship_phase_controller": int(authority_result.get(
				"next_ship_phase_controller", -1)),
	}


func execute_with_application_result(game_state: GameState,
		application_result: Dictionary) -> Dictionary:
	if application_result.size() != 3 \
			or not application_result.get("facedown_discards") is Array \
			or typeof(application_result.get(
					"ship_phase_turn_terminated")) != TYPE_BOOL \
			or typeof(application_result.get(
					"next_ship_phase_controller")) != TYPE_INT:
		return {}
	var owner: int = int(payload["owner_player"])
	var idx: int = int(payload["ship_index"])
	var ship: ShipInstance = game_state.get_ship(owner, idx)
	var raw_cards: Array = application_result["facedown_discards"] as Array
	if raw_cards.size() != ship.get_facedown_damage_count():
		return {}
	var expected_transition: Dictionary = _derive_ship_phase_return(
			game_state, owner)
	if bool(application_result["ship_phase_turn_terminated"]) \
			!= bool(expected_transition["ship_phase_turn_terminated"]) \
			or int(application_result["next_ship_phase_controller"]) \
			!= int(expected_transition["next_ship_phase_controller"]):
		return {}
	var cards: Array[DamageCard] = []
	for raw: Variant in raw_cards:
		if not raw is Dictionary:
			return {}
		var card: DamageCard = PassiveDamageLedger.deserialize_public_card(
				raw as Dictionary)
		if card == null or card.is_faceup:
			return {}
		cards.append(card)
	var ledger: PassiveDamageLedger = game_state.passive_damage_ledger
	var facedown_count: int = ledger.clear_facedown(ship.passive_damage_key())
	if facedown_count < 0:
		return {}
	var faceup: Array = ship.faceup_damage.duplicate()
	ship.faceup_damage.clear()
	for public_card: DamageCard in faceup:
		ledger.append_public_discard(public_card)
	for public_card: DamageCard in cards:
		ledger.append_public_discard(public_card)
	_apply_ship_phase_return(game_state, expected_transition)
	return {
		"cards_returned": faceup.size() + facedown_count,
		"data_key": ship.data_key,
		"facedown_discards": application_result["facedown_discards"].duplicate(true),
		"ship_phase_turn_terminated": expected_transition[
				"ship_phase_turn_terminated"],
		"next_ship_phase_controller": expected_transition[
				"next_ship_phase_controller"],
	}


## Validates that the target ship exists.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if not payload.has("owner_player"):
		return "Missing 'owner_player' in payload."
	if not payload.has("ship_index"):
		return "Missing 'ship_index' in payload."
	if payload.has("terminate_ship_phase_turn") \
			and typeof(payload["terminate_ship_phase_turn"]) != TYPE_BOOL:
		return "Invalid 'terminate_ship_phase_turn' in payload."
	var owner: int = int(payload["owner_player"])
	var idx: int = int(payload["ship_index"])
	var ship: ShipInstance = game_state.get_ship(owner, idx)
	if ship == null:
		return "Ship not found: player %d, index %d." % [owner, idx]
	if not ship.is_destroyed():
		return "Ship is not destroyed."
	if ship.get_total_damage() <= 0:
		# An out-of-play Maneuver destroys a healthy ship. Its originating
		# transaction records the interrupted activation, so the existing
		# destruction owner must still perform the exceptional phase return.
		# Once that return is installed, the same cleanup is stale.
		var flow: InteractionFlow = game_state.interaction_flow
		var awaiting_selection: bool = flow != null \
				and flow.flow_type == Constants.InteractionFlow.SHIP_ACTIVATION \
				and flow.step_id == Constants.InteractionStep.WAIT_FOR_SHIP_SELECT
		if not bool(payload.get("terminate_ship_phase_turn", false)) \
				or game_state.current_phase != Constants.GamePhase.SHIP \
				or awaiting_selection:
			return "Destroyed ship is already cleaned."
	return ""


## Performs destruction cleanup on the target ship and, when declared by the
## originating authority transaction, returns from its interrupted activation.
func execute(game_state: GameState) -> Dictionary:
	var owner: int = int(payload["owner_player"])
	var idx: int = int(payload["ship_index"])
	var ship: ShipInstance = game_state.get_ship(owner, idx)

	var facedown_discards: Array[Dictionary] = []
	for raw_card: Variant in ship.facedown_damage:
		facedown_discards.append((raw_card as DamageCard).serialize())
	# Clear damage cards and return to discard pile.
	var cards: Array = ship.clear_all_damage_cards()
	if game_state.damage_deck:
		for card: Variant in cards:
			game_state.damage_deck.discard(card)
	var transition: Dictionary = _derive_ship_phase_return(game_state, owner)
	_apply_ship_phase_return(game_state, transition)

	return {
		"cards_returned": cards.size(),
		"data_key": ship.data_key,
		"facedown_discards": facedown_discards,
		"ship_phase_turn_terminated": transition[
				"ship_phase_turn_terminated"],
		"next_ship_phase_controller": transition[
				"next_ship_phase_controller"],
	}


## Performs the purpose-specific exceptional return after cleanup of a ship
## that owned the interrupted Ship Phase activation. The originating damage
## transaction records that fact in this command; this command reuses the
## ordinary Ship Phase selection boundary and creates no durable route state.
func _derive_ship_phase_return(game_state: GameState,
		ending_player: int) -> Dictionary:
	if not bool(payload.get("terminate_ship_phase_turn", false)):
		return {
			"ship_phase_turn_terminated": false,
			"next_ship_phase_controller": -1,
		}
	var next_player: int = _next_ship_phase_controller(
			game_state, ending_player)
	return {
		"ship_phase_turn_terminated": true,
		"next_ship_phase_controller": next_player,
	}


func _apply_ship_phase_return(game_state: GameState,
		transition: Dictionary) -> void:
	if not bool(transition["ship_phase_turn_terminated"]):
		return
	var next_player: int = int(transition["next_ship_phase_controller"])
	game_state.interaction_flow = FLOW_SPEC_SCRIPT.make_interaction_flow(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT,
			game_state,
			{"active_player": next_player},
			Constants.Visibility.ALL)


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
			if not candidate.is_destroyed() \
					and not candidate.activated_this_round:
				return true
	return false
