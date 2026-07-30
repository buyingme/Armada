# BUG-003 — Attack Can Be Skipped After Commitment

Severity: High
Area: Attack Execution
Layer: Command Flow

## Expected

An attack may be skipped or cancelled only before it reaches its commitment point.

After the attack has been confirmed and dice have been rolled:

- the attack must continue through its remaining resolution steps;
- the Skip Attack action must no longer be projected;
- any attempted skip command must be rejected by the authoritative command flow.

## Actual

The player can still skip an attack after it has been confirmed and the attack dice have been rolled.

This allows an already committed attack with authoritative dice results to be abandoned before resolution is complete.

## Reproduction

1. Activate a squadron and select a legal target.
2. Confirm the attack.
3. Roll the attack dice.
4. Attempt to skip the attack during the attack-modification stage.

Result: The attack can still be skipped after dice have been rolled.

Frequency: Always

## Evidence

annotation_20260729_065933_002.json

The captured state shows:

- an active attack with ID attack:70;
- the attacker and defender already selected;
- obstruction resolved;
- four blue dice rolled;
- authoritative dice results present;
- attack stage attack_modify;
- interaction-flow step 18.

## Investigation Hint

The issue is visible after the attack transitions from pre_roll to attack_modify.

Inspect how the availability and authorization of the Skip Attack action are derived after dice results become authoritative.

## Resolution

Root cause:

Fix:

Verification:

- Confirm and roll dice for an attack.
- Verify that Skip Attack is no longer projected after the attack becomes committed.
- Verify that a skip command submitted during attack_modify is rejected.
- Verify that rejecting the command does not alter the attack state or dice results.
- Verify that the attack can continue through normal resolution.
- Verify the behavior for both ship and squadron attacks.

## Layer Definition

### Rules

Game mechanics or rules behave incorrectly.

### Command Flow

Commands, interactions, or game progression execute incorrectly, become unavailable, remain available when invalid, or occur in the wrong order.

### Projection

Displayed game information or available actions differ from the authoritative game state.

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
