# CAP-OBS-003: Station Maneuver Overlap

Package ID: CAP-OBS-003
Title: Station Maneuver Overlap
Status: Draft
Component Type: obstacle
Source Component: `station`
Related ADRs: ADR-003, ADR-006, ADR-010, ADR-013
Related Contracts: CON-003
Related Context Packs: CP-001
Related Tests: TEST-003; required tests listed below
Related Requirements: SMI-063, SMI-064, SMI-091; Ship Maneuver Owner Decision Record Section 25
Created: 2026-09-12
Last Updated: 2026-09-12
Owner: Project Owner
Test Owner: Capability implementation owner; Project Owner review required
Capability Classification: mixed

## 1. Purpose

This package traces the core station effect when a surviving ship's final
position after executing a Maneuver overlaps the core station. The ship may
discard one of its faceup or facedown damage cards. SMI-091 requires it to
reach CON-003 `Integrated`, with explicit Owner approval, before accepted
release/cutover depends on it. Its complete ordinary path may participate
earlier only after the whole workbook reaches Owner Decision 27's
`candidate-code-complete` condition in the unreleased 7/10/7 Integration
Candidate, without changing this Draft status.

This Draft records boundaries and missing evidence only.

Classification rationale: **mixed**. The optional effect originates from the
station component but participates in the core Maneuver consequence lifecycle.

## 2. Scope

### Included Behavior

- Final-position station overlap, including speed-zero execution.
- Optional decision by the rules-assigned actor—the affected ship's
  controller—to decline or discard exactly one legal faceup or facedown damage card.
- Public discard result, hidden-information-safe facedown selection/application,
  decision-equivalent recovery, exact-once completion, and return to Maneuver.
- Receipt of one selected station invocation from baseline Maneuver after
  baseline has owned any multiple-obstacle order choice required by SMI-063.

### Excluded Behavior

- Squadron hull recovery, attack obstruction, and objective-specific station
  behavior. Contested Outpost's suppression of the normal station effect is an
  external objective capability dependency, not part of this core package.
- Integration of Contested Outpost or any other objective, and any generic
  Station-, objective-, obstacle-, or modifier-framework. When an active
  objective would modify or suppress Station behavior and its required
  objective capability is not `Integrated`, the unsupported configuration
  fails closed instead of invoking ordinary Station behavior.
- Generic repair, optional-rule, obstacle-effect, consequence, continuation,
  queue, stack, or FSM ownership.
- Runtime presentation-derived geometry.

### Dependencies

- ADR-006 active Maneuver execution identity and return boundary.
- Verified canonical station contour and baseline final-position detection.
- Existing ship faceup/facedown damage state, damage deck discard, passive
  damage ledger, and reusable low-level discard/application helpers.
- A purpose-specific objective capability when the active objective modifies
  or suppresses Station. The ordinary Station path may run only when no such
  modifier applies or the applicable objective capability is `Integrated` and
  supplies its accepted purpose-specific behavior.

### Assumptions

- No prompt is projected when the ship is destroyed or has no legal damage
  card to discard; the station consequence then completes without fabricating a decision.
- SMI-063/064 own invocation/order; this package owns station availability,
  decline, selection, discard, and completion.
- Baseline Maneuver detection/invocation owns cross-obstacle order and validates
  its rules-assigned actor. No shared obstacle consequence manager is introduced.
- Baseline invocation fails closed before ordinary Station resolution when the
  active configuration names a Station-modifying or -suppressing objective
  whose capability is not `Integrated`; absence of objective integration is
  never treated as absence of the objective rule.
- A canonical contour may be extracted once from sufficiently faithful
  official artwork only after provenance and physical scale are verified and
  the result is accepted. Runtime or dynamic sprite, bounds, alpha-mask, or
  presentation-derived authoritative geometry is prohibited.

## 3. Rule Origin

### Component Source

- Component type: obstacle
- Source component key: `station`
- Rules reference id: `obstacle.space_station`; RRG 1.5.0, Obstacles, p.12

### Static Data

- Static files: `Resources/Game_Components/obstacles/station.json` and
  `obstacles_specs.txt`
- Loader/model: `src/utils/asset_loader.gd`, `src/models/obstacle_data.gd`
- Metadata/status: `NOT_INTEGRATED`; current oriented
  `SPRITE_BOUNDS_FACTOR` geometry is not authoritative for Maneuver overlap.

### Activation Conditions

- A surviving ship's authoritative final base overlaps an unresolved station
  placement after earlier SMI-064 consequences converge.
- No active objective requires a Station modification/suppression whose
  purpose-specific capability is absent or not `Integrated`; that unsupported
  configuration fails closed before ordinary Station activation.

### Runtime Prerequisites

- Matching activation/execution identities, final transform, canonical station
  placement/contour, unresolved status, ship damage collection/count, and
  rules-assigned affected-ship-controller entitlement.
- No production station Maneuver-effect path currently exists.

## 4. Responsibility Ownership

| Responsibility | Owner | Rationale | Evidence |
| --- | --- | --- | --- |
| State | Station-specific nested consequence state plus existing `GameState`/`ShipInstance` damage owners | Optional decision and resolution guard are station-specific; cards/discard remain canonical damage owners. | ADR-006; SMI-063, SMI-080 |
| Validation | Station-specific replayable decline/discard command boundary | It validates that the submitter is the rules-assigned actor—the affected ship's controller—plus identities, survival, overlap, unresolved status, action, and legal selected card. | ADR-003; CON-003 |
| Execution | Station-specific command using discard/application helpers | It records decline or removes exactly one selected card; Maneuver and Repair do not own the station rule. | RRG Obstacles; SMI-063 |
| Projection | `UIProjector` and station-specific interaction route | It derives station use/decline and card choices; baseline Maneuver separately owns cross-obstacle order projection. | ADR-010; TEST-003 |
| Serialization | `GameState`, `ShipInstance`, damage deck/ledger, and station-specific pending state | Pending opportunity, choice state, and completion must reconstruct. | SMI-080; ADR-013 |
| Replay | `CommandProcessor` history | Decline or discard is an explicit semantic decision in ordered history. | SMI-081; TEST-003 |
| Network | Authority command processing and passive application-result/snapshot paths | The rules-assigned actor decides; authority validates; passive peers apply public discard result only. | ADR-013; SMI-081 |
| Visibility | `StateFilter` and passive damage representation | Faceup choices are public; facedown identities remain hidden until the discarded card becomes public. | ADR-013 |
| Tests | Station package verification suite and runtime smoke owner | It owns unit, protocol, UI, persistence, replay, Network, visibility, decline, destruction, and runtime smoke evidence. | CON-003; TEST-003; Section 8 |

All nine canonical CON-003 surfaces are **Required** for this mixed capability.
Exact implementation filenames may remain deferred until implementation.

## 5. Surface Traceability

| Surface | Required? | Evidence | Notes |
| --- | --- | --- | --- |
| RuleRegistry | Not Applicable to ordinary Station | ADR-003; no active station registration | This package does not invent a generic modifier registry. A separately Integrated objective capability owns its purpose-specific registration, if any. |
| RuleSurface | Required | SMI-063/091; Ship Maneuver Owner Decision Record Section 25 | Station invocation must distinguish ordinary applicability from an unsupported active objective configuration and fail closed without a generic modifier surface. |
| Commands | Required | `RepairActionCommand` is related evidence only | Require station-specific explicit decline/discard boundary; do not reuse Engineering semantics as owner. |
| Resolvers | Required | Final obstacle detection missing; discard helper behavior exists | Shared pure geometry and discard helpers are allowed. |
| State Classes | Required | Ship damage/deck/ledger and obstacle placements are partial | Pending optional decision, exact-once state, and execution binding are missing. |
| Setup | Required | Station placement data/command exists | Placement reusable; current contour is not authoritative. |
| UI Projection | Required | No station interaction route exists | Full TEST-003 protocol applies. |
| Serialization | Required | Existing damage serialization is partial | Pending use/decline and card options must re-derive without duplication. |
| Replay | Required | Command history exists | Explicit decline/discard and ordered continuation need evidence. |
| Networking | Required | Repair facedown application is reusable evidence | Station-specific entitlement, application, reconnect, and visibility need proof. |

## 6. Runtime State

### Required Runtime State

- Matching activation/Maneuver execution and station placement identities.
- Canonical final overlap and verified contour/version.
- Station-specific pending/resolved fact and explicit decline or selected card
  reference/ordinal sufficient for authority validation without exposing hidden identity.
- Canonical faceup cards, authority facedown cards, passive facedown count, and public discard.

The concrete representation is deferred and must remain station-specific.

### Lifecycle

- Created by: accepted station invocation after final overlap/order selection.
- Updated by: station-specific decline or discard command.
- Consumed by: accepted decline/discard or automatic no-legal-option completion.
- Removed or expired by: return to Maneuver or ADR-006 exceptional termination.

### Persistence

- Save/load path: canonical damage state plus station-specific pending/completed state.
- Replay path: explicit decline/discard semantic command history.
- Network/reconnect path: filtered snapshot and public discard application result.

### Cleanup

- Cleanup owner: station-specific boundary with ADR-006 terminal cleanup.
- Cleanup trigger: decline, discard, no legal option, target destruction, or invalid identity.

## 7. Evidence Map

| Evidence Type | Evidence | Notes |
| --- | --- | --- |
| Implementation files | `src/core/commands/commit_setup_obstacle_command.gd`; `src/models/obstacle_data.gd`; `src/core/state/ship_instance.gd`; passive damage ledger | Reusable placement and damage state only. |
| Commands | `src/core/commands/repair_action_command.gd` | Demonstrates discard/application semantics but has the wrong gameplay source and validation boundary. |
| Resolvers | No production station overlap/effect resolver | Required behavior is absent. |
| Tests | Setup/catalog and Repair command tests | No station protocol evidence. |
| Documentation | RRG 1.5.0 Obstacles p.12; SMI-060, SMI-063/064, SMI-080/081, SMI-091 | Governing core behavior. |
| Related Rule Capability Packages | Contested Outpost and other objective packages | External modifiers/suppressors; explicitly excluded here. |

Contour evidence audit: the station PNG has raster dimensions (211x201 pixels)
and catalog history only. No verified official provenance, physical scale, canonical
origin/orientation, winding, contour, or version/hash exists. Canonical station
geometry remains an evidence gap. This gap is an implementation and acceptance
stop gate for this package.

## 8. Test Evidence

### Unit Tests

- Outstanding: contour/rotation/contact, final-only and speed-zero overlap,
  availability, explicit decline, faceup selection, facedown ordinal validation,
  no-card auto-completion, rejection rollback, and exact once.

### Integration Tests

- Outstanding: SMI-064 order, baseline-selected multiple-obstacle invocation,
  destruction before station, return/re-evaluation, ordinary behavior when no
  modifier applies, and fail-closed rejection when a Station-modifying
  objective capability is absent or not Integrated. A positive modified/
  suppressed-objective path is required only if an applicable purpose-specific
  objective capability actually exists at `Integrated` status; otherwise it is
  recorded as not applicable and BUG-043 performs no objective implementation.

### Replay Tests

- Outstanding: explicit decline/discard order and no repeated prompt/discard.

### Serialization Tests

- Outstanding: save/load before decision and after accepted completion.

### Network Tests

- Outstanding: rules-assigned-actor-only decision, wrong-actor/stale rejection, passive
  public discard application, and reconnect with the same legal options.

### Visibility Tests

- Outstanding: hidden facedown choices/identity before resolution and public discard after resolution.

### Regression Tests

- Outstanding: no prompt after destruction or with no cards; Engineering repair rules are not applied.

### TEST-003 Verification Matrix

| Field | Required package evidence |
| --- | --- |
| Timing-window identity | Ship Activation / live ADR-006 Maneuver execution / SMI-064 obstacle item for one selected station, from baseline invocation through use/decline/no-option completion. |
| Opener | Baseline Maneuver final-position detection/invocation supplies matching activation, execution, and selected station-placement identities after earlier survival checks. |
| Participants | Station capability, surviving affected ship, rules-assigned ship controller, canonical faceup/facedown damage state, deck/discard/ledger. Baseline owns cross-obstacle ordering. |
| Source owners | Canonical station placement/component source, target `ShipInstance`, authority damage deck/discard, passive ledger, and station-specific pending decision owner. |
| Controller / priority rule | The affected ship's controller decides use/decline and selected card; baseline separately validates the moving ship's actor for cross-obstacle order. |
| Use and decline commands | Explicit station-specific discard/use and decline semantic boundaries, each bound to activation/execution/placement identity; automatic no-legal-option completion creates no fabricated decision. Exact filenames deferred. |
| Authoritative state changed | Selected card removal, authority/public discard, passive facedown count/application, station-specific completion fact; decline changes only purpose-specific resolution state/history. |
| Re-derivation trigger | Accepted use/decline, no-legal-option determination, target destruction, purpose-specific objective capability change, or recovery installation. An unsupported active objective configuration fails closed before ordinary Station resolution. |
| Continuation command | Purpose-specific completion returns to the matching live ADR-006 Maneuver boundary; no generic optional-rule or continuation owner. Exact filename deferred. |
| Cleanup events | Use, decline, no legal option, target destruction, source suppression/invalidation, exceptional termination, or Maneuver retirement. |
| Unit tests | Required contour, eligibility, rules-actor validation, faceup/facedown selection, decline, no-option, hidden application, exact-once, rejection, and cleanup tests. |
| Protocol tests | Required opener -> projection -> use/decline -> mutation -> re-derivation -> return lifecycle, including baseline-selected multiple obstacles and fail-closed unsupported configuration. Add a positive modified/suppressed-objective path only when an applicable objective capability already exists at `Integrated`; otherwise record it not applicable. |
| UI-route tests | Required station projector/router/modal construction and dispatch, including explicit decline, hidden facedown selection, no-option absence, and rejection recovery. |
| Serialization tests | Required before decision, after explicit decline/use, and after completion. |
| Replay tests | Required explicit use/decline, discard identity result, order, continuation, and no repeated prompt/discard. |
| Network/reconnect tests | Required actor entitlement, authority validation, passive application/non-synthesis, hidden selection, order, and reconnect with equivalent options. |
| Visibility tests | Required faceup visibility, hidden facedown identity before selection, and public discarded card afterward. |
| Runtime smoke trace | Outstanding production-scene trace for station overlap through use and decline routes, hidden/public transition, and Maneuver return. |

## 9. Risk Assessment

### Serialization / Replay / Network / Visibility Impact

- Serialization impact: high; an optional decision can remain pending.
- Replay impact: high; decline and card selection alter later state.
- Network impact: high; rules-assigned actor entitlement and hidden card application must converge.
- Visibility impact: high; facedown identity changes from hidden to public on discard.

### Risk Table

| Risk Area | Impact | Evidence / Rationale | Mitigation or Outstanding Work |
| --- | --- | --- | --- |
| Replay impact | high | Optional decision must be explicit | Replay decline/discard and continuation. |
| Serialization impact | high | Pending prompt must reconstruct | Persist purpose-specific status; re-derive options. |
| Network impact | high | Owner choice with passive peers | TEST-003 end-to-end protocol tests. |
| Visibility impact | high | Facedown identity disclosure boundary | ADR-013 filtering/application tests. |
| Migration impact | high | No effect route; Repair command is not transferable ownership | Add station-specific boundary only. |
| Complexity | high | Geometry, optional choice, hidden data, objective modifiers | Keep ordinary behavior and the unsupported-modifier fail-closed boundary package-owned; objective behavior remains external. |

## 10. Integration Status

Current Status: Draft
Evidence Summary:

- Static station identity, placement, and reusable discard mechanics exist.
- Canonical contour, active station rule, interaction state, and protocol tests do not.

Outstanding Work:

- Close contour evidence; implement/verify ordinary Station and the unsupported-
  modifier fail-closed boundary; add positive modifier evidence only when an
  applicable objective capability is already `Integrated`; align metadata;
  obtain explicit Owner approval.

Approval State:

- Owner approval: not requested
- Reviewers required: Project Owner; gameplay/rules, architecture, Network/replay reviewers
- Review date: not applicable

## 11. Review History

| Reviewer | Date | Decision | Notes |
| --- | --- | --- | --- |
| Codex | 2026-09-12 | noted | Draft only; core station effect excludes objective-specific behavior. |
