## Unit tests for TooltipLayout — pure position / clamping logic.
##
## Requirements: TT-062.
extends GutTest


var _layout: TooltipLayout


func before_each() -> void:
	_layout = TooltipLayout.new()


# ------------------------------------------------------------------
# Test helpers
# ------------------------------------------------------------------

const VP: Vector2 = Vector2(1920.0, 1080.0)
const TT_SIZE: Vector2 = Vector2(200.0, 60.0)
const OFFSET: Vector2 = Vector2(12.0, 16.0)


# ------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------

## Normal case — tooltip fits to the bottom-right of the cursor.
func test_compute_position_normal_offset_places_tooltip_right_and_below() -> void:
	# Arrange
	var cursor: Vector2 = Vector2(400.0, 300.0)

	# Act
	var pos: Vector2 = TooltipLayout.compute_position(
			cursor, TT_SIZE, VP, OFFSET)

	# Assert
	assert_eq(pos, Vector2(412.0, 316.0),
			"Tooltip should be placed at cursor + offset")


## Tooltip overflows right edge — x-offset flips to the left.
func test_compute_position_flip_horizontal_when_overflowing_right() -> void:
	# Arrange — cursor near right edge
	var cursor: Vector2 = Vector2(1800.0, 300.0)

	# Act
	var pos: Vector2 = TooltipLayout.compute_position(
			cursor, TT_SIZE, VP, OFFSET)

	# Assert — flipped: cursor.x - offset.x - width = 1800 - 12 - 200 = 1588
	assert_eq(pos.x, 1588.0,
			"Tooltip should flip to the left of the cursor")
	assert_eq(pos.y, 316.0,
			"Vertical position should stay at cursor + offset")


## Tooltip overflows bottom edge — y-offset flips upward.
func test_compute_position_flip_vertical_when_overflowing_bottom() -> void:
	# Arrange — cursor near bottom edge
	var cursor: Vector2 = Vector2(400.0, 1050.0)

	# Act
	var pos: Vector2 = TooltipLayout.compute_position(
			cursor, TT_SIZE, VP, OFFSET)

	# Assert — flipped: cursor.y - offset.y - height = 1050 - 16 - 60 = 974
	assert_eq(pos.x, 412.0,
			"Horizontal position should stay at cursor + offset")
	assert_eq(pos.y, 974.0,
			"Tooltip should flip above the cursor")


## Tooltip overflows both right and bottom — both axes flip.
func test_compute_position_flip_both_axes_when_near_corner() -> void:
	# Arrange — cursor in bottom-right corner
	var cursor: Vector2 = Vector2(1850.0, 1060.0)

	# Act
	var pos: Vector2 = TooltipLayout.compute_position(
			cursor, TT_SIZE, VP, OFFSET)

	# Assert — flipped on both: x = 1850-12-200 = 1638, y = 1060-16-60 = 984
	assert_eq(pos.x, 1638.0,
			"Tooltip should flip left when near right edge")
	assert_eq(pos.y, 984.0,
			"Tooltip should flip up when near bottom edge")


## Tooltip is larger than viewport — clamps to (0, 0).
func test_compute_position_clamps_to_zero_when_tooltip_exceeds_viewport() -> void:
	# Arrange — tiny viewport, tooltip cannot fit
	var small_vp: Vector2 = Vector2(100.0, 40.0)
	var cursor: Vector2 = Vector2(10.0, 10.0)

	# Act
	var pos: Vector2 = TooltipLayout.compute_position(
			cursor, TT_SIZE, small_vp, OFFSET)

	# Assert — clamped to (0, 0) because tooltip is larger than viewport
	assert_eq(pos, Vector2(0.0, 0.0),
			"Tooltip should clamp to origin when larger than viewport")
