## Test: GameBoard Player Identity
##
## Unit tests for player-state-derived presentation identity helpers.
extends GutTest


func test_is_rebel_panel_left_imperial_player_zero_expected() -> void:
	var board: GameBoard = GameBoard.new()

	var rebel_left: bool = board._is_rebel_panel_left(
			0, int(Constants.Faction.GALACTIC_EMPIRE))

	assert_false(rebel_left,
			"Imperial player 0 should place the Imperial card panel on the left.")
	board.free()


func test_is_rebel_panel_left_rebel_player_one_expected() -> void:
	var board: GameBoard = GameBoard.new()

	var rebel_left: bool = board._is_rebel_panel_left(
			1, int(Constants.Faction.REBEL_ALLIANCE))

	assert_true(rebel_left,
			"Rebel player 1 should still place the Rebel card panel on the left.")
	board.free()
