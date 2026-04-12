## Test: RepairResolver
##
## Unit tests for RepairResolver — Repair (Engineering) command resolution.
## Covers engineering point calculation (dial/token/both), move shields,
## recover shields, repair hull (discard damage card), and finalization.
##
## Rules Reference: RRG "Engineering", p.4; CM-030–CM-037.
extends GutTest


# ---------------------------------------------------------------------------
# Helper — build a ShipInstance with configurable Repair resources
# ---------------------------------------------------------------------------


## Creates a ShipInstance with given engineering value, optional Repair dial
## and/or token, and configurable shields.
## Shield layout: FRONT=3/3, LEFT=2/2, RIGHT=2/2, REAR=1/1 by default.
func _make_ship(
		eng_value: int = 4,
		has_repair_dial: bool = true,
		has_repair_token: bool = false,
		front_shields: int = 3,
		left_shields: int = 2,
		right_shields: int = 2,
		rear_shields: int = 1) -> ShipInstance:
	var data: ShipData = ShipData.new()
	data.hull = 5
	data.max_speed = 3
	data.engineering_value = eng_value
	data.command_value = 2
	data.shields = {
		"FRONT": front_shields,
		"LEFT": left_shields,
		"RIGHT": right_shields,
		"REAR": rear_shields,
	}
	data.defense_tokens = []
	data.navigation_chart = [[1], [1, 1], [0, 1, 1]]
	var ship: ShipInstance = ShipInstance.create_from_data(
			"test_ship", data, 2, 0)
	# Set up command dial stack with a Repair (or Navigate) dial and reveal it.
	if has_repair_dial:
		ship.command_dial_stack.assign_dials(
				[Constants.CommandType.REPAIR,
				Constants.CommandType.NAVIGATE], 1)
		ship.command_dial_stack.reveal_top()
	else:
		ship.command_dial_stack.assign_dials(
				[Constants.CommandType.NAVIGATE,
				Constants.CommandType.NAVIGATE], 1)
		ship.command_dial_stack.reveal_top()
	# Add Repair token if requested.
	if has_repair_token:
		ship.command_tokens.add_token(Constants.CommandType.REPAIR)
	return ship


## Creates a DamageDeck for testing.
func _make_deck() -> DamageDeck:
	var deck: DamageDeck = DamageDeck.new()
	deck.initialize()
	return deck


# ---------------------------------------------------------------------------
# Engineering point calculation (CM-031, CM-032)
# ---------------------------------------------------------------------------


func test_dial_grants_full_engineering_points() -> void:
	var ship: ShipInstance = _make_ship(4, true, false)
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	assert_eq(resolver.get_total_points(), 4,
			"Dial should grant full engineering_value (CM-031)")
	assert_true(resolver.has_repair_dial(),
			"Should detect Repair dial")
	assert_false(resolver.has_repair_token(),
			"Should not detect Repair token when absent")


func test_token_grants_half_engineering_points_rounded_up() -> void:
	var ship: ShipInstance = _make_ship(3, false, true)
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	assert_eq(resolver.get_total_points(), 2,
			"Token should grant ceil(3/2) = 2 engineering points (CM-032)")
	assert_false(resolver.has_repair_dial(),
			"Should not detect Repair dial when absent")
	assert_true(resolver.has_repair_token(),
			"Should detect Repair token")


func test_dial_plus_token_combines_points() -> void:
	var ship: ShipInstance = _make_ship(4, true, true)
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	# Dial = 4, Token = ceil(4/2) = 2, Total = 6.
	assert_eq(resolver.get_total_points(), 6,
			"Dial + token should combine: 4 + ceil(4/2) = 6 (CM-031, CM-032)")


func test_no_repair_resources_gives_zero_points() -> void:
	var ship: ShipInstance = _make_ship(4, false, false)
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	assert_eq(resolver.get_total_points(), 0,
			"No Repair dial or token should give 0 points")
	assert_true(resolver.is_empty(),
			"Resolver with 0 points should report is_empty()")


func test_even_engineering_value_token_calculation() -> void:
	var ship: ShipInstance = _make_ship(2, false, true)
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	assert_eq(resolver.get_total_points(), 1,
			"Token should grant ceil(2/2) = 1 engineering point")


# ---------------------------------------------------------------------------
# Move Shields — 1 engineering point (CM-033)
# ---------------------------------------------------------------------------


func test_move_shields_costs_one_point() -> void:
	var ship: ShipInstance = _make_ship(4, true, false)
	ship.reduce_shields("REAR", 1) # REAR now 0/1 — can receive.
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	var result: bool = resolver.move_shields("FRONT", "REAR")
	assert_true(result, "Should succeed moving shields FRONT → REAR")
	assert_eq(resolver.get_remaining_points(), 3,
			"Should cost 1 engineering point (CM-033)")


func test_move_shields_updates_ship_shields() -> void:
	var ship: ShipInstance = _make_ship(4, true, false)
	ship.reduce_shields("REAR", 1) # REAR now 0/1.
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	resolver.move_shields("FRONT", "REAR")
	assert_eq(int(ship.current_shields["FRONT"]), 2,
			"Source zone should lose 1 shield")
	assert_eq(int(ship.current_shields["REAR"]), 1,
			"Target zone should gain 1 shield (up to max)")


func test_move_shields_fails_when_source_empty() -> void:
	# Reduce REAR shields to 0 first.
	var ship: ShipInstance = _make_ship(4, true, false, 3, 2, 2, 1)
	ship.reduce_shields("REAR", 1)
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	var result: bool = resolver.move_shields("REAR", "FRONT")
	assert_false(result, "Should fail when source zone has 0 shields")


func test_move_shields_fails_when_target_at_max() -> void:
	var ship: ShipInstance = _make_ship(4, true, false, 3, 2, 2, 1)
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	# FRONT is already at max (3/3).
	var result: bool = resolver.move_shields("LEFT", "FRONT")
	assert_false(result, "Should fail when target zone is at max shields")


func test_move_shields_fails_same_zone() -> void:
	var ship: ShipInstance = _make_ship(4, true, false)
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	var result: bool = resolver.move_shields("FRONT", "FRONT")
	assert_false(result, "Should fail when source == target zone")


func test_move_shields_fails_insufficient_points() -> void:
	# Token only with eng_value=1 → ceil(1/2) = 1 point. Spend it.
	var ship: ShipInstance = _make_ship(1, false, true, 3, 2, 2, 0)
	ship.reduce_shields("LEFT", 1) # LEFT now 1.
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	# Spend the 1 point on a move.
	resolver.move_shields("FRONT", "LEFT")
	# Now 0 points remain.
	var result: bool = resolver.move_shields("FRONT", "RIGHT")
	assert_false(result, "Should fail when no points remain")


func test_move_shields_works_to_non_full_zone() -> void:
	# Damage FRONT shields so it can receive.
	var ship: ShipInstance = _make_ship(4, true, false, 3, 2, 2, 1)
	ship.reduce_shields("FRONT", 2) # FRONT now 1/3.
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	var result: bool = resolver.move_shields("LEFT", "FRONT")
	assert_true(result, "Should succeed moving to non-full zone")
	assert_eq(int(ship.current_shields["FRONT"]), 2,
			"FRONT should increase to 2")
	assert_eq(int(ship.current_shields["LEFT"]), 1,
			"LEFT should decrease to 1")


# ---------------------------------------------------------------------------
# Recover Shields — 2 engineering points (CM-034)
# ---------------------------------------------------------------------------


func test_recover_shields_costs_two_points() -> void:
	var ship: ShipInstance = _make_ship(4, true, false, 3, 2, 2, 1)
	ship.reduce_shields("FRONT", 1) # FRONT now 2/3.
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	var result: bool = resolver.recover_shields("FRONT")
	assert_true(result, "Should succeed recovering shield on damaged zone")
	assert_eq(resolver.get_remaining_points(), 2,
			"Should cost 2 engineering points (CM-034)")


func test_recover_shields_updates_ship() -> void:
	var ship: ShipInstance = _make_ship(4, true, false, 3, 2, 2, 1)
	ship.reduce_shields("FRONT", 2) # FRONT now 1/3.
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	resolver.recover_shields("FRONT")
	assert_eq(int(ship.current_shields["FRONT"]), 2,
			"FRONT should increase by 1 to 2")


func test_recover_shields_fails_when_at_max() -> void:
	var ship: ShipInstance = _make_ship(4, true, false, 3, 2, 2, 1)
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	var result: bool = resolver.recover_shields("FRONT")
	assert_false(result, "Should fail when zone is at max shields")


func test_recover_shields_fails_insufficient_points() -> void:
	# 1 point from token (eng_value=2, ceil(2/2)=1).
	var ship: ShipInstance = _make_ship(2, false, true, 3, 2, 2, 1)
	ship.reduce_shields("FRONT", 1)
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	var result: bool = resolver.recover_shields("FRONT")
	assert_false(result, "1 point should not afford 2-point recover (CM-034)")


# ---------------------------------------------------------------------------
# Repair Hull — 3 engineering points (CM-035)
# ---------------------------------------------------------------------------


func test_repair_hull_costs_three_points() -> void:
	var ship: ShipInstance = _make_ship(4, true, false)
	var card: DamageCard = DamageCard.create("Ship", "Structural Damage")
	ship.add_facedown_damage(card)
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	var result: bool = resolver.repair_hull(card)
	assert_true(result, "Should succeed discarding facedown damage card")
	assert_eq(resolver.get_remaining_points(), 1,
			"Should cost 3 engineering points (CM-035)")


func test_repair_hull_removes_card_from_ship() -> void:
	var ship: ShipInstance = _make_ship(4, true, false)
	var card: DamageCard = DamageCard.create("Ship", "Structural Damage")
	ship.add_facedown_damage(card)
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	resolver.repair_hull(card)
	assert_eq(ship.facedown_damage.size(), 0,
			"Facedown damage should be empty after repair")


func test_repair_hull_discards_card_to_deck() -> void:
	var ship: ShipInstance = _make_ship(4, true, false)
	var card: DamageCard = DamageCard.create("Ship", "Structural Damage")
	ship.add_facedown_damage(card)
	var deck: DamageDeck = _make_deck()
	var initial_draw: int = deck.get_draw_count()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	resolver.repair_hull(card)
	assert_eq(deck.get_discard_count(), 1,
			"Discarded card should go to damage deck discard pile")


func test_repair_hull_works_on_faceup_card() -> void:
	var ship: ShipInstance = _make_ship(4, true, false)
	var card: DamageCard = DamageCard.create("Ship", "Blinded Gunners")
	card.flip_faceup()
	ship.add_faceup_damage(card)
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	var result: bool = resolver.repair_hull(card)
	assert_true(result, "Should succeed discarding faceup damage card")
	assert_eq(ship.faceup_damage.size(), 0,
			"Faceup damage should be empty after repair")


func test_repair_hull_fails_when_no_damage() -> void:
	var ship: ShipInstance = _make_ship(4, true, false)
	var card: DamageCard = DamageCard.create("Ship", "Test")
	# Card is NOT on the ship.
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	var result: bool = resolver.repair_hull(card)
	assert_false(result, "Should fail when card is not on the ship")


func test_repair_hull_fails_insufficient_points() -> void:
	# 2 points from token (eng_value=4, ceil(4/2)=2).
	var ship: ShipInstance = _make_ship(4, false, true)
	var card: DamageCard = DamageCard.create("Ship", "Test")
	ship.add_facedown_damage(card)
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	var result: bool = resolver.repair_hull(card)
	assert_false(result, "2 points should not afford 3-point hull repair")


func test_repair_hull_emits_ship_hull_changed() -> void:
	## Verify that repairing a card emits ship_hull_changed
	## so the ship token refreshes its hull counter display.
	var ship: ShipInstance = _make_ship(4, true, false)
	var card: DamageCard = DamageCard.create("Ship", "Structural Damage")
	ship.add_facedown_damage(card)
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	var result: Array = [-1]
	var on_hull_changed: Callable = func(_s: RefCounted, h: int) -> void:
		result[0] = h
	EventBus.ship_hull_changed.connect(on_hull_changed)
	resolver.repair_hull(card)
	EventBus.ship_hull_changed.disconnect(on_hull_changed)
	assert_eq(result[0], 5,
			"ship_hull_changed should emit with hull=5 after removing card")


# ---------------------------------------------------------------------------
# Combined spending — multiple effects (CM-036)
# ---------------------------------------------------------------------------


func test_multiple_effects_in_sequence() -> void:
	# eng_value=4, dial = 4 points. Spend: move(1) + recover(2) = 3.
	var ship: ShipInstance = _make_ship(4, true, false, 3, 2, 2, 1)
	ship.reduce_shields("FRONT", 2) # FRONT now 1/3.
	ship.reduce_shields("LEFT", 1) # LEFT now 1/2.
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	# Move (1 pt): LEFT → FRONT.
	var move_ok: bool = resolver.move_shields("LEFT", "FRONT")
	assert_true(move_ok, "Move should succeed")
	# Recover (2 pts): LEFT.
	var recover_ok: bool = resolver.recover_shields("LEFT")
	assert_true(recover_ok, "Recover should succeed with 3 pts remaining")
	assert_eq(resolver.get_remaining_points(), 1,
			"Should have 1 point remaining after 1+2 spent")
	assert_eq(resolver.get_points_spent(), 3,
			"Should report 3 points spent")


func test_same_effect_multiple_times() -> void:
	# eng_value=4, dial = 4 points. Move 4 times.
	var ship: ShipInstance = _make_ship(4, true, false, 3, 2, 2, 1)
	ship.reduce_shields("FRONT", 3) # FRONT now 0/3.
	ship.reduce_shields("REAR", 1) # REAR now 0/1.
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	# Move LEFT→FRONT 2 times.
	assert_true(resolver.move_shields("LEFT", "FRONT"), "Move 1 ok")
	assert_true(resolver.move_shields("LEFT", "FRONT"), "Move 2 ok")
	# LEFT is now 0; move RIGHT→FRONT, then RIGHT→REAR.
	assert_true(resolver.move_shields("RIGHT", "FRONT"), "Move 3 ok")
	assert_true(resolver.move_shields("RIGHT", "REAR"), "Move 4 ok")
	assert_eq(resolver.get_remaining_points(), 0,
			"All 4 points should be spent (CM-036)")


# ---------------------------------------------------------------------------
# Finalize — resource spending (CM-037)
# ---------------------------------------------------------------------------


func test_finalize_spends_dial() -> void:
	var ship: ShipInstance = _make_ship(4, true, false)
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	# The revealed dial should be Repair before finalize.
	var revealed: Dictionary = ship.command_dial_stack.get_revealed_dial()
	assert_eq(int(revealed.get("command", -1)),
			Constants.CommandType.REPAIR,
			"Revealed dial should be REPAIR before finalize")
	var result: Dictionary = resolver.finalize()
	# After finalize, the dial should be spent (no longer revealed).
	var after: Dictionary = ship.command_dial_stack.get_revealed_dial()
	assert_true(after.is_empty(),
			"Dial should be spent after finalize (CM-037)")
	assert_false(result.has("token_type"),
			"No token_type when only dial used")


func test_finalize_spends_token_only_when_used() -> void:
	var ship: ShipInstance = _make_ship(4, true, true)
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	# Spend exactly dial points (4) — token should NOT be consumed.
	ship.reduce_shields("FRONT", 3) # FRONT 0/3.
	resolver.move_shields("LEFT", "FRONT")
	resolver.move_shields("LEFT", "FRONT")
	resolver.move_shields("RIGHT", "FRONT")
	resolver.move_shields("RIGHT", "FRONT")
	# 4 spent = dial points exactly.
	var result: Dictionary = resolver.finalize()
	assert_false(result.has("token_type"),
			"No token_type when only dial points used")
	assert_true(ship.command_tokens.has_token(Constants.CommandType.REPAIR),
			"Token should NOT be spent when only dial points used")


func test_finalize_spends_token_when_exceeding_dial() -> void:
	var ship: ShipInstance = _make_ship(4, true, true)
	ship.reduce_shields("FRONT", 3) # FRONT 0/3.
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	# Total = 6 points (4 dial + 2 token). Spend 5.
	resolver.move_shields("LEFT", "FRONT") # 1 pt
	resolver.move_shields("LEFT", "FRONT") # 1 pt
	resolver.move_shields("RIGHT", "FRONT") # 1 pt -> FRONT now 3/3
	resolver.recover_shields("LEFT") # 2 pts -> LEFT 0→1 (was 0 after moves)
	# 5 points spent > 4 dial points. Token must be spent.
	var result: Dictionary = resolver.finalize()
	assert_true(result.has("token_type"),
			"finalize() should report token spend (CM-032)")
	assert_eq(int(result["token_type"]),
			int(Constants.CommandType.REPAIR),
			"Reported token_type should be REPAIR")
	# Token remains on ship — actual spend is via SpendTokenCommand.
	assert_true(ship.command_tokens.has_token(Constants.CommandType.REPAIR),
			"Token still present — spending deferred to command system")


func test_finalize_emits_repair_resolved_signal() -> void:
	var ship: ShipInstance = _make_ship(4, true, false)
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	watch_signals(EventBus)
	var _result: Dictionary = resolver.finalize()
	assert_signal_emitted(EventBus, "repair_command_resolved",
			"Should emit repair_command_resolved on finalize (CM-037)")


func test_unspent_points_are_lost() -> void:
	var ship: ShipInstance = _make_ship(4, true, false)
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	# Spend 1 of 4 points.
	ship.reduce_shields("FRONT", 1)
	resolver.move_shields("LEFT", "FRONT")
	var _result: Dictionary = resolver.finalize()
	# No way to reclaim the other 3 points (CM-037).
	assert_eq(resolver.get_points_spent(), 1,
			"Only 1 point should have been spent")
	assert_eq(resolver.get_remaining_points(), 3,
			"3 points are lost after finalize (CM-037)")


# ---------------------------------------------------------------------------
# ShipInstance.remove_damage_card()
# ---------------------------------------------------------------------------


func test_remove_facedown_damage_card() -> void:
	var ship: ShipInstance = _make_ship()
	var card: DamageCard = DamageCard.create("Ship", "Test")
	ship.add_facedown_damage(card)
	var removed: bool = ship.remove_damage_card(card)
	assert_true(removed, "Should remove facedown card")
	assert_eq(ship.facedown_damage.size(), 0,
			"Facedown array should be empty")


func test_remove_faceup_damage_card() -> void:
	var ship: ShipInstance = _make_ship()
	var card: DamageCard = DamageCard.create("Ship", "Test")
	card.flip_faceup()
	ship.add_faceup_damage(card)
	var removed: bool = ship.remove_damage_card(card)
	assert_true(removed, "Should remove faceup card")
	assert_eq(ship.faceup_damage.size(), 0,
			"Faceup array should be empty")


func test_remove_nonexistent_card_returns_false() -> void:
	var ship: ShipInstance = _make_ship()
	var card: DamageCard = DamageCard.create("Ship", "Test")
	var removed: bool = ship.remove_damage_card(card)
	assert_false(removed, "Should return false for card not on ship")


# ---------------------------------------------------------------------------
# has_any_repair_target (full-health skip)
# ---------------------------------------------------------------------------


func test_has_any_repair_target_false_at_full_health() -> void:
	var ship: ShipInstance = _make_ship()
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	assert_false(resolver.has_any_repair_target(),
			"Full-health ship should have no repair targets")


func test_has_any_repair_target_true_with_damage_card() -> void:
	var ship: ShipInstance = _make_ship()
	var card: DamageCard = DamageCard.create("Ship", "Test")
	ship.add_facedown_damage(card)
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	assert_true(resolver.has_any_repair_target(),
			"Ship with damage card should have a repair target")


func test_has_any_repair_target_true_with_reduced_shields() -> void:
	var ship: ShipInstance = _make_ship(4, true, false, 3, 2, 1, 1)
	ship.reduce_shields("RIGHT", 1)
	var deck: DamageDeck = _make_deck()
	var resolver: RepairResolver = RepairResolver.create(ship, deck)
	assert_true(resolver.has_any_repair_target(),
			"Ship with reduced shields should have a repair target")
