## Test: ShipCardPanel — Side Swap
##
## Unit tests for the ShipCardPanel set_side method.
## Requirements: BP-003.
extends GutTest


func test_initial_rebel_panel_is_left() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true)
	assert_true(panel.is_left_side(),
			"Rebel panel should be on the left initially")


func test_initial_imperial_panel_is_right() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.GALACTIC_EMPIRE, false)
	assert_false(panel.is_left_side(),
			"Imperial panel should be on the right initially")


func test_set_side_left_to_right() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true)
	panel.set_side(false)
	assert_false(panel.is_left_side(),
			"Panel should be on the right after set_side(false)")


func test_set_side_right_to_left() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.GALACTIC_EMPIRE, false)
	panel.set_side(true)
	assert_true(panel.is_left_side(),
			"Panel should be on the left after set_side(true)")
