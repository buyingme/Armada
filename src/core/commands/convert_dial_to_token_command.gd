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
	if ship.activated_this_round:
		return "Ship already activated this round."
	if ship.command_dial_stack == null:
		return "Ship has no dial stack."
	if ship.command_dial_stack.get_hidden_count() == 0 \
			and ship.command_dial_stack.get_revealed_dial().is_empty():
		return "Ship has no dials to reveal or spend."
	if ship.command_tokens == null:
		return "Ship has no command token manager."
	return ""


## Reveals the top dial, spends it, adds the matching token.
## Checks for Life Support Failure (ON_COMMAND_TOKEN_GAIN hook).
## Returns {"command": int, "token_added": bool, "duplicate": bool,
##          "overflow": bool, "token_blocked": bool}.
func execute(game_state: GameState) -> Dictionary:
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	# Reveal if not already revealed.
	var dial: Dictionary = \
			ship.command_dial_stack.get_revealed_dial()
	if dial.is_empty():
		dial = ship.command_dial_stack.reveal_top()
	if dial.is_empty():
		return {"command": -1, "token_added": false,
				"token_blocked": false}
	var cmd_type: int = int(dial.get("command", 0))
	# Spend the dial.
	ship.command_dial_stack.spend_revealed()
	# Check Life Support Failure (damage card blocks token gain).
	## Rules Reference: "Life Support Failure" card text.
	if _is_token_gain_blocked(game_state, ship):
		return {"command": cmd_type, "token_added": false,
				"duplicate": false, "overflow": false,
				"token_blocked": true,
				"ship_index": payload.get("ship_index", -1)}
	# Add the token.
	var add_result: Dictionary = \
			ship.command_tokens.force_add_token(cmd_type)
	var duplicate: bool = add_result.get("duplicate", false)
	var overflow: bool = add_result.get("overflow", false)
	# Auto-discard duplicate.
	if duplicate:
		ship.command_tokens.remove_token(cmd_type)
	return {
		"command": cmd_type,
		"token_added": true,
		"duplicate": duplicate,
		"overflow": overflow,
		"token_blocked": false,
		"ship_index": payload.get("ship_index", -1),
	}


## Checks if a damage card effect (Life Support Failure) blocks token gain.
func _is_token_gain_blocked(game_state: GameState,
		ship: ShipInstance) -> bool:
	if not game_state.effect_registry:
		return false
	var ctx: EffectContext = EffectContext.new()
	ctx.set_meta_value("ship", ship)
	ctx = game_state.effect_registry.resolve_hook(
			&"ON_COMMAND_TOKEN_GAIN", ctx)
	return ctx.cancelled
