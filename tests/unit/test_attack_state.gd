## Test: AttackState
##
## Unit tests for [AttackState] — shared attack-flow state holder.
## Validates default values, lifecycle methods (clear_all, clear_attacker,
## clear_defender, reset_dice, reset_for_next_attack, reset_deferred_damage),
## and query helpers.
extends GutTest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Creates a fresh [AttackState] with some fields dirtied for reset testing.
func _dirty_state() -> AttackState:
	var s: AttackState = AttackState.new()
	# Execution mode
	s.exec_mode = true
	s.squad_exec_mode = true
	# Attacker identity
	s.attacker_zone = Constants.HullZone.FRONT
	s.attacker_name = "VSD"
	s.attacker_zone_name = "FRONT"
	# Defender identity
	s.defender_zone = Constants.HullZone.REAR
	s.defender_name = "CR90"
	s.defender_zone_name = "REAR"
	# Attack tracking
	s.fired_zones.append(Constants.HullZone.FRONT)
	s.current_attack = 1
	# Dice
	s.dice_results.append({"face": "hit"})
	s.dice_pool["red"] = 2
	s.range_band = "close"
	s.cf_dial_used = true
	s.cf_token_used = true
	# Defense
	s.locked_tokens.append(0)
	s.accuracy_step = true
	s.defense_step = true
	s.spent_tokens[Constants.DefenseToken.BRACE] = 1
	s.defense_commit_queue.append(0)
	s.modified_damage = 3
	s.scatter_used = true
	s.redirect_remaining = 2
	s.redirect_zone = Constants.HullZone.LEFT
	s.contain_used = true
	s.brace_used = true
	s.redirect_step = true
	s.evade_step = true
	s.obstructed = true
	s.obstruction_step = true
	# Deferred damage
	s.awaiting_damage_summary = true
	return s


# ---------------------------------------------------------------------------
# Default values
# ---------------------------------------------------------------------------

func test_new_state_exec_mode_defaults() -> void:
	var s: AttackState = AttackState.new()
	assert_false(s.exec_mode, "exec_mode defaults to false")
	assert_false(s.squad_exec_mode, "squad_exec_mode defaults to false")
	assert_null(s.exec_ship_token, "exec_ship_token defaults to null")
	assert_null(s.exec_squad_token, "exec_squad_token defaults to null")


func test_new_state_attacker_defaults() -> void:
	var s: AttackState = AttackState.new()
	assert_null(s.attacker_ship, "attacker_ship defaults to null")
	assert_eq(s.attacker_zone, -1, "attacker_zone defaults to -1")
	assert_null(s.attacker_squadron, "attacker_squadron defaults to null")
	assert_eq(s.attacker_name, "", "attacker_name defaults to empty")
	assert_eq(s.attacker_zone_name, "", "attacker_zone_name defaults to empty")


func test_new_state_defender_defaults() -> void:
	var s: AttackState = AttackState.new()
	assert_null(s.defender_ship, "defender_ship defaults to null")
	assert_eq(s.defender_zone, -1, "defender_zone defaults to -1")
	assert_null(s.defender_squadron, "defender_squadron defaults to null")
	assert_eq(s.defender_name, "", "defender_name defaults to empty")
	assert_eq(s.defender_zone_name, "", "defender_zone_name defaults to empty")


func test_new_state_attack_tracking_defaults() -> void:
	var s: AttackState = AttackState.new()
	assert_eq(s.fired_zones.size(), 0, "fired_zones defaults to empty")
	assert_eq(s.current_attack, 0, "current_attack defaults to 0")
	assert_eq(s.attacked_squads.size(), 0, "attacked_squads defaults to empty")


func test_new_state_dice_defaults() -> void:
	var s: AttackState = AttackState.new()
	assert_eq(s.dice_results.size(), 0, "dice_results defaults to empty")
	assert_eq(s.dice_pool.size(), 0, "dice_pool defaults to empty")
	assert_eq(s.range_band, "", "range_band defaults to empty")
	assert_false(s.cf_dial_used, "cf_dial_used defaults to false")
	assert_false(s.cf_token_used, "cf_token_used defaults to false")


func test_new_state_defense_defaults() -> void:
	var s: AttackState = AttackState.new()
	assert_eq(s.locked_tokens.size(), 0, "locked_tokens defaults to empty")
	assert_false(s.accuracy_step, "accuracy_step defaults to false")
	assert_false(s.defense_step, "defense_step defaults to false")
	assert_eq(s.spent_tokens.size(), 0, "spent_tokens defaults to empty")
	assert_eq(s.defense_commit_queue.size(), 0, "defense_commit_queue defaults to empty")
	assert_eq(s.modified_damage, 0, "modified_damage defaults to 0")
	assert_false(s.scatter_used, "scatter_used defaults to false")
	assert_eq(s.redirect_remaining, 0, "redirect_remaining defaults to 0")
	assert_eq(s.redirect_zone, -1, "redirect_zone defaults to -1")
	assert_false(s.contain_used, "contain_used defaults to false")
	assert_false(s.brace_used, "brace_used defaults to false")
	assert_false(s.redirect_step, "redirect_step defaults to false")
	assert_false(s.evade_step, "evade_step defaults to false")
	assert_false(s.obstructed, "obstructed defaults to false")
	assert_false(s.obstruction_step, "obstruction_step defaults to false")


func test_new_state_deferred_damage_defaults() -> void:
	var s: AttackState = AttackState.new()
	assert_false(s.awaiting_damage_summary, "awaiting_damage_summary defaults to false")
	assert_null(s.deferred_immediate_card, "deferred_immediate_card defaults to null")
	assert_null(s.deferred_immediate_ship, "deferred_immediate_ship defaults to null")


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

func test_is_exec_active_false_by_default() -> void:
	var s: AttackState = AttackState.new()
	assert_false(s.is_exec_active(), "is_exec_active should be false by default")


func test_is_exec_active_true_when_exec_mode() -> void:
	var s: AttackState = AttackState.new()
	s.exec_mode = true
	assert_true(s.is_exec_active(), "is_exec_active should be true when exec_mode is set")


func test_is_squad_attack_false_by_default() -> void:
	var s: AttackState = AttackState.new()
	assert_false(s.is_squad_attack(), "is_squad_attack should be false by default")


func test_is_squad_attack_true_when_squad_mode() -> void:
	var s: AttackState = AttackState.new()
	s.squad_exec_mode = true
	assert_true(s.is_squad_attack(), "is_squad_attack should be true when squad_exec_mode is set")


func test_has_attacker_false_when_empty() -> void:
	var s: AttackState = AttackState.new()
	assert_false(s.has_attacker(), "has_attacker should be false when no ship or squadron set")


func test_has_defender_false_when_empty() -> void:
	var s: AttackState = AttackState.new()
	assert_false(s.has_defender(), "has_defender should be false when no ship or squadron set")


# ---------------------------------------------------------------------------
# clear_attacker
# ---------------------------------------------------------------------------

func test_clear_attacker_resets_attacker_fields() -> void:
	var s: AttackState = _dirty_state()
	s.clear_attacker()
	assert_null(s.attacker_ship, "attacker_ship should be null after clear_attacker")
	assert_eq(s.attacker_zone, -1, "attacker_zone should be -1 after clear_attacker")
	assert_null(s.attacker_squadron, "attacker_squadron should be null after clear_attacker")
	assert_eq(s.attacker_name, "", "attacker_name should be empty after clear_attacker")
	assert_eq(s.attacker_zone_name, "", "attacker_zone_name should be empty after clear_attacker")


func test_clear_attacker_preserves_defender() -> void:
	var s: AttackState = _dirty_state()
	s.clear_attacker()
	assert_eq(s.defender_name, "CR90", "defender_name should be preserved after clear_attacker")
	assert_eq(s.defender_zone, Constants.HullZone.REAR, "defender_zone should be preserved")


func test_clear_attacker_preserves_exec_mode() -> void:
	var s: AttackState = _dirty_state()
	s.clear_attacker()
	assert_true(s.exec_mode, "exec_mode should be preserved after clear_attacker")


# ---------------------------------------------------------------------------
# clear_defender
# ---------------------------------------------------------------------------

func test_clear_defender_resets_defender_fields() -> void:
	var s: AttackState = _dirty_state()
	s.clear_defender()
	assert_null(s.defender_ship, "defender_ship should be null after clear_defender")
	assert_eq(s.defender_zone, -1, "defender_zone should be -1 after clear_defender")
	assert_null(s.defender_squadron, "defender_squadron should be null after clear_defender")
	assert_eq(s.defender_name, "", "defender_name should be empty after clear_defender")
	assert_eq(s.defender_zone_name, "", "defender_zone_name should be empty after clear_defender")


func test_clear_defender_preserves_attacker() -> void:
	var s: AttackState = _dirty_state()
	s.clear_defender()
	assert_eq(s.attacker_name, "VSD", "attacker_name should be preserved after clear_defender")
	assert_eq(s.attacker_zone, Constants.HullZone.FRONT, "attacker_zone should be preserved")


# ---------------------------------------------------------------------------
# reset_dice
# ---------------------------------------------------------------------------

func test_reset_dice_clears_dice_fields() -> void:
	var s: AttackState = _dirty_state()
	s.reset_dice()
	assert_eq(s.dice_results.size(), 0, "dice_results should be empty after reset_dice")
	assert_eq(s.dice_pool.size(), 0, "dice_pool should be empty after reset_dice")
	assert_eq(s.range_band, "", "range_band should be empty after reset_dice")


func test_reset_dice_preserves_cf_flags() -> void:
	var s: AttackState = _dirty_state()
	s.reset_dice()
	assert_true(s.cf_dial_used, "cf_dial_used should be preserved after reset_dice")
	assert_true(s.cf_token_used, "cf_token_used should be preserved after reset_dice")


func test_reset_dice_preserves_defense_state() -> void:
	var s: AttackState = _dirty_state()
	s.reset_dice()
	assert_eq(s.modified_damage, 3, "modified_damage should be preserved after reset_dice")
	assert_true(s.brace_used, "brace_used should be preserved after reset_dice")


# ---------------------------------------------------------------------------
# reset_deferred_damage
# ---------------------------------------------------------------------------

func test_reset_deferred_damage_clears_deferred_fields() -> void:
	var s: AttackState = _dirty_state()
	s.reset_deferred_damage()
	assert_false(s.awaiting_damage_summary, "awaiting_damage_summary should be false")
	assert_null(s.deferred_immediate_card, "deferred_immediate_card should be null")
	assert_null(s.deferred_immediate_ship, "deferred_immediate_ship should be null")


func test_reset_deferred_damage_preserves_defense_state() -> void:
	var s: AttackState = _dirty_state()
	s.reset_deferred_damage()
	assert_eq(s.modified_damage, 3, "modified_damage should be preserved")
	assert_true(s.scatter_used, "scatter_used should be preserved")


# ---------------------------------------------------------------------------
# reset_for_next_attack
# ---------------------------------------------------------------------------

func test_reset_for_next_attack_clears_defender() -> void:
	var s: AttackState = _dirty_state()
	s.reset_for_next_attack()
	assert_eq(s.defender_name, "", "defender_name should be empty after reset_for_next_attack")
	assert_eq(s.defender_zone, -1, "defender_zone should be -1 after reset_for_next_attack")


func test_reset_for_next_attack_clears_dice() -> void:
	var s: AttackState = _dirty_state()
	s.reset_for_next_attack()
	assert_eq(s.dice_results.size(), 0, "dice_results should be empty after reset_for_next_attack")
	assert_eq(s.dice_pool.size(), 0, "dice_pool should be empty after reset_for_next_attack")
	assert_eq(s.range_band, "", "range_band should be empty after reset_for_next_attack")


func test_reset_for_next_attack_clears_attacked_squads() -> void:
	var s: AttackState = _dirty_state()
	s.attacked_squads.append(null)  # placeholder
	s.reset_for_next_attack()
	assert_eq(s.attacked_squads.size(), 0, "attacked_squads should be empty after reset_for_next_attack")


func test_reset_for_next_attack_preserves_attacker() -> void:
	var s: AttackState = _dirty_state()
	s.reset_for_next_attack()
	assert_eq(s.attacker_name, "VSD", "attacker_name should be preserved after reset_for_next_attack")
	assert_eq(s.attacker_zone, Constants.HullZone.FRONT, "attacker_zone should be preserved")


func test_reset_for_next_attack_preserves_fired_zones() -> void:
	var s: AttackState = _dirty_state()
	s.reset_for_next_attack()
	assert_eq(s.fired_zones.size(), 1, "fired_zones should be preserved after reset_for_next_attack")
	assert_eq(s.fired_zones[0], Constants.HullZone.FRONT, "fired_zones entry should be preserved")


func test_reset_for_next_attack_preserves_cf_usage() -> void:
	var s: AttackState = _dirty_state()
	s.reset_for_next_attack()
	assert_true(s.cf_dial_used, "cf_dial_used should be preserved after reset_for_next_attack")
	assert_true(s.cf_token_used, "cf_token_used should be preserved after reset_for_next_attack")


func test_reset_for_next_attack_preserves_current_attack() -> void:
	var s: AttackState = _dirty_state()
	s.reset_for_next_attack()
	assert_eq(s.current_attack, 1, "current_attack should be preserved after reset_for_next_attack")


# ---------------------------------------------------------------------------
# clear_all
# ---------------------------------------------------------------------------

func test_clear_all_resets_exec_mode() -> void:
	var s: AttackState = _dirty_state()
	s.clear_all()
	assert_false(s.exec_mode, "exec_mode should be false after clear_all")
	assert_false(s.squad_exec_mode, "squad_exec_mode should be false after clear_all")
	assert_null(s.exec_ship_token, "exec_ship_token should be null after clear_all")
	assert_null(s.exec_squad_token, "exec_squad_token should be null after clear_all")


func test_clear_all_resets_attacker() -> void:
	var s: AttackState = _dirty_state()
	s.clear_all()
	assert_eq(s.attacker_name, "", "attacker_name should be empty after clear_all")
	assert_eq(s.attacker_zone, -1, "attacker_zone should be -1 after clear_all")


func test_clear_all_resets_defender() -> void:
	var s: AttackState = _dirty_state()
	s.clear_all()
	assert_eq(s.defender_name, "", "defender_name should be empty after clear_all")
	assert_eq(s.defender_zone, -1, "defender_zone should be -1 after clear_all")


func test_clear_all_resets_attack_tracking() -> void:
	var s: AttackState = _dirty_state()
	s.clear_all()
	assert_eq(s.fired_zones.size(), 0, "fired_zones should be empty after clear_all")
	assert_eq(s.current_attack, 0, "current_attack should be 0 after clear_all")
	assert_eq(s.attacked_squads.size(), 0, "attacked_squads should be empty after clear_all")


func test_clear_all_resets_dice() -> void:
	var s: AttackState = _dirty_state()
	s.clear_all()
	assert_eq(s.dice_results.size(), 0, "dice_results should be empty after clear_all")
	assert_eq(s.dice_pool.size(), 0, "dice_pool should be empty after clear_all")
	assert_eq(s.range_band, "", "range_band should be empty after clear_all")
	assert_false(s.cf_dial_used, "cf_dial_used should be false after clear_all")
	assert_false(s.cf_token_used, "cf_token_used should be false after clear_all")


func test_clear_all_resets_defense() -> void:
	var s: AttackState = _dirty_state()
	s.clear_all()
	assert_eq(s.locked_tokens.size(), 0, "locked_tokens should be empty after clear_all")
	assert_false(s.accuracy_step, "accuracy_step should be false after clear_all")
	assert_false(s.defense_step, "defense_step should be false after clear_all")
	assert_eq(s.spent_tokens.size(), 0, "spent_tokens should be empty after clear_all")
	assert_eq(s.defense_commit_queue.size(), 0, "defense_commit_queue should be empty after clear_all")
	assert_eq(s.modified_damage, 0, "modified_damage should be 0 after clear_all")
	assert_false(s.scatter_used, "scatter_used should be false after clear_all")
	assert_eq(s.redirect_remaining, 0, "redirect_remaining should be 0 after clear_all")
	assert_eq(s.redirect_zone, -1, "redirect_zone should be -1 after clear_all")
	assert_false(s.contain_used, "contain_used should be false after clear_all")
	assert_false(s.brace_used, "brace_used should be false after clear_all")
	assert_false(s.redirect_step, "redirect_step should be false after clear_all")
	assert_false(s.evade_step, "evade_step should be false after clear_all")
	assert_false(s.obstructed, "obstructed should be false after clear_all")
	assert_false(s.obstruction_step, "obstruction_step should be false after clear_all")


func test_clear_all_resets_deferred_damage() -> void:
	var s: AttackState = _dirty_state()
	s.clear_all()
	assert_false(s.awaiting_damage_summary, "awaiting_damage_summary should be false after clear_all")
	assert_null(s.deferred_immediate_card, "deferred_immediate_card should be null after clear_all")
	assert_null(s.deferred_immediate_ship, "deferred_immediate_ship should be null after clear_all")


# ---------------------------------------------------------------------------
# Queries after clear_all
# ---------------------------------------------------------------------------

func test_queries_false_after_clear_all() -> void:
	var s: AttackState = _dirty_state()
	s.clear_all()
	assert_false(s.is_exec_active(), "is_exec_active should be false after clear_all")
	assert_false(s.is_squad_attack(), "is_squad_attack should be false after clear_all")
	assert_false(s.has_attacker(), "has_attacker should be false after clear_all")
	assert_false(s.has_defender(), "has_defender should be false after clear_all")
