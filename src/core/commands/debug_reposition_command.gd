## DebugRepositionCommand
##
## Purpose-specific authoritative DEBUG setup transaction for a single ship or
## squadron transform.  It deliberately has no normal movement lifecycle,
## activation, opportunity, or action semantics.
class_name DebugRepositionCommand
extends GameCommand


const TARGET_SHIP: String = "ship"
const TARGET_SQUADRON: String = "squadron"


func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, "debug_reposition", p_payload)


func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if not base.is_empty():
		return base
	var kind: String = str(payload.get("target_kind", ""))
	if kind != TARGET_SHIP and kind != TARGET_SQUADRON:
		return "Invalid debug reposition target_kind."
	var owner: int = int(payload.get("owner_player", -1))
	if owner < 0 or owner >= Constants.PLAYER_COUNT:
		return "Invalid owner_player."
	var unit_index: int = int(payload.get("unit_index", -1))
	var target: Variant = _target(game_state, kind, owner, unit_index)
	if target == null:
		return "Debug reposition target not found."
	if target.is_destroyed():
		return "Debug reposition target is destroyed."
	if not _has_finite_normalized_transform():
		return "Invalid debug reposition transform."
	if not GameScale.is_initialised or GameScale.play_area_size_px.x <= 0.0 \
			or GameScale.play_area_size_px.y <= 0.0:
		return "Board geometry is unavailable."
	if not _is_valid_placement(game_state, kind, target):
		return "Debug reposition transform is outside the board or overlaps a unit."
	return ""


func execute(game_state: GameState) -> Dictionary:
	var kind: String = str(payload.get("target_kind", ""))
	var owner: int = int(payload.get("owner_player", -1))
	var unit_index: int = int(payload.get("unit_index", -1))
	var target: Variant = _target(game_state, kind, owner, unit_index)
	if target == null:
		return {}
	target.pos_x = float(payload.get("pos_x", 0.0))
	target.pos_y = float(payload.get("pos_y", 0.0))
	target.rotation_deg = float(payload.get("rotation_deg", 0.0))
	return {
		"target_kind": kind,
		"owner_player": owner,
		"unit_index": unit_index,
		"pos_x": target.pos_x,
		"pos_y": target.pos_y,
		"rotation_deg": target.rotation_deg,
	}


func _has_finite_normalized_transform() -> bool:
	for key: String in ["pos_x", "pos_y", "rotation_deg"]:
		if not payload.has(key):
			return false
		var value: float = float(payload.get(key))
		if is_nan(value) or is_inf(value):
			return false
	var x: float = float(payload.get("pos_x", -1.0))
	var y: float = float(payload.get("pos_y", -1.0))
	var rotation: float = float(payload.get("rotation_deg", -1.0))
	return x >= 0.0 and x <= 1.0 and y >= 0.0 and y <= 1.0 \
			and rotation >= 0.0 and rotation < 360.0


func _target(game_state: GameState, kind: String, owner: int,
		unit_index: int) -> Variant:
	if kind == TARGET_SHIP:
		return game_state.get_ship(owner, unit_index)
	return game_state.get_squadron(owner, unit_index)


func _is_valid_placement(game_state: GameState, kind: String,
		target: Variant) -> bool:
	var desired: Vector2 = Vector2(
			float(payload.get("pos_x", 0.0)),
			float(payload.get("pos_y", 0.0))) * GameScale.play_area_size_px
	var rotation: float = deg_to_rad(float(payload.get("rotation_deg", 0.0)))
	var mover: TokenMover = TokenMover.new()
	var other_ships: Array = _other_ship_rects(game_state, target)
	var other_squadrons: Array = _other_squad_circles(game_state, target)
	var resolved: Vector2
	if kind == TARGET_SHIP:
		if target.ship_data == null:
			return false
		resolved = mover.resolve_ship_position_in_area(
			desired, target.get_pixel_position(GameScale.play_area_size_px),
			target.ship_data.ship_size, rotation, target.ship_data.faction,
			other_ships, other_squadrons, -1.0, -1.0,
			GameScale.play_area_size_px, false)
	else:
		if target.squadron_data == null:
			return false
		resolved = mover.resolve_squadron_position_in_area(
			desired, target.get_pixel_position(GameScale.play_area_size_px),
			GameScale.squadron_base_diameter_px * 0.5,
			target.squadron_data.faction, other_ships, other_squadrons,
			-1.0, -1.0, GameScale.play_area_size_px, false)
	return resolved.is_equal_approx(desired)


func _other_ship_rects(game_state: GameState, excluded: Variant) -> Array:
	var result: Array = []
	for owner: int in range(Constants.PLAYER_COUNT):
		var player: PlayerState = game_state.get_player_state(owner)
		if player == null:
			continue
		for raw_ship: Variant in player.ships:
			var ship: ShipInstance = raw_ship as ShipInstance
			if ship == null or ship == excluded or ship.is_destroyed() \
					or ship.ship_data == null:
				continue
			var size: Vector2 = GameScale.get_base_size(ship.ship_data.ship_size)
			result.append({"position": ship.get_pixel_position(GameScale.play_area_size_px),
				"rotation": ship.get_rotation_rad(), "half_w": size.x * 0.5,
				"half_l": size.y * 0.5})
	return result


func _other_squad_circles(game_state: GameState, excluded: Variant) -> Array:
	var result: Array = []
	for owner: int in range(Constants.PLAYER_COUNT):
		var player: PlayerState = game_state.get_player_state(owner)
		if player == null:
			continue
		for raw_squadron: Variant in player.squadrons:
			var squadron: SquadronInstance = raw_squadron as SquadronInstance
			if squadron == null or squadron == excluded or squadron.is_destroyed():
				continue
			result.append({"position": squadron.get_pixel_position(
				GameScale.play_area_size_px),
				"radius": GameScale.squadron_base_diameter_px * 0.5})
	return result
