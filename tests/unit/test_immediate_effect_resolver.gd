## Test: ImmediateEffectResolver
##
## Unit tests for the six immediate damage card effects:
## Structural Damage, Projector Misaligned, Life Support Failure,
## Injured Crew, Shield Failure, Comm Noise.
##
## Rules Reference: RRG "Damage Cards", p.4; individual card texts.
extends GutTest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


## Creates a ShipInstance with configurable shields and defense tokens.
func _make_ship(
		front: int = 3, left: int = 2,
		right: int = 2, rear: int = 1) -> ShipInstance:
	var data: ShipData = ShipData.new()
	data.hull = 5
	data.max_speed = 2
	data.engineering_value = 3
	data.command_value = 2
	data.shields = {
		"FRONT": front, "LEFT": left,
		"RIGHT": right, "REAR": rear,
	}
	data.defense_tokens = ["evade", "brace"]
	data.navigation_chart = [[1], [1, 1]]
	var ship: ShipInstance = ShipInstance.create_from_data(
			"test_ship", data, 1, 0)
	return ship


## Creates and returns a DamageDeck.
func _make_deck() -> DamageDeck:
	var deck: DamageDeck = DamageDeck.new()
	deck.initialize()
	return deck


## Creates a faceup DamageCard with the given effect_id and adds it to ship.
func _make_faceup_card(ship: ShipInstance,
		effect_id: String, title: String = "") -> DamageCard:
	var card: DamageCard = DamageCard.create("Ship", title if title else effect_id)
	card.effect_id = effect_id
	card.timing = "immediate"
	card.is_faceup = true
	ship.add_faceup_damage(card)
	return card


## Creates the resolver instance.
func _resolver() -> ImmediateEffectResolver:
	return ImmediateEffectResolver.new()


# ---------------------------------------------------------------------------
# is_immediate
# ---------------------------------------------------------------------------


func test_is_immediate_true_for_immediate_card() -> void:
	var card: DamageCard = DamageCard.create("Ship", "Structural Damage")
	card.timing = "immediate"
	assert_true(ImmediateEffectResolver.is_immediate(card),
			"Card with timing='immediate' should be immediate")


func test_is_immediate_false_for_persistent_card() -> void:
	var card: DamageCard = DamageCard.create("Ship", "Ruptured Engine")
	card.timing = "persistent"
	assert_false(ImmediateEffectResolver.is_immediate(card),
			"Card with timing='persistent' should not be immediate")


func test_is_immediate_true_for_immediate_persistent_card() -> void:
	var card: DamageCard = DamageCard.create("Crew", "Life Support Failure")
	card.timing = "immediate_persistent"
	card.effect_id = "life_support_failure"
	assert_true(ImmediateEffectResolver.is_immediate(card),
			"Card with timing='immediate_persistent' should be immediate")


# ---------------------------------------------------------------------------
# Structural Damage — deal 1 extra facedown, then flip facedown
# ---------------------------------------------------------------------------


func test_structural_damage_deals_extra_facedown() -> void:
	var ship: ShipInstance = _make_ship()
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "structural_damage", "Structural Damage")
	var facedown_before: int = ship.facedown_damage.size()
	var result: bool = _resolver().resolve(card, ship, deck)
	assert_true(result, "Should resolve successfully")
	# +1 extra drawn card AND +1 for the original card moving to facedown.
	assert_eq(ship.facedown_damage.size(), facedown_before + 2,
			"Should have 2 new facedown cards (1 extra + 1 flipped)")


func test_structural_damage_flips_card_facedown() -> void:
	var ship: ShipInstance = _make_ship()
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "structural_damage", "Structural Damage")
	_resolver().resolve(card, ship, deck)
	assert_false(card.is_faceup,
			"Card should be facedown after immediate effect")
	assert_eq(ship.faceup_damage.size(), 0,
			"Faceup array should be empty — card moved to facedown")
	# Card should now be in facedown_damage (the extra + this one).
	assert_true(ship.facedown_damage.has(card),
			"Original card should be in facedown array")


func test_structural_damage_no_choice_needed() -> void:
	var ship: ShipInstance = _make_ship()
	var card: DamageCard = _make_faceup_card(
			ship, "structural_damage", "Structural Damage")
	var choices: Dictionary = _resolver().get_required_choice(card, ship)
	assert_true(choices.is_empty(),
			"Structural Damage should not require a choice")


# ---------------------------------------------------------------------------
# Projector Misaligned — strip all shields from zone with most, flip facedown
# ---------------------------------------------------------------------------


func test_projector_misaligned_strips_highest_zone() -> void:
	var ship: ShipInstance = _make_ship(3, 2, 2, 1)
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "projector_misaligned", "Projector Misaligned")
	_resolver().resolve(card, ship, deck)
	assert_eq(int(ship.current_shields["FRONT"]), 0,
			"FRONT (highest=3) should lose all shields")
	assert_eq(int(ship.current_shields["LEFT"]), 2,
			"LEFT should be unchanged")
	assert_eq(int(ship.current_shields["RIGHT"]), 2,
			"RIGHT should be unchanged")
	assert_eq(int(ship.current_shields["REAR"]), 1,
			"REAR should be unchanged")


func test_projector_misaligned_no_shields_is_noop() -> void:
	var ship: ShipInstance = _make_ship(0, 0, 0, 0)
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "projector_misaligned", "Projector Misaligned")
	_resolver().resolve(card, ship, deck)
	assert_eq(int(ship.current_shields["FRONT"]), 0,
			"FRONT should remain 0")
	assert_eq(int(ship.current_shields["LEFT"]), 0,
			"LEFT should remain 0")


func test_projector_misaligned_flips_facedown() -> void:
	var ship: ShipInstance = _make_ship()
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "projector_misaligned", "Projector Misaligned")
	_resolver().resolve(card, ship, deck)
	assert_false(card.is_faceup,
			"Card should flip facedown after effect")


func test_projector_misaligned_unique_max_no_choice() -> void:
	var ship: ShipInstance = _make_ship(3, 2, 2, 1)
	var card: DamageCard = _make_faceup_card(
			ship, "projector_misaligned", "Projector Misaligned")
	var choices: Dictionary = _resolver().get_required_choice(card, ship)
	assert_true(choices.is_empty(),
			"No choice needed when FRONT is unique maximum")


func test_projector_misaligned_tied_zones_require_choice() -> void:
	var ship: ShipInstance = _make_ship(3, 3, 1, 0)
	var card: DamageCard = _make_faceup_card(
			ship, "projector_misaligned", "Projector Misaligned")
	var choices: Dictionary = _resolver().get_required_choice(card, ship)
	assert_false(choices.is_empty(),
			"Should require choice when FRONT and LEFT are tied")
	assert_eq(choices["choice_type"], "projector_misaligned",
			"Choice type should be 'projector_misaligned'")
	assert_eq(choices["chooser"], "owner",
			"Chooser should be 'owner'")
	var options: Array = choices.get("options", [])
	assert_eq(options.size(), 2,
			"Should list exactly the 2 tied zones")


func test_projector_misaligned_choice_strips_selected_zone() -> void:
	var ship: ShipInstance = _make_ship(3, 3, 1, 0)
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "projector_misaligned", "Projector Misaligned")
	_resolver().resolve(card, ship, deck, {"id": "zone_LEFT"})
	assert_eq(int(ship.current_shields["LEFT"]), 0,
			"LEFT chosen — should lose all 3 shields")
	assert_eq(int(ship.current_shields["FRONT"]), 3,
			"FRONT should be unchanged")


# ---------------------------------------------------------------------------
# Life Support Failure — discard all command tokens, flip facedown
# ---------------------------------------------------------------------------


func test_life_support_failure_discards_all_tokens() -> void:
	var ship: ShipInstance = _make_ship()
	ship.command_tokens.add_token(Constants.CommandType.NAVIGATE)
	ship.command_tokens.add_token(Constants.CommandType.REPAIR)
	assert_eq(ship.command_tokens.get_tokens().size(), 2,
			"Pre-condition: 2 command tokens")
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "life_support_failure", "Life Support Failure")
	_resolver().resolve(card, ship, deck)
	assert_eq(ship.command_tokens.get_tokens().size(), 0,
			"All command tokens should be discarded")


func test_life_support_failure_flips_facedown() -> void:
	var ship: ShipInstance = _make_ship()
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "life_support_failure", "Life Support Failure")
	_resolver().resolve(card, ship, deck)
	assert_true(card.is_faceup,
			"Card should stay faceup — hybrid persistent effect")


func test_life_support_failure_no_tokens_still_succeeds() -> void:
	var ship: ShipInstance = _make_ship()
	assert_eq(ship.command_tokens.get_tokens().size(), 0,
			"Pre-condition: no tokens")
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "life_support_failure", "Life Support Failure")
	var result: bool = _resolver().resolve(card, ship, deck)
	assert_true(result, "Should succeed even with no tokens to discard")


# ---------------------------------------------------------------------------
# Injured Crew — owner chooses and discards 1 defense token
# ---------------------------------------------------------------------------


func test_injured_crew_requires_choice() -> void:
	var ship: ShipInstance = _make_ship()
	var card: DamageCard = _make_faceup_card(
			ship, "injured_crew", "Injured Crew")
	var choices: Dictionary = _resolver().get_required_choice(card, ship)
	assert_false(choices.is_empty(),
			"Injured Crew should require a choice")
	assert_eq(choices["choice_type"], "injured_crew",
			"Choice type should be 'injured_crew'")
	assert_eq(choices["chooser"], "owner",
			"Chooser should be 'owner'")


func test_injured_crew_discard_defense_token() -> void:
	var ship: ShipInstance = _make_ship()
	# Ship has evade (idx 0) and brace (idx 1), both READY.
	assert_eq(
			int(ship.defense_tokens[0]["state"]),
			Constants.DefenseTokenState.READY,
			"Pre-condition: token 0 is READY")
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "injured_crew", "Injured Crew")
	var choice: Dictionary = {"id": "discard_defense_0"}
	var result: bool = _resolver().resolve(card, ship, deck, choice)
	assert_true(result, "Should resolve successfully")
	assert_eq(
			int(ship.defense_tokens[0]["state"]),
			Constants.DefenseTokenState.DISCARDED,
			"Defense token 0 should be DISCARDED")


func test_injured_crew_discard_exhausted_token() -> void:
	var ship: ShipInstance = _make_ship()
	ship.exhaust_defense_token(0)
	assert_eq(
			int(ship.defense_tokens[0]["state"]),
			Constants.DefenseTokenState.EXHAUSTED,
			"Pre-condition: token 0 is EXHAUSTED")
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "injured_crew", "Injured Crew")
	var choice: Dictionary = {"id": "discard_defense_0"}
	var result: bool = _resolver().resolve(card, ship, deck, choice)
	assert_true(result, "Should resolve successfully — can discard exhausted")
	assert_eq(
			int(ship.defense_tokens[0]["state"]),
			Constants.DefenseTokenState.DISCARDED,
			"Exhausted token should now be DISCARDED")


func test_injured_crew_flips_facedown() -> void:
	var ship: ShipInstance = _make_ship()
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "injured_crew", "Injured Crew")
	var choice: Dictionary = {"id": "discard_defense_0"}
	_resolver().resolve(card, ship, deck, choice)
	assert_false(card.is_faceup, "Card should flip facedown")


func test_injured_crew_no_options_returns_empty() -> void:
	# Ship with all defense tokens discarded.
	var ship: ShipInstance = _make_ship()
	ship.discard_defense_token(0)
	ship.discard_defense_token(1)
	var card: DamageCard = _make_faceup_card(
			ship, "injured_crew", "Injured Crew")
	var choices: Dictionary = _resolver().get_required_choice(card, ship)
	assert_true(choices.is_empty(),
			"Should return empty when all tokens are discarded")


func test_injured_crew_options_list_non_discarded() -> void:
	var ship: ShipInstance = _make_ship()
	ship.discard_defense_token(0)
	var card: DamageCard = _make_faceup_card(
			ship, "injured_crew", "Injured Crew")
	var choices: Dictionary = _resolver().get_required_choice(card, ship)
	assert_false(choices.is_empty(),
			"Should have options when 1 token remains")
	var options: Array = choices.get("options", [])
	assert_eq(options.size(), 1,
			"Should list only the non-discarded token")
	assert_eq(options[0]["id"], "discard_defense_1",
			"Only brace (idx 1) should be listed")


# ---------------------------------------------------------------------------
# Shield Failure — opponent chooses up to 2 hull zones, each loses 1 shield
# ---------------------------------------------------------------------------


func test_shield_failure_requires_choice() -> void:
	var ship: ShipInstance = _make_ship()
	var card: DamageCard = _make_faceup_card(
			ship, "shield_failure", "Shield Failure")
	var choices: Dictionary = _resolver().get_required_choice(card, ship)
	assert_false(choices.is_empty(),
			"Shield Failure should require a zone choice")
	assert_eq(choices["choice_type"], "shield_failure",
			"Choice type should be 'shield_failure'")
	assert_eq(choices["chooser"], "opponent",
			"Chooser should be 'opponent'")
	assert_true(choices.get("multi_select", false),
			"Should be multi-select")
	assert_eq(int(choices.get("max_selections", 0)), 2,
			"Max selections should be 2")


func test_shield_failure_removes_one_shield_from_one_zone() -> void:
	var ship: ShipInstance = _make_ship(3, 2, 2, 1)
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "shield_failure", "Shield Failure")
	var result: bool = _resolver().resolve(
			card, ship, deck, {"zones": ["FRONT"]})
	assert_true(result, "Should resolve successfully")
	assert_eq(int(ship.current_shields["FRONT"]), 2,
			"FRONT should be 3-1=2")
	# Other zones unchanged.
	assert_eq(int(ship.current_shields["LEFT"]), 2,
			"LEFT should be unchanged")


func test_shield_failure_removes_one_shield_from_two_zones() -> void:
	var ship: ShipInstance = _make_ship(3, 2, 2, 1)
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "shield_failure", "Shield Failure")
	var result: bool = _resolver().resolve(
			card, ship, deck, {"zones": ["FRONT", "LEFT"]})
	assert_true(result, "Should resolve successfully")
	assert_eq(int(ship.current_shields["FRONT"]), 2,
			"FRONT should be 3-1=2")
	assert_eq(int(ship.current_shields["LEFT"]), 1,
			"LEFT should be 2-1=1")
	# Untouched zones.
	assert_eq(int(ship.current_shields["RIGHT"]), 2,
			"RIGHT should be unchanged")
	assert_eq(int(ship.current_shields["REAR"]), 1,
			"REAR should be unchanged")


func test_shield_failure_zero_zones_chosen() -> void:
	var ship: ShipInstance = _make_ship(3, 2, 2, 1)
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "shield_failure", "Shield Failure")
	var result: bool = _resolver().resolve(
			card, ship, deck, {"zones": []})
	assert_true(result, "Should succeed even with 0 zones chosen")
	assert_eq(int(ship.current_shields["FRONT"]), 3,
			"FRONT should be unchanged")


func test_shield_failure_zone_at_zero_shields() -> void:
	var ship: ShipInstance = _make_ship(0, 2, 2, 1)
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "shield_failure", "Shield Failure")
	var result: bool = _resolver().resolve(
			card, ship, deck, {"zones": ["FRONT", "LEFT"]})
	assert_true(result, "Should resolve even if a zone is at 0")
	assert_eq(int(ship.current_shields["FRONT"]), 0,
			"FRONT should stay at 0")
	assert_eq(int(ship.current_shields["LEFT"]), 1,
			"LEFT should be 2-1=1")


func test_shield_failure_rejects_duplicate_zones() -> void:
	var ship: ShipInstance = _make_ship(3, 2, 2, 1)
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "shield_failure", "Shield Failure")
	var result: bool = _resolver().resolve(
			card, ship, deck, {"zones": ["FRONT", "FRONT"]})
	assert_false(result, "Should reject duplicate zones")
	# The resolver logs a warning via push_warning — mark it handled.
	for err: Variant in get_errors():
		err.handled = true


func test_shield_failure_flips_facedown() -> void:
	var ship: ShipInstance = _make_ship()
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "shield_failure", "Shield Failure")
	_resolver().resolve(card, ship, deck, {"zones": ["FRONT"]})
	assert_false(card.is_faceup, "Card should flip facedown")


# ---------------------------------------------------------------------------
# Comm Noise — opponent chooses: reduce speed OR change top dial command
# ---------------------------------------------------------------------------


func test_comm_noise_requires_choice() -> void:
	var ship: ShipInstance = _make_ship()
	# Ensure dial stack has hidden dials.
	ship.command_dial_stack.assign_dials(
			[Constants.CommandType.NAVIGATE,
			Constants.CommandType.REPAIR], 1)
	var card: DamageCard = _make_faceup_card(
			ship, "comm_noise", "Comm Noise")
	var choices: Dictionary = _resolver().get_required_choice(card, ship)
	assert_false(choices.is_empty(),
			"Comm Noise should require a choice")
	assert_eq(choices["choice_type"], "comm_noise",
			"Choice type should be 'comm_noise'")
	assert_eq(choices["chooser"], "opponent",
			"Chooser should be 'opponent'")


func test_comm_noise_reduce_speed() -> void:
	var ship: ShipInstance = _make_ship()
	ship.set_speed(2)
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "comm_noise", "Comm Noise")
	var result: bool = _resolver().resolve(
			card, ship, deck, {"id": "reduce_speed"})
	assert_true(result, "Should resolve successfully")
	assert_eq(ship.current_speed, 1,
			"Speed should be reduced from 2 to 1")


func test_comm_noise_reduce_speed_to_zero() -> void:
	var ship: ShipInstance = _make_ship()
	ship.set_speed(1)
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "comm_noise", "Comm Noise")
	var result: bool = _resolver().resolve(
			card, ship, deck, {"id": "reduce_speed"})
	assert_true(result, "Should resolve successfully")
	assert_eq(ship.current_speed, 0,
			"Speed should be reduced from 1 to 0")


func test_comm_noise_reduce_speed_unavailable_at_zero() -> void:
	var ship: ShipInstance = _make_ship()
	ship.set_speed(0)
	ship.command_dial_stack.assign_dials(
			[Constants.CommandType.NAVIGATE,
			Constants.CommandType.NAVIGATE], 1)
	var card: DamageCard = _make_faceup_card(
			ship, "comm_noise", "Comm Noise")
	var choices: Dictionary = _resolver().get_required_choice(card, ship)
	# reduce_speed should be listed but unavailable.
	var options: Array = choices.get("options", [])
	var speed_opt: Dictionary = {}
	for opt: Dictionary in options:
		if opt.get("id", "") == "reduce_speed":
			speed_opt = opt
	assert_false(speed_opt.is_empty(),
			"reduce_speed option should be listed")
	assert_false(speed_opt.get("available", true),
			"reduce_speed should be unavailable at speed 0")


func test_comm_noise_change_dial_command() -> void:
	var ship: ShipInstance = _make_ship()
	ship.command_dial_stack.assign_dials(
			[Constants.CommandType.NAVIGATE,
			Constants.CommandType.NAVIGATE], 1)
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "comm_noise", "Comm Noise")
	var result: bool = _resolver().resolve(
			card, ship, deck,
			{"id": "change_dial_%d" % Constants.CommandType.REPAIR})
	assert_true(result, "Should resolve successfully")
	# The top hidden dial should now be Repair.
	var top: Dictionary = ship.command_dial_stack.peek_top()
	assert_eq(int(top.get("command", -1)), Constants.CommandType.REPAIR,
			"Top dial should be changed to Repair")


func test_comm_noise_flips_facedown() -> void:
	var ship: ShipInstance = _make_ship()
	ship.set_speed(2)
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "comm_noise", "Comm Noise")
	_resolver().resolve(card, ship, deck, {"id": "reduce_speed"})
	assert_false(card.is_faceup, "Card should flip facedown")


func test_comm_noise_no_dials_speed_zero_returns_empty() -> void:
	var ship: ShipInstance = _make_ship()
	ship.set_speed(0)
	# No dials assigned, speed 0 — no available options.
	var card: DamageCard = _make_faceup_card(
			ship, "comm_noise", "Comm Noise")
	var choices: Dictionary = _resolver().get_required_choice(card, ship)
	assert_true(choices.is_empty(),
			"Should return empty when no options are available")


func test_comm_noise_speed_positive_no_dials_still_has_choice() -> void:
	var ship: ShipInstance = _make_ship()
	ship.set_speed(2)
	# No dials assigned, but speed > 0 → reduce_speed is available.
	var card: DamageCard = _make_faceup_card(
			ship, "comm_noise", "Comm Noise")
	var choices: Dictionary = _resolver().get_required_choice(card, ship)
	assert_false(choices.is_empty(),
			"Should have a choice when speed > 0 even without dials")
