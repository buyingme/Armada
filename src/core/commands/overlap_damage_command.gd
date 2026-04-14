## OverlapDamageCommand
##
## Deals one facedown damage card to both the moving ship and the
## closest overlapped ship after a ship–ship overlap is resolved.
## Also handles destruction if the resulting damage exceeds hull.
##
## Cards are pre-drawn by the presentation layer and serialized into
## the payload so the command is deterministic on replay.
##
## Payload:
##   [code]ship_index[/code]       — int — moving ship's fleet index
##   [code]other_owner[/code]      — int — overlapped ship's owner player
##   [code]other_ship_index[/code] — int — overlapped ship's fleet index
##   [code]moving_card[/code]      — Dictionary — serialized DamageCard
##   [code]other_card[/code]       — Dictionary — serialized DamageCard
##
## Rules Reference: RRG "Overlapping", p.8 — OV-011.
class_name OverlapDamageCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("overlap_damage", func(
			player: int, pl: Dictionary) -> GameCommand:
		return OverlapDamageCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "overlap_damage", p_payload)


## Validates that both ships exist and cards are provided.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if game_state.current_phase != Constants.GamePhase.SHIP:
		return "Not in Ship Phase."
	var moving: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	if moving == null:
		return "Moving ship not found."
	var other_owner: int = int(payload.get("other_owner", -1))
	var other_idx: int = int(payload.get("other_ship_index", -1))
	var other: ShipInstance = game_state.get_ship(other_owner, other_idx)
	if other == null:
		return "Overlapped ship not found."
	if payload.get("moving_card", {}).is_empty():
		return "Missing moving_card data."
	if payload.get("other_card", {}).is_empty():
		return "Missing other_card data."
	return ""


## Deals facedown damage to both ships and checks for destruction.
func execute(game_state: GameState) -> Dictionary:
	var moving: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	var other_owner: int = int(payload.get("other_owner", -1))
	var other_idx: int = int(payload.get("other_ship_index", -1))
	var other: ShipInstance = game_state.get_ship(other_owner, other_idx)
	# Deal card to moving ship.
	var m_card: DamageCard = DamageCard.deserialize(
			payload.get("moving_card", {}))
	m_card.is_faceup = false
	moving.add_facedown_damage(m_card)
	var m_hull: int = moving.ship_data.hull - moving.get_total_damage()
	var m_destroyed: bool = moving.is_destroyed()
	if m_destroyed:
		moving.mark_destroyed()
	# Deal card to overlapped ship.
	var o_card: DamageCard = DamageCard.deserialize(
			payload.get("other_card", {}))
	o_card.is_faceup = false
	other.add_facedown_damage(o_card)
	var o_hull: int = other.ship_data.hull - other.get_total_damage()
	var o_destroyed: bool = other.is_destroyed()
	if o_destroyed:
		other.mark_destroyed()
	return {
		"ship_index": payload.get("ship_index", -1),
		"other_owner": other_owner,
		"other_ship_index": other_idx,
		"moving_hull": m_hull,
		"moving_destroyed": m_destroyed,
		"other_hull": o_hull,
		"other_destroyed": o_destroyed,
	}
