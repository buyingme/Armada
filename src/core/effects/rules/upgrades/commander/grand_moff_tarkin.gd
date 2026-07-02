## GrandMoffTarkin
##
## Narrow CAP-UPG-001 helper for Grand Moff Tarkin's start-of-Ship-Phase
## command-token grant. This is command-owned rule logic; it does not register
## passive RuleRegistry observer hooks.
class_name GrandMoffTarkin
extends RefCounted


const DATA_KEY: String = "grand_moff_tarkin"
const GUARD_SHIP_PHASE_START: String = "ship_phase_start"
const RULE_STATE_LAST_CHOICE: String = "last_ship_phase_choice"


## Returns the first active Tarkin source that may prompt this Ship Phase.
static func find_prompt_source(game_state: GameState) -> Dictionary:
	for source: Dictionary in _active_sources(game_state):
		var runtime_upgrade: Dictionary = source.get("runtime_upgrade", {})
		if not has_used_this_ship_phase(runtime_upgrade, game_state.current_round):
			return source
	return {}


## Returns an active source by runtime upgrade id, or an empty dictionary.
static func find_active_source_by_id(
		game_state: GameState,
		runtime_upgrade_id: String) -> Dictionary:
	for source: Dictionary in _active_sources(game_state):
		var runtime_upgrade: Dictionary = source.get("runtime_upgrade", {})
		if str(runtime_upgrade.get("runtime_upgrade_id", "")) == runtime_upgrade_id:
			return source
	return {}


## Builds the public prompt payload for projection/reconnect.
static func prompt_payload(source: Dictionary) -> Dictionary:
	var runtime_upgrade: Dictionary = source.get("runtime_upgrade", {})
	return {
		"runtime_upgrade_id": str(runtime_upgrade.get("runtime_upgrade_id", "")),
		"source_data_key": DATA_KEY,
		"owner_player": int(source.get("owner_player", -1)),
		"source_ship_index": int(source.get("ship_index", -1)),
		"source_ship_ref": str(runtime_upgrade.get("source_ship_ref", "")),
		"available_commands": available_commands(),
	}


## Returns all command types Tarkin can choose.
static func available_commands() -> Array[int]:
	var commands: Array[int] = []
	for command: int in range(Constants.CommandType.size()):
		commands.append(command)
	return commands


## Returns true when the runtime upgrade already used this start timing.
static func has_used_this_ship_phase(
		runtime_upgrade: Dictionary,
		round_number: int) -> bool:
	var guards: Dictionary = _dict_from(runtime_upgrade.get("trigger_guards", {}))
	var guard: Dictionary = _dict_from(guards.get(GUARD_SHIP_PHASE_START, {}))
	return int(guard.get("round", -1)) == round_number


## Records the once-per-Ship-Phase guard and public last-choice state.
static func record_choice(game_state: GameState,
		runtime_upgrade: Dictionary,
		declined: bool,
		command: int) -> void:
	var guards: Dictionary = _dict_from(runtime_upgrade.get("trigger_guards", {}))
	guards[GUARD_SHIP_PHASE_START] = {
		"round": game_state.current_round,
		"phase": int(Constants.GamePhase.SHIP),
	}
	runtime_upgrade["trigger_guards"] = guards
	runtime_upgrade["rule_state"] = _choice_rule_state(
			game_state, runtime_upgrade, declined, command)


## Grants the selected command token to each friendly, non-destroyed ship.
static func grant_command_tokens(
		game_state: GameState,
		owner_player: int,
		command: int) -> Array[Dictionary]:
	var grants: Array[Dictionary] = []
	var player_state: PlayerState = game_state.get_player_state(owner_player)
	if player_state == null:
		return grants
	for ship_index: int in range(player_state.ships.size()):
		var ship: ShipInstance = player_state.ships[ship_index] as ShipInstance
		var grant: Dictionary = _grant_command_token_to_ship(
				game_state, ship, ship_index, command)
		if not grant.is_empty():
			grants.append(grant)
	return grants


static func _active_sources(game_state: GameState) -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	if game_state == null:
		return sources
	for player_index: int in range(game_state.player_states.size()):
		var player_state: PlayerState = game_state.get_player_state(player_index)
		_append_player_sources(sources, player_state)
	return sources


static func _append_player_sources(
		sources: Array[Dictionary],
		player_state: PlayerState) -> void:
	if player_state == null:
		return
	for ship_index: int in range(player_state.ships.size()):
		var ship: ShipInstance = player_state.ships[ship_index] as ShipInstance
		if ship == null or ship.is_destroyed():
			continue
		_append_ship_sources(sources, ship, ship_index)


static func _append_ship_sources(
		sources: Array[Dictionary],
		ship: ShipInstance,
		ship_index: int) -> void:
	for runtime_upgrade: Dictionary in ship.runtime_upgrades:
		if not _runtime_upgrade_active(runtime_upgrade):
			continue
		sources.append({
			"ship": ship,
			"ship_index": ship_index,
			"owner_player": ship.owner_player,
			"runtime_upgrade": runtime_upgrade,
		})


static func _runtime_upgrade_active(runtime_upgrade: Dictionary) -> bool:
	if str(runtime_upgrade.get("data_key", "")) != DATA_KEY:
		return false
	var card_state: Dictionary = _dict_from(runtime_upgrade.get("card_state", {}))
	return not bool(card_state.get("discarded", false)) \
			and not bool(card_state.get("disabled", false))


static func _choice_rule_state(game_state: GameState,
		runtime_upgrade: Dictionary,
		declined: bool,
		command: int) -> Dictionary:
	var rule_state: Dictionary = _dict_from(runtime_upgrade.get("rule_state", {}))
	rule_state[RULE_STATE_LAST_CHOICE] = {
		"round": game_state.current_round,
		"declined": declined,
		"command": command,
	}
	return rule_state


static func _grant_command_token_to_ship(game_state: GameState,
		ship: ShipInstance,
		ship_index: int,
		command: int) -> Dictionary:
	if ship == null or ship.is_destroyed() or ship.command_tokens == null:
		return {}
	if _token_gain_blocked(game_state, ship):
		return _grant_result(ship_index, false, false, false, true, ship)
	var add_result: Dictionary = ship.command_tokens.force_add_token(
			command as Constants.CommandType)
	var duplicate: bool = bool(add_result.get("duplicate", false))
	if duplicate:
		ship.command_tokens.remove_token(command as Constants.CommandType)
	var overflow: bool = bool(add_result.get("overflow", false)) and not duplicate
	return _grant_result(ship_index, true, duplicate, overflow, false, ship)


static func _token_gain_blocked(game_state: GameState,
		ship: ShipInstance) -> bool:
	var ctx: EffectContext = EffectContext.new()
	ctx.set_meta_value("ship", ship)
	return RuleSurface.is_blocked(ctx,
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT,
			RuleSurface.TARGET_COMMAND_TOKEN_GAIN)


static func _grant_result(ship_index: int,
		added: bool,
		duplicate: bool,
		overflow: bool,
		blocked: bool,
		ship: ShipInstance) -> Dictionary:
	return {
		"ship_index": ship_index,
		"token_added": added,
		"duplicate": duplicate,
		"overflow": overflow,
		"token_blocked": blocked,
		"token_count": ship.command_tokens.get_token_count(),
	}


static func _dict_from(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
