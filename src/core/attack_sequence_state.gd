## AttackSequenceState
##
## State machine that drives a ship's attack sequence during the Attack
## sub-step of activation. Orchestrates Steps 1–6 of the RRG attack
## procedure, including hull zone selection, dice pool management,
## Concentrate Fire integration, defense token resolution, and damage.
##
## Pure core logic — extends RefCounted, no scene-tree dependency.
## The UI layer (AttackModeController / AttackInfoPanel) reads state
## and calls transition methods in response to player actions.
##
## Rules Reference: "Attack", pp. 2–3; "Ship Activation", p. 16.
## Requirements: ATK-SM-001, ATK-FLOW-001–003.
class_name AttackSequenceState
extends RefCounted


## Attack sub-states.
enum State {
	IDLE,                     ## Not in attack mode.
	HULL_ZONE_SELECT,         ## Player picking attacking hull zone.
	TARGET_SELECT,            ## Player picking defender.
	DICE_POOL_PREVIEW,        ## Showing dice pool, CF dial prompt.
	ROLL_DICE,                ## Dice rolled, pre-Step-3 display.
	ATTACK_EFFECTS,           ## Step 3: CF token reroll, accuracy.
	DEFENSE_TOKENS,           ## Step 4: Defender spends tokens.
	RESOLVE_DAMAGE,           ## Step 5: Damage resolution.
	ADDITIONAL_SQUAD_TARGET,  ## Step 6: Pick next squadron target.
	ATTACK_COMPLETE,          ## One attack done; decide next.
	ALL_ATTACKS_DONE,         ## Both attacks finished/skipped.
}

## The current state.
var _state: State = State.IDLE

## The ship activation state (tracks hull zone usage, CF availability).
var _activation_state: ShipActivationState = null

## The attacking ShipInstance.
var _attacker: ShipInstance = null

## The selected attacking hull zone (or -1).
var _attacking_zone: int = -1

## Whether the target is a ship (true) or squadron (false).
var _target_is_ship: bool = false

## The defending ShipInstance (if ship target).
var _target_ship: ShipInstance = null

## The defending SquadronInstance (if squadron target).
var _target_squadron: RefCounted = null

## The defending hull zone (ship targets only).
var _defending_zone: int = -1

## The measured range band for this attack.
var _range_band: String = ""

## Whether the attack LOS is obstructed.
var _attack_obstructed: bool = false

## Squadrons already targeted from the current hull zone this attack
## (Step 6 tracking — each can only be targeted once).
var _targeted_squads: Array[RefCounted] = []

## The dice pool for the current attack.
var _dice_pool: AttackDicePool = AttackDicePool.new()

## The defense token resolver for the current attack.
var _defense_resolver: DefenseTokenResolver = DefenseTokenResolver.new()

## The damage resolver.
var _damage_resolver: DamageResolver = DamageResolver.new()

## The result of the last damage resolution.
var _last_damage_result: DamageResolver.DamageResult = null

## Whether the CF dial decision has been made for this attack.
var _cf_dial_decided: bool = false

## Whether the CF token decision has been made for this attack.
var _cf_token_decided: bool = false

## Types of defense tokens already spent this attack (max 1 per type).
var _spent_token_types: Array[int] = []

var _log: GameLogger = GameLogger.new("AttackSequenceState")


## Creates a new attack sequence for the given activation state.
## [param activation_state] — the ShipActivationState.
static func create(
		activation_state: ShipActivationState) -> AttackSequenceState:
	var seq: AttackSequenceState = AttackSequenceState.new()
	seq._activation_state = activation_state
	seq._attacker = activation_state.get_ship()
	seq._state = State.IDLE
	return seq


## Returns the current state.
func get_state() -> State:
	return _state


## Returns the activation state.
func get_activation_state() -> ShipActivationState:
	return _activation_state


## Returns the attacking ship.
func get_attacker() -> ShipInstance:
	return _attacker


## Returns the selected attacking hull zone, or -1.
func get_attacking_zone() -> int:
	return _attacking_zone


## Returns true if the target is a ship.
func is_target_ship() -> bool:
	return _target_is_ship


## Returns the defending ship (or null).
func get_target_ship() -> ShipInstance:
	return _target_ship


## Returns the defending squadron (or null).
func get_target_squadron() -> RefCounted:
	return _target_squadron


## Returns the defending hull zone (-1 if squadron target).
func get_defending_zone() -> int:
	return _defending_zone


## Returns the measured range band.
func get_range_band() -> String:
	return _range_band


## Returns whether the attack is obstructed.
func is_obstructed() -> bool:
	return _attack_obstructed


## Returns the dice pool.
func get_dice_pool() -> AttackDicePool:
	return _dice_pool


## Returns the defense token resolver.
func get_defense_resolver() -> DefenseTokenResolver:
	return _defense_resolver


## Returns the last damage result (null if not yet resolved).
func get_last_damage_result() -> DamageResolver.DamageResult:
	return _last_damage_result


# ---------------------------------------------------------------------------
# State transitions
# ---------------------------------------------------------------------------


## Enters attack mode — transitions from IDLE to HULL_ZONE_SELECT.
## Requirements: ATK-FLOW-001.
func begin_attacks() -> void:
	if _state != State.IDLE:
		return
	_state = State.HULL_ZONE_SELECT
	_log.info("Attack mode entered — select hull zone.")


## Selects the attacking hull zone.
## Transitions from HULL_ZONE_SELECT to TARGET_SELECT.
## [param zone] — the hull zone to attack from.
## Returns false if the zone is already used.
## Requirements: ATK-S1-001.
func select_attacking_zone(zone: Constants.HullZone) -> bool:
	if _state != State.HULL_ZONE_SELECT and \
			_state != State.ADDITIONAL_SQUAD_TARGET:
		return false
	if _activation_state.is_attack_zone_used(zone):
		_log.info("Hull zone %s already used." %
				Constants.HullZone.keys()[zone])
		return false
	_attacking_zone = int(zone)
	_state = State.TARGET_SELECT
	_log.info("Attacking zone selected: %s" %
			Constants.HullZone.keys()[zone])
	return true


## Deselects the attacking hull zone, returning to HULL_ZONE_SELECT.
## Requirements: ATK-S1-003.
func deselect_attacking_zone() -> void:
	if _state == State.ADDITIONAL_SQUAD_TARGET:
		return  # Cannot deselect during step 6.
	_attacking_zone = -1
	_target_ship = null
	_target_squadron = null
	_defending_zone = -1
	_target_is_ship = false
	_state = State.HULL_ZONE_SELECT
	_log.info("Attacking zone deselected.")


## Selects a ship hull zone as the target.
## [param ship] — defending ShipInstance.
## [param zone] — defending hull zone.
## [param range_band] — measured range band.
## [param obstructed] — whether LOS is obstructed.
## Requirements: ATK-S1-002.
func select_ship_target(ship: ShipInstance, zone: Constants.HullZone,
		range_band: String, obstructed: bool) -> void:
	if _state != State.TARGET_SELECT:
		return
	_target_is_ship = true
	_target_ship = ship
	_target_squadron = null
	_defending_zone = int(zone)
	_range_band = range_band
	_attack_obstructed = obstructed
	_state = State.DICE_POOL_PREVIEW
	_gather_dice_pool()
	_log.info("Ship target selected: zone %s, range %s, obstructed=%s" %
			[Constants.HullZone.keys()[zone], range_band, str(obstructed)])


## Selects a squadron as the target.
## [param squad] — defending SquadronInstance.
## [param range_band] — measured range band.
## [param obstructed] — whether LOS is obstructed.
## Requirements: ATK-S1-002.
func select_squadron_target(squad: RefCounted,
		range_band: String, obstructed: bool) -> void:
	if _state != State.TARGET_SELECT:
		return
	_target_is_ship = false
	_target_ship = null
	_target_squadron = squad
	_defending_zone = -1
	_range_band = range_band
	_attack_obstructed = obstructed
	_state = State.DICE_POOL_PREVIEW
	_gather_dice_pool()
	_log.info("Squadron target selected: range %s, obstructed=%s" %
			[range_band, str(obstructed)])


## Deselects the current target, returning to TARGET_SELECT.
## Requirements: ATK-S1-003.
func deselect_target() -> void:
	if _state != State.DICE_POOL_PREVIEW:
		return
	_target_ship = null
	_target_squadron = null
	_defending_zone = -1
	_target_is_ship = false
	_range_band = ""
	_attack_obstructed = false
	_dice_pool = AttackDicePool.new()
	_cf_dial_decided = false
	_state = State.TARGET_SELECT
	_log.info("Target deselected.")


## Handles obstruction die removal by the attacker.
## [param colour] — the colour of the die to remove ("RED", "BLUE", "BLACK").
## Returns true if the die was removed.
## If the pool is now empty, the attack is cancelled.
## Requirements: ATK-S2-002.
func remove_obstruction_die(colour: String) -> bool:
	if _state != State.DICE_POOL_PREVIEW:
		return false
	if not _dice_pool.remove_obstruction_die(colour):
		return false
	if _dice_pool.is_empty():
		_cancel_attack()
		return true
	return true


## Adds a CF dial die of the given colour.
## [param colour] — must be a colour already in the pool.
## Returns true if added.
## Requirements: ATK-S2-003.
func add_cf_die(colour: String) -> bool:
	if _state != State.DICE_POOL_PREVIEW:
		return false
	if not _dice_pool.add_concentrate_fire_die(colour):
		return false
	_cf_dial_decided = true
	if _activation_state:
		_activation_state.mark_command_resolved(
				Constants.CommandType.CONCENTRATE_FIRE)
	return true


## Skips the CF dial option.
func skip_cf_dial() -> void:
	_cf_dial_decided = true


## Returns true if the CF dial decision has been made.
func is_cf_dial_decided() -> bool:
	return _cf_dial_decided


## Returns true if a CF dial prompt should be shown.
func should_show_cf_dial_prompt() -> bool:
	if _cf_dial_decided:
		return false
	return _activation_state.has_concentrate_fire_dial()


## Rolls the dice. Transitions to ROLL_DICE, then ATTACK_EFFECTS.
## Requirements: ATK-S2-004.
func roll_dice() -> Array[Dictionary]:
	if _state != State.DICE_POOL_PREVIEW:
		return []
	if _dice_pool.get_gathered_count() == 0:
		_cancel_attack()
		return []
	var results: Array[Dictionary] = _dice_pool.roll()
	_state = State.ATTACK_EFFECTS
	_log.info("Dice rolled — entering Attack Effects.")
	return results


## Rerolls a die using the CF token.
## [param die_index] — index of the die to reroll.
## Returns the new face, or BLANK if failed.
## Requirements: ATK-S3-001.
func cf_reroll(die_index: int) -> Constants.DiceFace:
	if _state != State.ATTACK_EFFECTS:
		return Constants.DiceFace.BLANK
	if not _activation_state.has_concentrate_fire_token():
		return Constants.DiceFace.BLANK
	if _dice_pool.is_cf_reroll_used():
		return Constants.DiceFace.BLANK
	var face: Constants.DiceFace = _dice_pool.reroll_die(die_index)
	_dice_pool.mark_cf_reroll_used()
	_activation_state.spend_concentrate_fire_token()
	return face


## Spends an accuracy die to lock a defender's defense token.
## [param die_index] — the accuracy die index.
## [param token_index] — the defender's token index to lock.
## Returns true if successful.
## Requirements: ATK-S3-002.
func spend_accuracy(die_index: int, token_index: int) -> bool:
	if _state != State.ATTACK_EFFECTS:
		return false
	if not _dice_pool.spend_accuracy(die_index):
		return false
	_defense_resolver.lock_token(token_index)
	_log.info("Accuracy spent: die %d locks token %d." %
			[die_index, token_index])
	return true


## Finishes Step 3 and advances to Step 4 (Defense Tokens).
## Requirements: ATK-S3-003.
func finish_attack_effects() -> void:
	if _state != State.ATTACK_EFFECTS:
		return
	_state = State.DEFENSE_TOKENS
	_spent_token_types.clear()
	_log.info("Attack effects done — defender's turn.")


## Returns the list of spendable defense token indices for the defender.
func get_defender_spendable_tokens() -> Array[int]:
	var defender_tokens: Array[Dictionary] = _get_defender_tokens()
	var speed: int = _get_defender_speed()
	return _defense_resolver.get_spendable_tokens(
			defender_tokens, speed)


## Spends a defender's defense token.
## [param token_index] — the index in the defender's token array.
## Returns true if spent successfully.
## Requirements: ATK-S4-001.
func spend_defense_token(token_index: int,
		extra_data: Dictionary = {}) -> bool:
	if _state != State.DEFENSE_TOKENS:
		return false
	var tokens: Array[Dictionary] = _get_defender_tokens()
	if token_index < 0 or token_index >= tokens.size():
		return false
	if _defense_resolver.is_token_locked(token_index):
		return false
	var token: Dictionary = tokens[token_index]
	if token["state"] == Constants.DefenseTokenState.DISCARDED:
		return false
	var token_type: int = int(token["type"])

	# Max 1 of each type per attack.
	if token_type in _spent_token_types:
		_log.info("Already spent a %s token this attack." %
				Constants.DefenseToken.keys()[token_type])
		return false
	_spent_token_types.append(token_type)

	# Get the defender RefCounted.
	var defender: RefCounted = _get_defender_refcounted()
	if defender == null:
		return false

	# Apply the token's effect.
	match token_type:
		Constants.DefenseToken.EVADE:
			var die_idx: int = extra_data.get("die_index", 0)
			_defense_resolver.resolve_evade(
					_dice_pool, _range_band, die_idx)
		Constants.DefenseToken.BRACE:
			_defense_resolver.activate_brace()
		Constants.DefenseToken.SCATTER:
			_defense_resolver.resolve_scatter(_dice_pool)
		Constants.DefenseToken.REDIRECT:
			var redir_zone: Constants.HullZone = extra_data.get(
					"redirect_zone", Constants.HullZone.FRONT)
			var max_shields: int = extra_data.get("max_shields", 0)
			_defense_resolver.activate_redirect(redir_zone, max_shields)
		Constants.DefenseToken.CONTAIN:
			_defense_resolver.activate_contain()
		Constants.DefenseToken.SALVO:
			_log.info("Salvo not yet implemented — skipped.")
			return false

	# Flip / discard the token.
	DefenseTokenResolver.spend_token(defender, token_index)
	EventBus.defense_token_spent.emit(defender, token_type)
	_log.info("Defense token spent: %s (index %d)." %
			[Constants.DefenseToken.keys()[token_type], token_index])
	return true


## Finishes Step 4 and resolves damage (Step 5).
## Returns the DamageResult.
## Requirements: ATK-S4-009, ATK-S5-001–005.
func finish_defense_and_resolve_damage() -> DamageResolver.DamageResult:
	if _state != State.DEFENSE_TOKENS:
		return null
	_state = State.RESOLVE_DAMAGE

	if _target_is_ship and _target_ship:
		_last_damage_result = _damage_resolver.resolve_ship_damage(
				_dice_pool, _defense_resolver, _target_ship,
				_defending_zone as Constants.HullZone)
	elif _target_squadron:
		_last_damage_result = _damage_resolver.resolve_squadron_damage(
				_dice_pool, _defense_resolver, _target_squadron)
	else:
		_last_damage_result = DamageResolver.DamageResult.new()

	# Emit damage_resolved.
	var target_node: Node = null  # UI layer maps instances to nodes.
	var total_dmg: int = _last_damage_result.final_damage \
			if _last_damage_result else 0
	EventBus.damage_resolved.emit(target_node, total_dmg)

	_log.info("Damage resolved — final=%d, destroyed=%s" %
			[total_dmg, str(_last_damage_result.destroyed \
			if _last_damage_result else false)])
	return _last_damage_result


## After damage resolution, check for additional squadron targets (Step 6)
## or complete the attack.
## Returns the next state.
## Requirements: ATK-S6-001, ATK-S6-003.
func advance_after_damage() -> State:
	if _state != State.RESOLVE_DAMAGE:
		return _state

	# Track the targeted squadron for Step 6 uniqueness.
	if not _target_is_ship and _target_squadron:
		if _target_squadron not in _targeted_squads:
			_targeted_squads.append(_target_squadron)

	# Step 6: if the defender was a squadron, offer another squadron target.
	if not _target_is_ship:
		_state = State.ADDITIONAL_SQUAD_TARGET
		_log.info("Step 6 — additional squadron target available.")
		return _state

	# Attack complete (ship target — no Step 6).
	_complete_current_attack()
	return _state


## Selects a new squadron target for Step 6.
## [param squad] — the next SquadronInstance.
## [param range_band] — measured range band.
## [param obstructed] — whether obstructed.
## Returns false if the squadron was already targeted.
## Requirements: ATK-S6-001, ATK-S6-002.
func select_additional_squad_target(squad: RefCounted,
		range_band: String, obstructed: bool) -> bool:
	if _state != State.ADDITIONAL_SQUAD_TARGET:
		return false
	if squad in _targeted_squads:
		_log.info("Squadron already targeted this attack.")
		return false
	_target_squadron = squad
	_target_ship = null
	_target_is_ship = false
	_defending_zone = -1
	_range_band = range_band
	_attack_obstructed = obstructed

	# Reset pool and defense for the new sub-attack.
	_dice_pool = AttackDicePool.new()
	_defense_resolver = DefenseTokenResolver.new()
	_cf_dial_decided = true  # CF dial is once per activation.
	_cf_token_decided = true  # Token too, if already spent.
	_last_damage_result = null
	_spent_token_types.clear()

	_gather_dice_pool()
	_state = State.DICE_POOL_PREVIEW
	_log.info("Additional squadron target selected.")
	return true


## Skips Step 6 (no more squadron targets).
## Requirements: ATK-S6-003.
func skip_additional_squad_target() -> void:
	if _state != State.ADDITIONAL_SQUAD_TARGET:
		return
	_complete_current_attack()


## After one attack is complete, decide whether another attack is available.
## Returns the next state.
## Requirements: ATK-FLOW-002.
func advance_after_attack() -> State:
	if _state != State.ATTACK_COMPLETE:
		return _state
	if _activation_state.can_attack_again():
		# Offer second attack.
		_reset_for_new_attack()
		_state = State.HULL_ZONE_SELECT
		_log.info("Ready for second attack — select hull zone.")
	else:
		_state = State.ALL_ATTACKS_DONE
		_log.info("All attacks done.")
	return _state


## Skips remaining attacks and marks all done.
func skip_remaining_attacks() -> void:
	_state = State.ALL_ATTACKS_DONE
	_log.info("Remaining attacks skipped.")


## Returns true if attacks are all done.
func is_all_done() -> bool:
	return _state == State.ALL_ATTACKS_DONE


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------


## Gathers the dice pool based on current attacker/target selection.
func _gather_dice_pool() -> void:
	_dice_pool = AttackDicePool.new()
	var armament: Dictionary = {}
	if _target_is_ship:
		# Battery armament from the attacking hull zone.
		var zone_str: String = Constants.HullZone.keys()[_attacking_zone]
		armament = _attacker.ship_data.battery_armament.get(zone_str, {})
	else:
		# Anti-squadron armament.
		armament = _attacker.ship_data.anti_squadron_armament
	_dice_pool.gather(armament, _range_band, _attack_obstructed)

	# Auto-remove obstruction if only 1 die.
	if _dice_pool.is_obstructed() and not _dice_pool.is_obstruction_resolved():
		var auto: String = _dice_pool.auto_remove_obstruction()
		if auto != "" and _dice_pool.is_empty():
			_cancel_attack()


## Cancels the current attack (0 dice).
## Requirements: ATK-FLOW-003.
func _cancel_attack() -> void:
	_log.info("Attack cancelled — no dice.")
	EventBus.attack_cancelled.emit()
	_complete_current_attack()


## Marks the current attack as complete.
func _complete_current_attack() -> void:
	if _attacking_zone >= 0:
		_activation_state.mark_attack_zone_used(
				_attacking_zone as Constants.HullZone)
	_state = State.ATTACK_COMPLETE
	EventBus.attack_completed.emit()
	_log.info("Attack complete (attacks performed: %d)." %
			_activation_state.get_attacks_performed())


## Resets state for a new attack (second hull zone).
func _reset_for_new_attack() -> void:
	_attacking_zone = -1
	_target_ship = null
	_target_squadron = null
	_target_is_ship = false
	_defending_zone = -1
	_range_band = ""
	_attack_obstructed = false
	_targeted_squads.clear()
	_dice_pool = AttackDicePool.new()
	_defense_resolver = DefenseTokenResolver.new()
	_last_damage_result = null
	_cf_dial_decided = false
	_cf_token_decided = false
	_spent_token_types.clear()


## Returns the defender's defense tokens array.
func _get_defender_tokens() -> Array[Dictionary]:
	if _target_is_ship and _target_ship:
		return _target_ship.defense_tokens
	if _target_squadron and _target_squadron.has_method("get"):
		return _target_squadron.defense_tokens
	return [] as Array[Dictionary]


## Returns the defender's current speed (-1 for squadrons).
func _get_defender_speed() -> int:
	if _target_is_ship and _target_ship:
		return _target_ship.current_speed
	return 1  # Squadrons have no speed restriction.


## Returns the defender as a RefCounted (ShipInstance or SquadronInstance).
func _get_defender_refcounted() -> RefCounted:
	if _target_is_ship and _target_ship:
		return _target_ship
	return _target_squadron
