## Pure identity-bound evaluator for the next currently legal Maneuver action.
## It stores no route, stage, queue, or pending-work list.
class_name ManeuverExecutionEvaluator
extends RefCounted


const AUTHORITY: GDScript = preload(
		"res://src/core/movement/maneuver_authority.gd")
const PRE_MOVEMENT: GDScript = preload(
		"res://src/core/movement/maneuver_pre_movement_evaluator.gd")
const OBSTACLES: GDScript = preload(
		"res://src/core/geometry/obstacle_overlap_authority.gd")


static func next_action(game_state: GameState, owner_player: int,
		ship_index: int) -> Dictionary:
	if game_state == null:
		return {}
	var ship: ShipInstance = game_state.get_ship(owner_player, ship_index)
	if ship == null or ship.is_destroyed():
		return {}
	var execution: Dictionary = ship.active_maneuver_execution_snapshot()
	if execution.is_empty():
		return {}
	var base: Dictionary = {
		"owner_player": owner_player,
		"ship_index": ship_index,
		"ship_activation_identity": execution["ship_activation_identity"],
		"maneuver_execution_id": execution["maneuver_execution_id"],
	}
	if not bool(execution["final_transform_applied"]):
		var thrusters: Array[String] = PRE_MOVEMENT \
				.unresolved_thruster_fissures(ship)
		if not thrusters.is_empty():
			return {"kind": "decision", "command_type": "resolve_thruster_fissure",
				"player_index": owner_player, "payload": base,
				"public_card_refs": thrusters}
		if ship.has_active_immediate_resolution():
			return _immediate_action(ship, base)
		return {"kind": "command", "command_type": "apply_maneuver_transform",
			"player_index": owner_player, "payload": base}
	var displaced: Array[Dictionary] = AUTHORITY \
			.derive_affected_squadrons_from_canonical(
					game_state, owner_player, ship_index)
	if not displaced.is_empty():
		if game_state.interaction_flow != null \
				and game_state.interaction_flow.flow_type \
						== Constants.InteractionFlow.SQUADRON_DISPLACEMENT:
			return {"kind": "waiting", "command_type": "commit_displacement"}
		var start_payload: Dictionary = base.duplicate(true)
		start_payload["displaced_squadrons"] = displaced
		return {"kind": "command", "command_type": "start_displacement",
			"player_index": owner_player, "payload": start_payload}
	var collision: Dictionary = execution["ship_collision"] as Dictionary
	if str(collision["kind"]) == "closest_ship" \
			and not bool(collision["damage_resolved"]):
		var collision_payload: Dictionary = base.duplicate(true)
		for key: String in [
			"target_owner_player", "target_ship_index", "exact_once_key"]:
			collision_payload[key] = collision[key]
		return {"kind": "command",
			"command_type": "resolve_ship_collision_damage",
			"player_index": owner_player, "payload": collision_payload}
	if str(collision["kind"]) == "closest_ship":
		var damaged_controls: Array[String] = []
		for raw_card: Variant in ship.faceup_damage:
			if not raw_card is DamageCard:
				continue
			var card: DamageCard = raw_card as DamageCard
			if card.is_faceup and card.effect_id == "damaged_controls" \
					and not card.public_card_ref.is_empty() \
					and card.last_damaged_controls_execution_id \
							!= str(execution["maneuver_execution_id"]):
				damaged_controls.append(card.public_card_ref)
		if not damaged_controls.is_empty():
			var controls_payload: Dictionary = base.duplicate(true)
			controls_payload["public_card_ref"] = damaged_controls[0]
			controls_payload["overlap_kind"] = "ship"
			return {"kind": "command",
				"command_type": "resolve_damaged_controls",
				"player_index": owner_player, "payload": controls_payload}
	var overlaps: Array[Dictionary] = OBSTACLES.unresolved_overlaps(
			game_state, owner_player, ship_index,
			str(execution["maneuver_execution_id"]))
	if str(collision["kind"]) == "none" and not overlaps.is_empty():
		var obstacle_controls: Array[String] = _unresolved_card_refs(
				ship, "damaged_controls", "last_damaged_controls_execution_id",
				str(execution["maneuver_execution_id"]))
		if not obstacle_controls.is_empty():
			var controls_payload: Dictionary = base.duplicate(true)
			controls_payload["public_card_ref"] = obstacle_controls[0]
			controls_payload["overlap_kind"] = "obstacle"
			controls_payload["obstacle_id"] = overlaps[0]["obstacle_id"]
			return {"kind": "command",
				"command_type": "resolve_damaged_controls",
				"player_index": owner_player, "payload": controls_payload}
	var order: Array = execution.get("obstacle_resolution_order", []) as Array
	if order.is_empty() and not overlaps.is_empty():
		var order_payload: Dictionary = base.duplicate(true)
		order_payload["obstacle_ids"] = []
		for obstacle: Dictionary in overlaps:
			(order_payload["obstacle_ids"] as Array).append(
					obstacle["obstacle_id"])
		return {"kind": "command" if overlaps.size() == 1 else "decision",
			"command_type": "commit_maneuver_obstacle_order",
			"player_index": owner_player, "payload": order_payload,
			"obstacles": overlaps}
	var asteroid: Dictionary = ship.active_asteroid_resolution_snapshot()
	if not asteroid.is_empty():
		return _immediate_action(ship, base)
	var debris: Dictionary = ship.active_debris_resolution_snapshot()
	if not debris.is_empty():
		var debris_payload: Dictionary = base.duplicate(true)
		debris_payload["obstacle_id"] = debris["obstacle_id"]
		return {"kind": "decision", "command_type": "resolve_debris_overlap",
			"player_index": int(debris["controller_player"]),
			"payload": debris_payload,
			"hull_zones": ship.current_shields.keys()}
	var station: Dictionary = ship.active_station_resolution_snapshot()
	if not station.is_empty():
		var station_payload: Dictionary = base.duplicate(true)
		station_payload["obstacle_id"] = station["obstacle_id"]
		var faceup_refs: Array[String] = []
		for raw_card: Variant in ship.faceup_damage:
			if raw_card is DamageCard and not (
					raw_card as DamageCard).public_card_ref.is_empty():
				faceup_refs.append((raw_card as DamageCard).public_card_ref)
		if faceup_refs.is_empty() and ship.get_facedown_damage_count() == 0:
			station_payload["action"] = "no_option"
			return {"kind": "command",
				"command_type": "resolve_station_overlap",
				"player_index": owner_player, "payload": station_payload}
		return {"kind": "decision", "command_type": "resolve_station_overlap",
			"player_index": int(station["controller_player"]),
			"payload": station_payload, "faceup_refs": faceup_refs,
			"facedown_count": ship.get_facedown_damage_count()}
	if not overlaps.is_empty():
		var by_id: Dictionary = {}
		for obstacle: Dictionary in overlaps:
			by_id[str(obstacle["obstacle_id"])] = obstacle
		for raw_id: Variant in order:
			var obstacle_id: String = str(raw_id)
			if not by_id.has(obstacle_id):
				continue
			var obstacle: Dictionary = by_id[obstacle_id]
			if str(obstacle["obstacle_type"]) == "asteroid":
				var asteroid_payload: Dictionary = base.duplicate(true)
				asteroid_payload["obstacle_id"] = obstacle_id
				return {"kind": "command",
					"command_type": "resolve_asteroid_overlap",
					"player_index": owner_player,
					"payload": asteroid_payload}
			# A typed decision record should have been opened by the command
			# that committed/returned from the prior obstacle.
			return {"kind": "waiting", "command_type": ""}
	if ship.current_speed > 1:
		var ruptured: Array[String] = _unresolved_card_refs(
				ship, "ruptured_engine",
				"last_ruptured_engine_execution_id",
				str(execution["maneuver_execution_id"]))
		if not ruptured.is_empty():
			var ruptured_payload: Dictionary = base.duplicate(true)
			ruptured_payload["public_card_ref"] = ruptured[0]
			return {"kind": "decision",
				"command_type": "resolve_ruptured_engine",
				"player_index": owner_player,
				"payload": ruptured_payload,
				"hull_zones": ship.current_shields.keys(),
				"public_card_refs": ruptured}
	return {"kind": "command", "command_type": "complete_maneuver",
		"player_index": owner_player, "payload": base}


static func _unresolved_card_refs(ship: ShipInstance, effect_id: String,
		marker_field: String, execution_id: String) -> Array[String]:
	var result: Array[String] = []
	for raw_card: Variant in ship.faceup_damage:
		if not raw_card is DamageCard:
			continue
		var card: DamageCard = raw_card as DamageCard
		var marker: String = ""
		if marker_field == "last_damaged_controls_execution_id":
			marker = card.last_damaged_controls_execution_id
		elif marker_field == "last_ruptured_engine_execution_id":
			marker = card.last_ruptured_engine_execution_id
		if card.is_faceup and card.effect_id == effect_id \
				and not card.public_card_ref.is_empty() \
				and marker != execution_id:
			result.append(card.public_card_ref)
	return result


static func _immediate_action(ship: ShipInstance,
		maneuver_base: Dictionary) -> Dictionary:
	var record: Dictionary = ship.active_immediate_resolution_snapshot()
	if record.is_empty() or str(record.get("enclosing_kind", "")) != "maneuver":
		return {"kind": "waiting", "command_type": "resolve_immediate_effect"}
	var payload: Dictionary = {
		"owner_player": maneuver_base["owner_player"],
		"ship_index": maneuver_base["ship_index"],
		"public_card_ref": record["public_card_ref"],
		"immediate_resolution_id": record["immediate_resolution_id"],
		"enclosing_kind": "maneuver",
		"ship_activation_identity": record["ship_activation_identity"],
		"maneuver_execution_id": record["maneuver_execution_id"],
		"maneuver_source_kind": record["maneuver_source_kind"],
		"maneuver_source_id": record["maneuver_source_id"],
	}
	var effect: String = str(record["effect_id"])
	var actor: int = int(record["actor_player"])
	match effect:
		"structural_damage", "life_support_failure":
			return {"kind":"command", "command_type":"resolve_immediate_effect",
				"player_index":int(payload["owner_player"]), "payload":payload}
		"projector_misaligned":
			var maximum: int = 0
			var zones: Array[String] = []
			for zone: String in ship.current_shields:
				var value: int = int(ship.current_shields[zone])
				if value > maximum:
					maximum = value; zones = [zone]
				elif value == maximum and value > 0:
					zones.append(zone)
			if zones.size() > 1:
				return {"kind":"decision", "command_type":"resolve_immediate_effect",
					"player_index":actor, "payload":payload, "choice":"projector_zone",
					"options":zones}
			return {"kind":"command", "command_type":"resolve_immediate_effect",
				"player_index":int(payload["owner_player"]), "payload":payload}
		"injured_crew":
			var tokens: Array[int] = []
			for index: int in range(ship.defense_tokens.size()):
				if int(ship.defense_tokens[index].get("state", -1)) \
						!= int(Constants.DefenseTokenState.DISCARDED):
					tokens.append(index)
			if tokens.size() > 1:
				return {"kind":"decision", "command_type":"resolve_immediate_effect",
					"player_index":actor, "payload":payload,
					"choice":"defense_token_index", "options":tokens}
			return {"kind":"command", "command_type":"resolve_immediate_effect",
				"player_index":int(payload["owner_player"]), "payload":payload}
		"shield_failure":
			return {"kind":"decision", "command_type":"resolve_immediate_effect",
				"player_index":actor, "payload":payload, "choice":"shield_zones",
				"options":ship.current_shields.keys(), "multi_select":true,
				"max_selections":2}
		"comm_noise":
			var speed_available: bool = ship.current_speed > 0
			var dial_available: bool = ship.command_dial_stack != null \
					and ship.command_dial_stack.get_hidden_count() > 0
			if speed_available and not dial_available:
				payload["comm_noise_action"] = "speed"
				return {"kind":"command", "command_type":"resolve_immediate_effect",
					"player_index":int(payload["owner_player"]), "payload":payload}
			if not speed_available and not dial_available:
				payload["comm_noise_action"] = "none"
				return {"kind":"command", "command_type":"resolve_immediate_effect",
					"player_index":int(payload["owner_player"]), "payload":payload}
			return {"kind":"decision", "command_type":"resolve_immediate_effect",
				"player_index":actor, "payload":payload, "choice":"comm_noise",
				"speed_available":speed_available,
				"dial_available":dial_available}
	return {"kind":"waiting", "command_type":"resolve_immediate_effect"}
