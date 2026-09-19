## Dormant protocol-7 CAP-OBS-003 ordinary Station boundary.
class_name CandidateResolveStationOverlapCommand
extends GameCommand

const APPLICATION: GDScript = preload("res://src/core/damage/candidate_damage_application.gd")
const IMMEDIATE: GDScript = preload("res://src/core/damage/immediate_damage_authority.gd")
const OVERLAP: GDScript = preload("res://src/core/geometry/obstacle_overlap_authority.gd")
const BASE: Array[String] = ["owner_player","ship_index","ship_activation_identity","maneuver_execution_id","obstacle_id","action"]

func _init(p_player:int=0,p_payload:Dictionary={})->void: super._init(p_player,"resolve_station_overlap",p_payload)
func application_contract_id()->String:return command_type
func application_contract_version()->int:return 2

func validate(game_state:GameState)->String:
	var base:=super.validate(game_state);if not base.is_empty():return base
	if game_state.selected_objective_key()=="obj_def_contested_outpost":return "Station behavior is unsupported for the active objective."
	if typeof(payload.get("owner_player"))!=TYPE_INT or typeof(payload.get("ship_index"))!=TYPE_INT:return "Invalid Station target."
	var owner:=int(payload["owner_player"]);var ship:=game_state.get_ship(owner,int(payload["ship_index"]));var action:=str(payload.get("action",""));var keys:=BASE.duplicate()
	if action=="use_faceup":keys.append("public_card_ref")
	elif action=="use_facedown":keys.append("facedown_ordinal")
	elif action not in ["decline","no_option"]:return "Invalid Station action."
	if not _exact(payload,keys) or player_index!=owner or ship==null or ship.is_destroyed():return "Invalid Station payload, actor, or target."
	var record:=ship.active_station_resolution_snapshot()
	if record!={"maneuver_execution_id":payload["maneuver_execution_id"],"ship_activation_identity":payload["ship_activation_identity"],"obstacle_id":payload["obstacle_id"],"controller_player":owner,"disposition":"OPEN"}:return "No matching Station resolution."
	if action=="use_faceup":
		if typeof(payload["public_card_ref"])!=TYPE_STRING or ship.faceup_card_for_public_ref(str(payload["public_card_ref"]))==null:return "Station faceup reference is stale."
	elif action=="use_facedown":
		if typeof(payload["facedown_ordinal"])!=TYPE_INT or int(payload["facedown_ordinal"])<0 or int(payload["facedown_ordinal"])>=ship.get_facedown_damage_count():return "Station facedown ordinal is stale."
	elif action=="no_option" and (not ship.faceup_damage.is_empty() or ship.get_facedown_damage_count()>0):return "Station automatic completion still has a legal option."
	return ""

func execute(game_state:GameState)->Dictionary:
	if not validate(game_state).is_empty():return {}
	var owner:=int(payload["owner_player"]);var index:=int(payload["ship_index"]);var ship:=game_state.get_ship(owner,index);var action:=str(payload["action"]);var application:Dictionary=IMMEDIATE.empty_damage_application(ship,owner,index)
	if action=="use_faceup":
		var card:=ship.faceup_card_for_public_ref(str(payload["public_card_ref"]));var public:=card.serialize()
		if not ship.remove_damage_card(card):return {}
		card.public_card_ref="";game_state.damage_deck.discard(card);application["faceup_removals"]=[payload["public_card_ref"]];application["public_discards"]=[public]
	elif action=="use_facedown":
		var ordinal:=int(payload["facedown_ordinal"]);var card:DamageCard=ship.facedown_damage[ordinal];var public:=card.serialize()
		if not ship.remove_damage_card(card):return {}
		game_state.damage_deck.discard(card);application["facedown_delta"]=-1;application["public_discards"]=[public]
	application["new_hull"]=ship.ship_data.hull-ship.get_total_damage()
	if not ship.complete_station_resolution(str(payload["ship_activation_identity"]),str(payload["maneuver_execution_id"]),str(payload["obstacle_id"]),owner):return {}
	game_state.mark_obstacle_resolved_for_maneuver(str(payload["obstacle_id"]),str(payload["maneuver_execution_id"]))
	if not OVERLAP.open_next_purpose_resolution(game_state,owner,index):return {}
	var result:={}
	for key in BASE:result[key]=payload[key]
	result["damage_application"]=application;return result

func project_application_result(result:Dictionary,viewer_player:int)->Dictionary:return result.duplicate(true) if viewer_player in [0,1] and _result_valid(result) else {}

func execute_with_application_result(game_state:GameState,result:Dictionary)->Dictionary:
	if not _result_valid(result) or game_state.passive_damage_ledger==null or not validate(game_state).is_empty():return {}
	for key in BASE:
		if result[key]!=payload[key]:return {}
	var owner:=int(payload["owner_player"]);var index:=int(payload["ship_index"]);var ship:=game_state.get_ship(owner,index);var action:=str(payload["action"]);var damage:Dictionary=result["damage_application"]
	var expected_delta:=-1 if action=="use_facedown" else 0;var expected_removals:Array=[payload["public_card_ref"]] if action=="use_faceup" else [];var expected_discards:=1 if action in ["use_faceup","use_facedown"] else 0
	if int(damage["facedown_delta"])!=expected_delta or damage["faceup_removals"]!=expected_removals or (damage["public_discards"] as Array).size()!=expected_discards:return {}
	if action=="use_faceup":
		var card:=ship.faceup_card_for_public_ref(str(payload["public_card_ref"]));if card==null or not ship.remove_damage_card(card):return {}
	elif action=="use_facedown" and not game_state.passive_damage_ledger.decrement_facedown(ship.passive_damage_key(),1):return {}
	if expected_discards==1:
		var discarded:=PassiveDamageLedger.deserialize_public_card(damage["public_discards"][0]);if discarded==null or not game_state.passive_damage_ledger.append_public_discard(discarded):return {}
	if not ship.complete_station_resolution(str(payload["ship_activation_identity"]),str(payload["maneuver_execution_id"]),str(payload["obstacle_id"]),owner):return {}
	game_state.mark_obstacle_resolved_for_maneuver(str(payload["obstacle_id"]),str(payload["maneuver_execution_id"]))
	if not OVERLAP.open_next_purpose_resolution(game_state,owner,index):return {}
	return result.duplicate(true)

static func _result_valid(result:Dictionary)->bool:
	var keys:=BASE.duplicate();keys.append("damage_application");return _exact(result,keys) and APPLICATION.is_exact_damage_application(result["damage_application"])
static func _exact(value:Dictionary,keys:Array[String])->bool:
	if value.size()!=keys.size():return false
	for key in keys:
		if not value.has(key):return false
	return true
