# CAP-xxx: Rule Capability Package Title

Package ID: CAP-xxx  
Title: Rule Capability Package Title  
Status: Draft  
Component Type: `<upgrade | objective | damage card | keyword | ship ability | squadron ability | obstacle | token | other>`  
Source Component: `<stable source id or component key>`  
Related ADRs: ADR-003  
Related Contracts: CON-003  
Related Context Packs: CP-001  
Related Tests: TEST-xxx or test file references  
Created: YYYY-MM-DD  
Last Updated: YYYY-MM-DD  
Owner: `<owner name or role>`

Naming note:

The file/template uses the generic `CAP` prefix for stable identifiers, but the artifact type is a Rule Capability Package under CON-003.

Allowed status values:

- Draft
- Identified
- Implemented
- Tested
- Integrated

Status note:

A Rule Capability Package may only be marked `Integrated` after owner approval. Codex may recommend readiness, but Codex may not mark a package `Integrated`.

## How to Use This Template

This template is for Rule Capability Packages governed by ADR-003 and CON-003.

It supports packages of different complexity. Some packages will describe a small rule predicate or modifier. Others will describe behavior that crosses commands, resolvers, state, projection, serialization, replay, networking, and visibility.

Not every capability touches every architectural surface. Every section should still be reviewed. If a section does not apply, record `Not Applicable` followed by one short rationale. Repeating information from other sections is unnecessary; references to evidence are preferred over explanation.

Prefer concise evidence over long prose. The goal is traceability, not documentation volume. A short evidence-backed statement is better than a narrative that duplicates implementation details.

**Documentation Principle:** Keep entries concise. Short evidence-backed statements are preferred over lengthy explanations. This template captures architectural evidence, not implementation documentation.

## 1. Purpose

Describe the behavior covered by this Rule Capability Package.

Include:

- What behavior is covered.
- Why this Rule Capability Package exists.
- Which ADR, contract, context pack, task, or rule-extension concern it supports.

Do not describe gameplay beyond what is needed to identify the behavior and its implementation evidence.

## 2. Scope

### Included Behavior

- `<behavior included in this package>`

### Excluded Behavior

- `<related behavior intentionally excluded>`

### Dependencies

- `<static data, runtime state, command, resolver, UI, save/load, replay, network, or visibility dependency>`

### Assumptions

- `<implementation assumption, owner direction, or not-applicable rationale>`

If this package is part of a larger component, explain whether related behavior is covered by separate Rule Capability Packages.

## 3. Rule Origin

### Component Source

- Component type: `<component type>`
- Source component key: `<stable source id>`
- Rules reference id: `<rules reference id, if any>`

### Static Data

- Static data file(s): `<path>`
- Loader/model path(s): `<path>`
- Metadata/status fields: `<field names or not applicable>`

### Activation Conditions

- `<condition under which the behavior becomes active>`

### Runtime Prerequisites

- `<required runtime state, command state, setup state, interaction flow, or not applicable>`

State whether the behavior is active because runtime code invokes it. Static data or metadata alone is not active behavior evidence.

## 4. Responsibility Ownership

| Responsibility | Owner | Rationale | Evidence |
| --- | --- | --- | --- |
| Active State Owner | `<class/system/none>` | `<why this owner is responsible or why not applicable>` | `<files/tests/evidence>` |
| Validation Owner | `<class/system/none>` | `<why this owner is responsible or why not applicable>` | `<files/tests/evidence>` |
| Execution Owner | `<class/system/none>` | `<why this owner is responsible or why not applicable>` | `<files/tests/evidence>` |
| Projection Owner | `<class/system/none>` | `<why this owner is responsible or why not applicable>` | `<files/tests/evidence>` |
| Serialization Owner | `<class/system/none>` | `<why this owner is responsible or why not applicable>` | `<files/tests/evidence>` |
| Replay Owner | `<class/system/none>` | `<why this owner is responsible or why not applicable>` | `<files/tests/evidence>` |
| Network Owner | `<class/system/none>` | `<why this owner is responsible or why not applicable>` | `<files/tests/evidence>` |
| Visibility Owner | `<class/system/none>` | `<why this owner is responsible or why not applicable>` | `<files/tests/evidence>` |

Every responsibility must identify an owner or record a not-applicable rationale.

One short sentence is sufficient for a not-applicable rationale. Prefer referencing evidence over repeating explanation from other sections.

## 5. Surface Traceability

| Surface | Required? | Evidence | Notes |
| --- | --- | --- | --- |
| RuleRegistry | `<required | optional | not applicable>` | `<registration/call-site/test evidence>` | `<notes>` |
| RuleSurface | `<required | optional | not applicable>` | `<surface/call-site/test evidence>` | `<notes>` |
| Commands | `<required | optional | not applicable>` | `<command/validation/history evidence>` | `<notes>` |
| Resolvers | `<required | optional | not applicable>` | `<resolver/helper/test evidence>` | `<notes>` |
| State Classes | `<required | optional | not applicable>` | `<state fields/lifecycle evidence>` | `<notes>` |
| Setup | `<required | optional | not applicable>` | `<setup package/validator/command evidence>` | `<notes>` |
| UI Projection | `<required | optional | not applicable>` | `<UIProjector/controller/affordance evidence>` | `<notes>` |
| Serialization | `<required | optional | not applicable>` | `<serialize/deserialize evidence>` | `<notes>` |
| Replay | `<required | optional | not applicable>` | `<command history/replay evidence>` | `<notes>` |
| Networking | `<required | optional | not applicable>` | `<sync/snapshot/reconnect evidence>` | `<notes>` |

If `RuleRegistry` or `RuleSurface` is used, list both registration evidence and accepted call-site evidence.

For non-applicable surfaces, record `Not Applicable` and a short rationale. Do not repeat ownership or runtime-state details unless they are needed to make the rationale clear.

## 6. Runtime State

### Required Runtime State

- `<state field, payload, command data, setup data, or none>`

If no runtime state is required, write `Not Applicable` and one short sentence explaining why the behavior is fully derived or static.

### Lifecycle

- Created by: `<source>`
- Updated by: `<source>`
- Consumed by: `<source>`
- Removed or expired by: `<source>`

### Persistence

- Save/load path: `<path or not applicable>`
- Replay path: `<path or not applicable>`
- Network/reconnect path: `<path or not applicable>`

### Cleanup

- Cleanup owner: `<class/system/none>`
- Cleanup trigger: `<phase, command, destruction, discard, setup completion, or not applicable>`

## 7. Evidence Map

The Evidence Map should point to the authoritative implementation location.

Avoid copying implementation details into this document.

Prefer references to files, classes, tests, ADRs, and contracts.

| Evidence Type | Evidence | Notes |
| --- | --- | --- |
| Implementation files | `<path>` | `<what this proves>` |
| Commands | `<path/class/function>` | `<what this proves>` |
| Resolvers | `<path/class/function>` | `<what this proves>` |
| Tests | `<path/test name>` | `<what this proves>` |
| Documentation | `<path/section>` | `<what this proves>` |
| Related Rule Capability Packages | `<CAP-xxx>` | `<relationship>` |

Evidence must identify concrete files, classes, functions, resources, tests, or documentation references.

## 8. Test Evidence

Only include test categories that are applicable.

Mark non-applicable categories explicitly.

Do not create placeholder tests merely to satisfy the template.

### Unit Tests

- `<test path/name or not applicable>`

### Integration Tests

- `<test path/name or not applicable>`

### Replay Tests

- `<test path/name or not applicable>`

### Serialization Tests

- `<test path/name or not applicable>`

### Network Tests

- `<test path/name or not applicable>`

### Visibility Tests

- `<test path/name or not applicable>`

### Regression Tests

- `<test path/name or not applicable>`

If a test category is not applicable, record `Not Applicable` and one short rationale. If a test category is applicable but missing, record it as outstanding work. References to evidence are preferred over repeated explanation.

## 9. Risk Assessment

Keep the assessment proportional to the capability.

Simple rule modifiers usually require one or two concise sentences.

Complex cross-surface capabilities may require more detailed justification.

### Serialization / Replay / Network / Visibility Impact

Summarize the impact of this capability on durable and distributed behavior:

- Serialization impact: `<summary or not applicable>`
- Replay impact: `<summary or not applicable>`
- Network impact: `<summary or not applicable>`
- Visibility impact: `<summary or not applicable>`

Each applicable impact must reference evidence in the Evidence Map and Test Evidence sections.

### Risk Table

| Risk Area | Impact | Evidence / Rationale | Mitigation or Outstanding Work |
| --- | --- | --- | --- |
| Replay impact | `<none | low | medium | high>` | `<evidence>` | `<work or not applicable>` |
| Serialization impact | `<none | low | medium | high>` | `<evidence>` | `<work or not applicable>` |
| Network impact | `<none | low | medium | high>` | `<evidence>` | `<work or not applicable>` |
| Visibility impact | `<none | low | medium | high>` | `<evidence>` | `<work or not applicable>` |
| Migration impact | `<none | low | medium | high>` | `<evidence>` | `<work or not applicable>` |
| Complexity | `<low | medium | high>` | `<evidence>` | `<work or not applicable>` |

Risk assessment records implementation risk. It does not decide new architecture.

## 10. Integration Status

Current Status: Draft  
Evidence Summary:

- `<summary of evidence currently available>`

Outstanding Work:

- `<missing implementation, tests, review, metadata alignment, or owner decision>`

Approval State:

- Owner approval: `<not requested | requested | approved | rejected>`
- Reviewers required: `<owners or roles>`
- Review date: `<date or not applicable>`

Status rules:

- `Draft`: package exists but evidence is incomplete or still being gathered.
- `Identified`: source, scope, and applicable surfaces are identified.
- `Implemented`: required implementation surfaces exist for active behavior.
- `Tested`: required tests exist and pass for applicable surfaces.
- `Integrated`: package is complete, tests pass, metadata/status claims are aligned, all applicable surfaces are covered, and owner approval is recorded.

## 11. Review History

| Reviewer | Date | Decision | Notes |
| --- | --- | --- | --- |
| `<reviewer>` | `YYYY-MM-DD` | `<approved | changes requested | rejected | noted>` | `<notes>` |

Record owner approval explicitly before changing status to `Integrated`.

Review entries should document architectural decisions and approval outcomes only. Do not record every implementation change.

## 12. Codex Checklist

Before recommending this package as ready for owner review, Codex must complete this checklist:

- [ ] Ownership identified.
- [ ] Runtime state identified.
- [ ] Required surfaces identified.
- [ ] RuleRegistry registration and call site verified, or not-applicable rationale recorded.
- [ ] Command validation and execution impact reviewed.
- [ ] Resolver impact reviewed.
- [ ] UI projection impact reviewed.
- [ ] Serialization implications reviewed.
- [ ] Replay implications reviewed.
- [ ] Network implications reviewed.
- [ ] Visibility implications reviewed.
- [ ] Evidence collected.
- [ ] Tests identified.
- [ ] Applicable tests pass or missing tests are recorded as outstanding work.
- [ ] Metadata/status claims synchronized with package evidence.
- [ ] Not-applicable surfaces include rationale.
- [ ] Ready for Owner Review.

Codex may not mark this package `Integrated`.

## 13. Usage Instructions

Create a Rule Capability Package when:

- A new behavior-changing component rule is implemented.
- Existing behavior is backfilled under CON-003.
- A static component rule becomes active runtime behavior.
- A rule crosses command, resolver, state, projection, serialization, replay, network, or visibility surfaces.
- Owner direction requires explicit integration evidence.

Update a Rule Capability Package when:

- Behavior changes.
- Ownership changes.
- A new implementation surface is added.
- Tests are added, removed, renamed, or materially changed.
- Serialization, replay, networking, visibility, or metadata status changes.
- The package status changes.

Split one package into multiple packages when:

- A component has independent behavior slices.
- Setup behavior and runtime behavior can be reviewed separately.
- Immediate and persistent effects have different owners or evidence.
- Separate behavior requires different tests, approval owners, or migration timing.
- The package becomes too broad to review safely.

Relationship to ADR-003 and CON-003:

- ADR-003 defines the accepted architecture policy for rule and validation surfaces.
- CON-003 defines the accepted implementation contract for Rule Capability Packages.
- This template operationalizes CON-003 for concrete package documents.

A completed Rule Capability Package documents implementation evidence.

It does not grant `Integrated` status.

Only owner approval may change a package to `Integrated`.

## Template Philosophy

Capability packages are lightweight architecture artifacts.

Evidence is more important than prose. References to authoritative files, classes, tests, ADRs, contracts, and context packs are preferred over duplicated implementation detail.

Not every capability requires every surface. A simple modifier may only need a small set of ownership, traceability, evidence, and test entries. A mixed rule may require broader coverage. Both should use the same template so review remains consistent.

Reviewability is more important than completeness of narrative. The package should make it clear what behavior is covered, which surfaces are involved, what evidence exists, what remains missing, and whether owner approval has been granted.

The template should remain practical even for hundreds of capability packages. Keep entries concise, use `Not Applicable` with short rationales, and split broad component behavior into smaller packages when that improves traceability.
