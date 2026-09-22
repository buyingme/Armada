## Board-owned no-active-attack presentation for an accepted debug damage card.
## It derives every identity and chooser from canonical state/result data and
## submits the existing immediate-effect command; it has no DEBUG or attack
## continuation ownership.
class_name DamageCardImmediateEffectController
extends Node


var _camera: BoardCamera = null
var _handoff_overlay: HandoffOverlay = null
var _modal: OpponentChoiceModal = null
var _pending_ship: ShipInstance = null
var _pending_card: DamageCard = null


func initialize(camera: BoardCamera, handoff_overlay: HandoffOverlay) -> void:
	_camera = camera
	_handoff_overlay = handoff_overlay


func react_to_debug_damage_result(_command: GameCommand, result: Dictionary) -> void:
	var state: GameState = GameManager.current_game_state
	if state == null or not result.get("damage_application") is Dictionary:
		return
	var owner: int = int(result.get("owner_player", -1))
	var ship_index: int = int(result.get("ship_index", -1))
	var ship: ShipInstance = state.get_ship(owner, ship_index)
	var damage: Dictionary = result["damage_application"] as Dictionary
	var additions: Array = damage.get("faceup_additions", []) as Array
	if ship == null or str(result.get("debug_application_id", "")).is_empty() \
			or additions.size() != 1 or not additions[0] is Dictionary:
		return
	var addition: Dictionary = additions[0] as Dictionary
	var public_ref: String = str(addition.get("public_card_ref", ""))
	var card: DamageCard = ship.faceup_card_for_public_ref(public_ref)
	var record: Dictionary = ship.active_immediate_resolution_snapshot()
	if card == null or not ImmediateEffectResolver.is_immediate(card) \
			or str(addition.get("immediate_obligation", "")) != "open" \
			or str(addition.get("effect_id", "")) != card.effect_id \
			or str(record.get("public_card_ref", "")) != public_ref \
			or str(record.get("immediate_resolution_id", "")) \
					!= str(addition.get("immediate_resolution_id", "")) \
			or str(record.get("debug_application_id", "")) \
					!= str(result["debug_application_id"]):
		return
	var resolver: ImmediateEffectResolver = ImmediateEffectResolver.new()
	var choice_info: Dictionary = resolver.get_required_choice(card, ship)
	var chooser: int = ship.owner_player
	if str(choice_info.get("chooser", "owner")) == "opponent":
		chooser = 1 - ship.owner_player
	if not _can_act_as(chooser):
		return
	if choice_info.is_empty():
		GameManager.submit_resolve_immediate_effect(ship, card, {})
		return
	_pending_ship = ship
	_pending_card = card
	if _open_handoff(chooser):
		return
	_open_choice(choice_info)


func _can_act_as(player: int) -> bool:
	var local: int = NetworkManager.get_local_player_index()
	return local < 0 or local == player


func _open_handoff(chooser: int) -> bool:
	if NetworkManager.get_local_player_index() >= 0 \
			or _camera == null or _handoff_overlay == null:
		return false
	_camera.rotate_to_player(chooser)
	_handoff_overlay.show_handoff(chooser, "Damage Card Choice",
			UIProjector.player_display_label(GameManager.current_game_state, chooser))
	if not EventBus.handoff_accepted.is_connected(_on_handoff_accepted):
		EventBus.handoff_accepted.connect(_on_handoff_accepted, CONNECT_ONE_SHOT)
	return true


func _on_handoff_accepted() -> void:
	if _pending_card == null or _pending_ship == null:
		return
	var resolver: ImmediateEffectResolver = ImmediateEffectResolver.new()
	_open_choice(resolver.get_required_choice(_pending_card, _pending_ship))


func _open_choice(choice_info: Dictionary) -> void:
	if choice_info.is_empty():
		return
	if _modal == null:
		_modal = OpponentChoiceModal.new()
		_modal.name = "DebugDamageImmediateEffectModal"
		var layer: CanvasLayer = CanvasLayer.new()
		layer.name = "DebugDamageImmediateEffectModalLayer"
		layer.layer = 120
		add_child(layer)
		layer.add_child(_modal)
	if not _modal.choice_confirmed.is_connected(_on_choice_confirmed):
		_modal.choice_confirmed.connect(_on_choice_confirmed, CONNECT_ONE_SHOT)
	_modal.open(choice_info)


func _on_choice_confirmed(selection: Dictionary) -> void:
	var ship: ShipInstance = _pending_ship
	var card: DamageCard = _pending_card
	_pending_ship = null
	_pending_card = null
	if ship == null or card == null or not ship.faceup_damage.has(card):
		return
	var result: Dictionary = GameManager.submit_resolve_immediate_effect(
			ship, card, selection)
	if not result.is_empty() and not bool(result.get("awaiting_remote", false)):
		# Hot-seat has no remote-result mirror to emit these derived visuals.
		# The command remains the sole gameplay mutation; this only projects the
		# resulting canonical state through the same shared signal surface.
		var presentation: Dictionary = result.duplicate(true)
		presentation["effect_id"] = card.effect_id
		ImmediateEffectSignals.emit(card, ship, presentation)
