## TarkinChoiceCommand
##
## Replayable CAP-UPG-001 command for choosing or declining Grand Moff
## Tarkin's start-of-Ship-Phase command-token grant.
class_name TarkinChoiceCommand
extends GameCommand


const FLOW_SPEC_SCRIPT: GDScript = preload("res://src/core/state/flow_spec.gd")
const TARKIN_SCRIPT: GDScript = preload(
		"res://src/core/effects/rules/upgrades/commander/grand_moff_tarkin.gd")


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("tarkin_choice", func(
			player: int, pl: Dictionary) -> GameCommand:
		return TarkinChoiceCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "tarkin_choice", p_payload)


## Validates the projected Tarkin choice/decline prompt.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if game_state.current_phase != Constants.GamePhase.SHIP:
		return "Grand Moff Tarkin can only be used in the Ship Phase."
	var flow_error: String = _validate_flow(game_state.interaction_flow)
	if flow_error != "":
		return flow_error
	var source: Dictionary = _source(game_state)
	if source.is_empty():
		return "Grand Moff Tarkin source is not active."
	return _validate_source_choice(game_state, source)


## Resolves the Tarkin choice, grants tokens, and enters normal ship activation.
func execute(game_state: GameState) -> Dictionary:
	var source: Dictionary = _source(game_state)
	var runtime_upgrade: Dictionary = source.get("runtime_upgrade", {})
	var declined: bool = bool(payload.get("declined", false))
	var command: int = _selected_command()
	TARKIN_SCRIPT.record_choice(game_state, runtime_upgrade, declined, command)
	var grants: Array[Dictionary] = []
	if not declined:
		grants = TARKIN_SCRIPT.grant_command_tokens(
				game_state, player_index, command)
	_enter_ship_activation(game_state)
	return _result(runtime_upgrade, declined, command, grants)


func _validate_flow(flow: InteractionFlow) -> String:
	if flow == null:
		return "Grand Moff Tarkin prompt is not active."
	if flow.flow_type != Constants.InteractionFlow.SHIP_ACTIVATION \
			or flow.step_id != Constants.InteractionStep.TARKIN_COMMAND_CHOICE:
		return "Grand Moff Tarkin prompt is not active."
	if flow.controller_player != player_index:
		return "Only the Grand Moff Tarkin player may choose."
	return ""


func _validate_source_choice(game_state: GameState,
		source: Dictionary) -> String:
	if int(source.get("owner_player", -1)) != player_index:
		return "Grand Moff Tarkin source owner mismatch."
	var runtime_upgrade: Dictionary = source.get("runtime_upgrade", {})
	if TARKIN_SCRIPT.has_used_this_ship_phase(
			runtime_upgrade, game_state.current_round):
		return "Grand Moff Tarkin was already used this Ship Phase."
	if bool(payload.get("declined", false)):
		return ""
	if not payload.has("command"):
		return "Missing Grand Moff Tarkin command choice."
	if not TARKIN_SCRIPT.available_commands().has(_selected_command()):
		return "Invalid Grand Moff Tarkin command choice."
	return ""


func _source(game_state: GameState) -> Dictionary:
	var runtime_upgrade_id: String = str(payload.get("runtime_upgrade_id", ""))
	if runtime_upgrade_id.is_empty():
		return {}
	var flow: InteractionFlow = game_state.interaction_flow
	if flow != null and str(flow.payload.get("runtime_upgrade_id", "")) \
			!= runtime_upgrade_id:
		return {}
	return TARKIN_SCRIPT.find_active_source_by_id(
			game_state, runtime_upgrade_id)


func _selected_command() -> int:
	if bool(payload.get("declined", false)):
		return -1
	return int(payload.get("command", -1))


func _enter_ship_activation(game_state: GameState) -> void:
	game_state.interaction_flow = FLOW_SPEC_SCRIPT.make_interaction_flow(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT,
			game_state,
			{"active_player": game_state.initiative_player},
			Constants.Visibility.ALL,
			{"active_player": game_state.initiative_player})


func _result(runtime_upgrade: Dictionary,
		declined: bool,
		command: int,
		grants: Array[Dictionary]) -> Dictionary:
	return {
		"runtime_upgrade_id": str(runtime_upgrade.get("runtime_upgrade_id", "")),
		"owner_player": player_index,
		"declined": declined,
		"command": command,
		"grants": grants,
	}
