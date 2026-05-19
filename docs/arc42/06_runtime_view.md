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
    ├─ Step 1: Reveal Command Dial   ✓ (already done)
    ├─ Step 2: Squadron Command      → "Execute Squadron ►" (if dial/token available; else auto-skip)
    │    └─ Opens SquadronActivationModal → move + attack flow → returns to modal
    ├─ Step 3: Repair Command        → "Execute Repair ►" (if dial/token available; else auto-skip)
    │    └─ Opens RepairPanel → recover shields / discard damage → returns to modal
    ├─ Step 4: Attack                → "Execute Attack ►" (always available)
    │    └─ Opens AttackExecutor in EXEC mode → targeting, dice, defense, damage → returns to modal
    └─ Step 5: Execute Maneuver      → "Execute Maneuver ►"
         │
         ▼
    Modal stays open but button enters "Execute" phase
         │
         ▼  (player presses "Execute Maneuver ►")
         │
    Maneuver tool appears on ship (activation mode)
    Player adjusts joints, speed (±1/±2 via Navigate), yaw bonus
         │
         ▼
    Player reopens modal → "Commit Maneuver ►" button
         │
         ▼  (player presses "Commit Maneuver ►")
         │
    ┌─ OverlapResolver.check_ship_ship_overlap() ─┐
    │  If collision detected:                      │
    │    Speed reduced iteratively until no overlap │
    │    Both ships take 1 facedown damage card    │
    │    Amber collision label shown in modal      │
    └──────────────────────────────────────────────┘
         │
    ┌─ OverlapResolver.find_overlapped_squadrons() ─┐
    │  If squadron overlap detected:                 │
    │    Camera flips 180° to opposing player        │
    │    DisplacementModal opens (checklist)          │
    │    Player places each squadron at ship edge     │
    │    "Commit Placement ►" → camera flips back     │
    └────────────────────────────────────────────────┘
         │
    Ship snaps to final position
    Navigate token removed (if spent)
    EventBus.ship_moved emitted
    Modal stays open — all 5 steps show green ✓
         │
         ▼
    "End Activation ►" button appears at bottom of modal
         │
         ▼  (player presses)
         │
    EventBus.activation_ended emitted → next player's turn
    "Your Turn" banner shown for next player
```

### Key Participants

| Component | Role |
|-----------|------|
| `ShipActivationState` (RefCounted) | Tracks current step, spent commands |
| `ActivationModal` (Control) | Centred UI panel, step sequence, two-phase button, collision label, End Activation button |
| `ManeuverToolState` (RefCounted) | Activation-mode state: Navigate budget, yaw bonus |
| `ManeuverToolScene` (Node2D) | Visual tool with joints, speed buttons, ghost |
| `OverlapResolver` (RefCounted) | Ship–ship overlap (speed reduction + damage), ship–squadron overlap (displacement list) |
| `DisplacementModal` (Control) | Squadron displacement checklist: check/uncheck, snap-to-edge, commit |
| `CommandTokenManager` (RefCounted) | Spends Navigate token on commit |
| `EventBus` (Autoload) | Signals: `ship_activated`, `ship_moved`, `activation_ended` |

## 6.3 Attack Resolution Sequence

The attack system is split between `GameBoard` (activation flow) and
`AttackExecutor` (all attack-specific logic).

### 6.3.1 Free-form Attack Simulator

```
Player presses "A" or Attack toolbar button
    │
    ▼
EventBus.attack_simulator_requested  →  GameBoard._on_attack_simulator_requested()
    │                                         └─ delegates to AttackExecutor.on_simulator_requested()
    ▼
AttackExecutor enters SELECTING mode — click a friendly ship hull zone
    │
    ├─ Player clicks hull zone  →  attacker selected, enter TARGET_SELECTING mode
    │    └─ Arcs drawn, range/LOS ready
    │
    ├─ Player clicks enemy ship/squadron  →  target selected
    │    ├─ LOS traced (obstruction check)
    │    ├─ Range computed (dice colour at range)
    │    └─ Arc match validated (target in firing arc?)
    │
    └─ Press Escape / click empty  →  deselect and return to SELECTING
```

### 6.3.2 Attack Execution (Activation Step 4)

```
ActivationModal Step 4 ("Attack")  →  GameBoard._on_attack_step_entered()
    │                                       └─ AttackExecutor.start_ship_attack(ship_token)
    ▼
AttackExecutor enters EXEC mode
    │
    ├─ 1  Declare target + hull zone  (player clicks target)
    ├─ 2  Roll attack dice (Concentrate Fire dial/token may reroll)
    ├─ 3  Spend accuracy icons → lock defence tokens
    ├─ 4  Defender spends defence tokens (Evade, Brace, Redirect, Scatter, Contain)
    ├─ 5  Resolve damage → shields first, overflow to hull, draw damage cards
    └─ 6  Declare additional attack (if valid targets remain) or finish
              │
              ▼
         AttackExecutor emits attack_exec_completed  →  GameBoard._on_attack_exec_completed()
              └─ Advances ShipActivationState, reopens ActivationModal
```

### Key Participants

| Component | Role |
|-----------|------|
| `AttackExecutor` (Node) | All attack logic: simulator, execution, dice, defence tokens, damage |
| `GameBoard` (Node2D) | Delegates to AttackExecutor, manages activation flow callbacks |
| `ShipActivationState` (RefCounted) | Tracks current activation step |
| `DicePool` (RefCounted) | Dice rolling and modification |
| `DamageDeck` (RefCounted) | Draw damage cards for hull damage |
| `AttackDicePanel` (Control) | Dice display, reroll, confirm buttons |
| `EventBus` (Autoload) | Signals: `attack_simulator_requested`, `attack_dice_confirmed`, … |

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

## 6.5 Squadron Phase Sequence

```
Ship Phase ends → GameManager._begin_squadron_phase()
    │
    ├─ EffectFactory.register_squadron_keywords(game_state, initiative_player)
    │    └─ Scans all squadrons for keywords (Bomber, Escort, Swarm)
    │       and registers GameEffect instances in EffectRegistry
    │
    ├─ If neither player has squadrons → skip to Status Phase
    │
    ▼
Initiative player becomes active_player
_squadrons_activated_this_turn = 0
    │
    ▼
┌─────────────────────────────┐
│ Active Player's Turn        │
│                             │
│  Player activates squadron  │──→ GameManager.activate_squadron(sq)
│    - Must own squadron      │     ├─ Validates ownership
│    - Must not be activated  │     ├─ Validates not already activated
│    - No double activation   │     └─ Sets _activating_squadron
│                             │
│  Squadron moves + attacks   │    SquadronActivationModal handles move + attack
│                             │    SquadronMover validates distance-band placement
│  EventBus.squadron_activation_ended.emit(squadron)
│    └─ _on_squadron_activation_ended()
│        ├─ squadron.activated_this_round = true
│        ├─ _squadrons_activated_this_turn += 1
│        └─ If count == 2 or no more unactivated → switch turns
│                             │
└─────────┬───────────────────┘
          │
          ▼
_advance_squadron_phase_turn()
    ├─ Switch active player
    ├─ Reset _squadrons_activated_this_turn = 0
    ├─ If new player has unactivated squadrons → their turn
    ├─ If not but original player does → swap back
    └─ If both done → all remaining activated → Status Phase
```

### Effect/Hook Pipeline

The EffectRegistry resolves named hook points throughout the game loop.
Effects (keywords, damage cards, upgrades) register for hooks and mutate
a shared EffectContext when triggered. See §8.9 for the full hook catalogue.

```
Attack Flow Hook Sequence
─────────────────────────
AttackExecutor (target selection)
    ├─ resolve_hook(&"ATTACK_VALIDATE_TARGET", ctx)    ── Coolant Discharge, Depowered Armament, Disengaged FC
    │
AttackExecutor (dice pool assembly)
    ├─ resolve_hook(&"ATTACK_GATHER_DICE", ctx)         ── Remaining legacy gather effects
    ├─ RuleRegistry.modifiers_for(ATTACK/ATTACK_ROLL,
    │     "dice_pool")                                  ── Damaged Munitions / Point-Defense Failure choice/removal
    │
AttackExecutor (accuracy spending)
    ├─ resolve_hook(&"ATTACK_SPEND_ACCURACY", ctx)      ── Blinded Gunners
    │
AttackExecutor (defense token spending)
    ├─ RuleRegistry.blockers_for("defense_token_spend") ── Capacitor Failure UI eligibility
    ├─ RuleRegistry.validators_for("commit_defense" /
    │     "spend_defense_token" / "select_redirect_zone")
    │                                                   ── Capacitor Failure command safety
    ├─ resolve_hook(&"DEFENSE_VALIDATE_TOKEN", ctx)     ── Faulty Countermeasures legacy UI bridge
    │
AttackExecutor (resolve critical)
    ├─ resolve_hook(&"ATTACK_RESOLVE_CRITICAL", ctx)    ── Targeter Disruption
    │
AttackExecutor._calc_attack_damage(results)
    ├─ resolve_hook(&"ATTACK_CALC_DAMAGE", ctx)         ── Bomber (existing)

Movement Flow Hook Sequence
───────────────────────────
ManeuverTool (yaw calculation)
    ├─ resolve_hook(&"MANEUVER_DETERMINE_YAWS", ctx)    ── Thrust Control Malfunction
    │
After maneuver committed
    ├─ resolve_hook(&"AFTER_MANEUVER_EXECUTE", ctx)     ── Ruptured Engine, Damaged Controls
    │
Navigate command / speed change
    ├─ resolve_hook(&"ON_SPEED_CHANGE", ctx)             ── Thruster Fissure

Command & Status Hooks
──────────────────────
Ship activation (before dial reveal)
    ├─ UIProjector.affordances via RuleRegistry ENABLER  ── Crew Panic pre-reveal choice

Repair command resolution
    ├─ resolve_hook(&"CALC_ENGINEERING_VALUE", ctx)       ── Power Failure
    ├─ RuleRegistry.blockers_for("repair_shield")        ── Capacitor Failure UI eligibility
    ├─ RuleRegistry.validators_for("repair_action")      ── Capacitor Failure command safety
    ├─ resolve_hook(&"REPAIR_VALIDATE_SHIELD", ctx)      ── Remaining legacy repair blockers

Status phase (token readying)
    ├─ RuleRegistry.modifiers_for("defense_token_readying") ── Compartment Fire

Command token gain
    ├─ resolve_hook(&"ON_COMMAND_TOKEN_GAIN", ctx)       ── Life Support Failure
```

### Engagement Resolution

```
EngagementResolver.get_engaged_enemies(squadron, all_squadrons)
    │
    ├─ For each enemy squadron:
    │    ├─ _edge_distance(pos_a, radius_a, pos_b, radius_b)
    │    │    = max(0, center_distance - radius_a - radius_b)
    │    └─ If edge_distance <= _get_distance_1_px() → engaged
    │
    └─ Returns Array[Dictionary] of engaged enemies

EngagementResolver.get_valid_engaged_targets(squadron, engaged_enemies)
    │
    ├─ Check if any engaged enemy has "escort" keyword
    ├─ If yes → return only Escort squadrons
    └─ If no  → return all engaged enemies
```

### Key Participants

| Component | Role |
|-----------|------|
| `GameManager` (Autoload) | Orchestrates squadron phase turns, activation validation |
| `EffectRegistry` (RefCounted) | Resolves hook points, dispatches to registered effects |
| `EffectFactory` (RefCounted) | Scans squadrons, creates/registers keyword effects |
| `EffectContext` (RefCounted) | Mutable data bag for hook pipeline |
| `EngagementResolver` (RefCounted) | Distance-1 engagement checks, valid target filtering |
| `SquadronMover` (RefCounted) | Movement distance + overlap validation |
| `BomberEffect` (GameEffect) | Recalculates damage using `Dice.calculate_damage()` vs ships |
| `EscortEffect` (GameEffect) | Cancels attacks targeting non-Escort when Escort engaged |
| `SwarmEffect` (GameEffect) | Rerolls worst die when friendly squadron also engaged |
| `EventBus` (Autoload) | `squadron_activation_ended` signal |
