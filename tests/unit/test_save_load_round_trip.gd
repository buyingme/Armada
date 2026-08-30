## Test: Save/Load Round-Trip (Phase J2)
##
## Validates that `serialize → deserialize` preserves the full game state,
## and that `GameManager.start_new_game_from_state()` correctly installs
## a deserialised state as the live game.
extends GutTest


const SaveManagerScript: GDScript = preload(
		"res://src/autoload/save_game_manager.gd")
const TimingWindowStateScript: GDScript = preload(
		"res://src/core/state/timing_window_state.gd")
const CurrentAttackFixture: GDScript = preload(
		"res://tests/fixtures/current_attack_state_fixture.gd")
const TEST_SAVE: String = "_gut_j2_round_trip"

const SHIP_KEY_CR90: String = "cr90_corvette_a"
const SHIP_KEY_NEBULON: String = "nebulon_b_escort_frigate"
const SQUAD_KEY_X_WING: String = "x_wing_squadron"

var _manager: Node = null


func before_each() -> void:
	_manager = SaveManagerScript.new()


func after_each() -> void:
	RuleRegistry.clear()
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


func _accuracy_spend_blocked(attacker: ShipInstance) -> bool:
	var context: EffectContext = EffectContext.new()
	context.attacker = attacker
	return RuleSurface.is_blocked(context,
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			RuleSurface.TARGET_ACCURACY_SPEND)


func _make_populated_state() -> GameState:
	var gs: GameState = GameState.new()
	gs.initialize()
	assert_true(gs.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()))
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


## Produces the canonical state immediately after Player 0 completed a Ship
## activation.  EndActivationCommand is the authoritative producer of the
## persisted next-controller decision exercised by the resume regressions.
func _make_completed_ship_phase_state() -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()))
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.initiative_player = 0
	var cr90: ShipInstance = _make_ship(SHIP_KEY_CR90, 0)
	var nebulon: ShipInstance = _make_ship(SHIP_KEY_NEBULON, 0)
	var imperial_ship: ShipInstance = _make_ship(SHIP_KEY_CR90, 1)
	state.player_states[0].ships.append_array([cr90, nebulon])
	state.player_states[1].ships.append(imperial_ship)
	_assign_hidden_dials(cr90, Constants.CommandType.NAVIGATE)
	_assign_hidden_dials(nebulon, Constants.CommandType.REPAIR)
	_assign_hidden_dials(imperial_ship, Constants.CommandType.SQUADRON)

	var activate := ActivateShipCommand.new(0, {"ship_index": 0})
	activate.sequence = 1
	assert_eq(activate.validate(state), "",
			"Player 0 must be able to activate the CR90 before saving")
	var activation: Dictionary = activate.execute(state)
	var activation_id: String = str(activation.get("ship_activation_identity", ""))
	assert_false(activation_id.is_empty())
	assert_true(cr90.consume_unreached_squadron_command_opportunity(
			activation_id, true))
	assert_true(cr90.open_maneuver_opportunity(activation_id))
	assert_true(cr90.consume_open_maneuver_opportunity(activation_id))
	var finish := EndActivationCommand.new(0, {
		"ship_index": 0,
		"ship_activation_identity": activation_id,
	})
	assert_eq(finish.validate(state), "",
			"The completed Player 0 activation must produce the next actor")
	finish.execute(state)
	assert_true(cr90.activated_this_round)
	assert_eq(state.interaction_flow.controller_player, 1,
			"EndActivationCommand must persist Player 1 as the next actor")
	return state


func _assign_hidden_dials(ship: ShipInstance, command: int) -> void:
	var commands: Array[int] = []
	for _index: int in range(ship.command_dial_stack.get_dials_needed()):
		commands.append(command)
	assert_true(ship.command_dial_stack.assign_dials(commands, 1))


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


func test_debug_outcome_round_trip_preserves_public_transform_and_deck_order() -> void:
	var gs: GameState = _make_populated_state()
	var ship: ShipInstance = gs.player_states[0].ships[0] as ShipInstance
	ship.pos_x = 0.73
	ship.pos_y = 0.21
	ship.rotation_deg = 135.0
	var card: DamageCard = gs.damage_deck.take_debug_draw_card_by_effect_id(
			"injured_crew")
	assert_not_null(card)
	card.is_faceup = true
	ship.add_faceup_damage(card)
	var expected_deck: Dictionary = gs.damage_deck.serialize()
	assert_true(_manager.save_game(gs, TEST_SAVE))
	var result: Dictionary = _manager.load_game(TEST_SAVE)
	assert_true(bool(result.get("ok", false)))
	var loaded: GameState = result.get("state") as GameState
	var loaded_ship: ShipInstance = loaded.player_states[0].ships[0] as ShipInstance
	assert_eq(loaded_ship.pos_x, 0.73)
	assert_eq(loaded_ship.pos_y, 0.21)
	assert_eq(loaded_ship.rotation_deg, 135.0)
	assert_eq(loaded_ship.faceup_damage[0].effect_id, "injured_crew")
	assert_eq(loaded.damage_deck.serialize(), expected_deck)


func test_same_live_and_hot_seat_load_preserve_saved_next_ship_actor() -> void:
	var completed: GameState = _make_completed_ship_phase_state()
	var same_live: GameState = GameState.deserialize(completed.serialize())
	assert_not_null(same_live)
	assert_eq(same_live.interaction_flow.controller_player, 1,
			"The serialized state must retain Player 1's next decision")

	var prev_state: GameState = GameManager.current_game_state
	var prev_active: bool = GameManager.is_game_active
	var prev_player: int = GameManager.active_player
	assert_true(GameManager.start_new_game_from_state(same_live, "same_live"))
	assert_eq(GameManager.active_player, 1,
			"Same-live installation must not fall back to initiative")

	assert_true(_manager.save_game(completed, TEST_SAVE),
			"The post-activation Hot-Seat state must persist")
	var result: Dictionary = _manager.load_game(TEST_SAVE)
	assert_true(bool(result.get("ok", false)))
	var loaded: GameState = result.get("state") as GameState
	assert_not_null(loaded)
	assert_eq(loaded.interaction_flow.controller_player, 1,
			"Hot-Seat load must retain Player 1 as the next decision owner")
	assert_true(GameManager.start_new_game_from_state(loaded, "hot_seat_load"))
	assert_eq(GameManager.active_player, 1,
			"Hot-Seat installation must restore Player 1, not initiative Player 0")
	GameManager.current_game_state = prev_state
	GameManager.is_game_active = prev_active
	GameManager.active_player = prev_player


func test_local_attack_preview_does_not_enter_saved_authoritative_state() -> void:
	var gs: GameState = _make_populated_state()
	var canonical_before: Dictionary = gs.serialize()
	var scene_preview := AttackState.new()
	scene_preview.defender_name = "Local preview target"
	scene_preview.defender_zone = int(Constants.HullZone.FRONT)
	scene_preview.range_band = Constants.RANGE_BAND_CLOSE
	scene_preview.dice_pool = {"red": 2}
	assert_eq(gs.serialize(), canonical_before,
			"Local preview projection must not alter authoritative state.")

	assert_true(_manager.save_game(gs, TEST_SAVE),
			"Saving canonical state while a local preview exists should succeed.")
	var result: Dictionary = _manager.load_game(TEST_SAVE)
	assert_true(bool(result.get("ok", false)))
	var loaded: GameState = result.get("state") as GameState

	assert_not_null(loaded)
	assert_true(loaded.current_attack_state.is_inactive(),
			"Save/load before accepted Begin must restore no active attack.")
	assert_false(loaded.serialize().has("declaration_candidate"),
			"Transient declaration candidate must not enter save data.")


func test_timing_window_state_does_not_absorb_runtime_upgrade_rule_state() -> void:
	var gs: GameState = _make_populated_state()
	assert_not_null(CurrentAttackFixture.install(gs, {
		"attack_id": "attack:1",
		"attacker_player": 1,
		"defender_player": 0,
		"stage": CurrentAttackState.STAGE_ATTACK_MODIFY,
	}), "Fixture should install the matching canonical current attack")
	gs.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			1,
			Constants.Visibility.ALL,
			{"attacker_player": 1})
	assert_true(gs.set_timing_window_state(_make_active_timing_window(
			"attack_modify",
			"attack_modify",
			"attack_modify:2",
			1,
			{
				"continuation_id": "confirm_attack_dice",
				"resume_point": "attack_after_modify",
				"source_id": "attack:1",
				"source_type": "current_attack",
				"owner_player": 1,
			})),
			"GameState should accept valid timing-window lifecycle state")
	var ship: ShipInstance = gs.player_states[0].ships[0] as ShipInstance
	ship.roster_entry_id = "p0-cr90"
	var runtime_upgrade: Dictionary = ship.add_runtime_upgrade(
			"electronic_countermeasures",
			"upgrade-ecm-1",
			"DEFENSIVE_RETROFIT",
			0)
	runtime_upgrade["rule_state"] = {"pending_authorization": {"token": 1}}

	var restored: GameState = GameState.deserialize(gs.serialize())
	var restored_ship: ShipInstance = restored.player_states[0].ships[0]
	var restored_upgrade: Dictionary = restored_ship.runtime_upgrades[0]

	assert_eq(restored_upgrade["rule_state"],
			{"pending_authorization": {"token": 1}},
			"Runtime upgrade rule_state should round-trip on its owner")
	assert_false(restored.timing_window_state.serialize().has("rule_state"),
			"TimingWindowState must not copy rule-specific mutable state")


func _make_active_timing_window(
		window_id: String,
		stage: String,
		lifecycle_id: String,
		controller: int,
		continuation: Dictionary):
	var state = TimingWindowStateScript.new()
	assert_true(state.configure_active(
			window_id, stage, lifecycle_id, controller, continuation),
			"Test helper should build valid timing-window state")
	return state


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


## Regression: loaded games still derive Bomber from serialized squadron data
## without rebuilding transient runtime effect objects.
func test_start_new_game_from_state_preserves_bomber_rule_after_load() -> void:
	RuleRegistry.clear()
	BomberKeyword.register()
	var gs: GameState = _make_populated_state()
	var prev_state: GameState = GameManager.current_game_state
	var prev_active: bool = GameManager.is_game_active
	GameManager.start_new_game_from_state(gs, "x")
	var xwing: SquadronInstance = GameManager.current_game_state.get_squadron(0, 0)
	var defender: ShipInstance = GameManager.current_game_state.get_ship(0, 1)
	var context: EffectContext = _bomber_damage_context(xwing, defender)
	var modified: EffectContext = RuleSurface.apply_modifiers(context,
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE,
			RuleSurface.TARGET_ATTACK_DAMAGE)
	assert_eq(modified.damage_total, 2,
			"Loaded X-wing Bomber crit should count through RuleRegistry")
	GameManager.current_game_state = prev_state
	GameManager.is_game_active = prev_active


func _bomber_damage_context(attacker: SquadronInstance,
		defender: ShipInstance) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	context.attacker = attacker
	context.defender = defender
	context.damage_total = 1
	context.dice_results = [
		{"color": Constants.DiceColor.BLUE, "face": Constants.DiceFace.HIT},
		{"color": Constants.DiceColor.BLUE, "face": Constants.DiceFace.CRITICAL},
	]
	return context


func test_start_new_game_from_state_preserves_faceup_damage_rules() -> void:
	RuleRegistry.clear()
	BlindedGunners.register()
	var gs: GameState = _make_populated_state()
	var damaged_ship: ShipInstance = gs.player_states[0].ships[1]
	damaged_ship.add_faceup_damage(_make_blinded_gunners_card())
	var restored: GameState = GameState.deserialize(gs.serialize())
	var restored_ship: ShipInstance = restored.player_states[0].ships[1]
	var prev_state: GameState = GameManager.current_game_state
	var prev_active: bool = GameManager.is_game_active
	GameManager.start_new_game_from_state(restored, "x")
	assert_true(_accuracy_spend_blocked(restored_ship),
			"Loaded Blinded Gunners should block accuracy through RuleRegistry")
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
