## ResolveImmediateEffectCommand
##
## Routes all immediate (one-shot) damage card effect mutations through the
## command system for replay and multiplayer safety.
##
## Six damage cards have immediate effects; each is identified by its
## [code]effect_id[/code] in the payload:
##   [code]structural_damage[/code]  — deal 1 extra facedown, flip facedown
##   [code]projector_misaligned[/code] — strip shields from a zone, flip facedown
##   [code]life_support_failure[/code] — discard all command tokens; persistent
##      token-gain restriction is enforced by RuleRegistry while faceup
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


func application_contract_id() -> String:
	return "resolve_immediate_effect"


func project_application_result(_authority_result: Dictionary,
		_viewer_player: int) -> Dictionary:
	return {}


func execute_with_application_result(game_state: GameState,
		application_result: Dictionary) -> Dictionary:
	if not application_result.is_empty():
		return {}
	return execute(game_state)


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
	var ship: ShipInstance = _find_ship(game_state)
	if ship == null:
		return "Ship not found."
	var card_idx: int = int(payload.get("card_index", -1))
	if card_idx < 0 or card_idx >= ship.faceup_damage.size():
		return "Invalid card_index %d (faceup size %d)." % [
				card_idx, ship.faceup_damage.size()]
	var card: DamageCard = ship.faceup_damage[card_idx]
	var effect_id: String = card.effect_id
	if effect_id not in VALID_EFFECTS:
		return "Unknown public immediate effect."
	if effect_id == "structural_damage" \
			and not _has_available_hidden_draw(game_state):
		return "Structural Damage requires an available damage card."
	return _validate_choice(effect_id, ship)


## Validates the choice dictionary for effects that require one.
func _validate_choice(effect_id: String,
		ship: ShipInstance) -> String:
	if not payload.get("choice") is Dictionary:
		return "Immediate effect choice must be a dictionary."
	var choice: Dictionary = payload.get("choice", {}) as Dictionary
	match effect_id:
		"structural_damage", "life_support_failure":
			return "" if choice.is_empty() else "This effect accepts no choice."
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
	var maximum: int = 0
	var tied: Array[String] = []
	for zone_value: Variant in ship.current_shields:
		var zone_name: String = str(zone_value)
		var value: int = int(ship.current_shields[zone_value])
		if value > maximum:
			maximum = value
			tied = [zone_name]
		elif value == maximum and value > 0:
			tied.append(zone_name)
	if tied.size() <= 1:
		return "" if choice.is_empty() else "Projector choice is not applicable."
	if choice.size() != 1 or typeof(choice.get("id")) != TYPE_STRING:
		return "Projector choice has an invalid schema."
	if not chosen_id.begins_with("zone_"):
		return "Invalid projector choice id: '%s'." % chosen_id
	var zone: String = chosen_id.substr(5)
	if zone not in tied:
		return "Invalid projector zone: '%s'." % zone
	return ""


func _validate_injured_crew_choice(choice: Dictionary,
		ship: ShipInstance) -> String:
	var chosen_id: String = str(choice.get("id", ""))
	if choice.size() != 1 or typeof(choice.get("id")) != TYPE_STRING:
		return "Injured Crew choice has an invalid schema."
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
		ship: ShipInstance) -> String:
	if choice.size() != 1 or not choice.get("zones") is Array:
		return "Shield Failure choice has an invalid schema."
	var zones: Array = choice.get("zones", []) as Array
	if zones.size() > 2:
		return "Shield Failure: more than 2 zones selected."
	if zones.size() == 2 and str(zones[0]) == str(zones[1]):
		return "Shield Failure: duplicate zone '%s'." % str(zones[0])
	for zone: Variant in zones:
		if typeof(zone) != TYPE_STRING or not ship.current_shields.has(str(zone)):
			return "Shield Failure contains an invalid zone."
	return ""


func _validate_comm_noise_choice(choice: Dictionary,
		ship: ShipInstance) -> String:
	var chosen_id: String = str(choice.get("id", ""))
	if choice.size() != 1 or typeof(choice.get("id")) != TYPE_STRING:
		return "Comm Noise choice has an invalid schema."
	if chosen_id.is_empty():
		return "Comm Noise requires a choice."
	if chosen_id == "reduce_speed":
		return "" if ship.current_speed > 0 else "Speed cannot be reduced."
	if chosen_id.begins_with("change_dial_"):
		if ship.command_dial_stack == null \
				or ship.command_dial_stack.get_hidden_count() <= 0:
			return "No hidden top dial is available."
		var suffix: String = chosen_id.substr("change_dial_".length())
		if not suffix.is_valid_int() or int(suffix) not in [
				Constants.CommandType.NAVIGATE, Constants.CommandType.SQUADRON,
				Constants.CommandType.CONCENTRATE_FIRE, Constants.CommandType.REPAIR]:
			return "Invalid command dial choice."
		return ""
	return "Unknown Comm Noise choice: '%s'." % chosen_id


# ---------------------------------------------------------------------------
# Execute
# ---------------------------------------------------------------------------

## Executes the immediate effect — mutates [GameState]-owned objects.
func execute(game_state: GameState) -> Dictionary:
	var ship: ShipInstance = _find_ship(game_state)
	var card_idx: int = payload.get("card_index", -1) as int
	var card: DamageCard = ship.faceup_damage[card_idx]
	var effect_id: String = card.effect_id
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
	var extra: DamageCard = null
	if game_state.passive_damage_ledger != null:
		if not game_state.passive_damage_ledger.consume_hidden_draws(1) \
				or not game_state.passive_damage_ledger.increment_facedown(
						ship.passive_damage_key()):
			return {}
	else:
		extra = game_state.damage_deck.draw_card()
		if extra == null:
			return {}
		extra.is_faceup = false
		ship.add_facedown_damage(extra)
	card.flip_facedown()
	_move_to_facedown(card, ship)
	if ship.is_destroyed():
		ship.mark_destroyed()
	return {
		"extra_dealt": true,
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
		"shield_changes": shield_changes,
	}


## Comm Noise: reduce speed by 1 OR change top dial, flip card facedown.
func _execute_comm_noise(ship: ShipInstance,
		card: DamageCard, choice: Dictionary) -> Dictionary:
	var chosen_id: String = str(choice.get("id", ""))
	var result: Dictionary = {}
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
		if ship.is_passive_damage_bound():
			ship.increment_passive_facedown_damage()
		else:
			ship.facedown_damage.append(card)


func _has_available_hidden_draw(game_state: GameState) -> bool:
	if game_state.passive_damage_ledger != null:
		return game_state.passive_damage_ledger.can_consume_hidden_draws(1)
	return game_state.damage_deck != null \
			and game_state.damage_deck.get_total_count() > 0


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
