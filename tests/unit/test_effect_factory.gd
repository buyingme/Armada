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

func test_register_bomber_keyword() -> void:
	var gs: GameState = _setup_state([["Bomber"]], [])
	var count: int = EffectFactory.register_squadron_keywords(gs, 0)
	assert_eq(count, 1,
			"Should register 1 effect for 1 Bomber keyword")
	var effects: Array[GameEffect] = gs.effect_registry.get_effects_for_hook(
			&"ATTACK_CALC_DAMAGE")
	assert_eq(effects.size(), 1,
			"ATTACK_CALC_DAMAGE hook should have 1 effect")
	assert_true(effects[0] is BomberEffect,
			"Effect should be a BomberEffect")


func test_register_escort_keyword() -> void:
	var gs: GameState = _setup_state([["Escort"]], [])
	var count: int = EffectFactory.register_squadron_keywords(gs, 0)
	assert_eq(count, 1,
			"Should register 1 effect for 1 Escort keyword")


func test_register_swarm_keyword() -> void:
	var gs: GameState = _setup_state([["Swarm"]], [])
	var count: int = EffectFactory.register_squadron_keywords(gs, 0)
	assert_eq(count, 1,
			"Should register 1 effect for 1 Swarm keyword")


func test_register_multiple_keywords() -> void:
	var gs: GameState = _setup_state([["Bomber", "Escort"]], [])
	var count: int = EffectFactory.register_squadron_keywords(gs, 0)
	assert_eq(count, 2,
			"Should register 2 effects for a squadron with Bomber+Escort")


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
	var gs: GameState = _setup_state([["Bomber"]], [])
	EffectFactory.register_squadron_keywords(gs, 0)
	var effects: Array[GameEffect] = gs.effect_registry.get_all_effects()
	assert_eq(effects.size(), 1, "Should have 1 effect")
	var sq: SquadronInstance = \
			gs.get_player_state(0).squadrons[0] as SquadronInstance
	assert_eq(effects[0].owner, sq,
			"Effect owner should be set to the squadron instance")


func test_register_player_priority_initiative() -> void:
	# Player 0 has initiative, player 1 does not.
	var gs: GameState = _setup_state([["Bomber"]], [["Bomber"]])
	EffectFactory.register_squadron_keywords(gs, 0)
	var effects: Array[GameEffect] = gs.effect_registry.get_all_effects()
	assert_eq(effects.size(), 2, "Should have 2 effects total")
	# Find the effect belonging to player 0 vs player 1.
	var p0_effect: GameEffect = null
	var p1_effect: GameEffect = null
	for e: GameEffect in effects:
		var owner_sq: SquadronInstance = e.owner as SquadronInstance
		if owner_sq.owner_player == 0:
			p0_effect = e
		else:
			p1_effect = e
	assert_not_null(p0_effect, "Player 0 should have an effect")
	assert_not_null(p1_effect, "Player 1 should have an effect")
	assert_eq(p0_effect.player_priority, 0,
			"Initiative player effects should have priority 0")
	assert_eq(p1_effect.player_priority, 1,
			"Non-initiative player effects should have priority 1")


func test_register_null_game_state_returns_zero() -> void:
	var count: int = EffectFactory.register_squadron_keywords(null, 0)
	assert_eq(count, 0,
			"Null game state should return 0")


func test_register_both_players() -> void:
	var gs: GameState = _setup_state(
			[["Bomber"], ["Swarm"]],
			[["Escort"]])
	var count: int = EffectFactory.register_squadron_keywords(gs, 0)
	assert_eq(count, 3,
			"Should register 3 effects across both players")
