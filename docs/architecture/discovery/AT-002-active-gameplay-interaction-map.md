# AT-002: Active-Gameplay Interaction Map

Status: AS-IS discovery evidence (descriptive, non-normative)
Related task: AT-002
Related boundary: BC-003
Related accepted authority: ADR-001, for current-attack ownership only
Date: 2026-08-20

## Purpose and scope

This document preserves a high-level discovery of Armada's observed active-gameplay interaction flow, from Command Phase through game completion. It is repository evidence for future AT-002 work, not an accepted ADR, Contract, or TO-BE UI/interaction specification.

It records current behavior and mixed ownership where found. It does not resolve those observations or prescribe a redesign.

## Evidence inspected

- `docs/game_flow.md`
- `docs/current_state_architecture_maps.md`
- `docs/ARCHITECTURE_BOUNDARY_CANDIDATES.md` (BC-003)
- `docs/REALITY_GAP_REGISTER.md` (RG-003, RG-004, RG-014)
- `docs/architecture/adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md`
- `GameState`, phase/round commands, `FlowSpec`, `InteractionFlow`, `UIProjector`, `ModalRouter`, `GameManager`, and the Command/Ship/Squadron board controllers

## Level-1 active-gameplay interaction map

```text
Active game
├─ Command Phase
│  └─ Assign command dials
├─ Ship Phase
│  ├─ Select and activate a ship
│  └─ Resolve that ship's activation
│     ├─ Squadron command
│     ├─ Repair
│     ├─ Attack
│     └─ Maneuver / possible squadron displacement
├─ Squadron Phase
│  └─ Select and activate squadrons
│     ├─ Move
│     └─ Attack
├─ Shared Attack Flow
│  └─ Declare → roll → modify → defend → resolve
├─ Status Phase
│  └─ Cleanup / any optional status choices
└─ Completion / transition
   ├─ Start next round
   └─ End game by elimination or round limit
```

The shared Attack Flow is entered from Ship and Squadron activation; it is not itself a `GamePhase`.

## Level-2 decomposition

```text
Command Phase
└─ Dial assignment
   ├─ Select/assign this player's ship dials
   └─ Wait for the other player's submission
      → Ship Phase

Ship Phase
├─ Optional start-of-phase Tarkin choice
├─ Await eligible ship selection
└─ Active ship
   ├─ Activation sequence open
   ├─ Squadron-command opportunity
   ├─ Repair opportunity
   ├─ Attack opportunity → Shared Attack Flow
   ├─ Maneuver opportunity
   │  └─ If overlap: opposing player places displaced squadrons
   └─ End activation / pass turn
      → next ship player, or Squadron Phase

Squadron Phase
├─ Await eligible squadron selection
└─ Selected squadron / action choice
   ├─ Move
   ├─ Attack → Shared Attack Flow
   └─ Complete activation / pass turn
      → next squadron player, or Status Phase

Shared Attack Flow
├─ Attacker declares target
├─ Attacker rolls dice
├─ Attacker modifies dice
├─ Defender responds with defense tokens
├─ Attacker resolves damage
├─ Conditional counter choice
└─ Conditional critical/immediate-effect choice
   → return to parent activation, next attack, or no active flow

Status Phase
├─ Deterministic cleanup
└─ Optional status-rule choice, where present
   → next Command Phase, unless game end

Completion / transition
├─ Round transition: Status → StartRoundCommand → Command Phase
└─ Game end: elimination or round-six check → scoring/result event
```

## State classification

| Node | Primary state type | Observed distinction |
| --- | --- | --- |
| Round, phase, initiative, fleets, activation facts | Canonical gameplay | Serialized `GameState`; phase changes use `StartRoundCommand` / `AdvancePhaseCommand`. |
| Ship and squadron activation eligibility/progress | Canonical gameplay, with runtime coordination | Durable unit state and Squadron Phase progress live in `GameState`; `GameManager.active_player` is runtime orchestration state. |
| `InteractionFlow` step/controller/payload | Interaction/decision routing | Serialized and projected; it is not canonical current-attack gameplay truth under ADR-001. |
| Current attack facts | Canonical gameplay | `GameState.CurrentAttackState` is the accepted authority for active-attack facts. |
| Timing-window lifecycle | Canonical gameplay, separate boundary | `TimingWindowState` owns lifecycle; it is not the attack-state owner. |
| `FlowSpec` | Interaction metadata | Static definitions of known steps, controller roles, modal kinds, and applicable command surfaces. |
| `UIIntent`, HUD text, modal kind, affordances | Presentation state | Viewer-specific projection by `UIProjector`. |
| Modal lifecycle, camera, handoff overlay | Presentation state | `ModalRouter` and `GameBoard`; turn-transition overlays are outside persisted `InteractionFlow`. |
| Target selection, attack panels/FSM, command-dial queue, activation context | Mixed / scene-controller workflow state | Local workflow or preview state; some paths assemble or patch interaction payloads. |

## Structural observations

- **Attack authority is explicitly separated.** ADR-001 makes `CurrentAttackState` and replayable commands authoritative for attack facts and semantic transitions. `InteractionFlow`, `UIProjector`, `ModalRouter`, and scene controllers are non-authoritative consumers for that scope.
- **Non-attack flow ownership remains open.** AT-002 is only complete for current attacks; broader Command, Ship, Squadron, Status, and game-end interaction ownership remains an open BC-003 area.
- **Command Phase has a controller-owned recovery path.** `StartRoundCommand` creates Command flow, but `CommandPhaseController.begin_command_dial_flow()` rebuilds the dial-picker queue after handoff/turn-transition presentation events. Submission and assigning-player state live in `GameManager`, not in `GameState.interaction_flow`.
- **Squadron action substeps are not fully canonicalized as interaction states.** `SQUAD_MOVE` and `SQUAD_ATTACK` remain compatibility steps, while modal-local state, durable movement commands, and the shared Attack Flow commonly carry runtime behavior.
- **Modal restoration is mixed.** `ModalRouter` centrally projects post-command intent but includes command-specific lifecycle/recovery gates, including displacement opening and recovery of the ship's squadron-command surface. Equal projected state therefore does not always imply one uniform modal-opening path.
- **Game end lacks a clear persisted interaction-flow representation.** `GAME_OVER` exists in `FlowSpec` and `UIProjector`, while `GameManager.end_game()` calculates scoring and emits `game_ended` without setting that flow. A restored/reconnected end-game presentation does not appear to have the same single-state reconstruction path as an active attack.
- **Status is partly projected and partly automatic.** Cleanup writes `STATUS_CLEANUP`, chiefly for optional rule choices such as ECM. Without such a choice, orchestration can advance immediately, so generic Status UI is not a consistent durable player-facing state.

## Recommended next decomposition

1. **Ship Phase / Ship Activation** — it links phase progression, activation ownership, local `ActivationContext`, command-backed steps, the shared Attack Flow, displacement, and multiple presentation recovery paths.
2. **Command Phase** — it exposes the split between canonical phase state, `GameManager` runtime coordination, handoff UI, and controller-owned dial-picker state.

The completed Ship Phase / Ship Activation follow-on discovery is preserved in [AT-002 Ship Phase / Ship Activation Interaction Map](AT-002-ship-activation-interaction-map.md).
