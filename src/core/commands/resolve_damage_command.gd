## ResolveDamageCommand
##
## Applies all damage-resolution mutations atomically for replay safety.
## Handles both ship and squadron targets. For ships: absorbs shields,
## deals pre-drawn damage cards (faceup/facedown), and marks destruction.
## For squadrons: applies hull damage and marks destruction.
##
## The presentation layer (AttackExecutor) pre-computes shield absorption,
## draws cards from the DamageDeck, and determines faceup/facedown status
## BEFORE submitting this command. The command's [method execute] applies
## the recorded mutations to [GameState]-owned objects.
##
## Payload (ship target):
##   "target_type"      — "ship"
##   "owner_player"     — player index owning the defender
##   "ship_index"       — index into the player's ships array
##   "hull_zone"        — zone string ("FRONT", "LEFT", "RIGHT", "REAR")
##   "shield_damage"    — shields to absorb (pre-computed)
##   "damage_cards"     — Array of serialized card dicts (see DamageCard)
##   "target_destroyed" — whether the unit is destroyed after resolution
##
## Payload (squadron target):
##   "target_type"       — "squadron"
##   "owner_player"      — player index owning the defender
##   "squadron_index"    — index into the player's squadrons array
##   "hull_damage"       — damage to apply to hull
##   "actual_damage"     — damage actually applied (capped by current hull)
##   "target_destroyed"  — whether the squadron is destroyed
##
## Rules Reference: "Damage", p.4 — "Damage is the sum of all [hit] and
## [crit] icons in the attack pool."
class_name ResolveDamageCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("resolve_damage", func(player: int,
			pl: Dictionary) -> GameCommand:
		return ResolveDamageCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "resolve_damage", p_payload)


## Validates that damage resolution is legal in the current game state.
## Allowed in both Ship and Squadron phases.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	var phase: Constants.GamePhase = game_state.current_phase
	if phase != Constants.GamePhase.SHIP and phase != Constants.GamePhase.SQUADRON:
		return "Not in Ship or Squadron Phase."
	var target_type: String = payload.get("target_type", "")
	if target_type != "ship" and target_type != "squadron":
		return "Invalid target_type: '%s'." % target_type
	var owner: int = payload.get("owner_player", -1)
	if owner < 0 or owner >= Constants.PLAYER_COUNT:
		return "Invalid owner_player."
	match target_type:
		"ship":
			return _validate_ship(game_state, owner)
		"squadron":
			return _validate_squadron(game_state, owner)
	return ""


## Executes all damage mutations atomically.
## Returns a result dictionary describing what changed.
func execute(game_state: GameState) -> Dictionary:
	var target_type: String = payload.get("target_type", "")
	match target_type:
		"ship":
			return _execute_ship(game_state)
		"squadron":
			return _execute_squadron(game_state)
	return {}


# ---------------------------------------------------------------------------
# Ship validation & execution
# ---------------------------------------------------------------------------


## Validates ship-specific payload fields.
func _validate_ship(game_state: GameState, owner: int) -> String:
	var ship_index: int = payload.get("ship_index", -1)
	var ship: ShipInstance = game_state.get_ship(owner, ship_index)
	if ship == null:
		return "Ship not found."
	var hull_zone: String = payload.get("hull_zone", "")
	if hull_zone == "":
		return "Missing hull_zone."
	if not ship.current_shields.has(hull_zone):
		return "Invalid hull_zone: '%s'." % hull_zone
	var shield_damage: int = payload.get("shield_damage", -1)
	if shield_damage < 0:
		return "Invalid shield_damage."
	return ""


## Applies ship damage: shield absorption, damage cards, destruction.
func _execute_ship(game_state: GameState) -> Dictionary:
	var owner: int = payload.get("owner_player", 0)
	var ship_index: int = payload.get("ship_index", 0)
	var ship: ShipInstance = game_state.get_ship(owner, ship_index)
	var hull_zone: String = payload.get("hull_zone", "")
	var shield_damage: int = payload.get("shield_damage", 0)
	var card_data_array: Array = payload.get("damage_cards", [])
	var destroyed: bool = payload.get("target_destroyed", false)
	# Step 1: Absorb shields.
	var shield_absorbed: int = ship.reduce_shields(hull_zone, shield_damage)
	# Step 2: Deal damage cards.
	var cards_added: Array[Dictionary] = []
	for card_dict: Variant in card_data_array:
		var card: DamageCard = DamageCard.deserialize(
				card_dict as Dictionary)
		if card.is_faceup:
			ship.add_faceup_damage(card)
		else:
			ship.add_facedown_damage(card)
		cards_added.append(card.serialize())
	# Step 3: Mark destroyed if applicable.
	if destroyed:
		ship.mark_destroyed()
	return {
		"target_type": "ship",
		"owner_player": owner,
		"ship_index": ship_index,
		"hull_zone": hull_zone,
		"shield_absorbed": shield_absorbed,
		"new_shields": int(ship.current_shields.get(hull_zone, 0)),
		"cards_added": cards_added.size(),
		"destroyed": destroyed,
	}


# ---------------------------------------------------------------------------
# Squadron validation & execution
# ---------------------------------------------------------------------------


## Validates squadron-specific payload fields.
func _validate_squadron(game_state: GameState, owner: int) -> String:
	var sq_index: int = payload.get("squadron_index", -1)
	var sq: SquadronInstance = game_state.get_squadron(owner, sq_index)
	if sq == null:
		return "Squadron not found."
	var hull_damage: int = payload.get("hull_damage", -1)
	if hull_damage < 0:
		return "Invalid hull_damage."
	return ""


## Applies squadron damage: hull reduction and destruction.
func _execute_squadron(game_state: GameState) -> Dictionary:
	var owner: int = payload.get("owner_player", 0)
	var sq_index: int = payload.get("squadron_index", 0)
	var sq: SquadronInstance = game_state.get_squadron(owner, sq_index)
	var hull_damage: int = payload.get("hull_damage", 0)
	var destroyed: bool = payload.get("target_destroyed", false)
	# Apply hull damage.
	var actual: int = sq.suffer_damage(hull_damage)
	# Mark destroyed if applicable.
	if destroyed:
		sq.mark_destroyed()
	return {
		"target_type": "squadron",
		"owner_player": owner,
		"squadron_index": sq_index,
		"hull_damage": hull_damage,
		"actual_damage": actual,
		"new_hull": sq.current_hull,
		"destroyed": destroyed,
	}
