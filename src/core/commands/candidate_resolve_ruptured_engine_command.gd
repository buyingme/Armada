## Dormant protocol-7 CAP-DMG-003 post-obstacle suffered-damage boundary.
class_name CandidateResolveRupturedEngineCommand
extends GameCommand

const APPLICATION: GDScript=preload("res://src/core/damage/candidate_damage_application.gd")
const OVERLAP: GDScript=preload("res://src/core/geometry/obstacle_overlap_authority.gd")
const KEYS:Array[String]=["owner_player","ship_index","ship_activation_identity","maneuver_execution_id","public_card_ref","hull_zone"]

func _init(p_player:int=0,p_payload:Dictionary={})->void:super._init(p_player,"resolve_ruptured_engine",p_payload)
func application_contract_id()->String:return command_type
func application_contract_version()->int:return 2

func validate(game_state:GameState)->String:
	var base:=super.validate(game_state);if not base.is_empty():return base
	if not _exact(payload,KEYS) or typeof(payload["owner_player"])!=TYPE_INT or typeof(payload["ship_index"])!=TYPE_INT:return "Invalid Ruptured Engine payload."
	var owner:=int(payload["owner_player"]);var index:=int(payload["ship_index"]);var ship:=game_state.get_ship(owner,index)
	if player_index!=owner or ship==null or ship.is_destroyed():return "Invalid Ruptured Engine actor or target."
	var execution:=ship.active_maneuver_execution_snapshot()
	if str(execution.get("ship_activation_identity",""))!=str(payload["ship_activation_identity"]) or str(execution.get("maneuver_execution_id",""))!=str(payload["maneuver_execution_id"]) or not bool(execution.get("final_transform_applied",false)):return "Stale Ruptured Engine execution."
	if ship.current_speed<=1 or ship.has_active_obstacle_resolution() or not OVERLAP.unresolved_overlaps(game_state,owner,index,str(payload["maneuver_execution_id"])).is_empty():return "Ruptured Engine is not currently applicable."
	var card:=ship.faceup_card_for_public_ref(str(payload["public_card_ref"]))
	if card==null or card.effect_id!="ruptured_engine" or card.last_ruptured_engine_execution_id==str(payload["maneuver_execution_id"]):return "Ruptured Engine source is stale or resolved."
	var zone:=str(payload["hull_zone"]);if not ship.current_shields.has(zone):return "Invalid Ruptured Engine hull zone."
	var draws:=0 if int(ship.current_shields[zone])>0 else 1
	if game_state.passive_damage_ledger!=null:
		if not ship.is_passive_damage_bound() or not game_state.passive_damage_ledger.can_consume_hidden_draws(draws):return "Passive damage is unavailable."
	elif game_state.damage_deck==null or game_state.damage_deck.get_total_count()<draws or not game_state.validate_damage_state_for_save7():return "Damage authority cannot apply Ruptured Engine."
	return ""

func execute(game_state:GameState)->Dictionary:
	if not validate(game_state).is_empty():return {}
	var owner:=int(payload["owner_player"]);var index:=int(payload["ship_index"]);var ship:=game_state.get_ship(owner,index);var card:=ship.faceup_card_for_public_ref(str(payload["public_card_ref"]));var zone:=str(payload["hull_zone"]);var old_shield:=int(ship.current_shields[zone]);var old_damage:=ship.get_facedown_damage_count()
	if ship.reduce_shields(zone,1)==0:
		var drawn:=game_state.damage_deck.draw_card();if drawn==null or drawn.physical_card_id.is_empty():return {}
		drawn.flip_facedown();ship.add_facedown_damage(drawn)
	card.last_ruptured_engine_execution_id=str(payload["maneuver_execution_id"])
	if ship.get_total_damage()>=ship.ship_data.hull:ship.mark_destroyed()
	var changes:Array[Dictionary]=[];if int(ship.current_shields[zone])!=old_shield:changes.append({"zone":zone,"new_shields":int(ship.current_shields[zone])})
	var result:=payload.duplicate(true);result["damage_application"]={"owner_player":owner,"ship_index":index,"shield_changes":changes,"facedown_delta":ship.get_facedown_damage_count()-old_damage,"faceup_additions":[],"faceup_removals":[],"public_discards":[],"new_hull":ship.ship_data.hull-ship.get_total_damage(),"destroyed":ship.is_destroyed()};return result

func project_application_result(result:Dictionary,viewer_player:int)->Dictionary:return result.duplicate(true) if viewer_player in [0,1] and _result_valid(result) else {}
func execute_with_application_result(game_state:GameState,result:Dictionary)->Dictionary:
	if not _result_valid(result) or game_state.passive_damage_ledger==null or not validate(game_state).is_empty():return {}
	for key in KEYS:
		if result[key]!=payload[key]:return {}
	var ship:=game_state.get_ship(int(payload["owner_player"]),int(payload["ship_index"]));var card:=ship.faceup_card_for_public_ref(str(payload["public_card_ref"]));var zone:=str(payload["hull_zone"]);var old:=int(ship.current_shields[zone]);var draws:=0 if old>0 else 1;var damage:Dictionary=result["damage_application"];var changes:Array=[]
	if old>0:changes=[{"zone":zone,"new_shields":old-1}]
	var hull:=ship.ship_data.hull-ship.get_total_damage()-draws
	if damage["shield_changes"]!=changes or int(damage["facedown_delta"])!=draws or int(damage["new_hull"])!=hull or bool(damage["destroyed"])!=(hull<=0):return {}
	if old>0:ship.current_shields[zone]=old-1
	elif not game_state.passive_damage_ledger.consume_hidden_draws(1) or not ship.increment_passive_facedown_damage(1):return {}
	card.last_ruptured_engine_execution_id=str(payload["maneuver_execution_id"])
	if bool(damage["destroyed"]):ship.mark_destroyed()
	return result.duplicate(true)

static func _result_valid(result:Dictionary)->bool:
	var keys:=KEYS.duplicate();keys.append("damage_application");return _exact(result,keys) and APPLICATION.is_exact_damage_application(result["damage_application"])
static func _exact(value:Dictionary,keys:Array[String])->bool:
	if value.size()!=keys.size():return false
	for key in keys:
		if not value.has(key):return false
	return true
