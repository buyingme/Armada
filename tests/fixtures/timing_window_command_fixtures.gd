## Replayable commands used only to prove the shared timing-window protocol.
extends RefCounted


const ORCHESTRATOR: GDScript = preload(
		"res://src/core/timing_windows/timing_window_orchestrator.gd")
const DEFINITIONS: GDScript = preload(
		"res://src/core/timing_windows/timing_window_definitions.gd")
const OPPORTUNITY: GDScript = preload(
		"res://src/core/timing_windows/timing_window_opportunity.gd")
const PARTICIPANT: GDScript = preload(
		"res://tests/fixtures/timing_window_participant_fixture.gd")

const OPEN_TYPE: String = "publish_attack_flow"
const USE_TYPE: String = "reroll_attack_die"
const DECLINE_TYPE: String = "skip_attack_modifier"
const CONTINUATION_TYPE: String = "confirm_attack_dice"
const CANCEL_TYPE: String = "skip_attack"
const FOLLOWUP_TYPE: String = "debug_deal_damage"

const COMPLETED_KEY: String = "timing_fixture_completed"
const CONTINUATION_FAILURE_KEY: String = "timing_fixture_continuation_failure"
const MUTATION_COUNT_KEY: String = "timing_fixture_mutation_count"


static func register() -> void:
	GameCommand.register_type(OPEN_TYPE, func(player: int,
			payload: Dictionary) -> GameCommand:
		return OpenFixtureWindowCommand.new(player, payload))
	GameCommand.register_type(USE_TYPE, func(player: int,
			payload: Dictionary) -> GameCommand:
		return ResolveFixtureOpportunityCommand.new(player, USE_TYPE, payload))
	GameCommand.register_type(DECLINE_TYPE, func(player: int,
			payload: Dictionary) -> GameCommand:
		return ResolveFixtureOpportunityCommand.new(player, DECLINE_TYPE, payload))
	GameCommand.register_type(CONTINUATION_TYPE, func(player: int,
			payload: Dictionary) -> GameCommand:
		return ContinueFixtureWindowCommand.new(player, payload))
	GameCommand.register_type(CANCEL_TYPE, func(player: int,
			payload: Dictionary) -> GameCommand:
		return CancelFixtureWindowCommand.new(player, payload))
	GameCommand.register_type(FOLLOWUP_TYPE, func(player: int,
			payload: Dictionary) -> GameCommand:
		return AddFixtureBlockerCommand.new(player, payload))


static func register_participant() -> bool:
	return RuleRegistry.register_timing_window_participant({
		RuleRegistry.PARTICIPANT_KEY_CAPABILITY_ID: PARTICIPANT.CAPABILITY_ID,
		RuleRegistry.PARTICIPANT_KEY_WINDOW: DEFINITIONS.ATTACK_MODIFY,
		RuleRegistry.PARTICIPANT_KEY_SOURCE_OWNER_KIND:
				PARTICIPANT.SOURCE_OWNER_KIND,
		RuleRegistry.PARTICIPANT_KEY_RULE_SCRIPT: PARTICIPANT,
		RuleRegistry.PARTICIPANT_KEY_DIAGNOSTIC_ID: "fixture-protocol",
	})


static func make_open(player: int = 0) -> GameCommand:
	return OpenFixtureWindowCommand.new(player, {})


static func make_resolution(command_type: String,
		state: GameState,
		source_id: String,
		player: int = 0) -> GameCommand:
	return ResolveFixtureOpportunityCommand.new(player, command_type, {
		"timing_window_id": DEFINITIONS.ATTACK_MODIFY,
		"lifecycle_id": state.timing_window_state.lifecycle_id,
		"source_owner_kind": PARTICIPANT.SOURCE_OWNER_KIND,
		"runtime_source_id": source_id,
		"semantic_key": PARTICIPANT.SEMANTIC_KEY,
	})


static func make_cancel(state: GameState, player: int = 0) -> GameCommand:
	return CancelFixtureWindowCommand.new(player, {
		"timing_window_id": DEFINITIONS.ATTACK_MODIFY,
		"lifecycle_id": state.timing_window_state.lifecycle_id,
	})


class OpenFixtureWindowCommand extends GameCommand:
	func _init(player: int = 0, command_payload: Dictionary = {}) -> void:
		super._init(player, OPEN_TYPE, command_payload)

	func validate(game_state: GameState) -> String:
		var base: String = super.validate(game_state)
		if not base.is_empty():
			return base
		if game_state.timing_window_state.active:
			return "A fixture timing window is already active."
		if player_index < 0 or player_index >= Constants.PLAYER_COUNT:
			return "Invalid fixture controller."
		return ""

	func execute(game_state: GameState) -> Dictionary:
		var context: Dictionary = {
			TimingWindowState.CONTINUATION_KEY_ID: CONTINUATION_TYPE,
			TimingWindowState.CONTINUATION_KEY_RESUME_POINT:
					"attack_after_modify",
			TimingWindowState.CONTINUATION_KEY_SOURCE_ID: "fixture-attack",
			TimingWindowState.CONTINUATION_KEY_SOURCE_TYPE: "current_attack",
			TimingWindowState.CONTINUATION_KEY_OWNER_PLAYER: player_index,
		}
		return ORCHESTRATOR.open_window(
				game_state, DEFINITIONS.ATTACK_MODIFY, sequence, context)


class ResolveFixtureOpportunityCommand extends GameCommand:
	func _init(player: int = 0,
			type: String = USE_TYPE,
			command_payload: Dictionary = {}) -> void:
		super._init(player, type, command_payload)

	func validate(game_state: GameState) -> String:
		var common: String = _validate_fixture_opportunity(game_state)
		if not common.is_empty():
			return common
		if command_type != USE_TYPE and command_type != DECLINE_TYPE:
			return "Unsupported fixture opportunity command."
		return ""

	func _validate_fixture_opportunity(game_state: GameState) -> String:
		if game_state == null:
			return "No active game state."
		if game_state.current_phase != Constants.GamePhase.SHIP \
				and game_state.current_phase != Constants.GamePhase.SQUADRON:
			return "Fixture opportunity is outside an attack phase."
		var flow: InteractionFlow = game_state.interaction_flow
		if flow == null or flow.flow_type != Constants.InteractionFlow.ATTACK \
				or flow.step_id != Constants.InteractionStep.ATTACK_MODIFY:
			return "Fixture opportunity is outside Attack Modify."
		var timing_state: TimingWindowState = game_state.timing_window_state
		if not timing_state.active \
				or timing_state.timing_window_id != DEFINITIONS.ATTACK_MODIFY:
			return "No matching fixture timing window is active."
		if str(payload.get("lifecycle_id", "")) != timing_state.lifecycle_id:
			return "Stale fixture timing lifecycle."
		if player_index != timing_state.controller_player:
			return "Wrong fixture controller."
		if str(payload.get("source_owner_kind", "")) \
				!= PARTICIPANT.SOURCE_OWNER_KIND:
			return "Wrong fixture source-owner kind."
		var source_id: String = str(payload.get("runtime_source_id", ""))
		if source_id.is_empty() \
				or not PARTICIPANT.has_source(game_state, source_id):
			return "Missing fixture runtime source."
		if str(payload.get("semantic_key", "")) != PARTICIPANT.SEMANTIC_KEY:
			return "Wrong fixture semantic opportunity key."
		var resolved: Dictionary = game_state.objectives.get(
				PARTICIPANT.RESOLVED_KEY, {})
		if bool(resolved.get(source_id, false)):
			return "Fixture opportunity already resolved."
		return ""

	func execute(game_state: GameState) -> Dictionary:
		var source_id: String = str(payload.get("runtime_source_id", ""))
		var resolved: Dictionary = game_state.objectives.get(
				PARTICIPANT.RESOLVED_KEY, {}).duplicate(true)
		resolved[source_id] = true
		game_state.objectives[PARTICIPANT.RESOLVED_KEY] = resolved
		game_state.objectives[MUTATION_COUNT_KEY] = int(
				game_state.objectives.get(MUTATION_COUNT_KEY, 0)) + 1
		return {
			"success": true,
			"resolution": "used" if command_type == USE_TYPE else "declined",
			"runtime_source_id": source_id,
		}


class ContinueFixtureWindowCommand extends GameCommand:
	func _init(player: int = 0, command_payload: Dictionary = {}) -> void:
		super._init(player, CONTINUATION_TYPE, command_payload)

	func validate(game_state: GameState) -> String:
		var base: String = super.validate(game_state)
		if not base.is_empty():
			return base
		var timing_state: TimingWindowState = game_state.timing_window_state
		if not timing_state.active \
				or timing_state.status != TimingWindowState.STATUS_CLOSING:
			return "Fixture timing window is not awaiting continuation."
		if str(payload.get("lifecycle_id", "")) != timing_state.lifecycle_id:
			return "Stale fixture continuation lifecycle."
		if player_index != timing_state.controller_player:
			return "Wrong fixture continuation controller."
		var derivation: Dictionary = ORCHESTRATOR.derive_current_opportunities(
				game_state)
		if not bool(derivation.get(ORCHESTRATOR.KEY_OK, false)):
			return "Fixture continuation derivation failed."
		if not (derivation.get(ORCHESTRATOR.KEY_OPPORTUNITIES) as Array).is_empty():
			return "Fixture continuation is blocked."
		if bool(game_state.objectives.get(CONTINUATION_FAILURE_KEY, false)):
			return "Fixture continuation forced to reject."
		return ""

	func execute(game_state: GameState) -> Dictionary:
		game_state.objectives[COMPLETED_KEY] = true
		game_state.objectives[PARTICIPANT.RESOLVED_KEY] = {}
		return {"success": true, "fixture_continued": true}


class CancelFixtureWindowCommand extends GameCommand:
	func _init(player: int = 0, command_payload: Dictionary = {}) -> void:
		super._init(player, CANCEL_TYPE, command_payload)

	func validate(game_state: GameState) -> String:
		var base: String = super.validate(game_state)
		if not base.is_empty():
			return base
		var timing_state: TimingWindowState = game_state.timing_window_state
		if not timing_state.active:
			return "No fixture timing window is active."
		if str(payload.get("lifecycle_id", "")) != timing_state.lifecycle_id:
			return "Stale fixture cancellation lifecycle."
		if player_index != timing_state.controller_player:
			return "Wrong fixture cancellation controller."
		return ""

	func execute(game_state: GameState) -> Dictionary:
		game_state.objectives[PARTICIPANT.RESOLVED_KEY] = {}
		var result: Dictionary = ORCHESTRATOR.cancel_window(
				game_state, str(payload.get("lifecycle_id", "")))
		result["fixture_cancelled"] = bool(result.get(ORCHESTRATOR.KEY_OK, false))
		return result


class AddFixtureBlockerCommand extends GameCommand:
	func _init(player: int = 0, command_payload: Dictionary = {}) -> void:
		super._init(player, FOLLOWUP_TYPE, command_payload)

	func execute(game_state: GameState) -> Dictionary:
		var source_id: String = str(payload.get("runtime_source_id", "late-source"))
		var sources: Array = game_state.objectives.get(
				PARTICIPANT.SOURCES_KEY, []).duplicate()
		if not sources.has(source_id):
			sources.append(source_id)
		game_state.objectives[PARTICIPANT.SOURCES_KEY] = sources
		return {"success": true, "runtime_source_id": source_id}
