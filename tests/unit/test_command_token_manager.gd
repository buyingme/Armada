## Test: CommandTokenManager
##
## Unit tests for CommandTokenManager — command token management per ship.
## Rules Reference: CM-001, CM-004–006.
extends GutTest


var _mgr: CommandTokenManager = null


func before_each() -> void:
	_mgr = CommandTokenManager.create(2)


# --- Factory / create() ---

func test_create_sets_max_tokens() -> void:
	assert_eq(_mgr.max_tokens, 2,
			"max_tokens should equal the command value passed to create()")


func test_create_starts_empty() -> void:
	assert_eq(_mgr.get_token_count(), 0,
			"New manager should have zero tokens")


func test_create_get_tokens_empty() -> void:
	var tokens: Array[int] = _mgr.get_tokens()
	assert_eq(tokens.size(), 0,
			"get_tokens should return empty array initially")


# --- add_token() ---

func test_add_token_success() -> void:
	var result: bool = _mgr.add_token(Constants.CommandType.NAVIGATE)
	assert_true(result, "Should successfully add a Navigate token")
	assert_eq(_mgr.get_token_count(), 1,
			"Token count should be 1 after adding")


func test_add_two_different_tokens() -> void:
	_mgr.add_token(Constants.CommandType.NAVIGATE)
	_mgr.add_token(Constants.CommandType.REPAIR)
	assert_eq(_mgr.get_token_count(), 2,
			"Should hold 2 tokens of different types")


func test_add_token_rejects_duplicate() -> void:
	_mgr.add_token(Constants.CommandType.NAVIGATE)
	var result: bool = _mgr.add_token(Constants.CommandType.NAVIGATE)
	assert_false(result,
			"Should reject duplicate token type (CM-005)")
	assert_eq(_mgr.get_token_count(), 1,
			"Count should remain 1 after rejected duplicate")


func test_add_token_rejects_overflow() -> void:
	_mgr.add_token(Constants.CommandType.NAVIGATE)
	_mgr.add_token(Constants.CommandType.REPAIR)
	var result: bool = _mgr.add_token(Constants.CommandType.SQUADRON)
	assert_false(result,
			"Should reject token when at max capacity (CM-004)")
	assert_eq(_mgr.get_token_count(), 2,
			"Count should remain at max")


# --- has_token() ---

func test_has_token_true() -> void:
	_mgr.add_token(Constants.CommandType.SQUADRON)
	assert_true(_mgr.has_token(Constants.CommandType.SQUADRON),
			"Should report having a Squadron token")


func test_has_token_false() -> void:
	assert_false(_mgr.has_token(Constants.CommandType.NAVIGATE),
			"Should not have a Navigate token when none added")


# --- remove_token() / spend_token() ---

func test_remove_token_success() -> void:
	_mgr.add_token(Constants.CommandType.NAVIGATE)
	var result: bool = _mgr.remove_token(Constants.CommandType.NAVIGATE)
	assert_true(result, "Should successfully remove Navigate token")
	assert_eq(_mgr.get_token_count(), 0,
			"Count should be 0 after removing")


func test_remove_token_not_found() -> void:
	var result: bool = _mgr.remove_token(Constants.CommandType.REPAIR)
	assert_false(result, "Cannot remove token that doesn't exist")


func test_spend_token_is_alias_for_remove() -> void:
	_mgr.add_token(Constants.CommandType.REPAIR)
	var result: bool = _mgr.spend_token(Constants.CommandType.REPAIR)
	assert_true(result, "spend_token should work like remove_token (CM-001)")
	assert_eq(_mgr.get_token_count(), 0,
			"Count should be 0 after spending")


# --- add_token_with_discard() ---

func test_add_with_discard_when_not_at_capacity() -> void:
	_mgr.add_token(Constants.CommandType.NAVIGATE)
	var result: Dictionary = _mgr.add_token_with_discard(
			Constants.CommandType.REPAIR,
			Constants.CommandType.NAVIGATE)
	assert_true(result["added"],
			"Should add when not at capacity")
	assert_eq(int(result["discarded"]), -1,
			"Should not discard when not at capacity")
	assert_eq(_mgr.get_token_count(), 2,
			"Should have 2 tokens")


func test_add_with_discard_at_capacity() -> void:
	_mgr.add_token(Constants.CommandType.NAVIGATE)
	_mgr.add_token(Constants.CommandType.REPAIR)
	var result: Dictionary = _mgr.add_token_with_discard(
			Constants.CommandType.SQUADRON,
			Constants.CommandType.NAVIGATE)
	assert_true(result["added"],
			"Should add after discarding (CM-004)")
	assert_eq(int(result["discarded"]), Constants.CommandType.NAVIGATE,
			"Should report discarded token type")
	assert_false(_mgr.has_token(Constants.CommandType.NAVIGATE),
			"Navigate token should be gone")
	assert_true(_mgr.has_token(Constants.CommandType.SQUADRON),
			"Squadron token should now be present")


func test_add_with_discard_rejects_duplicate() -> void:
	_mgr.add_token(Constants.CommandType.NAVIGATE)
	var result: Dictionary = _mgr.add_token_with_discard(
			Constants.CommandType.NAVIGATE,
			Constants.CommandType.NAVIGATE)
	assert_false(result["added"],
			"Should reject duplicate even with discard (CM-005)")


func test_add_with_discard_rejects_missing_discard_type() -> void:
	_mgr.add_token(Constants.CommandType.NAVIGATE)
	_mgr.add_token(Constants.CommandType.REPAIR)
	var result: Dictionary = _mgr.add_token_with_discard(
			Constants.CommandType.SQUADRON,
			Constants.CommandType.CONCENTRATE_FIRE)
	assert_false(result["added"],
			"Should reject when discard_type is not held")


# --- clear() ---

func test_clear_removes_all() -> void:
	_mgr.add_token(Constants.CommandType.NAVIGATE)
	_mgr.add_token(Constants.CommandType.REPAIR)
	_mgr.clear()
	assert_eq(_mgr.get_token_count(), 0,
			"clear() should remove all tokens")


# --- get_tokens() returns copy ---

func test_get_tokens_returns_copy() -> void:
	_mgr.add_token(Constants.CommandType.NAVIGATE)
	var tokens: Array[int] = _mgr.get_tokens()
	tokens.append(Constants.CommandType.REPAIR)
	assert_eq(_mgr.get_token_count(), 1,
			"Modifying returned array should not affect manager")


# --- serialize() / deserialize() ---

func test_serialize_round_trip() -> void:
	_mgr.add_token(Constants.CommandType.NAVIGATE)
	_mgr.add_token(Constants.CommandType.REPAIR)
	var data: Dictionary = _mgr.serialize()
	var restored: CommandTokenManager = CommandTokenManager.deserialize(data)
	assert_eq(restored.max_tokens, 2,
			"Deserialized max_tokens should match")
	assert_eq(restored.get_token_count(), 2,
			"Deserialized token count should match")
	assert_true(restored.has_token(Constants.CommandType.NAVIGATE),
			"Deserialized should have Navigate")
	assert_true(restored.has_token(Constants.CommandType.REPAIR),
			"Deserialized should have Repair")


# --- Edge: command value 1 ---

func test_cmd_value_one_max_one_token() -> void:
	var mgr1: CommandTokenManager = CommandTokenManager.create(1)
	mgr1.add_token(Constants.CommandType.NAVIGATE)
	var result: bool = mgr1.add_token(Constants.CommandType.REPAIR)
	assert_false(result,
			"Command value 1 ship can only hold 1 token (CM-004)")


# --- force_add_token() ---

func test_force_add_token_normal_no_overflow() -> void:
	var result: Dictionary = _mgr.force_add_token(
			Constants.CommandType.NAVIGATE)
	assert_false(result["overflow"],
			"Should not be overflow when under max")
	assert_false(result["duplicate"],
			"Should not be duplicate when token is new")
	assert_eq(_mgr.get_token_count(), 1,
			"Token should be added")


func test_force_add_token_overflow_flagged() -> void:
	_mgr.force_add_token(Constants.CommandType.NAVIGATE)
	_mgr.force_add_token(Constants.CommandType.REPAIR)
	# max_tokens is 2, adding a third should flag overflow
	var result: Dictionary = _mgr.force_add_token(
			Constants.CommandType.SQUADRON)
	assert_true(result["overflow"],
			"Should flag overflow when tokens exceed max")
	assert_false(result["duplicate"],
			"Should not flag duplicate for new type")
	assert_eq(_mgr.get_token_count(), 3,
			"Token should still be added despite overflow")


func test_force_add_token_duplicate_flagged() -> void:
	_mgr.force_add_token(Constants.CommandType.NAVIGATE)
	var result: Dictionary = _mgr.force_add_token(
			Constants.CommandType.NAVIGATE)
	assert_true(result["duplicate"],
			"Should flag duplicate when same type exists")
	assert_eq(_mgr.get_token_count(), 2,
			"Duplicate token should still be physically added")


func test_force_add_token_cmd_value_one_overflow() -> void:
	var mgr1: CommandTokenManager = CommandTokenManager.create(1)
	mgr1.force_add_token(Constants.CommandType.NAVIGATE)
	var result: Dictionary = mgr1.force_add_token(
			Constants.CommandType.REPAIR)
	assert_true(result["overflow"],
			"CMD value 1: second token should flag overflow")
	assert_false(result["duplicate"],
			"Should not flag duplicate for different type")
	assert_eq(mgr1.get_token_count(), 2,
			"Both tokens should be present until caller resolves")


func test_force_add_then_remove_resolves_overflow() -> void:
	_mgr.force_add_token(Constants.CommandType.NAVIGATE)
	_mgr.force_add_token(Constants.CommandType.REPAIR)
	_mgr.force_add_token(Constants.CommandType.SQUADRON)
	assert_eq(_mgr.get_token_count(), 3,
			"Should have 3 tokens before discard")
	_mgr.remove_token(Constants.CommandType.NAVIGATE)
	assert_eq(_mgr.get_token_count(), 2,
			"Should have 2 tokens after discard (at max)")


func test_force_add_duplicate_then_remove_resolves() -> void:
	_mgr.force_add_token(Constants.CommandType.NAVIGATE)
	_mgr.force_add_token(Constants.CommandType.NAVIGATE)
	assert_eq(_mgr.get_token_count(), 2,
			"Should have 2 nav tokens before removing duplicate")
	_mgr.remove_token(Constants.CommandType.NAVIGATE)
	assert_eq(_mgr.get_token_count(), 1,
			"Should have 1 nav token after removing duplicate")
