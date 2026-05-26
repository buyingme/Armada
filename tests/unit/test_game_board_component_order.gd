## Test: GameBoard Component Order
##
## Unit tests for startup ordering between board-level controller dependencies.
extends GutTest


class NoUiSquadronPhaseController:
	extends SquadronPhaseController

	func create_ui(_layer: CanvasLayer, _register_resizable: Callable) -> void:
		pass


class ComponentOrderBoard:
	extends GameBoard

	var creation_order: Array[String] = []
	var tool_overlay_exists_when_target_selector_created: bool = false

	func _ready() -> void:
		pass

	func _record(component_name: String) -> void:
		creation_order.append(component_name)

	func _create_camera() -> void:
		_record("camera")

	func _create_token_container() -> void:
		_record("token_container")
		_token_container = Node2D.new()
		add_child(_token_container)

	func _create_debug_controller() -> void:
		_record("debug_controller")

	func _create_command_phase_controller() -> void:
		_record("command_phase_controller")

	func _create_squadron_phase_controller() -> void:
		_record("squadron_phase_controller")
		_squadron_phase_controller = NoUiSquadronPhaseController.new()
		add_child(_squadron_phase_controller)

	func _create_tool_overlay_controller() -> void:
		_record("tool_overlay_controller")
		_tool_overlay_controller = ToolOverlayController.new()
		add_child(_tool_overlay_controller)

	func _create_target_selector() -> void:
		_record("target_selector")
		tool_overlay_exists_when_target_selector_created = \
				_tool_overlay_controller != null

	func _create_attack_executor() -> void:
		_record("attack_executor")

	func _create_attack_panel_controller() -> void:
		_record("attack_panel_controller")

	func _create_displacement_controller() -> void:
		_record("displacement_controller")

	func _create_ship_activation_controller() -> void:
		_record("ship_activation_controller")

	func _create_dial_drag_controller() -> void:
		_record("dial_drag_controller")


class TargetSelectorConnectionBoard:
	extends GameBoard

	func _ready() -> void:
		pass

	func setup_minimal_dependencies() -> void:
		_token_container = Node2D.new()
		add_child(_token_container)


func test_create_board_components_creates_tool_overlay_before_target_selector() -> void:
	# Arrange
	var board: ComponentOrderBoard = ComponentOrderBoard.new()
	add_child_autofree(board)

	# Act
	board._create_board_components()

	# Assert
	assert_true(board.tool_overlay_exists_when_target_selector_created,
			"TargetSelector startup should see an initialized ToolOverlayController.")
	assert_lt(board.creation_order.find("tool_overlay_controller"),
			board.creation_order.find("target_selector"),
			"ToolOverlayController should be created before TargetSelector wiring.")


func test_create_target_selector_without_tool_overlay_uses_board_delegate() -> void:
	# Arrange
	var board: TargetSelectorConnectionBoard = TargetSelectorConnectionBoard.new()
	add_child_autofree(board)
	board.setup_minimal_dependencies()

	# Act
	board._create_target_selector()

	# Assert
	var delegate: Callable = Callable(board, "_on_dismiss_other_tools_requested")
	assert_not_null(board._target_selector,
			"TargetSelector should be created with minimal board dependencies.")
	assert_true(
			board._target_selector.dismiss_other_tools_requested.is_connected(delegate),
			"TargetSelector should connect to the board delegate, not a nullable controller.")
	board._target_selector.dismiss_other_tools_requested.emit()
