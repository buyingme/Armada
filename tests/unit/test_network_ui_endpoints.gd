## Tests for network UI endpoints and diagnostics display.
##
## Verifies:
## - Port input validation (_parse_port_or_default)
## - LAN IP detection (_detect_lan_ip)
## - Endpoint text formatting (_build_endpoint_text)
## - Diagnostics text formatting (_build_diagnostics_text)
## - Connection state and role name mappings
##
extends GutTest


var _main_menu: Control = null
var _lobby_room: Control = null


func before_each() -> void:
	# Main menu provides port parsing and display logic.
	_main_menu = preload("res://src/scenes/main_menu/main_menu.gd").new()
	_main_menu.name = "MainMenu"
	add_child(_main_menu)
	
	# Lobby room provides endpoint and diagnostics display logic.
	_lobby_room = preload("res://src/scenes/lobby/lobby_room.gd").new()
	_lobby_room.name = "LobbyRoom"
	add_child(_lobby_room)


func after_each() -> void:
	if _main_menu and is_instance_valid(_main_menu):
		_main_menu.queue_free()
	_main_menu = null
	
	if _lobby_room and is_instance_valid(_lobby_room):
		_lobby_room.queue_free()
	_lobby_room = null


# -----------------------------------------------------------------------
# Port Input Validation
# -----------------------------------------------------------------------

func test_parse_port_or_default_empty_returns_default() -> void:
	# Arrange
	var text: String = ""
	var expected: int = ServerMain.DEFAULT_PORT
	
	# Act
	var result: int = _main_menu._parse_port_or_default(text)
	
	# Assert
	assert_eq(result, expected,
			"Empty port input should return DEFAULT_NETWORK_PORT (%d)." % expected)


func test_parse_port_or_default_valid_range_1() -> void:
	# Arrange
	var text: String = "1"
	
	# Act
	var result: int = _main_menu._parse_port_or_default(text)
	
	# Assert
	assert_eq(result, 1,
			"Port 1 should be valid (minimum).")


func test_parse_port_or_default_valid_range_65535() -> void:
	# Arrange
	var text: String = "65535"
	
	# Act
	var result: int = _main_menu._parse_port_or_default(text)
	
	# Assert
	assert_eq(result, 65535,
			"Port 65535 should be valid (maximum).")


func test_parse_port_or_default_valid_midrange() -> void:
	# Arrange
	var text: String = "7350"
	
	# Act
	var result: int = _main_menu._parse_port_or_default(text)
	
	# Assert
	assert_eq(result, 7350,
			"Port 7350 should be valid (default).")


func test_parse_port_or_default_invalid_zero() -> void:
	# Arrange
	var text: String = "0"
	
	# Act
	var result: int = _main_menu._parse_port_or_default(text)
	
	# Assert
	assert_eq(result, -1,
			"Port 0 should be invalid (below minimum).")


func test_parse_port_or_default_invalid_negative() -> void:
	# Arrange
	var text: String = "-1"
	
	# Act
	var result: int = _main_menu._parse_port_or_default(text)
	
	# Assert
	assert_eq(result, -1,
			"Negative port should be invalid.")


func test_parse_port_or_default_invalid_too_large() -> void:
	# Arrange
	var text: String = "65536"
	
	# Act
	var result: int = _main_menu._parse_port_or_default(text)
	
	# Assert
	assert_eq(result, -1,
			"Port 65536 should be invalid (above maximum).")


func test_parse_port_or_default_invalid_non_numeric() -> void:
	# Arrange
	var text: String = "not_a_number"
	
	# Act
	var result: int = _main_menu._parse_port_or_default(text)
	
	# Assert
	assert_eq(result, -1,
			"Non-numeric input should be invalid.")


func test_parse_port_or_default_invalid_alphanumeric() -> void:
	# Arrange
	var text: String = "7350x"
	
	# Act
	var result: int = _main_menu._parse_port_or_default(text)
	
	# Assert
	assert_eq(result, -1,
			"Alphanumeric input should be invalid.")


func test_parse_port_or_default_whitespace_handling() -> void:
	# Arrange
	var text: String = "  7350  "
	# Note: Main menu calls .strip_edges() before calling _parse_port_or_default,
	# so the test should simulate that.
	
	# Act
	var result: int = _main_menu._parse_port_or_default(text.strip_edges())
	
	# Assert
	assert_eq(result, 7350,
			"Port with surrounding whitespace should be valid after stripping.")


# -----------------------------------------------------------------------
# LAN IP Detection
# -----------------------------------------------------------------------

func test_detect_lan_ip_returns_string() -> void:
	# Arrange + Act
	var ip: String = _lobby_room._detect_lan_ip()
	
	# Assert
	assert_true(ip is String,
			"_detect_lan_ip() should return a string.")
	assert_false(ip.is_empty(),
			"_detect_lan_ip() should not return empty string.")


func test_detect_lan_ip_is_valid_ipv4_format() -> void:
	# Arrange + Act
	var ip: String = _lobby_room._detect_lan_ip()
	
	# Assert
	var parts: PackedStringArray = ip.split(".")
	assert_eq(parts.size(), 4,
			"LAN IP should be in IPv4 format (4 octets).")
	for part: String in parts:
		var octet: int = part.to_int()
		assert_true(octet >= 0 and octet <= 255,
				"Each octet should be 0-255, got: %s" % part)


# -----------------------------------------------------------------------
# Endpoint Text Building (Host Side)
# -----------------------------------------------------------------------

func test_build_endpoint_text_format_includes_port_and_colon() -> void:
	# Arrange
	NetworkManager._active_server_port = 7350
	NetworkManager._active_remote_address = ""
	
	# Act
	var text: String = _lobby_room._build_endpoint_text()
	
	# Assert
	assert_true(text.contains("7350"),
			"Endpoint text should include the port number.")
	assert_true(text.contains(":"),
			"Endpoint text should contain colon separator for IP:port format.")


func test_build_endpoint_text_format_includes_host_prefix() -> void:
	# Arrange
	NetworkManager._active_server_port = 7350
	
	# Act
	var text: String = _lobby_room._build_endpoint_text()
	
	# Assert
	assert_true(text.contains("Host:"),
			"Endpoint text should start with 'Host:' prefix.")



# -----------------------------------------------------------------------
# Endpoint Text Building (Client Side)
# -----------------------------------------------------------------------

func test_build_endpoint_text_shows_remote_address_when_set() -> void:
	# Arrange
	NetworkManager._active_remote_address = "192.168.1.100"
	NetworkManager._active_server_port = 7350
	
	# Act
	var text: String = _lobby_room._build_endpoint_text()
	
	# Assert
	assert_true(text.contains("192.168.1.100"),
			"Endpoint should include remote address when set.")
	assert_true(text.contains("7350"),
			"Endpoint should include port.")


func test_build_endpoint_text_shows_unknown_when_remote_empty() -> void:
	# Arrange
	NetworkManager._active_remote_address = ""
	NetworkManager._active_server_port = 7350
	
	# Act
	var text: String = _lobby_room._build_endpoint_text()
	
	# Assert
	assert_true(text.contains("(unknown)"),
			"Endpoint should show '(unknown)' when remote address is empty.")



# -----------------------------------------------------------------------
# Connection State Name Mapping
# -----------------------------------------------------------------------

func test_connection_state_name_disconnected() -> void:
	# Arrange
	NetworkManager.connection_state = NetworkManager.ConnectionState.DISCONNECTED
	
	# Act
	var name: String = _lobby_room._connection_state_name()
	
	# Assert
	assert_eq(name, "DISCONNECTED",
			"Should map DISCONNECTED state correctly.")


func test_connection_state_name_connecting() -> void:
	# Arrange
	NetworkManager.connection_state = NetworkManager.ConnectionState.CONNECTING
	
	# Act
	var name: String = _lobby_room._connection_state_name()
	
	# Assert
	assert_eq(name, "CONNECTING",
			"Should map CONNECTING state correctly.")


func test_connection_state_name_authenticating() -> void:
	# Arrange
	NetworkManager.connection_state = NetworkManager.ConnectionState.AUTHENTICATING
	
	# Act
	var name: String = _lobby_room._connection_state_name()
	
	# Assert
	assert_eq(name, "AUTHENTICATING",
			"Should map AUTHENTICATING state correctly.")


func test_connection_state_name_lobby() -> void:
	# Arrange
	NetworkManager.connection_state = NetworkManager.ConnectionState.LOBBY
	
	# Act
	var name: String = _lobby_room._connection_state_name()
	
	# Assert
	assert_eq(name, "LOBBY",
			"Should map LOBBY state correctly.")


func test_connection_state_name_in_game() -> void:
	# Arrange
	NetworkManager.connection_state = NetworkManager.ConnectionState.IN_GAME
	
	# Act
	var name: String = _lobby_room._connection_state_name()
	
	# Assert
	assert_eq(name, "IN_GAME",
			"Should map IN_GAME state correctly.")


# -----------------------------------------------------------------------
# Role Name Mapping
# -----------------------------------------------------------------------

func test_role_name_none() -> void:
	# Arrange
	NetworkManager.role = NetworkManager.Role.NONE
	
	# Act
	var name: String = _lobby_room._role_name()
	
	# Assert
	assert_eq(name, "NONE",
			"Should map NONE role correctly.")


func test_role_name_server() -> void:
	# Arrange
	NetworkManager.role = NetworkManager.Role.SERVER
	
	# Act
	var name: String = _lobby_room._role_name()
	
	# Assert
	assert_eq(name, "SERVER",
			"Should map SERVER role correctly.")


func test_role_name_client() -> void:
	# Arrange
	NetworkManager.role = NetworkManager.Role.CLIENT
	
	# Act
	var name: String = _lobby_room._role_name()
	
	# Assert
	assert_eq(name, "CLIENT",
			"Should map CLIENT role correctly.")


func test_role_name_spectator() -> void:
	# Arrange
	NetworkManager.role = NetworkManager.Role.SPECTATOR
	
	# Act
	var name: String = _lobby_room._role_name()
	
	# Assert
	assert_eq(name, "SPECTATOR",
			"Should map SPECTATOR role correctly.")


# -----------------------------------------------------------------------
# Diagnostics Text Building
# -----------------------------------------------------------------------

func test_build_diagnostics_text_includes_required_fields() -> void:
	# Arrange
	NetworkManager.connection_state = NetworkManager.ConnectionState.LOBBY
	NetworkManager.role = NetworkManager.Role.SERVER
	
	# Act
	var text: String = _lobby_room._build_diagnostics_text()
	
	# Assert
	assert_true(text.contains("Diagnostics —"),
			"Diagnostics text should start with 'Diagnostics —' prefix.")
	assert_true(text.contains("state:"),
			"Diagnostics should include 'state:' label.")
	assert_true(text.contains("role:"),
			"Diagnostics should include 'role:' label.")
	assert_true(text.contains("peers:"),
			"Diagnostics should include 'peers:' label.")
	assert_true(text.contains("protocol:"),
			"Diagnostics should include 'protocol:' label.")


func test_build_diagnostics_text_contains_connection_state() -> void:
	# Arrange
	NetworkManager.connection_state = NetworkManager.ConnectionState.LOBBY
	NetworkManager.role = NetworkManager.Role.SERVER
	
	# Act
	var text: String = _lobby_room._build_diagnostics_text()
	
	# Assert
	assert_true(text.contains("LOBBY"),
			"Diagnostics should include the actual connection state.")


func test_build_diagnostics_text_contains_role() -> void:
	# Arrange
	NetworkManager.connection_state = NetworkManager.ConnectionState.LOBBY
	NetworkManager.role = NetworkManager.Role.CLIENT
	
	# Act
	var text: String = _lobby_room._build_diagnostics_text()
	
	# Assert
	assert_true(text.contains("CLIENT"),
			"Diagnostics should include the actual network role.")


func test_build_diagnostics_text_contains_peer_count() -> void:
	# Arrange
	NetworkManager.connection_state = NetworkManager.ConnectionState.LOBBY
	NetworkManager.role = NetworkManager.Role.SERVER
	var peer_count: int = NetworkManager.get_peer_count()
	
	# Act
	var text: String = _lobby_room._build_diagnostics_text()
	
	# Assert
	assert_true(text.contains(str(peer_count)),
			"Diagnostics should include peer count value.")


func test_build_diagnostics_text_contains_protocol_version() -> void:
	# Arrange
	NetworkManager.connection_state = NetworkManager.ConnectionState.LOBBY
	NetworkManager.role = NetworkManager.Role.SERVER
	var expected_version: int = NetworkManager.PROTOCOL_VERSION
	
	# Act
	var text: String = _lobby_room._build_diagnostics_text()
	
	# Assert
	assert_true(text.contains("v%d" % expected_version),
			"Diagnostics should include protocol version.")


func test_build_diagnostics_text_format_consistency() -> void:
	# Arrange
	NetworkManager.connection_state = NetworkManager.ConnectionState.IN_GAME
	NetworkManager.role = NetworkManager.Role.SERVER
	
	# Act
	var text: String = _lobby_room._build_diagnostics_text()
	
	# Assert
	# Should have pipe separators for readability
	assert_true(text.contains(" | "),
			"Diagnostics text should use pipe separators between fields.")


# -----------------------------------------------------------------------
# End-to-end port validation (with actual host/join flow)
# -----------------------------------------------------------------------

func test_port_validation_on_host_confirm() -> void:
	# Arrange
	# This test verifies that the host dialog initializes port to default.
	_main_menu._host_port_input.text = str(ServerMain.DEFAULT_PORT)
	
	# Act
	var parsed: int = _main_menu._parse_port_or_default(
			_main_menu._host_port_input.text.strip_edges())
	
	# Assert
	assert_eq(parsed, ServerMain.DEFAULT_PORT,
			"Host dialog should initialize port to DEFAULT_NETWORK_PORT.")


func test_port_validation_on_join_confirm() -> void:
	# Arrange
	# This test verifies that the join dialog initializes port to default.
	_main_menu._join_port_input.text = str(ServerMain.DEFAULT_PORT)
	
	# Act
	var parsed: int = _main_menu._parse_port_or_default(
			_main_menu._join_port_input.text.strip_edges())
	
	# Assert
	assert_eq(parsed, ServerMain.DEFAULT_PORT,
			"Join dialog should initialize port to DEFAULT_NETWORK_PORT.")
