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
	## Values are booleans keyed by stable snake_case names.
	var affordances: Dictionary = {}

	## Which player's board/card perspective this viewer should see.
	## For shared-screen handoff this follows the active player; for network
	## peers it stays pinned to the local seat.
	var perspective_player: int = -1

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
	intent.controller_player = flow.controller_player
	intent.is_interactive = (flow.controller_player == viewer_player)
	intent.hud_status_text = _hud_status_for(flow, viewer_player)
	intent.flow_type = flow.flow_type
	intent.step_id = flow.step_id
	intent.modal_kind = _modal_kind_for(flow)
	intent.payload = flow.payload.duplicate(true) if flow.payload != null \
			else {}
	intent.affordances = _affordances_for(flow)
	return intent


## Projects an active-player transition without branching in the scene layer.
## [param shared_screen] is [code]true[/code] for one local display shared by
## both players and [code]false[/code] for a peer pinned to its local seat.
static func project_turn_transition(
		phase: Constants.GamePhase,
		active_player: int,
		viewer_player: int,
		shared_screen: bool) -> UIIntent:
	var intent: UIIntent = UIIntent.new()
	intent.controller_player = active_player
	intent.perspective_player = active_player if shared_screen else viewer_player
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


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## Returns the score-header status string for the given flow + viewer.
##
## Phase I4 keeps the wording identical to the legacy
## [code]StatusTextPolicy[/code] / fallback path so the UI is byte-for-byte
## indistinguishable from before.
static func _hud_status_for(flow: InteractionFlow,
		viewer_player: int) -> String:
	# Command-phase: both players choose dials simultaneously.  Both see
	# the same prompt regardless of "controller" identity.
	if flow.flow_type == Constants.InteractionFlow.COMMAND_PHASE:
		return "make your choices"
	# All other flows: controller acts, opponent waits.
	if flow.controller_player == viewer_player:
		return "make your choices"
	if flow.controller_player == -1:
		return ""
	return "waiting for opponent's choice"


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


## Maps [member InteractionFlow.flow_type]+[member InteractionFlow.step_id]
## to the [enum Constants.ModalKind] the presentation layer should display.
##
## Phase I6b — added so attack-step UI consumers can switch on a single
## enum instead of reading the legacy step-id strings.  All ship-activation
## sub-steps map to [code]ACTIVATION[/code] because the activation modal
## remains the dominant UI throughout the activation; the WAIT_FOR_*_SELECT
## steps return [code]NONE[/code] because no modal is open while a target
## is being chosen.
static func _modal_kind_for(flow: InteractionFlow) -> Constants.ModalKind:
	match flow.flow_type:
		Constants.InteractionFlow.NONE:
			return Constants.ModalKind.NONE
		Constants.InteractionFlow.COMMAND_PHASE:
			return Constants.ModalKind.COMMAND_DIALS
		Constants.InteractionFlow.SHIP_ACTIVATION:
			if flow.step_id == Constants.InteractionStep.WAIT_FOR_SHIP_SELECT:
				return Constants.ModalKind.NONE
			if flow.step_id == Constants.InteractionStep.SQUADRON_STEP:
				return Constants.ModalKind.SQUADRON
			return Constants.ModalKind.ACTIVATION
		Constants.InteractionFlow.SQUADRON_ACTIVATION:
			if flow.step_id == Constants.InteractionStep.WAIT_FOR_SQUAD_SELECT:
				return Constants.ModalKind.NONE
			return Constants.ModalKind.SQUADRON
		Constants.InteractionFlow.ATTACK:
			return _attack_modal_kind_for_step(flow.step_id)
		Constants.InteractionFlow.SQUADRON_DISPLACEMENT:
			return Constants.ModalKind.DISPLACEMENT
		Constants.InteractionFlow.STATUS_CLEANUP:
			return Constants.ModalKind.STATUS_CLEANUP
		Constants.InteractionFlow.GAME_OVER:
			return Constants.ModalKind.GAME_OVER
	return Constants.ModalKind.NONE


## Sub-helper for the attack flow — keeps [method _modal_kind_for] under
## the 30-line ceiling.  Phase I6b.
static func _attack_modal_kind_for_step(
		step_id: Constants.InteractionStep) -> Constants.ModalKind:
	match step_id:
		Constants.InteractionStep.ATTACK_DECLARE:
			return Constants.ModalKind.ATTACK_DECLARE
		Constants.InteractionStep.ATTACK_ROLL:
			return Constants.ModalKind.ATTACK_ROLL
		Constants.InteractionStep.ATTACK_MODIFY:
			return Constants.ModalKind.ATTACK_MODIFY
		Constants.InteractionStep.ATTACK_DEFENSE_TOKENS:
			return Constants.ModalKind.ATTACK_DEFENSE_TOKENS
		Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE:
			return Constants.ModalKind.ATTACK_RESOLVE_DAMAGE
		Constants.InteractionStep.ATTACK_CRITICAL_CHOICE:
			return Constants.ModalKind.ATTACK_CRITICAL_CHOICE
	return Constants.ModalKind.NONE


## Computes non-mutating UI affordances from the current authoritative flow.
static func _affordances_for(flow: InteractionFlow) -> Dictionary:
	var affordances: Dictionary = {}
	if flow.flow_type != Constants.InteractionFlow.SHIP_ACTIVATION:
		return affordances
	if flow.step_id == Constants.InteractionStep.NONE \
			or flow.step_id == Constants.InteractionStep.WAIT_FOR_SHIP_SELECT:
		return affordances
	affordances["activation_sequence_button"] = true
	return affordances
