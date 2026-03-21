# 6. Runtime View

## 6.1 Game Round Sequence

```
Round Start
    │
    ▼
┌──────────────┐
│ Command Phase │  Both players secretly assign command dials
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  Ship Phase   │  Players alternate activating ships
│               │  (reveal command, attack, move)
└──────┬───────┘
       │
       ▼
┌──────────────┐
│Squadron Phase │  Players alternate activating squadrons
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Status Phase  │  Ready exhausted tokens, flip initiative
└──────┬───────┘
       │
       ▼
  Round End (or Game End after round 6)
```

## 6.2 Ship Activation Sequence

```
Player drags command dial → ship token (or card panel)
    │
    ├─ If dragged to card panel → convert dial to token
    │    └─ If token overflow → discard prompt → resolved
    │
    ▼
Dial revealed (icon behind base)
    │
    ▼
"Show Activation Sequence" button appears (bottom-centre)
    │
    ▼  (player presses)
    │
Activation Modal opens (centred, dark-blue panel)
    │
    ├─ Step 1: Reveal Command Dial ✓ (already done)
    ├─ Step 2: Squadron Command   → auto-skip ("Not yet implemented")
    ├─ Step 3: Repair Command     → auto-skip
    ├─ Step 4: Attack             → auto-skip
    └─ Step 5: Execute Maneuver   → active
         │
         ▼
    "Execute Maneuver ►" button in modal
         │
         ▼  (player presses)
         │
    Modal closes → maneuver tool appears on ship (activation mode)
    Player adjusts joints, speed (±1/±2 via Navigate), yaw bonus
         │
         ▼
    Player reopens modal → "Commit Maneuver ►" button
         │
         ▼  (player presses)
         │
    Ship snaps to final position
    Navigate token removed (if spent)
    EventBus.ship_moved emitted
    Activation auto-ends → next player's turn
```

### Key Participants

| Component | Role |
|-----------|------|
| `ShipActivationState` (RefCounted) | Tracks current step, spent commands |
| `ActivationModal` (Control) | Centred UI panel, step sequence, two-phase button |
| `ManeuverToolState` (RefCounted) | Activation-mode state: Navigate budget, yaw bonus |
| `ManeuverToolScene` (Node2D) | Visual tool with joints, speed buttons, ghost |
| `CommandTokenManager` (RefCounted) | Spends Navigate token on commit |
| `EventBus` (Autoload) | Signals: `ship_activated`, `ship_moved`, `activation_ended` |

## 6.3 Attack Resolution Sequence

> **TODO:** Detailed sequence diagrams will be created during Phase 6.

## 6.4 Movement Sequence

```
Maneuver tool displayed (activation or simulation mode)
    │
    ▼
Segments computed from ship transform + joint angles
    │
    ├─ Joint click (L/R) → rotate joint ± 1 click
    │    └─ Clamped to nav chart max yaw (+ Navigate bonus if active)
    │
    ├─ Speed +/− button → add/remove segment
    │    ├─ Activation mode: writes ShipInstance.current_speed
    │    │   (gated by Navigate dial/token budget)
    │    └─ Simulation mode: preview only, no state change
    │
    ▼
Ghost ship rendered at computed final position
    │
    ├─ Auto side-switching: bend direction determines tool side
    │    (port bend → left side, starboard → right)
    │
    ▼  (commit — activation mode only)
    │
Ship.global_position = ghost position
Ship.global_rotation = ghost rotation
Maneuver tool dismissed
```

### Chain Computation

1. Start at ship's front notch (orientation = ship heading)
2. Advance by segment 0's length
3. At each active joint, rotate heading by joint angle
4. Advance by next segment's length
5. After last active segment, contact points determine final ship placement

All pixel dimensions read from `scale_config.json`.
