## ConvertDialToTokenCommand
##
## Activates a ship by revealing and immediately spending its top dial,
## then converting it to a matching command token.
## Wraps [method GameManager.activate_ship_as_token].
##
## Payload:
##   "ship_index" — index of the ship in the player's fleet array.
##
## Rules Reference: "Command Dials", p.3 — "spend the command dial to gain
## a command token of the same type." SP-011b.
## Rules Reference: "Command Tokens", p.4 — overflow / duplicate discard.
class_name ConvertDialToTokenCommand
extends GameCommand


const FLOW_SPEC_SCRIPT: GDScript = preload("res://src/core/state/flow_spec.gd")


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("convert_dial_to_token", func(
			player: int, pl: Dictionary) -> GameCommand:
		return ConvertDialToTokenCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "convert_dial_to_token", p_payload)


## Validates that the conversion is legal.
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
	if ship.is_destroyed():
		return "Ship is destroyed."
	if ship.activated_this_round:
		return "Ship already activated this round."
	if not game_state.validate_declaration_adjacent_state():
		return "Declaration-adjacent state is invalid."
	for player_state: PlayerState in game_state.player_states:
		if player_state == null:
			continue
		for raw_ship: Variant in player_state.ships:
			if raw_ship is ShipInstance \
					and (raw_ship as ShipInstance).has_active_ship_activation():
				return "Another ship activation is active."
	if game_state.get_active_squadron_activation() != null:
		return "A squadron activation is active."
	if ship.command_dial_stack == null:
		return "Ship has no dial stack."
	if ship.command_dial_stack.get_hidden_count() == 0 \
			and ship.command_dial_stack.get_revealed_dial().is_empty():
		return "Ship has no dials to reveal or spend."
	if ship.command_tokens == null:
		return "Ship has no command token manager."
	return ""


## Reveals the top dial, spends it, adds the matching token.
## Checks RuleRegistry command-token gain blockers.
## Returns {"command": int, "token_added": bool, "duplicate": bool,
##          "overflow": bool, "token_blocked": bool}.
func execute(game_state: GameState) -> Dictionary:
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	if sequence < 0 or ship == null:
		return {}
	var boundary_before: Dictionary = ship.ship_activation_boundary_snapshot()
	var identity: String = "ship-activation:%d" % sequence
	if not ship.establish_ship_activation(identity) \
			or not game_state.validate_declaration_adjacent_state():
		ship.restore_ship_activation_boundary(boundary_before)
		return {}
	# Reveal if not already revealed.
	var dial: Dictionary = \
			ship.command_dial_stack.get_revealed_dial()
	if dial.is_empty():
		dial = ship.command_dial_stack.reveal_top()
	if dial.is_empty():
		ship.restore_ship_activation_boundary(boundary_before)
		return {"command": - 1, "token_added": false,
				"token_blocked": false}
	var cmd_type: int = int(dial.get("command", 0))
	# Spend the dial.
	ship.command_dial_stack.spend_revealed()
	# Rules Reference: "Life Support Failure" card text.
	if _is_token_gain_blocked(game_state, ship):
		_open_activation_flow(game_state)
		return {"command": cmd_type, "token_added": false,
				"duplicate": false, "overflow": false,
				"token_blocked": true,
				"ship_index": payload.get("ship_index", -1),
				"ship_activation_identity": identity}
	# Add the token.
	var add_result: Dictionary = \
			ship.command_tokens.force_add_token(cmd_type)
	var duplicate: bool = add_result.get("duplicate", false)
	var overflow: bool = add_result.get("overflow", false)
	# Auto-discard duplicate.
	if duplicate:
		ship.command_tokens.remove_token(cmd_type)
	_open_activation_flow(game_state)
	return {
		"command": cmd_type,
		"token_added": true,
		"duplicate": duplicate,
		"overflow": overflow,
		"token_blocked": false,
		"ship_index": payload.get("ship_index", -1),
		"ship_activation_identity": identity,
	}


func _open_activation_flow(game_state: GameState) -> void:
	game_state.interaction_flow = FLOW_SPEC_SCRIPT.make_interaction_flow(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.ACTIVATION_MODAL_OPEN,
			game_state,
			{"active_player": player_index},
			Constants.Visibility.ALL,
			{"ship_index": payload.get("ship_index", -1)})

## Checks if a damage card rule blocks command-token gain.
func _is_token_gain_blocked(game_state: GameState,
		ship: ShipInstance) -> bool:
	var ctx: EffectContext = EffectContext.new()
	ctx.set_meta_value("ship", ship)
	var step_id: Constants.InteractionStep = _token_gain_step(game_state)
	return RuleSurface.is_blocked(ctx,
			Constants.InteractionFlow.SHIP_ACTIVATION,
			step_id,
			RuleSurface.TARGET_COMMAND_TOKEN_GAIN)


func _token_gain_step(game_state: GameState) -> Constants.InteractionStep:
	if game_state == null or game_state.interaction_flow == null:
		return Constants.InteractionStep.ACTIVATION_MODAL_OPEN
	if game_state.interaction_flow.flow_type \
			!= Constants.InteractionFlow.SHIP_ACTIVATION:
		return Constants.InteractionStep.ACTIVATION_MODAL_OPEN
	return game_state.interaction_flow.step_id
