# CON-003: Rule Capability Contract

Contract ID: CON-003  
Title: Rule Capability Contract  
Status: Accepted  
Derived From: ADR-003

Accepted by: Owner  
Accepted date: 2026-06-21  
Supersedes: None  
Superseded by: None

Acceptance Note:

CON-003 is accepted as the implementation contract for ADR-003 Rule Capability Packages.

It defines required information, traceability, approval, status, and transitional testing rules.

The reusable Capability Package Template and TEST-003 remain required next artifacts.

Related:
- ADR-003
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

This contract operationalizes ADR-003. It does not redesign ADR-003, introduce alternative architectures, change authority boundaries, change integration requirements, or define gameplay behavior.

## 1. Purpose

This contract defines how behavior-changing component rules and special behavior are documented, traced, and evaluated for integration.

It defines:

- What a Rule Capability Package is.
- What information a package must contain.
- How integration evidence is recorded.
- How completeness is evaluated.
- What Codex and human implementers must identify before rule implementation.

This contract does not create a runtime subsystem and does not define exact file formats or final field names. The terms below describe required information categories. A later template may assign exact schema names.

## 2. Rule Capability Package

A Rule Capability Package is a traceability and integration artifact.

It records:

- The source of a behavior-changing rule.
- The affected component or rule category.
- The implementation surfaces involved.
- The owner of each applicable responsibility.
- The evidence that each applicable responsibility is implemented and tested.
- The integration status of the rule.

A Rule Capability Package is:

- A traceability artifact.
- An integration artifact.
- A completeness checklist.
- A review aid for human maintainers and Codex.

A Rule Capability Package is not:

- A runtime subsystem.
- A package manager.
- A replacement for commands, resolvers, state classes, `RuleRegistry`, `RuleSurface`, projection, serialization, replay, networking, or visibility filtering.
- The authority owner for gameplay behavior.

Implementation authority remains delegated by responsibility surface as defined in ADR-003.

## 3. Canonical Capability Package Form

Every Rule Capability Package shall follow one common structure.

Packages should normally be stored under:

- `docs/architecture/capability_packages/`

Another location may be used only when explicitly approved in documented project governance or owner direction.

This contract does not define package filenames.

Every package must contain these minimum sections:

- Identity
- Scope
- Ownership
- Surface Traceability
- Evidence Map
- Test Evidence
- Serialization / Replay / Network / Visibility Impact
- Integration Status
- Review History

This defines the minimum contract structure.

A reusable Capability Package Template will later operationalize this contract.

## 4. Required Information Categories

Every behavior-changing rule must have a capability package before it can be marked integrated.

The labels below are descriptive categories, not final schema field names.

### Identity

Required information:

- Stable capability identifier.
- Human-readable title.
- Rule source: component, damage card, rules-reference record, keyword, or other source.
- Component type: upgrade, objective, damage card, ship ability, squadron ability, obstacle, token, or other category.
- Source data keys or stable ids.
- Related rules-reference ids, if any.
- Related ADR, contract, gap, boundary, and test ids.

### Scope

Required information:

- Whether the rule is component-origin, core-mechanic-adjacent, or mixed.
- A short statement of what behavior is being integrated.
- A short statement of what behavior is explicitly out of scope.
- Affected game phase, interaction flow, or lifecycle area where known.

### Ownership

Required information:

- Active state owner.
- Validation owner.
- Execution owner.
- Projection owner.
- Serialization owner.
- Replay owner.
- Network synchronization owner.
- Visibility owner.
- Test owner.

If a responsibility is not applicable, the package must record a rationale.

### Implementation Evidence

Required information:

- Static data locations.
- Runtime state locations.
- Command locations.
- Resolver/helper locations.
- `RuleRegistry`/`RuleSurface` hook locations, if used.
- Setup/fleet validator locations, if used.
- Projection/UI locations, if used.
- Serialization/save/load locations, if used.
- Replay/network/visibility locations, if used.

### Test Evidence

Required information:

- Unit tests.
- Integration tests.
- Save/load tests, if applicable.
- Replay tests, if applicable.
- Network/reconnect tests, if applicable.
- Visibility/filtering tests, if applicable.
- Manual verification notes only where automated tests are not yet possible.

### Risk and Impact

Required information:

- Replay impact.
- Network impact.
- Visibility/hidden-information impact.
- Save/load impact.
- UI/projection impact.
- Metadata/status impact.
- Migration/backfill impact for existing behavior.

## 5. Surface Traceability Requirements

Each package must classify every surface below as required, optional, or not applicable.

| Surface | Required when | Optional when |
| --- | --- | --- |
| State | The rule needs durable facts, mutable state, setup state, damage state, counters, assignments, or active source state. | The rule is fully derived from already-serialized state and static data. |
| Validation | The rule can allow, block, constrain, or change command/setup/fleet legality. | The rule only affects passive display or already-validated calculation. |
| Execution | The rule changes gameplay behavior in any command, resolver, setup flow, state method, or accepted hook call site. | The package describes display-only metadata and has no gameplay behavior. |
| Projection | The player must see a prompt, affordance, status, choice, warning, or derived UI result. | The rule has no player-facing presentation impact. |
| Serialization | The rule adds or depends on durable state, setup state, interaction payload, command payload, or catalog identity. | The rule is entirely derived from existing serialized data. |
| Replay | The rule affects command execution, deterministic order, random inputs, observer followups, or derived effects. | The rule is static display-only metadata. |
| Network | The rule affects command sync, state snapshots, reconnect projection, setup package payloads, or peer-visible state. | The rule has no live gameplay or network-visible impact. |
| Visibility | The rule introduces private, owner-only, opponent-hidden, observer-specific, or server-only data. | All rule data and effects are public. |
| Tests | The rule has any behavior-changing effect. | Never optional for integrated behavior; only not applicable for static-only records. |

## 6. Integration Checklist

A rule may be considered integrated only when all applicable checklist items are satisfied:

- Static source is identified.
- Behavior scope is identified.
- Active state owner is identified or explicitly not applicable.
- Validation owner is identified or explicitly not applicable.
- Execution owner is identified or explicitly not applicable.
- Projection owner is identified or explicitly not applicable.
- Serialization impact is identified and covered.
- Replay impact is identified and covered.
- Network/reconnect impact is identified and covered.
- Visibility impact is identified and covered.
- Implementation locations are listed.
- Required tests are listed.
- Required tests exist and pass.
- Metadata/status claims are aligned with package evidence.
- Any not-applicable surface has a rationale.

Integrated does not mean:

- Static JSON exists.
- A rules-reference record exists.
- `rules_integration.status` says `INTEGRATED`.
- `implementation_status` says `INTEGRATED`.
- A `RuleRegistry` hook exists.
- A UI affordance exists.
- One test exists for one surface.

Integrated means the capability package is complete for the behavior's applicable surfaces.

## 7. Rule Categories

This section defines contract expectations only. It does not define gameplay.

| Rule category | Contract expectations |
| --- | --- |
| Upgrades | Must identify roster/static source, active runtime state needs, fleet/build validation impact, gameplay execution owner, projection impact, save/load/replay/network impact, and tests. If no generic upgrade runtime state exists, the package must state the chosen state owner or explain why existing serialized data is sufficient. |
| Objectives | Must separate setup lifecycle from runtime scoring or special behavior. Must identify setup state, setup validators/commands, objective runtime state if any, projection, serialization, replay/network, visibility, and tests. |
| Damage cards | Must distinguish persistent behavior from immediate effects. Must identify faceup/facedown state, damage deck/state impact, command-owned immediate effects, registry/resolver hooks if used, visibility filtering, save/load, replay, network, and tests. |
| Ship abilities | Must identify whether behavior is derived from ship static data or requires mutable state. Must trace command/resolver/projection impact and durability requirements. |
| Squadron abilities | Must distinguish generic keyword behavior from named or ace-specific behavior. Must trace squadron data/state, command/resolver execution, projection, serialization, replay/network, and tests. |
| Obstacles | Must distinguish setup placement from gameplay effects. Must trace setup validators/commands, board token/state impact, movement/overlap resolver impact, projection, serialization, replay/network, and tests. |
| Tokens | Must identify token state owner, command/resolver impact, projection, serialization, replay/network, visibility if hidden, and tests. New token types require explicit state and UI/projection evidence. |

## 8. Evidence Requirements

### Implementation Evidence

Implementation evidence must identify the concrete files, classes, functions, resources, or tests that make the behavior active.

Accepted implementation evidence may include:

- Static component JSON and typed model paths.
- Runtime state fields and serialization paths.
- Commands and command validation paths.
- Resolver/helper paths.
- Setup/fleet validators.
- `RuleRegistry` registrations and accepted `RuleSurface` call sites.
- `InteractionFlow` payloads.
- `UIProjector` projection paths.
- `StateFilter` visibility filtering paths.
- Replay/network paths.

Static metadata alone is not implementation evidence for active behavior.

### Testing Evidence

Testing evidence must identify automated tests for each applicable behavior surface.

Manual verification may supplement tests but does not replace tests for integrated behavior unless an owner explicitly accepts a temporary exception.

### Serialization Evidence

Serialization evidence is required when:

- The rule owns or depends on durable state.
- The rule affects setup state.
- The rule affects `InteractionFlow.payload`.
- The rule depends on static `data_key` lookups during load/replay/network flows.

### Replay Evidence

Replay evidence is required when:

- The rule affects command execution.
- The rule affects deterministic ordering.
- The rule uses registered hooks during command/resolver paths.
- The rule creates observer followups or delayed effects.

### Networking Evidence

Networking evidence is required when:

- The rule affects state snapshots.
- The rule affects command sync.
- The rule affects setup package handoff.
- The rule affects reconnect projection.
- The rule depends on static catalog consistency between peers.

### Visibility Evidence

Visibility evidence is required when:

- The rule adds private or owner-only state.
- The rule touches facedown damage, command dials, hidden setup choices, private payloads, or observer-specific data.
- The rule adds `InteractionFlow.payload` fields that are not public.

## 9. Status Model

This contract needs a capability-backed status model. The exact storage format is deferred.

### Alternatives Considered

| Model | Description | Strengths | Weaknesses |
| --- | --- | --- | --- |
| Simple lifecycle | Draft -> Identified -> Implemented -> Tested -> Integrated | Easy to understand; lightweight | Does not expose save/replay/network/visibility gaps clearly |
| Surface-tier model | Static, Loaded, Runtime Active, Validation Covered, UI Visible, Save Safe, Replay Safe, Network Safe, Tested, Integrated | Precise evidence tracking; aligns with ADR-003-B | Can become heavy and noisy for simple rules |
| Hybrid lifecycle with surface checklist | Uses simple public lifecycle while each status is backed by required surface checklist evidence | Balanced; readable; supports large content growth | Requires discipline so checklist evidence stays current |

### Recommended Status Model

Use the hybrid lifecycle with surface checklist evidence.

Recommended statuses:

| Status | Meaning |
| --- | --- |
| Draft | Capability package exists but evidence is incomplete or still being gathered. |
| Identified | Source, scope, and applicable surfaces are identified. |
| Implemented | Required implementation surfaces exist for active behavior. |
| Tested | Required tests exist and pass for applicable surfaces. |
| Integrated | Capability package is complete, tests pass, metadata/status claims are aligned, and all applicable surfaces are covered. |

Rules:

- `Integrated` requires the full integration checklist.
- `Tested` does not automatically mean `Integrated` if metadata, visibility, replay, network, or serialization evidence is missing.
- `Implemented` does not automatically mean `Tested`.
- Static-only records should not use `Integrated` for gameplay behavior.
- Existing `NOT_INTEGRATED`, `PARTIAL`, and `INTEGRATED` metadata values remain migration-era claims until mapped to this model.

## 10. Package Granularity

One game component may contain multiple capability packages.

Capability packages should describe one coherent behavior slice. A coherent behavior slice is a unit of behavior that can be traced, reviewed, implemented, tested, and approved without requiring unrelated behavior to be completed at the same time.

Examples:

| Component type | Possible capability package slices |
| --- | --- |
| Objective | Setup behavior; runtime scoring; special effects. |
| Damage card | Immediate effects; persistent effects. |
| Upgrade | Roster legality; command mutation; attack modifier; token interaction. |
| Ship or squadron ability | Static keyword behavior; named special behavior; mutable state behavior. |

Packages should optimize:

- Traceability.
- Reviewability.
- Implementation ownership.

Avoid combining independent behavior into a single large package only because the behavior comes from the same card or component.

## 11. Package Indexing

Capability packages should remain independently discoverable as rule content grows.

Capability packages should be indexable by:

- Package ID.
- Component Type.
- Source ID.
- Status.
- Related ADR.
- Related Contract.
- Related Tests.

Avoid creating one large capability package document.

Independent behavior should remain independently discoverable.

## 12. Approval Workflow

Keep the workflow lightweight.

### Creation

Capability packages may be created by:

- The feature implementer.
- A maintainer.
- Codex when explicitly asked to prepare rule integration evidence.

### Review

Review should include:

- Architecture owner or subsystem owner for behavior-changing rules.
- Test owner when test coverage is affected.
- Network/visibility owner when hidden information or network sync is affected.
- Setup/fleet owner when setup package or fleet validation is affected.

### Required Updates

A package must be updated when:

- A rule changes behavior.
- A new implementation surface is added.
- A command/resolver/setup/projection path changes.
- Serialization, replay, network, or visibility behavior changes.
- Metadata status changes.
- Tests are added, removed, renamed, or materially changed.
- The package status changes.

### Exceptions

Temporary exceptions are allowed only with owner direction and must be recorded in the package.

## 13. Approval Rules

`Integrated` requires explicit owner approval.

Mixed rules require review by every affected responsibility owner.

Replay, networking, visibility, and save/load impacts require explicit review whenever applicable.

Codex may never mark a package as `Integrated`.

Codex may only recommend readiness for owner review.

## 14. Transitional Test Policy

Until TEST-003 is accepted:

- Capability packages must list all applicable tests.
- The owner determines whether the listed evidence is sufficient for the package's current status.
- Validation slices are allowed.
- Broad rollout remains prohibited.

This policy expires automatically once TEST-003 is accepted.

## 15. Metadata Synchronization

Metadata status claims may never advance beyond capability package evidence.

If metadata and capability evidence disagree, capability package evidence is authoritative.

Existing catalog metadata and status fields remain migration-era status claims until they are mapped to capability-backed semantics.

## 16. Codex Requirements

Before implementing or modifying a behavior-changing rule, Codex must identify:

- Rule source and component category.
- Whether the rule is simple or mixed.
- Active state owner or not-applicable rationale.
- Validation owner or not-applicable rationale.
- Execution owner.
- Projection impact.
- Serialization impact.
- Replay impact.
- Network/reconnect impact.
- Visibility impact.
- Required tests.
- Existing metadata/status claims that may need alignment.

Codex must never assume:

- Static JSON means behavior is active.
- Metadata status proves integration.
- `implemented_rule_ids` proves execution.
- `rule_surfaces` proves call-site coverage.
- `runtime_state_requirements` proves state exists or serializes.
- `RuleRegistry` registration proves integration.
- UI affordance proves command legality.
- A rule can skip replay/network/visibility review because it appears local.
- ADR-003 acceptance authorizes broad behavior-changing rollout without CON-003 and TEST-003.

If required ownership or evidence cannot be determined, Codex must stop and ask for owner guidance before implementation.

## 17. Contract Validation Examples

These examples validate the contract.

They are not gameplay documentation.

### Example A - Backward Validation: Ruptured Engine Damage Card

Selected existing implementation: `Ruptured Engine`, a persistent ship damage-card rule.

Capability package slice:

- A capability package would describe the Ruptured Engine persistent post-maneuver damage behavior.
- The package would not own generic damage-card loading, generic maneuver execution, or unrelated persistent damage-card effects.
- The package would normally live under `docs/architecture/capability_packages/`.
- A filename is not defined by this contract.

Source static data:

- `Resources/Game_Components/damage_cards.json` contains the `Ruptured Engine` card text and `effect_id: "ruptured_engine"`.
- `Resources/Game_Components/damage_deck/damage_deck_composition.txt` records the deck composition and rules note for Ruptured Engine.

Responsibility owners:

| Responsibility | Observed owner |
| --- | --- |
| Active state owner | `ShipInstance.faceup_damage`, `ShipInstance.facedown_damage`, `DamageCard.effect_id`, and `DamageDeck`. |
| Validation owner | `PersistentEffectDamageCommand.validate`; maneuver legality remains owned by `ExecuteManeuverCommand` and normal command applicability. |
| Execution owner | `RupturedEngine.observe_execute_maneuver`, `CommandProcessor` observer follow-up drainage, and `PersistentEffectDamageCommand.execute`. |
| Rule hook owner | `RuleRegistry` / `RuleSurface` observer on `SHIP_ACTIVATION / MANEUVER_STEP / COMMAND_EXECUTE_MANEUVER`. |
| Projection owner | `ManeuverRuleResolver.preview_maneuver_damage_effect_ids` and `ShipActivationController` maneuver warning text. |
| Serialization owner | `DamageCard.serialize`, `ShipInstance` damage-card serialization, `GameState.serialize`, and `PersistentEffectDamageCommand.serialize`. |
| Replay owner | `CommandProcessor` command history and replay of `execute_maneuver` plus `persistent_effect_damage` follow-up commands. |
| Network/reconnect owner | Command sync and remote command handling for maneuver and persistent-effect damage commands; reconnect relies on serialized ship damage state and projected interaction state. |
| Visibility owner | Faceup Ruptured Engine is public damage-card state; the added facedown damage card remains represented as facedown damage state. |

Implementation surfaces:

- `src/core/effects/rules/damage_cards/ship/ruptured_engine.gd` registers the observer hook and returns a `PersistentEffectDamageCommand` when the damaged ship executes a speed greater than 1 maneuver.
- `src/autoload/rule_bootstrap.gd` preloads and registers the Ruptured Engine rule script with the other production rule scripts.
- `src/autoload/command_processor.gd` collects observer follow-ups after command execution and records follow-up commands in command history.
- `src/core/commands/persistent_effect_damage_command.gd` validates the effect id, draws or deserializes the facedown damage card, mutates ship damage state, and returns serialized result data.
- `src/core/movement/maneuver_rule_resolver.gd` provides non-mutating preview ids for post-maneuver damage effects.
- `src/scenes/game_board/ship_activation_controller.gd` uses the maneuver resolver preview to show a maneuver warning before commit.

Implementation evidence:

- `tests/unit/test_rule_ruptured_engine.gd` verifies RuleRegistry observer registration, speed greater than 1 follow-up creation, facedown damage draw, command-processor follow-up recording, speed 1 non-trigger behavior, and post-save/load behavior.
- `tests/unit/test_rule_bootstrap.gd` verifies production bootstrap registers maneuver observer hooks.
- `tests/unit/test_p6_commands.gd` verifies `PersistentEffectDamageCommand` execution, valid effect ids, draw-from-deck behavior, and serialize/deserialize behavior.
- `tests/unit/test_maneuver_rule_resolver.gd` verifies Ruptured Engine preview ids.
- `tests/unit/test_activation_modal.gd` verifies maneuver warning presentation.
- `tests/unit/test_resolve_damage_command.gd`, `tests/unit/test_ship_instance.gd`, and `tests/unit/test_save_load_round_trip.gd` provide supporting evidence for damage-card state, faceup damage persistence, and save/load behavior.

Required tests:

- Static damage-card loading/schema tests.
- Rule bootstrap and observer registration tests.
- Observer follow-up tests for speed greater than 1 and speed 1.
- Command validation and execution tests for `PersistentEffectDamageCommand`.
- Command-history/replay-oriented tests proving the follow-up command is recorded after the triggering maneuver command.
- Save/load tests proving faceup Ruptured Engine still triggers after serialization round-trip.
- Projection tests for maneuver warnings.
- Network/reconnect tests where live peer command sync or reconnect projection is affected.
- Visibility tests only if future behavior exposes private payloads beyond public faceup/facedown damage state.

Serialization impact:

- Active source state is the faceup `DamageCard` on `ShipInstance`.
- Resulting damage is persisted through `ShipInstance.facedown_damage`.
- The follow-up command payload stores `effect_id`, ship identity, and either serialized `card_data` or `draw_from_deck` behavior.

Replay impact:

- The triggering `execute_maneuver` command and resulting `persistent_effect_damage` follow-up are recorded in command history.
- `PersistentEffectDamageCommand` includes serialized result data when executed, and command serialization tests cover payload round-trip.
- Determinism depends on command order, damage deck state, and command payload data remaining stable.

Network/reconnect impact:

- Live network behavior depends on the same command and follow-up command path used by command sync.
- Reconnect depends on serialized ship damage state and any active interaction/projection state being reconstructed from the authoritative state.
- CON-003 would require explicit network/reconnect evidence before marking this package `Integrated`.

Visibility impact:

- Ruptured Engine itself is visible because it must be faceup to be active.
- The extra suffered card is added as facedown damage; opponents should see facedown count, not private card identity.
- Current evidence supports public faceup state and facedown damage representation; any owner-only card identity payload would require `InteractionFlow.visible_to` and `StateFilter` evidence.

Projection impact:

- The runtime rule execution does not depend on UI-only predicates.
- The UI preview uses `ManeuverRuleResolver` to warn that committing the maneuver will trigger damage.
- The warning is an affordance; the authoritative mutation remains the observer follow-up command.

Current status under CON-003:

- This implementation should be treated as `Tested`, not automatically `Integrated`.
- It has substantial implementation and test evidence across RuleRegistry, command execution, projection, serialization, and save/load.
- Under CON-003, `Integrated` still requires a capability package, explicit surface review, metadata/status alignment, network/reconnect evidence where applicable, and owner approval.

Would CON-003 have completely described this implementation if it had existed when the rule was originally implemented?

- Yes for capability slicing, active state ownership, hook ownership, command execution, projection, serialization, replay, visibility, and test expectations.
- The example validates why RuleRegistry registration alone is insufficient: the implementation also needs faceup damage state, command follow-up execution, command history, projection warnings, save/load behavior, and owner-reviewed network/reconnect impact.
- CON-003 would also have prevented marking this rule `Integrated` before package evidence and owner approval existed.

Missing contract clauses identified by this example:

- No new CON-003 clauses are required by this example.
- TEST-003 is still needed to define exact test sufficiency for replay and network/reconnect coverage.

Additional lightweight validation candidate: Bomber keyword

- `Bomber` is useful as a narrower RuleRegistry/RuleSurface example because it exposes attack critical/damage modifier surfaces without owning durable runtime state in the same way as a faceup damage card.
- It is less useful than Ruptured Engine as the primary backward validation example because it exercises fewer serialization, replay, and persistent-state concerns.

### Example B - Forward Validation: Future Upgrade That Modifies Attack Dice

Selected future implementation: a hypothetical upgrade that allows an attack dice modifier during a ship attack.

This example is illustrative only. It does not define gameplay.

Capability package creation:

- Create a package under the normal capability package location.
- Scope the package to the upgrade's attack dice modifier behavior.
- Do not include unrelated fleet-building, UI art, or future upgrade behavior unless it is part of the same coherent behavior slice.

Ownership identification:

| Responsibility | Expected identification path |
| --- | --- |
| Static source | Upgrade JSON and typed upgrade model. |
| Active state | Ship/roster upgrade assignment if static assignment is sufficient; otherwise the runtime entity/state class that owns mutable upgrade state. |
| Validation | Attack command validation or attack-flow legality owner if the modifier can be selected, allowed, blocked, or constrained. |
| Execution | Attack command, attack resolver, dice pool resolver, or accepted `RuleRegistry`/`RuleSurface` call site. |
| Projection | UI affordance that offers or displays the modifier. |
| Serialization | Any selected modifier, spent/exhausted state, command payload, or durable upgrade state. |
| Replay | Command payload and deterministic dice/result reconstruction. |
| Network | Command sync, state snapshot, and reconnect projection. |
| Visibility | Whether the modifier choice, dice state, or upgrade state is public or owner-only. |

Surface traceability:

- The package must identify whether the attack modifier is command-owned, resolver-owned, hook-owned, or mixed.
- If `RuleRegistry` is used, the package must list both the registration and the accepted call site.
- If the modifier changes command legality, command validation must be listed separately from execution.

Evidence collection:

- Static upgrade JSON and model loader evidence.
- Runtime upgrade assignment or state evidence.
- Attack command/resolver/hook implementation evidence.
- Projection evidence for any UI affordance or prompt.
- Serialization evidence for any command payload, spent state, or persistent upgrade state.
- Replay/network/reconnect evidence where the modifier affects attack outcomes or reconnect UI.
- Visibility evidence if any choice or payload is private.

Test expectations:

- Static loading/schema tests.
- Command legality tests if the modifier can be allowed or blocked.
- Resolver or hook execution tests.
- UI projection tests if the player must see a choice or modifier state.
- Save/load tests if durable state is introduced.
- Replay tests for deterministic attack resolution.
- Network/reconnect tests if live peers or reconnecting viewers must see the same attack state.
- Visibility tests if private payloads are introduced.

Approval process:

- Codex may prepare the package and recommend readiness.
- The owner determines whether evidence is sufficient while TEST-003 is not accepted.
- `Integrated` requires explicit owner approval.
- If the behavior touches attack command validation, resolver execution, UI projection, replay, network, or visibility, affected responsibility owners must review the package.

Was any information missing?

- The contract still does not define exact package filenames or the future reusable template. That is intentional; the minimum required sections are defined here and the template is deferred.
- Detailed test thresholds remain deferred to TEST-003. The transitional policy defines who decides sufficiency until then.

Were any contract clauses ambiguous?

- After these amendments, the main ambiguity is the exact final template/schema, not the required information categories or approval gate.

Could two independent developers produce substantially equivalent capability packages?

- Yes, for ownership, traceability, evidence, status, and review sections.
- Minor formatting differences may remain until the reusable Capability Package Template exists.

Recommended improvements to CON-003 from this example:

- Create the reusable Capability Package Template after CON-003 acceptance.
- Create TEST-003 to replace owner-judged test sufficiency with accepted test obligations.

## 18. Open Questions

These questions require owner decisions or future contract/template work:

- What exact template or schema should be used?
- Should existing metadata statuses be manually mapped, generated, or validated by tests?
- Which rule category should be the first pilot backfill slice?
- Who is the default reviewer for packages that span multiple subsystems?
- What temporary exceptions are acceptable before TEST-003 exists?
- How should catalog versioning for saves, replays, and network peers be represented?

## 19. Validation

### Consistency With ADR-003

Consistent.

This contract preserves ADR-003 decisions:

- Capability packages govern integration.
- `RuleRegistry` is one implementation surface, not the architecture.
- Authority remains delegated by responsibility.
- Integration remains capability-based.
- Metadata reports evidence/status/routing and does not own behavior.
- Broad rollout remains gated by CON-003 and TEST-003.

### Suitability For Large Content Growth

Suitable.

The contract supports large content growth by requiring repeatable traceability and evidence for upgrades, objectives, abilities, damage cards, obstacles, and tokens. The recommended status model avoids a full surface-status explosion while preserving detailed surface evidence in the checklist.

### Codex Friendliness

Strong.

The contract gives Codex explicit pre-implementation questions and explicit assumptions it must not make. It should reduce the main risks identified in CP-001 and ADR-003: metadata-only behavior, uninvoked hooks, UI-only predicates, missing serialization, missing replay/network coverage, and stale status claims.

Confidence score: 8/10.

Confidence is high because CON-003 directly operationalizes accepted ADR-003. It is not higher because TEST-003 does not exist yet, the reusable package template/schema is not chosen, and pilot backfill has not validated the process against real rule work.

### Final Verification

Verified:

- ADR-003 remains unchanged.
- No authority boundaries changed.
- No ownership rules changed.
- No integration semantics changed.
- No metadata semantics changed.
- No migration policy changed.

Summary of amendments:

- Added canonical capability package form and default storage convention.
- Added package granularity and indexing requirements.
- Added explicit approval rules for `Integrated`.
- Added transitional test policy until TEST-003 is accepted.
- Added metadata synchronization rule.
- Added backward and forward contract validation examples.

Implementation readiness:

CON-003 is accepted.

Next required artifacts:

- Capability Package Template.
- TEST-003 Capability Verification Strategy.
- Pilot capability package/backfill slice.
