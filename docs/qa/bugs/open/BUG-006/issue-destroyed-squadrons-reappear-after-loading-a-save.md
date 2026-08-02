# BUG-006 — Destroyed Squadrons Reappear After Loading a Save

Severity: High
Area: Save Loading / Board Projection
Layer: Projection

## Expected

When a saved or seed game is loaded, squadrons marked as destroyed must not appear on the active game board.

Their destroyed state may remain in the authoritative save data for scoring, history, or replay purposes, but they must not be instantiated as active board pieces or presented as selectable game entities.

This behavior must be consistent in both hot-seat and network play.

## Actual

Squadrons destroyed before the save was created reappear on the board when that save is loaded.

They are displayed at the positions where they were destroyed, even though the loaded game state marks them as destroyed with zero remaining hull.

The issue occurs in both hot-seat and network play.

## Reproduction

### Hot-seat

1. Start or continue a hot-seat game.
2. Destroy one or more squadrons.
3. Create a save after the squadrons have been destroyed.
4. Load the save as a seed or continued game.
5. Inspect the positions where the squadrons were destroyed.

Result:
The destroyed squadrons appear again at their final board positions.

### Network

1. Start or continue a network game.
2. Destroy a squadron.
3. Create a save after the squadron has been destroyed.
4. Load the save as a seed or continued network game.
5. Inspect the position where the squadron was destroyed.

Result:
The destroyed squadron appears again at its final board position.

Frequency: Always

## Evidence

NEWLearningScenario_HotSeat_R3_Ship.json

The hot-seat save contains two destroyed X-wing squadrons:

- player 0, squadron index 2:
  - current_hull: 0
  - destroyed: true
  - position approximately (0.5692, 0.4962)
- player 0, squadron index 3:
  - current_hull: 0
  - destroyed: true
  - position approximately (0.5316, 0.4996)

NEW_LearningScenario_Network_R3_Ship.json

The network save contains one destroyed TIE fighter squadron:

- player 1, squadron index 3:
  - current_hull: 0
  - destroyed: true
  - position approximately (0.5232, 0.4042)

Both saves were created during Round 3 of the Ship Phase, after the affected squadrons had already been destroyed.

The persisted state correctly records the squadrons as destroyed. The defect is that loading the state causes them to be displayed again on the active board.

## Resolution

Root cause:

Fix:

Verification:

- Load the provided hot-seat save.
- Verify that both destroyed X-wing squadrons remain absent from the board.
- Load the provided network save.
- Verify that the destroyed TIE fighter squadron remains absent from the board.
- Verify that surviving squadrons are still instantiated at their saved positions.
- Verify that destroyed squadrons are not selectable, targetable, movable, or included in active interaction projections.
- Verify that destroyed squadrons remain available where required for scoring, history, replay, or other authoritative state uses.
- Verify the behavior for both host and remote network clients.
- Save and reload a game containing newly destroyed squadrons and verify that they do not reappear.
- Verify that ships or other destroyed entity types are not affected by the same load-projection defect.

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
