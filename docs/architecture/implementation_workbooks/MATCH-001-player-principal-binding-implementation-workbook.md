# MATCH-001: Player–Principal Binding Implementation Workbook

Status: Accepted
Accepted by: Project Owner
Accepted date: 2026-07-18

Purpose: Implementation Workbook

Date: 2026-08-17

Implementation boundary: the smallest coherent cutover that gives every
currently supported live `GameState` one durable, immutable
player-to-principal binding and uses it at live command-authorization,
save/load, replay, and authoritative reconstruction boundaries.

## 1. Entry Gate — Evidence And Result

This gate is read-only evidence. It authorizes no production change and does
not alter ADR-008. The proposed implementation uses the existing `GameState`
aggregate and its existing installation/reconstruction paths; it does not add
another canonical owner.

| Gate | Result | Repository proof and required implementation posture |
| --- | --- | --- |
| A. `GameState` can own and carry the binding | **PASS** | [`GameState`](../../../src/core/state/game_state.gd) already owns canonical match state, serializes it in `serialize()`, reconstructs it in `deserialize()`, and validates reconstructed state before [`GameManager.start_new_game_from_state()`](../../../src/autoload/game_manager.gd) publishes it. Add one narrow immutable child value and validate it at these existing seams. |
| B. Every current live-match creation path can establish it before live publication | **PASS** | Source search finds only `GameManager.start_new_game()`, `FleetSetupBootstrapper._create_initialized_state()`, and `GameState.deserialize()` constructing production `GameState` values. Normal Hot-Seat and Network starts converge through `GameManager.bootstrap_game()`. The three fleet-setup choices converge through `start_new_game_from_setup_package()`; learning and debug scenarios converge through `start_new_game()` before `LearningScenarioPreparer` adds scenario entities. Each path can receive/install the binding before `current_game_state` assignment, `is_game_active = true`, or `EventBus.game_started`. |
| C. Supported reconstruction can restore it before principal-dependent gameplay | **PASS** | Save/checkpoint load and host-distributed loaded state already use `GameState.deserialize()` followed by `GameManager.start_new_game_from_state()`. Replay reconstructs through `ReplayDriver` and `GameManager.bootstrap_game()`. Filtered state reconstruction uses `GameState.serialize() -> StateFilter.filter_for_player() -> GameState.deserialize()`. New-format inputs can carry the binding before installation. Fresh-lobby Network resume cannot establish peer entitlement and is explicitly stopped in Sections 6 and 7; it is not allowed to become live post-MATCH-001. |
| D. Hot-Seat can map one HUMAN to both players without UI authority | **PASS** | `PlayMode.HOT_SEAT` is available before bootstrap, and both current player sides are created together. It is sufficient as a one-time construction selector. The host process creates one new match-scoped HUMAN principal and maps player indices `0` and `1` to it before live publication. Setup display names, handoff overlays, `_local_viewer()`, and `_can_act_as()` are not consulted. |
| E. Two-human Network can create two distinct HUMAN principals without reusing identity-like values | **PASS** | Before `LobbyManager.request_start_game()` transitions the session, `LobbyState.can_start()` proves two accepted player slots. The authoritative host can allocate two fresh match-scoped principal IDs, map them by the accepted initial slots, and record transient peer associations. Peer IDs, `PlayerProfile.client_id`, lobby/display names, and player indices are construction inputs or associations only; none becomes a principal ID. |
| F. HUMAN/AUTOMATED and zero-HUMAN shapes are representable | **PASS** | Current code has no production bot or automated-match bootstrap. A general value factory can nevertheless accept HUMAN/AUTOMATED principal kinds and a total two-player mapping, including two AUTOMATED principals and zero HUMAN principals. This requires no bot behavior, scheduling, routing, or synthetic human. |
| G. Network authorization can remain separate from gameplay legality | **PASS** | Remote commands enter at `NetworkManager._submit_command_to_server()`, where the current transient `peer -> player_index` check occurs before `CommandProcessor`. Replace that check with `peer -> principal_id -> binding controls command.player_index`; then leave `CommandProcessor`, command `validate()`, `CommandApplicability`, attack, activation, and timing-window validation unchanged. Host-local player submissions require the same association check; existing server-generated/replay paths remain explicitly separate from player-originated submission. |
| H. Replacement-peer entitlement can fail closed without invented authentication | **PASS** | `NetworkManager._on_peer_disconnected()` currently removes the peer record, while reconnect is documented as unimplemented. The canonical binding remains in `GameState`; the lost transient association is not recreated. A later/replacement handshake gets no `match_principal_id`, and its live commands are rejected. No token, account, client ID, display name, slot, or claimed principal is accepted as proof. |

**Overall Entry Gate: PASS.**

The pass depends on retaining the hard stop: fresh-lobby loading of a Network
save and replacement-peer command entitlement remain unavailable until a later
accepted reconnect-authentication decision exists. Treating the new lobby
slots as proof of ownership of saved principals would fail Gates C, E, and H.

## 2. Authority And Workbook Boundary

Binding authority:

- [ADR-008](../adr/ADR-008-durable-match-lifetime-player-principal-binding.md)
  and the binding [MATCH-001 Owner decisions](MATCH-001-player-principal-binding-owner-decisions.md);
- [ADR-001](../adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md)
  / [CON-001](../contracts/CON-001-current-attack-state-and-semantic-transition-contract.md);
- [ADR-005](../adr/ADR-005-timing-window-ownership-and-continuation.md)
  / [CON-005](../contracts/CON-005-timing-window-implementation-contract.md);
- [ADR-006](../adr/ADR-006-canonical-ship-activation-boundary-ownership.md)
  / [CON-006](../contracts/CON-006-attack-declaration-lifecycle-contract.md);
- [ADR-007](../adr/ADR-007-purpose-specific-completed-attack-result-inspection-lifecycle.md),
  accepted [TWI-003](TWI-003-authoritative-current-attack-state-implementation-workbook.md),
  and [TEST-003](../tests/TEST-003-interactive-rule-timing-window-verification.md);
- the accepted [Setup Flow Contract](../../setup_flow.md); and
- the existing save owners `SaveGameMetadata.CURRENT_VERSION`, replay owners
  `GameReplay.FORMAT_VERSION` / `SIGNED_FORMAT_VERSION`, and the accepted
  [Replay Baseline Workflow](../../development/REPLAY_BASELINE_WORKFLOW.md).

Governance and ordering remain those in
[`DOCUMENT_AUTHORITY.md`](../DOCUMENT_AUTHORITY.md),
[`ARCHITECTURE_ROADMAP.md`](../ARCHITECTURE_ROADMAP.md), and
[`CODEX_WORKFLOW.md`](../CODEX_WORKFLOW.md).

The archived [G4 Network plan](../../old/g4_network_plan.md) and closed-folder
[Network save/load bootstrap investigation](../../qa/bugs/closed/BUG-001/issue_network-save-load-session-bootstrap.md)
were consulted as historical seam evidence only. The former names a planned
snapshot/reconnect flow that current production code does not implement; its
location under `docs/old/` gives it no authority to answer ADR-008's
replacement-peer entitlement stop. The latter records an earlier session
bootstrap concern but likewise supplies no principal entitlement decision.

This workbook selects implementation details only. It does not modify accepted
architecture, define ADR-007 acknowledgement state, implement UX-005, add bot
behavior, or define replacement-peer entitlement.

## 3. Verified Current-State Seams

### 3.1 Canonical state and gameplay identity

| Current seam | Finding | MATCH-001 consequence |
| --- | --- | --- |
| `GameState.initialize()` | Creates exactly `Constants.PLAYER_COUNT` (`2`) `PlayerState` values and resets canonical match state. There is no player/principal binding. | Keep pre-live initialization, then install one complete binding before any live-state publication. |
| `GameState.serialize()` / `deserialize()` | Own the shared JSON-safe state boundary, including current attack and timing state. Deserialization already rejects malformed or cross-owner lifecycle state. | Add one required `match_player_control_binding` child and reject missing/invalid new-format data. |
| `GameState.validate_declaration_adjacent_state()` | Is called before loaded-state installation and covers accepted neighboring owners, but its name/scope is declaration-specific. | Add `validate_for_live_installation()` that first validates the binding and then delegates to existing canonical validation; do not weaken the existing method. |
| `GameManager.start_new_game*()` | Assigns `current_game_state`, marks it active, and emits `game_started`. | Build and validate a candidate first; no unbound candidate may cross any of those publication points. |
| `PlayerState.player_index` | Identifies gameplay side and owns fleets/ships/squadrons. | Do not add principal identity to `PlayerState`; Hot-Seat would duplicate one shared fact. |
| `GameCommand.player_index` | The serialized command envelope carries gameplay-side identity and command validators use it for rules/controller legality. | Keep it unchanged. Resolve only the submitting principal at the submission boundary. |

### 3.2 Creation and reconstruction inventory

The source-wide production constructor search found these live paths:

| Path | Actual construction/reconstruction route | Supported MATCH-001 behavior |
| --- | --- | --- |
| Hot-Seat learning scenario | `GameBoard._bootstrap_or_load_board_state()` -> `GameManager.bootstrap_game()` -> `start_new_game()`; scenario entities are then added by `LearningScenarioPreparer.prepare_game_state()`. | Construct one HUMAN/both-player binding in `bootstrap_game()` and install it in the candidate before `game_started`. |
| Hot-Seat debug scenario | Same route with `debug_scenario`. | Same Hot-Seat binding; debug is a scenario choice, not an identity mode. |
| Hot-Seat 400/300/180 setup | `SetupMatchOptions` -> consumed `FleetSetupPackage` -> `start_new_game_from_setup_package()` -> `FleetSetupBootstrapper.build_game_state()`. | Pass the construction binding separately from the package; bootstrapper installs it before returning the candidate. |
| Network learning/debug | `LobbyManager.request_start_game()` -> `NetworkManager.broadcast_game_config()` -> per-peer `GameManager.bootstrap_game()` -> `start_new_game()`. | Host creates one two-HUMAN binding, establishes initial transient associations, and distributes the serialized value in the authoritative game config. |
| Network 400/300/180 setup | Same lobby start using `broadcast_setup_package_config()` and `FleetSetupBootstrapper`. | Carry the binding beside, not inside, `FleetSetupPackage`; every peer installs the host-created value. |
| Named save/checkpoint Hot-Seat load | `SaveGameManager.load_game*()` -> `GameState.deserialize()` -> `LoadGameDialog` -> `GameManager.start_new_game_from_state()`. | Save v4 restores the embedded binding; installation validates it and establishes the local Hot-Seat association before live publication. |
| In-session Network load | `LobbyManager.host_load_save()` installs on host, sends `state.serialize()`, and the client deserializes/installs through `_receive_loaded_state()`. | Supported only when the loaded binding exactly equals the live match binding and all existing associations remain valid. Preserve those associations; do not rebind. |
| Fresh-lobby Network load | The same `host_load_save()` currently permits any ready lobby to install a Network save. | **BLOCKED BY RECONNECT AUTHENTICATION ARCHITECTURE.** Reject before host installation/broadcast because the lobby cannot prove entitlement to saved principals. |
| Hot-Seat replay | `ReplayDriver` loads a `GameReplay`, injects seed, bootstraps the scenario, then uses `submit_replay()`. | Replay v6 header supplies the exact binding before bootstrap; playback does not create live peers. |
| Network replay harness | `ReplayDriver` creates a normal two-peer lobby and routes the same replay by assigned harness seat. | Restore the header binding unchanged. Replay submission remains a separate accepted-history path and does not turn harness peers into original human principals. |
| Filtered/reconnect state reconstruction | Tests exercise `serialize -> StateFilter -> deserialize -> UIProjector`; no production reconnect/snapshot RPC exists. | Preserve the full non-secret binding through filtering and validation. This proves reconstruction only; it grants no replacement peer entitlement. |

No other production `GameState.new()` or `GameState.deserialize()` path was
found. Direct constructors in tests remain test setup and must be updated to
install explicit fixtures when they cross serialization or live-install gates.

### 3.3 Identity-like values and their allowed roles

| Value | Current lifetime/use | MATCH-001 classification |
| --- | --- | --- |
| `PlayMode` | Process-level HOT_SEAT/NETWORK deployment selection. | One-time creation/load routing input only; never stored as principal authority in `GameState`. |
| `PlayerProfile.client_id` | Persistent installation UUID, client-supplied in handshake, also reused as current lobby ID. | Must not be copied, hashed, namespaced, or otherwise transformed into `principal_id`; not entitlement proof. |
| `NetworkManager.peers[peer_id]` | Transient authenticated transport record with display name, client ID, assigned slot, protocol version. Removed on disconnect. | May carry a transient host-accepted `match_principal_id` association after initial match creation; never owns principal records or mapping. |
| ENet `peer_id` | Current connection endpoint. | Association key only; never a principal ID. |
| `LobbyState.players` | Connected lobby rows with peer, display name, player index, readiness, faction. | Accepted initial construction input for slot-to-new-principal association only. It cannot reconstruct a saved principal. |
| `FleetSetupPackage.players` | Player-indexed roster and required display-name records. | Setup input/side labels only; package format does not gain principal authority. |
| Setup/player display names | Required by setup authority and used in UI labels. | Presentation facts only, even when distinct and non-empty. |
| `GameBoard._local_viewer()`, `_can_act_as()`, controller/modal state | Transient perspective and affordance routing based largely on slot/current UI. | May continue projecting UI, but must not authorize server command submission or derive principals. |

## 4. Canonical Representation

### 4.1 Type and storage

Add `src/core/state/match_player_control_binding.gd`:

```gdscript
class_name MatchPlayerControlBinding
extends RefCounted
```

It is one immutable value with two private data members:

- `_principal_records: Array[Dictionary]`, each record exactly
  `{ "principal_id": String, "kind": String }`; and
- `_player_principal_ids: Array[String]`, where array position is the current
  gameplay player index.

Use JSON strings `HUMAN` and `AUTOMATED`, exposed as `KIND_HUMAN` and
`KIND_AUTOMATED`. Do not add a participant object, peer field, display name,
credential, account ID, bot state, acknowledgement, or current-controller fact.

### 4.2 Principal IDs

New authoritative match creation allocates canonical lowercase IDs in the
form `mp-<RFC-4122-UUID-v4>`. Generate the two IDs, when needed, from one
freshly randomized `RandomNumberGenerator`, setting UUID version and variant
bits as the repository already does for `PlayerProfile`; do not reuse the
profile UUID or seed this generator from gameplay RNG.

Allocate each record once and retry generation only on collision with an ID
already allocated for that same binding. Validation remains responsible for
rejecting duplicate IDs received at any reconstruction boundary.

The random ID is an opaque match-scoped label, not a secret or authentication
credential. Randomness avoids accidental equality between separately created
matches and permits exact same-match association preservation checks. IDs are
allocated only by the authoritative new-match creator, then serialized and
copied to clients/replays; clients never independently allocate IDs for an
authoritative Network match.

Deserialization accepts only the selected `mp-` UUID-v4 canonical encoding.
Factories and tests that need fixed values use `deserialize()` with explicit
valid IDs rather than adding a second ID scheme.

### 4.3 Factories and read API

Provide these APIs and no record/mapping mutators:

- `create_new(principal_kinds: Array[String], player_principal_indexes: Array[int])`
  allocates IDs and returns `null` on invalid shape;
- `create_hot_seat_human()` delegates to
  `create_new([HUMAN], [0, 0])`;
- `create_two_human()` delegates to
  `create_new([HUMAN, HUMAN], [0, 1])`;
- `deserialize(data: Dictionary)` validates and returns a value or `null`;
- `serialize() -> Dictionary` returns deep copies in canonical order;
- `is_valid() -> bool`;
- `principal_id_for_player(player_index: int) -> String`;
- `principal_kind(principal_id: String) -> String`;
- `controls_player(principal_id: String, player_index: int) -> bool`;
- `distinct_principal_ids(kind: String = "") -> Array[String]`, sorted; and
- `equals(other: MatchPlayerControlBinding) -> bool` using canonical data.

`create_new([HUMAN, AUTOMATED], [0, 1])` and
`create_new([AUTOMATED, AUTOMATED], [0, 1])` are the required structural
HUMAN/AUTOMATED and zero-HUMAN representations. They do not create a supported
bot bootstrap or authorize automated command production.

### 4.4 Serialized shape

`GameState.serialize()` adds exactly:

```json
"match_player_control_binding": {
  "principals": [
    {"principal_id": "mp-<uuid-v4>", "kind": "HUMAN"}
  ],
  "player_principal_ids": ["mp-<same-uuid>", "mp-<same-uuid>"]
}
```

Sort `principals` by `principal_id`; preserve player mapping in index order.
The stable ordering protects canonical state hashes without giving order any
identity semantics.

### 4.5 Validation

Validation rejects the whole value if any condition fails:

1. The two top-level fields exist with the exact collection types and no
   unknown top-level binding field is present.
2. `player_principal_ids.size() == Constants.PLAYER_COUNT` and later equals
   the installed `GameState.player_states.size()`.
3. Every player position has exactly one non-empty canonical principal ID.
4. Every record has exactly one supported kind and a unique canonical ID.
5. Every mapping target resolves to one record.
6. Every record is referenced at least once.
7. Unknown fields in principal records, duplicate records, dangling targets,
   unreferenced records, and unsupported kinds reject.
8. All returned arrays/dictionaries are copies; no post-construction mutation
   can alter the stored facts.

### 4.6 `GameState` ownership API

Add one private field `_match_player_control_binding` and these narrow APIs:

- `install_match_player_control_binding(binding) -> bool`: clone/canonicalize,
  validate, and install exactly once; reject null, invalid, or replacement;
- `has_valid_match_player_control_binding() -> bool`;
- `principal_id_for_player(player_index) -> String`;
- `principal_controls_player(principal_id, player_index) -> bool`; and
- `get_distinct_controlling_principal_ids(kind) -> Array[String]`.

The value is immutable as soon as created and `GameState` accepts it only
once, which is stronger than the required post-live immutability. Do not add a
rebinding, remove, add-principal, kind-change, or generic participant API.

Add `GameState.validate_for_live_installation()`. It rejects a missing or
invalid binding and then preserves all existing validation, including
declaration-adjacent reference validation and timing-window reconciliation at
their current owners. `GameState.deserialize()` requires and installs the
binding before accepting the rest of the reconstructed state.

## 5. Creation, Installation, And No-Bypass Cutover

### 5.1 Construction carrier

Use `config["match_player_control_binding"]` as a short-lived serialized
construction carrier for `GameManager.bootstrap_game()` and
`FleetSetupBootstrapper`. It is not a second owner:

- Hot-Seat bootstrap creates the value and immediately passes it to the
  candidate `GameState`;
- Network config contains the authoritative host-created serialization;
- replay injects the already validated replay-header serialization; and
- load does not use this carrier because the binding is already in the
  deserialized `GameState`.

Make pending Network configuration one-shot (`consume_pending_game_config()`
or explicit clearing after successful/failed bootstrap) so it does not remain
an alternative live binding source. Do not place the binding in
`FleetSetupPackage`; its format remains version 1.

### 5.2 Mode selection rules

`GameManager.bootstrap_game()` resolves the construction binding in this
order:

1. If replay bootstrap is active, require the validated replay binding.
2. Else if Network, require the binding received from the authoritative host;
   missing/invalid data aborts before state creation.
3. Else create one Hot-Seat HUMAN principal mapped to both players.

`start_new_game()` and `start_new_game_from_setup_package()` must not infer a
fallback binding. Direct Network starts without authoritative binding fail
closed. `FleetSetupBootstrapper` receives the resolved binding explicitly,
installs it on its candidate, and returns failure if installation fails.

The canonical value accepts every valid HUMAN/AUTOMATED shape independently
of deployment mode. Current production entry gates then require the specific
shape they support: one HUMAN controlling both players for Hot-Seat and two
distinct HUMAN principals for a normal two-player Network match. This keeps
future structurally valid shapes representable without creating a bot or
silently enabling a new match mode.

### 5.3 Publish atomically

For each new-state path:

1. build a local candidate;
2. initialize gameplay state;
3. install the complete binding;
4. run `validate_for_live_installation()` plus existing replay-RNG checks;
5. only then assign `GameManager.current_game_state`, set `is_game_active`,
   establish active-player projections, or emit `game_started`;
6. on failure, discard the candidate and any pre-live transient associations.

Refactor `start_new_game()` so it does not assign the new `GameState` to
`current_game_state` before this gate. Refactor
`start_new_game_from_setup_package()` similarly; the current early assignment
before `_install_setup_package_state()` must disappear.

For loaded state, `SaveGameManager` first validates the body, cursor, and
timing lifecycle. `GameManager.start_new_game_from_state()` repeats the live
installation guard before replacing the current authoritative state. This
defence-in-depth creates no second owner.

Local command authority uses one narrow transient association rather than
re-deriving identity after publication. Construct a new
`LocalCommandSubmitter` with the validated Hot-Seat HUMAN principal ID when a
new or loaded Hot-Seat candidate is installed. Its private
`_match_principal_id` is cleared with submitter replacement/end-of-match and is
never serialized. Network host association remains in `NetworkManager` as
specified below. Neither association owns principal records or the player
mapping; both must query the installed `GameState` to decide what the
associated principal controls.

## 6. Network Distribution And Association

### 6.1 Initial two-human Network creation (non-replay)

For a normal non-replay match, immediately before
`LobbyManager.request_start_game()` broadcasts either a scenario or
setup-package config, the authoritative host must:

1. require `LobbyState.can_start()` and exactly one row for each player index;
2. create `MatchPlayerControlBinding.create_two_human()` once;
3. call a narrow `NetworkManager.establish_initial_match_principal_associations(binding, lobby)`;
4. store `_host_match_principal_id` in `NetworkManager`, associated with the
   principal mapped to the host's accepted initial slot;
5. add `match_principal_id` to each current server-side peer record according
   to its accepted initial lobby slot; and
6. pass the serialized binding into `broadcast_game_config()` or
   `broadcast_setup_package_config()` before `start_game()`.

The association method succeeds only in `LOBBY`, only before any association
exists, and only for the complete two-player lobby. It never generates or
changes principals. If any association or broadcast prerequisite fails, clear
the partial associations and do not transition to `IN_GAME`.

Network replay is the explicit exception to new two-human construction. When
`ReplayDriver` is active, require its validated format-6 header binding, skip
`establish_initial_match_principal_associations()`, and distribute that exact
binding through the replay bootstrap. The harness lobby supplies transport
and player routing only; `submit_replay()` does not require or create live
peer/principal associations.

This changes the game-config RPC schema; increment
`NetworkManager.PROTOCOL_VERSION` from **1 to 2** in the same cutover. The
strict handshake version check prevents a mixed protocol session. There is no
other current allocation of protocol version 2.

### 6.2 Client state

Both game-config RPC variants carry the same full binding dictionary. Each
client validates and installs it in its mirror `GameState`; it does not create
or rewrite IDs. `StateFilter` leaves the complete binding in filtered
snapshots. The IDs are safe to distribute because they are labels, not proof.

The authoritative server's peer association, not the client mirror or a
client-claimed ID, decides remote command authority. Client-side slot checks
may remain as UI/preflight routing but have no authorization status.

### 6.3 Player-originated command authorization

At `NetworkManager._submit_command_to_server()`:

1. require a known current peer and deserialize the command envelope;
2. read that peer's server-held `match_principal_id`;
3. require the authoritative `GameState.principal_controls_player()` for
   `cmd.player_index`;
4. reject missing, stale, or mismatched associations with a targeted failure;
5. only then call the existing `CommandProcessor` path;
6. leave command `validate()`, `CommandApplicability`, rule, turn, attack,
   activation, and timing-window validation unchanged.

Remove the current equality check between `cmd.player_index` and the peer's
assigned slot as an authorization rule. The slot remains in the peer record
for current lobby/UI routing and for the one-time initial association only.

The host-local controller must pass the same relation check before
`NetworkHostCommandSubmitter` sends a player-originated command to
`CommandProcessor`; it reads `NetworkManager._host_match_principal_id` and
queries the current authoritative `GameState`. Hot-Seat
`LocalCommandSubmitter` checks its construction-time `_match_principal_id`,
which validly controls both players. A Network client submitter carries no
principal claim; the server resolves the authenticated transport peer to its
server-held association.

Do not accidentally block trusted server transitions or replays. Add an
explicit `submit_authoritative()` strategy method for existing engine-owned
commands and retain `submit_replay()` for accepted history. Move only the
current engine-owned seams to `submit_authoritative()`:

- `complete_setup_and_start_round()`;
- `_assign_fixed_commands_to_ship()`;
- `advance_phase()` / `_start_round()`;
- `_on_activation_ended()` terminal command;
- `_perform_status_phase_cleanup()`; and
- `_on_ship_destroyed()` canonical cleanup.

Existing `NetworkManager._submit_observer_followup_from_server()` remains an
authoritative server follow-up. All other current `GameManager` player/flow
submission methods remain on `submit()` and therefore require the submitting
local/remote principal to control `command.player_index`. This split is
submission provenance only; it adds no system principal, command field,
controller FSM, or gameplay-legality rule.

Network replay retains `submit_replay()` and its existing CLI-only replay
gate. It restores the recorded binding but does not associate the harness
processes with the historical HUMAN principals merely to play commands.

### 6.4 Disconnect, replacement, and loaded Network state

On disconnect:

- remove the peer record and its transient association as today;
- do not mutate `GameState` or the binding; and
- do not move the association to another peer.

A new handshake during `IN_GAME` may satisfy the existing transport handshake,
but it receives no match-principal association. Its commands fail the check in
Section 6.3. Never use the freed player slot, matching client ID, display name,
lobby row, save signature, or a claimed principal ID to recreate entitlement.

An in-session Network load is permitted only when:

- the current live binding equals the loaded binding exactly; and
- every still-associated host/peer principal remains a valid referenced
  principal controlling the same gameplay player under that unchanged value.

Preserve those existing associations. If the loaded binding differs, or the
load begins from a fresh lobby with no live associations, reject before
`GameManager.start_new_game_from_state()` and before `_receive_loaded_state()`.

**BLOCKED BY RECONNECT AUTHENTICATION ARCHITECTURE:** restoring a Network save
in a fresh lobby, restoring a disconnected peer's association, authorizing a
replacement peer, takeover, reassignment, or principal rebinding. MATCH-001
chooses no credential, proof, lifetime, rotation, replacement, or competition
policy.

## 7. Save/Load Compatibility

### 7.1 Allocation and new saves

The inspected current owner is `SaveGameMetadata.CURRENT_VERSION == 3`.
TWI-003 allocated and activated version 3; no current document or code allocates
version 4. MATCH-001 therefore atomically changes the current save version to
**4** when the binding becomes required.

New v4 saves keep the existing envelope:

```text
header.save_format_version = 4
state.match_player_control_binding = <canonical serialized binding>
```

`game_mode` remains signed metadata used for save categorization and supported
load routing. It is not a principal source. `save_game()` and checkpoint
creation reject an unbound/invalid live state before signing or writing.

### 7.2 Validation order

Both named-save and checkpoint loading use this order:

1. parse envelope and require version 4;
2. verify the existing signature;
3. `GameState.deserialize()` and validate the required binding before other
   principal-dependent reconstruction;
4. validate binding/player-state cardinality and all existing state references;
5. restore/validate the command cursor;
6. run timing-window reconciliation;
7. apply the deployment-specific association gate; and
8. install the state as live.

No failure path publishes a partial state or updates transient associations.

### 7.3 Legacy disposition

Save version 3 is **explicitly unsupported and rejected** with the existing
`version_unsupported` result before body installation. It is not equivalent:
it contains no stable principal IDs or canonical mapping. Although current
signed `game_mode` could suggest the cardinality of today's human-only modes,
creating previously absent identities would be a migration choice, not exact
restoration, and current save authority already uses a strict exact-version
cutover.

Do not synthesize principals from `game_mode`, player indices, profile IDs,
names, or the signature. Do not add a v3 compatibility reader, resave prompt,
or automatic resave. Version 4 saves round-trip exactly; no extra resave
behavior is required.

Hot-Seat v4 loads establish the local association to the one saved HUMAN
principal only after validating the required Hot-Seat shape. Current Network
v4 loads follow the in-session/fresh-lobby rules in Section 6.4.

## 8. Replay Compatibility

### 8.1 Carrier and allocation

The inspected current owner is `GameReplay.FORMAT_VERSION == 5` with
`SIGNED_FORMAT_VERSION == FORMAT_VERSION`. No current artifact allocates
format 6. MATCH-001 atomically changes both through the existing alias to
**format 6**.

Add `header.match_player_control_binding`. `CommandProcessor.create_replay()`
copies it from the current `GameState` and refuses replay capture from an
unbound state. `GameReplay.capture_header()`, `is_valid()`, and `deserialize()`
require it. Deserialization canonicalizes it with
`MatchPlayerControlBinding.deserialize()` before any command dictionary is
canonicalized or applied.

`ReplayDriver` exposes the validated binding as one-shot bootstrap input beside
the existing seed. Hot-Seat and Network harnesses pass that same value through
the normal candidate-state installation gate. They do not derive it from the
runner's current `PlayMode`, assigned harness seats, or live peers.

### 8.2 Legacy disposition

Replay format 5 is **rejected before command deserialization/application**.
It is not semantically equivalent because its header records neither play mode
nor principal structure: the same command player indices cannot reveal whether
one Hot-Seat HUMAN or two Network HUMAN principals controlled them. Any
principal reconstruction would fabricate history.

Do not relabel, edit, or convert format-5 files. Current executable baseline
inputs must be rerecorded through the accepted workflow after the code cutover:

- rerecord/promote `replay_hot_seat_solo.json` and `replay_network.json`;
- regenerate the Hot-Seat final-state hash because `GameState.serialize()`
  gains the binding;
- expect the Hot-Seat JSONL command trace to remain semantically unchanged;
- retain `BaselineTrace.FORMAT_VERSION == 1` because its record schema does not
  change; and
- keep diagnostic Network traces/hashes uncommitted as the workflow requires.

Historical replay attachments under `docs/qa/` remain immutable evidence and
become unsupported by the current loader; do not edit their headers. If an
active bug requires a current replay, reproduce and rerecord it normally.

## 9. Projection And Security Boundary

No new credential or secret is introduced. `StateFilter.filter_for_player()`
already deep-copies the state and removes enumerated hidden fields. Leave the
complete binding in both filtered views so a client mirror can deserialize and
validate the same semantics. Add an explicit preservation test so a later
filter change cannot accidentally drop or rewrite it.

`UIProjector` does not need a MATCH-001 principal projection. Current viewer,
modal, and side-label behavior may remain player-indexed. If a future UI reads
principal data, it must do so through `GameState` read APIs and must not treat
visibility as authority.

Only the canonical labels and kinds are distributed. Never put handshake
passwords, signing keys, future reconnect proof, `PlayerProfile.client_id`, or
peer data inside the binding. Logs should avoid describing a principal ID as
authenticated; it is an identifier only.

## 10. ADR-007 Future Read Seam

After MATCH-001 implementation, ADR-007 Entry Gate A can read exactly:

```gdscript
game_state.get_distinct_controlling_principal_ids(
        MatchPlayerControlBinding.KIND_HUMAN)
```

The method derives a sorted distinct set from the referenced canonical
mapping. It returns:

- one ID for Hot-Seat;
- two IDs for current two-human Network;
- one ID for HUMAN/AUTOMATED; and
- an empty array for AUTOMATED/AUTOMATED.

This workbook does not call that API from attack code, create pending
inspection state, add acknowledgement commands, decide continuation, or alter
ADR-007/UX-005. The formal ADR-007 Entry Gate A rerun occurs only after
MATCH-001 implementation and verification complete. Replacement-peer
acknowledgement remains subject to the separate entitlement stop.

## 11. Deterministic Implementation Sequence

The cutover must not leave an old and new semantic owner active in parallel.

1. **Canonical value, behavior-inert:** add `MatchPlayerControlBinding`, exact
   validation, immutable read APIs, fixed-ID fixtures, and focused unit tests.
2. **`GameState` integration, not yet live:** add install-once ownership,
   serialization/deserialization, live-install validation, and read queries.
   Update test state builders to install explicit bindings; add no default
   binding in `PlayerState`, UI, or networking.
3. **Candidate-state/no-bypass refactor:** make `start_new_game()`, setup
   bootstrap, and loaded-state install validate candidates before publication.
4. **All new-match bootstraps:** add Hot-Seat construction and Network
   authoritative construction/config distribution for fixed and setup-package
   paths. Keep package format 1; make pending config one-shot.
5. **Network initial association and protocol 2:** establish host-held initial
   associations, split player/authoritative/replay submission provenance, and
   replace slot equality with principal-control authorization while preserving
   all gameplay validation.
6. **Save cutover:** activate required GameState serialization and save version
   4 together; reject v3; enforce Hot-Seat and Network installation gates.
7. **Replay cutover:** add the binding header, activate format 6/signed alias,
   reject v5 before commands, and route one-shot replay reconstruction.
8. **Loaded/snapshot reconstruction:** preserve same-match live Network
   associations, block fresh-lobby/replacement entitlement, and prove filtered
   mirrors carry but never own the binding.
9. **Fixture maintenance:** rerecord/promote only the two active baseline replay
   inputs through the accepted workflow, update the Hot-Seat state hash after
   semantic review, and leave trace format 1.
10. **Verification and cutover audit:** run focused, full, baseline, lint, and
    structural-write checks; then rerun ADR-007 Entry Gate A without
    implementing ADR-007.

Save version 4, replay format 6, protocol version 2, and the required live
binding activate as one completed MATCH-001 semantic cutover. Do not ship an
intermediate build that emits one new artifact format while accepting unbound
live state or slot-based Network authorization.

Rollback before the cutover may remove the behavior-inert substrate. Rollback
after cutover means reverting the whole MATCH-001 semantic change; v4 saves and
format-6 replays must not be relabeled for older code.

## 12. Verification Matrix

Tests are implementation work and are not changed by this Draft workbook.

| Verification obligation | Focused evidence to add or update |
| --- | --- |
| Canonical valid shapes | New `tests/unit/test_match_player_control_binding.gd`: Hot-Seat shared HUMAN, two distinct HUMAN, HUMAN/AUTOMATED, two AUTOMATED/zero HUMAN, canonical ordering, query results. |
| Canonical invalid shapes | Same file: missing player, duplicate player/record, duplicate/invalid IDs, dangling/unreferenced principal, invalid kind/type/unknown record field, bad UUID encoding. |
| Immutability | Same file and `test_game_state.gd`: input/output copies cannot mutate value; second install/replacement fails and preserves original. |
| `GameState` round trip | Update `tests/unit/test_game_state.gd`: required field, exact round trip, missing/malformed rejection, player-count cross-validation, future HUMAN set API. |
| Live no-bypass | Update GameManager tests: no unbound state reaches `current_game_state`, `is_game_active`, or `game_started`; failure leaves prior state/associations unchanged. |
| Normal Hot-Seat setup | `test_game_manager_setup_package.gd` and bootstrapper tests: all 400/300/180 package variants use one HUMAN for both players. |
| Fixed learning/debug | `test_game_board_scenario_bootstrap.gd`: both scenario IDs install the Hot-Seat binding before scenario preparation/live publication. |
| Normal two-human Network setup | Lobby/GameManager/Network tests: fixed and package configs carry one host-created binding, two HUMAN IDs differ, host/client state values are equal. |
| Structural automated support | Binding unit tests only: H/A and A/A pass, distinct HUMAN query excludes AUTOMATED, zero-HUMAN result is empty. Assert no bot command path is created. |
| Initial associations | `test_network_manager.gd`: complete lobby succeeds exactly once; missing/duplicate slot, wrong phase, repeat, or partial failure rejects and rolls back. Assert IDs differ from peer/client/display/player values. |
| Remote principal authorization | `test_network_manager.gd` plus transport integration: matching associated principal/player proceeds to gameplay validation; mismatch/missing association rejects before `CommandProcessor`; spoofed principal fields are ignored/not accepted. |
| Host/local authorization | `test_command_submitter.gd`: Hot-Seat one principal can submit either player's legal command; Network host cannot submit a player-originated command for the remote principal. |
| Gameplay legality independence | Submit an associated-but-illegal command and prove existing validation rejects it; submit a legal command from the wrong principal and prove authorization rejects before gameplay validation. Keep TWI-003/TEST-003 command tests unchanged. |
| Trusted and replay provenance | Verify listed server transitions still execute through `submit_authoritative()` and cannot be selected by remote RPC; `submit_replay()` reconstructs accepted history without live-principal claims. |
| Save v4 round trip | Update `test_save_game_metadata.gd`, `test_save_game_manager.gd`, and relevant shared-protocol tests: exact binding, signature coverage, validation order, checkpoint/named-save parity. |
| Legacy save disposition | Assert v3 returns `version_unsupported` before `GameState.deserialize()`/installation; no reconstructed IDs and no resave. Update former exact-version assertions from 3 to 4. |
| Replay v6 round trip | Update `test_game_replay.gd`, `test_replay_driver.gd`, and `CommandProcessor` replay tests: header capture, exact restoration, signed alias, both harness modes, no peer fabrication. |
| Legacy replay disposition | Assert every non-6 format, including 5, rejects before command canonicalization/application. Update former exact-format assertions from 5 to 6. |
| Authoritative distribution | Fixed/setup Network integration proves host/client serialized bindings equal and `PROTOCOL_VERSION == 2`; mixed v1/v2 handshake rejects. |
| Filtering/client mirrors | `test_state_filter.gd` and reconstruction tests: binding passes unchanged, credentials/client/peer IDs are absent, mirror has no mutation/rebind API, authoritative hashes agree. |
| Disconnect preservation | Transport/unit test: removing peer erases association only; authoritative `GameState` serialization and player mapping remain byte-equivalent. |
| Replacement peer stop | Simulate later handshake after disconnect: no association is created from slot, name, client ID, or claimed ID; command rejects and binding is unchanged. Do not assert successful reconnect. |
| Network load boundary | Load same-match earlier v4 state during the same live association and succeed; different-binding in-session load and every fresh-lobby Network load reject before host/client installation. |
| ADR-007 Entry Gate A | Read-only test of `get_distinct_controlling_principal_ids(HUMAN)` for the four shapes; no attack acknowledgement state or command. |
| Neighboring authority regression | Existing ADR-001/005/006, CON-001/005/006, TWI-003 shared-protocol, timing-window, current-attack, save/load, replay, and reconstruction suites remain passing without altered expected gameplay semantics. |

### 12.1 Required execution gates

Run, at minimum:

1. focused new binding/GameState tests;
2. focused setup, GameManager, save, replay, command-submitter, NetworkManager,
   StateFilter, and network-transport tests;
3. protected TWI-003/current-attack/timing-window shared-protocol tests;
4. `./scripts/run_tests.sh` full suite;
5. `./scripts/run_baseline_traces.sh --all` after accepted fixture promotion;
6. the repository lint/architecture checks named by the current development
   process;
7. a structural search proving no binding/principal mutation outside
   `match_player_control_binding.gd` construction and the one GameState install;
8. a structural search proving peer IDs, client IDs, display names, player
   indices, and UI/controller state are not assigned to `principal_id`; and
9. `git diff --check`, scoped diff review, and worktree-status review.

Production transport evidence must complement, not be replaced by, direct
function-call tests. Baseline fixture differences require semantic review;
they are not accepted merely because generation succeeds.

## 13. Stop Conditions, Risks, And Exit Gate

Stop implementation rather than invent a local solution if any step requires:

- associating a disconnected/replacement/current-lobby peer with an existing
  saved principal without an already-live exact association;
- a credential, account, reconnect secret, proof lifetime/rotation,
  replacement/takeover rule, or principal rebind;
- storing canonical principal facts outside `GameState`;
- deriving principal authority from player index, mode, name, profile, peer,
  connected membership, UI, or controller state after construction;
- changing ADR-007 acknowledgement or attack-continuation behavior;
- bot behavior or a generic participant/session/controller framework;
- accepting a legacy save/replay through unproved semantic synthesis; or
- weakening an accepted current-attack, timing-window, activation, declaration,
  setup, save, replay, or test authority.

MATCH-001 implementation is ready to begin only after this Draft workbook is
accepted under the repository workflow. Its implementation exit gate requires:

- every live creation/reconstruction path in Section 3.2 is covered;
- one valid immutable binding exists before every live publication;
- save v4, replay format 6/signed alias, and protocol 2 are the sole new
  formats and strict older-format rejection is proven;
- live player-originated Network authorization uses principal association,
  while gameplay legality remains independently enforced;
- disconnect changes no canonical principal fact and replacement entitlement
  fails closed;
- no second semantic owner or forbidden generalization exists;
- all Section 12 verification gates pass; and
- the formal ADR-007 Entry Gate A rerun can derive the four required HUMAN
  principal sets from the exact GameState API in Section 10.

No additional Project Owner decision is required for this implementation
plan's ownership, structural automated support, v3/v5 rejection, or initial
match association choices. A separate accepted architecture decision remains
required before any replacement-peer or fresh-lobby Network-resume entitlement
can be implemented.
