# DBG-001 — Authoritative Debug State Mutation

Status: Accepted
Accepted by: Project Owner
Accepted date: 2026-08-29

## Purpose

The debug menu exists to make game-state setup, manipulation, and rule verification fast and reliable during development.

State-changing debug actions must produce game states that are equivalent in authority, projection, networking, serialization, and replay behavior to states reached through normal gameplay.

The debug menu must not create a second or presentation-only path for changing authoritative game state.

## AS-IS Discovery Evidence

This section records observed implementation facts. It is not a statement of
accepted target architecture.

- Ship debug dragging and rotation currently mutate only `ShipToken`
  presentation transforms. `ShipInstance.pos_x`, `pos_y`, and `rotation_deg`
  remain unchanged.
- Squadron debug dragging and rotation have the same presentation-only path;
  `SquadronInstance.pos_x`, `pos_y`, and `rotation_deg` remain unchanged.
- `ExecuteManeuverCommand` and `MoveSquadronCommand` are not raw debug
  repositioning commands. Their complete semantics include gameplay legality,
  activation opportunities, lifecycle, and continuation effects.
- `DebugDealDamageCommand` adds a selected faceup card to durable ship state,
  but the debug UI currently draws and identity-overrides the card from the
  authoritative damage deck before submitting that command. The deck mutation
  is therefore outside the recorded command and current debug replay does not
  fully reproduce damage-deck state.
- Once a faceup card has been assigned, normal and debug paths converge on the
  same durable ship damage-card state and immediate/persistent rule-resolution
  infrastructure. This is useful BUG-032 evidence, but does not resolve
  BUG-032.
- In Network play, a client can currently submit debug damage through ordinary
  gameplay-side authorization, while the host submitter is constrained by the
  gameplay side it controls and cannot freely debug the opposing side.
- No current debug UI exposes direct hull, shield, speed, defense-token, or
  destroy/restore mutation.

## Requirements

### DBG-001-01 — Canonical State Authority

Any debug action that changes gameplay-relevant state must change the canonical authoritative game state.

The debug UI must not directly mutate presentation state as the authoritative result of a state-changing debug action.

Examples include:

- moving ships or squadrons;
- assigning damage cards;
- changing hull or shields;
- changing speed;
- changing defense-token state;
- destroying or restoring game objects;
- changing other gameplay-relevant properties.

Presentation must derive the resulting state through the normal projection path.

Debug commands may bypass normal gameplay legality when needed to establish a
test state, but they must preserve the existing structural invariants of the
authoritative state model. This requirement does not define new gameplay
invariants.

### DBG-001-02 — Authoritative Command Path

State-changing debug actions must use the authoritative command infrastructure.

An existing gameplay command may be reused only when its complete authoritative
semantics match the intended debug operation. The comparison includes
lifecycle, opportunity consumption, legality, continuation, and
phase/activation effects, not merely the final field mutation.

Where those semantics do not match, including where debug functionality must
bypass normal gameplay legality, a purpose-specific debug command is required.

Debug-specific commands must use the same authoritative command execution infrastructure as gameplay commands rather than establishing a separate debug mutation system.

### DBG-001-03 — Rule Integration

Debug operations intended to create gameplay conditions for rule testing must leave the game in a state that exercises the same authoritative rule infrastructure as normal gameplay.

Debug tooling must not require a separate implementation of the affected game rule.

Where a debug operation intentionally bypasses normal prerequisite gameplay in order to establish a test condition, that distinction must not cause subsequent rule processing to use a different rule implementation.

### DBG-001-04 — Replay Visibility

Every state-changing debug command must be represented in the authoritative replay/command history.

The replay must make it possible to identify:

- that a state-changing operation originated from debug tooling;
- which authoritative object was affected;
- the state-changing intent and all authoritative state changes necessary for
  deterministic replay.

A replay containing debug commands must reproduce the resulting authoritative
game state, including authoritative resources consumed or otherwise changed by
the debug operation.

Where one debug operation necessarily causes follow-up authoritative commands,
history must contain enough evidence to reconstruct the resulting state and to
understand that the sequence originated from debug setup. This requirement does
not require debug flags in ordinary canonical gameplay state or a generic
command-correlation framework.

### DBG-001-05 — Network Authority

In network play, state-changing debug authority belongs only to the
authoritative host. This authority is independent of which saved or gameplay
side the host currently controls.

Clients may not independently issue or authorize an authoritative
state-changing debug mutation.

Accepted debug commands must propagate through the normal authoritative
command, synchronization, projection, and filtering infrastructure.

Clients must derive accepted debug mutations through those same mechanisms.

### DBG-001-06 — Hot-Seat Consistency

The same state-changing debug command infrastructure must be usable in hot-seat play.

Debug behavior must not depend on whether the game is running in hot-seat or network mode except where authority or visibility legitimately differs.

### DBG-001-07 — Presentation-Only Debug Tools

Debug functionality that does not change gameplay state may remain local and does not require an authoritative command.

Examples include:

- range visualization;
- firing-arc visualization;
- displaying object identifiers;
- displaying targeting information;
- diagnostic overlays;
- displaying canonical coordinates or internal state.

The distinction between state-changing and observation-only debug functionality must remain explicit.

### DBG-001-08 — Canonical-State Inspection

Debug tooling should provide a simple way to inspect the canonical state of a selected game object.

For movable objects this should include at least the authoritative position and orientation.

This capability should make discrepancies between canonical state and presentation state directly observable during testing.

## Required Verification

The minimum trusted authoritative-debug slice must demonstrate at minimum:

1. Moving a ship through the debug menu changes its canonical position and orientation.
2. Moving a squadron through the debug menu changes its canonical position and orientation.
3. Normal presentation subsequently reflects each canonical repositioning.
4. Each repositioning is present in replay history and reproduces correctly.
5. Assigning a damage card through debug tooling changes canonical ship state
   and consumes the authoritative damage deck through the authoritative
   command path.
6. Subsequent damage-card rule processing uses the same authoritative rule
   infrastructure used by normal gameplay.
7. Canonical-state inspection exposes the selected movable object's
   authoritative position and orientation sufficiently to verify these paths.
8. In Hot-Seat, the same authoritative debug command infrastructure is usable.
9. In Network play, a host-issued debug repositioning and damage assignment
   propagates correctly to a client, and a client cannot independently issue
   or authorize either mutation.
10. Save/load and replay after each operation reconstruct the resulting
    authoritative state, including damage-deck state after debug damage setup.

## Non-Goals

DBG-001 does not require:

- replacing presentation-only diagnostic tools with commands;
- forcing debug actions to obey normal gameplay legality where doing so would prevent useful test-state construction;
- creating a separate debug command processor;
- duplicating gameplay rule implementations for debug use;
- migrating every possible future state-changing debug operation in the first
  implementation slice.

Other state-changing debug actions may migrate incrementally when they exist
or become necessary. The minimum trusted slice is limited to ship
repositioning, squadron repositioning, damage-card assignment with
authoritative deck consumption, and the inspection, Hot-Seat, Network, replay,
and save/load support required to verify them.

## Relationship to BUG-032

BUG-032 exposed a discrepancy between damage-card behavior reached through normal gameplay and damage-card behavior exercised through debug tooling.

The working debug damage-card path is useful diagnostic evidence, but it cannot
be treated as a trustworthy reference path until its canonical deck mutation,
Network authority, and replay behavior are authoritative and reproducible.

Discovery shows that, after setup, normal and debug faceup-card paths use the
same durable ship-card state and rule-resolution infrastructure. That
convergence is useful comparison evidence only after the debug setup path meets
this requirement; it does not diagnose or resolve BUG-032.

BUG-032 therefore depends on DBG-001.

BUG-032 must not be considered resolved solely because the Injured Crew gameplay path is repaired.

Before BUG-032 can be accepted as resolved:

1. the relevant DBG-001 authoritative debug infrastructure must be implemented;
2. Injured Crew must be tested through authoritative debug setup;
3. Injured Crew must be tested through its normal gameplay path;
4. both paths must reach the same authoritative damage-card rule behavior;
5. replay evidence must demonstrate the relevant state transitions.

## Open Implementation Questions

- Whether the bounded ship and squadron repositioning scope is represented by
  one purpose-specific command class or two.
- The narrow payload and validation design that records authoritative
  damage-deck consumption and any necessary debug-origin follow-up evidence.
