## Test: TargetSelector
##
## Unit tests for execution-mode target-selection lifecycle helpers.
extends GutTest


func test_lock_current_target_selection_preserves_panel_visibility() -> void:
	# Arrange
	var selector: TargetSelector = _make_selector()
	selector.enter_attacker_selection(false)
	var panel: AttackSimPanel = selector.get_panel()

	# Act
	selector.lock_current_target_selection()

	# Assert
	assert_false(selector.is_selecting(),
			"Locked target selection should disable attacker clicks.")
	assert_false(selector.is_target_selecting(),
			"Locked target selection should disable target clicks.")
	assert_true(panel.visible,
			"Locked target selection should preserve the attack panel.")


func test_lock_current_target_selection_disables_target_mode() -> void:
	# Arrange
	var selector: TargetSelector = _make_selector()
	selector.prepare_next_squadron_target()
	assert_true(selector.is_target_selecting(),
			"Setup should enter target-selection mode.")

	# Act
	selector.lock_current_target_selection()

	# Assert
	assert_false(selector.is_target_selecting(),
			"Locked target selection should leave target mode.")


func _make_selector() -> TargetSelector:
	var selector: TargetSelector = TargetSelector.new()
	var container: Node2D = Node2D.new()
	add_child_autofree(container)
	add_child_autofree(selector)
	selector.initialize(Callable(self , "_empty_ship_tokens"),
			Callable(self , "_empty_squadron_tokens"), container, null,
			AttackState.new(), AttackDiceResolver.new())
	return selector


func _empty_ship_tokens() -> Array[ShipToken]:
	return []


func _empty_squadron_tokens() -> Array[SquadronToken]:
	return []
