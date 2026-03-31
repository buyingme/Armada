## Test: SquadronCommandResolver
##
## Unit tests for SquadronCommandResolver — Squadron command resolution
## during ship activation. Covers activation budget calculation (dial,
## token, both), range checking, activation tracking, finalization, and
## edge cases (empty resolver, no friendly squadrons).
##
## Rules Reference: RRG "Commands" p.4 — Squadron; CM-020–CM-022.
extends GutTest


# ---------------------------------------------------------------------------
# Helper — build a ShipInstance with configurable Squadron resources
# ---------------------------------------------------------------------------


## Creates a ShipInstance with the given squadron_value, optional dial/token.
func _make_ship(
		sq_value: int = 2,
		has_squad_dial: bool = true,
		has_squad_token: bool = false,
		ship_size: Constants.ShipSize = Constants.ShipSize.SMALL) -> ShipInstance:
	var data: ShipData = ShipData.new()
	data.hull = 5
	data.max_speed = 2
	data.engineering_value = 3
	data.command_value = 2
	data.squadron_value = sq_value
	data.ship_size = ship_size
	data.shields = {
		"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1,
	}
	data.defense_tokens = []
	data.navigation_chart = [[1], [0, 1]]
	var ship: ShipInstance = ShipInstance.create_from_data(
			"test_ship", data, 2, 0)
	# Set up command dial stack: Squadron or Navigate.
	if has_squad_dial:
		ship.command_dial_stack.assign_dials(
				[Constants.CommandType.SQUADRON,
				Constants.CommandType.NAVIGATE], 1)
		ship.command_dial_stack.reveal_top()
	else:
		ship.command_dial_stack.assign_dials(
				[Constants.CommandType.NAVIGATE,
				Constants.CommandType.NAVIGATE], 1)
		ship.command_dial_stack.reveal_top()
	# Add Squadron token if requested.
	if has_squad_token:
		ship.command_tokens.add_token(Constants.CommandType.SQUADRON)
	return ship


# ---------------------------------------------------------------------------
# Budget calculation (CM-020, CM-021, CM-022)
# ---------------------------------------------------------------------------


func test_dial_grants_squadron_value_activations() -> void:
	var ship: ShipInstance = _make_ship(3, true, false)
	var resolver: SquadronCommandResolver = SquadronCommandResolver.create(
			ship, Vector2.ZERO)
	assert_eq(resolver.get_max_activations(), 3,
			"Dial should grant squadron_value activations (CM-021)")
	assert_true(resolver.has_dial(),
			"Should detect Squadron dial")
	assert_false(resolver.has_token(),
			"Should not detect Squadron token when absent")


func test_token_only_grants_one_activation() -> void:
	var ship: ShipInstance = _make_ship(2, false, true)
	var resolver: SquadronCommandResolver = SquadronCommandResolver.create(
			ship, Vector2.ZERO)
	assert_eq(resolver.get_max_activations(), 1,
			"Token alone should grant 1 activation (CM-022)")
	assert_false(resolver.has_dial(),
			"Should not detect dial when Navigate was revealed")
	assert_true(resolver.has_token(),
			"Should detect Squadron token")


func test_dial_plus_token_grants_combined() -> void:
	var ship: ShipInstance = _make_ship(2, true, true)
	var resolver: SquadronCommandResolver = SquadronCommandResolver.create(
			ship, Vector2.ZERO)
	assert_eq(resolver.get_max_activations(), 3,
			"Dial + token should grant squadron_value + 1 (CM-020)")
	assert_true(resolver.has_dial(), "Should detect dial")
	assert_true(resolver.has_token(), "Should detect token")


func test_no_resources_is_empty() -> void:
	var ship: ShipInstance = _make_ship(2, false, false)
	var resolver: SquadronCommandResolver = SquadronCommandResolver.create(
			ship, Vector2.ZERO)
	assert_true(resolver.is_empty(),
			"No dial, no token → is_empty (CM-020)")
	assert_eq(resolver.get_max_activations(), 0,
			"Max activations should be 0 when no resources")


func test_vsd_squadron_value_three_dial() -> void:
	# VSD has squadron_value=3 → dial gives 3, dial+token gives 4.
	var ship: ShipInstance = _make_ship(3, true, true)
	var resolver: SquadronCommandResolver = SquadronCommandResolver.create(
			ship, Vector2.ZERO)
	assert_eq(resolver.get_max_activations(), 4,
			"VSD dial(3) + token(1) = 4 activations")


# ---------------------------------------------------------------------------
# Activation tracking
# ---------------------------------------------------------------------------


func test_use_activation_decrements_remaining() -> void:
	var ship: ShipInstance = _make_ship(2, true, false)
	var resolver: SquadronCommandResolver = SquadronCommandResolver.create(
			ship, Vector2.ZERO)
	assert_eq(resolver.get_remaining_activations(), 2,
			"Initially 2 remaining")
	var ok: bool = resolver.use_activation()
	assert_true(ok, "First use should succeed")
	assert_eq(resolver.get_remaining_activations(), 1,
			"1 remaining after first use")
	assert_eq(resolver.get_activations_used(), 1,
			"1 used after first use")
	assert_false(resolver.is_done(), "Not done yet")


func test_use_activation_returns_false_when_done() -> void:
	var ship: ShipInstance = _make_ship(1, false, true)
	var resolver: SquadronCommandResolver = SquadronCommandResolver.create(
			ship, Vector2.ZERO)
	resolver.use_activation()
	assert_true(resolver.is_done(), "Should be done after 1 use")
	var ok: bool = resolver.use_activation()
	assert_false(ok,
			"Should return false when all activations are used")


func test_is_done_true_after_all_used() -> void:
	var ship: ShipInstance = _make_ship(2, true, false)
	var resolver: SquadronCommandResolver = SquadronCommandResolver.create(
			ship, Vector2.ZERO)
	resolver.use_activation()
	resolver.use_activation()
	assert_true(resolver.is_done(),
			"Should be done after using all 2 activations")
	assert_eq(resolver.get_remaining_activations(), 0,
			"0 remaining when done")


# ---------------------------------------------------------------------------
# Range checking
# ---------------------------------------------------------------------------


func test_squadron_in_range_at_close_range() -> void:
	# Place ship at origin, squadron very close — should be in range.
	var ship: ShipInstance = _make_ship(2, true, false)
	var resolver: SquadronCommandResolver = SquadronCommandResolver.create(
			ship, Vector2(500, 500))
	assert_true(resolver.is_squadron_in_range(Vector2(550, 500)),
			"Squadron 50px away should be in range")


func test_squadron_out_of_range() -> void:
	# Place squadron very far away.
	var ship: ShipInstance = _make_ship(2, true, false)
	var resolver: SquadronCommandResolver = SquadronCommandResolver.create(
			ship, Vector2(500, 500))
	assert_false(resolver.is_squadron_in_range(Vector2(9999, 9999)),
			"Squadron thousands of pixels away should be out of range")


func test_squadron_at_medium_range_boundary() -> void:
	# Place squadron just inside the medium range limit.
	var ship: ShipInstance = _make_ship(2, true, false)
	var ship_pos: Vector2 = Vector2(500, 500)
	var resolver: SquadronCommandResolver = SquadronCommandResolver.create(
			ship, ship_pos)
	# Approximate: ship_half + squad_radius + medium_range_px
	var ship_half: float = GameScale.small_base_length_px * 0.5
	var squad_radius: float = GameScale.squadron_base_diameter_px * 0.5
	var medium_px: float = GameScale.range_medium_px
	# Place squadron 1px inside the limit to avoid float boundary issues.
	var limit_dist: float = ship_half + squad_radius + medium_px - 1.0
	var squad_pos: Vector2 = Vector2(500 + limit_dist, 500)
	assert_true(resolver.is_squadron_in_range(squad_pos),
			"Squadron just inside medium range should be in range")


func test_squadron_just_beyond_medium_range() -> void:
	var ship: ShipInstance = _make_ship(2, true, false)
	var ship_pos: Vector2 = Vector2(500, 500)
	var resolver: SquadronCommandResolver = SquadronCommandResolver.create(
			ship, ship_pos)
	var ship_half: float = GameScale.small_base_length_px * 0.5
	var squad_radius: float = GameScale.squadron_base_diameter_px * 0.5
	var medium_px: float = GameScale.range_medium_px
	# Place squadron 10px beyond the limit.
	var beyond_dist: float = ship_half + squad_radius + medium_px + 10.0
	var squad_pos: Vector2 = Vector2(500 + beyond_dist, 500)
	assert_false(resolver.is_squadron_in_range(squad_pos),
			"Squadron 10px beyond medium range should be out of range")


# ---------------------------------------------------------------------------
# Finalize (resource spending)
# ---------------------------------------------------------------------------


func test_finalize_spends_dial() -> void:
	var ship: ShipInstance = _make_ship(2, true, false)
	var resolver: SquadronCommandResolver = SquadronCommandResolver.create(
			ship, Vector2.ZERO)
	# Verify dial is revealed before finalize.
	var revealed: Dictionary = ship.command_dial_stack.get_revealed_dial()
	assert_false(revealed.is_empty(),
			"Dial should be revealed before finalize")
	resolver.finalize()
	# After finalize, the revealed dial should be consumed.
	var after: Dictionary = ship.command_dial_stack.get_revealed_dial()
	assert_true(after.is_empty(),
			"Revealed dial should be consumed after finalize (CM-020)")


func test_finalize_spends_token() -> void:
	var ship: ShipInstance = _make_ship(2, false, true)
	var resolver: SquadronCommandResolver = SquadronCommandResolver.create(
			ship, Vector2.ZERO)
	assert_true(ship.command_tokens.has_token(
			Constants.CommandType.SQUADRON),
			"Token should exist before finalize")
	resolver.use_activation()
	resolver.finalize()
	assert_false(ship.command_tokens.has_token(
			Constants.CommandType.SQUADRON),
			"Token should be consumed after finalize (CM-022)")


## Rules Reference: "Commands" p.4 — spending a command token is optional.
func test_finalize_does_not_spend_token_if_no_activations_used() -> void:
	var ship: ShipInstance = _make_ship(2, false, true)
	var resolver: SquadronCommandResolver = SquadronCommandResolver.create(
			ship, Vector2.ZERO)
	assert_true(ship.command_tokens.has_token(
			Constants.CommandType.SQUADRON),
			"Token should exist before finalize")
	# Finalize without using any activations — token should be kept.
	resolver.finalize()
	assert_true(ship.command_tokens.has_token(
			Constants.CommandType.SQUADRON),
			"Token should be kept when no activations used")


func test_finalize_spends_both_dial_and_token() -> void:
	var ship: ShipInstance = _make_ship(2, true, true)
	var resolver: SquadronCommandResolver = SquadronCommandResolver.create(
			ship, Vector2.ZERO)
	# Use at least one activation so the token counts as spent.
	resolver.use_activation()
	resolver.finalize()
	var after_dial: Dictionary = ship.command_dial_stack.get_revealed_dial()
	assert_true(after_dial.is_empty(),
			"Dial should be consumed after finalize")
	assert_false(ship.command_tokens.has_token(
			Constants.CommandType.SQUADRON),
			"Token should be consumed after finalize")


func test_finalize_no_resources_no_crash() -> void:
	var ship: ShipInstance = _make_ship(2, false, false)
	var resolver: SquadronCommandResolver = SquadronCommandResolver.create(
			ship, Vector2.ZERO)
	# Should complete without error even with nothing to spend.
	resolver.finalize()
	assert_true(resolver.is_empty(),
			"Empty resolver should remain empty after finalize")


# ---------------------------------------------------------------------------
# Ship accessor
# ---------------------------------------------------------------------------


func test_get_ship_returns_instance() -> void:
	var ship: ShipInstance = _make_ship(2, true, false)
	var resolver: SquadronCommandResolver = SquadronCommandResolver.create(
			ship, Vector2(100, 200))
	assert_eq(resolver.get_ship(), ship,
			"get_ship() should return the creating ship")
	assert_eq(resolver.get_ship_position(), Vector2(100, 200),
			"get_ship_position() should return the provided position")
