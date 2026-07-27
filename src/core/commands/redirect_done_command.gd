## RedirectDoneCommand
##
## Marker command submitted by the [b]defender peer[/b] in network mode
## when the player presses the [i]Done Redirecting[/i] button during the
## Redirect defense-token sub-step on the [AttackPanelMirror].  Ends
## the redirect sub-step early (before the redirect budget is fully
## allocated) so the rest of the defense-commit queue and damage
## resolution can proceed.
##
## Phase I6b-3 R4: closes the redirect-zone authority gap together
## with [SelectRedirectZoneCommand].  The attacker peer's
## [AttackExecutor] reacts to this command via
## [signal CommandProcessor.command_executed] and runs
## [code]apply_defender_redirect_done()[/code].
##
## Payload:
##   "ship_index" — index of the defending ship in the player's fleet.
##
## Hot-seat: this command is also submitted in hot-seat for replay
## determinism and to keep a single code path between modes.
##
## Rules Reference: "Redirect", DT-013, RRG v1.5.0, p.11.
class_name RedirectDoneCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("redirect_done", func(player: int,
			pl: Dictionary) -> GameCommand:
		return RedirectDoneCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "redirect_done", p_payload)


## Validates that the defender ship exists.  Allowed in both Ship and
## Squadron phases (only ships have hull zones, but the parent attack
## flow can run in either phase via squadron-vs-ship attacks).
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
			or attack.defense_stage != CurrentAttackState.DEFENSE_RESOLVING:
		return "Redirect resolution is not active."
	if attack.defender_kind != CurrentAttackState.KIND_SHIP \
			or player_index != attack.defender_player \
			or int(payload.get("ship_index", -1)) != attack.defender_index:
		return "Redirect completion does not match the current defender."
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	if ship == null:
		return "Defender ship not found."
	var token_index: int = int(payload.get("token_index", -1))
	if not _is_next_unresolved_redirect(attack, ship, token_index):
		return "No committed Redirect effect is pending."
	return ""


## Marker — no game-state mutation here.  The attacker peer's
## [AttackExecutor] reacts via [signal CommandProcessor.command_executed]
## and clears the redirect step + processes the next defense commit.
func execute(game_state: GameState) -> Dictionary:
	var attack: CurrentAttackState = game_state.current_attack_state
	var token_index: int = int(payload.get("token_index", -1))
	var effects: Array[Dictionary] = attack.resolved_defense_effects
	effects.append({
		"token_index": token_index,
		"token_type": int(Constants.DefenseToken.REDIRECT),
	})
	var replacement: CurrentAttackState = attack.with_patch({
		"resolved_defense_effects": effects,
		"defense_stage": CurrentAttackState.DEFENSE_COMPLETE \
				if _all_committed_effects_resolved(
						attack.committed_defense_tokens, effects) \
				else CurrentAttackState.DEFENSE_RESOLVING,
	})
	if replacement == null or not game_state.set_current_attack_state(replacement):
		return {}
	return {
		"attack_id": attack.attack_id,
		"ship_index": attack.defender_index,
		"token_index": token_index,
	}


func _is_next_unresolved_redirect(attack: CurrentAttackState,
		ship: ShipInstance, token_index: int) -> bool:
	var resolved: Dictionary = {}
	for effect: Dictionary in attack.resolved_defense_effects:
		resolved[int(effect.get("token_index", -1))] = true
	for committed_index: int in attack.committed_defense_tokens:
		if resolved.has(committed_index):
			continue
		return committed_index == token_index \
				and token_index >= 0 and token_index < ship.defense_tokens.size() \
				and int(ship.defense_tokens[token_index].get("type", -1)) \
						== int(Constants.DefenseToken.REDIRECT)
	return false


func _all_committed_effects_resolved(committed: Array[int],
		effects: Array[Dictionary]) -> bool:
	var resolved: Dictionary = {}
	for effect: Dictionary in effects:
		resolved[int(effect.get("token_index", -1))] = true
	for token_index: int in committed:
		if not resolved.has(token_index):
			return false
	return true
