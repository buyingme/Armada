## Test: Retired Legacy Keyword Effects
##
## Verifies Escort and Swarm no longer rebuild legacy GameEffect instances.
## Their production behavior is covered by RuleRegistry keyword rule tests.
extends GutTest


func test_escort_keyword_does_not_register_legacy_effect() -> void:
	var state: GameState = _state_with_keyword("Escort")
	var count: int = EffectFactory.register_squadron_keywords(state, 0)
	assert_eq(count, 0,
			"Escort should be implemented through RuleRegistry, not GameEffect.")
	assert_eq(state.effect_registry.get_all_effects().size(), 0,
			"Escort should not create a legacy effect instance.")


func test_swarm_keyword_does_not_register_legacy_effect() -> void:
	var state: GameState = _state_with_keyword("Swarm")
	var count: int = EffectFactory.register_squadron_keywords(state, 0)
	assert_eq(count, 0,
			"Swarm should be implemented through RuleRegistry, not GameEffect.")
	assert_eq(state.effect_registry.get_all_effects().size(), 0,
			"Swarm should not create a legacy effect instance.")


func _state_with_keyword(keyword_name: String) -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	var data: SquadronData = SquadronData.new()
	data.squadron_name = "Test Squadron"
	data.hull = 3
	data.speed = 3
	data.keywords = [ {"name": keyword_name}]
	var squadron: SquadronInstance = SquadronInstance.create_from_data(
			"test_squadron", data, 0)
	state.get_player_state(0).squadrons.append(squadron)
	return state
