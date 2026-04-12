## TargetSelector
##
## Owns the attacker/target selection pipeline shared by both the free-form
## attack simulator and the real attack execution flow. Manages the
## AttackSimPanel, AttackSimOverlay, RangeOverlayScene for visual aids,
## and the AttackTargetResolver for LOS/range/arc computation.
##
## In simulator mode (exec_mode == false), selection ends at the info panel.
## In execution mode (exec_mode == true), selection emits [signal target_locked]
## so the AttackExecutor can begin the dice sequence.
##
## Extracted from AttackExecutor as part of refactoring phase F5d (Option B).
## Requirements: AS-*, AE-TGT-*, AE-FLOW-002.
## Rules Reference: "Attack", Step 1, pp.2–3.
class_name TargetSelector
extends Node

## Preloaded script reference for calling static functions without triggering
## STATIC_CALLED_ON_INSTANCE warnings (Constants is an autoload instance).
const ConstantsScript := preload("res://src/autoload/constants.gd")

## Emitted when the executor needs GameBoard to dismiss other tools
## (range overlay, targeting list, maneuver tool) before activating.
signal dismiss_other_tools_requested

## Emitted when a valid target is selected in execution mode.
## The AttackExecutor connects to this to begin the dice sequence.
## [param range_band] — the computed range band string.
## [param dice_text] — human-readable dice pool description.
signal target_locked(range_band: String, dice_text: String)

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

## Callable that returns Array[ShipToken] — injected by GameBoard.
var _get_ship_tokens: Callable

## Callable that returns Array[SquadronToken] — injected by GameBoard.
var _get_squadron_tokens: Callable

## Container for all token nodes (for adding overlays).
var _token_container: Node2D = null

## Camera node reference.
var _camera: BoardCamera = null

## Shared mutable state for the current attack flow.
## Owned by AttackExecutor; passed by reference.
var _state: AttackState = null

## Pure-computation resolver for dice pool text display.
## Owned by AttackExecutor; passed by reference.
var _dice_resolver: AttackDiceResolver = null

## Logger instance.
var _log: GameLogger = GameLogger.new("TargetSelector")

## Pure-geometry resolver for targeting, LOS, range, and target availability.
## Constructed in [method initialize] with scene-tree callables.
var _target_resolver: AttackTargetResolver = null

# ---------------------------------------------------------------------------
# Selection state
# ---------------------------------------------------------------------------

## Whether we are in "select attacker" mode.
var _selecting: bool = false

## Whether we are in "select target" mode (attacker already chosen).
## Requirements: AS-TGT-001, AS-TGT-010.
var _target_selecting: bool = false

## Attack simulator info panel (null when not displayed).
var _panel: AttackSimPanel = null

## Attack simulator visual-aid overlay (null when not displayed).
var _overlay: AttackSimOverlay = null

## Range overlay shown as part of the attack simulator.
var _range_overlay: RangeOverlayScene = null


# ===========================================================================
# Public Interface
# ===========================================================================

## Initializes the selector with references to board infrastructure.
## [param get_ship_tokens] — Callable returning Array[ShipToken].
## [param get_squadron_tokens] — Callable returning Array[SquadronToken].
## [param token_container] — Node2D parent for overlays.
## [param camera] — BoardCamera reference.
## [param state] — Shared AttackState (owned by AttackExecutor).
## [param dice_resolver] — AttackDiceResolver for dice text.
func initialize(
		get_ship_tokens: Callable,
		get_squadron_tokens: Callable,
		token_container: Node2D,
		camera: BoardCamera,
		state: AttackState,
		dice_resolver: AttackDiceResolver) -> void:
	_get_ship_tokens = get_ship_tokens
	_get_squadron_tokens = get_squadron_tokens
	_token_container = token_container
	_camera = camera
	_state = state
	_dice_resolver = dice_resolver
	_target_resolver = AttackTargetResolver.new(
			get_ship_tokens, get_squadron_tokens,
			_build_obstruction_bodies)


## Returns the [AttackTargetResolver] for callers that need target checks.
func get_target_resolver() -> AttackTargetResolver:
	return _target_resolver


## Returns the shared [AttackState] for callers that share state.
func get_state() -> AttackState:
	return _state


## Returns the [AttackSimPanel] for callers that need panel access.
func get_panel() -> AttackSimPanel:
	return _panel


## Returns the selection flag.
func is_selecting() -> bool:
	return _selecting


## Returns the target-selection flag.
func is_target_selecting() -> bool:
	return _target_selecting


## Whether the selector has any active UI.
func is_active() -> bool:
	return _selecting or _target_selecting \
			or (_panel != null and _panel.visible)


## Handles the "Attack Simulator" toolbar button/key press.
## Toggle behaviour: if already active, dismiss. Otherwise activate
## and dismiss any other active tool first.
## Blocked during attack execution mode (use the activation modal instead).
## Requirements: AS-ACT-001, AS-ACT-004, AS-ACT-005, AE-FLOW-005.
func on_simulator_requested() -> void:
	# Block simulator toggle during attack execution.
	if _state.exec_mode:
		return
	if _selecting or _target_selecting \
			or (_panel and _panel.visible):
		dismiss()
		return
	# Dismiss other tools first (AS-ACT-005).
	dismiss_other_tools_requested.emit()
	_activate_sim()


## Enters attacker-selection mode for the attack execution flow.
## Called by AE after setting up exec state.
## [param show_exec_initial] — if true, shows the exec-mode initial panel.
## [param ship_name] — attacker ship name for exec panel display.
func enter_attacker_selection(show_exec_initial: bool = false,
		ship_name: String = "") -> void:
	_selecting = true
	_ensure_panel()
	if show_exec_initial:
		_panel.show_initial_attack_exec(ship_name)
	else:
		_panel.show_initial()


## Enters target-selection mode for a pre-selected squadron attacker.
## Called by AE after setting up exec state for squadron attacks.
## [param squadron_token] — the squadron token to show visuals for.
func enter_squadron_target_selection(
		squadron_token: SquadronToken) -> void:
	_selecting = false
	_target_selecting = true
	_ensure_panel()
	_show_squadron_visuals(squadron_token)


## Creates the attack simulation panel on a CanvasLayer if absent.
func _ensure_panel() -> void:
	if _panel != null:
		return
	_panel = AttackSimPanel.new()
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "AttackSimPanelLayer"
	layer.layer = 90
	add_child(layer)
	layer.add_child(_panel)


## Routes a ship token click. Returns true if handled.
func handle_ship_click(token: ShipToken) -> bool:
	if _target_selecting:
		_handle_target_ship_click(token)
		return true
	if _selecting:
		_handle_ship_click(token)
		return true
	return false


## Routes a squadron token click. Returns true if handled.
func handle_squadron_click(token: SquadronToken) -> bool:
	if _target_selecting:
		_handle_target_squadron_click(token)
		return true
	if _selecting:
		_handle_squadron_click(token)
		return true
	return false


## Handles Escape key press. Returns true if consumed.
## In attack execution mode, signals cancellation via the return value.
## Requirements: AS-ACT-003, AS-TGT-022, AE-FLOW-004.
func handle_escape(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.keycode != KEY_ESCAPE:
		return false
	if _selecting or _target_selecting \
			or (_panel and _panel.visible):
		dismiss()
		get_viewport().set_input_as_handled()
		return true
	return false


## Dismisses the selector, removing all visual aids.
## Requirements: AS-ACT-003, AS-PNL-003, AS-TGT-022.
func dismiss() -> void:
	_selecting = false
	_target_selecting = false
	_clear_attacker_state()
	_clear_target_state()
	# Remove info panel.
	if _panel:
		_panel.close()
	# Remove visual overlay.
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	# Remove range overlay.
	if _range_overlay:
		_range_overlay.queue_free()
		_range_overlay = null
	_log.info("Target selector dismissed.")


## Creates a range overlay centred on the given ship token.
## Used by AE to show the range overlay during ship attack execution.
func show_ship_range_overlay(ship_token: ShipToken) -> void:
	if _range_overlay:
		_range_overlay.queue_free()
		_range_overlay = null
	_range_overlay = RangeOverlayScene.new()
	_range_overlay.name = "AttackExecRangeOverlay"
	_token_container.add_child(_range_overlay)
	_token_container.move_child(_range_overlay, 0)
	_range_overlay.setup(ship_token)


## Returns true if the given ship has at least one valid attack target
## from any of its four hull zones.
## Rules Reference: "Attack", p.2 — a ship is not required to attack.
func has_any_attack_target(ship_token: ShipToken) -> bool:
	return _target_resolver.has_any_attack_target(ship_token)


## Resets dice-sequence UI elements on the panel.
## Called by AE when deselecting a target during the dice phase.
func reset_dice_ui() -> void:
	if _panel:
		_panel.hide_dice_count()
		_panel.hide_dice_results()
		_panel.hide_cf_dial_section()
		_panel.hide_cf_token_section()
		_panel.hide_roll_button()
		_panel.hide_confirm_button()
		_panel.hide_skip_attack_button()


## Deselects the current target. Returns to "Select a target" prompt.
## Accessible to AE for dice-phase target deselection.
func deselect_target() -> void:
	_deselect_target()


## Builds a [CombatParticipants] from the current attacker/target state.
func build_current_participants() -> CombatParticipants:
	return CombatParticipants.create(
			_state.attacker_ship, _state.attacker_zone,
			_state.attacker_squadron,
			_state.defender_ship, _state.defender_zone,
			_state.defender_squadron)


## Returns the [AttackSimOverlay] for exec-mode visual updates
## (e.g. spent-zone markers during 2HZ flow).
func get_overlay() -> AttackSimOverlay:
	return _overlay


## Returns the squadron-token callable for exec-mode iteration.
func get_squadron_tokens_callable() -> Callable:
	return _get_squadron_tokens


## Clears defender state. Used by exec code during auto-skip flows.
func clear_target_state() -> void:
	_clear_target_state()


## Prepares for the next squadron target in the Step 6 loop.
## Clears target state and overlay target marker; enters target-selection
## mode while keeping the attacker hull zone locked.
func prepare_next_squadron_target() -> void:
	_clear_target_state()
	if _overlay:
		_overlay.clear_target()
	_selecting = false
	_target_selecting = true


## Prepares for the next hull-zone attack (AE-2HZ flow).
## Clears overlay target marker and returns to attacker-selection mode.
func prepare_next_hull_zone() -> void:
	if _overlay:
		_overlay.clear_target()
	_selecting = true
	_target_selecting = false


# ===========================================================================
# Attacker Selection (Phase 6a)
# ===========================================================================

## Enters attacker-selection mode and shows the info panel.
## Requirements: AS-ACT-001, AS-PNL-001, AS-PNL-002.
func _activate_sim() -> void:
	_selecting = true
	_ensure_panel()
	_panel.show_initial()
	_log.info("Attack simulator activated.")


## Handles a ship token click during attacker selection.
## Determines the hull zone from the click position and sets up visual aids.
## Requirements: AS-SEL-001, AS-SEL-002, AE-FLOW-002.
func _handle_ship_click(token: ShipToken) -> void:
	# Attack execution guard: only activated ship allowed as attacker.
	if _state.exec_mode and token != _state.exec_ship_token:
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
	if _state.exec_mode and zone in _state.fired_zones:
		var fired_name: String = _ZONE_NAMES.get(zone, "UNKNOWN")
		_log.info("Attack exec: zone %s already used." % fired_name)
		TooltipManager.show_text(
				"%s arc already used this activation." % fired_name,
				Vector2.INF, 2.0, true)
		return
	_select_attacker_ship_zone(token, zone)


## Stores attacker state and enters target selection for the given ship
## hull zone.
func _select_attacker_ship_zone(token: ShipToken, zone: int) -> void:
	var zone_name: String = _ZONE_NAMES.get(zone, "UNKNOWN")
	var ship_name: String = ""
	if token.get_ship_data():
		ship_name = token.get_ship_data().ship_name
	# During attack execution, reject zones that have no valid targets.
	# Rules Reference: "Attack", Step 1, p.2 — a hull zone with no
	# eligible targets cannot be used to declare an attack.
	if _state.exec_mode:
		if not _target_resolver.zone_has_targets(
				token, zone as Constants.HullZone):
			_log.info("Attack exec: %s arc has no valid targets."
					% zone_name)
			TooltipManager.show_text(
					"No valid targets in %s arc." % zone_name,
					Vector2.INF, 2.0, true)
			return
	_log.info("Attacker selected: %s — %s arc." % [ship_name, zone_name])
	_log.debug("Click at %s → %s hull zone." % [
			token.get_global_mouse_position(), zone_name])
	_state.attacker_ship = token
	_state.attacker_zone = zone
	_state.attacker_squadron = null
	_state.attacker_name = ship_name
	_state.attacker_zone_name = zone_name
	_selecting = false
	_target_selecting = true
	if _panel:
		_panel.show_hull_zone_selected(ship_name, zone_name)
	_show_hull_zone_visuals(token, zone)


## Creates the visual aids for a hull zone attacker: range overlay, arc
## boundary lines, and LOS marker.
## Requirements: AS-VIS-001, AS-VIS-002, AS-VIS-003.
func _show_hull_zone_visuals(token: ShipToken, zone: int) -> void:
	# Clear any previous visuals.
	_clear_overlays()
	# Range overlay (reuse RangeOverlayScene).
	_range_overlay = RangeOverlayScene.new()
	_range_overlay.name = "AttackSimRangeOverlay"
	_token_container.add_child(_range_overlay)
	_token_container.move_child(_range_overlay, 0)
	_range_overlay.setup(token)
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
	_overlay = AttackSimOverlay.new()
	_overlay.name = "AttackSimOverlay"
	_overlay.attack_execution_mode = _state.exec_mode
	_token_container.add_child(_overlay)
	_overlay.setup_hull_zone(inner_a, outer_a, inner_b, outer_b, los_pos)


## Frees existing overlays.
func _clear_overlays() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	if _range_overlay:
		_range_overlay.queue_free()
		_range_overlay = null


## Handles a squadron token click during attacker selection.
## Requirements: AS-SEL-010, AS-SEL-011, AE-FLOW-002.
func _handle_squadron_click(token: SquadronToken) -> void:
	# Attack execution guard: only the activated ship's hull zones may attack.
	if _state.exec_mode:
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
	_state.attacker_ship = null
	_state.attacker_zone = -1
	_state.attacker_squadron = token
	_state.attacker_name = squad_name
	_state.attacker_zone_name = ""
	# End attacker selection, enter target selection.
	_selecting = false
	_target_selecting = true
	# Update info panel.
	if _panel:
		_panel.show_squadron_selected(squad_name)
	# Show visual aids.
	_show_squadron_visuals(token)


## Creates the visual aids for a squadron attacker: close-range circle.
## Requirements: AS-VIS-010.
func _show_squadron_visuals(token: SquadronToken) -> void:
	# Clear any previous visuals.
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	if _range_overlay:
		_range_overlay.queue_free()
		_range_overlay = null
	_overlay = AttackSimOverlay.new()
	_overlay.name = "AttackSimOverlay"
	_token_container.add_child(_overlay)
	_overlay.setup_squadron(
			token.global_position, token.get_radius_px())


# ===========================================================================
# Target Selection (Phase 6a-2)
# ===========================================================================

## Handles a ship token click during target selection.
## Checks for deselection (same attacker hull zone), same-ship guard,
## arc containment, or sets the target.
## Requirements: AS-TGT-001–003, AS-TGT-020–021, AS-TGT-030, AS-ARC-001,
## AE-TGT-001.
func _handle_target_ship_click(token: ShipToken) -> void:
	var click_pos: Vector2 = token.get_global_mouse_position()
	var zone: int = token.get_hull_zone_at(click_pos)
	if zone < 0:
		_log.debug("Target click outside ship base — ignored.")
		return
	# Dice-phase guard: once the dice sequence has started (pool computed),
	# only allow deselecting the current target.
	if _state.exec_mode and _state.dice_pool.size() > 0:
		if _state.defender_ship == token and _state.defender_zone == zone:
			_log.info("Target deselected during dice phase — resetting.")
			reset_dice_ui()
			_deselect_target()
		return
	var reject: String = _validate_target_ship_click(token, zone)
	if reject != "":
		return
	# New target selected.
	var zone_name: String = _ZONE_NAMES.get(zone, "UNKNOWN")
	var ship_name: String = ""
	if token.get_ship_data():
		ship_name = token.get_ship_data().ship_name
	_log.info("Target selected: %s — %s arc." % [ship_name, zone_name])
	_state.defender_ship = token
	_state.defender_zone = zone
	_state.defender_squadron = null
	_state.defender_name = ship_name
	_state.defender_zone_name = zone_name
	_compute_and_show_los()


## Validates a target ship click. Returns "" if valid, or a non-empty
## string if the click was handled (deselect/reject). Handles deselect
## of attacker, deselect of target, same-ship guard, faction guard,
## and arc check.
func _validate_target_ship_click(token: ShipToken,
		zone: int) -> String:
	# Destroyed guard — destroyed ships cannot be targeted.
	var ship_inst: ShipInstance = token.get_ship_instance()
	if ship_inst and ship_inst.is_destroyed():
		return _reject_target("Target rejected: ship is destroyed.",
				"That ship has been destroyed.", "destroyed")
	# Attacker re-click → deselect both (AS-TGT-021).
	if _state.attacker_ship == token and _state.attacker_zone == zone:
		if _state.exec_mode and _state.attacked_squads.size() > 0:
			return _reject_target("Hull zone locked during squadron loop.",
					"Hull zone is locked during anti-squadron attacks.",
					"locked")
		_log.info("Attacker re-clicked — both deselected.")
		_deselect_both()
		return "deselected"
	# Current target re-click → deselect target (AS-TGT-020).
	if _state.defender_ship == token and _state.defender_zone == zone:
		_log.info("Target deselected.")
		_deselect_target()
		return "deselected"
	# Same-ship guard (AS-TGT-030).
	if _state.attacker_ship == token:
		return _reject_target("Target rejected: same ship as attacker.",
				"Cannot target the same ship.", "same_ship")
	# Faction guard (AE-TGT-001).
	if _state.exec_mode:
		if token.get_faction() == _get_attacker_faction():
			return _reject_target(
					"Attack exec: same-faction target rejected.",
					"Cannot target a friendly ship.", "friendly")
	# Engagement guard (SM-012): engaged squadron must attack engaged enemy.
	# Rules Reference: RRG "Engagement" p.4 — "A squadron that is engaged
	# cannot move and can only attack squadrons that it is engaged with."
	# Fresh recomputation avoids stale is_engaged after mid-turn destruction.
	if _state.exec_mode and _state.squad_exec_mode \
			and _state.exec_squad_token:
		if _is_squad_attacker_engaged_fresh():
			return _reject_target(
					"Attack exec: engaged squadron cannot target ships.",
					"Engaged — must attack an engaged enemy squadron.",
					"must_attack_engaged")
	# Squadron loop guard: cannot target ships during Step 6 loop.
	# Rules Reference: "Attack", Step 6, p.2 — after attacking a squadron,
	# the attacker may only choose a new *squadron* defender in the same arc.
	if _state.exec_mode and _state.attacked_squads.size() > 0:
		return _reject_target(
				"Attack exec: ship target rejected during squadron loop.",
				"Can only target squadrons during anti-squadron attacks.",
				"squadron_loop")
	# Arc check (AS-ARC-001).
	if _state.attacker_ship:
		var arc_parts: CombatParticipants = \
				CombatParticipants.create_attacker_only(
						_state.attacker_ship, _state.attacker_zone,
						null)
		if not _target_resolver.is_ship_target_in_arc(
				arc_parts, token, zone):
			return _reject_target("Target rejected: not in arc.",
					"Defender is not in arc.", "not_in_arc")
	return ""


## Logs a rejection message, shows a tooltip, and returns a reason string.
func _reject_target(log_msg: String, tooltip: String,
		reason: String) -> String:
	_log.info(log_msg)
	TooltipManager.show_text(tooltip, Vector2.INF, 2.0, true)
	return reason


## Returns true if the current squadron attacker is freshly engaged.
## Recomputes from live positions instead of using the cached
## [member SquadronInstance.is_engaged] flag, which may be stale after
## a mid-turn squadron destruction.
## Rules Reference: RRG "Engagement" p.4.
func _is_squad_attacker_engaged_fresh() -> bool:
	if _state.exec_squad_token == null:
		return false
	var sq_inst: SquadronInstance = \
			_state.exec_squad_token.get_squadron_instance()
	if sq_inst == null:
		return false
	var all_squads: Array[Dictionary] = _build_squadron_positions()
	return EngagementResolver.is_engaged(
			sq_inst, _state.exec_squad_token.global_position,
			all_squads)


## Builds an array of {"instance": …, "position": …} for all
## non-destroyed squadrons on the board. Used for fresh engagement
## checks during target validation.
func _build_squadron_positions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for sq_token: SquadronToken in _get_squadron_tokens.call():
		var inst: SquadronInstance = sq_token.get_squadron_instance()
		if inst and not inst.is_destroyed():
			result.append({
				"instance": inst,
				"position": sq_token.global_position,
			})
	return result


## Returns the attacker faction for target validation guards.
func _get_attacker_faction() -> Constants.Faction:
	if _state.exec_ship_token:
		return _state.exec_ship_token.get_faction()
	if _state.exec_squad_token:
		return _state.exec_squad_token.get_faction()
	return Constants.Faction.REBEL_ALLIANCE


## Handles a squadron token click during target selection.
## Checks for deselection (same attacker squadron), arc containment,
## or sets the target.
## Requirements: AS-TGT-010–012, AS-TGT-020–021, AS-ARC-001–002.
func _handle_target_squadron_click(
		token: SquadronToken) -> void:
	# Dice-phase guard: once the dice sequence has started (pool computed),
	# only allow deselecting the current target.
	if _state.exec_mode and _state.dice_pool.size() > 0:
		if _state.defender_squadron == token:
			_log.info("Target deselected during dice phase — resetting.")
			reset_dice_ui()
			_deselect_target()
		return
	var reject: String = _validate_target_squadron_click(token)
	if reject != "":
		return
	# New target selected.
	var inst: SquadronInstance = token.get_squadron_instance()
	var squad_name: String = "Squadron"
	if inst and inst.squadron_data:
		squad_name = inst.squadron_data.squadron_name
	_log.info("Target selected: %s." % squad_name)
	_state.defender_ship = null
	_state.defender_zone = -1
	_state.defender_squadron = token
	_state.defender_name = squad_name
	_state.defender_zone_name = ""
	_compute_and_show_los()


## Validates a target squadron click. Returns "" if valid, or a non-empty
## string if the click was handled (deselect/reject).
func _validate_target_squadron_click(
		token: SquadronToken) -> String:
	# Destroyed guard — destroyed squadrons cannot be targeted.
	var sq_inst: SquadronInstance = token.get_squadron_instance()
	if sq_inst and sq_inst.is_destroyed():
		return _reject_target("Target rejected: squadron is destroyed.",
				"That squadron has been destroyed.", "destroyed")
	# Attacker re-click → deselect both (AS-TGT-021).
	if _state.attacker_squadron == token:
		if _state.squad_exec_mode:
			_log.info("Attacker re-clicked in squad exec — ignored.")
			return "locked"
		_log.info("Attacker re-clicked — both deselected.")
		_deselect_both()
		return "deselected"
	# Current target re-click → deselect (AS-TGT-020).
	if _state.defender_squadron == token:
		_log.info("Target deselected.")
		_deselect_target()
		return "deselected"
	# Arc check (AS-ARC-001, skipped for squadron attacker AS-ARC-002).
	if _state.attacker_ship:
		var arc_parts: CombatParticipants = \
				CombatParticipants.create_attacker_only(
						_state.attacker_ship, _state.attacker_zone,
						null)
		if not _target_resolver.is_squadron_target_in_arc(
				arc_parts, token):
			return _reject_target("Target rejected: not in arc.",
					"Defender is not in arc.", "not_in_arc")
	# Faction guard.
	if _state.exec_mode:
		if token.get_faction() == _get_attacker_faction():
			return _reject_target(
					"Attack exec: same-faction squadron rejected.",
					"Cannot target a friendly squadron.", "friendly")
	# Engagement guard (SM-012): if engaged, can only attack engaged enemies.
	# Rules Reference: RRG "Engagement" p.4 — "A squadron that is engaged
	# … can only attack squadrons that it is engaged with."
	# Fresh recomputation avoids stale is_engaged after mid-turn destruction.
	if _state.exec_mode and _state.squad_exec_mode \
			and _state.exec_squad_token:
		if _is_squad_attacker_engaged_fresh():
			var all_squads: Array[Dictionary] = \
					_build_squadron_positions()
			var def_inst: SquadronInstance = \
					token.get_squadron_instance()
			var def_engaged: bool = false
			if def_inst:
				def_engaged = EngagementResolver.is_engaged(
						def_inst, token.global_position, all_squads)
			if not def_engaged:
				return _reject_target(
						"Attack exec: engaged attacker cannot target "
						+"non-engaged squadron.",
						"Must attack an engaged enemy squadron.",
						"must_attack_engaged")
	# Already-attacked guard (Step 6, AE-SQ-002).
	if _state.exec_mode and token in _state.attacked_squads:
		return _reject_already_attacked_squad(token)
	return ""


## Rejects a squadron that has already been attacked this activation.
func _reject_already_attacked_squad(
		token: SquadronToken) -> String:
	var inst_name: String = "Squadron"
	var sq_inst: SquadronInstance = token.get_squadron_instance()
	if sq_inst and sq_inst.squadron_data:
		inst_name = sq_inst.squadron_data.squadron_name
	return _reject_target(
			"Attack exec: %s already attacked this activation."
			% inst_name,
			"%s has already been attacked." % inst_name,
			"already_attacked")


## Clears stored attacker state.
func _clear_attacker_state() -> void:
	_state.clear_attacker()


## Clears stored target state.
func _clear_target_state() -> void:
	_state.clear_defender()


## Deselects the target only; returns to "Select a target" prompt.
## Attacker visuals remain active.
## Requirements: AS-TGT-020.
func _deselect_target() -> void:
	_clear_target_state()
	# Remove target visuals from overlay (keep attacker visuals).
	if _overlay:
		_overlay.clear_target()
	# Hide dice count when target is deselected.
	if _panel:
		_panel.hide_dice_count()
	# Restore "Select a target" prompt.
	if _panel:
		if _state.attacker_zone_name != "":
			_panel.show_hull_zone_selected(
					_state.attacker_name, _state.attacker_zone_name)
		else:
			_panel.show_squadron_selected(_state.attacker_name)


## Deselects both attacker and target; returns to initial prompt.
## Requirements: AS-TGT-021.
func _deselect_both() -> void:
	_clear_attacker_state()
	_clear_target_state()
	_target_selecting = false
	_selecting = true
	# Remove all visuals.
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	if _range_overlay:
		_range_overlay.queue_free()
		_range_overlay = null
	# Show initial prompt.
	if _panel:
		_panel.hide_dice_count()
		if _state.exec_mode and _state.exec_ship_token:
			# Restore range overlay for activated ship.
			_range_overlay = RangeOverlayScene.new()
			_range_overlay.name = "AttackExecRangeOverlay"
			_token_container.add_child(_range_overlay)
			_token_container.move_child(_range_overlay, 0)
			_range_overlay.setup(_state.exec_ship_token)
			var ship_name: String = ""
			if _state.exec_ship_token.get_ship_data():
				ship_name = \
						_state.exec_ship_token.get_ship_data().ship_name
			_panel.show_initial_attack_exec(ship_name)
		else:
			_panel.show_initial()


# ===========================================================================
# LOS, Range, Obstruction
# ===========================================================================

## Computes LOS and range between attacker and target, then updates the
## overlay and info panel with the results.
## Requirements: AS-VIS-020–022, AS-PNL-011, AS-LOG-010, AS-RNG-010–014.
func _compute_and_show_los() -> void:
	var parts: CombatParticipants = build_current_participants()
	# Compute LOS via resolver.
	var los_info: Dictionary = _target_resolver.compute_los(parts)
	# Reset obstruction flag for this target evaluation.
	_state.obstructed = los_info["obstructed"]
	var status: int = los_info["status"]
	var los_text: String = los_info["text"]
	_log.info("LOS: %s." % los_text)
	# Compute range measurement via resolver.
	var range_data: Dictionary = _target_resolver.compute_range(parts)
	var range_distance: float = range_data.get("distance", INF)
	var range_band: String = Constants.RANGE_BAND_BEYOND
	if range_distance < INF:
		range_band = GameScale.get_range_band(range_distance)
	_log.info("Range: %s (%.0f px)." % [range_band, range_distance])
	_update_los_overlay_and_panel(
			los_info["atk_pt"], los_info["def_pt"], status, los_text,
			range_data, range_distance, range_band)


## Updates overlay visuals and panel with LOS/range results.
## In execution mode, emits [signal target_locked] so AE can begin dice.
func _update_los_overlay_and_panel(atk_pt: Vector2, def_pt: Vector2,
		status: int, los_text: String, range_data: Dictionary,
		range_distance: float, range_band: String) -> void:
	if _overlay:
		if _state.defender_ship:
			_overlay.setup_target_hull_zone(def_pt)
		else:
			_overlay.setup_target_squadron(def_pt)
		_overlay.setup_los_line(atk_pt, def_pt, status)
		if range_distance < INF:
			_overlay.setup_range_line(
					range_data["atk_pt"], range_data["def_pt"],
					range_band)
	if _panel:
		_panel.show_target_selected(
				_state.attacker_name, _state.attacker_zone_name,
				_state.defender_name, _state.defender_zone_name,
				los_text, range_band)
	if _state.exec_mode and _panel:
		_state.range_band = range_band
		var dice_text: String = _compute_dice_text(range_band)
		_panel.show_dice_count(dice_text)
		_log.info("Dice pool: %s." % dice_text)
		target_locked.emit(range_band, dice_text)


## Computes the dice pool text for the current attacker/target pair at the
## given [param range_band].
## Requirements: AE-PNL-002.
## Rules Reference: "Attack", Step 2, p.2; "Squadron Attacks", RRG p.19.
func _compute_dice_text(range_band: String) -> String:
	var parts: CombatParticipants = build_current_participants()
	return _dice_resolver.compute_dice_text(parts, range_band)


## Builds obstruction bodies from all ships excluding attacker/defender.
func _build_obstruction_bodies() -> Array:
	var bodies: Array = []
	for child: Node in _token_container.get_children():
		if child is ShipToken:
			var st: ShipToken = child as ShipToken
			if st == _state.attacker_ship or st == _state.defender_ship:
				continue
			var sd: ShipData = st.get_ship_data()
			if sd:
				bodies.append(
						LineOfSightChecker.ObstructionBody.from_ship_base(
								sd.ship_name, st.global_position,
								st.rotation, st.get_half_width(),
								st.get_half_length()))
	return bodies
