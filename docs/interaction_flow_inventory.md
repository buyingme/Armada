# Phase I0 — Interaction-Flow Inventory & Freeze

> Snapshot taken: 2026-04-25, before Phase I begins.
> Purpose: catalogue every site that participates in the parallel
> `NetworkInteractionState` channel today, so Phase I migrations are
> exhaustive and the lint in `scripts/lint_phase_i.sh` has a known baseline.
>
> **Freeze rule:** while Phase I is in flight, no new entries may be added
> to the **Producers** or **Consumers** tables below. The lint script
> enforces a numeric ceiling on each pattern.

---

## 1. Domain Type

| File | Purpose |
|------|---------|
| `src/core/network/network_interaction_state.gd` | The class to be deleted in I6. Replaced by `src/core/state/interaction_flow.gd` (Phase I1). |

## 2. Producers (server-side only)

All producers live in `src/autoload/game_manager.gd`. Every producer call
must be replaced by a `GameCommand.execute()` mutation of
`GameState.interaction_flow` during Phase I2.

| Site (file:line) | Function | Triggering command | Step IDs published |
|------------------|----------|--------------------|--------------------|
| `game_manager.gd:1472` | `_publish_interaction_state_for_command` → `advance_phase` | `AdvancePhaseCommand` | `wait_for_ship_select`, `wait_for_squad_select` |
| `game_manager.gd:1484` | `_publish_interaction_state_for_command` → `activate_ship`, `convert_dial_to_token` | `ActivateShipCommand`, `ConvertDialToTokenCommand` | `activation_modal_open` |
| `game_manager.gd:1491` | `_publish_interaction_state_for_command` → `execute_maneuver` | `ExecuteManeuverCommand` | `maneuver_step` |
| `game_manager.gd:1499` | `_publish_interaction_state_for_command` → `end_activation` (ship) | `EndActivationCommand` | `wait_for_ship_select` |
| `game_manager.gd:1506` | `_publish_interaction_state_for_command` → `end_activation` (squadron) | `EndActivationCommand` | `wait_for_squad_select` |
| `game_manager.gd:1512` | `_publish_interaction_state_for_command` → `activate_squadron` | `ActivateSquadronCommand` | `action_choice` |
| `game_manager.gd:1519` | `_publish_interaction_state_for_command` → `advance_activation_step` | `AdvanceActivationStepCommand` | dynamic from payload |
| `game_manager.gd:1530` | `_broadcast_interaction_step()` (helper, called by all sites above) | — | — |
| `network_manager.gd:684` | `broadcast_interaction_state(state)` (transport hop) | — | — |

**Producer count today: 7 distinct call sites + 2 helpers.**
**Phase I2 target: 0 (all replaced by `state.interaction_flow = …` inside `GameCommand.execute()`).**

## 3. Consumers (any client/host)

| Site (file:line) | Subscriber | Purpose | Migration target |
|------------------|------------|---------|------------------|
| `game_manager.gd:114` | `NetworkManager.interaction_state_received` → `_on_interaction_state_received` | C3/C4 ordered apply, emits `EventBus.interaction_state_changed` | Delete in I6 |
| `game_manager.gd:1591` | Emits `EventBus.interaction_state_changed` | Fan-out to UI | Delete in I6 |
| `game_board.gd:368` | `EventBus.interaction_state_changed.connect(_on_interaction_state_changed)` | Modal open/close + step sync | Migrate to `UIProjector` (I4–I6) |
| `activation_sidebar.gd:208` | `EventBus.interaction_state_changed.connect(_on_interaction_state_changed)` | Sidebar refresh | Migrate to `UIProjector` (I5) |

**Consumer count today: 4 subscription points.**
**Phase I6 target: 0 (signal removed; consumers read `UIProjector.project()`).**

## 4. Transport (network_manager.gd)

| Symbol | Line | Migration target |
|--------|-----:|------------------|
| `signal interaction_state_received(state_data)` | 104 | Delete in I6 |
| `var _latest_interaction_state: Dictionary` | 163 | Delete in I6 |
| `func broadcast_interaction_state(state)` | 684 | Delete in I6 |
| `@rpc _receive_interaction_state(state_data)` | (RPC) | Delete in I6 |
| `func get_latest_interaction_state()` | 698 | Delete in I6 |

## 5. EventBus

| Symbol | Line | Migration target |
|--------|-----:|------------------|
| `signal interaction_state_changed(state: NetworkInteractionState)` | 127 | Delete in I6 |

## 6. game_board.gd `is_network()` Branches (in scope of Phase I)

Audited: `src/scenes/game_board/game_board.gd` contains 18
`PlayMode.is_network()` / `NetworkManager.is_server()` branches today
(measured by grep at commit `c1004a4`). Phase I6 ceiling: ≤ 3 (camera /
perspective lock only).

## 7. Tests Touching the Parallel Channel

| Test file | What it covers | Migration target |
|-----------|----------------|------------------|
| `tests/unit/test_network_interaction_state.gd` | `NetworkInteractionState` serialize / version helpers | Replace with `test_interaction_flow.gd` in I1; delete original in I6 |
| `tests/unit/test_game_manager_interaction_state.gd` | C3/C4 ordered apply path | Keep through I5; delete in I6 |
| `tests/unit/test_activation_sidebar.gd` | Sidebar consumer | Update to use `UIProjector` in I5 |
| `tests/unit/test_activation_modal.gd`, `test_squadron_activation_modal.gd` | Modal interactivity | Update to use `UIProjector` in I5 |

---

## 8. Freeze Lint

`scripts/lint_phase_i.sh` enforces ceilings on the patterns above. Run
locally with `bash scripts/lint_phase_i.sh` before every commit during
Phase I. The CI job invokes the same script.

The ceilings shrink at each phase boundary:

| Pattern | Today (I0) | After I2 | After I5 | After I6 |
|---------|-----------:|---------:|---------:|---------:|
| `_broadcast_interaction_step` calls in `src/` | 7 | 7 | 7 | 0 |
| `broadcast_interaction_state` calls in `src/` | 1 | 1 | 1 | 0 |
| `interaction_state_changed` references in `src/` | ≥ 4 | ≥ 4 | 1 | 0 |
| `NetworkInteractionState` references in `src/` | ≥ 6 | ≥ 6 | ≥ 3 | 0 |
| `PlayMode.is_network()` in `src/scenes/` and `src/ui/` | 18 | 18 | 8 | ≤ 3 |

The lint **never increases** these counts. Any commit that does is rejected.

---

*This file is regenerated by I7's cleanup step and removed once Phase I lands.*
