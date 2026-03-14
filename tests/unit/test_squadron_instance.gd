## Test: SquadronInstance
##
## Unit tests for SquadronInstance — runtime squadron state.
## Rules Reference: SU-024–025.
extends GutTest


var _squad_data: SquadronData = null
var _instance: SquadronInstance = null


func before_each() -> void:
	_squad_data = SquadronData.new()
	_squad_data.squadron_name = "Test Squadron"
	_squad_data.hull = 3
	_squad_data.speed = 4
	_squad_data.defense_tokens = ["Brace", "Scatter"]
	_instance = SquadronInstance.create_from_data("test_squad", _squad_data, 1)


# --- Factory / Initialization ---

func test_create_from_data_sets_data_key() -> void:
	assert_eq(_instance.data_key, "test_squad",
			"data_key should match the key passed to factory")


func test_create_from_data_stores_data_ref() -> void:
	assert_eq(_instance.squadron_data, _squad_data,
			"squadron_data reference should be stored")


func test_create_from_data_hull_starts_at_max() -> void:
	assert_eq(_instance.current_hull, 3,
			"current_hull should start at max (3)")


func test_create_from_data_not_activated() -> void:
	assert_false(_instance.activated_this_round,
			"Should start unactivated (SU-025)")


func test_create_from_data_not_engaged() -> void:
	assert_false(_instance.is_engaged,
			"Should start not engaged")


func test_create_from_data_owner_player() -> void:
	assert_eq(_instance.owner_player, 1,
			"owner_player should match factory arg")


func test_create_from_data_defense_tokens() -> void:
	assert_eq(_instance.defense_tokens.size(), 2,
			"Should have 2 defense tokens")
	assert_eq(_instance.defense_tokens[0]["type"], Constants.DefenseToken.BRACE,
			"First token should be BRACE")
	assert_eq(_instance.defense_tokens[1]["type"], Constants.DefenseToken.SCATTER,
			"Second token should be SCATTER")


func test_create_from_data_defense_tokens_all_ready() -> void:
	for token: Dictionary in _instance.defense_tokens:
		assert_eq(token["state"], Constants.DefenseTokenState.READY,
				"All tokens should start READY")


func test_create_no_defense_tokens() -> void:
	var data: SquadronData = SquadronData.new()
	data.squadron_name = "Generic Squad"
	data.hull = 3
	data.speed = 3
	data.defense_tokens = []
	var inst: SquadronInstance = SquadronInstance.create_from_data(
			"generic", data, 0)
	assert_eq(inst.defense_tokens.size(), 0,
			"Generic squadron should have no defense tokens")


# --- Damage ---

func test_is_destroyed_false_initially() -> void:
	assert_false(_instance.is_destroyed(),
			"Squadron should not be destroyed initially")


func test_suffer_damage_reduces_hull() -> void:
	var dealt: int = _instance.suffer_damage(2)
	assert_eq(dealt, 2, "Should deal 2 damage")
	assert_eq(_instance.current_hull, 1, "Hull should be 1 after 2 damage")


func test_suffer_damage_clamped_to_hull() -> void:
	var dealt: int = _instance.suffer_damage(10)
	assert_eq(dealt, 3, "Should only deal up to current hull (3)")
	assert_eq(_instance.current_hull, 0, "Hull should be 0")


func test_is_destroyed_when_hull_zero() -> void:
	_instance.suffer_damage(3)
	assert_true(_instance.is_destroyed(),
			"Squadron should be destroyed at hull 0")


# --- Defense Tokens ---

func test_get_active_token_count() -> void:
	assert_eq(_instance.get_active_token_count(), 2,
			"Both tokens should be active initially")


func test_ready_defense_tokens() -> void:
	_instance.defense_tokens[0]["state"] = Constants.DefenseTokenState.EXHAUSTED
	_instance.ready_defense_tokens()
	assert_eq(_instance.defense_tokens[0]["state"],
			Constants.DefenseTokenState.READY,
			"EXHAUSTED tokens should become READY")


# --- Activation ---

func test_reset_activation() -> void:
	_instance.activated_this_round = true
	_instance.reset_activation()
	assert_false(_instance.activated_this_round,
			"Activation flag should be reset")
