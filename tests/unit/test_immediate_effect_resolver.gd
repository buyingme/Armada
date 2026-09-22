## Candidate-only pure presentation derivation coverage.
extends GutTest


func test_identifies_immediate_timings_without_mutation() -> void:
	var immediate := _card("structural_damage", "immediate")
	var persistent := _card("life_support_failure", "immediate_persistent")
	var ordinary := _card("ordinary", "persistent")
	assert_true(ImmediateEffectResolver.is_immediate(immediate))
	assert_true(ImmediateEffectResolver.is_immediate(persistent))
	assert_false(ImmediateEffectResolver.is_immediate(ordinary))


func test_owner_choice_derivation_is_pure() -> void:
	var ship: ShipInstance = _ship()
	var card := _card("injured_crew", "immediate")
	var before: Dictionary = ship.serialize()
	var choice: Dictionary = ImmediateEffectResolver.new() \
			.get_required_choice(card, ship)
	assert_eq(choice["choice_type"],
			ImmediateEffectResolver.CHOICE_INJURED_CREW)
	assert_eq(choice["chooser"], "owner")
	assert_eq((choice["options"] as Array).size(), 2)
	assert_eq(ship.serialize(), before)


func test_opponent_choice_derivation_preserves_hidden_dial_and_state() -> void:
	var ship: ShipInstance = _ship()
	ship.command_dial_stack.assign_dials(
			[Constants.CommandType.NAVIGATE, Constants.CommandType.REPAIR], 1)
	var card := _card("comm_noise", "immediate")
	var before: Dictionary = ship.serialize()
	var choice: Dictionary = ImmediateEffectResolver.new() \
			.get_required_choice(card, ship)
	assert_eq(choice["choice_type"],
			ImmediateEffectResolver.CHOICE_COMM_NOISE)
	assert_eq(choice["chooser"], "opponent")
	assert_eq((choice["options"] as Array).size(), 5)
	assert_eq(ship.serialize(), before)


func test_projector_choice_exists_only_for_positive_tie() -> void:
	var ship: ShipInstance = _ship()
	var card := _card("projector_misaligned", "immediate")
	ship.current_shields = {"front": 2, "left": 2, "right": 1, "rear": 0}
	var tied: Dictionary = ImmediateEffectResolver.new() \
			.get_required_choice(card, ship)
	assert_eq(tied["choice_type"],
			ImmediateEffectResolver.CHOICE_PROJECTOR_MISALIGNED)
	assert_eq((tied["options"] as Array).size(), 2)
	ship.current_shields["left"] = 1
	assert_true(ImmediateEffectResolver.new()
			.get_required_choice(card, ship).is_empty())


func test_resolver_source_exposes_no_mutating_authority() -> void:
	var source: String = FileAccess.get_file_as_string(
			"res://src/core/damage/immediate_effect_resolver.gd")
	assert_false(source.contains("func resolve("))
	assert_false(source.contains("func _resolve_"))
	assert_false(source.contains("_move_to_facedown"))
	assert_false(source.contains("EventBus."))
	assert_false(source.contains("add_facedown_damage"))


func _card(effect_id: String, timing: String) -> DamageCard:
	var card := DamageCard.new()
	card.effect_id = effect_id
	card.title = effect_id
	card.effect_text = effect_id
	card.timing = timing
	card.is_faceup = true
	return card


func _ship() -> ShipInstance:
	var data := ShipData.new()
	data.hull = 5
	data.command_value = 2
	data.max_speed = 3
	data.shields = {"front": 2, "left": 1, "right": 1, "rear": 1}
	data.defense_tokens = ["brace", "redirect"]
	return ShipInstance.create_from_data("resolver", data, 2, 0)
