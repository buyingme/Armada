## UIProjector
##
## Pure projector from filtered [GameState] to a [UIIntent] describing
## what the local viewer's UI should show.
##
## Despite living under [code]src/core/network/[/code], this module has no
## network code; it is co-located with [code]state_filter.gd[/code] for
## cohesion.  It is called once per applied state mutation (every
## [signal CommandProcessor.command_executed], every snapshot apply,
## every reconnect) and produces a deterministic [UIIntent] that the
## presentation layer renders without any further branching on
## [code]PlayMode.is_network()[/code].
##
## **Phase I4 (this commit)** — pilot scope: HUD status text only.
## Subsequent I5/I6 sub-steps will extend [UIIntent] with sidebar text,
## modal kind, modal interactivity, and attack-panel projection so that
## all eight [code]is_network()[/code] branches in the presentation
## layer can be removed.
##
## Plan: [code]docs/refactoring_phase_i_plan.md[/code] §I4.
class_name UIProjector
extends RefCounted


const FLOW_SPEC_SCRIPT: GDScript = preload("res://src/core/state/flow_spec.gd")


## Result of projecting a [GameState] for a single local viewer.
class UIIntent extends RefCounted:
	## Score-header helper string.  Empty when the HUD should not append
	## a status segment.  Examples:
	##   "make your choices"
	##   "waiting for opponent's choice"
	var hud_status_text: String = ""

	## True when the local viewer is the controller of the current
	## interaction flow and may interact with whichever modal is open.
	var is_interactive: bool = false

	## Convenience: numeric controller player from the projected
	## interaction flow (-1 when there is no flow).
	var controller_player: int = -1

	## Display label for [member controller_player], derived from GameState.
	var controller_player_label: String = ""

	## Faction enum value for [member controller_player], or -1 when unknown.
	var controller_player_faction: int = -1

	## Active flow type (mirrors [member InteractionFlow.flow_type]).
	## Phase I6b — exposed so consumers can switch on flow without
	## reaching back into [GameState].
	var flow_type: Constants.InteractionFlow = Constants.InteractionFlow.NONE

	## Active step within the flow (mirrors [member InteractionFlow.step_id]).
	## Phase I6b.
	var step_id: Constants.InteractionStep = Constants.InteractionStep.NONE

	## Which modal the presentation layer should currently display
	## (or [code]NONE[/code] when no modal applies).  Computed from
	## [member flow_type] + [member step_id].  Phase I6b.
	var modal_kind: Constants.ModalKind = Constants.ModalKind.NONE

	## Deep-copied snapshot of [member InteractionFlow.payload] for the
	## current step (e.g. dice pool, locked tokens, modified damage during
	## an attack).  Empty dictionary when there is no flow.  Phase I6b.
	var payload: Dictionary = {}

	## Optional projected UI affordances that are not themselves game-state
	## mutations, such as a local button that re-opens a common modal.
	## Values are booleans or JSON-safe payloads keyed by stable snake_case names.
	var affordances: Dictionary = {}

	## Which player's board/card perspective this viewer should see.
	## For shared-screen handoff this follows the active player; for network
	## peers it stays pinned to the local seat.
	var perspective_player: int = -1

	## Display label for [member perspective_player], derived from GameState.
	var perspective_player_label: String = ""

	## Faction enum value for [member perspective_player], or -1 when unknown.
	var perspective_player_faction: int = -1

	## True when the shared-screen transition should show the full handoff gate.
	var needs_handoff_overlay: bool = false

	## True when the transition should show the brief active-player banner.
	var needs_turn_banner: bool = false

	## True when the viewer is passive and should see the waiting status.
	var needs_waiting_overlay: bool = false

	## True when the command-dial flow should begin immediately.
	var should_begin_command_dial_flow: bool = false

	## True when a passive peer should observe the Squadron Phase modal state.
	var should_begin_passive_squadron_observer: bool = false


## Computes a [UIIntent] for [param viewer_player] from [param state].
##
## [param viewer_player] — the local player's index (0 or 1 in 2-player
## games).  Use [code]NetworkManager.get_local_player_index()[/code] in
## live code; tests pass an explicit value.
##
## In hot-seat mode the caller should pass the active player as
## [param viewer_player].  The projector then mirrors the active player's
## controller-side experience without further branching.
static func project(state: GameState, viewer_player: int) -> UIIntent:
	var intent: UIIntent = UIIntent.new()
	if state == null:
		return intent
	var flow: InteractionFlow = state.interaction_flow
	if flow == null or flow.flow_type == Constants.InteractionFlow.NONE:
		return intent
	var spec: Dictionary = FLOW_SPEC_SCRIPT.get_spec(
			int(flow.flow_type), int(flow.step_id))
	intent.controller_player = flow.controller_player
	intent.controller_player_label = player_display_label(
			state, flow.controller_player)
	intent.controller_player_faction = player_faction(state, flow.controller_player)
	intent.is_interactive = _is_interactive_for(flow, spec, viewer_player)
	intent.hud_status_text = _hud_status_for(flow, spec, viewer_player)
	intent.flow_type = flow.flow_type
	intent.step_id = flow.step_id
	intent.modal_kind = _modal_kind_for(spec)
	intent.payload = flow.payload.duplicate(true) if flow.payload != null \
			else {}
	intent.affordances = _affordances_for(state, flow, viewer_player)
	return intent


## Projects an active-player transition without branching in the scene layer.
## This is intentionally outside [FlowSpec]: it represents between-flow handoff
## surfaces, not a persisted [InteractionFlow] row.
## [param shared_screen] is [code]true[/code] for one local display shared by
## both players and [code]false[/code] for a peer pinned to its local seat.
static func project_turn_transition(
		phase: Constants.GamePhase,
		active_player: int,
		viewer_player: int,
		shared_screen: bool,
		state: GameState = null) -> UIIntent:
	var intent: UIIntent = UIIntent.new()
	intent.controller_player = active_player
	intent.controller_player_label = player_display_label(state, active_player)
	intent.controller_player_faction = player_faction(state, active_player)
	intent.perspective_player = active_player if shared_screen else viewer_player
	intent.perspective_player_label = player_display_label(
			state, intent.perspective_player)
	intent.perspective_player_faction = player_faction(
			state, intent.perspective_player)
	intent.is_interactive = shared_screen or active_player == viewer_player \
			or phase == Constants.GamePhase.COMMAND
	intent.hud_status_text = _turn_status_text(
			phase, active_player, viewer_player, shared_screen)
	intent.needs_handoff_overlay = shared_screen \
			and phase == Constants.GamePhase.COMMAND
	intent.needs_turn_banner = _needs_turn_banner(
			phase, active_player, viewer_player, shared_screen)
	intent.needs_waiting_overlay = not shared_screen \
			and active_player != viewer_player
	intent.should_begin_command_dial_flow = not shared_screen \
			and phase == Constants.GamePhase.COMMAND
	intent.should_begin_passive_squadron_observer = not shared_screen \
			and phase == Constants.GamePhase.SQUADRON \
			and active_player != viewer_player
	return intent


## Returns the player-facing label for [param player_index] from state.
## Falls back to a neutral player index label when the state has no entry.
static func player_display_label(state: GameState, player_index: int) -> String:
	var player_state: PlayerState = _player_state_or_null(state, player_index)
	if player_state == null:
		return _fallback_player_label(player_index)
	return "%s Player" % _faction_display_name(player_state.faction)


## Returns the player's faction label from state, or a neutral fallback.
static func player_faction_label(state: GameState, player_index: int) -> String:
	var player_state: PlayerState = _player_state_or_null(state, player_index)
	if player_state == null:
		return _fallback_player_label(player_index)
	return _faction_display_name(player_state.faction)


## Returns the faction enum value for [param player_index], or -1 if unknown.
static func player_faction(state: GameState, player_index: int) -> int:
	var player_state: PlayerState = _player_state_or_null(state, player_index)
	if player_state == null:
		return -1
	return int(player_state.faction)


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## Returns the score-header status string for the given flow + viewer.
##
## Phase I4 keeps the wording identical to the legacy
## [code]StatusTextPolicy[/code] / fallback path so the UI is byte-for-byte
## indistinguishable from before.
static func _hud_status_for(flow: InteractionFlow,
		spec: Dictionary,
		viewer_player: int) -> String:
	if _is_either_player_surface(flow, spec):
		return "make your choices"
	if flow.controller_player == viewer_player:
		return "make your choices"
	if flow.controller_player == -1:
		return ""
	return "waiting for opponent's choice"


static func _is_interactive_for(
		flow: InteractionFlow,
		spec: Dictionary,
		viewer_player: int) -> bool:
	if _is_either_player_surface(flow, spec):
		return true
	if _is_system_or_empty_surface(spec):
		return false
	return flow.controller_player == viewer_player


static func _turn_status_text(
		phase: Constants.GamePhase,
		active_player: int,
		viewer_player: int,
		shared_screen: bool) -> String:
	if shared_screen:
		return ""
	if phase == Constants.GamePhase.COMMAND or active_player == viewer_player:
		return "make your choices"
	return "waiting for opponent's choice"


static func _needs_turn_banner(
		phase: Constants.GamePhase,
		active_player: int,
		viewer_player: int,
		shared_screen: bool) -> bool:
	if phase != Constants.GamePhase.SHIP \
			and phase != Constants.GamePhase.SQUADRON:
		return false
	return shared_screen or active_player == viewer_player


static func _player_state_or_null(
		state: GameState,
		player_index: int) -> PlayerState:
	if state == null:
		return null
	if player_index < 0 or player_index >= state.player_states.size():
		return null
	var player_state: Variant = state.player_states[player_index]
	if player_state is PlayerState:
		return player_state as PlayerState
	return null


static func _faction_display_name(faction: Constants.Faction) -> String:
	match faction:
		Constants.Faction.REBEL_ALLIANCE:
			return "Rebel Alliance"
		Constants.Faction.GALACTIC_EMPIRE:
			return "Galactic Empire"
		Constants.Faction.GALACTIC_REPUBLIC:
			return "Galactic Republic"
		Constants.Faction.SEPARATIST_ALLIANCE:
			return "Separatist Alliance"
		_:
			return "Unknown Faction"


static func _fallback_player_label(player_index: int) -> String:
	if player_index < 0:
		return "Player"
	return "Player %d" % player_index


## Maps FlowSpec modal metadata to the primary modal the presentation layer
## should display. Empty or invalid pairs project no modal.
static func _modal_kind_for(spec: Dictionary) -> Constants.ModalKind:
	var modals: Array = spec.get("modals", [])
	if modals.is_empty():
		return Constants.ModalKind.NONE
	return int(modals[0]) as Constants.ModalKind


static func _is_either_player_surface(
		flow: InteractionFlow,
		spec: Dictionary) -> bool:
	if _controller_role_for(spec) == Constants.ControllerRole.EITHER_PLAYER:
		return true
	return spec.is_empty() \
			and flow.flow_type == Constants.InteractionFlow.COMMAND_PHASE


static func _is_system_or_empty_surface(spec: Dictionary) -> bool:
	if spec.is_empty():
		return false
	match _controller_role_for(spec):
		Constants.ControllerRole.NONE, Constants.ControllerRole.SYSTEM:
			return true
		_:
			return false


static func _controller_role_for(spec: Dictionary) -> Constants.ControllerRole:
	return (int(spec.get("controller_role", Constants.ControllerRole.NONE))
			as Constants.ControllerRole)


## Computes non-mutating UI affordances from the current authoritative flow.
static func _affordances_for(state: GameState,
		flow: InteractionFlow,
		viewer_player: int) -> Dictionary:
	var affordances: Dictionary = _rule_affordances_for(
			state, flow, viewer_player)
	if flow.flow_type != Constants.InteractionFlow.SHIP_ACTIVATION:
		return affordances
	if flow.step_id == Constants.InteractionStep.NONE \
			or flow.step_id == Constants.InteractionStep.WAIT_FOR_SHIP_SELECT:
		return affordances
	affordances["activation_sequence_button"] = true
	return affordances


static func _rule_affordances_for(state: GameState,
		flow: InteractionFlow,
		viewer_player: int) -> Dictionary:
	var affordances: Dictionary = {}
	for hook: FlowHook in RuleRegistry.enablers_for_step(
			int(flow.flow_type), int(flow.step_id)):
		if not hook.callback.is_valid():
			continue
		var raw_payload: Variant = hook.callback.call(
				state, flow, viewer_player)
		if raw_payload is Dictionary:
			_merge_affordance_payload(affordances, raw_payload as Dictionary)
	return affordances


static func _merge_affordance_payload(
		affordances: Dictionary,
		payload: Dictionary) -> void:
	for key_var: Variant in payload.keys():
		var key: String = str(key_var)
		affordances[key] = payload[key_var]
