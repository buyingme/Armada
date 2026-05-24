## Test: CrewPanic RuleRegistry integration
##
## Verifies Crew Panic projects a pre-reveal choice from serialized ship state
## without transient runtime effect objects.
extends GutTest


const TEST_SHIP_KEY: String = "cr90_corvette_a"


func before_each() -> void:
	RuleRegistry.clear()
	CrewPanic.register()


func after_each() -> void:
	RuleRegistry.clear()


func test_register_adds_pre_reveal_enabler_expected() -> void:
	var hooks: Array[FlowHook] = RuleRegistry.enablers_for(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT,
			CrewPanic.TARGET_COMMAND_DIAL_REVEAL)
	var step_hooks: Array[FlowHook] = RuleRegistry.enablers_for_step(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT)
	assert_eq(hooks.size(), 1,
			"Crew Panic should register one pre-reveal enabler.")
	assert_true(step_hooks.has(hooks[0]),
			"Step-wide enabler lookup should include Crew Panic.")


func test_project_active_ship_exposes_choice_affordance() -> void:
	var state: GameState = _make_ship_activation_state(0)
	var ship: ShipInstance = _add_ship(state, 0, true)
	_add_crew_panic(ship)
	var choice_info: Dictionary = _project_choice_info(state, 0)
	var options: Array = choice_info.get("options", [])
	assert_eq(choice_info.get("card_title", ""), "Crew Panic",
			"Projected choice should identify the damage card.")
	assert_eq(options.size(), 2,
			"Crew Panic should expose discard and damage options.")
	assert_eq((options[0] as Dictionary).get("id", ""),
			CrewPanic.OPTION_DISCARD_DIAL,
			"First option should discard the command dial.")
	assert_eq((options[1] as Dictionary).get("id", ""),
			CrewPanic.OPTION_SUFFER_DAMAGE,
			"Second option should suffer damage.")


func test_project_ship_without_card_has_no_affordance() -> void:
	var state: GameState = _make_ship_activation_state(0)
	_add_ship(state, 0, true)
	assert_true(_project_choices(state, 0).is_empty(),
			"Ships without Crew Panic should reveal normally.")


func test_project_opponent_card_has_no_affordance_for_controller() -> void:
	var state: GameState = _make_ship_activation_state(0)
	var opponent_ship: ShipInstance = _add_ship(state, 1, true)
	_add_crew_panic(opponent_ship)
	assert_true(_project_choices(state, 0).is_empty(),
			"Only the current controller's ships should get choices.")


func test_project_requires_hidden_dial() -> void:
	var state: GameState = _make_ship_activation_state(0)
	var ship: ShipInstance = _add_ship(state, 0, false)
	_add_crew_panic(ship)
	assert_true(_project_choices(state, 0).is_empty(),
			"Crew Panic should not project after all dials are gone.")


func test_project_passive_viewer_has_no_affordance() -> void:
	var state: GameState = _make_ship_activation_state(0)
	var ship: ShipInstance = _add_ship(state, 0, true)
	_add_crew_panic(ship)
	assert_true(_project_choices(state, 1).is_empty(),
			"Passive viewers should not control Crew Panic choices.")


func test_save_load_rebuild_has_no_legacy_effect_but_projects_rule() -> void:
	var state: GameState = _make_ship_activation_state(0)
	var ship: ShipInstance = _add_ship(state, 0, true)
	_add_crew_panic(ship)
	var loaded: GameState = GameState.deserialize(state.serialize())
	assert_false(_project_choice_info(loaded, 0).is_empty(),
			"RuleRegistry should still project from loaded faceup damage.")


func _make_ship_activation_state(controller: int) -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT,
			controller,
			Constants.Visibility.ALL,
			{})
	return state


func _add_ship(state: GameState,
		owner_player: int,
		assign_hidden_dial: bool) -> ShipInstance:
	var ship_data: ShipData = AssetLoader.load_ship_data(TEST_SHIP_KEY)
	assert_not_null(ship_data,
			"Crew Panic fixture requires CR90 ship data.")
	var ship: ShipInstance = ShipInstance.create_from_data(
			TEST_SHIP_KEY, ship_data, 2, owner_player)
	if assign_hidden_dial:
		ship.command_dial_stack.assign_dials(
				[Constants.CommandType.NAVIGATE], 1)
	state.get_player_state(owner_player).ships.append(ship)
	return ship


func _add_crew_panic(ship: ShipInstance) -> void:
	var card: DamageCard = DamageCard.create("Crew", "Crew Panic")
	card.effect_id = CrewPanic.EFFECT_ID
	card.effect_text = "Before you reveal a command dial, you must either " \
			+"suffer 1 damage or discard that dial. If you discard it, " \
			+"do not reveal a dial this round."
	card.timing = "persistent"
	card.is_faceup = true
	ship.add_faceup_damage(card)


func _project_choice_info(state: GameState,
		viewer_player: int) -> Dictionary:
	var choices: Array = _project_choices(state, viewer_player)
	if choices.is_empty():
		return {}
	return (choices[0] as Dictionary).get("choice_info", {}) as Dictionary


func _project_choices(state: GameState,
		viewer_player: int) -> Array:
	var intent: UIProjector.UIIntent = UIProjector.project(state, viewer_player)
	var payload: Dictionary = intent.affordances.get(
			CrewPanic.AFFORDANCE_KEY, {}) as Dictionary
	return payload.get("ships", []) as Array
