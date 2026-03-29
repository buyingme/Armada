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
# Projector Misaligned — reduce all zones by 1, then flip facedown
# ---------------------------------------------------------------------------


func test_projector_misaligned_reduces_all_zones() -> void:
	var ship: ShipInstance = _make_ship(3, 2, 2, 1)
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "projector_misaligned", "Projector Misaligned")
	_resolver().resolve(card, ship, deck)
	assert_eq(int(ship.current_shields["FRONT"]), 2,
			"FRONT should be 3-1=2")
	assert_eq(int(ship.current_shields["LEFT"]), 1,
			"LEFT should be 2-1=1")
	assert_eq(int(ship.current_shields["RIGHT"]), 1,
			"RIGHT should be 2-1=1")
	assert_eq(int(ship.current_shields["REAR"]), 0,
			"REAR should be 1-1=0")


func test_projector_misaligned_does_not_go_below_zero() -> void:
	var ship: ShipInstance = _make_ship(1, 0, 0, 0)
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "projector_misaligned", "Projector Misaligned")
	_resolver().resolve(card, ship, deck)
	assert_eq(int(ship.current_shields["FRONT"]), 0,
			"FRONT should be 0 (was 1)")
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
	assert_false(card.is_faceup,
			"Card should flip facedown after effect")


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
# Injured Crew — opponent chooses: discard token OR exhaust defense token
# ---------------------------------------------------------------------------


func test_injured_crew_requires_choice() -> void:
	var ship: ShipInstance = _make_ship()
	ship.command_tokens.add_token(Constants.CommandType.NAVIGATE)
	var card: DamageCard = _make_faceup_card(
			ship, "injured_crew", "Injured Crew")
	var choices: Dictionary = _resolver().get_required_choice(card, ship)
	assert_false(choices.is_empty(),
			"Injured Crew should require opponent choice")
	assert_eq(choices["choice_type"], "injured_crew",
			"Choice type should be 'injured_crew'")


func test_injured_crew_discard_command_token() -> void:
	var ship: ShipInstance = _make_ship()
	ship.command_tokens.add_token(Constants.CommandType.NAVIGATE)
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "injured_crew", "Injured Crew")
	var choice: Dictionary = {
		"id": "discard_token_%d" % Constants.CommandType.NAVIGATE,
	}
	var result: bool = _resolver().resolve(card, ship, deck, choice)
	assert_true(result, "Should resolve successfully")
	assert_false(ship.command_tokens.has_token(Constants.CommandType.NAVIGATE),
			"Navigate token should be discarded")


func test_injured_crew_exhaust_defense_token() -> void:
	var ship: ShipInstance = _make_ship()
	# Ship has evade (index 0) and brace (index 1) both READY.
	assert_eq(
			int(ship.defense_tokens[0]["state"]),
			Constants.DefenseTokenState.READY,
			"Pre-condition: token 0 is READY")
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "injured_crew", "Injured Crew")
	var choice: Dictionary = {"id": "exhaust_defense_0"}
	var result: bool = _resolver().resolve(card, ship, deck, choice)
	assert_true(result, "Should resolve successfully")
	assert_eq(
			int(ship.defense_tokens[0]["state"]),
			Constants.DefenseTokenState.EXHAUSTED,
			"Defense token 0 should be EXHAUSTED")


func test_injured_crew_flips_facedown() -> void:
	var ship: ShipInstance = _make_ship()
	ship.command_tokens.add_token(Constants.CommandType.NAVIGATE)
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "injured_crew", "Injured Crew")
	var choice: Dictionary = {
		"id": "discard_token_%d" % Constants.CommandType.NAVIGATE,
	}
	_resolver().resolve(card, ship, deck, choice)
	assert_false(card.is_faceup, "Card should flip facedown")


func test_injured_crew_no_options_returns_empty() -> void:
	# Ship with no command tokens and all defense tokens exhausted.
	var ship: ShipInstance = _make_ship()
	ship.exhaust_defense_token(0)
	ship.exhaust_defense_token(1)
	var card: DamageCard = _make_faceup_card(
			ship, "injured_crew", "Injured Crew")
	var choices: Dictionary = _resolver().get_required_choice(card, ship)
	assert_true(choices.is_empty(),
			"Should return empty when no valid options exist")


# ---------------------------------------------------------------------------
# Shield Failure — opponent chooses hull zone, all shields → 0
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


func test_shield_failure_zeroes_chosen_zone() -> void:
	var ship: ShipInstance = _make_ship(3, 2, 2, 1)
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "shield_failure", "Shield Failure")
	var result: bool = _resolver().resolve(
			card, ship, deck, {"id": "FRONT"})
	assert_true(result, "Should resolve successfully")
	assert_eq(int(ship.current_shields["FRONT"]), 0,
			"FRONT shields should be 0")
	# Other zones unchanged.
	assert_eq(int(ship.current_shields["LEFT"]), 2,
			"LEFT should be unchanged")


func test_shield_failure_flips_facedown() -> void:
	var ship: ShipInstance = _make_ship()
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "shield_failure", "Shield Failure")
	_resolver().resolve(card, ship, deck, {"id": "FRONT"})
	assert_false(card.is_faceup, "Card should flip facedown")


# ---------------------------------------------------------------------------
# Comm Noise — opponent chooses: discard top dial OR discard command token
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


func test_comm_noise_discard_dial() -> void:
	var ship: ShipInstance = _make_ship()
	ship.command_dial_stack.assign_dials(
			[Constants.CommandType.NAVIGATE,
			Constants.CommandType.NAVIGATE], 1)
	var hidden_before: int = ship.command_dial_stack.get_hidden_count()
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "comm_noise", "Comm Noise")
	var result: bool = _resolver().resolve(
			card, ship, deck, {"id": "discard_dial"})
	assert_true(result, "Should resolve successfully")
	assert_eq(ship.command_dial_stack.get_hidden_count(),
			hidden_before - 1,
			"Should have 1 fewer hidden dial")


func test_comm_noise_discard_token() -> void:
	var ship: ShipInstance = _make_ship()
	ship.command_tokens.add_token(Constants.CommandType.REPAIR)
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "comm_noise", "Comm Noise")
	var choice: Dictionary = {
		"id": "discard_token_%d" % Constants.CommandType.REPAIR,
	}
	var result: bool = _resolver().resolve(card, ship, deck, choice)
	assert_true(result, "Should resolve successfully")
	assert_false(ship.command_tokens.has_token(Constants.CommandType.REPAIR),
			"Repair token should be discarded")


func test_comm_noise_flips_facedown() -> void:
	var ship: ShipInstance = _make_ship()
	ship.command_dial_stack.assign_dials(
			[Constants.CommandType.NAVIGATE,
			Constants.CommandType.NAVIGATE], 1)
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_faceup_card(
			ship, "comm_noise", "Comm Noise")
	_resolver().resolve(card, ship, deck, {"id": "discard_dial"})
	assert_false(card.is_faceup, "Card should flip facedown")


func test_comm_noise_no_dials_no_tokens_returns_empty() -> void:
	var ship: ShipInstance = _make_ship()
	# No dials assigned, no tokens held.
	var card: DamageCard = _make_faceup_card(
			ship, "comm_noise", "Comm Noise")
	var choices: Dictionary = _resolver().get_required_choice(card, ship)
	assert_true(choices.is_empty(),
			"Should return empty when no dials or tokens available")
