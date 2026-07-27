## CommitDefenseCommand
##
## Marker command submitted by the [b]defender peer[/b] in network mode
## when the player presses [i]Commit Defense[/i] on the
## [AttackPanelMirror].  It carries the canonical-order list of
## defense-token indices the defender chose to spend and records the
## chosen ECM-authorized locked token when ECM is pending.
##
## Phase I6b-3 R2: closes NW-006 — defense-token authority moves from
## the attacker peer to the defender peer.  The attacker peer's
## [AttackExecutor] reacts to this command via
## [signal CommandProcessor.command_executed] and runs the existing
## token-spend pipeline, submitting one [SpendDefenseTokenCommand] per
## listed index.
##
## Payload:
##   "defender_kind"     — canonical participant kind (ship or squadron).
##   "defender_index"    — index of the defender in the matching fleet list.
##   "selected_indices"  — token indices in canonical resolution order
##                         (Scatter → Evade → Brace → Redirect → Contain),
##                         as produced by
##                         [code]_sort_defense_tokens_canonical[/code].
##                         May be empty (= "spend nothing, proceed").
##
## Hot-seat: this command is also submitted in hot-seat for replay
## determinism and to keep a single code path between modes.
##
## Rules Reference: "Defense Tokens", DT-001/DT-002, p.5.
class_name CommitDefenseCommand
extends GameCommand


const ECM_SCRIPT: GDScript = preload(
		"res://src/core/effects/rules/upgrades/defensive_retrofit/electronic_countermeasures.gd")


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("commit_defense", func(player: int,
			pl: Dictionary) -> GameCommand:
		return CommitDefenseCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "commit_defense", p_payload)


## Validates that the canonical defender exists and we are in an attack
## sub-flow.  The command itself performs no game-state mutation — the
## attacker peer's [AttackExecutor] reacts to the broadcast and submits
## one [SpendDefenseTokenCommand] per listed index.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	var phase: Constants.GamePhase = game_state.current_phase
	if phase != Constants.GamePhase.SHIP \
			and phase != Constants.GamePhase.SQUADRON:
		return "Not in Ship or Squadron Phase."
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack == null or not attack.active:
		return "No current attack."
	if attack.attack_id != str(payload.get("attack_id", "")):
		return "Stale current-attack identity."
	if attack.stage != CurrentAttackState.STAGE_DEFENSE \
			or attack.defense_stage != CurrentAttackState.DEFENSE_PENDING:
		return "Defense commitment is not pending."
	if player_index != attack.defender_player \
			or not _payload_matches_defender(attack):
		return "Defense commitment does not match the current defender."
	var defender: RefCounted = _defender(game_state, attack)
	if defender == null:
		return "Defender not found."
	var tokens: Array[Dictionary] = _defense_tokens(defender)
	var selected: Array = payload.get("selected_indices", []) as Array
	var seen: Dictionary = {}
	var selected_types: Dictionary = {}
	var resolver := DefenseTokenResolver.new()
	if not selected.is_empty() and defender is ShipInstance \
			and (defender as ShipInstance).current_speed == 0:
		return "A speed-0 defender cannot spend defense tokens."
	for raw_idx: Variant in selected:
		if typeof(raw_idx) != TYPE_INT:
			return "Invalid defense-token reference."
		var idx: int = int(raw_idx)
		if idx < 0 or idx >= tokens.size() or seen.has(idx):
			return "Token index %d out of range." % idx
		seen[idx] = true
		var token: Dictionary = tokens[idx]
		var token_type: int = int(token.get("type", -1))
		if defender is SquadronInstance \
				and attack.accuracy_locked_tokens.has(idx):
			return "An Accuracy-locked defense token cannot be committed."
		if defender is SquadronInstance \
				and token_type == int(Constants.DefenseToken.REDIRECT):
			return "A squadron cannot use Redirect."
		if selected_types.has(token_type):
			return "Only one defense token of each type may be spent."
		selected_types[token_type] = true
		if int(token.get("state", -1)) \
				== int(Constants.DefenseTokenState.DISCARDED):
			return "A discarded defense token cannot be committed."
		if resolver.is_token_blocked_by_effect(
				defender, token, attack.defender_zone):
			return "Defense token is blocked by an applicable rule."
	if selected != _canonical_order(selected, tokens):
		return "Defense tokens are not in canonical resolution order."
	if defender is ShipInstance:
		var ecm_error: String = ECM_SCRIPT.validate_authorized_token_selection(
				game_state, defender as ShipInstance,
				attack.defender_index, selected)
		if ecm_error != "":
			return ecm_error
	return ""


## Records any ECM-authorized locked token choice and echoes the selected
## indices so the attacker peer's [AttackExecutor] can drive the spend
## pipeline from the [signal CommandProcessor.command_executed] signal.
func execute(game_state: GameState) -> Dictionary:
	var attack: CurrentAttackState = game_state.current_attack_state
	var selected: Array = payload.get("selected_indices", []) as Array
	var replacement: CurrentAttackState = attack.with_patch({
		"committed_defense_tokens": selected,
		"defense_stage": CurrentAttackState.DEFENSE_COMPLETE \
				if selected.is_empty() \
				else CurrentAttackState.DEFENSE_RESOLVING,
	})
	if replacement == null or not game_state.set_current_attack_state(replacement):
		return {}
	var ecm_pending: Dictionary = {}
	if attack.defender_kind == CurrentAttackState.KIND_SHIP:
		ecm_pending = ECM_SCRIPT.commit_authorized_token_selection(
				game_state, attack.defender_index, selected)
	return {
		"attack_id": attack.attack_id,
		"defender_kind": attack.defender_kind,
		"defender_index": attack.defender_index,
		"ship_index": attack.defender_index \
				if attack.defender_kind == CurrentAttackState.KIND_SHIP else -1,
		"selected_indices": selected.duplicate(),
		"ecm_selected_token_index": int(ecm_pending.get(
				ECM_SCRIPT.PENDING_SELECTED_TOKEN_INDEX, -1)),
	}


func _payload_matches_defender(attack: CurrentAttackState) -> bool:
	var kind: String = str(payload.get(
			"defender_kind", CurrentAttackState.KIND_SHIP))
	var index: int = int(payload.get(
			"defender_index", payload.get("ship_index", -1)))
	return kind == attack.defender_kind and index == attack.defender_index


func _defender(game_state: GameState,
		attack: CurrentAttackState) -> RefCounted:
	if attack.defender_kind == CurrentAttackState.KIND_SHIP:
		return game_state.get_ship(attack.defender_player, attack.defender_index)
	return game_state.get_squadron(
			attack.defender_player, attack.defender_index)


func _defense_tokens(defender: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if defender != null:
		result.assign(defender.get("defense_tokens") as Array)
	return result


func _canonical_order(selected: Array,
		defense_tokens: Array[Dictionary]) -> Array:
	var result: Array = selected.duplicate()
	result.sort_custom(func(left: int, right: int) -> bool:
		var left_type: int = int(defense_tokens[left].get("type", -1))
		var right_type: int = int(defense_tokens[right].get("type", -1))
		return _token_order(left_type) < _token_order(right_type))
	return result


func _token_order(token_type: int) -> int:
	match token_type:
		Constants.DefenseToken.SCATTER:
			return 0
		Constants.DefenseToken.EVADE:
			return 1
		Constants.DefenseToken.BRACE:
			return 2
		Constants.DefenseToken.REDIRECT:
			return 3
		Constants.DefenseToken.CONTAIN:
			return 4
	return 99
