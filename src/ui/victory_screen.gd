## Victory Screen
##
## Full-screen overlay displayed when the game ends.  Shows the winning
## player / faction, final scores with a per-category breakdown, the
## victory reason, and action buttons ("Play Again" / "Quit").
##
## Created and shown by GameBoard in response to the [signal EventBus.game_ended]
## signal.  Sits on a dedicated CanvasLayer (layer 110) above all other UI.
##
## Rules Reference: "Winning and Losing", RRG p.21; WN-001–004.
class_name VictoryScreen
extends ColorRect


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Background colour — darker than the handoff overlay for gravitas.
const OVERLAY_COLOR: Color = Color(0.03, 0.03, 0.10, 0.97)

## Faction display names (index = player_index assuming Learning Scenario
## mapping:  0 = Rebel, 1 = Imperial).
const FACTION_NAMES: Array[String] = ["Rebel Alliance", "Galactic Empire"]

## Human-readable reason strings.
const REASON_TEXT: Dictionary = {
	"elimination": "Fleet Eliminated",
	"round_6": "Six Rounds Complete",
	"mutual_destruction": "Mutual Destruction",
}


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## The details dictionary received from game_ended signal.
var _details: Dictionary = {}

## Internal references to key UI nodes for testing.
var _title_label: Label = null
var _score_label: Label = null
var _reason_label: Label = null
var _play_again_button: Button = null
var _quit_button: Button = null
var _content_vbox: VBoxContainer = null

## Logger.
var _log: GameLogger = GameLogger.new("VictoryScreen")


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _init() -> void:
	color = OVERLAY_COLOR
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	name = "VictoryScreen"


## Shows the victory screen with the given end-game details.
## [param details] — Dictionary with keys: winner_index, reason, scores, round.
func show_results(details: Dictionary) -> void:
	_details = details
	_build_ui()
	visible = true
	_log.info("Victory screen shown. Winner: %d, Reason: %s" % [
			details.get("winner_index", -1),
			details.get("reason", "unknown")])


## Adjusts size to cover the full viewport.
func update_size(viewport_size: Vector2) -> void:
	position = Vector2.ZERO
	size = viewport_size
	custom_minimum_size = viewport_size
	_centre_content(viewport_size)


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

## Builds (or rebuilds) the content UI from the stored details.
func _build_ui() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var winner: int = _details.get("winner_index", -1)
	var reason: String = _details.get("reason", "unknown")
	var scores: Array = _details.get("scores", [0, 0])
	var round_num: int = _details.get("round", 0)
	var winner_name: String = _get_faction_name(winner)
	var loser: int = 1 - winner if winner >= 0 else -1
	var loser_name: String = _get_faction_name(loser)
	_content_vbox = VBoxContainer.new()
	_content_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_content_vbox.add_theme_constant_override("separation", 20)
	_content_vbox.name = "ContentVBox"
	add_child(_content_vbox)
	_build_title_section(winner_name, reason, round_num)
	_build_score_section(winner, loser, winner_name, loser_name, scores)
	_build_button_row()


## Builds the title and reason labels.
func _build_title_section(winner_name: String, reason: String,
		round_num: int) -> void:
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 40)
	_title_label.add_theme_color_override(
			"font_color", Color(1.0, 0.85, 0.3))
	_title_label.text = "%s Wins!" % winner_name
	_title_label.name = "TitleLabel"
	_content_vbox.add_child(_title_label)
	_reason_label = Label.new()
	_reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason_label.add_theme_font_size_override("font_size", 18)
	_reason_label.add_theme_color_override(
			"font_color", Color(0.7, 0.7, 0.8))
	_reason_label.text = REASON_TEXT.get(reason, reason)
	if round_num > 0:
		_reason_label.text += "  (Round %d)" % round_num
	_reason_label.name = "ReasonLabel"
	_content_vbox.add_child(_reason_label)


## Builds the separator + score label + spacer.
func _build_score_section(winner: int, loser: int,
		winner_name: String, loser_name: String,
		scores: Array) -> void:
	var sep: HSeparator = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	_content_vbox.add_child(sep)
	var score_text: String = ""
	if winner >= 0 and loser >= 0:
		var w_score: int = scores[winner] if winner < scores.size() else 0
		var l_score: int = scores[loser] if loser < scores.size() else 0
		score_text = "%s: %d pts\n%s: %d pts" % [
				winner_name, w_score, loser_name, l_score]
	else:
		score_text = "Scores: %s" % str(scores)
	_score_label = Label.new()
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 22)
	_score_label.add_theme_color_override(
			"font_color", Color(0.9, 0.9, 0.95))
	_score_label.text = score_text
	_score_label.name = "ScoreLabel"
	_content_vbox.add_child(_score_label)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	_content_vbox.add_child(spacer)


## Builds the Play Again / Quit button row.
func _build_button_row() -> void:
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	btn_row.name = "ButtonRow"
	_content_vbox.add_child(btn_row)
	_play_again_button = Button.new()
	_play_again_button.text = "Play Again"
	_play_again_button.custom_minimum_size = Vector2(160, 48)
	_play_again_button.name = "PlayAgainButton"
	_play_again_button.pressed.connect(_on_play_again_pressed)
	btn_row.add_child(_play_again_button)
	_quit_button = Button.new()
	_quit_button.text = "Quit"
	_quit_button.custom_minimum_size = Vector2(120, 48)
	_quit_button.name = "QuitButton"
	_quit_button.pressed.connect(_on_quit_pressed)
	btn_row.add_child(_quit_button)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns a human-readable faction name for the given player index.
func _get_faction_name(player_index: int) -> String:
	if player_index >= 0 and player_index < FACTION_NAMES.size():
		return FACTION_NAMES[player_index]
	return "Unknown"


## Centres the content VBox within the overlay.
func _centre_content(viewport_size: Vector2) -> void:
	if _content_vbox == null:
		return
	var vbox_size: Vector2 = Vector2(500, 350)
	_content_vbox.position = (viewport_size - vbox_size) * 0.5
	_content_vbox.size = vbox_size


# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

## Restarts the current scene (same Learning Scenario).
func _on_play_again_pressed() -> void:
	SfxManager.play_sfx("droid_sound")
	_log.info("Play Again pressed — reloading scene.")
	get_tree().reload_current_scene()


## Exits the application.
func _on_quit_pressed() -> void:
	SfxManager.play_sfx("droid_sound")
	_log.info("Quit pressed — exiting application.")
	get_tree().quit()
