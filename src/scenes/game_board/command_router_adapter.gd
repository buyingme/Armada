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

# ---------------------------------------------------------------------------
# Injected dependencies
# ---------------------------------------------------------------------------

var _attack_panel_controller: AttackPanelController = null
var _debug_controller: DebugController = null
var _modal_router: ModalRouter = null


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
	_create_modal_router(
			panel_mgr,
			attack_panel_controller,
			ship_activation_controller,
			displacement_controller,
			activation_ctx,
			find_ship_token_fn,
			find_squadron_token_fn)


func _create_modal_router(
		panel_mgr: UIPanelManager,
		attack_panel_controller: AttackPanelController,
		ship_activation_controller: ShipActivationController,
		displacement_controller: DisplacementController,
		activation_ctx: ActivationContext,
		find_ship_token_fn: Callable,
		find_squadron_token_fn: Callable) -> void:
	_modal_router = ModalRouter.new()
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
			Callable(self, "_route_to_controllers"))


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
