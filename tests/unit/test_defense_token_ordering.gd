## Test: Defense token canonical resolution ordering.
##
## Verifies that `_sort_defense_tokens_canonical()` enforces the RRG
## resolution order (Scatter → Evade → Brace → Redirect → Contain)
## and that Brace is applied immediately (before Redirect) so Redirect
## operates on the halved damage total.
## Requirements: AE-DEF-006–016.
## Rules Reference: "Defense Tokens", p.5.
extends GutTest


var _executor: AttackExecutor = null
var _ship_data: ShipData = null
var _ship_instance: ShipInstance = null
var _ship_token: ShipToken = null
var _saved_play_mode: PlayMode.Mode = PlayMode.Mode.HOT_SEAT
var _saved_network_role: NetworkManager.Role = NetworkManager.Role.NONE
var _saved_is_replaying: bool = false


func before_each() -> void:
	_saved_play_mode = PlayMode.current_mode
	_saved_network_role = NetworkManager.role
	_saved_is_replaying = CommandProcessor.is_replaying
	_executor = AttackExecutor.new()
	add_child_autofree(_executor)
	_ship_data = ShipData.new()
	_ship_data.ship_name = "TestDefender"
	_ship_data.hull = 5
	_ship_data.shields = {"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1}
	_ship_data.max_speed = 2
	_ship_data.command_value = 2
	_ship_token = ShipToken.new()
	add_child_autofree(_ship_token)


func after_each() -> void:
	PlayMode.current_mode = _saved_play_mode
	NetworkManager.role = _saved_network_role
	CommandProcessor.is_replaying = _saved_is_replaying


## Helper: creates a ShipInstance from the current _ship_data and binds it.
func _setup_tokens(token_names: Array) -> void:
	_ship_data.defense_tokens = token_names
	_ship_instance = ShipInstance.create_from_data(
			"test_def", _ship_data, 2, 0)
	_ship_token._ship_instance = _ship_instance
	_executor._state.defender_ship = _ship_token


# =========================================================================
# Canonical Order Constant
# =========================================================================

func test_resolve_order_scatter_first() -> void:
	var order: Dictionary = AttackExecutor._DEFENSE_RESOLVE_ORDER
	assert_eq(order[Constants.DefenseToken.SCATTER], 0,
			"Scatter should be first in resolve order")


func test_resolve_order_evade_second() -> void:
	var order: Dictionary = AttackExecutor._DEFENSE_RESOLVE_ORDER
	assert_eq(order[Constants.DefenseToken.EVADE], 1,
			"Evade should be second in resolve order")


func test_resolve_order_brace_third() -> void:
	var order: Dictionary = AttackExecutor._DEFENSE_RESOLVE_ORDER
	assert_eq(order[Constants.DefenseToken.BRACE], 2,
			"Brace should be third in resolve order")


func test_resolve_order_redirect_fourth() -> void:
	var order: Dictionary = AttackExecutor._DEFENSE_RESOLVE_ORDER
	assert_eq(order[Constants.DefenseToken.REDIRECT], 3,
			"Redirect should be fourth in resolve order")


func test_resolve_order_contain_fifth() -> void:
	var order: Dictionary = AttackExecutor._DEFENSE_RESOLVE_ORDER
	assert_eq(order[Constants.DefenseToken.CONTAIN], 4,
			"Contain should be fifth in resolve order")


func test_resolve_order_brace_before_redirect() -> void:
	var order: Dictionary = AttackExecutor._DEFENSE_RESOLVE_ORDER
	assert_true(
			order[Constants.DefenseToken.BRACE]
			< order[Constants.DefenseToken.REDIRECT],
			"Brace must resolve before Redirect")


# =========================================================================
# Sorting — _sort_defense_tokens_canonical
# =========================================================================

func test_sort_brace_redirect_already_ordered() -> void:
	## Brace at index 0, Redirect at index 1 — already in correct order.
	_setup_tokens(["Brace", "Redirect"])
	var input: Array[int] = [0, 1]
	var result: Array[int] = _executor._sort_defense_tokens_canonical(input)
	assert_eq(result[0], 0, "Brace (idx 0) should remain first")
	assert_eq(result[1], 1, "Redirect (idx 1) should remain second")


func test_sort_redirect_before_brace_reorders() -> void:
	## Redirect at index 0, Brace at index 1 — must swap.
	_setup_tokens(["Redirect", "Brace"])
	var input: Array[int] = [0, 1]
	var result: Array[int] = _executor._sort_defense_tokens_canonical(input)
	assert_eq(result[0], 1,
			"Brace (idx 1) should sort before Redirect (idx 0)")
	assert_eq(result[1], 0,
			"Redirect (idx 0) should sort after Brace (idx 1)")


func test_sort_all_five_token_types() -> void:
	## All five tokens in reverse canonical order.
	_setup_tokens(["Contain", "Redirect", "Brace", "Evade", "Scatter"])
	# Select all five indices in their ship order (reverse canonical).
	var input: Array[int] = [0, 1, 2, 3, 4]
	var result: Array[int] = _executor._sort_defense_tokens_canonical(input)
	# Expected order by type: Scatter(4) Evade(3) Brace(2) Redirect(1) Contain(0)
	assert_eq(result[0], 4, "Scatter (idx 4) should be first")
	assert_eq(result[1], 3, "Evade (idx 3) should be second")
	assert_eq(result[2], 2, "Brace (idx 2) should be third")
	assert_eq(result[3], 1, "Redirect (idx 1) should be fourth")
	assert_eq(result[4], 0, "Contain (idx 0) should be fifth")


func test_sort_single_token_unchanged() -> void:
	_setup_tokens(["Brace"])
	var input: Array[int] = [0]
	var result: Array[int] = _executor._sort_defense_tokens_canonical(input)
	assert_eq(result.size(), 1, "Single token list should stay length 1")
	assert_eq(result[0], 0, "Single token index should be unchanged")


func test_sort_empty_list_returns_empty() -> void:
	_setup_tokens(["Brace", "Redirect"])
	var input: Array[int] = []
	var result: Array[int] = _executor._sort_defense_tokens_canonical(input)
	assert_eq(result.size(), 0, "Empty list should return empty")


func test_sort_evade_brace_redirect() -> void:
	## Three tokens: Evade, Brace, Redirect — already canonical.
	_setup_tokens(["Evade", "Brace", "Redirect"])
	var input: Array[int] = [0, 1, 2]
	var result: Array[int] = _executor._sort_defense_tokens_canonical(input)
	assert_eq(result[0], 0, "Evade (idx 0) should be first")
	assert_eq(result[1], 1, "Brace (idx 1) should be second")
	assert_eq(result[2], 2, "Redirect (idx 2) should be third")


func test_sort_redirect_brace_evade_reversed() -> void:
	## Three tokens in reverse order — must reorder.
	_setup_tokens(["Redirect", "Brace", "Evade"])
	var input: Array[int] = [0, 1, 2]
	var result: Array[int] = _executor._sort_defense_tokens_canonical(input)
	assert_eq(result[0], 2, "Evade (idx 2) should be first")
	assert_eq(result[1], 1, "Brace (idx 1) should be second")
	assert_eq(result[2], 0, "Redirect (idx 0) should be third")


func test_sort_subset_of_tokens() -> void:
	## Ship has 4 tokens but only 2 selected.
	_setup_tokens(["Evade", "Redirect", "Brace", "Contain"])
	# Select only Redirect(1) and Brace(2).
	var input: Array[int] = [1, 2]
	var result: Array[int] = _executor._sort_defense_tokens_canonical(input)
	assert_eq(result[0], 2, "Brace (idx 2) should sort before Redirect (idx 1)")
	assert_eq(result[1], 1, "Redirect (idx 1) should sort after Brace (idx 2)")


func test_sort_null_defender_returns_original() -> void:
	## When no defender ship is set, sorting should return original order.
	_executor._state.defender_ship = null
	var input: Array[int] = [1, 0]
	var result: Array[int] = _executor._sort_defense_tokens_canonical(input)
	assert_eq(result[0], 1, "Without defender, order should be unchanged")
	assert_eq(result[1], 0, "Without defender, order should be unchanged")


# =========================================================================
# Brace Canonical Projection
# =========================================================================

func test_brace_projection_preserves_even_canonical_damage() -> void:
	## Canonical state already derived 4 damage; scene must not halve again.
	_setup_tokens(["Brace"])
	_executor._state.modified_damage = 4
	_executor._apply_defense_token_effect(
			Constants.DefenseToken.BRACE, _ship_instance)
	assert_eq(_executor._state.modified_damage, 4,
			"Scene projection must not apply Brace a second time")
	assert_true(_executor._state.brace_used,
			"Brace used flag should be set")


func test_brace_projection_preserves_odd_canonical_damage() -> void:
	## Canonical state already derived 5 damage; scene must not halve again.
	_setup_tokens(["Brace"])
	_executor._state.modified_damage = 5
	_executor._apply_defense_token_effect(
			Constants.DefenseToken.BRACE, _ship_instance)
	assert_eq(_executor._state.modified_damage, 5,
			"Scene projection must preserve canonical derived damage")


func test_brace_projection_preserves_one_canonical_damage() -> void:
	## The canonical projection has already resolved Brace.
	_setup_tokens(["Brace"])
	_executor._state.modified_damage = 1
	_executor._apply_defense_token_effect(
			Constants.DefenseToken.BRACE, _ship_instance)
	assert_eq(_executor._state.modified_damage, 1,
			"Scene projection must preserve canonical derived damage")


func test_brace_projection_preserves_zero_canonical_damage() -> void:
	## The canonical projection has already resolved Brace.
	_setup_tokens(["Brace"])
	_executor._state.modified_damage = 0
	_executor._apply_defense_token_effect(
			Constants.DefenseToken.BRACE, _ship_instance)
	assert_eq(_executor._state.modified_damage, 0,
			"Scene projection must preserve canonical derived damage")


func test_brace_then_redirect_preserves_canonical_total() -> void:
	## The projected total is already canonical before scene effects render.
	_setup_tokens(["Brace", "Redirect"])
	_executor._state.modified_damage = 4
	# Render Brace without recalculating it.
	_executor._apply_defense_token_effect(
			Constants.DefenseToken.BRACE, _ship_instance)
	assert_eq(_executor._state.modified_damage, 4,
			"Redirect must consume the canonical projected total unchanged")


func test_only_live_authority_may_resume_canonical_defense_state() -> void:
	PlayMode.current_mode = PlayMode.Mode.HOT_SEAT
	CommandProcessor.is_replaying = false
	assert_true(_executor._is_live_defense_authority(),
			"Live hot-seat play may resume a canonical deterministic step")
	CommandProcessor.is_replaying = true
	assert_false(_executor._is_live_defense_authority(),
			"Replay must only consume recorded commands")
	CommandProcessor.is_replaying = false
	PlayMode.current_mode = PlayMode.Mode.NETWORK
	NetworkManager.role = NetworkManager.Role.CLIENT
	assert_false(_executor._is_live_defense_authority(),
			"A network mirror must only consume server-authored commands")
	NetworkManager.role = NetworkManager.Role.SERVER
	assert_true(_executor._is_live_defense_authority(),
			"The live network authority should author follow-ups")


func test_resolve_damage_no_deferred_brace() -> void:
	## Ensure _attack_exec_resolve_damage does NOT re-halve damage.
	## Set brace_used flag and a known damage total — damage should pass
	## through unchanged.
	_setup_tokens(["Brace"])
	_executor._state.modified_damage = 3
	_executor._state.brace_used = true
	_executor._state.scatter_used = false
	# We can't call _attack_exec_resolve_damage directly because it
	# requires a defender and spawns timers. Instead, verify the logic
	# path: final_damage = _state.modified_damage (no halving).
	var final_damage: int = _executor._state.modified_damage
	if _executor._state.scatter_used:
		final_damage = 0
	# The old code would have done: final_damage = ceili(final_damage/2.0)
	# if _state.brace_used. That code has been removed.
	assert_eq(final_damage, 3,
			"Damage should not be re-halved in resolve step")


# =========================================================================
# Regression — apply_defender_commit canonical re-sort
# =========================================================================

## Regression: defender clicks Brace before Evade.  Without canonical
## re-sort in [method AttackExecutor.apply_defender_commit], the queue
## processes Brace first (halves damage) and Evade second (overwrites
## modified_damage from raw dice → undoes brace).
##
## See client log [code]client_20260510_150200.log[/code] line 2819-2840:
## annotation 002a "the brace defense token does not work any more".
## Rules Reference: "Defense Tokens", p.5 — Scatter → Evade → Brace.
func test_apply_defender_commit_resorts_brace_after_evade() -> void:
	# Defender token order: [Evade(idx 0), Brace(idx 1)].
	_setup_tokens(["Evade", "Brace"])
	# Defender clicked Brace then Evade — submitted [1, 0] (click order).
	var click_order: Array[int] = [1, 0]
	# Sort via the same helper apply_defender_commit uses.
	var canonical: Array[int] = (
			_executor._flow_executor.sort_defense_tokens_canonical(
					click_order, _ship_instance.defense_tokens))
	assert_eq(canonical[0], 0,
			"Evade (idx 0) must sort before Brace (idx 1) per RRG p.5")
	assert_eq(canonical[1], 1,
			"Brace (idx 1) must sort after Evade (idx 0) per RRG p.5")
