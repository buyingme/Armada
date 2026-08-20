# AT-002: Ship Phase / Ship Activation Interaction Map

Status: AS-IS discovery evidence (descriptive, non-normative)  
Related task: AT-002  
Related boundary: BC-003  
Authority posture: subordinate to applicable accepted architecture authority, including ADR-001, ADR-006, CON-006, and CON-007  
Date: 2026-08-20

## Purpose and scope

This document preserves the completed AS-IS Ship Phase / Ship Activation discovery. It is repository evidence for AT-002 / BC-003. It is not an accepted ADR, Contract, or TO-BE UI/interaction specification.

It records observed repository behavior and mixed ownership. It does not resolve, correct, redesign, or extend those observations.

`docs/game_flow.md` is treated here as legacy/historical comparison evidence, not as authority for current behavior or as the structure to reproduce.

## Evidence inspected

- [AT-002 active-gameplay interaction map](AT-002-active-gameplay-interaction-map.md)
- Accepted `ADR-006`, plus `ADR-001`
- Accepted `CON-006` and `CON-007`
- Current ship-activation commands/state, `ShipActivationController`, `ModalRouter`, `GameBoard` restoration, and focused unit/integration tests
- `docs/game_flow.md` as legacy comparison only

## Ship Activation hierarchy

```text
Ship Phase
├─ Select next eligible ship
│  ├─ Active player chooses a ship/dial
│  └─ Activate normally or convert dial to token
├─ Establish active ship activation
│  └─ Show/reopen activation sequence
├─ Resolve activation opportunities
│  ├─ Squadron command
│  │  └─ Select and resolve commanded squadrons, or close opportunity
│  ├─ Repair
│  ├─ Attack
│  │  ├─ Target preview / confirm
│  │  ├─ Shared Attack Flow
│  │  └─ Skip when no active attack
│  └─ Maneuver
│     ├─ Local maneuver preview / commit
│     └─ If squadron overlap: opponent displacement interaction
└─ Complete activation
   ├─ Deliberate End Activation
   └─ Next player selects a ship, or phase advances
```

## Three-layer mapping and UI recoverability

| Major interaction | Canonical gameplay state | Interaction / decision state | Presentation / UI state | Recovery |
| --- | --- | --- | --- | --- |
| Ship selection | `GameState.current_phase`; unactivated `ShipInstance`s; phase/turn eligibility | `SHIP_ACTIVATION / WAIT_FOR_SHIP_SELECT` | Board selection affordance, active-player handoff/banner | **R2** — `GameManager.active_player` and handoff presentation are runtime-derived, not the same as canonical phase state. |
| Activation entry | Selected `ShipInstance` gets a stable activation identity; both opportunity dispositions begin unreached | `ACTIVATION_MODAL_OPEN` with ship identity/payload | Activation modal, sidebar highlight, local `ActivationContext` / `ShipActivationState` | **R2** — owner-local state can identify an active ship, but scene context and token binding are needed to render the activation surface. |
| Squadron command | Active ship’s Squadron-command disposition and committed count; active commanded squadron, when selected | `SQUADRON_STEP` | Command-mode squadron modal, range overlay, resolver-derived remaining capacity | **R2** — reconstruction also needs scene tokens plus derived range/capacity; modal opening is additionally routed through selected command results. |
| Repair | No separate canonical repair-progress owner identified | `REPAIR_STEP` | Activation modal’s repair controls and local resource evaluation | **R3** — repair is primarily a projected step; `ModalRouter` opens the activation modal only for specific lifecycle commands, not from the step alone. |
| Attack declaration and active attack | Ship attack-step facts on `ShipInstance`; committed attack becomes canonical `CurrentAttackState` | `ATTACK_STEP`, then shared `ATTACK` flow | Transient target candidate, attack panel/modal, confirm/cancel state | **R1 after accepted Begin/Skip** — current attack and post-Skip Maneuver reconstruction are covered by focused tests. **R2 before Begin** — target preview/candidate is intentionally transient scene state. |
| Maneuver | Active ship’s Maneuver disposition is `OPEN`, then `CONSUMED` by `ExecuteManeuverCommand`; normalized result persists | `MANEUVER_STEP` | Activation modal, maneuver tool, local preview/warnings | **R2** — the executable opportunity is canonical, but the tool, geometry preview, token scene, and local maneuver state must be rebuilt. |
| Squadron displacement | Committed maneuver position plus displacement flow payload | `SQUADRON_DISPLACEMENT / DISPLACEMENT_PLACE` | Displacement modal and draggable squadron placements | **R3** — `ModalRouter` opens this surface specifically from `start_displacement` and resolves scene tokens/bases; the serialized flow alone is not its sole entry path. |
| End activation / handoff | Both ship opportunity dispositions consumed; activation identity cleared; ship marked activated | `ACTIVATION_DONE`, then `WAIT_FOR_SHIP_SELECT` | End button/modal closure, next-player banner or waiting UI | **R2** — canonical completion is clear, while next-player presentation depends on runtime turn orchestration and event-driven handoff. |

R1 means presentation derives from canonical/accepted interaction state. R2 means the core opportunity is recoverable, but a scene/controller reconstruction is also required. R3 means the visible surface materially depends on the command/callback path that reached the state. No R4 classification was required by the inspected evidence.

## Material legacy differences (`docs/game_flow.md`)

- **Canonical activation ownership is newer than the legacy map.** Current code follows ADR-006: the active `ShipInstance` owns an activation identity, Squadron-command disposition/count, Maneuver disposition, and ship attack-step progress. `game_flow.md` mainly models `InteractionFlow` steps and does not represent this owner-local boundary.
- **Presentation steps are not a complete canonical activation FSM.** The legacy step chain appears to describe progression uniformly. Current code deliberately stores only rule-significant opportunity facts; Repair, presentation step, modal route, and controller mode remain derived or mixed.
- **Current reconstruction is more explicit for attack/Maneuver than the legacy document indicates.** `GameBoard` rebuilds declaration-adjacent projection from canonical ship and attack state without consulting `InteractionFlow` as gameplay input; focused tests cover post-Skip Maneuver reconstruction.
- **Squadron-command modal behavior is more conditional than the legacy flow table.** Current opening depends on active ship state, resolver-derived capacity/range, current squadron state, and particular command-result routing—not simply the presence of `SQUADRON_STEP`.
- **Maneuver completion has an important current split.** `ExecuteManeuverCommand` canonically consumes the Maneuver opportunity, while the controller’s speed-zero shortcut still performs scene-local handling before advancing presentation. ADR-006 already records scene-only speed-zero completion as a migration risk.

## Owner-level findings/questions

1. What recovery guarantee should future UI specification require for **Repair and initial Activation**? Current canonical state does not encode a general current step; their restoration depends substantially on serialized flow plus controller context.
2. Should a future UI model treat **Squadron command and displacement** as recoverable state surfaces or as path-triggered experiences? Both currently require more than a projected step to open their complete UI.
3. How should the specification distinguish the **canonical active ship owner** from `GameManager.active_player`, flow controller, and handoff presentation? They cooperate today but are not one state concept.
4. What level of restoration is expected for **maneuver preview**? The opportunity is canonical, while the tool geometry, warning text, and preview transform are transient.
5. Is the current **speed-zero maneuver shortcut** intended as a supported player-facing route? It is materially different from the normal command-backed Maneuver path and is already identified by accepted authority as a migration risk.
