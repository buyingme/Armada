## Viewer-authorized current Maneuver identity, derived only from authority
## owners. This value is recovery information, not a gameplay owner.
class_name ManeuverConsequenceProjection
extends RefCounted


static func capture_authority(state: GameState) -> Dictionary:
	if state == null or state.passive_damage_ledger != null:
		return {}
	var found: Dictionary = {}
	for owner: int in range(state.player_states.size()):
		var player: PlayerState = state.get_player_state(owner)
		for index: int in range(player.ships.size()):
			var ship: ShipInstance = player.ships[index] as ShipInstance
			if ship == null or not ship.has_active_maneuver_execution():
				continue
			if not found.is_empty():
				return {}
			var execution: Dictionary = ship.active_maneuver_execution_snapshot()
			found = {
				"owner_player": owner,
				"ship_index": index,
				"ship_activation_identity": execution[
						"ship_activation_identity"],
				"maneuver_execution_id": execution[
						"maneuver_execution_id"],
				"consequence_view": _current_view(state, ship, owner, index),
			}
	return found


static func _current_view(state: GameState, ship: ShipInstance,
		owner: int, index: int) -> Dictionary:
	for record: Dictionary in [ship.pending_obstacle_pre_effect_snapshot(),
			ship.asteroid_completion_outstanding_snapshot()]:
		if not record.is_empty():
			return {"kind": "obstacle", "obstacle_id":
				record["obstacle_id"]}
	for record: Dictionary in [
		ship.active_asteroid_resolution_snapshot(),
		ship.active_debris_resolution_snapshot(),
		ship.active_station_resolution_snapshot(),
	]:
		if not record.is_empty():
			return {"kind": "obstacle", "obstacle_id": record["obstacle_id"]}
	var action: Dictionary = ManeuverExecutionEvaluator.next_action(
			state, owner, index)
	var command_type: String = str(action.get("command_type", ""))
	var payload: Dictionary = action.get("payload", {}) as Dictionary
	match command_type:
		"resolve_thruster_fissure":
			return {"kind": "thruster_fissure", "public_card_refs":
					(action.get("public_card_refs", []) as Array).duplicate()}
		"resolve_damaged_controls":
			var view: Dictionary = {"kind": "damaged_controls",
				"public_card_refs": (action.get("public_card_refs", [])
						as Array).duplicate(),
				"overlap_kind": payload.get("overlap_kind", "")}
			if view["overlap_kind"] == "obstacle":
				view["obstacle_id"] = payload.get("obstacle_id", "")
			return view
		"resolve_ruptured_engine":
			return {"kind": "ruptured_engine", "public_card_refs":
					(action.get("public_card_refs", []) as Array).duplicate()}
		"commit_maneuver_obstacle_order":
			return {"kind": "obstacle_order", "obstacle_ids":
					(payload.get("obstacle_ids", []) as Array).duplicate()}
		"resolve_asteroid_overlap":
			return {"kind": "obstacle", "obstacle_id":
					payload.get("obstacle_id", "")}
	return {}


static func is_closed_view(view: Dictionary) -> bool:
	if view.is_empty():
		return true
	if typeof(view.get("kind")) != TYPE_STRING:
		return false
	var kind: String = view["kind"]
	match kind:
		"thruster_fissure", "ruptured_engine":
			return _exact_keys(view, ["kind", "public_card_refs"]) \
					and _unique_strings(view.get("public_card_refs"))
		"damaged_controls":
			var overlap: Variant = view.get("overlap_kind")
			if overlap == "ship":
				return _exact_keys(view, ["kind", "public_card_refs",
						"overlap_kind"]) \
						and _unique_strings(view.get("public_card_refs"))
			if overlap == "obstacle":
				return _exact_keys(view, ["kind", "public_card_refs",
						"overlap_kind", "obstacle_id"]) \
						and _unique_strings(view.get("public_card_refs")) \
						and _nonempty_string(view.get("obstacle_id"))
		"obstacle_order":
			return _exact_keys(view, ["kind", "obstacle_ids"]) \
					and _unique_strings(view.get("obstacle_ids"))
		"obstacle":
			return _exact_keys(view, ["kind", "obstacle_id"]) \
					and _nonempty_string(view.get("obstacle_id"))
	return false


static func is_closed_replacement(replacement: Dictionary) -> bool:
	if replacement.is_empty():
		return true
	if not _exact_keys(replacement, ["owner_player", "ship_index",
			"ship_activation_identity", "maneuver_execution_id",
			"consequence_view"]):
		return false
	if typeof(replacement["owner_player"]) != TYPE_INT \
			or int(replacement["owner_player"]) not in [0, 1] \
			or typeof(replacement["ship_index"]) != TYPE_INT \
			or int(replacement["ship_index"]) < 0 \
			or not _nonempty_string(replacement["ship_activation_identity"]) \
			or not _nonempty_string(replacement["maneuver_execution_id"]) \
			or not replacement["consequence_view"] is Dictionary:
		return false
	return is_closed_view(replacement["consequence_view"] as Dictionary)


## Checks the complete filtered candidate after deserialization. Private
## completion facts are deliberately absent; authority proved completeness.
static func public_state_error(state: GameState,
		replacement: Dictionary) -> String:
	if state == null or not is_closed_replacement(replacement):
		return "Malformed Maneuver consequence replacement."
	var active_owner: int = -1
	var active_index: int = -1
	for owner: int in range(state.player_states.size()):
		var player: PlayerState = state.get_player_state(owner)
		for index: int in range(player.ships.size()):
			var candidate: ShipInstance = player.ships[index] as ShipInstance
			if candidate != null and candidate.has_active_maneuver_execution():
				if active_owner >= 0:
					return "Multiple Maneuver executions."
				active_owner = owner
				active_index = index
	if active_owner < 0:
		return "Replacement names an absent Maneuver execution." \
				if not replacement.is_empty() else ""
	if replacement.is_empty() \
			or int(replacement["owner_player"]) != active_owner \
			or int(replacement["ship_index"]) != active_index:
		return "Maneuver consequence owner mismatch."
	var ship: ShipInstance = state.get_ship(active_owner, active_index)
	var execution: Dictionary = ship.active_maneuver_execution_snapshot()
	if replacement["ship_activation_identity"] != execution.get(
			"ship_activation_identity") \
			or replacement["maneuver_execution_id"] != execution.get(
					"maneuver_execution_id"):
		return "Maneuver consequence execution mismatch."
	var view: Dictionary = replacement["consequence_view"] as Dictionary
	if view.is_empty():
		if not ship.pending_obstacle_pre_effect_snapshot().is_empty() \
				or not ship.asteroid_completion_outstanding_snapshot().is_empty():
			return "Pending obstacle context has no consequence view."
		return ""
	var kind: String = view["kind"]
	var effect: String = ""
	match kind:
		"thruster_fissure":
			effect = "thruster_fissure"
			if bool(execution["final_transform_applied"]) \
					or not bool(execution["navigate_speed_changed"]):
				return "Thruster consequence is outside pre-movement timing."
		"damaged_controls":
			effect = "damaged_controls"
			if not bool(execution["final_transform_applied"]):
				return "Damaged Controls is before movement."
			var collision: Dictionary = execution["ship_collision"] as Dictionary
			if view["overlap_kind"] == "ship" and (
					collision.get("kind") != "closest_ship" \
					or not bool(collision.get("damage_resolved", false))):
				return "Damaged Controls ship context is absent."
			if view["overlap_kind"] == "obstacle":
				if collision.get("kind") != "none" \
						or not _overlaps_obstacle(state, active_owner,
								active_index, str(view["obstacle_id"])):
					return "Damaged Controls obstacle context is absent."
		"ruptured_engine":
			effect = "ruptured_engine"
			if not bool(execution["final_transform_applied"]) \
					or ship.current_speed <= 1:
				return "Ruptured Engine timing is invalid."
	if not effect.is_empty():
		for ref: Variant in view["public_card_refs"] as Array:
			var card: DamageCard = ship.faceup_card_for_public_ref(str(ref))
			if card == null or not card.is_faceup or card.effect_id != effect:
				return "Maneuver consequence card is not public on its ship."
		return ""
	if not bool(execution["final_transform_applied"]):
		return "Obstacle consequence is before movement."
	if kind == "obstacle_order":
		if not (execution["obstacle_resolution_order"] as Array).is_empty():
			return "Obstacle order was already committed."
		for obstacle_id: Variant in view["obstacle_ids"] as Array:
			if not _overlaps_obstacle(state, active_owner,
					active_index, str(obstacle_id)):
				return "Obstacle order contains an invalid overlap."
		return ""
	var obstacle_id: String = str(view["obstacle_id"])
	if not _overlaps_obstacle(state, active_owner, active_index, obstacle_id) \
			or obstacle_id not in execution["obstacle_resolution_order"]:
		return "Current obstacle is outside the committed overlap order."
	for record: Dictionary in [
		ship.pending_obstacle_pre_effect_snapshot(),
		ship.asteroid_completion_outstanding_snapshot(),
		ship.active_asteroid_resolution_snapshot(),
		ship.active_debris_resolution_snapshot(),
		ship.active_station_resolution_snapshot(),
	]:
		if not record.is_empty() and record.get("obstacle_id") != obstacle_id:
			return "Active obstacle owner contradicts the view."
	return ""


## Option B admission check. Only public pre-state, command intent, and the
## command-owned application facts are read. No gameplay state is staged or
## mutated, and private completion history is never inferred.
static func pre_mutation_error(state: GameState, command: GameCommand,
		application_result: Dictionary, replacement: Dictionary) -> String:
	if state == null or command == null \
			or not is_closed_replacement(replacement):
		return "Malformed Maneuver consequence replacement."
	var previous: Dictionary = _active_identity(state)
	var created: bool = previous.is_empty() \
			and command.command_type == "execute_maneuver"
	var retired: bool = not previous.is_empty() and _retires_execution(
			state, command, application_result, previous)
	if previous.is_empty() and not created:
		return "Replacement creates an execution without its command." \
				if not replacement.is_empty() else ""
	if retired:
		return "Replacement preserves a retired execution." \
				if not replacement.is_empty() else ""
	if replacement.is_empty():
		return "Replacement omits the active execution."
	var expected: Dictionary = previous
	if created:
		expected = {
			"owner_player": command.player_index,
			"ship_index": command.payload.get("ship_index"),
			"ship_activation_identity": command.payload.get(
					"ship_activation_identity"),
			"maneuver_execution_id": "maneuver:%d" % command.sequence,
		}
		for key: String in expected:
			if application_result.get(key) != expected[key]:
				return "Maneuver creation result contradicts its command."
	for key: String in expected:
		if replacement.get(key) != expected[key]:
			return "Maneuver consequence identity mismatch."
	var owner: int = int(replacement["owner_player"])
	var index: int = int(replacement["ship_index"])
	var ship: ShipInstance = state.get_ship(owner, index)
	if ship == null or ship.is_destroyed():
		return "Maneuver consequence ship is unavailable."
	var view: Dictionary = replacement["consequence_view"] as Dictionary
	var execution: Dictionary = ship.active_maneuver_execution_snapshot()
	var transform_applied: bool = bool(execution.get(
			"final_transform_applied", false)) \
			or command.command_type == "apply_maneuver_transform"
	var speed_changed: bool = bool(execution.get(
			"navigate_speed_changed", false)) \
			or (created and bool(application_result.get(
					"navigate_speed_changed", false)))
	var speed: int = int(application_result.get("speed", ship.current_speed)) \
			if created else ship.current_speed
	var active_obstacle_id: String = _active_obstacle_id(ship)
	var active_obstacle_continues: bool = not active_obstacle_id.is_empty() \
			and not _command_completes_obstacle(
				command, application_result, active_obstacle_id)
	var kind: String = str(view.get("kind", ""))
	if active_obstacle_continues and kind != "obstacle":
		return "Active obstacle owner contradicts the replacement."
	if command.command_type == "commit_maneuver_obstacle_order" \
			and kind != "obstacle":
		return "Committed overlap order lacks its first obstacle."
	if command.command_type == "resolve_asteroid_overlap" \
			and not str(application_result.get(
				"immediate_resolution_id", "")).is_empty() \
			and (kind != "obstacle" \
				or view.get("obstacle_id") != command.payload.get(
						"obstacle_id")):
		return "Nested Asteroid record loses its parent obstacle."
	if view.is_empty():
		return ""
	var effect: String = ""
	match kind:
		"thruster_fissure":
			effect = "thruster_fissure"
			if transform_applied or not speed_changed:
				return "Thruster consequence is outside pre-movement timing."
		"damaged_controls":
			effect = "damaged_controls"
			if not transform_applied:
				return "Damaged Controls is before movement."
			var collision: Dictionary = execution.get(
					"ship_collision", {}) as Dictionary
			if created:
				return "Damaged Controls cannot precede movement."
			if view["overlap_kind"] == "ship" and (
					collision.get("kind") != "closest_ship" \
					or (not bool(collision.get("damage_resolved", false)) \
						and command.command_type \
							!= "resolve_ship_collision_damage")):
				return "Damaged Controls ship context is absent."
			if view["overlap_kind"] == "obstacle" \
					and collision.get("kind") != "none":
				return "Damaged Controls obstacle context is absent."
		"ruptured_engine":
			effect = "ruptured_engine"
			if not transform_applied or speed <= 1:
				return "Ruptured Engine timing is invalid."
	if not effect.is_empty():
		if kind in ["thruster_fissure", "ruptured_engine"] \
				and command.command_type == "resolve_" + kind \
				and command.payload.get("public_card_ref") \
						in view["public_card_refs"]:
			return "Resolved consequence source remains current."
		if kind == "damaged_controls" \
				and view["overlap_kind"] == "obstacle" \
				and not _public_overlaps_at_transition(state, command,
						application_result, owner, index).has(
							view["obstacle_id"]):
			return "Damaged Controls obstacle does not overlap."
		var facts: Dictionary = _public_damage_facts(application_result,
				owner, index)
		var additions: Dictionary = facts["additions"] as Dictionary
		var removals: Dictionary = facts["removals"] as Dictionary
		for ref: Variant in view["public_card_refs"] as Array:
			if removals.has(ref):
				return "Retired card appears in the replacement."
			var card: DamageCard = ship.faceup_card_for_public_ref(str(ref))
			if card != null:
				if not card.is_faceup or card.effect_id != effect:
					return "Consequence reference has the wrong public card type."
			elif not additions.has(ref) \
					or (additions[ref] as Dictionary).get("effect_id") != effect \
					or (additions[ref] as Dictionary).get("is_faceup") != true:
				return "Consequence reference has no authorized public source."
		return ""
	if not transform_applied:
		return "Obstacle consequence is before movement."
	var overlapping: Dictionary = _public_overlaps_at_transition(
			state, command, application_result, owner, index)
	if kind == "obstacle_order":
		if command.command_type == "commit_maneuver_obstacle_order":
			return "Obstacle order remains uncommitted after its command."
		if not execution.is_empty() and not (
				execution.get("obstacle_resolution_order", []) as Array).is_empty():
			return "Obstacle order is already committed."
		for obstacle_id: Variant in view["obstacle_ids"] as Array:
			if not overlapping.has(obstacle_id):
				return "Obstacle order contains a non-overlap."
		return ""
	var obstacle_id: String = str(view.get("obstacle_id", ""))
	if kind == "damaged_controls":
		obstacle_id = str(view.get("obstacle_id", ""))
	if not obstacle_id.is_empty() and not overlapping.has(obstacle_id):
		return "Current obstacle does not overlap."
	if kind == "obstacle":
		var order: Array = execution.get("obstacle_resolution_order", []) as Array
		if command.command_type == "commit_maneuver_obstacle_order":
			order = command.payload.get("obstacle_ids", []) as Array
		if obstacle_id not in order:
			return "Current obstacle is outside the committed order."
		if command.command_type == "commit_maneuver_obstacle_order" \
				and (order.is_empty() or obstacle_id != order[0]):
			return "Current obstacle does not start the committed order."
		var previous_view: Dictionary = ship \
				.passive_maneuver_consequence_view_snapshot()
		if previous_view.get("kind") == "obstacle":
			var previous_id: String = str(previous_view["obstacle_id"])
			var previous_completed: bool = _command_completes_obstacle(
					command, application_result, previous_id)
			if previous_completed and obstacle_id == previous_id:
				return "Completed obstacle remains current."
			if obstacle_id != previous_id:
				if not previous_completed:
					return "Current obstacle changes without its completion."
				var prior_position: int = order.find(previous_id)
				if prior_position < 0 \
						or prior_position + 1 >= order.size() \
						or obstacle_id != order[prior_position + 1]:
					return "Current obstacle skips the accepted return order."
		var active_id: String = _active_obstacle_id(ship)
		if not active_id.is_empty() and active_id != obstacle_id \
				and not _command_completes_obstacle(
						command, application_result, active_id):
			return "Current obstacle contradicts its active owner."
		if not active_id.is_empty() and active_id != obstacle_id \
				and _command_completes_obstacle(
						command, application_result, active_id):
			var current_position: int = order.find(active_id)
			if current_position < 0 \
						or current_position + 1 >= order.size() \
						or obstacle_id != order[current_position + 1]:
				return "Current obstacle skips the accepted return order."
	return ""


static func _active_identity(state: GameState) -> Dictionary:
	var found: Dictionary = {}
	for owner: int in range(state.player_states.size()):
		var player: PlayerState = state.get_player_state(owner)
		for index: int in range(player.ships.size()):
			var ship: ShipInstance = player.ships[index] as ShipInstance
			if ship == null or not ship.has_active_maneuver_execution():
				continue
			var execution: Dictionary = ship.active_maneuver_execution_snapshot()
			if not found.is_empty():
				return {}
			found = {"owner_player": owner, "ship_index": index,
				"ship_activation_identity": execution[
						"ship_activation_identity"],
				"maneuver_execution_id": execution[
						"maneuver_execution_id"]}
	return found


static func _retires_execution(state: GameState, command: GameCommand,
		result: Dictionary, previous: Dictionary) -> bool:
	if command.command_type == "complete_maneuver" \
			and command.payload.get("owner_player") == previous["owner_player"] \
			and command.payload.get("ship_index") == previous["ship_index"]:
		return true
	var facts: Dictionary = _public_damage_facts(result,
			int(previous["owner_player"]), int(previous["ship_index"]))
	if bool(facts["destroyed"]):
		return true
	if command.command_type == "apply_maneuver_transform" \
			and command.payload.get("owner_player") == previous["owner_player"] \
			and command.payload.get("ship_index") == previous["ship_index"]:
		var ship: ShipInstance = state.get_ship(
				int(previous["owner_player"]), int(previous["ship_index"]))
		if ship != null and ship.ship_data != null:
			var area: Vector2 = GameScale.play_area_size_px
			var base := ShipBase.new(ship.ship_data.ship_size,
					Transform2D(deg_to_rad(float(result.get(
							"rotation_deg", ship.rotation_deg))),
						Vector2(float(result.get("pos_x", ship.pos_x)) * area.x,
								float(result.get("pos_y", ship.pos_y)) * area.y)))
			return not ManeuverAuthority._base_inside_play_area(
					ship.ship_data.ship_size, base.ship_transform, area)
	return false


static func _public_damage_facts(value: Dictionary, owner: int,
		index: int) -> Dictionary:
	var facts: Dictionary = {"additions": {}, "removals": {},
		"destroyed": false}
	_collect_public_damage_facts(value, owner, index, facts)
	return facts


static func _collect_public_damage_facts(value: Dictionary, owner: int,
		index: int, facts: Dictionary) -> void:
	if value.has("faceup_additions") and value.has("faceup_removals") \
			and value.get("owner_player") == owner \
			and value.get("ship_index") == index:
		if value.get("faceup_additions") is Array:
			for raw: Variant in value["faceup_additions"] as Array:
				if raw is Dictionary:
					var addition: Dictionary = raw as Dictionary
					facts["additions"][addition.get("public_card_ref")] = addition
		if value.get("faceup_removals") is Array:
			for ref: Variant in value["faceup_removals"] as Array:
				facts["removals"][ref] = true
		facts["destroyed"] = bool(facts["destroyed"]) \
				or bool(value.get("destroyed", false))
	for child: Variant in value.values():
		if child is Dictionary:
			_collect_public_damage_facts(child as Dictionary,
					owner, index, facts)


static func _public_overlaps_at_transition(state: GameState,
		command: GameCommand, result: Dictionary, owner: int,
		index: int) -> Dictionary:
	var overlaps: Array[Dictionary]
	if command.command_type == "apply_maneuver_transform" \
			and command.payload.get("owner_player") == owner \
			and command.payload.get("ship_index") == index:
		overlaps = ObstacleOverlapAuthority.overlapping_obstacles_at(
				state, owner, index, float(result.get("pos_x", -1.0)),
				float(result.get("pos_y", -1.0)),
				float(result.get("rotation_deg", -1.0)))
	elif command.command_type == "debug_reposition" \
			and command.payload.get("target_kind") == "ship" \
			and command.payload.get("owner_player") == owner \
			and command.payload.get("unit_index") == index:
		overlaps = ObstacleOverlapAuthority.overlapping_obstacles_at(
				state, owner, index, float(command.payload["pos_x"]),
				float(command.payload["pos_y"]),
				float(command.payload["rotation_deg"]))
	else:
		overlaps = ObstacleOverlapAuthority.overlapping_obstacles(
				state, owner, index)
	var by_id: Dictionary = {}
	for obstacle: Dictionary in overlaps:
		by_id[obstacle["obstacle_id"]] = obstacle
	return by_id


static func _active_obstacle_id(ship: ShipInstance) -> String:
	for record: Dictionary in [ship.pending_obstacle_pre_effect_snapshot(),
			ship.asteroid_completion_outstanding_snapshot(),
			ship.active_asteroid_resolution_snapshot(),
			ship.active_debris_resolution_snapshot(),
			ship.active_station_resolution_snapshot()]:
		if not record.is_empty():
			return str(record["obstacle_id"])
	return ""


static func _command_completes_obstacle(command: GameCommand,
		result: Dictionary, obstacle_id: String) -> bool:
	if command.command_type == "resolve_asteroid_overlap":
		return false
	if command.command_type == CompleteAsteroidOverlapCommand.TYPE:
		return command.payload.get("obstacle_id") == obstacle_id
	if command.command_type in ["resolve_debris_overlap",
			"resolve_station_overlap"]:
		return command.payload.get("obstacle_id") == obstacle_id
	if command.command_type == "resolve_immediate_effect":
		return command.payload.get("maneuver_source_id") == obstacle_id
	return false


static func _overlaps_obstacle(state: GameState, owner: int,
		index: int, obstacle_id: String) -> bool:
	for obstacle: Dictionary in ObstacleOverlapAuthority.overlapping_obstacles(
			state, owner, index):
		if obstacle["obstacle_id"] == obstacle_id:
			return true
	return false


static func _exact_keys(value: Dictionary, keys: Array[String]) -> bool:
	if value.size() != keys.size():
		return false
	for key: String in keys:
		if not value.has(key):
			return false
	return true


static func _unique_strings(value: Variant) -> bool:
	if not value is Array or (value as Array).is_empty():
		return false
	var seen: Dictionary = {}
	for item: Variant in value as Array:
		if not _nonempty_string(item) or seen.has(item):
			return false
		seen[item] = true
	return true


static func _nonempty_string(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not (value as String).is_empty()
