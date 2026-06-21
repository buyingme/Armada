# ADR-003-D: Metadata Semantics Workbook

Status: Draft decision analysis  
Decision topic: Metadata Semantics For Rule Capability Evidence  
Supports: ADR-003 Rule and Validation Surface Decision  
Primary inputs: ADR-003 Direction Summary, ADR-003-C, ADR-003-A, ADR-003-B, CP-001 Game Component Rule Extension Context Pack  
Related tasks: AT-003, AT-004  
Related boundaries: BC-005, BC-005A, BC-011, BC-012  
Related gaps: RG-005, RG-006, RG-011, RG-013, RG-015

This workbook is not an ADR. It does not create CON-003. It analyzes how metadata should represent capability evidence, implementation status, routing information, and integration progress without becoming the owner of behavior.

## Locked Decisions

The following decisions are treated as fixed inputs:

- Capability Package is the governing model.
- Integration is capability-based.
- `RuleRegistry` is not the architecture.
- Authority boundaries from ADR-003-C are accepted as this workbook's input.
- Metadata is not proof of integration.
- ADR-003-A, ADR-003-B, and ADR-003-C are not reopened here.

## Decision Question

How should metadata represent capability evidence, implementation status, routing information, and integration progress without becoming the owner of behavior?

## 1. Current Metadata Landscape

| Metadata | Current meaning | Current usage | Current risks | Evidence source |
| --- | --- | --- | --- | --- |
| `rules_integration` | Component-level integration metadata with `status`, `implemented_rule_ids`, `pending_rule_surfaces`, and `notes` | Required by schema for many component records; parsed into `ShipData`, `SquadronData`, `UpgradeData`, `ObjectiveData`, and `ObstacleData`; exposed by `FleetCatalog` as `rules_integration_status` | README wording currently links integration to `RuleRegistry` ids, which is narrower than ADR-003 direction; status can imply behavior is live without capability evidence | `card_data_schema.json`; component model classes; `FleetCatalog`; CP-001; `Resources/Game_Components/README.md` |
| `implemented_rule_ids` inside `rules_integration` | Static list of implemented rule ids associated with a component | Used as JSON/catalog metadata; currently often understood as matching `RuleRegistry` ids | Can imply a hook exists, is invoked, and is complete; does not describe command/resolver/setup/projection/state ownership | `card_data_schema.json`; component JSON; CP-001 |
| `implemented_rule_ids` on rules-reference records | Static list of implemented ids for a rules-reference display/search record | Parsed by `RuleReferenceData`; tests require generic keyword rule-reference records to include ids | Useful display link, but not behavior authority; can overstate coverage if ids are not backed by capability evidence | `RuleReferenceData`; `Resources/Game_Components/rules/README.md`; `test_component_catalog_schema_contract.gd` |
| `implementation_status` | Rules-reference implementation status: `NOT_INTEGRATED`, `PARTIAL`, or `INTEGRATED` | Parsed by `RuleReferenceData`; exposed in `FleetCatalog`; filterable in fleet builder | Current tests expect some rules-reference records to be `INTEGRATED`, but status is not derived from a capability package today | `RuleReferenceData`; `FleetCatalog`; `test_component_catalog_schema_contract.gd`; `test_fleet_catalog.gd` |
| `rule_surfaces` | Declared surfaces where a component's behavior may apply | Parsed into squadron, upgrade, and objective models; tested as loaded metadata | Declared surface is not proof of an implemented or invoked surface; may mix intended routing with verified execution | `SquadronData`, `UpgradeData`, `ObjectiveData`; `test_upgrade_data.gd`; CP-001 |
| `pending_rule_surfaces` | Declared surfaces still pending inside `rules_integration` | Stored in component JSON and schema; surfaced as metadata | Can become stale if implementation changes but metadata is not updated; does not specify owner or test obligation | `card_data_schema.json`; component JSON; CP-001 |
| `runtime_state_requirements` | Declared state requirements for behavior-changing content | Parsed into squadron, upgrade, and objective models; objective requirements are copied into objective setup state by `FleetSetupPackageBuilder` | Requirement declaration does not prove state exists or serializes; objective setup use is active scaffolding but not generalized rule execution | `ObjectiveData`; `FleetSetupPackageBuilder._objective_setup_state()`; CP-001 |
| Catalog status fields | Flattened `rules_integration_status` or `implementation_status` for search/filter/display | `FleetCatalog` maps component status fields and rules-reference status fields into catalog entries; fleet builder filters them | Display/filter convenience can be mistaken for behavior authority; status source is static metadata today | `FleetCatalog`; `FleetBuilder`; fleet catalog tests |
| Rules-reference records | Static display/search records for generic or component-specific rules | Loaded by `AssetLoader`, parsed by `RuleReferenceData`, displayed/searched in fleet builder | Not executable; implemented ids/status can imply runtime behavior unless linked to capability evidence | `Resources/Game_Components/rules/README.md`; `RuleReferenceData`; CP-001 |

Current summary:
The metadata is schema-backed, loaded, visible, and partially tested. It is not currently runtime-enforced. Some existing documentation and tests still use older language where `INTEGRATED` means implemented through registered rule ids; ADR-003 direction narrows this to evidence/status reporting only unless backed by capability evidence.

## 2. Metadata Models

### Option A: Pure Descriptive Metadata

Concept:
Metadata remains manually authored descriptive information. It can say what a rule is about, where it may apply, and whether someone believes it is integrated, but runtime code and tests do not derive truth from it.

| Concern | Evaluation |
| --- | --- |
| Clarity | Medium. Easy to explain, but status fields are easy to overread. |
| Maintainability | Medium. Minimal machinery, but drift grows with content volume. |
| Codex safety | Low-medium. Codex may trust stale metadata or update metadata without behavior. |
| Migration effort | Low. Current files mostly fit. |
| Risk of status drift | High. Manual status can diverge from capability evidence. |
| Support for large content growth | Weak. 100 upgrades and 50 objectives would make manual status unreliable. |

Fit:
Acceptable for printed text and search metadata. Too weak for integration status.

### Option B: Documentation Metadata Plus Test Validation

Concept:
Metadata remains authored in JSON, but tests validate selected claims. For example, a status or implemented id must correspond to known tests, registered hooks, or expected component categories.

| Concern | Evaluation |
| --- | --- |
| Clarity | Medium-high. Metadata is still human-readable and selected claims are checked. |
| Maintainability | Medium. Tests reduce drift but can become broad and brittle. |
| Codex safety | Medium-high. Codex gets failures when obvious metadata claims are unsupported. |
| Migration effort | Medium. Existing schema/catalog tests can be extended incrementally. |
| Risk of status drift | Medium. Tests catch known claims but may not verify all surfaces. |
| Support for large content growth | Medium. Works if tests are generated or table-driven; weak if handcrafted per rule. |

Fit:
Useful transitional model, especially before CON-003 exists. It does not fully encode capability-package semantics by itself.

### Option C: Capability-Derived Status Model

Concept:
Metadata status fields are derived from, or explicitly traceable to, a capability package. JSON can still carry display/search/routing metadata, but integration status must be backed by package evidence for active state, validation, execution, projection, serialization, replay/network, visibility, and tests where applicable.

| Concern | Evaluation |
| --- | --- |
| Clarity | High. Metadata reports evidence; capability package owns completeness. |
| Maintainability | High if package/status rules are concise. |
| Codex safety | High. Codex must verify capability evidence instead of trusting static metadata. |
| Migration effort | Medium. Existing statuses need mapping and backfill over time. |
| Risk of status drift | Low-medium. Drift remains possible if statuses are not generated, but traceability makes it visible. |
| Support for large content growth | Strong. New content can progress through explicit statuses without pretending to be integrated. |

Fit:
Recommended for owner consideration. It matches ADR-003-A/B/C direction.

### Option D: Runtime-Enforced Metadata Model

Concept:
Runtime systems consume metadata directly to decide behavior ownership, hook routing, validation, projection, serialization, or status. Metadata becomes an executable or enforcement input.

| Concern | Evaluation |
| --- | --- |
| Clarity | Mixed. Central metadata may look clear, but it blurs data description and runtime behavior. |
| Maintainability | Medium-low. Runtime systems become coupled to catalog schema and versioning. |
| Codex safety | Medium. Codex may add metadata and accidentally alter behavior without code review. |
| Migration effort | High. Existing commands/resolvers/state/projection paths would need metadata-driven enforcement layers. |
| Risk of status drift | Low for enforced fields, but high risk of incorrect runtime coupling. |
| Support for large content growth | Potentially strong long term, but risky before capability contracts and versioning exist. |

Fit:
Not recommended for ADR-003. Some generated validation may be useful later, but metadata should not become behavior authority during the current migration.

## 3. Status Model Analysis

| Status | Precise meaning | Evidence required | Who supplies evidence | Who verifies evidence |
| --- | --- | --- | --- | --- |
| Static | Static JSON or rules-reference record exists and passes schema/parse expectations | Component JSON, schema validation, loader/model parse evidence | Content author or implementer | Schema/catalog tests |
| Loaded | Asset loader/model/catalog path exposes the data to fleet builder or setup code | Loader/model tests, catalog entry evidence | Implementer | Loader/catalog tests |
| Runtime Active | Runtime code can execute or consume the behavior in at least one active path | Command, resolver, setup flow, `RuleSurface` call site, state mutation, or projection evidence | Implementer | Focused runtime tests |
| Validation Covered | Command/setup/fleet/resolver legality impact is implemented or explicitly not applicable | Validation owner named in capability package; validation tests or not-applicable rationale | Implementer with subsystem owner | Command/setup/fleet/resolver tests |
| UI Visible | Player-facing affordance/projection is implemented where applicable | `UIProjector`, `InteractionFlow.payload`, UI controller, or "not visible" rationale | Implementer | Projection/UI tests |
| Save Safe | Durable state round-trips through serialization or is explicitly derived | Serialized fields, save/load tests, or derived-state rationale | Implementer | Save/load tests |
| Replay Safe | Behavior is deterministic through command replay where applicable | Command history evidence, replay tests, deterministic hook/order tests | Implementer | Replay tests |
| Network Safe | Behavior survives command sync, snapshots, reconnect, and visibility filtering where applicable | Network/reconnect tests, `StateFilter` classification, projection evidence | Implementer with network/visibility owner | Network/reconnect tests |
| Tested | Required tests for applicable surfaces exist and pass | Test list tied to capability package | Implementer | CI/test suite and reviewer |
| Integrated | Capability package is complete and all applicable statuses are satisfied | Complete package evidence across applicable surfaces; all required tests passing | Implementer and package owner | Owner/reviewer plus tests |

Status semantics:
Statuses are evidence states, not behavior owners. `Integrated` is the only final status. Intermediate statuses can be useful for catalog progress and planning, but must not imply complete behavior.

## 4. Metadata Ownership Rules

| Metadata field | Classification | Owner/maintainer | Semantics |
| --- | --- | --- | --- |
| `data_key`, `kind`, names, costs, printed stats, art paths | Descriptive | Content author; schema tests verify shape | Static catalog identity/display facts |
| `rules_reference_ids` | Descriptive | Content author; catalog tests verify references where available | Links component to static rules-reference records |
| Ability/effect/setup/scoring text | Descriptive | Content author | Printed text and search/display source, not executable behavior |
| `rules_integration.status` | Capability-derived once CON-003 exists; currently owner-maintained descriptive metadata | During migration: content/architecture owner; future: capability package/status process | Should report capability evidence, not own behavior |
| `rules_integration.implemented_rule_ids` | Capability-derived or owner-maintained routing/evidence link | During migration: implementer/content owner; future: capability package/status process | May link to rule ids or behavior ids, but should not imply registry-only ownership |
| `rules_integration.pending_rule_surfaces` | Owner-maintained planning/routing metadata | Content/architecture owner | Declares intended or pending surfaces; not evidence of implementation |
| `rules_integration.notes` | Descriptive/owner-maintained | Content/architecture owner | Human context and migration notes |
| `rule_surfaces` | Owner-maintained routing metadata; future capability-derived evidence if verified | Content/architecture owner; future package owner | Must distinguish declared/intended surfaces from implemented/verified surfaces |
| `runtime_state_requirements` | Owner-maintained requirement metadata; future capability-derived when linked to state evidence | Content/architecture owner; future package owner | Declares required state; not proof state exists or serializes |
| Rules-reference `implemented_rule_ids` | Capability-derived evidence link for implemented generic/component rules | Content/architecture owner; future package owner | Should link to capability/package behavior ids, not only `RuleRegistry` ids |
| Rules-reference `implementation_status` | Capability-derived once CON-003 exists; currently owner-maintained descriptive status | During migration: content/architecture owner; future package/status process | Reports display/search implementation status; not executable authority |
| Catalog `rules_integration_status` | Generated from loaded component metadata today; future derived from capability status | `FleetCatalog` generation from resource data | Display/filter field only |
| Catalog `implementation_status` | Generated from rules-reference metadata today; future derived from capability status | `FleetCatalog` generation from `RuleReferenceData` | Display/filter field only |
| Test evidence references | Test-derived | Test author/implementer | Should identify which tests verify the status claim |
| Capability package id | Capability-derived | Package owner | Stable traceability id once CON-003 exists |

## 5. Codex Safety Analysis

| Future task | Metadata Codex may trust | Metadata Codex must verify | Metadata that may be stale | Required guardrails |
| --- | --- | --- | --- | --- |
| Add upgrade | Static identity, printed text, cost, slot, restrictions, declared rule metadata shape | Whether `rules_integration.status`, `rule_surfaces`, and `runtime_state_requirements` match active runtime behavior | Pending surfaces, implemented ids, integration status, runtime-state requirements | Do not mark integrated from JSON alone; identify active state owner, command/resolver/hook/projection path, serialization, replay/network, and tests |
| Add objective | Objective identity, category, setup/scoring text, declared setup effects, schema validity | Whether setup scaffolding, runtime scoring, objective tokens, projection, and network behavior exist | Status, pending surfaces, runtime-state requirements | Separate setup metadata from runtime behavior; verify `GameState.objectives` state and setup/runtime tests |
| Add damage card | Static card text/effect id and damage-card catalog shape | Whether effect id maps to registered persistent hook, immediate command, resolver behavior, or intentionally passive behavior | Integrated status or implemented ids if not backed by tests | Verify faceup/facedown state, command/history path for immediate effects, hook call sites for persistent effects, visibility filtering, save/load/replay |
| Add ship ability | Ship identity, printed special-rule text, declared metadata | Whether named ability has active state, execution owner, projection, and tests | `rules_integration.status`, declared surfaces, printed text | Treat as component-origin mixed rule; do not infer active behavior from ship JSON |

General Codex rules:

- Trust metadata for catalog identity and display facts only.
- Verify metadata status claims against capability evidence before relying on them.
- Treat `INTEGRATED` as provisional until CON-003-backed evidence exists.
- Treat `rule_surfaces` and `runtime_state_requirements` as declarations unless verified by code/tests.
- Do not update metadata status to `INTEGRATED` without capability package evidence and tests.
- Do not convert metadata into runtime behavior authority without an accepted ADR/contract.

## 6. Recommendation

Recommended metadata model:
Capability-derived status model, with documentation metadata plus test validation as the migration bridge.

Metadata should remain descriptive/routing/status evidence. It should not own behavior. Integration-related status should be derived from, or explicitly traceable to, rule capability package evidence. Until CON-003 exists, existing metadata should be treated as owner-maintained and potentially stale unless tests and code evidence support it.

Strongest argument against:
Capability-derived metadata requires a new source of truth that does not exist yet. During migration, statuses may become more conservative or require backfill work, which can make catalog progress appear to move backward.

Migration strategy:

1. Keep current metadata fields readable and schema-valid.
2. Treat existing `INTEGRATED`, `PARTIAL`, and `NOT_INTEGRATED` values as migration-era labels, not final ADR-003 proof.
3. For new behavior-changing work, require capability package evidence before setting or preserving `INTEGRATED`.
4. Add capability package ids and evidence links only after CON-003 defines their shape.
5. Extend tests incrementally so status claims are checked against package evidence, implemented surfaces, and required tests.
6. Preserve catalog display/filter behavior while tightening the meaning of status values.
7. Backfill high-risk categories first: damage cards with split immediate/persistent behavior, generic squadron keywords, upgrades with runtime effects, objectives with setup/runtime state, and obstacles with gameplay effects.

Owner questions:

- Should existing `rules_integration.status` values keep the enum `NOT_INTEGRATED`, `PARTIAL`, `INTEGRATED`, or migrate to the tiered status model?
- Should tiered statuses be stored in component JSON, generated from capability packages, or shown only in reports/tests?
- Should `implemented_rule_ids` continue to mean `RuleRegistry` ids, or be broadened to capability/behavior ids?
- Should `rule_surfaces` represent intended surfaces, implemented surfaces, or both with separate fields?
- Should `runtime_state_requirements` remain authored metadata, or require links to concrete state owners once CON-003 exists?
- Should catalog filters expose migration-era status, capability-derived status, or both?
- What is the owner approval path for changing a component from `PARTIAL` to `INTEGRATED`?

## 7. Consequences For ADR-003

Metadata semantics that should become ADR policy:

- Metadata is not behavior authority.
- Metadata is not proof of integration.
- Integration status is capability-based.
- `RuleRegistry` ids or hook registration alone are insufficient for integrated status.
- Metadata should distinguish descriptive content, declared routing, implementation evidence, and verified integration status.
- Metadata may report integration progress only when traceable to capability evidence.

Semantics that should become CON-003 requirements:

- Capability package id and linkage rules.
- Evidence fields or references for active state, validation, execution, projection, serialization, replay, network, visibility, and tests.
- Rules for deriving or validating status fields.
- Rules for mapping old `NOT_INTEGRATED`/`PARTIAL`/`INTEGRATED` values to capability-backed statuses.
- Rules for interpreting `implemented_rule_ids`, `rule_surfaces`, `pending_rule_surfaces`, and `runtime_state_requirements`.
- Test requirements for status claims.

Semantics that should remain implementation details:

- Exact UI label names in the fleet builder.
- Exact catalog filter implementation.
- Whether status reports are generated during tests, editor tooling, or CI.
- Internal storage format for future evidence links.
- Whether intermediate statuses are physically stored in JSON or computed from capability packages.

## Readiness For Final ADR-003 Synthesis

Ready for final ADR-003 synthesis: Yes.

ADR-003-A, B, C, and D now converge on a stable direction:

- Capability packages govern rule integration.
- Authority is delegated by responsibility surface.
- Metadata reports evidence/status/routing and does not own behavior.

Confidence score: 8/10.

Unresolved risks:

- CON-003 does not exist yet, so capability-derived status cannot be mechanically enforced.
- Existing README language, tests, and JSON status values still reflect older registry-id semantics in some places.
- Backfilling existing integrated/partial status claims may reveal gaps.
- Large content growth will require generated or table-driven status/test validation to avoid manual drift.
- Catalog versioning for saves, replays, and network peers remains unresolved and should be addressed outside metadata semantics or in CON-003/test strategy.
