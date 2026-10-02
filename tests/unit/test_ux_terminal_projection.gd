extends GutTest


var _saved_local_player: int


func before_each() -> void:
	_saved_local_player = NetworkManager._local_player_index


func after_each() -> void:
	NetworkManager._local_player_index = _saved_local_player


func test_terminal_banner_orients_each_viewer_from_one_result() -> void:
	var details: Dictionary = {"result_id": "match-result:7",
		"winner_index": 1, "reason": "elimination",
		"scores": [0, 37], "round": 2}
	var manager := UIPanelManager.new()
	add_child_autofree(manager)
	NetworkManager._local_player_index = -1
	assert_eq(manager._terminal_banner_text(details), "VICTORY")
	NetworkManager._local_player_index = 1
	assert_eq(manager._terminal_banner_text(details), "VICTORY")
	NetworkManager._local_player_index = 0
	assert_eq(manager._terminal_banner_text(details), "DEFEAT")


func test_terminal_delay_is_presentation_only() -> void:
	var manager := UIPanelManager.new()
	add_child_autofree(manager)
	NetworkManager._local_player_index = 0
	var details: Dictionary = {"result_id": "match-result:9",
		"winner_index": 1, "reason": "elimination",
		"scores": [0, 37], "round": 2}
	manager.show_game_end(details)
	var layer: CanvasLayer = manager.get_node_or_null(
			"TerminalMatchBannerLayer") as CanvasLayer
	assert_not_null(layer)
	if layer == null:
		return
	var title: Label = layer.get_node(
			"TerminalMatchBanner/TerminalMatchBannerTitle") as Label
	var timer: Timer = layer.get_node(
			"TerminalMatchPresentationDelay") as Timer
	assert_eq(title.text, "DEFEAT")
	assert_eq(timer.wait_time, 2.0)
	assert_true(timer.time_left > 0.0)
	assert_null(manager.victory_screen)
	assert_eq(manager._terminal_details, details)
