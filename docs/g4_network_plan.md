# Phase G4 — Network Multiplayer Plan

> Star Wars: Armada — Digital Edition
> Created: 2026-04-18
> Status: **APPROVED** — open questions resolved 2026-04-18

---

## 0. Scope Overview

Full network multiplayer with:
- **Dedicated server (separate binary)** — server validates all mutations; players connect as clients
- **CommandSubmitter strategy** — hot-seat and single-player use `LocalCommandSubmitter` (in-process, zero-latency); network uses `NetworkCommandSubmitter` (serialize + RPC)
- **Lobby system** — create, browse, join games with lobby codes
- **Relay/lobby server** — lightweight WebSocket server for NAT traversal and lobby listing (security-hardened)
- **Information hiding** — facedown dials, damage deck order, etc. only sent to owners
- **In-game chat** — text messages between players
- **Spectator mode** — read-only observers (requires both players' confirmation to join)
- **Reconnection** — disconnected player can rejoin mid-game
- **Turn timers** — configurable, server-enforced; timeout = forfeit + restart from last save

Covers requirements: NW-001 through NW-008 plus new requirements NW-009 through NW-020.

---

## 1. Architecture Decisions

### 1.1 Transport Layer

| Option | Pros | Cons |
|--------|------|------|
| **ENetMultiplayerPeer** | Built into Godot, UDP, low latency, reliable channels | Requires port forwarding for WAN |
| **WebSocketMultiplayerPeer** | NAT-friendly, works behind firewalls | Higher latency, TCP overhead |
| **Steam SDK (GodotSteam)** | NAT punch-through, lobby system included | External dependency, requires Steam |

**Decision:** Use **ENetMultiplayerPeer** for the game transport (fast,
reliable, built-in) and a **lightweight WebSocket relay/lobby server** for
lobby listing and NAT traversal.  For LAN play, direct ENet connection with
no lobby server needed.

The relay/lobby server is a **separate project** (Node.js or Python) deployed
independently.  See §1.6 for security requirements.

### 1.2 Authoritative Server Model

```
                    ┌──────────────────────────┐
                    │   Dedicated Server       │
                    │   (headless Godot)        │
                    │                           │
                    │  GameState (authoritative) │
                    │  CommandProcessor          │
                    │  GameRng (server seed)     │
                    │  DamageDeck               │
                    │  LobbyManager             │
                    │  ChatRelay                │
                    ├───────────┬───────────────┤
                    │           │               │
              ENet  │     ENet  │         ENet  │
                    │           │               │
              ┌─────▼────┐ ┌───▼──────┐ ┌──────▼──────┐
              │ Client 1 │ │ Client 2 │ │ Spectator(s)│
              │ (Player) │ │ (Player) │ │ (read-only) │
              └──────────┘ └──────────┘ └─────────────┘
```

- **Server** is a **separate binary** — runs headless, no rendering, no UI.
- **Server** owns `GameState`, `CommandProcessor`, `GameRng`, `DamageDeck`.
- **Clients** render the game, gather player intent, and submit commands.
- **Clients** never mutate `GameState` directly — they send command payloads
  to the server, which validates, executes, and broadcasts results.
- **Spectators** receive state updates only after **both players confirm** the
  spectator's join request.  Spectators see everything (omniscient) with no delay.
- **One game per server process.**  Multiple concurrent games require multiple
  server instances.  This avoids shared-state complexity and isolates crashes.
- **Protocol versioning:** every handshake includes a `protocol_version: int`.
  The server rejects clients whose version doesn't match, with a clear error.
- **Single-player / hot-seat** use the existing in-process `CommandProcessor`
  behind a `CommandSubmitter` strategy interface (same API surface as network,
  no child process needed).  See §1.5 for details.

### 1.3 Message Protocol

All messages are serialized `Dictionary` values sent via Godot's `rpc()` system.

| Direction | Message | Contents |
|-----------|---------|----------|
| Client → Server | `handshake` | `{protocol_version: int, client_id: str, display_name: str, connection_token: str}` |
| Server → Client | `handshake_ack` | `{ok: bool, error: str, player_index: int}` |
| Client → Server | `submit_command` | `GameCommand.serialize()` dict |
| Server → Clients | `command_result` | `{seq: int, command: dict, result: dict}` |
| Server → Owner | `private_state` | Player-specific hidden state (dials, drawn cards) |
| Server → All | `state_snapshot` | Full `GameState.serialize()` (on connect/reconnect) |
| Server → All | `lobby_update` | Lobby state (players, ready status, settings) |
| Client → Server | `chat_message` | `{sender: str, text: str, timestamp: int}` |
| Server → All | `chat_broadcast` | Same dict, server-stamped |
| Client → Server | `lobby_action` | `{action: str, ...}` (ready, settings, etc.) |

#### 1.3.1 Client Update Strategy

**Decision: wait for server confirmation** before updating client state.

Clients submit a command and display a brief spinner/activity indicator until
the server responds with `command_result`.  Only then does the client apply the
result to its local state mirror and emit EventBus signals.

This is simpler than optimistic update + rollback and acceptable for a
turn-based game where sub-second latency is not critical.  Keeps client code
free from rollback complexity.

### 1.4 Information Hiding Strategy

| Secret | Owner | When Revealed | Implementation |
|--------|-------|---------------|----------------|
| Facedown command dials | Owning player only | On `RevealDialCommand` execute | Server sends dial contents only to owner in `private_state`; broadcasts `dial_assigned` (no content) to opponent |
| Damage deck order | Server only | On draw | Cards transmitted one-at-a-time on draw; deck order never leaves server |
| RNG seed | Server only | Never (or post-game) | Server generates seed, uses it for `GameRng`; clients receive results only (NW-004) |
| Opponent's faceup damage | Both players | Immediately | Public — broadcast to all |
| Defense token states | Both players | Immediately | Public — broadcast to all |

### 1.5 Play-Mode Architecture (CommandSubmitter Strategy)

Instead of spawning a child server process for every play mode, a
**`CommandSubmitter`** strategy interface abstracts how commands reach the
authority.  All `GameManager.submit_*()` methods delegate to the active
submitter — no per-method `if network:` branching.

```
┌────────────────────────────────────────────────────────────────────┐
│  Hot-Seat (existing, proven)                                       │
│  LocalCommandSubmitter → CommandProcessor.submit() (in-process)    │
│  Zero latency, no serialization overhead, camera handoff overlay   │
├────────────────────────────────────────────────────────────────────┤
│  Single-Player (future, with AI)                                   │
│  LocalCommandSubmitter → same in-process path                      │
│  AI opponent submits commands as Player 2 via same submitter       │
├────────────────────────────────────────────────────────────────────┤
│  Network Multiplayer                                               │
│  NetworkCommandSubmitter → serialize + RPC to dedicated server     │
│  Server validates, executes, broadcasts result; client applies     │
└────────────────────────────────────────────────────────────────────┘
```

#### CommandSubmitter Interface

```gdscript
## Strategy interface for command submission.
## Concrete implementations: LocalCommandSubmitter, NetworkCommandSubmitter.
class_name CommandSubmitter
extends RefCounted

## Submits a command.  Returns result dict (local) or {} (network, async).
func submit(command: GameCommand) -> Dictionary:
    return {}  # Override in subclass

## True when waiting for server confirmation (network only).
func is_awaiting_response() -> bool:
    return false
```

- **`LocalCommandSubmitter`** — calls `CommandProcessor.submit()` directly.
  Used for hot-seat and single-player.  Identical to today's behaviour.
- **`NetworkCommandSubmitter`** — serializes the command, sends via
  `submit_command` RPC, returns `{}`.  Client waits for `command_result`
  from server before updating state (see §1.3.1).

**Benefits:**
- Hot-seat stays on the existing proven zero-latency code path — no regression
- No child process spawning — works on all platforms (desktop, mobile, web)
- One set of `submit_*()` methods — no `if network:` branching per method
- Network and local modes share the same `GameCommand` serialize/deserialize
- Future AI opponent is just another caller of `LocalCommandSubmitter`
- `OfflineMultiplayerPeer` can be used for integration testing without real
  network sockets

#### Desktop-Only Note

Spawning a child server process (`OS.create_process()`) was considered and
rejected.  It adds cross-platform complexity (macOS permissions, Windows exe
paths, impossible on iOS/Android/Web), debugging difficulty (two processes),
and unnecessary latency for hot-seat.  If a self-hosted dedicated server is
needed on desktop, it uses the separate server binary — not a child process.

### 1.6 Relay/Lobby Server Security

The relay/lobby server is a **Node.js** WebSocket service (chosen for mature
WebSocket ecosystem and simple containerised deployment).  It handles lobby
listing, lobby codes, and optional NAT relay.  **It never touches game state**
— all game logic runs on the dedicated Godot server.

#### Security Requirements

| Threat | Mitigation |
|--------|------------|
| **Eavesdropping** | TLS (wss://) mandatory for all WebSocket connections |
| **Spoofed lobby listings** | Server-generated lobby IDs; listings require authenticated session |
| **Denial of service** | Per-IP rate limiting (max 10 requests/sec); connection cap per IP (max 5) |
| **Injection attacks** | Input validation on all fields (lobby name, player name, chat); max lengths enforced; no SQL/NoSQL backend — in-memory only |
| **Replay attacks** | Session tokens with expiry (HMAC-signed, 1h TTL); nonce on auth handshake |
| **Unauthorized spectating** | Relay only forwards spectate requests; game server enforces both-player confirmation |
| **Resource exhaustion** | Max lobbies per IP (3); idle lobby timeout (30 min); max message size (4 KB) |
| **Man-in-the-middle** | TLS certificate pinning in client (optional, for distribution builds) |

#### HMAC Secret Key Management

- **Generation:** min 256-bit entropy (`openssl rand -hex 32`)
- **Storage:** environment variable `RELAY_SECRET` — **never committed** to version control
- **Rotation:** monthly, with a 1h grace window accepting both old and new keys
- **Game server shared secret:** relay and game server share a second key
  (`GAME_TOKEN_SECRET`) used to sign connection tokens.  Game server verifies
  client-presented `connection_token` using this key before granting a player slot.

#### Authentication Flow

```
Client                 Relay Server              Game Server
  │                        │                          │
  │ 1. connect (wss://)    │                          │
  │───────────────────────▶│                          │
  │                        │                          │
  │ 2. auth_request        │                          │
  │  {display_name, nonce, │                          │
  │   client_id (UUID)}    │                          │
  │───────────────────────▶│                          │
  │                        │ 3. validate, check ban   │
  │                        │    list, issue token      │
  │ 4. auth_response       │                          │
  │  {session_token, exp}  │                          │
  │◀───────────────────────│                          │
  │                        │                          │
  │ 5. create/join lobby   │                          │
  │  {session_token, ...}  │                          │
  │───────────────────────▶│                          │
  │                        │                          │
  │ 6. lobby_ready →       │ 7. relay game server IP  │
  │    start_game          │    + connection token     │
  │                        │    (HMAC-signed w/        │
  │                        │     GAME_TOKEN_SECRET)    │
  │◀───────────────────────│                          │
  │                        │                          │
  │ 8. ENet connect ──────────────────────────────────▶│
  │  {connection_token,    │      9. verify token w/   │
  │   client_id,           │         GAME_TOKEN_SECRET  │
  │   protocol_version}    │        → accept or reject  │
  │                        │                          │
```

Session tokens are **HMAC-SHA256 signed** (server secret key), contain
`{session_id, display_name, ip, issued_at, expires_at}`, and are validated
on every request.  No persistent database — all state is in-memory with
periodic JSON backup for crash recovery.

### 1.7 Accepted Risks & Known Limitations

| Item | Status | Rationale |
|------|--------|-----------|
| **ENet game traffic is unencrypted** | Accepted for v1 | ENet uses plaintext UDP.  A LAN attacker could sniff commands/state and learn hidden info (dials, cards).  Competitive impact exists but attack requires local network access.  **Future:** Godot's `DTLSServer`/`PacketPeerDTLS` for encrypted ENet.  Not critical for initial release. |
| **No persistent identity system** | Accepted for v1 | Auth is `{display_name, client_id}` — no accounts, passwords, or email.  Anyone can claim any display name.  `client_id` (UUID, generated once, stored in `user://settings.cfg`) enables soft-banning and basic reputation tracking.  **Future:** optional account system. |
| **Replay file integrity** | Mitigated | Server-saved replays are HMAC-signed (append `{hmac: str}` to replay header using server key).  Tampering is detectable on load. |
| **Embedded server approach rejected** | By design | See §1.5.  `OS.create_process()` was rejected due to cross-platform complexity (impossible on iOS/Android/Web), debugging friction, and latency overhead for hot-seat.  `CommandSubmitter` strategy achieves code-path uniformity without child processes. |

---

## 2. New Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| NW-009 | Lobby creation: host specifies scenario, name, password (optional), max spectators | Must |
| NW-010 | Lobby browser: list active lobbies or join by lobby code | Must |
| NW-011 | Player profiles: display name (persisted to `user://settings.cfg`) | Must |
| NW-012 | Ready-up system: both players must ready before game starts | Must |
| NW-013 | In-game text chat: send/receive messages, chat history, timestamp display | Should |
| NW-014 | Spectator mode: read-only view, no command submission, sees both sides | Should |
| NW-015 | Spectator chat: spectators can chat with each other but not with players (optional toggle) | Could |
| NW-016 | Spectator admission: spectator join requires explicit confirmation from **both** players | Must |
| NW-017 | Turn timer forfeit: on timeout, server declares forfeit and offers restart from last auto-save/save | Must |
| NW-018 | Server-side replay saving: server writes replay files; clients do not save separately | Must |
| NW-019 | Single-player and hot-seat use `LocalCommandSubmitter` (in-process); same API as network | Must |
| NW-020 | Relay server security: TLS, rate limiting, input validation, auth tokens — see §1.6 | Must |
| NW-021 | Protocol versioning: handshake includes `protocol_version`; server rejects mismatches | Must |
| NW-022 | Client identity: UUID `client_id` generated on first launch, persisted, included in handshakes | Must |
| NW-023 | Connection token validation: relay signs token with `GAME_TOKEN_SECRET`; game server verifies | Must |
| NW-024 | Replay file signing: server-written replays include HMAC signature for tamper detection | Should |
| NW-025 | Server structured logging: command audit log, connection events, errors — via `GameLogger` | Should |
| NW-026 | Graceful server shutdown: SIGTERM → auto-save, notify clients, exit cleanly | Must |

---

## 3. Sub-Phase Breakdown

### G4.1 — Network Transport Foundation

**Goal:** Establish the core networking infrastructure.

| Task | Description | Files |
|------|-------------|-------|
| G4.1.1 | Create `NetworkManager` autoload — connection lifecycle, peer management, role tracking (server/client/spectator) | `src/autoload/network_manager.gd` |
| G4.1.2 | Server startup: `--server` CLI flag → headless mode, `ENetMultiplayerPeer` listen on configurable port | `network_manager.gd` |
| G4.1.3 | Client connection: connect to IP:port → authenticate → receive player slot assignment | `network_manager.gd` |
| G4.1.4 | Connection state machine: `DISCONNECTED → CONNECTING → AUTHENTICATING → LOBBY → IN_GAME → DISCONNECTED` | `network_manager.gd` |
| G4.1.5 | Heartbeat / keepalive (5s interval, 15s timeout) | `network_manager.gd` |
| G4.1.6 | Wire `PlayMode.set_mode(NETWORK)` when connecting as client or hosting | `play_mode.gd` |
| G4.1.7 | **Protocol versioning:** handshake includes `protocol_version: int`.  Server rejects mismatched versions with descriptive error ("Server requires protocol v3, you have v2 — please update") | `network_manager.gd` |
| G4.1.8 | **`TestNetworkHarness`:** reusable test fixture that spins up a server-mode and client-mode `CommandProcessor` in the same process using `OfflineMultiplayerPeer` or in-memory message passing.  Used by all G4.2–G4.9 integration tests | `tests/fixtures/test_network_harness.gd` |
| G4.1.9 | **`client_id` generation:** on first launch, generate UUID v4, persist to `user://settings.cfg`.  Include in all handshakes | `src/autoload/player_profile.gd` |
| G4.1.10 | Register autoload in `project.godot` | `project.godot` |

**Tests:** Unit tests for state machine transitions; unit test for protocol version rejection; integration test for connect/disconnect cycle using `TestNetworkHarness`.

**Deliverable:** Two Godot instances can connect via ENet. No game logic yet.

---

### G4.2 — Server-Side Command Processing

**Goal:** Route all commands through the server for authoritative validation and execution.

| Task | Description | Files |
|------|-------------|-------|
| G4.2.1 | **`CommandSubmitter` strategy interface:** base class with `submit()` and `is_awaiting_response()`.  Two concrete implementations: `LocalCommandSubmitter` (calls `CommandProcessor.submit()` directly) and `NetworkCommandSubmitter` (serialize + RPC).  See §1.5 | `src/core/command_submitter.gd`, `src/core/local_command_submitter.gd`, `src/core/network_command_submitter.gd` |
| G4.2.2 | `GameManager` delegates all `submit_*()` methods to the active `CommandSubmitter` — no per-method `if network:` branching | `game_manager.gd` |
| G4.2.3 | Server-side `submit_command` RPC: deserialize → validate → execute → broadcast `command_result` (with sequence number) to all clients | `command_processor.gd` |
| G4.2.4 | Client-side `command_result` RPC: receive result, apply to local state mirror, emit `command_executed` | `command_processor.gd` |
| G4.2.5 | Client-side state mirror: lightweight `GameState` copy that receives authoritative updates only | `network_state_mirror.gd` |
| G4.2.6 | **`is_replaying` flag** on `CommandProcessor`: during `replay_commands()` or reconnection replay, suppress EventBus signals and UI notifications.  Client applies final state silently, then resumes normal signal flow | `command_processor.gd` |
| G4.2.7 | Server-side `GameRng` — seed generated on server, never transmitted. Dice results sent via command results | `game_rng.gd` |
| G4.2.8 | Server-side `DamageDeck` — deck lives on server only, drawn cards sent per-command | `damage_deck.gd` |
| G4.2.9 | **Server-side structured logging:** command audit log (every command with timestamp, player, sequence number), connection events, error events.  Uses `GameLogger` | `network_manager.gd`, `command_processor.gd` |
| G4.2.10 | **Client-side submission indicator:** brief spinner/activity indicator shown while awaiting `command_result` from server (see §1.3.1) | `src/ui/command_wait_indicator.gd` |

**Tests:** Integration test: client submits command → server validates → client receives result.

**Deliverable:** Hot-seat play still works identically. Network play routes commands through server.

---

### G4.3 — Information Hiding

**Goal:** Ensure secret information is only visible to its owner.

| Task | Description | Files |
|------|-------------|-------|
| G4.3.1 | `StateFilter` utility — strips hidden information from `GameState.serialize()` based on requesting player index | `src/core/state_filter.gd` |
| G4.3.2 | Facedown dial hiding: `CommandDialStack.serialize()` omits content of unrevealable dials for non-owner | `state_filter.gd` |
| G4.3.3 | `private_state` RPC: after each command, server sends owner-specific private data (e.g. newly assigned dial content) | `command_processor.gd` |
| G4.3.4 | Damage deck: never serialized to clients; drawn cards appear only in command results | `state_filter.gd` |
| G4.3.5 | Reconnection snapshot: filtered per-player (`StateFilter.filter_for_player(state, player_index)`) | `network_manager.gd` |

**Tests:** Unit tests for `StateFilter` — verify opponent dials are stripped, damage deck is omitted, own dials are preserved.  **Exhaustive property-based tests:** for every `GameState` field, assert that the opponent's filtered view contains no secret data.  Run on randomised game states.  Add a "secret canary" field in test states that must never appear in filtered output.

**Deliverable:** Client state views contain no secret information belonging to the opponent.  `StateFilter` has high-confidence test coverage.

---

### G4.4 — Command Phase Sync Gate

**Goal:** Implement the "both submitted" gate for simultaneous Command Phase actions (NW-007).

| Task | Description | Files |
|------|-------------|-------|
| G4.4.1 | Server-side submission gate: track per-player dial submission status, hold results until both are in | `command_processor.gd` or `network_game_flow.gd` |
| G4.4.2 | Client UI: show "Waiting for opponent…" overlay after submitting own dials | `command_phase_controller.gd` |
| G4.4.3 | On both-submitted: server broadcasts both `AssignDialCommand` results simultaneously | `network_game_flow.gd` |
| G4.4.4 | Phase transition: server advances to Ship Phase only after both players confirm receipt | `game_manager.gd` |

**Tests:** Integration test: Player 1 submits dials → waits → Player 2 submits → both receive results.

**Deliverable:** Command Phase dials are hidden until both players submit.

---

### G4.5 — Lobby System

**Goal:** Create, browse, and join game lobbies.

| Task | Description | Files |
|------|-------------|-------|
| G4.5.1 | `LobbyManager` — server-side lobby state: lobby name, scenario, players, ready status, password hash, max spectators | `src/autoload/lobby_manager.gd` or `src/core/lobby_state.gd` |
| G4.5.2 | Lobby RPCs: `create_lobby`, `join_lobby`, `leave_lobby`, `set_ready`, `start_game`, `update_settings` | `lobby_manager.gd` |
| G4.5.3 | Lobby browser UI scene: list available lobbies (name, scenario, player count, ping), refresh, join by code | `src/scenes/lobby/lobby_browser.gd` |
| G4.5.4 | Lobby room UI scene: player list, ready indicators, scenario picker, faction picker, chat area, start button (host only) | `src/scenes/lobby/lobby_room.gd` |
| G4.5.5 | Main menu integration: "Host Game" / "Join Game" buttons → lobby flow | `src/scenes/main_menu/` |
| G4.5.6 | Password-protected lobbies: password prompt on join | `lobby_browser.gd` |
| G4.5.7 | Lobby code system: 6-character alphanumeric code for direct join | `lobby_manager.gd` |
| G4.5.8 | Player profile: display name entry, persisted to `user://settings.cfg` | `src/autoload/player_profile.gd` |
| G4.5.9 | Security: session tokens (HMAC-SHA256, 1h TTL) issued on connect, validated on every request — see §1.6 | `relay_server/` |
| G4.5.10 | Security: per-IP rate limiting (10 req/s), connection cap (5/IP), max lobbies per IP (3) | `relay_server/` |
| G4.5.11 | Security: lobby passwords bcrypt-hashed server-side; input validation on all lobby/player name fields (max 32 chars, no control chars) | `relay_server/`, `lobby_manager.gd` |
| G4.5.12 | Security: idle lobby timeout (30 min), max message size (4 KB), TLS (wss://) mandatory | `relay_server/` |

**Tests:** Unit tests for lobby state transitions; integration test for create → join → ready → start flow.  Security tasks tested in relay server project (separate test suite).

**Deliverable:** Players can create/join lobbies, pick scenarios, and start a networked game.  Relay server is security-hardened.

---

### G4.6 — Chat System

**Goal:** In-game text chat between players (and optionally spectators).

| Task | Description | Files |
|------|-------------|-------|
| G4.6.1 | `ChatManager` — message history, send/receive RPCs, timestamp, sender identification | `src/autoload/chat_manager.gd` |
| G4.6.2 | Chat UI panel: text input, scrollable message history, toggle visibility (T key or button) | `src/ui/chat_panel.gd` |
| G4.6.3 | Chat notification: unread message indicator when panel is hidden | `chat_panel.gd` |
| G4.6.4 | Player-to-player chat: messages between the two players | `chat_manager.gd` |
| G4.6.5 | Spectator chat channel: spectators chat among themselves, optionally visible to players (host setting) | `chat_manager.gd` |
| G4.6.6 | Chat in lobby: reuse chat panel in lobby room scene | `lobby_room.gd` |
| G4.6.7 | Message rate limiting: server-side anti-spam (max 5 messages/10s) | `chat_manager.gd` |

**Tests:** Integration test for send → receive → display flow.

**Deliverable:** Players can chat during the game and in the lobby.

---

### G4.7 — Spectator Mode

**Goal:** Third-party observers can watch live games.

| Task | Description | Files |
|------|-------------|-------|
| G4.7.1 | Spectator connection type: join lobby as spectator (separate from player slots), max spectator limit | `network_manager.gd`, `lobby_manager.gd` |
| G4.7.2 | **Spectator admission gate:** server sends spectate request to both players; game pauses until both accept or one rejects; rejection disconnects the spectator gracefully | `network_manager.gd`, `lobby_manager.gd` |
| G4.7.3 | Spectator admission UI: both players see "Player X wants to spectate — Allow / Deny" modal; 30s timeout → auto-deny | `src/ui/spectator_admit_dialog.gd` |
| G4.7.4 | Spectator state view: receives full state (both players' perspective) — omniscient observer | `state_filter.gd` |
| G4.7.5 | Spectator UI mode: read-only game board, no click interactions, no command submission, both card panels visible | `game_board.gd`, `ui_panel_manager.gd` |
| G4.7.6 | Spectator perspective toggle: switch between Player 1 / Player 2 / top-down view | `game_board.gd` |
| G4.7.7 | Spectator join mid-game: receive state snapshot on connect (after admission) | `network_manager.gd` |
| G4.7.8 | Spectator count display: show spectator count in game HUD | `phase_indicator.gd` |
| G4.7.9 | **Spectate request rate limiting (game server):** max 1 spectate request per 5 minutes per IP; auto-block IP after 3 consecutive denials | `network_manager.gd` |

**Tests:** Integration test: spectator requests → both players accept → spectator receives state → sees updates.  Denial flow: one player rejects → spectator disconnected.

**Deliverable:** Spectators can watch games only after both players consent.

---

### G4.8 — Reconnection

**Goal:** Disconnected players can rejoin without losing the game.

| Task | Description | Files |
|------|-------------|-------|
| G4.8.1 | Server-side disconnect handling: pause game timer (if active), keep player slot reserved for 60s (configurable) | `network_manager.gd` |
| G4.8.2 | Reconnection flow: client reconnects → authenticates → receives filtered state snapshot → resumes | `network_manager.gd` |
| G4.8.3 | Reconnection UI: "Opponent disconnected — waiting for reconnection (0:45)" overlay | `src/ui/reconnect_overlay.gd` |
| G4.8.4 | Timeout: if player doesn't reconnect within window, opponent wins by forfeit | `network_manager.gd`, `game_manager.gd` |
| G4.8.5 | Command replay on reconnect: send command history since last confirmed sequence number | `command_processor.gd` |

**Tests:** Integration test: client disconnects → reconnects → state is correct.

**Deliverable:** A brief network drop doesn't end the game.

---

### G4.9 — Turn Timers

**Goal:** Configurable, server-enforced turn timers (NW-008).

| Task | Description | Files |
|------|-------------|-------|
| G4.9.1 | Server-side timer: configurable per-turn time limit (30s / 60s / 120s / none) | `network_manager.gd` or `turn_timer.gd` |
| G4.9.2 | Timer broadcast: server sends remaining time to clients every second | `turn_timer.gd` |
| G4.9.3 | Timer UI: countdown display in game HUD, colour change at 10s remaining | `phase_indicator.gd` |
| G4.9.4 | **Forfeit on timeout:** server declares the timed-out player as forfeiting; game ends with opponent winning | `turn_timer.gd`, `game_manager.gd` |
| G4.9.5 | **Restart from save:** after forfeit, both players can restart from the last auto-save (taken at round start); server loads saved state and re-hosts | `turn_timer.gd`, `game_manager.gd`, `save_manager.gd` |
| G4.9.6 | Auto-save: server saves serialised `GameState` at every round start to `user://autosave/`.  **Validate on load** (checksum).  If corrupted, no restart offered | `save_manager.gd` |
| G4.9.7 | Timer configuration: set in lobby settings (host choice) | `lobby_room.gd` |

**Implementation note:** Implement G4.9.6 (auto-save) first as a standalone feature and stabilise before building the restart flow (G4.9.5) on top of it.

**Tests:** Unit test for timer expiry → forfeit flow.  Unit test for auto-save write/load/checksum.  Integration test: timeout → forfeit → restart from auto-save.

**Deliverable:** Games enforce time limits; timeout means forfeit, with option to restart from last save.

---

### G4.10 — Dedicated Server Binary

**Goal:** Build and deploy the dedicated server as a separate headless binary.

| Task | Description | Files |
|------|-------------|-------|
| G4.10.1 | Godot server export preset: headless, no rendering, dedicated server feature tag | `export_presets.cfg` |
| G4.10.2 | Server entry point: `server_main.gd` auto-detects server mode via CLI `--server`, starts `NetworkManager.host()`, loads scenario from CLI args | `src/autoload/server_main.gd` |
| G4.10.3 | **Graceful server shutdown:** handle `NOTIFICATION_WM_CLOSE_REQUEST` (SIGTERM); auto-save current state, send `server_shutting_down` to all clients, wait up to 5s for clients to disconnect, then exit | `server_main.gd`, `save_manager.gd` |
| G4.10.4 | **Headless GUT validation:** run full GUT test suite in headless mode (`--headless`); document any headless-specific workarounds (missing display server, autoload init order) | CI/CD config |
| G4.10.5 | **Replay file signing:** server writes command log replay files with HMAC signature in header (using server key); tampering detectable on load | `game_replay.gd` |
| G4.10.6 | Server build CI: automated build of server binary for Linux (primary deployment target) | CI/CD config |

**Tests:** Integration test: server starts headless → client connects → submit command → receive result → graceful shutdown.

**Deliverable:** Server binary can be deployed independently; graceful shutdown preserves game state.

---

## 4. Implementation Order & Dependencies

```
G4.0 Directory Reorganisation (prerequisite refactoring)
  └─► G4.10 Dedicated Server Binary
        └─► G4.1 Network Transport Foundation (+ test harness, protocol version)
              └─► G4.2 Server-Side Command Processing (+ CommandSubmitter strategy)
                    ├─► G4.3 Information Hiding (+ exhaustive StateFilter tests)
                    │     └─► G4.4 Command Phase Sync Gate
                    ├─► G4.5 Lobby System (+ security hardening)
                    ├─► G4.6 Chat System
                    ├─► G4.7 Spectator Mode (+ admission gate, rate limiting)
                    ├─► G4.8 Reconnection
                    └─► G4.9 Turn Timers (+ auto-save first, then forfeit)
```

| Order | Sub-Phase | Depends On | Est. Effort |
|-------|-----------|------------|-------------|
| 0 | G4.0 Directory Reorganisation | — | Low (zero-behaviour-change refactoring) |
| 1 | G4.10 Dedicated Server Binary | G4.0 | Low–Medium |
| 2 | G4.1 Transport Foundation | G4.10 | Medium |
| 3 | G4.2 Server-Side Commands (+ CommandSubmitter) | G4.1 | High |
| 4 | G4.3 Information Hiding | G4.2 | Medium |
| 5 | G4.4 Sync Gate | G4.3 | Low |
| 6 | G4.5 Lobby System | G4.1 | High |
| 7 | G4.6 Chat System | G4.1 | Low–Medium |
| 8 | G4.7 Spectator Mode | G4.2, G4.3 | Medium |
| 9 | G4.8 Reconnection | G4.2, G4.3 | Medium |
| 10 | G4.9 Turn Timers | G4.2 | Medium |

G4.0 is a **prerequisite refactoring** — zero-behaviour-change file moves.

G4.10 (server binary) is simpler now — no embedded server / child process.
G4.5 (lobby) and G4.2 (server commands) can progress in parallel once G4.1 is done.
G4.6 (chat) is independent of game logic.
G4.9 effort Medium due to auto-save and restart-from-save tasks.

**Hot-seat and single-player remain on the existing local `CommandProcessor`
path** (via `LocalCommandSubmitter`).  No changes needed for those modes
beyond wiring the `CommandSubmitter` strategy in G4.2.

---

## 5. File Plan

### 5.0 Existing Structure Problem

The current `src/` tree has two flat-file hotspots that make navigation difficult:

| Directory | Files | Problem |
|-----------|-------|---------|
| `src/core/` | 39 flat | Combat, geometry, state, replay, RNG, dials, activation, damage — all mixed |
| `src/ui/` | 30 flat | Ship panels, modals, debug tools, combat overlays — all mixed |

The `commands/` and `effects/` sub-folders inside `core/` are good examples of
successful grouping.  G4 **must not repeat the flat-dump pattern.**

### 5.1 Proposed Sub-Structure for Existing Code

Before adding network code, reorganise existing files into domain sub-folders.
This is a **prerequisite refactoring** (G4.0) — move files via `git mv`,
re-run `godot --import` to re-index UIDs, re-run tests to confirm zero breakage.
(No `preload()` paths to update — all cross-references use `class_name`.)

```
src/
├── autoload/                          # ← 12 files, OK (singletons are flat by nature)
│
├── core/
│   ├── commands/                      # ← already exists (26 files) ✓
│   ├── effects/                       # ← already exists (9 files) ✓
│   │   └── keywords/                  # ← already exists ✓
│   ├── combat/                        # NEW sub-folder
│   │   ├── attack_dice_resolver.gd
│   │   ├── attack_state.gd
│   │   ├── attack_target_resolver.gd
│   │   ├── combat_participants.gd
│   │   ├── defense_token_resolver.gd
│   │   ├── dice.gd
│   │   ├── dice_pool.gd
│   │   ├── engagement_resolver.gd
│   │   ├── squadron_command_resolver.gd
│   │   └── targeting_list_builder.gd
│   ├── damage/                        # NEW sub-folder
│   │   ├── damage_card.gd
│   │   ├── damage_dealer.gd
│   │   ├── damage_deck.gd
│   │   ├── immediate_effect_resolver.gd
│   │   └── repair_resolver.gd
│   ├── movement/                      # NEW sub-folder
│   │   ├── maneuver_calculator.gd
│   │   ├── maneuver_tool_state.gd
│   │   ├── overlap_resolver.gd
│   │   ├── squadron_mover.gd
│   │   └── token_mover.gd
│   ├── geometry/                      # NEW sub-folder
│   │   ├── geometry_helper.gd
│   │   ├── line_of_sight_checker.gd
│   │   ├── range_finder.gd
│   │   └── ship_base.gd
│   ├── state/                         # NEW sub-folder
│   │   ├── game_state.gd
│   │   ├── player_state.gd
│   │   ├── ship_instance.gd
│   │   ├── squadron_base.gd
│   │   ├── ship_activation_state.gd
│   │   ├── activation_context.gd
│   │   ├── command_dial_stack.gd
│   │   ├── command_token_manager.gd
│   │   └── squadron_instance.gd
│   ├── network/                       # NEW — all G4 network core logic
│   │   ├── command_submitter.gd
│   │   ├── local_command_submitter.gd
│   │   ├── network_command_submitter.gd
│   │   ├── state_filter.gd
│   │   ├── network_state_mirror.gd
│   │   ├── turn_timer.gd
│   │   └── server_main.gd
│   ├── game_command.gd                # base class — stays at core root
│   ├── game_replay.gd
│   ├── game_rng.gd
│   ├── learning_scenario_setup.gd
│   ├── scoring_calculator.gd
│   └── tooltip_layout.gd
│
├── models/                            # ← 4 files, OK
│
├── scenes/
│   ├── fleet_builder/                 # ← exists ✓
│   ├── game_board/                    # ← exists ✓
│   ├── main_menu/                     # ← exists ✓
│   ├── tokens/                        # ← exists ✓
│   ├── tools/                         # ← exists ✓
│   └── lobby/                         # NEW — network lobby scenes
│       ├── lobby_browser.gd
│       └── lobby_room.gd
│
├── ui/
│   ├── combat/                        # NEW sub-folder
│   │   ├── activation_modal.gd
│   │   ├── activation_sidebar.gd
│   │   ├── attack_sim_panel.gd
│   │   ├── defense_token_display.gd
│   │   ├── targeting_list_modal.gd
│   │   ├── squadron_activation_modal.gd
│   │   └── squadron_move_overlay.gd
│   ├── ship/                          # NEW sub-folder
│   │   ├── ship_card_panel.gd
│   │   ├── ship_card_entry_builder.gd
│   │   ├── card_detail_overlay.gd
│   │   ├── damage_card_display.gd
│   │   └── damage_summary_overlay.gd
│   ├── commands/                      # NEW sub-folder
│   │   ├── command_dial_picker.gd
│   │   ├── command_dial_order_modal.gd
│   │   ├── repair_panel.gd
│   │   └── displacement_modal.gd
│   ├── hud/                           # NEW sub-folder
│   │   ├── action_toolbar.gd
│   │   ├── end_activation_button.gd
│   │   ├── execute_maneuver_button.gd
│   │   ├── show_activation_button.gd
│   │   ├── show_squadron_modal_button.gd
│   │   ├── your_turn_banner.gd
│   │   └── tooltip_panel.gd
│   ├── debug/                         # NEW sub-folder
│   │   ├── debug_annotation_modal.gd
│   │   ├── debug_help_panel.gd
│   │   └── debug_toast.gd
│   ├── network/                       # NEW — all G4 network UI
│   │   ├── chat_panel.gd
│   │   ├── command_wait_indicator.gd
│   │   ├── reconnect_overlay.gd
│   │   └── spectator_admit_dialog.gd
│   ├── handoff_overlay.gd             # stays at ui root (cross-cutting)
│   ├── opponent_choice_modal.gd
│   ├── quit_confirmation_modal.gd
│   └── victory_screen.gd
│
└── utils/                             # ← 4 files, OK
```

### 5.2 Directory Rationale

| Sub-folder | What belongs here | Rule |
|------------|-------------------|------|
| `core/combat/` | Dice, attack resolution, defense tokens, engagement, squadron command, targeting | Files that implement Rules Ref "Attack", "Engagement", or targeting lists |
| `core/damage/` | Damage cards, deck, dealing, repair | Files that implement Rules Ref "Damage" or "Repair" |
| `core/movement/` | Maneuver tool, overlap, squadron/token movement | Files that implement Rules Ref "Movement" or debug movement |
| `core/geometry/` | Range, LOS, ship base polygons | Pure geometry calculations |
| `core/state/` | Game state, player state, ship/squadron instances | Data objects that hold mutable game state |
| `core/network/` | CommandSubmitter, StateFilter, server entry point | **All G4 network core logic** |
| `ui/combat/` | Activation, targeting, defense tokens | UI for combat interactions |
| `ui/ship/` | Card panels, damage displays | UI for ship information display |
| `ui/commands/` | Dial picker, repair panel | UI for command phase actions |
| `ui/hud/` | Toolbar, buttons, banners | Persistent on-screen HUD elements |
| `ui/debug/` | Debug modals, toast, annotations | Development-only UI |
| `ui/network/` | Chat, wait indicator, reconnect overlay | **All G4 network UI widgets** |

**Key principle:** a developer looking for network code finds it in exactly two
places: `src/core/network/` (logic) and `src/ui/network/` (widgets).  They
never need to hunt through 39 flat files.

### 5.3 New Files — Godot Project (G4 Network)

All new network files go into their designated sub-folders:

```
src/
├── autoload/
│   ├── network_manager.gd           # Connection lifecycle, peer management
│   ├── lobby_manager.gd             # Lobby state, RPCs, lobby codes
│   ├── chat_manager.gd              # Chat history, send/receive RPCs
│   ├── player_profile.gd            # Display name, client_id UUID persistence
│   └── save_manager.gd              # Auto-save at round start, load for restart
├── core/
│   └── network/
│       ├── command_submitter.gd      # Strategy interface (base class)
│       ├── local_command_submitter.gd  # In-process (hot-seat, single-player)
│       ├── network_command_submitter.gd # Serialize + RPC (network)
│       ├── state_filter.gd           # Per-player information hiding
│       ├── network_state_mirror.gd   # Client-side authoritative state
│       ├── turn_timer.gd             # Server-enforced turn timer
│       └── server_main.gd           # Server entry point, headless mode
├── scenes/
│   └── lobby/
│       ├── lobby_browser.gd          # Lobby list, join by code
│       └── lobby_room.gd             # Pre-game room, ready-up
└── ui/
    └── network/
        ├── chat_panel.gd             # Chat UI panel
        ├── command_wait_indicator.gd  # Spinner while awaiting server response
        ├── reconnect_overlay.gd      # "Waiting for reconnect" overlay
        └── spectator_admit_dialog.gd # "Allow spectator?" modal for players

tests/
├── fixtures/
│   └── test_network_harness.gd       # Reusable 2-peer test harness (G4.1.8)
├── unit/
│   ├── network/                      # NEW sub-folder for network unit tests
│   │   ├── test_state_filter.gd
│   │   ├── test_turn_timer.gd
│   │   ├── test_save_manager.gd
│   │   ├── test_command_submitter.gd
│   │   └── test_lobby_state.gd
│   └── ... (existing unit tests)
└── integration/
    ├── network/                      # NEW sub-folder for network integration tests
    │   ├── test_network_commands.gd
    │   └── test_network_reconnect.gd
    └── ... (existing integration tests)
```

### 5.4 New Files — Relay/Lobby Server (Separate Project)

```
relay_server/
├── README.md                # Setup, deployment, configuration
├── package.json             # Node.js
├── src/
│   ├── index.js             # Entry point, WebSocket server (wss://)
│   ├── auth.js              # HMAC session tokens, nonce, ban list check
│   ├── lobby.js             # Lobby CRUD, lobby codes, idle timeout
│   ├── rate_limiter.js      # Per-IP rate limiting, connection caps
│   ├── validator.js         # Input validation, sanitisation
│   └── config.js            # TLS paths, rate limits, RELAY_SECRET, GAME_TOKEN_SECRET
├── test/
│   ├── auth.test.js
│   ├── lobby.test.js
│   └── rate_limiter.test.js
└── Dockerfile               # Containerised deployment
```

### 5.5 Prerequisite Refactoring (G4.0) — COMPLETED

Reorganised existing flat directories before network implementation:

| Step | Action | Validation | Status |
|------|--------|------------|--------|
| 1 | Create sub-folders: `core/{combat,damage,movement,geometry,state}`, `ui/{combat,ship,commands,hud,debug}` | Directory structure matches §5.1 | Done |
| 2 | Move files + `.uid` sidecars into sub-folders per §5.1 mapping | `git mv` for each `.gd` + `.gd.uid` pair (59 files × 2 = 118 renames) | Done |
| 3 | Run `godot --headless --import` to re-index UIDs | All `class_name` types resolve correctly | Done |
| 4 | Run full GUT test suite — 0 failures, same script count | 115 scripts, 2369 tests, 4277 asserts — ALL PASSING | Done |
| 5 | Commit as `refactor(core): organise flat directories into domain sub-folders` | Clean commit before G4.1 | Done |

**No `preload()` or `load()` path updates were needed** — all cross-references
use `class_name`.  The `.uid` sidecar files maintain Godot's type index.

### 5.6 Modified Files

| File | Changes |
|------|---------|
| `command_processor.gd` | Server-side RPC handlers; `is_replaying` flag; structured audit logging |
| `game_manager.gd` | Delegates to active `CommandSubmitter`; reconnection flow |
| `game_replay.gd` | HMAC-signed replay file headers |
| `play_mode.gd` | Wire `NETWORK` mode on connect |
| `game_board.gd` | Spectator read-only mode; spectator perspective toggle |
| `ui_panel_manager.gd` | Spectator dual-panel layout |
| `command_phase_controller.gd` | "Waiting for opponent" overlay; network both-submitted gate |
| `phase_indicator.gd` | Timer display; spectator count |
| `project.godot` | New autoloads: NetworkManager, LobbyManager, ChatManager, PlayerProfile, SaveManager |
| `export_presets.cfg` | Server export preset (headless, dedicated server feature tag) |
| Main menu scene | Host/Join/Play buttons → lobby flow or local play |

---

## 6. Risk Assessment

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| NAT traversal failures on WAN | Players behind strict NAT can't connect | High | Relay server provides fallback; document port-forwarding; UDP hole-punching via relay |
| Race conditions in command processing | Desync between server and clients | Medium | Server is single authority; clients never mutate; sequence numbers enforce ordering |
| Reconnection state mismatch | Rejoined player sees stale state | Medium | Full state snapshot on reconnect + command replay from last confirmed sequence |
| Relay server availability | Can't browse/create games online | Medium | Local play still works (LocalCommandSubmitter); direct IP connect as fallback |
| GDScript performance for headless server | Server lag under load | Low | Turn-based game has minimal per-frame computation; profile and optimize if needed |
| Spectator information leak | Spectator relays hidden info to a player | Medium | Both-player admission gate + per-IP rate limiting mitigate; spectators see everything by design |
| **ENet traffic unencrypted (S-6/SEC-4)** | **LAN attacker can sniff dials/cards** | **Low** | **Accepted for v1.  Future: Godot DTLS.  Attack requires local network access** |
| **Relay server security breach** | **Session hijacking, lobby disruption** | **Low–Medium** | **TLS mandatory, HMAC tokens, rate limiting, input validation — see §1.6** |
| **Headless server stability** | **Godot 4.5 headless quirks** | **Low–Medium** | **Test headless export early (G4.10.4); run GUT suite in headless; document workarounds** |
| **Replay event duplication (IR-10)** | **UI re-animates on reconnection replay** | **Low** | **`is_replaying` flag suppresses EventBus signals during replay (G4.2.6)** |
| **StateFilter bug leaks secrets** | **Opponent learns hidden info** | **Medium** | **Exhaustive property-based tests with secret canary (G4.3)** |

---

## 7. Testing Strategy

| Layer | What | How |
|-------|------|-----|
| **Unit** | `StateFilter`, `TurnTimer`, `LobbyState`, `CommandSubmitter`, `SaveManager` | GUT — no network needed |
| **Integration** | CommandSubmitter dual-mode, reconnection flow, StateFilter exhaustive | GUT — `TestNetworkHarness` with `OfflineMultiplayerPeer` |
| **System** | Full 2-player game over network | Manual — two Godot instances on localhost |
| **Stress** | Reconnection under load, rapid command submission | Manual + scripted replay |
| **Relay** | Auth, lobby CRUD, rate limiting, input validation | Relay server test suite (Jest or equivalent) |

---

## 8. Open Questions — All Resolved

| # | Question | Decision (2026-04-18) |
|---|----------|-----------------------|
| 1 | Relay server? | **Yes** — build lightweight relay/lobby server (**Node.js** WebSocket), security-hardened (see §1.6) |
| 2 | Server distribution? | **Separate binary** — dedicated Godot server export, not a `--server` flag |
| 3 | Spectator info policy? | **Omniscient** — spectators see everything, but require both players' confirmation before admission (see G4.7.2–3) |
| 4 | Turn timer auto-action? | **Forfeit** — timed-out player forfeits; both players may restart from last auto-save (see G4.9.4–6) |
| 5 | Saved replays? | **Server saves replays** — authoritative command log, HMAC-signed for integrity |
| 6 | Single-player mode? | **`LocalCommandSubmitter`** — single-player and hot-seat stay on existing in-process path.  No embedded server child process.  See §1.5 |
