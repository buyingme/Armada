## AttackInfoPanel
##
## Floating panel displayed during the attack sequence. Shows the current
## attack state, dice pool (with PNG graphics), context-sensitive prompts,
## and action buttons for each step.
##
## Styled per .skills/ui_styling.md — identical to ActivationModal / CommandDialPicker.
## Positioned at centre of the viewport.
##
## Requirements: ATK-UI-001, ATK-UI-002.
class_name AttackInfoPanel
extends PanelContainer


## Emitted when the player chooses to add a CF dial die.
## [param colour] — "RED", "BLUE", or "BLACK".
signal cf_die_requested(colour: String)

## Emitted when the player skips the CF dial prompt.
signal cf_dial_skipped()

## Emitted when the player clicks "Roll Dice".
signal roll_requested()

## Emitted when the player clicks "Skip Attack" / "Done".
signal skip_requested()

## Emitted when the player clicks "Finish Step" to advance.
signal finish_step_requested()

## Emitted when the player clicks a defense token button.
## [param token_index] — index in the defender's token array.
signal defense_token_selected(token_index: int)

## Emitted when the player confirms damage / acknowledges result.
signal damage_acknowledged()

## Emitted when the player wants to attack another squadron (Step 6).
signal additional_target_requested()

## Emitted when the player clicks "Next Attack" after one attack is done.
signal next_attack_requested()

## Emitted when the player skips remaining attacks.
signal all_attacks_done_requested()


## Panel minimum size.
const PANEL_MIN_SIZE: Vector2 = Vector2(420, 260)

## Dice PNG base path.
const DICE_PATH: String = "dice/"

## Defense token PNG base path.
const TOKEN_PATH: String = "defense_tokens/"

## Mapping: {DiceColor}_{DiceFace} -> filename.
const DICE_FACE_FILES: Dictionary = {
	"RED_BLANK": "die_red_blank.png",
	"RED_HIT": "die_red_hit.png",
	"RED_CRITICAL": "die_red_crit.png",
	"RED_HIT_HIT": "die_red_hit_hit.png",
	"RED_ACCURACY": "die_red_accuracy.png",
	"BLUE_HIT": "die_blue_hit.png",
	"BLUE_CRITICAL": "die_blue_crit.png",
	"BLUE_ACCURACY": "die_blue_accuracy.png",
	"BLACK_BLANK": "die_black_blank.png",
	"BLACK_HIT": "die_black_hit.png",
	"BLACK_CRITICAL": "die_black_crit.png",
	"BLACK_HIT_CRITICAL": "die_black_hit_crit.png",
}

## Logger.
var _log: GameLogger = GameLogger.new("AttackInfoPanel")

## State reference.
var _attack_state: AttackSequenceState = null

## UI elements.
var _title_label: Label = null
var _prompt_label: Label = null
var _dice_container: HBoxContainer = null
var _button_container: HBoxContainer = null
var _info_label: Label = null
var _defense_container: HBoxContainer = null

## Whether dice images are available.
var _dice_images_available: bool = false


func _init() -> void:
	visible = false
	custom_minimum_size = PANEL_MIN_SIZE


## Opens the panel for the given attack sequence state.
func open(attack_state: AttackSequenceState) -> void:
	_attack_state = attack_state
	_build_ui()
	visible = true
	set_process_unhandled_input(true)
	update_display()
	_log.info("Attack info panel opened.")


## Closes and hides the panel.
func close() -> void:
	visible = false
	set_process_unhandled_input(false)
	_attack_state = null
	_clear_ui()
	_log.info("Attack info panel closed.")


## Updates the panel display to reflect the current attack state.
func update_display() -> void:
	if _attack_state == null:
		return
	_clear_buttons()
	_clear_dice_display()
	_clear_defense_display()

	var state: AttackSequenceState.State = _attack_state.get_state()
	match state:
		AttackSequenceState.State.HULL_ZONE_SELECT:
			_show_hull_zone_select()
		AttackSequenceState.State.TARGET_SELECT:
			_show_target_select()
		AttackSequenceState.State.DICE_POOL_PREVIEW:
			_show_dice_pool_preview()
		AttackSequenceState.State.ROLL_DICE:
			_show_roll_dice()
		AttackSequenceState.State.ATTACK_EFFECTS:
			_show_attack_effects()
		AttackSequenceState.State.DEFENSE_TOKENS:
			_show_defense_tokens()
		AttackSequenceState.State.RESOLVE_DAMAGE:
			_show_resolve_damage()
		AttackSequenceState.State.ADDITIONAL_SQUAD_TARGET:
			_show_additional_squad_target()
		AttackSequenceState.State.ATTACK_COMPLETE:
			_show_attack_complete()
		AttackSequenceState.State.ALL_ATTACKS_DONE:
			_show_all_attacks_done()


## Escape key dismisses the panel.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			skip_requested.emit()
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------


## Builds the panel UI from scratch.
func _build_ui() -> void:
	_clear_ui()

	# Panel style (ui_styling.md §1).
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.border_color = Color(0.4, 0.5, 0.7, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)

	# Margins (ui_styling.md §3).
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Title label.
	_title_label = Label.new()
	_title_label.text = "Attack"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_title_label)

	var sep1: HSeparator = HSeparator.new()
	vbox.add_child(sep1)

	# Prompt label.
	_prompt_label = Label.new()
	_prompt_label.text = ""
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_prompt_label)

	# Dice display container.
	_dice_container = HBoxContainer.new()
	_dice_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_dice_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_dice_container)

	# Defense token display container.
	_defense_container = HBoxContainer.new()
	_defense_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_defense_container.add_theme_constant_override("separation", 8)
	_defense_container.visible = false
	vbox.add_child(_defense_container)

	# Info label (damage summary, etc).
	_info_label = Label.new()
	_info_label.text = ""
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_info_label)

	var sep2: HSeparator = HSeparator.new()
	vbox.add_child(sep2)

	# Button container.
	_button_container = HBoxContainer.new()
	_button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_button_container)

	# Check if dice images are available.
	var test_tex: Texture2D = AssetLoader.load_texture(DICE_PATH,
			"die_red_hit.png")
	_dice_images_available = test_tex != null


## Clears all UI children.
func _clear_ui() -> void:
	for child: Node in get_children():
		child.queue_free()
	_title_label = null
	_prompt_label = null
	_dice_container = null
	_button_container = null
	_info_label = null
	_defense_container = null


## Clears buttons.
func _clear_buttons() -> void:
	if _button_container == null:
		return
	for child: Node in _button_container.get_children():
		child.queue_free()


## Clears dice display.
func _clear_dice_display() -> void:
	if _dice_container == null:
		return
	for child: Node in _dice_container.get_children():
		child.queue_free()


## Clears defense token display.
func _clear_defense_display() -> void:
	if _defense_container == null:
		return
	for child: Node in _defense_container.get_children():
		child.queue_free()
	_defense_container.visible = false


# ---------------------------------------------------------------------------
# State-specific displays
# ---------------------------------------------------------------------------


## HULL_ZONE_SELECT — prompt to pick an attacking hull zone.
func _show_hull_zone_select() -> void:
	var ship_name: String = _get_attacker_name()
	_title_label.text = "Attack — %s" % ship_name
	_prompt_label.text = "Select an attacking hull zone."
	_info_label.text = _format_used_zones()
	_add_button("Skip All Attacks", _on_skip_all_pressed)


## TARGET_SELECT — prompt to pick a target.
func _show_target_select() -> void:
	var zone_name: String = _zone_name(_attack_state.get_attacking_zone())
	_title_label.text = "Attack — %s (%s)" % [_get_attacker_name(), zone_name]
	_prompt_label.text = "Select a target ship or squadron."
	_info_label.text = ""
	_add_button("Change Zone", _on_change_zone_pressed)
	_add_button("Skip Attack", _on_skip_all_pressed)


## DICE_POOL_PREVIEW — show gathered dice, CF dial prompt if available.
func _show_dice_pool_preview() -> void:
	var zone_name: String = _zone_name(_attack_state.get_attacking_zone())
	var target_name: String = _get_target_name()
	_title_label.text = "%s (%s) → %s" % [_get_attacker_name(),
			zone_name, target_name]

	_show_dice_pool_graphics(false)

	if _attack_state.should_show_cf_dial_prompt():
		_prompt_label.text = "Add a die from Concentrate Fire dial?"
		var colours: Array[String] = _attack_state.get_dice_pool() \
				.get_available_colours()
		for colour: String in colours:
			_add_button("+ %s" % colour,
					_on_cf_die_pressed.bind(colour))
		_add_button("Skip CF", _on_cf_skip_pressed)
	else:
		_prompt_label.text = "Dice pool ready."
		_add_button("Roll Dice ►", _on_roll_pressed)


## ROLL_DICE — (transient, immediately goes to ATTACK_EFFECTS)
func _show_roll_dice() -> void:
	_prompt_label.text = "Rolling dice..."


## ATTACK_EFFECTS — show rolled dice, CF token reroll, accuracy spending.
func _show_attack_effects() -> void:
	_title_label.text = "Step 3: Resolve Attack Effects"
	_prompt_label.text = "Spend accuracies or use CF token reroll."
	_show_dice_pool_graphics(true)
	_show_damage_summary()
	_add_button("Done ►", _on_finish_effects_pressed)


## DEFENSE_TOKENS — show defender's spendable tokens.
func _show_defense_tokens() -> void:
	_title_label.text = "Step 4: Spend Defense Tokens"
	_prompt_label.text = "Defender may spend defense tokens."
	_show_dice_pool_graphics(true)
	_show_defender_tokens()
	_show_damage_summary()
	_add_button("Done ►", _on_finish_defense_pressed)


## RESOLVE_DAMAGE — show damage result.
func _show_resolve_damage() -> void:
	_title_label.text = "Step 5: Resolve Damage"
	var result: DamageResolver.DamageResult = \
			_attack_state.get_last_damage_result()
	if result:
		_prompt_label.text = _format_damage_result(result)
	else:
		_prompt_label.text = "No damage dealt."
	_show_dice_pool_graphics(true)
	_add_button("Continue ►", _on_damage_acknowledged)


## ADDITIONAL_SQUAD_TARGET — offer Step 6.
func _show_additional_squad_target() -> void:
	_title_label.text = "Step 6: Additional Squadron Target"
	_prompt_label.text = "Select another squadron, or skip."
	_info_label.text = ""
	_add_button("Select Target", _on_additional_target_pressed)
	_add_button("Skip", _on_finish_effects_pressed)


## ATTACK_COMPLETE — one attack done.
func _show_attack_complete() -> void:
	_title_label.text = "Attack Complete"
	var attacks: int = _attack_state.get_activation_state() \
			.get_attacks_performed()
	_prompt_label.text = "Attacks performed: %d" % attacks
	_info_label.text = ""
	if _attack_state.get_activation_state().can_attack_again():
		_add_button("Next Attack ►", _on_next_attack_pressed)
		_add_button("Skip Remaining", _on_skip_all_pressed)
	else:
		_add_button("Done ►", _on_all_done_pressed)


## ALL_ATTACKS_DONE — both attacks finished.
func _show_all_attacks_done() -> void:
	_title_label.text = "All Attacks Complete"
	_prompt_label.text = "Proceeding to maneuver."
	_info_label.text = ""
	_add_button("Continue ►", _on_all_done_pressed)


# ---------------------------------------------------------------------------
# Dice display
# ---------------------------------------------------------------------------


## Displays the dice pool as PNG images or text fallback.
func _show_dice_pool_graphics(show_faces: bool) -> void:
	_clear_dice_display()
	var pool: AttackDicePool = _attack_state.get_dice_pool()
	if show_faces:
		# Show rolled results.
		var results: Array[Dictionary] = pool.get_results()
		for i: int in range(results.size()):
			var die: Dictionary = results[i]
			var removed: bool = die.get("removed", false)
			if removed:
				continue
			_add_die_visual(die, i)
	else:
		# Show gathered pool (before rolling).
		var gathered: Dictionary = pool.get_gathered_pool()
		for colour_key: int in gathered:
			var count: int = gathered[colour_key]
			var colour_name: String = Constants.DiceColor.keys()[colour_key]
			for _j: int in range(count):
				_add_die_placeholder(colour_name)


## Adds a single die visual (rolled face).
func _add_die_visual(die: Dictionary, index: int) -> void:
	var colour: int = int(die.get("color", 0))
	var face: int = int(die.get("face", 0))
	var colour_name: String = Constants.DiceColor.keys()[colour]
	var face_name: String = Constants.DiceFace.keys()[face]
	var key: String = "%s_%s" % [colour_name, face_name]

	if _dice_images_available and key in DICE_FACE_FILES:
		var tex: Texture2D = AssetLoader.load_texture(DICE_PATH,
				DICE_FACE_FILES[key])
		if tex:
			var rect: TextureRect = TextureRect.new()
			rect.texture = tex
			rect.custom_minimum_size = Vector2(40, 40)
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.tooltip_text = "%s %s (die %d)" % [colour_name,
					face_name, index]
			_dice_container.add_child(rect)
			return

	# Text fallback.
	var lbl: Label = Label.new()
	lbl.text = "[%s:%s]" % [colour_name.left(1), face_name.left(3)]
	lbl.add_theme_font_size_override("font_size", 12)
	_apply_die_colour(lbl, colour_name)
	_dice_container.add_child(lbl)


## Adds a placeholder die (before rolling).
func _add_die_placeholder(colour_name: String) -> void:
	if _dice_images_available:
		# Show the blank face as a placeholder.
		var blank_key: String = "%s_BLANK" % colour_name
		if blank_key in DICE_FACE_FILES:
			var tex: Texture2D = AssetLoader.load_texture(DICE_PATH,
					DICE_FACE_FILES[blank_key])
			if tex:
				var rect: TextureRect = TextureRect.new()
				rect.texture = tex
				rect.custom_minimum_size = Vector2(40, 40)
				rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				rect.modulate = Color(1, 1, 1, 0.5)
				_dice_container.add_child(rect)
				return

	var lbl: Label = Label.new()
	lbl.text = "[%s]" % colour_name.left(1)
	lbl.add_theme_font_size_override("font_size", 12)
	_apply_die_colour(lbl, colour_name)
	lbl.modulate = Color(1, 1, 1, 0.5)
	_dice_container.add_child(lbl)


## Applies die colour tinting to a label.
func _apply_die_colour(lbl: Label, colour_name: String) -> void:
	match colour_name:
		"RED":
			lbl.add_theme_color_override("font_color",
					Color(0.9, 0.3, 0.3))
		"BLUE":
			lbl.add_theme_color_override("font_color",
					Color(0.3, 0.5, 0.9))
		"BLACK":
			lbl.add_theme_color_override("font_color",
					Color(0.7, 0.7, 0.7))


# ---------------------------------------------------------------------------
# Defense token display
# ---------------------------------------------------------------------------


## Shows the defender's spendable defense tokens as buttons.
func _show_defender_tokens() -> void:
	_clear_defense_display()
	_defense_container.visible = true

	var spendable: Array[int] = _attack_state.get_defender_spendable_tokens()
	var tokens: Array[Dictionary] = _get_defender_defense_tokens()

	for i: int in range(tokens.size()):
		var token: Dictionary = tokens[i]
		var token_type: int = int(token.get("type", 0))
		var token_state: int = int(token.get("state", 0))
		var type_name: String = Constants.DefenseToken.keys()[token_type]
		var is_locked: bool = _attack_state.get_defense_resolver() \
				.is_token_locked(i)
		var is_spendable: bool = i in spendable and not is_locked

		var btn: Button = Button.new()
		btn.text = type_name
		btn.custom_minimum_size = Vector2(80, 28)
		btn.disabled = not is_spendable

		if is_locked:
			btn.text += " 🔒"
		elif token_state == Constants.DefenseTokenState.EXHAUSTED:
			btn.text += " ⚠"
			btn.tooltip_text = "Spending will discard this token."

		if is_spendable:
			btn.pressed.connect(_on_defense_token_pressed.bind(i))
		_defense_container.add_child(btn)


# ---------------------------------------------------------------------------
# Damage summary
# ---------------------------------------------------------------------------


## Shows a text summary of current damage total.
func _show_damage_summary() -> void:
	if _attack_state == null:
		return
	var pool: AttackDicePool = _attack_state.get_dice_pool()
	var dmg: int = pool.calculate_ship_damage()
	var has_crit: bool = pool.has_critical()
	var acc: Array[int] = pool.get_accuracy_indices()
	var parts: Array[String] = []
	parts.append("Damage: %d" % dmg)
	if has_crit:
		parts.append("Crit: Yes")
	if acc.size() > 0:
		parts.append("Accuracies: %d" % acc.size())
	if _info_label:
		_info_label.text = " | ".join(parts)


## Formats a DamageResult for display.
func _format_damage_result(result: DamageResolver.DamageResult) -> String:
	var parts: Array[String] = []
	parts.append("Final damage: %d" % result.final_damage)
	if result.shields_lost_defending > 0:
		parts.append("Shields lost (zone): %d" %
				result.shields_lost_defending)
	if result.shields_lost_redirect > 0:
		parts.append("Shields redirected: %d" %
				result.shields_lost_redirect)
	if result.facedown_cards > 0:
		parts.append("Damage cards: %d" % result.facedown_cards)
	if result.standard_crit_triggered:
		parts.append("Standard crit: 1st card faceup!")
	if result.destroyed:
		parts.append("TARGET DESTROYED!")
	return "\n".join(parts)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


## Adds a button to the button container.
func _add_button(text: String, callback: Callable) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(120, 36)
	btn.pressed.connect(callback)
	if _button_container:
		_button_container.add_child(btn)
	return btn


## Returns the attacker's display name.
func _get_attacker_name() -> String:
	if _attack_state and _attack_state.get_attacker() and \
			_attack_state.get_attacker().ship_data:
		return _attack_state.get_attacker().ship_data.ship_name
	return "Ship"


## Returns the target's display name.
func _get_target_name() -> String:
	if _attack_state == null:
		return "Target"
	if _attack_state.is_target_ship() and _attack_state.get_target_ship():
		var tgt: ShipInstance = _attack_state.get_target_ship()
		if tgt.ship_data:
			return tgt.ship_data.ship_name
		return "Ship"
	if _attack_state.get_target_squadron():
		return "Squadron"
	return "Target"


## Formats the list of used attack zones.
func _format_used_zones() -> String:
	if _attack_state == null:
		return ""
	var used: Array[Constants.HullZone] = _attack_state \
			.get_activation_state().get_used_attack_zones()
	if used.is_empty():
		return ""
	var names: Array[String] = []
	for zone: Constants.HullZone in used:
		names.append(Constants.HullZone.keys()[int(zone)])
	return "Used zones: %s" % ", ".join(names)


## Returns a hull zone name by integer value.
func _zone_name(zone_int: int) -> String:
	if zone_int < 0 or zone_int >= Constants.HullZone.size():
		return "?"
	return Constants.HullZone.keys()[zone_int]


## Returns the defender's defense tokens.
func _get_defender_defense_tokens() -> Array[Dictionary]:
	if _attack_state == null:
		return [] as Array[Dictionary]
	if _attack_state.is_target_ship() and _attack_state.get_target_ship():
		return _attack_state.get_target_ship().defense_tokens
	return [] as Array[Dictionary]


## Centres the panel on the given viewport size.
func centre_on_screen(viewport_size: Vector2) -> void:
	var panel_size: Vector2 = custom_minimum_size
	position = (viewport_size - panel_size) * 0.5


# ---------------------------------------------------------------------------
# Button callbacks
# ---------------------------------------------------------------------------


func _on_cf_die_pressed(colour: String) -> void:
	cf_die_requested.emit(colour)


func _on_cf_skip_pressed() -> void:
	cf_dial_skipped.emit()


func _on_roll_pressed() -> void:
	roll_requested.emit()


func _on_finish_effects_pressed() -> void:
	finish_step_requested.emit()


func _on_finish_defense_pressed() -> void:
	finish_step_requested.emit()


func _on_defense_token_pressed(index: int) -> void:
	defense_token_selected.emit(index)


func _on_damage_acknowledged() -> void:
	damage_acknowledged.emit()


func _on_additional_target_pressed() -> void:
	additional_target_requested.emit()


func _on_next_attack_pressed() -> void:
	next_attack_requested.emit()


func _on_skip_all_pressed() -> void:
	skip_requested.emit()


func _on_all_done_pressed() -> void:
	all_attacks_done_requested.emit()


func _on_change_zone_pressed() -> void:
	if _attack_state:
		_attack_state.deselect_attacking_zone()
		update_display()
