## Test: ActivationContext
##
## Unit tests for [ActivationContext] — shared activation state holder.
## Validates set_active / clear lifecycle, is_active queries, and signal
## emission.
extends GutTest


# --- Helpers ---

## Creates a minimal ShipInstance for testing.
func _make_ship_instance() -> ShipInstance:
	var data: ShipData = ShipData.new()
	data.ship_name = "Test Ship"
	data.command_value = 2
	data.hull = 5
	data.max_speed = 2
	data.navigation_chart = [[1], [1, 1]]
	data.defense_tokens = []
	data.shields = {"front": 3, "left": 2, "right": 2, "rear": 1}
	return ShipInstance.create_from_data("test_ship", data, 2, 0)


## Creates a ShipActivationState from the given ship.
func _make_state(ship: ShipInstance) -> ShipActivationState:
	return ShipActivationState.create(ship)


## Creates a ready-to-use ActivationContext.
func _make_context() -> ActivationContext:
	return ActivationContext.new()


# --- is_active ---

func test_new_context_is_not_active() -> void:
	var ctx: ActivationContext = _make_context()
	assert_false(ctx.is_active(), "New context should not be active")


func test_is_active_after_set_active() -> void:
	var ctx: ActivationContext = _make_context()
	var ship: ShipInstance = _make_ship_instance()
	var state: ShipActivationState = _make_state(ship)
	# ShipToken is a Node2D — pass null for unit tests (no scene tree).
	ctx.activating_ship_token = null
	ctx.ship_activation_state = state
	assert_false(ctx.is_active(),
			"is_active should be false when token is null")


# --- set_active / clear ---

func test_set_active_stores_state() -> void:
	var ctx: ActivationContext = _make_context()
	var ship: ShipInstance = _make_ship_instance()
	var state: ShipActivationState = _make_state(ship)
	# We can't easily create a ShipToken in unit tests, so test with null
	# token to verify the state assignment side.
	ctx.set_active(null, state)
	assert_eq(ctx.ship_activation_state, state,
			"set_active should store the activation state")
	assert_null(ctx.activating_ship_token,
			"Token should be what was passed (null in unit test)")
	assert_false(ctx.last_maneuver_overlapped,
			"set_active should reset overlap flag")


func test_clear_resets_all_fields() -> void:
	var ctx: ActivationContext = _make_context()
	var ship: ShipInstance = _make_ship_instance()
	var state: ShipActivationState = _make_state(ship)
	ctx.set_active(null, state)
	ctx.last_maneuver_overlapped = true
	ctx.clear()
	assert_null(ctx.activating_ship_token,
			"clear should null the token")
	assert_null(ctx.ship_activation_state,
			"clear should null the state")
	assert_false(ctx.last_maneuver_overlapped,
			"clear should reset overlap flag")


func test_is_active_false_after_clear() -> void:
	var ctx: ActivationContext = _make_context()
	var ship: ShipInstance = _make_ship_instance()
	var state: ShipActivationState = _make_state(ship)
	ctx.set_active(null, state)
	ctx.clear()
	assert_false(ctx.is_active(), "is_active should be false after clear")


# --- Signal emission ---

func test_set_active_emits_signal() -> void:
	var ctx: ActivationContext = _make_context()
	watch_signals(ctx)
	var ship: ShipInstance = _make_ship_instance()
	var state: ShipActivationState = _make_state(ship)
	ctx.set_active(null, state)
	assert_signal_emitted(ctx, "activation_changed",
			"set_active should emit activation_changed")


func test_clear_emits_signal() -> void:
	var ctx: ActivationContext = _make_context()
	var ship: ShipInstance = _make_ship_instance()
	var state: ShipActivationState = _make_state(ship)
	ctx.set_active(null, state)
	watch_signals(ctx)
	ctx.clear()
	assert_signal_emitted(ctx, "activation_changed",
			"clear should emit activation_changed")


# --- last_maneuver_overlapped ---

func test_overlap_flag_survives_until_clear() -> void:
	var ctx: ActivationContext = _make_context()
	var ship: ShipInstance = _make_ship_instance()
	var state: ShipActivationState = _make_state(ship)
	ctx.set_active(null, state)
	ctx.last_maneuver_overlapped = true
	assert_true(ctx.last_maneuver_overlapped,
			"Overlap flag should persist during activation")
	ctx.clear()
	assert_false(ctx.last_maneuver_overlapped,
			"Overlap flag should reset on clear")


func test_set_active_resets_overlap_from_previous() -> void:
	var ctx: ActivationContext = _make_context()
	var ship: ShipInstance = _make_ship_instance()
	var state: ShipActivationState = _make_state(ship)
	ctx.set_active(null, state)
	ctx.last_maneuver_overlapped = true
	# Start new activation.
	var ship2: ShipInstance = _make_ship_instance()
	var state2: ShipActivationState = _make_state(ship2)
	ctx.set_active(null, state2)
	assert_false(ctx.last_maneuver_overlapped,
			"set_active should reset overlap from previous activation")
