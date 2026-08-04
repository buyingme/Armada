## Concentrate Fire token Attack Modify participant.
##
## The participant derives one optional blocking opportunity from the
## authoritative attacking ship, its Concentrate Fire token, and canonical
## CurrentAttackState. It owns no lifecycle, opportunity cache, or mutation.
class_name ConcentrateFireTokenRule
extends RefCounted


const SCRIPT_PATH: String = \
		"res://src/core/effects/rules/concentrate_fire_token.gd"
const CAPABILITY_ID: String = "command_token.concentrate_fire"
const SOURCE_OWNER_KIND: String = "ship_command_token"
const SEMANTIC_KEY: String = "concentrate_fire_token_reroll"
const DISPLAY_KEY: String = "command_token.concentrate_fire"

const USE_COMMAND_TYPE: String = "use_concentrate_fire_token_reroll"
const DECLINE_COMMAND_TYPE: String = "decline_concentrate_fire_token_reroll"

const PAYLOAD_ATTACK_ID: String = "attack_id"
const PAYLOAD_ATTACKING_SHIP_ID: String = "attacking_ship_id"


static func register() -> void:
	var rule_script: GDScript = load(SCRIPT_PATH) as GDScript
	RuleRegistry.register_timing_window_participant({
		RuleRegistry.PARTICIPANT_KEY_CAPABILITY_ID: CAPABILITY_ID,
		RuleRegistry.PARTICIPANT_KEY_WINDOW: TimingWindowDefinitions.ATTACK_MODIFY,
		RuleRegistry.PARTICIPANT_KEY_SOURCE_OWNER_KIND: SOURCE_OWNER_KIND,
		RuleRegistry.PARTICIPANT_KEY_RULE_SCRIPT: rule_script,
		RuleRegistry.PARTICIPANT_KEY_DIAGNOSTIC_ID:
				"concentrate-fire-token-reroll",
	})


static func enumerate_timing_window_sources(game_state: GameState,
		timing_state: TimingWindowState) -> Variant:
	var source: Dictionary = pending_source(game_state, timing_state)
	if source.is_empty():
		return []
	return [{
		TimingWindowOpportunity.KEY_SOURCE_OWNER_KIND: SOURCE_OWNER_KIND,
		TimingWindowOpportunity.KEY_RUNTIME_SOURCE_ID:
				str(source.get("runtime_source_id", "")),
	}]


static func derive_timing_window_opportunities(game_state: GameState,
		timing_state: TimingWindowState,
		source_owner_kind: String,
		runtime_source_id: String) -> Variant:
	var source: Dictionary = pending_source(game_state, timing_state)
	if source.is_empty() \
			or source_owner_kind != SOURCE_OWNER_KIND \
			or runtime_source_id != str(source.get("runtime_source_id", "")):
		return []
	var identity_payload: Dictionary = {
		TimingWindowOrchestrator.COMMAND_KEY_TIMING_WINDOW_ID:
				timing_state.timing_window_id,
		TimingWindowOrchestrator.COMMAND_KEY_LIFECYCLE_ID:
				timing_state.lifecycle_id,
		TimingWindowOpportunity.KEY_SOURCE_OWNER_KIND: SOURCE_OWNER_KIND,
		TimingWindowOpportunity.KEY_RUNTIME_SOURCE_ID: runtime_source_id,
		TimingWindowOpportunity.KEY_SEMANTIC_KEY: SEMANTIC_KEY,
		PAYLOAD_ATTACK_ID: str(source.get(PAYLOAD_ATTACK_ID, "")),
		PAYLOAD_ATTACKING_SHIP_ID:
				str(source.get(PAYLOAD_ATTACKING_SHIP_ID, "")),
	}
	var opportunity: Dictionary = TimingWindowOpportunity.create({
		TimingWindowOpportunity.KEY_CAPABILITY_ID: CAPABILITY_ID,
		TimingWindowOpportunity.KEY_SOURCE_OWNER_KIND: SOURCE_OWNER_KIND,
		TimingWindowOpportunity.KEY_RUNTIME_SOURCE_ID: runtime_source_id,
		TimingWindowOpportunity.KEY_SEMANTIC_KEY: SEMANTIC_KEY,
		TimingWindowOpportunity.KEY_CONTROLLER_PLAYER:
				timing_state.controller_player,
		TimingWindowOpportunity.KEY_RESOLUTION_KIND:
				TimingWindowOpportunity.RESOLUTION_OPTIONAL,
		TimingWindowOpportunity.KEY_BLOCKING: true,
		TimingWindowOpportunity.KEY_USE_INTENT: {
			TimingWindowOpportunity.INTENT_KEY_COMMAND_TYPE: USE_COMMAND_TYPE,
			TimingWindowOpportunity.INTENT_KEY_PLAYER:
					timing_state.controller_player,
			TimingWindowOpportunity.INTENT_KEY_PAYLOAD:
					identity_payload.duplicate(true),
		},
		TimingWindowOpportunity.KEY_DECLINE_INTENT: {
			TimingWindowOpportunity.INTENT_KEY_COMMAND_TYPE:
					DECLINE_COMMAND_TYPE,
			TimingWindowOpportunity.INTENT_KEY_PLAYER:
					timing_state.controller_player,
			TimingWindowOpportunity.INTENT_KEY_PAYLOAD:
					identity_payload.duplicate(true),
		},
	})
	return [opportunity] if not opportunity.is_empty() else null


## Concentrate Fire token information is public; interaction remains limited
## to the authoritative timing-window controller by UIProjector.
static func project_timing_window_opportunity(_game_state: GameState,
		_timing_state: TimingWindowState,
		opportunity: Dictionary,
		_viewer_player: int) -> Dictionary:
	if str(opportunity.get(
			TimingWindowOpportunity.KEY_CAPABILITY_ID, "")) != CAPABILITY_ID:
		return {}
	return {
		"visible": true,
		"source_visible": true,
		"display_key": DISPLAY_KEY,
	}


## Returns the one currently legal authoritative source, or an empty result.
static func pending_source(game_state: GameState,
		timing_state: TimingWindowState) -> Dictionary:
	if game_state == null or timing_state == null \
			or not timing_state.active \
			or timing_state.timing_window_id \
					!= TimingWindowDefinitions.ATTACK_MODIFY:
		return {}
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack == null or not attack.active \
			or attack.stage != CurrentAttackState.STAGE_ATTACK_MODIFY \
			or attack.attacker_kind != CurrentAttackState.KIND_SHIP \
			or attack.cf_token_resolution \
					!= CurrentAttackState.RESOLUTION_PENDING:
		return {}
	var context: Dictionary = timing_state.continuation_context
	if timing_state.controller_player != attack.attacker_player \
			or str(context.get(
				TimingWindowState.CONTINUATION_KEY_SOURCE_ID, "")) \
					!= attack.attack_id \
			or str(context.get(
				TimingWindowState.CONTINUATION_KEY_SOURCE_TYPE, "")) \
					!= "current_attack" \
			or int(context.get(
				TimingWindowState.CONTINUATION_KEY_OWNER_PLAYER, -1)) \
					!= attack.attacker_player:
		return {}
	var ship: ShipInstance = game_state.get_ship(
			attack.attacker_player, attack.attacker_index)
	if ship == null or ship.command_tokens == null \
			or not ship.command_tokens.has_token(
				Constants.CommandType.CONCENTRATE_FIRE):
		return {}
	var ship_id: String = attacking_ship_identity(attack)
	return {
		"ship": ship,
		PAYLOAD_ATTACK_ID: attack.attack_id,
		PAYLOAD_ATTACKING_SHIP_ID: ship_id,
		"runtime_source_id": token_source_identity(ship_id),
	}


## Validates the common identity and ownership boundary for use and decline.
static func validate_resolution_context(game_state: GameState,
		acting_player: int,
		payload: Dictionary) -> String:
	if game_state == null:
		return "No active game state."
	if game_state.current_phase != Constants.GamePhase.SHIP \
			and game_state.current_phase != Constants.GamePhase.SQUADRON:
		return "Concentrate Fire token reroll is outside an attack phase."
	var flow: InteractionFlow = game_state.interaction_flow
	if flow == null or flow.flow_type != Constants.InteractionFlow.ATTACK \
			or flow.step_id != Constants.InteractionStep.ATTACK_MODIFY:
		return "Concentrate Fire token reroll is outside Attack Modify."
	var timing: TimingWindowState = game_state.timing_window_state
	if timing == null or not timing.active \
			or timing.timing_window_id != TimingWindowDefinitions.ATTACK_MODIFY:
		return "No shared Attack Modify lifecycle is active."
	if timing.status != TimingWindowState.STATUS_OPEN:
		return "Shared Attack Modify lifecycle is not accepting choices."
	if str(payload.get(
			TimingWindowOrchestrator.COMMAND_KEY_TIMING_WINDOW_ID, "")) \
				!= timing.timing_window_id:
		return "Wrong timing-window type."
	if str(payload.get(
			TimingWindowOrchestrator.COMMAND_KEY_LIFECYCLE_ID, "")) \
				!= timing.lifecycle_id:
		return "Stale timing-window lifecycle identity."
	if acting_player != timing.controller_player:
		return "Concentrate Fire token choice belongs to player %d." \
				% timing.controller_player
	var source: Dictionary = pending_source(game_state, timing)
	if source.is_empty():
		return "Concentrate Fire token reroll is not pending."
	if str(payload.get(PAYLOAD_ATTACK_ID, "")) \
			!= str(source.get(PAYLOAD_ATTACK_ID, "")):
		return "Stale current-attack identity."
	if str(payload.get(PAYLOAD_ATTACKING_SHIP_ID, "")) \
			!= str(source.get(PAYLOAD_ATTACKING_SHIP_ID, "")):
		return "Stale attacking-ship identity."
	if str(payload.get(
			TimingWindowOpportunity.KEY_SOURCE_OWNER_KIND, "")) \
				!= SOURCE_OWNER_KIND:
		return "Wrong Concentrate Fire source-owner kind."
	if str(payload.get(
			TimingWindowOpportunity.KEY_RUNTIME_SOURCE_ID, "")) \
				!= str(source.get("runtime_source_id", "")):
		return "Stale Concentrate Fire token source identity."
	if str(payload.get(TimingWindowOpportunity.KEY_SEMANTIC_KEY, "")) \
			!= SEMANTIC_KEY:
		return "Wrong Concentrate Fire semantic opportunity key."
	return ""


static func attacking_ship_identity(attack: CurrentAttackState) -> String:
	if attack == null or not attack.active \
			or attack.attacker_kind != CurrentAttackState.KIND_SHIP:
		return ""
	return "%d:ship:%d" % [attack.attacker_player, attack.attacker_index]


static func token_source_identity(attacking_ship_id: String) -> String:
	if attacking_ship_id.is_empty():
		return ""
	return "%s:command_token:%d" % [
		attacking_ship_id,
		int(Constants.CommandType.CONCENTRATE_FIRE),
	]
