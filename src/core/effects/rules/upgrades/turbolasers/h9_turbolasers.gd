## H9 Turbolasers shared Attack Modify participant.
##
## Each equipped runtime upgrade is an independent optional blocker. The
## participant derives opportunities only; replayable commands own the dice
## mutation and the runtime-upgrade guard.
class_name H9TurbolasersRule
extends RefCounted


const SCRIPT_PATH: String = \
		"res://src/core/effects/rules/upgrades/turbolasers/h9_turbolasers.gd"
const DATA_KEY: String = "h9_turbolasers"
const CAPABILITY_ID: String = "upgrade.h9_turbolasers"
const SOURCE_OWNER_KIND: String = "runtime_ship_upgrade"
const SEMANTIC_KEY: String = "change_die_to_accuracy"
const DISPLAY_KEY: String = "upgrade.h9_turbolasers"

const USE_COMMAND_TYPE: String = "use_h9"
const DECLINE_COMMAND_TYPE: String = "decline_h9"

const PAYLOAD_ATTACK_ID: String = "attack_id"
const PAYLOAD_RUNTIME_UPGRADE_ID: String = "runtime_upgrade_id"
const PAYLOAD_TARGET_FACE: String = "target_face"

const RULE_STATE_GUARD: String = "h9_current_attack_resolution"
const GUARD_ATTACK_ID: String = "current_attack_id"
const GUARD_RESOLUTION: String = "resolution"
const RESOLUTION_USED: String = "used"
const RESOLUTION_DECLINED: String = "declined"


static func register() -> void:
	var rule_script: GDScript = load(SCRIPT_PATH) as GDScript
	RuleRegistry.register_timing_window_participant({
		RuleRegistry.PARTICIPANT_KEY_CAPABILITY_ID: CAPABILITY_ID,
		RuleRegistry.PARTICIPANT_KEY_WINDOW: TimingWindowDefinitions.ATTACK_MODIFY,
		RuleRegistry.PARTICIPANT_KEY_SOURCE_OWNER_KIND: SOURCE_OWNER_KIND,
		RuleRegistry.PARTICIPANT_KEY_RULE_SCRIPT: rule_script,
		RuleRegistry.PARTICIPANT_KEY_DIAGNOSTIC_ID: "h9-turbolasers",
	})


static func enumerate_timing_window_sources(game_state: GameState,
		timing_state: TimingWindowState) -> Variant:
	var attack_source: Dictionary = _attacking_ship_source(
			game_state, timing_state)
	if attack_source.is_empty():
		return []
	var ship: ShipInstance = attack_source.get("ship") as ShipInstance
	var sources: Array[Dictionary] = []
	for runtime_upgrade: Dictionary in ship.runtime_upgrades:
		if not _is_h9_source_on_ship(runtime_upgrade, ship):
			continue
		sources.append({
			TimingWindowOpportunity.KEY_SOURCE_OWNER_KIND: SOURCE_OWNER_KIND,
			TimingWindowOpportunity.KEY_RUNTIME_SOURCE_ID:
					str(runtime_upgrade.get("runtime_upgrade_id", "")),
		})
	return sources


static func derive_timing_window_opportunities(game_state: GameState,
		timing_state: TimingWindowState,
		source_owner_kind: String,
		runtime_source_id: String) -> Variant:
	if source_owner_kind != SOURCE_OWNER_KIND:
		return []
	var source: Dictionary = pending_source(
			game_state, timing_state, runtime_source_id)
	if bool(source.get("invalid_guard", false)):
		return null
	if source.is_empty():
		return []
	var attack: CurrentAttackState = game_state.current_attack_state
	var identity_payload: Dictionary = {
		TimingWindowOrchestrator.COMMAND_KEY_TIMING_WINDOW_ID:
				timing_state.timing_window_id,
		TimingWindowOrchestrator.COMMAND_KEY_LIFECYCLE_ID:
				timing_state.lifecycle_id,
		TimingWindowOpportunity.KEY_SOURCE_OWNER_KIND: SOURCE_OWNER_KIND,
		TimingWindowOpportunity.KEY_RUNTIME_SOURCE_ID: runtime_source_id,
		TimingWindowOpportunity.KEY_SEMANTIC_KEY: SEMANTIC_KEY,
		PAYLOAD_ATTACK_ID: attack.attack_id,
		PAYLOAD_RUNTIME_UPGRADE_ID: runtime_source_id,
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


## H9 is public. Fully formed use choices remain derived projection and are
## exposed only to the controller by UIProjector.
static func project_timing_window_opportunity(game_state: GameState,
		timing_state: TimingWindowState,
		opportunity: Dictionary,
		_viewer_player: int) -> Dictionary:
	if str(opportunity.get(
			TimingWindowOpportunity.KEY_CAPABILITY_ID, "")) != CAPABILITY_ID:
		return {}
	var source_id: String = str(opportunity.get(
			TimingWindowOpportunity.KEY_RUNTIME_SOURCE_ID, ""))
	var source: Dictionary = pending_source(game_state, timing_state, source_id)
	if source.is_empty() or bool(source.get("invalid_guard", false)):
		return {}
	var base_intent: Dictionary = (opportunity.get(
			TimingWindowOpportunity.KEY_USE_INTENT, {}) as Dictionary).duplicate(true)
	var choices: Array[Dictionary] = []
	for die_index: int in eligible_die_indices(
			game_state.current_attack_state.dice_results):
		var selected: Dictionary = game_state.current_attack_state.dice_results[
				die_index]
		var intent: Dictionary = base_intent.duplicate(true)
		var intent_payload: Dictionary = (intent.get(
				TimingWindowOpportunity.INTENT_KEY_PAYLOAD, {}) \
				as Dictionary).duplicate(true)
		intent_payload["die_index"] = die_index
		intent_payload["expected_color"] = int(selected.get("color", -1))
		intent_payload["expected_face"] = int(selected.get("face", -1))
		intent_payload[PAYLOAD_TARGET_FACE] = int(Constants.DiceFace.ACCURACY)
		intent[TimingWindowOpportunity.INTENT_KEY_PAYLOAD] = intent_payload
		choices.append({
			"label": "Die %d to Accuracy" % (die_index + 1),
			"intent": intent,
		})
	return {
		"visible": true,
		"source_visible": true,
		"display_key": DISPLAY_KEY,
		"use_choices": choices,
	}


## Returns one currently legal source, an invalid-guard marker, or empty.
static func pending_source(game_state: GameState,
		timing_state: TimingWindowState,
		runtime_upgrade_id: String) -> Dictionary:
	var attack_source: Dictionary = _attacking_ship_source(
			game_state, timing_state)
	if attack_source.is_empty() or runtime_upgrade_id.is_empty():
		return {}
	var ship: ShipInstance = attack_source.get("ship") as ShipInstance
	var runtime_upgrade: Dictionary = ship.get_runtime_upgrade(runtime_upgrade_id)
	if not _is_h9_source_on_ship(runtime_upgrade, ship):
		return {}
	var attack: CurrentAttackState = game_state.current_attack_state
	var guard: Dictionary = resolution_guard(runtime_upgrade)
	if not guard.is_empty():
		if not _valid_guard_shape(guard) \
				or str(guard.get(GUARD_ATTACK_ID, "")) != attack.attack_id:
			return {"invalid_guard": true}
		return {}
	if eligible_die_indices(attack.dice_results).is_empty():
		return {}
	return {
		"ship": ship,
		"runtime_upgrade": runtime_upgrade,
		PAYLOAD_ATTACK_ID: attack.attack_id,
		PAYLOAD_RUNTIME_UPGRADE_ID: runtime_upgrade_id,
	}


static func validate_resolution_context(game_state: GameState,
		acting_player: int,
		payload: Dictionary) -> String:
	if game_state == null:
		return "H9 Turbolasers requires a game state."
	if game_state.current_phase != Constants.GamePhase.SHIP \
			and game_state.current_phase != Constants.GamePhase.SQUADRON:
		return "H9 Turbolasers is outside an attack phase."
	var flow: InteractionFlow = game_state.interaction_flow
	if flow == null or flow.flow_type != Constants.InteractionFlow.ATTACK \
			or flow.step_id != Constants.InteractionStep.ATTACK_MODIFY:
		return "H9 Turbolasers is outside Attack Modify."
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
		return "H9 Turbolasers choice belongs to player %d." \
				% timing.controller_player
	var runtime_upgrade_id: String = str(payload.get(
			PAYLOAD_RUNTIME_UPGRADE_ID, ""))
	var source: Dictionary = pending_source(
			game_state, timing, runtime_upgrade_id)
	if source.is_empty() or bool(source.get("invalid_guard", false)):
		return "H9 Turbolasers opportunity is not pending."
	var attack: CurrentAttackState = game_state.current_attack_state
	if str(payload.get(PAYLOAD_ATTACK_ID, "")) != attack.attack_id:
		return "Stale current-attack identity."
	if str(payload.get(
			TimingWindowOpportunity.KEY_SOURCE_OWNER_KIND, "")) \
				!= SOURCE_OWNER_KIND:
		return "Wrong H9 source-owner kind."
	if str(payload.get(
			TimingWindowOpportunity.KEY_RUNTIME_SOURCE_ID, "")) \
				!= runtime_upgrade_id:
		return "Stale H9 runtime source identity."
	if str(payload.get(TimingWindowOpportunity.KEY_SEMANTIC_KEY, "")) \
			!= SEMANTIC_KEY:
		return "Wrong H9 semantic opportunity key."
	return ""


static func eligible_die_indices(
		dice_results: Array[Dictionary]) -> Array[int]:
	var indices: Array[int] = []
	for die_index: int in range(dice_results.size()):
		var result: Dictionary = dice_results[die_index]
		var color: int = int(result.get("color", -1))
		var face: int = int(result.get("face", -1))
		if _face_has_hit_or_critical(face) and _color_has_accuracy(color):
			indices.append(die_index)
	return indices


static func selected_die_reason(selected: Dictionary,
		target_face: int) -> String:
	var color: int = int(selected.get("color", -1))
	var face: int = int(selected.get("face", -1))
	if not _face_has_hit_or_critical(face):
		return "Selected die has no Hit or Critical icon."
	if target_face != int(Constants.DiceFace.ACCURACY):
		return "H9 target face must be Accuracy."
	if not _color_has_accuracy(color):
		return "Selected die color has no Accuracy face."
	return ""


static func resolution_guard(runtime_upgrade: Dictionary) -> Dictionary:
	var rule_state: Dictionary = _dict_from(runtime_upgrade.get("rule_state", {}))
	return _dict_from(rule_state.get(RULE_STATE_GUARD, {}))


static func write_resolution_guard(runtime_upgrade: Dictionary,
		attack_id: String,
		resolution: String) -> bool:
	if runtime_upgrade.is_empty() or attack_id.is_empty() \
			or not [RESOLUTION_USED, RESOLUTION_DECLINED].has(resolution):
		return false
	var rule_state: Dictionary = _dict_from(runtime_upgrade.get("rule_state", {}))
	rule_state[RULE_STATE_GUARD] = {
		GUARD_ATTACK_ID: attack_id,
		GUARD_RESOLUTION: resolution,
	}
	runtime_upgrade["rule_state"] = rule_state
	return resolution_guard(runtime_upgrade) == rule_state[RULE_STATE_GUARD]


## Clears matching H9 state at an accepted enclosing command boundary.
static func clear_attack_guards(game_state: GameState,
		attack_id: String) -> Array[String]:
	var cleared: Array[String] = []
	if game_state == null or attack_id.is_empty():
		return cleared
	for player_index: int in range(game_state.player_states.size()):
		var player_state: PlayerState = game_state.get_player_state(player_index)
		if player_state == null:
			continue
		for ship_var: Variant in player_state.ships:
			var ship: ShipInstance = ship_var as ShipInstance
			if ship == null:
				continue
			for runtime_upgrade: Dictionary in ship.runtime_upgrades:
				if str(runtime_upgrade.get("data_key", "")) != DATA_KEY:
					continue
				var guard: Dictionary = resolution_guard(runtime_upgrade)
				if str(guard.get(GUARD_ATTACK_ID, "")) != attack_id:
					continue
				var rule_state: Dictionary = _dict_from(
						runtime_upgrade.get("rule_state", {}))
				rule_state.erase(RULE_STATE_GUARD)
				runtime_upgrade["rule_state"] = rule_state
				cleared.append(str(runtime_upgrade.get("runtime_upgrade_id", "")))
	return cleared


## Rejects reconstructed rule guards that do not have their exact enclosing
## canonical attack and shared timing lifecycle.
static func validate_reconstructed_state(game_state: GameState) -> String:
	if game_state == null:
		return "Missing game state for H9 reconstruction."
	for player_index: int in range(game_state.player_states.size()):
		var player_state: PlayerState = game_state.get_player_state(player_index)
		if player_state == null:
			continue
		for ship_var: Variant in player_state.ships:
			var ship: ShipInstance = ship_var as ShipInstance
			if ship == null:
				continue
			for runtime_upgrade: Dictionary in ship.runtime_upgrades:
				if str(runtime_upgrade.get("data_key", "")) != DATA_KEY:
					continue
				var guard: Dictionary = resolution_guard(runtime_upgrade)
				if guard.is_empty():
					continue
				if not _valid_guard_shape(guard):
					return "Invalid H9 current-attack guard."
				var reason: String = _reconstructed_guard_reason(
						game_state, ship, runtime_upgrade, guard)
				if not reason.is_empty():
					return reason
	return ""


static func _attacking_ship_source(game_state: GameState,
		timing_state: TimingWindowState) -> Dictionary:
	if game_state == null or timing_state == null or not timing_state.active \
			or timing_state.timing_window_id \
					!= TimingWindowDefinitions.ATTACK_MODIFY:
		return {}
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack == null or not attack.active \
			or attack.stage != CurrentAttackState.STAGE_ATTACK_MODIFY \
			or attack.attacker_kind != CurrentAttackState.KIND_SHIP:
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
	if ship == null or ship.is_destroyed():
		return {}
	return {"ship": ship, "attack": attack}


static func _is_h9_source_on_ship(runtime_upgrade: Dictionary,
		ship: ShipInstance) -> bool:
	if runtime_upgrade.is_empty() or ship == null \
			or str(runtime_upgrade.get("data_key", "")) != DATA_KEY \
			or int(runtime_upgrade.get("owner_player_id", -1)) \
					!= ship.owner_player \
			or str(runtime_upgrade.get("source_roster_entry_id", "")) \
					!= ship.roster_entry_id:
		return false
	var card_state: Dictionary = _dict_from(
			runtime_upgrade.get("card_state", {}))
	return not bool(card_state.get("discarded", false)) \
			and not bool(card_state.get("disabled", false))


static func _reconstructed_guard_reason(game_state: GameState,
		ship: ShipInstance,
		runtime_upgrade: Dictionary,
		guard: Dictionary) -> String:
	var attack: CurrentAttackState = game_state.current_attack_state
	var timing: TimingWindowState = game_state.timing_window_state
	if attack == null or not attack.active \
			or attack.stage != CurrentAttackState.STAGE_ATTACK_MODIFY \
			or attack.attacker_kind != CurrentAttackState.KIND_SHIP \
			or str(guard.get(GUARD_ATTACK_ID, "")) != attack.attack_id:
		return "H9 guard has no matching current attack."
	if timing == null or not timing.active \
			or timing.timing_window_id != TimingWindowDefinitions.ATTACK_MODIFY \
			or not [TimingWindowState.STATUS_OPEN,
				TimingWindowState.STATUS_CLOSING].has(timing.status):
		return "H9 guard has no matching Attack Modify lifecycle."
	if game_state.get_ship(attack.attacker_player, attack.attacker_index) != ship \
			or not _is_h9_source_on_ship(runtime_upgrade, ship):
		return "H9 guard source does not match the attacking ship."
	var context: Dictionary = timing.continuation_context
	if str(context.get(TimingWindowState.CONTINUATION_KEY_SOURCE_ID, "")) \
			!= attack.attack_id \
			or timing.controller_player != attack.attacker_player:
		return "H9 guard conflicts with timing lifecycle identity."
	return ""


static func _valid_guard_shape(guard: Dictionary) -> bool:
	if guard.size() != 2 \
			or typeof(guard.get(GUARD_ATTACK_ID)) != TYPE_STRING \
			or str(guard.get(GUARD_ATTACK_ID, "")).is_empty() \
			or typeof(guard.get(GUARD_RESOLUTION)) != TYPE_STRING:
		return false
	for raw_key: Variant in guard.keys():
		if typeof(raw_key) != TYPE_STRING \
				or not [GUARD_ATTACK_ID, GUARD_RESOLUTION].has(str(raw_key)):
			return false
	return [RESOLUTION_USED, RESOLUTION_DECLINED].has(
			str(guard.get(GUARD_RESOLUTION, "")))


static func _face_has_hit_or_critical(face: int) -> bool:
	return face in [
		int(Constants.DiceFace.HIT),
		int(Constants.DiceFace.CRITICAL),
		int(Constants.DiceFace.HIT_CRITICAL),
		int(Constants.DiceFace.HIT_HIT),
	]


static func _color_has_accuracy(color: int) -> bool:
	if not Dice.DICE_FACES.has(color):
		return false
	return (Dice.DICE_FACES[color] as Array).has(Constants.DiceFace.ACCURACY)


static func _dict_from(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) \
			if value is Dictionary else {}
