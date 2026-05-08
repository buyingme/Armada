## SaveGameManager
##
## Autoload singleton responsible for saving and loading game state to disk.
## Phase J1 — saves are stored as
## [code]{"header": SaveGameMetadata, "state": GameState.serialize()}[/code]
## with an HMAC signature in the header (see [IntegritySigner]).  Files
## live under [code]res://saves/[/code] (project-scoped during development;
## migrate to [code]user://[/code] for release builds).
##
## API:
##   - [method save_game] — write current [GameState] with metadata header.
##   - [method load_game] — read a save file and return
##     [code]{ok, state, meta, reason}[/code].
##   - [method can_save_now] — safe-point gate.
##   - [method list_with_meta] — enumerate all saves with header info.
##
## Rules Reference: Phase J1 — save game header schema + safe-point gate.
extends Node


## Directory under the project root where save files are stored.
## Resolved via [PathConfig]: in the editor it stays inside the
## project as [code]res://saves[/code]; in exported builds it points
## at [code]user://saves[/code] (a writeable per-user folder).
static var SAVE_DIR: String = PathConfig.SAVES_DIR

## File extension for save files.
const SAVE_EXT: String = ".json"

## Filename of the per-install signing key (auto-generated on first save).
static var SIGNING_KEY_FILE: String = PathConfig.SIGNING_KEY_FILE

## Length of the signing key in bytes.
const SIGNING_KEY_LEN: int = 32

## Path to the scenarios subfolder inside the AssetLoader root.
const SCENARIO_SUBFOLDER: String = "scenarios/"


## Logger for this system.
var _log: GameLogger = GameLogger.new("SaveGameManager")

## Cached signing key (loaded once per process).
var _signing_key: PackedByteArray = PackedByteArray()

## Command count at the last successful save.  Used by [method is_dirty]
## (legacy hot-seat semantics, only consulted when no checkpoint exists
## yet).  Reset to 0 on [method CommandProcessor.reset].
var _command_count_at_last_save: int = 0

## Phase J5.5 — per-mode checkpoint slots.  Each slot holds:
## [code]{"payload": Dictionary, "signature": String,
##   "last_named": String}[/code].  The keys are
## [constant SaveGameMetadata.MODE_HOT_SEAT] /
## [constant SaveGameMetadata.MODE_NETWORK].
var _checkpoints: Dictionary = {}

## Filename prefix reserved for system saves (checkpoints).
## Excluded from [method list_saves] / [method list_with_meta] when it
## matches one of the known checkpoint filenames.
const SYSTEM_PREFIX: String = "_checkpoint_"

## Save filenames for the per-mode checkpoints.
const CHECKPOINT_HOT_SEAT_NAME: String = "_checkpoint_hot_seat"
const CHECKPOINT_NETWORK_NAME: String = "_checkpoint_network"

## Debug — when [LoggingMode] is enabled, every successful checkpoint
## capture is also written to a numbered snapshot file
## ([code]_checkpoint_<mode>_NNN.json[/code]) so the full sequence can
## be inspected after the fact.  Counter is reset on each
## [signal EventBus.game_started].
var _debug_checkpoint_seq: Dictionary = {
	SaveGameMetadata.MODE_HOT_SEAT: 0,
	SaveGameMetadata.MODE_NETWORK: 0,
}


func _ready() -> void:
	_init_checkpoints()
	_load_checkpoints_from_disk()
	if is_instance_valid(CommandProcessor):
		CommandProcessor.command_executed.connect(
				_on_command_executed_refresh)
	if is_instance_valid(EventBus):
		EventBus.game_started.connect(_on_game_started_initial)
	# Phase J6: client-side toast when host saves.
	if is_instance_valid(NetworkManager):
		NetworkManager.save_notification_received.connect(
				_on_remote_save_notification)


## Shows a toast on the client when the host has saved the game.
## Phase J6.
func _on_remote_save_notification(display_name: String) -> void:
	if not is_instance_valid(TooltipManager):
		return
	var msg: String = "Host saved the game as \"%s\"." % display_name
	TooltipManager.show_text(msg, Vector2.INF, 3.0, true)


func _init_checkpoints() -> void:
	_checkpoints = {
		SaveGameMetadata.MODE_HOT_SEAT: _empty_slot(),
		SaveGameMetadata.MODE_NETWORK: _empty_slot(),
	}


func _empty_slot() -> Dictionary:
	return {
		"payload": {},
		"signature": "",
		"last_named": "",
	}


func _checkpoint_filename(mode: String) -> String:
	if mode == SaveGameMetadata.MODE_NETWORK:
		return CHECKPOINT_NETWORK_NAME
	return CHECKPOINT_HOT_SEAT_NAME


func _load_checkpoints_from_disk() -> void:
	for mode: String in [
			SaveGameMetadata.MODE_HOT_SEAT,
			SaveGameMetadata.MODE_NETWORK]:
		var name: String = _checkpoint_filename(mode)
		if not save_exists(name):
			continue
		var payload: Dictionary = _read_payload(name)
		if payload.is_empty():
			continue
		var header: Dictionary = payload.get("header", {}) as Dictionary
		var body: Dictionary = payload.get("state", {}) as Dictionary
		if header.is_empty() or body.is_empty():
			continue
		# Verify signature.  Invalid → ignore.
		if not IntegritySigner.is_signed(header):
			continue
		if not IntegritySigner.verify(
				header, body, _get_or_create_signing_key()):
			continue
		var slot: Dictionary = _checkpoints[mode]
		slot["payload"] = payload
		slot["signature"] = _signature_from_header(header)
		slot["last_named"] = slot["signature"]
		_log.info("Restored %s checkpoint from disk." % mode)


# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

## Saves [param game_state] to a JSON file with metadata header.
## [param file_name] — save name (without extension).  Used as
## [code]display_name[/code] if [param meta] is not provided.
## [param meta] — optional pre-built header.  If null, one is built from
## [param game_state] using the current scenario id and play mode.
##
## Phase J5.5: when a checkpoint exists for the current mode, the file
## is written from the checkpoint payload (not the live state) and only
## [code]display_name[/code] in the header is replaced.  This guarantees
## that named saves always reflect the most recent safe point even when
## the player presses Save mid-flow.
func save_game(
		game_state: GameState,
		file_name: String = "quicksave",
		meta: SaveGameMetadata = null) -> bool:
	if game_state == null:
		_log.error("save_game called with null game_state.")
		return false
	if file_name.begins_with(SYSTEM_PREFIX):
		_log.error("save_game refused: '%s' uses reserved prefix '%s'."
				% [file_name, SYSTEM_PREFIX])
		return false
	# Phase J6: only the host may write authoritative network saves.
	# Defense in depth — the UI already hides the Save button on the
	# client (GameMenuModal.NETWORK_CLIENT branch).
	if PlayMode != null and PlayMode.is_network() \
			and is_instance_valid(NetworkManager) \
			and not NetworkManager.is_server():
		_log.warn("save_game refused on network client (host-only).")
		return false
	if not _ensure_save_dir():
		return false
	# Phase J5.5: prefer the active mode's checkpoint payload over the
	# live state, so saves taken mid-flow capture the last safe point.
	var mode: String = _current_game_mode()
	var slot: Dictionary = _slot_for(mode)
	var use_checkpoint: bool = not slot.get("payload", {}).is_empty() \
			and meta == null
	if use_checkpoint:
		var source: Dictionary = (slot["payload"] as Dictionary).duplicate(true)
		var header: Dictionary = source.get("header", {}) as Dictionary
		var body: Dictionary = source.get("state", {}) as Dictionary
		header["display_name"] = file_name
		if not IntegritySigner.sign(
				header, body, _get_or_create_signing_key()):
			_log.error("save_game failed to re-sign checkpoint payload.")
			return false
		if not _write_payload(file_name, header, body):
			return false
		slot["last_named"] = slot["signature"]
		_command_count_at_last_save = _current_command_count()
		_log.info("Game saved to %s (from %s checkpoint)."
				% [_path_for(file_name), mode])
		return true
	if meta == null:
		meta = build_metadata_for(game_state, file_name)
	var validation: Dictionary = meta.validate()
	if not bool(validation.get("ok", false)):
		_log.error("save_game header invalid: %s" %
				validation.get("reason", "unknown"))
		return false
	var header_dict: Dictionary = meta.to_dict()
	var body_dict: Dictionary = game_state.serialize()
	if not IntegritySigner.sign(
			header_dict, body_dict, _get_or_create_signing_key()):
		_log.error("save_game failed to sign payload.")
		return false
	if not _write_payload(file_name, header_dict, body_dict):
		return false
	slot["last_named"] = slot.get("signature", "")
	_command_count_at_last_save = _current_command_count()
	_log.info("Game saved to %s (%s)" %
			[_path_for(file_name), meta.display_name])
	return true


## Loads a save file.  Returns a result dictionary:
## [codeblock]
## {
##   "ok": bool,
##   "state": GameState,        # null on failure
##   "meta": SaveGameMetadata,  # null on failure
##   "reason": String,          # one of: "missing", "parse_error",
##                              #   "schema_invalid", "version_unsupported",
##                              #   "signature_invalid", "header_invalid"
## }
## [/codeblock]
## Note: ship/squadron template re-association is the caller's
## responsibility (templates are [Resource] objects that cannot be in JSON).
func load_game(file_name: String = "quicksave") -> Dictionary:
	var file_path: String = _path_for(file_name)
	if not FileAccess.file_exists(file_path):
		_log.info("Save file not found: %s" % file_path)
		return _load_failure("missing")
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		_log.error("Failed to open save file for reading: %s" % file_path)
		return _load_failure("missing")
	var json_string: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var parse_err: Error = json.parse(json_string)
	if parse_err != OK:
		_log.error("Failed to parse save JSON: %s (line %d)" %
				[json.get_error_message(), json.get_error_line()])
		return _load_failure("parse_error")
	var data: Dictionary = json.data as Dictionary
	if data == null or not data.has("header") or not data.has("state"):
		_log.error("Save file schema invalid (missing header/state).")
		return _load_failure("schema_invalid")
	var header: Dictionary = data["header"] as Dictionary
	var body: Dictionary = data["state"] as Dictionary
	if header == null or body == null:
		return _load_failure("schema_invalid")
	var meta: SaveGameMetadata = SaveGameMetadata.from_dict(header)
	if meta.save_format_version != SaveGameMetadata.CURRENT_VERSION:
		_log.info("Save file version %d unsupported (expected %d)." %
				[meta.save_format_version, SaveGameMetadata.CURRENT_VERSION])
		return _load_failure("version_unsupported", null, meta)
	# Verify signature.  Unsigned saves are rejected; tampered saves are
	# rejected.  Only signatures produced by the current install's key
	# pass verification.
	if not IntegritySigner.is_signed(header):
		_log.info("Save file is unsigned: %s" % file_path)
		return _load_failure("signature_invalid", null, meta)
	if not IntegritySigner.verify(
			header, body, _get_or_create_signing_key()):
		_log.info("Save file signature invalid: %s" % file_path)
		return _load_failure("signature_invalid", null, meta)
	var state: GameState = GameState.deserialize(body)
	if state == null:
		return _load_failure("schema_invalid", null, meta)
	_log.info("Game loaded from %s (%s)" % [file_path, meta.display_name])
	return {
		"ok": true,
		"state": state,
		"meta": meta,
		"reason": "",
	}


# ---------------------------------------------------------------------------
# Metadata builder
# ---------------------------------------------------------------------------

## Builds a [SaveGameMetadata] header from the current runtime context.
## [param game_state] — supplies round and phase.
## [param display_name] — user-visible save name (also used as filename).
func build_metadata_for(
		game_state: GameState, display_name: String) -> SaveGameMetadata:
	var meta: SaveGameMetadata = SaveGameMetadata.new()
	meta.save_format_version = SaveGameMetadata.CURRENT_VERSION
	meta.scenario_id = _current_scenario_id()
	if meta.scenario_id.is_empty():
		meta.scenario_id = "unknown"
	meta.scenario_name = _resolve_scenario_name(meta.scenario_id)
	meta.game_mode = _current_game_mode()
	meta.current_round = game_state.current_round
	meta.phase = SaveGameMetadata.phase_label(game_state.current_phase)
	meta.created_at = Time.get_datetime_string_from_system(true)
	meta.app_version = String(Engine.get_version_info().get("string", ""))
	meta.display_name = display_name
	return meta


## Builds the default save-name template for the current state.
func default_save_name(game_state: GameState) -> String:
	if game_state == null:
		return "save"
	var scenario_name: String = _resolve_scenario_name(_current_scenario_id())
	return SaveGameMetadata.build_default_name(
			scenario_name,
			_current_game_mode(),
			game_state.current_round,
			SaveGameMetadata.phase_label(game_state.current_phase))


# ---------------------------------------------------------------------------
# Safe-point gate
# ---------------------------------------------------------------------------

## Returns whether the current [param game_state] is at a safe save point.
## Result: [code]{"ok": bool, "reason": String}[/code].  When [code]ok[/code]
## is false, [code]reason[/code] is a short human-readable explanation
## suitable for a tooltip.
## Steps at which it is safe to save — the player is between top-level
## actions, no ship/squadron is mid-activation, and any local UI state
## can be reconstructed from [GameState] after a load.
##
## Intentionally excludes [code]NONE[/code] (a transient gap left by
## commands that don't update the flow) and
## [code]ACTIVATION_DONE[/code] (a momentary marker before the flow
## resets to [code]WAIT_FOR_SHIP_SELECT[/code]).  Captures during those
## steps were observed mid-squadron-command and mid-displacement.
const _SAFE_STEPS: Array[Constants.InteractionStep] = [
	# Ship phase — between activations, no dial revealed yet.
	Constants.InteractionStep.WAIT_FOR_SHIP_SELECT,
	# Squadron phase — between squadron activations.
	Constants.InteractionStep.WAIT_FOR_SQUAD_SELECT,
	# Command phase — between dial submissions by the two players.
	Constants.InteractionStep.WAIT_FOR_OPPONENT_DIALS,
	# Status / Game Over — terminal phases, no per-ship flow.
	Constants.InteractionStep.STATUS_CLEANUP_STEP,
	Constants.InteractionStep.GAME_OVER_STEP,
]


## Returns whether the current [param game_state] is at a safe save point.
## Result: [code]{"ok": bool, "reason": String}[/code].  When [code]ok[/code]
## is false, [code]reason[/code] is a short human-readable explanation
## suitable for a tooltip.
##
## Safe points are determined by [member InteractionFlow.step_id] AND a
## structural invariant: no ship has a revealed (popped) command dial.
## A revealed dial means the active ship's activation has begun
## (squadron command, repair, attack, maneuver) but is not yet
## finalised, so the engine state is mid-transition and saving here
## would resume in an inconsistent UI state.
func can_save_now(game_state: GameState) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "No active game."}
	if game_state.current_phase == Constants.GamePhase.SETUP:
		return {"ok": false, "reason": "Cannot save during setup."}
	if game_state.interaction_flow != null:
		var step: Constants.InteractionStep = \
				game_state.interaction_flow.step_id
		if not _SAFE_STEPS.has(step):
			return {
				"ok": false,
				"reason": "Finish the current step before saving.",
			}
	# Structural invariant: in the SHIP phase, no ship may have a
	# revealed dial — that means an activation is already mid-flight
	# (e.g. a squadron command was just issued and we are between its
	# move/attack steps).
	if _any_ship_mid_activation(game_state):
		return {
			"ok": false,
			"reason": "Finish the current ship's activation before saving.",
		}
	# Phase-progression invariant: between activations, the
	# interaction_flow can briefly read WAIT_FOR_SHIP_SELECT /
	# WAIT_FOR_SQUAD_SELECT after the last activation finished but
	# before the AdvancePhase command fires.  Saving in that window
	# strands the game in the current phase with nothing to activate.
	if game_state.current_phase == Constants.GamePhase.SHIP \
			and not _any_player_has_unactivated_ships(game_state):
		return {
			"ok": false,
			"reason": "Phase transition pending — wait for next phase.",
		}
	if game_state.current_phase == Constants.GamePhase.SQUADRON \
			and not _any_player_has_unactivated_squadrons(game_state):
		return {
			"ok": false,
			"reason": "Phase transition pending — wait for next phase.",
		}
	return {"ok": true, "reason": ""}


## Returns true if any ship in [param game_state] has a revealed command
## dial — i.e. it has begun activation but has not yet spent its dial.
func _any_ship_mid_activation(game_state: GameState) -> bool:
	if game_state == null:
		return false
	for player_state: PlayerState in game_state.player_states:
		for ship: Variant in player_state.ships:
			if ship == null:
				continue
			if not ("command_dial_stack" in ship):
				continue
			var stack: Variant = ship.command_dial_stack
			if stack == null:
				continue
			if not stack.get_revealed_dial().is_empty():
				return true
	return false


## Returns true if at least one player has at least one ship still
## eligible to activate this round (alive and not yet activated).
func _any_player_has_unactivated_ships(game_state: GameState) -> bool:
	if game_state == null:
		return false
	for player_state: PlayerState in game_state.player_states:
		for ship: Variant in player_state.ships:
			if ship == null:
				continue
			if "is_destroyed" in ship and ship.is_destroyed():
				continue
			if "activated_this_round" in ship \
					and not ship.activated_this_round:
				return true
	return false


## Returns true if at least one player has at least one squadron still
## eligible to activate this round (alive and not yet activated).
func _any_player_has_unactivated_squadrons(game_state: GameState) -> bool:
	if game_state == null:
		return false
	for player_state: PlayerState in game_state.player_states:
		for sq: Variant in player_state.squadrons:
			if sq == null:
				continue
			if "is_destroyed" in sq and sq.is_destroyed():
				continue
			if "activated_this_round" in sq \
					and not sq.activated_this_round:
				return true
	return false


## Returns whether the current game has advanced since the last save.
## Used by the ESC menu to prompt "Save first?" before quit (Phase J Q4).
##
## Phase J5.5: per-mode semantics.  Returns [code]true[/code] iff the
## given mode's checkpoint signature differs from the signature recorded
## at the last named save of that mode.  When [param mode] is empty,
## defaults to the current active mode.  Falls back to the legacy
## command-count comparison when no checkpoint has been written yet
## (e.g. very first command after game_started).
func is_dirty(mode: String = "") -> bool:
	if not is_instance_valid(GameManager) or not GameManager.is_game_active:
		return false
	var resolved_mode: String = mode
	if resolved_mode.is_empty():
		resolved_mode = _current_game_mode()
	var slot: Dictionary = _slot_for(resolved_mode)
	var sig: String = String(slot.get("signature", ""))
	var last: String = String(slot.get("last_named", ""))
	if sig.is_empty() and last.is_empty():
		# No checkpoint yet — use legacy counter.
		return _current_command_count() > _command_count_at_last_save
	return sig != last


## Resets the dirty-tracking counter and per-mode last-named
## signatures.  Call when starting a new game or loading a save so the
## freshly-installed state is considered clean.
func mark_clean() -> void:
	_command_count_at_last_save = _current_command_count()
	for mode: String in _checkpoints.keys():
		var slot: Dictionary = _checkpoints[mode]
		slot["last_named"] = slot.get("signature", "")


# ---------------------------------------------------------------------------
# Phase J5.5 — Checkpoint refresh + public checkpoint API
# ---------------------------------------------------------------------------

## Returns [code]true[/code] iff a checkpoint payload exists for the
## given mode.  Defaults to the current active mode.
func has_checkpoint(mode: String = "") -> bool:
	var resolved: String = mode if not mode.is_empty() else _current_game_mode()
	var slot: Dictionary = _slot_for(resolved)
	return not (slot.get("payload", {}) as Dictionary).is_empty()


## Returns the [SaveGameMetadata] of the given mode's checkpoint, or
## [code]null[/code] when none exists.
func checkpoint_metadata(mode: String = "") -> SaveGameMetadata:
	var resolved: String = mode if not mode.is_empty() else _current_game_mode()
	var slot: Dictionary = _slot_for(resolved)
	var payload: Dictionary = slot.get("payload", {}) as Dictionary
	if payload.is_empty():
		return null
	var header: Dictionary = payload.get("header", {}) as Dictionary
	if header.is_empty():
		return null
	return SaveGameMetadata.from_dict(header)


## Loads the given mode's checkpoint as if it were a regular save file.
## Returns the same shape as [method load_game]; result is
## [code]{"ok": false, "reason": "missing"}[/code] when no checkpoint
## exists for that mode.
func load_game_from_checkpoint(mode: String) -> Dictionary:
	var slot: Dictionary = _slot_for(mode)
	var payload: Dictionary = slot.get("payload", {}) as Dictionary
	if payload.is_empty():
		return _load_failure("missing")
	var header: Dictionary = payload.get("header", {}) as Dictionary
	var body: Dictionary = payload.get("state", {}) as Dictionary
	if header.is_empty() or body.is_empty():
		return _load_failure("schema_invalid")
	var meta: SaveGameMetadata = SaveGameMetadata.from_dict(header)
	if not IntegritySigner.is_signed(header):
		return _load_failure("signature_invalid", null, meta)
	if not IntegritySigner.verify(
			header, body, _get_or_create_signing_key()):
		return _load_failure("signature_invalid", null, meta)
	var state: GameState = GameState.deserialize(body)
	if state == null:
		return _load_failure("schema_invalid", null, meta)
	return {
		"ok": true,
		"state": state,
		"meta": meta,
		"reason": "",
	}


func _slot_for(mode: String) -> Dictionary:
	if _checkpoints.is_empty():
		_init_checkpoints()
	if not _checkpoints.has(mode):
		_checkpoints[mode] = _empty_slot()
	return _checkpoints[mode]


## Clears in-memory checkpoint state and removes both checkpoint files.
## Intended for tests and "clear data" UX.
func clear_checkpoints() -> void:
	_init_checkpoints()
	delete_save(CHECKPOINT_HOT_SEAT_NAME)
	delete_save(CHECKPOINT_NETWORK_NAME)


## Refreshes the active mode's checkpoint when [param command] resolves
## at a safe point.  Wired to [signal CommandProcessor.command_executed]
## in [method _ready].  No-op when [method can_save_now] returns false.
func _on_command_executed_refresh(
		_command: GameCommand, _result: Dictionary) -> void:
	if not is_instance_valid(GameManager) \
			or not GameManager.is_game_active \
			or GameManager.current_game_state == null:
		return
	var state: GameState = GameManager.current_game_state
	var gate: Dictionary = can_save_now(state)
	if not bool(gate.get("ok", false)):
		if is_instance_valid(LoggingMode) and LoggingMode.enabled:
			_log.info("Checkpoint skipped — %s (%s)" % [
					gate.get("reason", "unsafe"),
					_checkpoint_context_string(state)])
		return
	_capture_checkpoint(state)


## Writes the initial checkpoint when a game starts (or is loaded).
## Bypasses the safe-point gate — a freshly built [GameState] is by
## construction at a safe point.  No numbered debug snapshot is written
## here: the game-start state is not interesting for diagnosis (use the
## first command's checkpoint as the diagnostic baseline).
func _on_game_started_initial() -> void:
	if not is_instance_valid(GameManager) \
			or not GameManager.is_game_active \
			or GameManager.current_game_state == null:
		return
	# Reset numbered debug snapshots so each session starts from 001.
	_reset_debug_checkpoint_snapshots()
	_capture_checkpoint(GameManager.current_game_state, true, false)
	# Fresh state is considered clean for the active mode.
	var slot: Dictionary = _slot_for(_current_game_mode())
	slot["last_named"] = slot.get("signature", "")


func _capture_checkpoint(
		state: GameState,
		bypass_gate: bool = false,
		write_debug_snapshot: bool = true) -> void:
	# Belt-and-braces re-check: any caller of this method must have
	# verified [method can_save_now], but reaffirm here so a future
	# caller cannot accidentally write an unsafe checkpoint.  The
	# initial game-start path passes [code]bypass_gate=true[/code]
	# because a freshly built [GameState] is safe by construction.
	if not bypass_gate:
		var gate: Dictionary = can_save_now(state)
		if not gate.get("ok", false):
			if is_instance_valid(LoggingMode) and LoggingMode.enabled:
				_log.info("Checkpoint capture refused — %s (%s)" % [
						gate.get("reason", "unsafe"),
						_checkpoint_context_string(state)])
			return
	var mode: String = _current_game_mode()
	var slot: Dictionary = _slot_for(mode)
	var meta: SaveGameMetadata = build_metadata_for(state, "")
	# Skip auto-capture when there is no real scenario context (test
	# fixtures that build a GameState directly).  These can have
	# partially-populated ship/squadron lists that would crash
	# state.serialize().
	if meta.scenario_id == "unknown" or meta.scenario_id.is_empty():
		return
	var header: Dictionary = meta.to_dict()
	var body: Dictionary = state.serialize()
	if not IntegritySigner.sign(
			header, body, _get_or_create_signing_key()):
		_log.warn("Could not sign checkpoint payload.")
		return
	var payload: Dictionary = {"header": header, "state": body}
	slot["payload"] = payload
	slot["signature"] = _signature_from_header(header)
	# Persist to disk so we survive crashes.
	if _ensure_save_dir():
		_write_payload(_checkpoint_filename(mode), header, body)
		if write_debug_snapshot:
			_maybe_write_debug_snapshot(mode, header, body, state)


## Returns a short human-readable summary of [param state]'s position in
## the game flow.  Used for INFO-level checkpoint logging.
func _checkpoint_context_string(state: GameState) -> String:
	var step: int = -1
	if state != null and state.interaction_flow != null:
		step = int(state.interaction_flow.step_id)
	var step_name: String = Constants.InteractionStep.keys()[step] \
			if step >= 0 and step < Constants.InteractionStep.size() \
			else "?"
	var phase: int = -1
	if state != null:
		phase = int(state.current_phase)
	var phase_name: String = Constants.GamePhase.keys()[phase] \
			if phase >= 0 and phase < Constants.GamePhase.size() \
			else "?"
	var round_n: int = state.current_round if state != null else -1
	var seq: int = _current_command_count()
	return "round=%d phase=%s step=%s cmd_seq=%d" % [
			round_n, phase_name, step_name, seq]


## Writes a numbered debug copy of the checkpoint when [LoggingMode] is
## enabled.  Files are named [code]_checkpoint_<mode>_NNN.json[/code]
## (NNN = 3-digit zero-padded sequence) and live alongside the canonical
## checkpoint.  Counter increments per capture; reset on game_started.
func _maybe_write_debug_snapshot(
		mode: String,
		header: Dictionary,
		body: Dictionary,
		state: GameState) -> void:
	if not is_instance_valid(LoggingMode) or not LoggingMode.enabled:
		return
	var seq: int = int(_debug_checkpoint_seq.get(mode, 0)) + 1
	_debug_checkpoint_seq[mode] = seq
	var debug_name: String = "%s_%03d" % [_checkpoint_filename(mode), seq]
	_write_payload(debug_name, header, body)
	_log.info("Checkpoint captured #%03d (%s) — %s → %s" % [
			seq, mode, _checkpoint_context_string(state),
			_path_for(debug_name)])


## Seeds the per-mode debug-snapshot counter from any numbered files
## already on disk, so subsequent captures append (e.g. _006, _007)
## rather than overwriting an existing series.  Called from
## [method _on_game_started_initial].
##
## Existing numbered snapshots are intentionally NOT deleted: when the
## user loads a checkpoint to diagnose a bad capture, the rest of the
## series must remain available for inspection.
func _reset_debug_checkpoint_snapshots() -> void:
	_debug_checkpoint_seq[SaveGameMetadata.MODE_HOT_SEAT] = \
			_max_debug_snapshot_seq(SaveGameMetadata.MODE_HOT_SEAT)
	_debug_checkpoint_seq[SaveGameMetadata.MODE_NETWORK] = \
			_max_debug_snapshot_seq(SaveGameMetadata.MODE_NETWORK)


## Scans [SAVE_DIR] for numbered debug snapshots belonging to
## [param mode] and returns the highest sequence number found, or 0 if
## none exist.
func _max_debug_snapshot_seq(mode: String) -> int:
	var highest: int = 0
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		return highest
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir == null:
		return highest
	var prefix: String = _checkpoint_filename(mode) + "_"
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() \
				and entry.ends_with(SAVE_EXT) \
				and entry.begins_with(prefix) \
				and _is_numbered_debug_snapshot(entry):
			var stem: String = entry.substr(
					0, entry.length() - SAVE_EXT.length())
			var us: int = stem.rfind("_")
			var tail: String = stem.substr(us + 1)
			if tail.is_valid_int():
				highest = max(highest, int(tail))
		entry = dir.get_next()
	dir.list_dir_end()
	return highest


## Returns true if [param file_name] matches the numbered debug snapshot
## pattern [code]_checkpoint_<mode>_NNN.json[/code].
func _is_numbered_debug_snapshot(file_name: String) -> bool:
	# Form: _checkpoint_<mode>_<digits>.json
	if not file_name.ends_with(SAVE_EXT):
		return false
	var stem: String = file_name.substr(0, file_name.length() - SAVE_EXT.length())
	var us: int = stem.rfind("_")
	if us < 0:
		return false
	var tail: String = stem.substr(us + 1)
	if tail.is_empty():
		return false
	return tail.is_valid_int()


func _signature_from_header(header: Dictionary) -> String:
	return "%s|%s|%d" % [
			String(header.get("created_at", "")),
			String(header.get("signature", "")),
			int(header.get("current_round", 0))]


func _write_payload(
		file_name: String,
		header: Dictionary,
		body: Dictionary) -> bool:
	var data: Dictionary = {"header": header, "state": body}
	var path: String = _path_for(file_name)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_log.error("Failed to open save file for writing: %s" % path)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


func _read_payload(file_name: String) -> Dictionary:
	var path: String = _path_for(file_name)
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return {}
	var data: Dictionary = json.data as Dictionary
	if data == null:
		return {}
	return data


# ---------------------------------------------------------------------------
# Listing / deletion
# ---------------------------------------------------------------------------

## Returns an array of available save file names (without extension).
## Phase J5.5: filenames starting with [constant SYSTEM_PREFIX] (the
## [code]_[/code] prefix) are excluded — these are reserved for
## checkpoints and other internal artefacts.
func list_saves() -> Array[String]:
	var saves: Array[String] = []
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		return saves
	var include_debug: bool = is_instance_valid(LoggingMode) \
			and LoggingMode.enabled
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir == null:
		return saves
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(SAVE_EXT):
			var is_system: bool = entry.begins_with(SYSTEM_PREFIX)
			var is_numbered_debug: bool = is_system \
					and _is_numbered_debug_snapshot(entry)
			if not is_system or (include_debug and is_numbered_debug):
				saves.append(entry.trim_suffix(SAVE_EXT))
		entry = dir.get_next()
	dir.list_dir_end()
	return saves


## Returns an array of [code]{"name": String, "meta": SaveGameMetadata,
## "valid": bool, "reason": String}[/code] for every save file in
## [constant SAVE_DIR].  Files that fail to parse are included with
## [code]valid=false[/code] and a reason so the UI can show them as
## errored entries.  Sorted by [member SaveGameMetadata.created_at]
## descending (most recent first); entries without a timestamp sort last.
func list_with_meta() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for name: String in list_saves():
		rows.append(_inspect_save(name))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: String = ""
		var tb: String = ""
		if a.get("meta") != null:
			ta = (a["meta"] as SaveGameMetadata).created_at
		if b.get("meta") != null:
			tb = (b["meta"] as SaveGameMetadata).created_at
		return ta > tb)
	return rows


## Deletes a save file.
## [param file_name] — the save file name (without extension).
## Returns [code]true[/code] if the file was deleted.
func delete_save(file_name: String) -> bool:
	var file_path: String = _path_for(file_name)
	if not FileAccess.file_exists(file_path):
		_log.info("Save file not found for deletion: %s" % file_path)
		return false
	var err: Error = DirAccess.remove_absolute(file_path)
	if err != OK:
		_log.error("Failed to delete save file: %s" % file_path)
		return false
	_log.info("Save file deleted: %s" % file_path)
	return true


## Returns [code]true[/code] iff a save with the given name exists.
func save_exists(file_name: String) -> bool:
	return FileAccess.file_exists(_path_for(file_name))


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _path_for(file_name: String) -> String:
	return "%s/%s%s" % [SAVE_DIR, file_name, SAVE_EXT]


func _ensure_save_dir() -> bool:
	if DirAccess.dir_exists_absolute(SAVE_DIR):
		return true
	var err: Error = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if err != OK:
		_log.error("Failed to create save directory: %s" % SAVE_DIR)
		return false
	return true


func _load_failure(
		reason: String,
		state: GameState = null,
		meta: SaveGameMetadata = null) -> Dictionary:
	return {
		"ok": false,
		"state": state,
		"meta": meta,
		"reason": reason,
	}


## Reads the current scenario id from [GameManager].  Returns ""
## when no game is active.
func _current_scenario_id() -> String:
	if GameManager == null:
		return ""
	if GameManager.has_method("get_scenario_id"):
		return String(GameManager.get_scenario_id())
	return ""


## Returns [CommandProcessor.get_command_count] safely (guards against
## the autoload being unavailable in unit-test contexts).
func _current_command_count() -> int:
	if not is_instance_valid(CommandProcessor):
		return 0
	return CommandProcessor.get_command_count()


## Reads the current game mode from [PlayMode].  Defaults to hot-seat.
func _current_game_mode() -> String:
	if PlayMode != null and PlayMode.is_network():
		return SaveGameMetadata.MODE_NETWORK
	return SaveGameMetadata.MODE_HOT_SEAT


## Lazy-loads or generates the per-install signing key.  The key is a
## random 32-byte sequence stored in [constant SIGNING_KEY_FILE].  This
## key is local-only — it's not a security boundary against a determined
## attacker with filesystem access; it just makes accidental hand-edits
## of save files visible.
func _get_or_create_signing_key() -> PackedByteArray:
	if not _signing_key.is_empty():
		return _signing_key
	if FileAccess.file_exists(SIGNING_KEY_FILE):
		var f: FileAccess = FileAccess.open(SIGNING_KEY_FILE, FileAccess.READ)
		if f != null:
			_signing_key = f.get_buffer(SIGNING_KEY_LEN)
			f.close()
			if _signing_key.size() == SIGNING_KEY_LEN:
				return _signing_key
	# Generate a new key.
	_ensure_save_dir()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(SIGNING_KEY_LEN)
	for i: int in range(SIGNING_KEY_LEN):
		bytes[i] = rng.randi_range(0, 255)
	_signing_key = bytes
	var f2: FileAccess = FileAccess.open(SIGNING_KEY_FILE, FileAccess.WRITE)
	if f2 != null:
		f2.store_buffer(bytes)
		f2.close()
	else:
		_log.warn("Could not persist signing key to %s; key is in-memory only."
				% SIGNING_KEY_FILE)
	return _signing_key


## Resolves the human-readable scenario name from the scenario JSON's
## [code]scenario_name[/code] field.  Falls back to a title-cased version
## of [param scenario_id] if the file cannot be read.
func _resolve_scenario_name(scenario_id: String) -> String:
	if scenario_id.is_empty():
		return "Unknown"
	var data: Dictionary = AssetLoader.load_json(
			SCENARIO_SUBFOLDER, scenario_id + ".json")
	var name: String = data.get("scenario_name", "") as String
	if not name.is_empty():
		return name
	return scenario_id.replace("_", " ").capitalize()


## Reads a save file's header without deserialising the full state.
## Returns one of:
## [codeblock]
## {"name": String, "meta": SaveGameMetadata, "valid": true,  "reason": ""}
## {"name": String, "meta": null,             "valid": false, "reason": "<why>"}
## [/codeblock]
func _inspect_save(file_name: String) -> Dictionary:
	var path: String = _path_for(file_name)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"name": file_name, "meta": null,
			"valid": false, "reason": "missing",
		}
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return {
			"name": file_name, "meta": null,
			"valid": false, "reason": "parse_error",
		}
	var data: Dictionary = json.data as Dictionary
	if data == null or not data.has("header"):
		return {
			"name": file_name, "meta": null,
			"valid": false, "reason": "schema_invalid",
		}
	var meta: SaveGameMetadata = SaveGameMetadata.from_dict(
			data["header"] as Dictionary)
	var ok: bool = (meta.save_format_version == SaveGameMetadata.CURRENT_VERSION)
	return {
		"name": file_name,
		"meta": meta,
		"valid": ok,
		"reason": "" if ok else "version_unsupported",
	}
