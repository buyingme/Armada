# BUG-002 — Attack Sequence Early Termination

Severity: High
Area: Ship Phase / Attack Execution
Layer: Command Flow

## Expected

A ship may normally perform up to two attacks during its activation, using a different hull zone for each attack.

When a hull zone performs an anti-squadron attack, that attack must be resolvable against every eligible enemy squadron in that hull zone's firing arc, one squadron at a time.

After that anti-squadron attack finishes, the ship must retain the opportunity to perform its second legal attack from another hull zone.

 The rules are presented here: SWM-RULES-REFERENCE-GUIDE-150.md

## Actual

Attack flow terminates after one attack from a ship. The second attack cannot commence. Multiple attacks against squadrons cannot be done.

## Reproduction

1. Activate a ship with at least two legal attacks.
2. Select a hull zone containing multiple enemy squadrons.
3. Resolve and confirm the attack against the first squadron.
4. Attempt to attack another eligible squadron or begin the ship's second attack.

Result: no further attack can be initiated.

Reproduced with both the Nebulon-B and Victory II.

## Evidence

annotation_20260727_195551_001.json
annotation_20260727_195741_001.json
evidence after first fix attempt:
annotation_20260801_075338_001.json
annotation_20260801_075833_003.json

## Resolution

Root cause:
Fix:
Verification: 20260801, verified by user in both network and hotseat mode.

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
