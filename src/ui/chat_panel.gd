## Chat Panel
##
## Reusable chat UI widget with scrollable message history,
## text input, send button, and unread message indicator.
## Toggle visibility with T key or the built-in toggle button.
##
## Uses [UIStyleHelper] for consistent styling.
## Connects to [ChatManager] for message send/receive.
##
## G4 Network Plan: §4 — G4.6.2, G4.6.3
class_name ChatPanel
extends PanelContainer


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Panel width.
const PANEL_WIDTH: float = 320.0

## Panel height.
const PANEL_HEIGHT: float = 400.0

## Maximum visible messages in the scroll area.
const MAX_VISIBLE_LINES: int = 50

## System message colour.
const SYSTEM_COLOR: Color = Color(0.7, 0.7, 0.5)

## Own message colour.
const OWN_COLOR: Color = Color(0.6, 0.8, 1.0)

## Other player message colour.
const OTHER_COLOR: Color = Color(0.85, 0.85, 0.9)

## Rate limit warning colour.
const RATE_LIMIT_COLOR: Color = Color(0.9, 0.5, 0.3)


# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when the panel visibility is toggled.
signal visibility_toggled(is_visible: bool)


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Unread message count (incremented when panel is hidden).
var _unread_count: int = 0

## UI element references.
var _scroll: ScrollContainer
var _message_container: VBoxContainer
var _input: LineEdit
var _send_button: Button
var _toggle_button: Button
var _unread_label: Label
var _header_label: Label


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_ui()
	_connect_signals()
	_load_history()


func _connect_signals() -> void:
	ChatManager.message_received.connect(_on_message_received)
	ChatManager.rate_limited.connect(_on_rate_limited)


## Handles T key toggle and Escape to hide.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_T:
			if not _input.has_focus():
				toggle_panel()
				get_viewport().set_input_as_handled()
		elif key_event.pressed and key_event.keycode == KEY_ESCAPE:
			if visible and _input.has_focus():
				_input.release_focus()
				get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Toggles the chat panel visibility.
func toggle_panel() -> void:
	visible = not visible
	if visible:
		_unread_count = 0
		_update_unread_display()
		_scroll_to_bottom()
		_input.grab_focus()
	visibility_toggled.emit(visible)


## Returns the unread message count.
func get_unread_count() -> int:
	return _unread_count


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

## Builds the chat panel UI.
func _build_ui() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	add_theme_stylebox_override("panel",
			UIStyleHelper.create_modal_panel_style(0.0))

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_build_header(vbox)
	_build_message_area(vbox)
	_build_input_area(vbox)


## Builds the header with title and close button.
func _build_header(parent: VBoxContainer) -> void:
	var hbox: HBoxContainer = HBoxContainer.new()
	parent.add_child(hbox)

	_header_label = Label.new()
	_header_label.text = "Chat"
	_header_label.add_theme_font_size_override("font_size",
			UIStyleHelper.FONT_TITLE)
	_header_label.add_theme_color_override("font_color",
			UIStyleHelper.GOLD_TITLE)
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_header_label)

	_unread_label = Label.new()
	_unread_label.text = ""
	_unread_label.add_theme_font_size_override("font_size",
			UIStyleHelper.FONT_HINT)
	_unread_label.add_theme_color_override("font_color",
			UIStyleHelper.BLUE_ACCENT)
	_unread_label.visible = false
	hbox.add_child(_unread_label)

	var close_btn: Button = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(toggle_panel)
	hbox.add_child(close_btn)

	parent.add_child(HSeparator.new())


## Builds the scrollable message display area.
func _build_message_area(parent: VBoxContainer) -> void:
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(_scroll)

	_message_container = VBoxContainer.new()
	_message_container.add_theme_constant_override("separation", 2)
	_message_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_message_container)


## Builds the text input and send button.
func _build_input_area(parent: VBoxContainer) -> void:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	parent.add_child(hbox)

	_input = LineEdit.new()
	_input.placeholder_text = "Type a message..."
	_input.max_length = ChatManager.MAX_MESSAGE_LENGTH
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.custom_minimum_size.y = 32
	_input.text_submitted.connect(_on_text_submitted)
	hbox.add_child(_input)

	_send_button = Button.new()
	_send_button.text = "Send"
	_send_button.custom_minimum_size = Vector2(60, 32)
	_send_button.pressed.connect(_on_send_pressed)
	hbox.add_child(_send_button)


# ---------------------------------------------------------------------------
# Message display
# ---------------------------------------------------------------------------

## Adds a message entry to the display.
func _add_message_label(entry: Dictionary) -> void:
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size",
			UIStyleHelper.FONT_BODY)

	var sender: String = entry.get("sender", "Unknown")
	var text: String = entry.get("text", "")
	var channel: String = entry.get("channel", "game")

	var colour: Color = _get_message_colour(sender, channel)
	var hex: String = colour.to_html(false)
	label.text = "[color=#%s][b]%s:[/b] %s[/color]" % [
			hex, sender, text]

	_message_container.add_child(label)
	# Trim old messages from display.
	while _message_container.get_child_count() > MAX_VISIBLE_LINES:
		var old: Node = _message_container.get_child(0)
		_message_container.remove_child(old)
		old.queue_free()
	call_deferred("_scroll_to_bottom")


## Returns the colour for a message based on sender and channel.
func _get_message_colour(sender: String,
		channel: String) -> Color:
	if channel == "system":
		return SYSTEM_COLOR
	var own_name: String = PlayerProfile.get_display_name() \
			if PlayerProfile else ""
	if sender == own_name:
		return OWN_COLOR
	return OTHER_COLOR


## Scrolls the message area to the bottom.
func _scroll_to_bottom() -> void:
	if _scroll:
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


## Loads existing history on startup.
func _load_history() -> void:
	for entry: Dictionary in ChatManager.history:
		_add_message_label(entry)


# ---------------------------------------------------------------------------
# Input handling
# ---------------------------------------------------------------------------

## Handles Enter key in the input field.
func _on_text_submitted(_text: String) -> void:
	_send_current_message()


## Handles the Send button press.
func _on_send_pressed() -> void:
	_send_current_message()


## Sends the current input text as a chat message.
func _send_current_message() -> void:
	var text: String = _input.text.strip_edges()
	if text.is_empty():
		return
	ChatManager.send_message(text)
	_input.text = ""
	_input.grab_focus()


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

## New message received — add to display and update unread count.
func _on_message_received(entry: Dictionary) -> void:
	_add_message_label(entry)
	if not visible:
		_unread_count += 1
		_update_unread_display()


## Rate limited — show warning in chat.
func _on_rate_limited(seconds_remaining: float) -> void:
	var warning: RichTextLabel = RichTextLabel.new()
	warning.bbcode_enabled = true
	warning.fit_content = true
	warning.scroll_active = false
	warning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	warning.add_theme_font_size_override("normal_font_size",
			UIStyleHelper.FONT_HINT)
	var hex: String = RATE_LIMIT_COLOR.to_html(false)
	warning.text = "[color=#%s]Rate limited — wait %.0fs[/color]" % [
			hex, seconds_remaining]
	_message_container.add_child(warning)
	call_deferred("_scroll_to_bottom")


## Updates the unread message indicator.
func _update_unread_display() -> void:
	if _unread_count > 0:
		_unread_label.text = "(%d new)" % _unread_count
		_unread_label.visible = true
	else:
		_unread_label.text = ""
		_unread_label.visible = false
