## ActivateShipCommand
##
## Activates a ship during the Ship Phase by revealing its top command dial.
## Wraps [method GameManager.activate_ship] as a serializable command.
##
## Payload:
##   "ship_index" — index of the ship in the player's fleet array.
##   "skip_reveal" — optional, true when a rule discarded the dial first.
##   "reason" — optional rule/effect id explaining skip_reveal.
##
## Rules Reference: "Ship Phase", SP-010 — reveal top facedown dial.
class_name ActivateShipCommand
extends GameCommand


const FLOW_SPEC_SCRIPT: GDScript = preload("res://src/core/state/flow_spec.gd")
const PAYLOAD_SKIP_REVEAL: String = "skip_reveal"
const PAYLOAD_REASON: String = "reason"


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("activate_ship", func(player: int,
			pl: Dictionary) -> GameCommand:
		return ActivateShipCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "activate_ship", p_payload)


## Validates that ship activation is legal.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if game_state.current_phase != Constants.GamePhase.SHIP:
		return "Not in Ship Phase."
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	if ship == null:
		return "Ship not found."
	if ship.activated_this_round:
		return "Ship already activated this round."
	if _skip_reveal_requested():
		return ""
	if ship.command_dial_stack == null:
		return "Ship has no dial stack."
	if ship.command_dial_stack.get_hidden_count() == 0 \
			and ship.command_dial_stack.get_revealed_dial().is_empty():
		return "Ship has no dials to reveal."
	return ""


## Reveals the top dial and marks the ship as activating.
## If a dial is already revealed (two-click flow), uses that dial.
## Returns {"command": int} where command is the revealed dial's type,
## or {"command": -1} if reveal failed.
func execute(game_state: GameState) -> Dictionary:
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	if _skip_reveal_requested():
		_open_activation_flow(game_state)
		return {"command": -1,
				"ship_index": payload.get("ship_index", -1),
				"activation_without_command": true,
				"reason": str(payload.get(PAYLOAD_REASON, ""))}
	# Use already-revealed dial if present (two-click activation flow).
	var dial: Dictionary = ship.command_dial_stack.get_revealed_dial()
	if dial.is_empty():
		dial = ship.command_dial_stack.reveal_top()
	if dial.is_empty():
		return {"command": - 1}
	_open_activation_flow(game_state)
	return {"command": int(dial.get("command", -1)),
			"ship_index": payload.get("ship_index", -1)}


func _skip_reveal_requested() -> bool:
	return bool(payload.get(PAYLOAD_SKIP_REVEAL, false))


func _open_activation_flow(game_state: GameState) -> void:
	game_state.interaction_flow = FLOW_SPEC_SCRIPT.make_interaction_flow(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.ACTIVATION_MODAL_OPEN,
			game_state,
			{"active_player": player_index},
			Constants.Visibility.ALL,
			{"ship_index": payload.get("ship_index", -1)})
