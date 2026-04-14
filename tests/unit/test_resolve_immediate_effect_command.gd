## Tests for P5 ResolveImmediateEffectCommand.
##
## Covers: validate (happy + rejection) per effect_id, execute for all 6
## immediate effects, and serialize/deserialize roundtrip.
extends GutTest


var _state: GameState


## Creates a minimal ShipData for testing.
func _make_ship_data() -> ShipData:
	var data := ShipData.new()
	data.hull = 5
	data.max_speed = 2
	data.command_value = 2
	data.engineering_value = 3
	data.shields = {"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1}
	data.defense_tokens = ["evade", "brace"]
	data.navigation_chart = [[1], [1, 1]]
	return data


## Creates a ShipInstance and adds it to the player's fleet.
## Returns the ship index.
func _add_ship(player: int) -> int:
	var ship := ShipInstance.create_from_data(
			"test_ship", _make_ship_data(), 2, player)
	# Give ship a command dial stack with 2 dials.
	ship.command_dial_stack.assign_dials(
			[Constants.CommandType.NAVIGATE,
			Constants.CommandType.REPAIR], 1)
	var ps: PlayerState = _state.get_player_state(player)
	ps.ships.append(ship)
	return ps.ships.size() - 1


## Creates a faceup DamageCard and adds it to the ship.
func _add_faceup_card(ship: ShipInstance, effect_id: String,
		title: String = "", timing: String = "immediate") -> DamageCard:
	var card: DamageCard = DamageCard.create("Ship",
			title if not title.is_empty() else effect_id)
	card.effect_id = effect_id
	card.timing = timing
	card.is_faceup = true
	ship.add_faceup_damage(card)
	return card


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_state.current_round = 1
	_state.current_phase = Constants.GamePhase.SHIP
	_state.damage_deck = DamageDeck.new()
	_state.damage_deck.initialize()
	ResolveImmediateEffectCommand.register()


func after_each() -> void:
	GameCommand._registry.erase("resolve_immediate_effect")


# ======================================================================
# Validate — general
# ======================================================================

func test_validate_wrong_phase() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	_add_faceup_card(ps.ships[idx], "structural_damage")
	_state.current_phase = Constants.GamePhase.COMMAND
	var cmd := ResolveImmediateEffectCommand.new(0, {
		"effect_id": "structural_damage",
		"owner_player": 0,
		"ship_index": idx,
		"card_index": 0,
		"choice": {},
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject when not in Ship or Squadron Phase")


func test_validate_unknown_effect() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	_add_faceup_card(ps.ships[idx], "bogus_effect")
	var cmd := ResolveImmediateEffectCommand.new(0, {
		"effect_id": "bogus_effect",
		"owner_player": 0,
		"ship_index": idx,
		"card_index": 0,
		"choice": {},
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject unknown effect_id")


func test_validate_ship_not_found() -> void:
	var cmd := ResolveImmediateEffectCommand.new(0, {
		"effect_id": "structural_damage",
		"owner_player": 0,
		"ship_index": 99,
		"card_index": 0,
		"choice": {},
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject when ship index is out of bounds")


func test_validate_card_index_oob() -> void:
	var idx: int = _add_ship(0)
	var cmd := ResolveImmediateEffectCommand.new(0, {
		"effect_id": "structural_damage",
		"owner_player": 0,
		"ship_index": idx,
		"card_index": 5,
		"choice": {},
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject when card index is out of bounds")


func test_validate_effect_id_mismatch() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	_add_faceup_card(ps.ships[idx], "structural_damage")
	var cmd := ResolveImmediateEffectCommand.new(0, {
		"effect_id": "comm_noise",
		"owner_player": 0,
		"ship_index": idx,
		"card_index": 0,
		"choice": {},
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject when effect_id does not match card's effect_id")


# ======================================================================
# Validate + Execute — structural_damage
# ======================================================================

func test_validate_structural_damage_ok() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	_add_faceup_card(ps.ships[idx], "structural_damage")
	var cmd := ResolveImmediateEffectCommand.new(0, {
		"effect_id": "structural_damage",
		"owner_player": 0,
		"ship_index": idx,
		"card_index": 0,
		"choice": {},
	})
	assert_eq(cmd.validate(_state), "",
			"structural_damage should validate with no choice needed")


func test_execute_structural_damage_extra_card() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	var ship: ShipInstance = ps.ships[idx]
	_add_faceup_card(ship, "structural_damage")
	# Pre-draw a card and serialize it.
	var extra: DamageCard = _state.damage_deck.draw_card()
	var extra_data: Dictionary = extra.serialize()
	var cmd := ResolveImmediateEffectCommand.new(0, {
		"effect_id": "structural_damage",
		"owner_player": 0,
		"ship_index": idx,
		"card_index": 0,
		"choice": {},
		"extra_card_data": extra_data,
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("effect_id"), "structural_damage",
			"Result should echo effect_id")
	assert_true(result.get("extra_dealt", false) as bool,
			"Should report extra card dealt")
	assert_eq(ship.faceup_damage.size(), 0,
			"Faceup card should be moved to facedown (flipped)")
	# 1 original card (now facedown) + 1 extra = 2 facedown.
	assert_eq(ship.facedown_damage.size(), 2,
			"Should have 2 facedown cards after structural damage")


func test_execute_structural_damage_no_extra() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	var ship: ShipInstance = ps.ships[idx]
	_add_faceup_card(ship, "structural_damage")
	var cmd := ResolveImmediateEffectCommand.new(0, {
		"effect_id": "structural_damage",
		"owner_player": 0,
		"ship_index": idx,
		"card_index": 0,
		"choice": {},
	})
	var result: Dictionary = cmd.execute(_state)
	assert_false(result.get("extra_dealt", true) as bool,
			"Should report no extra card when extra_card_data is empty")
	assert_eq(ship.facedown_damage.size(), 1,
			"Original card should be moved to facedown only")


# ======================================================================
# Validate + Execute — projector_misaligned
# ======================================================================

func test_execute_projector_misaligned_auto() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	var ship: ShipInstance = ps.ships[idx]
	_add_faceup_card(ship, "projector_misaligned")
	# FRONT=3 is the unique maximum.
	var cmd := ResolveImmediateEffectCommand.new(0, {
		"effect_id": "projector_misaligned",
		"owner_player": 0,
		"ship_index": idx,
		"card_index": 0,
		"choice": {},
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("zone"), "FRONT",
			"Should pick FRONT (highest shields)")
	assert_eq(int(result.get("shields_lost")), 3,
			"Should lose all 3 shields from FRONT")
	assert_eq(int(ship.current_shields["FRONT"]), 0,
			"FRONT should be 0 after stripping")


func test_execute_projector_misaligned_choice() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	var ship: ShipInstance = ps.ships[idx]
	# Tie LEFT and RIGHT at 2.
	ship.current_shields["FRONT"] = 2
	_add_faceup_card(ship, "projector_misaligned")
	var cmd := ResolveImmediateEffectCommand.new(0, {
		"effect_id": "projector_misaligned",
		"owner_player": 0,
		"ship_index": idx,
		"card_index": 0,
		"choice": {"id": "zone_LEFT"},
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("zone"), "LEFT",
			"Should use the player's chosen zone")
	assert_eq(int(ship.current_shields["LEFT"]), 0,
			"LEFT should be stripped to 0")


# ======================================================================
# Validate + Execute — life_support_failure
# ======================================================================

func test_execute_life_support_failure() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	var ship: ShipInstance = ps.ships[idx]
	ship.command_tokens.add_token(Constants.CommandType.NAVIGATE)
	ship.command_tokens.add_token(Constants.CommandType.REPAIR)
	assert_true(ship.command_tokens.get_token_count() > 0,
			"Precondition: ship has tokens")
	_add_faceup_card(ship, "life_support_failure",
			"Life Support Failure", "immediate_persistent")
	var cmd := ResolveImmediateEffectCommand.new(0, {
		"effect_id": "life_support_failure",
		"owner_player": 0,
		"ship_index": idx,
		"card_index": 0,
		"choice": {},
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("effect_id"), "life_support_failure",
			"Result should echo effect_id")
	assert_true(result.get("tokens_cleared", false) as bool,
			"Should report tokens cleared")
	assert_eq(ship.command_tokens.get_token_count(), 0,
			"Ship should have 0 tokens")
	# Card stays faceup for persistent effect.
	assert_true(result.get("stays_faceup", false) as bool,
			"Should report stays_faceup")
	assert_eq(ship.faceup_damage.size(), 1,
			"Card should remain in faceup_damage")


# ======================================================================
# Validate + Execute — injured_crew
# ======================================================================

func test_validate_injured_crew_ok() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	_add_faceup_card(ps.ships[idx], "injured_crew")
	var cmd := ResolveImmediateEffectCommand.new(0, {
		"effect_id": "injured_crew",
		"owner_player": 0,
		"ship_index": idx,
		"card_index": 0,
		"choice": {"id": "discard_defense_0"},
	})
	assert_eq(cmd.validate(_state), "",
			"injured_crew should validate with valid token index")


func test_validate_injured_crew_no_choice() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	_add_faceup_card(ps.ships[idx], "injured_crew")
	var cmd := ResolveImmediateEffectCommand.new(0, {
		"effect_id": "injured_crew",
		"owner_player": 0,
		"ship_index": idx,
		"card_index": 0,
		"choice": {},
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject injured_crew without a choice")


func test_execute_injured_crew() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	var ship: ShipInstance = ps.ships[idx]
	_add_faceup_card(ship, "injured_crew")
	var cmd := ResolveImmediateEffectCommand.new(0, {
		"effect_id": "injured_crew",
		"owner_player": 0,
		"ship_index": idx,
		"card_index": 0,
		"choice": {"id": "discard_defense_0"},
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("token_index"), 0,
			"Result should report discarded token index")
	assert_eq(int(ship.defense_tokens[0].get("state")),
			Constants.DefenseTokenState.DISCARDED,
			"Token 0 should be DISCARDED")
	assert_eq(ship.faceup_damage.size(), 0,
			"Card should be moved to facedown after effect")


# ======================================================================
# Validate + Execute — shield_failure
# ======================================================================

func test_validate_shield_failure_too_many_zones() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	_add_faceup_card(ps.ships[idx], "shield_failure")
	var cmd := ResolveImmediateEffectCommand.new(0, {
		"effect_id": "shield_failure",
		"owner_player": 0,
		"ship_index": idx,
		"card_index": 0,
		"choice": {"zones": ["FRONT", "LEFT", "RIGHT"]},
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject more than 2 zones")


func test_execute_shield_failure_two_zones() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	var ship: ShipInstance = ps.ships[idx]
	_add_faceup_card(ship, "shield_failure")
	var cmd := ResolveImmediateEffectCommand.new(0, {
		"effect_id": "shield_failure",
		"owner_player": 0,
		"ship_index": idx,
		"card_index": 0,
		"choice": {"zones": ["FRONT", "LEFT"]},
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(int(ship.current_shields["FRONT"]), 2,
			"FRONT should lose 1 shield (3→2)")
	assert_eq(int(ship.current_shields["LEFT"]), 1,
			"LEFT should lose 1 shield (2→1)")
	var changes: Array = result.get("shield_changes", [])
	assert_eq(changes.size(), 2,
			"Result should report 2 shield changes")
	assert_eq(ship.faceup_damage.size(), 0,
			"Card should be moved to facedown")


func test_execute_shield_failure_zero_zones() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	var ship: ShipInstance = ps.ships[idx]
	_add_faceup_card(ship, "shield_failure")
	var cmd := ResolveImmediateEffectCommand.new(0, {
		"effect_id": "shield_failure",
		"owner_player": 0,
		"ship_index": idx,
		"card_index": 0,
		"choice": {"zones": []},
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(int(ship.current_shields["FRONT"]), 3,
			"FRONT should be unchanged")
	assert_eq(ship.faceup_damage.size(), 0,
			"Card should still flip facedown")


# ======================================================================
# Validate + Execute — comm_noise
# ======================================================================

func test_validate_comm_noise_no_choice() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	_add_faceup_card(ps.ships[idx], "comm_noise")
	var cmd := ResolveImmediateEffectCommand.new(0, {
		"effect_id": "comm_noise",
		"owner_player": 0,
		"ship_index": idx,
		"card_index": 0,
		"choice": {},
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject comm_noise without a choice")


func test_execute_comm_noise_reduce_speed() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	var ship: ShipInstance = ps.ships[idx]
	ship.current_speed = 2
	_add_faceup_card(ship, "comm_noise")
	var cmd := ResolveImmediateEffectCommand.new(0, {
		"effect_id": "comm_noise",
		"owner_player": 0,
		"ship_index": idx,
		"card_index": 0,
		"choice": {"id": "reduce_speed"},
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("action"), "reduce_speed",
			"Result should report reduce_speed action")
	assert_eq(ship.current_speed, 1,
			"Speed should drop from 2 to 1")
	assert_eq(ship.faceup_damage.size(), 0,
			"Card should flip facedown")


func test_execute_comm_noise_change_dial() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	var ship: ShipInstance = ps.ships[idx]
	_add_faceup_card(ship, "comm_noise")
	var cmd := ResolveImmediateEffectCommand.new(0, {
		"effect_id": "comm_noise",
		"owner_player": 0,
		"ship_index": idx,
		"card_index": 0,
		"choice": {"id": "change_dial_%d" % Constants.CommandType.REPAIR},
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("action"), "change_dial",
			"Result should report change_dial action")
	assert_eq(int(result.get("new_command")),
			Constants.CommandType.REPAIR,
			"New command should be REPAIR")
	assert_eq(ship.faceup_damage.size(), 0,
			"Card should flip facedown")


# ======================================================================
# Serialize / Deserialize roundtrip
# ======================================================================

func test_serialize_deserialize_structural_damage() -> void:
	var cmd := ResolveImmediateEffectCommand.new(0, {
		"effect_id": "structural_damage",
		"owner_player": 0,
		"ship_index": 0,
		"card_index": 0,
		"choice": {},
		"extra_card_data": {"trait_type": "Ship", "title": "Test",
				"is_faceup": false, "effect_text": "",
				"timing": "", "effect_id": ""},
	})
	cmd.sequence = 42
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored, "Should deserialize")
	assert_eq(restored.command_type, "resolve_immediate_effect",
			"Type should match")
	assert_eq(restored.sequence, 42, "Sequence should match")
	assert_eq(restored.payload.get("effect_id"), "structural_damage",
			"effect_id survives roundtrip")
	var extra: Dictionary = restored.payload.get("extra_card_data", {})
	assert_eq(extra.get("title"), "Test",
			"extra_card_data should survive roundtrip")


func test_serialize_deserialize_comm_noise() -> void:
	var cmd := ResolveImmediateEffectCommand.new(1, {
		"effect_id": "comm_noise",
		"owner_player": 1,
		"ship_index": 0,
		"card_index": 0,
		"choice": {"id": "reduce_speed"},
	})
	cmd.sequence = 7
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored, "Should deserialize")
	assert_eq(restored.payload.get("effect_id"), "comm_noise",
			"effect_id survives roundtrip")
	var choice: Dictionary = restored.payload.get("choice", {})
	assert_eq(choice.get("id"), "reduce_speed",
			"choice.id survives roundtrip")


func test_validate_squadron_phase_allowed() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	_add_faceup_card(ps.ships[idx], "structural_damage")
	_state.current_phase = Constants.GamePhase.SQUADRON
	var cmd := ResolveImmediateEffectCommand.new(0, {
		"effect_id": "structural_damage",
		"owner_player": 0,
		"ship_index": idx,
		"card_index": 0,
		"choice": {},
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept Squadron Phase (attacks happen there too)")
