## CommandRouterAdapter
##
## Composition root for command-result presentation routing on the game board.
## It owns the [ModalRouter] child that subscribes to
## [signal CommandProcessor.command_executed] and delegates non-modal command
## reactions back to this adapter.
##
## Responsibilities (formerly inline on `game_board.gd._on_command_executed_project_ui`):
##   1. Forward the command/result to [AttackPanelController.react_to_command]
##      so the attacker can route defender responses.
##   2. Forward `debug_deal_damage` commands to [DebugController.react_to_command].
##   3. Create [ModalRouter], which computes the local viewer and projects
##      [GameState.interaction_flow] into HUD, modal, and mirror updates.
##
## Extracted from [game_board.gd](game_board.gd) as part of refactoring
## phase K12.
class_name CommandRouterAdapter
extends Node

const MODAL_ROUTER_SCRIPT: GDScript = preload(
		"res://src/scenes/game_board/modal_router.gd")
const TIMING_WINDOW_DEFINITIONS: GDScript = preload(
		"res://src/core/timing_windows/timing_window_definitions.gd")
const TIMING_WINDOW_OPPORTUNITY: GDScript = preload(
		"res://src/core/timing_windows/timing_window_opportunity.gd")

# ---------------------------------------------------------------------------
# Injected dependencies
# ---------------------------------------------------------------------------

var _attack_panel_controller: AttackPanelController = null
var _debug_controller: DebugController = null
var _modal_router: Node = null
var _find_ship_token_fn: Callable = Callable()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Stores command-reaction references and creates the [ModalRouter] child.
##
## All controllers are required. Token-finder callables are forwarded to the
## router for the network displacement modal lifecycle.
func initialize(
		panel_mgr: UIPanelManager,
		attack_panel_controller: AttackPanelController,
		debug_controller: DebugController,
		ship_activation_controller: ShipActivationController,
		displacement_controller: DisplacementController,
		activation_ctx: ActivationContext,
		find_ship_token_fn: Callable,
		find_squadron_token_fn: Callable) -> void:
	_attack_panel_controller = attack_panel_controller
	_debug_controller = debug_controller
	_find_ship_token_fn = find_ship_token_fn
	_create_modal_router(
			panel_mgr,
			attack_panel_controller,
			ship_activation_controller,
			displacement_controller,
			activation_ctx,
			find_ship_token_fn,
			find_squadron_token_fn)


## Dispatches one derived use/decline intent through the active submitter.
## The submitted command still owns all applicability and authorization checks.
func submit_timing_window_intent(intent: Dictionary) -> Dictionary:
	if not _is_structured_timing_window_intent(intent):
		return {}
	var command_type: String = str(intent.get(
			TIMING_WINDOW_OPPORTUNITY.INTENT_KEY_COMMAND_TYPE, ""))
	if _is_timing_window_continuation(command_type):
		return {}
	var command: GameCommand = GameCommand.deserialize({
		"type": command_type,
		"player": int(intent.get(
				TIMING_WINDOW_OPPORTUNITY.INTENT_KEY_PLAYER, -1)),
		"sequence": -1,
		"payload": (intent.get(
				TIMING_WINDOW_OPPORTUNITY.INTENT_KEY_PAYLOAD) \
				as Dictionary).duplicate(true),
	})
	if command == null:
		return {}
	var submitter: CommandSubmitter = GameManager.get_command_submitter()
	if submitter == null:
		return {}
	return submitter.submit(command)


func _create_modal_router(
		panel_mgr: UIPanelManager,
		attack_panel_controller: AttackPanelController,
		ship_activation_controller: ShipActivationController,
		displacement_controller: DisplacementController,
		activation_ctx: ActivationContext,
		find_ship_token_fn: Callable,
		find_squadron_token_fn: Callable) -> void:
	_modal_router = MODAL_ROUTER_SCRIPT.new()
	_modal_router.name = "ModalRouter"
	add_child(_modal_router)
	_modal_router.initialize(
			panel_mgr,
			attack_panel_controller,
			ship_activation_controller,
			displacement_controller,
			activation_ctx,
			find_ship_token_fn,
			find_squadron_token_fn,
			Callable(self, "_route_to_controllers"),
			Callable(self, "submit_timing_window_intent"))


# ---------------------------------------------------------------------------
# Command routing
# ---------------------------------------------------------------------------

## Routes the command to controllers that own command-type-specific
## reactions (attack pipeline, debug damage card chain).
func _route_to_controllers(cmd: GameCommand, result: Dictionary) -> void:
	# Phase K9: attacker-side defender-response routing
	# (commit_defense / select_evade_die / select_redirect_zone /
	# redirect_done / resolve_immediate_effect) lives on
	# [AttackPanelController].
	if _attack_panel_controller != null:
		_attack_panel_controller.react_to_command(cmd, result)
	# DBG-050: when a [DebugDealDamageCommand] is broadcast / executed,
	# emit the visual signals on every peer (so hot-seat, host, and
	# client all refresh the [ShipCardPanel] / hull display) and chain
	# the immediate-effect resolution on the originating peer only.
	# Owned by [DebugController] since Phase K10.
	if cmd != null and _debug_controller != null \
			and cmd.command_type == "debug_deal_damage":
		_debug_controller.react_to_command(cmd, result)
	if cmd != null and cmd.command_type == "persistent_effect_damage":
		_emit_persistent_damage_events(cmd, result)


func _emit_persistent_damage_events(cmd: GameCommand,
		result: Dictionary) -> void:
	var ship: ShipInstance = _persistent_damage_ship(cmd, result)
	if ship == null or result.is_empty():
		return
	EventBus.damage_card_dealt.emit(ship, null, false)
	EventBus.ship_hull_changed.emit(ship, int(result.get("new_hull", 0)))
	if bool(result.get("destroyed", false)):
		var target: Node = _destroyed_ship_signal_target(ship)
		if target != null:
			EventBus.ship_destroyed.emit(target)


func _persistent_damage_ship(cmd: GameCommand,
		result: Dictionary) -> ShipInstance:
	var state: GameState = GameManager.current_game_state
	if state == null:
		return null
	var owner_player: int = int(result.get(
			"owner_player", cmd.payload.get("owner_player", -1)))
	var ship_index: int = int(result.get(
			"ship_index", cmd.payload.get("ship_index", -1)))
	return state.get_ship(owner_player, ship_index)


func _destroyed_ship_signal_target(ship: ShipInstance) -> Node:
	if _find_ship_token_fn.is_valid():
		var token: Variant = _find_ship_token_fn.call(ship)
		if token is Node:
			return token as Node
	return null


func _is_structured_timing_window_intent(intent: Dictionary) -> bool:
	var expected_keys: Array[String] = [
		TIMING_WINDOW_OPPORTUNITY.INTENT_KEY_COMMAND_TYPE,
		TIMING_WINDOW_OPPORTUNITY.INTENT_KEY_PLAYER,
		TIMING_WINDOW_OPPORTUNITY.INTENT_KEY_PAYLOAD,
	]
	for raw_key: Variant in intent.keys():
		if typeof(raw_key) != TYPE_STRING \
				or not expected_keys.has(str(raw_key)):
			return false
	if typeof(intent.get(
			TIMING_WINDOW_OPPORTUNITY.INTENT_KEY_COMMAND_TYPE)) != TYPE_STRING \
			or str(intent.get(
				TIMING_WINDOW_OPPORTUNITY.INTENT_KEY_COMMAND_TYPE, "")).is_empty():
		return false
	var player: Variant = intent.get(
			TIMING_WINDOW_OPPORTUNITY.INTENT_KEY_PLAYER)
	if typeof(player) != TYPE_INT \
			or int(player) < 0 or int(player) >= Constants.PLAYER_COUNT:
		return false
	var payload: Variant = intent.get(
			TIMING_WINDOW_OPPORTUNITY.INTENT_KEY_PAYLOAD)
	if not payload is Dictionary:
		return false
	for key: String in ["lifecycle_id", "source_owner_kind",
			"runtime_source_id", "semantic_key"]:
		if typeof((payload as Dictionary).get(key)) != TYPE_STRING \
				or str((payload as Dictionary).get(key, "")).is_empty():
			return false
	return true


func _is_timing_window_continuation(command_type: String) -> bool:
	for timing_window_id: String in \
			TIMING_WINDOW_DEFINITIONS.all_timing_window_ids():
		var definition: Dictionary = TIMING_WINDOW_DEFINITIONS.get_definition(
				timing_window_id)
		if command_type == str(definition.get(
				TIMING_WINDOW_DEFINITIONS.KEY_CONTINUATION_COMMAND_TYPE, "")):
			return true
	return false
