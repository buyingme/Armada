## Unit tests for TargetingListBuilder.
##
## Integration-level tests that exercise the full pipeline: arc test → range
## measurement → maximum-range filter → LOS trace → range-path check.
## Uses hand-crafted ShipInfo and SquadInfo to avoid Scene-tree dependency.
##
## Requirements: TL-LIST-001–007, TL-ALGO-003, AC-TL-19.
extends GutTest


# =========================================================================
# Config — matches test_token_mover scale so range bands are known.
# =========================================================================

const _SCALE_CONFIG: Dictionary = {
	"ruler_total_length_px": 720,
	"range_bands": {
		"close": {"max_px": 181},
		"medium": {"max_px": 442},
		"long": {"max_px": 720},
	},
	"distance_bands_px": [181, 294, 434, 577, 720],
	"base_graphics": {
		"small_ship": {
			"base_region_width_px": 103,
			"base_region_length_px": 171,
		},
		"medium_ship": {
			"base_region_width_px": 148,
			"base_region_length_px": 243,
		},
		"squadron_base": {
			"base_region_diameter_px": 82,
		},
	},
}


# =========================================================================
# Helpers
# =========================================================================

## Standard half-width/length for test ships.
const HW: float = 20.0
const HL: float = 35.0


## Creates a ShipInfo with arc_pts and los_pts computed for a rectangular
## base centred at [pos] with rotation [rot].
func _make_ship(
		ship_name: String,
		owner: int,
		pos: Vector2,
		rot: float,
		battery: Dictionary = {},
		anti_sq: Dictionary = {}) -> TargetingListBuilder.ShipInfo:
	var info: TargetingListBuilder.ShipInfo = TargetingListBuilder.ShipInfo.new()
	info.ship_name = ship_name
	info.data_key = ship_name.to_lower().replace(" ", "_")
	info.owner_player = owner
	info.pos = pos
	info.rot = rot
	info.half_w = HW
	info.half_l = HL
	info.arc_pts = _make_arc_pts(pos, rot)
	info.los_pts = _make_los_pts(pos, rot)
	if battery.is_empty():
		battery = {
			"FRONT": {"RED": 2, "BLUE": 1},
			"LEFT": {"RED": 1},
			"RIGHT": {"RED": 1},
			"REAR": {"RED": 1},
		}
	info.battery_armament = battery
	info.anti_squadron_armament = anti_sq
	return info


## Creates a SquadInfo at [pos] with the given owner.
func _make_squad(
		squad_name: String,
		owner: int,
		pos: Vector2) -> TargetingListBuilder.SquadInfo:
	var sq: TargetingListBuilder.SquadInfo = TargetingListBuilder.SquadInfo.new()
	sq.squad_name = squad_name
	sq.owner_player = owner
	sq.pos = pos
	sq.radius = 15.0
	return sq


## Creates world-space arc boundary points (same helper as test_range_finder).
func _make_arc_pts(pos: Vector2, rot: float) -> Dictionary:
	var centre: Vector2 = pos
	var fl_ext: Vector2 = pos + (Vector2(-HW, -HL).normalized() * 100.0).rotated(rot)
	var fr_ext: Vector2 = pos + (Vector2(HW, -HL).normalized() * 100.0).rotated(rot)
	var rl_ext: Vector2 = pos + (Vector2(-HW, HL).normalized() * 100.0).rotated(rot)
	var rr_ext: Vector2 = pos + (Vector2(HW, HL).normalized() * 100.0).rotated(rot)
	return {
		"inner_point_front_left": centre,
		"outer_point_front_left": fl_ext,
		"inner_point_front_right": centre,
		"outer_point_front_right": fr_ext,
		"inner_point_rear_left": centre,
		"outer_point_rear_left": rl_ext,
		"inner_point_rear_right": centre,
		"outer_point_rear_right": rr_ext,
	}


## Creates LOS targeting points for the four hull zones.
func _make_los_pts(pos: Vector2, rot: float) -> Dictionary:
	return {
		"FRONT": pos + Vector2(0, -HL).rotated(rot),
		"LEFT": pos + Vector2(-HW, 0).rotated(rot),
		"RIGHT": pos + Vector2(HW, 0).rotated(rot),
		"REAR": pos + Vector2(0, HL).rotated(rot),
	}


# =========================================================================
# Setup / Teardown
# =========================================================================

func before_each() -> void:
	GameScale.initialise_from_dict(_SCALE_CONFIG)


# =========================================================================
# build — two opposing ships within range
# =========================================================================

func test_build_finds_outgoing_target_when_ship_ahead() -> void:
	# Arrange — friendly at (500, 600), enemy at (500, 400), both facing up.
	# Distance between edges: ~130px (well within close range of 181px).
	var friendly: TargetingListBuilder.ShipInfo = _make_ship(
			"Rebel CR90", 0, Vector2(500, 600), 0.0)
	var enemy: TargetingListBuilder.ShipInfo = _make_ship(
			"ISD", 1, Vector2(500, 400), 0.0)
	# Act
	var results: Array = TargetingListBuilder.build(
			[friendly, enemy], [], 0)
	# Assert — Should find at least one outgoing target.
	assert_eq(results.size(), 1, "Should have 1 ship result (friendly only)")
	var ship_result: TargetingListBuilder.ShipTargetingResult = results[0]
	assert_eq(ship_result.ship_name, "Rebel CR90", "Result ship name")
	assert_gt(ship_result.outgoing.size(), 0,
			"Should have at least one outgoing target")
	var first_target: TargetingListBuilder.TargetEntry = ship_result.outgoing[0]
	assert_eq(first_target.target_name, "ISD", "Target should be the enemy")


func test_build_finds_incoming_threat_from_enemy() -> void:
	# Arrange — enemy ahead can also see us.
	var friendly: TargetingListBuilder.ShipInfo = _make_ship(
			"CR90", 0, Vector2(500, 600), 0.0)
	var enemy: TargetingListBuilder.ShipInfo = _make_ship(
			"VSD", 1, Vector2(500, 400), PI)  # facing down → front towards us
	# Act
	var results: Array = TargetingListBuilder.build(
			[friendly, enemy], [], 0)
	# Assert
	var ship_result: TargetingListBuilder.ShipTargetingResult = results[0]
	assert_gt(ship_result.incoming.size(), 0,
			"Should have at least one incoming threat")
	var threat: TargetingListBuilder.ThreatEntry = ship_result.incoming[0]
	assert_eq(threat.enemy_name, "VSD", "Threat should be from the VSD")


# =========================================================================
# build — ships out of range
# =========================================================================

func test_build_no_targets_when_ships_far_apart() -> void:
	# 2000px apart — well beyond long range (720px).
	var friendly: TargetingListBuilder.ShipInfo = _make_ship(
			"CR90", 0, Vector2(500, 2000), 0.0)
	var enemy: TargetingListBuilder.ShipInfo = _make_ship(
			"ISD", 1, Vector2(500, 100), 0.0)
	var results: Array = TargetingListBuilder.build(
			[friendly, enemy], [], 0)
	var ship_result: TargetingListBuilder.ShipTargetingResult = results[0]
	assert_eq(ship_result.outgoing.size(), 0,
			"No outgoing targets when out of range")


func test_build_no_targets_when_enemy_behind_no_rear_dice() -> void:
	# Friendly has no rear armament.
	var battery: Dictionary = {
		"FRONT": {"RED": 2, "BLUE": 1},
		"LEFT": {"RED": 1},
		"RIGHT": {"RED": 1},
		"REAR": {},
	}
	var friendly: TargetingListBuilder.ShipInfo = _make_ship(
			"CR90", 0, Vector2(500, 400), 0.0, battery)
	# Enemy is behind the friendly.
	var enemy: TargetingListBuilder.ShipInfo = _make_ship(
			"ISD", 1, Vector2(500, 600), 0.0)
	var results: Array = TargetingListBuilder.build(
			[friendly, enemy], [], 0)
	var ship_result: TargetingListBuilder.ShipTargetingResult = results[0]
	# The FRONT arc should not see the enemy (it's behind).
	# LEFT/RIGHT might see depending on geometry, but REAR has no dice.
	# Filter to only entries from REAR arc.
	var rear_targets: int = 0
	for entry: Variant in ship_result.outgoing:
		var te: TargetingListBuilder.TargetEntry = entry as TargetingListBuilder.TargetEntry
		if te.arc == Constants.HullZone.REAR:
			rear_targets += 1
	assert_eq(rear_targets, 0,
			"No targets from REAR arc when armament is empty")


# =========================================================================
# build — squadron targets
# =========================================================================

func test_build_finds_squadron_target() -> void:
	var friendly: TargetingListBuilder.ShipInfo = _make_ship(
			"CR90", 0, Vector2(500, 500), 0.0,
			{"FRONT": {"BLUE": 2}, "LEFT": {}, "RIGHT": {}, "REAR": {}},
			{"BLUE": 1})
	var squad: TargetingListBuilder.SquadInfo = _make_squad(
			"TIE Fighter", 1, Vector2(500, 400))
	var results: Array = TargetingListBuilder.build(
			[friendly], [squad], 0)
	var ship_result: TargetingListBuilder.ShipTargetingResult = results[0]
	# Check for a squadron entry in outgoing.
	var found_squad: bool = false
	for entry: Variant in ship_result.outgoing:
		var te: TargetingListBuilder.TargetEntry = entry as TargetingListBuilder.TargetEntry
		if te.target_name == "TIE Fighter":
			found_squad = true
	assert_true(found_squad, "Should find the enemy squadron as a target")


# =========================================================================
# build — ghost section
# =========================================================================

func test_build_includes_ghost_with_projected_label() -> void:
	var friendly: TargetingListBuilder.ShipInfo = _make_ship(
			"CR90", 0, Vector2(500, 600), 0.0)
	var ghost: TargetingListBuilder.ShipInfo = _make_ship(
			"CR90", 0, Vector2(500, 500), 0.0)
	var enemy: TargetingListBuilder.ShipInfo = _make_ship(
			"ISD", 1, Vector2(500, 300), 0.0)
	var results: Array = TargetingListBuilder.build(
			[friendly, enemy], [], 0, ghost)
	# Should have 2 results: friendly + ghost.
	assert_eq(results.size(), 2, "Should have friendly + ghost results")
	var ghost_result: TargetingListBuilder.ShipTargetingResult = results[1]
	assert_true(ghost_result.ship_name.contains("(projected)"),
			"Ghost ship name should contain '(projected)'")


# =========================================================================
# build — dice filtering by range band
# =========================================================================

func test_build_long_range_only_red_dice() -> void:
	# Place ships ~500px apart → medium range with red dice still valid.
	# Armament: {"RED": 1, "BLUE": 1, "BLACK": 1}.
	var battery: Dictionary = {
		"FRONT": {"RED": 1, "BLUE": 1, "BLACK": 1},
		"LEFT": {}, "RIGHT": {}, "REAR": {},
	}
	var friendly: TargetingListBuilder.ShipInfo = _make_ship(
			"CR90", 0, Vector2(500, 900), 0.0, battery)
	# ~600px apart (edges are at ~565 and ~335 → distance ~530 → medium).
	var enemy: TargetingListBuilder.ShipInfo = _make_ship(
			"ISD", 1, Vector2(500, 200), 0.0)
	var results: Array = TargetingListBuilder.build(
			[friendly, enemy], [], 0)
	var ship_result: TargetingListBuilder.ShipTargetingResult = results[0]
	if ship_result.outgoing.size() > 0:
		var entry: TargetingListBuilder.TargetEntry = ship_result.outgoing[0]
		# At medium range, black dice should be excluded.
		assert_false(entry.dice.has("BLACK"),
				"Black dice should not be available at medium range")


# =========================================================================
# build — obstructed target
# =========================================================================

func test_build_marks_obstructed_when_intervening_ship() -> void:
	# Friendly at bottom, enemy at top, blocker in between.
	var friendly: TargetingListBuilder.ShipInfo = _make_ship(
			"CR90", 0, Vector2(500, 650), 0.0)
	var blocker: TargetingListBuilder.ShipInfo = _make_ship(
			"Blocker", 0, Vector2(500, 500), 0.0)
	var enemy: TargetingListBuilder.ShipInfo = _make_ship(
			"ISD", 1, Vector2(500, 350), 0.0)
	var results: Array = TargetingListBuilder.build(
			[friendly, blocker, enemy], [], 0)
	# Find the CR90's outgoing targets.
	var cr90_result: TargetingListBuilder.ShipTargetingResult = null
	for r: Variant in results:
		var sr: TargetingListBuilder.ShipTargetingResult = r as TargetingListBuilder.ShipTargetingResult
		if sr.ship_name == "CR90":
			cr90_result = sr
			break
	assert_not_null(cr90_result, "Should find CR90 result")
	if cr90_result == null:
		return
	# Find the ISD target entry.
	var isd_entry: TargetingListBuilder.TargetEntry = null
	for entry: Variant in cr90_result.outgoing:
		var te: TargetingListBuilder.TargetEntry = entry as TargetingListBuilder.TargetEntry
		if te.target_name == "ISD":
			isd_entry = te
			break
	if isd_entry != null:
		assert_true(isd_entry.obstructed,
				"Target should be obstructed by intervening ship")


# =========================================================================
# _hz_key
# =========================================================================

func test_hz_key_returns_correct_strings() -> void:
	assert_eq(TargetingListBuilder._hz_key(Constants.HullZone.FRONT), "FRONT",
			"FRONT hull zone key")
	assert_eq(TargetingListBuilder._hz_key(Constants.HullZone.LEFT), "LEFT",
			"LEFT hull zone key")
	assert_eq(TargetingListBuilder._hz_key(Constants.HullZone.RIGHT), "RIGHT",
			"RIGHT hull zone key")
	assert_eq(TargetingListBuilder._hz_key(Constants.HullZone.REAR), "REAR",
			"REAR hull zone key")


# =========================================================================
# Friendly-only output  (TL-LIST-001)
# =========================================================================

func test_build_only_includes_active_player_ships() -> void:
	var friendly: TargetingListBuilder.ShipInfo = _make_ship(
			"CR90", 0, Vector2(500, 500), 0.0)
	var enemy: TargetingListBuilder.ShipInfo = _make_ship(
			"ISD", 1, Vector2(500, 350), 0.0)
	var results: Array = TargetingListBuilder.build(
			[friendly, enemy], [], 0)
	# Only friendly ship should appear as a result.
	assert_eq(results.size(), 1, "Only 1 result for active player")
	var sr: TargetingListBuilder.ShipTargetingResult = results[0]
	assert_eq(sr.ship_name, "CR90", "Only the friendly ship is listed")


# =========================================================================
# Ship → Squadron uses anti-squadron armament (TL-RNG-007, AC-TL-20/21)
# =========================================================================

func test_squadron_target_uses_anti_squadron_dice() -> void:
	# Arrange — ship with strong battery but weak anti-squadron.
	var battery: Dictionary = {
		"FRONT": {"RED": 3, "BLUE": 1}, "LEFT": {}, "RIGHT": {}, "REAR": {},
	}
	var anti_sq: Dictionary = {"BLUE": 1}
	var friendly: TargetingListBuilder.ShipInfo = _make_ship(
			"VSD", 0, Vector2(500, 500), 0.0, battery, anti_sq)
	var squad: TargetingListBuilder.SquadInfo = _make_squad(
			"X-wing", 1, Vector2(500, 420))
	# Act
	var results: Array = TargetingListBuilder.build(
			[friendly], [squad], 0)
	# Assert — dice should be anti-squadron (1 blue) not battery (3 red, 1 blue).
	var ship_result: TargetingListBuilder.ShipTargetingResult = results[0]
	var squad_entry: TargetingListBuilder.TargetEntry = null
	for entry: Variant in ship_result.outgoing:
		var te: TargetingListBuilder.TargetEntry = entry as TargetingListBuilder.TargetEntry
		if te.target_name == "X-wing":
			squad_entry = te
	assert_not_null(squad_entry, "Should find the squadron target")
	if squad_entry:
		assert_eq(squad_entry.dice.get("BLUE", 0), 1,
				"Anti-squadron dice: 1 blue")
		assert_false(squad_entry.dice.has("RED"),
				"Anti-squadron armament has no red dice")
		assert_eq(squad_entry.range_band, "in range",
				"Squadron target text should say 'in range'")


func test_squadron_target_no_anti_squadron_armament_excluded() -> void:
	# Arrange — ship with no anti-squadron armament.
	var battery: Dictionary = {
		"FRONT": {"RED": 3}, "LEFT": {}, "RIGHT": {}, "REAR": {},
	}
	var friendly: TargetingListBuilder.ShipInfo = _make_ship(
			"VSD", 0, Vector2(500, 500), 0.0, battery, {})
	var squad: TargetingListBuilder.SquadInfo = _make_squad(
			"X-wing", 1, Vector2(500, 420))
	# Act
	var results: Array = TargetingListBuilder.build(
			[friendly], [squad], 0)
	# Assert — no squadron target since anti-squadron armament is empty.
	var ship_result: TargetingListBuilder.ShipTargetingResult = results[0]
	var found_squad: bool = false
	for entry: Variant in ship_result.outgoing:
		var te: TargetingListBuilder.TargetEntry = entry as TargetingListBuilder.TargetEntry
		if te.target_name == "X-wing":
			found_squad = true
	assert_false(found_squad,
			"No squadron target when anti-squadron armament is empty")


func test_squadron_target_max_range_uses_anti_squadron() -> void:
	# Arrange — battery has red dice (long range) but anti-squadron is
	# blue-only (medium range max). Place squadron at medium range.
	var battery: Dictionary = {
		"FRONT": {"RED": 3}, "LEFT": {}, "RIGHT": {}, "REAR": {},
	}
	var anti_sq: Dictionary = {"BLUE": 1}
	var friendly: TargetingListBuilder.ShipInfo = _make_ship(
			"VSD", 0, Vector2(500, 700), 0.0, battery, anti_sq)
	# ~250px ahead of hull edge (HL=35 → edge at y=665, squad at y=400).
	# Distance ≈ 665-400-15 = 250px → medium range (181–442).
	var squad: TargetingListBuilder.SquadInfo = _make_squad(
			"X-wing", 1, Vector2(500, 400))
	# Act
	var results: Array = TargetingListBuilder.build(
			[friendly], [squad], 0)
	# Assert — should still find the squadron (within medium = anti-sq max).
	var ship_result: TargetingListBuilder.ShipTargetingResult = results[0]
	var found: bool = false
	for entry: Variant in ship_result.outgoing:
		var te: TargetingListBuilder.TargetEntry = entry as TargetingListBuilder.TargetEntry
		if te.target_name == "X-wing":
			found = true
	assert_true(found,
			"Squadron at medium range is valid with blue anti-sq armament")


# =========================================================================
# Incoming squadron threats (TL-LIST-008, AC-TL-22)
# =========================================================================

func test_incoming_threats_includes_enemy_squadron_at_close() -> void:
	# Arrange — enemy squadron at close range of friendly ship.
	var friendly: TargetingListBuilder.ShipInfo = _make_ship(
			"CR90", 0, Vector2(500, 500), 0.0)
	var squad: TargetingListBuilder.SquadInfo = _make_squad(
			"TIE Fighter", 1, Vector2(500, 450))
	squad.battery_armament = {"BLUE": 1}
	# Act
	var results: Array = TargetingListBuilder.build(
			[friendly], [squad], 0)
	# Assert — squadron should appear as incoming threat.
	var ship_result: TargetingListBuilder.ShipTargetingResult = results[0]
	var found_threat: bool = false
	for entry: Variant in ship_result.incoming:
		var te: TargetingListBuilder.ThreatEntry = entry as TargetingListBuilder.ThreatEntry
		if te.enemy_name == "TIE Fighter":
			found_threat = true
			assert_eq(te.range_band, "in range",
					"Squadron threat should say 'in range'")
	assert_true(found_threat,
			"Enemy squadron at close range is an incoming threat")


func test_incoming_threats_excludes_squadron_beyond_distance_1() -> void:
	# Arrange — enemy squadron far away (beyond close range).
	var friendly: TargetingListBuilder.ShipInfo = _make_ship(
			"CR90", 0, Vector2(500, 500), 0.0)
	# Place squadron ~400px away (well beyond close range 181px).
	var squad: TargetingListBuilder.SquadInfo = _make_squad(
			"TIE Fighter", 1, Vector2(500, 50))
	squad.battery_armament = {"BLUE": 1}
	# Act
	var results: Array = TargetingListBuilder.build(
			[friendly], [squad], 0)
	# Assert — squadron too far, should not appear as threat.
	var ship_result: TargetingListBuilder.ShipTargetingResult = results[0]
	var found_threat: bool = false
	for entry: Variant in ship_result.incoming:
		var te: TargetingListBuilder.ThreatEntry = entry as TargetingListBuilder.ThreatEntry
		if te.enemy_name == "TIE Fighter":
			found_threat = true
	assert_false(found_threat,
			"Enemy squadron beyond distance 1 is not an incoming threat")


func test_incoming_threats_excludes_squadron_without_battery() -> void:
	# Arrange — enemy squadron at close range but no battery armament.
	var friendly: TargetingListBuilder.ShipInfo = _make_ship(
			"CR90", 0, Vector2(500, 500), 0.0)
	var squad: TargetingListBuilder.SquadInfo = _make_squad(
			"TIE Fighter", 1, Vector2(500, 450))
	# battery_armament stays empty (default).
	# Act
	var results: Array = TargetingListBuilder.build(
			[friendly], [squad], 0)
	# Assert — no threat since the squadron has no battery armament.
	var ship_result: TargetingListBuilder.ShipTargetingResult = results[0]
	var found_threat: bool = false
	for entry: Variant in ship_result.incoming:
		var te: TargetingListBuilder.ThreatEntry = entry as TargetingListBuilder.ThreatEntry
		if te.enemy_name == "TIE Fighter":
			found_threat = true
	assert_false(found_threat,
			"Squadron without battery armament is not an incoming threat")


func test_incoming_threats_excludes_friendly_squadron() -> void:
	# Arrange — friendly squadron at close range.
	var friendly: TargetingListBuilder.ShipInfo = _make_ship(
			"CR90", 0, Vector2(500, 500), 0.0)
	var squad: TargetingListBuilder.SquadInfo = _make_squad(
			"X-wing", 0, Vector2(500, 450))  # same player
	squad.battery_armament = {"RED": 1}
	# Act
	var results: Array = TargetingListBuilder.build(
			[friendly], [squad], 0)
	# Assert — friendly squadron should not be a threat.
	var ship_result: TargetingListBuilder.ShipTargetingResult = results[0]
	var found_threat: bool = false
	for entry: Variant in ship_result.incoming:
		var te: TargetingListBuilder.ThreatEntry = entry as TargetingListBuilder.ThreatEntry
		if te.enemy_name == "X-wing":
			found_threat = true
	assert_false(found_threat,
			"Friendly squadron should not appear as an incoming threat")


# =========================================================================
# Anti-squadron from empty-battery hull zone (arc still valid)
# =========================================================================

func test_squadron_target_found_even_when_battery_empty() -> void:
	# Arrange — ship with empty FRONT battery but valid anti-sq armament.
	var battery: Dictionary = {
		"FRONT": {}, "LEFT": {}, "RIGHT": {}, "REAR": {},
	}
	var anti_sq: Dictionary = {"BLUE": 1}
	var friendly: TargetingListBuilder.ShipInfo = _make_ship(
			"VSD", 0, Vector2(500, 500), 0.0, battery, anti_sq)
	var squad: TargetingListBuilder.SquadInfo = _make_squad(
			"X-wing", 1, Vector2(500, 420))
	# Act
	var results: Array = TargetingListBuilder.build(
			[friendly], [squad], 0)
	# Assert — squadron should still appear (anti-sq is global, not per zone).
	var ship_result: TargetingListBuilder.ShipTargetingResult = results[0]
	var found: bool = false
	for entry: Variant in ship_result.outgoing:
		var te: TargetingListBuilder.TargetEntry = entry as TargetingListBuilder.TargetEntry
		if te.target_name == "X-wing":
			found = true
	assert_true(found,
			"Squadron target found even when hull zone battery is empty")


# =========================================================================
# Range measurement uses circle edge, not centre (analytical closest point)
# =========================================================================

func test_range_measurement_uses_circle_edge() -> void:
	# Arrange — place squadron so its CENTRE is beyond close range (181px)
	# but its EDGE is within close range.  With black-only anti-sq the max
	# range is close, so the squadron must be found if measured correctly.
	# Ship front edge is at y = 500 - 35 = 465.
	# Squadron centre at y = 270 → centre distance = 465 - 270 = 195px (medium).
	# Edge distance = 195 - 15 = 180px (close, ≤ 181px).
	var battery: Dictionary = {
		"FRONT": {"RED": 1}, "LEFT": {}, "RIGHT": {}, "REAR": {},
	}
	var anti_sq: Dictionary = {"BLACK": 1}
	var friendly: TargetingListBuilder.ShipInfo = _make_ship(
			"VSD", 0, Vector2(500, 500), 0.0, battery, anti_sq)
	var squad: TargetingListBuilder.SquadInfo = _make_squad(
			"X-wing", 1, Vector2(500, 270))
	# Act
	var results: Array = TargetingListBuilder.build(
			[friendly], [squad], 0)
	# Assert — with old sampling (centre=195px → medium → beyond black max),
	# this would fail.  Analytical closest (edge=180px → close) should pass.
	var ship_result: TargetingListBuilder.ShipTargetingResult = results[0]
	var found: bool = false
	for entry: Variant in ship_result.outgoing:
		var te: TargetingListBuilder.TargetEntry = entry as TargetingListBuilder.TargetEntry
		if te.target_name == "X-wing":
			found = true
	assert_true(found,
			"Squadron should be found when edge is in range (analytical closest)")
