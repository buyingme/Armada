## Test: SquadronActivationModal
##
## Unit tests for the Squadron Phase activation modal state machine.
## Covers: state transitions, button availability (engagement), Rogue flow,
## open/close behaviour, signals, and error handling.
##
## Rules Reference: "Squadron Phase" p.20, "Engagement" p.4.
## Requirements: SQA-001–013, SQM-001–007.
extends GutTest


var _modal: SquadronActivationModal = null


## Creates a minimal SquadronData for testing.
func _make_squad_data(
		speed: int = 3,
		faction: Constants.Faction = Constants.Faction.REBEL_ALLIANCE,
		kw: Array[Dictionary] = []) -> SquadronData:
	var data: SquadronData = SquadronData.new()
	data.squadron_name = "TestSquad"
	data.faction = faction
	data.hull = 3
	data.speed = speed
	data.defense_tokens = []
	data.keywords = kw
	return data


## Creates a SquadronInstance with optional engagement flag.
func _make_instance(
		player: int = 0,
		engaged: bool = false,
		activated: bool = false,
		speed: int = 3,
		faction: Constants.Faction = Constants.Faction.REBEL_ALLIANCE,
		kw: Array[Dictionary] = []) -> SquadronInstance:
	var data: SquadronData = _make_squad_data(speed, faction, kw)
	var inst: SquadronInstance = SquadronInstance.create_from_data(
			"test_squad", data, player)
	inst.is_engaged = engaged
	inst.activated_this_round = activated
	return inst


## Creates a mock SquadronToken-like object for testing.
## Since SquadronToken requires a scene, we use the real scene.
func _make_token(
		instance: SquadronInstance) -> SquadronToken:
	var scene: PackedScene = preload(
			"res://src/scenes/tokens/squadron_token.tscn")
	var token: SquadronToken = scene.instantiate() as SquadronToken
	add_child_autofree(token)
	var placement: TokenPlacement = TokenPlacement.new(
			"test_squad", false,
			instance.squadron_data.faction,
			0.5, 0.5, 0.0)
	token.setup(placement)
	token.bind_instance(instance)
	return token


func before_each() -> void:
	_modal = SquadronActivationModal.new()
	add_child_autofree(_modal)


# ===========================================================================
# Initial state
# ===========================================================================

func test_initial_state_is_waiting() -> void:
	assert_eq(int(_modal.get_state()),
			int(SquadronActivationModal.State.WAITING_FOR_SELECTION),
			"Initial state should be WAITING_FOR_SELECTION")


func test_initially_hidden() -> void:
	assert_false(_modal.visible,
			"Modal should be hidden on creation")


func test_selected_token_initially_null() -> void:
	assert_null(_modal.get_selected_token(),
			"No token should be selected initially")


# ===========================================================================
# open_for_turn
# ===========================================================================

func test_open_for_turn_makes_visible() -> void:
	_modal.open_for_turn(1, 2)
	assert_true(_modal.visible,
			"Modal should be visible after open_for_turn")


func test_open_for_turn_sets_waiting_state() -> void:
	_modal.open_for_turn(1, 2)
	assert_eq(int(_modal.get_state()),
			int(SquadronActivationModal.State.WAITING_FOR_SELECTION),
			"State should be WAITING_FOR_SELECTION after open")


func test_open_for_turn_resets_selected_token() -> void:
	_modal.open_for_turn(1, 2)
	assert_null(_modal.get_selected_token(),
			"Selected token should be null after open")


# ===========================================================================
# handle_squadron_click — selection
# ===========================================================================

func test_click_valid_squadron_transitions_to_action_choice() -> void:
	# Set up GameManager state for squadron phase.
	GameManager.start_new_game()
	GameManager.current_game_state.current_phase = \
			Constants.GamePhase.SQUADRON
	var inst: SquadronInstance = _make_instance(0)
	GameManager.active_player = 0
	var ps: PlayerState = GameManager.current_game_state.get_player_state(0)
	ps.squadrons.append(inst)
	_modal.open_for_turn(1, 2)
	var token: SquadronToken = _make_token(inst)
	var consumed: bool = _modal.handle_squadron_click(token)
	assert_true(consumed, "Valid click should be consumed")
	assert_eq(int(_modal.get_state()),
			int(SquadronActivationModal.State.ACTION_CHOICE),
			"State should transition to ACTION_CHOICE")


func test_click_wrong_player_rejected() -> void:
	GameManager.start_new_game()
	GameManager.current_game_state.current_phase = \
			Constants.GamePhase.SQUADRON
	var inst: SquadronInstance = _make_instance(1) # enemy squadron
	GameManager.active_player = 0
	_modal.open_for_turn(1, 2)
	var token: SquadronToken = _make_token(inst)
	var consumed: bool = _modal.handle_squadron_click(token)
	assert_false(consumed,
			"Clicking wrong player's squadron should be rejected")
	assert_eq(int(_modal.get_state()),
			int(SquadronActivationModal.State.WAITING_FOR_SELECTION),
			"State should remain WAITING_FOR_SELECTION")
	# push_warning from _log.warn is caught by GUT as engine error
	assert_engine_error(1,
			"Should push a warning for wrong-player selection")


func test_click_already_activated_rejected() -> void:
	GameManager.start_new_game()
	GameManager.current_game_state.current_phase = \
			Constants.GamePhase.SQUADRON
	var inst: SquadronInstance = _make_instance(0, false, true) # activated
	GameManager.active_player = 0
	var ps: PlayerState = GameManager.current_game_state.get_player_state(0)
	ps.squadrons.append(inst)
	_modal.open_for_turn(1, 2)
	var token: SquadronToken = _make_token(inst)
	var consumed: bool = _modal.handle_squadron_click(token)
	assert_false(consumed,
			"Already-activated squadron should be rejected")
	# push_warning from _log.warn is caught by GUT as engine error
	assert_engine_error(1,
			"Should push a warning for already-activated squadron")


func test_click_when_hidden_returns_false() -> void:
	var inst: SquadronInstance = _make_instance(0)
	var token: SquadronToken = _make_token(inst)
	# Modal not visible (not opened).
	var consumed: bool = _modal.handle_squadron_click(token)
	assert_false(consumed,
			"Click when modal is hidden should return false")


# ===========================================================================
# Action buttons — engagement rules
# ===========================================================================

func test_engaged_squadron_move_hidden() -> void:
	GameManager.start_new_game()
	GameManager.current_game_state.current_phase = \
			Constants.GamePhase.SQUADRON
	var inst: SquadronInstance = _make_instance(0, true) # engaged
	GameManager.active_player = 0
	var ps: PlayerState = GameManager.current_game_state.get_player_state(0)
	ps.squadrons.append(inst)
	_modal.open_for_turn(1, 2)
	var token: SquadronToken = _make_token(inst)
	_modal.handle_squadron_click(token)
	assert_false(_modal._move_button.visible,
			"Move button should be hidden when engaged (SM-011)")


func test_engaged_squadron_skip_disabled() -> void:
	GameManager.start_new_game()
	GameManager.current_game_state.current_phase = \
			Constants.GamePhase.SQUADRON
	var inst: SquadronInstance = _make_instance(0, true) # engaged
	GameManager.active_player = 0
	var ps: PlayerState = GameManager.current_game_state.get_player_state(0)
	ps.squadrons.append(inst)
	_modal.open_for_turn(1, 2)
	var token: SquadronToken = _make_token(inst)
	_modal.handle_squadron_click(token)
	assert_true(_modal._skip_button.disabled,
			"Skip button should be disabled when engaged (SM-012)")


func test_engaged_squadron_attack_enabled() -> void:
	GameManager.start_new_game()
	GameManager.current_game_state.current_phase = \
			Constants.GamePhase.SQUADRON
	var inst: SquadronInstance = _make_instance(0, true) # engaged
	GameManager.active_player = 0
	var ps: PlayerState = GameManager.current_game_state.get_player_state(0)
	ps.squadrons.append(inst)
	_modal.open_for_turn(1, 2)
	var token: SquadronToken = _make_token(inst)
	_modal.handle_squadron_click(token)
	assert_false(_modal._attack_button.disabled,
			"Attack button should be enabled for engaged squadron")


func test_unengaged_squadron_all_buttons_visible() -> void:
	GameManager.start_new_game()
	GameManager.current_game_state.current_phase = \
			Constants.GamePhase.SQUADRON
	var inst: SquadronInstance = _make_instance(0, false) # not engaged
	GameManager.active_player = 0
	var ps: PlayerState = GameManager.current_game_state.get_player_state(0)
	ps.squadrons.append(inst)
	_modal.open_for_turn(1, 2)
	var token: SquadronToken = _make_token(inst)
	_modal.handle_squadron_click(token)
	assert_true(_modal._move_button.visible,
			"Move should be visible when not engaged")
	assert_true(_modal._attack_button.visible,
			"Attack should be visible when not engaged")
	assert_true(_modal._skip_button.visible,
			"Skip should be visible when not engaged")


# ===========================================================================
# State transitions — Move flow
# ===========================================================================

func test_notify_move_preview_success_transitions_to_preview() -> void:
	GameManager.start_new_game()
	GameManager.current_game_state.current_phase = \
			Constants.GamePhase.SQUADRON
	var inst: SquadronInstance = _make_instance(0)
	GameManager.active_player = 0
	var ps: PlayerState = GameManager.current_game_state.get_player_state(0)
	ps.squadrons.append(inst)
	_modal.open_for_turn(1, 2)
	var token: SquadronToken = _make_token(inst)
	_modal.handle_squadron_click(token)
	_modal._transition_to(SquadronActivationModal.State.MOVING)
	_modal.notify_move_preview_success()
	assert_eq(int(_modal.get_state()),
			int(SquadronActivationModal.State.MOVE_PREVIEW),
			"Should transition to MOVE_PREVIEW after success")


func test_notify_move_preview_failed_stays_in_moving() -> void:
	GameManager.start_new_game()
	GameManager.current_game_state.current_phase = \
			Constants.GamePhase.SQUADRON
	var inst: SquadronInstance = _make_instance(0)
	GameManager.active_player = 0
	var ps: PlayerState = GameManager.current_game_state.get_player_state(0)
	ps.squadrons.append(inst)
	_modal.open_for_turn(1, 2)
	var token: SquadronToken = _make_token(inst)
	_modal.handle_squadron_click(token)
	_modal._transition_to(SquadronActivationModal.State.MOVING)
	_modal.notify_move_preview_failed("Too far")
	assert_eq(int(_modal.get_state()),
			int(SquadronActivationModal.State.MOVING),
			"Should remain in MOVING after failed placement")
	# push_warning from _log.warn is caught by GUT as engine error
	assert_engine_error(1,
			"Should push a warning for failed placement")


# ===========================================================================
# State transitions — Attack flow
# ===========================================================================

func test_notify_attack_completed_finishes_activation() -> void:
	GameManager.start_new_game()
	GameManager.current_game_state.current_phase = \
			Constants.GamePhase.SQUADRON
	var inst: SquadronInstance = _make_instance(0)
	GameManager.active_player = 0
	var ps: PlayerState = GameManager.current_game_state.get_player_state(0)
	ps.squadrons.append(inst)
	_modal.open_for_turn(1, 2)
	var token: SquadronToken = _make_token(inst)
	_modal.handle_squadron_click(token)
	_modal._transition_to(SquadronActivationModal.State.ATTACKING)
	_modal.notify_attack_completed()
	assert_eq(int(_modal.get_state()),
			int(SquadronActivationModal.State.DONE),
			"Non-Rogue should go to DONE after attack completed")


func test_notify_attack_cancelled_returns_to_action_choice() -> void:
	GameManager.start_new_game()
	GameManager.current_game_state.current_phase = \
			Constants.GamePhase.SQUADRON
	var inst: SquadronInstance = _make_instance(0)
	GameManager.active_player = 0
	var ps: PlayerState = GameManager.current_game_state.get_player_state(0)
	ps.squadrons.append(inst)
	_modal.open_for_turn(1, 2)
	var token: SquadronToken = _make_token(inst)
	_modal.handle_squadron_click(token)
	_modal._transition_to(SquadronActivationModal.State.ATTACKING)
	_modal.notify_attack_cancelled()
	assert_eq(int(_modal.get_state()),
			int(SquadronActivationModal.State.ACTION_CHOICE),
			"Should return to ACTION_CHOICE after attack cancelled")


# ===========================================================================
# Skip — activation_done signal
# ===========================================================================

func test_skip_emits_activation_done() -> void:
	GameManager.start_new_game()
	GameManager.current_game_state.current_phase = \
			Constants.GamePhase.SQUADRON
	var inst: SquadronInstance = _make_instance(0)
	GameManager.active_player = 0
	var ps: PlayerState = GameManager.current_game_state.get_player_state(0)
	ps.squadrons.append(inst)
	_modal.open_for_turn(1, 2)
	var token: SquadronToken = _make_token(inst)
	_modal.handle_squadron_click(token)
	watch_signals(_modal)
	_modal._on_skip_pressed()
	assert_signal_emitted(_modal, "activation_done",
			"Skip should emit activation_done signal")


# ===========================================================================
# close_modal
# ===========================================================================

func test_close_modal_hides_and_resets() -> void:
	_modal.open_for_turn(1, 2)
	_modal.close_modal()
	assert_false(_modal.visible,
			"Modal should be hidden after close_modal()")
	assert_eq(int(_modal.get_state()),
			int(SquadronActivationModal.State.WAITING_FOR_SELECTION),
			"State should reset to WAITING after close")
	assert_null(_modal.get_selected_token(),
			"Selected token should be null after close")


func test_close_button_hides_modal() -> void:
	_modal.open_for_turn(1, 2)
	_modal._on_close_pressed()
	assert_false(_modal.visible,
			"Modal should be hidden after close button press")


# ===========================================================================
# set_action_availability
# ===========================================================================

func test_set_action_availability_hides_move() -> void:
	GameManager.start_new_game()
	GameManager.current_game_state.current_phase = \
			Constants.GamePhase.SQUADRON
	var inst: SquadronInstance = _make_instance(0, false)
	GameManager.active_player = 0
	var ps: PlayerState = GameManager.current_game_state.get_player_state(0)
	ps.squadrons.append(inst)
	_modal.open_for_turn(1, 2)
	var token: SquadronToken = _make_token(inst)
	_modal.handle_squadron_click(token)
	_modal.set_action_availability(false, true)
	assert_false(_modal._move_button.visible,
			"Move button should be hidden when can_move=false")
	assert_true(_modal._attack_button.visible,
			"Attack button should remain visible when has_targets=true")


func test_set_action_availability_hides_attack() -> void:
	GameManager.start_new_game()
	GameManager.current_game_state.current_phase = \
			Constants.GamePhase.SQUADRON
	var inst: SquadronInstance = _make_instance(0, false)
	GameManager.active_player = 0
	var ps: PlayerState = GameManager.current_game_state.get_player_state(0)
	ps.squadrons.append(inst)
	_modal.open_for_turn(1, 2)
	var token: SquadronToken = _make_token(inst)
	_modal.handle_squadron_click(token)
	_modal.set_action_availability(true, false)
	assert_true(_modal._move_button.visible,
			"Move button should remain visible when can_move=true")
	assert_false(_modal._attack_button.visible,
			"Attack button should be hidden when has_targets=false")


# ===========================================================================
# notify_move_completed and cancel_move
# ===========================================================================

func test_notify_move_completed_finishes_activation() -> void:
	GameManager.start_new_game()
	GameManager.current_game_state.current_phase = \
			Constants.GamePhase.SQUADRON
	var inst: SquadronInstance = _make_instance(0)
	GameManager.active_player = 0
	var ps: PlayerState = GameManager.current_game_state.get_player_state(0)
	ps.squadrons.append(inst)
	_modal.open_for_turn(1, 2)
	var token: SquadronToken = _make_token(inst)
	_modal.handle_squadron_click(token)
	_modal._transition_to(SquadronActivationModal.State.MOVING)
	_modal.notify_move_completed()
	assert_eq(int(_modal.get_state()),
			int(SquadronActivationModal.State.DONE),
			"Non-Rogue should go to DONE after move completed")


func test_cancel_move_returns_to_action_choice() -> void:
	GameManager.start_new_game()
	GameManager.current_game_state.current_phase = \
			Constants.GamePhase.SQUADRON
	var inst: SquadronInstance = _make_instance(0)
	GameManager.active_player = 0
	var ps: PlayerState = GameManager.current_game_state.get_player_state(0)
	ps.squadrons.append(inst)
	_modal.open_for_turn(1, 2)
	var token: SquadronToken = _make_token(inst)
	_modal.handle_squadron_click(token)
	_modal._transition_to(SquadronActivationModal.State.MOVING)
	_modal.cancel_move()
	assert_eq(int(_modal.get_state()),
			int(SquadronActivationModal.State.ACTION_CHOICE),
			"cancel_move should return to ACTION_CHOICE")
