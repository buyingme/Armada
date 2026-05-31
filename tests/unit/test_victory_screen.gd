## Test: Victory Screen
##
## Unit tests for VictoryScreen — verifies correct display of winner,
## scores, reason, and button existence.
## Rules Reference: WN-001–004.
extends GutTest


func before_each() -> void:
	GameManager.current_game_state = null


func after_each() -> void:
	GameManager.current_game_state = null


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Creates a VictoryScreen, shows it with the given details, and auto-frees.
func _make_screen(details: Dictionary) -> VictoryScreen:
	var screen: VictoryScreen = VictoryScreen.new()
	add_child_autofree(screen)
	screen.show_results(details)
	return screen


## Standard details dictionary for a Rebel win on round 6.
func _rebel_wins_round6() -> Dictionary:
	return {
		"winner_index": 0,
		"reason": "round_6",
		"scores": [73, 50],
		"round": 6,
	}


## Standard details dictionary for an Imperial elimination win.
func _imperial_wins_elimination() -> Dictionary:
	return {
		"winner_index": 1,
		"reason": "elimination",
		"scores": [0, 120],
		"round": 3,
	}


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_shows_correct_winner_rebel() -> void:
	var screen: VictoryScreen = _make_screen(_rebel_wins_round6())
	assert_not_null(screen._title_label,
			"Title label should exist")
	assert_string_contains(screen._title_label.text, "Rebel Alliance",
			"Title should contain winner faction name")
	assert_string_contains(screen._title_label.text, "Wins",
			"Title should say 'Wins'")


func test_shows_correct_winner_imperial() -> void:
	var screen: VictoryScreen = _make_screen(_imperial_wins_elimination())
	assert_string_contains(screen._title_label.text, "Galactic Empire",
			"Title should contain Imperial faction name")


func test_show_results_uses_live_player_state_faction_expected() -> void:
	var state: GameState = GameState.new()
	state.initialize()
	state.get_player_state(0).faction = Constants.Faction.GALACTIC_EMPIRE
	state.get_player_state(1).faction = Constants.Faction.REBEL_ALLIANCE
	GameManager.current_game_state = state

	var screen: VictoryScreen = _make_screen(_rebel_wins_round6())

	assert_string_contains(screen._title_label.text, "Galactic Empire",
			"Victory title should resolve winner faction from live player state.")


func test_shows_scores() -> void:
	var screen: VictoryScreen = _make_screen(_rebel_wins_round6())
	assert_not_null(screen._score_label, "Score label should exist")
	# Winner (Rebel, 73) should appear first.
	assert_string_contains(screen._score_label.text, "73",
			"Score label should contain winner's score")
	assert_string_contains(screen._score_label.text, "50",
			"Score label should contain loser's score")


func test_shows_reason_round_6() -> void:
	var screen: VictoryScreen = _make_screen(_rebel_wins_round6())
	assert_not_null(screen._reason_label, "Reason label should exist")
	assert_string_contains(screen._reason_label.text, "Six Rounds",
			"Reason should mention round completion")
	assert_string_contains(screen._reason_label.text, "Round 6",
			"Reason should show the round number")


func test_shows_reason_elimination() -> void:
	var screen: VictoryScreen = _make_screen(_imperial_wins_elimination())
	assert_string_contains(screen._reason_label.text, "Fleet Eliminated",
			"Reason should mention elimination")


func test_shows_reason_mutual_destruction() -> void:
	var details: Dictionary = {
		"winner_index": 1,
		"reason": "mutual_destruction",
		"scores": [30, 50],
		"round": 4,
	}
	var screen: VictoryScreen = _make_screen(details)
	assert_string_contains(screen._reason_label.text, "Mutual Destruction",
			"Reason should mention mutual destruction")


func test_play_again_button_exists() -> void:
	var screen: VictoryScreen = _make_screen(_rebel_wins_round6())
	assert_not_null(screen._play_again_button,
			"Play Again button should exist")
	assert_eq(screen._play_again_button.text, "Play Again",
			"Play Again button text should match")


func test_quit_button_exists() -> void:
	var screen: VictoryScreen = _make_screen(_rebel_wins_round6())
	assert_not_null(screen._quit_button, "Quit button should exist")
	assert_eq(screen._quit_button.text, "Quit",
			"Quit button text should match")


func test_screen_visible_after_show() -> void:
	var screen: VictoryScreen = _make_screen(_rebel_wins_round6())
	assert_true(screen.visible,
			"Victory screen should be visible after show_results()")
