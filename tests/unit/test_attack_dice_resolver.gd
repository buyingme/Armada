## Test: AttackDiceResolver
##
## Unit tests for [AttackDiceResolver] — pure-computation helper that resolves
## armament, dice pools, Concentrate Fire detection, obstruction die removal,
## gather-dice hooks, damage calculation, and attack-blocked checks.
##
## Uses real ShipToken / SquadronToken instances with manually set internal
## fields (ShipData, ShipInstance, SquadronInstance) to control test state.
extends GutTest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

var _resolver: AttackDiceResolver


func before_each() -> void:
	_resolver = AttackDiceResolver.new()


## Creates a ShipToken with the given faction and configurable ShipData.
## Sets _half_w, _half_l, _placement, _ship_data, _ship_instance.
func _make_ship_token(
		faction: Constants.Faction = Constants.Faction.REBEL_ALLIANCE,
		battery: Dictionary = {},
		anti_sq: Dictionary = {},
		command_value: int = 1) -> ShipToken:
	var token: ShipToken = ShipToken.new()
	token._placement = TokenPlacement.new(
			"test_ship", true, faction, 0.5, 0.5, 0.0,
			Constants.ShipSize.SMALL)
	token._half_w = 30.0
	token._half_l = 50.0
	# Set up ShipData with string keys (matching JSON format).
	var data: ShipData = ShipData.new()
	data.ship_name = "Test Ship"
	data.faction = faction
	data.hull = 4
	data.command_value = command_value
	data.max_speed = 3
	data.shields = {"FRONT": 2, "LEFT": 1, "RIGHT": 1, "REAR": 1}
	data.battery_armament = battery
	data.anti_squadron_armament = anti_sq
	data.defense_tokens = []
	token._ship_data = data
	# Create ShipInstance.
	var inst: ShipInstance = ShipInstance.create_from_data(
			"test_ship", data, 2, 0)
	token._ship_instance = inst
	add_child_autofree(token)
	return token


## Creates a SquadronToken with configurable SquadronData / instance.
func _make_squad_token(
		faction: Constants.Faction = Constants.Faction.REBEL_ALLIANCE,
		battery: Dictionary = {},
		anti_sq: Dictionary = {}) -> SquadronToken:
	var token: SquadronToken = SquadronToken.new()
	token._placement = TokenPlacement.new(
			"test_squad", false, faction, 0.5, 0.5, 0.0)
	token._radius_px = 20.0
	var data: SquadronData = SquadronData.new()
	data.squadron_name = "Test Squadron"
	data.faction = faction
	data.hull = 3
	data.speed = 3
	data.battery_armament = battery
	data.anti_squadron_armament = anti_sq
	var inst: SquadronInstance = SquadronInstance.new()
	inst.squadron_data = data
	token._squadron_instance = inst
	add_child_autofree(token)
	return token


## Helper to build CombatParticipants for ship-vs-ship.
func _ship_vs_ship(
		atk: ShipToken, zone: int,
		def: ShipToken, def_zone: int = -1) -> CombatParticipants:
	return CombatParticipants.create(atk, zone, null, def, def_zone, null)


## Helper to build CombatParticipants for ship-vs-squadron.
func _ship_vs_squad(
		atk: ShipToken, zone: int,
		def_sq: SquadronToken) -> CombatParticipants:
	return CombatParticipants.create(atk, zone, null, null, -1, def_sq)


## Helper to build CombatParticipants for squadron-vs-ship.
func _squad_vs_ship(
		atk_sq: SquadronToken,
		def: ShipToken, def_zone: int = -1) -> CombatParticipants:
	return CombatParticipants.create(null, -1, atk_sq, def, def_zone, null)


## Helper to build CombatParticipants for squadron-vs-squadron.
func _squad_vs_squad(
		atk_sq: SquadronToken,
		def_sq: SquadronToken) -> CombatParticipants:
	return CombatParticipants.create(null, -1, atk_sq, null, -1, def_sq)


# ---------------------------------------------------------------------------
# resolve_armament — ship attacker vs ship
# ---------------------------------------------------------------------------

func test_resolve_armament_ship_vs_ship_front_zone() -> void:
	var battery: Dictionary = {
		"FRONT": {"RED": 3, "BLUE": 1},
		"LEFT": {"RED": 1},
		"RIGHT": {"RED": 1},
		"REAR": {"BLUE": 1},
	}
	var atk: ShipToken = _make_ship_token(
			Constants.Faction.REBEL_ALLIANCE, battery)
	var def: ShipToken = _make_ship_token(
			Constants.Faction.GALACTIC_EMPIRE)
	var parts: CombatParticipants = _ship_vs_ship(
			atk, Constants.HullZone.FRONT, def)
	var armament: Dictionary = _resolver.resolve_armament(parts)
	assert_eq(armament, {"RED": 3, "BLUE": 1},
			"Ship-vs-ship FRONT should return front battery armament")


func test_resolve_armament_ship_vs_ship_rear_zone() -> void:
	var battery: Dictionary = {
		"FRONT": {"RED": 3},
		"LEFT": {"RED": 1},
		"RIGHT": {"RED": 1},
		"REAR": {"BLUE": 2},
	}
	var atk: ShipToken = _make_ship_token(
			Constants.Faction.REBEL_ALLIANCE, battery)
	var def: ShipToken = _make_ship_token(
			Constants.Faction.GALACTIC_EMPIRE)
	var parts: CombatParticipants = _ship_vs_ship(
			atk, Constants.HullZone.REAR, def)
	var armament: Dictionary = _resolver.resolve_armament(parts)
	assert_eq(armament, {"BLUE": 2},
			"Ship-vs-ship REAR should return rear battery armament")


# ---------------------------------------------------------------------------
# resolve_armament — ship attacker vs squadron
# ---------------------------------------------------------------------------

func test_resolve_armament_ship_vs_squadron_returns_anti_sq() -> void:
	var battery: Dictionary = {
		"FRONT": {"RED": 3, "BLUE": 1},
	}
	var anti_sq: Dictionary = {"BLUE": 2}
	var atk: ShipToken = _make_ship_token(
			Constants.Faction.REBEL_ALLIANCE, battery, anti_sq)
	var def_sq: SquadronToken = _make_squad_token(
			Constants.Faction.GALACTIC_EMPIRE)
	var parts: CombatParticipants = _ship_vs_squad(
			atk, Constants.HullZone.FRONT, def_sq)
	var armament: Dictionary = _resolver.resolve_armament(parts)
	assert_eq(armament, {"BLUE": 2},
			"Ship-vs-squadron should return anti-squadron armament")


# ---------------------------------------------------------------------------
# resolve_armament — squadron attacker
# ---------------------------------------------------------------------------

func test_resolve_armament_squad_vs_ship_returns_battery() -> void:
	var sq_battery: Dictionary = {"RED": 1}
	var sq_anti: Dictionary = {"BLUE": 4}
	var atk_sq: SquadronToken = _make_squad_token(
			Constants.Faction.REBEL_ALLIANCE, sq_battery, sq_anti)
	var def: ShipToken = _make_ship_token(
			Constants.Faction.GALACTIC_EMPIRE)
	var parts: CombatParticipants = _squad_vs_ship(atk_sq, def)
	var armament: Dictionary = _resolver.resolve_armament(parts)
	assert_eq(armament, {"RED": 1},
			"Squadron-vs-ship should return squadron battery armament")


func test_resolve_armament_squad_vs_squad_returns_anti_sq() -> void:
	var sq_battery: Dictionary = {"RED": 1}
	var sq_anti: Dictionary = {"BLUE": 4}
	var atk_sq: SquadronToken = _make_squad_token(
			Constants.Faction.REBEL_ALLIANCE, sq_battery, sq_anti)
	var def_sq: SquadronToken = _make_squad_token(
			Constants.Faction.GALACTIC_EMPIRE)
	var parts: CombatParticipants = _squad_vs_squad(atk_sq, def_sq)
	var armament: Dictionary = _resolver.resolve_armament(parts)
	assert_eq(armament, {"BLUE": 4},
			"Squadron-vs-squadron should return anti-squadron armament")


# ---------------------------------------------------------------------------
# resolve_armament — edge cases
# ---------------------------------------------------------------------------

func test_resolve_armament_no_attacker_returns_empty() -> void:
	var parts: CombatParticipants = CombatParticipants.new()
	var armament: Dictionary = _resolver.resolve_armament(parts)
	assert_eq(armament, {},
			"No attacker should return empty armament")


func test_resolve_armament_ship_null_data_returns_empty() -> void:
	var token: ShipToken = ShipToken.new()
	token._placement = TokenPlacement.new(
			"test", true, Constants.Faction.REBEL_ALLIANCE,
			0.5, 0.5, 0.0, Constants.ShipSize.SMALL)
	# No _ship_data set.
	add_child_autofree(token)
	var parts: CombatParticipants = CombatParticipants.create(
			token, Constants.HullZone.FRONT, null, null, -1, null)
	var armament: Dictionary = _resolver.resolve_armament(parts)
	assert_eq(armament, {},
			"Ship with null ShipData should return empty armament")


# ---------------------------------------------------------------------------
# compute_pool
# ---------------------------------------------------------------------------

func test_compute_pool_filters_by_range() -> void:
	var armament: Dictionary = {"RED": 2, "BLUE": 1, "BLACK": 1}
	var pool: Dictionary = _resolver.compute_pool(
			armament, Constants.RANGE_BAND_MEDIUM)
	assert_eq(pool, {"RED": 2, "BLUE": 1},
			"Medium range should include red + blue, exclude black")


func test_compute_pool_close_includes_all() -> void:
	var armament: Dictionary = {"RED": 1, "BLUE": 1, "BLACK": 1}
	var pool: Dictionary = _resolver.compute_pool(
			armament, Constants.RANGE_BAND_CLOSE)
	assert_eq(pool, {"RED": 1, "BLUE": 1, "BLACK": 1},
			"Close range should include all dice colours")


func test_compute_pool_long_only_red() -> void:
	var armament: Dictionary = {"RED": 2, "BLUE": 1, "BLACK": 1}
	var pool: Dictionary = _resolver.compute_pool(
			armament, Constants.RANGE_BAND_LONG)
	assert_eq(pool, {"RED": 2},
			"Long range should only include red dice")


func test_compute_pool_beyond_returns_empty() -> void:
	var armament: Dictionary = {"RED": 2, "BLUE": 1}
	var pool: Dictionary = _resolver.compute_pool(
			armament, Constants.RANGE_BAND_BEYOND)
	assert_eq(pool, {},
			"Beyond range should return empty pool")


# ---------------------------------------------------------------------------
# compute_dice_text
# ---------------------------------------------------------------------------

func test_compute_dice_text_no_attacker_returns_zero() -> void:
	var parts: CombatParticipants = CombatParticipants.new()
	var text: String = _resolver.compute_dice_text(
			parts, Constants.RANGE_BAND_MEDIUM)
	assert_eq(text, "0 dice",
			"No attacker should produce '0 dice'")


func test_compute_dice_text_ship_at_medium() -> void:
	var battery: Dictionary = {
		"FRONT": {"RED": 2, "BLUE": 1, "BLACK": 1},
	}
	var atk: ShipToken = _make_ship_token(
			Constants.Faction.REBEL_ALLIANCE, battery)
	var def: ShipToken = _make_ship_token(
			Constants.Faction.GALACTIC_EMPIRE)
	var parts: CombatParticipants = _ship_vs_ship(
			atk, Constants.HullZone.FRONT, def)
	var text: String = _resolver.compute_dice_text(
			parts, Constants.RANGE_BAND_MEDIUM)
	assert_eq(text, "2 red, 1 blue",
			"FRONT at medium should show 2 red, 1 blue (black filtered)")


# ---------------------------------------------------------------------------
# compute_pool_for_parts
# ---------------------------------------------------------------------------

func test_compute_pool_for_parts_no_attacker_empty() -> void:
	var parts: CombatParticipants = CombatParticipants.new()
	var pool: Dictionary = _resolver.compute_pool_for_parts(
			parts, Constants.RANGE_BAND_CLOSE)
	assert_eq(pool, {},
			"No attacker should produce empty pool")


func test_compute_pool_for_parts_ship_vs_ship() -> void:
	var battery: Dictionary = {
		"FRONT": {"RED": 3, "BLUE": 2, "BLACK": 1},
	}
	var atk: ShipToken = _make_ship_token(
			Constants.Faction.REBEL_ALLIANCE, battery)
	var def: ShipToken = _make_ship_token(
			Constants.Faction.GALACTIC_EMPIRE)
	var parts: CombatParticipants = _ship_vs_ship(
			atk, Constants.HullZone.FRONT, def)
	var pool: Dictionary = _resolver.compute_pool_for_parts(
			parts, Constants.RANGE_BAND_CLOSE)
	assert_eq(pool, {"RED": 3, "BLUE": 2, "BLACK": 1},
			"Close range should return full pool")


# ---------------------------------------------------------------------------
# apply_gather_hook
# ---------------------------------------------------------------------------

func test_apply_gather_hook_null_registry_unchanged() -> void:
	var pool: Dictionary = {"RED": 2, "BLUE": 1}
	var parts: CombatParticipants = CombatParticipants.new()
	var result: Dictionary = _resolver.apply_gather_hook(
			pool, null, parts)
	assert_eq(result, {"RED": 2, "BLUE": 1},
			"Null registry should return pool unchanged")


func test_apply_gather_hook_empty_registry_unchanged() -> void:
	var pool: Dictionary = {"RED": 2, "BLUE": 1}
	var registry: EffectRegistry = EffectRegistry.new()
	var atk: ShipToken = _make_ship_token()
	var def: ShipToken = _make_ship_token(
			Constants.Faction.GALACTIC_EMPIRE)
	var parts: CombatParticipants = _ship_vs_ship(
			atk, Constants.HullZone.FRONT, def)
	var result: Dictionary = _resolver.apply_gather_hook(
			pool, registry, parts)
	assert_eq(result, {"RED": 2, "BLUE": 1},
			"Empty registry should return pool unchanged")


# ---------------------------------------------------------------------------
# is_blocked_by_damage
# ---------------------------------------------------------------------------

func test_is_blocked_null_registry_returns_false() -> void:
	var parts: CombatParticipants = CombatParticipants.new()
	var blocked: bool = _resolver.is_blocked_by_damage(
			null, parts, false, 1)
	assert_false(blocked,
			"Null registry should not block attack")


func test_is_blocked_empty_registry_returns_false() -> void:
	var registry: EffectRegistry = EffectRegistry.new()
	var atk: ShipToken = _make_ship_token()
	var parts: CombatParticipants = CombatParticipants.create(
			atk, Constants.HullZone.FRONT, null, null, -1, null)
	var blocked: bool = _resolver.is_blocked_by_damage(
			registry, parts, false, 1)
	assert_false(blocked,
			"Empty registry should not block attack")


# ---------------------------------------------------------------------------
# get_cf_dial_colours
# ---------------------------------------------------------------------------

func test_get_cf_dial_colours_returns_available() -> void:
	var pool: Dictionary = {"RED": 2, "BLUE": 1}
	var colours: Array[String] = _resolver.get_cf_dial_colours(pool)
	assert_has(colours, "RED", "RED should be available")
	assert_has(colours, "BLUE", "BLUE should be available")
	assert_eq(colours.size(), 2, "Should have exactly 2 colours")


func test_get_cf_dial_colours_excludes_zero_count() -> void:
	var pool: Dictionary = {"RED": 1, "BLUE": 0}
	var colours: Array[String] = _resolver.get_cf_dial_colours(pool)
	assert_has(colours, "RED", "RED should be available")
	assert_does_not_have(colours, "BLUE",
			"BLUE with 0 count should be excluded")


func test_get_cf_dial_colours_empty_pool() -> void:
	var pool: Dictionary = {}
	var colours: Array[String] = _resolver.get_cf_dial_colours(pool)
	assert_eq(colours.size(), 0, "Empty pool should have no colours")


# ---------------------------------------------------------------------------
# has_cf_dial
# ---------------------------------------------------------------------------

func test_has_cf_dial_null_token_returns_false() -> void:
	assert_false(_resolver.has_cf_dial(null),
			"Null token should return false for CF dial")


func test_has_cf_dial_no_revealed_returns_false() -> void:
	var token: ShipToken = _make_ship_token(
			Constants.Faction.REBEL_ALLIANCE, {}, {}, 2)
	# No dial revealed — stack created but empty.
	assert_false(_resolver.has_cf_dial(token),
			"No revealed dial should return false")


func test_has_cf_dial_cf_revealed_returns_true() -> void:
	var token: ShipToken = _make_ship_token(
			Constants.Faction.REBEL_ALLIANCE, {}, {}, 2)
	var inst: ShipInstance = token.get_ship_instance()
	# Assign two CF dials (command_value=2 → needs 2 in round 1) and reveal.
	inst.command_dial_stack.assign_dials(
			[Constants.CommandType.CONCENTRATE_FIRE,
			Constants.CommandType.CONCENTRATE_FIRE], 1)
	inst.command_dial_stack.reveal_top()
	assert_true(_resolver.has_cf_dial(token),
			"Revealed CF dial should return true")


func test_has_cf_dial_navigate_revealed_returns_false() -> void:
	var token: ShipToken = _make_ship_token(
			Constants.Faction.REBEL_ALLIANCE, {}, {}, 2)
	var inst: ShipInstance = token.get_ship_instance()
	# Assign two Navigate dials (command_value=2) and reveal.
	inst.command_dial_stack.assign_dials(
			[Constants.CommandType.NAVIGATE,
			Constants.CommandType.NAVIGATE], 1)
	inst.command_dial_stack.reveal_top()
	assert_false(_resolver.has_cf_dial(token),
			"Non-CF revealed dial should return false")


# ---------------------------------------------------------------------------
# has_cf_token
# ---------------------------------------------------------------------------

func test_has_cf_token_null_token_returns_false() -> void:
	assert_false(_resolver.has_cf_token(null),
			"Null token should return false for CF token")


func test_has_cf_token_no_tokens_returns_false() -> void:
	var token: ShipToken = _make_ship_token(
			Constants.Faction.REBEL_ALLIANCE, {}, {}, 2)
	assert_false(_resolver.has_cf_token(token),
			"No command tokens should return false")


func test_has_cf_token_with_cf_returns_true() -> void:
	var token: ShipToken = _make_ship_token(
			Constants.Faction.REBEL_ALLIANCE, {}, {}, 2)
	var inst: ShipInstance = token.get_ship_instance()
	inst.command_tokens.add_token(
			Constants.CommandType.CONCENTRATE_FIRE)
	assert_true(_resolver.has_cf_token(token),
			"Ship with CF token should return true")


func test_has_cf_token_with_navigate_only_returns_false() -> void:
	var token: ShipToken = _make_ship_token(
			Constants.Faction.REBEL_ALLIANCE, {}, {}, 2)
	var inst: ShipInstance = token.get_ship_instance()
	inst.command_tokens.add_token(Constants.CommandType.NAVIGATE)
	assert_false(_resolver.has_cf_token(token),
			"Ship with only Navigate token should return false")


# ---------------------------------------------------------------------------
# remove_obstruction_die
# ---------------------------------------------------------------------------

func test_remove_obstruction_die_decrements_count() -> void:
	var pool: Dictionary = {"RED": 2, "BLUE": 1}
	var result: Dictionary = _resolver.remove_obstruction_die(pool, "RED")
	assert_eq(result.get("RED", 0), 1,
			"RED count should decrease by 1")
	assert_eq(result.get("BLUE", 0), 1,
			"BLUE count should remain unchanged")


func test_remove_obstruction_die_erases_zero_count() -> void:
	var pool: Dictionary = {"RED": 1, "BLUE": 1}
	var result: Dictionary = _resolver.remove_obstruction_die(pool, "RED")
	assert_false(result.has("RED"),
			"RED key should be erased when count reaches 0")
	assert_eq(result.get("BLUE", 0), 1,
			"BLUE should be unaffected")


func test_remove_obstruction_die_does_not_mutate_original() -> void:
	var pool: Dictionary = {"RED": 2, "BLUE": 1}
	var _result: Dictionary = _resolver.remove_obstruction_die(pool, "RED")
	assert_eq(pool.get("RED", 0), 2,
			"Original pool should not be mutated")


func test_remove_obstruction_die_missing_colour_no_crash() -> void:
	var pool: Dictionary = {"RED": 1}
	var result: Dictionary = _resolver.remove_obstruction_die(
			pool, "BLACK")
	assert_eq(result, {"RED": 1},
			"Removing missing colour should return pool unchanged")


# ---------------------------------------------------------------------------
# calc_damage — ship vs ship (crits count)
# ---------------------------------------------------------------------------

func test_calc_damage_ship_vs_ship_counts_crits() -> void:
	var atk: ShipToken = _make_ship_token()
	var def: ShipToken = _make_ship_token(
			Constants.Faction.GALACTIC_EMPIRE)
	var parts: CombatParticipants = _ship_vs_ship(
			atk, Constants.HullZone.FRONT, def)
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT},
		{"color": Constants.DiceColor.RED,
				"face": Constants.DiceFace.CRITICAL},
	]
	var damage: int = _resolver.calc_damage(results, parts, null)
	assert_eq(damage, 2,
			"Ship-vs-ship: HIT + CRIT should equal 2 damage")


func test_calc_damage_ship_vs_ship_hit_crit_face() -> void:
	var atk: ShipToken = _make_ship_token()
	var def: ShipToken = _make_ship_token(
			Constants.Faction.GALACTIC_EMPIRE)
	var parts: CombatParticipants = _ship_vs_ship(
			atk, Constants.HullZone.FRONT, def)
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED,
				"face": Constants.DiceFace.HIT_CRITICAL},
	]
	var damage: int = _resolver.calc_damage(results, parts, null)
	assert_eq(damage, 2,
			"Ship-vs-ship: HIT_CRITICAL face should equal 2 damage")


# ---------------------------------------------------------------------------
# calc_damage — squadron involved (crits don't count)
# ---------------------------------------------------------------------------

func test_calc_damage_ship_vs_squad_crit_not_counted() -> void:
	var atk: ShipToken = _make_ship_token()
	var def_sq: SquadronToken = _make_squad_token(
			Constants.Faction.GALACTIC_EMPIRE)
	var parts: CombatParticipants = _ship_vs_squad(
			atk, Constants.HullZone.FRONT, def_sq)
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.BLUE,
				"face": Constants.DiceFace.CRITICAL},
	]
	var damage: int = _resolver.calc_damage(results, parts, null)
	assert_eq(damage, 0,
			"Ship-vs-squad: standalone CRIT should deal 0 damage")


func test_calc_damage_squad_vs_ship_crit_not_counted() -> void:
	var atk_sq: SquadronToken = _make_squad_token()
	var def: ShipToken = _make_ship_token(
			Constants.Faction.GALACTIC_EMPIRE)
	var parts: CombatParticipants = _squad_vs_ship(atk_sq, def)
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED,
				"face": Constants.DiceFace.CRITICAL},
	]
	var damage: int = _resolver.calc_damage(results, parts, null)
	assert_eq(damage, 0,
			"Squad-vs-ship: standalone CRIT should deal 0 damage")


func test_calc_damage_squad_vs_squad_hit_crit_partial() -> void:
	var atk_sq: SquadronToken = _make_squad_token()
	var def_sq: SquadronToken = _make_squad_token(
			Constants.Faction.GALACTIC_EMPIRE)
	var parts: CombatParticipants = _squad_vs_squad(atk_sq, def_sq)
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED,
				"face": Constants.DiceFace.HIT_CRITICAL},
	]
	var damage: int = _resolver.calc_damage(results, parts, null)
	assert_eq(damage, 1,
			"Squad-vs-squad: HIT_CRITICAL should deal only 1 (hit portion)")


# ---------------------------------------------------------------------------
# calc_damage — with effect registry (no effects = base)
# ---------------------------------------------------------------------------

func test_calc_damage_with_empty_registry_returns_base() -> void:
	var registry: EffectRegistry = EffectRegistry.new()
	var atk: ShipToken = _make_ship_token()
	var def: ShipToken = _make_ship_token(
			Constants.Faction.GALACTIC_EMPIRE)
	var parts: CombatParticipants = _ship_vs_ship(
			atk, Constants.HullZone.FRONT, def)
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT},
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT},
	]
	var damage: int = _resolver.calc_damage(results, parts, registry)
	assert_eq(damage, 2,
			"Empty registry should still return base damage of 2")


# ---------------------------------------------------------------------------
# calc_damage — empty results
# ---------------------------------------------------------------------------

func test_calc_damage_empty_results_returns_zero() -> void:
	var atk: ShipToken = _make_ship_token()
	var def: ShipToken = _make_ship_token(
			Constants.Faction.GALACTIC_EMPIRE)
	var parts: CombatParticipants = _ship_vs_ship(
			atk, Constants.HullZone.FRONT, def)
	var results: Array[Dictionary] = []
	var damage: int = _resolver.calc_damage(results, parts, null)
	assert_eq(damage, 0,
			"Empty results should yield 0 damage")
