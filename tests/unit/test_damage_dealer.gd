## Tests for [DamageDealer].
##
## Verifies the pure-computation helper extracted in refactoring phase F4d.
## Every public method has at least one test. Uses AAA pattern.
extends GutTest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

var _dealer: DamageDealer


func before_each() -> void:
	_dealer = DamageDealer.new()


func _make_card(card_title: String, card_timing: String = "",
		card_effect_id: String = "") -> DamageCard:
	var card: DamageCard = DamageCard.new()
	card.title = card_title
	card.trait_type = "Ship"
	card.timing = card_timing
	card.effect_id = card_effect_id
	return card


# ===========================================================================
# calculate_final_damage
# ===========================================================================


func test_calculate_final_damage_no_scatter_returns_modified() -> void:
	var result: int = _dealer.calculate_final_damage(5, false)
	assert_eq(result, 5, "No scatter → modified damage unchanged.")


func test_calculate_final_damage_scatter_returns_zero() -> void:
	var result: int = _dealer.calculate_final_damage(5, true)
	assert_eq(result, 0, "Scatter → damage reduced to 0.")


func test_calculate_final_damage_negative_clamped_to_zero() -> void:
	var result: int = _dealer.calculate_final_damage(-3, false)
	assert_eq(result, 0, "Negative damage clamped to 0.")


func test_calculate_final_damage_zero_stays_zero() -> void:
	var result: int = _dealer.calculate_final_damage(0, false)
	assert_eq(result, 0, "Zero damage stays zero.")


# ===========================================================================
# calculate_shield_absorption
# ===========================================================================


func test_shield_absorption_enough_shields() -> void:
	var result: int = _dealer.calculate_shield_absorption(3, 2)
	assert_eq(result, 2, "Shields >= damage → absorb all damage.")


func test_shield_absorption_not_enough_shields() -> void:
	var result: int = _dealer.calculate_shield_absorption(1, 4)
	assert_eq(result, 1, "Shields < damage → absorb only available shields.")


func test_shield_absorption_zero_shields() -> void:
	var result: int = _dealer.calculate_shield_absorption(0, 3)
	assert_eq(result, 0, "Zero shields → absorb nothing.")


func test_shield_absorption_zero_damage() -> void:
	var result: int = _dealer.calculate_shield_absorption(3, 0)
	assert_eq(result, 0, "Zero damage → absorb nothing.")


func test_shield_absorption_negative_damage() -> void:
	var result: int = _dealer.calculate_shield_absorption(3, -1)
	assert_eq(result, 0, "Negative damage clamped → absorb nothing.")


# ===========================================================================
# calculate_hull_remaining
# ===========================================================================


func test_hull_remaining_no_damage() -> void:
	var result: int = _dealer.calculate_hull_remaining(5, 0)
	assert_eq(result, 5, "No damage → full hull.")


func test_hull_remaining_partial_damage() -> void:
	var result: int = _dealer.calculate_hull_remaining(5, 3)
	assert_eq(result, 2, "3 damage from 5 hull → 2 remaining.")


func test_hull_remaining_exact_destruction() -> void:
	var result: int = _dealer.calculate_hull_remaining(5, 5)
	assert_eq(result, 0, "Damage equals hull → 0 remaining.")


func test_hull_remaining_over_destruction() -> void:
	var result: int = _dealer.calculate_hull_remaining(5, 7)
	assert_eq(result, -2, "Damage exceeds hull → negative remaining.")


# ===========================================================================
# is_ship_destroyed
# ===========================================================================


func test_is_ship_destroyed_under_hull() -> void:
	assert_false(_dealer.is_ship_destroyed(5, 3),
			"Damage < hull → not destroyed.")


func test_is_ship_destroyed_at_hull() -> void:
	assert_true(_dealer.is_ship_destroyed(5, 5),
			"Damage == hull → destroyed. (DM-003)")


func test_is_ship_destroyed_over_hull() -> void:
	assert_true(_dealer.is_ship_destroyed(5, 8),
			"Damage > hull → destroyed.")


func test_is_ship_destroyed_zero_damage() -> void:
	assert_false(_dealer.is_ship_destroyed(5, 0),
			"Zero damage → not destroyed.")


# ===========================================================================
# is_squadron_destroyed
# ===========================================================================


func test_is_squadron_destroyed_positive_hull() -> void:
	assert_false(_dealer.is_squadron_destroyed(2),
			"Hull > 0 → not destroyed.")


func test_is_squadron_destroyed_zero_hull() -> void:
	assert_true(_dealer.is_squadron_destroyed(0),
			"Hull == 0 → destroyed.")


func test_is_squadron_destroyed_negative_hull() -> void:
	assert_true(_dealer.is_squadron_destroyed(-1),
			"Hull < 0 → destroyed.")


# ===========================================================================
# plan_ship_damage
# ===========================================================================


func test_plan_ship_damage_basic() -> void:
	# 4 damage, no scatter, 2 shields, 5 hull, 0 existing damage
	var plan: Dictionary = _dealer.plan_ship_damage(4, false, 2, 5, 0)
	assert_eq(plan["final_damage"], 4, "Final damage = 4.")
	assert_eq(plan["shield_absorbed"], 2, "Shields absorb 2.")
	assert_eq(plan["cards_to_deal"], 2, "2 cards to deal.")
	assert_eq(plan["hull_remaining"], 3, "Hull: 5 - 2 = 3.")
	assert_false(plan["is_destroyed"] as bool, "Not destroyed.")


func test_plan_ship_damage_scatter_zeros_everything() -> void:
	var plan: Dictionary = _dealer.plan_ship_damage(6, true, 3, 5, 0)
	assert_eq(plan["final_damage"], 0, "Scatter → 0 damage.")
	assert_eq(plan["shield_absorbed"], 0, "No shields consumed.")
	assert_eq(plan["cards_to_deal"], 0, "No cards to deal.")
	assert_eq(plan["hull_remaining"], 5, "Hull unchanged.")
	assert_false(plan["is_destroyed"] as bool, "Not destroyed.")


func test_plan_ship_damage_shields_absorb_all() -> void:
	var plan: Dictionary = _dealer.plan_ship_damage(2, false, 3, 5, 0)
	assert_eq(plan["shield_absorbed"], 2, "All damage absorbed by shields.")
	assert_eq(plan["cards_to_deal"], 0, "No hull damage.")
	assert_eq(plan["hull_remaining"], 5, "Hull stays at max.")


func test_plan_ship_damage_destroys_ship() -> void:
	# 6 damage, 1 shield, hull 4, existing 1 damage
	var plan: Dictionary = _dealer.plan_ship_damage(6, false, 1, 4, 1)
	assert_eq(plan["shield_absorbed"], 1, "1 shield absorbed.")
	assert_eq(plan["cards_to_deal"], 5, "5 cards to deal.")
	# total damage = existing 1 + 5 new = 6, hull = 4
	assert_true(plan["is_destroyed"] as bool,
			"6 total damage >= 4 hull → destroyed. (DM-003)")
	assert_eq(plan["hull_remaining"], -2, "Hull remaining = 4 - 6 = -2.")


func test_plan_ship_damage_existing_damage_counted() -> void:
	# 2 damage, 0 shields, hull 5, existing 2 damage
	var plan: Dictionary = _dealer.plan_ship_damage(2, false, 0, 5, 2)
	assert_eq(plan["cards_to_deal"], 2, "2 cards to deal.")
	# total = existing 2 + 2 new = 4
	assert_eq(plan["hull_remaining"], 1, "Hull: 5 - 4 = 1.")
	assert_false(plan["is_destroyed"] as bool, "4 < 5 → not destroyed.")


func test_plan_ship_damage_zero_damage() -> void:
	var plan: Dictionary = _dealer.plan_ship_damage(0, false, 3, 5, 0)
	assert_eq(plan["final_damage"], 0, "Zero damage.")
	assert_eq(plan["cards_to_deal"], 0, "No cards to deal.")


# ===========================================================================
# plan_squadron_damage
# ===========================================================================


func test_plan_squadron_damage_basic() -> void:
	var plan: Dictionary = _dealer.plan_squadron_damage(2, 3, 3)
	assert_eq(plan["actual_damage"], 2, "2 damage dealt.")
	assert_eq(plan["new_hull"], 1, "Hull: 3 - 2 = 1.")
	assert_eq(plan["max_hull"], 3, "Max hull preserved.")
	assert_false(plan["is_destroyed"] as bool, "Not destroyed.")


func test_plan_squadron_damage_destroys() -> void:
	var plan: Dictionary = _dealer.plan_squadron_damage(5, 3, 3)
	assert_eq(plan["actual_damage"], 3, "Clamped to current hull.")
	assert_eq(plan["new_hull"], 0, "Hull reduced to 0.")
	assert_true(plan["is_destroyed"] as bool, "Destroyed.")


func test_plan_squadron_damage_zero_damage() -> void:
	var plan: Dictionary = _dealer.plan_squadron_damage(0, 3, 3)
	assert_eq(plan["actual_damage"], 0, "No damage.")
	assert_eq(plan["new_hull"], 3, "Hull unchanged.")
	assert_false(plan["is_destroyed"] as bool, "Not destroyed.")


func test_plan_squadron_damage_exact_hull() -> void:
	var plan: Dictionary = _dealer.plan_squadron_damage(3, 3, 3)
	assert_eq(plan["actual_damage"], 3, "Exact damage = hull.")
	assert_eq(plan["new_hull"], 0, "Hull reduced to 0.")
	assert_true(plan["is_destroyed"] as bool, "Destroyed at exact hull.")


# ===========================================================================
# build_damage_summary
# ===========================================================================


func test_build_damage_summary_no_crit() -> void:
	var s: String = _dealer.build_damage_summary(
			"front", 2, 3, "", 4, 8)
	assert_eq(s, "front: 2 shield, 3 card(s) | Hull 4/8",
			"Summary without crit name.")


func test_build_damage_summary_with_crit() -> void:
	var s: String = _dealer.build_damage_summary(
			"right", 1, 2, "Structural Damage", 3, 6)
	assert_eq(s,
			"right: 1 shield, 2 card(s) — CRIT: Structural Damage | Hull 3/6",
			"Summary with crit name.")


func test_build_damage_summary_zero_shields() -> void:
	var s: String = _dealer.build_damage_summary(
			"rear", 0, 1, "", 5, 5)
	assert_eq(s, "rear: 0 shield, 1 card(s) | Hull 5/5",
			"Zero shields in summary.")


# ===========================================================================
# build_squadron_damage_info
# ===========================================================================


func test_build_squadron_damage_info() -> void:
	var s: String = _dealer.build_squadron_damage_info(2, 1, 3)
	assert_eq(s, "Squadron: 2 damage → Hull 1/3",
			"Squadron damage info string.")


func test_build_squadron_damage_info_zero() -> void:
	var s: String = _dealer.build_squadron_damage_info(0, 3, 3)
	assert_eq(s, "Squadron: 0 damage → Hull 3/3",
			"Zero damage squadron info.")


# ===========================================================================
# build_no_damage_info
# ===========================================================================


func test_build_no_damage_info() -> void:
	assert_eq(_dealer.build_no_damage_info(), "No damage dealt.",
			"No damage info string constant.")


# ===========================================================================
# should_deal_faceup
# ===========================================================================


func test_should_deal_faceup_first_card_with_crit() -> void:
	assert_true(_dealer.should_deal_faceup(0, true),
			"Index 0 + faceup flag → faceup.")


func test_should_deal_faceup_first_card_no_crit() -> void:
	assert_false(_dealer.should_deal_faceup(0, false),
			"Index 0, no faceup flag → facedown.")


func test_should_deal_faceup_later_card_with_crit() -> void:
	assert_false(_dealer.should_deal_faceup(1, true),
			"Index > 0 → always facedown.")


func test_should_deal_faceup_later_card_no_crit() -> void:
	assert_false(_dealer.should_deal_faceup(2, false),
			"Index > 0, no crit → facedown.")


# ===========================================================================
# has_immediate_effect
# ===========================================================================


func test_has_immediate_effect_true() -> void:
	var card: DamageCard = _make_card("Structural Damage", "immediate",
			"structural_damage")
	assert_true(_dealer.has_immediate_effect(card),
			"Immediate timing → has immediate effect.")


func test_has_immediate_effect_false_for_persistent() -> void:
	var card: DamageCard = _make_card("Damaged Controls", "persistent",
			"damaged_controls")
	assert_false(_dealer.has_immediate_effect(card),
			"Persistent only → no immediate effect.")


func test_has_immediate_effect_immediate_persistent() -> void:
	var card: DamageCard = _make_card("Life Support Failure",
			"immediate_persistent", "life_support_failure")
	assert_true(_dealer.has_immediate_effect(card),
			"immediate_persistent → has immediate effect.")


# ===========================================================================
# get_chooser_player_index
# ===========================================================================


func test_get_chooser_player_index_owner() -> void:
	assert_eq(_dealer.get_chooser_player_index("owner", 0), 0,
			"Owner → defender's player index.")


func test_get_chooser_player_index_opponent_from_p0() -> void:
	assert_eq(_dealer.get_chooser_player_index("opponent", 0), 1,
			"Opponent of p0 → p1.")


func test_get_chooser_player_index_opponent_from_p1() -> void:
	assert_eq(_dealer.get_chooser_player_index("opponent", 1), 0,
			"Opponent of p1 → p0.")
