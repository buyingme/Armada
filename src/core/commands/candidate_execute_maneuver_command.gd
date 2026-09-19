## Dormant protocol-7 ExecuteManeuverCommand implementation candidate.
##
## This script is intentionally not registered before WP6. Direct tests use it
## to prove the accepted intent-only commitment transaction while the live
## protocol-6 command retains its old shape.
class_name CandidateExecuteManeuverCommand
extends GameCommand


const AUTHORITY: GDScript = preload(
		"res://src/core/movement/maneuver_authority.gd")
const EXACT_PAYLOAD_KEYS: Array[String] = [
	"ship_index",
	"ship_activation_identity",
	"speed",
	"yaw_clicks",
	"yaw_bonus_joint",
]


func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, "execute_maneuver", p_payload)


func application_contract_id() -> String:
	return "execute_maneuver"


func application_contract_version() -> int:
	return 2


func project_application_result(authority_result: Dictionary,
		viewer_player: int) -> Dictionary:
	return authority_result.duplicate(true) \
			if viewer_player in [0, 1] and _result_is_valid(authority_result) \
			else {}


func execute_with_application_result(game_state: GameState,
		application_result: Dictionary) -> Dictionary:
	if not _result_is_valid(application_result) \
			or not validate(game_state).is_empty():
		return {}
	var ship: ShipInstance = game_state.get_ship(
			player_index, int(payload["ship_index"]))
	var derivation: Dictionary = AUTHORITY.derive(
			game_state, player_index, int(payload["ship_index"]),
			int(payload["speed"]), payload["yaw_clicks"] as Array,
			int(payload["yaw_bonus_joint"]))
	var sources: Dictionary = AUTHORITY.derive_navigate_sources(
			ship, int(payload["speed"]), int(payload["yaw_bonus_joint"]))
	if not bool(derivation.get("ok", false)) \
			or not bool(sources.get("ok", false)):
		return {}
	var expected: Dictionary = {
		"owner_player": player_index,
		"ship_index": int(payload["ship_index"]),
		"ship_activation_identity": payload["ship_activation_identity"],
		"maneuver_execution_id": "maneuver:%d" % sequence,
		"speed": payload["speed"],
		"yaw_clicks": (payload["yaw_clicks"] as Array).duplicate(),
		"yaw_bonus_joint": payload["yaw_bonus_joint"],
		"navigate_dial_spent": bool(sources["navigate_dial_spent"]),
		"navigate_token_spent": bool(sources["navigate_token_spent"]),
		"navigate_speed_changed": bool(sources["navigate_speed_changed"]),
		"pos_x": float(derivation["pos_x"]),
		"pos_y": float(derivation["pos_y"]),
		"rotation_deg": float(derivation["rotation_deg"]),
		"maneuver_opportunity_disposition": "OPEN",
	}
	if application_result != expected:
		return {}
	var applied: Dictionary = execute(game_state)
	return application_result.duplicate(true) if applied == expected else {}


func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if not base.is_empty():
		return base
	if not _has_exact_keys(payload, EXACT_PAYLOAD_KEYS):
		return "Invalid execute_maneuver payload shape."
	if game_state.current_phase != Constants.GamePhase.SHIP:
		return "Not in Ship Phase."
	if typeof(payload["ship_index"]) != TYPE_INT \
			or typeof(payload["ship_activation_identity"]) != TYPE_STRING \
			or typeof(payload["speed"]) != TYPE_INT \
			or typeof(payload["yaw_clicks"]) != TYPE_ARRAY \
			or typeof(payload["yaw_bonus_joint"]) != TYPE_INT:
		return "Invalid execute_maneuver payload types."
	var ship_index: int = int(payload["ship_index"])
	var ship: ShipInstance = game_state.get_ship(player_index, ship_index)
	if ship == null:
		return "Ship not found."
	if ship.is_destroyed():
		return "Ship is destroyed."
	if ship.command_dial_stack == null or ship.command_tokens == null:
		return "Ship command resources are unavailable."
	var activation_identity: String = str(payload["ship_activation_identity"])
	if activation_identity.is_empty() \
			or activation_identity != ship.ship_activation_identity:
		return "Stale or missing ship activation identity."
	if ship.maneuver_opportunity_disposition \
			!= ShipInstance.ACTIVATION_DISPOSITION_OPEN \
			or ship.has_active_maneuver_execution():
		return "Maneuver commitment is not open."
	if not game_state.validate_declaration_adjacent_state():
		return "Declaration-adjacent state is invalid."
	return AUTHORITY.validate_course_intent(
			game_state, player_index, ship_index, int(payload["speed"]),
			payload["yaw_clicks"] as Array, int(payload["yaw_bonus_joint"]))


func execute(game_state: GameState) -> Dictionary:
	if not validate(game_state).is_empty():
		return {}
	var ship_index: int = int(payload["ship_index"])
	var ship: ShipInstance = game_state.get_ship(player_index, ship_index)
	var speed: int = int(payload["speed"])
	var yaw_clicks: Array = (payload["yaw_clicks"] as Array).duplicate()
	var yaw_bonus_joint: int = int(payload["yaw_bonus_joint"])
	var activation_identity: String = str(payload["ship_activation_identity"])
	var maneuver_execution_id: String = "maneuver:%d" % sequence
	var derivation: Dictionary = AUTHORITY.derive(
			game_state, player_index, ship_index, speed, yaw_clicks,
			yaw_bonus_joint)
	if not bool(derivation.get("ok", false)):
		return {}
	var sources: Dictionary = AUTHORITY.derive_navigate_sources(
			ship, speed, yaw_bonus_joint)
	if not bool(sources.get("ok", false)):
		return {}
	var snapshot: Dictionary = _snapshot(ship)
	if bool(sources["navigate_dial_spent"]):
		var spent: Dictionary = ship.command_dial_stack.spend_revealed()
		if spent.is_empty() \
				or int(spent.get("command", -1)) \
						!= int(Constants.CommandType.NAVIGATE):
			_restore(ship, snapshot)
			return {}
	if bool(sources["navigate_token_spent"]) \
			and not ship.command_tokens.spend_token(
					Constants.CommandType.NAVIGATE):
		_restore(ship, snapshot)
		return {}
	ship.current_speed = speed
	var committed_result: Dictionary = {
		"yaw_clicks": yaw_clicks.duplicate(),
		"yaw_bonus_joint": yaw_bonus_joint,
		"pos_x": float(derivation["pos_x"]),
		"pos_y": float(derivation["pos_y"]),
		"rotation_deg": float(derivation["rotation_deg"]),
	}
	var collision: Dictionary = _collision_record(
			derivation["ship_collision"] as Dictionary,
			activation_identity, maneuver_execution_id)
	if collision.is_empty() or not ship.commit_maneuver_execution(
			activation_identity, maneuver_execution_id,
			bool(sources["navigate_speed_changed"]), committed_result,
			collision) \
			or not game_state.validate_declaration_adjacent_state():
		_restore(ship, snapshot)
		return {}
	return {
		"owner_player": player_index,
		"ship_index": ship_index,
		"ship_activation_identity": activation_identity,
		"maneuver_execution_id": maneuver_execution_id,
		"speed": speed,
		"yaw_clicks": yaw_clicks,
		"yaw_bonus_joint": yaw_bonus_joint,
		"navigate_dial_spent": bool(sources["navigate_dial_spent"]),
		"navigate_token_spent": bool(sources["navigate_token_spent"]),
		"navigate_speed_changed": bool(sources["navigate_speed_changed"]),
		"pos_x": committed_result["pos_x"],
		"pos_y": committed_result["pos_y"],
		"rotation_deg": committed_result["rotation_deg"],
		"maneuver_opportunity_disposition":
				ShipInstance.ACTIVATION_DISPOSITION_OPEN,
	}


static func _snapshot(ship: ShipInstance) -> Dictionary:
	return {
		"current_speed": ship.current_speed,
		"pos_x": ship.pos_x,
		"pos_y": ship.pos_y,
		"rotation_deg": ship.rotation_deg,
		"activation_boundary": ship.ship_activation_boundary_snapshot(),
		"command_dial_stack": ship.command_dial_stack.serialize(),
		"command_tokens": ship.command_tokens.serialize(),
	}


static func _restore(ship: ShipInstance, snapshot: Dictionary) -> void:
	ship.current_speed = int(snapshot["current_speed"])
	ship.pos_x = float(snapshot["pos_x"])
	ship.pos_y = float(snapshot["pos_y"])
	ship.rotation_deg = float(snapshot["rotation_deg"])
	ship.command_dial_stack = CommandDialStack.deserialize(
			snapshot["command_dial_stack"] as Dictionary)
	ship.command_tokens = CommandTokenManager.deserialize(
			snapshot["command_tokens"] as Dictionary)
	ship.restore_ship_activation_boundary(
			snapshot["activation_boundary"] as Dictionary)


static func _collision_record(derived: Dictionary,
		activation_identity: String, maneuver_execution_id: String) -> Dictionary:
	if derived == {"kind": "none"}:
		return derived.duplicate(true)
	if derived.keys().size() != 3 \
			or str(derived.get("kind", "")) != "closest_ship" \
			or typeof(derived.get("target_owner_player")) != TYPE_INT \
			or typeof(derived.get("target_ship_index")) != TYPE_INT:
		return {}
	var target_owner: int = int(derived["target_owner_player"])
	var target_index: int = int(derived["target_ship_index"])
	return {
		"kind": "closest_ship",
		"target_owner_player": target_owner,
		"target_ship_index": target_index,
		"exact_once_key": "collision:%s:%s:%d:%d" % [
			activation_identity, maneuver_execution_id,
			target_owner, target_index],
		"damage_resolved": false,
	}


static func _has_exact_keys(value: Dictionary,
		expected: Array[String]) -> bool:
	if value.size() != expected.size():
		return false
	for key: String in expected:
		if not value.has(key):
			return false
	return true


static func _result_is_valid(result: Dictionary) -> bool:
	var keys: Array[String] = [
		"owner_player", "ship_index", "ship_activation_identity",
		"maneuver_execution_id", "speed", "yaw_clicks", "yaw_bonus_joint",
		"navigate_dial_spent", "navigate_token_spent",
		"navigate_speed_changed", "pos_x", "pos_y", "rotation_deg",
		"maneuver_opportunity_disposition",
	]
	if not _has_exact_keys(result, keys) \
			or typeof(result["owner_player"]) != TYPE_INT \
			or int(result["owner_player"]) not in [0, 1] \
			or typeof(result["ship_index"]) != TYPE_INT \
			or int(result["ship_index"]) < 0 \
			or typeof(result["speed"]) != TYPE_INT \
			or int(result["speed"]) < 0 \
			or typeof(result["yaw_bonus_joint"]) != TYPE_INT \
			or not result["yaw_clicks"] is Array \
			or typeof(result["navigate_dial_spent"]) != TYPE_BOOL \
			or typeof(result["navigate_token_spent"]) != TYPE_BOOL \
			or typeof(result["navigate_speed_changed"]) != TYPE_BOOL \
			or result["maneuver_opportunity_disposition"] != "OPEN":
		return false
	if (result["yaw_clicks"] as Array).size() != int(result["speed"]):
		return false
	for click: Variant in result["yaw_clicks"] as Array:
		if typeof(click) != TYPE_INT:
			return false
	for key: String in ["ship_activation_identity", "maneuver_execution_id"]:
		if typeof(result[key]) != TYPE_STRING or str(result[key]).is_empty():
			return false
	for key: String in ["pos_x", "pos_y", "rotation_deg"]:
		if typeof(result[key]) != TYPE_FLOAT \
				or not is_finite(float(result[key])):
			return false
	return true
