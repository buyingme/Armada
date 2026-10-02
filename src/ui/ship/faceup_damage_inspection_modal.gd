## Presentation of one canonical faceup damage-card inspection occurrence.
## The button submits an acknowledgment; closing this view never releases it.
class_name FaceupDamageInspectionModal
extends Control

signal acknowledge_requested(inspection_id: String)

var _card: TextureRect
var _title: Label
var _description: Label
var _button: Button
var _identity: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.82)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(360, 0)
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_card = TextureRect.new()
	_card.custom_minimum_size = Vector2(300, 420)
	_card.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(_card)
	_description = Label.new()
	_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_description)
	_button = Button.new()
	_button.text = "Acknowledge card"
	_button.pressed.connect(_submit_acknowledgment)
	column.add_child(_button)
	visible = false


func sync_inspection(data: Dictionary, actionable: bool) -> void:
	if data.is_empty():
		_identity = ""
		visible = false
		return
	_identity = str(data.get("inspection_id", ""))
	var public_card: Dictionary = data.get("public_card", {}) as Dictionary
	_title.text = str(public_card.get("title", "Damage card"))
	_description.text = str(public_card.get("effect_text", ""))
	_card.texture = AssetLoader.load_texture("damage_deck/",
			"damage_%s.png" % str(public_card.get("effect_id", "")))
	_button.visible = actionable
	visible = true


func _submit_acknowledgment() -> void:
	if not _identity.is_empty():
		acknowledge_requested.emit(_identity)
