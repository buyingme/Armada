# DBG-001 — Authoritative Debug State Mutation

Status: Draft

## Purpose

The debug menu exists to make game-state setup, manipulation, and rule verification fast and reliable during development.

State-changing debug actions must produce game states that are equivalent in authority, projection, networking, serialization, and replay behavior to states reached through normal gameplay.

The debug menu must not create a second or presentation-only path for changing authoritative game state.

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

### DBG-001-02 — Authoritative Command Path

State-changing debug actions must use the authoritative command infrastructure.

Where an existing gameplay command correctly represents the intended operation, it may be reused.

Where debug functionality requires behavior that normal gameplay does not permit, a debug-specific command may be used.

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
- the state-changing intent and information necessary for deterministic replay.

A replay containing debug commands must reproduce the resulting authoritative game state.

### DBG-001-05 — Network Authority

In network play, only the authoritative host may issue state-changing debug commands.

Accepted debug commands must propagate through the normal authoritative network synchronization path.

Clients must derive the resulting state through the same synchronization/projection mechanisms used for ordinary gameplay.

Clients must not independently perform authoritative debug mutations.

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

The implementation must demonstrate at minimum:

1. Moving a ship through the debug menu changes its canonical position and orientation.
2. Normal presentation subsequently reflects that canonical position.
3. The movement is present in replay history and reproduces correctly.
4. In network play, a host-issued debug movement is reflected correctly on the client.
5. The client cannot independently issue an authoritative state-changing debug operation.
6. Assigning a damage card through debug tooling changes canonical state through the authoritative command path.
7. Subsequent damage-card rule processing uses the same authoritative rule infrastructure used by normal gameplay.
8. Save/load or replay after debug manipulation reconstructs the authoritative state correctly.

## Non-Goals

DBG-001 does not require:

- replacing presentation-only diagnostic tools with commands;
- forcing debug actions to obey normal gameplay legality where doing so would prevent useful test-state construction;
- creating a separate debug command processor;
- duplicating gameplay rule implementations for debug use;
- migrating every existing debug function in one implementation step unless required to eliminate an identified non-authoritative mutation path.

## Relationship to BUG-032

BUG-032 exposed a discrepancy between damage-card behavior reached through normal gameplay and damage-card behavior exercised through debug tooling.

The working debug damage-card path is useful diagnostic evidence, but the debug infrastructure itself must first be made authoritative and replayable before it can be treated as a trustworthy reference path.

BUG-032 therefore depends on DBG-001.

BUG-032 must not be considered resolved solely because the Injured Crew gameplay path is repaired.

Before BUG-032 can be accepted as resolved:

1. the relevant DBG-001 authoritative debug infrastructure must be implemented;
2. Injured Crew must be tested through authoritative debug setup;
3. Injured Crew must be tested through its normal gameplay path;
4. both paths must reach the same authoritative damage-card rule behavior;
5. replay evidence must demonstrate the relevant state transitions.

## Open Implementation Questions

The implementation/audit should determine:

- which existing debug actions currently mutate presentation objects directly;
- which debug actions mutate canonical state without using commands;
- which existing gameplay commands can safely be reused;
- which operations require dedicated debug-specific commands;
- whether current damage-card debug injection invokes rule processing differently from normal damage resolution;
- whether ship/squadron debug displacement currently changes scene transforms without changing canonical geometry.
