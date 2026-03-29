## SquadronActivationModal
##
## Bottom-centre panel that guides the player through the Squadron Phase.
## State machine: WAITING → ACTION_CHOICE → MOVING → ATTACKING → DONE.
##
## Styled identically to ActivationModal / AttackSimPanel
## (see .skills/ui_styling.md).
##
## Dismissable via Escape or "✕ Close" button.  Closing hides the panel
## without cancelling the activation — the player can re-open it via the
## ShowSquadronModalButton.
##
## Rules Reference: RRG "Squadron Phase" p.20, "Squadron Activation" p.19.
## Requirements: SQA-001–013, SQM-001–007, SQA-ATK-001–006, SQA-TM-001–004.
class_name SquadronActivationModal
extends PanelContainer


# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Player clicked "Move" — game board should enter move-placement mode.
signal move_requested(squadron_token: SquadronToken)

## Player clicked "Commit Move" — finalise the previewed placement.
signal move_commit_requested(squadron_token: SquadronToken)

## Player clicked "Attack" — game board should open the attack executor.
signal attack_requested(squadron_token: SquadronToken)

## Player clicked "Skip (End Activation)" — end without action.
signal skip_requested()

## A single squadron activation is done (move, attack, or skip completed).
## The game board should emit [code]EventBus.squadron_activation_ended[/code].
signal activation_done(squadron_instance: SquadronInstance)

## The modal was closed / dismissed by the player.
signal modal_closed()


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Modal width limits.
const MODAL_MAX_WIDTH: float = 360.0
const MODAL_WIDTH_FRACTION: float = 0.35

## Vertical offset from the bottom of the screen.
const BOTTOM_OFFSET_X: float = -120.0
const BOTTOM_OFFSET_Y: float = -40.0


# ---------------------------------------------------------------------------
# State machine
# ---------------------------------------------------------------------------

enum State {
	WAITING_FOR_SELECTION, ## Prompt "Click a squadron to activate".
	ACTION_CHOICE, ## Show Move / Attack / Skip buttons.
	MOVING, ## Waiting for placement click → Commit Move.
	MOVE_PREVIEW, ## Token snapped to preview pos — show Commit Move.
	ATTACKING, ## Attack executor is running.
	DONE, ## Current activation finished; advance or next.
}

var _state: State = State.WAITING_FOR_SELECTION


# ---------------------------------------------------------------------------
# Runtime data
# ---------------------------------------------------------------------------

## Logger.
var _log: GameLogger = GameLogger.new("SqActModal")

## Currently selected squadron token (null in WAITING state).
var _selected_token: SquadronToken = null

## The SquadronInstance for the selected token.
var _selected_instance: SquadronInstance = null

## Activation counter within the current turn (1-based).
var _activation_number: int = 1

## Max activations this turn.
var _max_activations: int = Constants.SQUADRONS_PER_ACTIVATION

## Whether the selected squadron is engaged.
var _is_engaged: bool = false

## Whether the selected squadron has Rogue.
var _has_rogue: bool = false

## Whether the Rogue squadron has already moved this activation.
var _rogue_has_moved: bool = false

## Whether the Rogue squadron has already attacked this activation.
var _rogue_has_attacked: bool = false

## Whether the selected squadron can move (not engaged, speed > 0).
## Set by [method set_action_availability] from the game board.
var _can_move: bool = true

## Whether the selected squadron has at least one valid attack target.
## Set by [method set_action_availability] from the game board.
var _has_targets: bool = true


# ---------------------------------------------------------------------------
# UI elements
# ---------------------------------------------------------------------------

var _margin: MarginContainer = null
var _vbox: VBoxContainer = null
var _title_label: Label = null
var _subtitle_label: Label = null
var _prompt_label: Label = null
var _button_container: HBoxContainer = null
var _move_button: Button = null
var _attack_button: Button = null
var _skip_button: Button = null
var _commit_move_button: Button = null
var _close_button: Button = null
var _error_label: Label = null


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_apply_anchor_position()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			_on_close_pressed()
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Opens the modal for a new turn.
## [param activation_num] — which activation within the turn (1 or 2).
## [param max_act] — how many activations this turn allows.
func open_for_turn(activation_num: int, max_act: int) -> void:
	_activation_number = activation_num
	_max_activations = max_act
	_selected_token = null
	_selected_instance = null
	_rogue_has_moved = false
	_rogue_has_attacked = false
	_transition_to(State.WAITING_FOR_SELECTION)
	visible = true
	_log.info("Opened for activation %d of %d." % [activation_num, max_act])


## Called by game_board when a squadron token is clicked.
## Returns true if the click was consumed.
func handle_squadron_click(token: SquadronToken) -> bool:
	if not visible:
		return false
	match _state:
		State.WAITING_FOR_SELECTION:
			return _try_select_squadron(token)
		State.MOVING:
			# During movement, clicks on other squadrons are ignored
			# (board click handler is used for placement).
			return false
		_:
			return false


## Called by game_board when the player clicks on the board (not a token)
## during the MOVING state.  [param world_pos] is the click position in
## game-world coordinates.
func handle_board_click(world_pos: Vector2) -> bool:
	if not visible:
		return false
	if _state != State.MOVING:
		return false
	if _selected_token == null:
		return false
	move_requested.emit(_selected_token)
	# The actual validation + snap is done by game_board; it calls
	# notify_move_preview_success or notify_move_preview_failed.
	return true


## Called by game_board after a valid move preview placement.
func notify_move_preview_success() -> void:
	_transition_to(State.MOVE_PREVIEW)


## Called by game_board when the move is placed by clicking during MOVING.
## Directly finishes the activation (no Commit Move step needed).
func notify_move_completed() -> void:
	if _has_rogue and not _rogue_has_moved:
		_rogue_has_moved = true
		if _rogue_has_attacked:
			_finish_activation()
		else:
			# Rogue can still attack.
			_transition_to(State.ACTION_CHOICE)
	else:
		_finish_activation()


## Called by game_board when the player presses Escape during MOVING.
## Reverts the token to its original position (done by game_board) and
## returns to ACTION_CHOICE so the player can pick a different action.
func cancel_move() -> void:
	_transition_to(State.ACTION_CHOICE)


## Called by game_board when the move preview placement was invalid.
## [param reason] — human-readable error message.
func notify_move_preview_failed(reason: String) -> void:
	_show_error(reason)


## Called by game_board when the attack executor finishes.
func notify_attack_completed() -> void:
	if _has_rogue and not _rogue_has_attacked:
		_rogue_has_attacked = true
		if _rogue_has_moved:
			_finish_activation()
		else:
			# Rogue can still move.
			_transition_to(State.ACTION_CHOICE)
	else:
		_finish_activation()


## Called by game_board when the attack executor is cancelled.
func notify_attack_cancelled() -> void:
	_transition_to(State.ACTION_CHOICE)


## Resets the modal when the squadron phase ends.
func close_modal() -> void:
	_selected_token = null
	_selected_instance = null
	_state = State.WAITING_FOR_SELECTION
	visible = false


## Sets which actions are available for the currently selected squadron.
## Called by game_board after [method _on_squadron_selected_in_modal].
## [param can_move] — false if engaged or speed 0.
## [param has_targets] — false if no enemies in range.
func set_action_availability(can_move: bool, has_targets: bool) -> void:
	_can_move = can_move
	_has_targets = has_targets
	if _state == State.ACTION_CHOICE:
		_update_action_buttons()


## Returns the currently selected squadron token (or null).
func get_selected_token() -> SquadronToken:
	return _selected_token


## Returns the current state (for testing).
func get_state() -> State:
	return _state


# ---------------------------------------------------------------------------
# Private — state transitions
# ---------------------------------------------------------------------------

func _transition_to(new_state: State) -> void:
	_state = new_state
	_update_ui()


func _try_select_squadron(token: SquadronToken) -> bool:
	var instance: SquadronInstance = token.get_squadron_instance()
	if instance == null:
		_show_error("No instance bound to token.")
		return false
	if instance.owner_player != GameManager.active_player:
		_show_error("Not your squadron.")
		return false
	if instance.activated_this_round:
		_show_error("Already activated this round.")
		return false
	# Call GameManager to formally activate.
	GameManager.activate_squadron(instance)
	if GameManager.get_activating_squadron() != instance:
		_show_error("Activation rejected by GameManager.")
		return false
	_selected_token = token
	_selected_instance = instance
	_is_engaged = instance.is_engaged
	_has_rogue = instance.squadron_data != null \
			and instance.squadron_data.has_keyword("Rogue")
	_rogue_has_moved = false
	_rogue_has_attacked = false
	# Defaults — game_board overrides via set_action_availability().
	_can_move = not _is_engaged
	_has_targets = true
	_log.info("Selected squadron: %s (engaged=%s, rogue=%s)" % [
			instance.data_key, str(_is_engaged), str(_has_rogue)])
	_transition_to(State.ACTION_CHOICE)
	return true


func _finish_activation() -> void:
	_transition_to(State.DONE)
	if _selected_instance != null:
		activation_done.emit(_selected_instance)
	_selected_token = null
	_selected_instance = null


# ---------------------------------------------------------------------------
# Private — UI construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# Panel style.
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.border_color = Color(0.4, 0.5, 0.7, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)

	# Margin.
	_margin = MarginContainer.new()
	_margin.add_theme_constant_override("margin_left", 16)
	_margin.add_theme_constant_override("margin_right", 16)
	_margin.add_theme_constant_override("margin_top", 12)
	_margin.add_theme_constant_override("margin_bottom", 12)
	add_child(_margin)

	# VBox.
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 8)
	# Explicit min-width so the autowrap _prompt_label computes a correct
	# minimum height before the PanelContainer propagates its width.
	var content_w: float = (-BOTTOM_OFFSET_X) * 2.0 - 32.0 # 240 - 32 = 208
	_vbox.custom_minimum_size.x = maxf(content_w, 100.0)
	_margin.add_child(_vbox)

	# Title.
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.text = "Squadron Phase"
	_vbox.add_child(_title_label)

	# Subtitle.
	_subtitle_label = Label.new()
	_subtitle_label.add_theme_font_size_override("font_size", 12)
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_color_override(
			"font_color", Color(0.6, 0.6, 0.6))
	_vbox.add_child(_subtitle_label)

	# Prompt.
	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.add_child(_prompt_label)

	# Error label (hidden by default).
	_error_label = Label.new()
	_error_label.add_theme_font_size_override("font_size", 12)
	_error_label.add_theme_color_override(
			"font_color", Color(0.9, 0.3, 0.3))
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.visible = false
	_vbox.add_child(_error_label)

	# Action buttons.
	_button_container = HBoxContainer.new()
	_button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_container.add_theme_constant_override("separation", 8)
	_vbox.add_child(_button_container)

	_move_button = Button.new()
	_move_button.text = "Move"
	_move_button.custom_minimum_size = Vector2(90, 36)
	_move_button.pressed.connect(_on_move_pressed)
	_button_container.add_child(_move_button)

	_attack_button = Button.new()
	_attack_button.text = "Attack"
	_attack_button.custom_minimum_size = Vector2(90, 36)
	_attack_button.pressed.connect(_on_attack_pressed)
	_button_container.add_child(_attack_button)

	_skip_button = Button.new()
	_skip_button.text = "Skip"
	_skip_button.custom_minimum_size = Vector2(90, 36)
	_skip_button.pressed.connect(_on_skip_pressed)
	_button_container.add_child(_skip_button)

	# Commit Move button (hidden by default).
	_commit_move_button = Button.new()
	_commit_move_button.text = "Commit Move"
	_commit_move_button.custom_minimum_size = Vector2(200, 44)
	_commit_move_button.visible = false
	_commit_move_button.pressed.connect(_on_commit_move_pressed)
	var commit_hbox: HBoxContainer = HBoxContainer.new()
	commit_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	commit_hbox.add_child(_commit_move_button)
	_vbox.add_child(commit_hbox)

	# Close button.
	_close_button = Button.new()
	_close_button.text = "✕ Close"
	_close_button.custom_minimum_size = Vector2(80, 28)
	_close_button.pressed.connect(_on_close_pressed)
	var close_hbox: HBoxContainer = HBoxContainer.new()
	close_hbox.alignment = BoxContainer.ALIGNMENT_END
	close_hbox.add_child(_close_button)
	_vbox.add_child(close_hbox)


func _apply_anchor_position() -> void:
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = BOTTOM_OFFSET_X
	offset_right = - BOTTOM_OFFSET_X
	offset_top = BOTTOM_OFFSET_Y
	offset_bottom = BOTTOM_OFFSET_Y
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN


# ---------------------------------------------------------------------------
# Private — UI updates
# ---------------------------------------------------------------------------

func _update_ui() -> void:
	_error_label.visible = false
	var faction_name: String = _get_active_faction_name()
	_title_label.text = "Squadron Phase — %s" % faction_name

	match _state:
		State.WAITING_FOR_SELECTION:
			_subtitle_label.text = "Activate squadron %d of %d" % [
					_activation_number, _max_activations]
			_prompt_label.text = "Click a squadron to activate"
			_button_container.visible = false
			_commit_move_button.visible = false
		State.ACTION_CHOICE:
			var squad_name: String = _get_squadron_name()
			_subtitle_label.text = squad_name
			_prompt_label.text = "Choose an action:"
			_button_container.visible = true
			_commit_move_button.visible = false
			_update_action_buttons()
		State.MOVING:
			_subtitle_label.text = _get_squadron_name()
			_prompt_label.text = "Move the squadron, then click to place"
			_button_container.visible = false
			_commit_move_button.visible = false
		State.MOVE_PREVIEW:
			_subtitle_label.text = _get_squadron_name()
			_prompt_label.text = "Squadron placed — confirm or click again"
			_button_container.visible = false
			_commit_move_button.visible = true
		State.ATTACKING:
			_subtitle_label.text = _get_squadron_name()
			_prompt_label.text = "Resolving attack…"
			_button_container.visible = false
			_commit_move_button.visible = false
		State.DONE:
			_subtitle_label.text = ""
			_prompt_label.text = "Activation complete."
			_button_container.visible = false
			_commit_move_button.visible = false


func _update_action_buttons() -> void:
	# Move button — hidden if squadron cannot move (engaged or no targets
	# computed by game_board).  Also hidden if Rogue already moved.
	var can_move: bool = _can_move
	if _has_rogue and _rogue_has_moved:
		can_move = false
	_move_button.visible = can_move
	_move_button.disabled = false
	_move_button.tooltip_text = ""

	# Attack button — hidden if no valid targets in range.
	var can_attack: bool = _has_targets
	if _has_rogue and _rogue_has_attacked:
		can_attack = false
	_attack_button.visible = can_attack
	_attack_button.disabled = false
	if not can_attack and _has_rogue and _rogue_has_attacked:
		_attack_button.tooltip_text = "Already attacked"
	else:
		_attack_button.tooltip_text = ""

	# Skip button — disabled if engaged (SM-012: must attack).
	var can_skip: bool = not _is_engaged
	if _has_rogue:
		# Rogue engaged can still skip if they've already attacked.
		if _rogue_has_attacked or not _is_engaged:
			can_skip = true
	_skip_button.visible = true
	_skip_button.disabled = not can_skip
	if not can_skip:
		_skip_button.tooltip_text = "Engaged — must attack an engaged enemy"
	else:
		_skip_button.tooltip_text = ""

	# Update the prompt if no actions are available (edge case).
	if not can_move and not can_attack and not can_skip:
		_prompt_label.text = "No actions available — skip to end."
		_skip_button.visible = true
		_skip_button.disabled = false


func _get_active_faction_name() -> String:
	var gs: GameState = GameManager.current_game_state
	if gs == null:
		return ""
	var player: int = GameManager.active_player
	var ps: PlayerState = gs.get_player_state(player)
	if ps == null:
		return ""
	match ps.faction:
		Constants.Faction.REBEL_ALLIANCE:
			return "Rebel Alliance"
		Constants.Faction.GALACTIC_EMPIRE:
			return "Galactic Empire"
		_:
			return "Player %d" % player


func _get_squadron_name() -> String:
	if _selected_instance != null and _selected_instance.squadron_data != null:
		return _selected_instance.squadron_data.squadron_name
	if _selected_instance != null:
		return _selected_instance.data_key
	return "Unknown"


func _show_error(msg: String) -> void:
	_error_label.text = msg
	_error_label.visible = true
	_log.warn("UI error: %s" % msg)


# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

func _on_move_pressed() -> void:
	_log.info("Move pressed for %s" % _get_squadron_name())
	_transition_to(State.MOVING)
	move_requested.emit(_selected_token)


func _on_attack_pressed() -> void:
	_log.info("Attack pressed for %s" % _get_squadron_name())
	_transition_to(State.ATTACKING)
	attack_requested.emit(_selected_token)


func _on_skip_pressed() -> void:
	_log.info("Skip pressed for %s" % _get_squadron_name())
	_finish_activation()


func _on_commit_move_pressed() -> void:
	_log.info("Commit Move pressed for %s" % _get_squadron_name())
	move_commit_requested.emit(_selected_token)
	if _has_rogue and not _rogue_has_moved:
		_rogue_has_moved = true
		if _rogue_has_attacked:
			_finish_activation()
		else:
			# Rogue can still attack.
			_transition_to(State.ACTION_CHOICE)
	else:
		_finish_activation()


func _on_close_pressed() -> void:
	_log.info("Modal dismissed.")
	visible = false
	modal_closed.emit()
