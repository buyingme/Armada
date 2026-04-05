## Tests for DamageSummaryOverlay — defensive dismissed signal.
extends GutTest


var _overlay: DamageSummaryOverlay


func before_each() -> void:
	_overlay = DamageSummaryOverlay.new()
	add_child_autofree(_overlay)


## show_summary with empty textures and 0 facedown emits dismissed
## immediately so the attack flow never stalls.
func test_show_summary_empty_emits_dismissed() -> void:
	# Arrange
	watch_signals(_overlay)

	# Act
	_overlay.show_summary([], 0, null, "Test Ship")

	# Assert
	assert_signal_emitted(_overlay, "dismissed",
			"dismissed signal should emit when nothing to show")
	assert_false(_overlay.visible,
			"overlay should remain hidden when nothing to show")


## show_summary with content does NOT auto-emit dismissed.
func test_show_summary_with_content_does_not_auto_dismiss() -> void:
	# Arrange
	watch_signals(_overlay)
	var fake_tex: Texture2D = PlaceholderTexture2D.new()

	# Act — 0 faceup textures but 1 facedown card.
	_overlay.show_summary([], 1, fake_tex, "Test Ship")

	# Assert
	assert_signal_not_emitted(_overlay, "dismissed",
			"dismissed signal should NOT emit when cards are shown")
	assert_true(_overlay.visible,
			"overlay should be visible when facedown cards exist")


## show_summary with faceup textures shows overlay.
func test_show_summary_with_faceup_shows_overlay() -> void:
	# Arrange
	watch_signals(_overlay)
	var fake_tex: Texture2D = PlaceholderTexture2D.new()
	var faceup: Array = [ {"texture": fake_tex, "title": "Test Card"}]

	# Act
	_overlay.show_summary(faceup, 0, null, "Test Ship")

	# Assert
	assert_signal_not_emitted(_overlay, "dismissed",
			"dismissed should NOT emit with faceup content")
	assert_true(_overlay.visible,
			"overlay should be visible with faceup cards")
