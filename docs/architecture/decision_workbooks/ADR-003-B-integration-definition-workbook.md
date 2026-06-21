# ADR-003-B: Definition of "Integrated" Workbook

Status: Draft decision analysis  
Decision topic: Definition of "Integrated"  
Supports: ADR-003 Rule and Validation Surface Decision  
Primary evidence: CP-001 Game Component Rule Extension Context Pack, Baseline Evidence  
Related workbook: ADR-003-A Rule Ownership Model Workbook  
Related tasks: AT-003, AT-004  
Related boundaries: BC-005, BC-005A, BC-011, BC-012  
Related gaps: RG-005, RG-006, RG-011, RG-013, RG-015

This workbook is not an ADR. It evaluates options for owner decision.

## Decision Question

When may a component rule or special behavior be marked as integrated?

## Owner Direction From ADR-003-A

ADR-003-A records owner direction to adopt a modified Option C/D:

- The controlling model is a rule capability package or contract.
- `RuleRegistry`/`RuleSurface` is a preferred implementation surface only for suitable component-origin predicates, modifiers, enablers, and registered hooks where accepted call sites exist.
- `RuleRegistry` alone does not prove integration.
- Commands, resolvers, setup/fleet validators, state classes, `InteractionFlow` payloads, `UIProjector`, `StateFilter`, and visibility filtering remain valid owners depending on what the rule does.
- "Component rule" describes source/origin, not architectural ownership.
- "Mixed rule" requires explicit surface traceability.

## Evidence Baseline

CP-001 is treated as Baseline Evidence. The current implementation shows:

- Static catalog metadata is schema-backed and visible through loaders/catalogs, but it is descriptive unless consumed by runtime code.
- `rules_integration`, `rule_surfaces`, `runtime_state_requirements`, `implemented_rule_ids`, and `implementation_status` do not by themselves prove active behavior.
- Active behavior is distributed across `RuleRegistry`, `RuleSurface`, commands, resolvers, setup/fleet validators, state classes, `InteractionFlow.payload`, `UIProjector`, `StateFilter`, and UI/presentation paths.
- Registered rules are not serialized. Durable rule inputs must live in serialized `GameState`, `PlayerState`, `ShipInstance`, `SquadronInstance`, setup state, command history, or other JSON-safe runtime data.
- Damage cards demonstrate split integration: persistent effects mostly use registered scripts, while immediate effects use `ResolveImmediateEffectCommand`.
- Existing tests cover static catalog/schema loading, fleet/setup packages, command validation/history, rule bootstrap/surfaces, damage-card rules, squadron keywords, save/load, replay, network, and reconnect, but no accepted per-rule integration test strategy exists yet.

Relevant observed evidence includes:

| Concern | Evidence files/classes |
| --- | --- |
| Static metadata and schema | `Resources/Game_Components/card_data_schema.json`, `Resources/Game_Components/damage_cards.json`, `AssetLoader`, `FleetCatalog` |
| Rule registration and hook surfaces | `RuleBootstrap`, `RuleRegistry`, `RuleSurface`, `tests/unit/test_rule_bootstrap.gd`, `tests/unit/test_rule_surface.gd` |
| Command-owned behavior | `CommandProcessor`, `ResolveImmediateEffectCommand`, `tests/unit/test_resolve_immediate_effect_command.gd`, `tests/unit/test_command_processor_rule_hooks.gd` |
| Resolver-owned behavior | `AttackDiceResolver`, `DefenseTokenResolver`, `RepairResolver`, `ManeuverRuleResolver`, resolver tests |
| Setup/objective/obstacle state | `FleetSetupPackageBuilder`, `SetupInteractionFlowResolver`, setup package and setup validator tests |
| Runtime state and serialization | `GameState`, `PlayerState`, `ShipInstance`, `SquadronInstance`, `InteractionFlow`, `tests/unit/test_save_load_round_trip.gd` |
| Replay and determinism | `CommandProcessor`, `GameReplay`, `tests/unit/test_game_replay.gd`, `tests/integration/test_rule_order_replay.gd` |
| Network/reconnect/visibility | `StateFilter`, `UIProjector`, `NetworkManager`, `tests/unit/test_state_filter.gd`, `tests/unit/test_ui_projector.gd`, `tests/integration/test_reconnection_mid_attack.gd` |

## Option A: Minimal Integration

### Concept

A rule is integrated when static metadata exists and at least one runtime implementation path exists. The implementation path may be a command, resolver, `RuleRegistry` hook, setup validator, projection path, or other active code path.

### Evaluation

| Concern | Evaluation |
| --- | --- |
| Clarity for developers | Simple to understand, but underspecified. Developers can mark a rule integrated without knowing whether all affected surfaces are covered. |
| Codex safety | Low. Codex may add one visible path and miss save/load, replay, network, projection, or validation. |
| Compatibility with ADR-003-A owner direction | Weak. It recognizes non-registry owners, but does not enforce capability-package traceability. |
| Active state requirements | Optional or implicit. Risky for upgrades/objectives that need durable runtime state. |
| Command validation requirements | Not guaranteed. A UI affordance or resolver hook could exist while command validation remains incomplete. |
| Resolver/hook requirements | Requires at least one path, but does not require the correct path or an exercised call site. |
| UI projection requirements | Not guaranteed. Behavior may be active but invisible or misleading in UI. |
| Save/load requirements | Not guaranteed. Runtime-only or local-only behavior could be marked integrated. |
| Replay requirements | Not guaranteed. Determinism and command history are outside the definition. |
| Network/reconnect requirements | Not guaranteed. Hidden or viewer-specific behavior could break reconnect. |
| Hidden-information requirements | Not guaranteed. `StateFilter` and `InteractionFlow.visible_to` may be skipped. |
| Test obligations | Minimal. A single focused test may be considered enough. |
| Schema/metadata implications | Allows `rules_integration.status` or `implementation_status` to drift toward optimistic reporting. |
| Migration effort | Low. Few existing records need restructuring. |

### Fit

This option is useful as a temporary "partially active" status, but it is too weak for the final meaning of integrated.

## Option B: Hook-Based Integration

### Concept

A rule is integrated when it has a registered `RuleRegistry`/`RuleSurface` hook and at least one exercised call site. The hook must be invoked by a command, resolver, projection path, or other runtime path.

### Evaluation

| Concern | Evaluation |
| --- | --- |
| Clarity for developers | Clear for hook-shaped rules. Poor for command-owned immediate effects, setup/objective state, hidden information, and resolver-owned mechanics. |
| Codex safety | Medium. Better than metadata-only because hooks need call sites, but Codex may force non-hook behavior into `RuleRegistry`. |
| Compatibility with ADR-003-A owner direction | Partial. ADR-003-A says `RuleRegistry` is preferred for suitable component-origin behavior, not default ownership for all behavior. |
| Active state requirements | Must be declared outside the hook. Registry registration does not identify durable source state by itself. |
| Command validation requirements | Only covered if command validation invokes the hook or a command-specific validator is also implemented. |
| Resolver/hook requirements | Strong for registered modifiers/blockers/enablers with accepted call sites. |
| UI projection requirements | Covered only when projection invokes registry enablers or documented projection code exists. |
| Save/load requirements | Not proven by hook registration. Active source state and deterministic bootstrap still need separate evidence. |
| Replay requirements | Hook invocation must be deterministic and exercised through command replay; hook tests alone are insufficient. |
| Network/reconnect requirements | Not proven. Hook output that affects payloads or affordances still needs filtering/projection evidence. |
| Hidden-information requirements | Weak unless the hook is explicitly connected to `StateFilter`, `InteractionFlow.visible_to`, or projection tests. |
| Test obligations | Requires registration and invocation tests, but may omit end-to-end command/save/replay/network tests. |
| Schema/metadata implications | Could make `implemented_rule_ids` easier to validate, but risks treating hook presence as behavior completeness. |
| Migration effort | Medium-high if non-hook rules must be wrapped or represented as hooks. |

### Fit

This option is suitable as one integration tier for hook-shaped behavior. It should not be the general definition of integrated.

## Option C: Capability-Package Integration

### Concept

A rule is integrated only when a capability package identifies all required implementation surfaces and required tests for that rule. The package records what the rule does and names the applicable owners: static metadata, active state, validation, command mutation, resolver/hook execution, projection, serialization, replay, network/reconnect, hidden information, and tests.

### Evaluation

| Concern | Evaluation |
| --- | --- |
| Clarity for developers | High once the package template exists. Developers know which surfaces must be checked before claiming integration. |
| Codex safety | High. Codex has an explicit checklist and cannot infer integration from metadata or a single hook. |
| Compatibility with ADR-003-A owner direction | Strong. This is the controlling model requested by ADR-003-A owner direction. |
| Active state requirements | Explicit. Package must name durable source state or mark state as not applicable with rationale. |
| Command validation requirements | Explicit. Package must identify command validation/preflight impact or state why none is needed. |
| Resolver/hook requirements | Explicit. Package can name `RuleRegistry`/`RuleSurface`, command logic, resolver logic, setup logic, or another active execution owner. |
| UI projection requirements | Explicit. Package must identify projection/affordance impact or declare no visible UI effect. |
| Save/load requirements | Explicit. Package must state serialized fields and round-trip evidence where durable state exists. |
| Replay requirements | Explicit. Package must state replay requirements for command-driven or deterministic behavior. |
| Network/reconnect requirements | Explicit. Package must state snapshot, command sync, reconnect, and projection requirements where applicable. |
| Hidden-information requirements | Explicit. Package must state visibility handling when rule state or payload data is private, owner-only, observer-specific, or public. |
| Test obligations | Explicit. Package defines required unit/integration categories and names accepted test evidence. |
| Schema/metadata implications | Metadata fields can reference package status, but cannot be proof by themselves. |
| Migration effort | Medium. Existing rules need package records over time, but behavior does not need an immediate rewrite. |

### Fit

This option best matches the owner direction and the observed hybrid implementation. Its main weakness is process overhead unless paired with a concise template and status model.

## Option D: Tiered Integration

### Concept

Rules move through explicit statuses, such as Static, Loaded, Runtime Active, UI Visible, Tested, Save/Replay Safe, Network Safe, and Integrated. A rule can be partially implemented without being marked fully integrated.

### Evaluation

| Concern | Evaluation |
| --- | --- |
| Clarity for developers | High if statuses are precise. Developers can distinguish static data from executable, tested, durable behavior. |
| Codex safety | High. Codex can report the current tier instead of overstating integration. |
| Compatibility with ADR-003-A owner direction | Strong if tiers are backed by capability packages. Weak if tiers become free-form metadata only. |
| Active state requirements | Covered by Runtime Active and Save/Replay Safe tiers. |
| Command validation requirements | Needs an explicit Validation Covered tier or checklist item; otherwise validation can be missed. |
| Resolver/hook requirements | Covered by Runtime Active when an exercised execution path is required. |
| UI projection requirements | Covered by UI Visible, but UI visibility must not imply authoritative behavior. |
| Save/load requirements | Covered by Save/Replay Safe or separate Save Safe tier. |
| Replay requirements | Covered by Save/Replay Safe or separate Replay Safe tier. |
| Network/reconnect requirements | Covered by Network Safe. |
| Hidden-information requirements | Needs explicit Hidden-Information Safe or must be included in Network Safe. |
| Test obligations | Needs a Tested tier, but the tier must identify which tests were run for which surfaces. |
| Schema/metadata implications | Strong for catalog/status UI, provided statuses are derived from package evidence rather than manually asserted. |
| Migration effort | Medium-high. Existing metadata/status fields may need remapping to avoid misleading users. |

### Fit

This option is useful as the reporting/status layer for Option C. It is not enough by itself unless each tier is backed by capability-package evidence.

## Comparative Summary

| Option | Developer clarity | Codex safety | Owner-direction fit | Migration effort | Main risk |
| --- | --- | --- | --- | --- | --- |
| A. Minimal integration | Medium | Low | Weak | Low | Marks partial behavior as complete |
| B. Hook-based integration | Medium | Medium | Partial | Medium-high | Treats registry hooks as ownership proof |
| C. Capability-package integration | High | High | Strong | Medium | Process overhead |
| D. Tiered integration | High | High | Strong when package-backed | Medium-high | Status labels drift from evidence |

## Recommended Definition of "Integrated"

Recommended for owner consideration:

A component rule or special behavior may be marked integrated only when a rule capability package identifies every applicable behavior surface and provides evidence that each applicable surface is implemented and tested.

Integration does not require every rule to use `RuleRegistry`. Integration does require that the owning implementation surfaces are explicit. For a simple passive rule, the applicable surfaces may be few. For a mixed rule, the package may need to cover active state, command validation, resolver execution, projection, serialization, replay, network/reconnect, hidden information, and tests.

Static metadata, loaded catalog records, printed text, `rules_integration.status`, `implemented_rule_ids`, or `RuleRegistry` registration alone are not sufficient evidence of integration.

## Proposed Checklist And Status Model

### Capability Checklist

Each behavior-changing rule should identify:

- Rule identity: stable id, component source, affected component category, related static metadata.
- Rule type: passive modifier, validator, enabler, command mutation, resolver calculation, setup lifecycle effect, hidden-information effect, UI-only preview, or mixed rule.
- Active state: durable source of truth or explicit "no durable state required" rationale.
- Validation owner: command, setup/fleet validator, resolver guard, registry blocker, or not applicable.
- Execution owner: command mutation, resolver logic, `RuleRegistry`/`RuleSurface` hook, setup flow, state class behavior, or other path.
- Projection owner: `UIProjector`, `InteractionFlow.payload`, UI controller, or no visible projection.
- Serialization: fields included in save/load or explicit "derived from static/runtime state" rationale.
- Replay: command-history and deterministic-order evidence or explicit non-replay-affecting rationale.
- Network/reconnect: snapshot, command sync, projection, and reconnect evidence where applicable.
- Hidden information: visibility classification, `InteractionFlow.visible_to`, `StateFilter`, observer impact, or public-only rationale.
- Tests: required unit/integration tests and existing evidence.

### Suggested Statuses

| Status | Meaning | May be shown as integrated? |
| --- | --- | --- |
| Static | Static component metadata exists. | No |
| Loaded | Loader/model/catalog path accepts and exposes the data. | No |
| Runtime Active | Runtime code can execute or consume the behavior in at least one path. | No |
| Validation Covered | Command/setup/fleet/resolver validation impact is implemented or explicitly not applicable. | No |
| UI Visible | Player-facing projection/affordance is implemented where applicable. | No |
| Save Safe | Durable state round-trips or is explicitly derived. | No |
| Replay Safe | Command/replay determinism is covered where applicable. | No |
| Network Safe | Sync/reconnect/visibility behavior is covered where applicable. | No |
| Tested | Required tests for applicable surfaces exist and pass. | No |
| Integrated | Capability package is complete and all applicable statuses are satisfied. | Yes |

Status fields should be derived from, or at least traceable to, capability-package evidence. They should not be manually asserted without evidence references.

## Strongest Argument Against The Recommendation

The recommended model introduces governance overhead before any code improvement. For simple rules, a capability package can feel heavier than the implementation. If the package template is too large or mandatory fields are not scoped by rule type, developers and Codex may produce mechanical paperwork rather than useful integration evidence.

The mitigation is to make the package checklist conditional: every rule must explicitly consider the surfaces, but simple rules may mark many surfaces as not applicable with rationale.

## Owner Questions

- Should ADR-003-B define one `Integrated` status, or separate public statuses such as `Runtime Active`, `Tested`, `Network Safe`, and `Integrated`?
- Which capability-package fields are mandatory for every behavior-changing rule?
- Which fields may be marked not applicable, and what rationale is sufficient?
- Should static catalog metadata include references to capability-package ids once CON-003 exists?
- Should `rules_integration.status` be replaced, constrained, or mapped to the new status model?
- What minimum tests are required before a rule can be marked `Integrated`?
- Should save/load, replay, and network tests be mandatory for every rule, or only for rules with durable state, commands, hidden information, or projection impact?
- Who owns review of a capability package: architecture owner, subsystem owner, or feature implementer?
- Should existing damage-card and squadron keyword rules be backfilled into the new model before new component categories are implemented?
- Which rule category should be used as the first CON-003 validation slice?

## Implications For CON-003 Rule Capability Contract

CON-003 should define the concrete artifact that proves integration. Based on this workbook, CON-003 likely needs:

- A capability-package template with stable ids and related component/static metadata references.
- A surface applicability matrix for active state, validation, execution, projection, serialization, replay, network/reconnect, hidden information, and tests.
- Rules for when `RuleRegistry`/`RuleSurface` is an accepted implementation surface and when command/resolver/setup/state ownership is valid.
- A status model that distinguishes static content, loaded content, runtime-active behavior, tested behavior, save/replay/network-safe behavior, and fully integrated behavior.
- Evidence requirements for each status.
- Guardrails preventing static metadata, UI-only predicates, uninvoked hooks, or untested runtime paths from being marked integrated.
- A migration rule for existing behavior: backfill capability packages incrementally, prioritizing new component rules, touched rules, and high-risk mixed rules.

CON-003 should not require large refactoring by itself. Its primary role should be to define what evidence must exist before a rule or special behavior can be called integrated.
