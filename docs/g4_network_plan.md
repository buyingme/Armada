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
| G4.2.1 | **`CommandSubmitter` strategy interface:** base class with `submit()` and `is_awaiting_response()`.  Two concrete implementations: `LocalCommandSubmitter` (calls `CommandProcessor.submit()` directly) and `NetworkCommandSubmitter` (serialize + RPC).  See §1.5 | `src/core/commands/command_submitter.gd`, `src/core/commands/local_command_submitter.gd`, `src/core/commands/network_command_submitter.gd` |
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
| G4.3.1 | `StateFilter` utility — strips hidden information from `GameState.serialize()` based on requesting player index | `src/core/network/state_filter.gd` |
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

### G4.6.5 — Network Game Wiring (Lobby → Gameplay Bridge)

**Goal:** Connect the existing lobby/transport infrastructure to the game board
so that two players can actually play a game over the network.

> **Planning note — why this was missed:** The original plan assumed that G4.2
> ("Server-Side Command Processing") would deliver end-to-end network play.
> In practice, G4.2 built the *plumbing* (CommandSubmitter classes, server-side
> RPC handlers, command_result broadcast) while G4.5 built the *lobby UI*.
> But the **integration glue** — swapping the submitter, syncing initial state,
> handling command results on the client, and adapting the game board for
> network mode — fell into the seam between G4.2 (which stopped at "Hot-seat
> still works identically") and G4.5 (which stopped at "Start a networked
> game", i.e. scene transition).  Neither phase owned the "game board works
> in network mode" deliverable.
>
> The root cause is a **vertical-slice gap**: each phase was scoped
> *horizontally* (transport, commands, lobby, chat) rather than delivering a
> thin vertical slice of actual networked gameplay.  The lesson: after building
> infrastructure layers, always add an explicit integration phase that proves
> the layers work together end-to-end with a real user scenario.

| Task | Description | Files |
|------|-------------|-------|
| G4.6.5.1 | **Submitter swap on game start:** `_on_lobby_game_start()` in main_menu or a new network boot handler calls `GameManager.set_command_submitter(NetworkCommandSubmitter.new())` when `PlayMode.is_network()` | `main_menu.gd`, `game_manager.gd` |
| G4.6.5.2 | **Server-side game initialisation RPC:** host/server generates RNG seed, picks scenario from lobby settings, calls `start_new_game()` locally, then broadcasts `_game_start_config.rpc(seed, scenario_id, player_assignments)` to all clients | `network_manager.gd`, `game_manager.gd` |
| G4.6.5.3 | **Client-side game initialisation handler:** on receiving `_game_start_config`, client calls `GameManager.start_new_game()` with the shared seed and scenario — ensuring both instances have identical initial `GameState` | `network_manager.gd`, `game_manager.gd` |
| G4.6.5.4 | **GameBoard network-mode branch:** skip local `start_new_game()` when `PlayMode.is_network()` — game is already initialised by the RPC in G4.6.5.3 before the scene loads | `game_board.gd` |
| G4.6.5.5 | **`local_player_index` tracking:** `NetworkManager` stores the player index assigned during handshake.  Expose `NetworkManager.get_local_player_index() -> int`.  Game board uses this to lock camera perspective and determine "my turn" vs "opponent's turn" | `network_manager.gd` |
| G4.6.5.6 | **Client-side command result handler:** `GameManager` connects to `NetworkManager.command_result_received`.  On receive: deserialize the command, apply it to local `GameState` via `CommandProcessor.apply_remote_command()`, emit appropriate EventBus signals, call `NetworkCommandSubmitter.clear_awaiting()` | `game_manager.gd`, `command_processor.gd` |
| G4.6.5.7 | **Network-mode active-player handling:** replace the `if not PlayMode.is_hot_seat(): return` guard in `_on_active_player_changed()` with network-aware logic — lock camera to own perspective, show "Opponent's turn" overlay when `active_player != local_player_index`, disable input for non-active player | `game_board.gd` |
| G4.6.5.8 | **Input lockout for non-active player:** when it's the opponent's turn, disable ship/squadron interaction, toolbar buttons, and command phase UI.  Show a subtle "Waiting for opponent…" indicator | `game_board.gd`, `ui_panel_manager.gd` |
| G4.6.5.9 | **State snapshot on connect:** server sends `GameState.serialize()` (filtered via `StateFilter`) to newly connected clients in IN_GAME state, for late-join and future reconnection support | `network_manager.gd` |
| G4.6.5.10 | **Hot-seat regression guard:** verify that `PlayMode.HOT_SEAT` still uses `LocalCommandSubmitter` and all existing gameplay paths are unaffected | `game_manager.gd`, `game_board.gd` |

**Tests:**
- Unit test: `GameManager` submitter is `NetworkCommandSubmitter` when `PlayMode == NETWORK`
- Unit test: `GameBoard._ready()` does not call `start_new_game()` in network mode
- Integration test (2-instance): host creates game → client receives matching `GameState` → command phase dials → ship phase activation — commands round-trip through server
- Regression test: hot-seat game plays identically to pre-G4.6.5

**Deliverable:** Two players can play an actual game over the network using the Learning Scenario.  Commands route through the server, state stays synchronised, and each player only controls their own side.

#### G4.6.5 Bug-Fix Implementation Plan

> Added: 2026-04-19 after first network test (MT-G4.6.5.1 passed; MT-G4.6.5.2–3 failed).

**Root cause:** Both instances (host + client) run `start_new_game()` →
`_start_round()` → `apply_fixed_round1_commands()` → `advance_phase()`
independently.  The client submits game-flow commands (`start_round`,
`advance_phase`) with `player_index=0` — the server rejects them because the
client is assigned `player_index=1`.  The client also submits `AssignDialCommand`
for the opponent's ships, which the server also rejects.  Additionally,
`_handle_remote_command_effects()` only handles `assign_dials` — all other
command types fall through with no side effects, so the client UI never
transitions phases or shows opponent activations.

**Architecture principle:** In network mode, the **client is passive** for game
flow.  It initialises `GameState` with the shared seed (identical starting
state) but does NOT drive round/phase progression.  All game-flow mutations
arrive from the server via `command_result` broadcasts.  Post-command effects
(EventBus signals, tracking variables) are applied by the broadcast handler.

##### Phase A — Client Passivity (core fix)

Goal: prevent the client from submitting or executing game-flow commands.

| # | Task | File(s) | Description |
|---|------|---------|-------------|
| A1 | `client_mode` flag in `start_new_game()` | `game_manager.gd` | When `config.get("client_mode", false)` is true, skip `_start_round()` at the end of `start_new_game()`. Client only initialises `GameState`, resets tracking, emits `game_started`. Round start arrives from server broadcast. |
| A2 | Pass `client_mode` from GameBoard | `game_board.gd` | Network client adds `"client_mode": true` to config dict. Host passes config as-is (no flag). |
| A3 | Skip `apply_fixed_round1_commands()` on client | `game_board.gd` | Guard: `if not PlayMode.is_network() or NetworkManager.is_server()`. Host auto-assigns and broadcasts; client receives via handler. |
| A4 | Guard `advance_phase()` on client | `game_manager.gd` | Early return if `PlayMode.is_network() and not NetworkManager.is_server()`. Server drives phase advancement; client receives via broadcast. |
| A5 | Guard `_start_round()` on client | `game_manager.gd` | Same guard. Client never submits `StartRoundCommand` itself. |
| A6 | Guard `_check_command_phase_complete()` | `game_manager.gd` | Skip `advance_phase()` call on client. Server broadcasts `AdvancePhaseCommand` after sync gate releases. Client still tracks `_command_submitted` locally for UI ("waiting for opponent"). |
| A7 | Guard `_begin_status_phase()` on client | `game_manager.gd` | Skip `_perform_status_phase_cleanup()` and `advance_phase()` calls. Server handles both and broadcasts results. |
| A8 | Guard `_advance_ship_phase_turn()` on client | `game_manager.gd` | Skip `advance_phase()` and `_set_active_player()` calls on client. Turn changes arrive from the server's `_set_active_player()` being broadcast (indirectly via next activation or phase-advance commands). |
| A9 | Guard `_advance_squadron_phase_turn()` on client | `game_manager.gd` | Same pattern as A8. |
| A10 | Guard post-submit side effects | `game_manager.gd` | `_on_command_picker_confirmed()` L411–413: wrap `EventBus.command_dials_changed.emit()` and `_check_player_all_assigned()` inside `if not result.is_empty()`. `NetworkCommandSubmitter.submit()` returns `{}`, so these skip on client. |
| A11 | Guard `_on_activation_ended()` on client | `game_manager.gd` | Client should not submit `EndActivationCommand` or call `_advance_ship_phase_turn()`. Server broadcasts both. |

**Deliverable:** Client no longer submits game-flow commands. No more server
rejection warnings. Client waits passively for broadcasts.

##### Phase B — Complete Command Result Handler

Goal: expand `_handle_remote_command_effects()` to handle all 26 command types
so the client's GameManager state and UI stay synchronised with the server.

The handler is called after `CommandProcessor.submit(cmd)` has already applied
the command's `execute()` to the client's `GameState`.  The handler mirrors the
post-submit side effects that the host runs inline (EventBus signals, tracking
variables, phase-begin methods).

| # | Command Type | Side Effects to Mirror on Client |
|---|-------------|----------------------------------|
| B1 | `start_round` | Reset `_command_submitted = [false, false]`, `_command_assigning_player` to initiative player, set `active_player` to initiative player, activate sync gate via `NetworkManager.activate_sync_gate()`, emit `EventBus.round_started`, emit `EventBus.phase_changed(COMMAND)`. |
| B2 | `assign_dials` | ✅ Already done. Find ship → emit `command_dials_changed` → `_check_player_all_assigned()`. |
| B3 | `advance_phase` | Read `next_phase` from `cmd.payload`. Reset `_command_assigning_player = -1`. If leaving COMMAND phase: emit `command_phase_complete`. Emit `phase_changed(next_phase)`. Call `_begin_ship_phase()` / `_begin_squadron_phase()` / (skip `_begin_status_phase()` — server handles cleanup). |
| B4 | `activate_ship` | Find ship → set `_activating_ship` → emit `command_dials_changed`. |
| B5 | `convert_dial_to_token` | Find ship → set `_activating_ship` → emit `command_dials_changed` + `command_tokens_changed`. If `result.get("duplicate")`: emit `duplicate_token_discarded`. If `result.get("overflow")`: emit `token_discard_required`. |
| B6 | `reveal_dial` | Find ship → emit `command_dials_changed`. |
| B7 | `set_speed` | No GM-level side effects (command mutates `GameState` directly). |
| B8 | `spend_dial` | Find ship → emit `command_dials_changed`. |
| B9 | `execute_maneuver` | No GM-level side effects. GameBoard handles token repositioning from the command payload's normalised position. |
| B10 | `end_activation` | Find ship → clear `_activating_ship` → emit `command_dials_changed` → call `_advance_ship_phase_turn()` (which on client is guarded to only set local tracking, not re-submit). |
| B11 | `activate_squadron` | Find squadron → set `_activating_squadron`. |
| B12 | `move_squadron` | No GM-level side effects. GameBoard moves the squadron token. |
| B13 | `spend_token` | Find ship → emit `command_tokens_changed`. |
| B14 | `discard_token` | Find ship → emit `command_tokens_changed` + `token_discarded`. |
| B15 | `roll_dice` | No GM-level side effects. Attack executor handles dice display from result. |
| B16 | `spend_defense_token` | Find ship → emit `ship_defense_token_changed`. |
| B17 | `select_redirect_zone` | No GM-level side effects. |
| B18 | `skip_attack` | No GM-level side effects. |
| B19 | `resolve_damage` | Find ship → emit `ship_damaged` + `ship_defense_token_changed`. If ship destroyed: emit `ship_destroyed`. |
| B20 | `overlap_damage` | Find ship → emit damage signals. |
| B21 | `persistent_effect_damage` | Find ship → emit damage signals. |
| B22 | `repair_action` | Find ship → emit shield/token/hull change signals based on `action_type`. |
| B23 | `resolve_immediate_effect` | Find ship → emit effect-specific signals. |
| B24 | `status_phase_cleanup` | Emit `ship_defense_token_changed` + `command_dials_changed` for all ships (both players). |
| B25 | `destroy_unit` | Emit `ship_destroyed` or `squadron_destroyed`. |
| B26 | `debug_deal_damage` | No network side effects (debug only, `pass`). |

Helper needed: `_find_squadron_from_command(cmd) -> SquadronInstance` (analog of
existing `_find_ship_from_command()`).

**Implementation note:** B1–B10 are the **critical path** — they cover game flow
and ship activation. B11–B26 cover combat, squadrons, damage, and repairs.
All are implemented in a single phase since the Learning Scenario is a full
game that can use any command type.

**Deliverable:** Client UI reacts to all server-broadcast commands. Phase
transitions, ship/squadron activations, combat, and damage all display
correctly on the passive client.

##### Phase C — Per-Instance Logging

Goal: each network instance writes to its own log file for debugging.

| # | Task | File(s) | Description |
|---|------|---------|-------------|
| C1 | Enable file logging per role | `game_manager.gd` | In `start_new_game()`, if `PlayMode.is_network()`: determine role string (`"host"` / `"client"` / `"spectator"`), call `GameLogger.enable_file_logging("res://logs/<role>_<timestamp>.log")`. Create `logs/` dir via `DirAccess`. |
| C2 | Log instance identity | `game_manager.gd` | Write a header line to the log file: role, player_index, RNG seed, scenario_id. |

`GameLogger` already supports `enable_file_logging(path)` with file handle,
`min_file_level`, and `write_raw_to_file()`. No framework changes needed.

**Deliverable:** `logs/host_20260419_170000.log` and `logs/client_20260419_170002.log`
with full debug output per instance. Terminal interleaving no longer a problem.

##### Phase D — Replay Suppression on Client

Goal: only the host writes replay files in network mode.

| # | Task | File(s) | Description |
|---|------|---------|-------------|
| D1 | Guard `auto_save_replay()` | `game_manager.gd` | Early return when `PlayMode.is_network() and not NetworkManager.is_server()`. |

**Deliverable:** No more duplicate replay files. Only the authoritative
host/server saves replays.

##### Phase F — Tests & Validation

| # | Task | Description |
|---|------|-------------|
| F1 | Headless GUT | Run full suite — confirm 124 scripts, 2587 tests, 0 failures. |
| F2 | Hot-seat regression (MT-G4.6.5.4) | Single-instance Learning Scenario plays identically to pre-fix. |
| F3 | Network test (MT-G4.6.5.1–3) | Two-instance: game starts synced → Command Phase dials → Ship Phase activation → maneuver visible on both. |
| F4 | Verify log files | `logs/` contains one file per instance with correct role and content. |
| F5 | Verify replays | Only one replay file written (by host). |

##### Execution Order

```
A (client passivity)
 → B (command handler — all 26 types)
   → C (per-instance logging)
     → D (replay suppression)
       → F1 (headless GUT)
         → F2 (hot-seat regression)
           → F3 (network manual test)
             → F4–F5 (verify logging + replays)
```

Each phase is committed separately with a conventional commit message.

##### Known Debt

| Item | Description | When to Address |
|------|-------------|-----------------|
| Squadron activation end | `_on_squadron_activation_ended()` mutates `activated_this_round = true` outside a `GameCommand`. No `EndSquadronActivationCommand` exists. On client, the state is correct because `ActivateSquadronCommand.execute()` already marks it, but GM tracking (`_activating_squadron`, `_squadrons_activated_this_turn`) must be synced via the handler. | G4.7 or dedicated cleanup |
| Attack flow on client | `AttackExecutor` drives multi-step dice/defense flows locally. In network mode, the passive client needs to see opponent's attack steps (dice roll results, defense token choices, damage resolution) in sequence. The commands are broadcast and applied to GameState, but the visual presentation (modal panels, animations) is not yet wired for the spectating player. | G4.7 (spectator mode shares this need) |
| Input lockout | G4.6.5.8 (disable interactions for non-active player) is partially implemented via `_handle_network_active_player()`. Full lockout (toolbar, targeting, etc.) deferred. | After MT-G4.6.5.3 passes |

#### G4.6.6 Shared Visibility + Split Authority Model (NEW)

> Added: 2026-04-20 after network UX review and manual annotations.

**Problem statement:** In network mode, some UI flows currently couple
"what is visible" with "who can interact". This causes asymmetry:
- activation sidebars diverge between peers,
- activation/displacement modals can appear on the wrong screen,
- planning tools and action tools are not cleanly separated by permission.

**Target interaction model (authoritative server remains unchanged):**
- **Shared visibility:** both peers see the same game progression state,
  activation sequence state, and public combat timeline.
- **Split authority:** only the currently entitled player may advance each
  interaction step (active player for attack initiation and dice flow,
  defending player for defense-token decisions, passive player for
  displacement placement, etc.).
- **Private tooling:** local-only planning tools (range ruler, attack
  simulator, candidate previews) stay client-local and never mutate
  authoritative state until converted into a command.

**Architecture fit assessment:**
- **Feasible with current architecture:** yes.
- Why: existing command model, `CommandSubmitter` strategy, server
  authority, and EventBus post-command hooks already support step-by-step
  authority transfer.
- Main gap: UI state is currently partially derived from local interaction
  events instead of server-broadcast interaction state.

**Critical design rule:**
- Treat every interactive timing window as an explicit network-visible
  interaction state with a single `controller_player`.
- Visibility is broad; input permission is narrow.

**Topology decision ("both players are hosts" assessment):**
- **Do not move to dual-host authority now.**
- Keeping one authoritative process (dedicated server or listen-server host)
  is significantly lower risk and matches current command validation model.
- A dual-host model requires deterministic lockstep or conflict resolution,
  rollback/reconciliation, anti-cheat redesign, and protocol rewrite.
- Estimated additional effort for dual-host authority: **3x-5x** this phase,
  with higher desync risk and harder debugging.

**Effort estimate for shared-visibility/split-authority refactor:**

| Track | Scope | Effort | Risk |
|------|-------|--------|------|
| T1 | Network Interaction State layer (explicit step owner + visible state) | 4-6 days | Medium |
| T2 | Activation sidebar parity from authoritative state only | 1-2 days | Low |
| T3 | Activation modal mirroring with per-control lock/unlock | 3-5 days | Medium |
| T4 | Planning tool split (local-only previews, command-only commits) | 2-4 days | Medium |
| T5 | Attack timeline authority handoff (attacker/defender windows) | 4-7 days | High |
| T6 | Displacement authority routing (passive player places, both observe) | 2-4 days | Medium |
| T7 | Regression + network integration tests + MT scenarios | 3-5 days | Medium |

**Total:** ~19-33 engineering days (single developer), incremental delivery
possible after each track.

**Implementation sketch (incremental, no rewrite):**

1. Add a `NetworkInteractionState` domain object
   - fields: `flow_type`, `step_id`, `controller_player`,
     `visible_to`, `payload`, `version`.
   - replicated from server via command results or dedicated interaction
     state messages.

2. Introduce interaction commands/events for step transitions
   - examples: `begin_ship_activation_flow`, `enter_attack_step`,
     `request_defense_token_choice`, `begin_displacement_for_player`,
     `interaction_step_completed`.
   - all progression runs through server validation.

3. Refactor UI consumers to permission-check against interaction state
   - modals and buttons render for both peers when visible,
   - controls enabled only when `local_player == controller_player`.

4. Convert activation sidebar to pure state projection
   - remove reliance on local token-only activation callbacks,
   - refresh from authoritative model changes + interaction state updates.

5. Keep planning tools local-only
   - range ruler / attack simulator never emit gameplay commands by default,
   - only explicit confirm actions submit commands.

6. Add deterministic interaction tests
   - host/client symmetry assertions for sidebar content,
   - "same visible sequence, different control owner" assertions,
  - displacement-passive and defense-owner authority transfer scenarios.

##### Ratified UX Contract (From modal_classification.md, 2026-04-21)

These decisions are now authoritative inputs for implementation:

1. Ship/squadron activation modals are **common** (visible on both peers)
  with **disabled controls** on non-controller peers.
2. Attack flow is **fully mirrored live** for both peers (targeting,
  roll/reroll, defense, redirect, resolution).
3. During defense windows, attacker and defender both see the **same modal**;
  only the current controller may act.
4. Displacement controller is the **non-active (passive) player** who did
  not cause the overlap, not the squadron owner.
5. Network mode removes blocking handoff overlay UX; replace with non-blocking
  status text beneath the score header:
  - active player: "make your choices"
  - passive player: "waiting for opponent's choice"
6. Command phase in network mode:
  - each player sees only their own `CommandDialPicker` content,
  - opponent is shown as generic planning state (no dial details).
7. Public sequences use fully mirrored visuals (no additional fog-of-war
  beyond existing hidden-information rules for dials/private state).

Any implementation conflicting with this contract is out of scope.

##### T0 — Contract Freeze (Mandatory Before T1)

**Goal:** eliminate ambiguity before refactor starts.

**Inputs:**
- `docs/modal_classification.md` (annotated)
- Ratified UX contract above.

**Outputs (must exist before T1 coding):**
- `InteractionStateStepMap` table in this plan:
  - every step ID,
  - visibility (`common`/`private`),
  - controller role,
  - allowed commands.
- `ModalRenderPolicy` table:
  - each modal/overlay,
  - render mode (`common`, `private`, `hidden`),
  - interactivity rule.
- `StatusTextPolicy` for network mode score-header messages.

**Frozen T0 tables (implementation baseline):**

`InteractionStateStepMap`:

| flow_type | step_id | visible_to | controller_role | allowed_commands | next_step_on_success |
|---|---|---|---|---|---|
| command_phase | select_dials | owner_only | owner | assign_dials | command_phase.wait_for_opponent |
| command_phase | wait_for_opponent | all | none | none | command_phase.both_submitted |
| command_phase | both_submitted | all | server | advance_phase | ship_activation.wait_for_ship_select |
| ship_activation | wait_for_ship_select | all | active | activate_ship, convert_dial_to_token | ship_activation.activation_modal_open |
| ship_activation | activation_modal_open | all | active | enter_squadron_step, enter_repair_step, enter_attack_step, enter_maneuver_step, end_activation | ship_activation.step_specific |
| ship_activation | squadron_step | all | active | begin_squadron_command, skip_squadron_step | ship_activation.repair_step |
| ship_activation | repair_step | all | active | begin_repair_step, skip_repair_step | ship_activation.attack_step |
| ship_activation | attack_step | all | active | begin_attack_step, skip_attack | ship_activation.maneuver_step |
| ship_activation | maneuver_step | all | active | execute_maneuver, end_activation | ship_activation.wait_for_ship_select or squadron_phase.wait_for_squad_select |
| squadron_phase | wait_for_squad_select | all | active | activate_squadron | squadron_phase.action_choice |
| squadron_phase | action_choice | all | active | begin_squadron_move, begin_squadron_attack, skip_squadron_action | squadron_phase.move_or_attack |
| squadron_phase | move_preview | all | active | move_squadron, confirm_squadron_move, cancel_squadron_move | squadron_phase.attack_or_done |
| squadron_phase | attack_window | all | active | begin_attack_step | squadron_phase.done_for_unit |
| attack | declare_attacker | all | active | set_attacker_zone or set_attacker_squadron | attack.declare_target |
| attack | declare_target | all | active | select_target | attack.roll_dice |
| attack | roll_dice | all | active | roll_dice | attack.spend_accuracies |
| attack | spend_accuracies | all | active | confirm_accuracies, skip_accuracies | attack.defense_tokens |
| attack | defense_tokens | all | defender | spend_defense_token, discard_defense_token, done_defense_tokens | attack.redirect_choice or attack.resolve_damage |
| attack | redirect_choice | all | defender | select_redirect_zone, done_redirect | attack.resolve_damage |
| attack | resolve_damage | all | active | resolve_damage | attack.immediate_effect_choice or attack.finalize |
| attack | immediate_effect_choice | all | owner_or_opponent_per_card | resolve_immediate_effect | attack.finalize |
| attack | finalize | all | server | none | ship_activation.activation_modal_open or squadron_phase.action_choice |
| displacement | place_displaced_squadrons | all | passive | move_squadron, commit_displacement | displacement.commit |
| displacement | commit | all | passive | commit_displacement | ship_activation.maneuver_step or ship_activation.wait_for_ship_select |
| status_phase | cleanup | all | server | status_phase_cleanup, advance_phase | command_phase.select_dials |

`ModalRenderPolicy`:

| surface | render_mode | controller_source | interactivity_rule | hidden_data_rule |
|---|---|---|---|---|
| ActivationModal | common | interaction_state.controller_player | enabled only when local player is controller | no hidden data |
| SquadronActivationModal | common | interaction_state.controller_player | enabled only when local player is controller | no hidden data |
| RepairPanel | common | interaction_state.controller_player | enabled only when local player is controller | no hidden data |
| AttackSimPanel | common | interaction_state.controller_player | enabled only when local player is controller for current attack step | no hidden data |
| OpponentChoiceModal | common | interaction_state.controller_player | enabled only when local player is controller chosen by card effect | no hidden data |
| DisplacementModal | common | interaction_state.controller_player | enabled only when local player is passive controller | no hidden data |
| CommandDialPicker | private | local ownership only | interactive only for owner | hide dial values from opponent always |
| CommandDialOrderModal | private | local ownership only | interactive only for owner | hide dial values from opponent always |
| TargetingListModal | private | local-only tool | always local-only | never replicated |
| CardDetailOverlay | private | local-only tool | always local-only | never replicated |
| RangeOverlayScene | private | local-only tool | always local-only | never replicated |
| AttackSimOverlay | private_by_default | local-only tool unless explicitly mirrored by interaction step | local-only except mirrored attack windows | mirrored mode must still hide private command info |
| HandoffOverlay (network mode) | hidden | n/a | never shown in network mode | replaced by status text |

`StatusTextPolicy`:

| condition | text | source | clear_condition |
|---|---|---|---|
| local player equals controller_player | make your choices | interaction_state.ui_status_text or fallback policy | on step change where local is no longer controller |
| local player differs from controller_player | waiting for opponent's choice | interaction_state.ui_status_text or fallback policy | on step change where local becomes controller |
| command_phase local submitted and remote pending | waiting for opponent's choice | command_phase gate state | when both submitted event received |
| no active interaction window (server-controlled transition) | waiting for game update | transition guard | when next interaction_state arrives |

**Exit criteria:**
- No unresolved "open question" rows remain for T1-T6 surfaces.
- T1-T6 tasks reference frozen step IDs only.

##### Protocol Guarantees (Mandatory)

The following transport/application guarantees apply to T1-T7:

1. **Ordering rule**
   - `command_result.seq` is the primary ordering source.
   - `interaction_state.version` must be monotonic per match.
   - Clients buffer out-of-order interaction updates until all prior
     versions are applied.

2. **Idempotency rule**
   - Re-applying the same `command_result.seq` or
     `interaction_state.version` is a no-op.
   - UI transitions must be edge-triggered by unseen version/seq only.

3. **Consistency rule between command and interaction state**
   - A step transition that depends on command side-effects is only applied
     after the corresponding `command_result.seq` has been applied locally.
   - If interaction update arrives first, client stores it as pending.

4. **Reconnection restore rule**
   - Reconnect snapshot must include current `NetworkInteractionState`
     alongside `GameState`.
   - Client rehydrates to exact interaction step before input is re-enabled.

5. **Privacy invariant rule (Command Phase)**
   - Opponent payloads must never contain dial contents.
   - Tests must include negative assertions for accidental dial leakage in:
     snapshot payloads, command results, and UI event payloads.

6. **Displacement timeout/disconnect rule**
   - If passive controller disconnects during displacement:
     - pause interaction and show waiting state,
     - apply reconnection window from G4.8,
     - if timeout expires, resolve by forfeit (no auto-placement).

##### Detailed T1-T7 Execution Plan

This section expands T1-T7 into implementation-ready work packages.

###### T1 — Network Interaction State Layer

**Goal:** Decouple visibility from interaction authority by introducing an
authoritative interaction timeline.

**Core addition:**
- `NetworkInteractionState` (new domain object, serializable):
  - `flow_type: String` (e.g. `ship_activation`, `attack`, `displacement`)
  - `step_id: String` (e.g. `attack_roll_dice`, `defense_token_window`)
  - `controller_player: int`
  - `visible_to: String` (`all`, `owner_only`, `public_with_hidden_fields`)
  - `payload: Dictionary`
  - `version: int`
  - `ui_status_text: String` (score-header helper text)

**Code impact (expected):**
- `src/autoload/game_manager.gd`
- `src/autoload/network_manager.gd`
- new file `src/core/network/network_interaction_state.gd`
- optional `src/core/network/interaction_state_router.gd`

**Design rules:**
- Server is the only writer of interaction state.
- Clients treat interaction state as read-only.
- Every UI action checks `local_player == controller_player`.
- Visibility and control are independent fields (never inferred from turn
  ownership alone).

**Deliverable:**
- Both peers receive identical interaction snapshots; only designated
  controller can send step-advancing commands.

**Tests:**
- State serialization/deserialization.
- Version monotonicity and stale-state rejection.
- Authority guard tests: non-controller commands rejected.
- Network status text snapshot tests (active/passive strings).

###### T1a — Function-Mapped Execution Checklist (Do Before T2)

Use this checklist as the coding order for T1-T6. Each row maps a work item to
concrete integration hooks so implementation does not drift from T0.

| ID | Work item | Existing hook(s) | Add/Modify | Done when |
|---|---|---|---|---|
| C1 | Add interaction-state domain object | none | ✅ `src/core/network/network_interaction_state.gd` — `class_name NetworkInteractionState extends RefCounted`: fields `flow_type`, `step_id`, `controller_player`, `visible_to`, `payload`, `version`, `ui_status_text`; methods `serialize()`, `static deserialize()`, `is_newer_than()`, `same_version()`. Tests: `tests/unit/test_network_interaction_state.gd` (25 tests). | Unit tests pass for round-trip serialization and version comparisons |
| C2 | Add network signal + cache for interaction updates | `NetworkManager.command_result_received`, `NetworkManager._pending_game_config` | ✅ `src/autoload/network_manager.gd`: signal `interaction_state_received(state_data)`, field `_latest_interaction_state: Dictionary`, public `broadcast_interaction_state(state: NetworkInteractionState)`, public `get_latest_interaction_state() -> Dictionary`, `@rpc("authority","call_local","reliable") _receive_interaction_state(state_data)` with idempotency version guard; `_cleanup()` resets cache. | Client receives state updates and keeps latest version cache |
| C3 | Add ordered apply path (idempotent) | `GameManager._on_network_command_result(...)` | ✅ `src/autoload/game_manager.gd`: fields `_last_interaction_version`, `_pending_interaction_by_version`; methods `_on_interaction_state_received()`, `_apply_interaction_state_if_ready()`, `_flush_pending_interaction_states()`; connected to `NetworkManager.interaction_state_received`; reset in `start_new_game()`. Signal `EventBus.interaction_state_changed` added. Tests: `tests/unit/test_game_manager_interaction_state.gd` (13 tests). | Duplicate/old versions are ignored; out-of-order versions are buffered then applied in order |
| C4 | Tie command-result seq and interaction version consistency | `GameManager._on_network_command_result(...)`, `NetworkManager.command_result_received` | ✅ `src/autoload/game_manager.gd`: field `_last_applied_command_seq`; tracked from `result.get("seq")` in `_on_network_command_result()`; `_flush_pending_interaction_states()` called after every command on both host and client paths; `payload["requires_seq"]` checked before buffered states are released. Reset in `start_new_game()`. | No premature step transitions when interaction update arrives before its command result |
| C5 | Project active controller to score-header text | `UIPanelManager.update_phase_hud()`, `GameBoard._on_active_player_changed(...)` | ✅ `src/scenes/game_board/ui_panel_manager.gd`: added `set_network_status_text(text: String)` + `_network_status_text` HUD suffix in network mode. `src/scenes/game_board/game_board.gd`: consumes `EventBus.interaction_state_changed` (`_on_interaction_state_changed`) and also applies an active-player fallback in `_handle_network_active_player()` while server-side interaction-state broadcasting is still being wired. Tests: `tests/unit/test_ui_panel_manager.gd` (2 new tests). | Text switches correctly between "make your choices" and "waiting for opponent's choice" |
| C6 | Sidebar becomes authoritative projection | `ActivationSidebar.populate(...)`, `ActivationSidebar.refresh()`, `ActivationSidebar._on_ship_activated(...)`, `ActivationSidebar._on_squadron_activated(...)` | Refactor `src/ui/combat/activation_sidebar.gd` to rebuild from `GameManager.current_game_state` + interaction state; remove dependence on local-only activation events for correctness | Host/client sidebar parity snapshot tests are stable |
| C7 | Activation modal permission gates | `ActivationModal.open(...)`, `ActivationModal._update_step_display()`, `_on_attack_pressed()`, `_on_repair_pressed()`, `_on_squadron_pressed()`, `_on_end_activation_pressed()` | Add `ActivationModal.set_interactable(is_enabled: bool)` and call from game-board/controller using `local_player == controller_player`; reject button handlers when disabled | Both peers see same step; passive peer cannot trigger state changes |
| C8 | Squadron modal permission gates | `SquadronActivationModal._update_ui()`, `_on_move_pressed()`, `_on_attack_pressed()`, `_on_commit_move_pressed()`, `_on_done_pressed()` | Add `SquadronActivationModal.set_interactable(is_enabled: bool)` and gate all action handlers | Passive peer sees mirrored modal but cannot move/attack/commit |
| C9 | Attack timeline mirrored and gated | `AttackExecutor._on_target_locked(...)`, `AttackExecutor._on_network_dice_result(...)`, `AttackSimPanel` action handlers (`_on_roll_pressed`, `_on_accuracy_confirm`, `_on_defense_done`, `_on_redirect_done_pressed`) | Add per-step controller checks in executor/panel; show full timeline to both peers, enable controls only for controller window | Attacker/defender handoff is visible and enforceable at each step |
| C10 | Displacement routed to passive controller | `DisplacementController.start(...)`, `_on_committed()`, `_submit_displaced_positions()` | Derive interactivity from interaction state controller role (`passive`); keep modal visible to both, lock controls for active player | Passive player controls placement; active player observes read-only timeline |
| C11 | Remove handoff overlay from network flow | `GameBoard._on_active_player_changed(...)`, `GameBoard._handle_network_active_player(...)`, `UIPanelManager.handoff_overlay` usage | In network mode, skip `HandoffOverlay.show_handoff(...)`; rely on status text policy only | No blocking ready gate appears in network mode |
| C12 | Reconnect restores exact interaction step | `NetworkManager.get_pending_game_config()`, reconnect snapshot path in network manager | Include serialized interaction state + version in reconnect payload and rehydrate before enabling input | Reconnected client resumes same visible step with correct controller and disabled/enabled controls |

**C5 learning note (2026-04-22):** Score-header visibility must be keyed to
the explicit UI status value itself, not to `PlayMode.is_network()` checks,
because mode assignment can lag scene UI initialization on some transition
paths. Keeping rendering value-driven avoids silent suppression of status text.

**Execution note:** Implement C1-C5 first (state + protocol), then C6-C12
UI consumers. Do not start T2/T3 visual tweaks before C3/C4 ordering rules are
in place.

###### T2 — Activation Sidebar Parity

**Goal:** Sidebar content and active highlights match on both peers.

**Current gap:**
- Sidebar updates are partially event-driven from local token flows;
  remote activations may not mirror identical event sequences.

**Implementation:**
- Make sidebar a pure projection of authoritative model + interaction state.
- Refresh triggers:
  - command_result application,
  - phase transitions,
  - interaction-state changes.
- Avoid local-only shortcuts (`ship_activated` UI signal dependence).

**Code impact (expected):**
- `src/ui/combat/activation_sidebar.gd`
- `src/scenes/game_board/game_board.gd`
- `src/autoload/game_manager.gd`

**Deliverable:**
- Ship/squadron activation, active highlight, destroyed status, and
  initiative order are identical across host/client.

**Tests:**
- Two-instance parity snapshot test for sidebar text/colors/states.

###### T3 — Activation Modal Mirroring + Permission Locks

**Goal:** Modal visibility is shared while controls are authority-gated.

**Implementation:**
- Split modal API into:
  - `render_state(view_model)`
  - `set_interactable(bool)`
- For each step in `ActivationModal` / `SquadronActivationModal`:
  - both peers render same step,
  - only controller has enabled step buttons.
- Ensure button handlers fail fast if local player is not controller.
- Remove `HandoffOverlay` as network flow gate for command/ship/squadron
  transitions; use score-header status text instead.

**Code impact (expected):**
- `src/ui/combat/activation_modal.gd`
- `src/ui/combat/squadron_activation_modal.gd`
- `src/scenes/game_board/squadron_phase_controller.gd`
- `src/scenes/game_board/game_board.gd`

**Deliverable:**
- Shared modal timeline with deterministic enable/disable behavior.
- Network transitions are non-blocking (no "Ready" gate), with explicit
  passive/active status text.

**Tests:**
- UI interaction tests: passive peer cannot trigger button signals.
- Visibility tests: both peers open/close same modal steps.

###### T4 — Planning Tools Separation

**Goal:** Keep planning tools private and independent per peer.

**Scope:**
- `RangeOverlayScene`, targeting list, local attack preview overlays,
  card zoom and local inspectors.

**Implementation:**
- Explicitly classify tools as `local_only`.
- Prevent planning-tool opens/closes from entering network command stream.
- Ensure no gameplay state mutation from planning tool callbacks.

**Code impact (expected):**
- `src/scenes/game_board/range_tool_controller.gd`
- `src/scenes/game_board/target_selector.gd`
- `src/ui/combat/targeting_list_modal.gd`
- `src/scenes/tools/attack_sim_overlay.gd`

**Deliverable:**
- Both peers can use planning tools independently without desync or lockout.

**Tests:**
- Tool usage on one client does not alter remote state/UI.

###### T5 — Attack Timeline Authority Handoff

**Goal:** Encode attacker/defender authority windows explicitly.

**Expected windows:**
- attacker: declare attacker, choose target, roll/reroll attacker dice,
  spend accuracies.
- defender: spend defense tokens, select redirect zone, defense completion.
- attacker: finalize damage / continue sequence.

**Mirroring rule (ratified):**
- All sub-steps are rendered on both peers in real time.
- Both peers keep the same `AttackSimPanel` progression; only the controller
  can click at each step.

**Implementation:**
- Add step IDs for all attack sub-phases.
- Update `AttackExecutor` to:
  - render all steps on both peers,
  - gate controls by `controller_player`,
  - avoid local speculative branching in network mode.
- Convert implicit handoff points into explicit server-declared state changes.

**Code impact (expected):**
- `src/scenes/game_board/attack_executor.gd`
- `src/ui/combat/attack_sim_panel.gd`
- `src/autoload/game_manager.gd`

**Deliverable:**
- Both peers observe identical attack progression; only entitled side can act.

**Tests:**
- End-to-end attack integration scenarios (ship vs ship, ship vs squadron,
  evade/redirect, skip attack).

###### T6 — Displacement Ownership Routing

**Goal:** Displacement is controlled by the passive (non-active) player.

**Implementation:**
- Server emits displacement interaction state with passive-player controller.
- Passive peer enters `DisplacementModal` interactive mode.
- Active peer sees mirrored read-only displacement timeline.
- On commit, authoritative `move_squadron` commands are applied and broadcast.

**Code impact (expected):**
- `src/scenes/game_board/displacement_controller.gd`
- `src/ui/commands/displacement_modal.gd`
- `src/autoload/game_manager.gd`

**Deliverable:**
- Passive player's screen owns placement in all overlap scenarios.

**Tests:**
- Overlap scenarios verify controller = non-active player regardless of
  displaced squadron ownership.

###### T7 — Test Matrix + Manual Validation Pack

**Goal:** Lock behavior with deterministic automated and manual tests.

**Automated additions:**
- Symmetry assertions for shared modals and sidebar state.
- Authority assertions for every controller window.
- Regression tests for command phase, ship phase, squadron phase,
  attack flow, displacement flow.

**Manual validation pack:**
- MT-T1: command phase simultaneous assignment + private dial visibility.
- MT-T2: shared activation modal, passive disabled controls.
- MT-T3: attack attacker/defender handoff windows.
- MT-T4: displacement passive-player-control routing.
- MT-T5: independent planning tools on both peers.
- MT-T6: network status text policy ("make your choices" / "waiting for
  opponent's choice") with no blocking handoff overlay.

**Deliverable:**
- Repeatable validation checklist for every refactor increment.

**Immediate bug relevance from current annotations:**
- Sidebar mismatch indicates authoritative activation state is not consistently
  projected in both clients' sidebar update paths.
- Displacement modal ownership indicates flow ownership is still inferred from
  local trigger source rather than explicit `controller_player`.

**Decision:** Proceed with incremental refactor on top of current
authoritative-server architecture. No rewrite required.

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

### 5.1 Directory Structure (Current)

All `src/core/` scripts live in domain sub-folders — **no files at the
`core/` root**.  The prerequisite refactoring (G4.0) is complete.

```
src/
├── autoload/                          # ← singletons (flat by nature)
│
├── core/                              # ← NO files at root — sub-folders only
│   ├── combat/                        # Attack resolution, defense tokens, dice
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
│   ├── commands/                      # GameCommand base + all command subclasses + submitters
│   │   ├── game_command.gd
│   │   ├── game_replay.gd
│   │   ├── command_submitter.gd
│   │   ├── local_command_submitter.gd
│   │   ├── network_command_submitter.gd
│   │   ├── activate_ship_command.gd
│   │   └── ... (30+ command subclasses)
│   ├── damage/                        # Damage cards, deck, dealing, repair
│   │   ├── damage_card.gd
│   │   ├── damage_dealer.gd
│   │   ├── damage_deck.gd
│   │   ├── immediate_effect_resolver.gd
│   │   └── repair_resolver.gd
│   ├── effects/                       # Upgrade / ability effects
│   │   ├── game_effect.gd
│   │   ├── effect_registry.gd
│   │   └── keywords/
│   │       ├── bomber_effect.gd
│   │       ├── escort_effect.gd
│   │       └── swarm_effect.gd
│   ├── geometry/                      # Ship bases, range, LOS, layout math
│   │   ├── geometry_helper.gd
│   │   ├── line_of_sight_checker.gd
│   │   ├── range_finder.gd
│   │   ├── ship_base.gd
│   │   └── tooltip_layout.gd
│   ├── movement/                      # Maneuver tool, overlap, squadron/token movement
│   │   ├── maneuver_calculator.gd
│   │   ├── maneuver_tool_state.gd
│   │   ├── overlap_resolver.gd
│   │   ├── squadron_mover.gd
│   │   └── token_mover.gd
│   ├── network/                       # G4 network core logic (future)
│   │   ├── state_filter.gd
│   │   ├── network_state_mirror.gd
│   │   ├── network_game_flow.gd
│   │   ├── turn_timer.gd
│   │   └── server_main.gd
│   └── state/                         # GameState, activation, dials, RNG, scoring
│       ├── game_state.gd
│       ├── player_state.gd
│       ├── ship_instance.gd
│       ├── squadron_base.gd
│       ├── squadron_instance.gd
│       ├── ship_activation_state.gd
│       ├── activation_context.gd
│       ├── command_dial_stack.gd
│       ├── command_token_manager.gd
│       ├── game_rng.gd
│       ├── scoring_calculator.gd
│       └── learning_scenario_setup.gd
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
| `core/commands/` | `GameCommand` base, all command subclasses, `CommandSubmitter` strategy + implementations, `GameReplay` | Command infrastructure and all concrete commands |
| `core/damage/` | Damage cards, deck, dealing, repair | Files that implement Rules Ref "Damage" or "Repair" |
| `core/effects/` | Upgrade / ability effects, keyword sub-folder | Effect system and keyword implementations |
| `core/geometry/` | Range, LOS, ship base polygons, tooltip layout | Pure geometry / positioning calculations |
| `core/movement/` | Maneuver tool, overlap, squadron/token movement | Files that implement Rules Ref "Movement" |
| `core/network/` | StateFilter, state mirror, game flow sync, turn timer, server entry point | **G4 network-specific core logic** (not command submitters — those are in `commands/`) |
| `core/state/` | Game state, player state, ship/squadron instances, RNG, scoring, dials | Data objects that hold mutable game state |
| `ui/combat/` | Activation, targeting, defense tokens | UI for combat interactions |
| `ui/ship/` | Card panels, damage displays | UI for ship information display |
| `ui/commands/` | Dial picker, repair panel | UI for command phase actions |
| `ui/hud/` | Toolbar, buttons, banners | Persistent on-screen HUD elements |
| `ui/debug/` | Debug modals, toast, annotations | Development-only UI |
| `ui/network/` | Chat, wait indicator, reconnect overlay | **All G4 network UI widgets** |

**Key principle:** a developer looking for network code finds it in exactly two
places: `src/core/network/` (logic) and `src/ui/network/` (widgets).  Command
submitters live in `core/commands/` because they are command infrastructure
first, network-specific second.  They never need to hunt through flat files.

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
│   ├── commands/                     # (submitters already here from G4.2)
│   │   ├── command_submitter.gd      # Strategy interface (base class) — DONE
│   │   ├── local_command_submitter.gd  # In-process (hot-seat) — DONE
│   │   └── network_command_submitter.gd # Serialize + RPC — DONE
│   └── network/
│       ├── state_filter.gd           # Per-player information hiding
│       ├── network_state_mirror.gd   # Client-side authoritative state
│       ├── network_game_flow.gd      # Command phase sync gate
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
│   ├── test_command_submitter.gd     # Already exists (G4.2) — covers all submitter variants
│   ├── test_network_manager.gd       # Already exists (G4.1/G4.2)
│   ├── network/                      # NEW sub-folder for future network unit tests
│   │   ├── test_state_filter.gd
│   │   ├── test_turn_timer.gd
│   │   ├── test_save_manager.gd
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
| 2 | Move files + `.uid` sidecars into sub-folders per §5.1 mapping | `git mv` for each `.gd` + `.gd.uid` pair | Done |
| 3 | Move remaining root files: `game_command`, `game_replay`, submitters → `commands/`; `game_rng`, `scoring_calculator`, `learning_scenario_setup` → `state/`; `tooltip_layout` → `geometry/` | No files at `core/` root | Done |
| 4 | Delete 3 orphaned `.uid` files (`attack_dice_pool`, `damage_resolver`, `attack_sequence_state`) | Clean directory listing | Done |
| 5 | Run `godot --headless --import` to re-index UIDs | All `class_name` types resolve correctly | Done |
| 6 | Run full GUT test suite — 0 failures, same script count | 120 scripts, 2480 tests, 4447 asserts — ALL PASSING | Done |
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

---

## 9. Bug Fix Plan — G4.6.5 First Network Test (2026-04-19)

Discovered during manual test MT-G4.6.5.2/3 after Phases A–D implementation.

### BF-1: `_on_activation_ended()` guard blocks client command submission (BLOCKER)

**Symptom:** Client presses "End Activation" → nothing happens. Host cannot
activate its second ship because `active_player` stays at 1.

**Root cause:** The Phase A guard `if _is_network_client(): return` at the
top of `_on_activation_ended()` suppresses the *entire* function, including
the `_submitter.submit(cmd)` call.  The client's `NetworkCommandSubmitter`
needs to send the command to the server, but the guard prevents it.

**Fix:** Remove the blanket early return.  The function is already safe for
the client because:
- `_submitter.submit(cmd)` on a `NetworkCommandSubmitter` sends via RPC
  (returns `{}`), so the `if not result.is_empty()` guard prevents duplicate
  local signal emissions.
- `_advance_ship_phase_turn()` / `_advance_squadron_phase_turn()` already
  have their own `_is_network_client()` guards.

**File:** `src/autoload/game_manager.gd` — `_on_activation_ended()`

### BF-2: No visual token repositioning for remote `execute_maneuver` (VISUAL)

**Symptom:** When the host moves a ship, the client sees the ship remain at
its original position.

**Root cause:** The Phase B handler has `"execute_maneuver": pass`.  The
command's `execute()` updates `ShipInstance.pos_x/pos_y/rotation_deg` in
GameState, but no code moves the visual `ShipToken` Node2D on the client.

**Fix (two parts):**
1. In `_handle_remote_command_effects()`, replace `pass` with a call to
   `_handle_remote_execute_maneuver(cmd)` that emits
   `EventBus.ship_repositioned_remotely` with the ShipInstance.
2. In `game_board.gd`, connect to `ship_repositioned_remotely`, look up the
   ShipToken via `_find_ship_token_for_instance()`, convert normalised
   `pos_x`/`pos_y` to pixels via `GameScale.play_area_size_px`, and set
   `token.global_position` + `token.global_rotation`.
3. Same approach for `"move_squadron"` — emit `squadron_repositioned_remotely`.

**New signal:** `EventBus.ship_repositioned_remotely(ship: RefCounted)`
**New signal:** `EventBus.squadron_repositioned_remotely(squadron: RefCounted)`
**Files:** `event_bus.gd`, `game_manager.gd`, `game_board.gd`

### BF-3: Duplicate `command_phase_complete` signal on client (MINOR)

**Symptom:** Client log shows "Command Phase complete — advancing to Ship
Phase." twice.

**Root cause:** When the client receives the server's `assign_dials` commands,
`_handle_remote_assign_dials()` → `_check_player_all_assigned()` →
`_check_command_phase_complete()` emits `command_phase_complete`.  Then the
server's `advance_phase` command arrives and `_handle_remote_advance_phase()`
emits `command_phase_complete` again.

**Fix:** In `_handle_remote_advance_phase()`, only emit `command_phase_complete`
if `_check_command_phase_complete()` hasn't already fired — i.e. skip the
emit when transitioning from COMMAND to SHIP, since the assign_dials handler
already triggered it.

**File:** `src/autoload/game_manager.gd` — `_handle_remote_advance_phase()`

### BF-4: Client `convert_dial_to_token` processes stale empty result (COSMETIC)

**Symptom:** Client shows `added=false, discard=false` in log for its own
convert_dial_to_token, then the real result arrives from the server.

**Root cause:** On the client, `GameManager.activate_ship_as_token(ship)`
submits via `NetworkCommandSubmitter` which returns `{}`.  The caller in
`game_board.gd` (`_on_dial_token_converted`) immediately reads keys from
the empty result dict (e.g. `result.get("needs_discard", false)`).  The
real result arrives later in `_on_network_command_result`.

**Fix:** In `_on_dial_token_converted()`, when `PlayMode.is_network()` and
the result is empty (client), defer the activation UI setup.  Store the
ship reference and set up the activation context, but skip the result-
dependent log and discard logic.  The `_handle_remote_convert_dial_to_token()`
handler already emits the correct signals when the server result arrives.

**File:** `src/scenes/game_board/game_board.gd` — `_on_dial_token_converted()`

### BF Summary

| # | Severity | File(s) | Status |
|---|----------|---------|--------|
| BF-1 | BLOCKER | game_manager.gd | ☐ |
| BF-2 | VISUAL | event_bus.gd, game_manager.gd, game_board.gd | ☐ |
| BF-3 | MINOR | game_manager.gd | ☐ |
| BF-4 | COSMETIC | game_board.gd | ☐ |
