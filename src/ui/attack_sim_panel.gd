## AttackSimPanel
##
## Screen-space info panel for the Attack Simulator and the real attack
## execution step.  Shows step-by-step prompts guiding the player through
## the attack sequence.
## Phase 6a: attacker declaration.  Phase 6a-2: target selection + LOS result.
## Phase 6a-3: range band display alongside LOS result.
## Phase 6b-1: dice count display and "Done" button for attack execution.
## Phase 6b-2: CF dial, dice rolling, CF token reroll, Confirm, Skip Attack.
##
## Built as a PanelContainer following the project's standard modal styling.
## Dismissed by Escape, re-pressing "A", or programmatically via [method close].
##
## Requirements: AS-PNL-001–003, AS-PNL-010–011, AS-RNG-014, AE-PNL-001–003,
## AE-CF-001–005, AE-CF-010–014, AE-DICE-001–004, AE-CONF-001–002,
## AE-2HZ-001–005, AE-SKIP-001–003.
## Rules Reference: "Attack", Step 1, p.2; "Line of Sight", p.10;
## "Attack Range", p.3; "Concentrate Fire", p.3.
class_name AttackSimPanel
extends PanelContainer


## Emitted when the player presses the "Done" button (sim mode only).
## Requirements: AE-PNL-003.
signal attack_done_pressed()

## Emitted when the player selects a colour for the CF dial extra die.
## Requirements: AE-CF-003.
signal cf_dial_colour_selected(colour_key: String)

## Emitted when the player skips the CF dial.
## Requirements: AE-CF-005.
signal cf_dial_skipped()

## Emitted when the player presses "Roll Dice".
## Requirements: AE-DICE-001.
signal roll_dice_pressed()

## Emitted when the player confirms a die reroll (CF token).
## Requirements: AE-CF-011.
signal cf_token_reroll_requested(die_index: int)

## Emitted when the player skips the CF token reroll.
## Requirements: AE-CF-013.
signal cf_token_reroll_skipped()

## Emitted when the player presses "Confirm" to finalise the attack.
## Requirements: AE-CONF-001.
signal confirm_pressed()

## Emitted when the player presses "Skip Attack".
## Requirements: AE-SKIP-001.
signal skip_attack_pressed()

## Emitted when the player toggles a defense token lock (accuracy).
## [param token_index] — index in the defender's defense_tokens array.
## Requirements: AE-ACC-002, AE-ACC-003.
signal accuracy_token_toggled(token_index: int)

## Emitted when the player confirms accuracy spending.
## Requirements: AE-ACC-006.
signal accuracy_confirmed()

## Emitted when the player spends a defense token during the defense step.
## [param token_index] — index in the defender's defense_tokens array.
## [param spend_method] — "exhaust" or "discard".
## Requirements: AE-DEF-001, AE-DEF-002.
signal defense_token_selected(token_index: int, spend_method: String)

## Emitted when the player finishes spending defense tokens.
## Requirements: AE-DEF-003.
signal defense_tokens_done()

## Emitted when the player clicks "Done Redirecting" to finish the
## redirect sub-step early.
signal redirect_done_pressed()

## Emitted when the player selects a hull zone for redirect damage.
## [param zone] — Constants.HullZone value.
## Requirements: AE-DEF-012, AE-DEF-013.
signal redirect_zone_selected(zone: int)

## Emitted when the defender selects a die during evade die-selection.
## [param die_index] — index in the dice results array.
## Requirements: AE-DEF-007.
## Rules Reference: "Evade", RRG v1.5.0, p.5 — "the defender cancels one
## attack die of its choice."
signal evade_die_confirmed(die_index: int)

## Emitted when the attacker chooses which die colour to remove due to
## obstruction.
## [param colour_key] — "RED", "BLUE", or "BLACK".
## Requirements: AE-OBS-001.
## Rules Reference: "Obstructed", RRG v1.5.0, p.10 — "the attacker must
## remove one die of his choice from his attack pool."
signal obstruction_die_selected(colour_key: String)


## Logger.
var _log: GameLogger = GameLogger.new("AttackSimPanel")

## Title label at the top of the panel.
var _title_label: Label = null

## Body label showing the current prompt.
var _body_label: Label = null

## The VBox holding all content.
var _content: VBoxContainer = null

## Dice count label — visible only in attack execution mode.
## Requirements: AE-PNL-001.
var _dice_count_label: Label = null

## "Done" button — visible only in sim mode.
## Requirements: AE-PNL-003.
var _done_button: Button = null

## --- Phase 6b-2 UI elements ---

## CF dial section container (label + colour buttons + skip).
var _cf_dial_container: VBoxContainer = null
## HBox holding the colour buttons for CF dial.
var _cf_dial_buttons: HBoxContainer = null
## Skip button for the CF dial section.
var _cf_dial_skip_button: Button = null
## Obstruction die-removal section container.
var _obstruction_container: VBoxContainer = null
## HBox holding colour buttons for obstruction removal.
var _obstruction_buttons: HBoxContainer = null
## Empty-pool notice container (target beyond range / no dice).
var _empty_pool_container: VBoxContainer = null
## "Roll Dice" button.
var _roll_button: Button = null
## HBox holding die face TextureRects.
var _dice_container: HBoxContainer = null
## CF token reroll section container.
var _cf_token_container: VBoxContainer = null
## HBox holding the Reroll + Skip buttons for CF token.
var _cf_token_buttons: HBoxContainer = null
## "Reroll" button inside CF token section.
var _cf_token_reroll_button: Button = null
## "Skip" button inside CF token section.
var _cf_token_skip_button: Button = null
## "Confirm" button — finalises the attack.
var _confirm_button: Button = null
## "Skip Attack" button — skips the entire attack.
var _skip_attack_button: Button = null
## Confirmation prompt shown after pressing "Skip Attack".
var _skip_confirm_container: HBoxContainer = null
## "Yes" button inside the skip-attack confirmation prompt.
var _skip_confirm_yes: Button = null
## "No" button inside the skip-attack confirmation prompt.
var _skip_confirm_no: Button = null

## --- Phase 6c-1: Accuracy spending UI ---

## Accuracy section container (label + token buttons + confirm).
var _accuracy_container: VBoxContainer = null
## HBox holding defender token buttons for accuracy lock.
var _accuracy_token_buttons: HBoxContainer = null
## "Confirm Accuracies" button.
var _accuracy_confirm_button: Button = null
## Tracks which token indices are currently locked by accuracy.
var _accuracy_locked_indices: Array[int] = []
## Number of accuracy icons available to spend.
var _accuracy_budget: int = 0

## --- Phase 6c-2: Defense token spending UI ---

## Defense section container (label + token buttons + done).
var _defense_container: VBoxContainer = null
## HBox holding defender token buttons for spending.
var _defense_token_buttons: HBoxContainer = null
## "Done" button to finish defense token spending.
var _defense_done_button: Button = null
## Info label showing current damage after modifications.
var _defense_info_label: Label = null
## Tracks defense token indices currently selected (not yet committed).
var _defense_selected_indices: Array[int] = []

## --- Phase 6c-2: Redirect zone selection UI ---

## Redirect zone selection container.
var _redirect_container: VBoxContainer = null
## HBox holding zone buttons.
var _redirect_zone_buttons: HBoxContainer = null
## Redirect info label.
var _redirect_info_label: Label = null
## "Done Redirecting" button inside the redirect section.
var _redirect_done_button: Button = null

## --- Phase 6c-3: Damage resolution info UI ---

## Damage resolution info container.
var _damage_info_container: VBoxContainer = null
## Damage info label.
var _damage_info_label: Label = null

## Array of TextureRects showing die face images.
var _dice_textures: Array[TextureRect] = []
## Index of the die selected for reroll (-1 = none).
var _selected_reroll_index: int = -1
## Whether dice are in evade-selection mode (click = immediate confirm).
var _evade_mode: bool = false
## Size of each die image in the row (pixels).
const _DIE_IMAGE_SIZE: float = 32.0

## Whether this panel is in attack execution mode (shows dice count + Done).
var _attack_execution_mode: bool = false

## Initial prompt shown when the panel first appears.
## Requirements: AS-PNL-002.
const INITIAL_PROMPT: String = "Select a hull zone or squadron as the attacker."


func _init() -> void:
	name = "AttackSimPanel"
	visible = false
	_apply_anchor_position()


## Builds the panel UI and makes it visible with the initial prompt.
## Requirements: AS-PNL-001, AS-PNL-002.
func show_initial() -> void:
	_build_ui()
	_set_prompt("Attack Simulator", INITIAL_PROMPT)
	visible = true
	_request_deferred_layout()


## Builds the panel UI in attack execution mode with initial hull zone prompt.
## Requirements: AE-PNL-001.
func show_initial_attack_exec(ship_name: String) -> void:
	_attack_execution_mode = true
	_build_ui()
	_set_prompt("%s — Attack" % ship_name,
			"Select attacking hull zone.")
	visible = true
	_request_deferred_layout()


## Builds the panel UI in attack execution mode for a squadron attacker.
## Unlike ship attacks, the attacker is pre-selected — go straight to
## target selection.
## Requirements: SQA-ATK-001, AE-PNL-001.
func show_initial_squadron_exec(squad_name: String) -> void:
	_attack_execution_mode = true
	_build_ui()
	_set_prompt("Attacking: %s" % squad_name, "Select a target.")
	visible = true
	_request_deferred_layout()


## Updates the panel to show attacker confirmation for a hull zone.
## [param ship_name] — display name of the selected ship.
## [param zone_name] — hull zone string (e.g. "FRONT").
## Requirements: AS-VIS-004, AS-PNL-010.
func show_hull_zone_selected(ship_name: String, zone_name: String) -> void:
	var title: String = "Attacking: %s — %s arc" % [ship_name, zone_name]
	var body: String = "Select a target."
	_set_prompt(title, body)


## Updates the panel to show attacker confirmation for a squadron.
## [param squad_name] — display name of the selected squadron.
## Requirements: AS-VIS-011, AS-PNL-010.
func show_squadron_selected(squad_name: String) -> void:
	var title: String = "Attacking: %s" % squad_name
	var body: String = "Select a target."
	_set_prompt(title, body)


## Updates the panel to prompt for the next squadron target in the same arc.
## Shown after confirming an attack against a squadron when more enemy
## squadrons remain in range and arc.
## [param ship_name] — display name of the attacking ship.
## [param zone_name] — hull zone string (e.g. "FRONT").
## Requirements: AE-SQ-004, AE-SQ-005.
## Rules Reference: "Attack", Step 6, p.2.
func show_select_next_squadron(ship_name: String,
		zone_name: String) -> void:
	var title: String = "%s — %s arc" % [ship_name, zone_name]
	var body: String = "Select next squadron in arc, or Skip."
	_set_prompt(title, body)


## Updates the panel to show the attacker → target pair, LOS result,
## and range band.
## [param atk_name] — display name of the attacking ship/squadron.
## [param atk_zone] — hull zone string or empty for squadrons.
## [param def_name] — display name of the defending ship/squadron.
## [param def_zone] — hull zone string or empty for squadrons.
## [param los_text] — LOS result string (e.g. "Clear", "Obstructed by X", "Blocked").
## [param range_band] — range band string ("close", "medium", "long", "beyond")
##     or empty to omit the range part.
## Requirements: AS-PNL-011, AS-RNG-014.
func show_target_selected(atk_name: String, atk_zone: String,
		def_name: String, def_zone: String, los_text: String,
		range_band: String = "") -> void:
	var atk_part: String = atk_name
	if atk_zone != "":
		atk_part = "%s — %s" % [atk_name, atk_zone]
	var def_part: String = def_name
	if def_zone != "":
		def_part = "%s — %s" % [def_name, def_zone]
	var title: String = "%s → %s" % [atk_part, def_part]
	var body: String = "LOS: %s" % los_text
	if range_band != "":
		var display_band: String = range_band.capitalize()
		body = "LOS: %s · Range: %s" % [los_text, display_band]
	_set_prompt(title, body)


## Shows the dice pool count label.  Only effective in attack execution mode.
## [param dice_text] — formatted string like "2 red, 1 blue".
## Requirements: AE-PNL-002.
func show_dice_count(dice_text: String) -> void:
	hide_empty_pool_section()
	if _dice_count_label:
		_dice_count_label.text = "Dice: %s" % dice_text
		_dice_count_label.visible = true
	# Done button only in sim mode; attack execution uses Confirm flow.
	if _done_button and not _attack_execution_mode:
		_done_button.visible = true


## Hides the dice count label and Done button (e.g. when target is deselected).
## Also hides all Phase 6b-2 UI sections.
func hide_dice_count() -> void:
	if _dice_count_label:
		_dice_count_label.visible = false
	if _done_button:
		_done_button.visible = false
	hide_cf_dial_section()
	hide_obstruction_section()
	hide_empty_pool_section()
	hide_roll_button()
	hide_dice_results()
	hide_cf_token_section()
	hide_confirm_button()
	hide_skip_attack_button()


## Returns the current dice count text (for testing).
func get_dice_count_text() -> String:
	if _dice_count_label:
		return _dice_count_label.text
	return ""


## Hides and clears the panel.
## Requirements: AS-PNL-003.
func close() -> void:
	visible = false
	_attack_execution_mode = false
	_clear_content()


## Returns the current title text (for testing).
func get_title_text() -> String:
	if _title_label:
		return _title_label.text
	return ""


## Returns the current body text (for testing).
func get_body_text() -> String:
	if _body_label:
		return _body_label.text
	return ""


# =========================================================================
# UI Construction
# =========================================================================

## Schedules a one-frame-deferred layout reset.  Hidden children inflate
## the PanelContainer to ~648 px during the synchronous add_child() pass.
## Godot only excludes them in the deferred layout pass that fires when the
## panel first becomes visible — but on a *reuse* (already shown once) no
## such pass is scheduled automatically.  This helper forces it.
func _request_deferred_layout() -> void:
	call_deferred("_deferred_layout_reset")


## Resets size + offsets on the next frame so the panel shrinks to fit
## only its visible children.
func _deferred_layout_reset() -> void:
	size.y = 0
	offset_top = -40.0
	offset_bottom = -40.0


## Sets bottom-centre anchoring once — must not be called from _build_ui
## to avoid Godot offset recalculation on repeated anchor writes.
func _apply_anchor_position() -> void:
	var vp: Vector2 = Vector2(1280, 720)
	if get_viewport():
		vp = get_viewport().get_visible_rect().size
	var panel_w: float = minf(360.0, vp.x * 0.35)
	custom_minimum_size = Vector2(panel_w, 0.0)
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = - panel_w * 0.5
	offset_right = panel_w * 0.5
	offset_top = -40.0
	offset_bottom = -40.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN


## Builds the panel structure and applies standard modal styling.
func _build_ui() -> void:
	_clear_content()
	# Zero the cached height (prevents the PanelContainer from retaining
	# its old expanded height, e.g. 648 px from a previous attack).  Only
	# reset the vertical component — zeroing width would shrink the panel
	# horizontally, and Godot preserves the left edge, shifting the centre
	# leftward on every reopen.
	size.y = 0
	offset_top = -40.0
	offset_bottom = -40.0
	_build_panel_style()
	_content = _build_content_container()
	add_child(_content)
	_content.add_child(_build_title_body_labels())
	_content.add_child(_build_dice_count_section())
	_content.add_child(_build_cf_dial_section())
	_content.add_child(_build_obstruction_section())
	_content.add_child(_build_empty_pool_section())
	_content.add_child(_build_roll_button())
	_content.add_child(_build_dice_results_section())
	_content.add_child(_build_cf_token_section())
	_content.add_child(_build_confirm_skip_section())
	_content.add_child(_build_accuracy_section())
	_content.add_child(_build_defense_section())
	_content.add_child(_build_redirect_section())
	_content.add_child(_build_damage_info_section())


## Creates and applies the standard modal panel StyleBox.
func _build_panel_style() -> void:
	add_theme_stylebox_override("panel",
			UIStyleHelper.create_modal_panel_style())


## Creates the main VBoxContainer for all panel content.
func _build_content_container() -> VBoxContainer:
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	var _margin_h: float = 32.0 # 16 px content-margin on each side
	content.custom_minimum_size.x = maxf(
			custom_minimum_size.x - _margin_h, 100.0)
	return content


## Creates the title and body text labels.
func _build_title_body_labels() -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section.add_child(_title_label)
	_body_label = Label.new()
	_body_label.add_theme_font_size_override("font_size", 13)
	_body_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(_body_label)
	return section


## Creates the dice count label and Done button (sim mode).
func _build_dice_count_section() -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	_dice_count_label = Label.new()
	_dice_count_label.add_theme_font_size_override("font_size", 14)
	_dice_count_label.add_theme_color_override("font_color",
			Color(0.6, 0.85, 1.0))
	_dice_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_count_label.visible = false
	section.add_child(_dice_count_label)
	_done_button = Button.new()
	_done_button.text = "Done"
	_done_button.custom_minimum_size = Vector2(80.0, 32.0)
	_done_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_done_button.visible = false
	_done_button.pressed.connect(_on_done_pressed)
	section.add_child(_done_button)
	return section


## Creates the Concentrate Fire dial colour-selection section.
func _build_cf_dial_section() -> VBoxContainer:
	_cf_dial_container = VBoxContainer.new()
	_cf_dial_container.add_theme_constant_override("separation", 4)
	_cf_dial_container.visible = false
	var cf_dial_label: Label = Label.new()
	cf_dial_label.text = "CF Dial — add 1 die:"
	cf_dial_label.add_theme_font_size_override("font_size", 13)
	cf_dial_label.add_theme_color_override("font_color",
			Color(1.0, 0.8, 0.3))
	cf_dial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cf_dial_container.add_child(cf_dial_label)
	_cf_dial_buttons = HBoxContainer.new()
	_cf_dial_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_cf_dial_buttons.add_theme_constant_override("separation", 6)
	_cf_dial_container.add_child(_cf_dial_buttons)
	_cf_dial_skip_button = Button.new()
	_cf_dial_skip_button.text = "Skip"
	_cf_dial_skip_button.custom_minimum_size = Vector2(60.0, 28.0)
	_cf_dial_skip_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_cf_dial_skip_button.pressed.connect(_on_cf_dial_skip)
	_cf_dial_container.add_child(_cf_dial_skip_button)
	return _cf_dial_container


## Creates the obstruction die-removal section.
func _build_obstruction_section() -> VBoxContainer:
	_obstruction_container = VBoxContainer.new()
	_obstruction_container.add_theme_constant_override("separation", 4)
	_obstruction_container.visible = false
	var obs_label: Label = Label.new()
	obs_label.text = "Obstructed \u2014 remove 1 die:"
	obs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	obs_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	_obstruction_container.add_child(obs_label)
	_obstruction_buttons = HBoxContainer.new()
	_obstruction_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_obstruction_buttons.add_theme_constant_override("separation", 8)
	_obstruction_container.add_child(_obstruction_buttons)
	return _obstruction_container


## Creates the empty-pool notice section (hidden by default).
func _build_empty_pool_section() -> VBoxContainer:
	_empty_pool_container = VBoxContainer.new()
	_empty_pool_container.add_theme_constant_override("separation", 4)
	_empty_pool_container.visible = false
	var pool_label: Label = Label.new()
	pool_label.text = "No dice in pool \u2014 select a different target"
	pool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pool_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_empty_pool_container.add_child(pool_label)
	return _empty_pool_container


## Creates the Roll Dice button.
func _build_roll_button() -> Button:
	_roll_button = Button.new()
	_roll_button.text = "Roll Dice"
	_roll_button.custom_minimum_size = Vector2(100.0, 32.0)
	_roll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_roll_button.visible = false
	_roll_button.pressed.connect(_on_roll_pressed)
	return _roll_button


## Creates the dice results container and CF token reroll section.
func _build_dice_results_section() -> HBoxContainer:
	_dice_container = HBoxContainer.new()
	_dice_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_dice_container.add_theme_constant_override("separation", 4)
	_dice_container.visible = false
	return _dice_container


## Creates the CF token reroll section (label + reroll/skip buttons).
func _build_cf_token_section() -> VBoxContainer:
	_cf_token_container = VBoxContainer.new()
	_cf_token_container.add_theme_constant_override("separation", 4)
	_cf_token_container.visible = false
	var cf_token_label: Label = Label.new()
	cf_token_label.text = "CF Token — select a die to reroll:"
	cf_token_label.add_theme_font_size_override("font_size", 13)
	cf_token_label.add_theme_color_override("font_color",
			Color(1.0, 0.8, 0.3))
	cf_token_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cf_token_container.add_child(cf_token_label)
	_cf_token_buttons = HBoxContainer.new()
	_cf_token_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_cf_token_buttons.add_theme_constant_override("separation", 6)
	_cf_token_container.add_child(_cf_token_buttons)
	_cf_token_reroll_button = Button.new()
	_cf_token_reroll_button.text = "Reroll"
	_cf_token_reroll_button.custom_minimum_size = Vector2(60.0, 28.0)
	_cf_token_reroll_button.disabled = true
	_cf_token_reroll_button.pressed.connect(_on_cf_token_reroll)
	_cf_token_buttons.add_child(_cf_token_reroll_button)
	_cf_token_skip_button = Button.new()
	_cf_token_skip_button.text = "Skip"
	_cf_token_skip_button.custom_minimum_size = Vector2(60.0, 28.0)
	_cf_token_skip_button.pressed.connect(_on_cf_token_skip)
	_cf_token_buttons.add_child(_cf_token_skip_button)
	return _cf_token_container


## Creates the Confirm button, Skip Attack button, and skip confirmation.
func _build_confirm_skip_section() -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	_confirm_button = Button.new()
	_confirm_button.text = "Confirm"
	_confirm_button.custom_minimum_size = Vector2(100.0, 32.0)
	_confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_confirm_button.visible = false
	_confirm_button.pressed.connect(_on_confirm_pressed)
	section.add_child(_confirm_button)
	_skip_attack_button = Button.new()
	_skip_attack_button.text = "Skip Attack"
	_skip_attack_button.custom_minimum_size = Vector2(100.0, 28.0)
	_skip_attack_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_skip_attack_button.visible = false
	_skip_attack_button.pressed.connect(_on_skip_attack_pressed)
	section.add_child(_skip_attack_button)
	section.add_child(_build_skip_confirm_prompt())
	return section


## Creates the skip-attack confirmation prompt (Yes/No).
func _build_skip_confirm_prompt() -> HBoxContainer:
	_skip_confirm_container = HBoxContainer.new()
	_skip_confirm_container.add_theme_constant_override("separation", 8)
	_skip_confirm_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_skip_confirm_container.visible = false
	var skip_lbl: Label = Label.new()
	skip_lbl.text = "Really skip attack?"
	_skip_confirm_container.add_child(skip_lbl)
	_skip_confirm_yes = Button.new()
	_skip_confirm_yes.text = "Yes"
	_skip_confirm_yes.custom_minimum_size = Vector2(60.0, 28.0)
	_skip_confirm_yes.pressed.connect(_on_skip_confirm_yes)
	_skip_confirm_container.add_child(_skip_confirm_yes)
	_skip_confirm_no = Button.new()
	_skip_confirm_no.text = "No"
	_skip_confirm_no.custom_minimum_size = Vector2(60.0, 28.0)
	_skip_confirm_no.pressed.connect(_on_skip_confirm_no)
	_skip_confirm_container.add_child(_skip_confirm_no)
	return _skip_confirm_container


## Creates the accuracy token-locking section.
func _build_accuracy_section() -> VBoxContainer:
	_accuracy_container = VBoxContainer.new()
	_accuracy_container.add_theme_constant_override("separation", 4)
	_accuracy_container.visible = false
	var acc_label: Label = Label.new()
	acc_label.text = "Accuracy — lock defender tokens:"
	acc_label.add_theme_font_size_override("font_size", 13)
	acc_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	acc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_accuracy_container.add_child(acc_label)
	_accuracy_token_buttons = HBoxContainer.new()
	_accuracy_token_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_accuracy_token_buttons.add_theme_constant_override("separation", 6)
	_accuracy_container.add_child(_accuracy_token_buttons)
	_accuracy_confirm_button = Button.new()
	_accuracy_confirm_button.text = "Confirm Accuracies"
	_accuracy_confirm_button.custom_minimum_size = Vector2(140.0, 28.0)
	_accuracy_confirm_button.size_flags_horizontal = (
			Control.SIZE_SHRINK_CENTER)
	_accuracy_confirm_button.pressed.connect(_on_accuracy_confirm)
	_accuracy_container.add_child(_accuracy_confirm_button)
	return _accuracy_container


## Creates the defense token spending section.
func _build_defense_section() -> VBoxContainer:
	_defense_container = VBoxContainer.new()
	_defense_container.add_theme_constant_override("separation", 4)
	_defense_container.visible = false
	_defense_info_label = Label.new()
	_defense_info_label.add_theme_font_size_override("font_size", 13)
	_defense_info_label.add_theme_color_override("font_color",
			Color(1.0, 0.6, 0.3))
	_defense_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_defense_container.add_child(_defense_info_label)
	_defense_token_buttons = HBoxContainer.new()
	_defense_token_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_defense_token_buttons.add_theme_constant_override("separation", 6)
	_defense_container.add_child(_defense_token_buttons)
	_defense_done_button = Button.new()
	_defense_done_button.text = "Commit Defense"
	_defense_done_button.custom_minimum_size = Vector2(140.0, 28.0)
	_defense_done_button.size_flags_horizontal = (
			Control.SIZE_SHRINK_CENTER)
	_defense_done_button.pressed.connect(_on_defense_done)
	_defense_container.add_child(_defense_done_button)
	return _defense_container


## Creates the redirect zone selection section.
func _build_redirect_section() -> VBoxContainer:
	_redirect_container = VBoxContainer.new()
	_redirect_container.add_theme_constant_override("separation", 4)
	_redirect_container.visible = false
	_redirect_info_label = Label.new()
	_redirect_info_label.text = "Redirect — select adjacent zone:"
	_redirect_info_label.add_theme_font_size_override("font_size", 13)
	_redirect_info_label.add_theme_color_override("font_color",
			Color(0.3, 1.0, 0.6))
	_redirect_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_redirect_container.add_child(_redirect_info_label)
	_redirect_zone_buttons = HBoxContainer.new()
	_redirect_zone_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_redirect_zone_buttons.add_theme_constant_override("separation", 6)
	_redirect_container.add_child(_redirect_zone_buttons)
	_redirect_done_button = Button.new()
	_redirect_done_button.text = "Done Redirecting"
	_redirect_done_button.custom_minimum_size = Vector2(130.0, 28.0)
	_redirect_done_button.size_flags_horizontal = (
			Control.SIZE_SHRINK_CENTER)
	_redirect_done_button.pressed.connect(_on_redirect_done_pressed)
	_redirect_container.add_child(_redirect_done_button)
	return _redirect_container


## Creates the damage resolution info section.
func _build_damage_info_section() -> VBoxContainer:
	_damage_info_container = VBoxContainer.new()
	_damage_info_container.add_theme_constant_override("separation", 4)
	_damage_info_container.visible = false
	_damage_info_label = Label.new()
	_damage_info_label.add_theme_font_size_override("font_size", 13)
	_damage_info_label.add_theme_color_override("font_color",
			Color(1.0, 0.5, 0.5))
	_damage_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_damage_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_damage_info_container.add_child(_damage_info_label)
	return _damage_info_container


## Updates the title and body text.
func _set_prompt(title: String, body: String) -> void:
	if _title_label:
		_title_label.text = title
	if _body_label:
		_body_label.text = body


## Removes all content children.
## Uses remove_child() before queue_free() so the old VBox is excluded
## from PanelContainer's minimum-size computation immediately.
func _clear_content() -> void:
	if _content:
		remove_child(_content)
		_content.queue_free()
	_content = null
	_null_core_widget_refs()
	_null_attack_step_refs()
	_null_defense_step_refs()
	_reset_selection_state()


## Nulls core widget references (title, body, dice count, done, roll, etc.).
func _null_core_widget_refs() -> void:
	_title_label = null
	_body_label = null
	_dice_count_label = null
	_done_button = null
	_roll_button = null
	_dice_container = null
	_confirm_button = null


## Nulls attack-step widget references (CF dial, obstruction, CF token, skip).
func _null_attack_step_refs() -> void:
	_cf_dial_container = null
	_cf_dial_buttons = null
	_cf_dial_skip_button = null
	_obstruction_container = null
	_obstruction_buttons = null
	_empty_pool_container = null
	_cf_token_container = null
	_cf_token_buttons = null
	_cf_token_reroll_button = null
	_cf_token_skip_button = null
	_skip_attack_button = null
	_skip_confirm_container = null
	_skip_confirm_yes = null
	_skip_confirm_no = null


## Nulls defense-step widget references (accuracy, defense, redirect, damage).
func _null_defense_step_refs() -> void:
	_accuracy_container = null
	_accuracy_token_buttons = null
	_accuracy_confirm_button = null
	_defense_container = null
	_defense_token_buttons = null
	_defense_done_button = null
	_defense_info_label = null
	_redirect_container = null
	_redirect_zone_buttons = null
	_redirect_info_label = null
	_redirect_done_button = null
	_damage_info_container = null
	_damage_info_label = null


## Resets selection/state tracking variables.
func _reset_selection_state() -> void:
	_accuracy_locked_indices.clear()
	_accuracy_budget = 0
	_defense_selected_indices.clear()
	_dice_textures.clear()
	_selected_reroll_index = -1


## Called when the Done button is pressed (sim mode).
func _on_done_pressed() -> void:
	SfxManager.play_sfx("skip_beep")
	attack_done_pressed.emit()


# =========================================================================
# Phase 6b-2 — Concentrate Fire Dial
# =========================================================================

## Display colour names for CF dial buttons.
const _CF_COLOUR_DISPLAY: Dictionary = {
	"RED": "Red", "BLUE": "Blue", "BLACK": "Black",
}

## Tint colours for CF dial buttons.
const _CF_COLOUR_TINTS: Dictionary = {
	"RED": Color(0.9, 0.2, 0.2),
	"BLUE": Color(0.2, 0.4, 0.9),
	"BLACK": Color(0.5, 0.5, 0.5),
}


## Shows the Concentrate Fire dial section with colour buttons.
## [param available_colours] — colour keys ("RED", "BLUE", "BLACK") the
##     player may choose from (range-filtered).
## Requirements: AE-CF-001, AE-CF-003.
func show_cf_dial_section(available_colours: Array[String]) -> void:
	if _cf_dial_container == null or _cf_dial_buttons == null:
		return
	# Clear previous buttons.
	for child: Node in _cf_dial_buttons.get_children():
		child.queue_free()
	# Build colour buttons.
	for colour_key: String in available_colours:
		var btn: Button = Button.new()
		btn.text = _CF_COLOUR_DISPLAY.get(colour_key, colour_key)
		btn.custom_minimum_size = Vector2(60.0, 28.0)
		btn.add_theme_color_override("font_color",
				_CF_COLOUR_TINTS.get(colour_key, Color.WHITE))
		btn.pressed.connect(_on_cf_dial_colour.bind(colour_key))
		_cf_dial_buttons.add_child(btn)
	_cf_dial_container.visible = true


## Hides the Concentrate Fire dial section.
func hide_cf_dial_section() -> void:
	if _cf_dial_container:
		_cf_dial_container.visible = false


func _on_cf_dial_colour(colour_key: String) -> void:
	SfxManager.play_sfx("droid_sound")
	cf_dial_colour_selected.emit(colour_key)


func _on_cf_dial_skip() -> void:
	SfxManager.play_sfx("skip_beep")
	cf_dial_skipped.emit()


# =========================================================================
# Phase 6b-2 — Obstruction Die Removal
# =========================================================================

## Shows the obstruction die-colour choice buttons.
## [param available_colours] — colour keys ("RED", "BLUE", "BLACK") the
## attacker may choose from.
## Requirements: AE-OBS-002.
func show_obstruction_die_choice(available_colours: Array[String]) -> void:
	if not _obstruction_buttons or not _obstruction_container:
		return
	# Clear any previous buttons.
	for child: Node in _obstruction_buttons.get_children():
		child.queue_free()
	for colour_key: String in available_colours:
		var btn: Button = Button.new()
		var display: String = _CF_COLOUR_DISPLAY.get(colour_key, colour_key)
		btn.text = display
		btn.custom_minimum_size = Vector2(70.0, 28.0)
		if _CF_COLOUR_TINTS.has(colour_key):
			btn.add_theme_color_override("font_color", _CF_COLOUR_TINTS[colour_key])
		btn.pressed.connect(_on_obstruction_colour.bind(colour_key))
		_obstruction_buttons.add_child(btn)
	_obstruction_container.visible = true


## Shows an auto-skip message when no dice remain to remove.
## Requirements: AE-OBS-003.
func show_obstruction_auto_skip() -> void:
	if not _obstruction_container:
		return
	for child: Node in _obstruction_buttons.get_children():
		child.queue_free()
	var msg: Label = Label.new()
	msg.text = "(no removable dice — skipped)"
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_obstruction_buttons.add_child(msg)
	_obstruction_container.visible = true


## Shows the empty-pool notice when no dice can be added to the pool
## (e.g. target beyond range, or all dice removed by persistent effects).
## Rules Reference: "Attack", Step 1, p.2 — "The attacker must be able
## to add at least one die to the attack pool."
func show_empty_pool_auto_skip() -> void:
	if _empty_pool_container:
		_empty_pool_container.visible = true


## Hides the empty-pool notice section.
func hide_empty_pool_section() -> void:
	if _empty_pool_container:
		_empty_pool_container.visible = false


## Hides the obstruction section.
func hide_obstruction_section() -> void:
	if _obstruction_container:
		_obstruction_container.visible = false


func _on_obstruction_colour(colour_key: String) -> void:
	SfxManager.play_sfx("droid_sound")
	obstruction_die_selected.emit(colour_key)


# =========================================================================
# Phase 6b-2 — Dice Rolling
# =========================================================================

## Shows the "Roll Dice" button.
## Requirements: AE-DICE-001.
func show_roll_button() -> void:
	if _roll_button:
		_roll_button.visible = true


## Hides the "Roll Dice" button.
func hide_roll_button() -> void:
	if _roll_button:
		_roll_button.visible = false


## Shows the dice roll results as PNG images.
## [param results] — Array of {color: DiceColor, face: DiceFace}.
## Requirements: AE-DICE-002.
func show_dice_results(results: Array[Dictionary]) -> void:
	if _dice_container == null:
		return
	_clear_dice_images()
	_dice_textures.clear()
	_selected_reroll_index = -1
	for i: int in range(results.size()):
		var result: Dictionary = results[i]
		var color: Constants.DiceColor = (
				result["color"] as Constants.DiceColor)
		var face: Constants.DiceFace = (
				result["face"] as Constants.DiceFace)
		var tex_rect: TextureRect = _create_die_image(color, face, i)
		_dice_container.add_child(tex_rect)
		_dice_textures.append(tex_rect)
	_dice_container.visible = true


## Updates a single die image after a reroll.
## [param die_index] — index in the results array.
## [param new_result] — {color: DiceColor, face: DiceFace}.
## Requirements: AE-CF-014.
func update_die_result(die_index: int, new_result: Dictionary) -> void:
	if die_index < 0 or die_index >= _dice_textures.size():
		return
	var color: Constants.DiceColor = (
			new_result["color"] as Constants.DiceColor)
	var face: Constants.DiceFace = (
			new_result["face"] as Constants.DiceFace)
	var path: String = Dice.get_face_image_path(color, face)
	var tex: Texture2D = load(path) as Texture2D
	if tex and _dice_textures[die_index]:
		_dice_textures[die_index].texture = tex
	_selected_reroll_index = -1
	_clear_die_selection_highlights()


## Hides dice result images.
func hide_dice_results() -> void:
	if _dice_container:
		_clear_dice_images()
		_dice_container.visible = false
	_dice_textures.clear()


func _on_roll_pressed() -> void:
	roll_dice_pressed.emit()


# =========================================================================
# Phase 6b-2 — CF Token Reroll
# =========================================================================

## Shows the CF token reroll section.  Die images become clickable.
## Requirements: AE-CF-010.
func show_cf_token_section() -> void:
	if _cf_token_container == null:
		return
	_selected_reroll_index = -1
	_cf_token_container.visible = true
	if _cf_token_reroll_button:
		_cf_token_reroll_button.disabled = true
	_set_dice_clickable(true)


## Hides the CF token reroll section.
func hide_cf_token_section() -> void:
	if _cf_token_container:
		_cf_token_container.visible = false
	_set_dice_clickable(false)
	_selected_reroll_index = -1
	_clear_die_selection_highlights()


## Returns the currently selected reroll die index (for testing).
func get_selected_reroll_index() -> int:
	return _selected_reroll_index


func _on_cf_token_reroll() -> void:
	if _selected_reroll_index >= 0:
		SfxManager.play_sfx("droid_sound")
		cf_token_reroll_requested.emit(_selected_reroll_index)


func _on_cf_token_skip() -> void:
	SfxManager.play_sfx("skip_beep")
	cf_token_reroll_skipped.emit()


# =========================================================================
# Phase 6b-2 — Confirm / Skip Attack
# =========================================================================

## Shows the "Confirm" button.
## Requirements: AE-CONF-001.
func show_confirm_button() -> void:
	if _confirm_button:
		_confirm_button.visible = true


## Hides the "Confirm" button.
func hide_confirm_button() -> void:
	if _confirm_button:
		_confirm_button.visible = false


## Shows the "Skip Attack" button (resets any pending confirmation).
## Requirements: AE-SKIP-001.
func show_skip_attack_button() -> void:
	_hide_skip_confirm()
	if _skip_attack_button:
		_skip_attack_button.visible = true


## Hides the "Skip Attack" button and any pending confirmation.
func hide_skip_attack_button() -> void:
	_hide_skip_confirm()
	if _skip_attack_button:
		_skip_attack_button.visible = false


func _on_confirm_pressed() -> void:
	SfxManager.play_sfx("droid_sound")
	confirm_pressed.emit()


## Shows the "Really skip attack?" confirmation instead of
## emitting immediately.
func _on_skip_attack_pressed() -> void:
	SfxManager.play_sfx("skip_beep")
	if _skip_attack_button:
		_skip_attack_button.visible = false
	if _skip_confirm_container:
		_skip_confirm_container.visible = true


## Player confirmed the skip.
func _on_skip_confirm_yes() -> void:
	SfxManager.play_sfx("skip_beep")
	_hide_skip_confirm()
	skip_attack_pressed.emit()


## Player cancelled the skip — restore the Skip Attack button.
func _on_skip_confirm_no() -> void:
	SfxManager.play_sfx("skip_beep")
	_hide_skip_confirm()
	if _skip_attack_button:
		_skip_attack_button.visible = true


## Hides the skip-attack confirmation prompt.
func _hide_skip_confirm() -> void:
	if _skip_confirm_container:
		_skip_confirm_container.visible = false


# =========================================================================
# Phase 6c-1 — Accuracy Spending
# =========================================================================

## Defence token image base path.
const _TOKEN_IMAGE_BASE: String = (
		"res://Resources/Game_Components/defense_tokens/")

## Maps DefenseToken enum to filename fragment.
const _TOKEN_FILE_NAMES: Dictionary = {
	Constants.DefenseToken.EVADE: "evade",
	Constants.DefenseToken.REDIRECT: "redirect",
	Constants.DefenseToken.BRACE: "brace",
	Constants.DefenseToken.SCATTER: "scatter",
	Constants.DefenseToken.CONTAIN: "contain",
	Constants.DefenseToken.SALVO: "salvo",
}

## Token image size in pixels.
const _TOKEN_IMAGE_SIZE: float = 28.0


## Shows the accuracy spending section with the defender's defense tokens.
## [param tokens] — Array of {type: DefenseToken, state: DefenseTokenState}.
## [param accuracy_count] — number of accuracy icons in the dice pool.
## Requirements: AE-ACC-001–004.
func show_accuracy_section(tokens: Array[Dictionary],
		accuracy_count: int) -> void:
	if _accuracy_container == null or _accuracy_token_buttons == null:
		return
	_accuracy_locked_indices.clear()
	_accuracy_budget = accuracy_count
	# Clear old buttons.
	for child: Node in _accuracy_token_buttons.get_children():
		child.queue_free()
	# Build token buttons.
	for i: int in range(tokens.size()):
		var token: Dictionary = tokens[i]
		var state: Constants.DefenseTokenState = (
				token["state"] as Constants.DefenseTokenState)
		if state == Constants.DefenseTokenState.DISCARDED:
			continue
		var btn: Button = _create_token_button(token, i)
		btn.pressed.connect(_on_accuracy_token_pressed.bind(i))
		_accuracy_token_buttons.add_child(btn)
	_accuracy_container.visible = true


## Hides the accuracy section.
func hide_accuracy_section() -> void:
	if _accuracy_container:
		_accuracy_container.visible = false
	_accuracy_locked_indices.clear()
	_accuracy_budget = 0


## Returns currently locked token indices (for testing).
func get_accuracy_locked_indices() -> Array[int]:
	return _accuracy_locked_indices.duplicate()


func _on_accuracy_token_pressed(token_index: int) -> void:
	# Toggle lock state.
	if token_index in _accuracy_locked_indices:
		_accuracy_locked_indices.erase(token_index)
	else:
		if _accuracy_locked_indices.size() >= _accuracy_budget:
			return # All accuracy icons used
		_accuracy_locked_indices.append(token_index)
	# Update button visuals.
	_update_accuracy_button_visuals()
	accuracy_token_toggled.emit(token_index)


func _on_accuracy_confirm() -> void:
	SfxManager.play_sfx("droid_sound")
	accuracy_confirmed.emit()


## Refreshes the visual state of accuracy token buttons.
func _update_accuracy_button_visuals() -> void:
	if _accuracy_token_buttons == null:
		return
	for child: Node in _accuracy_token_buttons.get_children():
		var btn: Button = child as Button
		if btn == null:
			continue
		var idx: int = btn.get_meta("token_index", -1)
		if idx in _accuracy_locked_indices:
			btn.modulate = Color(0.5, 0.5, 0.5, 1.0)
			btn.text = btn.get_meta("base_text", "") + " [LOCKED]"
		else:
			btn.modulate = Color.WHITE
			btn.text = btn.get_meta("base_text", "")


# =========================================================================
# Phase 6c-2 — Defense Token Spending
# =========================================================================

## Shows the defense token spending section.
## [param tokens] — defender's defense tokens with states.
## [param locked_indices] — token indices locked by accuracy.
## [param damage] — current unmodified damage from dice.
## [param defender_speed] — defender's speed (0 blocks spending).
## Requirements: AE-DEF-001–005.
## Rules Reference: "Defense Tokens", bullet 4, p.5 — speed 0 blocks all.
func show_defense_section(tokens: Array[Dictionary],
		locked_indices: Array[int], damage: int,
		defender_speed: int) -> void:
	if _defense_container == null or _defense_token_buttons == null:
		return
	# Reset selection state.
	_defense_selected_indices.clear()
	# Clear old buttons.
	for child: Node in _defense_token_buttons.get_children():
		child.queue_free()
	# Update info label.
	if _defense_info_label:
		_defense_info_label.text = "Damage: %d — Spend tokens:" % damage
	# Speed 0 check.
	if defender_speed == 0:
		if _defense_info_label:
			_defense_info_label.text = (
					"Damage: %d — Speed 0: cannot spend tokens." % damage)
		_defense_container.visible = true
		return
	_populate_defense_token_buttons(tokens, locked_indices)
	# Re-show Commit button (may have been hidden during a previous commit).
	if _defense_done_button:
		_defense_done_button.visible = true
		_defense_done_button.text = "Commit Defense"
	_defense_container.visible = true


## Populates _defense_token_buttons with one button per non-discarded token.
func _populate_defense_token_buttons(tokens: Array[Dictionary],
		locked_indices: Array[int]) -> void:
	for i: int in range(tokens.size()):
		var token: Dictionary = tokens[i]
		var state: Constants.DefenseTokenState = (
				token["state"] as Constants.DefenseTokenState)
		if state == Constants.DefenseTokenState.DISCARDED:
			continue
		if i in locked_indices:
			# Show locked token (greyed out, not clickable).
			var btn: Button = _create_token_button(token, i)
			btn.disabled = true
			btn.modulate = Color(0.4, 0.4, 0.4, 1.0)
			btn.text = btn.get_meta("base_text", "") + " [LOCKED]"
			_defense_token_buttons.add_child(btn)
			continue
		var btn: Button = _create_token_button(token, i)
		btn.pressed.connect(_on_defense_token_pressed.bind(i))
		_defense_token_buttons.add_child(btn)


## Hides the defense section.
func hide_defense_section() -> void:
	if _defense_container:
		_defense_container.visible = false


## Updates the damage display during defense modifications.
## When [param brace_pending] is true, shows a "(Brace pending)" hint.
func update_defense_damage(damage: int, brace_pending: bool = false) -> void:
	if _defense_info_label:
		if brace_pending:
			var braced: int = ceili(float(damage) / 2.0)
			_defense_info_label.text = (
					"Modified damage: %d (Brace pending → %d)" % [
					damage, braced])
		else:
			_defense_info_label.text = "Modified damage: %d" % damage


## Disables a defense token button after it's been spent.
func disable_defense_token_button(token_index: int) -> void:
	if _defense_token_buttons == null:
		return
	for child: Node in _defense_token_buttons.get_children():
		var btn: Button = child as Button
		if btn and btn.get_meta("token_index", -1) == token_index:
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5, 0.7)
			break


## Toggles a defense token's selection state.
## If another token of the same type is already selected, it is
## deselected first (only one of each type per attack).
## Rules Reference: "Defense Tokens", bullet 3, p.5.
func _on_defense_token_pressed(token_index: int) -> void:
	if token_index in _defense_selected_indices:
		_defense_selected_indices.erase(token_index)
		_set_defense_token_highlight(token_index, false)
	else:
		# Enforce one token per type: deselect any same-type token.
		var new_type: int = _get_defense_token_type(token_index)
		for sel_i: int in _defense_selected_indices.duplicate():
			if _get_defense_token_type(sel_i) == new_type:
				_defense_selected_indices.erase(sel_i)
				_set_defense_token_highlight(sel_i, false)
		_defense_selected_indices.append(token_index)
		_set_defense_token_highlight(token_index, true)


## Returns the token type for a defense button by its token index.
func _get_defense_token_type(token_index: int) -> int:
	if _defense_token_buttons == null:
		return -1
	for child: Node in _defense_token_buttons.get_children():
		var btn: Button = child as Button
		if btn and btn.get_meta("token_index", -1) == token_index:
			return btn.get_meta("token_type", -1) as int
	return -1


## Applies or removes the visual highlight on a defense token button.
func _set_defense_token_highlight(token_index: int,
		selected: bool) -> void:
	if _defense_token_buttons == null:
		return
	for child: Node in _defense_token_buttons.get_children():
		var btn: Button = child as Button
		if btn and btn.get_meta("token_index", -1) == token_index:
			if selected:
				btn.modulate = Color(0.3, 1.0, 0.3, 1.0)
				btn.text = btn.get_meta("base_text", "") + " ✓"
			else:
				# Restore original modulate (exhausted = orange, else white).
				var token_state: int = btn.get_meta("token_state", 0)
				if token_state == Constants.DefenseTokenState.EXHAUSTED:
					btn.modulate = Color(1.0, 0.7, 0.3, 1.0)
				else:
					btn.modulate = Color.WHITE
				btn.text = btn.get_meta("base_text", "")
			break


## Returns the list of defense token indices currently selected.
func get_defense_selected_indices() -> Array[int]:
	return _defense_selected_indices.duplicate()


## Disables all defense token buttons (used during commit processing).
func disable_all_defense_buttons() -> void:
	if _defense_token_buttons:
		for child: Node in _defense_token_buttons.get_children():
			var btn: Button = child as Button
			if btn:
				btn.disabled = true
	if _defense_done_button:
		_defense_done_button.visible = false


## Enters evade die-selection mode — dice become clickable and the prompt
## instructs the defender to pick a die to remove (long) or reroll (med/close).
## Requirements: AE-DEF-007–009.
## Rules Reference: "Evade", RRG v1.5.0, p.5.
func show_evade_die_selection(range_band: String) -> void:
	_evade_mode = true
	_set_dice_clickable(true)
	_clear_die_selection_highlights()
	# Tint dice cyan to show they are selectable.
	for tex_rect: TextureRect in _dice_textures:
		if tex_rect:
			tex_rect.modulate = Color(0.7, 1.0, 1.0, 1.0)
	if _defense_info_label:
		if range_band == Constants.RANGE_BAND_LONG:
			_defense_info_label.text += "\nEvade: click a die to remove."
		else:
			_defense_info_label.text += "\nEvade: click a die to reroll."


## Exits evade die-selection mode — dice return to non-clickable.
func hide_evade_die_selection() -> void:
	_evade_mode = false
	_set_dice_clickable(false)
	_clear_die_selection_highlights()


func _on_defense_done() -> void:
	SfxManager.play_sfx("droid_sound")
	defense_tokens_done.emit()


func _on_redirect_done_pressed() -> void:
	SfxManager.play_sfx("droid_sound")
	redirect_done_pressed.emit()


# =========================================================================
# Phase 6c-2 — Redirect Zone Selection
# =========================================================================

## Shows the redirect zone selection with buttons for adjacent zones.
## [param zones] — Array of Constants.HullZone values that are adjacent.
## [param remaining] — damage points still to redirect.
## Requirements: AE-DEF-011–013.
func show_redirect_section(zones: Array, remaining: int) -> void:
	if _redirect_container == null or _redirect_zone_buttons == null:
		return
	for child: Node in _redirect_zone_buttons.get_children():
		child.queue_free()
	if _redirect_info_label:
		_redirect_info_label.text = (
				"Redirect %d damage — select zone:" % remaining)
	for zone: Variant in zones:
		var zone_enum: Constants.HullZone = zone as Constants.HullZone
		var zone_name: String = Constants.hull_zone_to_string(zone_enum)
		var btn: Button = Button.new()
		btn.text = zone_name
		btn.custom_minimum_size = Vector2(70.0, 28.0)
		btn.pressed.connect(_on_redirect_zone_pressed.bind(
				zone_enum as int))
		_redirect_zone_buttons.add_child(btn)
	_redirect_container.visible = true


## Updates the redirect info label with remaining budget.
func update_redirect_remaining(remaining: int) -> void:
	if _redirect_info_label:
		_redirect_info_label.text = (
				"Redirect %d remaining — select zone:" % remaining)


## Hides the redirect section.
func hide_redirect_section() -> void:
	if _redirect_container:
		_redirect_container.visible = false


func _on_redirect_zone_pressed(zone: int) -> void:
	redirect_zone_selected.emit(zone)


# =========================================================================
# Phase 6c-3 — Damage Resolution Info
# =========================================================================

## Shows the damage resolution info.
## [param text] — damage summary text.
func show_damage_info(text: String) -> void:
	if _damage_info_container and _damage_info_label:
		_damage_info_label.text = text
		_damage_info_container.visible = true


## Hides the damage info.
func hide_damage_info() -> void:
	if _damage_info_container:
		_damage_info_container.visible = false


# =========================================================================
# Die Image Helpers
# =========================================================================

## Creates a TextureRect for a single die face image.
func _create_die_image(color: Constants.DiceColor,
		face: Constants.DiceFace, index: int) -> TextureRect:
	var path: String = Dice.get_face_image_path(color, face)
	var tex: Texture2D = load(path) as Texture2D
	var rect: TextureRect = TextureRect.new()
	rect.texture = tex
	rect.custom_minimum_size = Vector2(_DIE_IMAGE_SIZE, _DIE_IMAGE_SIZE)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_meta("die_index", index)
	return rect


## Clears all die image children from the container.
func _clear_dice_images() -> void:
	if _dice_container:
		for child: Node in _dice_container.get_children():
			child.queue_free()


## Enables or disables click handling on die images.
func _set_dice_clickable(clickable: bool) -> void:
	for tex_rect: TextureRect in _dice_textures:
		if tex_rect == null:
			continue
		if clickable:
			if not tex_rect.gui_input.is_connected(_on_die_clicked):
				tex_rect.gui_input.connect(
						_on_die_clicked.bind(tex_rect))
			tex_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			if tex_rect.gui_input.is_connected(_on_die_clicked):
				tex_rect.gui_input.disconnect(
						_on_die_clicked.bind(tex_rect))
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Called when a die image is clicked during reroll or evade selection.
func _on_die_clicked(event: InputEvent,
		tex_rect: TextureRect) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var index: int = tex_rect.get_meta("die_index", -1)
	if index < 0:
		return
	if _evade_mode:
		# Evade: immediate confirm on click.
		_clear_die_selection_highlights()
		tex_rect.modulate = Color(1.0, 1.0, 0.5, 1.0)
		evade_die_confirmed.emit(index)
		return
	_selected_reroll_index = index
	_clear_die_selection_highlights()
	tex_rect.modulate = Color(1.0, 1.0, 0.5, 1.0)
	if _cf_token_reroll_button:
		_cf_token_reroll_button.disabled = false


## Resets all die images to default modulate.
func _clear_die_selection_highlights() -> void:
	for tex_rect: TextureRect in _dice_textures:
		if tex_rect:
			tex_rect.modulate = Color.WHITE


# =========================================================================
# Token Button Helpers
# =========================================================================

## Creates a Button representing a defense token with icon and text.
## Stores metadata: "token_index", "token_type", "token_state", "base_text".
func _create_token_button(token: Dictionary, index: int) -> Button:
	var token_type: Constants.DefenseToken = (
			token["type"] as Constants.DefenseToken)
	var state: Constants.DefenseTokenState = (
			token["state"] as Constants.DefenseTokenState)
	var type_name: String = Constants.DEFENSE_TOKEN_NAMES.get(
			token_type, "?")
	var state_suffix: String = ""
	match state:
		Constants.DefenseTokenState.EXHAUSTED:
			state_suffix = " (E)"
		Constants.DefenseTokenState.DISCARDED:
			state_suffix = " (D)"
	var label_text: String = type_name + state_suffix
	var btn: Button = Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(80.0, 28.0)
	btn.set_meta("token_index", index)
	btn.set_meta("token_type", token_type)
	btn.set_meta("token_state", int(state))
	btn.set_meta("base_text", label_text)
	# Tint exhausted tokens orange.
	if state == Constants.DefenseTokenState.EXHAUSTED:
		btn.modulate = Color(1.0, 0.7, 0.3, 1.0)
	return btn
