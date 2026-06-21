# ADR-003: Rule and Validation Surface Decision

Status: Accepted

ADR-ID: ADR-003  
Title: Rule and Validation Surface Decision

Accepted by: Owner

Accepted date: 2026-06-19

Supersedes:
None

Superseded by:
None

Related:
- CP-001
- AT-003
- AT-004
- BC-005
- BC-005A
- BC-011
- BC-012
- RG-005
- RG-006
- RG-011
- RG-013
- RG-015

Inputs:
- `docs/architecture/decision_workbooks/ADR-003-direction-summary.md`
- `docs/architecture/decision_workbooks/ADR-003-A-rule-ownership-workbook.md`
- `docs/architecture/decision_workbooks/ADR-003-B-integration-definition-workbook.md`
- `docs/architecture/decision_workbooks/ADR-003-C-authority-boundaries-workbook.md`
- `docs/architecture/decision_workbooks/ADR-003-D-metadata-semantics-workbook.md`
- `docs/architecture/context/CP-001-game-component-rule-extension.md`
- `docs/architecture/DOCUMENT_AUTHORITY.md`
- `docs/architecture/CODEX_WORKFLOW.md`
- `docs/architecture/ARCHITECTURE_ROADMAP.md`

## Acceptance Note

ADR-003 is accepted as the governing architecture policy for behavior-changing component rules.

The decision establishes architectural direction and migration policy.

ADR-003 does not define the implementation contract.

CON-003 Rule Capability Contract and TEST-003 Capability Verification Strategy remain required before broad rollout of behavior-changing rule implementations.

## 1. Context

The current implementation has a hybrid rule and validation architecture.

Observed rule behavior exists across:

- `RuleRegistry` and `RuleSurface` registered hooks.
- Command validation and command execution.
- Combat, movement, repair, setup, fleet, and damage resolvers.
- Setup and fleet validators.
- Runtime state classes such as `GameState`, `PlayerState`, `ShipInstance`, `SquadronInstance`, and `InteractionFlow`.
- `UIProjector` and scene/UI affordance paths.
- `StateFilter`, serialization, replay, network sync, and reconnect paths.

CP-001 establishes that static component JSON and metadata are broad and schema-backed, but metadata is not executable behavior by itself. Active behavior exists only when static data is connected to runtime state, command/resolver/setup/projection paths, serialization, replay, network handling, visibility filtering, and tests.

The reality gaps around `BC-005` and `BC-005A` showed that the project needed an accepted model for expanding behavior-changing rules for ships, squadrons, upgrades, objectives, obstacles, damage cards, tokens, and rules-reference records. The key risk is not that the current hybrid implementation is automatically wrong. The risk is that future work, especially AI-assisted work, may add behavior to only one surface and falsely treat the rule as complete.

## 2. Decision Drivers

- Codex safety: future AI-assisted changes need explicit guardrails and traceability.
- Rule discoverability: behavior-changing rules must be findable even when they span multiple implementation surfaces.
- Mixed-rule support: upgrades, objectives, damage cards, and abilities often cross command, resolver, state, projection, visibility, and persistence boundaries.
- Replay safety: rule behavior must be deterministic through command history and replay.
- Network safety: rule behavior must survive command sync, snapshots, reconnect, and hidden-information filtering.
- Save/load durability: active rule source state must serialize or be explicitly derived.
- Migration cost: the project should avoid a broad rewrite and preserve working behavior.
- Maintainability: the model must scale to many new upgrades, objectives, abilities, and special rules.

## 3. Decision

ADR-003 proposes the following architecture:

- A Rule Capability Package is the governing integration model for behavior-changing component rules and special behavior.
- `RuleRegistry` is not the architecture.
- `RuleRegistry` is one implementation surface.
- `RuleRegistry`/`RuleSurface` is a preferred implementation surface for suitable component-origin predicates, modifiers, enablers, and registered hooks where accepted call sites exist.
- Component rule describes source/origin, not architectural ownership.
- Core mechanic describes base lifecycle/procedure ownership.
- Mixed rules are expected and common.
- Authority is delegated by responsibility surface.
- Integration is capability-based.
- Metadata reports evidence, routing, and status. Metadata does not own behavior.

The capability package is a traceability and integration artifact that documents ownership, evidence, and completeness. It does not imply a dedicated runtime package manager or runtime ownership layer.

## 4. Authority Model

Authority is delegated by responsibility:

| Responsibility | Authority |
| --- | --- |
| Active state | State classes and serialized runtime/setup state |
| Command legality and submitted mutation | `CommandProcessor`, `CommandApplicability`, and concrete commands |
| Resolver calculations | Mechanic-specific resolvers |
| Setup lifecycle | Setup package builder, setup validators, setup commands, and setup interaction-flow paths |
| Fleet construction legality | Fleet validators and roster/package validation |
| Registered hooks | `RuleRegistry` and `RuleSurface` where accepted call sites exist |
| Interaction payload shape | `InteractionFlow` when payloads are serialized in `GameState` |
| Projection and affordances | `UIProjector`, with UI controllers as presentation consumers |
| Hidden information | `StateFilter` and `InteractionFlow.visible_to` |
| Serialization | `serialize()`/`deserialize()` paths and JSON-safe payload contracts |
| Replay | `CommandProcessor` history, deterministic command execution, and replay drivers |
| Network synchronization | Host/server command authority, snapshots, reconnect projection, and filtering |
| Integration status | Rule Capability Package evidence |

The capability package is authoritative for traceability and completeness. It does not replace the implementation authority of commands, resolvers, state classes, projection, filtering, serialization, replay, or network systems, and it does not imply a new runtime subsystem.

## 5. Integration Model

A component rule or special behavior is integrated only when its capability package identifies every applicable behavior surface and provides evidence that each applicable surface is implemented and tested.

Integration does not require every rule to use `RuleRegistry`.

Integration does require applicable evidence for:

- Static component identity and rule source.
- Active runtime/setup state, or a rationale that no durable state is required.
- Validation and command legality.
- Execution path: command, resolver, setup flow, `RuleRegistry`/`RuleSurface`, state class, or another named surface.
- Projection and UI affordance behavior where applicable.
- Serialization and save/load durability where applicable.
- Replay determinism where applicable.
- Network/reconnect behavior where applicable.
- Hidden-information classification where applicable.
- Tests covering the relevant surfaces.

Tests are part of the integration evidence. A hook, metadata field, UI affordance, or static JSON record is not enough to mark behavior integrated.

## 6. Metadata Policy

Metadata is evidence and routing information, not behavior authority.

Static fields such as printed text, `rules_reference_ids`, `rules_integration`, `implemented_rule_ids`, `implementation_status`, `rule_surfaces`, `pending_rule_surfaces`, and `runtime_state_requirements` may describe intent, source linkage, declared surfaces, or implementation progress. They do not prove behavior is active unless backed by capability package evidence.

`rules_integration.status` and rules-reference `implementation_status` are migration-era status fields until CON-003 defines capability-backed status semantics. Existing values such as `NOT_INTEGRATED`, `PARTIAL`, and `INTEGRATED` must be treated as status claims, not proof.

Metadata may become capability-derived in future work. It must not become the owner of rule behavior without a separate accepted decision and contract.

## 7. Consequences

Positive consequences:

- Provides a stable model for adding upgrades, objectives, abilities, damage cards, obstacles, and other behavior-changing content.
- Preserves working command, resolver, setup, state, projection, replay, and network paths.
- Makes mixed rules explicit instead of forcing them into one implementation surface.
- Reduces Codex risk by requiring surface traceability before claiming integration.
- Supports incremental migration instead of a broad rewrite.
- Clarifies that `RuleRegistry` remains useful without becoming the universal owner.

Negative consequences:

- Requires a new capability-package contract before the model can be enforced consistently.
- Adds process overhead for behavior-changing rules.
- Existing status metadata may need backfill or reclassification.
- Existing tests may not yet map cleanly to capability-package evidence.
- Some current README/test wording still reflects older registry-id semantics and will need later alignment.

Tradeoffs:

- The decision favors explicit traceability and safety over minimal process.
- The decision preserves implementation diversity instead of enforcing uniform rule execution.
- The decision delays exact schema/status mechanics to CON-003 rather than embedding them in this ADR.

## 8. Migration Rules

- Do not perform a big-bang rewrite.
- Preserve existing working behavior unless a feature, bug, contract, or test need requires touching it.
- New behavior-changing rule work must follow ADR-003.
- Touched behavior-changing rules should be migrated toward capability-package traceability.
- High-risk mixed rules should be prioritized for backfill: damage cards with split immediate/persistent effects, upgrades with runtime effects, objectives with setup/runtime state, obstacles with gameplay effects, and named ship/squadron abilities.
- Metadata may remain readable and schema-valid during migration, but integration claims should become capability-backed.
- Existing metadata and status fields remain migration-era status claims until CON-003 defines capability-backed semantics. Until then, metadata may be useful for discovery and routing, but it is not proof and must not be treated as authoritative evidence.
- Existing `RuleRegistry`, command, resolver, setup, projection, serialization, replay, and network paths remain valid implementation surfaces.

## 9. Consequences For Future Contracts

CON-003 Rule Capability Contract is required.

CON-003 should define:

- A capability package template.
- Stable package identifiers.
- Surface traceability requirements.
- Integration checklist rules.
- Status derivation or validation rules.
- Evidence requirements for state, validation, execution, projection, serialization, replay, network, visibility, and tests.
- Rules for interpreting existing metadata fields.
- Test strategy requirements for behavior-changing rules.

This ADR does not design CON-003 and does not define exact schemas.

The capability package contract should define traceability, evidence, and completeness requirements. It should not be interpreted as requiring a dedicated runtime package manager unless a later accepted decision explicitly introduces one.

## 10. Codex Guardrails

- Do not treat static JSON or printed rules text as active behavior.
- Do not treat `rules_integration.status`, `implementation_status`, `implemented_rule_ids`, `rule_surfaces`, `pending_rule_surfaces`, or `runtime_state_requirements` as proof of integration.
- Treat existing metadata/status values as migration-era status claims until CON-003 defines capability-backed semantics.
- Do not treat `RuleRegistry` registration alone as proof of integration.
- Do not add behavior-changing content as static metadata only.
- Do not add rule predicates only in UI/projection paths.
- Do not add hooks without verifying accepted call sites.
- Do not add command/resolver behavior without checking projection, serialization, replay, network, visibility, and tests where applicable.
- For new or touched behavior-changing rules, identify active state owner, validation owner, execution owner, projection owner, serialization impact, replay impact, network/reconnect impact, hidden-information impact, and test evidence.
- Acceptance of ADR-003 does not authorize broad behavior-changing rule implementation without CON-003 or explicit owner guidance. Until CON-003 exists, limited validation slices and exploratory work are allowed; broad rollout is not assumed.
- When documentation and code conflict, follow accepted ADRs/contracts and use CP-001/current-state evidence for observed behavior.

## 11. Open Questions

The following questions remain after ADR-003-A/B/C/D and should be handled by CON-003, a test strategy, or follow-up work:

- What exact capability package schema should be used?
- Which package fields are mandatory for every rule, and which are conditional by rule type?
- How should existing metadata statuses map to capability-backed statuses?
- Should metadata status be stored manually, generated from capability packages, or validated by tests?
- What exact test minimum is required per surface and per rule category?
- Who approves a capability package that spans multiple subsystems?
- Which existing rule category should be backfilled first?
- How should catalog versioning interact with saves, replays, and network peers when behavior depends on static component data?

These questions do not reopen the core ADR-003 decision.

## 12. Implementation Readiness

ADR-003 is accepted.

The next required artifacts are:

1. CON-003 Rule Capability Contract.
2. TEST-003 Capability Verification Strategy.

Broad rollout of behavior-changing rule implementations remains gated by those artifacts.

Implementation work before CON-003 should be limited to:

- exploratory work
- validation slices
- owner-directed exceptions
