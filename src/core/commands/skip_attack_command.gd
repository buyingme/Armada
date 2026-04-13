## SkipAttackCommand
##
## Records that the active player chose to skip (pass on) an attack
## or an attack sub-step during the Ship Phase.
## This is a flow-control command — it performs no state mutation but
## is recorded so replays faithfully reproduce the player's choices.
##
## Payload:
##   "reason" — optional human-readable reason for the skip
##              (e.g. "no_targets", "voluntary", "squadron_done").
##
## Rules Reference: "Attack", p.2 —
## "A ship can perform up to two attacks during its activation."
class_name SkipAttackCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("skip_attack", func(player: int,
			pl: Dictionary) -> GameCommand:
		return SkipAttackCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "skip_attack", p_payload)


## Validates that skipping is legal.
## Allowed in both Ship and Squadron phases (squadrons may skip attacks).
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	var phase: Constants.GamePhase = game_state.current_phase
	if phase != Constants.GamePhase.SHIP and phase != Constants.GamePhase.SQUADRON:
		return "Not in Ship or Squadron Phase."
	return ""


## No-op execution — returns the skip reason for logging/replay.
func execute(_game_state: GameState) -> Dictionary:
	return {
		"skipped": true,
		"reason": payload.get("reason", "voluntary"),
	}
