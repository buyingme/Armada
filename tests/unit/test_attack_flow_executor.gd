## Test: AttackFlowExecutor
##
## Unit tests for pure attack-flow payload construction extracted from
## AttackExecutor in Phase K14a.
extends GutTest

const AttackFlowExecutorScript := preload(
		"res://src/core/combat/attack_flow_executor.gd")


var _executor: RefCounted = null
var _saved_game_state: GameState = null
var _saved_active_player: int = 0


func before_each() -> void:
	_saved_game_state = GameManager.current_game_state
	_saved_active_player = GameManager.active_player
	_executor = AttackFlowExecutorScript.new()


func after_each() -> void:
	GameManager.current_game_state = _saved_game_state
	GameManager.active_player = _saved_active_player


func test_build_clear_target_patch_contains_expected_defaults() -> void:
	var patch: Dictionary = _executor.build_clear_target_patch()
	assert_eq(patch.get("defender_name", "?"), "",
			"defender_name should reset to empty")
	assert_eq(int(patch.get("defender_zone", 999)), -1,
			"defender_zone should reset to -1")
	assert_eq(int(patch.get("modified_damage", -1)), 0,
			"modified_damage should reset to 0")
	assert_eq(bool(patch.get("evade_active", true)), false,
			"evade_active should reset to false")
	assert_eq(bool(patch.get("redirect_active", true)), false,
			"redirect_active should reset to false")


func test_build_clear_target_patch_clears_collection_fields() -> void:
	var patch: Dictionary = _executor.build_clear_target_patch()
	assert_true((patch.get("locked_tokens", null) as Array).is_empty(),
			"locked_tokens should be empty")
	assert_true((patch.get("defense_tokens", null) as Array).is_empty(),
			"defense_tokens should be empty")
	assert_true((patch.get("dice_results", null) as Array).is_empty(),
			"dice_results should be empty")
	assert_true((patch.get("dice_pool", null) as Dictionary).is_empty(),
			"dice_pool should be empty")


func test_compute_attack_identity_patch_without_gamestate_returns_base_fields() -> void:
	var state: AttackState = AttackState.new()
	state.attacker_name = "Nebulon-B"
	state.attacker_zone = Constants.HullZone.FRONT
	state.attacker_zone_name = "FRONT"
	state.defender_name = "Victory"
	state.defender_zone = Constants.HullZone.LEFT

	var patch: Dictionary = _executor.compute_attack_identity_patch(state, null)

	assert_eq(patch.get("attacker_name", ""), "Nebulon-B",
			"attacker_name should mirror state")
	assert_eq(int(patch.get("attacker_zone", -1)), int(Constants.HullZone.FRONT),
			"attacker_zone should mirror state")
	assert_eq(patch.get("defender_name", ""), "Victory",
			"defender_name should mirror state")
	assert_false(patch.has("attacker_kind"),
			"attacker_kind should not be set without GameState")
	assert_false(patch.has("target_kind"),
			"target_kind should not be set without GameState")


func test_compute_attack_identity_patch_ship_attacker_sets_kind_and_player() -> void:
	GameManager.start_new_game()
	var gs: GameState = GameManager.current_game_state
	var ps: PlayerState = gs.get_player_state(0)
	var ship: ShipInstance = _make_ship_instance(0)
	ps.ships.append(ship)

	var ship_token: ShipToken = _make_ship_token(ship)
	var state: AttackState = AttackState.new()
	state.attacker_ship = ship_token
	state.attacker_name = "Attacker"
	state.attacker_zone = Constants.HullZone.FRONT
	state.attacker_zone_name = "FRONT"

	var patch: Dictionary = _executor.compute_attack_identity_patch(state, gs)

	assert_eq(patch.get("attacker_kind", ""), "ship",
			"attacker_kind should be ship")
	assert_eq(int(patch.get("attacker_player", -1)), 0,
			"attacker_player should match ship owner")
	assert_eq(int(patch.get("attacker_ship_index", -1)), 0,
			"attacker_ship_index should resolve in GameState")


func test_compute_attack_identity_patch_squadron_target_sets_target_kind() -> void:
	GameManager.start_new_game()
	var gs: GameState = GameManager.current_game_state
	var ps: PlayerState = gs.get_player_state(1)
	var squad: SquadronInstance = _make_squadron_instance(1)
	ps.squadrons.append(squad)

	var sq_token: SquadronToken = _make_squadron_token(squad)
	var state: AttackState = AttackState.new()
	state.defender_squadron = sq_token
	state.defender_name = "Target Squad"
	state.defender_zone = -1

	var patch: Dictionary = _executor.compute_attack_identity_patch(state, gs)

	assert_eq(patch.get("target_kind", ""), "squadron",
			"target_kind should be squadron")
	assert_eq(int(patch.get("target_squadron_index", -1)), 0,
			"target_squadron_index should resolve in GameState")


func _make_ship_instance(owner_player: int) -> ShipInstance:
	var data: ShipData = ShipData.new()
	data.ship_name = "Test Ship"
	data.hull = 5
	data.max_speed = 2
	data.engineering_value = 3
	data.command_value = 2
	data.shields = {"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1}
	data.defense_tokens = []
	data.navigation_chart = [[1], [0, 1]]
	data.ship_size = Constants.ShipSize.SMALL
	data.faction = Constants.Faction.REBEL_ALLIANCE
	return ShipInstance.create_from_data("test_ship", data, owner_player, 0)


func _make_squadron_instance(owner_player: int) -> SquadronInstance:
	var data: SquadronData = SquadronData.new()
	data.squadron_name = "Test Squadron"
	data.faction = Constants.Faction.GALACTIC_EMPIRE
	data.hull = 3
	data.speed = 3
	data.defense_tokens = []
	data.keywords = []
	return SquadronInstance.create_from_data("test_squad", data, owner_player)


func _make_ship_token(inst: ShipInstance) -> ShipToken:
	var scene: PackedScene = preload("res://src/scenes/tokens/ship_token.tscn")
	var token: ShipToken = scene.instantiate() as ShipToken
	add_child_autofree(token)
	token.bind_instance(inst)
	return token


func _make_squadron_token(inst: SquadronInstance) -> SquadronToken:
	var scene: PackedScene = preload("res://src/scenes/tokens/squadron_token.tscn")
	var token: SquadronToken = scene.instantiate() as SquadronToken
	add_child_autofree(token)
	token.bind_instance(inst)
	return token
