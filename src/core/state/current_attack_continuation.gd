## Derives deterministic current-attack follow-ups from authoritative state.
##
## This stateless helper is invoked only from CommandProcessor's existing
## post-success/deferred-follow-up seam. It reads only canonical GameState
## facts, including the accepted Counter-choice projection; it never reads
## scene state, network ownership, or presentation-local references.
class_name CurrentAttackContinuation
extends RefCounted


const MODE_LIVE_AUTHORITY: String = "live_authority"
const MODE_NETWORK_MIRROR: String = "network_mirror"
const MODE_REPLAY: String = "replay"
const MODE_RECONSTRUCTION: String = "reconstruction"

const KEY_OK: String = "ok"
const KEY_REASON: String = "reason"
const KEY_CONTINUATION: String = "continuation"


## Returns no command or exactly one deterministic semantic follow-up.
## Passive modes inspect the same accepted state but never synthesize commands.
static func process_successful_command(game_state: GameState,
		command: GameCommand,
		result: Dictionary,
		execution_mode: String) -> Dictionary:
	if execution_mode not in [
		MODE_LIVE_AUTHORITY,
		MODE_NETWORK_MIRROR,
		MODE_REPLAY,
		MODE_RECONSTRUCTION,
	]:
		return _failure("Unknown current-attack execution mode.")
	if game_state == null or command == null:
		return _success()
	var continuation: GameCommand = _derive_followup(game_state, command, result)
	if execution_mode != MODE_LIVE_AUTHORITY:
		continuation = null
	return _success(continuation)


## Re-evaluates only the durable completed-result release state after a fully
## validated save/load or reconnect installation. It intentionally returns an
## existing consumer command or no command; it never records a synthetic
## acknowledgement or continuation descriptor.
static func derive_reconstructed_inspection_release(
		game_state: GameState) -> GameCommand:
	if game_state == null:
		return null
	return _derive_inspection_release(game_state)


## A released faceup inspection leaves the existing resolved Attack owner
## durable even when the in-memory follow-up queue was lost on reconstruction.
static func derive_reconstructed_resolved_attack(
		game_state: GameState) -> GameCommand:
	if game_state == null:
		return null
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack == null or not attack.active \
			or attack.stage != CurrentAttackState.STAGE_RESOLVED:
		return null
	if attack.counter_disposition != CurrentAttackState.COUNTER_UNDECIDED:
		return _derive_decided_counter_parent(game_state, attack)
	if counter_opportunity(game_state, attack):
		return _build_counter_publication(game_state, attack)
	if _post_damage_decision_pending(game_state, attack):
		return null
	return _build_complete_attack(attack)


## Reads only the existing Attack and Squadron owners. A scene token or flow
## affordance cannot establish Counter eligibility.
static func counter_opportunity(game_state: GameState,
		attack: CurrentAttackState) -> bool:
	if game_state == null or attack == null or not attack.active \
			or attack.attacker_kind != CurrentAttackState.KIND_SQUADRON \
			or attack.defender_kind != CurrentAttackState.KIND_SQUADRON \
			or attack.counter_disposition \
					!= CurrentAttackState.COUNTER_UNDECIDED:
		return false
	return CounterKeyword.is_counter_trigger_available(
			attack.attack_kind,
			game_state.get_squadron(attack.attacker_player,
					attack.attacker_index),
			game_state.get_squadron(attack.defender_player,
					attack.defender_index))


## Detached prospective publication. The command's accepted validation is
## the only route that installs this Counter projection.
static func _build_counter_publication(game_state: GameState,
		attack: CurrentAttackState) -> PublishAttackFlowCommand:
	if attack.stage != CurrentAttackState.STAGE_RESOLVED \
			or attack.damage_stage != CurrentAttackState.DAMAGE_RESOLVED \
			or game_state.completed_attack_inspection != null \
			or game_state.faceup_damage_inspection != null \
			or not counter_opportunity(game_state, attack):
		return null
	var installed: InteractionFlow = game_state.interaction_flow
	if installed == null or (installed.flow_type \
			== Constants.InteractionFlow.ATTACK and installed.step_id \
			== Constants.InteractionStep.ATTACK_COUNTER_CHOICE):
		return null
	var outcome: Dictionary = attack.resolved_outcome
	if outcome.get("target_kind") != CurrentAttackState.KIND_SQUADRON \
			or typeof(outcome.get("requested_hull_damage")) != TYPE_INT \
			or int(outcome["requested_hull_damage"]) < 0:
		return null
	var original: SquadronInstance = game_state.get_squadron(
			attack.attacker_player, attack.attacker_index)
	var counter: SquadronInstance = game_state.get_squadron(
			attack.defender_player, attack.defender_index)
	if original == null or counter == null:
		return null
	var blue_count: int = SquadronKeywordRuleHelper.get_keyword_value(
			counter, SquadronKeywordRuleHelper.KEYWORD_COUNTER)
	if blue_count <= 0:
		return null
	var projected: Dictionary = {}
	if installed.flow_type == Constants.InteractionFlow.ATTACK:
		projected = installed.payload.duplicate(true)
	projected.merge({
		"attack_id": attack.attack_id,
		"attacker_kind": attack.attacker_kind,
		"attacker_player": attack.attacker_player,
		"attacker_squadron_index": attack.attacker_index,
		"attacker_zone": attack.attacker_zone,
		"target_kind": attack.defender_kind,
		"defender_player": attack.defender_player,
		"target_squadron_index": attack.defender_index,
		"defender_zone": attack.defender_zone,
		"attack_kind": attack.attack_kind,
		"range_band": attack.range_band,
		"dice_pool": attack.dice_pool,
		"dice_results": attack.dice_results,
		"locked_tokens": attack.accuracy_locked_tokens,
		"attacker_name": original.squadron_data.squadron_name,
		"defender_name": counter.squadron_data.squadron_name,
		"final_damage": outcome["requested_hull_damage"],
		"counter_attack_available": true,
		"counter_controller_player": attack.defender_player,
		"controller_player": attack.defender_player,
		"counter_attacker_player": attack.defender_player,
		"counter_attacker_squadron_index": attack.defender_index,
		"counter_target_player": attack.attacker_player,
		"counter_target_squadron_index": attack.attacker_index,
		"counter_dice_pool": {"BLUE": blue_count},
	}, true)
	projected.erase("counter_choice_accepted")
	var prospective: InteractionFlow = FlowSpec.make_interaction_flow(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_COUNTER_CHOICE,
			game_state, {"attacker_player": attack.attacker_player,
				"defender_player": attack.defender_player,
				"controller_player": attack.defender_player},
			Constants.Visibility.ALL, projected)
	var publication: PublishAttackFlowCommand = GameManager \
			.build_publish_attack_flow_command(game_state, prospective,
					attack.attacker_player)
	if publication == null or not publication.validate(game_state).is_empty():
		return null
	return publication


static func _derive_followup(game_state: GameState,
		command: GameCommand,
		result: Dictionary) -> GameCommand:
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack == null or not attack.active:
		if command.command_type == "skip_attack" \
				and str(command.payload.get("reason", "")) == "cancelled":
			return _derive_cancelled_attack_return(game_state, command, result)
		if command.command_type == "skip_attack" \
				and str(command.payload.get("reason", "")) in [
					SkipAttackCommand.REASON_SQUADRON_DONE,
					SkipAttackCommand.REASON_ANTI_SQUADRON_VOLUNTARY_DONE,
				]:
			return _derive_post_squadron_done_ship_return(game_state, command)
		return _derive_inspection_release(game_state)
	if command.command_type in [
		"commit_accuracy",
		"commit_defense",
		"spend_defense_token",
		"select_evade_die",
		"select_redirect_zone",
		"redirect_done",
	]:
		return _derive_defense_followup(
				game_state, attack, command, result)
	if command.command_type == "resolve_damage":
		if counter_opportunity(game_state, attack):
			return _build_counter_publication(game_state, attack)
		if not _post_damage_decision_pending(game_state, attack):
			return _build_complete_attack(attack)
	if command.command_type == "counter_choice" \
			and attack.stage == CurrentAttackState.STAGE_RESOLVED:
		return _derive_decided_counter_parent(game_state, attack)
	if command.command_type in ["resolve_immediate_effect",
			"acknowledge_faceup_damage"] \
			and attack.stage == CurrentAttackState.STAGE_RESOLVED \
			and not _post_damage_decision_pending(game_state, attack):
		return _build_complete_attack(attack)
	return null


## Reconstruction may rediscover the same command from the durable cancellation
## return identity, but only live authority submits it to the history.
static func derive_reconstructed_cancelled_attack_return(
		game_state: GameState) -> GameCommand:
	if game_state == null or game_state.current_attack_state.active \
			or game_state.completed_attack_inspection != null:
		return null
	var active_squadron: SquadronInstance = \
			game_state.get_active_squadron_activation()
	if active_squadron != null:
		var squadron_flow: InteractionFlow = game_state.interaction_flow
		var phase_return: bool = active_squadron.activation_context \
				== SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE \
				and game_state.current_phase == Constants.GamePhase.SQUADRON \
				and squadron_flow != null \
				and squadron_flow.flow_type \
					== Constants.InteractionFlow.SQUADRON_ACTIVATION \
				and squadron_flow.step_id \
					== Constants.InteractionStep.ACTION_CHOICE
		var commanded_return: bool = active_squadron.activation_context \
				== SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND \
				and game_state.current_phase == Constants.GamePhase.SHIP \
				and squadron_flow != null \
				and squadron_flow.flow_type \
					== Constants.InteractionFlow.SHIP_ACTIVATION \
				and squadron_flow.step_id \
					== Constants.InteractionStep.SQUADRON_STEP
		if (phase_return or commanded_return) \
				and game_state.is_squadron_activation_action_complete(
					active_squadron):
			return _build_complete_squadron_activation(
					game_state, active_squadron)
	var ship: ShipInstance = game_state.get_active_ship_activation()
	if ship == null:
		return null
	var flow: InteractionFlow = game_state.interaction_flow
	if flow == null or flow.flow_type \
			!= Constants.InteractionFlow.SHIP_ACTIVATION \
			or flow.step_id != Constants.InteractionStep.ATTACK_STEP \
			or not ship.attack_step_active:
		return null
	var marker: Dictionary = ship.pending_anti_squadron_cancellation_return()
	var ship_index: int = game_state.find_ship_index(ship)
	if ship_index < 0:
		return null
	if not marker.is_empty():
		if _has_remaining_anti_squadron_target(
				game_state, ship, ship.owner_player, ship_index):
			return null
		var payload: Dictionary = marker.duplicate(true)
		payload["reason"] = SkipAttackCommand.REASON_SQUADRON_DONE
		payload["ship_index"] = ship_index
		return SkipAttackCommand.new(ship.owner_player, payload)
	if ship.committed_attack_count <= 0 \
			or (ship.committed_attack_count < 2 \
				and _has_remaining_normal_ship_target(game_state, ship,
					ship.owner_player, ship_index)):
		return null
	return AdvanceActivationStepCommand.new(ship.owner_player, {
		"ship_index": ship_index,
		"step_id": "maneuver_step",
		"ship_activation_identity": ship.ship_activation_identity,
	})


static func _derive_cancelled_attack_return(game_state: GameState,
		command: GameCommand, result: Dictionary) -> GameCommand:
	var attacker_index: int = int(result.get("attacker_index", -1))
	if attacker_index < 0:
		return null
	if str(result.get("attacker_kind", "")) == CurrentAttackState.KIND_SQUADRON:
		var squadron: SquadronInstance = game_state.get_squadron(
				command.player_index, attacker_index)
		if squadron == null \
				or not game_state.is_squadron_activation_action_complete(squadron):
			return null
		return _build_complete_squadron_activation(game_state, squadron)
	var ship: ShipInstance = game_state.get_ship(
			command.player_index, attacker_index)
	if ship == null or not ship.attack_step_active:
		return null
	if ship.anti_squadron_attack_zone >= 0:
		return derive_reconstructed_cancelled_attack_return(game_state)
	return derive_reconstructed_cancelled_attack_return(game_state)


static func _build_complete_squadron_activation(game_state: GameState,
		squadron: SquadronInstance) -> GameCommand:
	var squadron_index: int = game_state.find_squadron_index(squadron)
	if squadron_index < 0 or squadron.activation_id.is_empty():
		return null
	var payload: Dictionary = {
		"squadron_index": squadron_index,
		"activation_id": squadron.activation_id,
		"activation_context": squadron.activation_context,
	}
	if squadron.activation_context \
			== SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND:
		var commanding_ship: ShipInstance = game_state.get_ship(
				squadron.commanding_ship_player,
				squadron.commanding_ship_index)
		if commanding_ship == null \
				or commanding_ship.ship_activation_identity.is_empty():
			return null
		payload["commanding_ship_player"] = squadron.commanding_ship_player
		payload["commanding_ship_index"] = squadron.commanding_ship_index
		payload["ship_activation_identity"] = \
				commanding_ship.ship_activation_identity
	return CompleteSquadronActivationCommand.new(squadron.owner_player, payload)


static func _derive_inspection_release(game_state: GameState) -> GameCommand:
	var inspection: CompletedAttackInspection = game_state.completed_attack_inspection
	if inspection == null or not inspection.is_satisfied():
		return null
	if inspection.counter_disposition() \
			== CurrentAttackState.COUNTER_ACCEPTED:
		return _derive_counter_inspection_release(game_state, inspection)
	var data: Dictionary = inspection.serialize()
	if str(data.get("attack_kind", "")) \
			== SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER:
		return _derive_counter_child_inspection_release(
				game_state, inspection, data)
	var attacker: Dictionary = data.get("attacker", {}) as Dictionary
	var attacker_kind: String = str(attacker.get("kind", ""))
	var attacker_player: int = int(attacker.get("player", -1))
	var attacker_index: int = int(attacker.get("index", -1))
	if attacker_kind == CurrentAttackState.KIND_SHIP:
		return _derive_ship_inspection_release(
				game_state, inspection, attacker_player, attacker_index)
	if attacker_kind == CurrentAttackState.KIND_SQUADRON:
		return _derive_squadron_inspection_release(
				game_state, inspection, attacker_player, attacker_index)
	return null


## A completed Counter child returns through the child defender's retained
## Squadron activation. The parent/child relationship was already validated by
## the authoritative Counter Begin; terminal state intentionally retains no
## historical parent attack identity.
static func _derive_counter_child_inspection_release(game_state: GameState,
		inspection: CompletedAttackInspection,
		data: Dictionary) -> GameCommand:
	if inspection == null or not inspection.is_satisfied() \
			or str(data.get("source_attack_id", "")) \
					!= inspection.source_attack_id():
		return null
	var defender: Dictionary = data.get("defender", {}) as Dictionary
	if str(defender.get("kind", "")) != CurrentAttackState.KIND_SQUADRON:
		return null
	var player: int = int(defender.get("player", -1))
	var squadron_index: int = int(defender.get("index", -1))
	var squadron: SquadronInstance = game_state.get_squadron(
			player, squadron_index)
	var active_squadron: SquadronInstance = \
			game_state.get_active_squadron_activation()
	if squadron == null or squadron.is_destroyed() \
			or squadron.activated_this_round \
			or squadron != active_squadron \
			or squadron.attack_action_disposition \
					!= SquadronInstance.ATTACK_ACTION_BEGUN \
			or not game_state.validate_declaration_adjacent_state() \
			or not _counter_child_activation_context_is_valid(
					game_state, squadron):
		return null
	if game_state.has_legal_remaining_squadron_move_action(squadron):
		# The decision is derived from canonical state. Its authoritative Move or
		# Move-decline command consumes J atomically.
		return null
	if not game_state.is_squadron_activation_action_complete(squadron):
		return null
	return _build_complete_squadron_activation_with_inspection(
			game_state, squadron, squadron_index, inspection.inspection_id())


static func _counter_child_activation_context_is_valid(game_state: GameState,
		squadron: SquadronInstance) -> bool:
	if squadron.activation_id.is_empty():
		return false
	if squadron.activation_context \
			== SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE:
		return game_state.current_phase == Constants.GamePhase.SQUADRON \
				and squadron.owner_player \
						== game_state.squadron_phase_controller_player
	if squadron.activation_context \
			!= SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND \
			or game_state.current_phase != Constants.GamePhase.SHIP:
		return false
	var ship: ShipInstance = game_state.get_ship(
			squadron.commanding_ship_player, squadron.commanding_ship_index)
	return ship != null \
			and ship == game_state.get_active_ship_activation() \
			and ship.owner_player == squadron.owner_player \
			and not ship.ship_activation_identity.is_empty() \
			and ship.squadron_command_opportunity_disposition \
					== ShipInstance.ACTIVATION_DISPOSITION_OPEN


static func _derive_counter_inspection_release(game_state: GameState,
		inspection: CompletedAttackInspection) -> GameCommand:
	var flow: InteractionFlow = game_state.interaction_flow
	if inspection.counter_disposition() \
			!= CurrentAttackState.COUNTER_ACCEPTED \
			or not CounterPublicationConsistency \
					.reconstructed_state_is_consistent(game_state) \
			or flow == null or flow.flow_type != Constants.InteractionFlow.ATTACK \
			or flow.step_id != Constants.InteractionStep.ATTACK_COUNTER_CHOICE \
			or inspection.source_attack_id() \
					!= str(flow.payload.get("attack_id", "")) \
			or not bool(flow.payload.get("counter_choice_accepted", false)):
		return null
	var keys: Array[String] = [
		"counter_attacker_player", "counter_attacker_squadron_index",
		"counter_target_player", "counter_target_squadron_index",
	]
	for key: String in keys:
		if typeof(flow.payload.get(key)) != TYPE_INT:
			return null
	var attacker_player: int = int(flow.payload["counter_attacker_player"])
	var attacker_index: int = int(
			flow.payload["counter_attacker_squadron_index"])
	var defender_player: int = int(flow.payload["counter_target_player"])
	var defender_index: int = int(flow.payload["counter_target_squadron_index"])
	var attacker: SquadronInstance = game_state.get_squadron(
			attacker_player, attacker_index)
	var defender: SquadronInstance = game_state.get_squadron(
			defender_player, defender_index)
	if attacker == null or defender == null or defender.is_destroyed():
		return null
	var inspection_data: Dictionary = inspection.serialize()
	var parent_attacker: Dictionary = inspection_data.get(
			"attacker", {}) as Dictionary
	var parent_defender: Dictionary = inspection_data.get(
			"defender", {}) as Dictionary
	if str(parent_attacker.get("kind", "")) \
			!= CurrentAttackState.KIND_SQUADRON \
			or int(parent_attacker.get("player", -1)) != defender_player \
			or int(parent_attacker.get("index", -1)) != defender_index \
			or str(parent_defender.get("kind", "")) \
					!= CurrentAttackState.KIND_SQUADRON \
			or int(parent_defender.get("player", -1)) != attacker_player \
			or int(parent_defender.get("index", -1)) != attacker_index:
		return null
	return _build_counter_child_begin(game_state, inspection.source_attack_id(),
			attacker_player, attacker_index, defender_player, defender_index,
			inspection.inspection_id())


static func _derive_decided_counter_parent(game_state: GameState,
		parent: CurrentAttackState) -> GameCommand:
	if parent == null or not parent.active \
			or parent.counter_disposition \
					== CurrentAttackState.COUNTER_UNDECIDED \
			or not CounterPublicationConsistency \
					.reconstructed_state_is_consistent(game_state):
		return null
	if parent.counter_disposition == CurrentAttackState.COUNTER_DECLINED:
		return _build_complete_attack(parent)
	if not game_state.get_distinct_controlling_principal_ids(
			MatchPlayerControlBinding.KIND_HUMAN).is_empty():
		return _build_complete_attack(parent)
	return _build_counter_child_begin(game_state, parent.attack_id,
			parent.defender_player, parent.defender_index,
			parent.attacker_player, parent.attacker_index, "")


static func _build_counter_child_begin(game_state: GameState,
		source_attack_id: String, attacker_player: int, attacker_index: int,
		defender_player: int, defender_index: int,
		inspection_id: String) -> GameCommand:
	var entry: Dictionary = TargetingListBuilder.authoritative_attack_entry(
			game_state, attacker_player, CurrentAttackState.KIND_SQUADRON,
			attacker_index, -1, defender_player,
			CurrentAttackState.KIND_SQUADRON, defender_index, -1)
	if entry.is_empty():
		return null
	return BeginAttackCommand.new(attacker_player, {
		"attacker_player": attacker_player,
		"attacker_kind": CurrentAttackState.KIND_SQUADRON,
		"attacker_index": attacker_index,
		"attacker_zone": -1,
		"defender_player": defender_player,
		"defender_kind": CurrentAttackState.KIND_SQUADRON,
		"defender_index": defender_index,
		"defender_zone": -1,
		"attack_kind": SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER,
		"counter_source_attack_id": source_attack_id,
		"range_band": str(entry.get("range_band", "")),
		"obstructed": bool(entry.get("obstructed", false)),
		"completed_attack_inspection_id": inspection_id,
	})


static func _derive_ship_inspection_release(game_state: GameState,
		inspection: CompletedAttackInspection, player: int,
		ship_index: int) -> GameCommand:
	var ship: ShipInstance = game_state.get_ship(player, ship_index)
	if ship == null or not ship.has_active_ship_activation() \
			or not ship.attack_step_active:
		return null
	var identity: String = inspection.inspection_id()
	if ship.anti_squadron_attack_zone >= 0:
		if _has_remaining_anti_squadron_target(game_state, ship, player, ship_index):
			return null
		return SkipAttackCommand.new(player, {
			"reason": "squadron_done",
			"ship_index": ship_index,
			"completed_attack_inspection_id": identity,
		})
	if ship.committed_attack_count < 2 \
			and _has_remaining_normal_ship_target(game_state, ship,
				player, ship_index):
		return null
	return AdvanceActivationStepCommand.new(player, {
		"ship_index": ship_index,
		"step_id": "maneuver_step",
		"ship_activation_identity": ship.ship_activation_identity,
		"completed_attack_inspection_id": identity,
	})


## `squadron_done` is the atomic child-iteration consumer.  Once it has
## consumed the completed-result inspection, re-evaluate only the enclosing
## Ship Attack owner from durable ship state.  A remaining normal declaration
## is derived-only; the existing Maneuver transaction is selected only when no
## declaration remains.
static func _derive_post_squadron_done_ship_return(game_state: GameState,
		command: GameCommand) -> GameCommand:
	var player: int = command.player_index
	var ship_index: int = int(command.payload.get("ship_index", -1))
	var ship: ShipInstance = game_state.get_ship(player, ship_index)
	if ship == null or not ship.has_active_ship_activation() \
			or not ship.attack_step_active \
			or ship.anti_squadron_attack_zone >= 0:
		return null
	if ship.committed_attack_count < 2 \
			and _has_remaining_normal_ship_target(game_state, ship, player, ship_index):
		return null
	return AdvanceActivationStepCommand.new(player, {
		"ship_index": ship_index,
		"step_id": "maneuver_step",
		"ship_activation_identity": ship.ship_activation_identity,
	})


## Reuses the authoritative declaration candidates used by BeginAttackCommand
## and the live target selector. Nominal attack capacity alone is not enough:
## an unused hull zone must still have a legal ordinary ship declaration.  A
## completed anti-squadron iteration does not prohibit a different unused zone
## from legally targeting a surviving squadron.
static func _has_remaining_normal_ship_target(game_state: GameState,
		ship: ShipInstance, player: int, ship_index: int) -> bool:
	if game_state == null or ship == null:
		return false
	for candidate: Dictionary in \
			TargetingListBuilder.authoritative_ship_target_entries(
					game_state, player, ship_index):
		if int(candidate.get("attacker_zone", -1)) \
			in ship.used_attack_hull_zones:
			continue
		return true
	return false


static func _derive_squadron_inspection_release(game_state: GameState,
		inspection: CompletedAttackInspection, player: int,
		squadron_index: int) -> GameCommand:
	var squadron: SquadronInstance = game_state.get_squadron(player, squadron_index)
	if squadron == null or squadron.activated_this_round \
			or not game_state.is_squadron_activation_action_complete(squadron):
		return null
	return _build_complete_squadron_activation_with_inspection(
			game_state, squadron, squadron_index, inspection.inspection_id())


static func _build_complete_squadron_activation_with_inspection(
		game_state: GameState, squadron: SquadronInstance,
		squadron_index: int, inspection_id: String) -> GameCommand:
	var payload: Dictionary = {
		"squadron_index": squadron_index,
		"activation_id": squadron.activation_id,
		"activation_context": squadron.activation_context,
		"completed_attack_inspection_id": inspection_id,
	}
	if squadron.activation_context \
			== SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND:
		var ship: ShipInstance = game_state.get_ship(
			squadron.commanding_ship_player, squadron.commanding_ship_index)
		if ship == null:
			return null
		payload["commanding_ship_player"] = squadron.commanding_ship_player
		payload["commanding_ship_index"] = squadron.commanding_ship_index
		payload["ship_activation_identity"] = ship.ship_activation_identity
	return CompleteSquadronActivationCommand.new(squadron.owner_player, payload)


static func _has_remaining_anti_squadron_target(game_state: GameState,
		ship: ShipInstance, player: int, ship_index: int) -> bool:
	for candidate: Dictionary in \
		TargetingListBuilder.authoritative_ship_target_entries(
				game_state, player, ship_index):
		if int(candidate.get("attacker_zone", -1)) \
				!= ship.anti_squadron_attack_zone \
			or str(candidate.get("target_kind", "")) \
					!= CurrentAttackState.KIND_SQUADRON:
			continue
		var owner: int = int(candidate.get("target_owner", -1))
		var index: int = int(candidate.get("target_index", -1))
		var squadron: SquadronInstance = game_state.get_squadron(owner, index)
		if squadron != null and not squadron.is_destroyed() \
				and not ship.has_anti_squadron_target(owner, index):
			return true
	return false


static func _derive_defense_followup(game_state: GameState,
		attack: CurrentAttackState,
		command: GameCommand,
		result: Dictionary) -> GameCommand:
	match command.command_type:
		"commit_accuracy":
			if attack.stage == CurrentAttackState.STAGE_DEFENSE \
					and attack.defense_stage \
							== CurrentAttackState.DEFENSE_COMPLETE:
				return _build_resolve_damage(attack)
		"commit_defense":
			return _build_next_defense_or_damage(game_state, attack)
		"spend_defense_token":
			var token_type: int = int(result.get("token_type", -1))
			if token_type not in [
				Constants.DefenseToken.EVADE,
				Constants.DefenseToken.REDIRECT,
			]:
				return _build_next_defense_or_damage(game_state, attack)
		"select_evade_die", "redirect_done":
			return _build_next_defense_or_damage(game_state, attack)
		"select_redirect_zone":
			if bool(result.get("redirect_complete", false)):
				return _build_next_defense_or_damage(game_state, attack)
	return null


static func _build_next_defense_or_damage(game_state: GameState,
		attack: CurrentAttackState) -> GameCommand:
	if attack.stage != CurrentAttackState.STAGE_DEFENSE:
		return null
	if attack.defense_stage == CurrentAttackState.DEFENSE_COMPLETE:
		return _build_resolve_damage(attack)
	if attack.defense_stage != CurrentAttackState.DEFENSE_RESOLVING:
		return null
	var token_index: int = _next_unresolved_token(attack)
	if token_index < 0:
		return null
	var defender: RefCounted = _defender(game_state, attack)
	var tokens: Array[Dictionary] = _defense_tokens(defender)
	if token_index >= tokens.size():
		return null
	var token: Dictionary = tokens[token_index]
	var resolver := DefenseTokenResolver.new()
	var spend_method: String = resolver.resolve_spend_method(
			"exhaust", token)
	return SpendDefenseTokenCommand.new(attack.defender_player, {
		"attack_id": attack.attack_id,
		"defender_kind": attack.defender_kind,
		"defender_index": attack.defender_index,
		"ship_index": attack.defender_index \
				if attack.defender_kind == CurrentAttackState.KIND_SHIP else -1,
		"token_index": token_index,
		"expected_token_type": int(token.get("type", -1)),
		"spend_method": spend_method,
	})


static func _build_resolve_damage(
		attack: CurrentAttackState) -> GameCommand:
	return CandidateResolveDamageCommand.new(attack.attacker_player, {
		"attack_id": attack.attack_id,
	})


static func _build_complete_attack(
		attack: CurrentAttackState) -> GameCommand:
	return CompleteAttackCommand.new(attack.attacker_player, {
		"attack_id": attack.attack_id,
	})


static func _post_damage_decision_pending(game_state: GameState,
		attack: CurrentAttackState) -> bool:
	if game_state.faceup_damage_inspection != null:
		return true
	if _counter_decision_pending(game_state, attack):
		return true
	if attack.defender_kind != CurrentAttackState.KIND_SHIP:
		return false
	var defender: ShipInstance = game_state.get_ship(
			attack.defender_player, attack.defender_index)
	return defender != null and defender.has_active_immediate_resolution()


static func _counter_decision_pending(game_state: GameState,
		attack: CurrentAttackState) -> bool:
	if attack.attacker_kind != CurrentAttackState.KIND_SQUADRON \
			or attack.defender_kind != CurrentAttackState.KIND_SQUADRON:
		return false
	return CounterKeyword.is_counter_trigger_available(
			attack.attack_kind,
			game_state.get_squadron(
					attack.attacker_player, attack.attacker_index),
			game_state.get_squadron(
					attack.defender_player, attack.defender_index))


static func _next_unresolved_token(attack: CurrentAttackState) -> int:
	var resolved: Dictionary = {}
	for effect: Dictionary in attack.resolved_defense_effects:
		resolved[int(effect.get("token_index", -1))] = true
	for token_index: int in attack.committed_defense_tokens:
		if not resolved.has(token_index):
			return token_index
	return -1


static func _defender(game_state: GameState,
		attack: CurrentAttackState) -> RefCounted:
	if attack.defender_kind == CurrentAttackState.KIND_SHIP:
		return game_state.get_ship(
				attack.defender_player, attack.defender_index)
	return game_state.get_squadron(
			attack.defender_player, attack.defender_index)


static func _defense_tokens(defender: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if defender != null:
		result.assign(defender.get("defense_tokens") as Array)
	return result


static func _success(
		continuation: GameCommand = null) -> Dictionary:
	return {
		KEY_OK: true,
		KEY_REASON: "",
		KEY_CONTINUATION: continuation,
	}


static func _failure(reason: String) -> Dictionary:
	return {
		KEY_OK: false,
		KEY_REASON: reason,
		KEY_CONTINUATION: null,
	}
