## RedirectDoneCommand
##
## Marker command submitted by the [b]defender peer[/b] in network mode
## when the player presses the [i]Done Redirecting[/i] button during the
## Redirect defense-token sub-step on the [AttackPanelMirror].  Ends
## the redirect sub-step early (before the redirect budget is fully
## allocated) so the rest of the defense-commit queue and damage
## resolution can proceed.
##
## Phase I6b-3 R4: closes the redirect-zone authority gap together
## with [SelectRedirectZoneCommand].  The attacker peer's
## [AttackExecutor] reacts to this command via
## [signal CommandProcessor.command_executed] and runs
## [code]apply_defender_redirect_done()[/code].
##
## Payload:
##   "ship_index" — index of the defending ship in the player's fleet.
##
## Hot-seat: this command is also submitted in hot-seat for replay
## determinism and to keep a single code path between modes.
##
## Rules Reference: "Redirect", DT-013, RRG v1.5.0, p.11.
class_name RedirectDoneCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("redirect_done", func(player: int,
			pl: Dictionary) -> GameCommand:
		return RedirectDoneCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "redirect_done", p_payload)


## Validates that the defender ship exists.  Allowed in both Ship and
## Squadron phases (only ships have hull zones, but the parent attack
## flow can run in either phase via squadron-vs-ship attacks).
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	var phase: Constants.GamePhase = game_state.current_phase
	if phase != Constants.GamePhase.SHIP \
			and phase != Constants.GamePhase.SQUADRON:
		return "Not in Ship or Squadron Phase."
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	if ship == null:
		return "Defender ship not found."
	return ""


## Marker — no game-state mutation here.  The attacker peer's
## [AttackExecutor] reacts via [signal CommandProcessor.command_executed]
## and clears the redirect step + processes the next defense commit.
func execute(_game_state: GameState) -> Dictionary:
	return {
		"ship_index": int(payload.get("ship_index", -1)),
	}
