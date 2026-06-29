# ADR-004: Upgrade Runtime Ownership

Status: Accepted
Accepted by: Project Owner
Accepted date: 2026-06-28

ADR-ID: ADR-004
Title: Upgrade Runtime Ownership

Supersedes:
None

Superseded by:
None

Related:
- ADR-003
- CON-003
- CP-001
- CAP-UPG-001
- UPG-001
- BC-005
- BC-005A
- BC-007
- BC-008
- BC-009
- BC-012
- AT-004
- AT-007
- AT-008
- AT-009
- AT-011

## 1. Context

The project is preparing to implement the first batch of behavior-changing
upgrade rules.

ADR-003 is accepted as the governing rule and validation surface decision.
CON-003 is accepted as the Rule Capability Contract. Together they establish
that behavior-changing component rules require explicit active state ownership,
validation ownership, execution ownership, projection impact, serialization,
replay, network/reconnect, visibility, and tests before integration can be
claimed.

CP-001 records the current upgrade evidence:

- Upgrade JSON is loaded as static catalog data through `UpgradeData` and
  `AssetLoader`.
- Upgrade assignments are represented in fleet roster/setup payloads through
  `FleetUpgradeAssignment`, `FleetShipEntry`, `FleetRoster`, and
  `FleetSetupPackage`.
- Fleet validation already consumes upgrade assignment data for roster legality.
- Setup currently uses assigned upgrades for fleet-point calculation.
- No generic active runtime upgrade-state collection was observed on
  `ShipInstance`.
- `ShipInstance` serializes mutable ship state, command dials, command tokens,
  damage, shields, activation, position, owner, roster id, and static ship
  identity.
- Durable component behavior must be serialized on runtime state, serialized on
  `GameState`, represented in command/history state, derived from deterministic
  static lookup, or some combination of these.

CAP-UPG-001 confirms that even a narrow Grand Moff Tarkin implementation cannot
proceed safely until active upgrade ownership is decided. UPG-001 records that
the first upgrade batch also includes exhaustible/readied upgrades, command
window effects, attack modifiers, critical effects, range/cross-ship effects,
and hidden-information-sensitive effects.

After review of the evidence, the Project Owner selected a refined
`ShipInstance` ownership direction for active runtime upgrade instances and
durable mutable upgrade state. This ADR records that ownership decision while
leaving identity, serialization shape, lookup, command references, replay,
network/reconnect, and Rule Capability Package reference rules to a narrow
follow-up contract.

This ADR candidate decides only:

- where active equipped upgrades are available at runtime,
- where exhausted/readied upgrade-card state lives,
- where per-phase and per-round trigger guards live if they are not derived
  from command history,
- how this ownership integrates with serialization, save/load, replay, network,
  and Rule Capability Packages at the ownership level.

This ADR does not decide the full upgrade framework.

## 2. Decision

Choose a refined `ShipInstance` ownership model:

- Active equipped upgrades become runtime upgrade instances after setup.
- Runtime upgrade instances live on the owning `ShipInstance` by default.
- Runtime upgrade instances reference static upgrade data by `data_key`.
- Full static upgrade data is not copied into runtime state.
- Mutable upgrade state lives on the runtime upgrade instance by default.
- Exhausted, discarded, disabled, readied, used-this-round, used-this-phase,
  and similar trigger guards live on the runtime upgrade instance by default.
- Per-phase and per-round trigger guards live on the runtime upgrade instance
  unless a Rule Capability Package proves command-history derivation is
  sufficient for that rule.
- Commander, fleet-wide, range/aura, and cross-ship effects still have a source
  runtime upgrade instance on `ShipInstance` by default.
- Exceptions require Rule Capability Package justification and must not become
  a full generic upgrade framework.

This corresponds to a refined version of Option A from the evaluated
alternatives.

The source runtime upgrade instance identifies that an equipped upgrade is
active for a ship and provides the default durable owner for mutable upgrade
state. Static rule text, points, restrictions, and other catalog data remain
looked up through the instance's `data_key`.

Mutable runtime upgrade state includes:

- exhausted, discarded, disabled, or readied upgrade-card state,
- per-phase or per-round trigger guards when not command-history-derived,
- used-this-round, used-this-phase, or similar durable guard state,
- other durable upgrade-owned counters, flags, or selected state required by a
  Rule Capability Package.

Runtime upgrade instances and their mutable state must be JSON-safe and
serialized as part of authoritative game state. They must be available to
save/load, replay initialization, network snapshots, and reconnect projection.

Commands, resolvers, `RuleRegistry`, `RuleSurface`, `InteractionFlow`,
`UIProjector`, `StateFilter`, and tests remain responsibility surfaces under
ADR-003 and CON-003. This ADR chooses the ownership of active runtime upgrade
instances and mutable upgrade state only.

A narrow follow-up contract, CON-004, is required before implementation begins.
CON-004 must define identity, serialization, lookup, command references, replay
reconstruction, network/reconnect reconstruction, and Rule Capability Package
reference rules for this ownership model.

## 3. Options Considered

### Option A: Store Runtime Upgrade Instances And Mutable State On ShipInstance

Under this option, each `ShipInstance` owns runtime instances for its equipped
upgrades and those instances own mutable upgrade state by default.

Evidence support:

- Upgrade effects usually attach to ships.
- `ShipInstance` already owns ship-local mutable state such as shields, damage,
  defense tokens, command dials, command tokens, activation state, and
  deployment state.
- `ShipInstance` already serializes ship-local mutable state.
- CP-001 records that durable component behavior can be serialized on runtime
  entity state.
- The Project Owner selected runtime upgrade instances on `ShipInstance` as the
  default ownership direction.
- A source `ShipInstance` runtime upgrade instance gives commander, fleet-wide,
  range/aura, and cross-ship effects an explicit source even when their effects
  affect other ships.

Evidence concerns:

- CP-001 observed no generic active runtime upgrade-state collection on
  `ShipInstance`.
- Some upgrade effects are fleet-level, commander-level, aura-based, or
  cross-ship, not purely ship-local.
- Commander effects such as Grand Moff Tarkin affect multiple friendly ships.
- Range/cross-ship effects such as Redemption and Leia Organa are not naturally
  resolved only by mutating the source ship.
- A follow-up contract must define identity, serialization, lookup, command
  references, save/load, replay, network, reconnect, and Rule Capability
  Package obligations before implementation.

### Option B: Store Active Assignments And Mutable State In PlayerState

Under this option, each `PlayerState` would own that player's active upgrade
assignments and mutable upgrade state.

Evidence support:

- Upgrade ownership is player-scoped through rosters and fleet setup.
- Commander and fleet-wide effects can affect multiple ships controlled by the
  same player.
- `PlayerState` serializes the player's ships and squadrons.

Evidence concerns:

- The observed `PlayerState` structure primarily serializes player ships and
  squadrons.
- CP-001 does not identify existing upgrade ownership state on `PlayerState`.
- Some upgrade effects need source-ship identity, target ship identity, or
  cross-player visibility/filtering that would still require additional
  indexing and authority rules.
- Putting all mutable upgrade state in `PlayerState` may obscure interactions
  that are globally relevant for save/load, replay, network snapshots, and
  reconnect.
- This option does not match the Project Owner's selected default ownership
  direction.

### Option C: Store Active Assignments And Mutable State In GameState-Level Upgrade Runtime State

Under this option, `GameState` owns both active upgrade assignments and all
mutable upgrade runtime state.

Evidence support:

- `GameState.serialize()` is the authoritative snapshot path for current phase,
  player states, objectives, damage deck, RNG, interaction flow, and other
  runtime facts.
- Network snapshots and reconnect already depend on serialized `GameState`.
- Cross-ship, commander, aura, phase, and global upgrade effects can be
  represented from one authoritative runtime surface.

Evidence concerns:

- Active assignments already exist in roster/setup payloads; copying all
  assignment facts into new `GameState` runtime state may duplicate source data.
- Duplication can create drift between setup/roster facts and runtime
  assignment facts.
- This option may be broader than necessary if each equipped upgrade can have a
  source runtime instance on its owning `ShipInstance`.
- This option does not match the Project Owner's selected default ownership
  direction.

### Option D: Derive Active Assignments From Setup/Roster State, Store Mutable State In Explicit Runtime State

Under this option, setup/roster state remains the source for active upgrade
assignment identity. Mutable upgrade state is stored separately in explicit
serialized runtime state.

Evidence support:

- Upgrade assignments already serialize through fleet roster/setup payloads.
- CP-001 records that upgrade assignments are roster/setup facts and not active
  runtime rule objects by themselves.
- CP-001 says durable behavior can be serialized runtime entity state,
  serialized `GameState` state, serialized command/history state, deterministic
  static lookup by `data_key`, or a combination.
- This option avoids copying static assignment facts when they can be derived.
- This option creates an explicit durable owner for mutable upgrade facts that
  cannot be derived.
- It supports ship-local, commander-level, aura, cross-ship, phase, and
  globally relevant upgrade effects without forcing all state onto one ship.

Evidence concerns:

- The repository does not yet contain the explicit upgrade runtime state
  surface.
- Deriving active assignments from setup/roster state alone does not create a
  runtime upgrade instance that can own mutable card state.
- Implementations must avoid treating setup/roster assignment facts as proof
  that behavior is active.
- This option does not match the Project Owner's selected materialized runtime
  instance direction.

### Option E: Another Evidence-Supported Option

No stronger evidence-supported ownership option was identified.

The current evidence supports entity-level state for source upgrade instances
and durable mutable upgrade facts, with explicit Rule Capability Package
justification for exceptions. It does not support a broader generic upgrade
framework in this ADR.

## 4. Evaluation

| Criterion | A: ShipInstance runtime instances | B: PlayerState | C: GameState owns all | D: Derive assignments, explicit runtime state |
| --- | --- | --- | --- | --- |
| Matches owner-selected direction | High | Low | Low | Low |
| Establishes active runtime upgrade instances | High | Medium | Medium | Low |
| Avoids copying full static upgrade data | High | Medium | Medium | High |
| Supports ship-local upgrades | High | Medium | High | High |
| Supports commander/fleet-wide source identity | High | Medium | High | Medium |
| Supports cross-ship/aura source identity | High | Medium | High | Medium |
| Supports exhaustible/readied upgrade cards | High | Medium | High | High |
| Supports phase trigger guards | High | Medium | High | High |
| Save/load clarity | Medium pending CON-004 | Medium | High | High |
| Replay/network/reconnect clarity | Medium pending CON-004 | Medium | High | High |
| Risk of state drift | Medium pending CON-004 | Medium | Medium-high | Low-medium |
| Scope control | High with RCP exception rule | Medium | Medium | High |
| Evidence support | High with owner decision | Medium | Medium-high | High |

Option A is now the selected direction because it gives every equipped upgrade a
source runtime instance on the owning ship, aligns mutable card state with the
ship entity that carries the upgrade, and still allows Rule Capability Package
justification for commander, fleet-wide, range/aura, and cross-ship exceptions.
It requires CON-004 before implementation because the repository does not yet
define runtime upgrade identity, serialization shape, lookup, command
references, replay reconstruction, or network/reconnect reconstruction.

Option B is attractive for player-owned fleets and commanders, but it is less
aligned with current observed `PlayerState` responsibilities and still requires
additional source/target indexing for ship-local and cross-ship behavior.

Option C is clear for serialization, network snapshots, and reconnect, but it
duplicates assignment facts that already exist in setup/roster state and is
broader than the owner-selected source-instance model.

Option D preserves useful separation between static setup facts and mutable
runtime facts, but it leaves active upgrade behavior too dependent on derived
assignment lookup and does not provide the owner-selected materialized runtime
instance on `ShipInstance`.

## 5. Chosen Option

Chosen option: refined Option A.

Active equipped upgrades are materialized into runtime upgrade instances on the
owning `ShipInstance` after setup. Mutable upgrade runtime state is stored on
the runtime upgrade instance by default. Static upgrade data is referenced by
`data_key`; full static data is not copied into runtime state.

This ADR intentionally names the ownership level, not a concrete class name,
field schema, or implementation API. Those details belong in CON-004 and
implementation work.

The proposed ownership principle is:

- setup/roster assignment state answers "which upgrade is equipped where",
- runtime upgrade instances answer "which equipped upgrades are active at
  runtime",
- the runtime upgrade instance's `data_key` answers "which static upgrade data
  defines this upgrade",
- runtime upgrade instance mutable state answers "what durable gameplay state
  does this equipped upgrade currently have",
- command history answers "which replayable choices or effects happened",
- Rule Capability Packages answer "which surfaces prove this rule is complete
  and whether any exception to default ownership is justified".

## 6. Consequences

Positive consequences:

- Active upgrade behavior has a concrete default runtime owner.
- Mutable upgrade state has a default durable owner colocated with the equipped
  upgrade's source ship.
- Exhausted, discarded, disabled, readied, used-this-round, used-this-phase,
  and similar trigger guards have a clear default place to live.
- Static upgrade data remains catalog-owned and is referenced by `data_key`
  instead of copied into runtime state.
- Commander, fleet-wide, range/aura, and cross-ship effects retain a source
  runtime upgrade instance even when their effects reach beyond the source
  ship.
- Rule Capability Packages can reference one accepted default ownership
  decision and must justify exceptions.
- The decision supports source-ship-local, commander, aura, cross-ship,
  status-phase, and phase-window upgrade behavior without requiring a full
  generic upgrade framework.

Negative consequences:

- A follow-up contract is required before implementation to define runtime
  identity, serialization, lookup, command references, replay,
  network/reconnect, and Rule Capability Package reference rules.
- Implementation must add runtime upgrade instances on `ShipInstance`; CP-001
  did not observe this surface in the current code.
- Ship serialization, save/load, replay initialization, network snapshots, and
  reconnect projection must include runtime upgrade instances and mutable state.
- Commander, fleet-wide, range/aura, and cross-ship exceptions require careful
  Rule Capability Package justification to avoid drifting into a full generic
  upgrade framework.
- This decision does not by itself define timing-window handling, visibility,
  command-history shape, concrete schemas, concrete APIs, or test sufficiency.

## 7. Explicit Non-Decisions

This ADR does not decide:

- a full generic upgrade framework,
- a specific implementation for Grand Moff Tarkin,
- a timing-window queue design,
- a command-history model for every upgrade choice,
- a visibility policy for prompts or private payloads,
- a TEST-003 replacement,
- metadata status advancement,
- a concrete runtime upgrade class, API, or schema,
- a concrete API for lookup or mutation,
- concrete identity fields for runtime upgrade instances,
- concrete command-reference payloads for runtime upgrade instances,
- whether a specific upgrade uses command-owned, resolver-owned, RuleRegistry,
  or other execution surfaces.

All upgrade JSON remains governed by existing metadata status until package
evidence and owner approval justify changes.

## 8. Migration Implications

If this ADR is accepted, before implementing behavior-changing upgrade rules:

- Setup must materialize equipped upgrades into runtime upgrade instances on
  the owning `ShipInstance`.
- Runtime upgrade instances must reference static upgrade data by `data_key`;
  full static data must not be copied into runtime state.
- Mutable upgrade state must live on the runtime upgrade instance by default.
- Exhausted, discarded, disabled, readied, used-this-round, used-this-phase,
  and similar trigger guards must use runtime upgrade instance state by default.
- Per-phase or per-round trigger guards must use runtime upgrade instance state
  unless the relevant Rule Capability Package proves the guard is fully derived
  from command history.
- Commander, fleet-wide, range/aura, and cross-ship effects must still have a
  source runtime upgrade instance on `ShipInstance` by default.
- Exceptions to default source-instance ownership must be justified in the
  relevant Rule Capability Package.
- Save/load tests must prove runtime upgrade instances, `data_key` references,
  and mutable upgrade state survive serialization round trip.
- Replay tests must prove that command history plus serialized runtime upgrade
  instances reconstructs upgrade behavior deterministically.
- Network/reconnect tests must prove snapshots and reconnect projection include
  the required runtime upgrade instance state without relying on local UI state.
- Each implemented upgrade still needs a Rule Capability Package or package
  slice under CON-003.

Existing upgrade records must remain `NOT_INTEGRATED` until implementation
evidence, tests, metadata alignment, and owner approval support advancement.

## 9. Follow-Up Contract Needed

A narrow CON-004 contract is required after this ADR and before implementation.

CON-004 should define:

- runtime upgrade instance identity,
- setup materialization rules,
- the minimum serialized fields for runtime upgrade instances,
- how runtime upgrade instances reference static upgrade data by `data_key`,
- JSON-safe shape requirements for mutable runtime upgrade state,
- representation rules for exhausted, discarded, disabled, readied,
  used-this-round, used-this-phase, and similar trigger guards,
- lookup rules for commands, resolvers, `RuleRegistry`, `RuleSurface`,
  projection, and tests,
- command-history references to runtime upgrade instances,
- serialization and deserialization obligations,
- save/load, replay, network, and reconnect obligations,
- when per-phase and per-round trigger guards may be command-history-derived
  instead of stored on the runtime upgrade instance,
- exception boundaries for commander, fleet-wide, range/aura, and cross-ship
  effects,
- how Rule Capability Packages reference the accepted ownership model and
  justify exceptions.

CON-004 should not decide:

- timing-window queue design,
- visibility policy,
- TEST-003 replacement,
- specific upgrade behavior,
- metadata status advancement,
- a full generic upgrade framework.

## 10. Related Documents

- `ARCHITECTURE.md`
- `docs/architecture/DOCUMENT_AUTHORITY.md`
- `docs/architecture/adr/ADR-003-rule-and-validation-surfaces.md`
- `docs/architecture/contracts/CON-003-rule-capability-contract.md`
- `docs/architecture/context/CP-001-game-component-rule-extension.md`
- `docs/architecture/rule_capability_packages/CAP-UPG-001-grand-moff-tarkin-command-token-grant.md`
- `docs/architecture/decision_workbooks/UPG-001-recurring-upgrade-rule-architecture-workbook.md`

## 11. Open Owner Questions

The Project Owner has selected the refined Option A ownership direction. Before
this ADR can become Accepted, the remaining owner questions are:

1. Does the owner approve this ADR text as the intended refined Option A
   decision?
2. Does the owner confirm that CON-004 is required before the first upgrade-rule
   implementation begins?
3. Does the owner confirm that commander, fleet-wide, range/aura, and
   cross-ship exceptions require Rule Capability Package justification and must
   not become a full generic upgrade framework?

No concrete runtime upgrade class, API, schema, identity format, command payload
shape, timing-window design, visibility policy, or test-policy replacement is
decided by this ADR.

## 12. Recommendation For Owner Review

Recommended owner action:

- Accept the refined Option A ownership direction in ADR-004.
- Direct a narrow CON-004 contract for runtime upgrade identity,
  materialization, serialization, lookup, command references, replay,
  network/reconnect, and Rule Capability Package reference rules before
  implementing the first upgrade rule.

The Project Owner must explicitly decide the three open questions above before
this ADR can become Accepted.
