# MATCH-003: Fresh-Session Network Resume With Explicit Side Assignment Implementation Workbook

Status: Accepted
Accepted by: Project Owner
Accepted date: 2026-08-28

Date: 2026-08-28

Purpose: define the smallest coherent successor to superseded MATCH-002 for
fresh-session Network resume through explicit, host-authoritative,
pre-publication assignment of the two connected human endpoints to the two
unchanged saved HUMAN-controlled gameplay sides.

This workbook is the proposed executable successor to historical MATCH-002.
Until accepted by the Project Owner, it authorizes no production, test,
acceptance, or transition work. MATCH-002 remains non-executable historical
evidence and SHALL NOT be amended, repaired, or treated as an implementation
specification.

## 1. Classification, Authority, And Entry Result

This is **Uncertain/High-Risk Architecture** planning under
[CODEX_WORKFLOW](../CODEX_WORKFLOW.md). It crosses `BC-006`, `BC-007`, and
`BC-008`; affects Network association, hidden-information filtering,
save/load, reconstruction, protocol compatibility, and command admission; and
must transition a dirty implementation of a superseded design without
discarding unrelated or reusable work.

Normative authority, in precedence order:

- accepted, amended
  [ADR-011](../adr/ADR-011-network-match-resume-and-principal-entitlement.md);
- accepted
  [ADR-008](../adr/ADR-008-durable-match-lifetime-player-principal-binding.md),
  with only its Section 9 human-continuity proof requirement narrowly
  superseded by amended ADR-011;
- accepted
  [ADR-010](../adr/ADR-010-gameplay-interaction-decision-equivalent-recovery.md);
- accepted
  [MATCH-001](MATCH-001-player-principal-binding-implementation-workbook.md)
  for canonical binding, command authorization, current save/replay formats,
  same-live-match Network load, filtering, and the existing fail-closed fresh
  lobby boundary; and
- repository governance in
  [DOCUMENT_AUTHORITY](../DOCUMENT_AUTHORITY.md),
  [CODEX_WORKFLOW](../CODEX_WORKFLOW.md), and the
  [Architecture Roadmap](../ARCHITECTURE_ROADMAP.md).

[ODR-003](../decision_workbooks/ODR-003-network-match-resume-and-replacement-principal-entitlement.md)
preserves accepted Owner reasoning but is not normative after ADR-011
extracted the amended decision. Superseded
[MATCH-002](MATCH-002-network-match-resume-and-principal-reassociation-implementation-workbook.md)
is historical, non-executable implementation evidence only. This workbook
reuses only independently justified seams: staged reconstruction, atomic
publication, filtered installation, transient associations, command-admission
closure, confirmed-loss reconnect, and process-isolated Network evidence.

Applicable traceability:

- `BC-006` / `RG-007` / `AT-006`: keep canonical installation with the
  existing `GameManager.start_new_game_from_state()` seam and add no new
  `GameManager` responsibility category;
- `BC-007` / `RG-013` / `AT-008`: prove assignment, filtering, transport,
  reconnect, and command-admission invariants with focused and real
  multi-process evidence; and
- `BC-008` / `RG-013` / `RG-016` / `AT-009`: preserve save/checkpoint
  validation, format, trust boundary, reconstruction cursor, and Hot-Seat
  behavior.

### 1.1 Entry gates

| Gate | Result | Repository evidence and implementation posture |
| --- | --- | --- |
| Canonical identity already exists | **PASS** | `GameState` owns the immutable `MatchPlayerControlBinding`; load and replay already serialize and validate it. MATCH-003 derives a saved principal from an explicitly selected saved gameplay side and never creates, replaces, reclassifies, or rebinds a principal. |
| Fresh candidate can remain non-live | **PASS** | `SaveGameManager.load_game*()` returns a validated candidate and metadata before `GameManager.start_new_game_from_state()` publishes it. `LobbyManager` can hold one purpose-specific pending resume without changing canonical ownership. |
| Two-human assignment is bounded | **PASS** | The supported Network shape is exactly two connected endpoints and exactly two distinct HUMAN principals, each controlling one saved gameplay player. No participant generalization is required. |
| Host can assign itself explicitly | **PASS** | `NetworkManager` already owns host-local and remote transient principal associations plus the local gameplay viewer index. MATCH-003 may set those transient values from the validated host choice rather than from lobby slots. |
| Filtered client reconstruction exists | **PASS** | `StateFilter.filter_for_player()` -> `GameState.deserialize()` -> reconstruction-cursor validation -> `UIProjector` is an existing tested seam. It can stage the client view only after the complete assignment determines the authorized player. |
| Publication and command admission can fail closed | **PASS** | The dirty MATCH-002 work demonstrates purpose-specific staging, installation acknowledgement, and admission gates in the existing managers. Credential logic must be removed, but the ordering seams are reusable. |
| Confirmed-loss reconnect has a bounded transport seam | **PASS WITH BOUNDED CHANGE** | Baseline transport removes associations on confirmed disconnect but has no production snapshot/reassignment RPC. The dirty work proves an in-game handshake, targeted filtered snapshot, and installation ACK are feasible. Replace proof with explicit host assignment; do not generalize the session model. |
| Same-live load can remain separate | **PASS** | MATCH-001's `can_install_loaded_binding()` preserves exact live binding and associations. Fresh resume uses a distinct staged branch and does not weaken or route through this gate. |
| Current artifact compatibility can remain unchanged | **PASS** | `SaveGameMetadata.CURRENT_VERSION == 5` and `GameReplay.FORMAT_VERSION == 7`. Session assignment adds no canonical or persistent field. Only Network RPC shape changes, so protocol 3 -> 4 is sufficient. |
| Dirty transition is deterministic | **PASS** | Section 3 establishes the exact baseline commit and Section 12 classifies every dirty MATCH-002 path as RETAIN, ADAPT, RESTORE, or DELETE. |

**Overall entry result: PASS FOR WORKBOOK ACCEPTANCE.** Implementation may
begin only after this Draft is accepted. Any Section 15 stop gate overrides
this result.

## 2. Selected Smallest Strategy

Add one purpose-specific fresh-resume coordinator across the existing
`LobbyManager` and `NetworkManager` seams and one narrow side-assignment UI.
Do not add persistent proof or a generic participant/controller/session
aggregate.

1. A host in a complete two-human lobby selects a current valid Network save
   or Network checkpoint through the existing load dialog.
2. The normal load pipeline verifies the existing installation-local save
   signature, current version, canonical state, and reconstruction cursor.
   The candidate remains staged; it is not installed into `GameManager`.
3. The host receives a purpose-specific assignment surface with two connected
   endpoint rows, including the host, and two saved gameplay-side choices.
   The host explicitly chooses one side for each endpoint.
4. The host validates the complete one-to-one mapping. Each selected gameplay
   side resolves to the exact principal already bound to it in the saved
   `MatchPlayerControlBinding`.
5. The host commits both transient endpoint-to-existing-principal
   associations with player-command admission closed, then sends the remote
   endpoint only `StateFilter.filter_for_player(candidate, assigned_player)`.
6. The remote endpoint deserializes and validates the filtered candidate and
   cursor into purpose-specific staging memory and acknowledges readiness. It
   does not expose the board or accept input.
7. The host revalidates candidate, cursor, binding, endpoints, assignment,
   associations, and readiness, then publishes the full canonical candidate
   exactly once through `GameManager.start_new_game_from_state()`.
8. The remote endpoint receives the commit, installs its already validated
   filtered candidate exactly once, and acknowledges installation.
9. Only after all expected installation acknowledgements does the host enable
   player-originated admission for both saved HUMAN principals and release the
   board transition. Presentation is then re-derived from installed state.

The host can choose either saved side. The implementation SHALL NOT contain a
fallback that maps host to Player 0, client to Player 1, or maps by lobby slot,
arrival order, readiness, peer ID, profile ID, display name, or prior endpoint.

### 2.1 Why this is the smallest conforming design

- It preserves `GameState`, `MatchPlayerControlBinding`, save v5, replay v7,
  `StateFilter`, `UIProjector`, and `GameManager` ownership unchanged.
- It removes all capability generation, custody, transfer, persistence,
  challenge, signature, verifier, and recovery behavior.
- It reuses the existing load dialog, lobby, transient peer association,
  command authorization, state installation, and Network transport owners.
- It introduces only a purpose-specific assignment surface and coordinator;
  no general controller, participant, bot, identity, or session framework is
  created.
- It allocates one protocol cutover for the actual new transport messages and
  no save/replay format cutover.

## 3. Deterministic Pre-MATCH-002 Implementation Baseline

The exact clean implementation baseline is:

```text
75061be58b6b8f719426ac19fd8de73830917c0c
docs: accept MATCH-002 network resume implementation plan
```

Repository evidence:

1. Commit `75061be58b6b8f719426ac19fd8de73830917c0c` changes only
   `ADR-011` and the newly accepted MATCH-002 workbook. It contains no
   production, test, script, user-guide, or QA-acceptance implementation
   change.
2. Its successor and current `HEAD`,
   `e806ef2301dbeebd09bf64a02473e66174508bfb`, is the authoritative decision
   amendment. `git diff --name-status 75061be..e806ef2` lists only six
   documentation paths: ADR-008, ADR-011, ODR-003, historical MATCH-002, the
   historical MATCH-002 manual acceptance record, and the Network setup guide.
3. Therefore every tracked production and test path in Section 12 has the
   same clean content at `75061be` and at current `HEAD`. The dirty changes on
   those paths are the uncommitted superseded MATCH-002 implementation.
4. The current authoritative documentation SHALL remain at `e806ef2` or its
   later descendants. The baseline is used only path-by-path for implementation
   transition; it is not a request to move `HEAD` or restore authority docs.

The historical manual-acceptance phrase “4100/4100 pre-implementation
baseline” records a test-count checkpoint, not a Git object identity. It is
insufficient for rollback and does not replace the full commit hash above.

Later transition must compare every tracked implementation path with
`75061be58b6b8f719426ac19fd8de73830917c0c`. It SHALL NOT use `HEAD` as an
implicit baseline if further commits land before implementation.

## 4. Ownership And Transient Data

| Responsibility | Existing owner | MATCH-003 behavior | Explicit non-owner |
| --- | --- | --- | --- |
| Canonical gameplay state and player/principal binding | `GameState` / `MatchPlayerControlBinding` | Restore and validate exactly; no field or mutator added. | Lobby, endpoint, UI, assignment coordinator |
| Save trust, parsing, version, and cursor | `SaveGameManager`, `SaveGameMetadata`, existing integrity helpers | Reuse unchanged v5 load/checkpoint pipeline and `reconstruction_cursor_for()`. | Assignment UI, peer record |
| Fresh candidate and publication orchestration | `LobbyManager` | Hold one pending state/meta/cursor/fingerprint and coordinate assignment, staging, publish, abort, and exact-once UI signals. | `GameState`, generic session service |
| Endpoint association, assignment validation, filtering, RPC, and admission | `NetworkManager` | Hold one purpose-specific attempt; map explicit endpoint -> saved player -> existing principal; enforce exclusivity; target filtered snapshots; maintain admission. | `GameManager`, UI, lobby slot |
| Assignment presentation | New narrow `NetworkSideAssignmentDialog`, hosted by `LobbyRoom` for fresh resume and `GameMenuModal` for live reconnect | Display endpoint labels and public saved-side labels; submit a proposed mapping; never derive or commit authority. | Canonical state, association validator |
| Canonical publication | Existing `GameManager.start_new_game_from_state()` | Remains the sole host live-state publication linearization point. No production change authorized. | `LobbyManager` pending dictionary, UI |
| Remote mirror installation | Existing `GameManager.start_new_game_from_state()` on the client | Install only the correctly filtered, already validated staged state after host commit. No production change authorized. | State filter, assignment UI |
| Gameplay legality | Existing command/applicability/rule/turn/activation/timing owners | Unchanged and evaluated after association/admission authorization. | Assignment, peer role |
| Presentation recovery | Existing `UIProjector`, modal/controller reconstruction | Re-derive the decision after installation; never progress gameplay. | Assignment or snapshot ACK |

Purpose-specific transient records may contain only:

- attempt ID and operation (`fresh_session_resume` or `reconnect`);
- validated candidate state/meta reference, canonical state fingerprint, saved
  binding serialization, and reconstruction cursor;
- expected connected endpoint IDs and non-authoritative display labels;
- explicit endpoint -> saved gameplay-player proposals;
- derived endpoint -> existing saved principal associations;
- staging and installation acknowledgement sets;
- phase and exact-once guards; and
- prior transient association/viewer values required for pre-publication
  rollback.

They SHALL NOT contain a persistent human ID, credential, key, verifier,
signature, entitlement, transfer record, account/profile authority, canonical
rebind, or generic controller lifecycle.

## 5. Fresh-Session Assignment UX And Validation

### 5.1 Entry and staging UX

The current load dialog remains the save-selection surface. In a ready
two-human Network lobby, selecting a Network save/checkpoint calls a distinct
fresh-resume staging branch instead of the MATCH-001 same-live-load branch.

Before the assignment surface appears, the host validates:

1. server role and `LOBBY` connection state;
2. exactly one authenticated remote participating endpoint plus the host
   endpoint;
3. a current valid Network save/checkpoint under the existing original
   save-owning-installation trust/file boundary;
4. a valid canonical candidate and reconstruction cursor;
5. exactly two distinct saved `HUMAN` principals;
6. exactly one saved gameplay player controlled by each of those principals;
7. no AUTOMATED principal, shared Hot-Seat principal, missing side, extra
   participant, or malformed binding; and
8. no other pending fresh-resume attempt.

The board, canonical state, command cursor, local gameplay viewer, and current
associations remain unchanged at this point.

### 5.2 Host assignment surface

The host sees exactly two endpoint rows:

- the host endpoint, explicitly labelled as host for presentation only; and
- the one connected client endpoint, labelled with its current display name
  for presentation only.

Each row has a saved-side selector. Side labels may use player index and
already public saved side/faction/display metadata. The assignment surface
must not render a board, private hand, hidden dial, owner-only interaction
payload, or any other side-filtered gameplay fact.

Both selectors begin unassigned. A convenience **Swap** action is permitted
only when it writes the same explicit two-row proposal; it is not authority.
The **Resume With This Assignment** action remains disabled until both endpoint
rows are assigned to different saved sides. Its final confirmation shows the
complete endpoint-to-side mapping and authorizes automatic publication only
after every later validation and installation gate succeeds. No second
publication click is required. Client consent is not required by ADR-011; the
client sees non-authoritative waiting/assignment status.

### 5.3 Completeness and exclusivity validator

The host accepts a proposal only if all conditions hold together:

1. expected endpoint set is exactly `{host, authenticated client}`;
2. proposal keys equal that endpoint set exactly;
3. proposal values equal the two saved gameplay-player indices exactly;
4. each endpoint and each saved side appears once;
5. each selected side resolves through the unchanged saved binding to one
   distinct HUMAN principal;
6. no resolved principal has another staged or active endpoint association;
7. the client endpoint is still connected and authenticated;
8. candidate fingerprint, binding, cursor, save metadata, and expected endpoint
   set equal their staged values; and
9. attempt/phase is current and has not already committed or aborted.

Unknown fields, missing rows, duplicate endpoints, duplicate sides, stale
peer IDs, wrong phase, repeated submission, or any mismatch fail before
snapshot distribution. Validation derives principal IDs from the saved side;
the UI and client never submit a principal ID as authority.

## 6. Association, Filtering, Publication, And Admission Ordering

The required fresh-resume state machine is purpose-specific:

```text
IDLE
  -> CANDIDATE_STAGED
  -> ASSIGNMENT_STAGED
  -> ASSOCIATIONS_COMMITTED_ADMISSION_CLOSED
  -> CLIENT_STAGE_ACKNOWLEDGED
  -> HOST_CANONICAL_PUBLISHED
  -> CLIENT_INSTALLED_ACKNOWLEDGED
  -> PUBLISHED_ADMISSION_OPEN
```

Any pre-host-publication failure transitions to `ABORTED`, discards client and
host staging, restores prior transient viewer/association values, and leaves
the canonical state/cursor untouched. Duplicate valid deliveries are
idempotent; contradictory duplicates fail closed.

### 6.1 Association commit

After complete validation, `NetworkManager` derives:

```text
endpoint ID -> explicitly selected saved player index
            -> saved binding principal_id_for_player(player index)
```

It commits the two derived transient associations as one synchronous set with
no admitted principal. It also sets the host and client transient local viewer
indices to their assigned saved sides only within the guarded attempt. Lobby
slot/player indices are not rewritten into canonical authority and are not a
fallback.

### 6.2 Hidden-information staging

Only after the complete association set is committed may the host serialize
the candidate for distribution. For each remote endpoint it sends exactly:

```text
StateFilter.filter_for_player(candidate.serialize(), assigned_player_index)
+ current save metadata needed by existing installation
+ attempt ID, assigned player index, and non-secret existing principal label
```

The client verifies the attempt, deserializes the filtered state, checks that
the unchanged binding controls the assigned player through the supplied
principal, validates the reconstruction cursor, and holds the state outside
live `GameManager`. The acknowledgement means only “this authorized filtered
candidate is valid and staged.” It grants no command authority and triggers no
scene transition or gameplay command.

No endpoint receives a snapshot before the complete mapping exists. No remote
endpoint receives both filtered views. The authoritative host necessarily
holds the full candidate in memory, but its staging UI and later local
presentation expose only the public assignment labels and its assigned-side
view. The full binding may remain in each filtered state as MATCH-001's
non-secret canonical identifier structure; it is not authorization proof.

### 6.3 Publication and installation

Immediately before host publication, repeat every Section 5.3 check plus the
client staging acknowledgement. The successful return from the host's existing
`GameManager.start_new_game_from_state()` is the sole canonical live-state
linearization point. That existing installation seam emits
`EventBus.game_started` when it installs the host state and, later, when it
installs the client mirror. Those canonical installation events are distinct
from `LobbyManager.game_starting`, which releases the board-scene transition
only after installation acknowledgement and command admission are complete.
MATCH-003 adds no second canonical `game_started` event and no new
`GameManager` responsibility.

After that return:

1. mark the host canonical state live with admission still closed;
2. send one commit message to the client for the already staged attempt;
3. client installs the staged filtered state exactly once through the existing
   installation seam and acknowledges the exact attempt/cursor;
4. after every expected installation acknowledgement, add both saved HUMAN
   principals to the narrow admitted-principal set;
5. enable the corresponding client-local submitter gate; and
6. emit the gated `LobbyManager.game_starting` board-scene release once per
   endpoint and re-derive presentation.

Player-originated command admission is authorized only when:

```text
submitting endpoint -> committed transient principal association
                    -> principal is currently admitted
                    -> unchanged saved binding controls command.player_index
                    -> existing gameplay legality accepts the command
```

Trusted authoritative engine submissions and `submit_replay()` remain on
their existing separate provenance paths.

### 6.4 Post-linearization failure

After host publication, canonical state is not rolled back by presentation or
transport code. If the client disconnects or rejects installation, the host
keeps the restored canonical state live but removes/non-admits only the missing
side's transient association. The board must remain fail-closed from that
side's input and complete through the ordinary reconnect path in Section 7.
No second save load, host installation, host `EventBus.game_started`, or
`LobbyManager.game_starting` board release occurs.

## 7. Confirmed-Loss Reconnect Lifecycle

Reconnect applies only to an already-live Network match and an unoccupied
saved HUMAN-controlled side.

1. Confirmed disconnect removes the endpoint's transient association and that
   principal from the admitted-principal set. Canonical state, principal kind,
   binding, command history, cursor, and other side's association/admission
   remain unchanged.
2. A new in-game handshake authenticates transport only. The endpoint is held
   as connected but unassigned with player-command admission closed. It does
   not receive a vacant lobby slot or state snapshot automatically.
3. The host receives a purpose-specific **Assign Reconnected Player** prompt.
   It shows the connected unassigned endpoint and the currently unoccupied
   saved side. The host must explicitly select and confirm that side even when
   only one legal mapping exists.
4. Assignment fails while an incumbent association for that side is active or
   its loss has not been confirmed. No eviction or timeout-based takeover is
   added.
5. After validation, commit the new endpoint -> existing principal association
   with that principal still non-admitted.
6. Send only the current `StateFilter` result for the explicitly selected
   player, plus the current cursor and attempt metadata.
7. The client validates, installs, and acknowledges the current filtered state.
8. Add only that principal back to the admitted set and release the client
   board/presentation. The incumbent side remains admitted throughout.

Reconnect may be performed by the prior human or a different human. It SHALL
NOT inspect or match a credential, previous peer ID, freed lobby slot, profile,
client ID, display name, or host/client role. It SHALL NOT reload, replace, or
republish the host canonical state or synthesize gameplay progression.

## 8. Existing Behavior Preservation

| Capability | Required MATCH-003 disposition |
| --- | --- |
| Same-live-match Network load | Preserve MATCH-001 exactly: `IN_GAME`, exact loaded/live binding equality, and all existing associations still controlling the same saved players. Do not show assignment UI, change viewer indices, or reshuffle associations. A missing association continues to reject the load. |
| Save/checkpoint format | Keep save version 5 and existing HMAC/trust pipeline. Add no canonical assignment, credential, registry, or resume metadata. Every valid current v5 two-HUMAN Network save on the supported save-owning installation is eligible for structural staging. |
| Save portability | Remains unresolved and unsupported. No copied-save/new-host acceptance, key transfer, cloud flow, or integrity redesign is authorized. |
| Decision-equivalent reconstruction | Restore exact state and cursor, run only existing accepted canonical reconciliation, and derive the same next mandatory/optional decision or stable state. Assignment, ACKs, scene transitions, and projection submit no gameplay command. |
| Hot-Seat | Preserve one HUMAN principal controlling both players, named/checkpoint load behavior, and local submission. No Network assignment UI, RPC, or protocol state is created. |
| Replay | Preserve replay format 7, saved binding reconstruction, accepted-history submission, and Network replay harness semantics. Replay creates no live resume assignment and needs no endpoint entitlement. |
| New Network match | Preserve MATCH-001 initial lobby-slot construction of new principals and initial associations. Remove MATCH-002's initial capability/verifier preparation. Explicit saved-side assignment applies only to fresh resume and confirmed-loss reconnect. |
| State filtering | Keep `StateFilter` production code unchanged. Add evidence that each assigned client receives exactly one correct filtered view and no owner-only fact from the other side. |
| Gameplay ownership | Preserve every accepted command, attack, activation, timing, rule, and continuation owner. No recovery callback or assignment surface becomes semantic authority. |

## 9. Network Protocol Compatibility

Allocate and activate **Network protocol version 4** for MATCH-003. The clean
implementation baseline and committed product protocol is version 3. The dirty
MATCH-002 tree's version-4 value is reusable only as the uncommitted allocation;
its credential RPC schema is not compatible and must be replaced.

Protocol 4 contains only the narrow messages needed for:

- fresh-resume assignment status and attempt identity;
- targeted filtered staging snapshot and staging acknowledgement;
- association/publication commit and installation acknowledgement;
- admission enable/abort;
- in-game transport-only handshake status; and
- explicit reconnect assignment and targeted current snapshot.

Message payloads contain no private or persistent proof. Host/client mixed
protocol 3/4 sessions reject at the existing handshake version gate; do not
downgrade or retain credential-era protocol-4 RPC aliases. Since the dirty
protocol 4 was never committed as an accepted implementation, no protocol 5
allocation is justified.

Save version 5, replay format 7, baseline trace format, setup package format,
and canonical `GameState` schema remain unchanged.

## 10. Failure, Rollback, And Exact-Once Rules

Before host canonical publication, all of these abort the complete fresh
attempt with zero live install and zero player command:

- invalid save, cursor, state, binding, or Network metadata;
- unsupported principal cardinality/kind/mapping;
- incomplete, duplicate, ambiguous, stale, or competing assignment;
- endpoint disconnect or authentication/state change;
- candidate/binding/cursor mutation;
- snapshot/filter/deserialization/reconstruction rejection;
- missing or contradictory acknowledgement;
- repeat commit, wrong attempt, wrong phase, or protocol mismatch; and
- cancellation by the host.

RPCs are exact-once in effect:

- duplicate proposal never creates another association;
- duplicate staging snapshot/ACK never advances phase twice;
- duplicate commit never installs or emits `game_started` twice;
- duplicate installation ACK never opens admission twice;
- stale/aborted attempt messages are ignored or rejected without touching a
  newer attempt; and
- disconnect cleanup is idempotent.

Rollback is transient only. It may restore the pre-attempt host/client local
viewer index and association dictionaries before canonical publication. It may
not mutate or reconstruct a different `GameState`, binding, principal, player,
or command cursor.

## 11. Authorized Implementation Scope After Acceptance

No implementation file is authorized while this workbook remains Draft. After
Owner acceptance, the maximum authorized scope is below. Evidence may reduce
this scope; expansion requires workbook refinement or a stop-gate decision.

### 11.1 Production files

| Path | Authorized purpose |
| --- | --- |
| `src/autoload/lobby_manager.gd` | Purpose-specific candidate staging, assignment/publish orchestration, failure/cancel/exact-once signals; preserve ordinary new-match and same-live-load branches. |
| `src/autoload/network_manager.gd` | Protocol 4, explicit assignment validation/association, admitted-principal gating, targeted filtered snapshot RPCs, confirmed-loss reconnect, and cleanup. Remove all credential-era behavior. |
| `src/scenes/lobby/lobby_room.gd` | Host fresh-resume assignment/status/cancel/publish presentation through the narrow dialog; client waiting status only. |
| `src/ui/save/game_menu_modal.gd` | Host-only entry/status for explicit assignment of an unassigned reconnecting endpoint; no capability management. |
| `src/ui/network/network_side_assignment_dialog.gd` | New purpose-specific, non-authoritative two-endpoint/two-side assignment UI reusable by lobby and reconnect. |
| `src/ui/network/network_side_assignment_dialog.gd.uid` | Godot UID paired with the new script if generated by normal import. |

No production change is authorized in `GameState`,
`MatchPlayerControlBinding`, `GameManager`, `StateFilter`, `UIProjector`,
commands, save/replay models, integrity helpers, player profiles, or generic
session/controller abstractions.

### 11.2 Automated evidence files

| Path | Authorized purpose |
| --- | --- |
| `tests/unit/test_network_manager.gd` | Assignment validator, atomic association, per-principal admission, competition, disconnect, exact-once, and protocol tests. |
| `tests/unit/test_lobby_manager_load.gd` | Candidate staging, no early publication, cancel/failure, host publication linearization, and same-live branch preservation. |
| `tests/unit/test_lobby_room.gd` | Explicit host/client row UX, no automatic mapping, completeness gating, status, and cancel/publish behavior. |
| `tests/unit/test_game_menu_modal.gd` | Host-only reconnect assignment entry and Hot-Seat/client preservation. |
| `tests/unit/test_network_side_assignment_dialog.gd` | New pure UI proposal/completeness tests; prove presentation never commits authority. |
| `tests/integration/test_network_transport.gd` | Protocol 4 negotiation and transport guards. |
| `tests/integration/test_network_resume_and_reassociation.gd` | Fresh staging/publication/filter/recovery, swapped assignment, reconnect, and same-live/Hot-Seat/replay integration. |
| `tests/integration/test_network_resume_and_reassociation.gd.uid` | Preserve the existing untracked UID with the adapted integration test. |
| `scripts/run_network_resume_acceptance.sh` | Adapt the existing real multi-process runner to MATCH-003 scenarios with isolated roots and no credential artifacts. |
| `tests/acceptance/network_resume/driver.gd` | Adapt process driver to explicit assignment and confirmed-loss reconnect. |
| `tests/acceptance/network_resume/driver.gd.uid` | Preserve stable UID. |
| `tests/acceptance/network_resume/driver.tscn` | Preserve existing driver scene. |
| `tests/acceptance/network_resume/assertions.gd` | Adapt machine-readable assertions to assignment, filtering, admission, and exact-once evidence. |
| `tests/acceptance/network_resume/assertions.gd.uid` | Preserve stable UID. |

Existing focused recovery, save/load, Network command, filtering, replay,
Hot-Seat, current-attack, timing-window, activation, and baseline tests may be
updated only if a concrete expectation must change from protocol 3 to 4. No
canonical gameplay expectation is expected to change.

### 11.3 Documentation and acceptance files

| Path | Disposition at successor implementation |
| --- | --- |
| `docs/setup_network_game.md` | **ADAPT.** Preserve accurate assignment/reconnect and same-live guidance; remove the transition warning, credential-control references, and “not implemented” language only after acceptance passes. Document the actual UI labels and protocol 4. |
| `docs/qa/MATCH-002-network-resume-manual-acceptance.md` | **RETAIN UNCHANGED AS HISTORICAL.** It is superseded credential-era evidence and must not be executed, rewritten as MATCH-003 evidence, or deleted. |
| `docs/qa/MATCH-003-network-resume-manual-acceptance.md` | **CREATE DURING IMPLEMENTATION.** Record the Section 14.3 cases, results, build commit, screenshots/log references, and unresolved failures without credential/security language. |
| `docs/architecture/implementation_workbooks/MATCH-002-network-match-resume-and-principal-reassociation-implementation-workbook.md` | **RETAIN UNCHANGED.** Historical, non-executable evidence only. |
| This MATCH-003 workbook | Update status only through Owner acceptance and later evidence checkpoints under repository governance; do not self-accept. |

## 12. Existing Dirty MATCH-002 Transition Map

The treatment below classifies every superseded MATCH-002 implementation path
reported against current `HEAD` on 2026-08-28, excluding this untracked
MATCH-003 workbook itself. It covers exactly 33 MATCH-002 implementation paths:
4 RETAIN, 13 ADAPT, 8 RESTORE, and 8 DELETE. RETAIN means directly compatible
as a file artifact; ADAPT means preserve only the named seam while replacing
superseded behavior; RESTORE means restore the tracked path exactly from the
Section 3 baseline before applying any independently authorized successor edit;
DELETE means remove the exact untracked credential-specific artifact.

### 12.1 RETAIN

| Path | Mechanical treatment and rationale |
| --- | --- |
| `tests/acceptance/network_resume/assertions.gd.uid` | Keep unchanged; stable UID for the adapted successor assertions script. |
| `tests/acceptance/network_resume/driver.gd.uid` | Keep unchanged; stable UID for the adapted process driver. |
| `tests/acceptance/network_resume/driver.tscn` | Keep unchanged unless Godot import proves a path update is required. It only binds the purpose-specific driver scene and contains no credential behavior. |
| `tests/integration/test_network_resume_and_reassociation.gd.uid` | Keep unchanged; stable UID for the adapted integration suite. |

### 12.2 ADAPT

| Path | Mechanical treatment and rationale |
| --- | --- |
| `src/autoload/lobby_manager.gd` | Preserve the pending-candidate, stage/ACK, publication-linearization, post-linearization failure, cancel, and exact-once seams. Restore ordinary new-match startup from baseline; remove all initial-entitlement signals/gates. Replace claims/proofs with the complete explicit endpoint-to-side proposal and revalidation. Preserve same-live load unchanged. |
| `src/autoload/network_manager.gd` | Preserve protocol-4 allocation, purpose-specific attempt staging, targeted filtering, staging/install ACKs, in-game transport-only handshake, disconnect lifecycle, competition checks, and admission closure. Delete capability façade/store, initial verifier registration, challenge/proof/claim logic, registry checks, match-fingerprint-as-entitlement behavior, and credential statuses. Derive associations only from host-confirmed player selections and saved binding. Replace the global host admission behavior with narrow per-principal host authority so reconnect closes only the lost side. |
| `src/scenes/lobby/lobby_room.gd` | Preserve resume status, cancel, and publication-gate presentation seams. Repurpose the current publish confirmation as the complete **Resume With This Assignment** confirmation, then publish automatically after downstream gates. Replace capability paste/import and entitlement status with the explicit two-row side-assignment dialog and client waiting summary. No host grant/takeover wording is needed; host assignment is the accepted current-session authority. |
| `src/ui/save/game_menu_modal.gd` | Replace Resume Capabilities with host-only **Assign Reconnected Player** behavior and the new purpose-specific dialog. Preserve Hot-Seat and Network-client save/load visibility. |
| `tests/integration/test_network_transport.gd` | Retain real-transport documentation and protocol-4/mixed-v3 rejection coverage; replace MATCH-002 wording and add/route successor message-shape evidence as needed. |
| `tests/unit/test_game_menu_modal.gd` | Replace capability visibility assertions with host-only reconnect-assignment visibility/status; preserve existing menu behavior tests. |
| `tests/unit/test_lobby_manager_load.gd` | Retain the fresh-lobby no-early-publication seam and cleanup scaffolding; replace missing-registry rejection with successful valid-candidate staging plus incomplete/invalid assignment failure, cancel, and same-live regression. |
| `tests/unit/test_lobby_room.gd` | Replace capability import assertions with explicit unassigned host/client rows, duplicate-side disablement, swapped mapping, one complete assignment confirmation, and no automatic host/client mapping. |
| `tests/unit/test_network_manager.gd` | Preserve admission, competition, disconnect, attempt cleanup, and protocol scaffolding. Replace store/proof fixtures with explicit endpoint/player proposals and exact saved binding fixtures. Prove per-principal reconnect admission and no incidental identity inference. |
| `scripts/run_network_resume_acceptance.sh` | Preserve isolated process roots, bounded cleanup, real ENet launch, timeouts, redacted logs, and machine-readable evidence. Rename MATCH-002 labels/temp roots; remove capability transfer/competitor-proof/forged-proof steps; add explicit swapped assignment, incomplete/duplicate assignment, confirmed-loss reconnect with a different endpoint, and zero hidden-state leakage. Never use broad untracked cleanup. |
| `tests/acceptance/network_resume/driver.gd` | Preserve production-RPC process orchestration, reused original host/client roots where relevant, state/cursor snapshots, disconnect confirmation, and exact-once counters. Replace capability import/export/proof behavior with host proposal submission and reconnect assignment. |
| `tests/acceptance/network_resume/assertions.gd` | Preserve cross-process convergence/admission/protocol assertions. Replace credential, replacement-holder, forged-proof, and foreign-host-entitlement assertions with explicit mapping, swapped-side, duplicate/incomplete rejection, hidden filtering, confirmed-loss reconnect, and no-republication assertions. Save portability remains outside the positive scenarios. |
| `tests/integration/test_network_resume_and_reassociation.gd` | Preserve filtered reconstruction, unchanged binding/format, staging/publication, reconnect, and decision-recovery seams. Replace all entitlement/store/proof inputs and expectations with explicit assignment and structural save eligibility. |

### 12.3 RESTORE

Restore each tracked path exactly from
`75061be58b6b8f719426ac19fd8de73830917c0c`. Do not reconstruct the baseline
by hand and do not restore any directory.

| Path | Rationale |
| --- | --- |
| `src/autoload/save_game_manager.gd` | Added resumability queries exist only to inspect a credential/verifier registry. Current valid v5 Network saves need no new persistent eligibility record; structural/candidate validation belongs in the staged resume entry. |
| `src/scenes/main_menu/main_menu.gd` | Resume capability management and join-time capability paste have no successor purpose. Fresh resume begins in a hosted lobby; reconnect assignment is host-side and session-local. |
| `src/ui/save/load_game_dialog.gd` | Credential-registry row gating conflicts with the successor. Baseline already exposes Network saves in a valid lobby and routes loading through `LobbyManager`, where full staging validation now belongs. |
| `src/utils/path_config.gd` | Every added path is for private capability/verifier persistence, which the successor forbids. |
| `tests/unit/scenes/main_menu/test_main_menu_new_game.gd` | Added test asserts credential management UI only. |
| `tests/unit/test_load_game_dialog.gd` | All added fixtures and expectations depend on a verifier registry. Restore baseline lobby row behavior. |
| `tests/unit/test_path_config.gd` | Added test protects credential paths that must not exist. |
| `tests/unit/test_save_game_manager.gd` | Added version assertion is credential-rationale-only and duplicates existing current-version coverage. Save v5 preservation is covered by successor integration/compatibility tests. |

### 12.4 DELETE

Delete only these exact untracked paths after their successor replacements are
ready. No wildcard, recursive untracked cleanup, or generic directory deletion
is permitted.

| Path | Rationale |
| --- | --- |
| `src/core/network/match_principal_entitlement_store.gd` | Entire artifact implements persistent RSA capability/verifier storage, signing, proof, transfer, and registry behavior removed by amended ADR-011. |
| `src/core/network/match_principal_entitlement_store.gd.uid` | UID belongs only to the deleted credential store. |
| `src/ui/network/match_principal_capability_dialog.gd` | Entire UI manages credential listing/import/export and has no independent assignment purpose. |
| `src/ui/network/match_principal_capability_dialog.gd.uid` | UID belongs only to the deleted capability dialog. |
| `tests/unit/test_match_principal_capability_dialog.gd` | Tests only superseded credential UI. |
| `tests/unit/test_match_principal_capability_dialog.gd.uid` | UID belongs only to the deleted credential UI test. |
| `tests/unit/test_match_principal_entitlement_store.gd` | Tests only persistent credential, RSA proof, verifier registry, corruption, transfer, and proof-retention behavior. |
| `tests/unit/test_match_principal_entitlement_store.gd.uid` | UID belongs only to the deleted credential-store test. |

### 12.5 Required transition procedure

Later implementation SHALL:

1. re-record current `git status --short` immediately before transition and
   compare it with this inventory;
2. identify, record, preserve, and report any unrelated non-overlapping user
   changes that appeared after this workbook was drafted; such work is not
   unexplained debris and SHALL NOT be restored, deleted, or cleaned;
3. stop if a new dirty change overlaps a classified path or hunk and the
   transition cannot be performed safely without disturbing that change;
4. restore only the eight Section 12.3 paths from the full baseline hash;
5. delete only the eight exact Section 12.4 untracked paths;
6. retain the four Section 12.1 paths;
7. adapt each Section 12.2 file by reviewing its diff against the full
   baseline hash, removing superseded hunks, and applying the successor plan;
8. add only the new paths authorized by Section 11; and
9. prove final status contains no unexplained MATCH-002 transition path and no
   targeted MATCH-002 credential-era symbol prohibited by Section 14.4.

The transition SHALL NOT use `git reset --hard`, `git restore .`, broad
`git checkout`, directory-wide restore, `git clean`, wildcard deletion,
generic deletion of untracked files, or any operation that changes the
authoritative documentation commits. Path-specific restore must name both the
full baseline hash and each exact tracked path. Deletion must name each exact
untracked credential artifact.

## 13. Deterministic Implementation Sequence

1. **Path-specific transition:** execute Section 12 only after workbook
   acceptance; verify baseline equality on RESTORE paths and absence of DELETE
   paths. Do not modify authoritative historical workbooks.
2. **Behavior-inert assignment UI/validator seam:** add the narrow assignment
   dialog and pure proposal/completeness tests. It cannot commit authority.
3. **Remove new-match credentials:** restore baseline initial Network match
   startup/association while keeping protocol changes inactive until the
   successor RPC set is complete.
4. **Fresh candidate staging:** adapt `LobbyManager.host_load_save()` to keep
   same-live load unchanged and stage a structurally supported fresh candidate
   without installation.
5. **Explicit association and filtering:** implement host/client endpoint rows,
   complete mapping validation, derived existing-principal associations,
   admitted-principal closure, targeted filter, and staging ACK.
6. **Atomic publication:** add commit-time revalidation, one host publication,
   one client installation, installation ACK, admission open, and exact-once
   abort/duplicate behavior.
7. **Confirmed-loss reconnect:** adapt in-game handshake and snapshot seam to
   require host explicit assignment, preserve the incumbent side's admission,
   and avoid host reload/republication.
8. **Protocol-4 cutover:** remove all credential RPCs and activate only the
   successor schema; prove v3 mismatch rejection.
9. **Focused and integration evidence:** complete unit/integration matrix,
   including swapped mapping, hidden information, decision equivalence,
   same-live load, Hot-Seat, and replay.
10. **Real multi-process and manual acceptance:** adapt the existing harness,
    create the MATCH-003 manual acceptance record, update the user guide only
    after behavior passes, and run all exit gates.

Do not ship an intermediate build that advertises fresh resume while using
credential logic, automatic host/client side assignment, partial associations,
unfiltered staging, or open command admission.

## 14. Verification And Acceptance Strategy

### 14.1 Focused and integration matrix

| Obligation | Required evidence |
| --- | --- |
| Structural candidate eligibility | Valid v5 two-distinct-HUMAN Network binding passes; Hot-Seat shared HUMAN, HUMAN/AUTOMATED, AUTOMATED/AUTOMATED, malformed/missing mapping, wrong mode, bad cursor, and invalid save fail before assignment. |
| Explicit UX | Both rows begin unassigned; host row is not Player 0 by default; client row is not Player 1 by default; duplicate side disables staging; both host->P1/client->P0 and host->P0/client->P1 proposals work. |
| Complete/exclusive assignment | Missing endpoint/side, extra endpoint/field, duplicate endpoint/side/principal, stale endpoint, wrong phase, and competing association reject atomically. |
| Host self-assignment | Host local viewer/principal follows the explicit selected saved side and can submit only for that side after admission; host role grants no other saved side. |
| Pre-publication closure | Candidate load, proposal, association commit, filtered stage, and staging ACK emit no `EventBus.game_started`, change no live state/cursor, expose no board, and admit no player command. |
| Filtered staging | Remote receives only the filter for its assigned side; other-side owner payload/hidden facts are absent. Host staging UI exposes only public labels. Binding remains exact and non-secret. |
| Publication ordering | Association committed with admission closed; client stage ACK precedes host publication; host and client installation each emit the existing `EventBus.game_started` exactly once; all installation ACKs precede admission and the single gated `LobbyManager.game_starting` board release per endpoint. |
| Exact-once/failure | Duplicate/stale messages, disconnect at every phase, cancel, candidate mutation, client reject, and commit race leave the required pre/post-linearization outcomes, with no duplicate canonical installation event, gated board release, or command. |
| Authorization vs legality | Correct admitted association reaches existing legality; wrong/non-admitted association rejects before `CommandProcessor`; associated but illegal command reaches and fails existing gameplay validation. |
| Confirmed-loss reconnect | Incumbent competition rejects without eviction; confirmed disconnect removes only lost association/admission; a new/different endpoint is explicitly assigned, receives one filtered current snapshot, installs/ACKs, and regains only that side. Host state/cursor and incumbent admission never reload. |
| Same-live Network load | Exact live binding and associations load earlier state unchanged; different binding, missing association, or fresh staging accidentally routed through the same-live gate rejects. No assignment reshuffle. |
| Decision-equivalent recovery | At least one mandatory decision, one optional decision, and one accepted stable state recover the same actor, optionality, legal choices/source, commit/decline/completion semantics, cursor, and public canonical hash as direct reconstruction. Zero synthetic command. |
| Save/load compatibility | Named save and checkpoint remain v5 and byte/semantic compatible; no credential/assignment field; original-install trust boundary unchanged; no portability claim. |
| Hot-Seat/replay | Hot-Seat named/checkpoint load and one-HUMAN/two-player control unchanged; replay format 7 and Network replay harness produce no resume assignment or live-human inference. |
| Protocol | Protocol 4 peers exchange only successor messages; protocol 3/4 mismatch rejects during handshake; no credential-era RPC or payload remains. |
| Malformed protocol/RPC | Wrong sender or role, wrong field types, missing required fields, unexpected fields, invalid endpoint/player indices, unknown operation/message type, and stale attempt IDs fail closed as applicable. None changes association, publication, installation, admission, canonical state, or cursor. |

### 14.2 Real multi-process acceptance

`./scripts/run_network_resume_acceptance.sh` remains mandatory but must be
adapted before execution. It SHALL launch separate Godot OS processes through
production ENet RPCs, with distinct process memory and isolated `user://`
roots. It must use bounded timeouts, terminate all child processes, retain
machine-readable failure evidence, and contain no capability-transfer or
secret-redaction workflow because MATCH-003 creates no such secret.

Required scenarios:

**A. Fresh resume with swapped transport roles**

1. Create/save a normal two-human Network match and terminate the session.
2. Reuse the original save-owning host root, connect one client, and load the
   save into staging.
3. Explicitly assign host -> saved Player 1 and client -> saved Player 0.
4. Prove zero early board/event/command, correct targeted filter, exact binding
   and cursor, one host publication, one client install, and admission only
   after ACK.
5. Submit one legal command from each assigned side when its gameplay turn
   permits, proving host/client role is not gameplay-side authority.

**B. Opposite explicit mapping and failure vectors**

Repeat with host -> Player 0/client -> Player 1. Exercise incomplete,
duplicate, stale, repeated, and disconnect-before-publication proposals. Each
fails with no partial state, hidden information, association, or command.

**C. Competing incumbent and confirmed-loss reconnect**

Keep the resumed match live. Connect a new endpoint before incumbent loss and
prove assignment rejects without eviction or snapshot. Confirm the incumbent
disconnect, explicitly assign a clean endpoint with different profile/name/
peer history to the now-unoccupied side, install one filtered current snapshot,
and reopen only that side after ACK. Prove host canonical state/cursor and the
other side's admission never reload or republish.

**D. Compatibility**

Run an exact-binding same-live Network named/checkpoint load, Hot-Seat
named/checkpoint load, and Network replay. Assert save v5, replay v7, unchanged
bindings, no assignment traffic on Hot-Seat/replay, and protocol-4 negotiation
only for live Network peers.

### 14.3 Manual acceptance

Use two real GUI processes/builds:

1. Save a Network match at a visible decision, close both applications, create
   a fresh lobby on the save-owning installation, connect the other human, and
   select the save. Confirm the board remains absent while staged.
2. Confirm both endpoint rows start unassigned. Assign the host to the side the
   client previously controlled and the client to the other saved side. Verify
   duplicate/incomplete choices cannot be staged.
3. Publish and compare round, phase, pieces, public state, assigned perspective,
   side-hidden information, current actor, legal controls, and next decision on
   both processes. Confirm no duplicate modal/action or synthetic progression.
4. Repeat with the opposite explicit mapping.
5. During a live decision, connect a third process while the incumbent remains
   associated. Confirm no takeover, eviction, or snapshot. Disconnect the
   incumbent, wait for confirmed loss, explicitly assign the new process, and
   confirm the exact pending decision returns once before input reopens.
6. Load an earlier save from the same still-live Network match and confirm no
   reassignment. Load a Hot-Seat save and run a replay through their supported
   paths; confirm they remain unchanged.
7. Confirm the UI contains no Resume Capabilities, Import/Export Capability,
   entitlement, credential, verifier, proof, transfer, or recovery material.

Record tester, date, exact commit/build, mapping choices, screenshots of the
pre-publication assignment and restored decision, process logs, protocol
version, state/cursor comparison, and failures in the new MATCH-003 manual
acceptance record.

### 14.4 Execution gates

Implementation acceptance requires:

1. all focused unit and integration evidence in Section 14.1;
2. the process-isolated Section 14.2 scenarios through production protocol-4
   ENet paths;
3. existing save/load, checkpoint, Network command, state-filter,
   reconnection-recovery, replay, current-attack, timing-window, activation,
   and shared-protocol suites;
4. `./scripts/run_tests.sh`;
5. `./scripts/run_baseline_traces.sh --all`, with no fixture promotion unless
   an independently reviewed canonical change is found (none is expected);
6. `./scripts/lint_phase_k.sh` and `./scripts/quality_check.sh`;
7. targeted structural searches proving no MATCH-002 credential-era store,
   path, RPC, UI control/status, persistence field, protocol payload, test
   fixture, log label, or active acceptance artifact remains, including the
   capability/RSA/verifier-registry/challenge/proof/transfer surfaces named in
   Sections 12.2-12.4. Record the search patterns and any qualified allowlist;
   unrelated accepted uses of generic words such as `verifier`, `proof`, or
   `entitlement` are not removal targets merely because the words match;
8. structural searches proving host/client role, lobby/player slot, arrival,
   ready order, peer/profile/client ID, display name, UI state, and prior
   endpoint are never used to derive resumed side authority;
9. structural searches proving `GameState` and binding have no new rebind/kind/
   principal mutation, and no production diff exists in `GameManager`,
   `StateFilter`, save/replay schemas, or gameplay owners;
10. path-by-path comparison with the Section 3 baseline and Section 12
    treatment, including preservation of the current authority docs;
11. link/reference review, `git diff --check`, scoped diff review, and final
    worktree status; and
12. successful Section 14.3 manual acceptance.

## 15. Implementation Stop Gates

Stop and request Project Owner direction rather than improvise if any
discovery requires:

- canonical player, principal, kind, or player-to-principal rebinding;
- a new persistent human identity, entitlement, account, credential,
  capability, verifier, registry, secret, proof, or transfer mechanism;
- cross-host, cross-installation, cross-device, cloud, copied-save, or other
  save portability or save-integrity redesign;
- automatic host -> Player 0, client -> Player 1, slot/arrival/name/profile/
  peer inference, or any other non-explicit assignment fallback;
- active-controller eviction, timeout takeover, shared control, absent-player
  progression, spectator behavior, or more than the current two participating
  humans;
- a generic controller, participant, identity, lobby, session, bot, or
  reconnect framework;
- bot execution/substitution, principal-kind mutation, or new AUTOMATED
  behavior;
- a new canonical gameplay owner, changes to accepted gameplay ownership,
  synthetic recovery commands, or presentation-originated progression;
- production changes to `GameManager`, `StateFilter`, `UIProjector`,
  `GameState`, binding, save/replay schema, command schema, or accepted
  gameplay owners beyond a separately accepted refinement;
- weakening same-live-load exact-binding/current-association behavior,
  Hot-Seat semantics, replay provenance, or existing legality validation;
- hidden-state distribution before a complete assignment or distribution of
  more than the assigned endpoint's filtered view;
- publication with an incomplete association/install-ACK set or command
  admission before the required gates; or
- any production/test/document scope materially broader than Section 11 and
  the narrow successor architecture.

No stop gate is triggered by the evidence available at Draft time. Save
portability remains explicitly unresolved, excluded, and unsupported.

## 16. Exit Gate

MATCH-003 implementation is complete only when:

1. the Section 12 transition is mechanically accounted for from the exact
   baseline, with no superseded credential artifact or unexplained dirty path;
2. a valid fresh v5 Network candidate remains non-live until the host
   explicitly assigns both endpoints, including itself, one-to-one to the two
   saved HUMAN-controlled sides;
3. assignments derive existing principals through the immutable saved binding
   without automatic role/slot inference or canonical mutation;
4. associations commit with admission closed, the remote receives only its
   filtered view, all staging/installation acknowledgements succeed, host and
   client publish/install exactly once, and admission opens afterward;
5. confirmed-loss reconnect explicitly assigns only an unoccupied side,
   preserves incumbent association/admission, reloads no host state, and
   restores the filtered current decision before reopening that side;
6. same-live Network load, save v5/checkpoints, decision-equivalent recovery,
   Hot-Seat, replay v7, filtering, command provenance, and gameplay legality
   remain unchanged;
7. protocol 4 contains no credential-era RPC/payload and mixed v3/v4 peers
   reject cleanly;
8. focused, integration, real multi-process, full-suite, baseline, lint,
   structural, diff, and manual gates all pass;
9. `docs/setup_network_game.md` describes the accepted implemented UX, the new
   MATCH-003 manual acceptance record contains the evidence, and historical
   MATCH-002 documents remain unchanged; and
10. no Section 15 stop gate is triggered.

No additional Owner decision is required for this narrow plan after workbook
acceptance. Acceptance of this workbook does not decide save portability,
generic session/controller architecture, active takeover, absent players,
shared control, spectators, or bots.
