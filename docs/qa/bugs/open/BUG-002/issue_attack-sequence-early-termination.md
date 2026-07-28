# BUG-002 — Attack Sequence Early Termination

Severity: Critical
Area: Ship Phase / Attack Execution
Layer: Command Flow

## Expected

Attack flow is according to the rules. A ship can make a total of two attacks, each one from a different hull zone. attacks against squadrons should be handeled correctly. Multiple attacks should be possible if multiple squadrons are within a single hull zone. The rules are presented here: SWM-RULES-REFERENCE-GUIDE-150.md

## Actual

Attack flow terminates after one attack from a ship. The second attack cannot commence. Multiple attacks against squadrons cannot be done.

## Reproduction

Always

## Evidence

annotation_20260727_195551_001.json
annotation_20260727_195741_001.json

## Resolution

Root cause:
Fix:
Verification:

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
