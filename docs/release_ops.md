# Release Operations Runbook — macOS LAN Builds

This runbook describes how to prepare, package, and validate a playable
network release on two Macs connected to the same router.

## 0. Quickstart (5-minute internal build)

For an internal LAN test on a Mac you trust (no DMG, no signing):

1. From repository root:

```bash
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit | tail -10
```

   Confirm zero failures.

2. Export the macOS preset to `build/macos/Armada.app` from the Godot editor (Project → Export → macOS → Export Project).
3. Copy `Armada.app` to the second Mac (AirDrop or shared folder).
4. On the host Mac:
   - Allow the app in System Settings → Network → Firewall.
   - Find LAN IP: `ipconfig getifaddr en0` (or `en1`).
   - Launch app → Host Game → create lobby.
5. On the client Mac: launch app → Join Game → enter host IP and port.
6. Both Ready → host starts → confirm board appears on both machines.

For a packaged DMG release follow §3 onwards.

## 1. Scope

Use this for:
- pre-release validation on a fixed commit
- macOS app export
- DMG packaging
- two-machine LAN host/join verification

Out of scope:
- internet (WAN) hosting and port-forwarding; see the Tailscale guide in
   [setup_network_game.md](setup_network_game.md#12-playing-over-the-internet-with-tailscale)
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

### Host machine

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

### Client machine

1. Start app.
2. Click Join Game.
3. Enter host LAN IP and password (if set).
4. Confirm lobby join succeeds.

### In-lobby and in-game checks

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
