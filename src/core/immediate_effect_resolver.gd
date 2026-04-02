## ImmediateEffectResolver
##
## Resolves the immediate (one-shot) effects of faceup damage cards.
## These effects trigger the instant the card is dealt faceup, and most
## cards then flip facedown afterwards (losing their persistent status).
##
## Six damage cards have immediate effects:
##   1. Structural Damage  — suffer 1 extra facedown damage, then flip facedown
##   2. Projector Misaligned — reduce each hull zone's shields by 1, flip facedown
##   3. Life Support Failure — discard all command tokens, stays faceup (persistent)
##   4. Injured Crew — ship owner chooses and discards 1 defense token;
##      flip facedown
##   5. Shield Failure — opponent chooses up to 2 hull zones; each loses 1
##      shield; flip facedown
##   6. Comm Noise — opponent chooses: reduce speed by 1 OR choose a new
##      command on the top command dial; flip facedown
##
## For cards requiring player choices, call [method get_required_choice]
## first. If it returns a non-empty Dictionary, present the choice UI and
## then call [method resolve] with the player's selection.
##
## Choice descriptor format (returned by [method get_required_choice]):
##   "choice_type": String — one of the CHOICE_* constants
##   "chooser": String — "owner" or "opponent"
##   "multi_select": bool — true for Shield Failure (up to N zones)
##   "max_selections": int — max items selectable (Shield Failure = 2)
##   "card_title": String — display title for the modal
##   "effect_text": String — card effect text for the modal
##   "options": Array[Dictionary] — available choices
##   Each option: {"id": String, "label": String, "available": bool}
##
## Rules Reference: RRG "Damage Cards", p.4; individual card texts.
class_name ImmediateEffectResolver
extends RefCounted


## Choice types returned by [method get_required_choice].
const CHOICE_NONE: String = ""
const CHOICE_INJURED_CREW: String = "injured_crew"
const CHOICE_SHIELD_FAILURE: String = "shield_failure"
const CHOICE_COMM_NOISE: String = "comm_noise"

var _log: GameLogger = GameLogger.new("ImmediateEffectResolver")


## Returns true if the given card has an immediate effect.
static func is_immediate(card: DamageCard) -> bool:
	return card.timing == "immediate"


## Returns the choice descriptor for a card that requires player input.
## Returns an empty Dictionary if no choice is needed (auto-resolve).
##
## [param card] — the faceup damage card.
## [param ship] — the damaged ship.
func get_required_choice(card: DamageCard,
		ship: ShipInstance) -> Dictionary:
	match card.effect_id:
		"injured_crew":
			return _get_injured_crew_choices(ship, card)
		"shield_failure":
			return _get_shield_failure_choices(ship, card)
		"comm_noise":
			return _get_comm_noise_choices(ship, card)
		_:
			return {}


## Resolves the immediate effect of a faceup damage card.
## For auto-resolve cards, [param choice] can be empty.
## For choice cards, [param choice] must match the expected format:
##   Shield Failure: {"zones": Array[String]} (up to 2 zone IDs)
##   Injured Crew: {"id": String} (defense token index)
##   Comm Noise: {"id": String} (action identifier)
##
## [param card] — the faceup damage card to resolve.
## [param ship] — the ship that received the card.
## [param deck] — the shared DamageDeck (for Structural Damage's extra card).
## [param choice] — the player's selection (empty for auto-resolve cards).
## Returns true if the effect was resolved successfully.
func resolve(card: DamageCard, ship: ShipInstance,
		deck: DamageDeck, choice: Dictionary = {}) -> bool:
	match card.effect_id:
		"structural_damage":
			return _resolve_structural_damage(card, ship, deck)
		"projector_misaligned":
			return _resolve_projector_misaligned(card, ship)
		"life_support_failure":
			return _resolve_life_support_failure(card, ship)
		"injured_crew":
			return _resolve_injured_crew(card, ship, choice)
		"shield_failure":
			return _resolve_shield_failure(card, ship, choice)
		"comm_noise":
			return _resolve_comm_noise(card, ship, choice)
		_:
			_log.warn("Unknown immediate effect_id: '%s'" % card.effect_id)
			return false


# ---------------------------------------------------------------------------
# Auto-resolve effects
# ---------------------------------------------------------------------------


## Structural Damage: Suffer 1 additional facedown damage card, then flip
## this card facedown.
## Rules Reference: "Structural Damage" card text.
func _resolve_structural_damage(card: DamageCard,
		ship: ShipInstance, deck: DamageDeck) -> bool:
	# Deal 1 extra facedown damage.
	if deck:
		var extra: DamageCard = deck.draw_card()
		if extra:
			ship.add_facedown_damage(extra)
			_log.info("Structural Damage: dealt 1 extra facedown card.")
		else:
			_log.warn("Structural Damage: deck empty, no extra card dealt.")
	else:
		_log.warn("Structural Damage: no deck available.")
	# Flip this card facedown.
	card.flip_facedown()
	_move_to_facedown(card, ship)
	EventBus.damage_card_flipped.emit(ship, card, false)
	return true


## Projector Misaligned: Reduce each hull zone's shields by 1, then flip
## this card facedown.
## Rules Reference: "Projector Misaligned" card text.
func _resolve_projector_misaligned(card: DamageCard,
		ship: ShipInstance) -> bool:
	for zone: String in ship.current_shields.keys():
		var current: int = int(ship.current_shields.get(zone, 0))
		if current > 0:
			ship.reduce_shields(zone, 1)
			EventBus.ship_shields_changed.emit(
					ship, zone,
					int(ship.current_shields.get(zone, 0)))
	_log.info("Projector Misaligned: reduced all hull zone shields by 1.")
	card.flip_facedown()
	_move_to_facedown(card, ship)
	EventBus.damage_card_flipped.emit(ship, card, false)
	return true


## Life Support Failure: Discard all command tokens.
## This card stays FACEUP because it has a persistent effect:
## "You cannot have command tokens" (registered in DamageCardEffectFactory).
## Rules Reference: "Life Support Failure" card text.
func _resolve_life_support_failure(card: DamageCard,
		ship: ShipInstance) -> bool:
	if ship.command_tokens:
		ship.command_tokens.clear()
		EventBus.command_tokens_changed.emit(ship)
	_log.info("Life Support Failure: discarded all command tokens. " +
			"Card stays faceup (persistent).")
	# Card stays faceup — persistent effect registered separately.
	return true


# ---------------------------------------------------------------------------
# Choice-based effects
# ---------------------------------------------------------------------------


## Injured Crew: Ship owner chooses and discards 1 defense token.
## Card text: "Choose and discard 1 of your defense tokens.
## Then flip this card facedown."
## Rules Reference: "Injured Crew" card text.
func _resolve_injured_crew(card: DamageCard,
		ship: ShipInstance, choice: Dictionary) -> bool:
	var chosen_id: String = choice.get("id", "")
	if chosen_id == "":
		_log.warn("Injured Crew: no choice provided.")
		return false
	if not chosen_id.begins_with("discard_defense_"):
		_log.warn("Injured Crew: invalid choice id '%s'." % chosen_id)
		return false
	var idx_str: String = chosen_id.substr("discard_defense_".length())
	var idx: int = idx_str.to_int()
	if idx < 0 or idx >= ship.defense_tokens.size():
		_log.warn("Injured Crew: invalid token index %d." % idx)
		return false
	var state: int = int(ship.defense_tokens[idx].get("state", -1))
	if state == Constants.DefenseTokenState.DISCARDED:
		_log.warn("Injured Crew: token %d already discarded." % idx)
		return false
	ship.discard_defense_token(idx)
	EventBus.ship_defense_token_changed.emit(ship)
	_log.info("Injured Crew: discarded defense token at index %d." % idx)
	card.flip_facedown()
	_move_to_facedown(card, ship)
	EventBus.damage_card_flipped.emit(ship, card, false)
	return true


## Shield Failure: Opponent chooses up to 2 hull zones; each loses 1 shield.
## Card text: "Your opponent may choose up to 2 of your hull zones. Each of
## the chosen hull zones loses 1 shield. Then flip this card facedown."
## Rules Reference: DM-010–015; "Shield Failure" card text.
func _resolve_shield_failure(card: DamageCard,
		ship: ShipInstance, choice: Dictionary) -> bool:
	var zones: Array = choice.get("zones", [])
	# Validate: max 2 distinct zones.
	if zones.size() > 2:
		_log.warn("Shield Failure: more than 2 zones selected.")
		return false
	# Check for duplicate zones.
	if zones.size() == 2 and zones[0] == zones[1]:
		_log.warn("Shield Failure: duplicate zone '%s'." % str(zones[0]))
		return false
	for zone: Variant in zones:
		var zone_str: String = str(zone)
		var current: int = int(ship.current_shields.get(zone_str, 0))
		if current > 0:
			ship.reduce_shields(zone_str, 1)
			EventBus.ship_shields_changed.emit(
					ship, zone_str,
					int(ship.current_shields.get(zone_str, 0)))
		_log.info("Shield Failure: %s lost 1 shield (was %d)." %
				[zone_str, current])
	if zones.is_empty():
		_log.info("Shield Failure: opponent chose 0 zones.")
	card.flip_facedown()
	_move_to_facedown(card, ship)
	EventBus.damage_card_flipped.emit(ship, card, false)
	return true


## Comm Noise: Opponent chooses — reduce speed by 1 OR choose a new command
## on the top command dial.
## Card text: "Your opponent may either reduce your speed by 1 or choose a
## new command on your top command dial. Then flip this card facedown."
## Rules Reference: "Comm Noise" card text.
func _resolve_comm_noise(card: DamageCard,
		ship: ShipInstance, choice: Dictionary) -> bool:
	var chosen_id: String = choice.get("id", "")
	if chosen_id == "":
		_log.warn("Comm Noise: no choice provided.")
		return false
	if chosen_id == "reduce_speed":
		var old_speed: int = ship.current_speed
		ship.set_speed(ship.current_speed - 1)
		EventBus.ship_speed_changed.emit(ship, ship.current_speed)
		_log.info("Comm Noise: reduced speed %d → %d." % [
				old_speed, ship.current_speed])
	elif chosen_id.begins_with("change_dial_"):
		var cmd_str: String = chosen_id.substr("change_dial_".length())
		var cmd_type: int = cmd_str.to_int()
		if ship.command_dial_stack:
			ship.command_dial_stack.replace_top_command(cmd_type)
			EventBus.command_dials_changed.emit(ship)
			_log.info("Comm Noise: changed top dial to %s." %
					_command_type_name(cmd_type))
		else:
			_log.warn("Comm Noise: no command dial stack.")
	else:
		_log.warn("Comm Noise: unknown choice '%s'." % chosen_id)
		return false
	card.flip_facedown()
	_move_to_facedown(card, ship)
	EventBus.damage_card_flipped.emit(ship, card, false)
	return true


# ---------------------------------------------------------------------------
# Choice descriptors
# ---------------------------------------------------------------------------


## Returns choice options for Injured Crew.
## The ship's OWNER chooses and discards 1 defense token.
## Card text: "Choose and discard 1 of your defense tokens."
func _get_injured_crew_choices(
		ship: ShipInstance, card: DamageCard) -> Dictionary:
	var options: Array[Dictionary] = []
	# List all non-discarded defense tokens (ready or exhausted).
	for i: int in range(ship.defense_tokens.size()):
		var dt: Dictionary = ship.defense_tokens[i]
		var state: int = int(dt.get("state", -1))
		if state == Constants.DefenseTokenState.DISCARDED:
			continue
		var dt_name: String = _defense_token_name(int(dt.get("type", -1)))
		var state_label: String = "ready"
		if state == Constants.DefenseTokenState.EXHAUSTED:
			state_label = "exhausted"
		options.append({
			"id": "discard_defense_%d" % i,
			"label": "Discard %s (%s)" % [dt_name, state_label],
			"available": true,
		})
	if options.is_empty():
		return {}
	return {
		"choice_type": CHOICE_INJURED_CREW,
		"chooser": "owner",
		"multi_select": false,
		"max_selections": 1,
		"card_title": card.title,
		"effect_text": card.effect_text,
		"options": options,
	}


## Returns choice options for Shield Failure.
## The OPPONENT chooses up to 2 hull zones.
## Card text: "Your opponent may choose up to 2 of your hull zones."
func _get_shield_failure_choices(
		ship: ShipInstance, card: DamageCard) -> Dictionary:
	var options: Array[Dictionary] = []
	for zone: String in ship.current_shields.keys():
		var current: int = int(ship.current_shields.get(zone, 0))
		options.append({
			"id": zone,
			"label": "%s (%d shields)" % [zone, current],
			"available": true,
		})
	if options.is_empty():
		return {}
	return {
		"choice_type": CHOICE_SHIELD_FAILURE,
		"chooser": "opponent",
		"multi_select": true,
		"max_selections": 2,
		"card_title": card.title,
		"effect_text": card.effect_text,
		"options": options,
	}


## Returns choice options for Comm Noise.
## The OPPONENT chooses: reduce speed by 1 OR choose a new command on the
## top command dial.
## Card text: "Your opponent may either reduce your speed by 1 or choose a
## new command on your top command dial."
func _get_comm_noise_choices(
		ship: ShipInstance, card: DamageCard) -> Dictionary:
	var options: Array[Dictionary] = []
	# Option A: reduce speed by 1 (available if speed > 0).
	options.append({
		"id": "reduce_speed",
		"label": "Reduce speed by 1 (current: %d)" % ship.current_speed,
		"available": ship.current_speed > 0,
	})
	# Option B: choose a new command on top dial (one sub-option per command).
	if ship.command_dial_stack and \
			ship.command_dial_stack.get_hidden_count() > 0:
		for cmd_type: int in [
				Constants.CommandType.NAVIGATE,
				Constants.CommandType.SQUADRON,
				Constants.CommandType.CONCENTRATE_FIRE,
				Constants.CommandType.REPAIR]:
			options.append({
				"id": "change_dial_%d" % cmd_type,
				"label": "Change top dial to %s" % _command_type_name(cmd_type),
				"available": true,
			})
	if options.is_empty():
		return {}
	# Check if ANY option is available.
	var has_available: bool = false
	for opt: Dictionary in options:
		if opt.get("available", false):
			has_available = true
			break
	if not has_available:
		return {}
	return {
		"choice_type": CHOICE_COMM_NOISE,
		"chooser": "opponent",
		"multi_select": false,
		"max_selections": 1,
		"card_title": card.title,
		"effect_text": card.effect_text,
		"options": options,
	}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


## Moves a card from faceup_damage to facedown_damage on the ship.
func _move_to_facedown(card: DamageCard, ship: ShipInstance) -> void:
	var idx: int = ship.faceup_damage.find(card)
	if idx >= 0:
		ship.faceup_damage.remove_at(idx)
		ship.facedown_damage.append(card)


## Returns a human-readable name for a CommandType integer.
static func _command_type_name(cmd: int) -> String:
	match cmd:
		Constants.CommandType.NAVIGATE:
			return "Navigate"
		Constants.CommandType.SQUADRON:
			return "Squadron"
		Constants.CommandType.REPAIR:
			return "Repair"
		Constants.CommandType.CONCENTRATE_FIRE:
			return "Concentrate Fire"
		_:
			return "Unknown(%d)" % cmd


## Returns a human-readable name for a DefenseToken integer.
static func _defense_token_name(dt_type: int) -> String:
	match dt_type:
		Constants.DefenseToken.EVADE:
			return "Evade"
		Constants.DefenseToken.BRACE:
			return "Brace"
		Constants.DefenseToken.REDIRECT:
			return "Redirect"
		Constants.DefenseToken.SCATTER:
			return "Scatter"
		Constants.DefenseToken.CONTAIN:
			return "Contain"
		Constants.DefenseToken.SALVO:
			return "Salvo"
		_:
			return "Unknown(%d)" % dt_type
