## AttackExecutor
##
## Manages all attack simulator and attack execution logic, extracted from
## GameBoard to reduce file size and improve separation of concerns.
##
## Handles both the free-form attack simulator (Phase 6a) and the attack
## execution flow from ship activation (Phases 6b/6c). Owns the
## AttackSimPanel, AttackSimOverlay, and associated visual aids.
##
## Requirements: AS-*, AE-*, AT-001–007.
## Rules Reference: "Attack", Steps 1–6, pp.2–3.
class_name AttackExecutor
extends Node

## Preloaded script reference for calling static functions without triggering
## STATIC_CALLED_ON_INSTANCE warnings (Constants is an autoload instance).
const ConstantsScript := preload("res://src/autoload/constants.gd")


## Emitted when the attack execution step is fully complete.
## GameBoard should advance the activation state and reopen the modal.
signal attack_exec_completed

## Emitted when the player cancels attack execution (Escape).
## GameBoard should reopen the activation modal without advancing.
signal attack_exec_cancelled

## Emitted when the executor needs GameBoard to dismiss other tools
## (range overlay, targeting list, maneuver tool) before activating.
signal dismiss_other_tools_requested


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Maps Constants.HullZone values to their firing-arc boundary key pairs.
## Each entry has "inner_a"/"outer_a" (left boundary) and
## "inner_b"/"outer_b" (right boundary).
const _ATTACK_SIM_ARC_KEYS: Dictionary = {
	Constants.HullZone.FRONT: {
		"inner_a": "inner_point_front_left",
		"outer_a": "outer_point_front_left",
		"inner_b": "inner_point_front_right",
		"outer_b": "outer_point_front_right",
	},
	Constants.HullZone.LEFT: {
		"inner_a": "inner_point_front_left",
		"outer_a": "outer_point_front_left",
		"inner_b": "inner_point_rear_left",
		"outer_b": "outer_point_rear_left",
	},
	Constants.HullZone.RIGHT: {
		"inner_a": "inner_point_front_right",
		"outer_a": "outer_point_front_right",
		"inner_b": "inner_point_rear_right",
		"outer_b": "outer_point_rear_right",
	},
	Constants.HullZone.REAR: {
		"inner_a": "inner_point_rear_left",
		"outer_a": "outer_point_rear_left",
		"inner_b": "inner_point_rear_right",
		"outer_b": "outer_point_rear_right",
	},
}

## Human-readable zone names for logging and panel display.
const _ZONE_NAMES: Dictionary = {
	Constants.HullZone.FRONT: "FRONT",
	Constants.HullZone.LEFT: "LEFT",
	Constants.HullZone.RIGHT: "RIGHT",
	Constants.HullZone.REAR: "REAR",
}


# ---------------------------------------------------------------------------
# External references (set via initialize)
# ---------------------------------------------------------------------------

## Reference to the parent GameBoard (for get_ship_tokens/get_squadron_tokens).
## Typed as Node2D to avoid a circular class_name dependency with GameBoard.
var _board: Node2D = null

## Container for all token nodes (for adding overlays).
var _token_container: Node2D = null

## Camera node reference (for perspective rotation during defense step).
var _camera: BoardCamera = null

## Shared damage deck for the game.
var _damage_deck: DamageDeck = null

## Resolver for immediate faceup damage card effects (DM-005).
var _immediate_resolver: ImmediateEffectResolver = ImmediateEffectResolver.new()

## Logger instance.
var _log: GameLogger = GameLogger.new("AttackExecutor")


# ---------------------------------------------------------------------------
# Attack Simulator state (Phase 6a / 6a-2)
# ---------------------------------------------------------------------------

## Whether we are in "select attacker" mode.
var _attack_sim_selecting: bool = false

## Whether we are in "select target" mode (attacker already chosen).
## Requirements: AS-TGT-001, AS-TGT-010.
var _attack_sim_target_selecting: bool = false

## Attack simulator info panel (null when not displayed).
var _attack_sim_panel: AttackSimPanel = null

## Attack simulator visual-aid overlay (null when not displayed).
var _attack_sim_overlay: AttackSimOverlay = null

## Range overlay shown as part of the attack simulator.
var _attack_sim_range_overlay: RangeOverlayScene = null


# ---------------------------------------------------------------------------
# Attacker state (stored after attacker selection)
# ---------------------------------------------------------------------------

## The attacking ship token (null if attacker is a squadron).
var _attack_sim_atk_ship: ShipToken = null
## The attacking hull zone (only valid when _attack_sim_atk_ship != null).
var _attack_sim_atk_zone: int = -1
## The attacking squadron token (null if attacker is a ship).
var _attack_sim_atk_squad: SquadronToken = null
## Attacker display name (cached for panel text).
var _attack_sim_atk_name: String = ""
## Attacker zone display name (empty for squadrons).
var _attack_sim_atk_zone_name: String = ""


# ---------------------------------------------------------------------------
# Target state (stored after target selection)
# ---------------------------------------------------------------------------

## The defending ship token (null if target is a squadron).
var _attack_sim_def_ship: ShipToken = null
## The defending hull zone (only valid when _attack_sim_def_ship != null).
var _attack_sim_def_zone: int = -1
## The defending squadron token (null if target is a ship).
var _attack_sim_def_squad: SquadronToken = null
## Target display name (cached for panel text).
var _attack_sim_def_name: String = ""
## Target zone display name (empty for squadrons).
var _attack_sim_def_zone_name: String = ""


# ---------------------------------------------------------------------------
# Attack execution state (Phase 6b-1)
# ---------------------------------------------------------------------------

## Whether the current attack sim session is an actual attack execution
## (from the activation modal) rather than the free-form simulator.
## Requirements: AE-FLOW-001.
var _attack_exec_mode: bool = false

## Whether the executor is in squadron attack execution mode (Squadron Phase).
## When true, the attacker is a squadron (not a ship hull zone).
## Requirements: SQA-ATK-001.
var _attack_exec_squad_mode: bool = false

## The SquadronToken being activated for attack (Squadron Phase only).
var _attack_exec_squad_token: SquadronToken = null

## The ShipToken being activated, whose hull zones are the only valid
## attacker choices during attack execution.
## Requirements: AE-FLOW-002.
var _attack_exec_ship_token: ShipToken = null

## Hull zones already attacked from during this activation.
## Requirements: AE-2HZ-001.
var _attack_exec_fired_zones: Array[int] = []

## Which attack number we are on (0 = first, 1 = second).
## Requirements: AE-2HZ-004.
var _attack_exec_current_attack: int = 0

## Dice roll results for the current attack.
## Requirements: AE-DICE-003.
var _attack_exec_dice_results: Array[Dictionary] = []

## String-keyed dice pool for the current attack.
## Requirements: AE-DICE-001.
var _attack_exec_pool: Dictionary = {}

## Range band of the current attack target.
var _attack_exec_range_band: String = ""

## Whether the CF dial has already been used during this activation's attacks.
var _attack_exec_cf_dial_used: bool = false

## Whether the CF token has already been used during this activation's attacks.
var _attack_exec_cf_token_used: bool = false

## Squadrons already targeted during the current hull zone's anti-squadron
## attack loop (Rules Reference: "Attack", Step 6).
## Requirements: AE-SQ-001.
var _attack_exec_attacked_squads: Array[SquadronToken] = []


# ---------------------------------------------------------------------------
# Phase 6c: Accuracy, Defense Tokens, Damage Resolution
# ---------------------------------------------------------------------------

## Indices of defender defense tokens locked by accuracy icons.
## Requirements: AE-ACC-001–008.
var _attack_exec_locked_tokens: Array[int] = []

## Whether we are in the accuracy spending sub-step.
var _attack_exec_accuracy_step: bool = false

## Whether we are in the defense token spending sub-step.
var _attack_exec_defense_step: bool = false

## Defense tokens spent this attack, keyed by Constants.DefenseToken type.
## Requirements: AE-DEF-001–016.
var _attack_exec_spent_tokens: Dictionary = {}

## Current damage total after defense modifications (brace etc.).
var _attack_exec_modified_damage: int = 0

## Whether Scatter was spent this attack (cancels all dice).
var _attack_exec_scatter_used: bool = false

## How many damage points must still be redirected (Redirect token).
## Requirements: AE-DEF-011–013.
var _attack_exec_redirect_remaining: int = 0

## The hull zone selected for redirect (Constants.HullZone value or -1).
var _attack_exec_redirect_zone: int = -1

## Whether the Contain token was spent (prevents standard critical).
## Requirements: AE-DEF-014.
var _attack_exec_contain_used: bool = false

## Whether the Brace token was spent this attack.
## Requirements: AE-DEF-010.
var _attack_exec_brace_used: bool = false

## Whether we are in the redirect zone click sub-step.
var _attack_exec_redirect_step: bool = false

## Whether we are in the evade die-selection sub-step.
var _attack_exec_evade_step: bool = false

## Queue of defense token indices being processed during commit.
var _defense_commit_queue: Array[int] = []

## Reference to the game's [EffectRegistry] for hook resolution.
## Set via [method set_effect_registry] after game initialisation.
var _effect_registry: EffectRegistry = null


# ===========================================================================
# Public Interface
# ===========================================================================


## Initializes the executor with references to board infrastructure.
func initialize(board: Node2D, token_container: Node2D,
		camera: BoardCamera) -> void:
	_board = board
	_token_container = token_container
	_camera = camera


## Sets the [EffectRegistry] for hook resolution during attacks.
func set_effect_registry(registry: EffectRegistry) -> void:
	_effect_registry = registry


## Sets the shared damage deck reference.
func set_damage_deck(deck: DamageDeck) -> void:
	_damage_deck = deck


## Handles the "Attack Simulator" toolbar button/key press.
## Toggle behaviour: if already active, dismiss. Otherwise activate
## and dismiss any other active tool first.
## Blocked during attack execution mode (use the activation modal instead).
## Requirements: AS-ACT-001, AS-ACT-004, AS-ACT-005, AE-FLOW-005.
func on_simulator_requested() -> void:
	# Block simulator toggle during attack execution.
	if _attack_exec_mode:
		return
	if _attack_sim_selecting or _attack_sim_target_selecting \
			or (_attack_sim_panel and _attack_sim_panel.visible):
		dismiss()
		return
	# Dismiss other tools first (AS-ACT-005).
	dismiss_other_tools_requested.emit()
	_activate_attack_sim()


## Starts the attack execution flow from the activation modal.
## Requirements: AE-FLOW-001, AE-ACT-001.
func start_ship_attack(ship_token: ShipToken) -> void:
	_log.info("Attack step entered — starting attack execution flow.")
	if ship_token == null:
		_log.info("Cannot start attack — no ship token.")
		return
	# Dismiss any other active tool first.
	dismiss_other_tools_requested.emit()
	dismiss()
	# Set attack execution mode.
	_attack_exec_mode = true
	_attack_exec_ship_token = ship_token
	_attack_exec_fired_zones.clear()
	_attack_exec_current_attack = 0
	_attack_exec_dice_results.clear()
	_attack_exec_pool.clear()
	_attack_exec_range_band = ""
	_attack_exec_cf_dial_used = false
	_attack_exec_cf_token_used = false
	_attack_exec_attacked_squads.clear()
	_attack_sim_selecting = true
	# Create the info panel on a CanvasLayer.
	if _attack_sim_panel == null:
		_attack_sim_panel = AttackSimPanel.new()
		var layer: CanvasLayer = CanvasLayer.new()
		layer.name = "AttackSimPanelLayer"
		layer.layer = 90
		add_child(layer)
		layer.add_child(_attack_sim_panel)
	# Connect Done button if not already connected (sim mode compat).
	if not _attack_sim_panel.attack_done_pressed.is_connected(
			_finish_attack_execution):
		_attack_sim_panel.attack_done_pressed.connect(
				_finish_attack_execution)
	# Connect Phase 6b-2 signals.
	_connect_attack_panel_signals()
	var ship_name: String = ""
	if _attack_exec_ship_token.get_ship_data():
		ship_name = _attack_exec_ship_token.get_ship_data().ship_name
	_attack_sim_panel.show_initial_attack_exec(ship_name)
	# Always show Skip Attack so the player can opt out.
	_attack_sim_panel.show_skip_attack_button()
	# Auto-skip if no valid targets exist from any hull zone.
	## Rules Reference: "Attack", p.2 — a ship is not required to attack.
	if not _attack_exec_has_any_valid_target():
		_log.info("No valid targets from any hull zone — auto-skipping.")
		if _attack_sim_panel:
			_attack_sim_panel.hide_skip_attack_button()
		_finish_attack_execution()
		return
	# Show range overlay for the activated ship.
	if _attack_sim_range_overlay:
		_attack_sim_range_overlay.queue_free()
		_attack_sim_range_overlay = null
	_attack_sim_range_overlay = RangeOverlayScene.new()
	_attack_sim_range_overlay.name = "AttackExecRangeOverlay"
	_token_container.add_child(_attack_sim_range_overlay)
	_token_container.move_child(_attack_sim_range_overlay, 0)
	_attack_sim_range_overlay.setup(_attack_exec_ship_token)
	_log.info("Attack execution: range overlay shown, awaiting hull zone.")


## Starts the squadron attack execution flow from the Squadron Activation
## Modal.  Pre-selects the squadron as attacker; enters target selection.
## Requirements: SQA-ATK-001, SQA-ATK-002.
func start_squadron_attack(squadron_token: SquadronToken) -> void:
	_log.info("Squadron attack step entered.")
	if squadron_token == null:
		_log.info("Cannot start squadron attack — no token.")
		return
	dismiss_other_tools_requested.emit()
	dismiss()
	# Set execution mode flags.
	_attack_exec_mode = true
	_attack_exec_squad_mode = true
	_attack_exec_squad_token = squadron_token
	_attack_exec_ship_token = null
	_attack_exec_fired_zones.clear()
	_attack_exec_current_attack = 0
	_attack_exec_dice_results.clear()
	_attack_exec_pool.clear()
	_attack_exec_range_band = ""
	_attack_exec_cf_dial_used = false
	_attack_exec_cf_token_used = false
	_attack_exec_attacked_squads.clear()
	# Pre-select the squadron as attacker.
	var inst: SquadronInstance = squadron_token.get_squadron_instance()
	var squad_name: String = "Squadron"
	if inst and inst.squadron_data:
		squad_name = inst.squadron_data.squadron_name
	_attack_sim_atk_ship = null
	_attack_sim_atk_zone = -1
	_attack_sim_atk_squad = squadron_token
	_attack_sim_atk_name = squad_name
	_attack_sim_atk_zone_name = ""
	# Enter target selection mode directly.
	_attack_sim_selecting = false
	_attack_sim_target_selecting = true
	# Create the info panel on a CanvasLayer.
	if _attack_sim_panel == null:
		_attack_sim_panel = AttackSimPanel.new()
		var layer: CanvasLayer = CanvasLayer.new()
		layer.name = "AttackSimPanelLayer"
		layer.layer = 90
		add_child(layer)
		layer.add_child(_attack_sim_panel)
	if not _attack_sim_panel.attack_done_pressed.is_connected(
			_finish_attack_execution):
		_attack_sim_panel.attack_done_pressed.connect(
				_finish_attack_execution)
	_connect_attack_panel_signals()
	_attack_sim_panel.show_initial_squadron_exec(squad_name)
	_attack_sim_panel.show_skip_attack_button()
	# Show visual aids for the squadron.
	_attack_sim_show_squadron_visuals(squadron_token)
	_log.info("Squadron attack: target selection active for %s." % squad_name)


## Routes a ship token click. Returns true if handled.
func handle_ship_click(token: ShipToken) -> bool:
	if _attack_sim_target_selecting:
		_attack_sim_handle_target_ship_click(token)
		return true
	if _attack_sim_selecting:
		_attack_sim_handle_ship_click(token)
		return true
	return false


## Routes a squadron token click. Returns true if handled.
func handle_squadron_click(token: SquadronToken) -> bool:
	if _attack_sim_target_selecting:
		_attack_sim_handle_target_squadron_click(token)
		return true
	if _attack_sim_selecting:
		_attack_sim_handle_squadron_click(token)
		return true
	return false


## Handles Escape key press. Returns true if consumed.
## In attack execution mode, cancels back to the activation modal.
## Requirements: AS-ACT-003, AS-TGT-022, AE-FLOW-004.
func handle_escape(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.keycode != KEY_ESCAPE:
		return false
	if _attack_sim_selecting or _attack_sim_target_selecting \
			or (_attack_sim_panel and _attack_sim_panel.visible):
		var was_exec: bool = _attack_exec_mode
		dismiss()
		if was_exec:
			_reset_exec_state()
			attack_exec_cancelled.emit()
		get_viewport().set_input_as_handled()
		return true
	return false


## Dismisses the attack simulator/executor, removing all visual aids.
## Requirements: AS-ACT-003, AS-PNL-003, AS-TGT-022.
func dismiss() -> void:
	_attack_sim_selecting = false
	_attack_sim_target_selecting = false
	_attack_sim_clear_attacker_state()
	_attack_sim_clear_target_state()
	# Remove info panel.
	if _attack_sim_panel:
		_attack_sim_panel.close()
	# Remove visual overlay.
	if _attack_sim_overlay:
		_attack_sim_overlay.queue_free()
		_attack_sim_overlay = null
	# Remove attack sim range overlay.
	if _attack_sim_range_overlay:
		_attack_sim_range_overlay.queue_free()
		_attack_sim_range_overlay = null
	_log.info("Attack simulator dismissed.")


## Whether the executor has any active UI.
func is_active() -> bool:
	return _attack_sim_selecting or _attack_sim_target_selecting \
			or (_attack_sim_panel != null and _attack_sim_panel.visible)


## Whether in attacker-selection mode.
func is_selecting() -> bool:
	return _attack_sim_selecting


## Whether in target-selection mode.
func is_target_selecting() -> bool:
	return _attack_sim_target_selecting


## Whether in attack execution mode (from activation modal).
func is_in_exec_mode() -> bool:
	return _attack_exec_mode


## Returns true if the given ship has at least one valid attack target
## from any of its four hull zones. Unlike [method _attack_exec_has_any_valid_target]
## this does NOT exclude fired zones — it is used before the attack step
## begins to decide whether the modal should auto-skip the Attack step.
## Rules Reference: "Attack", p.2 — a ship is not required to attack.
func has_any_attack_target(ship_token: ShipToken) -> bool:
	if ship_token == null:
		return false
	var all_zones: Array[int] = [
		Constants.HullZone.FRONT, Constants.HullZone.LEFT,
		Constants.HullZone.RIGHT, Constants.HullZone.REAR,
	]
	for zone: int in all_zones:
		if _attack_exec_zone_has_targets(
				ship_token, zone as Constants.HullZone):
			return true
	return false


# ===========================================================================
# Internal Helpers
# ===========================================================================


## Resets all attack execution state variables.
func _reset_exec_state() -> void:
	_attack_exec_mode = false
	_attack_exec_squad_mode = false
	_attack_exec_squad_token = null
	_attack_exec_ship_token = null
	_attack_exec_fired_zones.clear()
	_attack_exec_current_attack = 0
	_attack_exec_dice_results.clear()
	_attack_exec_pool.clear()
	_attack_exec_range_band = ""
	_attack_exec_cf_dial_used = false
	_attack_exec_cf_token_used = false
	_attack_exec_attacked_squads.clear()
	_attack_exec_locked_tokens.clear()
	_attack_exec_accuracy_step = false
	_attack_exec_defense_step = false
	_attack_exec_spent_tokens.clear()
	_defense_commit_queue.clear()
	_attack_exec_modified_damage = 0
	_attack_exec_scatter_used = false
	_attack_exec_redirect_remaining = 0
	_attack_exec_redirect_zone = -1
	_attack_exec_contain_used = false
	_attack_exec_brace_used = false
	_attack_exec_redirect_step = false
	_attack_exec_evade_step = false


## Completes the attack execution step. Cleans up and signals GameBoard.
## Requirements: AE-FLOW-003, AE-CONF-002.
func _finish_attack_execution() -> void:
	_log.info("Attack execution done — completing attack step.")
	dismiss()
	_reset_exec_state()
	attack_exec_completed.emit()


## Clears stored attacker state.
func _attack_sim_clear_attacker_state() -> void:
	_attack_sim_atk_ship = null
	_attack_sim_atk_zone = -1
	_attack_sim_atk_squad = null
	_attack_sim_atk_name = ""
	_attack_sim_atk_zone_name = ""


## Clears stored target state.
func _attack_sim_clear_target_state() -> void:
	_attack_sim_def_ship = null
	_attack_sim_def_zone = -1
	_attack_sim_def_squad = null
	_attack_sim_def_name = ""
	_attack_sim_def_zone_name = ""


## Returns the damage total for the current dice pool, using the correct
## formula for the combatant types. Critical icons only count as damage when
## both attacker and defender are ships; if either combatant is a squadron
## the no-critical formula is used.
## After the base calculation, the ATTACK_CALC_DAMAGE hook is resolved
## so keyword effects (e.g. Bomber) can adjust the total.
## Rules Reference: "Dice Icons", p.5 — "Critical: If the attacker and
## defender are ships, this icon adds one damage to the damage total."
func _calc_attack_damage(results: Array[Dictionary]) -> int:
	var base_damage: int
	# Critical icons only add damage when BOTH attacker and defender are ships.
	# If either combatant is a squadron, use the no-critical formula.
	if _attack_sim_def_squad != null or _attack_sim_atk_squad != null:
		base_damage = Dice.calculate_damage_vs_squadron(results)
	else:
		base_damage = Dice.calculate_damage(results)
	# Resolve ATTACK_CALC_DAMAGE hook for keyword effects (e.g. Bomber).
	if _effect_registry != null:
		var ctx: EffectContext = EffectContext.new()
		ctx.dice_results = results
		ctx.damage_total = base_damage
		# Determine attacker/defender RefCounted references.
		if _attack_sim_atk_ship != null and _attack_sim_atk_ship is ShipToken:
			ctx.attacker = (_attack_sim_atk_ship as ShipToken).get_ship_instance()
		if _attack_sim_atk_squad != null:
			ctx.attacker = _attack_sim_atk_squad.get_squadron_instance()
		if _attack_sim_def_squad != null:
			ctx.defender = _attack_sim_def_squad.get_squadron_instance()
		elif _attack_sim_def_ship != null and _attack_sim_def_ship is ShipToken:
			ctx.defender = (_attack_sim_def_ship as ShipToken).get_ship_instance()
		ctx = _effect_registry.resolve_hook(&"ATTACK_CALC_DAMAGE", ctx)
		return ctx.damage_total
	return base_damage


# ===========================================================================
# Attack Simulator — Activation & Attacker Selection (Phase 6a)
# ===========================================================================


## Enters attacker-selection mode and shows the info panel.
## Requirements: AS-ACT-001, AS-PNL-001, AS-PNL-002.
func _activate_attack_sim() -> void:
	_attack_sim_selecting = true
	# Create the info panel on a CanvasLayer for screen-space display.
	if _attack_sim_panel == null:
		_attack_sim_panel = AttackSimPanel.new()
		var layer: CanvasLayer = CanvasLayer.new()
		layer.name = "AttackSimPanelLayer"
		layer.layer = 90
		add_child(layer)
		layer.add_child(_attack_sim_panel)
	_attack_sim_panel.show_initial()
	_log.info("Attack simulator activated.")


## Handles a ship token click during attacker selection.
## Determines the hull zone from the click position and sets up visual aids.
## Requirements: AS-SEL-001, AS-SEL-002, AE-FLOW-002.
func _attack_sim_handle_ship_click(token: ShipToken) -> void:
	# Attack execution guard: only activated ship allowed as attacker.
	if _attack_exec_mode and token != _attack_exec_ship_token:
		_log.info("Attack exec: non-activated ship rejected as attacker.")
		TooltipManager.show_text("Only the activated ship can attack.",
				Vector2.INF, 2.0, true)
		return
	# Determine hull zone from click position.
	var click_pos: Vector2 = token.get_global_mouse_position()
	var zone: int = token.get_hull_zone_at(click_pos)
	if zone < 0:
		_log.debug("Click outside ship base — ignored.")
		return
	# Block hull zones already attacked from (two-HZ rule).
	# Requirements: AE-2HZ-002.
	if _attack_exec_mode and zone in _attack_exec_fired_zones:
		var fired_name: String = _ZONE_NAMES.get(zone, "UNKNOWN")
		_log.info("Attack exec: zone %s already used." % fired_name)
		TooltipManager.show_text(
				"%s arc already used this activation." % fired_name,
				Vector2.INF, 2.0, true)
		return
	var zone_name: String = _ZONE_NAMES.get(zone, "UNKNOWN")
	var ship_name: String = ""
	if token.get_ship_data():
		ship_name = token.get_ship_data().ship_name
	_log.info("Attacker selected: %s — %s arc." % [ship_name, zone_name])
	_log.debug("Click at %s → %s hull zone." % [click_pos, zone_name])
	# Store attacker state.
	_attack_sim_atk_ship = token
	_attack_sim_atk_zone = zone
	_attack_sim_atk_squad = null
	_attack_sim_atk_name = ship_name
	_attack_sim_atk_zone_name = zone_name
	# End attacker selection, enter target selection.
	_attack_sim_selecting = false
	_attack_sim_target_selecting = true
	# Update info panel.
	if _attack_sim_panel:
		_attack_sim_panel.show_hull_zone_selected(ship_name, zone_name)
	# Show visual aids.
	_attack_sim_show_hull_zone_visuals(token, zone)


## Creates the visual aids for a hull zone attacker: range overlay, arc
## boundary lines, and LOS marker.
## Requirements: AS-VIS-001, AS-VIS-002, AS-VIS-003.
func _attack_sim_show_hull_zone_visuals(token: ShipToken,
		zone: int) -> void:
	# Clear any previous visuals.
	if _attack_sim_overlay:
		_attack_sim_overlay.queue_free()
		_attack_sim_overlay = null
	if _attack_sim_range_overlay:
		_attack_sim_range_overlay.queue_free()
		_attack_sim_range_overlay = null
	# Range overlay (reuse RangeOverlayScene).
	_attack_sim_range_overlay = RangeOverlayScene.new()
	_attack_sim_range_overlay.name = "AttackSimRangeOverlay"
	_token_container.add_child(_attack_sim_range_overlay)
	_token_container.move_child(_attack_sim_range_overlay, 0)
	_attack_sim_range_overlay.setup(token)
	# Firing arc boundary lines + LOS marker via AttackSimOverlay.
	var arc_pts: Dictionary = token.get_firing_arc_world_points()
	var los_pts: Dictionary = token.get_los_origins_world()
	var keys: Dictionary = _ATTACK_SIM_ARC_KEYS.get(zone, {})
	if keys.is_empty() or arc_pts.is_empty():
		_log.warn("No arc boundary data for zone %s." % zone)
		return
	var inner_a: Vector2 = arc_pts.get(keys["inner_a"], Vector2.ZERO)
	var outer_a: Vector2 = arc_pts.get(keys["outer_a"], Vector2.ZERO)
	var inner_b: Vector2 = arc_pts.get(keys["inner_b"], Vector2.ZERO)
	var outer_b: Vector2 = arc_pts.get(keys["outer_b"], Vector2.ZERO)
	var zone_name: String = _ZONE_NAMES.get(zone, "FRONT")
	var los_pos: Vector2 = los_pts.get(zone_name, Vector2.ZERO)
	_attack_sim_overlay = AttackSimOverlay.new()
	_attack_sim_overlay.name = "AttackSimOverlay"
	_attack_sim_overlay.attack_execution_mode = _attack_exec_mode
	_token_container.add_child(_attack_sim_overlay)
	_attack_sim_overlay.setup_hull_zone(inner_a, outer_a, inner_b, outer_b,
			los_pos)


## Handles a squadron token click during attacker selection.
## Requirements: AS-SEL-010, AS-SEL-011, AE-FLOW-002.
func _attack_sim_handle_squadron_click(token: SquadronToken) -> void:
	# Attack execution guard: only the activated ship's hull zones may attack.
	if _attack_exec_mode:
		_log.info("Attack exec: squadron cannot be attacker.")
		TooltipManager.show_text("Select a hull zone on the activated ship.",
				Vector2.INF, 2.0, true)
		return
	var inst: SquadronInstance = token.get_squadron_instance()
	var squad_name: String = "Squadron"
	if inst and inst.squadron_data:
		squad_name = inst.squadron_data.squadron_name
	_log.info("Attacker selected: %s." % squad_name)
	# Store attacker state.
	_attack_sim_atk_ship = null
	_attack_sim_atk_zone = -1
	_attack_sim_atk_squad = token
	_attack_sim_atk_name = squad_name
	_attack_sim_atk_zone_name = ""
	# End attacker selection, enter target selection.
	_attack_sim_selecting = false
	_attack_sim_target_selecting = true
	# Update info panel.
	if _attack_sim_panel:
		_attack_sim_panel.show_squadron_selected(squad_name)
	# Show visual aids.
	_attack_sim_show_squadron_visuals(token)


## Creates the visual aids for a squadron attacker: close-range circle.
## Requirements: AS-VIS-010.
func _attack_sim_show_squadron_visuals(token: SquadronToken) -> void:
	# Clear any previous visuals.
	if _attack_sim_overlay:
		_attack_sim_overlay.queue_free()
		_attack_sim_overlay = null
	if _attack_sim_range_overlay:
		_attack_sim_range_overlay.queue_free()
		_attack_sim_range_overlay = null
	_attack_sim_overlay = AttackSimOverlay.new()
	_attack_sim_overlay.name = "AttackSimOverlay"
	_token_container.add_child(_attack_sim_overlay)
	_attack_sim_overlay.setup_squadron(
			token.global_position, token.get_radius_px())


# ===========================================================================
# Attack Simulator — Target Selection (Phase 6a-2)
# ===========================================================================


## Handles a ship token click during target selection.
## Checks for deselection (same attacker hull zone), same-ship guard,
## arc containment, or sets the target.
## Requirements: AS-TGT-001–003, AS-TGT-020–021, AS-TGT-030, AS-ARC-001,
## AE-TGT-001.
func _attack_sim_handle_target_ship_click(token: ShipToken) -> void:
	var click_pos: Vector2 = token.get_global_mouse_position()
	var zone: int = token.get_hull_zone_at(click_pos)
	if zone < 0:
		_log.debug("Target click outside ship base — ignored.")
		return
	# Dice-phase guard: once the dice sequence has started (pool computed),
	# only allow deselecting the current target. Ignore all other clicks
	# to prevent spurious "not in arc" errors.
	if _attack_exec_mode and _attack_exec_pool.size() > 0:
		if _attack_sim_def_ship == token and _attack_sim_def_zone == zone:
			_log.info("Target deselected during dice phase — resetting.")
			_attack_exec_reset_dice_ui()
			_attack_sim_deselect_target()
		return
	# Check: clicking the attacker hull zone → deselect both (AS-TGT-021).
	# But NOT during the Step 6 squadron loop — hull zone is locked.
	if _attack_sim_atk_ship == token and _attack_sim_atk_zone == zone:
		if _attack_exec_mode and _attack_exec_attacked_squads.size() > 0:
			_log.info("Hull zone locked during squadron loop.")
			TooltipManager.show_text(
					"Hull zone is locked during anti-squadron attacks.",
					Vector2.INF, 2.0, true)
			return
		_log.info("Attacker re-clicked — both deselected.")
		_attack_sim_deselect_both()
		return
	# Check: clicking the current target hull zone → deselect target
	# (AS-TGT-020).
	if _attack_sim_def_ship == token and _attack_sim_def_zone == zone:
		_log.info("Target deselected.")
		_attack_sim_deselect_target()
		return
	# Same-ship guard: different zone on the same ship → reject
	# (AS-TGT-030).
	if _attack_sim_atk_ship == token:
		_log.info("Target rejected: same ship as attacker.")
		TooltipManager.show_text("Cannot target the same ship.",
				Vector2.INF, 2.0, true)
		return
	# Faction guard: in attack execution mode, only enemy ships
	# (AE-TGT-001).
	if _attack_exec_mode:
		var atk_faction: Constants.Faction = Constants.Faction.REBEL_ALLIANCE
		if _attack_exec_ship_token:
			atk_faction = _attack_exec_ship_token.get_faction()
		elif _attack_exec_squad_token:
			atk_faction = _attack_exec_squad_token.get_faction()
		if token.get_faction() == atk_faction:
			_log.info("Attack exec: same-faction target rejected.")
			TooltipManager.show_text("Cannot target a friendly ship.",
					Vector2.INF, 2.0, true)
			return
	# Arc check for ship attacker → ship target (AS-ARC-001).
	if _attack_sim_atk_ship:
		if not _attack_sim_is_ship_target_in_arc(token, zone):
			_log.info("Target rejected: not in arc.")
			TooltipManager.show_text("Defender is not in arc.",
					Vector2.INF, 2.0, true)
			return
	# New target selected.
	var zone_name: String = _ZONE_NAMES.get(zone, "UNKNOWN")
	var ship_name: String = ""
	if token.get_ship_data():
		ship_name = token.get_ship_data().ship_name
	_log.info("Target selected: %s — %s arc." % [ship_name, zone_name])
	# Store target state.
	_attack_sim_def_ship = token
	_attack_sim_def_zone = zone
	_attack_sim_def_squad = null
	_attack_sim_def_name = ship_name
	_attack_sim_def_zone_name = zone_name
	# Compute and display LOS + range.
	_attack_sim_compute_and_show_los()


## Handles a squadron token click during target selection.
## Checks for deselection (same attacker squadron), arc containment,
## or sets the target.
## Requirements: AS-TGT-010–012, AS-TGT-020–021, AS-ARC-001–002.
func _attack_sim_handle_target_squadron_click(
		token: SquadronToken) -> void:
	# Dice-phase guard: once the dice sequence has started (pool computed),
	# only allow deselecting the current target. Ignore all other clicks
	# to prevent spurious "not in arc" errors.
	if _attack_exec_mode and _attack_exec_pool.size() > 0:
		if _attack_sim_def_squad == token:
			_log.info("Target deselected during dice phase — resetting.")
			_attack_exec_reset_dice_ui()
			_attack_sim_deselect_target()
		return
	# Check: clicking the attacker squadron → deselect both (AS-TGT-021).
	# In squadron exec mode the attacker is pre-selected and has only one
	# hull zone (its base), so deselection is not allowed (SQA-ATK-006).
	if _attack_sim_atk_squad == token:
		if _attack_exec_squad_mode:
			_log.info("Attacker re-clicked in squad exec — ignored.")
			return
		_log.info("Attacker re-clicked — both deselected.")
		_attack_sim_deselect_both()
		return
	# Check: clicking the current target squadron → deselect target
	# (AS-TGT-020).
	if _attack_sim_def_squad == token:
		_log.info("Target deselected.")
		_attack_sim_deselect_target()
		return
	# Arc check for ship attacker → squadron target (AS-ARC-001).
	# Skipped when attacker is a squadron (AS-ARC-002).
	if _attack_sim_atk_ship:
		if not _attack_sim_is_squadron_target_in_arc(token):
			_log.info("Target rejected: not in arc.")
			TooltipManager.show_text("Defender is not in arc.",
					Vector2.INF, 2.0, true)
			return
	# Faction guard: in attack execution mode, only enemy squadrons.
	if _attack_exec_mode:
		var atk_faction: Constants.Faction = Constants.Faction.REBEL_ALLIANCE
		if _attack_exec_ship_token:
			atk_faction = _attack_exec_ship_token.get_faction()
		elif _attack_exec_squad_token:
			atk_faction = _attack_exec_squad_token.get_faction()
		if token.get_faction() == atk_faction:
			_log.info("Attack exec: same-faction squadron rejected.")
			TooltipManager.show_text(
					"Cannot target a friendly squadron.",
					Vector2.INF, 2.0, true)
			return
	# Already-attacked guard (Step 6): each squadron targeted only once.
	# Requirements: AE-SQ-002.
	# Rules Reference: "Attack", Step 6, p.2 — "Each enemy squadron can
	# be targeted only once per attack."
	if _attack_exec_mode and token in _attack_exec_attacked_squads:
		var inst_name: String = "Squadron"
		var sq_inst: SquadronInstance = token.get_squadron_instance()
		if sq_inst and sq_inst.squadron_data:
			inst_name = sq_inst.squadron_data.squadron_name
		_log.info("Attack exec: %s already attacked this activation." \
				% inst_name)
		TooltipManager.show_text(
				"%s has already been attacked." % inst_name,
				Vector2.INF, 2.0, true)
		return
	# New target selected.
	var inst: SquadronInstance = token.get_squadron_instance()
	var squad_name: String = "Squadron"
	if inst and inst.squadron_data:
		squad_name = inst.squadron_data.squadron_name
	_log.info("Target selected: %s." % squad_name)
	# Store target state.
	_attack_sim_def_ship = null
	_attack_sim_def_zone = -1
	_attack_sim_def_squad = token
	_attack_sim_def_name = squad_name
	_attack_sim_def_zone_name = ""
	# Compute and display LOS + range.
	_attack_sim_compute_and_show_los()


## Resets all dice-sequence UI elements and internal dice state.
## Called when deselecting a target during the dice phase so the
## panel returns cleanly to target-selection mode.
func _attack_exec_reset_dice_ui() -> void:
	_attack_exec_pool.clear()
	_attack_exec_dice_results.clear()
	_attack_exec_range_band = ""
	if _attack_sim_panel:
		_attack_sim_panel.hide_dice_count()
		_attack_sim_panel.hide_dice_results()
		_attack_sim_panel.hide_cf_dial_section()
		_attack_sim_panel.hide_cf_token_section()
		_attack_sim_panel.hide_roll_button()
		_attack_sim_panel.hide_confirm_button()
		_attack_sim_panel.hide_skip_attack_button()


## Deselects the target only; returns to "Select a target" prompt.
## Attacker visuals remain active.
## Requirements: AS-TGT-020.
func _attack_sim_deselect_target() -> void:
	_attack_sim_clear_target_state()
	# Remove target visuals from overlay (keep attacker visuals).
	if _attack_sim_overlay:
		_attack_sim_overlay.clear_target()
	# Hide dice count when target is deselected.
	if _attack_sim_panel:
		_attack_sim_panel.hide_dice_count()
	# Restore "Select a target" prompt.
	if _attack_sim_panel:
		if _attack_sim_atk_zone_name != "":
			_attack_sim_panel.show_hull_zone_selected(
					_attack_sim_atk_name, _attack_sim_atk_zone_name)
		else:
			_attack_sim_panel.show_squadron_selected(_attack_sim_atk_name)


## Deselects both attacker and target; returns to initial prompt.
## Requirements: AS-TGT-021.
func _attack_sim_deselect_both() -> void:
	_attack_sim_clear_attacker_state()
	_attack_sim_clear_target_state()
	_attack_sim_target_selecting = false
	_attack_sim_selecting = true
	# Remove all visuals.
	if _attack_sim_overlay:
		_attack_sim_overlay.queue_free()
		_attack_sim_overlay = null
	if _attack_sim_range_overlay:
		_attack_sim_range_overlay.queue_free()
		_attack_sim_range_overlay = null
	# Show initial prompt.
	if _attack_sim_panel:
		_attack_sim_panel.hide_dice_count()
		if _attack_exec_mode and _attack_exec_ship_token:
			# Restore range overlay for activated ship.
			_attack_sim_range_overlay = RangeOverlayScene.new()
			_attack_sim_range_overlay.name = "AttackExecRangeOverlay"
			_token_container.add_child(_attack_sim_range_overlay)
			_token_container.move_child(_attack_sim_range_overlay, 0)
			_attack_sim_range_overlay.setup(_attack_exec_ship_token)
			var ship_name: String = ""
			if _attack_exec_ship_token.get_ship_data():
				ship_name = \
						_attack_exec_ship_token.get_ship_data().ship_name
			_attack_sim_panel.show_initial_attack_exec(ship_name)
		else:
			_attack_sim_panel.show_initial()


## Computes LOS and range between attacker and target, then updates the
## overlay and info panel with the results.
## Requirements: AS-VIS-020–022, AS-PNL-011, AS-LOG-010, AS-RNG-010–014.
func _attack_sim_compute_and_show_los() -> void:
	# Determine LOS endpoints and trace result.
	var endpoints: Dictionary = _attack_sim_compute_los_endpoints()
	var atk_pt: Vector2 = endpoints["atk"]
	var def_pt: Vector2 = endpoints["def"]
	var los_result: LineOfSightChecker.LOSResult = _attack_sim_trace_los(
			atk_pt, def_pt)
	# Determine overlay status.
	var status: int = AttackSimOverlay.LOSStatus.CLEAR
	var los_text: String = "Clear"
	if not los_result.has_los:
		status = AttackSimOverlay.LOSStatus.BLOCKED
		los_text = "Blocked"
		# Debug: log the arc boundary that blocked LOS.
		if _attack_sim_def_ship:
			var def_arc: Dictionary = \
					_attack_sim_def_ship.get_firing_arc_world_points()
			var info: Dictionary = \
					LineOfSightChecker.get_blocking_boundary_info(
							atk_pt, def_pt, def_arc)
			if not info.is_empty():
				_log.debug(
						"LOS blocked by boundary '%s': " % info["boundary"]
						+"inner=%s outer=%s ix=%s." % [
								info["inner"], info["outer"],
								info["intersection"]])
	elif los_result.obstructed:
		status = AttackSimOverlay.LOSStatus.OBSTRUCTED
		if los_result.obstructed_by.size() > 0:
			los_text = "Obstructed by %s" % ", ".join(
					los_result.obstructed_by)
		else:
			los_text = "Obstructed"
	_log.info("LOS: %s." % los_text)
	# Compute range measurement.
	var range_data: Dictionary = _attack_sim_compute_range_endpoints()
	var range_distance: float = range_data.get("distance", INF)
	var range_band: String = Constants.RANGE_BAND_BEYOND
	if range_distance < INF:
		range_band = GameScale.get_range_band(range_distance)
	_log.info("Range: %s (%.0f px)." % [range_band, range_distance])
	# Update overlay: target marker + LOS line + range line.
	if _attack_sim_overlay:
		if _attack_sim_def_ship:
			_attack_sim_overlay.setup_target_hull_zone(def_pt)
		else:
			_attack_sim_overlay.setup_target_squadron(def_pt)
		_attack_sim_overlay.setup_los_line(atk_pt, def_pt, status)
		if range_distance < INF:
			_attack_sim_overlay.setup_range_line(
					range_data["atk_pt"], range_data["def_pt"],
					range_band)
	# Update panel.
	if _attack_sim_panel:
		_attack_sim_panel.show_target_selected(
				_attack_sim_atk_name, _attack_sim_atk_zone_name,
				_attack_sim_def_name, _attack_sim_def_zone_name,
				los_text, range_band)
	# In attack execution mode, compute and display the dice pool, then
	# begin the attack sequence (CF dial → Roll → Reroll → Confirm).
	if _attack_exec_mode and _attack_sim_panel:
		_attack_exec_range_band = range_band
		var dice_text: String = _compute_attack_dice_text(range_band)
		_attack_sim_panel.show_dice_count(dice_text)
		_log.info("Dice pool: %s." % dice_text)
		_attack_exec_begin_sequence(range_band)


## Computes the dice pool text for the current attacker/target pair at the
## given [param range_band]. Uses the ship's battery armament for the
## selected hull zone, or anti-squadron armament when targeting a squadron.
## For squadron attackers, uses anti-squadron or battery armament from
## SquadronData.
## Requirements: AE-PNL-002.
## Rules Reference: "Attack", Step 2, p.2; "Squadron Attacks", RRG p.19.
func _compute_attack_dice_text(range_band: String) -> String:
	if _attack_sim_atk_ship == null and _attack_sim_atk_squad == null:
		return "0 dice"
	var armament: Dictionary = _resolve_attacker_armament()
	return DicePool.format_attack_pool(armament, range_band)


# ===========================================================================
# LOS Computation
# ===========================================================================


## Computes the LOS line endpoints for the current attacker/target pair.
## Returns a Dictionary with "atk" and "def" Vector2 keys.
## Rules Reference: "Line of Sight", p.10.
func _attack_sim_compute_los_endpoints() -> Dictionary:
	var atk_pt: Vector2 = Vector2.ZERO
	var def_pt: Vector2 = Vector2.ZERO
	# Attacker endpoint.
	if _attack_sim_atk_ship:
		# Ship hull zone → targeting point.
		var los_pts: Dictionary = \
				_attack_sim_atk_ship.get_los_origins_world()
		var zone_key: String = _ZONE_NAMES.get(
				_attack_sim_atk_zone, "FRONT")
		atk_pt = los_pts.get(zone_key, Vector2.ZERO)
	# Defender endpoint (depends on type).
	if _attack_sim_def_ship:
		# Ship hull zone → targeting point.
		var los_pts: Dictionary = \
				_attack_sim_def_ship.get_los_origins_world()
		var zone_key: String = _ZONE_NAMES.get(
				_attack_sim_def_zone, "FRONT")
		def_pt = los_pts.get(zone_key, Vector2.ZERO)
	if _attack_sim_atk_ship and _attack_sim_def_squad:
		# Ship → Squadron: defender = closest point on squadron base.
		def_pt = RangeFinder.closest_point_on_circle(
				atk_pt,
				_attack_sim_def_squad.global_position,
				_attack_sim_def_squad.get_radius_px())
	if _attack_sim_atk_squad and _attack_sim_def_ship:
		# Squadron → Ship: attacker = closest point on squadron base to
		# defender's targeting point.
		var d_los_pts: Dictionary = \
				_attack_sim_def_ship.get_los_origins_world()
		var d_zone_key: String = _ZONE_NAMES.get(
				_attack_sim_def_zone, "FRONT")
		def_pt = d_los_pts.get(d_zone_key, Vector2.ZERO)
		atk_pt = RangeFinder.closest_point_on_circle(
				def_pt,
				_attack_sim_atk_squad.global_position,
				_attack_sim_atk_squad.get_radius_px())
	if _attack_sim_atk_squad and _attack_sim_def_squad:
		# Squadron → Squadron: both = closest points on each base to the
		# other's centre.
		atk_pt = RangeFinder.closest_point_on_circle(
				_attack_sim_def_squad.global_position,
				_attack_sim_atk_squad.global_position,
				_attack_sim_atk_squad.get_radius_px())
		def_pt = RangeFinder.closest_point_on_circle(
				_attack_sim_atk_squad.global_position,
				_attack_sim_def_squad.global_position,
				_attack_sim_def_squad.get_radius_px())
	return {"atk": atk_pt, "def": def_pt}


## Traces LOS between the attacker and target using LineOfSightChecker.
## Builds obstruction bodies from all ships except the attacker/defender.
## Requirements: AS-VIS-022, TL-LOS-001–005.
func _attack_sim_trace_los(atk_pt: Vector2,
		def_pt: Vector2) -> LineOfSightChecker.LOSResult:
	# Build obstruction bodies from all ships excluding attacker/defender.
	var bodies: Array = []
	for child: Node in _token_container.get_children():
		if child is ShipToken:
			var st: ShipToken = child as ShipToken
			if st == _attack_sim_atk_ship or st == _attack_sim_def_ship:
				continue
			var sd: ShipData = st.get_ship_data()
			if sd:
				bodies.append(
						LineOfSightChecker.ObstructionBody.from_ship_base(
								sd.ship_name, st.global_position,
								st.rotation, st.get_half_width(),
								st.get_half_length()))
	var obstacles: Array = [] # Future: obstacle tokens.
	# Determine which trace method to use.
	# Ship → Ship
	if _attack_sim_atk_ship and _attack_sim_def_ship:
		var ds: ShipToken = _attack_sim_def_ship
		return LineOfSightChecker.trace_los_ship_to_ship(
				atk_pt, def_pt,
				_attack_sim_def_zone as Constants.HullZone,
				ds.global_position, ds.rotation,
				ds.get_half_width(), ds.get_half_length(),
				bodies, obstacles,
				ds.get_firing_arc_world_points())
	# Ship → Squadron
	if _attack_sim_atk_ship and _attack_sim_def_squad:
		return LineOfSightChecker.trace_los_ship_to_squadron(
				atk_pt,
				_attack_sim_def_squad.global_position,
				_attack_sim_def_squad.get_radius_px(),
				bodies, obstacles)
	# Squadron → Ship
	if _attack_sim_atk_squad and _attack_sim_def_ship:
		var ds: ShipToken = _attack_sim_def_ship
		return LineOfSightChecker.trace_los_squad_to_ship(
				_attack_sim_atk_squad.global_position,
				_attack_sim_atk_squad.get_radius_px(),
				def_pt,
				_attack_sim_def_zone as Constants.HullZone,
				ds.global_position, ds.rotation,
				ds.get_half_width(), ds.get_half_length(),
				bodies, obstacles,
				ds.get_firing_arc_world_points())
	# Squadron → Squadron — no hull zone blocking, just obstruction.
	if _attack_sim_atk_squad and _attack_sim_def_squad:
		return LineOfSightChecker.trace_los_squad_to_squad(
				_attack_sim_atk_squad.global_position,
				_attack_sim_atk_squad.get_radius_px(),
				_attack_sim_def_squad.global_position,
				_attack_sim_def_squad.get_radius_px(),
				bodies, obstacles)
	# Fallback (should not happen).
	return LineOfSightChecker.LOSResult.new()


# ===========================================================================
# Arc Validation (Phase 6a-3)
# ===========================================================================


## Returns the hull-zone edge polyline for [param token], preferring
## arc-based multi-segment edges when boundary data with corner_* keys
## is available, otherwise falling back to rectangle corners.
## Requirements: HZ-EDGE-001.
func _get_ship_edge(
		token: ShipToken, zone: Constants.HullZone) -> Array[Vector2]:
	var arc_pts: Dictionary = token.get_firing_arc_world_points()
	if not arc_pts.is_empty() and arc_pts.has("corner_front_left"):
		return RangeFinder.get_hull_zone_edge_from_arcs(arc_pts, zone)
	return RangeFinder.get_hull_zone_edge(
			token.global_position, token.rotation,
			token.get_half_width(), token.get_half_length(), zone)


## Returns true if the defending ship hull zone is inside the attacker's
## firing arc. Only valid when the attacker is a ship hull zone.
## Requirements: AS-ARC-001, HZ-EDGE-001.
func _attack_sim_is_ship_target_in_arc(
		def_token: ShipToken, def_zone: int) -> bool:
	if not _attack_sim_atk_ship:
		return true
	var atk_arc_pts: Dictionary = _attack_sim_atk_ship \
			.get_firing_arc_world_points()
	if atk_arc_pts.is_empty():
		return true # No arc data → allow.
	var def_edge: Array[Vector2] = _get_ship_edge(
			def_token, def_zone as Constants.HullZone)
	return RangeFinder.is_hull_zone_edge_in_arc(
			def_edge,
			_attack_sim_atk_zone as Constants.HullZone,
			atk_arc_pts)


## Returns true if the defending squadron is inside the attacker's
## firing arc. Only valid when the attacker is a ship hull zone.
## Requirements: AS-ARC-001.
func _attack_sim_is_squadron_target_in_arc(
		def_token: SquadronToken) -> bool:
	if not _attack_sim_atk_ship:
		return true
	var atk_arc_pts: Dictionary = _attack_sim_atk_ship \
			.get_firing_arc_world_points()
	if atk_arc_pts.is_empty():
		return true
	return RangeFinder.is_squadron_in_arc(
			def_token.global_position,
			def_token.get_radius_px(),
			_attack_sim_atk_zone as Constants.HullZone,
			atk_arc_pts)


# ===========================================================================
# Range Measurement (Phase 6a-3)
# ===========================================================================


## Computes the range measurement endpoints and distance for the current
## attacker/target pair. Returns a Dictionary with "distance" (float),
## "atk_pt" (Vector2), "def_pt" (Vector2).
## Requirements: AS-RNG-010, AS-RNG-011, HZ-EDGE-001.
func _attack_sim_compute_range_endpoints() -> Dictionary:
	# Ship → Ship
	if _attack_sim_atk_ship and _attack_sim_def_ship:
		var atk_edge: Array[Vector2] = _get_ship_edge(
				_attack_sim_atk_ship,
				_attack_sim_atk_zone as Constants.HullZone)
		var def_edge: Array[Vector2] = _get_ship_edge(
				_attack_sim_def_ship,
				_attack_sim_def_zone as Constants.HullZone)
		var atk_arc_pts: Dictionary = _attack_sim_atk_ship \
				.get_firing_arc_world_points()
		return RangeFinder.measure_attack_range_ship_endpoints(
				atk_edge, def_edge,
				_attack_sim_atk_zone as Constants.HullZone,
				atk_arc_pts)
	# Ship → Squadron
	if _attack_sim_atk_ship and _attack_sim_def_squad:
		var atk_edge: Array[Vector2] = _get_ship_edge(
				_attack_sim_atk_ship,
				_attack_sim_atk_zone as Constants.HullZone)
		var atk_arc_pts: Dictionary = _attack_sim_atk_ship \
				.get_firing_arc_world_points()
		return RangeFinder.measure_attack_range_squadron_endpoints(
				atk_edge,
				_attack_sim_def_squad.global_position,
				_attack_sim_def_squad.get_radius_px(),
				_attack_sim_atk_zone as Constants.HullZone,
				atk_arc_pts)
	# Squadron → Ship
	if _attack_sim_atk_squad and _attack_sim_def_ship:
		var def_edge: Array[Vector2] = _get_ship_edge(
				_attack_sim_def_ship,
				_attack_sim_def_zone as Constants.HullZone)
		return RangeFinder.measure_range_squad_to_ship(
				_attack_sim_atk_squad.global_position,
				_attack_sim_atk_squad.get_radius_px(),
				def_edge)
	# Squadron → Squadron
	if _attack_sim_atk_squad and _attack_sim_def_squad:
		return RangeFinder.measure_range_squad_to_squad(
				_attack_sim_atk_squad.global_position,
				_attack_sim_atk_squad.get_radius_px(),
				_attack_sim_def_squad.global_position,
				_attack_sim_def_squad.get_radius_px())
	# Fallback.
	return {"distance": INF, "atk_pt": Vector2.ZERO,
			"def_pt": Vector2.ZERO}


# ===========================================================================
# Phase 6b-2 — Attack Sequence Orchestration
# ===========================================================================


## Connects the Phase 6b-2 panel signals to executor handlers.
func _connect_attack_panel_signals() -> void:
	if _attack_sim_panel == null:
		return
	var p: AttackSimPanel = _attack_sim_panel
	if not p.cf_dial_colour_selected.is_connected(
			_on_attack_cf_dial_colour):
		p.cf_dial_colour_selected.connect(_on_attack_cf_dial_colour)
	if not p.cf_dial_skipped.is_connected(_on_attack_cf_dial_skipped):
		p.cf_dial_skipped.connect(_on_attack_cf_dial_skipped)
	if not p.roll_dice_pressed.is_connected(_on_attack_roll_dice):
		p.roll_dice_pressed.connect(_on_attack_roll_dice)
	if not p.cf_token_reroll_requested.is_connected(
			_on_attack_cf_token_reroll):
		p.cf_token_reroll_requested.connect(_on_attack_cf_token_reroll)
	if not p.cf_token_reroll_skipped.is_connected(
			_on_attack_cf_token_skipped):
		p.cf_token_reroll_skipped.connect(_on_attack_cf_token_skipped)
	if not p.confirm_pressed.is_connected(_on_attack_confirm):
		p.confirm_pressed.connect(_on_attack_confirm)
	if not p.skip_attack_pressed.is_connected(_on_attack_skip):
		p.skip_attack_pressed.connect(_on_attack_skip)
	# Phase 6c signals.
	if not p.accuracy_confirmed.is_connected(
			_on_attack_accuracy_confirmed):
		p.accuracy_confirmed.connect(_on_attack_accuracy_confirmed)
	if not p.defense_token_selected.is_connected(
			_on_attack_defense_token_spent):
		p.defense_token_selected.connect(_on_attack_defense_token_spent)
	if not p.defense_tokens_done.is_connected(
			_on_attack_defense_done):
		p.defense_tokens_done.connect(_on_attack_defense_done)
	if not p.redirect_zone_selected.is_connected(
			_on_attack_redirect_zone_selected):
		p.redirect_zone_selected.connect(
				_on_attack_redirect_zone_selected)
	if not p.evade_die_confirmed.is_connected(
			_on_evade_die_selected):
		p.evade_die_confirmed.connect(_on_evade_die_selected)
	if not p.redirect_done_pressed.is_connected(
			_on_redirect_done_early):
		p.redirect_done_pressed.connect(_on_redirect_done_early)


## Begins the Phase 6b-2 attack sequence after target and range are known.
## Checks for a CF dial and starts the appropriate step.
## For squadron attackers, CF dials are not available — skip straight to roll.
## Requirements: AE-CF-001, AE-CF-002, SQA-ATK-001.
## Rules Reference: "Concentrate Fire", p.3 — "While attacking, the ship
## may add 1 die to its attack pool of a color that is already in its
## attack pool."
func _attack_exec_begin_sequence(range_band: String) -> void:
	if _attack_sim_panel == null:
		return
	if _attack_exec_ship_token == null and _attack_exec_squad_token == null:
		return
	# Compute the string-keyed pool.
	_attack_exec_pool = _compute_attack_pool_dict(range_band)
	# Hook: ATTACK_GATHER_DICE — Damaged Munitions / Point-Defense Failure.
	if _effect_registry:
		var gd_ctx: EffectContext = EffectContext.new()
		gd_ctx.dice_pool = _attack_exec_pool
		if _attack_exec_ship_token and _attack_exec_ship_token is ShipToken:
			gd_ctx.attacker = (
					_attack_exec_ship_token as ShipToken
					).get_ship_instance()
		if _attack_sim_def_squad:
			gd_ctx.defender = _attack_sim_def_squad.get_squadron_instance()
		elif _attack_sim_def_ship and _attack_sim_def_ship is ShipToken:
			gd_ctx.defender = (
					_attack_sim_def_ship as ShipToken).get_ship_instance()
		gd_ctx = _effect_registry.resolve_hook(
				&"ATTACK_GATHER_DICE", gd_ctx)
		_attack_exec_pool = gd_ctx.dice_pool
	# Show Skip Attack button.
	_attack_sim_panel.show_skip_attack_button()
	# Check CF dial availability (ship attackers only — squadrons have no dials).
	if _attack_exec_ship_token and not _attack_exec_cf_dial_used \
			and _attack_exec_has_cf_dial():
		# Offer CF dial: colours must be present in pool.
		var available: Array[String] = _get_cf_dial_colours(
				_attack_exec_pool)
		if available.size() > 0:
			_attack_sim_panel.show_cf_dial_section(available)
			_log.info("CF dial available — offering colours: %s." % [
					str(available)])
			return
	# No CF dial — proceed to roll.
	_attack_exec_show_roll_button()


## Checks whether the activated ship has a revealed CF dial.
## Requirements: AE-CF-001.
func _attack_exec_has_cf_dial() -> bool:
	var inst: ShipInstance = _attack_exec_ship_token.get_ship_instance()
	if inst == null or inst.command_dial_stack == null:
		return false
	var dial: Dictionary = inst.command_dial_stack.get_revealed_dial()
	if dial.is_empty():
		return false
	return (dial.get("command", -1) as int) == (
			Constants.CommandType.CONCENTRATE_FIRE as int)


## Returns which colour keys are available for CF dial extra die.
## Only colours already in the pool may be chosen.
## Requirements: AE-CF-003.
## Rules Reference: "Concentrate Fire", p.3.
func _get_cf_dial_colours(pool: Dictionary) -> Array[String]:
	var colours: Array[String] = []
	for key: String in pool:
		if int(pool[key]) > 0:
			colours.append(key)
	return colours


## Computes the string-keyed dice pool for the current attacker/target.
## Same logic as _compute_attack_dice_text but returns the Dictionary.
func _compute_attack_pool_dict(range_band: String) -> Dictionary:
	if _attack_sim_atk_ship == null and _attack_sim_atk_squad == null:
		return {}
	var armament: Dictionary = _resolve_attacker_armament()
	return DicePool.get_attack_pool(armament, range_band)


## Resolves the attacker's armament dictionary for the current
## attacker/target pair.  Handles ship (battery / anti-squadron) and
## squadron (battery / anti-squadron) attackers.
## Rules Reference: "Attack", Step 2, p.2; "Squadron Attacks", RRG p.19.
func _resolve_attacker_armament() -> Dictionary:
	# Ship attacker.
	if _attack_sim_atk_ship:
		var ship_data: ShipData = _attack_sim_atk_ship.get_ship_data()
		if ship_data == null:
			return {}
		if _attack_sim_def_squad:
			return ship_data.anti_squadron_armament
		var zone_key: String = _ZONE_NAMES.get(
				_attack_sim_atk_zone, "FRONT")
		return ship_data.battery_armament.get(zone_key, {})
	# Squadron attacker.
	if _attack_sim_atk_squad:
		var inst: SquadronInstance = \
				_attack_sim_atk_squad.get_squadron_instance()
		if inst == null or inst.squadron_data == null:
			return {}
		if _attack_sim_def_squad:
			return inst.squadron_data.anti_squadron_armament
		return inst.squadron_data.battery_armament
	return {}


## Shows the Roll Dice button.
func _attack_exec_show_roll_button() -> void:
	if _attack_sim_panel:
		_attack_sim_panel.hide_cf_dial_section()
		_attack_sim_panel.show_roll_button()
	_log.info("Awaiting dice roll.")


## Called when the player selects a colour for the CF dial extra die.
## Requirements: AE-CF-003, AE-CF-004.
func _on_attack_cf_dial_colour(colour_key: String) -> void:
	_log.info("CF dial: adding 1 %s die." % colour_key)
	# Add die to the pool.
	var current: int = int(_attack_exec_pool.get(colour_key, 0))
	_attack_exec_pool[colour_key] = current + 1
	# Spend the dial.
	var inst: ShipInstance = _attack_exec_ship_token.get_ship_instance()
	if inst and inst.command_dial_stack:
		inst.command_dial_stack.spend_revealed()
		EventBus.command_dials_changed.emit(inst)
	_attack_exec_cf_dial_used = true
	# Update dice count display.
	if _attack_sim_panel:
		var dice_text: String = DicePool.format_pool(_attack_exec_pool)
		_attack_sim_panel.show_dice_count(dice_text)
	# Proceed to roll.
	_attack_exec_show_roll_button()


## Called when the player skips the CF dial.
## Requirements: AE-CF-005.
func _on_attack_cf_dial_skipped() -> void:
	_log.info("CF dial skipped.")
	_attack_exec_show_roll_button()


## Called when the player presses "Roll Dice".
## Requirements: AE-DICE-001, AE-DICE-003.
func _on_attack_roll_dice() -> void:
	_log.info("Rolling dice: %s." % DicePool.format_pool(
			_attack_exec_pool))
	# Convert to engine pool and roll.
	var engine_pool: Dictionary = DicePool.to_engine_pool(
			_attack_exec_pool)
	_attack_exec_dice_results = Dice.roll_pool(engine_pool)
	# Show results.
	if _attack_sim_panel:
		_attack_sim_panel.hide_roll_button()
		_attack_sim_panel.show_dice_results(_attack_exec_dice_results)
	# Log results.
	var damage: int = _calc_attack_damage(_attack_exec_dice_results)
	_log.info("Dice rolled: %d dice, %d damage." % [
			_attack_exec_dice_results.size(), damage])
	# Check CF token for reroll.
	if _attack_exec_has_cf_token():
		if _attack_sim_panel:
			_attack_sim_panel.show_cf_token_section()
		_log.info("CF token available — offering reroll.")
		return
	# No token — show confirm.
	_attack_exec_show_confirm()


## Checks whether the activated ship has a CF command token.
## Requirements: AE-CF-010.
func _attack_exec_has_cf_token() -> bool:
	var inst: ShipInstance = _attack_exec_ship_token.get_ship_instance()
	if inst == null or inst.command_tokens == null:
		return false
	return inst.command_tokens.has_token(
			Constants.CommandType.CONCENTRATE_FIRE)


## Called when the player selects a die and confirms reroll (CF token).
## Requirements: AE-CF-011, AE-CF-012, AE-CF-014.
func _on_attack_cf_token_reroll(die_index: int) -> void:
	if die_index < 0 or die_index >= _attack_exec_dice_results.size():
		return
	var old_result: Dictionary = _attack_exec_dice_results[die_index]
	var color: Constants.DiceColor = (
			old_result["color"] as Constants.DiceColor)
	# Reroll the die.
	var new_face: Constants.DiceFace = Dice.roll_die(color)
	var new_result: Dictionary = {"color": color, "face": new_face}
	_attack_exec_dice_results[die_index] = new_result
	_log.info("CF token: rerolled die %d (%s) → %s." % [
			die_index, str(old_result["face"]), str(new_face)])
	# Spend the token.
	var inst: ShipInstance = _attack_exec_ship_token.get_ship_instance()
	if inst and inst.command_tokens:
		inst.command_tokens.spend_token(
				Constants.CommandType.CONCENTRATE_FIRE)
		EventBus.command_tokens_changed.emit(inst)
	# Update display.
	if _attack_sim_panel:
		_attack_sim_panel.update_die_result(die_index, new_result)
		_attack_sim_panel.hide_cf_token_section()
	# Show confirm.
	_attack_exec_show_confirm()


## Called when the player skips the CF token reroll.
## Requirements: AE-CF-013.
func _on_attack_cf_token_skipped() -> void:
	_log.info("CF token reroll skipped.")
	if _attack_sim_panel:
		_attack_sim_panel.hide_cf_token_section()
	_attack_exec_show_confirm()


## Shows the Confirm button after dice are finalised.
## Requirements: AE-CONF-001.
func _attack_exec_show_confirm() -> void:
	if _attack_sim_panel:
		_attack_sim_panel.show_confirm_button()
	var damage: int = _calc_attack_damage(_attack_exec_dice_results)
	_log.info("Final dice: %d damage. Awaiting confirm." % damage)


## Called when the player presses "Confirm" to accept the dice results.
## Starts the accuracy spending step (Step 3), then defense (Step 4),
## then damage resolution (Step 5).
## Requirements: AE-CONF-002, AE-ACC-001, AE-DEF-001, AE-DMG-001.
## Rules Reference: "Attack", Steps 3–5.
func _on_attack_confirm() -> void:
	var damage: int = _calc_attack_damage(_attack_exec_dice_results)
	_log.info(
			"Attack confirmed: %d damage. Starting Step 3 (accuracy)."
			% damage)
	if _attack_sim_panel:
		_attack_sim_panel.hide_confirm_button()
	# Reset Phase 6c state for this attack.
	_attack_exec_locked_tokens.clear()
	_attack_exec_spent_tokens.clear()
	_defense_commit_queue.clear()
	_attack_exec_modified_damage = damage
	_attack_exec_scatter_used = false
	_attack_exec_redirect_remaining = 0
	_attack_exec_redirect_zone = -1
	_attack_exec_contain_used = false
	_attack_exec_brace_used = false
	_attack_exec_redirect_step = false
	_attack_exec_evade_step = false
	# Zero damage — skip accuracy and defense entirely since there is
	# nothing to mitigate.  Go straight to damage resolution which will
	# show "No damage dealt." and advance to the next attack.
	if damage == 0:
		_log.info("No damage in roll — skipping accuracy & defense.")
		_attack_exec_accuracy_step = false
		_attack_exec_defense_step = false
		_attack_exec_resolve_damage()
		return
	_attack_exec_start_accuracy()


# ===========================================================================
# Phase 6c-1 — Accuracy Spending (Step 3)
# ===========================================================================


## Starts the accuracy spending step.
## If the defender is a ship and the attacker rolled accuracy icons,
## show the accuracy UI. Otherwise, skip to defense tokens.
## Requirements: AE-ACC-001–008.
## Rules Reference: "Accuracy", p.2 — "The attacker can spend one or more
## of his accuracy icons to choose the same number of the defender's
## defense tokens. The chosen tokens cannot be spent during this attack."
func _attack_exec_start_accuracy() -> void:
	_attack_exec_accuracy_step = true
	var acc_count: int = Dice.count_accuracy(_attack_exec_dice_results)
	# Hook: ATTACK_SPEND_ACCURACY — Blinded Gunners blocks accuracy spending.
	if acc_count > 0 and _effect_registry:
		var acc_ctx: EffectContext = EffectContext.new()
		if _attack_sim_atk_ship is ShipToken:
			acc_ctx.attacker = (
					_attack_sim_atk_ship as ShipToken).get_ship_instance()
		acc_ctx = _effect_registry.resolve_hook(
				&"ATTACK_SPEND_ACCURACY", acc_ctx)
		if acc_ctx.cancelled:
			_log.info("Accuracy spending blocked by damage card effect.")
			acc_count = 0
	# Only ships have defense tokens; squadrons skip accuracy step.
	if _attack_sim_def_ship == null or acc_count == 0:
		_log.info("No accuracy icons or squadron defender — skipping "
				+"accuracy step.")
		_attack_exec_accuracy_step = false
		_attack_exec_start_defense()
		return
	var def_inst: ShipInstance = _attack_sim_def_ship.get_ship_instance()
	if def_inst == null:
		_attack_exec_accuracy_step = false
		_attack_exec_start_defense()
		return
	# Check if the defender has any non-discarded tokens to lock.
	var lockable: int = 0
	for token: Dictionary in def_inst.defense_tokens:
		if token["state"] != Constants.DefenseTokenState.DISCARDED:
			lockable += 1
	if lockable == 0:
		_log.info("Defender has no lockable tokens — skipping accuracy.")
		_attack_exec_accuracy_step = false
		_attack_exec_start_defense()
		return
	_log.info("Accuracy step: %d icons, %d lockable tokens." % [
			acc_count, lockable])
	# Grey out accuracy dice in the dice display.
	if _attack_sim_panel:
		_attack_sim_panel.show_accuracy_section(
				def_inst.defense_tokens, acc_count)
		_attack_sim_panel.hide_confirm_button()


## Called when the player confirms accuracy spending.
## Stores the locked token indices and proceeds to defense step.
## Requirements: AE-ACC-006.
func _on_attack_accuracy_confirmed() -> void:
	if _attack_sim_panel:
		_attack_exec_locked_tokens = (
				_attack_sim_panel.get_accuracy_locked_indices())
		_attack_sim_panel.hide_accuracy_section()
	_attack_exec_accuracy_step = false
	_log.info("Accuracy confirmed: locked tokens %s." % [
			str(_attack_exec_locked_tokens)])
	_attack_exec_start_defense()


# ===========================================================================
# Phase 6c-2 — Defense Token Spending (Step 4)
# ===========================================================================


## Starts the defense token spending step.
## If the defender is a ship with spendable tokens, show the defense UI.
## Otherwise, skip to damage resolution.
## Requirements: AE-DEF-001–016.
## Rules Reference: "Spend Defense Tokens", p.5 — "The defender can spend
## one or more of his defense tokens."
func _attack_exec_start_defense() -> void:
	_attack_exec_defense_step = true
	_attack_exec_spent_tokens.clear()
	_defense_commit_queue.clear()
	# Squadron defenders have no defense tokens (generic squads).
	if _attack_sim_def_ship == null:
		_attack_exec_defense_step = false
		_attack_exec_resolve_damage()
		return
	var def_inst: ShipInstance = _attack_sim_def_ship.get_ship_instance()
	if def_inst == null:
		_attack_exec_defense_step = false
		_attack_exec_resolve_damage()
		return
	# Check if the defender can spend any tokens.
	var spendable: int = _count_spendable_defense_tokens(def_inst)
	if spendable == 0:
		_log.info("No spendable defense tokens — skipping defense step.")
		_attack_exec_defense_step = false
		_attack_exec_resolve_damage()
		return
	# Speed 0 check: cannot spend defense tokens.
	## Rules Reference: "Defense Tokens", bullet 4, p.5.
	## "If the defender's speed is 0, he cannot spend any defense tokens."
	if def_inst.current_speed == 0:
		_log.info("Defender speed 0 — cannot spend defense tokens.")
		_attack_exec_defense_step = false
		_attack_exec_resolve_damage()
		return
	# Rotate camera to the defender's perspective so they can see their
	# tokens. Requirement: AE-DEF-011.
	if _camera and PlayMode.is_hot_seat():
		_camera.rotate_to_player(def_inst.owner_player)
	_log.info("Defense step: %d spendable tokens, %d damage." % [
			spendable, _attack_exec_modified_damage])
	if _attack_sim_panel:
		_attack_sim_panel.show_defense_section(
				def_inst.defense_tokens,
				_attack_exec_locked_tokens,
				_attack_exec_modified_damage,
				def_inst.current_speed)


## Returns the number of spendable (non-discarded, non-locked) tokens.
func _count_spendable_defense_tokens(inst: ShipInstance) -> int:
	var count: int = 0
	for i: int in range(inst.defense_tokens.size()):
		if i in _attack_exec_locked_tokens:
			continue
		var state: Constants.DefenseTokenState = (
				inst.defense_tokens[i]["state"]
				as Constants.DefenseTokenState)
		if state != Constants.DefenseTokenState.DISCARDED:
			count += 1
	return count


## Called when the player spends a defense token.
## [param token_index] — index in the defender's defense_tokens array.
## [param spend_method] — "exhaust" or "discard".
## Requirements: AE-DEF-001–016.
## Rules Reference: "Defense Tokens", p.5 — each token type at most once.
func _on_attack_defense_token_spent(token_index: int,
		spend_method: String) -> void:
	if _attack_sim_def_ship == null:
		return
	var def_inst: ShipInstance = _attack_sim_def_ship.get_ship_instance()
	if def_inst == null:
		return
	if token_index < 0 or token_index >= def_inst.defense_tokens.size():
		return
	var token: Dictionary = def_inst.defense_tokens[token_index]
	var token_type: Constants.DefenseToken = (
			token["type"] as Constants.DefenseToken)
	var token_state: Constants.DefenseTokenState = (
			token["state"] as Constants.DefenseTokenState)
	# Cannot spend discarded tokens.
	if token_state == Constants.DefenseTokenState.DISCARDED:
		_log.info("Token %d already discarded — ignoring." % token_index)
		return
	# Cannot spend a token type already spent this attack.
	if _attack_exec_spent_tokens.has(token_type):
		_log.info("Token type already spent this attack — ignoring.")
		return
	# Cannot spend locked tokens.
	if token_index in _attack_exec_locked_tokens:
		_log.info("Token %d is locked by accuracy — ignoring." %
				token_index)
		return
	# Determine spend method: exhausted tokens must be discarded.
	var actual_method: String = spend_method
	if token_state == Constants.DefenseTokenState.EXHAUSTED:
		actual_method = "discard"
	# Apply the spend.
	match actual_method:
		"discard":
			def_inst.discard_defense_token(token_index)
		_:
			def_inst.exhaust_defense_token(token_index)
	_attack_exec_spent_tokens[token_type] = actual_method
	EventBus.ship_defense_token_changed.emit(def_inst)
	EventBus.defense_token_spent.emit(
			_attack_sim_def_ship, token_type)
	_log.info("Defense token spent: %s (%s)." % [
			Constants.DEFENSE_TOKEN_NAMES.get(token_type, "?"),
			actual_method])
	# Apply the token's effect immediately.
	_apply_defense_token_effect(token_type, def_inst)


## Applies the effect of a defense token to the current attack.
## Requirements: AE-DEF-006–016.
## Rules Reference: "Defense Tokens", p.5; individual token entries.
func _apply_defense_token_effect(token_type: Constants.DefenseToken,
		def_inst: ShipInstance) -> void:
	match token_type:
		Constants.DefenseToken.SCATTER:
			# Cancel all dice.
			## Rules Reference: "Scatter", p.11 — "the attacker must
			## choose and remove all dice from the attack pool."
			_attack_exec_scatter_used = true
			_attack_exec_modified_damage = 0
			_log.info("Scatter: all damage cancelled.")
			if _attack_sim_panel:
				_attack_sim_panel.update_defense_damage(0)
				_attack_sim_panel.disable_defense_token_button(-1)
		Constants.DefenseToken.EVADE:
			# Enter die-selection mode — defender chooses which die.
			## Rules Reference: "Evade", RRG v1.5.0, p.5.
			_attack_exec_start_evade()
			return # Don't disable button here; evade step handles it
		Constants.DefenseToken.BRACE:
			# Applied immediately: halve damage total, rounded up.
			## Rules Reference: "Brace", RRG v1.5.0, p.3 — "the total
			## damage is reduced to half, rounded up."
			## Must resolve before Redirect so Redirect operates on the
			## halved total (canonical order: Brace → Redirect).
			_attack_exec_brace_used = true
			if _attack_exec_modified_damage > 0:
				_attack_exec_modified_damage = ceili(
						float(_attack_exec_modified_damage) / 2.0)
			_log.info("Brace: damage halved to %d." % [
					_attack_exec_modified_damage])
			if _attack_sim_panel:
				_attack_sim_panel.update_defense_damage(
						_attack_exec_modified_damage)
		Constants.DefenseToken.REDIRECT:
			# Enter redirect mode — player must click hull zone.
			_attack_exec_start_redirect(def_inst)
			return # Don't disable button here; redirect step handles it
		Constants.DefenseToken.CONTAIN:
			# Prevents the standard critical effect.
			## Rules Reference: "Contain", p.3.
			_attack_exec_contain_used = true
			_log.info("Contain: standard critical effect prevented.")
		_:
			_log.info("Unhandled defense token type: %s" \
					% str(token_type))
	# Disable the spent token button.
	if _attack_sim_panel:
		_attack_sim_panel.disable_defense_token_button(
				_get_token_button_index_for_type(token_type))


## Returns the button index for a given token type in the current attack.
func _get_token_button_index_for_type(
		token_type: Constants.DefenseToken) -> int:
	if _attack_sim_def_ship == null:
		return -1
	var def_inst: ShipInstance = _attack_sim_def_ship.get_ship_instance()
	if def_inst == null:
		return -1
	for i: int in range(def_inst.defense_tokens.size()):
		if def_inst.defense_tokens[i]["type"] == token_type:
			if _attack_exec_spent_tokens.has(token_type):
				return i
	return -1


## Starts the Evade die-selection sub-step.
## The defender must click a die to remove (long) or reroll (med/close).
## Requirements: AE-DEF-007–009.
## Rules Reference: "Evade", RRG v1.5.0, p.5 — "At long range, the
## defender cancels one attack die of its choice. At medium or close
## range, the defender chooses one attack die to be rerolled."
func _attack_exec_start_evade() -> void:
	if _attack_exec_dice_results.is_empty():
		_log.info("Evade: no dice to target — skipping.")
		return
	_attack_exec_evade_step = true
	var range_band: String = _attack_exec_range_band
	_log.info("Evade: awaiting die selection (%s range)." % range_band)
	if _attack_sim_panel:
		_attack_sim_panel.show_evade_die_selection(range_band)


## Called when the defender selects a die during evade die-selection.
## At long range: remove the die. At medium/close: reroll it.
## Requirements: AE-DEF-007–009.
func _on_evade_die_selected(die_index: int) -> void:
	if not _attack_exec_evade_step:
		return
	if die_index < 0 or die_index >= _attack_exec_dice_results.size():
		_log.info("Evade: invalid die index %d." % die_index)
		return
	_attack_exec_evade_step = false
	if _attack_sim_panel:
		_attack_sim_panel.hide_evade_die_selection()
	var range_band: String = _attack_exec_range_band
	if range_band == Constants.RANGE_BAND_LONG:
		# Remove the chosen die.
		_attack_exec_dice_results.remove_at(die_index)
		_attack_exec_modified_damage = _calc_attack_damage(
				_attack_exec_dice_results)
		_log.info("Evade (long): removed die %d. Damage now %d." % [
				die_index, _attack_exec_modified_damage])
		if _attack_sim_panel:
			_attack_sim_panel.show_dice_results(
					_attack_exec_dice_results)
	else:
		# Medium or close: reroll the chosen die.
		var die_result: Dictionary = (
				_attack_exec_dice_results[die_index])
		var color: Constants.DiceColor = (
				die_result["color"] as Constants.DiceColor)
		var new_face: Constants.DiceFace = Dice.roll_die(color)
		_attack_exec_dice_results[die_index]["face"] = new_face
		_attack_exec_modified_damage = _calc_attack_damage(
				_attack_exec_dice_results)
		_log.info("Evade (%s): rerolled die %d → %s. Damage now %d."
				% [range_band, die_index, str(new_face),
				_attack_exec_modified_damage])
		if _attack_sim_panel:
			_attack_sim_panel.update_die_result(die_index, {
				"color": color, "face": new_face})
	# Update damage display.
	if _attack_sim_panel:
		_attack_sim_panel.update_defense_damage(
				_attack_exec_modified_damage)
	# Disable the Evade button.
	if _attack_sim_panel:
		_attack_sim_panel.disable_defense_token_button(
				_get_token_button_index_for_type(
				Constants.DefenseToken.EVADE))
	# Continue processing the defense commit queue.
	_process_next_defense_commit()


## Starts the redirect sub-step: shows adjacent zone buttons.
## Requirements: AE-DEF-011–013.
## Rules Reference: "Redirect", p.11 — "the defender chooses one hull zone
## adjacent to the defending hull zone and may suffer up to that adjacent
## zone's remaining shields in that zone instead."
func _attack_exec_start_redirect(_def_inst: ShipInstance) -> void:
	_attack_exec_redirect_step = true
	# The redirect budget is all the current damage.
	_attack_exec_redirect_remaining = _attack_exec_modified_damage
	# Get adjacent zones to the defending hull zone.
	var def_zone: Constants.HullZone = (
			_attack_sim_def_zone as Constants.HullZone)
	var adjacent: Array = ConstantsScript.get_adjacent_hull_zones(def_zone)
	_log.info(
			"Redirect: %d damage to redirect from %s. Adjacent: %s"
			% [_attack_exec_redirect_remaining,
			ConstantsScript.hull_zone_to_string(def_zone),
			str(adjacent)])
	if _attack_sim_panel:
		_attack_sim_panel.show_redirect_section(
				adjacent, _attack_exec_redirect_remaining)


## Called when the player selects a hull zone for redirect.
## Each click redirects 1 damage to that zone (limited by zone shields).
## Requirements: AE-DEF-012, AE-DEF-013.
func _on_attack_redirect_zone_selected(zone: int) -> void:
	if not _attack_exec_redirect_step:
		return
	if _attack_sim_def_ship == null:
		return
	var def_inst: ShipInstance = \
			_attack_sim_def_ship.get_ship_instance()
	if def_inst == null:
		return
	var zone_enum: Constants.HullZone = zone as Constants.HullZone
	var zone_str: String = ConstantsScript.hull_zone_to_string(zone_enum)
	var zone_shields: int = int(
			def_inst.current_shields.get(zone_str, 0))
	if zone_shields <= 0:
		_log.info(
				"Redirect: %s has 0 shields — cannot redirect there."
				% zone_str)
		return
	if _attack_exec_redirect_remaining <= 0:
		_log.info("Redirect: no more damage to redirect.")
		return
	# Redirect 1 damage to this zone (absorbed by shield).
	def_inst.reduce_shields(zone_str, 1)
	EventBus.ship_shields_changed.emit(
			def_inst, zone_str,
			int(def_inst.current_shields.get(zone_str, 0)))
	_attack_exec_redirect_remaining -= 1
	_attack_exec_modified_damage -= 1
	_log.info("Redirect: 1 damage to %s shield. Remaining: %d/%d." % [
			zone_str, _attack_exec_redirect_remaining,
			_attack_exec_modified_damage])
	if _attack_sim_panel:
		_attack_sim_panel.update_defense_damage(
				_attack_exec_modified_damage)
		if _attack_exec_redirect_remaining > 0:
			# Check if any adjacent zone still has shields.
			var def_zone: Constants.HullZone = (
					_attack_sim_def_zone as Constants.HullZone)
			var adjacent: Array = \
					ConstantsScript.get_adjacent_hull_zones(def_zone)
			var has_shields: bool = false
			for adj_zone: Variant in adjacent:
				var adj_str: String = \
						ConstantsScript.hull_zone_to_string(
						adj_zone as Constants.HullZone)
				if int(def_inst.current_shields.get(
						adj_str, 0)) > 0:
					has_shields = true
					break
			if has_shields:
				_attack_sim_panel.update_redirect_remaining(
						_attack_exec_redirect_remaining)
				return # Continue redirect
		_attack_sim_panel.hide_redirect_section()
	_attack_exec_redirect_step = false
	# Continue processing the defense commit queue.
	_process_next_defense_commit()


## Called when the player presses "Commit Defense".
## Reads selected token indices from the panel and processes them
## sequentially via [method _process_next_defense_commit].
## Requirements: AE-DEF-003.
func _on_attack_defense_done() -> void:
	var selected: Array[int] = []
	if _attack_sim_panel:
		selected = _attack_sim_panel.get_defense_selected_indices()
		_attack_sim_panel.disable_all_defense_buttons()
	if selected.is_empty():
		_log.info("No defense tokens selected — proceeding to damage.")
		_attack_exec_defense_step = false
		if _attack_sim_panel:
			_attack_sim_panel.hide_defense_section()
		_attack_exec_resolve_damage()
		return
	# Sort tokens into canonical resolution order (RRG "Defense Tokens"):
	# Scatter → Evade → Brace → Redirect → Contain.
	# This ensures Brace halves damage before Redirect distributes it.
	_defense_commit_queue = _sort_defense_tokens_canonical(selected)
	_log.info("Defense commit: %d tokens queued." %
			_defense_commit_queue.size())
	_process_next_defense_commit()


## Canonical defense token resolution order.
## Rules Reference: "Defense Tokens", p.5 — effects resolve in a
## fixed sequence: Scatter (cancel) → Evade (dice mod) → Brace
## (halve total) → Redirect (distribute) → Contain (prevent crit).
const _DEFENSE_RESOLVE_ORDER: Dictionary = {
	Constants.DefenseToken.SCATTER: 0,
	Constants.DefenseToken.EVADE: 1,
	Constants.DefenseToken.BRACE: 2,
	Constants.DefenseToken.REDIRECT: 3,
	Constants.DefenseToken.CONTAIN: 4,
}


## Sorts token indices into canonical RRG resolution order.
func _sort_defense_tokens_canonical(
		indices: Array[int]) -> Array[int]:
	if _attack_sim_def_ship == null:
		return indices
	var def_inst: ShipInstance = \
			_attack_sim_def_ship.get_ship_instance()
	if def_inst == null:
		return indices
	var sorted: Array[int] = indices.duplicate()
	sorted.sort_custom(func(a: int, b: int) -> bool:
		var type_a: Constants.DefenseToken = \
				def_inst.defense_tokens[a]["type"] \
				as Constants.DefenseToken
		var type_b: Constants.DefenseToken = \
				def_inst.defense_tokens[b]["type"] \
				as Constants.DefenseToken
		return _DEFENSE_RESOLVE_ORDER.get(type_a, 99) < \
				_DEFENSE_RESOLVE_ORDER.get(type_b, 99)
	)
	return sorted


## Processes the next defense token in the commit queue.
## When the queue is empty, hides the defense UI and resolves damage.
func _process_next_defense_commit() -> void:
	if _defense_commit_queue.is_empty():
		_log.info("Defense commit complete. Modified damage: %d." % [
				_attack_exec_modified_damage])
		_attack_exec_defense_step = false
		if _attack_sim_panel:
			_attack_sim_panel.hide_defense_section()
		_attack_exec_resolve_damage()
		return
	var token_index: int = _defense_commit_queue.pop_front()
	_log.info("Processing committed token index %d." % token_index)
	# Reuse the existing spending logic (validates, applies, starts
	# sub-steps for Evade/Redirect).
	_on_attack_defense_token_spent(token_index, "exhaust")
	# For simple tokens (Scatter, Brace, Contain) the method returns
	# synchronously. For Evade/Redirect, sub-steps will call
	# _process_next_defense_commit() when they finish.
	if not _attack_exec_evade_step and not _attack_exec_redirect_step:
		_process_next_defense_commit()


## Called when the player presses "Done Redirecting" in the redirect
## section, ending the redirect sub-step early.
func _on_redirect_done_early() -> void:
	if not _attack_exec_redirect_step:
		return
	_log.info("Redirect ended early by player.")
	_attack_exec_redirect_step = false
	if _attack_sim_panel:
		_attack_sim_panel.hide_redirect_section()
	_process_next_defense_commit()


# ===========================================================================
# Phase 6c-3 — Damage Resolution (Step 5)
# ===========================================================================


## Resolves damage against the defender.
## For ships: shields absorb damage first, then damage cards are dealt.
## Standard critical: if at least one critical icon and Contain was not
## used, the first damage card is dealt faceup.
## Requirements: AE-DMG-001–014.
## Rules Reference: "Damage", p.4 — "Damage is applied one point at a
## time."
func _attack_exec_resolve_damage() -> void:
	var final_damage: int = _attack_exec_modified_damage
	if _attack_exec_scatter_used:
		final_damage = 0
	# Brace is already applied during Step 4 (canonical order before
	# Redirect), so _attack_exec_modified_damage is already halved.
	_log.info("Resolving damage: %d total." % final_damage)
	if final_damage <= 0:
		_log.info("No damage to resolve.")
		if _attack_sim_panel:
			_attack_sim_panel.show_damage_info("No damage dealt.")
		_attack_exec_finalize_after_delay()
		return
	# --- Squadron defender ---
	if _attack_sim_def_squad:
		_resolve_squadron_damage(final_damage)
		_attack_exec_finalize_after_delay()
		return
	# --- Ship defender ---
	if _attack_sim_def_ship:
		_resolve_ship_damage(final_damage)
		_attack_exec_finalize_after_delay()
		return
	_log.error("No defender found for damage resolution!")
	_attack_exec_finalize_attack()


## Resolves damage against a squadron.
## Squadrons have no shields — damage goes directly to hull.
## Requirements: AE-DMG-002.
func _resolve_squadron_damage(damage: int) -> void:
	var sq_inst: SquadronInstance = (
			_attack_sim_def_squad.get_squadron_instance())
	if sq_inst == null:
		_log.error("Squadron instance is null — cannot resolve damage.")
		return
	var actual: int = sq_inst.suffer_damage(damage)
	EventBus.squadron_hull_changed.emit(sq_inst, sq_inst.current_hull)
	_log.info("Squadron took %d damage. Hull: %d/%d." % [
			actual, sq_inst.current_hull,
			sq_inst.squadron_data.hull])
	if _attack_sim_panel:
		_attack_sim_panel.show_damage_info(
				"Squadron: %d damage → Hull %d/%d" % [
				actual, sq_inst.current_hull,
				sq_inst.squadron_data.hull])
	if sq_inst.is_destroyed():
		_log.info("Squadron destroyed!")
		EventBus.squadron_destroyed.emit(_attack_sim_def_squad)
		_fade_out_token(_attack_sim_def_squad)


## Resolves damage against a ship.
## Shields absorb damage first. Remaining damage becomes damage cards.
## Standard critical: first card is faceup if any critical icon present
## and Contain was not spent.
## Requirements: AE-DMG-003–014.
## Rules Reference: "Damage", p.4.
func _resolve_ship_damage(damage: int) -> void:
	var def_inst: ShipInstance = (
			_attack_sim_def_ship.get_ship_instance())
	if def_inst == null:
		_log.error("Ship instance is null — cannot resolve damage.")
		return
	var def_zone_str: String = ConstantsScript.hull_zone_to_string(
			_attack_sim_def_zone as Constants.HullZone)
	var remaining: int = damage
	# Step 1: Absorb damage with shields.
	var shield_absorbed: int = def_inst.reduce_shields(
			def_zone_str, remaining)
	remaining -= shield_absorbed
	if shield_absorbed > 0:
		EventBus.ship_shields_changed.emit(
				def_inst, def_zone_str,
				int(def_inst.current_shields.get(def_zone_str, 0)))
		_log.info("Shields absorbed %d damage in %s. Remaining: %d." % [
				shield_absorbed, def_zone_str, remaining])
	# Step 2: Deal damage cards for remaining damage.
	var has_crit: bool = Dice.has_any_critical(
			_attack_exec_dice_results)
	var first_card_faceup: bool = (has_crit
			and not _attack_exec_contain_used)
	_log.info("Damage cards: remaining=%d, has_crit=%s, contain=%s, "
			% [remaining, has_crit, _attack_exec_contain_used]
			+"first_faceup=%s." % first_card_faceup)
	# Hook: ATTACK_RESOLVE_CRITICAL — Targeter Disruption can block critical.
	if first_card_faceup and _effect_registry:
		var crit_ctx: EffectContext = EffectContext.new()
		if _attack_sim_atk_ship is ShipToken:
			crit_ctx.attacker = (
					_attack_sim_atk_ship as ShipToken).get_ship_instance()
		crit_ctx.critical_allowed = true
		crit_ctx = _effect_registry.resolve_hook(
				&"ATTACK_RESOLVE_CRITICAL", crit_ctx)
		if not crit_ctx.critical_allowed:
			first_card_faceup = false
			_log.info("Critical effect blocked by damage card effect.")
	var cards_dealt: int = 0
	var faceup_card_name: String = ""
	for i: int in range(remaining):
		_log.info("Dealing card %d/%d …" % [i + 1, remaining])
		if _damage_deck == null:
			_log.error("No damage deck available!")
			break
		var card: DamageCard = _damage_deck.draw_card()
		if card == null:
			_log.error("Damage deck is empty!")
			break
		_log.info("Drew card: '%s' [%s] (timing=%s, effect_id=%s)."
				% [card.title, card.trait_type, card.timing,
				card.effect_id])
		if i == 0 and first_card_faceup:
			card.is_faceup = true
			def_inst.add_faceup_damage(card)
			faceup_card_name = card.title
			_log.info("Faceup card added to ship damage list.")
			# Register persistent damage card effect (DM-005).
			if _effect_registry and DamageCardEffectFactory.is_persistent(card):
				DamageCardEffectFactory.register_effect(
						card, def_inst, _effect_registry)
				_log.info("Persistent effect registered for '%s'."
						% card.title)
			# Emit signal so other systems can react to the faceup card.
			EventBus.damage_card_flipped.emit(def_inst, card, true)
			_log.info(
					"Dealt FACEUP damage card: '%s' [%s] (standard critical)."
					% [card.title, card.trait_type])
			# Resolve immediate effect if applicable (DM-005).
			_resolve_immediate_card_effect(card, def_inst)
		else:
			def_inst.add_facedown_damage(card)
			_log.info(
					"Dealt facedown damage card #%d to %s."
					% [i + 1, def_inst.ship_data.ship_name])
		cards_dealt += 1
	_log.info("Card loop done: %d card(s) dealt." % cards_dealt)
	if cards_dealt > 0:
		var new_hull: int = def_inst.ship_data.hull - (
				def_inst.get_total_damage())
		EventBus.ship_hull_changed.emit(def_inst, new_hull)
		EventBus.ship_damaged.emit(
				_attack_sim_def_ship, cards_dealt,
				_attack_sim_def_zone as Constants.HullZone)
		_log.info("Hull remaining: %d/%d after %d card(s) dealt to %s." % [
				new_hull, def_inst.ship_data.hull, cards_dealt,
				def_inst.ship_data.ship_name])
	# Build damage summary.
	var summary: String = "%s: %d shield, %d card(s)" % [
			def_zone_str, shield_absorbed, cards_dealt]
	if faceup_card_name != "":
		summary += " — CRIT: %s" % faceup_card_name
	var hull_remaining: int = def_inst.ship_data.hull - (
			def_inst.get_total_damage())
	summary += " | Hull %d/%d" % [hull_remaining, def_inst.ship_data.hull]
	if _attack_sim_panel:
		_attack_sim_panel.show_damage_info(summary)
	_log.info("Damage resolved: %s" % summary)
	# Check for destruction.
	EventBus.damage_resolved.emit(
			_attack_sim_def_ship, damage)
	if def_inst.is_destroyed():
		_log.info("Ship destroyed! %s" % def_inst.data_key)
		EventBus.ship_destroyed.emit(_attack_sim_def_ship)
		_fade_out_token(_attack_sim_def_ship)


## Resolves the immediate one-shot effect of a faceup damage card, if any.
## Auto-resolve cards (Structural Damage, Projector Misaligned, Life Support
## Failure) are handled immediately. Choice cards (Injured Crew, Shield
## Failure, Comm Noise) auto-resolve with the first available option for now.
## Rules Reference: RRG "Damage Cards", p.4; DM-005.
func _resolve_immediate_card_effect(card: DamageCard,
		ship: ShipInstance) -> void:
	if not ImmediateEffectResolver.is_immediate(card):
		return
	var choice_info: Dictionary = _immediate_resolver.get_required_choice(
			card, ship)
	if choice_info.is_empty():
		# Auto-resolve (no opponent choice needed).
		var ok: bool = _immediate_resolver.resolve(
				card, ship, _damage_deck)
		if ok:
			_log.info("Immediate effect resolved: '%s'." % card.title)
		else:
			_log.warn("Immediate effect failed: '%s'." % card.title)
		return
	# Choice-based card — pick the first available option automatically.
	# TODO: Present a choice UI to the opponent (Phase 10 UI polish).
	var options: Array = choice_info.get("options", [])
	var selected: Dictionary = {}
	for opt: Dictionary in options:
		if opt.get("available", false):
			selected = {"id": opt.get("id", "")}
			break
	if selected.is_empty():
		_log.warn("No available choice for '%s'. " % card.title +
				"Auto-resolving without choice.")
		_immediate_resolver.resolve(card, ship, _damage_deck)
		return
	var ok: bool = _immediate_resolver.resolve(
			card, ship, _damage_deck, selected)
	if ok:
		_log.info("Immediate effect resolved: '%s' (auto-chose '%s')." % [
				card.title, selected.get("id", "")])
	else:
		_log.warn("Immediate effect failed: '%s'." % card.title)


## Waits briefly to show the damage info, then proceeds to finalize.
func _attack_exec_finalize_after_delay() -> void:
	# Small delay so the player can see the damage info.
	var timer: SceneTreeTimer = get_tree().create_timer(1.2)
	timer.timeout.connect(_attack_exec_finalize_attack)


## Finalises the attack: records the zone as fired, checks for follow-up
## attacks (two-hull-zone rule, squadron Step 6 loop).
## Requirements: AE-2HZ-001, AE-2HZ-003, AE-2HZ-004, AE-SQ-001,
## AE-SQ-003, AE-SQ-004.
## Rules Reference: "Attack", Step 6, p.2.
func _attack_exec_finalize_attack() -> void:
	if _attack_sim_panel:
		_attack_sim_panel.hide_damage_info()
		_attack_sim_panel.hide_defense_section()
		_attack_sim_panel.hide_accuracy_section()
		_attack_sim_panel.hide_redirect_section()
	# Rotate camera back to the attacker's perspective for hull zone
	# selection or the squadron loop. Requirement: AE-DEF-011.
	if _camera and PlayMode.is_hot_seat():
		if _attack_exec_ship_token:
			var atk_inst: ShipInstance = (
					_attack_exec_ship_token.get_ship_instance())
			if atk_inst:
				_camera.rotate_to_player(atk_inst.owner_player)
		elif _attack_exec_squad_token:
			var sq_inst: SquadronInstance = (
					_attack_exec_squad_token.get_squadron_instance())
			if sq_inst:
				_camera.rotate_to_player(sq_inst.owner_player)
	# --- Squadron defender: Step 6 loop ---
	if _attack_sim_def_squad:
		_attack_exec_attacked_squads.append(_attack_sim_def_squad)
		if _attack_sim_overlay:
			_attack_sim_overlay.add_spent_zone_marker(
					_attack_sim_def_squad.global_position)
		if _attack_exec_has_more_squad_targets():
			_attack_exec_prepare_next_squadron()
			return
		if _attack_sim_atk_zone >= 0:
			_attack_exec_fired_zones.append(_attack_sim_atk_zone)
		_attack_exec_mark_spent_zone()
		_attack_exec_current_attack += 1
		if _attack_exec_current_attack < 2:
			_attack_exec_attacked_squads.clear()
			_attack_exec_prepare_next_attack()
			return
		_finish_attack_execution()
		return
	# --- Ship defender: two-hull-zone logic ---
	if _attack_sim_atk_zone >= 0:
		_attack_exec_fired_zones.append(_attack_sim_atk_zone)
	_attack_exec_mark_spent_zone()
	_attack_exec_current_attack += 1
	if _attack_exec_current_attack < 2:
		_attack_exec_prepare_next_attack()
		return
	_finish_attack_execution()


## Draws a red dot on the spent hull zone's LOS marker position.
## Requirements: AE-2HZ-002.
func _attack_exec_mark_spent_zone() -> void:
	if _attack_sim_overlay and _attack_sim_atk_ship:
		var los_pts: Dictionary = (
				_attack_sim_atk_ship.get_los_origins_world())
		var zone_key: String = _ZONE_NAMES.get(
				_attack_sim_atk_zone, "FRONT")
		var los_pos: Vector2 = los_pts.get(zone_key, Vector2.ZERO)
		_attack_sim_overlay.add_spent_zone_marker(los_pos)


## Checks whether there are more enemy squadrons in the current arc
## that have not yet been attacked during this hull zone's attack.
## Requirements: AE-SQ-003.
## Rules Reference: "Attack", Step 6, p.2 — new defender must be inside
## the firing arc and at attack range of the same attacking hull zone.
func _attack_exec_has_more_squad_targets() -> bool:
	if not _attack_sim_atk_ship or not _attack_exec_ship_token:
		return false
	var attacker_faction: int = _attack_exec_ship_token.get_faction()
	for sq_token: SquadronToken in _board.get_squadron_tokens():
		# Must be an enemy.
		if sq_token.get_faction() == attacker_faction:
			continue
		# Must not be already attacked.
		if sq_token in _attack_exec_attacked_squads:
			continue
		# Must be in arc.
		if not _attack_sim_is_squadron_target_in_arc(sq_token):
			continue
		# Must be at attack range (not beyond).
		if not _attack_exec_is_squadron_at_range(sq_token):
			continue
		return true
	return false


## Checks whether a squadron is at attack range (close/medium/long)
## from the current attacker hull zone.
## Requirements: AE-SQ-003.
func _attack_exec_is_squadron_at_range(
		sq_token: SquadronToken) -> bool:
	var atk_edge: Array[Vector2] = _get_ship_edge(
			_attack_sim_atk_ship,
			_attack_sim_atk_zone as Constants.HullZone)
	var atk_arc_pts: Dictionary = _attack_sim_atk_ship \
			.get_firing_arc_world_points()
	var range_data: Dictionary = (
			RangeFinder.measure_attack_range_squadron_endpoints(
			atk_edge, sq_token.global_position,
			sq_token.get_radius_px(),
			_attack_sim_atk_zone as Constants.HullZone,
			atk_arc_pts))
	var dist: float = range_data.get("distance", INF)
	if dist >= INF:
		return false
	var band: String = GameScale.get_range_band(dist)
	return band != Constants.RANGE_BAND_BEYOND


## Returns true if the given hull zone on the attacker has ANY valid
## enemy target (ship or squadron) in arc and at attack range.
## Used to auto-skip attack when no targets exist.
## Requirements: AE-SKIP-003.
func _attack_exec_zone_has_targets(ship_token: ShipToken,
		zone: Constants.HullZone) -> bool:
	var atk_arc_pts: Dictionary = \
			ship_token.get_firing_arc_world_points()
	var atk_edge: Array[Vector2] = _get_ship_edge(ship_token, zone)
	var attacker_faction: int = ship_token.get_faction()
	# Check enemy ships.
	for def_token: ShipToken in _board.get_ship_tokens():
		if def_token.get_faction() == attacker_faction:
			continue
		if def_token == ship_token:
			continue
		# Check all 4 hull zones of the defender.
		for def_zone: int in [Constants.HullZone.FRONT,
				Constants.HullZone.LEFT, Constants.HullZone.RIGHT,
				Constants.HullZone.REAR]:
			var def_edge: Array[Vector2] = _get_ship_edge(
					def_token, def_zone as Constants.HullZone)
			if not RangeFinder.is_hull_zone_edge_in_arc(
					def_edge, zone, atk_arc_pts):
				continue
			var range_data: Dictionary = (
					RangeFinder.measure_attack_range_ship_endpoints(
					atk_edge, def_edge, zone, atk_arc_pts))
			var dist: float = range_data.get("distance", INF)
			if dist >= INF:
				continue
			var rng_band: String = GameScale.get_range_band(dist)
			if rng_band != Constants.RANGE_BAND_BEYOND:
				return true
	# Check enemy squadrons.
	for sq_token: SquadronToken in _board.get_squadron_tokens():
		if sq_token.get_faction() == attacker_faction:
			continue
		if not RangeFinder.is_squadron_in_arc(
				sq_token.global_position, sq_token.get_radius_px(),
				zone, atk_arc_pts):
			continue
		var range_data: Dictionary = (
				RangeFinder.measure_attack_range_squadron_endpoints(
				atk_edge, sq_token.global_position,
				sq_token.get_radius_px(), zone, atk_arc_pts))
		var dist: float = range_data.get("distance", INF)
		if dist >= INF:
			continue
		var rng_band: String = GameScale.get_range_band(dist)
		if rng_band != Constants.RANGE_BAND_BEYOND:
			return true
	return false


## Returns true if the attacker has valid targets from ANY unfired
## hull zone.
## Requirements: AE-SKIP-003.
func _attack_exec_has_any_valid_target() -> bool:
	if _attack_exec_ship_token == null:
		return false
	var all_zones: Array[int] = [
		Constants.HullZone.FRONT, Constants.HullZone.LEFT,
		Constants.HullZone.RIGHT, Constants.HullZone.REAR,
	]
	for zone: int in all_zones:
		if zone in _attack_exec_fired_zones:
			continue
		if _attack_exec_zone_has_targets(
				_attack_exec_ship_token,
				zone as Constants.HullZone):
			return true
	return false


## Prepares the board for attacking the next squadron in the same arc.
## Resets target and dice state but keeps the hull zone locked.
## Requirements: AE-SQ-004, AE-SQ-005.
## Rules Reference: "Attack", Step 6, p.2 — "Treat each repetition of
## steps 2 through 6 as a new attack for the purposes of resolving
## card effects."
func _attack_exec_prepare_next_squadron() -> void:
	_log.info("Preparing next squadron target (Step 6 loop). " \
			+"Attacked so far: %d." \
			% _attack_exec_attacked_squads.size())
	# Reset target and dice state.
	_attack_sim_clear_target_state()
	_attack_exec_dice_results.clear()
	_attack_exec_pool.clear()
	_attack_exec_range_band = ""
	# Clean up target visuals, keep spent zone markers.
	if _attack_sim_overlay:
		_attack_sim_overlay.clear_target()
	# Stay in target-selection mode with the hull zone locked.
	_attack_sim_selecting = false
	_attack_sim_target_selecting = true
	# Update panel with "Select next squadron" prompt.
	if _attack_sim_panel:
		_attack_sim_panel.hide_dice_count()
		_attack_sim_panel.hide_dice_results()
		_attack_sim_panel.hide_confirm_button()
		_attack_sim_panel.hide_cf_dial_section()
		_attack_sim_panel.hide_cf_token_section()
		_attack_sim_panel.hide_roll_button()
		var ship_name: String = ""
		if _attack_exec_ship_token.get_ship_data():
			ship_name = \
					_attack_exec_ship_token.get_ship_data().ship_name
		_attack_sim_panel.show_select_next_squadron(
				ship_name, _attack_sim_atk_zone_name)
		_attack_sim_panel.show_skip_attack_button()


## Prepares the board for a second hull zone attack.
## Resets target state and returns to hull zone selection.
## Requirements: AE-2HZ-004, AE-2HZ-005.
func _attack_exec_prepare_next_attack() -> void:
	_log.info("Preparing second attack (attack %d/2)." % [
			_attack_exec_current_attack + 1])
	# Auto-skip if no valid targets remain from unfired hull zones.
	if not _attack_exec_has_any_valid_target():
		_log.info(
				"No valid targets for second attack — auto-skipping.")
		_finish_attack_execution()
		return
	# Reset target and dice state.
	_attack_sim_clear_target_state()
	_attack_exec_dice_results.clear()
	_attack_exec_pool.clear()
	_attack_exec_range_band = ""
	_attack_exec_attacked_squads.clear()
	# Clean up target visuals, keep spent zone markers.
	if _attack_sim_overlay:
		_attack_sim_overlay.clear_target()
	# Return to hull zone selection.
	_attack_sim_selecting = true
	_attack_sim_target_selecting = false
	# Update panel.
	if _attack_sim_panel:
		_attack_sim_panel.hide_dice_count()
		var ship_name: String = ""
		if _attack_exec_ship_token.get_ship_data():
			ship_name = \
					_attack_exec_ship_token.get_ship_data().ship_name
		_attack_sim_panel.show_initial_attack_exec(ship_name)
		_attack_sim_panel.show_skip_attack_button()
	# Restore range overlay.
	if _attack_sim_range_overlay:
		_attack_sim_range_overlay.queue_free()
		_attack_sim_range_overlay = null
	_attack_sim_range_overlay = RangeOverlayScene.new()
	_attack_sim_range_overlay.name = "AttackExecRangeOverlay"
	_token_container.add_child(_attack_sim_range_overlay)
	_token_container.move_child(_attack_sim_range_overlay, 0)
	_attack_sim_range_overlay.setup(_attack_exec_ship_token)


## Called when the player presses "Skip Attack".
## During hull zone selection: ends the attack step immediately.
## During the Step 6 squadron loop: ends the loop and proceeds to
## the next hull zone (or finishes if both are done).
## Requirements: AE-SKIP-001, AE-SKIP-002, AE-SQ-006.
func _on_attack_skip() -> void:
	# If we're in the Step 6 squadron loop (attacked >=1 squadron and
	# still target-selecting for the next one), treat as "done with
	# this hull zone's anti-squadron attacks."
	if _attack_exec_attacked_squads.size() > 0 and \
			_attack_sim_target_selecting:
		_log.info(
				"Squadron loop skipped — moving to next hull zone.")
		# Record this zone as fired.
		if _attack_sim_atk_zone >= 0:
			_attack_exec_fired_zones.append(_attack_sim_atk_zone)
		_attack_exec_mark_spent_zone()
		_attack_exec_current_attack += 1
		_attack_exec_attacked_squads.clear()
		if _attack_exec_current_attack < 2:
			_attack_exec_prepare_next_attack()
			return
		_finish_attack_execution()
		return
	_log.info("Attack skipped by player.")
	_finish_attack_execution()


## Fades out a destroyed token over 0.8 seconds, then hides it.
## Called when a ship or squadron is destroyed during an attack.
## Rules Reference: GF-004 — destroyed ships are removed from play.
func _fade_out_token(token: Node2D) -> void:
	if token == null:
		return
	var tween: Tween = token.create_tween()
	tween.tween_property(token, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func() -> void:
		token.visible = false
		# Reset alpha so the token could theoretically be shown again.
		token.modulate.a = 1.0
	)
