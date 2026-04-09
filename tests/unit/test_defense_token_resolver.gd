## Test: DefenseTokenResolver
##
## Unit tests for [DefenseTokenResolver] — pure-computation helper that
## resolves defense token availability, spend-method resolution, token
## effects (scatter, brace, evade, redirect), canonical sorting, and
## faceup-card determination.
##
## Extracted from AttackExecutor as part of refactoring step F4c.
## Rules Reference: "Defense Tokens", p.5; individual token entries.
extends GutTest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

var _resolver: DefenseTokenResolver


func before_each() -> void:
	_resolver = DefenseTokenResolver.new()


## Creates a minimal ShipInstance with the given defense tokens and speed.
## [param token_names] — Array of String names ("Brace", "Redirect", etc.).
## [param speed] — current speed (default 2).
## [param shields] — optional shield dictionary override.
func _make_defender(token_names: Array = [],
		speed: int = 2,
		shields: Dictionary = {
			"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1,
		}) -> ShipInstance:
	var data: ShipData = ShipData.new()
	data.ship_name = "Test Defender"
	data.hull = 5
	data.shields = shields
	data.max_speed = 3
	data.command_value = 2
	data.defense_tokens = token_names
	var inst: ShipInstance = ShipInstance.create_from_data(
			"test_def", data, speed, 0)
	return inst


## Creates a minimal ShipInstance for use as an attacker (no tokens needed).
func _make_attacker() -> ShipInstance:
	var data: ShipData = ShipData.new()
	data.ship_name = "Test Attacker"
	data.hull = 4
	data.shields = {"FRONT": 2, "LEFT": 1, "RIGHT": 1, "REAR": 1}
	data.max_speed = 3
	data.command_value = 2
	data.defense_tokens = []
	return ShipInstance.create_from_data("test_atk", data, 2, 1)


## Creates a token Dictionary matching the format used by ShipInstance.
func _make_token(type: Constants.DefenseToken,
		state: Constants.DefenseTokenState = \
		Constants.DefenseTokenState.READY) -> Dictionary:
	return {"type": type, "state": state}


# =========================================================================
# count_lockable_tokens
# =========================================================================

func test_count_lockable_tokens_all_ready() -> void:
	var def: ShipInstance = _make_defender(["Brace", "Redirect", "Evade"])
	var result: int = _resolver.count_lockable_tokens(def)
	assert_eq(result, 3,
			"All ready tokens should be lockable")


func test_count_lockable_tokens_one_discarded() -> void:
	var def: ShipInstance = _make_defender(["Brace", "Redirect", "Evade"])
	def.defense_tokens[1]["state"] = Constants.DefenseTokenState.DISCARDED
	var result: int = _resolver.count_lockable_tokens(def)
	assert_eq(result, 2,
			"Discarded token should not be lockable")


func test_count_lockable_tokens_exhausted_still_lockable() -> void:
	var def: ShipInstance = _make_defender(["Brace", "Redirect"])
	def.defense_tokens[0]["state"] = Constants.DefenseTokenState.EXHAUSTED
	var result: int = _resolver.count_lockable_tokens(def)
	assert_eq(result, 2,
			"Exhausted tokens should still be lockable")


func test_count_lockable_tokens_all_discarded() -> void:
	var def: ShipInstance = _make_defender(["Brace", "Redirect"])
	def.defense_tokens[0]["state"] = Constants.DefenseTokenState.DISCARDED
	def.defense_tokens[1]["state"] = Constants.DefenseTokenState.DISCARDED
	var result: int = _resolver.count_lockable_tokens(def)
	assert_eq(result, 0,
			"All discarded tokens should return 0")


func test_count_lockable_tokens_no_tokens() -> void:
	var def: ShipInstance = _make_defender([])
	var result: int = _resolver.count_lockable_tokens(def)
	assert_eq(result, 0,
			"No tokens should return 0")


# =========================================================================
# can_spend_tokens
# =========================================================================

func test_can_spend_tokens_ready_tokens_speed_nonzero() -> void:
	var def: ShipInstance = _make_defender(["Brace", "Evade"], 2)
	var result: bool = _resolver.can_spend_tokens(
			def, [], null, Constants.HullZone.FRONT)
	assert_true(result,
			"Should allow spending with ready tokens and speed > 0")


func test_can_spend_tokens_speed_zero_returns_false() -> void:
	var def: ShipInstance = _make_defender(["Brace", "Evade"], 0)
	var result: bool = _resolver.can_spend_tokens(
			def, [], null, Constants.HullZone.FRONT)
	assert_false(result,
			"Speed 0 defender should not be able to spend tokens")


func test_can_spend_tokens_no_tokens_returns_false() -> void:
	var def: ShipInstance = _make_defender([], 2)
	var result: bool = _resolver.can_spend_tokens(
			def, [], null, Constants.HullZone.FRONT)
	assert_false(result,
			"No tokens should return false")


func test_can_spend_tokens_all_locked_returns_false() -> void:
	var def: ShipInstance = _make_defender(["Brace", "Evade"], 2)
	var locked: Array[int] = [0, 1]
	var result: bool = _resolver.can_spend_tokens(
			def, locked, null, Constants.HullZone.FRONT)
	assert_false(result,
			"All tokens locked should return false")


func test_can_spend_tokens_one_locked_one_free() -> void:
	var def: ShipInstance = _make_defender(["Brace", "Evade"], 2)
	var locked: Array[int] = [0]
	var result: bool = _resolver.can_spend_tokens(
			def, locked, null, Constants.HullZone.FRONT)
	assert_true(result,
			"One free token should allow spending")


func test_can_spend_tokens_all_discarded_returns_false() -> void:
	var def: ShipInstance = _make_defender(["Brace"], 2)
	def.defense_tokens[0]["state"] = Constants.DefenseTokenState.DISCARDED
	var result: bool = _resolver.can_spend_tokens(
			def, [], null, Constants.HullZone.FRONT)
	assert_false(result,
			"All discarded tokens should return false")


# =========================================================================
# count_spendable_tokens
# =========================================================================

func test_count_spendable_all_ready() -> void:
	var def: ShipInstance = _make_defender(["Brace", "Evade", "Redirect"])
	var result: int = _resolver.count_spendable_tokens(
			def, [], null, Constants.HullZone.FRONT)
	assert_eq(result, 3,
			"All ready tokens should be spendable")


func test_count_spendable_skips_locked() -> void:
	var def: ShipInstance = _make_defender(["Brace", "Evade", "Redirect"])
	var locked: Array[int] = [1]
	var result: int = _resolver.count_spendable_tokens(
			def, locked, null, Constants.HullZone.FRONT)
	assert_eq(result, 2,
			"Locked token should be skipped")


func test_count_spendable_skips_discarded() -> void:
	var def: ShipInstance = _make_defender(["Brace", "Evade"])
	def.defense_tokens[0]["state"] = Constants.DefenseTokenState.DISCARDED
	var result: int = _resolver.count_spendable_tokens(
			def, [], null, Constants.HullZone.FRONT)
	assert_eq(result, 1,
			"Discarded token should be skipped")


# =========================================================================
# is_token_spendable
# =========================================================================

func test_is_token_spendable_ready_token() -> void:
	var def: ShipInstance = _make_defender(["Brace"])
	var token: Dictionary = def.defense_tokens[0]
	var result: bool = _resolver.is_token_spendable(
			0, token, {}, [], def, null, Constants.HullZone.FRONT)
	assert_true(result,
			"Ready, unlocked, unspent token should be spendable")


func test_is_token_spendable_discarded_returns_false() -> void:
	var def: ShipInstance = _make_defender(["Brace"])
	def.defense_tokens[0]["state"] = Constants.DefenseTokenState.DISCARDED
	var token: Dictionary = def.defense_tokens[0]
	var result: bool = _resolver.is_token_spendable(
			0, token, {}, [], def, null, Constants.HullZone.FRONT)
	assert_false(result,
			"Discarded token should not be spendable")


func test_is_token_spendable_already_spent_type_returns_false() -> void:
	var def: ShipInstance = _make_defender(["Brace"])
	var token: Dictionary = def.defense_tokens[0]
	var spent: Dictionary = {Constants.DefenseToken.BRACE: "exhaust"}
	var result: bool = _resolver.is_token_spendable(
			0, token, spent, [], def, null, Constants.HullZone.FRONT)
	assert_false(result,
			"Already spent type should not be spendable again")


func test_is_token_spendable_locked_returns_false() -> void:
	var def: ShipInstance = _make_defender(["Brace"])
	var token: Dictionary = def.defense_tokens[0]
	var locked: Array[int] = [0]
	var result: bool = _resolver.is_token_spendable(
			0, token, {}, locked, def, null, Constants.HullZone.FRONT)
	assert_false(result,
			"Locked token should not be spendable")


func test_is_token_spendable_exhausted_is_still_spendable() -> void:
	var def: ShipInstance = _make_defender(["Brace"])
	def.defense_tokens[0]["state"] = Constants.DefenseTokenState.EXHAUSTED
	var token: Dictionary = def.defense_tokens[0]
	var result: bool = _resolver.is_token_spendable(
			0, token, {}, [], def, null, Constants.HullZone.FRONT)
	assert_true(result,
			"Exhausted token should be spendable (will be discarded)")


# =========================================================================
# is_token_blocked_by_effect
# =========================================================================

func test_is_token_blocked_null_registry_returns_false() -> void:
	var def: ShipInstance = _make_defender(["Brace"])
	var token: Dictionary = def.defense_tokens[0]
	var result: bool = _resolver.is_token_blocked_by_effect(
			def, token, null, Constants.HullZone.FRONT)
	assert_false(result,
			"Null registry should never block")


func test_is_token_blocked_null_instance_returns_false() -> void:
	var registry: EffectRegistry = EffectRegistry.new()
	var token: Dictionary = _make_token(Constants.DefenseToken.BRACE)
	var result: bool = _resolver.is_token_blocked_by_effect(
			null, token, registry, Constants.HullZone.FRONT)
	assert_false(result,
			"Null instance should never block")


func test_is_token_blocked_empty_registry_returns_false() -> void:
	var def: ShipInstance = _make_defender(["Brace"])
	var registry: EffectRegistry = EffectRegistry.new()
	var token: Dictionary = def.defense_tokens[0]
	var result: bool = _resolver.is_token_blocked_by_effect(
			def, token, registry, Constants.HullZone.FRONT)
	assert_false(result,
			"Empty registry should not block")


# =========================================================================
# resolve_spend_method
# =========================================================================

func test_resolve_spend_method_ready_exhaust() -> void:
	var token: Dictionary = _make_token(
			Constants.DefenseToken.BRACE,
			Constants.DefenseTokenState.READY)
	var result: String = _resolver.resolve_spend_method("exhaust", token)
	assert_eq(result, "exhaust",
			"Ready token with exhaust should stay exhaust")


func test_resolve_spend_method_ready_discard() -> void:
	var token: Dictionary = _make_token(
			Constants.DefenseToken.BRACE,
			Constants.DefenseTokenState.READY)
	var result: String = _resolver.resolve_spend_method("discard", token)
	assert_eq(result, "discard",
			"Ready token with discard should stay discard")


func test_resolve_spend_method_exhausted_forces_discard() -> void:
	var token: Dictionary = _make_token(
			Constants.DefenseToken.BRACE,
			Constants.DefenseTokenState.EXHAUSTED)
	var result: String = _resolver.resolve_spend_method("exhaust", token)
	assert_eq(result, "discard",
			"Exhausted token must be discarded regardless of input")


# =========================================================================
# apply_scatter
# =========================================================================

func test_apply_scatter_cancels_all_damage() -> void:
	var result: int = _resolver.apply_scatter(6)
	assert_eq(result, 0,
			"Scatter should cancel all damage to 0")


func test_apply_scatter_on_zero_damage() -> void:
	var result: int = _resolver.apply_scatter(0)
	assert_eq(result, 0,
			"Scatter on 0 damage should return 0")


# =========================================================================
# apply_brace
# =========================================================================

func test_apply_brace_halves_even_damage() -> void:
	var result: int = _resolver.apply_brace(4)
	assert_eq(result, 2,
			"Brace should halve 4 damage to 2")


func test_apply_brace_halves_odd_damage_rounds_up() -> void:
	var result: int = _resolver.apply_brace(5)
	assert_eq(result, 3,
			"Brace should halve 5 damage to 3 (ceil)")


func test_apply_brace_on_one_damage() -> void:
	var result: int = _resolver.apply_brace(1)
	assert_eq(result, 1,
			"Brace should halve 1 damage to 1 (ceil)")


func test_apply_brace_on_zero_damage() -> void:
	var result: int = _resolver.apply_brace(0)
	assert_eq(result, 0,
			"Brace on 0 damage should return 0")


# =========================================================================
# apply_evade_remove
# =========================================================================

func test_apply_evade_remove_removes_die() -> void:
	var dice: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT},
		{"color": Constants.DiceColor.BLUE, "face": Constants.DiceFace.HIT},
	]
	var result: Dictionary = _resolver.apply_evade_remove(
			0, dice, null, null)
	assert_eq(result["dice_results"].size(), 1,
			"Should have 1 die after removal")
	assert_eq(result["damage"], 1,
			"Damage should be 1 after removing 1-hit die")


func test_apply_evade_remove_invalid_index_no_change() -> void:
	var dice: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT},
	]
	var result: Dictionary = _resolver.apply_evade_remove(
			5, dice, null, null)
	assert_eq(result["dice_results"].size(), 1,
			"Invalid index should not remove any die")


func test_apply_evade_remove_does_not_mutate_original() -> void:
	var dice: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT},
		{"color": Constants.DiceColor.BLUE, "face": Constants.DiceFace.HIT},
	]
	var _result: Dictionary = _resolver.apply_evade_remove(
			0, dice, null, null)
	assert_eq(dice.size(), 2,
			"Original dice array should not be mutated")


# =========================================================================
# apply_evade_reroll
# =========================================================================

func test_apply_evade_reroll_returns_new_face() -> void:
	var dice: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT},
	]
	var result: Dictionary = _resolver.apply_evade_reroll(
			0, dice, null, null)
	assert_has(result, "new_face",
			"Result should contain new_face key")
	assert_eq(result["dice_results"].size(), 1,
			"Dice count should not change after reroll")


func test_apply_evade_reroll_does_not_mutate_original() -> void:
	var dice: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT},
	]
	var _result: Dictionary = _resolver.apply_evade_reroll(
			0, dice, null, null)
	assert_eq(dice[0]["face"], Constants.DiceFace.HIT,
			"Original dice should not be mutated")


func test_apply_evade_reroll_invalid_index_no_change() -> void:
	var dice: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT},
	]
	var result: Dictionary = _resolver.apply_evade_reroll(
			-1, dice, null, null)
	assert_eq(result["dice_results"].size(), 1,
			"Invalid index should return unchanged dice")


# =========================================================================
# can_redirect_to_zone
# =========================================================================

func test_can_redirect_zone_has_shields() -> void:
	var def: ShipInstance = _make_defender(
			["Redirect"], 2, {"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1})
	var result: bool = _resolver.can_redirect_to_zone(
			Constants.HullZone.LEFT, def, 2)
	assert_true(result,
			"Zone with shields and remaining budget should allow redirect")


func test_can_redirect_zone_no_shields() -> void:
	var def: ShipInstance = _make_defender(
			["Redirect"], 2, {"FRONT": 3, "LEFT": 0, "RIGHT": 2, "REAR": 1})
	var result: bool = _resolver.can_redirect_to_zone(
			Constants.HullZone.LEFT, def, 2)
	assert_false(result,
			"Zone with 0 shields should not allow redirect")


func test_can_redirect_zero_remaining() -> void:
	var def: ShipInstance = _make_defender(
			["Redirect"], 2, {"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1})
	var result: bool = _resolver.can_redirect_to_zone(
			Constants.HullZone.LEFT, def, 0)
	assert_false(result,
			"Zero remaining redirect budget should not allow redirect")


# =========================================================================
# can_redirect_continue
# =========================================================================

func test_can_redirect_continue_has_budget_and_shields() -> void:
	var def: ShipInstance = _make_defender(
			["Redirect"], 2, {"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1})
	var result: bool = _resolver.can_redirect_continue(
			2, Constants.HullZone.FRONT, def)
	assert_true(result,
			"Should continue when budget > 0 and adjacent has shields")


func test_can_redirect_continue_zero_budget() -> void:
	var def: ShipInstance = _make_defender(
			["Redirect"], 2, {"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1})
	var result: bool = _resolver.can_redirect_continue(
			0, Constants.HullZone.FRONT, def)
	assert_false(result,
			"Should stop when budget is 0")


func test_can_redirect_continue_no_adjacent_shields() -> void:
	var def: ShipInstance = _make_defender(
			["Redirect"], 2, {"FRONT": 3, "LEFT": 0, "RIGHT": 0, "REAR": 1})
	var result: bool = _resolver.can_redirect_continue(
			2, Constants.HullZone.FRONT, def)
	assert_false(result,
			"Should stop when no adjacent zone has shields")


# =========================================================================
# sort_tokens_canonical
# =========================================================================

func test_sort_canonical_brace_before_redirect() -> void:
	var def: ShipInstance = _make_defender(["Redirect", "Brace"])
	var input: Array[int] = [0, 1]
	var result: Array[int] = _resolver.sort_tokens_canonical(
			input, def.defense_tokens)
	assert_eq(result[0], 1,
			"Brace (idx 1) should sort before Redirect (idx 0)")
	assert_eq(result[1], 0,
			"Redirect (idx 0) should sort after Brace (idx 1)")


func test_sort_canonical_all_five_types() -> void:
	var def: ShipInstance = _make_defender(
			["Contain", "Redirect", "Brace", "Evade", "Scatter"])
	var input: Array[int] = [0, 1, 2, 3, 4]
	var result: Array[int] = _resolver.sort_tokens_canonical(
			input, def.defense_tokens)
	# Expected: Scatter(4) Evade(3) Brace(2) Redirect(1) Contain(0)
	assert_eq(result[0], 4, "Scatter should be first")
	assert_eq(result[1], 3, "Evade should be second")
	assert_eq(result[2], 2, "Brace should be third")
	assert_eq(result[3], 1, "Redirect should be fourth")
	assert_eq(result[4], 0, "Contain should be fifth")


func test_sort_canonical_single_token() -> void:
	var def: ShipInstance = _make_defender(["Brace"])
	var input: Array[int] = [0]
	var result: Array[int] = _resolver.sort_tokens_canonical(
			input, def.defense_tokens)
	assert_eq(result.size(), 1, "Single token list should stay size 1")
	assert_eq(result[0], 0, "Single token index unchanged")


func test_sort_canonical_empty_list() -> void:
	var def: ShipInstance = _make_defender(["Brace"])
	var input: Array[int] = []
	var result: Array[int] = _resolver.sort_tokens_canonical(
			input, def.defense_tokens)
	assert_eq(result.size(), 0, "Empty list returns empty")


func test_sort_canonical_already_ordered() -> void:
	var def: ShipInstance = _make_defender(["Evade", "Brace", "Redirect"])
	var input: Array[int] = [0, 1, 2]
	var result: Array[int] = _resolver.sort_tokens_canonical(
			input, def.defense_tokens)
	assert_eq(result[0], 0, "Evade should remain first")
	assert_eq(result[1], 1, "Brace should remain second")
	assert_eq(result[2], 2, "Redirect should remain third")


# =========================================================================
# get_token_button_index
# =========================================================================

func test_get_token_button_index_finds_spent_type() -> void:
	var def: ShipInstance = _make_defender(["Evade", "Brace"])
	var spent: Dictionary = {Constants.DefenseToken.BRACE: "exhaust"}
	var result: int = _resolver.get_token_button_index(
			Constants.DefenseToken.BRACE,
			def.defense_tokens, spent)
	assert_eq(result, 1,
			"Should find Brace at index 1")


func test_get_token_button_index_unspent_returns_minus1() -> void:
	var def: ShipInstance = _make_defender(["Evade", "Brace"])
	var result: int = _resolver.get_token_button_index(
			Constants.DefenseToken.BRACE,
			def.defense_tokens, {})
	assert_eq(result, -1,
			"Unspent type should return -1")


func test_get_token_button_index_missing_type_returns_minus1() -> void:
	var def: ShipInstance = _make_defender(["Evade", "Brace"])
	var spent: Dictionary = {Constants.DefenseToken.SCATTER: "exhaust"}
	var result: int = _resolver.get_token_button_index(
			Constants.DefenseToken.SCATTER,
			def.defense_tokens, spent)
	assert_eq(result, -1,
			"Token type not present should return -1")


# =========================================================================
# determine_first_card_faceup
# =========================================================================

func test_determine_faceup_crit_no_contain() -> void:
	var dice: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.CRITICAL},
	]
	var result: bool = _resolver.determine_first_card_faceup(
			dice, false, null, null)
	assert_true(result,
			"Critical with no Contain should be faceup")


func test_determine_faceup_crit_with_contain() -> void:
	var dice: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.CRITICAL},
	]
	var result: bool = _resolver.determine_first_card_faceup(
			dice, true, null, null)
	assert_false(result,
			"Critical with Contain should NOT be faceup")


func test_determine_faceup_no_crit() -> void:
	var dice: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT},
	]
	var result: bool = _resolver.determine_first_card_faceup(
			dice, false, null, null)
	assert_false(result,
			"No critical face should not produce faceup card")


func test_determine_faceup_empty_dice() -> void:
	var dice: Array[Dictionary] = []
	var result: bool = _resolver.determine_first_card_faceup(
			dice, false, null, null)
	assert_false(result,
			"Empty dice should not produce faceup card")


# =========================================================================
# DEFENSE_RESOLVE_ORDER constant
# =========================================================================

func test_resolve_order_scatter_first() -> void:
	assert_eq(DefenseTokenResolver.DEFENSE_RESOLVE_ORDER[
			Constants.DefenseToken.SCATTER], 0,
			"Scatter should be first in resolve order")


func test_resolve_order_evade_second() -> void:
	assert_eq(DefenseTokenResolver.DEFENSE_RESOLVE_ORDER[
			Constants.DefenseToken.EVADE], 1,
			"Evade should be second in resolve order")


func test_resolve_order_brace_third() -> void:
	assert_eq(DefenseTokenResolver.DEFENSE_RESOLVE_ORDER[
			Constants.DefenseToken.BRACE], 2,
			"Brace should be third in resolve order")


func test_resolve_order_redirect_fourth() -> void:
	assert_eq(DefenseTokenResolver.DEFENSE_RESOLVE_ORDER[
			Constants.DefenseToken.REDIRECT], 3,
			"Redirect should be fourth in resolve order")


func test_resolve_order_contain_fifth() -> void:
	assert_eq(DefenseTokenResolver.DEFENSE_RESOLVE_ORDER[
			Constants.DefenseToken.CONTAIN], 4,
			"Contain should be fifth in resolve order")
