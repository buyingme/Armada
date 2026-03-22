## AttackModeController
##
## Board-level controller that manages the attack sub-step during ship
## activation. Coordinates user input (hull zone selection, target selection),
## the [AttackSequenceState] state machine, the [AttackInfoPanel] UI,
## and visual overlays (LOS lines, hull zone highlights).
##
## Created by [GameBoard] when the activation modal reaches the Attack step.
## Destroyed when all attacks are complete or the player skips.
##
## This is a scene-tree Node so it can own the info panel CanvasLayer
## and draw overlays.
##
## Requirements: ATK-FLOW-001–003, ATK-UI-001.
class_name AttackModeController
extends Node2D


## Emitted when all attacks are done (or skipped).
signal attacks_finished()

## Logger.
var _log: GameLogger = GameLogger.new("AttackMode")

## The attack sequence state machine (core logic).
var _attack_state: AttackSequenceState = null

## The info panel UI (floating centred panel).
var _info_panel: AttackInfoPanel = null

## The CanvasLayer for the info panel (layer 85 — above activation modal).
var _panel_layer: CanvasLayer = null

## The activating ship token (for LOS/arc geometry).
var _attacker_token: ShipToken = null

## All enemy ship tokens (potential targets).
var _enemy_ship_tokens: Array[ShipToken] = []

## All enemy squadron tokens (potential targets).
var _enemy_squad_tokens: Array = []  # Array[SquadronToken]

## Currently highlighted target token (yellow outline).
var _highlighted_target: Node2D = null

## LOS line endpoints for drawing (world space).
var _los_line_from: Vector2 = Vector2.ZERO
var _los_line_to: Vector2 = Vector2.ZERO
var _los_line_visible: bool = false

## All ship body data for obstruction checks.
var _all_ship_bodies: Array = []


## Sets up the controller for the given activation.
## [param activation_state] — the ShipActivationState.
## [param attacker_token] — the ShipToken of the attacker.
## [param enemy_ships] — Array[ShipToken] of enemy ships.
## [param enemy_squads] — Array of enemy SquadronTokens.
## [param all_ship_bodies] — obstruction data for LOS.
func setup(
		activation_state: ShipActivationState,
		attacker_token: ShipToken,
		enemy_ships: Array[ShipToken],
		enemy_squads: Array,
		all_ship_bodies: Array) -> void:
	_attacker_token = attacker_token
	_enemy_ship_tokens = enemy_ships
	_enemy_squad_tokens = enemy_squads
	_all_ship_bodies = all_ship_bodies

	# Create the state machine.
	_attack_state = AttackSequenceState.create(activation_state)
	_attack_state.begin_attacks()

	# Create the info panel on a CanvasLayer.
	_panel_layer = CanvasLayer.new()
	_panel_layer.name = "AttackInfoLayer"
	_panel_layer.layer = 85
	add_child(_panel_layer)

	_info_panel = AttackInfoPanel.new()
	_info_panel.name = "AttackInfoPanel"
	_panel_layer.add_child(_info_panel)

	# Connect panel signals.
	_info_panel.cf_die_requested.connect(_on_cf_die_requested)
	_info_panel.cf_dial_skipped.connect(_on_cf_dial_skipped)
	_info_panel.roll_requested.connect(_on_roll_requested)
	_info_panel.skip_requested.connect(_on_skip_requested)
	_info_panel.finish_step_requested.connect(_on_finish_step)
	_info_panel.defense_token_selected.connect(_on_defense_token_selected)
	_info_panel.damage_acknowledged.connect(_on_damage_acknowledged)
	_info_panel.additional_target_requested.connect(
			_on_additional_target_requested)
	_info_panel.next_attack_requested.connect(_on_next_attack)
	_info_panel.all_attacks_done_requested.connect(_on_all_attacks_done)

	_info_panel.open(_attack_state)
	_centre_panel()


## Cleans up and removes the controller.
func teardown() -> void:
	_los_line_visible = false
	_highlighted_target = null
	if _info_panel:
		_info_panel.close()
	if _panel_layer:
		_panel_layer.queue_free()
		_panel_layer = null
	_info_panel = null
	_attack_state = null
	queue_free()


## Returns the attack state machine.
func get_attack_state() -> AttackSequenceState:
	return _attack_state


## Called when a ship token is clicked during attack mode.
## Handles hull zone selection (on own ship) or target selection (on enemy).
func handle_ship_click(token: ShipToken) -> void:
	if _attack_state == null:
		return

	var state: AttackSequenceState.State = _attack_state.get_state()

	if state == AttackSequenceState.State.HULL_ZONE_SELECT:
		# Clicking own ship selects a hull zone.
		if token == _attacker_token:
			_select_hull_zone_from_click(token)
		return

	if state == AttackSequenceState.State.TARGET_SELECT:
		# Clicking own ship changes attacking zone.
		if token == _attacker_token:
			_attack_state.deselect_attacking_zone()
			_select_hull_zone_from_click(token)
			_refresh_panel()
			return
		# Clicking enemy ship selects it as target.
		if _is_enemy_ship(token):
			_select_ship_target(token)
		return

	if state == AttackSequenceState.State.ADDITIONAL_SQUAD_TARGET:
		# Ship clicks are ignored during step 6.
		return


## Called when a squadron token is clicked during attack mode.
func handle_squadron_click(token: Node2D) -> void:
	if _attack_state == null:
		return

	var state: AttackSequenceState.State = _attack_state.get_state()

	if state == AttackSequenceState.State.TARGET_SELECT:
		if _is_enemy_squadron(token):
			_select_squadron_target(token)
		return

	if state == AttackSequenceState.State.ADDITIONAL_SQUAD_TARGET:
		if _is_enemy_squadron(token):
			_select_additional_squad(token)
		return


# ---------------------------------------------------------------------------
# Hull Zone Selection
# ---------------------------------------------------------------------------


## Determines the closest hull zone on the attacker for the click and selects it.
## Uses the LOS origin points as zone centres for proximity detection.
func _select_hull_zone_from_click(token: ShipToken) -> void:
	# For now, cycle through hull zones in order: FRONT, RIGHT, LEFT, REAR.
	# A more advanced approach would detect which zone the click is in.
	var zones: Array[Constants.HullZone] = [
		Constants.HullZone.FRONT,
		Constants.HullZone.RIGHT,
		Constants.HullZone.LEFT,
		Constants.HullZone.REAR,
	]
	for zone: Constants.HullZone in zones:
		if _attack_state.select_attacking_zone(zone):
			_refresh_panel()
			return
	# All zones used — signal done.
	_log.info("All hull zones already used.")
	_attack_state.skip_remaining_attacks()
	_finish_attacks()


# ---------------------------------------------------------------------------
# Target Selection
# ---------------------------------------------------------------------------


## Selects an enemy ship as the target, measuring range and LOS.
func _select_ship_target(target_token: ShipToken) -> void:
	var attacker_inst: ShipInstance = _attacker_token.get_ship_instance()
	var defender_inst: ShipInstance = target_token.get_ship_instance()
	if attacker_inst == null or defender_inst == null:
		return

	var atk_zone: int = _attack_state.get_attacking_zone()
	var atk_zone_str: String = Constants.HullZone.keys()[atk_zone]

	# Get attacker LOS origin for the attacking zone.
	var los_origins: Dictionary = _attacker_token.get_los_origins_world()
	var atk_origin: Vector2 = los_origins.get(atk_zone_str, Vector2.ZERO)

	# Measure range to each defender hull zone, pick closest.
	var best_zone: Constants.HullZone = Constants.HullZone.FRONT
	var best_range: String = ""
	var best_obstructed: bool = false
	var found_valid: bool = false

	var def_los_origins: Dictionary = target_token.get_los_origins_world()

	for zone_val: int in range(Constants.HullZone.size()):
		var zone: Constants.HullZone = zone_val as Constants.HullZone
		var zone_str: String = Constants.HullZone.keys()[zone_val]
		var def_pt: Vector2 = def_los_origins.get(zone_str, Vector2.ZERO)
		if def_pt == Vector2.ZERO:
			continue

		var range_result: Dictionary = RangeFinder.measure_attack_range_ship(
				atk_origin, def_pt)
		var range_band: String = range_result.get("range_band", "")
		if range_band.is_empty() or range_band == "beyond":
			continue

		# Check if the attacker has dice at this range.
		var armament: Dictionary = attacker_inst.ship_data.battery_armament \
				.get(atk_zone_str, {})
		var dice: Dictionary = RangeFinder.dice_at_range(
				armament, range_band)
		var total: int = 0
		for c: String in dice:
			total += int(dice[c])
		if total <= 0:
			continue

		# LOS check.
		var los_result: Dictionary = \
				LineOfSightChecker.trace_los_ship_to_ship(
				atk_origin, def_pt, _get_obstruction_bodies(
				_attacker_token, target_token))
		if not los_result.get("has_los", false):
			continue

		var obstructed: bool = los_result.get("obstructed", false)

		if not found_valid or _is_closer_range(range_band, best_range):
			best_zone = zone
			best_range = range_band
			best_obstructed = obstructed
			found_valid = true

	if not found_valid:
		_log.info("No valid hull zone in range/LOS for target.")
		return

	# Draw LOS line.
	var def_zone_str: String = Constants.HullZone.keys()[int(best_zone)]
	_los_line_from = atk_origin
	_los_line_to = def_los_origins.get(def_zone_str, Vector2.ZERO)
	_los_line_visible = true
	queue_redraw()

	_attack_state.select_ship_target(
			defender_inst, best_zone, best_range, best_obstructed)
	_refresh_panel()


## Selects an enemy squadron as the target.
func _select_squadron_target(target_token: Node2D) -> void:
	var attacker_inst: ShipInstance = _attacker_token.get_ship_instance()
	if attacker_inst == null:
		return

	var squad_inst: RefCounted = _get_squadron_instance(target_token)
	if squad_inst == null:
		return

	var atk_zone: int = _attack_state.get_attacking_zone()
	var atk_zone_str: String = Constants.HullZone.keys()[atk_zone]
	var los_origins: Dictionary = _attacker_token.get_los_origins_world()
	var atk_origin: Vector2 = los_origins.get(atk_zone_str, Vector2.ZERO)
	var def_pos: Vector2 = target_token.global_position

	# Range check.
	var range_result: Dictionary = RangeFinder.measure_attack_range_squadron(
			atk_origin, def_pos)
	var range_band: String = range_result.get("range_band", "")
	if range_band.is_empty() or range_band == "beyond":
		_log.info("Squadron target out of range.")
		return

	# Anti-squadron armament check.
	var armament: Dictionary = attacker_inst.ship_data.anti_squadron_armament
	var dice: Dictionary = RangeFinder.dice_at_range(armament, range_band)
	var total: int = 0
	for c: String in dice:
		total += int(dice[c])
	if total <= 0:
		_log.info("No anti-squadron dice at range.")
		return

	# LOS check.
	var los_result: Dictionary = LineOfSightChecker.trace_los_ship_to_squadron(
			atk_origin, def_pos, _get_obstruction_bodies(
			_attacker_token, null))
	if not los_result.get("has_los", false):
		_log.info("No LOS to squadron.")
		return

	var obstructed: bool = los_result.get("obstructed", false)
	_los_line_from = atk_origin
	_los_line_to = def_pos
	_los_line_visible = true
	queue_redraw()

	_attack_state.select_squadron_target(
			squad_inst, range_band, obstructed)
	_refresh_panel()


## Selects an additional squadron target for Step 6.
func _select_additional_squad(target_token: Node2D) -> void:
	var squad_inst: RefCounted = _get_squadron_instance(target_token)
	if squad_inst == null:
		return

	var atk_zone: int = _attack_state.get_attacking_zone()
	var atk_zone_str: String = Constants.HullZone.keys()[atk_zone]
	var los_origins: Dictionary = _attacker_token.get_los_origins_world()
	var atk_origin: Vector2 = los_origins.get(atk_zone_str, Vector2.ZERO)
	var def_pos: Vector2 = target_token.global_position

	var range_result: Dictionary = RangeFinder.measure_attack_range_squadron(
			atk_origin, def_pos)
	var range_band: String = range_result.get("range_band", "")
	if range_band.is_empty() or range_band == "beyond":
		return

	var los_result: Dictionary = LineOfSightChecker.trace_los_ship_to_squadron(
			atk_origin, def_pos, _get_obstruction_bodies(
			_attacker_token, null))
	if not los_result.get("has_los", false):
		return

	var obstructed: bool = los_result.get("obstructed", false)
	if _attack_state.select_additional_squad_target(
			squad_inst, range_band, obstructed):
		_refresh_panel()


# ---------------------------------------------------------------------------
# Panel signal handlers
# ---------------------------------------------------------------------------


## CF dial: add a die.
func _on_cf_die_requested(colour: String) -> void:
	if _attack_state.add_cf_die(colour):
		_refresh_panel()


## CF dial: skip.
func _on_cf_dial_skipped() -> void:
	_attack_state.skip_cf_dial()
	_refresh_panel()


## Roll dice.
func _on_roll_requested() -> void:
	_attack_state.roll_dice()
	_refresh_panel()


## Skip all attacks.
func _on_skip_requested() -> void:
	_attack_state.skip_remaining_attacks()
	_finish_attacks()


## Finish current step (Attack Effects or Defense Tokens).
func _on_finish_step() -> void:
	var state: AttackSequenceState.State = _attack_state.get_state()
	if state == AttackSequenceState.State.ATTACK_EFFECTS:
		_attack_state.finish_attack_effects()
		_refresh_panel()
	elif state == AttackSequenceState.State.DEFENSE_TOKENS:
		_attack_state.finish_defense_and_resolve_damage()
		_refresh_panel()
	elif state == AttackSequenceState.State.ADDITIONAL_SQUAD_TARGET:
		_attack_state.skip_additional_squad_target()
		_handle_after_attack()


## Defense token selected.
func _on_defense_token_selected(token_index: int) -> void:
	# For now, use defaults for extra_data.
	# Future: prompt for redirect zone, evade die index.
	_attack_state.spend_defense_token(token_index)
	_refresh_panel()


## Damage acknowledged.
func _on_damage_acknowledged() -> void:
	_attack_state.advance_after_damage()
	_handle_after_attack()


## Additional target requested.
func _on_additional_target_requested() -> void:
	# Panel switches to showing "select target" — handled by clicks.
	_refresh_panel()


## Next attack.
func _on_next_attack() -> void:
	_attack_state.advance_after_attack()
	_los_line_visible = false
	queue_redraw()
	_refresh_panel()


## All attacks done.
func _on_all_attacks_done() -> void:
	_attack_state.skip_remaining_attacks()
	_finish_attacks()


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


## Handles flow after damage or skip of additional squad target.
func _handle_after_attack() -> void:
	var state: AttackSequenceState.State = _attack_state.get_state()
	if state == AttackSequenceState.State.ADDITIONAL_SQUAD_TARGET:
		_refresh_panel()
	elif state == AttackSequenceState.State.ATTACK_COMPLETE:
		_los_line_visible = false
		queue_redraw()
		_refresh_panel()
	elif state == AttackSequenceState.State.ALL_ATTACKS_DONE:
		_finish_attacks()
	else:
		_refresh_panel()


## Finishes attack mode.
func _finish_attacks() -> void:
	_los_line_visible = false
	queue_redraw()
	EventBus.all_attacks_completed.emit()
	attacks_finished.emit()
	_log.info("Attack mode finished.")


## Refreshes the info panel display.
func _refresh_panel() -> void:
	if _info_panel:
		_info_panel.update_display()
		_centre_panel()


## Centres the info panel on the viewport.
func _centre_panel() -> void:
	if _info_panel == null:
		return
	if not is_inside_tree():
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_info_panel.centre_on_screen(vp_size)


## Checks if a ship token belongs to an enemy.
func _is_enemy_ship(token: ShipToken) -> bool:
	return token in _enemy_ship_tokens


## Checks if a squadron token belongs to an enemy.
func _is_enemy_squadron(token: Node2D) -> bool:
	return token in _enemy_squad_tokens


## Gets the SquadronInstance from a squadron token.
func _get_squadron_instance(token: Node2D) -> RefCounted:
	if token.has_method("get_squadron_instance"):
		return token.get_squadron_instance()
	return null


## Returns obstruction bodies excluding attacker and optionally the target.
func _get_obstruction_bodies(
		attacker: ShipToken, target: ShipToken) -> Array:
	var bodies: Array = []
	for body: Dictionary in _all_ship_bodies:
		var token: ShipToken = body.get("token", null)
		if token == attacker:
			continue
		if target != null and token == target:
			continue
		bodies.append(body.get("body"))
	return bodies


## Returns true if range_a is closer than range_b.
func _is_closer_range(range_a: String, range_b: String) -> bool:
	var order: Dictionary = {"close": 0, "medium": 1, "long": 2}
	return order.get(range_a, 3) < order.get(range_b, 3)


## Draws LOS line overlay.
func _draw() -> void:
	if _los_line_visible:
		draw_line(_los_line_from, _los_line_to,
				Color(1.0, 0.9, 0.2, 0.8), 2.0)
