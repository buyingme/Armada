## ResolveDamageCommand
##
## Applies all damage-resolution mutations atomically for replay safety.
## Handles both ship and squadron targets. For ships: absorbs shields,
## deals pre-drawn damage cards (faceup/facedown), registers persistent
## faceup damage-card effects, and marks destruction.
## For squadrons: applies hull damage and marks destruction.
##
## Damage, shield absorption, and card draws are derived inside the command
## from canonical current-attack and target state.
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
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack == null or not attack.active:
		return "No current attack."
	if attack.attack_id != str(payload.get("attack_id", "")):
		return "Stale current-attack identity."
	if player_index != attack.attacker_player:
		return "Damage resolution belongs to the attacker."
	if attack.stage != CurrentAttackState.STAGE_DEFENSE \
			or attack.defense_stage != CurrentAttackState.DEFENSE_COMPLETE:
		return "Defense resolution is not complete."
	match attack.defender_kind:
		"ship":
			return _validate_ship(game_state, attack)
		"squadron":
			return _validate_squadron(game_state, attack)
	return "Invalid current-attack defender."


## Executes all damage mutations atomically.
## Returns a result dictionary describing what changed.
func execute(game_state: GameState) -> Dictionary:
	var attack: CurrentAttackState = game_state.current_attack_state
	match attack.defender_kind:
		"ship":
			return _execute_ship(game_state, attack)
		"squadron":
			return _execute_squadron(game_state, attack)
	return {}


# ---------------------------------------------------------------------------
# Ship validation & execution
# ---------------------------------------------------------------------------


## Validates ship-specific payload fields.
func _validate_ship(game_state: GameState,
		attack: CurrentAttackState) -> String:
	var ship: ShipInstance = game_state.get_ship(
			attack.defender_player, attack.defender_index)
	if ship == null:
		return "Ship not found."
	var hull_zone: String = Constants.hull_zone_to_string(
			attack.defender_zone as Constants.HullZone)
	if not ship.current_shields.has(hull_zone):
		return "Invalid hull_zone: '%s'." % hull_zone
	var cards_required: int = maxi(0, attack.derive_damage(game_state) \
			- int(ship.current_shields.get(hull_zone, 0)))
	if game_state.damage_deck == null and cards_required > 0:
		return "Damage deck is unavailable."
	if game_state.damage_deck != null \
			and game_state.damage_deck.get_total_count() < cards_required:
		return "Damage deck does not contain enough cards."
	return ""


## Applies ship damage: shield absorption, damage cards, destruction.
func _execute_ship(game_state: GameState,
		attack: CurrentAttackState) -> Dictionary:
	var owner: int = attack.defender_player
	var ship_index: int = attack.defender_index
	var ship: ShipInstance = game_state.get_ship(owner, ship_index)
	var hull_zone: String = Constants.hull_zone_to_string(
			attack.defender_zone as Constants.HullZone)
	var damage: int = attack.derive_damage(game_state)
	var shield_damage: int = mini(
			int(ship.current_shields.get(hull_zone, 0)), damage)
	var remaining: int = damage - shield_damage
	var deck_snapshot: Dictionary = game_state.damage_deck.serialize() \
			if remaining > 0 else {}
	var card_data_array: Array[Dictionary] = _draw_damage_cards(
			game_state, attack, remaining)
	if card_data_array.size() != remaining:
		_restore_damage_deck(game_state, deck_snapshot)
		return {}
	var destroyed: bool = ship.get_total_damage() + card_data_array.size() \
			>= ship.ship_data.hull
	var replacement: CurrentAttackState = attack.with_patch({
		"stage": CurrentAttackState.STAGE_RESOLVED,
		"damage_stage": CurrentAttackState.DAMAGE_RESOLVED,
	})
	if replacement == null:
		_restore_damage_deck(game_state, deck_snapshot)
		return {}
	if not game_state.set_current_attack_state(replacement):
		_restore_damage_deck(game_state, deck_snapshot)
		return {}
	# Remaining steps are non-fallible after validation and CAS install.
	var shield_absorbed: int = ship.reduce_shields(hull_zone, shield_damage)
	var cards_added: Array[Dictionary] = []
	for card_dict: Variant in card_data_array:
		var card: DamageCard = DamageCard.deserialize(
				card_dict as Dictionary)
		if card.is_faceup:
			ship.add_faceup_damage(card)
		else:
			ship.add_facedown_damage(card)
		cards_added.append(card.serialize())
	if destroyed:
		ship.mark_destroyed()
	return {
		"attack_id": attack.attack_id,
		"target_type": "ship",
		"owner_player": owner,
		"ship_index": ship_index,
		"hull_zone": hull_zone,
		"shield_absorbed": shield_absorbed,
		"new_shields": int(ship.current_shields.get(hull_zone, 0)),
		"cards_added": cards_added.size(),
		"damage_cards": cards_added,
		"final_damage": damage,
		"persistent_registered": 0,
		"destroyed": destroyed,
	}


# ---------------------------------------------------------------------------
# Squadron validation & execution
# ---------------------------------------------------------------------------


## Validates squadron-specific payload fields.
func _validate_squadron(game_state: GameState,
		attack: CurrentAttackState) -> String:
	var sq: SquadronInstance = game_state.get_squadron(
			attack.defender_player, attack.defender_index)
	if sq == null:
		return "Squadron not found."
	return ""


## Applies squadron damage: hull reduction and destruction.
func _execute_squadron(game_state: GameState,
		attack: CurrentAttackState) -> Dictionary:
	var owner: int = attack.defender_player
	var sq_index: int = attack.defender_index
	var sq: SquadronInstance = game_state.get_squadron(owner, sq_index)
	var hull_damage: int = attack.derive_damage(game_state)
	var actual_damage: int = mini(hull_damage, sq.current_hull)
	var destroyed: bool = sq.current_hull - actual_damage <= 0
	var replacement: CurrentAttackState = attack.with_patch({
		"stage": CurrentAttackState.STAGE_RESOLVED,
		"damage_stage": CurrentAttackState.DAMAGE_RESOLVED,
	})
	if replacement == null:
		return {}
	if not game_state.set_current_attack_state(replacement):
		return {}
	# Remaining steps are non-fallible after validation and CAS install.
	var actual: int = sq.suffer_damage(hull_damage)
	# Mark destroyed if applicable.
	if destroyed:
		sq.mark_destroyed()
	return {
		"attack_id": attack.attack_id,
		"target_type": "squadron",
		"owner_player": owner,
		"squadron_index": sq_index,
		"hull_damage": hull_damage,
		"actual_damage": actual,
		"new_hull": sq.current_hull,
		"destroyed": destroyed,
	}


func _draw_damage_cards(game_state: GameState,
		attack: CurrentAttackState, count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var first_faceup: bool = _first_card_faceup(game_state, attack)
	for index: int in range(count):
		var card: DamageCard = game_state.damage_deck.draw_card()
		if card == null:
			break
		card.is_faceup = index == 0 and first_faceup
		result.append(card.serialize())
	return result


func _restore_damage_deck(game_state: GameState,
		deck_snapshot: Dictionary) -> void:
	if not deck_snapshot.is_empty():
		game_state.damage_deck = DamageDeck.deserialize(deck_snapshot)


func _first_card_faceup(game_state: GameState,
		attack: CurrentAttackState) -> bool:
	if attack.attacker_kind != CurrentAttackState.KIND_SHIP \
			or attack.defender_kind != CurrentAttackState.KIND_SHIP \
			or not Dice.has_any_critical(attack.dice_results):
		return false
	for effect: Dictionary in attack.resolved_defense_effects:
		if int(effect.get("token_type", -1)) == Constants.DefenseToken.CONTAIN:
			return false
	var context := EffectContext.new()
	context.attacker = game_state.get_ship(
			attack.attacker_player, attack.attacker_index)
	context.defender = game_state.get_ship(
			attack.defender_player, attack.defender_index)
	context.critical_allowed = true
	return not RuleSurface.is_blocked(
			context,
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE,
			RuleSurface.TARGET_CRITICAL_EFFECT)
