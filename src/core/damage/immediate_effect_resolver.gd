## ImmediateEffectResolver
##
## Pure presentation derivation for immediate faceup damage cards.
## Canonical mutation belongs exclusively to
## [CandidateResolveImmediateEffectCommand].
##
## Six damage cards have immediate effects:
##   1. Structural Damage  — suffer 1 extra facedown damage, then flip facedown
##   2. Projector Misaligned — reduce each hull zone's shields by 1, flip facedown
##   3. Life Support Failure — discard all command tokens, stays faceup;
##      its persistent token-gain restriction lives in RuleRegistry
##   4. Injured Crew — ship owner chooses and discards 1 defense token;
##      flip facedown
##   5. Shield Failure — opponent chooses up to 2 hull zones; each loses 1
##      shield; flip facedown
##   6. Comm Noise — opponent chooses: reduce speed by 1 OR choose a new
##      command on the top command dial; flip facedown
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
const CHOICE_PROJECTOR_MISALIGNED: String = "projector_misaligned"

## Returns true if the given card has an immediate effect.
static func is_immediate(card: DamageCard) -> bool:
	return card.timing == "immediate" or card.timing == "immediate_persistent"


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
		"projector_misaligned":
			return _get_projector_misaligned_choices(ship, card)
		_:
			return {}


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
	var options: Array[Dictionary] = _build_comm_noise_options(ship)
	if options.is_empty():
		return {}
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


## Builds the option list for a Comm Noise choice.
func _build_comm_noise_options(ship: ShipInstance) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	options.append({
		"id": "reduce_speed",
		"label": "Reduce speed by 1 (current: %d)" % ship.current_speed,
		"available": ship.current_speed > 0,
	})
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
	return options


## Returns choice options for Projector Misaligned when multiple zones
## are tied for the most shields.  Returns empty if a unique maximum exists.
## The OWNER chooses which tied zone loses all shields.
## Card text: "The hull zone with the most remaining shields loses all of
## its shields. If tied, the ship's owner chooses."
func _get_projector_misaligned_choices(
		ship: ShipInstance, card: DamageCard) -> Dictionary:
	# Find the maximum shield value.
	var best_val: int = 0
	for zone: String in ship.current_shields.keys():
		var val: int = int(ship.current_shields.get(zone, 0))
		if val > best_val:
			best_val = val
	if best_val <= 0:
		return {}
	# Collect all zones tied at the maximum.
	var tied: Array[String] = []
	for zone: String in ship.current_shields.keys():
		if int(ship.current_shields.get(zone, 0)) == best_val:
			tied.append(zone)
	# Unique maximum — auto-resolve, no choice needed.
	if tied.size() <= 1:
		return {}
	# Tied — present a choice to the ship's owner.
	var options: Array[Dictionary] = []
	for zone: String in tied:
		options.append({
			"id": "zone_%s" % zone,
			"label": "%s (%d shields)" % [zone, best_val],
			"available": true,
		})
	return {
		"choice_type": CHOICE_PROJECTOR_MISALIGNED,
		"chooser": "owner",
		"multi_select": false,
		"max_selections": 1,
		"card_title": card.title,
		"effect_text": card.effect_text,
		"options": options,
	}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


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
