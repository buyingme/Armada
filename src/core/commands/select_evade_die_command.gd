## SelectEvadeDieCommand
##
## Marker command submitted by the [b]defender peer[/b] in network mode
## when the player picks a die during the Evade defense-token sub-step
## on the [AttackPanelMirror].  It carries the die index targeted by
## the evade effect.
##
## Phase I6b-3 R3: closes the evade-target authority gap.  The attacker
## peer's [AttackExecutor] reacts to this command via
## [signal CommandProcessor.command_executed] and runs the existing
## remove-die / reroll-die pipeline (depending on range band).
##
## Payload:
##   "ship_index" — index of the defending ship in the player's fleet.
##   "die_index"  — index into [code]_state.dice_results[/code] of the
##                  die the defender targeted with the evade effect.
##
## Hot-seat: this command is also submitted in hot-seat for replay
## determinism and to keep a single code path between modes.
##
## Rules Reference: "Evade", DT-001/DT-003, RRG v1.5.0, p.5.
class_name SelectEvadeDieCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("select_evade_die", func(player: int,
			pl: Dictionary) -> GameCommand:
		return SelectEvadeDieCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "select_evade_die", p_payload)


## Validates that the defender ship exists and the die index is
## non-negative.  Whether the index is in range of the current attack's
## dice pool is validated by [AttackExecutor] (which holds the
## authoritative dice-results buffer) before applying the effect.
## Allowed in both Ship and Squadron phases (evade applies to both).
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
	var die_index: int = int(payload.get("die_index", -1))
	if die_index < 0:
		return "Invalid die index %d." % die_index
	return ""


## Marker — no game-state mutation here.  The die index is echoed in
## the result so the attacker peer's [AttackExecutor] can drive the
## evade pipeline from the [signal CommandProcessor.command_executed]
## signal.
func execute(_game_state: GameState) -> Dictionary:
	return {
		"ship_index": int(payload.get("ship_index", -1)),
		"die_index": int(payload.get("die_index", -1)),
	}
