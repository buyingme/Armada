# ADR-003 Direction Summary

Status: Owner Direction Recorded

Supports:
- ADR-003 Rule and Validation Surface Decision

Based on:
- ADR-003-A
- ADR-003-A Challenge Review
- ADR-003-B
- CP-001

This document is not an ADR. It records owner direction and architectural conclusions that should be treated as stable assumptions for the remaining ADR-003 work. Future ADR-003 workbooks should not re-open these topics unless contradictory implementation evidence is discovered.

Note: no standalone `ADR-003-A-rule-ownership-challenge.md` file was found in `docs/architecture/decision_workbooks/` when this summary was created. The challenge review referenced here is the adversarial review result that informed the recorded ADR-003-A owner direction.

## 1. Stable Conclusions

| Conclusion | Evidence source | Confidence |
| --- | --- | --- |
| Component rule describes source/origin, not architectural ownership. | ADR-003-A Owner Direction and Refined Definitions; ADR-003-A Challenge Review | High |
| Core mechanic describes base lifecycle/procedure ownership. | ADR-003-A Refined Definitions; CP-001 rule-surface evidence | High |
| Mixed rules are expected and common. | ADR-003-A Refined Definitions; CP-001 damage-card, objective, upgrade, obstacle, and resolver evidence; ADR-003-A Challenge Review | High |
| `RuleRegistry` is not the architecture. | ADR-003-A Owner Direction; ADR-003-B Owner Direction; CP-001 Current Rule Surfaces | High |
| `RuleRegistry` is one implementation surface. | CP-001 Current Rule Surfaces; ADR-003-A Owner Direction; ADR-003-B Hook-Based Integration analysis | High |
| `RuleRegistry`/`RuleSurface` is preferred only for suitable component-origin behavior with accepted call sites. | ADR-003-A Owner Direction; ADR-003-B Owner Direction | High |
| Commands, resolvers, setup/fleet validators, state classes, `InteractionFlow` payloads, `UIProjector`, `StateFilter`, serialization, replay, and networking remain valid rule ownership surfaces when the rule requires them. | ADR-003-A Owner Direction; CP-001 Current Rule Surfaces; ADR-003-B Capability-Package Integration analysis | High |
| Active state ownership must be explicit. | CP-001 runtime activation and serialization evidence; ADR-003-A Refined Definitions; ADR-003-B Capability Checklist | High |
| Static metadata alone is not proof of integration. | CP-001 static content pipeline; ADR-003-B Evidence Baseline and recommended definition | High |
| `rules_integration.status`, `implemented_rule_ids`, `rule_surfaces`, `runtime_state_requirements`, and `implementation_status` are descriptive unless backed by executable behavior and evidence. | CP-001 static metadata evidence; ADR-003-B recommended definition | High |
| Rule registration alone is insufficient evidence of integration. | ADR-003-A Consequences For ADR-003-B; ADR-003-B Hook-Based Integration analysis | High |
| Integration requires evidence beyond registration, including applicable state, validation, projection, serialization, replay/network, visibility, and tests. | ADR-003-B recommended definition and checklist; CP-001 Evidence Map | High |
| Context Packs provide evidence, not decisions. | CP-001 status/purpose; `DOCUMENT_AUTHORITY.md`; `CODEX_WORKFLOW.md` | High |
| ADR-003 work should proceed incrementally and should not require a broad rewrite as a prerequisite. | Architecture roadmap and workflow; ADR-003-A Minimal Migration Strategy; ADR-003-B CON-003 implications | High |

## 2. Owner Direction

The governing model is a Rule Capability Package.

`RuleRegistry`/`RuleSurface` is a preferred implementation surface for suitable component-origin predicates, modifiers, enablers, and registered hooks where accepted call sites exist.

`RuleRegistry` is not the default owner of all component behavior. Commands, resolvers, setup/fleet validators, state classes, `InteractionFlow` payloads, `UIProjector`, `StateFilter`, visibility filtering, serialization, replay, and networking remain valid ownership surfaces where required by the behavior.

Capability Packages provide traceability across those surfaces. They identify the source content, active state owner, validation owner, execution owner, projection responsibility, serialization requirements, replay/network requirements, visibility requirements, and test evidence.

This direction combines ADR-003-A's modified Option C/D with ADR-003-B's capability-package definition of integration.

## 3. Decisions Considered Locked

| Decision | Rationale | Source workbook |
| --- | --- | --- |
| Integration is capability-based. | Behavior-changing rules may cross several runtime surfaces, so a single implementation mechanism cannot prove completeness. | ADR-003-B |
| Metadata is descriptive unless backed by capability evidence. | CP-001 shows catalog metadata is parsed and surfaced but not executable by itself. | ADR-003-B; CP-001 |
| `RuleRegistry` registration alone is insufficient. | Registered hooks can exist without active state, accepted call sites, projection, serialization, replay/network safety, or tests. | ADR-003-A; ADR-003-B |
| `RuleRegistry`/`RuleSurface` remains a preferred surface for suitable hook-shaped component behavior. | Existing damage-card and squadron keyword rules show this surface is useful when invoked by accepted call sites. | ADR-003-A |
| Command-owned, resolver-owned, setup-owned, state-owned, projection-owned, and visibility-owned rule behavior is valid when required. | Existing implementation already uses these surfaces for active behavior, and the owner direction preserves them. | ADR-003-A; CP-001 |
| Component rule is an origin classification, not an ownership classification. | The adversarial review showed that rules often become mixed once they affect mutation, validation, projection, lifecycle, visibility, or serialization. | ADR-003-A Challenge Review; ADR-003-A |
| Core mechanic is a lifecycle/procedure ownership classification. | Core attack, defense, movement, setup, command, save/load, replay, network, and visibility procedures exist independently of optional component content. | ADR-003-A |
| Mixed rules require explicit surface traceability. | Mixed rules are common and cannot be safely implemented by assuming one owner from content source alone. | ADR-003-A; ADR-003-B |
| Save/load, replay, network, and visibility obligations must be considered for behavior-changing rules. | CP-001 shows active rule behavior depends on serialized state, deterministic replay, network snapshots, reconnect projection, and hidden-information filtering. | ADR-003-B; CP-001 |
| New behavior-changing rules require surface traceability before being considered integrated. | This is the practical guardrail that prevents static metadata, UI-only predicates, uninvoked hooks, or untested behavior from being marked complete. | ADR-003-B |

These decisions should remain fixed for ADR-003-C and ADR-003-D unless new implementation evidence contradicts them.

## 4. Remaining Open Questions

### ADR-003-C Authority Boundaries

- Which surface is authoritative when a mixed rule affects both command validation and resolver execution?
- Which surface owns durable state for behavior-changing upgrades, objectives, obstacles, named ship abilities, and named squadron abilities?
- Which subsystem owns rule-driven projection: rule package, `UIProjector`, `InteractionFlow`, command payloads, or feature-specific UI controllers?
- Which subsystem owns hidden-information classification for rule payloads and rule-derived state?
- How should owner review work when a capability package names multiple implementation surfaces?
- Which existing rule categories should be backfilled first into capability packages?

### ADR-003-D Metadata Semantics

- Should static catalog metadata reference capability package ids once CON-003 exists?
- Should `rules_integration.status` be replaced, constrained, or mapped to the new status model?
- Which statuses should be public catalog-facing labels and which should be internal implementation evidence?
- Should metadata statuses be manually maintained, generated from capability package evidence, or validated by tests?
- How should catalog versioning affect saves, replays, and network peers when behavior depends on static `data_key` lookups?
- What is the accepted meaning of partially implemented statuses such as Static, Loaded, Runtime Active, Tested, Save Safe, Replay Safe, Network Safe, and Integrated?

## 5. Assumptions For Future Workbooks

### Use These Assumptions

- Do not evaluate `RuleRegistry` as the universal ownership model.
- Assume capability packages exist as the governing model for behavior-changing rule integration.
- Assume mixed rules are normal, not exceptional.
- Evaluate authority boundaries within the capability-package model.
- Evaluate metadata semantics as evidence/status mechanisms, not ownership mechanisms.
- Treat `RuleRegistry`/`RuleSurface` as a preferred implementation surface only when the behavior is suitable and an accepted call site exists.
- Treat commands, resolvers, setup/fleet validators, state classes, projection, visibility filtering, serialization, replay, and networking as valid ownership surfaces where the rule behavior requires them.
- Do not treat static JSON, printed text, catalog loading, `rules_integration.status`, or `implementation_status` as proof of active behavior.
- Do not treat hook registration as proof of integration without active state, invocation, applicable projection, durability, replay/network, visibility, and test evidence.
- Do not reopen ADR-003-A or ADR-003-B unless new code evidence contradicts the locked decisions above.

## 6. Consequences For CON-003

The future Rule Capability Contract will likely need:

- A capability package template.
- Stable identifiers for rule capability packages.
- Links from capability packages to component ids, static metadata, rule ids, and related tests.
- A surface traceability matrix covering active state, validation, execution, projection, serialization, replay, networking, visibility, and tests.
- An integration checklist that distinguishes applicable, not applicable, implemented, and tested surfaces.
- Status derivation rules so static metadata/status fields do not drift away from implementation evidence.
- Evidence requirements for declaring a rule Static, Loaded, Runtime Active, Validation Covered, UI Visible, Save Safe, Replay Safe, Network Safe, Tested, or Integrated.
- Rules for when `RuleRegistry`/`RuleSurface` is an accepted implementation surface.
- Rules for when command/resolver/setup/state/projection/visibility ownership is accepted.
- Guardrails preventing UI-only predicates, uninvoked hooks, or metadata-only records from being marked integrated.
- Incremental migration rules for existing behavior, prioritizing new component rules, touched rules, and high-risk mixed rules.

This section identifies likely CON-003 requirements only. It does not design the contract.

## 7. Readiness Assessment

| Question | Assessment |
| --- | --- |
| Is ADR-003-A sufficiently resolved? | Yes. Rule ownership direction is stable: modified Option C/D, with capability packages as the governing model and `RuleRegistry` as one preferred surface where suitable. |
| Is ADR-003-B sufficiently resolved? | Yes for direction-summary purposes. The definition of integrated should be capability-package based, with tiered statuses as the likely reporting model. |
| Is the project ready to proceed to ADR-003-C? | Yes. The remaining work is authority-boundary analysis inside the capability-package model, not reopening whether the model should be registry-only or metadata-only. |
| Most important unresolved risk | Capability packages could become too heavy or too vague. ADR-003-C and CON-003 must define enough authority and applicability rules to make the package useful without turning it into paperwork. |

Confidence rating: 8/10.

The confidence is high because CP-001 is Baseline Evidence and ADR-003-A/B now converge on the same direction. It is not 10/10 because CON-003 does not exist yet, metadata semantics are still undecided, and authority boundaries for mixed rules still need ADR-003-C.
