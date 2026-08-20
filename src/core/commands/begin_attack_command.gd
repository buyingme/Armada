## Starts one canonical individual attack.
class_name BeginAttackCommand
extends GameCommand

const TYPE: String = "begin_attack"
const FLOW_SPEC_SCRIPT: GDScript = preload("res://src/core/state/flow_spec.gd")

var _log: GameLogger = GameLogger.new("BeginAttackCommand")

static func register() -> void:
	GameCommand.register_type(TYPE, func(player: int, pl: Dictionary) -> GameCommand:
		return BeginAttackCommand.new(player, pl))

func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, TYPE, p_payload)

func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	var inspection_reason: String = \
		game_state.validate_completed_attack_inspection_consumer(
				str(payload.get("completed_attack_inspection_id", "")))
	if inspection_reason != "":
		return inspection_reason
	if game_state.current_attack_state.active:
		return "Another current attack is active."
	if game_state.current_phase != Constants.GamePhase.SHIP \
			and game_state.current_phase != Constants.GamePhase.SQUADRON:
		return "Not in Ship or Squadron Phase."
	if not game_state.validate_declaration_adjacent_state():
		return "Declaration-adjacent state is invalid."
	var identity_error: String = _validate_identity(game_state)
	if identity_error != "":
		return identity_error
	var context_error: String = _validate_declaration_context(game_state)
	if context_error != "":
		return context_error
	var progress_error: String = _validate_ship_attack_progress(game_state)
	if progress_error != "":
		return progress_error
	var entry: Dictionary = _authoritative_entry(game_state)
	if entry.is_empty():
		return "Attack target is not legal from authoritative board state."
	if str(payload.get("range_band", "")) != str(entry.get("range_band", "")):
		return "Attack range does not match authoritative board state."
	if bool(payload.get("obstructed", false)) \
			!= bool(entry.get("obstructed", false)):
		return "Attack obstruction does not match authoritative board state."
	var target_error: String = _validate_authoritative_target_rules(
			game_state, entry)
	if target_error != "":
		return target_error
	var pool: Dictionary = _derive_initial_pool(game_state, entry)
	if DicePool.get_total_count(pool) <= 0:
		return "Attack has no legal dice pool."
	return ""

func execute(game_state: GameState) -> Dictionary:
	var inspection_id: String = str(payload.get(
			"completed_attack_inspection_id", ""))
	var inspection_before: CompletedAttackInspection = \
		game_state.completed_attack_inspection
	var ship: ShipInstance = _tracked_attacker_ship(game_state)
	if _coordinates_ship_attack_progress() and ship == null:
		_log.debug("Rejected execution without an active authoritative ship " \
				+ "Attack-step opportunity.")
		return {}
	var state := CurrentAttackState.new()
	var entry: Dictionary = _authoritative_entry(game_state)
	var pool: Dictionary = _derive_initial_pool(game_state, entry)
	var cf_dial: String = CurrentAttackState.RESOLUTION_UNAVAILABLE
	var cf_token: String = CurrentAttackState.RESOLUTION_UNAVAILABLE
	if str(payload.get("attacker_kind", "")) == CurrentAttackState.KIND_SHIP:
		var cf_ship: ShipInstance = game_state.get_ship(
				int(payload.get("attacker_player", -1)),
				int(payload.get("attacker_index", -1)))
		if _has_cf_dial(cf_ship):
			cf_dial = CurrentAttackState.RESOLUTION_PENDING
		if cf_ship != null and cf_ship.command_tokens != null \
				and cf_ship.command_tokens.has_token(
						Constants.CommandType.CONCENTRATE_FIRE):
			cf_token = CurrentAttackState.RESOLUTION_PENDING
	var values: Dictionary = {
		"attacker_player": int(payload.get("attacker_player", -1)),
		"attacker_kind": str(payload.get("attacker_kind", "")),
		"attacker_index": int(payload.get("attacker_index", -1)),
		"attacker_zone": int(payload.get("attacker_zone", -1)),
		"defender_player": int(payload.get("defender_player", -1)),
		"defender_kind": str(payload.get("defender_kind", "")),
		"defender_index": int(payload.get("defender_index", -1)),
		"defender_zone": int(payload.get("defender_zone", -1)),
		"attack_kind": _canonical_attack_kind(),
		"range_band": str(entry.get("range_band", "")),
		"obstructed": bool(entry.get("obstructed", false)),
		"obstruction_resolved": not bool(entry.get("obstructed", false)),
		"dice_pool": pool,
		"cf_dial_resolution": cf_dial,
		"cf_token_resolution": cf_token,
	}
	var attack_id: String = "attack:%d" % sequence
	if not state.configure_active(attack_id, values):
		return {}
	var progress_snapshot: Dictionary = {}
	var squadron: SquadronInstance = _standard_attacker_squadron(game_state)
	var action_snapshot: Dictionary = {}
	if ship != null:
		_log.debug("Begin before authoritative progress commit: %s" %
				JSON.stringify(ship.attack_progress_snapshot()))
		progress_snapshot = ship.attack_progress_snapshot()
		ship.commit_attack(
				int(payload.get("attacker_zone", -1)),
				int(payload.get("defender_player", -1)),
				str(payload.get("defender_kind", "")),
				int(payload.get("defender_index", -1)))
	elif squadron != null:
		action_snapshot = squadron.activation_action_state_snapshot()
		if not squadron.commit_attack_action_begun(
				str(payload.get("activation_id", "")),
				_is_rogue(squadron)):
			return {}
	var installed: bool = game_state.set_current_attack_state(state) \
			if inspection_id.is_empty() \
			else game_state.replace_satisfied_inspection_with_current_attack(
					inspection_id, state)
	if not installed:
		if ship != null:
			ship.restore_attack_progress(progress_snapshot)
		if squadron != null:
			squadron.restore_activation_action_state(action_snapshot)
		return {}
	if not game_state.validate_declaration_adjacent_state():
		game_state.set_current_attack_state(CurrentAttackState.inactive())
		if inspection_before != null:
			game_state.restore_completed_attack_inspection_for_rollback(
					inspection_before)
		if ship != null:
			ship.restore_attack_progress(progress_snapshot)
		if squadron != null:
			squadron.restore_activation_action_state(action_snapshot)
		return {}
	if ship != null:
		_log.debug("Begin after authoritative progress commit: %s" %
				JSON.stringify(ship.attack_progress_snapshot()))
	if _canonical_attack_kind() \
			== SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD:
		game_state.interaction_flow = FLOW_SPEC_SCRIPT.make_interaction_flow(
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_DECLARE,
				game_state,
				{"attacker_player": player_index},
				Constants.Visibility.ALL,
				{"attack_id": attack_id})
	return {"attack_id": attack_id, "dice_pool": pool.duplicate(true),
			"activation_id": str(payload.get("activation_id", "")),
			"ship_activation_identity": str(payload.get(
					"ship_activation_identity", ""))}


func _validate_ship_attack_progress(game_state: GameState) -> String:
	if not _coordinates_ship_attack_progress():
		return ""
	var ship: ShipInstance = _tracked_attacker_ship(game_state)
	if ship == null:
		return "No active authoritative ship Attack-step opportunity."
	return ship.validate_attack_commit(
			int(payload.get("attacker_zone", -1)),
			int(payload.get("defender_player", -1)),
			str(payload.get("defender_kind", "")),
			int(payload.get("defender_index", -1)))


func _validate_declaration_context(game_state: GameState) -> String:
	if _canonical_attack_kind() \
			== SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER:
		return ""
	var attacker_kind: String = str(payload.get("attacker_kind", ""))
	if attacker_kind == CurrentAttackState.KIND_SHIP:
		var ship: ShipInstance = game_state.get_ship(
				int(payload.get("attacker_player", -1)),
				int(payload.get("attacker_index", -1)))
		if ship == null or not ship.attack_step_active:
			return "No active authoritative ship Attack-step opportunity."
		var expected_identity: String = str(payload.get(
				"ship_activation_identity", ""))
		if expected_identity.is_empty() \
				or expected_identity != ship.ship_activation_identity:
			return "Stale or missing ship activation identity."
		return ""
	if attacker_kind != CurrentAttackState.KIND_SQUADRON:
		return "Unsupported declaration attacker context."
	var squadron: SquadronInstance = _standard_attacker_squadron(game_state)
	if squadron == null or squadron.activated_this_round:
		return "No active authoritative squadron declaration opportunity."
	if str(payload.get("activation_id", "")) != squadron.activation_id \
			or str(payload.get("activation_context", "")) \
					!= squadron.activation_context:
		return "Stale or wrong-context squadron activation identity."
	if not squadron.has_remaining_attack_action(_is_rogue(squadron)):
		return "Squadron attack action is not available."
	if squadron.activation_context \
			== SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE:
		if game_state.current_phase != Constants.GamePhase.SQUADRON \
				or player_index != game_state.squadron_phase_controller_player:
			return "Squadron declaration belongs to the canonical controller."
		return ""
	if squadron.activation_context \
			!= SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND \
			or game_state.current_phase != Constants.GamePhase.SHIP:
		return "Squadron declaration context is invalid."
	var commanding_ship: ShipInstance = game_state.get_ship(
			squadron.commanding_ship_player, squadron.commanding_ship_index)
	if commanding_ship == null or commanding_ship.owner_player != player_index:
		return "Commanding ship is unavailable."
	if str(payload.get("ship_activation_identity", "")) \
			!= commanding_ship.ship_activation_identity \
			or commanding_ship.squadron_command_opportunity_disposition \
					!= ShipInstance.ACTIVATION_DISPOSITION_OPEN:
		return "Ship Squadron-command opportunity does not match."
	var capacity: int = SquadronCommandResolver.authoritative_capacity(
			commanding_ship)
	if commanding_ship.squadron_command_activations_committed <= 0 \
			or commanding_ship.squadron_command_activations_committed > capacity:
		return "Commanding ship activation budget is invalid."
	return ""


func _tracked_attacker_ship(game_state: GameState) -> ShipInstance:
	if not _coordinates_ship_attack_progress():
		return null
	var ship: ShipInstance = game_state.get_ship(
			int(payload.get("attacker_player", -1)),
			int(payload.get("attacker_index", -1)))
	return ship if ship != null and ship.attack_step_active else null


func _standard_attacker_squadron(game_state: GameState) -> SquadronInstance:
	if _canonical_attack_kind() \
			!= SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD \
			or str(payload.get("attacker_kind", "")) \
					!= CurrentAttackState.KIND_SQUADRON:
		return null
	return game_state.get_squadron(
			int(payload.get("attacker_player", -1)),
			int(payload.get("attacker_index", -1)))


func _is_rogue(squadron: SquadronInstance) -> bool:
	return squadron != null and squadron.squadron_data != null \
			and squadron.squadron_data.has_keyword("Rogue")


func _coordinates_ship_attack_progress() -> bool:
	return _canonical_attack_kind() \
			== SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD \
			and str(payload.get("attacker_kind", "")) \
					== CurrentAttackState.KIND_SHIP

func _validate_identity(game_state: GameState) -> String:
	for key: String in ["attacker_player", "attacker_index", "attacker_zone",
			"defender_player", "defender_index", "defender_zone"]:
		if typeof(payload.get(key)) != TYPE_INT:
			return "Invalid %s." % key
	for key: String in ["attacker_kind", "defender_kind", "attack_kind", "range_band"]:
		if typeof(payload.get(key)) != TYPE_STRING or str(payload.get(key)).is_empty():
			return "Invalid %s." % key
	if typeof(payload.get("obstructed")) != TYPE_BOOL:
		return "Invalid obstructed value."
	var attack_kind: String = str(payload.get("attack_kind", ""))
	if attack_kind != SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD \
			and attack_kind != SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER:
		return "Invalid attack kind."
	var attacker_player: int = int(payload.get("attacker_player", -1))
	if player_index != attacker_player:
		return "Attack entry belongs to player %d." % attacker_player
	if not _entity_exists(game_state, str(payload.get("attacker_kind", "")),
			attacker_player, int(payload.get("attacker_index", -1))):
		return "Attacker not found."
	if not _entity_exists(game_state, str(payload.get("defender_kind", "")),
			int(payload.get("defender_player", -1)),
			int(payload.get("defender_index", -1))):
		return "Defender not found."
	if not _zone_valid(str(payload.get("attacker_kind", "")),
			int(payload.get("attacker_zone", -1))) \
			or not _zone_valid(str(payload.get("defender_kind", "")),
					int(payload.get("defender_zone", -1))):
		return "Invalid attack hull-zone identity."
	var attacker: RefCounted = _entity(game_state,
			str(payload.get("attacker_kind", "")), attacker_player,
			int(payload.get("attacker_index", -1)))
	var defender: RefCounted = _entity(game_state,
			str(payload.get("defender_kind", "")),
			int(payload.get("defender_player", -1)),
			int(payload.get("defender_index", -1)))
	if defender != null and bool(defender.call("is_destroyed")):
		return "Defender is destroyed."
	if attack_kind == SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER:
		return _validate_counter_identity(game_state, attacker, defender)
	if attacker != null and bool(attacker.call("is_destroyed")):
		return "Attacker is destroyed."
	return ""

func _derive_initial_pool(game_state: GameState,
		entry: Dictionary = {}) -> Dictionary:
	var attacker_kind: String = str(payload.get("attacker_kind", ""))
	var defender_kind: String = str(payload.get("defender_kind", ""))
	var attacker_player: int = int(payload.get("attacker_player", -1))
	var attacker_index: int = int(payload.get("attacker_index", -1))
	var attacker: RefCounted = null
	var defender: RefCounted = null
	if _canonical_attack_kind() \
			== SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER:
		var counter_squadron: SquadronInstance = game_state.get_squadron(
				attacker_player, attacker_index)
		var counter_dice: int = SquadronKeywordRuleHelper.get_keyword_value(
				counter_squadron, SquadronKeywordRuleHelper.KEYWORD_COUNTER)
		return {"BLUE": counter_dice} if counter_dice > 0 else {}
	if attacker_kind == CurrentAttackState.KIND_SHIP:
		var ship: ShipInstance = game_state.get_ship(attacker_player, attacker_index)
		attacker = ship
	else:
		var squadron: SquadronInstance = game_state.get_squadron(
				attacker_player, attacker_index)
		attacker = squadron
	if defender_kind == CurrentAttackState.KIND_SHIP:
		defender = game_state.get_ship(
				int(payload.get("defender_player", -1)),
				int(payload.get("defender_index", -1)))
	else:
		defender = game_state.get_squadron(
				int(payload.get("defender_player", -1)),
				int(payload.get("defender_index", -1)))
	var context := EffectContext.new()
	context.attacker = attacker
	context.defender = defender
	context.range_band = str(entry.get("range_band", ""))
	context.dice_pool = (entry.get("dice", {}) as Dictionary).duplicate(true)
	context.set_meta_value(SquadronKeywordRuleHelper.PAYLOAD_ATTACK_KIND,
			_canonical_attack_kind())
	for hook: FlowHook in RuleRegistry.modifiers_for(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			"dice_pool"):
		if hook.callback.is_valid():
			var changed: Variant = hook.callback.call(context)
			if changed is EffectContext:
				context = changed as EffectContext
	return context.dice_pool.duplicate(true)

func _entity_exists(game_state: GameState, kind: String,
		owner: int, index: int) -> bool:
	return _entity(game_state, kind, owner, index) != null


func _entity(game_state: GameState, kind: String,
		owner: int, index: int) -> RefCounted:
	if kind == CurrentAttackState.KIND_SHIP:
		return game_state.get_ship(owner, index)
	if kind == CurrentAttackState.KIND_SQUADRON:
		return game_state.get_squadron(owner, index)
	return null


func _authoritative_entry(game_state: GameState) -> Dictionary:
	return TargetingListBuilder.authoritative_attack_entry(
			game_state,
			int(payload.get("attacker_player", -1)),
			str(payload.get("attacker_kind", "")),
			int(payload.get("attacker_index", -1)),
			int(payload.get("attacker_zone", -1)),
			int(payload.get("defender_player", -1)),
			str(payload.get("defender_kind", "")),
			int(payload.get("defender_index", -1)),
			int(payload.get("defender_zone", -1)))


func _validate_authoritative_target_rules(game_state: GameState,
		entry: Dictionary) -> String:
	var attacker: RefCounted = _entity(game_state,
			str(payload.get("attacker_kind", "")),
			int(payload.get("attacker_player", -1)),
			int(payload.get("attacker_index", -1)))
	var defender: RefCounted = _entity(game_state,
			str(payload.get("defender_kind", "")),
			int(payload.get("defender_player", -1)),
			int(payload.get("defender_index", -1)))
	if attacker == null or defender == null:
		return "Attack participants are unavailable."
	var attack_kind: String = _canonical_attack_kind()
	var all_squadrons: Array[Dictionary] = \
			SquadronKeywordRuleHelper.positions_from_state(game_state)
	var obstruction_bodies: Array = \
			EngagementResolver.obstruction_bodies_from_state(game_state)
	if attack_kind == SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD \
			and attacker is SquadronInstance:
		var attacker_squadron: SquadronInstance = attacker as SquadronInstance
		var attacker_pos: Vector2 = \
				SquadronKeywordRuleHelper.position_from_state(attacker_squadron)
		if defender is ShipInstance \
				and not SquadronKeywordRuleHelper.can_attack_ship_with_heavy_rule(
					attacker_squadron, attacker_pos, all_squadrons,
					obstruction_bodies):
			return "Engaged squadron must attack an engaged enemy squadron."
		if defender is SquadronInstance \
				and SquadronKeywordRuleHelper.is_engaged_by_non_heavy(
					attacker_squadron, attacker_pos, all_squadrons,
					obstruction_bodies) \
				and not SquadronKeywordRuleHelper.is_engaged_with_target(
					attacker_squadron, attacker_pos,
					defender as SquadronInstance,
					SquadronKeywordRuleHelper.position_from_state(
						defender as SquadronInstance), obstruction_bodies):
			return "Squadron target is not an engaged enemy."
	var context := EffectContext.new()
	context.attacker = attacker
	context.defender = defender
	context.range_band = str(entry.get("range_band", ""))
	context.set_meta_value("target_kind", str(payload.get("defender_kind", "")))
	context.set_meta_value("is_obstructed", bool(entry.get("obstructed", false)))
	context.set_meta_value("ship_target_attacks_this_round",
			game_state.get_ship_target_attack_count(attacker as ShipInstance) \
					if attacker is ShipInstance else 0)
	context.set_meta_value(SquadronKeywordRuleHelper.PAYLOAD_ATTACKER_POS,
			SquadronKeywordRuleHelper.position_from_state(attacker as SquadronInstance) \
					if attacker is SquadronInstance else Vector2.ZERO)
	context.set_meta_value(SquadronKeywordRuleHelper.PAYLOAD_TARGET_POS,
			SquadronKeywordRuleHelper.position_from_state(defender as SquadronInstance) \
					if defender is SquadronInstance else Vector2.ZERO)
	context.set_meta_value(SquadronKeywordRuleHelper.PAYLOAD_ALL_SQUADRONS,
			all_squadrons)
	context.set_meta_value(SquadronKeywordRuleHelper.PAYLOAD_ATTACK_KIND,
			attack_kind)
	context.set_meta_value(SquadronKeywordRuleHelper.META_OBSTRUCTION_BODIES,
			obstruction_bodies)
	var blocked: Dictionary = RuleSurface.block_result(context,
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DECLARE,
			RuleSurface.TARGET_ATTACK_TARGET)
	if bool(blocked.get(RuleSurface.RESULT_BLOCKED, false)):
		return str(blocked.get(RuleSurface.RESULT_REASON,
				"Attack target is blocked by a rule."))
	return ""


func _validate_counter_identity(game_state: GameState,
		attacker: RefCounted, defender: RefCounted) -> String:
	if not attacker is SquadronInstance or not defender is SquadronInstance:
		return "Counter attacks require two squadrons."
	if SquadronKeywordRuleHelper.get_keyword_value(
			attacker as SquadronInstance,
			SquadronKeywordRuleHelper.KEYWORD_COUNTER) <= 0:
		return "Attacker has no Counter value."
	var flow: InteractionFlow = game_state.interaction_flow
	if flow == null or flow.flow_type != Constants.InteractionFlow.ATTACK \
			or flow.step_id != Constants.InteractionStep.ATTACK_COUNTER_CHOICE \
			or not bool(flow.payload.get("counter_choice_accepted", false)):
		return "No accepted Counter attack is pending."
	var expected: Dictionary = {
		"counter_attacker_player": int(payload.get("attacker_player", -1)),
		"counter_attacker_squadron_index": int(payload.get("attacker_index", -1)),
		"counter_target_player": int(payload.get("defender_player", -1)),
		"counter_target_squadron_index": int(payload.get("defender_index", -1)),
	}
	for key: String in expected:
		if int(flow.payload.get(key, -2)) != int(expected[key]):
			return "Counter attack identity does not match the accepted choice."
	return ""


func _canonical_attack_kind() -> String:
	return SquadronKeywordRuleHelper.attack_kind_from_payload(payload)

func _zone_valid(kind: String, zone: int) -> bool:
	if kind == CurrentAttackState.KIND_SQUADRON:
		return zone == -1
	return kind == CurrentAttackState.KIND_SHIP \
			and zone >= Constants.HullZone.FRONT and zone <= Constants.HullZone.REAR

func _has_cf_dial(ship: ShipInstance) -> bool:
	if ship == null or ship.command_dial_stack == null:
		return false
	var dial: Dictionary = ship.command_dial_stack.get_revealed_dial()
	return not dial.is_empty() \
			and int(dial.get("command", -1)) == int(Constants.CommandType.CONCENTRATE_FIRE)
