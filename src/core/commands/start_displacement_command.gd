## StartDisplacementCommand
##
## Opens the squadron-displacement flow after a ship maneuver causes
## ship–squadron overlap.  Mutates [member GameState.interaction_flow]
## to [code]SQUADRON_DISPLACEMENT / DISPLACEMENT_PLACE[/code] with the
## non-moving (opposing) peer as [code]controller_player[/code], so
## [UIProjector] can route the displacement modal to the correct peer.
##
## Payload:
##   "ship_index"           — index of the maneuvering ship in the active
##                            player's fleet.  The ship's pose comes from
##                            [GameState] so peers reproduce the same
##                            ship base for the touch-validation step.
##   "displaced_squadrons"  — Array[Dictionary] of
##                            [code]{ "owner": int, "squadron_index": int }[/code]
##                            entries identifying which squadrons must be
##                            re-placed.
##   "controller_player"    — int (0 or 1) — the peer that must drive the
##                            placement modal.  Per RRG "Overlapping", p.8
##                            this is the player who is NOT moving the
##                            ship, regardless of who owns the displaced
##                            squadrons.
##
## Rules Reference: RRG "Overlapping", p.8 — OV-001 to OV-004.
class_name StartDisplacementCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("start_displacement", func(player: int,
			pl: Dictionary) -> GameCommand:
		return StartDisplacementCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "start_displacement", p_payload)


## Validates that displacement can be opened.
##
## - Phase must be Ship Phase (overlap occurs during a maneuver).
## - Maneuvering ship must exist and not be destroyed.
## - Each listed squadron must exist and not be destroyed.
## - [code]controller_player[/code] must be 0 or 1.
## - No other displacement flow may already be active.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if game_state.current_phase != Constants.GamePhase.SHIP:
		return "Not in Ship Phase."
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	if ship == null:
		return "Maneuvering ship not found."
	if ship.is_destroyed():
		return "Maneuvering ship is destroyed."
	var controller: int = int(payload.get("controller_player", -1))
	if controller != 0 and controller != 1:
		return "controller_player must be 0 or 1."
	var raw_list: Variant = payload.get("displaced_squadrons", [])
	if not (raw_list is Array):
		return "displaced_squadrons must be an Array."
	var list: Array = raw_list as Array
	if list.is_empty():
		return "displaced_squadrons must not be empty."
	for entry: Variant in list:
		if not (entry is Dictionary):
			return "displaced_squadrons entry must be a Dictionary."
		var d: Dictionary = entry as Dictionary
		var owner: int = int(d.get("owner", -1))
		var sq_idx: int = int(d.get("squadron_index", -1))
		var sq: SquadronInstance = game_state.get_squadron(owner, sq_idx)
		if sq == null:
			return "Displaced squadron not found (owner=%d idx=%d)." \
					% [owner, sq_idx]
		if sq.is_destroyed():
			return "Displaced squadron is destroyed (owner=%d idx=%d)." \
					% [owner, sq_idx]
	if game_state.interaction_flow != null \
			and game_state.interaction_flow.flow_type \
					== Constants.InteractionFlow.SQUADRON_DISPLACEMENT:
		return "Displacement flow already active."
	return ""


## Mutates [member GameState.interaction_flow] to open the displacement
## modal for the non-moving player named by [code]controller_player[/code].
func execute(game_state: GameState) -> Dictionary:
	var controller: int = int(payload.get("controller_player", -1))
	var ship_index: int = int(payload.get("ship_index", -1))
	var raw_list: Array = payload.get("displaced_squadrons", []) as Array
	# Defensive deep copy so later payload mutation cannot leak into
	# GameState.interaction_flow.payload.
	var list_copy: Array = []
	for entry: Variant in raw_list:
		if entry is Dictionary:
			list_copy.append((entry as Dictionary).duplicate(true))
	game_state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SQUADRON_DISPLACEMENT,
			Constants.InteractionStep.DISPLACEMENT_PLACE,
			controller,
			Constants.Visibility.ALL,
			{
				"ship_index": ship_index,
				"displaced_squadrons": list_copy,
			})
	return {
		"ship_index": ship_index,
		"controller_player": controller,
		"displaced_squadrons": list_copy,
	}
