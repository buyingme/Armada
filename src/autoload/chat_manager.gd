## Chat Manager
##
## Autoload singleton that manages in-game text chat.
## Handles message history, send/receive RPCs, timestamps,
## sender identification, and server-side rate limiting.
##
## Supports two channels: player chat (game) and spectator chat.
## Chat works in both lobby and in-game phases.
##
## G4 Network Plan: §4 — G4.6.1, G4.6.4, G4.6.5, G4.6.7
extends Node


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Maximum characters per message.
const MAX_MESSAGE_LENGTH: int = 200

## Maximum messages stored in history.
const MAX_HISTORY: int = 100

## Rate limit: max messages per window.
const RATE_LIMIT_COUNT: int = 5

## Rate limit: window duration in seconds.
const RATE_LIMIT_WINDOW: float = 10.0


# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when a new message is added to the history.
signal message_received(entry: Dictionary)

## Emitted when a send attempt is rate-limited.
signal rate_limited(seconds_remaining: float)


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Chat message history.  Each entry:
## [code]{sender: String, text: String, timestamp: int, channel: String}[/code]
## Channels: "game" (player chat), "spectator", "system".
var history: Array[Dictionary] = []

## Server-side: per-peer send timestamps for rate limiting.
## Maps [code]peer_id → Array[float][/code] of unix timestamps.
var _send_timestamps: Dictionary = {}

## Logger for this system.
var _log: GameLogger = GameLogger.new("ChatManager")


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Sends a chat message.  On server, broadcasts directly.
## On client, sends to server for relay.
## Returns [code]true[/code] if the message was sent successfully.
func send_message(text: String) -> bool:
	var sanitized: String = _sanitize(text)
	if sanitized.is_empty():
		return false
	var display_name: String = PlayerProfile.get_display_name() \
			if PlayerProfile else "Player"
	if NetworkManager.is_server():
		var entry: Dictionary = _create_entry(
				display_name, sanitized, "game")
		_add_to_history(entry)
		_relay_message.rpc(entry)
		return true
	else:
		_submit_message.rpc_id(1, sanitized)
		return true


## Adds a system message (not from a player).
## Used for join/leave notifications, game events, etc.
func add_system_message(text: String) -> void:
	var entry: Dictionary = _create_entry("System", text, "system")
	_add_to_history(entry)
	if NetworkManager.is_server():
		_relay_message.rpc(entry)


## Clears the chat history.
func clear_history() -> void:
	history.clear()


## Returns the number of messages in history.
func get_message_count() -> int:
	return history.size()


# ---------------------------------------------------------------------------
# RPCs
# ---------------------------------------------------------------------------

## Client → Server: submit a chat message for relay.
@rpc("any_peer", "reliable")
func _submit_message(text: String) -> void:
	if not NetworkManager.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	# --- Rate limiting (G4.6.7) ---
	if not _check_rate_limit(sender_id):
		var remaining: float = _get_rate_limit_remaining(sender_id)
		_log.warn("Rate-limited peer %d (%.1fs remaining)." % [
				sender_id, remaining])
		_rate_limit_notify.rpc_id(sender_id, remaining)
		return
	# --- Sanitize and relay ---
	var sanitized: String = _sanitize(text)
	if sanitized.is_empty():
		return
	var peer_info: Dictionary = NetworkManager.peers.get(
			sender_id, {})
	var display_name: String = peer_info.get(
			"display_name", "Player")
	var entry: Dictionary = _create_entry(
			display_name, sanitized, "game")
	_add_to_history(entry)
	_relay_message.rpc(entry)


## Server → All: broadcast a chat message to all clients.
@rpc("authority", "reliable")
func _relay_message(entry: Dictionary) -> void:
	_add_to_history(entry)


## Server → Client: notify that the client is rate-limited.
@rpc("authority", "reliable")
func _rate_limit_notify(seconds_remaining: float) -> void:
	rate_limited.emit(seconds_remaining)


# ---------------------------------------------------------------------------
# Rate limiting (G4.6.7)
# ---------------------------------------------------------------------------

## Server-side: checks if a peer is within the rate limit.
## Records the timestamp if allowed.
func _check_rate_limit(peer_id: int) -> bool:
	var now: float = Time.get_unix_time_from_system()
	if not _send_timestamps.has(peer_id):
		_send_timestamps[peer_id] = [] as Array[float]
	var timestamps: Array = _send_timestamps[peer_id]
	# Remove timestamps outside the window.
	var cutoff: float = now - RATE_LIMIT_WINDOW
	var filtered: Array[float] = []
	for ts: float in timestamps:
		if ts > cutoff:
			filtered.append(ts)
	_send_timestamps[peer_id] = filtered
	if filtered.size() >= RATE_LIMIT_COUNT:
		return false
	filtered.append(now)
	_send_timestamps[peer_id] = filtered
	return true


## Returns seconds remaining until the rate limit resets.
func _get_rate_limit_remaining(peer_id: int) -> float:
	if not _send_timestamps.has(peer_id):
		return 0.0
	var timestamps: Array = _send_timestamps[peer_id]
	if timestamps.is_empty():
		return 0.0
	var oldest: float = timestamps[0]
	var remaining: float = (oldest + RATE_LIMIT_WINDOW) \
			- Time.get_unix_time_from_system()
	return maxf(0.0, remaining)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Creates a chat entry dictionary.
func _create_entry(sender: String, text: String,
		channel: String) -> Dictionary:
	return {
		"sender": sender,
		"text": text,
		"timestamp": int(Time.get_unix_time_from_system()),
		"channel": channel,
	}


## Adds an entry to history, trimming if over max.
func _add_to_history(entry: Dictionary) -> void:
	history.append(entry)
	if history.size() > MAX_HISTORY:
		history.pop_front()
	message_received.emit(entry)


## Sanitizes a chat message: strips control chars, clamps length.
func _sanitize(text: String) -> String:
	var result: String = ""
	for i: int in range(text.length()):
		var c: String = text[i]
		if c.unicode_at(0) >= 32:
			result += c
	result = result.strip_edges()
	if result.length() > MAX_MESSAGE_LENGTH:
		result = result.left(MAX_MESSAGE_LENGTH)
	return result


## Cleans up rate-limit tracking when a peer disconnects.
func _on_peer_disconnected(peer_id: int) -> void:
	_send_timestamps.erase(peer_id)
