## DBG-001 production-board F12 admission coverage.
extends GutTest


const GAME_BOARD_SCENE: PackedScene = preload(
		"res://src/scenes/game_board/game_board.tscn")

var _saved_state: GameState = null
var _saved_active: bool = false
var _saved_preloaded: bool = false
var _saved_play_mode: PlayMode.Mode
var _saved_network_role: NetworkManager.Role
var _saved_local_player: int = -1


func before_each() -> void:
	_saved_state = GameManager.current_game_state
	_saved_active = GameManager.is_game_active
	_saved_preloaded = GameManager.is_state_preloaded
	_saved_play_mode = PlayMode.current_mode
	_saved_network_role = NetworkManager.role
	_saved_local_player = NetworkManager._local_player_index
	DebugMode.enabled = false
	DebugMode.deselect_token()
	PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
	NetworkManager.role = NetworkManager.Role.NONE
	NetworkManager._local_player_index = -1


func after_each() -> void:
	DebugMode.enabled = false
	DebugMode.deselect_token()
	GameManager.current_game_state = _saved_state
	GameManager.is_game_active = _saved_active
	GameManager.is_state_preloaded = _saved_preloaded
	PlayMode.current_mode = _saved_play_mode
	NetworkManager.role = _saved_network_role
	NetworkManager._local_player_index = _saved_local_player


func test_board_f12_enters_debug_in_hot_seat() -> void:
	var board := _make_live_board()
	board._input(_f12())
	assert_true(DebugMode.enabled)


func test_board_f12_enters_debug_for_network_host() -> void:
	var board := _make_live_board()
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.SERVER
	board._input(_f12())
	assert_true(DebugMode.enabled)


func test_board_f12_rejects_network_client() -> void:
	var board := _make_live_board()
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.CLIENT
	board._input(_f12())
	assert_false(DebugMode.enabled)


func test_board_f12_respects_visible_handoff_overlay() -> void:
	var board := _make_live_board()
	board._panel_mgr.handoff_overlay.show()
	board._input(_f12())
	assert_false(DebugMode.enabled)


func _make_live_board() -> GameBoard:
	var state := GameState.new()
	state.initialize()
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()))
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.damage_deck = DamageDeck.new()
	state.damage_deck.initialize()
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 0))
	var board := GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	return board


func _f12() -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_F12
	return event
