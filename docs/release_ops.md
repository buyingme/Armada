# Release Operations Runbook — macOS LAN Builds

This runbook describes how to prepare, package, and validate a playable
network release on two Macs connected to the same router.

## 0. Five-Minute Internal Quickstart

Use this path for a fast sanity pass before full release validation.

1. Export a macOS release app from the target commit.
2. Package DMG:

```bash
hdiutil create -volname Armada -srcfolder build/macos/Armada.app -ov -format UDZO build/macos/Armada.dmg
```

3. Install on Mac A (host) and Mac B (client).
4. Host on Mac A, join from Mac B with host LAN IP and port.
5. Validate lobby ready/start and one in-game command on both peers.

If any step fails, continue with the full runbook below.

## 1. Scope

Use this for:
- pre-release validation on a fixed commit
- macOS app export
- DMG packaging
- two-machine LAN host/join verification

Out of scope:
- internet (WAN) hosting and port-forwarding
- spectator/reconnect runtime features (tracked in implementation plan)

## 2. Preconditions

- Both machines run the same exported build from the same commit hash.
- Godot export templates are installed for macOS.
- Host and client are on the same subnet (for example 192.168.1.x).
- Host is allowed through macOS Firewall for incoming connections.
- Router guest isolation/client isolation is disabled.

## 3. Release Freeze

1. Choose and tag the release commit.
2. Record commit hash, date, and owner in release notes.
3. Freeze content changes until release validation is complete.

## 4. Validation Before Export

Run from repository root:

```bash
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Gate:
- zero test failures
- expected script/test/assert totals for the release commit

## 5. macOS Export Setup

1. Add a macOS export preset in export_presets.cfg (if missing).
2. Use Release export and embed PCK.
3. Export to a clean path, for example:
   - build/macos/Armada.app
4. Launch the exported app once on the build machine.

## 6. DMG Packaging

Example command:

```bash
hdiutil create -volname Armada -srcfolder build/macos/Armada.app -ov -format UDZO build/macos/Armada.dmg
```

Validation:
1. Mount DMG.
2. Launch Armada.app from DMG on a second Mac.
3. Confirm first-launch flow works (right-click Open if unsigned).

## 7. Two-Machine LAN Smoke Test

### 7.1 Host and Client Setup

**Host machine:**
1. Start app.
2. Click Host Game.
3. Create lobby and optional password.
4. Get LAN IP:

```bash
ipconfig getifaddr en0
```

If empty, try:

```bash
ipconfig getifaddr en1
```

**Client machine:**
1. Start app.
2. Click Join Game.
3. Enter host LAN IP and password (if set).
4. Confirm lobby join succeeds.

### 7.2 Port Input Fields & Network Diagnostics

After successful host/join and lobby entry, verify the new port input fields
and network diagnostics display work as expected. These features aid in
troubleshooting LAN connectivity issues.

#### Port Input Validation (Host and Client)

**Host machine:**
1. Click Host Game.
2. Enter a game name, password (optional).
3. Verify the default port (7350) is pre-populated in the "Server Port:" field.
4. Try entering invalid ports:
   - `0` → should reject or show error toast "Invalid server port (1-65535)."
   - `65536` → should reject or show error toast.
   - `abc` → should reject or show error toast.
5. Enter a valid port in range 1–65535 (e.g., 8000) and confirm.
6. **Expected outcome:** Connection starts with the entered port.

**Client machine:**
1. Click Join Game.
2. Verify the default port (7350) is pre-populated in the "Server Port:" field.
3. Enter host LAN IP in "Server IP Address:" field.
4. Try entering invalid ports (same as above).
5. Enter a valid port matching the host's chosen port and confirm.
6. **Expected outcome:** Client successfully connects to the host.

#### Network Diagnostics Display (In-Lobby)

**In lobby (both machines):**
1. After successful host/join, observe the header area below the lobby code.
2. Verify **Endpoint line** displays:
   - **Host side:** `Host: <LAN_IP>:<port>` (e.g., `Host: 192.168.1.42:8000`)
   - **Client side:** `Host: <remote_IP>:<port>` (e.g., `Host: 192.168.1.99:8000`)
   - If remote IP cannot be determined, shows `Host: (unknown):<port>`
3. Verify **Diagnostics line** displays:
   - Format: `Diagnostics — state: <STATE> | role: <ROLE> | peers: <N> | protocol: v<VERSION>`
   - Example: `Diagnostics — state: LOBBY | role: SERVER | peers: 2 | protocol: v1`
   - Possible states: `CONNECTING`, `AUTHENTICATING`, `LOBBY`, `IN_GAME`
   - Possible roles: `SERVER`, `CLIENT`
   - Peer count should reflect connected players (e.g., 2 for a full lobby)

4. **State transitions during in-game play:**
   - After clicking "Start Game," state should change to `IN_GAME`.
   - Both host and client should reflect the same peer count.

#### Unit Test Coverage for Network UI

Port input validation and network diagnostics text building are covered by:
- `tests/unit/test_network_ui_endpoints.gd` (33 unit tests)
- Test coverage includes: port range validation, LAN IP detection, endpoint text formatting, diagnostics formatting, state/role name mapping.

Run unit tests with:
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

All network UI tests should pass (look for test names matching `test_network_ui_endpoints`).

### 7.3 In-Lobby and In-Game Checks

1. Both players click Ready.
2. Host starts game.
3. Verify both transition to board.
4. Execute at least:
   - one ship activation
   - one squadron activation
5. Save/load network smoke:
   - host can save
   - client cannot save
   - load behavior matches current design (lobby/in-session)

## 8. Logging Evidence

For each release candidate, retain:
- host log
- client log
- test run summary
- commit hash and DMG checksum

Suggested metadata block:
- release candidate ID
- commit hash
- test totals
- host IP/subnet
- pass/fail per checklist section

## 9. Troubleshooting Quick Guide

Connection fails immediately:
- verify host IP is LAN IP, not loopback
- verify firewall permission for Armada.app
- verify both machines are on same SSID/subnet

Client reaches ENet but handshake rejected:
- confirm both builds come from same commit
- confirm protocol-compatible binaries
- verify lobby password

Lobby works but game start/load desyncs:
- retest with fresh app restart on both machines
- clear stale local saves/checkpoints only if reproducing save/load issues
- capture host/client logs and attach to issue

## 10. Release Artifacts

Minimum bundle:
- Armada.dmg
- SHA256 checksum text file
- short release notes (features, fixes, known limits)
- this completed checklist with sign-off

## 11. Sign-Off Gate

Release is approved only when all are true:
1. Exported app starts on both Macs.
2. Host/join/ready/start flow passes over LAN.
3. Core in-game sync smoke passes.
4. Save/load network smoke passes according to current feature set.
5. Artifacts and logs are archived with commit hash.
