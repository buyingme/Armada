## Read-only mirror of the [AttackSimPanel] shown on the non-attacker
## peer in network play.
##
## Phase I6b-3 R1b: opens the same `AttackSimPanel` UI on the passive
## peer, populated entirely from `interaction_flow.payload`.  Input
## signals are intentionally [b]not[/b] connected — the mirror is
## strictly informational at this slice.  Subsequent slices (R2–R5)
## will turn defender-driven sub-steps interactive on the defender peer
## via dedicated commands.
##
## Lifecycle:
##  * [method setup] is called once by [UIPanelManager] with a
##    dedicated [CanvasLayer]; the panel is created hidden.
##  * [method apply_flow] is called from
##    [GameBoard._on_command_executed_project_ui] for every
##    `command_executed` while the local peer is the non-attacker.  It
##    opens the panel on first call and updates the prompt.
##  * [method close] hides the panel when the attack flow ends.
##
## Hot-seat invariant: this class is only ever instantiated and called
## while [code]PlayMode.is_network()[/code] is true (gated in
## [GameBoard]).  The mirror has no effect on the attacker peer.
class_name AttackPanelMirror
extends RefCounted


## The owned [AttackSimPanel] instance.  Created in [method setup].
var _panel: AttackSimPanel = null

## True once [method apply_flow] has been called for the current attack
## flow and the panel has been opened.  Reset by [method close].
var _is_open: bool = false

## Cached display string of the last applied modal_kind so we only call
## the (relatively expensive) `_set_prompt` flavour when it actually
## changes.
var _last_modal_kind: int = -1

## Last published `defender_name` from `interaction_flow.payload`.
## Tracks transitions from "have target" to "no target" (between
## consecutive attacks under the 2-hull-zone rule or in the Step 6
## squadron loop) so the mirror reverts to the initial-attack prompt
## without rebuilding the panel on every snapshot.
var _last_defender_name: String = ""

## Logger.
var _log: GameLogger = GameLogger.new("AttackPanelMirror")


## Maps [enum Constants.HullZone] to display strings.  Mirrors the
## table inside [DefenseMirrorPanel].
const _ZONE_NAMES: Dictionary = {
	Constants.HullZone.FRONT: "FRONT",
	Constants.HullZone.LEFT: "LEFT",
	Constants.HullZone.RIGHT: "RIGHT",
	Constants.HullZone.REAR: "REAR",
}


## Creates the [AttackSimPanel] instance and adds it as a child of
## [param layer].  Must be called once before [method apply_flow].
func setup(layer: CanvasLayer) -> void:
	if _panel != null:
		return
	_panel = AttackSimPanel.new()
	_panel.name = "AttackPanelMirror"
	layer.add_child(_panel)
	_panel.visible = false


## Returns the underlying panel — for tests only.  Production code
## should not connect signals on this panel.
func get_panel() -> AttackSimPanel:
	return _panel


## Returns true if the mirror panel is currently open.
func is_open() -> bool:
	return _is_open and _panel != null and _panel.visible


## Opens (if needed) and refreshes the mirror panel from the published
## attack-flow payload.
##
## [param payload] — the dictionary stored on
## [member InteractionFlow.payload], populated by
## [AttackExecutor._compute_attack_identity_patch] and the per-step
## patches.
## [param modal_kind] — current [enum Constants.ModalKind] value;
## reserved for sub-step-specific population in later slices (R2+).
func apply_flow(payload: Dictionary, modal_kind: int) -> void:
	if _panel == null:
		return
	# First call for this attack flow — open the panel with the
	# appropriate "initial" prompt based on attacker kind.
	var attacker_kind: String = String(
			payload.get("attacker_kind", "ship"))
	var attacker_name: String = String(
			payload.get("attacker_name", ""))
	if not _is_open:
		if attacker_kind == "squadron":
			_panel.show_initial_squadron_exec(attacker_name)
		else:
			_panel.show_initial_attack_exec(attacker_name)
		_is_open = true
		_last_modal_kind = -1
	# Refresh the target line whenever a defender is published.  Cheap
	# enough to call on every command_executed; AttackSimPanel just
	# updates two Labels.
	var def_name: String = String(payload.get("defender_name", ""))
	if def_name != "":
		var atk_name: String = String(payload.get("attacker_name", ""))
		var atk_zone: int = int(payload.get("attacker_zone", -1))
		var atk_zone_name: String = String(
				payload.get("attacker_zone_name", _zone_label(atk_zone)))
		var def_zone: int = int(payload.get("defender_zone", -1))
		var def_zone_name: String = _zone_label(def_zone)
		var range_band: String = String(payload.get("range_band", ""))
		_panel.show_target_selected(
				atk_name, atk_zone_name, def_name, def_zone_name,
				"", range_band)
	else:
		# Phase I6b-3 R1b follow-up: between consecutive attacks the
		# host clears the defender identity (see
		# [method AttackExecutor._publish_clear_target_patch]).  Mirror
		# the host's "Select target" prompt so the title drops the
		# previous target.  Only rebuild on the transition edge —
		# otherwise every command_executed would rebuild the panel.
		if _last_defender_name != "":
			if attacker_kind == "squadron":
				_panel.show_initial_squadron_exec(attacker_name)
			else:
				_panel.show_initial_attack_exec(attacker_name)
	_last_defender_name = def_name
	_last_modal_kind = modal_kind


## Hides the mirror panel.  Idempotent.
func close() -> void:
	if _panel == null:
		return
	if _panel.visible:
		_panel.close()
	_is_open = false
	_last_modal_kind = -1
	_last_defender_name = ""


## Returns a display string for the given [enum Constants.HullZone]
## value, or empty string for non-ship targets / unknown zones.
func _zone_label(zone: int) -> String:
	if zone < 0:
		return ""
	return String(_ZONE_NAMES.get(zone, ""))
