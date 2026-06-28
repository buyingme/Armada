# CON-004: Upgrade Runtime Contract

Contract ID: CON-004  
Title: Upgrade Runtime Contract  
Status: Proposed  
Derived From: ADR-004

Accepted by: Not accepted  
Accepted date: Not applicable  
Supersedes: None  
Superseded by: None

Related:
- ADR-003
- ADR-004
- CON-003
- CP-001
- CAP-UPG-001
- UPG-001

Acceptance Note:

This contract operationalizes ADR-004. It defines implementation obligations
for runtime upgrade instances, mutable upgrade state, persistence, replay,
network/reconnect behavior, and Rule Capability Package references.

This contract does not reconsider ADR-004. It does not introduce a generic
upgrade framework, define specific upgrade behavior, define a timing-window
queue, define command execution architecture, define visibility policy, replace
TEST-003, or change metadata status handling.

## 1. Purpose

CON-004 defines the minimum implementation obligations required to implement
the ADR-004 ownership model consistently.

ADR-004 decided:

- Active equipped upgrades become runtime upgrade instances after setup.
- Runtime upgrade instances live on the owning `ShipInstance` by default.
- Runtime upgrade instances reference static upgrade data through `data_key`.
- Full static upgrade data is never copied into runtime state.
- Mutable upgrade state belongs to the runtime upgrade instance by default.
- Exhausted, discarded, disabled, readied, and trigger-guard state belong to the
  runtime upgrade instance by default.
- Commander, fleet-wide, range/aura, and cross-ship effects still have a source
  runtime upgrade instance on `ShipInstance` by default.
- Exceptions require Rule Capability Package justification.
- A generic upgrade framework SHALL NOT be introduced.

This contract converts those decisions into reviewable implementation rules.

## 2. Scope

This contract defines only:

- runtime upgrade instance identity,
- runtime instance materialization during setup,
- mandatory runtime instance fields,
- mandatory `data_key` reference rules,
- mutable state representation,
- trigger-guard representation,
- lookup rules,
- command reference rules,
- serialization requirements,
- deserialization requirements,
- save/load obligations,
- replay obligations,
- network obligations,
- reconnect obligations,
- Rule Capability Package reference rules,
- exception documentation rules.

This contract does not define:

- timing-window queue design,
- command execution architecture,
- visibility policy,
- TEST-003,
- implementation classes,
- implementation APIs,
- inheritance hierarchies,
- event systems,
- plugin systems,
- metadata status handling,
- specific upgrade behavior,
- additional architectural responsibilities.

## 3. Terms

Runtime upgrade instance:

- A JSON-safe runtime representation of one equipped upgrade after setup.
- It exists on the owning `ShipInstance` by default.
- It references static upgrade catalog data by `data_key`.
- It owns mutable upgrade state by default.

Source runtime upgrade instance:

- The runtime upgrade instance on the owning `ShipInstance` that proves the
  upgrade is active at runtime.
- Commander, fleet-wide, range/aura, and cross-ship effects SHALL still have a
  source runtime upgrade instance by default.

Static upgrade data:

- Catalog data loaded from the upgrade JSON and typed static data pipeline.
- Static upgrade data SHALL be referenced by `data_key`.
- Static upgrade data SHALL NOT be copied into runtime upgrade state.

Mutable upgrade state:

- JSON-safe state owned by the runtime upgrade instance.
- Mutable upgrade state includes card status, trigger guards, and
  Rule Capability Package documented rule-specific state.

Rule Capability Package:

- The CON-003 traceability artifact for a concrete behavior-changing rule or
  behavior slice.
- A Rule Capability Package SHALL identify how the rule uses CON-004 and SHALL
  justify any exception to default runtime upgrade ownership.

## 4. Normative Requirements

### 4.1 Runtime Upgrade Instance Identity

CON-004-ID-001:

Each runtime upgrade instance SHALL have one stable `runtime_upgrade_id`.

CON-004-ID-002:

`runtime_upgrade_id` SHALL be unique within the authoritative game state.

CON-004-ID-003:

`runtime_upgrade_id` SHALL remain stable across save/load, replay initialization,
network snapshots, and reconnect.

CON-004-ID-004:

Runtime upgrade instance identity SHALL be derived from serialized setup/roster
facts or serialized runtime state. It SHALL NOT depend on local UI state,
unserialized object identity, memory address, load order outside serialized
data, or non-deterministic generation.

CON-004-ID-005:

Each runtime upgrade instance SHALL preserve enough identity facts to resolve:

- the owning player,
- the owning `ShipInstance`,
- the source roster ship entry,
- the source upgrade assignment,
- the assigned upgrade slot and slot index when present in setup/roster data,
- the static upgrade `data_key`.

CON-004-ID-006:

If the setup/roster payload lacks a stable source upgrade assignment identity,
implementation SHALL stop for Project Owner guidance before implementing
behavior-changing upgrade rules that depend on runtime upgrade instances.

### 4.2 Runtime Instance Materialization During Setup

CON-004-MAT-001:

Setup SHALL materialize one runtime upgrade instance for each equipped upgrade
assigned to a ship that enters the game.

CON-004-MAT-002:

Runtime upgrade instances SHALL be materialized after the owning `ShipInstance`
exists and before gameplay behavior can query active upgrades.

CON-004-MAT-003:

Materialization SHALL attach runtime upgrade instances to the owning
`ShipInstance` by default.

CON-004-MAT-004:

Materialization SHALL reference the static upgrade catalog by `data_key`.

CON-004-MAT-005:

Materialization SHALL NOT copy full static upgrade data into runtime upgrade
state.

CON-004-MAT-006:

Materialization SHALL be deterministic for a given serialized setup package and
static catalog.

CON-004-MAT-007:

Fleet legality and roster legality SHALL remain owned by the existing
fleet/setup validation surfaces unless a later accepted contract changes that
ownership.

CON-004-MAT-008:

Runtime materialization SHALL NOT treat static upgrade metadata,
`rules_integration.status`, `implementation_status`, `rule_surfaces`,
`pending_rule_surfaces`, or `runtime_state_requirements` as proof that upgrade
behavior is implemented or integrated.

CON-004-MAT-009:

Runtime upgrade instances SHALL initialize mutable state with these canonical
serialized values:

- `card_state.exhausted = false`,
- `card_state.discarded = false`,
- `card_state.disabled = false`,
- `card_state.readied = true`,
- `trigger_guards = {}`,
- `rule_state = {}`.

### 4.3 Mandatory Runtime Instance Fields

CON-004-FLD-001:

Each serialized runtime upgrade instance SHALL contain these fields:

- `runtime_upgrade_id`,
- `data_key`,
- `owner_player_id`,
- `source_ship_ref`,
- `source_roster_entry_id`,
- `source_assignment_id`,
- `slot`,
- `slot_index`,
- `card_state`,
- `trigger_guards`,
- `rule_state`.

CON-004-FLD-002:

`source_ship_ref` SHALL resolve to exactly one owning `ShipInstance` in the
authoritative game state.

CON-004-FLD-003:

`source_assignment_id` SHALL preserve the stable assignment identity from the
setup/roster payload.

CON-004-FLD-004:

`slot` and `slot_index` SHALL preserve the assignment slot information from the
setup/roster payload when present. If the setup/roster payload has no slot or
slot index, the serialized field MAY be `null`.

CON-004-FLD-005:

`card_state` SHALL be a JSON-safe object containing these boolean fields:

- `exhausted`,
- `discarded`,
- `disabled`,
- `readied`.

CON-004-FLD-006:

`trigger_guards` SHALL be a JSON-safe object.

CON-004-FLD-007:

`rule_state` SHALL be a JSON-safe object.

CON-004-FLD-008:

Rule-specific mutable fields SHALL live under `rule_state` unless this contract
or an accepted Rule Capability Package exception defines a more specific owner.

CON-004-FLD-009:

Runtime upgrade instance fields SHALL NOT contain full static upgrade catalog
records, card art data, printed rule text, restriction records, or point-cost
records.

CON-004-FLD-010:

The field names defined by CON-004 SHALL be canonical serialized runtime
representation names. They SHALL NOT prescribe implementation class names,
property names, APIs, inheritance, or internal data structures.

CON-004-FLD-011:

Serialized `card_state` values SHALL obey these consistency rules:

- `readied = true` means `exhausted = false`.
- `exhausted = true` means `readied = false`.
- `discarded = true` forbids `readied = true` and `exhausted = true`.
- `disabled = true` MAY coexist with other card states only when explicitly
  allowed by the relevant Rule Capability Package.

Invalid serialized `card_state` combinations SHALL be rejected or surfaced as
invalid state. Implementations SHALL NOT guess an interpretation.

### 4.4 `data_key` Reference Rules

CON-004-DATA-001:

Runtime upgrade instances SHALL use `data_key` as the reference to static
upgrade data.

CON-004-DATA-002:

Commands, resolvers, rule hooks, projection, serialization, replay, network, and
reconnect code SHALL resolve static upgrade data from `data_key` when static
facts are needed.

CON-004-DATA-003:

Runtime upgrade instances SHALL NOT duplicate static upgrade data that can be
looked up by `data_key`.

CON-004-DATA-004:

Deserialization, replay initialization, and reconnect reconstruction SHALL
reject or surface an invalid-state error when a runtime upgrade instance
references a `data_key` that cannot be resolved in the static catalog.

CON-004-DATA-005:

Runtime behavior SHALL NOT infer that an upgrade rule is implemented only
because static upgrade data or static rule metadata exists.

### 4.5 Mutable State Representation

CON-004-STATE-001:

Mutable upgrade state SHALL live on the runtime upgrade instance by default.

CON-004-STATE-002:

Exhausted, discarded, disabled, and readied state SHALL live in `card_state`.

CON-004-STATE-003:

Rule-specific counters, selected values, pending state, and other durable
upgrade-owned facts SHALL live in `rule_state` unless a Rule Capability Package
justifies an exception.

CON-004-STATE-004:

All mutable upgrade state SHALL be JSON-safe.

CON-004-STATE-005:

Mutable upgrade state SHALL be serialized as part of authoritative game state.

CON-004-STATE-006:

Mutable upgrade state SHALL NOT rely on local UI state, unregistered scripts,
unserialized objects, or static metadata for durability.

CON-004-STATE-007:

If a rule claims that no mutable state is required, its Rule Capability Package
SHALL state why existing serialized state, command history, and `data_key`
lookup are sufficient.

### 4.6 Trigger-Guard Representation

CON-004-GUARD-001:

Trigger guards SHALL live on the runtime upgrade instance by default.

CON-004-GUARD-002:

Trigger guards SHALL be stored under `trigger_guards`.

CON-004-GUARD-003:

Each trigger guard SHALL use a stable guard key documented by the relevant Rule
Capability Package.

CON-004-GUARD-004:

Each stored trigger guard SHALL record JSON-safe interval facts sufficient to
determine whether the guard has been consumed for its relevant round, phase, or
other documented interval.

CON-004-GUARD-005:

Per-round trigger guards SHALL record the round identity or equivalent
authoritative interval identity used by the game state.

CON-004-GUARD-006:

Per-phase trigger guards SHALL record the round identity and phase identity, or
equivalent authoritative interval identities used by the game state.

CON-004-GUARD-007:

A trigger guard MAY be derived from command history only when the relevant Rule
Capability Package proves that command history alone is sufficient for
validation, save/load, replay, network, and reconnect.

CON-004-GUARD-008:

If command-history derivation is used for a trigger guard, the Rule Capability
Package SHALL identify the exact command-history evidence that proves the guard
has or has not been consumed.

### 4.7 Lookup Rules

CON-004-LOOKUP-001:

Runtime upgrade lookup SHALL use authoritative runtime game state.

CON-004-LOOKUP-002:

Active upgrade behavior SHALL look up runtime upgrade instances on the owning
`ShipInstance` by default.

CON-004-LOOKUP-003:

Commands, resolvers, `RuleRegistry`, `RuleSurface`, projection, serialization,
replay, network, reconnect, and tests SHALL NOT treat setup/roster upgrade
assignments alone as active runtime upgrade instances.

CON-004-LOOKUP-004:

Lookup by `runtime_upgrade_id` SHALL resolve to zero or one runtime upgrade
instance. A lookup that resolves to multiple instances SHALL be treated as an
invalid state.

CON-004-LOOKUP-005:

Lookup by `data_key` alone SHALL NOT be sufficient when a command, resolver, or
projection path needs to identify a specific equipped upgrade instance.

CON-004-LOOKUP-006:

Commander, fleet-wide, range/aura, and cross-ship effects SHALL resolve their
source runtime upgrade instance before applying behavior outside the source
ship.

CON-004-LOOKUP-007:

If a lookup path needs an index, cache, or helper for performance or ergonomics,
that path SHALL remain derived from authoritative serialized runtime upgrade
instances and SHALL NOT become an independent ownership surface.

### 4.8 Command Reference Rules

CON-004-CMD-001:

Commands that use, exhaust, discard, disable, ready, or otherwise mutate a
runtime upgrade instance SHALL reference the relevant `runtime_upgrade_id`.

CON-004-CMD-002:

Commands that make a replayable choice for a specific runtime upgrade instance
SHALL reference the relevant `runtime_upgrade_id`.

CON-004-CMD-003:

Command payloads SHALL NOT carry full static upgrade data.

CON-004-CMD-004:

Command payloads MAY carry `data_key` as supporting validation or audit data,
but `data_key` SHALL NOT replace `runtime_upgrade_id` when the command targets
a specific equipped upgrade instance.

CON-004-CMD-005:

Command validation SHALL reject or fail a command that references a missing,
ambiguous, discarded, disabled, or otherwise unusable runtime upgrade instance
when that state makes the command illegal for the rule being executed.

CON-004-CMD-006:

This contract does not decide whether a concrete upgrade behavior is
command-owned, resolver-owned, `RuleRegistry`-owned, or mixed. The relevant Rule
Capability Package SHALL identify the execution surface under ADR-003 and
CON-003.

### 4.9 Serialization Requirements

CON-004-SER-001:

`ShipInstance` serialization SHALL include its runtime upgrade instances.

CON-004-SER-002:

Serialized runtime upgrade instances SHALL include every mandatory field listed
in this contract.

CON-004-SER-003:

Serialized runtime upgrade instance state SHALL be JSON-safe.

CON-004-SER-004:

Serialized runtime upgrade instance state SHALL include mutable `card_state`,
`trigger_guards`, and `rule_state`.

CON-004-SER-005:

Serialized runtime upgrade instance state SHALL NOT include full static upgrade
data.

CON-004-SER-006:

Serialization SHALL preserve enough ordering or identity information to
deserialize runtime upgrade instances without changing their
`runtime_upgrade_id`.

CON-004-SER-007:

Serialization SHALL preserve commander, fleet-wide, range/aura, and cross-ship
source runtime upgrade instances on their owning `ShipInstance` by default.

### 4.10 Deserialization Requirements

CON-004-DESER-001:

Deserialization SHALL reconstruct runtime upgrade instances from serialized
runtime upgrade instance data.

CON-004-DESER-002:

Deserialization SHALL reattach runtime upgrade instances to the owning
`ShipInstance` by default.

CON-004-DESER-003:

Deserialization SHALL resolve static upgrade data by `data_key` when static
facts are needed.

CON-004-DESER-004:

Deserialization SHALL preserve `runtime_upgrade_id`, `card_state`,
`trigger_guards`, and `rule_state`.

CON-004-DESER-005:

Deserialization SHALL NOT rematerialize mutable runtime upgrade state from
setup/roster assignments when serialized runtime upgrade instance state is
present.

CON-004-DESER-006:

If serialized runtime upgrade instance state is missing for a behavior-changing
upgrade after the point where runtime instances are required, deserialization
SHALL reject the state or surface an invalid-state error rather than silently
assuming static setup/roster assignment is sufficient.

### 4.11 Save/Load Obligations

CON-004-SAVE-001:

Save/load behavior SHALL preserve the set of runtime upgrade instances.

CON-004-SAVE-002:

Save/load behavior SHALL preserve each runtime upgrade instance's identity,
`data_key`, source ownership facts, `card_state`, `trigger_guards`, and
`rule_state`.

CON-004-SAVE-003:

Save/load behavior SHALL preserve enough state for command validation,
execution, projection, replay continuation, network snapshots, and reconnect
projection to agree after load.

CON-004-SAVE-004:

A Rule Capability Package for a behavior-changing upgrade SHALL identify the
save/load evidence that proves its required runtime upgrade state survives a
serialization round trip.

### 4.12 Replay Obligations

CON-004-REPLAY-001:

Replay initialization SHALL reconstruct runtime upgrade instances and mutable
upgrade state from serialized authoritative state.

CON-004-REPLAY-002:

Replayable commands that refer to a runtime upgrade instance SHALL use stable
runtime upgrade instance references as defined by this contract.

CON-004-REPLAY-003:

Replay SHALL NOT depend on local UI state, nonserialized object identity, or
static metadata status to determine whether an upgrade is active.

CON-004-REPLAY-004:

Replay SHALL resolve static upgrade data by `data_key` from the static catalog.

CON-004-REPLAY-005:

A Rule Capability Package for a behavior-changing upgrade SHALL identify replay
evidence for any command, choice, follow-up effect, trigger guard, or mutable
state that affects deterministic replay.

### 4.13 Network Obligations

CON-004-NET-001:

Authoritative game-state snapshots SHALL include runtime upgrade instances and
their mutable state when those instances are part of authoritative state.

CON-004-NET-002:

Network command payloads that target a specific runtime upgrade instance SHALL
reference `runtime_upgrade_id`.

CON-004-NET-003:

Network behavior SHALL NOT require peers to infer active upgrade instances from
static upgrade metadata alone.

CON-004-NET-004:

Network behavior SHALL resolve static upgrade data by `data_key`.

CON-004-NET-005:

Network behavior SHALL NOT transmit full static upgrade data as runtime upgrade
state.

CON-004-NET-006:

A Rule Capability Package for a behavior-changing upgrade SHALL identify network
evidence for command sync, state snapshots, and peer-visible runtime upgrade
state where applicable.

### 4.14 Reconnect Obligations

CON-004-RECON-001:

Reconnect reconstruction SHALL use serialized authoritative runtime upgrade
instances and mutable state.

CON-004-RECON-002:

Reconnect projection SHALL NOT require local UI state to determine whether an
upgrade is active, exhausted, discarded, disabled, readied, or guard-consumed.

CON-004-RECON-003:

Reconnect projection SHALL resolve static upgrade data by `data_key` when
static display or rule facts are needed.

CON-004-RECON-004:

A Rule Capability Package for a behavior-changing upgrade SHALL identify
reconnect evidence when the rule affects active prompts, command choices,
mutable upgrade state, command-token state, attack state, damage state, or other
projected gameplay state.

CON-004-RECON-005:

This contract does not define visibility policy. Reconnect filtering and
viewer-specific payload rules remain owned by the existing visibility surfaces
identified under ADR-003 and CON-003.

### 4.15 Rule Capability Package Reference Rules

CON-004-RCP-001:

Every Rule Capability Package for a behavior-changing upgrade SHALL reference
ADR-004 and CON-004.

CON-004-RCP-002:

Every Rule Capability Package for a behavior-changing upgrade SHALL identify the
source runtime upgrade instance owner.

CON-004-RCP-003:

Every Rule Capability Package for a behavior-changing upgrade SHALL identify any
`card_state`, `trigger_guards`, and `rule_state` fields required by the rule.

CON-004-RCP-004:

Every Rule Capability Package for a behavior-changing upgrade SHALL identify
whether any trigger guard is stored on the runtime upgrade instance or derived
from command history.

CON-004-RCP-005:

If a trigger guard is command-history-derived, the Rule Capability Package SHALL
provide the evidence required by CON-004-GUARD-007 and CON-004-GUARD-008.

CON-004-RCP-006:

Every Rule Capability Package for a behavior-changing upgrade SHALL identify
serialization, save/load, replay, network, and reconnect impacts for the
runtime upgrade instance and its mutable state.

CON-004-RCP-007:

Every Rule Capability Package for a behavior-changing upgrade SHALL state
whether the default ADR-004 ownership model is used without exception.

### 4.16 Exception Documentation Rules

CON-004-EXC-001:

Exceptions to default runtime upgrade ownership SHALL be documented in the
relevant Rule Capability Package.

CON-004-EXC-002:

An exception SHALL identify the accepted architecture or owner direction that
permits the exception.

CON-004-EXC-003:

An exception SHALL explain why the source runtime upgrade instance on
`ShipInstance` is insufficient for the exceptional state or behavior.

CON-004-EXC-004:

An exception SHALL identify the alternate state owner, lookup path,
serialization impact, replay impact, network impact, reconnect impact, and test
evidence required for the exception.

CON-004-EXC-005:

An exception SHALL NOT introduce a generic upgrade framework.

CON-004-EXC-006:

Commander, fleet-wide, range/aura, and cross-ship effects SHALL still retain a
source runtime upgrade instance on `ShipInstance` by default, even when their
effects apply outside the source ship.

CON-004-EXC-007:

If an implementation requires mutable upgrade state outside the source runtime
upgrade instance and no accepted architecture already authorizes that state
owner, the Rule Capability Package SHALL record an Owner Decision Required
before implementation.

## 5. Rationale

ADR-004 selected runtime upgrade instances on `ShipInstance` as the default
owner for active equipped upgrades and mutable upgrade state. CP-001 records
that upgrade assignments currently exist as roster/setup facts and that no
generic active runtime upgrade-state collection was observed on `ShipInstance`.

This contract closes the implementation ambiguity identified by ADR-004 without
broadening the architecture:

- runtime instances are materialized from setup/roster facts,
- static data remains catalog-owned and referenced by `data_key`,
- mutable upgrade state is serialized with the runtime instance,
- commands and replayable choices reference runtime instance identity,
- save/load, replay, network, and reconnect reconstruct from authoritative
  serialized state,
- Rule Capability Packages document concrete rule usage and exceptions.

The contract does not choose timing-window mechanics, command execution
architecture, visibility policy, or test sufficiency. Those remain outside
ADR-004 and outside this contract.

## 6. Owner Decisions Required

The following topics are not decided by ADR-004 or CON-004. If implementation
requires one of these answers, the implementer SHALL stop for Project Owner
guidance or rely on a later accepted architecture artifact:

1. Timing-window queue design for optional upgrade prompts.
2. Whether a concrete optional decline is represented as an explicit command.
3. Command execution architecture for a concrete upgrade behavior.
4. Visibility policy for prompts, private payloads, chosen commands, hidden
   command dials, damage-deck payloads, or viewer-specific projections.
5. TEST-003 or any replacement test-threshold policy.
6. Metadata status advancement for upgrade JSON or rules-reference records.
7. Any exception that moves mutable upgrade state outside the source runtime
   upgrade instance without accepted architecture support.

## 7. Contract Validation

### 7.1 Consistency With ADR-004

Consistent.

This contract preserves ADR-004 decisions:

- active equipped upgrades become runtime upgrade instances after setup,
- runtime upgrade instances live on `ShipInstance` by default,
- static upgrade data is referenced by `data_key`,
- full static data is not copied into runtime state,
- mutable upgrade state belongs to the runtime upgrade instance by default,
- exhausted, discarded, disabled, readied, and trigger-guard state belong to
  the runtime upgrade instance by default,
- commander, fleet-wide, range/aura, and cross-ship effects retain a source
  runtime upgrade instance by default,
- exceptions require Rule Capability Package justification,
- no generic upgrade framework is introduced.

### 7.2 Consistency With ADR-003 And CON-003

Consistent.

This contract preserves ADR-003 and CON-003:

- Rule Capability Packages remain the integration evidence model.
- `RuleRegistry` remains one implementation surface, not the architecture.
- Commands, resolvers, state classes, projection, serialization, replay,
  network, and visibility retain their responsibility boundaries.
- Static metadata remains evidence and routing information, not behavior
  authority.
- Codex SHALL NOT mark a Rule Capability Package as `Integrated`.

### 7.3 Narrowness Check

Verified.

This contract does not define:

- a timing-window queue,
- command execution architecture,
- visibility policy,
- TEST-003,
- implementation classes or APIs,
- inheritance hierarchy,
- event system,
- plugin system,
- metadata status handling,
- specific upgrade behavior,
- a generic upgrade framework.

### 7.4 Implementation Consistency Check

This contract is intended to let two independent implementations agree on:

- what a runtime upgrade instance is,
- when runtime upgrade instances are created,
- where runtime upgrade instances live by default,
- what serialized fields every instance contains,
- how static data is referenced,
- where mutable state and trigger guards live,
- how commands reference specific runtime upgrade instances,
- how save/load, replay, network, and reconnect reconstruct upgrade state,
- what a Rule Capability Package documents.

Expected remaining differences are limited to implementation classes, APIs,
internal helper names, and concrete behavior surfaces selected by each Rule
Capability Package.

## 8. Related Documents

- `ARCHITECTURE.md`
- `docs/architecture/DOCUMENT_AUTHORITY.md`
- `docs/architecture/adr/ADR-003-rule-and-validation-surfaces.md`
- `docs/architecture/adr/ADR-004-upgrade-runtime-ownership.md`
- `docs/architecture/contracts/CON-003-rule-capability-contract.md`
- `docs/architecture/context/CP-001-game-component-rule-extension.md`
- `docs/architecture/rule_capability_packages/CAP-UPG-001-grand-moff-tarkin-command-token-grant.md`
- `docs/architecture/decision_workbooks/UPG-001-recurring-upgrade-rule-architecture-workbook.md`
