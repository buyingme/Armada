extends GutTest


var _dialog: NetworkSideAssignmentDialog
var _received: Dictionary = {}


func before_each() -> void:
	_dialog = NetworkSideAssignmentDialog.new()
	add_child_autofree(_dialog)


func test_rows_start_unassigned_and_duplicate_sides_disable_confirmation() -> void:
	_dialog.configure({1: "Host", 42: "Client"}, _endpoint_ids(), _available_players())
	assert_true(_dialog._confirm.disabled)
	var host: OptionButton = _dialog._selectors[1]
	var client: OptionButton = _dialog._selectors[42]
	host.select(1)
	_dialog._refresh_confirmation(1)
	assert_true(_dialog._confirm.disabled)
	client.select(1)
	_dialog._refresh_confirmation(1)
	assert_true(_dialog._confirm.disabled)
	client.select(2)
	_dialog._refresh_confirmation(2)
	assert_false(_dialog._confirm.disabled)


func test_confirmation_returns_only_the_explicit_endpoint_to_player_mapping() -> void:
	_dialog.configure({1: "Host", 42: "Client"}, _endpoint_ids(), _available_players())
	_dialog.assignment_confirmed.connect(func(proposals: Dictionary) -> void:
		_received = proposals)
	(_dialog._selectors[1] as OptionButton).select(2)
	(_dialog._selectors[42] as OptionButton).select(1)
	_dialog._confirm_assignment()
	assert_eq(_received, {1: 1, 42: 0})


func test_side_selector_uses_saved_side_identity_not_player_index() -> void:
	_dialog.configure({1: "Host", 42: "Client"}, _endpoint_ids(),
			_available_players(), {
				0: "Rebel Alliance — Redemption Fleet",
				1: "Galactic Empire — Devastator Fleet",
			})
	var host: OptionButton = _dialog._selectors[1]
	assert_eq(host.get_item_text(1), "Rebel Alliance — Redemption Fleet")
	assert_eq(host.get_item_text(2), "Galactic Empire — Devastator Fleet")
	assert_false(host.get_item_text(1).contains("Player 0"))
	assert_false(host.get_item_text(2).contains("Player 1"))


func _endpoint_ids() -> Array[int]:
	return [1, 42]


func _available_players() -> Array[int]:
	return [0, 1]
