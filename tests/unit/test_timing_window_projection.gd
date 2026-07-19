## Focused Slice 6 projection and live-route tests with shared fixtures.
extends GutTest


const DEFINITIONS: GDScript = preload(
		"res://src/core/timing_windows/timing_window_definitions.gd")
const ORCHESTRATOR: GDScript = preload(
		"res://src/core/timing_windows/timing_window_orchestrator.gd")
const COMMANDS: GDScript = preload(
		"res://tests/fixtures/timing_window_command_fixtures.gd")
const PARTICIPANT: GDScript = preload(
		"res://tests/fixtures/timing_window_participant_fixture.gd")


class RecordingSubmitter:
	extends CommandSubmitter

	var submitted_commands: Array[GameCommand] = []

	func submit(command: GameCommand) -> Dictionary:
		submitted_commands.append(command)
		return {"submitted": true}


var _saved_registry: Dictionary = {}
var _saved_state: GameState = null
var _saved_submitter: CommandSubmitter = null
var _saved_active_player: int = -1
var _saved_local_player: int = -1
var _state: GameState = null
var _submitter: RecordingSubmitter = null


func before_each() -> void:
	_saved_registry = GameCommand._registry.duplicate()
	_saved_state = GameManager.current_game_state
	_saved_submitter = GameManager.get_command_submitter()
	_saved_active_player = GameManager.active_player
	_saved_local_player = NetworkManager._local_player_index
	RuleRegistry.clear()
	COMMANDS.register()
	assert_true(COMMANDS.register_participant())
	_state = _make_active_state([
		"public-a",
		"public-b",
	], [
		"hidden-source",
		"owner-source",
	])
	GameManager.current_game_state = _state
	GameManager.active_player = 0
	NetworkManager._local_player_index = -1
	_submitter = RecordingSubmitter.new()
	GameManager.set_command_submitter(_submitter)


func after_each() -> void:
	RuleRegistry.clear()
	GameCommand._registry = _saved_registry
	GameManager.current_game_state = _saved_state
	GameManager.set_command_submitter(_saved_submitter)
	GameManager.active_player = _saved_active_player
	NetworkManager._local_player_index = _saved_local_player


func test_controller_projection_contains_all_choices_and_intents() -> void:
	var intent: UIProjector.UIIntent = UIProjector.project(_state, 0)
	var projected: Array = intent.timing_window.get("opportunities", [])

	assert_eq(projected.size(), 4,
			"Controller should receive every current selectable opportunity.")
	assert_true(bool(intent.timing_window.get("is_interactive", false)))
	for opportunity: Dictionary in projected:
		assert_true(bool(opportunity.get("is_interactive", false)))
		assert_true(opportunity.has("use_intent"))
		assert_true(opportunity.has("decline_intent"))


func test_observer_projection_filters_owner_only_and_redacts_hidden_source() -> void:
	var intent: UIProjector.UIIntent = UIProjector.project(_state, 1)
	var projected: Array = intent.timing_window.get("opportunities", [])

	assert_eq(projected.size(), 3,
			"Observer should see two public choices and one redacted choice.")
	assert_false(bool(intent.timing_window.get("is_interactive", true)))
	assert_false(_has_runtime_source(projected, "owner-source"),
			"Owner-only source must be absent for the other player.")
	assert_false(_has_runtime_source(projected, "hidden-source"),
			"Hidden source identity must not leak to the other player.")
	var redacted_count: int = 0
	for opportunity: Dictionary in projected:
		assert_false(bool(opportunity.get("is_interactive", true)))
		assert_false(opportunity.has("use_intent"),
				"Observer projection must not carry actionable command payloads.")
		assert_false(opportunity.has("decline_intent"))
		if not opportunity.has("opportunity_id"):
			redacted_count += 1
	assert_eq(redacted_count, 1,
			"Exactly the hidden-source opportunity should be redacted.")


func test_projection_order_is_stable_without_selecting_an_opportunity() -> void:
	var first: Dictionary = UIProjector.project(_state, 0).timing_window
	var second: Dictionary = UIProjector.project(_state, 0).timing_window

	assert_eq(first, second,
			"Fresh derivation from unchanged state should project identically.")
	assert_false(first.has("selected_opportunity"),
			"Projection must never choose for the player.")
	assert_eq(_state.objectives.get(PARTICIPANT.RESOLVED_KEY), {},
			"Projection must not mutate rule-owned fixture state.")


func test_live_route_dispatches_exact_projected_use_and_decline_commands() -> void:
	var adapter: CommandRouterAdapter = CommandRouterAdapter.new()
	add_child_autofree(adapter)
	var opportunities: Array = UIProjector.project(
			_state, 0).timing_window.get("opportunities", [])
	var use_intent: Dictionary = (opportunities[0] as Dictionary).get(
			"use_intent", {})
	var decline_intent: Dictionary = (opportunities[1] as Dictionary).get(
			"decline_intent", {})

	assert_eq(adapter.submit_timing_window_intent(use_intent),
			{"submitted": true})
	assert_eq(adapter.submit_timing_window_intent(decline_intent),
			{"submitted": true})
	assert_eq(_submitter.submitted_commands.size(), 2)
	assert_eq(_submitter.submitted_commands[0].serialize(), {
		"type": use_intent["command_type"],
		"player": use_intent["player_index"],
		"sequence": -1,
		"payload": use_intent["payload"],
	})
	assert_eq(_submitter.submitted_commands[1].serialize(), {
		"type": decline_intent["command_type"],
		"player": decline_intent["player_index"],
		"sequence": -1,
		"payload": decline_intent["payload"],
	})


func test_composed_live_panel_renders_selects_dispatches_and_clears_stale() -> void:
	var composition: Dictionary = _make_live_route()
	var adapter: CommandRouterAdapter = composition.get("adapter")
	var panel: AttackSimPanel = composition.get("primary_panel")
	var router: Node = adapter._modal_router

	router.route_command_result(null, {})
	assert_eq(panel.timing_window_choice_count(), 4,
			"The real attacker panel must render every projected choice.")
	var use_button: Button = panel.find_child(
			"TimingUseButton_0", true, false) as Button
	assert_not_null(use_button)
	use_button.pressed.emit()
	assert_eq(_submitter.submitted_commands.size(), 1,
			"Panel selection must dispatch through CommandRouterAdapter.")
	assert_true(use_button.disabled,
			"Submitted controls must disable while authority is pending.")

	router.route_command_result(null, {})
	var decline_button: Button = panel.find_child(
			"TimingDeclineButton_1", true, false) as Button
	assert_not_null(decline_button)
	decline_button.pressed.emit()
	assert_eq(_submitter.submitted_commands.size(), 2)
	assert_eq(_submitter.submitted_commands[1].command_type,
			COMMANDS.DECLINE_TYPE)

	assert_true(bool(ORCHESTRATOR.cancel_window(
			_state, _state.timing_window_state.lifecycle_id).get(
					ORCHESTRATOR.KEY_OK, false)))
	router.route_command_result(null, {})
	assert_eq(panel.timing_window_choice_count(), 0,
			"A stale lifecycle projection must remove the controls.")
	await get_tree().process_frame


func test_composed_observer_panel_is_visible_but_never_actionable() -> void:
	NetworkManager._local_player_index = 1
	var composition: Dictionary = _make_live_route()
	var adapter: CommandRouterAdapter = composition.get("adapter")
	var mirror_panel: AttackSimPanel = composition.get("mirror_panel")

	adapter._modal_router.route_command_result(null, {})

	assert_eq(mirror_panel.timing_window_choice_count(), 3)
	assert_null(mirror_panel.find_child("TimingUseButton_0", true, false))
	assert_null(mirror_panel.find_child("TimingDeclineButton_0", true, false))
	assert_eq(_submitter.submitted_commands.size(), 0)


func test_live_route_cannot_submit_continuation() -> void:
	var adapter: CommandRouterAdapter = CommandRouterAdapter.new()
	add_child_autofree(adapter)
	var continuation_intent: Dictionary = {
		"command_type": COMMANDS.CONTINUATION_TYPE,
		"player_index": 0,
		"payload": {
			"lifecycle_id": _state.timing_window_state.lifecycle_id,
			"source_owner_kind": PARTICIPANT.SOURCE_OWNER_KIND,
			"runtime_source_id": "public-a",
			"semantic_key": PARTICIPANT.SEMANTIC_KEY,
		},
	}

	assert_eq(adapter.submit_timing_window_intent(continuation_intent), {})
	assert_eq(_submitter.submitted_commands.size(), 0,
			"Continuation remains orchestrator-owned, never UI-submitted.")


func test_modal_teardown_cannot_clear_authoritative_lifecycle() -> void:
	var lifecycle_before: String = _state.timing_window_state.lifecycle_id
	var projected: UIProjector.UIIntent = UIProjector.project(_state, 0)
	projected = null

	assert_true(_state.timing_window_state.active)
	assert_eq(_state.timing_window_state.lifecycle_id, lifecycle_before)


func test_reconstruction_rebuilds_projection_without_ui_memory() -> void:
	var expected_owner: Dictionary = UIProjector.project(
			_state, 0).timing_window
	var expected_observer: Dictionary = UIProjector.project(
			_state, 1).timing_window
	var restored: GameState = GameState.deserialize(_state.serialize())

	assert_not_null(restored)
	assert_eq(UIProjector.project(restored, 0).timing_window, expected_owner)
	assert_eq(UIProjector.project(restored, 1).timing_window, expected_observer)


func _make_active_state(public_source_ids: Array[String],
		private_source_ids: Array[String] = []) -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SHIP
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			0,
			Constants.Visibility.OWNER,
			{
				"attacker_player": 0,
				PARTICIPANT.PRIVATE_SOURCES_KEY:
						private_source_ids.duplicate(),
				PARTICIPANT.VISIBILITY_KEY: {
					"hidden-source": PARTICIPANT.VISIBILITY_HIDDEN_SOURCE,
					"owner-source": PARTICIPANT.VISIBILITY_OWNER_ONLY,
				},
			})
	state.objectives[PARTICIPANT.SOURCES_KEY] = public_source_ids.duplicate()
	state.objectives[PARTICIPANT.RESOLVED_KEY] = {}
	var opened: Dictionary = ORCHESTRATOR.open_window(
			state,
			DEFINITIONS.ATTACK_MODIFY,
			7,
			{
				TimingWindowState.CONTINUATION_KEY_ID:
						COMMANDS.CONTINUATION_TYPE,
				TimingWindowState.CONTINUATION_KEY_RESUME_POINT:
						"attack_after_modify",
				TimingWindowState.CONTINUATION_KEY_SOURCE_ID:
						"fixture-attack",
				TimingWindowState.CONTINUATION_KEY_SOURCE_TYPE:
						"current_attack",
				TimingWindowState.CONTINUATION_KEY_OWNER_PLAYER: 0,
			})
	assert_true(bool(opened.get(ORCHESTRATOR.KEY_OK, false)))
	return state


func _make_live_route() -> Dictionary:
	var panel_manager: UIPanelManager = UIPanelManager.new()
	add_child_autofree(panel_manager)
	var mirror_layer: CanvasLayer = CanvasLayer.new()
	panel_manager.add_child(mirror_layer)
	panel_manager.attack_panel_mirror = AttackPanelMirror.new()
	panel_manager.attack_panel_mirror.setup(mirror_layer)

	var target_selector: TargetSelector = TargetSelector.new()
	add_child_autofree(target_selector)
	target_selector.enter_attacker_selection(true, "Fixture attacker")

	var attack_controller: AttackPanelController = AttackPanelController.new()
	add_child_autofree(attack_controller)
	attack_controller.initialize(null, panel_manager, target_selector)

	var adapter: CommandRouterAdapter = CommandRouterAdapter.new()
	add_child_autofree(adapter)
	adapter.initialize(
			panel_manager,
			attack_controller,
			null,
			null,
			null,
			null,
			Callable(),
			Callable())
	return {
		"adapter": adapter,
		"primary_panel": target_selector.get_panel(),
		"mirror_panel": panel_manager.attack_panel_mirror.get_panel(),
	}


func _has_runtime_source(opportunities: Array, source_id: String) -> bool:
	for opportunity: Dictionary in opportunities:
		if str(opportunity.get("runtime_source_id", "")) == source_id:
			return true
	return false
