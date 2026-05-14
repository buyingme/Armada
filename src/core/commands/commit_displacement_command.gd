## CommitDisplacementCommand
##
## Closes the squadron-displacement flow.  Applies each placed squadron's
## final normalised position to [SquadronInstance] and clears
## [member GameState.interaction_flow] back to NONE so the activation
## flow can resume.
##
## Submitted by the controller peer (the non-moving player) once they confirm
## all placements via [DisplacementModal].  Phase I6b-4.
##
## Payload:
##   "placements" — Array[Dictionary] of
##                  [code]{
##                    "owner": int,
##                    "squadron_index": int,
##                    "pos_x": float,   # normalised 0.0–1.0
##                    "pos_y": float,
##                  }[/code].
##
## Rules Reference: RRG "Overlapping", p.8 — OV-001 to OV-004.
class_name CommitDisplacementCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("commit_displacement", func(player: int,
			pl: Dictionary) -> GameCommand:
		return CommitDisplacementCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "commit_displacement", p_payload)


## Validates that the controller peer may commit placements.
##
## - A [code]SQUADRON_DISPLACEMENT[/code] flow must be active.
## - [code]player_index[/code] must equal the flow's
##   [code]controller_player[/code].
## - Every placement must reference an existing, non-destroyed squadron.
## - Every position must be normalised in [code][0.0, 1.0][/code].
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	var flow: InteractionFlow = game_state.interaction_flow
	if flow == null \
			or flow.flow_type \
					!= Constants.InteractionFlow.SQUADRON_DISPLACEMENT:
		return "No active displacement flow."
	if player_index != flow.controller_player:
		return "Only the displacement controller may commit placements."
	var raw_list: Variant = payload.get("placements", [])
	if not (raw_list is Array):
		return "placements must be an Array."
	var list: Array = raw_list as Array
	if list.is_empty():
		return "placements must not be empty."
	for entry: Variant in list:
		if not (entry is Dictionary):
			return "placements entry must be a Dictionary."
		var d: Dictionary = entry as Dictionary
		var owner: int = int(d.get("owner", -1))
		var sq_idx: int = int(d.get("squadron_index", -1))
		var sq: SquadronInstance = game_state.get_squadron(owner, sq_idx)
		if sq == null:
			return "Placed squadron not found (owner=%d idx=%d)." \
					% [owner, sq_idx]
		if sq.is_destroyed():
			return "Placed squadron is destroyed (owner=%d idx=%d)." \
					% [owner, sq_idx]
		var px: float = float(d.get("pos_x", -1.0))
		var py: float = float(d.get("pos_y", -1.0))
		if px < 0.0 or px > 1.0 or py < 0.0 or py > 1.0:
			return "Placement position out of range (%.3f, %.3f)." \
					% [px, py]
	return ""


## Applies the placements and clears the displacement flow.
func execute(game_state: GameState) -> Dictionary:
	var raw_list: Array = payload.get("placements", []) as Array
	var applied: Array = []
	for entry: Variant in raw_list:
		if not (entry is Dictionary):
			continue
		var d: Dictionary = entry as Dictionary
		var owner: int = int(d.get("owner", -1))
		var sq_idx: int = int(d.get("squadron_index", -1))
		var sq: SquadronInstance = game_state.get_squadron(owner, sq_idx)
		if sq == null:
			continue
		var px: float = float(d.get("pos_x", 0.0))
		var py: float = float(d.get("pos_y", 0.0))
		sq.pos_x = px
		sq.pos_y = py
		applied.append({
			"owner": owner,
			"squadron_index": sq_idx,
			"pos_x": px,
			"pos_y": py,
		})
	# Clear the displacement flow.  GameBoard's post-displacement handler
	# then resumes the maneuvering ship's activation (camera flip back +
	# end-activation button).  The activation flow_type is restored when
	# the next [AdvanceActivationStepCommand] runs, so there is no need
	# to push SHIP_ACTIVATION back here.
	game_state.interaction_flow = InteractionFlow.empty()
	return {"placements": applied}
