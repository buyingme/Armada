## Tests for [ChatManager].
##
## Verifies message sanitization, history management,
## rate limiting, and entry creation.
extends GutTest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Creates a fresh ChatManager instance for isolated testing.
## We test the public helper methods and logic directly
## without relying on RPC infrastructure.
var _manager: Node


func before_each() -> void:
	_manager = ChatManager
	_manager.clear_history()


# ---------------------------------------------------------------------------
# Sanitization
# ---------------------------------------------------------------------------

func test_sanitize_strips_control_chars() -> void:
	var dirty: String = "Hello" + char(1) + "World" + char(31)
	var clean: String = _manager._sanitize(dirty)
	assert_eq(clean, "HelloWorld",
			"Control characters should be stripped.")


func test_sanitize_preserves_normal_text() -> void:
	var text: String = "Good game! GG :)"
	assert_eq(_manager._sanitize(text), text,
			"Normal text should be preserved.")


func test_sanitize_clamps_to_max_length() -> void:
	var long_text: String = "A".repeat(300)
	var result: String = _manager._sanitize(long_text)
	assert_eq(result.length(), ChatManager.MAX_MESSAGE_LENGTH,
			"Text should be clamped to MAX_MESSAGE_LENGTH.")


func test_sanitize_strips_whitespace() -> void:
	assert_eq(_manager._sanitize("  hello  "), "hello",
			"Leading/trailing whitespace should be stripped.")


func test_sanitize_empty_returns_empty() -> void:
	assert_eq(_manager._sanitize(""), "",
			"Empty string should return empty.")


func test_sanitize_only_whitespace_returns_empty() -> void:
	assert_eq(_manager._sanitize("   "), "",
			"Whitespace-only should return empty.")


# ---------------------------------------------------------------------------
# Entry creation
# ---------------------------------------------------------------------------

func test_create_entry_has_required_fields() -> void:
	var entry: Dictionary = _manager._create_entry(
			"Alice", "Hello", "game")
	assert_eq(entry["sender"], "Alice",
			"Sender should match.")
	assert_eq(entry["text"], "Hello",
			"Text should match.")
	assert_eq(entry["channel"], "game",
			"Channel should match.")
	assert_true(entry.has("timestamp"),
			"Entry should have timestamp.")


func test_create_entry_system_channel() -> void:
	var entry: Dictionary = _manager._create_entry(
			"System", "Player joined", "system")
	assert_eq(entry["channel"], "system",
			"Channel should be 'system'.")


# ---------------------------------------------------------------------------
# History management
# ---------------------------------------------------------------------------

func test_add_to_history_appends() -> void:
	var entry: Dictionary = _manager._create_entry(
			"Alice", "Hello", "game")
	_manager._add_to_history(entry)
	assert_eq(_manager.get_message_count(), 1,
			"History should have 1 message.")


func test_add_to_history_trims_at_max() -> void:
	for i: int in range(ChatManager.MAX_HISTORY + 10):
		var entry: Dictionary = _manager._create_entry(
				"Bot", "msg %d" % i, "game")
		_manager._add_to_history(entry)
	assert_eq(_manager.get_message_count(), ChatManager.MAX_HISTORY,
			"History should be capped at MAX_HISTORY.")


func test_clear_history() -> void:
	_manager._add_to_history(_manager._create_entry(
			"Alice", "Hi", "game"))
	_manager.clear_history()
	assert_eq(_manager.get_message_count(), 0,
			"History should be empty after clear.")


func test_history_order_preserved() -> void:
	_manager._add_to_history(_manager._create_entry(
			"Alice", "First", "game"))
	_manager._add_to_history(_manager._create_entry(
			"Bob", "Second", "game"))
	assert_eq(_manager.history[0]["text"], "First",
			"First message should be first.")
	assert_eq(_manager.history[1]["text"], "Second",
			"Second message should be second.")


# ---------------------------------------------------------------------------
# Rate limiting
# ---------------------------------------------------------------------------

func test_rate_limit_allows_within_limit() -> void:
	_manager._send_timestamps.clear()
	for i: int in range(ChatManager.RATE_LIMIT_COUNT):
		assert_true(_manager._check_rate_limit(99),
				"Message %d should be allowed." % i)


func test_rate_limit_blocks_over_limit() -> void:
	_manager._send_timestamps.clear()
	for i: int in range(ChatManager.RATE_LIMIT_COUNT):
		_manager._check_rate_limit(99)
	assert_false(_manager._check_rate_limit(99),
			"Message over limit should be blocked.")


func test_rate_limit_per_peer() -> void:
	_manager._send_timestamps.clear()
	for i: int in range(ChatManager.RATE_LIMIT_COUNT):
		_manager._check_rate_limit(100)
	# Different peer should still be allowed.
	assert_true(_manager._check_rate_limit(200),
			"Different peer should not be rate-limited.")


func test_rate_limit_remaining_returns_positive() -> void:
	_manager._send_timestamps.clear()
	for i: int in range(ChatManager.RATE_LIMIT_COUNT):
		_manager._check_rate_limit(99)
	var remaining: float = _manager._get_rate_limit_remaining(99)
	assert_gt(remaining, 0.0,
			"Should have positive remaining time.")


func test_rate_limit_remaining_zero_for_unknown_peer() -> void:
	_manager._send_timestamps.clear()
	assert_eq(_manager._get_rate_limit_remaining(999), 0.0,
			"Unknown peer should have 0 remaining.")


func test_rate_limit_cleanup_on_disconnect() -> void:
	_manager._send_timestamps.clear()
	_manager._check_rate_limit(50)
	assert_true(_manager._send_timestamps.has(50),
			"Should have timestamps for peer 50.")
	_manager._on_peer_disconnected(50)
	assert_false(_manager._send_timestamps.has(50),
			"Timestamps should be cleaned up after disconnect.")


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

func test_max_message_length_is_positive() -> void:
	assert_gt(ChatManager.MAX_MESSAGE_LENGTH, 0,
			"MAX_MESSAGE_LENGTH should be positive.")


func test_max_history_is_positive() -> void:
	assert_gt(ChatManager.MAX_HISTORY, 0,
			"MAX_HISTORY should be positive.")


func test_rate_limit_count_is_positive() -> void:
	assert_gt(ChatManager.RATE_LIMIT_COUNT, 0,
			"RATE_LIMIT_COUNT should be positive.")


func test_rate_limit_window_is_positive() -> void:
	assert_gt(ChatManager.RATE_LIMIT_WINDOW, 0.0,
			"RATE_LIMIT_WINDOW should be positive.")
