## Test: CombatParticipants
##
## Unit tests for [CombatParticipants] — lightweight data class bundling
## attacker and defender identity for a single attack interaction.
## Validates factory methods, convenience queries, and ZONE_NAMES constant.
extends GutTest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Creates a ShipToken (Node2D) and registers it for auto-free.
## Default faction is REBEL_ALLIANCE (no placement → default).
func _make_ship_token() -> ShipToken:
	var token: ShipToken = ShipToken.new()
	add_child_autofree(token)
	return token


## Creates a SquadronToken (Node2D) and registers it for auto-free.
## Default faction is REBEL_ALLIANCE (no placement → default).
func _make_squad_token() -> SquadronToken:
	var token: SquadronToken = SquadronToken.new()
	add_child_autofree(token)
	return token


# ---------------------------------------------------------------------------
# ZONE_NAMES constant
# ---------------------------------------------------------------------------

func test_zone_names_has_four_entries() -> void:
	assert_eq(CombatParticipants.ZONE_NAMES.size(), 4,
			"ZONE_NAMES should contain exactly four hull zones")


func test_zone_names_maps_front() -> void:
	assert_eq(CombatParticipants.ZONE_NAMES[Constants.HullZone.FRONT],
			"FRONT", "FRONT zone should map to 'FRONT'")


func test_zone_names_maps_left() -> void:
	assert_eq(CombatParticipants.ZONE_NAMES[Constants.HullZone.LEFT],
			"LEFT", "LEFT zone should map to 'LEFT'")


func test_zone_names_maps_right() -> void:
	assert_eq(CombatParticipants.ZONE_NAMES[Constants.HullZone.RIGHT],
			"RIGHT", "RIGHT zone should map to 'RIGHT'")


func test_zone_names_maps_rear() -> void:
	assert_eq(CombatParticipants.ZONE_NAMES[Constants.HullZone.REAR],
			"REAR", "REAR zone should map to 'REAR'")


# ---------------------------------------------------------------------------
# Default state
# ---------------------------------------------------------------------------

func test_new_instance_has_null_atk_ship() -> void:
	var p: CombatParticipants = CombatParticipants.new()
	assert_null(p.atk_ship, "New instance should have null atk_ship")


func test_new_instance_has_null_atk_squad() -> void:
	var p: CombatParticipants = CombatParticipants.new()
	assert_null(p.atk_squad, "New instance should have null atk_squad")


func test_new_instance_has_null_def_ship() -> void:
	var p: CombatParticipants = CombatParticipants.new()
	assert_null(p.def_ship, "New instance should have null def_ship")


func test_new_instance_has_null_def_squad() -> void:
	var p: CombatParticipants = CombatParticipants.new()
	assert_null(p.def_squad, "New instance should have null def_squad")


func test_new_instance_has_neg1_atk_zone() -> void:
	var p: CombatParticipants = CombatParticipants.new()
	assert_eq(p.atk_zone, -1,
			"New instance should have atk_zone == -1")


func test_new_instance_has_neg1_def_zone() -> void:
	var p: CombatParticipants = CombatParticipants.new()
	assert_eq(p.def_zone, -1,
			"New instance should have def_zone == -1")


# ---------------------------------------------------------------------------
# create() factory
# ---------------------------------------------------------------------------

func test_create_stores_atk_ship() -> void:
	var ship: ShipToken = _make_ship_token()
	var p: CombatParticipants = CombatParticipants.create(
			ship, Constants.HullZone.FRONT, null, null, -1, null)
	assert_eq(p.atk_ship, ship,
			"create() should store the attacker ship token")


func test_create_stores_atk_zone() -> void:
	var ship: ShipToken = _make_ship_token()
	var p: CombatParticipants = CombatParticipants.create(
			ship, Constants.HullZone.LEFT, null, null, -1, null)
	assert_eq(p.atk_zone, Constants.HullZone.LEFT,
			"create() should store the attacker hull zone")


func test_create_stores_atk_squad() -> void:
	var sq: SquadronToken = _make_squad_token()
	var p: CombatParticipants = CombatParticipants.create(
			null, -1, sq, null, -1, null)
	assert_eq(p.atk_squad, sq,
			"create() should store the attacker squadron token")


func test_create_stores_def_ship() -> void:
	var def_ship: ShipToken = _make_ship_token()
	var p: CombatParticipants = CombatParticipants.create(
			null, -1, null, def_ship, Constants.HullZone.REAR, null)
	assert_eq(p.def_ship, def_ship,
			"create() should store the defender ship token")


func test_create_stores_def_zone() -> void:
	var def_ship: ShipToken = _make_ship_token()
	var p: CombatParticipants = CombatParticipants.create(
			null, -1, null, def_ship, Constants.HullZone.RIGHT, null)
	assert_eq(p.def_zone, Constants.HullZone.RIGHT,
			"create() should store the defender hull zone")


func test_create_stores_def_squad() -> void:
	var def_sq: SquadronToken = _make_squad_token()
	var p: CombatParticipants = CombatParticipants.create(
			null, -1, null, null, -1, def_sq)
	assert_eq(p.def_squad, def_sq,
			"create() should store the defender squadron token")


# ---------------------------------------------------------------------------
# create_attacker_only() factory
# ---------------------------------------------------------------------------

func test_create_attacker_only_stores_ship() -> void:
	var ship: ShipToken = _make_ship_token()
	var p: CombatParticipants = CombatParticipants.create_attacker_only(
			ship, Constants.HullZone.FRONT, null)
	assert_eq(p.atk_ship, ship,
			"create_attacker_only() should store the ship token")


func test_create_attacker_only_stores_zone() -> void:
	var ship: ShipToken = _make_ship_token()
	var p: CombatParticipants = CombatParticipants.create_attacker_only(
			ship, Constants.HullZone.RIGHT, null)
	assert_eq(p.atk_zone, Constants.HullZone.RIGHT,
			"create_attacker_only() should store the hull zone")


func test_create_attacker_only_stores_squad() -> void:
	var sq: SquadronToken = _make_squad_token()
	var p: CombatParticipants = CombatParticipants.create_attacker_only(
			null, -1, sq)
	assert_eq(p.atk_squad, sq,
			"create_attacker_only() should store the squadron token")


func test_create_attacker_only_leaves_def_null() -> void:
	var ship: ShipToken = _make_ship_token()
	var p: CombatParticipants = CombatParticipants.create_attacker_only(
			ship, Constants.HullZone.FRONT, null)
	assert_null(p.def_ship,
			"create_attacker_only() should leave def_ship null")
	assert_null(p.def_squad,
			"create_attacker_only() should leave def_squad null")
	assert_eq(p.def_zone, -1,
			"create_attacker_only() should leave def_zone as -1")


# ---------------------------------------------------------------------------
# Convenience queries — attacker
# ---------------------------------------------------------------------------

func test_atk_is_ship_true_when_ship_set() -> void:
	var ship: ShipToken = _make_ship_token()
	var p: CombatParticipants = CombatParticipants.create(
			ship, Constants.HullZone.FRONT, null, null, -1, null)
	assert_true(p.atk_is_ship(),
			"atk_is_ship() should be true when atk_ship is set")


func test_atk_is_ship_false_when_no_ship() -> void:
	var p: CombatParticipants = CombatParticipants.new()
	assert_false(p.atk_is_ship(),
			"atk_is_ship() should be false when atk_ship is null")


func test_atk_is_squadron_true_when_squad_set() -> void:
	var sq: SquadronToken = _make_squad_token()
	var p: CombatParticipants = CombatParticipants.create(
			null, -1, sq, null, -1, null)
	assert_true(p.atk_is_squadron(),
			"atk_is_squadron() should be true when atk_squad is set")


func test_atk_is_squadron_false_when_no_squad() -> void:
	var p: CombatParticipants = CombatParticipants.new()
	assert_false(p.atk_is_squadron(),
			"atk_is_squadron() should be false when atk_squad is null")


# ---------------------------------------------------------------------------
# Convenience queries — defender
# ---------------------------------------------------------------------------

func test_def_is_ship_true_when_ship_set() -> void:
	var ship: ShipToken = _make_ship_token()
	var p: CombatParticipants = CombatParticipants.create(
			null, -1, null, ship, Constants.HullZone.REAR, null)
	assert_true(p.def_is_ship(),
			"def_is_ship() should be true when def_ship is set")


func test_def_is_ship_false_when_no_ship() -> void:
	var p: CombatParticipants = CombatParticipants.new()
	assert_false(p.def_is_ship(),
			"def_is_ship() should be false when def_ship is null")


func test_def_is_squadron_true_when_squad_set() -> void:
	var sq: SquadronToken = _make_squad_token()
	var p: CombatParticipants = CombatParticipants.create(
			null, -1, null, null, -1, sq)
	assert_true(p.def_is_squadron(),
			"def_is_squadron() should be true when def_squad is set")


func test_def_is_squadron_false_when_no_squad() -> void:
	var p: CombatParticipants = CombatParticipants.new()
	assert_false(p.def_is_squadron(),
			"def_is_squadron() should be false when def_squad is null")


# ---------------------------------------------------------------------------
# Faction queries
# ---------------------------------------------------------------------------

func test_get_atk_faction_default_rebel() -> void:
	var p: CombatParticipants = CombatParticipants.new()
	assert_eq(p.get_atk_faction(), Constants.Faction.REBEL_ALLIANCE,
			"get_atk_faction() should default to REBEL_ALLIANCE")


func test_get_def_faction_default_empire() -> void:
	var p: CombatParticipants = CombatParticipants.new()
	assert_eq(p.get_def_faction(), Constants.Faction.GALACTIC_EMPIRE,
			"get_def_faction() should default to GALACTIC_EMPIRE")


func test_get_atk_faction_from_ship() -> void:
	var ship: ShipToken = _make_ship_token()
	# ShipToken without placement defaults to REBEL_ALLIANCE.
	var p: CombatParticipants = CombatParticipants.create(
			ship, Constants.HullZone.FRONT, null, null, -1, null)
	assert_eq(p.get_atk_faction(), Constants.Faction.REBEL_ALLIANCE,
			"get_atk_faction() should return ship's faction")


func test_get_atk_faction_from_squad() -> void:
	var sq: SquadronToken = _make_squad_token()
	# SquadronToken without placement defaults to REBEL_ALLIANCE.
	var p: CombatParticipants = CombatParticipants.create(
			null, -1, sq, null, -1, null)
	assert_eq(p.get_atk_faction(), Constants.Faction.REBEL_ALLIANCE,
			"get_atk_faction() should return squadron's faction")


func test_get_def_faction_from_ship() -> void:
	var ship: ShipToken = _make_ship_token()
	var p: CombatParticipants = CombatParticipants.create(
			null, -1, null, ship, Constants.HullZone.FRONT, null)
	assert_eq(p.get_def_faction(), Constants.Faction.REBEL_ALLIANCE,
			"get_def_faction() should return defender ship's faction")


func test_get_def_faction_from_squad() -> void:
	var sq: SquadronToken = _make_squad_token()
	var p: CombatParticipants = CombatParticipants.create(
			null, -1, null, null, -1, sq)
	assert_eq(p.get_def_faction(), Constants.Faction.REBEL_ALLIANCE,
			"get_def_faction() should return defender squadron's faction")
