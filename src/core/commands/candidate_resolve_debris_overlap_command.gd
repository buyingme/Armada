## Dormant protocol-7 CAP-OBS-002 authority/application boundary.
class_name CandidateResolveDebrisOverlapCommand
extends GameCommand

const APPLICATION: GDScript = preload("res://src/core/damage/candidate_damage_application.gd")
const OVERLAP: GDScript = preload("res://src/core/geometry/obstacle_overlap_authority.gd")
const KEYS: Array[String] = ["owner_player","ship_index","ship_activation_identity","maneuver_execution_id","obstacle_id","hull_zone"]

func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void: super._init(p_player,"resolve_debris_overlap",p_payload)
func application_contract_id() -> String: return command_type
func application_contract_version() -> int: return 2

func validate(game_state: GameState) -> String:
	var base := super.validate(game_state); if not base.is_empty(): return base
	if not _exact(payload,KEYS) or typeof(payload["owner_player"]) != TYPE_INT or typeof(payload["ship_index"]) != TYPE_INT: return "Invalid debris payload."
	var owner := int(payload["owner_player"]); var ship := game_state.get_ship(owner,int(payload["ship_index"]))
	if player_index != owner or ship == null or ship.is_destroyed(): return "Invalid debris actor or target."
	var record := ship.active_debris_resolution_snapshot()
	if record != {"maneuver_execution_id":payload["maneuver_execution_id"],"ship_activation_identity":payload["ship_activation_identity"],"obstacle_id":payload["obstacle_id"],"controller_player":owner,"disposition":"OPEN"}: return "No matching debris resolution."
	var zone := str(payload["hull_zone"])
	if not ship.current_shields.has(zone): return "Invalid debris hull zone."
	var outcome: Dictionary = _sequential_outcome(ship, zone)
	var draws := int(outcome["facedown_delta"])
	if game_state.passive_damage_ledger != null:
		if not ship.is_passive_damage_bound() or not game_state.passive_damage_ledger.can_consume_hidden_draws(draws): return "Passive debris damage is unavailable."
	elif game_state.damage_deck == null or game_state.damage_deck.get_total_count() < draws or not game_state.validate_damage_state_for_save7(): return "Damage authority cannot apply debris damage."
	return ""

func execute(game_state: GameState) -> Dictionary:
	if not validate(game_state).is_empty(): return {}
	var owner := int(payload["owner_player"]); var index := int(payload["ship_index"]); var ship := game_state.get_ship(owner,index); var zone := str(payload["hull_zone"])
	var old_shields := int(ship.current_shields[zone]); var old_count := ship.get_facedown_damage_count()
	for point in 2:
		if ship.reduce_shields(zone,1) == 0:
			var card := game_state.damage_deck.draw_card()
			if card == null or card.physical_card_id.is_empty(): return {}
			card.flip_facedown(); ship.add_facedown_damage(card)
		if ship.is_destroyed():
			ship.mark_destroyed()
			break
	if not ship.is_destroyed():
		if not ship.complete_debris_resolution(str(payload["ship_activation_identity"]),str(payload["maneuver_execution_id"]),str(payload["obstacle_id"]),owner): return {}
		game_state.mark_obstacle_resolved_for_maneuver(str(payload["obstacle_id"]),str(payload["maneuver_execution_id"]))
		if not OVERLAP.open_next_purpose_resolution(game_state,owner,index): return {}
	var changes: Array[Dictionary] = []
	if int(ship.current_shields[zone]) != old_shields: changes.append({"zone":zone,"new_shields":int(ship.current_shields[zone])})
	var result := payload.duplicate(true); result["damage_application"]={"owner_player":owner,"ship_index":index,"shield_changes":changes,"facedown_delta":ship.get_facedown_damage_count()-old_count,"faceup_additions":[],"faceup_removals":[],"public_discards":[],"new_hull":ship.ship_data.hull-ship.get_total_damage(),"destroyed":ship.is_destroyed()}; return result

func project_application_result(result: Dictionary, viewer_player: int) -> Dictionary: return result.duplicate(true) if viewer_player in [0,1] and _result_valid(result) else {}

func execute_with_application_result(game_state: GameState,result: Dictionary) -> Dictionary:
	if not _result_valid(result) or game_state.passive_damage_ledger == null or not validate(game_state).is_empty(): return {}
	for key in KEYS:
		if result[key] != payload[key]: return {}
	var ship := game_state.get_ship(int(payload["owner_player"]),int(payload["ship_index"])); var damage: Dictionary=result["damage_application"]; var zone:=str(payload["hull_zone"]); var old:=int(ship.current_shields[zone]); var outcome:Dictionary=_sequential_outcome(ship,zone);var draws:=int(outcome["facedown_delta"])
	var expected_changes: Array = []
	if int(outcome["new_shields"]) != old: expected_changes=[{"zone":zone,"new_shields":int(outcome["new_shields"])}]
	if damage["shield_changes"] != expected_changes or int(damage["facedown_delta"]) != draws or int(damage["new_hull"]) != int(outcome["new_hull"]) or bool(damage["destroyed"]) != bool(outcome["destroyed"]): return {}
	ship.current_shields[zone]=int(outcome["new_shields"])
	if draws > 0:
		if not game_state.passive_damage_ledger.consume_hidden_draws(draws): return {}
		if not ship.increment_passive_facedown_damage(draws): return {}
	if bool(damage["destroyed"]):
		ship.mark_destroyed()
	else:
		if not ship.complete_debris_resolution(str(payload["ship_activation_identity"]),str(payload["maneuver_execution_id"]),str(payload["obstacle_id"]),int(payload["owner_player"])): return {}
		game_state.mark_obstacle_resolved_for_maneuver(str(payload["obstacle_id"]),str(payload["maneuver_execution_id"]))
		if not OVERLAP.open_next_purpose_resolution(game_state,int(payload["owner_player"]),int(payload["ship_index"])): return {}
	return result.duplicate(true)

static func _sequential_outcome(ship: ShipInstance, zone: String) -> Dictionary:
	var shields := int(ship.current_shields[zone])
	var facedown_delta := 0
	var remaining_hull := ship.ship_data.hull - ship.get_total_damage()
	for point in 2:
		if shields > 0:
			shields -= 1
		else:
			facedown_delta += 1
			if facedown_delta >= remaining_hull:
				break
	var new_hull := remaining_hull - facedown_delta
	return {"new_shields":shields,"facedown_delta":facedown_delta,
		"new_hull":new_hull,"destroyed":new_hull<=0}

static func _result_valid(result:Dictionary)->bool:
	var keys:=KEYS.duplicate();keys.append("damage_application");return _exact(result,keys) and APPLICATION.is_exact_damage_application(result["damage_application"])
static func _exact(value:Dictionary,keys:Array[String])->bool:
	if value.size()!=keys.size():return false
	for key in keys:
		if not value.has(key):return false
	return true
