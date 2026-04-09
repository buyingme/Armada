## Test: SaveGameManager
##
## Unit tests for SaveGameManager — save / load / list / delete.
## Uses a temporary save-file name to avoid polluting real saves.
extends GutTest


const TEST_SAVE: String = "_gut_test_save"
const SaveManagerScript: GDScript = preload(
		"res://src/autoload/save_game_manager.gd")

var _manager: Node = null


func before_each() -> void:
	# Create a fresh instance (not the global autoload) to isolate tests.
	_manager = SaveManagerScript.new()


func after_each() -> void:
	# Clean up any test save files.
	_manager.delete_save(TEST_SAVE)
	_manager.free()


# --- Helpers ---

func _make_game_state() -> GameState:
	var gs: GameState = GameState.new()
	gs.initialize()
	gs.current_round = 3
	gs.current_phase = Constants.GamePhase.SHIP
	gs.initiative_player = 1
	gs.player_states[0].faction = Constants.Faction.REBEL_ALLIANCE
	gs.player_states[0].score = 45
	gs.player_states[1].faction = Constants.Faction.GALACTIC_EMPIRE
	gs.player_states[1].score = 30
	gs.damage_deck = DamageDeck.new()
	gs.damage_deck.initialize()
	return gs


# --- save_game / load_game round-trip ---

func test_save_and_load_round_trip() -> void:
	var gs: GameState = _make_game_state()
	var ok: bool = _manager.save_game(gs, TEST_SAVE)
	assert_true(ok, "save_game should return true on success")
	var loaded: GameState = _manager.load_game(TEST_SAVE)
	assert_not_null(loaded, "load_game should return a GameState")
	assert_eq(loaded.current_round, 3,
			"Round-trip should preserve current_round")
	assert_eq(loaded.initiative_player, 1,
			"Round-trip should preserve initiative_player")


func test_round_trip_preserves_player_scores() -> void:
	var gs: GameState = _make_game_state()
	_manager.save_game(gs, TEST_SAVE)
	var loaded: GameState = _manager.load_game(TEST_SAVE)
	assert_eq(loaded.player_states[0].score, 45,
			"Round-trip should preserve player 0 score")
	assert_eq(loaded.player_states[1].score, 30,
			"Round-trip should preserve player 1 score")


func test_round_trip_preserves_damage_deck() -> void:
	var gs: GameState = _make_game_state()
	# Draw 5 cards so counts change.
	for i: int in range(5):
		gs.damage_deck.draw_card()
	_manager.save_game(gs, TEST_SAVE)
	var loaded: GameState = _manager.load_game(TEST_SAVE)
	assert_not_null(loaded.damage_deck,
			"Round-trip should restore damage_deck")
	assert_eq(loaded.damage_deck.get_draw_count(),
			DamageDeck.DECK_SIZE - 5,
			"Round-trip should preserve draw count")


# --- load non-existent ---

func test_load_nonexistent_returns_null() -> void:
	var loaded: GameState = _manager.load_game("_nonexistent_12345")
	assert_null(loaded,
			"load_game should return null for missing file")
	assert_push_error(1,
			"load_game should push_error for missing file")


# --- list_saves ---

func test_list_saves_includes_created_file() -> void:
	var gs: GameState = _make_game_state()
	_manager.save_game(gs, TEST_SAVE)
	var saves: Array[String] = _manager.list_saves()
	assert_has(saves, TEST_SAVE,
			"list_saves should include the test save")


# --- delete_save ---

func test_delete_save_removes_file() -> void:
	var gs: GameState = _make_game_state()
	_manager.save_game(gs, TEST_SAVE)
	var deleted: bool = _manager.delete_save(TEST_SAVE)
	assert_true(deleted, "delete_save should return true")
	var saves: Array[String] = _manager.list_saves()
	assert_does_not_have(saves, TEST_SAVE,
			"Deleted save should no longer appear in list")


func test_delete_nonexistent_returns_false() -> void:
	var deleted: bool = _manager.delete_save("_nonexistent_12345")
	assert_false(deleted,
			"delete_save should return false for missing file")
