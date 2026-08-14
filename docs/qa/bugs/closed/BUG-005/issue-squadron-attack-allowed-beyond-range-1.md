# BUG-005 — Squadron Attack Allowed Beyond Range 1

Severity: High
Area: Squadron Phase / Attack Validation
Layer: Rules

## Expected

Squadrons may attack only targets within squadron attack range.

A squadron attack must not be selectable, authorized, or resolved when the target is beyond Range 1.

Ship attack ranges remain governed separately by the attack dice available at close, medium, and long range.

## Actual

An X-wing squadron was able to attack a TIE fighter squadron positioned beyond Range 1.

The out-of-range target was accepted and the attack was resolved.

## Reproduction

1. Enter the Squadron Phase.
2. Activate an X-wing squadron.
3. Position or identify an enemy TIE fighter squadron beyond Range 1.
4. Attempt to select and attack that squadron.

Result:
The out-of-range squadron can be selected and attacked.

Frequency: Once

## Evidence

annotation_20260801_173628_001.json

The captured state shows:

- the game is in Round 3 of the Squadron Phase;
- the attacking X-wing squadron has already activated;
- enemy TIE fighter squadrons are present at several positions;
- squadron attack history has been recorded in ship_target_attack_counts;
- the annotation records that the attack was resolved against a target beyond Range 1.

The snapshot was captured after the attack completed, so it does not preserve the target-selection interaction or measured attack range at the moment of authorization.

## Resolution

Root cause:

Fix:

Verification:

- Place an enemy squadron just inside Range 1 and verify that it can be attacked.
- Place an enemy squadron just beyond Range 1 and verify that it is not projected as a legal target.
- Submit an attack command against a squadron beyond Range 1 and verify that the authoritative command layer rejects it.
- Verify the same behavior for multiple squadron types and both players.
- Verify that ship attacks continue to use their normal close, medium, and long-range rules.

## Layer Definition

### Rules

Game mechanics or rules behave incorrectly.

### Command Flow

Commands, interactions, or game progression execute incorrectly, become unavailable, or occur in the wrong order.

### Projection

Displayed game information differs from the authoritative game state.

### Presentation

Visual elements, text, layout, or UI controls behave incorrectly without affecting the underlying game state.

### Architecture

The defect appears to originate from system ownership, lifecycle, or architectural responsibilities.

### Serialization

Save, load, reconnect, replay, or persisted game state behaves incorrectly.

### Networking

Remote synchronization, visibility, or multiplayer state differs from the authoritative game state.

### Performance

The game exhibits excessive loading time, poor responsiveness, frame drops, freezes, or resource issues.
