## ResolveImmediateEffectCommand
##
## Routes all immediate (one-shot) damage card effect mutations through the
## command system for replay and multiplayer safety.
##
## Six damage cards have immediate effects; each is identified by its
## [code]effect_id[/code] in the payload:
##   [code]structural_damage[/code]  — deal 1 extra facedown, flip facedown
##   [code]projector_misaligned[/code] — strip shields from a zone, flip facedown
##   [code]life_support_failure[/code] — discard all command tokens (stays faceup)
##   [code]injured_crew[/code] — discard 1 defense token, flip facedown
##   [code]shield_failure[/code] — reduce shields in up to 2 zones, flip facedown
##   [code]comm_noise[/code] — reduce speed OR change top dial, flip facedown
##
## The presentation layer gathers any required player choices before
## submitting this command.  The command owns the atomic GameState mutation;
## EventBus signals are emitted by the caller after execute() returns.
##
## Payload:
##   [code]effect_id[/code]       — String — damage card effect identifier
##   [code]owner_player[/code]    — int — player index owning the ship
##   [code]ship_index[/code]      — int — index in player's ships array
##   [code]card_index[/code]      — int — index in ship.faceup_damage
##   [code]choice[/code]          — Dictionary — player selection (may be empty)
##   [code]extra_card_data[/code] — Dictionary — (structural_damage only)
##                                   serialized DamageCard for the extra draw
##
## Rules Reference: RRG "Damage Cards", p.4; DM-005, DM-010–015.
class_name ResolveImmediateEffectCommand
extends GameCommand


## Valid immediate effect ids.
const VALID_EFFECTS: Array[String] = [
	"structural_damage",
	"projector_misaligned",
	"life_support_failure",
	"injured_crew",
	"shield_failure",
	"comm_noise",
]


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("resolve_immediate_effect", func(
			player: int, pl: Dictionary) -> GameCommand:
		return ResolveImmediateEffectCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "resolve_immediate_effect", p_payload)


# ---------------------------------------------------------------------------
# Validate
# ---------------------------------------------------------------------------

## Validates that the immediate effect resolution is legal.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	# Immediate effects fire during attacks (Ship Phase) or debug (any).
	if game_state.current_phase != Constants.GamePhase.SHIP \
			and game_state.current_phase != Constants.GamePhase.SQUADRON:
		return "Not in Ship or Squadron Phase."
	var effect_id: String = payload.get("effect_id", "") as String
	if effect_id not in VALID_EFFECTS:
		return "Unknown effect_id: '%s'." % effect_id
	var ship: ShipInstance = _find_ship(game_state)
	if ship == null:
		return "Ship not found."
	var card_idx: int = payload.get("card_index", -1) as int
	if card_idx < 0 or card_idx >= ship.faceup_damage.size():
		return "Invalid card_index %d (faceup size %d)." % [
				card_idx, ship.faceup_damage.size()]
	var card: DamageCard = ship.faceup_damage[card_idx]
	if card.effect_id != effect_id:
		return "Card at index %d has effect '%s', expected '%s'." % [
				card_idx, card.effect_id, effect_id]
	return _validate_choice(effect_id, ship)


## Validates the choice dictionary for effects that require one.
func _validate_choice(effect_id: String,
		ship: ShipInstance) -> String:
	var choice: Dictionary = payload.get("choice", {})
	match effect_id:
		"structural_damage", "life_support_failure":
			return ""  # No choice needed.
		"projector_misaligned":
			return _validate_projector_choice(choice, ship)
		"injured_crew":
			return _validate_injured_crew_choice(choice, ship)
		"shield_failure":
			return _validate_shield_failure_choice(choice, ship)
		"comm_noise":
			return _validate_comm_noise_choice(choice, ship)
		_:
			return "Unknown effect_id: '%s'." % effect_id


func _validate_projector_choice(choice: Dictionary,
		ship: ShipInstance) -> String:
	var chosen_id: String = str(choice.get("id", ""))
	if chosen_id.is_empty():
		return ""  # Auto-resolve (unique max).
	if not chosen_id.begins_with("zone_"):
		return "Invalid projector choice id: '%s'." % chosen_id
	var zone: String = chosen_id.substr(5)
	if not ship.current_shields.has(zone):
		return "Invalid projector zone: '%s'." % zone
	return ""


func _validate_injured_crew_choice(choice: Dictionary,
		ship: ShipInstance) -> String:
	var chosen_id: String = str(choice.get("id", ""))
	if chosen_id.is_empty():
		return "Injured Crew requires a choice."
	if not chosen_id.begins_with("discard_defense_"):
		return "Invalid injured crew choice id: '%s'." % chosen_id
	var idx: int = chosen_id.substr("discard_defense_".length()).to_int()
	if idx < 0 or idx >= ship.defense_tokens.size():
		return "Invalid defense token index %d." % idx
	var state: int = int(ship.defense_tokens[idx].get("state", -1))
	if state == Constants.DefenseTokenState.DISCARDED:
		return "Token %d already discarded." % idx
	return ""


func _validate_shield_failure_choice(choice: Dictionary,
		_ship: ShipInstance) -> String:
	var zones: Array = choice.get("zones", [])
	if zones.size() > 2:
		return "Shield Failure: more than 2 zones selected."
	if zones.size() == 2 and str(zones[0]) == str(zones[1]):
		return "Shield Failure: duplicate zone '%s'." % str(zones[0])
	return ""


func _validate_comm_noise_choice(choice: Dictionary,
		ship: ShipInstance) -> String:
	var chosen_id: String = str(choice.get("id", ""))
	if chosen_id.is_empty():
		return "Comm Noise requires a choice."
	if chosen_id == "reduce_speed":
		return ""
	if chosen_id.begins_with("change_dial_"):
		return ""
	return "Unknown Comm Noise choice: '%s'." % chosen_id


# ---------------------------------------------------------------------------
# Execute
# ---------------------------------------------------------------------------

## Executes the immediate effect — mutates [GameState]-owned objects.
func execute(game_state: GameState) -> Dictionary:
	var effect_id: String = payload.get("effect_id", "") as String
	var ship: ShipInstance = _find_ship(game_state)
	var card_idx: int = payload.get("card_index", -1) as int
	var card: DamageCard = ship.faceup_damage[card_idx]
	var choice: Dictionary = payload.get("choice", {})
	match effect_id:
		"structural_damage":
			return _execute_structural_damage(game_state, ship, card)
		"projector_misaligned":
			return _execute_projector_misaligned(ship, card, choice)
		"life_support_failure":
			return _execute_life_support_failure(ship, card)
		"injured_crew":
			return _execute_injured_crew(ship, card, choice)
		"shield_failure":
			return _execute_shield_failure(ship, card, choice)
		"comm_noise":
			return _execute_comm_noise(ship, card, choice)
		_:
			return {"error": "Unknown effect_id."}


# ---------------------------------------------------------------------------
# Execute helpers
# ---------------------------------------------------------------------------

## Structural Damage: deal 1 extra facedown card, flip this card facedown.
func _execute_structural_damage(game_state: GameState,
		ship: ShipInstance, card: DamageCard) -> Dictionary:
	var extra_data: Dictionary = payload.get("extra_card_data", {})
	if not extra_data.is_empty():
		var extra: DamageCard = DamageCard.deserialize(extra_data)
		extra.is_faceup = false
		ship.add_facedown_damage(extra)
	card.flip_facedown()
	_move_to_facedown(card, ship)
	return {
		"effect_id": "structural_damage",
		"extra_dealt": not extra_data.is_empty(),
		"new_hull": ship.ship_data.hull - ship.get_total_damage(),
	}


## Projector Misaligned: strip all shields from the zone with the most.
func _execute_projector_misaligned(ship: ShipInstance,
		card: DamageCard, choice: Dictionary) -> Dictionary:
	var zone: String = _pick_projector_zone(ship, choice)
	var shields_lost: int = 0
	if not zone.is_empty():
		shields_lost = int(ship.current_shields.get(zone, 0))
		if shields_lost > 0:
			ship.reduce_shields(zone, shields_lost)
	card.flip_facedown()
	_move_to_facedown(card, ship)
	return {
		"effect_id": "projector_misaligned",
		"zone": zone,
		"shields_lost": shields_lost,
		"new_shields": int(ship.current_shields.get(zone, 0)),
	}


## Life Support Failure: discard all command tokens. Card stays faceup.
func _execute_life_support_failure(ship: ShipInstance,
		_card: DamageCard) -> Dictionary:
	var had_tokens: bool = false
	if ship.command_tokens:
		had_tokens = ship.command_tokens.get_token_count() > 0
		ship.command_tokens.clear()
	return {
		"effect_id": "life_support_failure",
		"tokens_cleared": had_tokens,
		"stays_faceup": true,
	}


## Injured Crew: discard 1 defense token, flip card facedown.
func _execute_injured_crew(ship: ShipInstance,
		card: DamageCard, choice: Dictionary) -> Dictionary:
	var chosen_id: String = str(choice.get("id", ""))
	var idx: int = chosen_id.substr("discard_defense_".length()).to_int()
	ship.discard_defense_token(idx)
	card.flip_facedown()
	_move_to_facedown(card, ship)
	return {
		"effect_id": "injured_crew",
		"token_index": idx,
	}


## Shield Failure: reduce shields in up to 2 zones, flip card facedown.
func _execute_shield_failure(ship: ShipInstance,
		card: DamageCard, choice: Dictionary) -> Dictionary:
	var zones: Array = choice.get("zones", [])
	var shield_changes: Array[Dictionary] = []
	for zone_var: Variant in zones:
		var zone: String = str(zone_var)
		var before: int = int(ship.current_shields.get(zone, 0))
		if before > 0:
			ship.reduce_shields(zone, 1)
		shield_changes.append({
			"zone": zone,
			"new_shields": int(ship.current_shields.get(zone, 0)),
		})
	card.flip_facedown()
	_move_to_facedown(card, ship)
	return {
		"effect_id": "shield_failure",
		"shield_changes": shield_changes,
	}


## Comm Noise: reduce speed by 1 OR change top dial, flip card facedown.
func _execute_comm_noise(ship: ShipInstance,
		card: DamageCard, choice: Dictionary) -> Dictionary:
	var chosen_id: String = str(choice.get("id", ""))
	var result: Dictionary = {"effect_id": "comm_noise"}
	if chosen_id == "reduce_speed":
		ship.set_speed(ship.current_speed - 1)
		result["action"] = "reduce_speed"
		result["new_speed"] = ship.current_speed
	elif chosen_id.begins_with("change_dial_"):
		var cmd_type: int = chosen_id.substr(
				"change_dial_".length()).to_int()
		if ship.command_dial_stack:
			ship.command_dial_stack.replace_top_command(cmd_type)
		result["action"] = "change_dial"
		result["new_command"] = cmd_type
	card.flip_facedown()
	_move_to_facedown(card, ship)
	return result


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Finds the ship referenced by payload's owner_player + ship_index.
func _find_ship(game_state: GameState) -> ShipInstance:
	var owner: int = payload.get("owner_player", -1) as int
	var idx: int = payload.get("ship_index", -1) as int
	if owner < 0 or owner >= game_state.player_states.size():
		return null
	var ps: PlayerState = game_state.get_player_state(owner)
	if ps == null or idx < 0 or idx >= ps.ships.size():
		return null
	return ps.ships[idx]


## Moves a card from faceup_damage to facedown_damage on the ship.
func _move_to_facedown(card: DamageCard,
		ship: ShipInstance) -> void:
	var idx: int = ship.faceup_damage.find(card)
	if idx >= 0:
		ship.faceup_damage.remove_at(idx)
		ship.facedown_damage.append(card)


## Determines which zone Projector Misaligned strips.
func _pick_projector_zone(ship: ShipInstance,
		choice: Dictionary) -> String:
	var chosen_id: String = str(choice.get("id", ""))
	if chosen_id.begins_with("zone_"):
		return chosen_id.substr(5)
	var best_zone: String = ""
	var best_val: int = 0
	for zone: String in ship.current_shields.keys():
		var val: int = int(ship.current_shields.get(zone, 0))
		if val > best_val:
			best_val = val
			best_zone = zone
	return best_zone
