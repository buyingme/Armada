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
	return intent


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## Returns the score-header status string for the given flow + viewer.
##
## Phase I4 keeps the wording identical to the legacy
## [code]StatusTextPolicy[/code] / fallback path so the UI is byte-for-byte
## indistinguishable from before.  I5 will introduce richer per-step
## strings as the projection takes over from
## [code]NetworkInteractionState[/code].
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
