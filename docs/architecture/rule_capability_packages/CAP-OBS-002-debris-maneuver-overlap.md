# CAP-OBS-002: Debris Maneuver Overlap

Package ID: CAP-OBS-002
Title: Debris Maneuver Overlap
Status: Draft
Component Type: obstacle
Source Component: `debris_1`, `debris_2`
Related ADRs: ADR-003, ADR-006, ADR-010, ADR-012, ADR-013
Related Contracts: CON-003
Related Context Packs: CP-001
Related Tests: TEST-003; required tests listed below
Created: 2026-09-12
Last Updated: 2026-09-12
Owner: Project Owner
Test Owner: Capability implementation owner; Project Owner review required
Capability Classification: mixed

## 1. Purpose

This package traces the core debris-field effect when a ship's final position
after executing a Maneuver overlaps either core debris token. The ship suffers
two damage on one hull zone selected by its owner, with damage resolved one
point at a time. SMI-091 requires it to reach CON-003 `Integrated`, with
explicit Owner approval, before accepted release/cutover depends on it. Its
complete path may participate earlier only after the whole workbook reaches
Owner Decision 27's `candidate-code-complete` condition in the unreleased
7/10/7 Integration Candidate, without changing this Draft status.

This Draft records boundaries and missing evidence only.

Classification rationale: **mixed**. The effect originates from an obstacle
component but participates in the core Maneuver consequence lifecycle.

## 2. Scope

### Included Behavior

- Final-position overlap with `debris_1` or `debris_2`, including speed zero.
- A ship-owner choice of one hull zone followed by two sequential damage
  points against that same zone, including shields, damage-card draws, and
  immediate destruction.
- Authority-only randomness, passive result application, decision-equivalent
  recovery, and exact-once return to the live ADR-006 Maneuver boundary.
- Receipt of one selected debris invocation from baseline Maneuver after
  baseline has owned any multiple-obstacle order choice required by SMI-063.

### Excluded Behavior

- Attack obstruction, Squadron interaction, and objective-specific behavior,
  including Dangerous Territory suppression/reward behavior.
- Geometry derived from presentation assets at runtime.
- A generic damage-choice, obstacle-effect, consequence, continuation, queue,
  stack, or FSM owner.

### Dependencies

- ADR-006 active Maneuver execution identity and return boundary.
- Verified explicit canonical contours for both debris tokens and shared
  final-position detection.
- Existing obstacle placement, ship hull-zone/shield state, damage deck,
  passive ledger, and low-level one-point damage/application helpers.

### Assumptions

- SMI-063/064 govern invocation and ordering. This package owns debris
  applicability, hull-zone choice, and the two-point effect only.
- Baseline Maneuver detection/invocation owns cross-obstacle order and validates
  its rules-assigned actor. This package owns only debris eligibility, its
  ship-owner hull-zone decision, effect, and completion.
- A canonical contour may be extracted once from sufficiently faithful
  official artwork only after provenance and physical scale are verified and
  the result is accepted. Runtime or dynamic sprite, bounds, alpha-mask, or
  presentation-derived authoritative geometry is prohibited.

## 3. Rule Origin

### Component Source

- Component type: obstacle
- Source component keys: `debris_1`, `debris_2`
- Rules reference id: `obstacle.debris_field`; RRG 1.5.0, Obstacles, p.12

### Static Data

- Static files: `Resources/Game_Components/obstacles/debris_1.json`,
  `debris_2.json`, and `obstacles_specs.txt`
- Loader/model: `src/utils/asset_loader.gd`, `src/models/obstacle_data.gd`
- Metadata/status: both records are `NOT_INTEGRATED`; their oriented
  `SPRITE_BOUNDS_FACTOR` boxes are not authoritative Maneuver geometry.

### Activation Conditions

- A surviving ship's authoritative final base overlaps an unresolved core
  debris placement after the earlier SMI-064 consequences have converged.

### Runtime Prerequisites

- Matching activation/execution identities, final transform, canonical debris
  placement/contour, unresolved placement identity, target hull-zone/shield
  state, damage deck, and rules-assigned ship-owner entitlement.
- No production debris Maneuver-effect path currently exists.

## 4. Responsibility Ownership

| Responsibility | Owner | Rationale | Evidence |
| --- | --- | --- | --- |
| State | Debris-specific nested consequence state plus existing `GameState`/`ShipInstance` owners | The pending hull-zone choice is purpose-specific; placement, shields, hull, and cards remain canonical owners. No persisted midpoint is presumed. | ADR-006; SMI-063, SMI-080 |
| Validation | Debris-specific replayable choice/resolution command boundary | It validates that the submitter is the rules-assigned actor—the affected ship's owner—plus identities, overlap, obstacle type, survival, legal hull zone, and unresolved status. | ADR-003; CON-003 |
| Execution | Debris-specific command using one-point damage/draw helpers | It fixes one selected zone and applies two points sequentially and safely within the accepted mutation boundary; Maneuver does not own damage. | RRG Damage and Obstacles; SMI-063 |
| Projection | `UIProjector` and debris-specific choice route | It derives the ship-owner hull-zone prompt; baseline Maneuver separately owns cross-obstacle order projection. | ADR-010; TEST-003 |
| Serialization | `GameState`, `ShipInstance`, damage deck, and debris-specific pending state | Pending choice must reconstruct; midpoint progress is required only if implementation exposes a real semantic interruption between damage points. | SMI-080; ADR-013 |
| Replay | `CommandProcessor` history and deterministic damage-deck progression | The chosen zone and accepted sequential result replay in order. | ADR-012; SMI-081 |
| Network | Authority execution plus passive application-result/snapshot paths | The ship owner chooses; passive peers do not choose, draw, or originate follow-ups. | ADR-012; ADR-013 |
| Visibility | `StateFilter` and passive damage representation | Hull-zone choice, shields, hull, and public consequences are visible; facedown identities/deck order remain hidden. | ADR-013 |
| Tests | Debris package verification suite and runtime smoke owner | It owns unit, protocol, UI, persistence, replay, Network, visibility, destruction, atomicity, and runtime smoke evidence. | CON-003; TEST-003; Section 8 |

All nine canonical CON-003 surfaces are **Required** for this mixed capability.
Exact implementation filenames may remain deferred until implementation.

## 5. Surface Traceability

| Surface | Required? | Evidence | Notes |
| --- | --- | --- | --- |
| RuleRegistry | Optional | ADR-003; no debris registration exists | Narrow modifiers may use it; it is not the state or execution owner. |
| RuleSurface | Required | SMI-063/091 | Explicit debris invocation/modification surface is outstanding. |
| Commands | Required | No debris effect command exists | Require debris-specific choice/resolution with exact schema and application contract. |
| Resolvers | Required | Existing damage helpers; final obstacle detection missing | Share only pure geometry and one-point damage primitives. |
| State Classes | Required | `ShipInstance`, damage deck, obstacle placements are partial | Pending selected zone, exact-once fact, and execution binding are missing; no midpoint state is required unless a real interruption boundary exists. |
| Setup | Required | `CommitSetupObstacleCommand`; obstacle JSON | Placement is reusable; current box contour is rejected as authority. |
| UI Projection | Required | No debris hull-zone route exists | Full TEST-003 protocol is required. |
| Serialization | Required | Existing ship/deck serialization is partial | Pending choice and partial two-point resolution must resume exactly. |
| Replay | Required | Command history exists | Choice, point order, draws, destruction, and return need evidence. |
| Networking | Required | Damage application patterns exist | Authority mutation, passive application, rejection, and reconnect need evidence. |

## 6. Runtime State

### Required Runtime State

- Matching activation/Maneuver execution and debris placement identities.
- Canonical final overlap and verified contour/version.
- Hull zone selected by the rules-assigned actor—the affected ship's owner—and
  the atomic sequential two-point resolution result.
- Current shields/hull, damage deck, public faceup damage, hidden facedown counts,
  and exact-once completion fact.

The concrete representation is deferred and must remain debris-specific.

### Lifecycle

- Created by: accepted final-geometry detection and debris invocation.
- Updated by: ship-owner choice and one debris-specific accepted mutation that
  applies the two damage points sequentially to that same zone. If a real
  semantic interruption boundary is later exposed, its purpose-specific
  progress must then be durable and exact-once.
- Consumed by: completion after both points or immediate destruction.
- Removed or expired by: return to Maneuver or ADR-006 exceptional termination.

### Persistence

- Save/load path: canonical ship/deck state plus pending debris state.
- Replay path: ordered semantic choice/damage commands.
- Network/reconnect path: filtered snapshot and viewer-authorized results.

### Cleanup

- Cleanup owner: debris-specific boundary with ADR-006 terminal cleanup.
- Cleanup trigger: two points resolved, target destroyed, or identity invalidated.

## 7. Evidence Map

| Evidence Type | Evidence | Notes |
| --- | --- | --- |
| Implementation files | `src/core/commands/commit_setup_obstacle_command.gd`; `src/models/obstacle_data.gd`; `src/core/state/ship_instance.gd`; damage deck/ledger classes | Reusable state exists, not active debris behavior. |
| Commands | `src/core/commands/resolve_damage_command.gd` is attack-scoped; no debris command exists | Low-level semantics may be extracted/reused, not the attack command owner. |
| Resolvers | Existing damage helpers; no final obstacle resolver | Required integration is missing. |
| Tests | Setup/catalog and generic damage tests | No debris interaction or protocol evidence. |
| Documentation | RRG 1.5.0 Obstacles/Damage; SMI-060, SMI-063/064, SMI-080/081, SMI-091 | Governing rule and accepted order. |
| Related Rule Capability Packages | Objective packages that modify debris effects | External and excluded from this core package. |

Contour evidence audit: the two PNGs have raster dimensions (181x197 and
175x166 pixels) but no repository evidence proving official provenance,
physical scale, canonical origin,
orientation, winding, contour, or version/hash. No contour is asserted here.
This gap is an implementation and acceptance stop gate for this package.

## 8. Test Evidence

### Unit Tests

- Outstanding: both contours/rotations/contact policy, final-only and speed-zero
  overlap, legal-zone validation, same-zone invariant, two sequential points,
  shields, draws, rejection rollback, and exact once.

### Integration Tests

- Outstanding: SMI-064 order, baseline-selected multi-obstacle invocation,
  destruction after point one or two, return/re-evaluation, and no later
  ship-dependent consequences after destruction.

### Replay Tests

- Outstanding: ship-owner choice, point/draw order, destruction, and no duplication.

### Serialization Tests

- Outstanding: save/load before choice and after accepted completion. A
  persisted midpoint test becomes required only if implementation exposes a
  real semantic interruption between points.

### Network Tests

- Outstanding: wrong-actor/stale rejection, passive results, hidden draws,
  ordered return, and reconnect at each pending state.

### Visibility Tests

- Outstanding: public zone/shield/hull effects and facedown count without private identities.

### Regression Tests

- Outstanding: intermediate overlap is inert; both points stay on the selected zone; speed zero resolves.

### TEST-003 Verification Matrix

| Field | Required package evidence |
| --- | --- |
| Timing-window identity | Ship Activation / live ADR-006 Maneuver execution / SMI-064 obstacle item for one selected debris placement, from baseline invocation through ship-owner choice and completion. |
| Opener | Baseline Maneuver final-position detection/invocation supplies matching activation, execution, and selected debris-placement identities. |
| Participants | Selected debris capability, affected ship, rules-assigned ship owner, ship hull zones/shields, authority damage deck. Baseline owns cross-obstacle ordering. |
| Source owners | Canonical debris placement/component source, target `ShipInstance`, authority damage deck, and debris-specific pending choice owner. |
| Controller / priority rule | The affected ship's owner selects the hull zone. Baseline separately validates the moving ship's rules-assigned actor for cross-obstacle order. |
| Use and decline commands | Mandatory debris-specific hull-zone resolution command bound to activation/execution/placement identity; decline is Not Applicable. Exact filename/schema details may be finalized during implementation. |
| Authoritative state changed | Selected hull-zone shields/hull, authority deck and ship damage, debris-specific exact-once fact, passive representation, and destruction. Two points resolve sequentially against the same zone inside one safe accepted mutation unless a real semantic interruption is later required. |
| Re-derivation trigger | Accepted debris mutation, target destruction, or recovery installation; re-derive remaining purpose-specific obligations after the complete accepted mutation. |
| Continuation command | Purpose-specific completion returns to the matching still-live ADR-006 Maneuver boundary; no generic continuation owner. Exact filename deferred. |
| Cleanup events | Completion, target destruction, source invalidation, exceptional activation termination, or Maneuver retirement. |
| Unit tests | Required contour, overlap, rules-actor validation, same-zone sequential points, shield/draw order, atomic rejection, exact-once, and destruction tests. |
| Protocol tests | Required opener -> choice -> accepted sequential mutation -> re-derivation -> return/termination lifecycle, including baseline-selected multiple obstacles. |
| UI-route tests | Required ship-owner hull-zone projector/router/modal construction, dispatch, rejection recovery, and baseline-to-package invocation. |
| Serialization tests | Required before choice and after completion; midpoint persistence evidence is conditional on an actual exposed semantic interruption boundary. |
| Replay tests | Required selected-zone and ordered realized damage/draw/destruction result without duplication. |
| Network/reconnect tests | Required rules-actor validation, authority-only mutation/draws, passive application/non-synthesis, and reconnect before choice. |
| Visibility tests | Required public zone/shield/hull results and hidden facedown/deck identities. |
| Runtime smoke trace | Outstanding production-scene trace from final debris overlap through ship-owner choice, two-point result, and Maneuver return/termination. |

## 9. Risk Assessment

### Serialization / Replay / Network / Visibility Impact

- Serialization impact: high; a two-step consequence can be interrupted.
- Replay impact: high; player choice, damage order, and random draws are semantic.
- Network impact: high; authority/private deck and ship-owner choice must converge.
- Visibility impact: high; facedown card identity and deck order remain hidden.

### Risk Table

| Risk Area | Impact | Evidence / Rationale | Mitigation or Outstanding Work |
| --- | --- | --- | --- |
| Replay impact | high | Ordered choice and damage points | End-to-end command-history tests. |
| Serialization impact | high | Pending choice must resume; accepted two-point mutation must be atomic and sequential | Persist the pending choice; persist midpoint progress only if a real interruption boundary exists. |
| Network impact | high | Player decision plus authority draws | TEST-003 and ADR-012/013 tests. |
| Visibility impact | high | Hidden facedown identities | Filter and application-result tests. |
| Migration impact | high | No active route or accepted contour | Gate on shared prerequisites. |
| Complexity | high | Geometry, interaction, sequential damage, destruction | Purpose-specific state with low-level helpers only. |

## 10. Integration Status

Current Status: Draft
Evidence Summary:

- Static debris identities, placement, and damage infrastructure exist.
- Canonical contours, active effect, pending-choice state, and complete tests do not.

Outstanding Work:

- Close contour evidence; implement and verify every applicable CON-003 surface;
  align metadata; obtain explicit Owner approval.

Approval State:

- Owner approval: not requested
- Reviewers required: Project Owner; gameplay/rules, architecture, Network/replay reviewers
- Review date: not applicable

## 11. Review History

| Reviewer | Date | Decision | Notes |
| --- | --- | --- | --- |
| Codex | 2026-09-12 | noted | Draft only; no implementation or integration claim. |
