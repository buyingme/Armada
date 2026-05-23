## Test: EffectFactory
##
## Unit tests for keyword effect registration.
## Rules Reference: "Effect Use and Timing", RRG p.5; ET-001–004.
extends GutTest


## Creates a GameState with squadrons carrying the given keywords.
func _setup_state(
		p0_keywords: Array[Array],
		p1_keywords: Array[Array]) -> GameState:
	var gs: GameState = GameState.new()
	gs.initialize()
	var all_player_kw: Array[Array] = [p0_keywords, p1_keywords]
	for player_idx: int in range(2):
		var ps: PlayerState = gs.get_player_state(player_idx)
		for kw_list: Array in all_player_kw[player_idx]:
			var data: SquadronData = SquadronData.new()
			data.squadron_name = "Sq"
			data.hull = 3
			data.speed = 3
			data.defense_tokens = []
			var kw_dicts: Array[Dictionary] = []
			for kw: Variant in kw_list:
				kw_dicts.append({"name": kw as String})
			data.keywords = kw_dicts
			var inst: SquadronInstance = SquadronInstance.create_from_data(
					"sq_%d_%d" % [player_idx, ps.squadrons.size()],
					data, player_idx)
			ps.squadrons.append(inst)
	return gs


# --- Registration ---

func test_register_bomber_keyword_returns_zero_after_rule_migration() -> void:
	var gs: GameState = _setup_state([["Bomber"]], [])
	var count: int = EffectFactory.register_squadron_keywords(gs, 0)
	assert_eq(count, 0,
			"Bomber should use RuleRegistry instead of EffectFactory after N10")
	var effects: Array[GameEffect] = gs.effect_registry.get_effects_for_hook(
			&"ATTACK_CALC_DAMAGE")
	assert_eq(effects.size(), 0,
			"No legacy ATTACK_CALC_DAMAGE effect should be registered")


func test_register_escort_keyword() -> void:
	var gs: GameState = _setup_state([["Escort"]], [])
	var count: int = EffectFactory.register_squadron_keywords(gs, 0)
	assert_eq(count, 0,
			"Escort should use RuleRegistry instead of EffectFactory after N19")


func test_register_swarm_keyword() -> void:
	var gs: GameState = _setup_state([["Swarm"]], [])
	var count: int = EffectFactory.register_squadron_keywords(gs, 0)
	assert_eq(count, 0,
			"Swarm should use RuleRegistry instead of EffectFactory after N21")


func test_register_multiple_keywords() -> void:
	var gs: GameState = _setup_state([["Bomber", "Escort"]], [])
	var count: int = EffectFactory.register_squadron_keywords(gs, 0)
	assert_eq(count, 0,
			"Migrated squadron keywords should not register legacy effects")


func test_register_unknown_keyword_ignored() -> void:
	var gs: GameState = _setup_state([["Heavy"]], [])
	var count: int = EffectFactory.register_squadron_keywords(gs, 0)
	assert_eq(count, 0,
			"Unknown keyword 'Heavy' should not register any effects")


func test_register_no_squadrons() -> void:
	var gs: GameState = _setup_state([], [])
	var count: int = EffectFactory.register_squadron_keywords(gs, 0)
	assert_eq(count, 0,
			"No squadrons should register 0 effects")


func test_register_sets_owner() -> void:
	var gs: GameState = _setup_state([["Escort"]], [])
	EffectFactory.register_squadron_keywords(gs, 0)
	var effects: Array[GameEffect] = gs.effect_registry.get_all_effects()
	assert_eq(effects.size(), 0,
			"Migrated keywords should not create legacy owned effects")


func test_register_player_priority_initiative() -> void:
	# Player 0 has initiative, player 1 does not.
	var gs: GameState = _setup_state([["Escort"]], [["Escort"]])
	EffectFactory.register_squadron_keywords(gs, 0)
	var effects: Array[GameEffect] = gs.effect_registry.get_all_effects()
	assert_eq(effects.size(), 0,
			"Migrated keywords should not depend on legacy priority ordering")


func test_register_null_game_state_returns_zero() -> void:
	var count: int = EffectFactory.register_squadron_keywords(null, 0)
	assert_eq(count, 0,
			"Null game state should return 0")


func test_register_both_players() -> void:
	var gs: GameState = _setup_state(
			[["Bomber"], ["Swarm"]],
			[["Escort"]])
	var count: int = EffectFactory.register_squadron_keywords(gs, 0)
	assert_eq(count, 0,
			"Migrated squadron keywords should not register legacy effects")
