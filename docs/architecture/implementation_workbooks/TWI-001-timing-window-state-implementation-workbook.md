# TWI-001: Timing Window State Implementation Workbook

Status: Accepted
Accepted by: Project Owner
Accepted date: 2026-07-14

Purpose: Implementation Workbook
Slice: Slice 1 -- Authoritative TimingWindowState
Authority:
- ADR-005
- CON-005
- TEST-003

This workbook prepares one narrow implementation slice. It is not an ADR, a
Contract, a TEST document, or implementation authorization.

## 1. Purpose

TWI-001 translates the accepted timing-window architecture into a
repository-grounded plan for adding the minimum `GameState`-owned
`TimingWindowState` lifecycle state required by CON-005.

This workbook answers:

- what minimum semantic lifecycle state must be added now;
- where that state belongs;
- which existing surfaces must change or remain unchanged;
- how serialization and reconstruction must behave;
- how lifecycle identity is represented semantically without fixing final field
  names;
- which tests prove Slice 1;
- which work is deferred to later timing-window slices;
- how the repository remains safe before the orchestrator exists.

## 2. Status And Authority

Status: Draft.

Authority:

- ADR-005 decides timing-window ownership and continuation.
- CON-005 defines mandatory implementation obligations.
- TEST-003 defines verification obligations.
- MA-TW-001 organizes implementation sequencing and identifies Slice 1 as the
  first shared implementation slice.
- TWI-001 derives Slice 1 planning from ADR-005, CON-005, TEST-003, and the
  MA-TW-001 sequencing evidence.

Relevant accepted obligations:

- `GameState` owns authoritative timing-window lifecycle state.
- `TimingWindowState` represents lifecycle state only.
- `TimingWindowState` must not store opportunities, participant lists,
  projection state, UI state, RuleRegistry data, or rule-specific mutable state.
- Serialized lifecycle identity must be sufficient to distinguish reopened
  same-type windows from stale commands.
- Save/load, replay initialization, network mirror application, and reconnect
  reconstruction must preserve or reconstruct lifecycle identity.
- Existing repository compatibility/versioning mechanisms must be used before
  introducing any timing-window-specific version authority.

## 3. Slice Boundary

Slice 1 covers only:

- adding authoritative `TimingWindowState` ownership to `GameState`;
- minimum lifecycle semantics;
- lifecycle identity sufficient for future stale-window rejection;
- JSON-safe serialization and deserialization;
- compatibility with older serialized states that do not contain
  `TimingWindowState`;
- save/load reconstruction;
- replay initialization default behavior;
- reconnect/state snapshot reconstruction;
- safe inactive/default state;
- focused tests for those obligations.

Slice 1 does not cover:

- static timing-window definitions;
- Timing Window Orchestrator implementation;
- RuleRegistry participant indexing;
- opportunity derivation;
- command lifecycle validation;
- continuation;
- projection migration;
- H9 implementation;
- Tarkin migration;
- ECM migration;
- CAP updates.

## 4. Accepted Constraints

Accepted constraints from ADR-005 and CON-005:

- `TimingWindowState` is owned by `GameState`.
- Version 1 supports at most one active timing window.
- `TimingWindowState` owns lifecycle only.
- Rule-specific state remains on its accepted owner, including runtime upgrade
  `rule_state` under ADR-004 and CON-004.
- `InteractionFlow`, `FlowSpec`, `RuleSurface`, `UIProjector`, modal routers,
  scene controllers, and UI remain non-authoritative.
- Opportunities are derived later and must not be serialized as a mutable queue.
- Continuation command objects and payloads are not serialized in
  `TimingWindowState`.
- Missing older serialized timing-window state may be reconstructed
  deterministically.
- Present but unsupported or internally inconsistent serialized timing-window
  state must fail closed by making `GameState.deserialize()` return `null`
  while preserving authoritative rule-specific state.

## 5. Repository Evidence

Documents inspected:

- `AGENTS.md`
- `ARCHITECTURE.md`
- `docs/development/AI_DEVELOPMENT_PRINCIPLES.md`
- `docs/development/AI_DEVELOPMENT_PROCESS.md`
- `.ai/instructions/AI_STARTUP_GUARDRAILS.md`
- `docs/architecture/DOCUMENT_AUTHORITY.md`
- `docs/architecture/ARCHITECTURE_ROADMAP.md`
- `docs/architecture/CODEX_WORKFLOW.md`
- `docs/architecture/decision_workbooks/TIM-001-timing-window-ownership-and-continuation-workbook.md`
- `docs/architecture/decision_workbooks/TIM-002-timing-window-implementation-obligations-workbook.md`
- `docs/architecture/decision_workbooks/TIM-002-owner-decisions.md`
- `docs/architecture/adr/ADR-003-rule-and-validation-surfaces.md`
- `docs/architecture/adr/ADR-004-upgrade-runtime-ownership.md`
- `docs/architecture/adr/ADR-005-timing-window-ownership-and-continuation.md`
- `docs/architecture/contracts/CON-003-rule-capability-contract.md`
- `docs/architecture/contracts/CON-004-upgrade-runtime-contract.md`
- `docs/architecture/contracts/CON-005-timing-window-implementation-contract.md`
- `docs/architecture/tests/TEST-003-interactive-rule-timing-window-verification.md`
- `docs/architecture/migration_assessments/MA-ECM-001-con-005-compliance.md`
- `docs/architecture/migration_assessments/MA-TARKIN-001-con-005-compliance.md`
- `docs/architecture/migration_assessments/MA-H9-001-con-005-compliance.md`
- `docs/architecture/migration_assessments/MA-TW-001-cross-consumer-synthesis.md`
- `docs/architecture/rule_capability_packages/CAP-ECM-001-electronic-countermeasures.md`
- `docs/architecture/rule_capability_packages/CAP-UPG-001-grand-moff-tarkin-command-token-grant.md`
- `docs/architecture/rule_capability_packages/CAP-H9-001-h9-turbolasers.md`
- `docs/architecture/templates/RULE_CAPABILITY_PACKAGE_TEMPLATE.md`
- `.github/copilot-instructions.md`
- `.github/skills/rule-integration/SKILL.md`
- `.skills/testing_standards.md`
- `.skills/serialization_and_commands.md`
- `docs/game_flow.md`

Implementation evidence inspected:

- `src/core/state/game_state.gd`
- `src/core/state/interaction_flow.gd`
- `src/core/state/save_game_metadata.gd`
- `src/autoload/save_game_manager.gd`
- `src/autoload/baseline_trace.gd`
- `scripts/run_baseline_traces.sh`
- `src/core/network/state_filter.gd`
- `src/core/commands/game_replay.gd`
- `src/autoload/replay_driver.gd`
- `src/autoload/lobby_manager.gd`
- `src/autoload/network_manager.gd`
- `src/autoload/game_manager.gd`
- `src/autoload/command_processor.gd`
- `tests/unit/test_game_state.gd`
- `tests/unit/test_interaction_flow.gd`
- `tests/unit/test_save_game_manager.gd`
- `tests/unit/test_save_load_round_trip.gd`
- `tests/unit/test_game_replay.gd`
- `tests/unit/test_replay_driver.gd`
- `tests/unit/test_network_manager.gd`
- `tests/integration/test_reconnection_mid_attack.gd`
- `tests/fixtures/network_harness.gd`

Key evidence:

- `GameState` currently owns core mutable state, including
  `interaction_flow`, and serializes/deserializes it in
  `GameState.serialize()` / `GameState.deserialize()`.
- `InteractionFlow` serializes flow type, step, controller, visibility, and
  payload. Its file header currently calls it authoritative UI state, but
  ADR-005/CON-005 supersede that for timing-window lifecycle authority.
- `SaveGameMetadata.CURRENT_VERSION` is the repository's explicit save-format
  compatibility owner for breaking changes to the save header or
  `GameState.serialize()` / `GameState.deserialize()`.
- `SaveGameManager` stores saves as `{"header": SaveGameMetadata, "state":
  GameState.serialize()}` and rejects unsupported save header versions.
- `BaselineTrace.write_final_state_hash()` hashes
  `CanonicalJson.stringify(state.serialize())`; `GameState.serialize()` must
  not include timestamps, peer IDs, or per-process fields.
- `scripts/run_baseline_traces.sh` compares the hot-seat command trace and
  committed hot-seat final-state hash. The network gate compares host and
  client final-state hashes for equality within a run.
- `GameState.deserialize()` uses default reconstruction for missing fields such
  as missing `interaction_flow`.
- `StateFilter.filter_for_player()` filters serialized `GameState` snapshots
  for reconnect and currently filters `interaction_flow` payload visibility.
- `GameReplay.FORMAT_VERSION` owns replay-file compatibility. `GameReplay`
  serializes replay headers and command history, not a full `GameState` body.
- `ReplayDriver` reconstructs game state through normal game bootstrap and
  command replay; without later timing-window replay support, Slice 1 should
  initialize inactive timing-window state.
- `LobbyManager._receive_loaded_state()` reconstructs host-loaded state on
  clients through `GameState.deserialize(state_dict)`.
- Network command result mirroring uses command serialization and local
  `CommandProcessor.submit_mirror()`, not state snapshots for every command.
- Existing tests cover `GameState` serialization, `InteractionFlow`
  serialization, save/load version rejection, save/load round trips,
  reconnect projection through `GameState.serialize() ->
  StateFilter.filter_for_player() -> GameState.deserialize()`, replay file
  serialization, and replay driver startup behavior.

## 6. Current State

Current implementation state:

- There is no `TimingWindowState` class, value object, dictionary, or field.
- There is no serialized timing-window lifecycle identity.
- `GameState` serializes `interaction_flow`, but that field is a presentation
  and legacy interaction surface, not the accepted timing-window lifecycle
  owner under ADR-005.
- Save/load compatibility is handled at the save-file header level by
  `SaveGameMetadata.CURRENT_VERSION`.
- The `GameState` body has no independent schema version field.
- Baseline final-state hashes are derived from canonical `GameState.serialize()`
  output, so adding a serialized field can create deterministic fixture drift
  even when command history is unchanged.
- Missing `GameState` fields are typically reconstructed with safe defaults in
  `GameState.deserialize()`.
- Reconnect state snapshots preserve public top-level fields unless
  `StateFilter` explicitly removes or filters them.
- Replay files contain command history and a replay header, not full
  `GameState` lifecycle snapshots.

## 7. Problem Statement

CON-005 requires `GameState` to own authoritative timing-window lifecycle
state, but the repository currently has no such state. The closest existing
surface is `InteractionFlow`, which is serialized and used for UI projection,
save/load, and reconnect. Treating `InteractionFlow` as the lifecycle owner
would conflict with ADR-005 and would preserve the legacy authority problem
identified by the ECM, Tarkin, and H9 migration assessments.

Slice 1 must introduce the durable lifecycle owner without migrating legacy
flows or implementing later timing-window responsibilities early.

## 8. Required Semantic State

Slice 1 must provide semantic capacity for:

- active versus inactive lifecycle state;
- timing-window identity when active;
- lifecycle stage or timing point when active;
- authoritative lifecycle identity sufficient to distinguish a closed,
  cancelled, replaced, or reopened same-type timing window;
- current controller or controlling context when not uniquely derivable later;
- continuation context sufficient for later orchestrator reconstruction;
- JSON-safe serialization;
- deterministic inactive/default reconstruction.

Slice 1 must explicitly exclude:

- derived opportunities;
- participant lists;
- RuleRegistry data;
- projection, UI, modal, scene, or payload state;
- cached legality;
- visibility results;
- continuation command instances;
- continuation payload objects;
- rule-specific mutable state;
- card state;
- use or decline guards;
- dice, token, or effect results;
- static timing-window definition data.

This workbook does not require exact field names. It requires only the semantic
capacity needed by CON-005.

## 9. Candidate Implementation Shapes

### Option A: Dedicated TimingWindowState value/state class owned by GameState

Description:

- Add a dedicated JSON-safe `TimingWindowState` type.
- `GameState` owns one instance and serializes it as a top-level
  `GameState` field.
- The type owns default inactive construction, validation,
  serialization/deserialization, and equality helpers for tests.

ADR-005 compliance:

- Strong. It creates a distinct lifecycle owner and avoids using derived
  presentation surfaces as authority.

CON-005 compliance:

- Strong. It can encode lifecycle-only semantics and reject unsupported present
  state without absorbing opportunities or rule-specific state.

Serialization safety:

- Strong if the type uses only plain dictionaries, arrays, strings, numbers,
  booleans, and null-equivalent defaults.

Reconstruction safety:

- Strong. Missing older state can reconstruct to inactive. Present invalid
  state can fail closed in one narrow deserialization point.

Codex implementation clarity:

- Strong. The boundary is visible and testable.

Future orchestrator integration:

- Strong. Later slices can depend on a typed lifecycle surface instead of a
  loose dictionary or `InteractionFlow` payload.

Risk of authority leakage:

- Low if the type rejects opportunities, projection payloads, and rule-specific
  fields.

Implementation complexity:

- Low-to-medium. It adds a small new state type and GameState wiring.

### Option B: Plain JSON-safe dictionary embedded directly in GameState

Description:

- Add a top-level `timing_window_state` dictionary to `GameState`.
- Implement defaults and validation inside `GameState.serialize()` /
  `deserialize()`.

ADR-005 compliance:

- Moderate. Ownership is in `GameState`, but the lifecycle boundary is less
  explicit.

CON-005 compliance:

- Possible, but easier to erode because any caller can place arbitrary keys in
  the dictionary.

Serialization safety:

- Strong by default, because the shape is plain JSON data.

Reconstruction safety:

- Moderate. Validation must be hand-maintained in `GameState`.

Codex implementation clarity:

- Moderate. It is simple initially but risks spreading ad hoc key checks.

Future orchestrator integration:

- Moderate. Later code would either continue ad hoc dictionary access or need
  a value type later.

Risk of authority leakage:

- Medium. A dictionary can silently accumulate opportunities, payloads, or
  rule-specific state.

Implementation complexity:

- Low initially, higher over time.

### Option C: Extend InteractionFlow to carry authoritative lifecycle state

Description:

- Add timing-window lifecycle fields to `InteractionFlow`.

ADR-005 compliance:

- Poor. ADR-005 explicitly keeps `InteractionFlow` non-authoritative for
  timing-window lifecycle.

CON-005 compliance:

- Poor. This would merge lifecycle authority with projection/interaction state.

Serialization safety:

- Existing `InteractionFlow` serialization is JSON-safe, but the authority
  boundary would be wrong.

Reconstruction safety:

- Weak. Existing reconnect tests treat `InteractionFlow` as projection input,
  not as lifecycle authority.

Codex implementation clarity:

- Poor. It would preserve the legacy ambiguity identified in the migration
  assessments.

Future orchestrator integration:

- Poor. Later slices would have to unwind this choice.

Risk of authority leakage:

- High. Payload and modal state could become authoritative by accident.

Implementation complexity:

- Low short-term, high architectural cost.

## 10. Recommended Direction

Recommend Option A: a dedicated `TimingWindowState` value/state class owned by
`GameState`.

Reasons:

- It creates the distinct authoritative lifecycle owner required by ADR-005.
- It prevents `InteractionFlow` from becoming the timing-window authority.
- It does not introduce a new architecture layer; it is a small state value
  under `GameState`.
- It supports later orchestrator work cleanly.
- It gives Codex one deterministic location for lifecycle serialization,
  default reconstruction, validation, and tests.
- It reduces the risk that opportunities, projection payloads, or rule-specific
  state leak into lifecycle state.

Recommended Version 1 behavior:

- Missing serialized `timing_window_state` reconstructs to inactive.
- Fresh `GameState.initialize()` creates inactive timing-window state.
- Present inactive serialized timing-window state round-trips.
- Present active serialized timing-window state may round-trip only if it
  satisfies the minimal Slice 1 semantic shape.
- Present structurally invalid timing-window state fails closed by making
  `GameState.deserialize()` return `null`. `SaveGameManager.load_game()` then
  surfaces the existing `schema_invalid` result.
- Present semantically unsupported timing-window state follows the same
  deterministic fail-closed path: `GameState.deserialize()` returns `null`, and
  `SaveGameManager.load_game()` surfaces `schema_invalid`.
- Slice 1 should not bump `SaveGameMetadata.CURRENT_VERSION` if the new field
  is backward-compatible and older saves reconstruct deterministically.
- A future incompatible timing-window serialization change must use the
  repository compatibility owner or be escalated if that owner is insufficient.

Baseline replay/hash obligation:

- Slice 1 is not required to preserve existing final-state hashes.
- Because the baseline hash is canonical `GameState.serialize()` output, adding
  serialized inactive `TimingWindowState` is expected to change the hot-seat
  final-state hash deterministically.
- The implementation must run `scripts/run_baseline_traces.sh`; if the command
  trace remains unchanged and the only drift is the additive serialized
  timing-window state, the hot-seat final-state hash fixture must be
  intentionally updated as part of the Slice 1 implementation review.
- Network baseline verification must continue to pass by host/client
  final-state hash equality. Host and client must serialize identical
  timing-window state.

Replay format obligation:

- `GameReplay.FORMAT_VERSION` owns replay-file compatibility.
- Slice 1 changes `GameState` reconstruction and final-state serialization; it
  does not by itself require a replay-file format change.
- Do not introduce another replay compatibility mechanism for
  `TimingWindowState`.

## 11. Repository Change Surface

Must change in Slice 1:

- `src/core/state/game_state.gd`
  - Add `GameState` ownership of timing-window lifecycle state.
  - Initialize inactive state.
  - Serialize and deserialize the new state.
  - Preserve older serialized states by defaulting missing timing-window state
    to inactive.

- New timing-window state file, likely under `src/core/state/` or an existing
  nearby shared core-state location.
  - Provide the dedicated JSON-safe lifecycle value object.
  - Provide inactive construction, serialization, deserialization, validation,
    and test helpers as needed.

- Focused tests, likely extending:
  - `tests/unit/test_game_state.gd`
  - `tests/unit/test_save_load_round_trip.gd`
  - `tests/unit/test_save_game_manager.gd`
  - `tests/integration/test_reconnection_mid_attack.gd` or a focused
    reconnect/state-filter test

May change in Slice 1:

- `src/core/network/state_filter.gd`
  - Only if evidence shows top-level timing-window state needs explicit
    filtering or preservation. Default expectation: public lifecycle state
    passes through unchanged, while visibility remains projection-specific.

- `src/core/state/save_game_metadata.gd`
  - Only if implementation determines the new field is an incompatible
    `GameState.serialize()` / `deserialize()` change. Recommended Slice 1
    behavior is backward-compatible reconstruction, so no version bump should
    be needed.

- Replay-focused tests.
  - Only to prove replay initialization creates inactive timing-window state
    when no active lifecycle is serialized.

Must not change in Slice 1:

- `src/core/state/interaction_flow.gd`
  - Do not add authoritative timing-window lifecycle state here.

- `src/core/state/flow_spec.gd`
  - Static timing-window definitions are Slice 2.

- `src/core/effects/rule_registry.gd`
  - Participant indexing is a later slice.

- `src/autoload/command_processor.gd`
  - Command lifecycle validation and orchestrator integration are later slices.

- `src/autoload/game_manager.gd`
  - ECM/Tarkin continuation migration is later.

- `src/autoload/replay_driver.gd`
  - Replay protocol integration for active windows is later unless a focused
    inactive-state test needs no production change.

- `src/autoload/network_manager.gd`
  - Network timing-window command sequencing is later.

- `src/core/network/ui_projector.gd`
  - Projection migration is later.

- ECM, Tarkin, H9 production files.

- CAPs, ADRs, Contracts, TEST documents, migration assessments, and roadmap
  documents.

## 12. Serialization And Compatibility Obligations

Actual serialization/versioning owner found:

- `src/core/state/save_game_metadata.gd`
- Symbol: `SaveGameMetadata.CURRENT_VERSION`

Evidence:

- The comment on `CURRENT_VERSION` states it should be bumped on breaking
  changes to the header or to `GameState.serialize()` /
  `GameState.deserialize()`.
- `SaveGameManager.load_game()` rejects unsupported save header versions with
  `version_unsupported`.
- The serialized `GameState` body does not currently have a separate schema
  version field.

Slice 1 compatibility recommendation:

- Do not create a timing-window-specific version field.
- Do not create a timing-window-specific migration subsystem.
- Do not bump `SaveGameMetadata.CURRENT_VERSION` for the initial additive field
  if older saves can reconstruct missing timing-window state to inactive.
- Document and test the compatibility behavior:
  - missing field: reconstruct inactive;
  - valid inactive field: preserve inactive;
  - valid active field: preserve lifecycle semantics;
  - malformed present field: `GameState.deserialize()` returns `null`;
  - semantically unsupported present field: `GameState.deserialize()` returns
    `null`;
  - saves with either invalid present-field case surface `schema_invalid`
    through `SaveGameManager.load_game()`.

Accepted Decision 10 requires any incompatible serialized timing-window state
to choose exactly one behavior:

- migrate through the existing compatibility/versioning path;
- reconstruct deterministically;
- reject fail-closed.

For Slice 1:

- older states without timing-window state: reconstruct deterministically to
  inactive;
- structurally invalid present timing-window state: reject fail-closed by
  returning `null` from `GameState.deserialize()`;
- semantically unsupported present timing-window state: reject fail-closed by
  returning `null` from `GameState.deserialize()`;
- future incompatible semantic changes: use `SaveGameMetadata.CURRENT_VERSION`
  unless implementation evidence proves it insufficient and the owner accepts a
  different compatibility mechanism.

Replay compatibility:

- `GameReplay.FORMAT_VERSION` remains the replay-file compatibility owner.
- Slice 1 must not bump or reinterpret replay format unless the replay header
  or command-list schema changes.
- Replay baseline final-state hash drift is handled through the baseline trace
  fixture process, not through replay-file versioning.

## 13. Reconstruction Obligations

Fresh `GameState` creation:

- `GameState.initialize()` must create inactive timing-window state.

Loading an older save without `TimingWindowState`:

- Reconstruct inactive timing-window state.
- Do not infer active timing-window state from `InteractionFlow`.

Loading a save with inactive `TimingWindowState`:

- Preserve inactive state and JSON-safe defaults.

Loading a save with active `TimingWindowState`:

- Preserve lifecycle identity and semantic lifecycle facts if the serialized
  state is valid.
- Do not derive opportunities, participants, projection, or continuation in
  Slice 1.

Replay initialization:

- Replay bootstrap must start with inactive timing-window state unless a later
  replay architecture explicitly supplies active lifecycle state.
- Command replay must not infer timing-window state from legacy
  `InteractionFlow` in Slice 1.

Reconnect/state snapshot reconstruction:

- Serialized timing-window state must survive
  `GameState.serialize() -> StateFilter.filter_for_player() ->
  GameState.deserialize()`.
- Slice 1 should not add visibility filtering for lifecycle state unless a
  concrete hidden-information requirement is found.

Invalid or unsupported serialized timing-window state:

- `GameState.deserialize()` returns `null`.
- `SaveGameManager.load_game()` surfaces `schema_invalid` for saves.
- Preserve rule-specific authoritative state.
- Do not synthesize continuation.
- Do not mutate `InteractionFlow`.

Authoritative state outside a valid timing window:

- Timing-window state remains inactive.
- Legacy flows continue to behave as legacy flows until later migration slices.

## 14. Safe Intermediate-State Rules

Slice 1 will exist before static definitions, orchestrator, participant
discovery, opportunity derivation, and command lifecycle validation. The
repository remains safe only if the following rules hold:

- `TimingWindowState` defaults to inactive.
- No current legacy flow automatically becomes authoritative timing-window
  state.
- `InteractionFlow` remains the current derived/legacy interaction surface.
- No implementation claims CON-005 compliance merely because
  `TimingWindowState` exists.
- No command begins validating lifecycle identity until the relevant later
  slice wires that protocol.
- No dual authoritative lifecycle systems are introduced.
- No legacy Tarkin or ECM behavior is migrated in Slice 1.
- No H9 behavior is implemented in Slice 1.
- No static timing-window definition table is added in Slice 1.
- No opportunities, participant lists, or RuleRegistry data are stored in the
  new state.
- No projection or modal route reads the new state for gameplay authority in
  Slice 1.
- Save/load and reconnect can carry the inactive or explicitly test-created
  state, but do not use it to progress gameplay.

## 15. Verification Plan

Focused tests for Slice 1:

- Default inactive state:
  - new `TimingWindowState` is inactive;
  - `GameState.initialize()` creates inactive timing-window state.

- Serialization/deserialization round trip:
  - inactive state round-trips through `GameState.serialize()` /
    `GameState.deserialize()`;
  - test-created active lifecycle semantics round-trip without opportunities or
    rule-specific state.

- JSON safety:
  - serialized timing-window state contains only JSON-safe primitive/container
    types.

- Missing-field backward-compatible reconstruction:
  - remove the timing-window field from serialized `GameState`;
  - deserialize;
  - assert inactive state.

- Invalid serialized state behavior:
  - malformed present field makes `GameState.deserialize()` return `null`;
  - semantically unsupported present field makes `GameState.deserialize()`
    return `null`;
  - `SaveGameManager.load_game()` surfaces `schema_invalid` for both cases;
  - no continuation or projection mutation is synthesized.

- Lifecycle identity preservation:
  - lifecycle identity survives `serialize()` / `deserialize()`;
  - reopened same-type identity can be represented semantically, even though
    command stale-window validation is deferred.

- GameState copy/clone behavior:
  - where the repository duplicates serialized GameState dictionaries, the
    timing-window state must not alias mutable nested dictionaries.

- Save/load round trip:
  - `SaveGameManager.save_game()` / `load_game()` preserves the state.

- Replay initialization:
  - replay bootstrap or replay test fixture creates inactive timing-window
    state when no active lifecycle is serialized.

- Baseline replay/final-state hash:
  - `scripts/run_baseline_traces.sh` passes;
  - hot-seat command trace remains unchanged unless command history actually
    changes;
  - hot-seat final-state hash is intentionally updated if the only difference
    is deterministic additive serialized `TimingWindowState`;
  - network host/client final-state hashes remain equal.

- Replay format:
  - `GameReplay.FORMAT_VERSION` remains unchanged unless replay header or
    command schema changes.

- Reconnect/snapshot reconstruction:
  - `GameState.serialize() -> StateFilter.filter_for_player() ->
    GameState.deserialize()` preserves timing-window lifecycle state.

- InteractionFlow remains non-authoritative:
  - deserializing legacy `interaction_flow` without timing-window state does
    not create active timing-window state.

- Rule-specific runtime state remains unaffected:
  - runtime upgrade `rule_state` still round-trips independently and is not
    copied into timing-window state.

Mapping to CON-005 and TEST-003:

- CON-005-STATE-001 through STATE-012: ownership, lifecycle semantics,
  lifecycle identity, inactive default, invalid-state behavior.
- CON-005-SER obligations: JSON-safe serialization and compatibility behavior.
- CON-005-SAVE obligations: save/load reconstruction.
- CON-005-RECON obligations: reconnect reconstruction.
- TEST-003 lifecycle and serialization categories only. Full protocol,
  opportunity, projection, continuation, network command, and capability
  behavior categories are later-slice obligations.

## 16. Acceptance Criteria

Slice 1 is complete only when:

- `GameState` owns serialized `TimingWindowState`.
- Lifecycle identity semantics are represented.
- Serialization is JSON-safe.
- Old serialized state without timing-window data reconstructs
  deterministically to inactive.
- Structurally invalid present timing-window state makes
  `GameState.deserialize()` return `null`.
- Semantically unsupported present timing-window state makes
  `GameState.deserialize()` return `null`.
- Saves containing invalid present timing-window state surface
  `schema_invalid`.
- `InteractionFlow` remains non-authoritative for timing-window lifecycle.
- No opportunities are stored.
- No participant lists are stored.
- No RuleRegistry data is stored.
- No projection/UI/modal payload is stored.
- No rule-specific mutable state is stored.
- Save/load round trip tests pass.
- Replay initialization default tests pass.
- Baseline trace/hash verification passes with either preserved hashes or an
  intentionally reviewed hot-seat final-state hash update.
- Reconnect/snapshot reconstruction tests pass.
- Rule-specific runtime state tests remain unaffected.
- No later-slice behavior was introduced.
- No architecture decision was reopened.

## 17. Explicit Deferrals

Deferred to later slices:

- static definition table;
- Timing Window Orchestrator;
- participant discovery;
- canonical opportunities;
- command lifecycle validation;
- continuation;
- projection migration;
- shared protocol suites beyond state/reconstruction;
- H9;
- Tarkin;
- ECM;
- CAP updates.

## 18. Risks And Failure Modes

Implementation risks:

- A plain dictionary implementation may accumulate rule-specific state or
  projection payloads over time.
- Extending `InteractionFlow` would preserve the known legacy authority problem.
- Adding lifecycle state without safe defaults could break older saves.
- Adding a timing-window-specific version field would create a competing
  compatibility authority without evidence.
- Filtering lifecycle state as if it were UI payload could break reconnect.
- Inferring active timing-window state from legacy `InteractionFlow` would
  create dual lifecycle authority.
- Early command validation against inactive placeholder state would break ECM,
  Tarkin, and current attack flows before their migrations.

Failure modes Slice 1 must avoid:

- old saves fail solely because the new field is absent;
- malformed present state silently becomes active;
- semantically unsupported present state silently becomes inactive;
- active lifecycle identity is lost during serialization;
- deterministic baseline hash drift is missed or treated as accidental;
- projection payload becomes authoritative;
- rule-specific runtime upgrade state is moved or copied into
  `TimingWindowState`;
- command or continuation behavior changes before later slices.

## 19. Open Implementation Questions

Repository evidence questions:

- Should reconnect filtering explicitly preserve the timing-window state, or is
  the existing top-level pass-through behavior sufficient once tests prove it?
- Which test file should own focused replay initialization coverage: existing
  replay driver tests or a new state-focused test?

Implementation details:

- Exact file path and class name for the state value object.
- Exact serialized key name.
- Exact internal lifecycle identity representation.
- Exact inactive-state serialization shape.

Architecture decision required:

- None identified for Slice 1, provided implementation reuses
  `SaveGameMetadata.CURRENT_VERSION` as the save-state
  compatibility/versioning owner, keeps `GameReplay.FORMAT_VERSION` as the
  replay-file compatibility owner, reconstructs missing older timing-window
  state to inactive, and rejects structurally invalid or semantically
  unsupported present timing-window state by returning `null` from
  `GameState.deserialize()`.

Escalate before implementation only if a required save-state compatibility
change cannot be handled by the existing `SaveGameMetadata.CURRENT_VERSION`
mechanism, or if a required replay-file compatibility change would require
changing `GameReplay.FORMAT_VERSION`.

## 20. Implementation Readiness Assessment

Readiness: Ready for Architecture Audit.

Rationale:

- The accepted architecture and CON-005 define the Slice 1 obligation clearly.
- Repository evidence identifies the correct owner: `GameState`.
- Repository evidence identifies the compatibility/versioning owner:
  `SaveGameMetadata.CURRENT_VERSION`.
- Repository evidence identifies the replay-file compatibility owner:
  `GameReplay.FORMAT_VERSION`.
- The recommended shape is narrow and repository-consistent.
- Missing older state has a deterministic safe reconstruction behavior.
- Invalid or unsupported present state has one deterministic fail-closed path:
  `GameState.deserialize()` returns `null`.
- No architecture ambiguity was found.
- The workbook defers orchestrator, definitions, opportunities, command
  validation, projection, and capability migrations.

Implementation should not begin until this workbook has passed the requested
audit/acceptance step.
