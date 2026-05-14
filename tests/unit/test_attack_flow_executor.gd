## Test: AttackFlowExecutor
##
## Unit tests for pure attack-flow payload construction extracted from
## AttackExecutor in Phase K14a.
extends GutTest

const AttackFlowExecutorScript := preload(
		"res://src/core/combat/attack_flow_executor.gd")


var _executor: RefCounted = null
var _saved_game_state: GameState = null
var _saved_active_player: int = 0


func before_each() -> void:
	_saved_game_state = GameManager.current_game_state
	_saved_active_player = GameManager.active_player
	_executor = AttackFlowExecutorScript.new()


func after_each() -> void:
	GameManager.current_game_state = _saved_game_state
	GameManager.active_player = _saved_active_player


func test_build_clear_target_patch_contains_expected_defaults() -> void:
	var patch: Dictionary = _executor.build_clear_target_patch()
	assert_eq(patch.get("defender_name", "?"), "",
			"defender_name should reset to empty")
	assert_eq(int(patch.get("defender_zone", 999)), -1,
			"defender_zone should reset to -1")
	assert_eq(int(patch.get("modified_damage", -1)), 0,
			"modified_damage should reset to 0")
	assert_eq(bool(patch.get("evade_active", true)), false,
			"evade_active should reset to false")
	assert_eq(bool(patch.get("redirect_active", true)), false,
			"redirect_active should reset to false")


func test_build_clear_target_patch_clears_collection_fields() -> void:
	var patch: Dictionary = _executor.build_clear_target_patch()
	assert_true((patch.get("locked_tokens", null) as Array).is_empty(),
			"locked_tokens should be empty")
	assert_true((patch.get("defense_tokens", null) as Array).is_empty(),
			"defense_tokens should be empty")
	assert_true((patch.get("dice_results", null) as Array).is_empty(),
			"dice_results should be empty")
	assert_true((patch.get("dice_pool", null) as Dictionary).is_empty(),
			"dice_pool should be empty")


func test_compute_attack_identity_patch_without_gamestate_returns_base_fields() -> void:
	var state: AttackState = AttackState.new()
	state.attacker_name = "Nebulon-B"
	state.attacker_zone = Constants.HullZone.FRONT
	state.attacker_zone_name = "FRONT"
	state.defender_name = "Victory"
	state.defender_zone = Constants.HullZone.LEFT

	var patch: Dictionary = _executor.compute_attack_identity_patch(state, null)

	assert_eq(patch.get("attacker_name", ""), "Nebulon-B",
			"attacker_name should mirror state")
	assert_eq(int(patch.get("attacker_zone", -1)), int(Constants.HullZone.FRONT),
			"attacker_zone should mirror state")
	assert_eq(patch.get("defender_name", ""), "Victory",
			"defender_name should mirror state")
	assert_false(patch.has("attacker_kind"),
			"attacker_kind should not be set without GameState")
	assert_false(patch.has("target_kind"),
			"target_kind should not be set without GameState")


func test_compute_attack_identity_patch_ship_attacker_sets_kind_and_player() -> void:
	GameManager.start_new_game()
	var gs: GameState = GameManager.current_game_state
	var ps: PlayerState = gs.get_player_state(0)
	var ship: ShipInstance = _make_ship_instance(0)
	ps.ships.append(ship)

	var ship_token: ShipToken = _make_ship_token(ship)
	var state: AttackState = AttackState.new()
	state.attacker_ship = ship_token
	state.attacker_name = "Attacker"
	state.attacker_zone = Constants.HullZone.FRONT
	state.attacker_zone_name = "FRONT"

	var patch: Dictionary = _executor.compute_attack_identity_patch(state, gs)

	assert_eq(patch.get("attacker_kind", ""), "ship",
			"attacker_kind should be ship")
	assert_eq(int(patch.get("attacker_player", -1)), 0,
			"attacker_player should match ship owner")
	assert_eq(int(patch.get("attacker_ship_index", -1)), 0,
			"attacker_ship_index should resolve in GameState")


func test_compute_attack_identity_patch_squadron_target_sets_target_kind() -> void:
	GameManager.start_new_game()
	var gs: GameState = GameManager.current_game_state
	var ps: PlayerState = gs.get_player_state(1)
	var squad: SquadronInstance = _make_squadron_instance(1)
	ps.squadrons.append(squad)

	var sq_token: SquadronToken = _make_squadron_token(squad)
	var state: AttackState = AttackState.new()
	state.defender_squadron = sq_token
	state.defender_name = "Target Squad"
	state.defender_zone = -1

	var patch: Dictionary = _executor.compute_attack_identity_patch(state, gs)

	assert_eq(patch.get("target_kind", ""), "squadron",
			"target_kind should be squadron")
	assert_eq(int(patch.get("target_squadron_index", -1)), 0,
			"target_squadron_index should resolve in GameState")


func test_init_ship_exec_state_resets_attack_tracking() -> void:
	var state: AttackState = AttackState.new()
	state.squad_exec_mode = true
	state.current_attack = 2
	state.dice_pool = {"red": 2}
	state.attacked_squads.append(null)
	var ship: ShipInstance = _make_ship_instance(0)
	var ship_token: ShipToken = _make_ship_token(ship)

	_executor.init_ship_exec_state(state, ship_token)

	assert_true(state.exec_mode,
			"ship init should enable exec_mode")
	assert_false(state.squad_exec_mode,
			"ship init should disable squad_exec_mode")
	assert_same(state.exec_ship_token, ship_token,
			"ship token should be installed")
	assert_null(state.exec_squad_token,
			"squad token should be cleared")
	assert_eq(state.current_attack, 0,
			"attack counter should reset")
	assert_true(state.dice_pool.is_empty(),
			"dice pool should be reset")
	assert_true(state.attacked_squads.is_empty(),
			"attacked squad list should be reset")


func test_init_squadron_exec_state_sets_attacker_identity() -> void:
	var state: AttackState = AttackState.new()
	state.exec_ship_token = _make_ship_token(_make_ship_instance(0))
	var sq: SquadronInstance = _make_squadron_instance(1)
	var sq_token: SquadronToken = _make_squadron_token(sq)

	_executor.init_squadron_exec_state(state, sq_token)

	assert_true(state.exec_mode,
			"squad init should enable exec mode")
	assert_true(state.squad_exec_mode,
			"squad init should set squad exec mode")
	assert_same(state.exec_squad_token, sq_token,
			"squad token should be installed")
	assert_null(state.exec_ship_token,
			"ship token should be cleared")
	assert_eq(state.attacker_name, "Test Squadron",
			"attacker_name should use squadron display name")
	assert_same(state.attacker_squadron, sq_token,
			"attacker_squadron should point at selected token")


func test_extract_roll_results_filters_non_dictionary_entries() -> void:
	var parsed: Array[Dictionary] = _executor.extract_roll_results({
		"dice_results": [
			{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT},
			"junk",
			12,
		],
	})
	assert_eq(parsed.size(), 1,
			"extract_roll_results should keep only dictionaries")


func test_reset_for_confirm_sets_defense_defaults() -> void:
	var state: AttackState = AttackState.new()
	state.locked_tokens = [1, 2]
	state.spent_tokens = {Constants.DefenseToken.BRACE: true}
	state.defense_commit_queue = [0]
	state.redirect_remaining = 2
	state.redirect_zone = int(Constants.HullZone.LEFT)
	state.contain_used = true
	state.brace_used = true
	state.redirect_step = true
	state.evade_step = true

	_executor.reset_for_confirm(state, 4)

	assert_true(state.locked_tokens.is_empty(),
			"locked tokens should be cleared")
	assert_true(state.spent_tokens.is_empty(),
			"spent tokens should be cleared")
	assert_true(state.defense_commit_queue.is_empty(),
			"defense queue should be cleared")
	assert_eq(state.modified_damage, 4,
			"modified damage should mirror confirm damage")
	assert_eq(state.redirect_zone, -1,
			"redirect_zone should reset")
	assert_false(state.contain_used,
			"contain flag should reset")


func test_build_defense_payload_contains_expected_keys() -> void:
	GameManager.start_new_game()
	var gs: GameState = GameManager.current_game_state
	var ps: PlayerState = gs.get_player_state(1)
	var ship: ShipInstance = _make_ship_instance(1)
	ship.current_speed = 2
	ps.ships.append(ship)

	var state: AttackState = AttackState.new()
	state.locked_tokens = [1]
	state.modified_damage = 3
	state.defender_zone = int(Constants.HullZone.FRONT)
	state.dice_results = [{
		"color": Constants.DiceColor.RED,
		"face": Constants.DiceFace.HIT,
	}]

	var payload: Dictionary = _executor.build_defense_payload(state, ship, gs)

	assert_eq(int(payload.get("defender_player", -1)), ship.owner_player,
			"payload should carry defender player")
	assert_eq(int(payload.get("defender_ship_index", -1)),
			gs.find_ship_index(ship),
			"payload should carry defender ship index")
	assert_eq(int(payload.get("defender_speed", -1)), 2,
			"payload should carry defender speed")
	assert_eq(int(payload.get("modified_damage", -1)), 3,
			"payload should carry modified damage")
	assert_eq((payload.get("locked_tokens", []) as Array).size(), 1,
			"payload should carry locked tokens")
	var dice_results: Array = payload.get("dice_results", []) as Array
	assert_eq(dice_results.size(), 1,
			"payload should carry final dice results")
	var first_die: Dictionary = dice_results[0] as Dictionary
	assert_eq(int(first_die.get("face", -1)), int(Constants.DiceFace.HIT),
			"payload should carry the final die face")


func test_sort_defense_tokens_canonical_orders_by_rrg_sequence() -> void:
	var defense_tokens: Array[Dictionary] = [
		{"type": int(Constants.DefenseToken.REDIRECT)},
		{"type": int(Constants.DefenseToken.SCATTER)},
		{"type": int(Constants.DefenseToken.BRACE)},
	]
	var selected: Array[int] = [0, 2, 1]
	var sorted: Array[int] = _executor.sort_defense_tokens_canonical(
			selected, defense_tokens)
	assert_eq(sorted, [1, 2, 0],
			"token indices should be sorted Scatter -> Brace -> Redirect")


func test_begin_defense_commit_with_empty_selection_clears_step() -> void:
	var state: AttackState = AttackState.new()
	state.defense_step = true
	state.defense_commit_queue = [3, 4]
	var selected: Array[int] = []

	var has_queue: bool = _executor.begin_defense_commit(state, selected)

	assert_false(has_queue,
			"empty selection should not start queue processing")
	assert_false(state.defense_step,
			"defense step should end on empty commit")
	assert_true(state.defense_commit_queue.is_empty(),
			"commit queue should be cleared")


func test_begin_defense_commit_with_selection_sets_queue() -> void:
	var state: AttackState = AttackState.new()
	state.defense_step = true
	var selected: Array[int] = [5, 1]

	var has_queue: bool = _executor.begin_defense_commit(state, selected)

	assert_true(has_queue,
			"non-empty selection should start queue processing")
	assert_eq(state.defense_commit_queue, [5, 1],
			"selected indices should be copied into commit queue")


func test_poll_next_defense_commit_empty_queue_ends_step() -> void:
	var state: AttackState = AttackState.new()
	state.defense_step = true

	var poll: Dictionary = _executor.poll_next_defense_commit(state)

	assert_false(bool(poll.get("has_token", true)),
			"empty queue should return has_token=false")
	assert_eq(int(poll.get("token_index", 0)), -1,
			"empty queue should return token index -1")
	assert_false(state.defense_step,
			"empty queue should end defense step")


func test_poll_next_defense_commit_pops_first_token() -> void:
	var state: AttackState = AttackState.new()
	state.defense_step = true
	state.defense_commit_queue = [6, 2]

	var poll: Dictionary = _executor.poll_next_defense_commit(state)

	assert_true(bool(poll.get("has_token", false)),
			"non-empty queue should return has_token=true")
	assert_eq(int(poll.get("token_index", -1)), 6,
			"poll should return first queued index")
	assert_eq(state.defense_commit_queue, [2],
			"poll should remove the returned index")


func test_count_faceup_cards_counts_true_flags_only() -> void:
	var card_data: Array = [
		{"is_faceup": true},
		{"is_faceup": false},
		{"id": "missing_flag"},
		{"is_faceup": true},
	]
	var count: int = _executor.count_faceup_cards(card_data)
	assert_eq(count, 2,
			"count_faceup_cards should count only true is_faceup flags")


func test_determine_first_card_faceup_true_for_critical_without_contain() -> void:
	var state: AttackState = AttackState.new()
	state.contain_used = false
	state.dice_results = [
		{
			"color": Constants.DiceColor.RED,
			"face": Constants.DiceFace.CRITICAL,
		}
	]
	var resolver: DefenseTokenResolver = DefenseTokenResolver.new()
	var first_faceup: bool = _executor.determine_first_card_faceup(
			state, resolver, null)
	assert_true(first_faceup,
			"critical result without contain should set first card faceup")


func test_determine_first_card_faceup_false_when_contain_used() -> void:
	var state: AttackState = AttackState.new()
	state.contain_used = true
	state.dice_results = [
		{
			"color": Constants.DiceColor.RED,
			"face": Constants.DiceFace.CRITICAL,
		}
	]
	var resolver: DefenseTokenResolver = DefenseTokenResolver.new()
	var first_faceup: bool = _executor.determine_first_card_faceup(
			state, resolver, null)
	assert_false(first_faceup,
			"contain should prevent first card from being faceup")


func test_build_damage_summary_uses_damage_dealer_format() -> void:
	var dealer: DamageDealer = DamageDealer.new()
	var ship: ShipInstance = _make_ship_instance(1)
	ship.facedown_damage.append(DamageCard.new())
	var summary: String = _executor.build_damage_summary(
			dealer, ship, "FRONT", 2, 1, "Structural Damage")
	assert_true(summary.find("FRONT: 2 shield, 1 card(s)") >= 0,
			"summary should include zone and shield/card values")
	assert_true(summary.find("CRIT: Structural Damage") >= 0,
			"summary should include faceup crit card text")


func test_can_continue_redirect_true_with_remaining_and_adjacent_shields() -> void:
	var state: AttackState = AttackState.new()
	state.defender_zone = int(Constants.HullZone.FRONT)
	state.redirect_remaining = 1
	var ship: ShipInstance = _make_ship_instance(1)
	var resolver: DefenseTokenResolver = DefenseTokenResolver.new()
	var can_continue: bool = _executor.can_continue_redirect(
			state, ship, resolver)
	assert_true(can_continue,
			"redirect should continue with remaining budget and adjacent shields")


func test_can_continue_redirect_false_when_no_budget() -> void:
	var state: AttackState = AttackState.new()
	state.defender_zone = int(Constants.HullZone.FRONT)
	state.redirect_remaining = 0
	var ship: ShipInstance = _make_ship_instance(1)
	var resolver: DefenseTokenResolver = DefenseTokenResolver.new()
	var can_continue: bool = _executor.can_continue_redirect(
			state, ship, resolver)
	assert_false(can_continue,
			"redirect should stop when remaining budget is zero")


func test_prepare_faceup_card_returns_registration_and_immediate_flags() -> void:
	var card: DamageCard = DamageCard.new()
	card.title = "Structural Damage"
	card.timing = "immediate"
	card.effect_id = "structural_damage"
	var dealer: DamageDealer = DamageDealer.new()
	var result: Dictionary = _executor.prepare_faceup_card(card, dealer)
	assert_true(result.has("should_register_persistent"),
			"result should have should_register_persistent key")
	assert_true(result.has("has_immediate"),
			"result should have has_immediate key")
	assert_eq(result.get("card_title", ""), "Structural Damage",
			"result should include card title")


func test_prepare_faceup_card_identifies_immediate_effects() -> void:
	var card: DamageCard = DamageCard.new()
	card.title = "Injured Crew"
	card.timing = "immediate"
	card.effect_id = "injured_crew"
	var dealer: DamageDealer = DamageDealer.new()
	var result: Dictionary = _executor.prepare_faceup_card(card, dealer)
	assert_true(bool(result.get("has_immediate", false)),
			"Injured Crew should be marked as immediate")


func test_decide_immediate_effect_flow_returns_decision_structure() -> void:
	var card: DamageCard = DamageCard.new()
	card.title = "Structural Damage"
	card.timing = "immediate"
	card.effect_id = "structural_damage"
	var ship: ShipInstance = _make_ship_instance(0)
	var resolver: ImmediateEffectResolver = ImmediateEffectResolver.new()
	var result: Dictionary = _executor.decide_immediate_effect_flow(
			card, ship, resolver)
	assert_true(result.has("should_process"),
			"result should have should_process key")
	assert_true(result.has("should_defer"),
			"result should have should_defer key")
	assert_true(result.has("choice_info"),
			"result should have choice_info key")
	assert_true(result.has("card_id"),
			"result should have card_id key")


func test_decide_immediate_effect_flow_marks_auto_resolve_cards() -> void:
	var card: DamageCard = DamageCard.new()
	card.title = "Structural Damage"
	card.timing = "immediate"
	card.effect_id = "structural_damage"
	var ship: ShipInstance = _make_ship_instance(0)
	var resolver: ImmediateEffectResolver = ImmediateEffectResolver.new()
	var result: Dictionary = _executor.decide_immediate_effect_flow(
			card, ship, resolver)
	assert_true(bool(result.get("should_process", false)),
			"should_process should be true for immediate card")
	assert_false(bool(result.get("should_defer", true)),
			"should_defer should be false for auto-resolve card")
	assert_true((result.get("choice_info", null) as Dictionary).is_empty(),
			"choice_info should be empty for auto-resolve")


func test_decide_immediate_effect_flow_skips_non_immediate_cards() -> void:
	var card: DamageCard = DamageCard.new()
	card.title = "Deck Failure"
	card.timing = "persistent"
	card.effect_id = "deck_failure"
	var ship: ShipInstance = _make_ship_instance(0)
	var resolver: ImmediateEffectResolver = ImmediateEffectResolver.new()
	var result: Dictionary = _executor.decide_immediate_effect_flow(
			card, ship, resolver)
	assert_false(bool(result.get("should_process", true)),
			"should_process should be false for non-immediate card")


func _make_ship_instance(owner_player: int) -> ShipInstance:
	var data: ShipData = ShipData.new()
	data.ship_name = "Test Ship"
	data.hull = 5
	data.max_speed = 2
	data.engineering_value = 3
	data.command_value = 2
	data.shields = {"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1}
	data.defense_tokens = []
	data.navigation_chart = [[1], [0, 1]]
	data.ship_size = Constants.ShipSize.SMALL
	data.faction = Constants.Faction.REBEL_ALLIANCE
	return ShipInstance.create_from_data("test_ship", data, owner_player, 0)


func _make_squadron_instance(owner_player: int) -> SquadronInstance:
	var data: SquadronData = SquadronData.new()
	data.squadron_name = "Test Squadron"
	data.faction = Constants.Faction.GALACTIC_EMPIRE
	data.hull = 3
	data.speed = 3
	data.defense_tokens = []
	data.keywords = []
	return SquadronInstance.create_from_data("test_squad", data, owner_player)


func _make_ship_token(inst: ShipInstance) -> ShipToken:
	var scene: PackedScene = preload("res://src/scenes/tokens/ship_token.tscn")
	var token: ShipToken = scene.instantiate() as ShipToken
	add_child_autofree(token)
	token.bind_instance(inst)
	return token


func _make_squadron_token(inst: SquadronInstance) -> SquadronToken:
	var scene: PackedScene = preload("res://src/scenes/tokens/squadron_token.tscn")
	var token: SquadronToken = scene.instantiate() as SquadronToken
	add_child_autofree(token)
	token.bind_instance(inst)
	return token
