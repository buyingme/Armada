## Tests for AttackSequenceState
##
## Covers: state transitions, hull zone selection, target selection,
## dice rolling, CF dial/token integration, accuracy spending,
## defense token spending, damage resolution, Step 6 additional
## squadron target, multi-attack flow, cancellation.
##
## Rules Reference: "Attack", pp. 2–3; "Ship Activation", p. 16.
## Requirements: ATK-SM-001, ATK-FLOW-001–003.
extends GutTest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


func _make_ship(has_cf_dial: bool = false,
		has_cf_token: bool = false) -> ShipInstance:
	var data: ShipData = ShipData.new()
	data.hull = 5
	data.max_speed = 3
	data.command_value = 2
	data.shields = {"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1}
	data.defense_tokens = ["BRACE", "REDIRECT"]
	data.navigation_chart = [[2], [1, 2], [0, 1, 2]]
	data.battery_armament = {
		"FRONT": {"RED": 2, "BLUE": 1, "BLACK": 0},
		"LEFT": {"RED": 1, "BLUE": 0, "BLACK": 0},
		"RIGHT": {"RED": 1, "BLUE": 0, "BLACK": 0},
		"REAR": {"RED": 0, "BLUE": 1, "BLACK": 0},
	}
	data.anti_squadron_armament = {"RED": 0, "BLUE": 1, "BLACK": 0}
	var ship: ShipInstance = ShipInstance.create_from_data(
			"test_ship", data, 2, 0)
	# Set up command dial stack.
	if has_cf_dial:
		ship.command_dial_stack.assign_dials(
				[Constants.CommandType.CONCENTRATE_FIRE,
				Constants.CommandType.REPAIR], 1)
	else:
		ship.command_dial_stack.assign_dials(
				[Constants.CommandType.REPAIR,
				Constants.CommandType.REPAIR], 1)
	ship.command_dial_stack.reveal_top()
	if has_cf_token:
		ship.command_tokens.add_token(
				Constants.CommandType.CONCENTRATE_FIRE)
	return ship


func _make_defender(front_shields: int = 3) -> ShipInstance:
	var data: ShipData = ShipData.new()
	data.hull = 4
	data.max_speed = 2
	data.command_value = 2
	data.shields = {
		"FRONT": front_shields, "LEFT": 1, "RIGHT": 1, "REAR": 1,
	}
	data.defense_tokens = ["EVADE", "BRACE"]
	data.navigation_chart = [[1], [0, 1]]
	data.battery_armament = {}
	data.anti_squadron_armament = {}
	return ShipInstance.create_from_data("defender_ship", data, 1, 1)


func _make_squadron() -> RefCounted:
	## Returns a real SquadronInstance with minimal data.
	var data := load("res://src/models/squadron_data.gd").new()
	data.squadron_name = "Test Squadron"
	data.hull = 3
	data.speed = 4
	data.defense_tokens = []
	return load("res://src/core/squadron_instance.gd").create_from_data("test_squad", data, 1)


func _make_state(
		has_cf_dial: bool = false,
		has_cf_token: bool = false) -> AttackSequenceState:
	var ship: ShipInstance = _make_ship(has_cf_dial, has_cf_token)
	var activation: ShipActivationState = ShipActivationState.create(ship)
	return AttackSequenceState.create(activation)


# ---------------------------------------------------------------------------
# Initial state
# ---------------------------------------------------------------------------


func test_create_starts_at_idle() -> void:
	var seq: AttackSequenceState = _make_state()
	assert_eq(seq.get_state(), AttackSequenceState.State.IDLE,
			"Should start in IDLE state")


# ---------------------------------------------------------------------------
# begin_attacks
# ---------------------------------------------------------------------------


func test_begin_attacks_transitions_to_hull_zone_select() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()
	assert_eq(seq.get_state(),
			AttackSequenceState.State.HULL_ZONE_SELECT,
			"Should transition to HULL_ZONE_SELECT")


func test_begin_attacks_ignored_if_not_idle() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()
	seq.begin_attacks()  # Second call should be ignored.
	assert_eq(seq.get_state(),
			AttackSequenceState.State.HULL_ZONE_SELECT,
			"Should stay at HULL_ZONE_SELECT")


# ---------------------------------------------------------------------------
# select_attacking_zone
# ---------------------------------------------------------------------------


func test_select_attacking_zone_transitions_to_target_select() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()
	var ok: bool = seq.select_attacking_zone(Constants.HullZone.FRONT)
	assert_true(ok, "Should succeed selecting FRONT")
	assert_eq(seq.get_state(),
			AttackSequenceState.State.TARGET_SELECT,
			"Should transition to TARGET_SELECT")
	assert_eq(seq.get_attacking_zone(), int(Constants.HullZone.FRONT),
			"Attacking zone should be FRONT")


func test_select_used_zone_fails() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()
	# Mark FRONT as used via activation state.
	seq.get_activation_state().mark_attack_zone_used(
			Constants.HullZone.FRONT)
	var ok: bool = seq.select_attacking_zone(Constants.HullZone.FRONT)
	assert_false(ok, "Should fail — FRONT already used")
	assert_eq(seq.get_state(),
			AttackSequenceState.State.HULL_ZONE_SELECT,
			"Should stay at HULL_ZONE_SELECT")


# ---------------------------------------------------------------------------
# deselect_attacking_zone
# ---------------------------------------------------------------------------


func test_deselect_zone_returns_to_hull_zone_select() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	seq.deselect_attacking_zone()
	assert_eq(seq.get_state(),
			AttackSequenceState.State.HULL_ZONE_SELECT,
			"Should return to HULL_ZONE_SELECT")
	assert_eq(seq.get_attacking_zone(), -1,
			"Attacking zone should be reset")


# ---------------------------------------------------------------------------
# select_ship_target
# ---------------------------------------------------------------------------


func test_select_ship_target_transitions_to_dice_pool_preview() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	var defender: ShipInstance = _make_defender()
	seq.select_ship_target(defender, Constants.HullZone.FRONT,
			"medium", false)
	assert_eq(seq.get_state(),
			AttackSequenceState.State.DICE_POOL_PREVIEW,
			"Should transition to DICE_POOL_PREVIEW")
	assert_true(seq.is_target_ship(), "Target should be a ship")
	assert_eq(seq.get_range_band(), "medium", "Range should be medium")


# ---------------------------------------------------------------------------
# select_squadron_target
# ---------------------------------------------------------------------------


func test_select_squadron_target_transitions_to_dice_pool_preview() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	var squad: RefCounted = _make_squadron()
	seq.select_squadron_target(squad, "close", false)
	assert_eq(seq.get_state(),
			AttackSequenceState.State.DICE_POOL_PREVIEW,
			"Should transition to DICE_POOL_PREVIEW")
	assert_false(seq.is_target_ship(), "Target should not be a ship")


# ---------------------------------------------------------------------------
# deselect_target
# ---------------------------------------------------------------------------


func test_deselect_target_returns_to_target_select() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	var defender: ShipInstance = _make_defender()
	seq.select_ship_target(defender, Constants.HullZone.FRONT,
			"medium", false)
	seq.deselect_target()
	assert_eq(seq.get_state(),
			AttackSequenceState.State.TARGET_SELECT,
			"Should return to TARGET_SELECT")


# ---------------------------------------------------------------------------
# Dice pool gathering
# ---------------------------------------------------------------------------


func test_dice_pool_gathered_after_ship_target() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	var defender: ShipInstance = _make_defender()
	seq.select_ship_target(defender, Constants.HullZone.FRONT,
			"medium", false)
	var pool: AttackDicePool = seq.get_dice_pool()
	# FRONT battery: RED=2, BLUE=1 at medium → RED stays, BLUE stays.
	assert_true(pool.get_gathered_count() > 0,
			"Pool should not be empty for FRONT at medium range")


func test_dice_pool_gathered_after_squadron_target() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	var squad: RefCounted = _make_squadron()
	seq.select_squadron_target(squad, "close", false)
	var pool: AttackDicePool = seq.get_dice_pool()
	# Anti-squadron: BLUE=1 at close.
	assert_eq(pool.get_gathered_count(), 1,
			"Anti-squadron pool should have 1 die")


# ---------------------------------------------------------------------------
# CF dial prompt
# ---------------------------------------------------------------------------


func test_cf_dial_prompt_shown_when_available() -> void:
	var seq: AttackSequenceState = _make_state(true, false)  # CF dial.
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	var defender: ShipInstance = _make_defender()
	seq.select_ship_target(defender, Constants.HullZone.FRONT,
			"medium", false)
	assert_true(seq.should_show_cf_dial_prompt(),
			"CF dial prompt should be shown")


func test_cf_dial_prompt_not_shown_without_dial() -> void:
	var seq: AttackSequenceState = _make_state(false, false)  # No CF dial.
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	var defender: ShipInstance = _make_defender()
	seq.select_ship_target(defender, Constants.HullZone.FRONT,
			"medium", false)
	assert_false(seq.should_show_cf_dial_prompt(),
			"CF dial prompt should NOT be shown")


func test_add_cf_die_marks_decided() -> void:
	var seq: AttackSequenceState = _make_state(true, false)
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	var defender: ShipInstance = _make_defender()
	seq.select_ship_target(defender, Constants.HullZone.FRONT,
			"medium", false)
	var count_before: int = seq.get_dice_pool().get_gathered_count()
	var ok: bool = seq.add_cf_die("RED")
	assert_true(ok, "Should succeed adding CF die")
	assert_true(seq.is_cf_dial_decided(), "CF dial should be decided")
	assert_eq(seq.get_dice_pool().get_gathered_count(),
			count_before + 1, "Pool should have 1 more die")


func test_skip_cf_dial_marks_decided() -> void:
	var seq: AttackSequenceState = _make_state(true, false)
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	var defender: ShipInstance = _make_defender()
	seq.select_ship_target(defender, Constants.HullZone.FRONT,
			"medium", false)
	seq.skip_cf_dial()
	assert_true(seq.is_cf_dial_decided(),
			"CF dial should be decided after skip")
	assert_false(seq.should_show_cf_dial_prompt(),
			"Prompt should no longer show")


# ---------------------------------------------------------------------------
# roll_dice
# ---------------------------------------------------------------------------


func test_roll_dice_transitions_to_attack_effects() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	var defender: ShipInstance = _make_defender()
	seq.select_ship_target(defender, Constants.HullZone.FRONT,
			"medium", false)
	var results: Array[Dictionary] = seq.roll_dice()
	assert_eq(seq.get_state(),
			AttackSequenceState.State.ATTACK_EFFECTS,
			"Should transition to ATTACK_EFFECTS after rolling")
	assert_true(results.size() > 0, "Results should not be empty")


# ---------------------------------------------------------------------------
# finish_attack_effects → DEFENSE_TOKENS
# ---------------------------------------------------------------------------


func test_finish_attack_effects_transitions_to_defense_tokens() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	var defender: ShipInstance = _make_defender()
	seq.select_ship_target(defender, Constants.HullZone.FRONT,
			"medium", false)
	seq.roll_dice()
	seq.finish_attack_effects()
	assert_eq(seq.get_state(),
			AttackSequenceState.State.DEFENSE_TOKENS,
			"Should transition to DEFENSE_TOKENS")


# ---------------------------------------------------------------------------
# spend_defense_token
# ---------------------------------------------------------------------------


func test_spend_brace_token_succeeds() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	var defender: ShipInstance = _make_defender()
	seq.select_ship_target(defender, Constants.HullZone.FRONT,
			"medium", false)
	seq.roll_dice()
	seq.finish_attack_effects()
	# Defender has [EVADE(0), BRACE(1)].
	var ok: bool = seq.spend_defense_token(1)  # Brace.
	assert_true(ok, "Should succeed spending BRACE token")


func test_spend_same_type_twice_fails() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	# Defender with two brace tokens.
	var data: ShipData = ShipData.new()
	data.hull = 4
	data.max_speed = 2
	data.command_value = 2
	data.shields = {"FRONT": 3, "LEFT": 1, "RIGHT": 1, "REAR": 1}
	data.defense_tokens = ["BRACE", "BRACE"]
	data.navigation_chart = [[1], [0, 1]]
	var defender: ShipInstance = ShipInstance.create_from_data(
			"double_brace", data, 1, 1)
	seq.select_ship_target(defender, Constants.HullZone.FRONT,
			"medium", false)
	seq.roll_dice()
	seq.finish_attack_effects()
	var ok1: bool = seq.spend_defense_token(0)  # First brace.
	var ok2: bool = seq.spend_defense_token(1)  # Second brace — same type.
	assert_true(ok1, "First BRACE should succeed")
	assert_false(ok2, "Second BRACE (same type) should fail")


func test_spend_locked_token_fails() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	var defender: ShipInstance = _make_defender()
	seq.select_ship_target(defender, Constants.HullZone.FRONT,
			"medium", false)
	# Manually set a specific result with accuracy so we can lock a token.
	var pool: AttackDicePool = seq.get_dice_pool()
	pool._rolled_results = [
		{"color": Constants.DiceColor.BLUE,
				"face": Constants.DiceFace.ACCURACY, "removed": false},
		{"color": Constants.DiceColor.RED,
				"face": Constants.DiceFace.HIT, "removed": false},
	] as Array[Dictionary]
	pool._is_rolled = true
	seq._state = AttackSequenceState.State.ATTACK_EFFECTS
	# Spend accuracy on defender token 0 (EVADE).
	seq.spend_accuracy(0, 0)
	seq.finish_attack_effects()
	# Try to spend the locked token.
	var ok: bool = seq.spend_defense_token(0)
	assert_false(ok, "Locked token should not be spendable")


# ---------------------------------------------------------------------------
# finish_defense_and_resolve_damage
# ---------------------------------------------------------------------------


func test_resolve_damage_returns_result() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	var defender: ShipInstance = _make_defender(0)  # No shields.
	seq.select_ship_target(defender, Constants.HullZone.FRONT,
			"medium", false)
	# Force known dice results.
	var pool: AttackDicePool = seq.get_dice_pool()
	pool._rolled_results = [
		{"color": Constants.DiceColor.RED,
				"face": Constants.DiceFace.HIT, "removed": false},
		{"color": Constants.DiceColor.RED,
				"face": Constants.DiceFace.HIT, "removed": false},
	] as Array[Dictionary]
	pool._is_rolled = true
	seq._state = AttackSequenceState.State.ATTACK_EFFECTS
	seq.finish_attack_effects()
	var result: DamageResolver.DamageResult = \
			seq.finish_defense_and_resolve_damage()
	assert_not_null(result, "Damage result should not be null")
	assert_eq(result.raw_damage, 2, "Raw damage = 2")
	assert_eq(result.facedown_cards, 2,
			"2 facedown cards (no shields)")


# ---------------------------------------------------------------------------
# advance_after_damage — ship target → ATTACK_COMPLETE
# ---------------------------------------------------------------------------


func test_advance_after_damage_ship_goes_to_attack_complete() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	var defender: ShipInstance = _make_defender()
	seq.select_ship_target(defender, Constants.HullZone.FRONT,
			"medium", false)
	seq.roll_dice()
	seq.finish_attack_effects()
	seq.finish_defense_and_resolve_damage()
	var next: AttackSequenceState.State = seq.advance_after_damage()
	assert_eq(next, AttackSequenceState.State.ATTACK_COMPLETE,
			"Ship target → ATTACK_COMPLETE (no Step 6)")


# ---------------------------------------------------------------------------
# advance_after_damage — squadron target → ADDITIONAL_SQUAD_TARGET
# ---------------------------------------------------------------------------


func test_advance_after_damage_squad_goes_to_additional() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	var squad: RefCounted = _make_squadron()
	seq.select_squadron_target(squad, "close", false)
	seq.roll_dice()
	seq.finish_attack_effects()
	seq.finish_defense_and_resolve_damage()
	var next: AttackSequenceState.State = seq.advance_after_damage()
	assert_eq(next,
			AttackSequenceState.State.ADDITIONAL_SQUAD_TARGET,
			"Squadron target → ADDITIONAL_SQUAD_TARGET (Step 6)")


# ---------------------------------------------------------------------------
# skip_additional_squad_target → ATTACK_COMPLETE
# ---------------------------------------------------------------------------


func test_skip_additional_squad_goes_to_attack_complete() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	var squad: RefCounted = _make_squadron()
	seq.select_squadron_target(squad, "close", false)
	seq.roll_dice()
	seq.finish_attack_effects()
	seq.finish_defense_and_resolve_damage()
	seq.advance_after_damage()
	seq.skip_additional_squad_target()
	assert_eq(seq.get_state(),
			AttackSequenceState.State.ATTACK_COMPLETE,
			"Should be ATTACK_COMPLETE after skipping Step 6")


# ---------------------------------------------------------------------------
# advance_after_attack — second attack available
# ---------------------------------------------------------------------------


func test_advance_after_first_attack_offers_second() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	var defender: ShipInstance = _make_defender()
	seq.select_ship_target(defender, Constants.HullZone.FRONT,
			"medium", false)
	seq.roll_dice()
	seq.finish_attack_effects()
	seq.finish_defense_and_resolve_damage()
	seq.advance_after_damage()
	var next: AttackSequenceState.State = seq.advance_after_attack()
	assert_eq(next, AttackSequenceState.State.HULL_ZONE_SELECT,
			"Should offer second attack")


# ---------------------------------------------------------------------------
# advance_after_attack — all done after second
# ---------------------------------------------------------------------------


func test_all_done_after_two_attacks() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()

	# First attack.
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	var defender: ShipInstance = _make_defender()
	seq.select_ship_target(defender, Constants.HullZone.FRONT,
			"medium", false)
	seq.roll_dice()
	seq.finish_attack_effects()
	seq.finish_defense_and_resolve_damage()
	seq.advance_after_damage()
	seq.advance_after_attack()

	# Second attack.
	seq.select_attacking_zone(Constants.HullZone.LEFT)
	seq.select_ship_target(defender, Constants.HullZone.LEFT,
			"close", false)
	seq.roll_dice()
	seq.finish_attack_effects()
	seq.finish_defense_and_resolve_damage()
	seq.advance_after_damage()
	var next: AttackSequenceState.State = seq.advance_after_attack()

	assert_eq(next, AttackSequenceState.State.ALL_ATTACKS_DONE,
			"Should be ALL_ATTACKS_DONE after 2 attacks")
	assert_true(seq.is_all_done(), "is_all_done should return true")


# ---------------------------------------------------------------------------
# skip_remaining_attacks
# ---------------------------------------------------------------------------


func test_skip_remaining_attacks_sets_all_done() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()
	seq.skip_remaining_attacks()
	assert_true(seq.is_all_done(),
			"Should be ALL_ATTACKS_DONE after skipping")


# ---------------------------------------------------------------------------
# spend_accuracy locks defender token
# ---------------------------------------------------------------------------


func test_spend_accuracy_locks_and_removes_die() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	var defender: ShipInstance = _make_defender()
	seq.select_ship_target(defender, Constants.HullZone.FRONT,
			"medium", false)
	# Force results with accuracy.
	var pool: AttackDicePool = seq.get_dice_pool()
	pool._rolled_results = [
		{"color": Constants.DiceColor.BLUE,
				"face": Constants.DiceFace.ACCURACY, "removed": false},
		{"color": Constants.DiceColor.RED,
				"face": Constants.DiceFace.HIT, "removed": false},
	] as Array[Dictionary]
	pool._is_rolled = true
	seq._state = AttackSequenceState.State.ATTACK_EFFECTS
	var ok: bool = seq.spend_accuracy(0, 1)  # Lock defender token 1.
	assert_true(ok, "Should succeed")
	assert_true(seq.get_defense_resolver().is_token_locked(1),
			"Defender token 1 should be locked")


# ---------------------------------------------------------------------------
# obstruction die removal
# ---------------------------------------------------------------------------


func test_remove_obstruction_die_succeeds() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	var defender: ShipInstance = _make_defender()
	seq.select_ship_target(defender, Constants.HullZone.FRONT,
			"medium", true)  # Obstructed.
	var count_before: int = seq.get_dice_pool().get_gathered_count()
	var ok: bool = seq.remove_obstruction_die("RED")
	assert_true(ok, "Should succeed removing obstruction die")
	assert_eq(seq.get_dice_pool().get_gathered_count(),
			count_before - 1, "Pool should have 1 fewer die")


# ---------------------------------------------------------------------------
# CF reroll (token)
# ---------------------------------------------------------------------------


func test_cf_reroll_succeeds_with_token() -> void:
	var seq: AttackSequenceState = _make_state(false, true)  # CF token.
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	var defender: ShipInstance = _make_defender()
	seq.select_ship_target(defender, Constants.HullZone.FRONT,
			"medium", false)
	# Force results.
	var pool: AttackDicePool = seq.get_dice_pool()
	pool._rolled_results = [
		{"color": Constants.DiceColor.RED,
				"face": Constants.DiceFace.BLANK, "removed": false},
		{"color": Constants.DiceColor.BLUE,
				"face": Constants.DiceFace.HIT, "removed": false},
	] as Array[Dictionary]
	pool._is_rolled = true
	seq._state = AttackSequenceState.State.ATTACK_EFFECTS
	var face: Constants.DiceFace = seq.cf_reroll(0)
	# We can't predict the reroll face, but it should have run.
	assert_true(pool.is_cf_reroll_used(),
			"CF reroll should be marked as used")


func test_cf_reroll_fails_without_token() -> void:
	var seq: AttackSequenceState = _make_state(false, false)  # No CF token.
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	var defender: ShipInstance = _make_defender()
	seq.select_ship_target(defender, Constants.HullZone.FRONT,
			"medium", false)
	seq.roll_dice()
	var face: Constants.DiceFace = seq.cf_reroll(0)
	assert_eq(face, Constants.DiceFace.BLANK,
			"Should return BLANK when no CF token")


# ---------------------------------------------------------------------------
# Select additional squad target — Step 6
# ---------------------------------------------------------------------------


func test_select_additional_squad_target_works() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	var squad1: RefCounted = _make_squadron()
	seq.select_squadron_target(squad1, "close", false)
	seq.roll_dice()
	seq.finish_attack_effects()
	seq.finish_defense_and_resolve_damage()
	seq.advance_after_damage()
	# Now in ADDITIONAL_SQUAD_TARGET.
	var squad2: RefCounted = _make_squadron()
	var ok: bool = seq.select_additional_squad_target(
			squad2, "close", false)
	assert_true(ok, "Should succeed selecting new squad target")
	assert_eq(seq.get_state(),
			AttackSequenceState.State.DICE_POOL_PREVIEW,
			"Should return to DICE_POOL_PREVIEW for new target")


func test_select_same_squad_target_fails() -> void:
	var seq: AttackSequenceState = _make_state()
	seq.begin_attacks()
	seq.select_attacking_zone(Constants.HullZone.FRONT)
	var squad1: RefCounted = _make_squadron()
	seq.select_squadron_target(squad1, "close", false)
	seq.roll_dice()
	seq.finish_attack_effects()
	seq.finish_defense_and_resolve_damage()
	seq.advance_after_damage()
	# Try to target the same squadron.
	var ok: bool = seq.select_additional_squad_target(
			squad1, "close", false)
	assert_false(ok, "Same squadron should be rejected in Step 6")
