extends SceneTree


func _initialize() -> void:
	var shared := _arg("--shared=")
	if _arg("--section-d-only=") != "true":
		if not _assert_fresh_and_reconnect(shared):
			return
	if not _assert_network_same_live_compatibility(shared):
		return
	if not _assert_hot_seat_compatibility(shared):
		return
	if not _assert_network_replay_compatibility(_arg("--replay="), _arg("--logs="), shared):
		return
	print("MATCH-003 REAL ENET ACCEPTANCE: A-C plus Section 14.2 D compatibility passed")
	quit(0)


func _assert_fresh_and_reconnect(shared: String) -> bool:
	for mapping: int in [0, 1]:
		for role: String in ["host", "client"]:
			var path := shared.path_join("fresh-" + role + "-" + str(mapping) + ".json")
			var record := _load_record(path)
			if record.is_empty():
				return false
			if not bool(record.get("ok", false)) or int(record.get("protocol", 0)) != 4 \
					or not bool(record.get("admission", false)) \
					or int(record.get("canonical_installs", 0)) != 1 \
					or int(record.get("board_releases", 0)) != 1:
				_fail("fresh-resume process evidence is incomplete: " + path)
				return false
			if mapping == 0 and int(record.get("player_index", -1)) != \
					(0 if role == "host" else 1):
				_fail("swapped assignment did not reach the selected side: " + path)
				return false
			if mapping == 1 and int(record.get("player_index", -1)) != \
					(1 if role == "host" else 0):
				_fail("opposite explicit assignment did not reach the selected side: " + path)
				return false
			if role == "host" and not bool(record.get("persisted_save_loaded", false)):
				_fail("host did not resume through a persisted save/load candidate: " + path)
				return false
	for role: String in ["host", "incumbent", "failed_reconnect", "reconnect"]:
		var path := shared.path_join("reconnect-" + role + ".json")
		var record := _load_record(path)
		if record.is_empty() or not bool(record.get("ok", false)):
			_fail("reconnect process failed: " + path)
			return false
		if role == "host" and (int(record.get("canonical_installs", 0)) != 1 \
				or int(record.get("board_releases", 0)) != 1 \
				or int(record.get("reconnect_offers", 0)) < 2):
			_fail("host republished or did not retry explicit reconnect: " + path)
			return false
		if role == "reconnect" and (not bool(record.get("admission", false)) \
				or int(record.get("canonical_installs", 0)) != 1 \
				or int(record.get("board_releases", 0)) != 1):
			_fail("clean reconnect was not installed/released exactly once: " + path)
			return false
	return true


func _assert_network_same_live_compatibility(shared: String) -> bool:
	for role: String in ["host", "client"]:
		var path := shared.path_join("compat-network-" + role + ".json")
		var record := _load_record(path)
		if record.is_empty():
			return false
		var compatibility: Dictionary = record.get("compatibility", {}) as Dictionary
		if not bool(record.get("ok", false)) \
				or int(record.get("protocol", 0)) != 4 \
				or int(record.get("canonical_installs", 0)) != 3 \
				or int(record.get("board_releases", 0)) != 3 \
				or bool(record.get("resume_attempt_active", true)) \
				or compatibility.get("before", {}) != compatibility.get("after", {}):
			_fail("same-live Network named/checkpoint compatibility failed: " + path)
			return false
		if role == "host":
			if int(compatibility.get("named_save_v5", 0)) != 5 \
					or int(compatibility.get("checkpoint_v5", 0)) != 5 \
					or not bool(compatibility.get("checkpoint_persisted", false)) \
					or int(compatibility.get("assignment_events_after_initial", -1)) != 0:
				_fail("same-live Network save v5/checkpoint or no-assignment boundary failed: " + path)
				return false
	return true


func _assert_hot_seat_compatibility(shared: String) -> bool:
	var path := shared.path_join("compat-hot-seat.json")
	var record := _load_record(path)
	if record.is_empty():
		return false
	var compatibility: Dictionary = record.get("compatibility", {}) as Dictionary
	if not bool(record.get("ok", false)) \
			or int(record.get("canonical_installs", 0)) != 2 \
			or int(record.get("assignment_events", -1)) != 0 \
			or bool(record.get("resume_attempt_active", true)) \
			or int(compatibility.get("named_save_v5", 0)) != 5 \
			or int(compatibility.get("checkpoint_v5", 0)) != 5 \
			or not bool(compatibility.get("checkpoint_persisted", false)) \
			or compatibility.get("binding_before", {}) != compatibility.get("binding_after", {}) \
			or int(compatibility.get("network_role", -1)) != 0 \
			or int(compatibility.get("network_peers", -1)) != 0:
		_fail("Hot-Seat named/checkpoint compatibility or no-assignment boundary failed: " + path)
		return false
	return true


func _assert_network_replay_compatibility(
		replay_path: String, logs: String, shared: String) -> bool:
	if not FileAccess.file_exists(replay_path):
		_fail("Network replay artifact is missing: " + replay_path)
		return false
	var parsed := JSON.new()
	if parsed.parse(FileAccess.get_file_as_string(replay_path)) != OK \
			or not (parsed.data is Dictionary):
		_fail("Network replay artifact is not valid JSON: " + replay_path)
		return false
	var replay_data: Dictionary = parsed.data as Dictionary
	var header: Dictionary = replay_data.get("header", {}) as Dictionary
	if int(header.get("format_version", 0)) != 7 \
			or not (header.get("match_player_control_binding", {}) is Dictionary) \
			or not (replay_data.get("commands", []) is Array):
		_fail("Network replay artifact is not persisted replay format 7: " + replay_path)
		return false
	var host_hash_path := shared.path_join("network-replay-host.jsonl.state_hash")
	var client_hash_path := shared.path_join("network-replay-client.jsonl.state_hash")
	if not FileAccess.file_exists(host_hash_path) or not FileAccess.file_exists(client_hash_path):
		_fail("Network replay produced no final-state evidence.")
		return false
	var host_hash := FileAccess.get_file_as_string(host_hash_path).strip_edges()
	var client_hash := FileAccess.get_file_as_string(client_hash_path).strip_edges()
	if host_hash.is_empty() or host_hash != client_hash:
		_fail("Network replay peers did not finish with the same canonical state hash.")
		return false
	var host_log := logs.path_join("compat-replay-host.log")
	if not FileAccess.file_exists(host_log):
		_fail("Network replay host log is missing.")
		return false
	var log_text := FileAccess.get_file_as_string(host_log)
	if log_text.find("protocol v4") == -1 or log_text.find("Handshake from peer") == -1 \
			or log_text.find(" v4,") == -1:
		_fail("Network replay did not negotiate protocol 4 over live ENet.")
		return false
	if log_text.to_lower().find("fresh resume") != -1 \
			or log_text.to_lower().find("explicit side assignment") != -1:
		_fail("Network replay emitted fresh-resume assignment traffic.")
		return false
	return true


func _load_record(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_fail("missing compatibility process evidence: " + path)
		return {}
	var parsed := JSON.new()
	if parsed.parse(FileAccess.get_file_as_string(path)) != OK or not (parsed.data is Dictionary):
		_fail("invalid compatibility process evidence: " + path)
		return {}
	return parsed.data as Dictionary


func _arg(prefix: String) -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix):
			return value.trim_prefix(prefix)
	return ""
func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
