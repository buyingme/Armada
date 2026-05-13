## Test: Save/Load Round-Trip (Phase J2)
##
## Validates that `serialize → deserialize` preserves the full game state,
## and that `GameManager.start_new_game_from_state()` correctly installs
## a deserialised state as the live game.
extends GutTest


const SaveManagerScript: GDScript = preload(
		"res://src/autoload/save_game_manager.gd")
const TEST_SAVE: String = "_gut_j2_round_trip"

const SHIP_KEY_CR90: String = "cr90_corvette_a"
const SHIP_KEY_NEBULON: String = "nebulon_b_escort_frigate"
const SQUAD_KEY_X_WING: String = "x_wing_squadron"

var _manager: Node = null


func before_each() -> void:
	_manager = SaveManagerScript.new()


func after_each() -> void:
	_manager.delete_save(TEST_SAVE)
	_manager.free()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_ship(key: String, owner: int) -> ShipInstance:
	var template: ShipData = AssetLoader.load_ship_data(key)
	assert_not_null(template, "Test fixture requires ship data for %s" % key)
	return ShipInstance.create_from_data(key, template, 2, owner)


func _make_squadron(key: String, owner: int) -> SquadronInstance:
	var template: SquadronData = AssetLoader.load_squadron_data(key)
	assert_not_null(template, "Test fixture requires squadron data for %s" % key)
	var inst: SquadronInstance = SquadronInstance.new()
	inst.data_key = key
	inst.squadron_data = template
	inst.current_hull = template.hull
	inst.owner_player = owner
	return inst


func _make_blinded_gunners_card() -> DamageCard:
	var card: DamageCard = DamageCard.new()
	card.effect_id = "blinded_gunners"
	card.title = "Blinded Gunners"
	card.trait_type = "Crew"
	card.timing = "persistent"
	card.effect_text = "While attacking, you cannot spend accuracy icons."
	card.is_faceup = true
	return card


func _accuracy_spend_cancelled(
		registry: EffectRegistry,
		attacker: ShipInstance) -> bool:
	var context: EffectContext = EffectContext.new()
	context.attacker = attacker
	registry.resolve_hook(&"ATTACK_SPEND_ACCURACY", context)
	return context.cancelled


func _make_populated_state() -> GameState:
	var gs: GameState = GameState.new()
	gs.initialize()
	gs.current_round = 4
	gs.current_phase = Constants.GamePhase.SHIP
	gs.initiative_player = 1
	# Player 0: CR90 + Nebulon-B
	gs.player_states[0].faction = Constants.Faction.REBEL_ALLIANCE
	var cr90: ShipInstance = _make_ship(SHIP_KEY_CR90, 0)
	cr90.current_hull = 2 # damaged
	cr90.pos_x = 0.42
	cr90.pos_y = 0.55
	cr90.rotation_deg = 90.0
	var nebulon: ShipInstance = _make_ship(SHIP_KEY_NEBULON, 0)
	nebulon.activated_this_round = true
	gs.player_states[0].ships.append_array([cr90, nebulon])
	# Player 0 also gets a squadron
	var xwing: SquadronInstance = _make_squadron(SQUAD_KEY_X_WING, 0)
	xwing.current_hull = 1
	xwing.pos_x = 0.10
	xwing.pos_y = 0.20
	gs.player_states[0].squadrons.append(xwing)
	# Damage deck — draw a few cards so the state isn't trivial.
	gs.damage_deck = DamageDeck.new()
	gs.damage_deck.initialize()
	for i: int in range(3):
		gs.damage_deck.draw_card()
	return gs


# ---------------------------------------------------------------------------
# PlayerState fleet rebuilding
# ---------------------------------------------------------------------------

func test_player_state_rebuilds_ships_from_template_keys() -> void:
	var gs: GameState = _make_populated_state()
	var data: Dictionary = gs.serialize()
	var restored: GameState = GameState.deserialize(data)
	var p0: PlayerState = restored.player_states[0]
	assert_eq(p0.ships.size(), 2,
			"Round-trip should restore both ships")
	var cr90: ShipInstance = p0.ships[0]
	assert_not_null(cr90.ship_data,
			"Restored ship should have its template re-resolved")
	assert_eq(cr90.data_key, SHIP_KEY_CR90,
			"data_key should round-trip")
	assert_eq(cr90.current_hull, 2,
			"current_hull should round-trip")
	assert_almost_eq(cr90.pos_x, 0.42, 0.001,
			"pos_x should round-trip")
	assert_almost_eq(cr90.rotation_deg, 90.0, 0.001,
			"rotation_deg should round-trip")
	var nebulon: ShipInstance = p0.ships[1]
	assert_true(nebulon.activated_this_round,
			"activated_this_round should round-trip")


func test_player_state_rebuilds_squadrons_from_template_keys() -> void:
	var gs: GameState = _make_populated_state()
	var restored: GameState = GameState.deserialize(gs.serialize())
	var p0: PlayerState = restored.player_states[0]
	assert_eq(p0.squadrons.size(), 1,
			"Round-trip should restore the squadron")
	var xwing: SquadronInstance = p0.squadrons[0]
	assert_not_null(xwing.squadron_data,
			"Restored squadron should have its template re-resolved")
	assert_eq(xwing.data_key, SQUAD_KEY_X_WING,
			"squadron data_key should round-trip")
	assert_eq(xwing.current_hull, 1,
			"squadron current_hull should round-trip")


# ---------------------------------------------------------------------------
# SaveGameManager round-trip with full fleet
# ---------------------------------------------------------------------------

func test_save_load_round_trip_preserves_fleet() -> void:
	var gs: GameState = _make_populated_state()
	var ok: bool = _manager.save_game(gs, TEST_SAVE)
	assert_true(ok, "save_game should succeed")
	var result: Dictionary = _manager.load_game(TEST_SAVE)
	assert_true(result["ok"], "load_game should succeed")
	var loaded: GameState = result["state"]
	assert_eq(loaded.player_states[0].ships.size(), 2,
			"Loaded state should have both ships")
	assert_eq(loaded.player_states[0].squadrons.size(), 1,
			"Loaded state should have the squadron")
	# Damage deck draw count preserved.
	assert_eq(loaded.damage_deck.get_draw_count(),
			DamageDeck.DECK_SIZE - 3,
			"Damage deck draw count should round-trip")
	# Restored ships have the template (otherwise downstream max-shield
	# look-ups would crash).
	for ship: Variant in loaded.player_states[0].ships:
		assert_not_null((ship as ShipInstance).ship_data,
				"Loaded ship template should be re-resolved")


# ---------------------------------------------------------------------------
# GameManager.start_new_game_from_state
# ---------------------------------------------------------------------------

func test_start_new_game_from_state_installs_state() -> void:
	var gs: GameState = _make_populated_state()
	var prev_state: GameState = GameManager.current_game_state
	var prev_active: bool = GameManager.is_game_active
	GameManager.start_new_game_from_state(gs, "test_scenario_xyz")
	assert_same(GameManager.current_game_state, gs,
			"current_game_state should point to the installed state")
	assert_true(GameManager.is_game_active,
			"is_game_active should be true after install")
	assert_eq(GameManager.active_player, gs.initiative_player,
			"active_player should default to the initiative player")
	assert_eq(GameManager.get_scenario_id(), "test_scenario_xyz",
			"scenario id should be recorded")
	# Restore prior state so we don't leak into other tests.
	GameManager.current_game_state = prev_state
	GameManager.is_game_active = prev_active


func test_start_new_game_from_state_emits_game_started() -> void:
	var gs: GameState = _make_populated_state()
	watch_signals(EventBus)
	var prev_state: GameState = GameManager.current_game_state
	var prev_active: bool = GameManager.is_game_active
	GameManager.start_new_game_from_state(gs, "x")
	assert_signal_emitted(EventBus, "game_started",
			"game_started should be emitted so the board can rebuild")
	GameManager.current_game_state = prev_state
	GameManager.is_game_active = prev_active


func test_start_new_game_from_state_initialises_effect_registry() -> void:
	var gs: GameState = _make_populated_state()
	gs.effect_registry = null # simulate a freshly-deserialised state
	var prev_state: GameState = GameManager.current_game_state
	var prev_active: bool = GameManager.is_game_active
	GameManager.start_new_game_from_state(gs, "x")
	assert_not_null(GameManager.current_game_state.effect_registry,
			"start_new_game_from_state should ensure effect_registry exists")
	GameManager.current_game_state = prev_state
	GameManager.is_game_active = prev_active


## Regression: when a save is loaded outside the Squadron Phase (e.g.
## mid-Ship-Phase), squadron keyword effects (Bomber, Escort, Swarm)
## must already be registered so that the next squadron attack issued
## under a Squadron command resolves keyword damage correctly.
##
## Without this, an X-wing's Bomber crit deals 0 damage on a
## squadron-vs-ship attack — see attack_executor → calc_damage which
## relies on the ATTACK_CALC_DAMAGE hook firing.
func test_start_new_game_from_state_registers_squadron_keywords() -> void:
	var gs: GameState = _make_populated_state()
	gs.effect_registry = EffectRegistry.new() # empty, like a load
	var prev_state: GameState = GameManager.current_game_state
	var prev_active: bool = GameManager.is_game_active
	GameManager.start_new_game_from_state(gs, "x")
	var registry: EffectRegistry = GameManager.current_game_state.effect_registry
	assert_gt(registry.get_effect_count(), 0,
			"squadron keyword effects should be registered after load "
			+"so Bomber crits resolve outside the Squadron Phase")
	# X-wing has Bomber + Escort — both should be present.
	var hooks: Array[GameEffect] = registry.get_effects_for_hook(
			&"ATTACK_CALC_DAMAGE")
	var has_bomber: bool = false
	for e: GameEffect in hooks:
		if e is BomberEffect:
			has_bomber = true
			break
	assert_true(has_bomber,
			"BomberEffect should be registered for the X-wing on load")
	GameManager.current_game_state = prev_state
	GameManager.is_game_active = prev_active


func test_start_new_game_from_state_registers_faceup_damage_effects() -> void:
	var gs: GameState = _make_populated_state()
	var damaged_ship: ShipInstance = gs.player_states[0].ships[1]
	damaged_ship.add_faceup_damage(_make_blinded_gunners_card())
	var restored: GameState = GameState.deserialize(gs.serialize())
	restored.effect_registry = EffectRegistry.new()
	var restored_ship: ShipInstance = restored.player_states[0].ships[1]
	assert_false(_accuracy_spend_cancelled(
			restored.effect_registry, restored_ship),
			"Precondition: deserialized state should start with no runtime hooks")
	var prev_state: GameState = GameManager.current_game_state
	var prev_active: bool = GameManager.is_game_active
	GameManager.start_new_game_from_state(restored, "x")
	var registry: EffectRegistry = GameManager.current_game_state.effect_registry
	var effects: Array[GameEffect] = registry.get_effects_for_hook(
			&"ATTACK_SPEND_ACCURACY")
	assert_eq(effects.size(), 1,
			"Loaded faceup Blinded Gunners should register its hook")
	assert_true(_accuracy_spend_cancelled(registry, restored_ship),
			"Loaded Blinded Gunners should block accuracy spending")
	GameManager.current_game_state = prev_state
	GameManager.is_game_active = prev_active


# ---------------------------------------------------------------------------
# Phase J5.6 — preloaded-state flag
# ---------------------------------------------------------------------------

func test_start_new_game_from_state_sets_preloaded_flag() -> void:
	var gs: GameState = _make_populated_state()
	var prev_state: GameState = GameManager.current_game_state
	var prev_active: bool = GameManager.is_game_active
	var prev_flag: bool = GameManager.is_state_preloaded
	GameManager.is_state_preloaded = false
	GameManager.start_new_game_from_state(gs, "x")
	assert_true(GameManager.is_state_preloaded,
			"start_new_game_from_state should mark state as preloaded")
	GameManager.current_game_state = prev_state
	GameManager.is_game_active = prev_active
	GameManager.is_state_preloaded = prev_flag


func test_consume_preloaded_flag_returns_true_then_clears() -> void:
	var prev_flag: bool = GameManager.is_state_preloaded
	GameManager.is_state_preloaded = true
	var first: bool = GameManager.consume_preloaded_flag()
	var second: bool = GameManager.consume_preloaded_flag()
	assert_true(first,
			"first consume_preloaded_flag() should return true")
	assert_false(second,
			"second consume_preloaded_flag() should return false (cleared)")
	GameManager.is_state_preloaded = prev_flag


func test_consume_preloaded_flag_returns_false_when_not_set() -> void:
	var prev_flag: bool = GameManager.is_state_preloaded
	GameManager.is_state_preloaded = false
	assert_false(GameManager.consume_preloaded_flag(),
			"consume_preloaded_flag() should return false when not set")
	GameManager.is_state_preloaded = prev_flag
