# ADR-003 Owner Review

Status: Owner review draft  
Subject: ADR-003 Rule and Validation Surface Decision  
Reviewed ADR: `docs/architecture/adr/ADR-003-rule-and-validation-surfaces.md`

This document is not a redesign exercise. It stress-tests whether ADR-003 is ready for owner acceptance.

## 1. Decision Integrity Review

| Check | Assessment | Notes |
| --- | --- | --- |
| Internal consistency | Pass | The ADR consistently states that capability packages govern integration, `RuleRegistry` is one implementation surface, authority is delegated by responsibility, and metadata does not own behavior. |
| Consistency with CP-001 | Pass | CP-001 states that current rule behavior is hybrid, metadata is not executable, `RuleRegistry` is not serialized, and behavior must connect to runtime state, commands/resolvers/projection, save/load, replay, network, visibility, and tests. ADR-003 preserves those findings. |
| Consistency with ADR-003-A | Pass | ADR-003 adopts the modified Option C/D owner direction: capability package as controlling model and `RuleRegistry` as preferred surface only where suitable. |
| Consistency with ADR-003-B | Pass | ADR-003 defines integration as capability-based and explicitly rejects hook/metadata-only integration. |
| Consistency with ADR-003-C | Pass | ADR-003 uses delegated authority by responsibility surface and does not re-centralize authority in one subsystem. |
| Consistency with ADR-003-D | Pass | ADR-003 treats metadata as evidence/status/routing, not behavior authority. |
| Consistency with `DOCUMENT_AUTHORITY.md` | Pass | ADR-003 is a proposed ADR. If accepted, it becomes accepted architecture and outranks older intended architecture for this topic. |
| Consistency with `CODEX_WORKFLOW.md` | Pass | ADR-003 follows the evolution workflow: CP baseline evidence, ADR analysis, owner decision, then future contract/test/migration work. |
| Consistency with roadmap | Pass | ADR-003 directly addresses `AT-003`, uses `AT-004`/`CP-001`, and points to `CON-003` as the next output. |

Contradictions found:

- No acceptance-blocking contradiction found.
- Known migration tension remains: some existing README/test/status wording still reflects older registry-id semantics. ADR-003 identifies this as migration work rather than treating it as accepted future semantics.

## 2. Five-Year Scalability Review

Assumptions:

- 100+ upgrades.
- 50+ objectives.
- Many new ship and squadron abilities.
- Additional game mechanics.
- Continued Codex-assisted development.

Assessment:

ADR-003 scales better than registry-only or metadata-only approaches because it does not force all rules into one mechanism. It accepts that long-lived game rules often cross state, command validation, resolver calculation, projection, visibility, serialization, replay, and networking surfaces.

The capability-package model should scale if CON-003 keeps packages concise and conditional by rule type. Large content growth needs a repeatable package checklist, status derivation or validation, and table-driven tests. Without those, the model could become manual paperwork and status drift could return.

Scalability verdict:
ADR-003 is suitable for five-year growth, provided CON-003 and the test strategy are created before broad rule expansion.

## 3. Rule Integration Walkthrough

| Scenario | ADR-003 application | Friction points | Missing guidance |
| --- | --- | --- | --- |
| New upgrade | Treat as component-origin behavior. Identify whether it affects build legality, active runtime state, command legality, resolver calculation, projection, serialization, replay, network, or visibility. Use `RuleRegistry` only if an accepted call site exists for the effect shape. | No generic active upgrade state currently exists on `ShipInstance`; upgrades may affect many mechanics. | CON-003 must define package fields for active state owner and upgrade assignment/runtime state evidence. |
| New objective | Separate setup lifecycle from runtime scoring/special behavior. Setup package/setup validators own setup scaffolding. Runtime effects need explicit state and command/resolver/projection owners. | Objective setup state can be mistaken for full runtime objective implementation. | CON-003 must define how one component can have separate setup and runtime capability slices. |
| New damage card | Classify persistent hook-shaped behavior versus immediate command-owned behavior. Faceup/facedown card state remains state-owned. Immediate mutations must be command/replay-safe. | Some cards may have both immediate and persistent effects. Hidden damage information adds visibility risk. | CON-003 must define how one card maps to multiple capability surfaces and tests. |
| New ship ability | Treat as component-origin mixed rule unless proven simple. Determine active state source, command/resolver impact, projection, save/load, replay/network, and tests. | No generalized named ship ability path is currently established. | CON-003 must define when derived static identity is enough versus when mutable active state is required. |
| New squadron ability | Distinguish generic keyword behavior from named/ace-specific behavior. Existing keyword hooks may apply; named behavior needs explicit surfaces. | Generic keyword infrastructure can be over-assumed for named abilities. | CON-003 must define package rules for generic keywords versus named component-specific abilities. |

Overall:
ADR-003 gives enough direction to prevent unsafe placement. It intentionally leaves exact package shape and test thresholds to CON-003.

## 4. Codex Safety Review

Likely implementation mistakes:

- Add static JSON and mark behavior integrated without runtime implementation.
- Add a `RuleRegistry` hook without an accepted call site.
- Implement resolver behavior without command validation or projection alignment.
- Add UI affordances that are not enforced by commands/resolvers.
- Add state that does not serialize or is not filtered for hidden information.
- Add immediate effects outside command history, breaking replay/network behavior.

Likely documentation mistakes:

- Treat ADR-003 as if it designed CON-003.
- Treat the capability package as a new runtime subsystem rather than a traceability/integration artifact.
- Continue using older README wording where `INTEGRATED` means only registered rule ids.
- Update metadata status without corresponding evidence.

Likely metadata mistakes:

- Trust `rules_integration.status` as proof.
- Treat `implemented_rule_ids` as proof of execution.
- Treat `rule_surfaces` as implemented call sites.
- Treat `runtime_state_requirements` as proof that state exists and serializes.

Guardrail assessment:
ADR-003 guardrails are sufficient for acceptance. They are not sufficient for implementation without CON-003, which the ADR explicitly requires.

## 5. Contract Readiness

ADR-003 provides enough direction to create CON-003.

Policy present:

- Capability package is the governing integration model.
- Integration is capability-based.
- Authority is delegated by responsibility.
- Metadata is evidence/status/routing, not behavior authority.
- `RuleRegistry` is one implementation surface and not proof of integration.
- Save/load, replay, network, visibility, projection, validation, active state, and tests must be considered where applicable.

Terminology present:

- Component rule.
- Core mechanic.
- Mixed rule.
- Rule Capability Package.
- Integrated.
- Authority surface.

Definitions sufficient for contract drafting:

- Mostly yes. CON-003 can define exact fields, required evidence, status derivation, and test obligations using ADR-003 as policy input.

Acceptance-blocking gaps:

- None.

Non-blocking gaps for CON-003:

- Exact package schema.
- Conditional field rules by rule type.
- Review/approval ownership.
- Test minimums per surface.
- Status mapping for existing metadata.
- First backfill category.

## 6. Acceptance Recommendation

Recommendation: Accept with amendments.

| Amendment | Severity | Rationale | ADR section affected |
| --- | --- | --- | --- |
| Clarify that the capability package is a traceability/integration artifact, not necessarily a new runtime subsystem. | Medium | Prevents Codex or implementers from creating a runtime "package manager" prematurely. | Section 3 Decision; Section 9 Future Contracts |
| Add "metadata/status claims may remain migration-era until CON-003 exists" to Codex guardrails or migration rules. | Low | The ADR already says this in Metadata Policy, but repeating it in migration/guardrails reduces Codex mistakes. | Section 8 Migration Rules; Section 10 Codex Guardrails |
| Clarify that acceptance of ADR-003 does not by itself permit broad new behavior-changing rule work without CON-003 or owner guidance. | Medium | The ADR says CON-003 is required, but this should be explicit to avoid treating acceptance as implementation-ready permission. | Section 12 Readiness Recommendation or Section 10 Codex Guardrails |

No amendment requires redesigning ADR-003.

## 7. Acceptance Readiness

Is ADR-003 ready for owner acceptance?

Yes, with the amendments above.

Biggest remaining risk:

The biggest risk is premature implementation before CON-003 exists. ADR-003 gives the policy direction, but not the package schema, status derivation, or test thresholds needed for broad feature work.

What should happen next:

1. Apply the small ADR wording amendments listed above.
2. Owner accepts ADR-003.
3. Create CON-003 Rule Capability Contract.
4. Create the related test strategy.
5. Backfill one high-value rule category as the validation slice.

Confidence score: 8/10.

Confidence is high because the ADR is internally consistent and aligns with CP-001, the ADR-003 workbooks, and governance docs. It is not higher because the contract and test strategy are still future work, and because existing metadata/status wording will require migration.
