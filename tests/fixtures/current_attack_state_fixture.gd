## Test-only builder for invariant-valid canonical current-attack states.
class_name CurrentAttackStateFixture
extends RefCounted


const SHIP_KEY: String = "cr90_corvette_a"
const SQUADRON_KEY: String = "x_wing_squadron"


static func install(game_state: GameState,
		options: Dictionary = {}) -> CurrentAttackState:
	var attacker_kind: String = str(options.get("attacker_kind", "ship"))
	var attacker_player: int = int(options.get("attacker_player", 0))
	var attacker_index: int = int(options.get("attacker_index", 0))
	var defender_kind: String = str(options.get("defender_kind", "ship"))
	var defender_player: int = int(options.get("defender_player", 1))
	var defender_index: int = int(options.get("defender_index", 0))
	_ensure_entity(game_state, attacker_kind, attacker_player, attacker_index)
	_ensure_entity(game_state, defender_kind, defender_player, defender_index)
	var state := CurrentAttackState.new()
	var attack_id: String = str(options.get("attack_id", "attack:0"))
	var values: Dictionary = {
		"attacker_player": attacker_player,
		"attacker_kind": attacker_kind,
		"attacker_index": attacker_index,
		"attacker_zone": int(options.get(
				"attacker_zone", Constants.HullZone.FRONT)),
		"defender_player": defender_player,
		"defender_kind": defender_kind,
		"defender_index": defender_index,
		"defender_zone": int(options.get(
				"defender_zone", Constants.HullZone.FRONT)),
		"attack_kind": str(options.get("attack_kind", "standard")),
		"range_band": str(options.get(
				"range_band", Constants.RANGE_BAND_CLOSE)),
		"obstructed": bool(options.get("obstructed", false)),
		"obstruction_resolved": bool(options.get(
				"obstruction_resolved", true)),
		"dice_pool": (options.get("dice_pool", {"RED": 1}) \
				as Dictionary).duplicate(true),
		"cf_dial_resolution": str(options.get("cf_dial_resolution",
				CurrentAttackState.RESOLUTION_UNAVAILABLE)),
		"cf_token_resolution": str(options.get("cf_token_resolution",
				CurrentAttackState.RESOLUTION_UNAVAILABLE)),
	}
	if values["attacker_kind"] == CurrentAttackState.KIND_SQUADRON:
		values["attacker_zone"] = -1
	if values["defender_kind"] == CurrentAttackState.KIND_SQUADRON:
		values["defender_zone"] = -1
	if not state.configure_active(attack_id, values):
		return null
	var stage: String = str(options.get(
			"stage", CurrentAttackState.STAGE_PRE_ROLL))
	var patch: Dictionary = {}
	if stage != CurrentAttackState.STAGE_PRE_ROLL:
		patch["stage"] = stage
		patch["dice_results"] = _dice(options)
		if state.cf_dial_resolution == CurrentAttackState.RESOLUTION_PENDING:
			patch["cf_dial_resolution"] = CurrentAttackState.RESOLUTION_DECLINED
	if stage in [CurrentAttackState.STAGE_DEFENSE,
			CurrentAttackState.STAGE_DAMAGE,
			CurrentAttackState.STAGE_RESOLVED]:
		patch["accuracy_complete"] = true
		patch["accuracy_locked_tokens"] = (options.get(
				"accuracy_locked_tokens", []) as Array).duplicate()
		patch["defense_stage"] = str(options.get("defense_stage",
				CurrentAttackState.DEFENSE_PENDING))
		patch["committed_defense_tokens"] = (options.get(
				"committed_defense_tokens", []) as Array).duplicate()
		patch["resolved_defense_effects"] = (options.get(
				"resolved_defense_effects", []) as Array).duplicate(true)
		patch["redirect_allocations"] = (options.get(
				"redirect_allocations", []) as Array).duplicate(true)
	if stage == CurrentAttackState.STAGE_RESOLVED:
		patch["damage_stage"] = CurrentAttackState.DAMAGE_RESOLVED
	if not patch.is_empty():
		state = state.with_patch(patch)
	if state == null \
			or not _prepare_declaration_adjacent_owner(game_state, state) \
			or not game_state.set_current_attack_state(state):
		return null
	return game_state.current_attack_state


## Installs the accepted adjacent owner state that a production Begin would
## already have committed. This keeps timing/attack fixtures representative of
## the complete TWI-003 state rather than reconstructing authority from flow.
static func _prepare_declaration_adjacent_owner(
		game_state: GameState, attack: CurrentAttackState) -> bool:
	if attack.attack_kind != SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD:
		return true
	if attack.attacker_kind == CurrentAttackState.KIND_SHIP:
		var ship: ShipInstance = game_state.get_ship(
				attack.attacker_player, attack.attacker_index)
		if ship == null:
			return false
		if not ship.has_active_ship_activation() \
				and not ship.establish_ship_activation(
						"ship-activation:fixture:%s" % attack.attack_id):
			return false
		ship.begin_attack_step()
		if ship.committed_attack_count == 0:
			ship.commit_attack(attack.attacker_zone,
					attack.defender_player, attack.defender_kind,
					attack.defender_index)
		return ship.attack_step_active
	if attack.attacker_kind != CurrentAttackState.KIND_SQUADRON \
			or game_state.current_phase != Constants.GamePhase.SQUADRON:
		return false
	var squadron: SquadronInstance = game_state.get_squadron(
			attack.attacker_player, attack.attacker_index)
	if squadron == null:
		return false
	if not game_state.has_squadron_phase_controller() \
			and not game_state.initialize_squadron_phase_progress(
					attack.attacker_player):
		return false
	var activation_id: String = "squadron-activation:fixture:%s" % \
			attack.attack_id
	if not squadron.has_activation_action_state() \
			and not squadron.initialize_activation_action_state(
					activation_id,
					SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE):
		return false
	if squadron.attack_action_disposition \
			== SquadronInstance.ATTACK_ACTION_AVAILABLE:
		return squadron.commit_attack_action_begun(
				squadron.activation_id,
				squadron.squadron_data != null \
						and squadron.squadron_data.has_keyword("Rogue"))
	return squadron.attack_action_disposition \
			== SquadronInstance.ATTACK_ACTION_BEGUN


static func _ensure_entity(game_state: GameState, kind: String,
		player: int, index: int) -> void:
	if game_state == null or player < 0 or player >= Constants.PLAYER_COUNT:
		return
	var player_state: PlayerState = game_state.get_player_state(player)
	if player_state == null:
		return
	if kind == CurrentAttackState.KIND_SHIP:
		var ship_data: ShipData = AssetLoader.load_ship_data(SHIP_KEY)
		while player_state.ships.size() <= index:
			player_state.ships.append(ShipInstance.create_from_data(
					SHIP_KEY, ship_data, 2, player))
	elif kind == CurrentAttackState.KIND_SQUADRON:
		var squadron_data: SquadronData = AssetLoader.load_squadron_data(
				SQUADRON_KEY)
		while player_state.squadrons.size() <= index:
			player_state.squadrons.append(SquadronInstance.create_from_data(
					SQUADRON_KEY, squadron_data, player))


static func _dice(options: Dictionary) -> Array[Dictionary]:
	var configured: Array = options.get("dice_results", [
		{"color": int(Constants.DiceColor.RED),
			"face": int(Constants.DiceFace.HIT)},
	]) as Array
	var result: Array[Dictionary] = []
	for entry: Variant in configured:
		result.append((entry as Dictionary).duplicate(true))
	return result
