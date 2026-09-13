# CAP-OBS-001: Asteroid Maneuver Overlap

Package ID: CAP-OBS-001
Title: Asteroid Maneuver Overlap
Status: Draft
Component Type: obstacle
Source Component: `asteroid_1`, `asteroid_2`, `asteroid_3`
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

This package traces the core asteroid-field effect when a ship's final position
after executing a Maneuver overlaps any of the three core asteroid tokens. The
asteroid rule deals that ship one faceup damage card. It is one of the six
prerequisites that SMI-091 requires to reach CON-003 `Integrated`, with
explicit Owner approval, before accepted release/cutover depends on it. Its
complete path may participate earlier only after the whole workbook reaches
Owner Decision 27's `candidate-code-complete` condition in the unreleased
7/10/7 Integration Candidate, without changing this Draft status.

This Draft records boundaries and missing evidence only. It changes no runtime
behavior or integration status.

Classification rationale: **mixed**. The effect originates from an obstacle
component but is invoked from, and must return to, the core Maneuver mechanic.

## 2. Scope

### Included Behavior

- Final-position overlap with `asteroid_1`, `asteroid_2`, or `asteroid_3`,
  including speed-zero execution.
- One faceup damage-card draw per resolved asteroid obstacle.
- Authority-only randomness, passive result application, immediate faceup-card
  follow-on behavior, survival re-evaluation, and exact-once return to the live
  ADR-006 Maneuver boundary.
- Receipt of one selected asteroid invocation from baseline Maneuver after
  baseline has owned any multiple-obstacle order choice required by SMI-063.

### Excluded Behavior

- Attack obstruction and Squadron interaction with asteroid fields.
- Objective-specific additions, suppression, rewards, or obstacle movement,
  including Dangerous Territory. Those belong to separate objective packages.
- Geometry derived from sprite bounds, alpha masks, or runtime presentation.
- A generic obstacle-effect command, consequence owner, continuation owner,
  queue, stack, or FSM.

### Dependencies

- ADR-006 active Maneuver execution identity and still-`OPEN` return boundary.
- Verified explicit canonical contours for all three asteroid tokens and the
  baseline final-position detection substrate.
- `GameState` obstacle placement identity/position/rotation/order.
- Authority-owned damage deck, faceup damage state, passive damage ledger, and
  immediate damage-card capability boundaries.

### Assumptions

- SMI-063 and SMI-064 govern invocation and cross-category order; this package
  owns only the asteroid-specific effect.
- Baseline Maneuver detection/invocation owns cross-obstacle order, including
  rules-assigned actor validation. This package owns only its own eligibility,
  effect, delegated immediate-card decision, and completion.
- A canonical contour may be extracted once from sufficiently faithful
  official artwork only after its provenance and physical scale are verified
  and the result is accepted. Runtime or dynamic derivation from sprites,
  bounds, alpha masks, or presentation scaling is prohibited.
- Objective rules may suppress or add behavior without changing this core
  package; their packages must intercept through accepted rule surfaces.

## 3. Rule Origin

### Component Source

- Component type: obstacle
- Source component keys: `asteroid_1`, `asteroid_2`, `asteroid_3`
- Rules reference id: `obstacle.asteroid_field`; RRG 1.5.0, Obstacles, p.12

### Static Data

- Static data files: `Resources/Game_Components/obstacles/asteroid_1.json`,
  `asteroid_2.json`, `asteroid_3.json`, and `obstacles_specs.txt`
- Loader/model paths: `src/utils/asset_loader.gd`,
  `src/models/obstacle_data.gd`
- Metadata/status: each record says `rules_integration.status =
  NOT_INTEGRATED`; current `shape_metadata` is `oriented_box` with
  `SPRITE_BOUNDS_FACTOR` and is not authoritative Maneuver geometry.

### Activation Conditions

- A surviving ship has committed a Maneuver, authoritative final geometry is
  established, and its base overlaps an unresolved core asteroid placement.

### Runtime Prerequisites

- Matching activation and Maneuver execution identities; canonical ship final
  transform; canonical asteroid placement and contour; unresolved asteroid
  identity; authority damage deck; and surviving target ship.
- Static data alone does not activate this behavior. No production asteroid
  Maneuver-effect path currently exists.

## 4. Responsibility Ownership

| Responsibility | Owner | Rationale | Evidence |
| --- | --- | --- | --- |
| State | Asteroid-specific nested consequence state plus existing `GameState`/`ShipInstance` owners | Placement, resolution identity, deck state, and ship damage remain in their purpose-specific canonical owners; the Maneuver record does not duplicate them. | ADR-006 Sections 3.3-4; SMI-063, SMI-080 |
| Validation | Asteroid-specific replayable command boundary | It validates the matching baseline invocation, activation/execution identities, survival, final overlap, obstacle type, and unresolved status before mutation. Cross-obstacle actor validation is not package-owned. | ADR-003; CON-003; SMI-063 |
| Execution | Asteroid-specific command using damage-deck/card helpers | It owns the faceup draw and resolution fact; Maneuver only invokes and awaits it. | RRG Obstacles p.12; SMI-063, SMI-091 |
| Projection | `UIProjector` and existing damage-card projection routes | Package projection is limited to asteroid eligibility/effect and any delegated immediate-card decision; baseline Maneuver owns cross-obstacle order projection. | ADR-010; TEST-003 |
| Serialization | `GameState`, `ShipInstance`, damage deck, and asteroid-specific pending state | All canonical facts needed to resume must serialize once. | SMI-080; ADR-013 |
| Replay | `CommandProcessor` history and deterministic authority deck progression | Replay applies semantic commands in accepted order; transient live application results are not replay inputs. | ADR-012; SMI-081 |
| Network | Authority command execution plus passive application-result/snapshot paths | Only authority draws; passive peers install viewer-authorized results and do not synthesize follow-ups. | ADR-012; ADR-013; SMI-081 |
| Visibility | `StateFilter` and passive damage representation | The dealt faceup card and resolved obstacle are public; remaining deck order stays authority-only. | ADR-013 |
| Tests | Asteroid package verification suite and runtime smoke owner | It owns the package's unit, protocol, UI, persistence, replay, Network, visibility, destruction, and runtime smoke evidence. | CON-003; TEST-003; Section 8 |

All nine canonical CON-003 surfaces are **Required** for this mixed capability.
Exact implementation filenames may remain deferred until implementation;
missing evidence remains explicit in Sections 5, 7, and 8.

## 5. Surface Traceability

| Surface | Required? | Evidence | Notes |
| --- | --- | --- | --- |
| RuleRegistry | Optional | ADR-003; no active registration exists | May expose a narrow asteroid enabler/modifier surface; it is not the effect owner. |
| RuleSurface | Required | SMI-063 and SMI-091 | Accepted invocation/modification call site must be explicit and responsibility-specific. |
| Commands | Required | No asteroid effect command exists | Require one replayable asteroid-specific resolution boundary with exact schema and passive application contract. |
| Resolvers | Required | Baseline final-geometry resolver is outstanding | Pure detection may be shared; asteroid applicability/effect remains package-owned. |
| State Classes | Required | Existing obstacle placement, deck, and ship damage state are partial evidence | Purpose-specific exact-once/pending state and active-execution binding are outstanding. |
| Setup | Required | `CommitSetupObstacleCommand`; obstacle JSON | Placement facts are reusable; setup boxes are not authoritative contours. |
| UI Projection | Required | No production asteroid immediate-card route exists | Cross-obstacle order projection belongs to baseline Maneuver; TEST-003 applies to any package-owned decision. |
| Serialization | Required | Existing `GameState`/damage serialization is partial evidence | Must resume before draw, after draw, and during any immediate-card consequence without duplication. |
| Replay | Required | `CommandProcessor` history exists | Asteroid command ordering, seeded draw, and immediate follow-ons need evidence. |
| Networking | Required | ADR-012/ADR-013 application pattern exists | Authority draw, passive faceup result, reconnect, and non-synthesis need evidence. |

## 6. Runtime State

### Required Runtime State

- Matching activation and Maneuver execution identities.
- Stable obstacle placement identity and unresolved/resolved asteroid fact.
- Canonical final transform and verified asteroid contour/version.
- Damage-deck state, resulting public faceup card, and any purpose-specific
  immediate-card pending state owned by that card capability.

The concrete storage shape is deferred. It must remain purpose-specific and
must not become a generic Maneuver work list.

### Lifecycle

- Created by: accepted Maneuver final-geometry detection and asteroid invocation.
- Updated by: asteroid-specific command and any delegated immediate-card command.
- Consumed by: asteroid completion returning to the matching live Maneuver boundary.
- Removed or expired by: exact-once completion or ADR-006 exceptional termination.

### Persistence

- Save/load path: existing canonical state plus outstanding asteroid-specific state.
- Replay path: ordered semantic commands and deterministic authority deck state.
- Network/reconnect path: filtered snapshot plus authority application results.

### Cleanup

- Cleanup owner: asteroid-specific boundary with ADR-006 exceptional termination.
- Cleanup trigger: completion, target destruction, or invalidated activation/execution identity.

## 7. Evidence Map

| Evidence Type | Evidence | Notes |
| --- | --- | --- |
| Implementation files | `src/core/commands/commit_setup_obstacle_command.gd`; `src/models/obstacle_data.gd`; `src/core/setup/setup_obstacle_validator.gd` | Placement exists; geometry is setup-only box evidence. |
| Commands | No production asteroid Maneuver-effect command | Required boundary is missing. |
| Resolvers | No production final-position obstacle resolver | Required active behavior is missing. |
| Tests | Catalog/setup obstacle tests only | No gameplay, recovery, replay, or Network proof. |
| Documentation | RRG 1.5.0 Obstacles p.12; `ship_maneuver_interaction.md` SMI-060, SMI-063, SMI-064, SMI-080/081, SMI-091 | Accepted behavior and ownership boundary. |
| Related Rule Capability Packages | Immediate faceup damage-card package(s), when applicable | A drawn immediate card retains its own rule ownership. |

Contour evidence audit: the three PNGs provide only raster dimensions
(179x89, 137x144, and 145x107 pixels) and a shared catalog-import commit. The
repository provides no verified official
source provenance, physical scale, local origin/orientation, winding, contour,
or hash/version record. Canonical asteroid geometry therefore remains an
evidence gap and is not invented here. This gap is an implementation and
acceptance stop gate for this package.

## 8. Test Evidence

### Unit Tests

- Outstanding: all three contours, rotations, boundary contact policy,
  final-only overlap, speed zero, validation rejection, exact-once resolution,
  seeded faceup draw, and immediate-card delegation.

### Integration Tests

- Outstanding: full SMI-064 ordering, baseline-selected multiple-obstacle
  invocation into this package, return/re-evaluation, survival, and exceptional termination.

### Replay Tests

- Outstanding: command order, deterministic draw, immediate follow-ons, and no duplicate draw.

### Serialization Tests

- Outstanding: save/load before resolution and during immediate-card state.

### Network Tests

- Outstanding: host-only draw/follow-up, passive application, ordering, and reconnect.

### Visibility Tests

- Outstanding: public faceup card and obstacle result with hidden remaining deck order.

### Regression Tests

- Outstanding: intermediate movement does not trigger; speed zero does; duplicate/stale command is inert.

### TEST-003 Verification Matrix

| Field | Required package evidence |
| --- | --- |
| Timing-window identity | Ship Activation / live ADR-006 Maneuver execution / SMI-064 obstacle item for one selected asteroid, from baseline invocation through asteroid and delegated immediate-card completion. |
| Opener | Baseline Maneuver final-position detection/invocation supplies matching activation, execution, and selected obstacle-placement identities. |
| Participants | Selected asteroid capability; target ship; authority damage deck; any immediate faceup-card capability opened by the draw. Baseline, not this package, derives the cross-obstacle participant order. |
| Source owners | Canonical obstacle placement/component source, authority damage deck, target `ShipInstance`, and any delegated immediate-card source owner. |
| Controller / priority rule | Baseline validates the moving ship's rules-assigned actor for cross-obstacle order. Asteroid itself is mandatory and has no package-owned player choice; delegated cards retain their own actor/order rules. |
| Use and decline commands | One asteroid-specific mandatory resolution command with activation/execution/placement identity and passive application result; decline is Not Applicable. Immediate-card commands remain external. |
| Authoritative state changed | Authority deck, ship faceup damage, asteroid-specific exact-once fact, public/passive damage representation, and destruction state when applicable. |
| Re-derivation trigger | Accepted asteroid command, each delegated immediate-card command, source/ship destruction, or recovery installation. Re-derive remaining purpose-specific obligations after each. |
| Continuation command | Purpose-specific completion returns to the matching still-live ADR-006 Maneuver boundary; normal completion occurs only through its accepted command when no obligation remains. Exact filename deferred. |
| Cleanup events | Asteroid completion, target destruction, source invalidation, exceptional activation termination, or Maneuver retirement. |
| Unit tests | Required contour, final-overlap, command validation, draw/application, exact-once, immediate-card delegation, and destruction tests listed above. |
| Protocol tests | Required opener -> authority mutation -> re-derivation -> return/termination lifecycle, including multiple baseline-selected obstacles. |
| UI-route tests | Required for baseline-to-package invocation and any delegated immediate-card projector/router/modal construction and dispatch; no asteroid-only prompt is fabricated. |
| Serialization tests | Required before draw and during any real delegated immediate-card pending state. |
| Replay tests | Required command order, deterministic draw, delegated follow-ons, and no duplicate resolution. |
| Network/reconnect tests | Required authority-only draw/follow-up, passive non-synthesis/application, ordering, and reconnect. |
| Visibility tests | Required public asteroid/faceup result with authority-private deck order and correct delegated-card visibility. |
| Runtime smoke trace | Outstanding production-scene trace for final overlap through faceup result, delegated interaction if applicable, and Maneuver return/termination. |

## 9. Risk Assessment

### Serialization / Replay / Network / Visibility Impact

- Serialization impact: high; exact-once pending state and deck/card state must resume together.
- Replay impact: high; random draw and follow-on command order are semantic.
- Network impact: high; only authority may draw or originate automatic follow-ups.
- Visibility impact: high; faceup result is public while deck order remains private.

### Risk Table

| Risk Area | Impact | Evidence / Rationale | Mitigation or Outstanding Work |
| --- | --- | --- | --- |
| Replay impact | high | Random draw and nested effects | Deterministic command-history tests. |
| Serialization impact | high | Live consequence can span save/load | Persist purpose-specific state and test every boundary. |
| Network impact | high | Hidden authority deck and passive result application | ADR-012/013 protocol tests. |
| Visibility impact | high | Public card from hidden deck | Filter/application-result tests. |
| Migration impact | high | No active obstacle route; current geometry is prohibited | Stage behind evidence and package gates. |
| Complexity | high | Geometry, randomness, nested effects, destruction | Keep shared helpers low-level and ownership purpose-specific. |

## 10. Integration Status

Current Status: Draft
Evidence Summary:

- Static obstacle identities, setup placement, card/deck infrastructure, and
  accepted behavior exist.
- Active asteroid effect, canonical contour evidence, and cross-surface tests do not exist.

Outstanding Work:

- Approve canonical contour source/evidence; implement all required surfaces;
  pass applicable CON-003/TEST-003 evidence; align obstacle metadata; complete
  Owner review.

Approval State:

- Owner approval: not requested
- Reviewers required: Project Owner; gameplay/rules, architecture, Network/replay reviewers
- Review date: not applicable

## 11. Review History

| Reviewer | Date | Decision | Notes |
| --- | --- | --- | --- |
| Codex | 2026-09-12 | noted | Drafted from accepted authority and verified production evidence; no integration claim. |
