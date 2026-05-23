## Test: GameBoard Scenario Bootstrap
##
## Unit tests for the scenario id handoff between game bootstrap and
## scenario-token spawning.
extends GutTest


class ScenarioCaptureBoard:
	extends GameBoard

	var spawned_scenario_id: String = ""

	func _spawn_learning_scenario_tokens(scenario_id: String) -> void:
		spawned_scenario_id = scenario_id


var _previous_game_state: GameState = null
var _previous_is_game_active: bool = false
var _previous_active_player: int = 0
var _previous_is_state_preloaded: bool = false
var _previous_scenario_id: String = ""
var _previous_next_scenario_id: String = ""
var _previous_play_mode: PlayMode.Mode = PlayMode.Mode.HOT_SEAT
var _previous_network_role: NetworkManager.Role = NetworkManager.Role.NONE
var _previous_pending_config: Dictionary = {}


func before_each() -> void:
	_previous_game_state = GameManager.current_game_state
	_previous_is_game_active = GameManager.is_game_active
	_previous_active_player = GameManager.active_player
	_previous_is_state_preloaded = GameManager.is_state_preloaded
	_previous_scenario_id = GameManager._scenario_id
	_previous_next_scenario_id = GameManager._next_scenario_id
	_previous_play_mode = PlayMode.current_mode
	_previous_network_role = NetworkManager.role
	_previous_pending_config = NetworkManager._pending_game_config.duplicate(true)
	GameManager.is_state_preloaded = false
	GameManager._next_scenario_id = ""


func after_each() -> void:
	GameManager.current_game_state = _previous_game_state
	GameManager.is_game_active = _previous_is_game_active
	GameManager.active_player = _previous_active_player
	GameManager.is_state_preloaded = _previous_is_state_preloaded
	GameManager._scenario_id = _previous_scenario_id
	GameManager._next_scenario_id = _previous_next_scenario_id
	PlayMode.current_mode = _previous_play_mode
	NetworkManager.role = _previous_network_role
	NetworkManager._pending_game_config = _previous_pending_config.duplicate(true)


func test_bootstrap_or_load_board_state_spawns_network_pending_scenario() -> void:
	PlayMode.current_mode = PlayMode.Mode.NETWORK
	NetworkManager.role = NetworkManager.Role.SERVER
	NetworkManager._receive_game_config(12345, LobbyState.SCENARIO_DEBUG_ID)
	var board: ScenarioCaptureBoard = ScenarioCaptureBoard.new()
	autofree(board)

	board._bootstrap_or_load_board_state()

	assert_eq(board.spawned_scenario_id, LobbyState.SCENARIO_DEBUG_ID,
			"Network board spawn should use the scenario from pending game config.")
