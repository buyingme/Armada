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
##   "ship_index"        — index of the defending ship in the
##                         player's fleet.
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


## Validates that the defender ship exists and we are in an attack
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
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	if ship == null:
		return "Defender ship not found."
	var selected: Array = payload.get("selected_indices", []) as Array
	for raw_idx: Variant in selected:
		var idx: int = int(raw_idx)
		if idx < 0 or idx >= ship.defense_tokens.size():
			return "Token index %d out of range." % idx
	var ecm_error: String = ECM_SCRIPT.validate_authorized_token_selection(
			game_state, ship, int(payload.get("ship_index", -1)), selected)
	if ecm_error != "":
		return ecm_error
	return ""


## Records any ECM-authorized locked token choice and echoes the selected
## indices so the attacker peer's [AttackExecutor] can drive the spend
## pipeline from the [signal CommandProcessor.command_executed] signal.
func execute(game_state: GameState) -> Dictionary:
	var selected: Array = payload.get("selected_indices", []) as Array
	var ecm_pending: Dictionary = ECM_SCRIPT.commit_authorized_token_selection(
			game_state, int(payload.get("ship_index", -1)), selected)
	return {
		"ship_index": payload.get("ship_index", -1),
		"selected_indices": selected.duplicate(),
		"ecm_selected_token_index": int(ecm_pending.get(
				ECM_SCRIPT.PENDING_SELECTED_TOKEN_INDEX, -1)),
	}
