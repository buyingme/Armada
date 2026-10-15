## Focused regressions for identity-free remote ship-damage presentation.
extends GutTest


var _state: GameState
var _previous_state: GameState


func before_each() -> void:
	_previous_state = GameManager.current_game_state
	_state = GameState.new()
	_state.initialize()
	_state.current_round = 1
	_state.current_phase = Constants.GamePhase.SHIP
	assert_not_null(CurrentAttackStateFixture.install(_state, {
		"attack_id": "attack:41",
		"attacker_player": 0,
		"defender_player": 1,
	}))
	GameManager.current_game_state = _state
	watch_signals(EventBus)


func after_each() -> void:
	GameManager.current_game_state = _previous_state


func test_identity_free_shield_only_refreshes_exact_zone_without_hull() -> void:
	var ship: ShipInstance = _defender()
	ship.current_shields["FRONT"] = 2

	GameManager._handle_remote_resolve_damage(_command(), _outcome({
		"post_resolution_shields": 2,
		"shield_absorbed": 1,
	}))

	assert_signal_emitted_with_parameters(EventBus,
			"ship_shields_changed", [ship, "FRONT", 2])
	assert_signal_not_emitted(EventBus, "ship_hull_changed")
	assert_signal_not_emitted(EventBus, "damage_card_dealt")


func test_identity_free_facedown_hull_refreshes_canonical_cards() -> void:
	var ship: ShipInstance = _defender()
	ship.add_facedown_damage(DamageCard.create("Ship", "Facedown"))

	GameManager._handle_remote_resolve_damage(_command(), _outcome({
		"hull_damage": 1,
		"final_damage": 1,
	}))

	assert_signal_emitted_with_parameters(EventBus,
			"ship_hull_changed", [ship, ship.ship_data.hull - 1])
	assert_signal_emitted(EventBus, "damage_card_dealt")
	assert_signal_emitted(EventBus, "damage_summary_requested")


func test_identity_free_faceup_hull_refreshes_canonical_cards() -> void:
	var ship: ShipInstance = _defender()
	var card: DamageCard = DamageCard.create("Ship", "Faceup")
	card.flip_faceup()
	card.public_card_ref = "faceup:remote:41"
	ship.add_faceup_damage(card)

	GameManager._handle_remote_resolve_damage(_command(), _outcome({
		"hull_damage": 1,
		"final_damage": 1,
	}))

	assert_signal_emitted_with_parameters(EventBus,
			"ship_hull_changed", [ship, ship.ship_data.hull - 1])
	assert_signal_emitted(EventBus, "damage_card_dealt")
	assert_signal_emitted(EventBus, "damage_summary_requested")
	assert_eq(ship.faceup_damage, [card],
			"Presentation normalization must not replace canonical faceup state.")


func test_identity_free_lethal_refreshes_zero_hull() -> void:
	var ship: ShipInstance = _defender()
	for index: int in range(ship.ship_data.hull):
		ship.add_facedown_damage(DamageCard.create(
				"Ship", "Lethal %d" % index))
	assert_true(ship.is_destroyed())

	GameManager._handle_remote_resolve_damage(_command(), _outcome({
		"hull_damage": ship.ship_data.hull,
		"final_damage": ship.ship_data.hull,
		"destroyed": true,
	}))

	assert_signal_emitted_with_parameters(EventBus,
			"ship_hull_changed", [ship, 0])
	assert_signal_emitted(EventBus, "damage_card_dealt")
	assert_signal_emitted(EventBus, "damage_summary_requested")


func test_partial_or_invalid_explicit_identity_never_falls_back() -> void:
	var partial: Dictionary = _outcome()
	partial["owner_player"] = 1
	assert_true(GameManager._resolve_remote_ship_damage_presentation(
			_command(), partial).is_empty())

	var mistyped: Dictionary = _outcome()
	mistyped["owner_player"] = "1"
	mistyped["ship_index"] = 0
	assert_true(GameManager._resolve_remote_ship_damage_presentation(
			_command(), mistyped).is_empty())

	var invalid: Dictionary = _outcome()
	invalid["owner_player"] = -1
	invalid["ship_index"] = 0
	assert_true(GameManager._resolve_remote_ship_damage_presentation(
			_command(), invalid).is_empty())


func test_identity_free_shape_requires_matching_active_attack() -> void:
	var stale: ResolveDamageCommand = ResolveDamageCommand.new(0, {
		"attack_id": "attack:40",
	})
	assert_true(GameManager._resolve_remote_ship_damage_presentation(
			stale, _outcome()).is_empty())
	assert_true(_state.set_current_attack_state(CurrentAttackState.inactive()))
	assert_true(GameManager._resolve_remote_ship_damage_presentation(
			_command(), _outcome()).is_empty())


func _command() -> ResolveDamageCommand:
	return ResolveDamageCommand.new(0, {"attack_id": "attack:41"})


func _defender() -> ShipInstance:
	return _state.get_ship(1, 0)


func _outcome(overrides: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"target_kind": CurrentAttackState.KIND_SHIP,
		"affected_zone": int(Constants.HullZone.FRONT),
		"post_resolution_shields": int(
				_defender().current_shields.get("FRONT", 0)),
		"hull_damage": 0,
		"shield_absorbed": 0,
		"final_damage": 0,
		"destroyed": _defender().is_destroyed(),
	}
	result.merge(overrides, true)
	return result
