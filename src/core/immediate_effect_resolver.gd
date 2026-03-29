## ImmediateEffectResolver
##
## Resolves the immediate (one-shot) effects of faceup damage cards.
## These effects trigger the instant the card is dealt faceup, and most
## cards then flip facedown afterwards (losing their persistent status).
##
## Six damage cards have immediate effects:
##   1. Structural Damage  — suffer 1 extra facedown damage, then flip facedown
##   2. Projector Misaligned — reduce each hull zone's shields by 1, flip facedown
##   3. Life Support Failure — discard all command tokens, flip facedown
##   4. Injured Crew — opponent chooses: discard 1 command token OR exhaust 1
##      defense token; flip facedown
##   5. Shield Failure — opponent chooses a hull zone; all shields in it → 0;
##      flip facedown
##   6. Comm Noise — opponent chooses: discard top command dial OR discard 1
##      command token; flip facedown
##
## For cards requiring opponent choices, call [method get_required_choice]
## first. If it returns a non-empty Dictionary, present the choice UI and
## then call [method resolve] with the player's selection.
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


## Returns the choice descriptor for a card that requires opponent input.
## Returns an empty Dictionary if no choice is needed (auto-resolve).
##
## Dictionary format:
##   "choice_type": String — one of the CHOICE_* constants
##   "options": Array[Dictionary] — available choices
##   Each option: {"id": String, "label": String, "available": bool}
##
## [param card] — the faceup damage card.
## [param ship] — the damaged ship.
func get_required_choice(card: DamageCard,
		ship: ShipInstance) -> Dictionary:
	match card.effect_id:
		"injured_crew":
			return _get_injured_crew_choices(ship)
		"shield_failure":
			return _get_shield_failure_choices(ship)
		"comm_noise":
			return _get_comm_noise_choices(ship)
		_:
			return {}


## Resolves the immediate effect of a faceup damage card.
## For auto-resolve cards, [param choice] can be empty.
## For choice cards, [param choice] must contain {"id": String} matching
## one of the options from [method get_required_choice].
##
## [param card] — the faceup damage card to resolve.
## [param ship] — the ship that received the card.
## [param deck] — the shared DamageDeck (for Structural Damage's extra card).
## [param choice] — the opponent's selection (empty for auto-resolve cards).
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


## Injured Crew: Opponent chooses — discard 1 command token OR exhaust 1
## non-exhausted defense token.
## Rules Reference: "Injured Crew" card text.
func _resolve_injured_crew(card: DamageCard,
		ship: ShipInstance, choice: Dictionary) -> bool:
	var chosen_id: String = choice.get("id", "")
	if chosen_id == "":
		_log.warn("Injured Crew: no choice provided.")
		return false
	if chosen_id.begins_with("discard_token_"):
		# Discard a specific command token.
		var cmd_str: String = chosen_id.substr("discard_token_".length())
		var cmd_type: int = cmd_str.to_int()
		if ship.command_tokens:
			ship.command_tokens.remove_token(
					cmd_type as Constants.CommandType)
			EventBus.command_tokens_changed.emit(ship)
			_log.info("Injured Crew: discarded command token %s." % cmd_str)
	elif chosen_id.begins_with("exhaust_defense_"):
		# Exhaust a specific defense token by index.
		var idx_str: String = chosen_id.substr("exhaust_defense_".length())
		var idx: int = idx_str.to_int()
		ship.exhaust_defense_token(idx)
		EventBus.ship_defense_token_changed.emit(ship)
		_log.info("Injured Crew: exhausted defense token at index %d." % idx)
	else:
		_log.warn("Injured Crew: unknown choice id '%s'." % chosen_id)
		return false
	card.flip_facedown()
	_move_to_facedown(card, ship)
	EventBus.damage_card_flipped.emit(ship, card, false)
	return true


## Shield Failure: Opponent chooses a hull zone; all shields in it become 0.
## Rules Reference: "Shield Failure" card text.
func _resolve_shield_failure(card: DamageCard,
		ship: ShipInstance, choice: Dictionary) -> bool:
	var zone: String = choice.get("id", "")
	if zone == "":
		_log.warn("Shield Failure: no zone chosen.")
		return false
	var current: int = int(ship.current_shields.get(zone, 0))
	if current > 0:
		ship.reduce_shields(zone, current)
		EventBus.ship_shields_changed.emit(
				ship, zone,
				int(ship.current_shields.get(zone, 0)))
	_log.info("Shield Failure: zeroed shields in %s (was %d)." %
			[zone, current])
	card.flip_facedown()
	_move_to_facedown(card, ship)
	EventBus.damage_card_flipped.emit(ship, card, false)
	return true


## Comm Noise: Opponent chooses — discard top command dial OR discard 1
## command token.
## Rules Reference: "Comm Noise" card text.
func _resolve_comm_noise(card: DamageCard,
		ship: ShipInstance, choice: Dictionary) -> bool:
	var chosen_id: String = choice.get("id", "")
	if chosen_id == "":
		_log.warn("Comm Noise: no choice provided.")
		return false
	if chosen_id == "discard_dial":
		if ship.command_dial_stack:
			ship.command_dial_stack.discard_top()
			EventBus.command_dials_changed.emit(ship)
			_log.info("Comm Noise: discarded top command dial.")
	elif chosen_id.begins_with("discard_token_"):
		var cmd_str: String = chosen_id.substr("discard_token_".length())
		var cmd_type: int = cmd_str.to_int()
		if ship.command_tokens:
			ship.command_tokens.remove_token(
					cmd_type as Constants.CommandType)
			EventBus.command_tokens_changed.emit(ship)
			_log.info("Comm Noise: discarded command token %s." % cmd_str)
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
func _get_injured_crew_choices(
		ship: ShipInstance) -> Dictionary:
	var options: Array[Dictionary] = []
	# Option A: discard a command token (one entry per held token type).
	if ship.command_tokens:
		for cmd_int: int in ship.command_tokens.get_tokens():
			var cmd_name: String = _command_type_name(cmd_int)
			options.append({
				"id": "discard_token_%d" % cmd_int,
				"label": "Discard %s token" % cmd_name,
				"available": true,
			})
	# Option B: exhaust a non-exhausted defense token.
	for i: int in range(ship.defense_tokens.size()):
		var dt: Dictionary = ship.defense_tokens[i]
		var state: int = int(dt.get("state", -1))
		if state == Constants.DefenseTokenState.READY:
			var dt_name: String = _defense_token_name(int(dt.get("type", -1)))
			options.append({
				"id": "exhaust_defense_%d" % i,
				"label": "Exhaust %s defense token" % dt_name,
				"available": true,
			})
	if options.is_empty():
		return {}
	return {"choice_type": CHOICE_INJURED_CREW, "options": options}


## Returns choice options for Shield Failure.
func _get_shield_failure_choices(
		ship: ShipInstance) -> Dictionary:
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
	return {"choice_type": CHOICE_SHIELD_FAILURE, "options": options}


## Returns choice options for Comm Noise.
func _get_comm_noise_choices(
		ship: ShipInstance) -> Dictionary:
	var options: Array[Dictionary] = []
	# Option A: discard top command dial.
	if ship.command_dial_stack and \
			ship.command_dial_stack.get_hidden_count() > 0:
		options.append({
			"id": "discard_dial",
			"label": "Discard top command dial",
			"available": true,
		})
	# Option B: discard a command token.
	if ship.command_tokens:
		for cmd_int: int in ship.command_tokens.get_tokens():
			var cmd_name: String = _command_type_name(cmd_int)
			options.append({
				"id": "discard_token_%d" % cmd_int,
				"label": "Discard %s token" % cmd_name,
				"available": true,
			})
	if options.is_empty():
		return {}
	return {"choice_type": CHOICE_COMM_NOISE, "options": options}


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
