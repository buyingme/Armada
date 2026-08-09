## Focused Slice 8A regressions for command execution failure integrity.
extends GutTest


const PROCESSOR_SCRIPT: GDScript = preload(
		"res://src/autoload/command_processor.gd")
const CURRENT_ATTACK_FIXTURE: GDScript = preload(
		"res://tests/fixtures/current_attack_state_fixture.gd")
const ORCHESTRATOR: GDScript = preload(
		"res://src/core/timing_windows/timing_window_orchestrator.gd")
const DEFINITIONS: GDScript = preload(
		"res://src/core/timing_windows/timing_window_definitions.gd")
const ECM_SCRIPT: GDScript = preload(
		"res://src/core/effects/rules/upgrades/defensive_retrofit/electronic_countermeasures.gd")
const CF_RULE: GDScript = preload(
		"res://src/core/effects/rules/concentrate_fire_token.gd")
const CF_USE_COMMAND: GDScript = preload(
		"res://src/core/commands/use_concentrate_fire_token_reroll_command.gd")
const H9_RULE: GDScript = preload(
		"res://src/core/effects/rules/upgrades/turbolasers/h9_turbolasers.gd")
const H9_USE_COMMAND: GDScript = preload(
		"res://src/core/commands/use_h9_command.gd")


var _state: FaultInjectGameState = null
var _processor: Node = null
var _saved_game_state: GameState = null
var _saved_registry: Dictionary = {}


func before_each() -> void:
	_saved_game_state = GameManager.current_game_state
	_saved_registry = GameCommand._registry.duplicate()
	GameCommand._registry.clear()
	_state = FaultInjectGameState.new()
	_state.initialize()
	_state.current_round = 1
	_state.current_phase = Constants.GamePhase.SHIP
	_state.rng = GameRng.new(8675309)
	GameManager.current_game_state = _state
	_processor = PROCESSOR_SCRIPT.new()
	add_child_autofree(_processor)


func after_each() -> void:
	GameManager.current_game_state = _saved_game_state
	GameCommand._registry = _saved_registry


func test_empty_execution_rejects_without_history_or_cursor_advance() -> void:
	var command := EmptyExecutionCommand.new()
	assert_eq(_processor.submit(command), {})
	_assert_stream_unchanged(command)
	assert_engine_error(1,
			"Empty execution should produce one rejection diagnostic.")


func test_explicit_execution_failure_rejects_without_history_or_cursor_advance() -> void:
	var command := ExplicitFailureCommand.new()
	assert_eq(_processor.submit(command), {})
	_assert_stream_unchanged(command)
	assert_engine_error(1,
			"Explicit execution failure should produce one rejection diagnostic.")


func test_roll_dice_failure_restores_rng_attack_and_attack_count() -> void:
	_add_ship(0)
	_add_ship(1)
	_install_attack({
		"dice_pool": {"RED": 2},
		"stage": CurrentAttackState.STAGE_PRE_ROLL,
	})
	var before_attack: Dictionary = _attack_snapshot()
	var before_rng: int = _state.rng.get_state()
	var before_counts: Dictionary = _state.ship_target_attack_counts.duplicate(true)
	_state.reject_current_attack_updates = true
	var command := RollDiceCommand.new(0, {"attack_id": _attack_id()})

	assert_eq(_processor.submit(command), {})
	assert_eq(_attack_snapshot(), before_attack)
	assert_eq(_state.rng.get_state(), before_rng)
	assert_eq(_state.ship_target_attack_counts, before_counts)
	_assert_stream_unchanged(command)
	assert_engine_error(1)


func test_select_evade_failure_restores_rng_and_attack() -> void:
	_add_ship(0)
	var defender: ShipInstance = _add_ship(1)
	var evade_index: int = _token_index(
			defender, Constants.DefenseToken.EVADE)
	_install_attack({
		"stage": CurrentAttackState.STAGE_DEFENSE,
		"range_band": Constants.RANGE_BAND_CLOSE,
		"dice_results": [_red_hit()],
		"defense_stage": CurrentAttackState.DEFENSE_RESOLVING,
		"committed_defense_tokens": [evade_index],
	})
	var before_attack: Dictionary = _attack_snapshot()
	var before_rng: int = _state.rng.get_state()
	_state.reject_current_attack_updates = true
	var command := SelectEvadeDieCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": 0,
		"token_index": evade_index,
		"die_index": 0,
		"expected_color": int(Constants.DiceColor.RED),
		"expected_face": int(Constants.DiceFace.HIT),
	})

	assert_eq(_processor.submit(command), {})
	assert_eq(_attack_snapshot(), before_attack)
	assert_eq(_state.rng.get_state(), before_rng)
	_assert_stream_unchanged(command)
	assert_engine_error(1)


func test_shared_concentrate_fire_failure_restores_rng_token_and_attack() -> void:
	var attacker: ShipInstance = _add_ship(0)
	_add_ship(1)
	assert_true(attacker.command_tokens.add_token(
			Constants.CommandType.CONCENTRATE_FIRE))
	_install_attack({
		"stage": CurrentAttackState.STAGE_ATTACK_MODIFY,
		"dice_results": [_red_hit()],
		"cf_token_resolution": CurrentAttackState.RESOLUTION_PENDING,
	})
	_state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			0)
	var context: Dictionary = {
		TimingWindowState.CONTINUATION_KEY_ID: ConfirmAttackDiceCommand.TYPE,
		TimingWindowState.CONTINUATION_KEY_RESUME_POINT: "attack_after_modify",
		TimingWindowState.CONTINUATION_KEY_SOURCE_ID: _attack_id(),
		TimingWindowState.CONTINUATION_KEY_SOURCE_TYPE: "current_attack",
		TimingWindowState.CONTINUATION_KEY_OWNER_PLAYER: 0,
	}
	assert_true(bool(ORCHESTRATOR.open_window(
			_state, DEFINITIONS.ATTACK_MODIFY, 1, context).get(
					ORCHESTRATOR.KEY_OK, false)))
	CF_RULE.register()
	var before_attack: Dictionary = _attack_snapshot()
	var before_rng: int = _state.rng.get_state()
	var before_tokens: Dictionary = attacker.command_tokens.serialize()
	_state.reject_current_attack_updates = true
	var ship_id: String = CF_RULE.attacking_ship_identity(
			_state.current_attack_state)
	var command: GameCommand = CF_USE_COMMAND.new(0, {
		"timing_window_id": TimingWindowDefinitions.ATTACK_MODIFY,
		"lifecycle_id": _state.timing_window_state.lifecycle_id,
		"source_owner_kind": CF_RULE.SOURCE_OWNER_KIND,
		"runtime_source_id":
				CF_RULE.token_source_identity(ship_id),
		"semantic_key": CF_RULE.SEMANTIC_KEY,
		"attack_id": _attack_id(),
		"attacking_ship_id": ship_id,
		"die_index": 0,
		"expected_color": int(Constants.DiceColor.RED),
		"expected_face": int(Constants.DiceFace.HIT),
	})

	assert_eq(_processor.submit(command), {})
	assert_eq(_attack_snapshot(), before_attack)
	assert_eq(_state.rng.get_state(), before_rng)
	assert_eq(attacker.command_tokens.serialize(), before_tokens)
	_assert_stream_unchanged(command)
	assert_engine_error(1)


func test_h9_failure_restores_rule_guard_and_attack() -> void:
	var attacker: ShipInstance = _add_ship(0)
	_add_ship(1)
	attacker.roster_entry_id = "atomic-attacker"
	var runtime_upgrade: Dictionary = attacker.add_runtime_upgrade(
			H9_RULE.DATA_KEY, "atomic-h9", "TURBOLASERS", 0)
	_install_attack({
		"stage": CurrentAttackState.STAGE_ATTACK_MODIFY,
		"dice_results": [_red_hit()],
	})
	_state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			0)
	var context: Dictionary = {
		TimingWindowState.CONTINUATION_KEY_ID: ConfirmAttackDiceCommand.TYPE,
		TimingWindowState.CONTINUATION_KEY_RESUME_POINT: "attack_after_modify",
		TimingWindowState.CONTINUATION_KEY_SOURCE_ID: _attack_id(),
		TimingWindowState.CONTINUATION_KEY_SOURCE_TYPE: "current_attack",
		TimingWindowState.CONTINUATION_KEY_OWNER_PLAYER: 0,
	}
	assert_true(bool(ORCHESTRATOR.open_window(
			_state, DEFINITIONS.ATTACK_MODIFY, 1, context).get(
					ORCHESTRATOR.KEY_OK, false)))
	H9_RULE.register()
	var before_attack: Dictionary = _attack_snapshot()
	var before_rule_state: Dictionary = (runtime_upgrade.get(
			"rule_state", {}) as Dictionary).duplicate(true)
	_state.reject_current_attack_updates = true
	var runtime_upgrade_id: String = str(runtime_upgrade.get(
			"runtime_upgrade_id", ""))
	var command: GameCommand = H9_USE_COMMAND.new(0, {
		"timing_window_id": TimingWindowDefinitions.ATTACK_MODIFY,
		"lifecycle_id": _state.timing_window_state.lifecycle_id,
		"source_owner_kind": H9_RULE.SOURCE_OWNER_KIND,
		"runtime_source_id": runtime_upgrade_id,
		"semantic_key": H9_RULE.SEMANTIC_KEY,
		"attack_id": _attack_id(),
		"runtime_upgrade_id": runtime_upgrade_id,
		"die_index": 0,
		"expected_color": int(Constants.DiceColor.RED),
		"expected_face": int(Constants.DiceFace.HIT),
		"target_face": int(Constants.DiceFace.ACCURACY),
	})

	assert_eq(_processor.submit(command), {})
	assert_eq(_attack_snapshot(), before_attack)
	assert_eq(runtime_upgrade.get("rule_state"), before_rule_state)
	_assert_stream_unchanged(command)
	assert_engine_error(1)


func test_concentrate_fire_dial_failure_preserves_revealed_dial() -> void:
	var attacker: ShipInstance = _add_ship(0)
	_add_ship(1)
	assert_true(attacker.command_dial_stack.assign_dials([
		Constants.CommandType.CONCENTRATE_FIRE,
		Constants.CommandType.NAVIGATE,
	], 1))
	assert_false(attacker.command_dial_stack.reveal_top().is_empty())
	_install_attack({
		"dice_pool": {"RED": 1},
		"cf_dial_resolution": CurrentAttackState.RESOLUTION_PENDING,
	})
	var before_attack: Dictionary = _attack_snapshot()
	var before_dials: Dictionary = attacker.command_dial_stack.serialize()
	_state.reject_current_attack_updates = true
	var command := UseConcentrateFireDialCommand.new(0, {
		"attack_id": _attack_id(),
		"color": "RED",
	})

	assert_eq(_processor.submit(command), {})
	assert_eq(_attack_snapshot(), before_attack)
	assert_eq(attacker.command_dial_stack.serialize(), before_dials)
	_assert_stream_unchanged(command)
	assert_engine_error(1)


func test_defense_token_failure_preserves_token_and_attack() -> void:
	_add_ship(0)
	var defender: ShipInstance = _add_ship(1)
	var brace_index: int = _token_index(
			defender, Constants.DefenseToken.BRACE)
	_install_attack({
		"stage": CurrentAttackState.STAGE_DEFENSE,
		"dice_results": [_red_hit()],
		"defense_stage": CurrentAttackState.DEFENSE_RESOLVING,
		"committed_defense_tokens": [brace_index],
	})
	var before_attack: Dictionary = _attack_snapshot()
	var before_tokens: Array = defender.defense_tokens.duplicate(true)
	_state.reject_current_attack_updates = true
	var command := SpendDefenseTokenCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": 0,
		"token_index": brace_index,
		"expected_token_type": int(Constants.DefenseToken.BRACE),
		"spend_method": "exhaust",
	})

	assert_eq(_processor.submit(command), {})
	assert_eq(_attack_snapshot(), before_attack)
	assert_eq(defender.defense_tokens, before_tokens)
	_assert_stream_unchanged(command)
	assert_engine_error(1)


func test_redirect_failure_preserves_shields_and_attack() -> void:
	_add_ship(0)
	var defender: ShipInstance = _add_ship(1)
	var redirect_index: int = _token_index(
			defender, Constants.DefenseToken.REDIRECT)
	_install_attack({
		"stage": CurrentAttackState.STAGE_DEFENSE,
		"dice_results": [_red_hit()],
		"defender_zone": Constants.HullZone.FRONT,
		"defense_stage": CurrentAttackState.DEFENSE_RESOLVING,
		"committed_defense_tokens": [redirect_index],
	})
	var zone: Constants.HullZone = Constants.HullZone.LEFT
	var zone_name: String = Constants.hull_zone_to_string(zone)
	var before_attack: Dictionary = _attack_snapshot()
	var before_shields: Dictionary = defender.current_shields.duplicate(true)
	_state.reject_current_attack_updates = true
	var command := SelectRedirectZoneCommand.new(1, {
		"attack_id": _attack_id(),
		"ship_index": 0,
		"token_index": redirect_index,
		"zone": int(zone),
		"expected_shields": int(defender.current_shields[zone_name]),
	})

	assert_eq(_processor.submit(command), {})
	assert_eq(_attack_snapshot(), before_attack)
	assert_eq(defender.current_shields, before_shields)
	_assert_stream_unchanged(command)
	assert_engine_error(1)


func test_resolve_damage_failure_restores_deck_ship_and_attack() -> void:
	_add_ship(0)
	var defender: ShipInstance = _add_ship(1)
	defender.current_shields["FRONT"] = 0
	var card := DamageCard.create("Ship", "Atomic Test Damage")
	card.effect_id = "atomic_test_damage"
	_state.damage_deck = DamageDeck.deserialize({
		"draw_pile": [card.serialize()],
		"discard_pile": [],
	})
	_install_attack({
		"stage": CurrentAttackState.STAGE_DEFENSE,
		"dice_results": [_red_hit()],
		"defender_zone": Constants.HullZone.FRONT,
		"defense_stage": CurrentAttackState.DEFENSE_COMPLETE,
	})
	var before_attack: Dictionary = _attack_snapshot()
	var before_deck: Dictionary = _state.damage_deck.serialize()
	var before_ship: Dictionary = defender.serialize()
	_state.reject_current_attack_updates = true
	var command := ResolveDamageCommand.new(0, {
		"attack_id": _attack_id(),
	})

	assert_eq(_processor.submit(command), {})
	assert_eq(_attack_snapshot(), before_attack)
	assert_eq(_state.damage_deck.serialize(), before_deck)
	assert_eq(defender.serialize(), before_ship)
	_assert_stream_unchanged(command)
	assert_engine_error(1)


func test_complete_attack_failure_preserves_ecm_runtime_owner() -> void:
	_add_ship(0)
	var defender: ShipInstance = _add_ship(1)
	defender.roster_entry_id = "atomic-defender"
	var runtime_upgrade: Dictionary = defender.add_runtime_upgrade(
			"electronic_countermeasures", "atomic-ecm",
			"DEFENSIVE_RETROFIT", 0)
	_install_attack({
		"stage": CurrentAttackState.STAGE_RESOLVED,
		"dice_results": [_red_hit()],
		"defense_stage": CurrentAttackState.DEFENSE_COMPLETE,
	})
	var pending: Dictionary = {
		"runtime_upgrade_id": str(runtime_upgrade.get(
				"runtime_upgrade_id", "")),
		"attack_scope": {"attack_id": _attack_id()},
	}
	runtime_upgrade["rule_state"] = {
		ECM_SCRIPT.RULE_STATE_PENDING_AUTHORIZATION: pending,
	}
	var before_attack: Dictionary = _attack_snapshot()
	_state.reject_current_attack_updates = true
	var command := CompleteAttackCommand.new(0, {
		"attack_id": _attack_id(),
	})

	assert_eq(_processor.submit(command), {})
	assert_eq(_attack_snapshot(), before_attack)
	assert_eq(ECM_SCRIPT.pending_authorization(runtime_upgrade), pending,
			"Failed completion must not clean the ECM runtime owner.")
	_assert_stream_unchanged(command)
	assert_engine_error(1)


func test_skip_attack_failure_restores_attack_and_timing_owner() -> void:
	_add_ship(0)
	var defender: ShipInstance = _add_ship(1)
	defender.roster_entry_id = "atomic-defender"
	var runtime_upgrade: Dictionary = defender.add_runtime_upgrade(
			"electronic_countermeasures", "atomic-ecm",
			"DEFENSIVE_RETROFIT", 0)
	_install_attack({
		"stage": CurrentAttackState.STAGE_ATTACK_MODIFY,
		"dice_results": [_red_hit()],
	})
	_state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			0)
	var context: Dictionary = {
		TimingWindowState.CONTINUATION_KEY_ID: "confirm_attack_dice",
		TimingWindowState.CONTINUATION_KEY_RESUME_POINT: "attack_after_modify",
		TimingWindowState.CONTINUATION_KEY_SOURCE_ID: _attack_id(),
		TimingWindowState.CONTINUATION_KEY_SOURCE_TYPE: "current_attack",
		TimingWindowState.CONTINUATION_KEY_OWNER_PLAYER: 0,
	}
	var opened: Dictionary = ORCHESTRATOR.open_window(
			_state, DEFINITIONS.ATTACK_MODIFY, 12, context)
	assert_true(bool(opened.get(ORCHESTRATOR.KEY_OK, false)))
	var before_attack: Dictionary = _attack_snapshot()
	var before_timing: Dictionary = _state.timing_window_state.serialize()
	var pending: Dictionary = {
		"runtime_upgrade_id": str(runtime_upgrade.get(
				"runtime_upgrade_id", "")),
		"attack_scope": {"attack_id": _attack_id()},
	}
	runtime_upgrade["rule_state"] = {
		ECM_SCRIPT.RULE_STATE_PENDING_AUTHORIZATION: pending,
	}
	_state.reject_timing_window_updates = true
	var command := SkipAttackCommand.new(0, {
		"attack_id": _attack_id(),
		"reason": "cancelled",
		ORCHESTRATOR.COMMAND_KEY_LIFECYCLE_ID:
				_state.timing_window_state.lifecycle_id,
	})

	assert_eq(_processor.submit(command), {})
	assert_eq(_attack_snapshot(), before_attack)
	assert_eq(_state.timing_window_state.serialize(), before_timing)
	assert_eq(ECM_SCRIPT.pending_authorization(runtime_upgrade), pending,
			"Failed cancellation must not clean the ECM runtime owner.")
	_assert_stream_unchanged(command)
	assert_engine_error(1)


func _install_attack(options: Dictionary) -> void:
	assert_not_null(CURRENT_ATTACK_FIXTURE.install(_state, options),
			"Atomic-failure fixture should install canonical attack state.")


func _add_ship(player: int) -> ShipInstance:
	var data := ShipData.new()
	data.ship_name = "Atomic Test Ship"
	data.hull = 5
	data.max_speed = 2
	data.command_value = 2
	data.shields = {"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1}
	data.defense_tokens = ["brace", "redirect", "evade"]
	data.navigation_chart = [[1], [1, 1]]
	var ship := ShipInstance.create_from_data("atomic_test_ship", data, 2, player)
	_state.get_player_state(player).ships.append(ship)
	return ship


func _token_index(ship: ShipInstance,
		token_type: Constants.DefenseToken) -> int:
	for index: int in range(ship.defense_tokens.size()):
		if int(ship.defense_tokens[index].get("type", -1)) == int(token_type):
			return index
	return -1


func _attack_id() -> String:
	return _state.current_attack_state.attack_id


func _attack_snapshot() -> Dictionary:
	return _state.current_attack_state.serialize()


func _red_hit() -> Dictionary:
	return {
		"color": int(Constants.DiceColor.RED),
		"face": int(Constants.DiceFace.HIT),
	}


func _assert_stream_unchanged(command: GameCommand) -> void:
	assert_eq(_processor.get_command_count(), 0)
	assert_eq(_processor.get_next_sequence(), 0)
	assert_eq(command.sequence, -1,
			"Rejected live execution must release its tentative sequence.")


class FaultInjectGameState extends GameState:
	var reject_current_attack_updates: bool = false
	var reject_timing_window_updates: bool = false

	func set_current_attack_state(value: CurrentAttackState) -> bool:
		if reject_current_attack_updates:
			return false
		return super.set_current_attack_state(value)

	func set_timing_window_state(value: TimingWindowState) -> bool:
		if reject_timing_window_updates:
			return false
		return super.set_timing_window_state(value)


class EmptyExecutionCommand extends GameCommand:
	func _init() -> void:
		super._init(0, "skip_attack", {})

	func validate(_game_state: GameState) -> String:
		return ""

	func execute(_game_state: GameState) -> Dictionary:
		return {}


class ExplicitFailureCommand extends GameCommand:
	func _init() -> void:
		super._init(0, "skip_attack", {})

	func validate(_game_state: GameState) -> String:
		return ""

	func execute(_game_state: GameState) -> Dictionary:
		return {"success": false, "reason": "Injected execution failure."}
