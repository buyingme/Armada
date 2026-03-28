# 5. Building Block View

## 5.1 Level 1 — System Overview

```
┌─────────────────────────────────────────────────┐
│            Star Wars: Armada Digital             │
│                                                  │
│  ┌────────────┐  ┌──────────┐  ┌─────────────┐  │
│  │   UI /     │  │  Game    │  │   Data      │  │
│  │   Scenes   │──│  Core    │──│   Layer     │  │
│  │            │  │          │  │             │  │
│  └────────────┘  └──────────┘  └─────────────┘  │
│         │              │              │           │
│  ┌────────────┐  ┌──────────┐  ┌─────────────┐  │
│  │  Assets    │  │ Autoload │  │   Tests     │  │
│  │            │  │ Services │  │             │  │
│  └────────────┘  └──────────┘  └─────────────┘  │
└─────────────────────────────────────────────────┘
```

### Component Descriptions

| Block | Description | Location |
|-------|-------------|----------|
| **UI / Scenes** | Visual scenes, HUD elements, menus, game board rendering | `src/scenes/`, `src/ui/` |
| **Game Core** | Rules engine, game state, phase management, combat resolution | `src/core/` |
| **Data Layer** | Data models as Godot Resources (ships, squadrons, upgrades) | `src/models/` |
| **Autoload Services** | Singletons (GameManager, EventBus, Constants, TooltipManager) | `src/autoload/` |
| **Assets** | Textures, audio, fonts, shaders | `assets/` |
| **Tests** | Unit and integration tests | `tests/` |

## 5.2 Level 2 — Game Core Detail

### Implemented Core Components

| Component | Extends | File | Purpose |
|-----------|---------|------|---------|
| `GameState` | RefCounted | `src/core/game_state.gd` | Round, phase, fleet and ship tracking |
| `PhaseState` | RefCounted | `src/core/phase_state.gd` | Phase/sub-phase transitions, initiative |
| `DicePool` | RefCounted | `src/core/dice.gd` | Dice rolling and modification |
| `FleetBuilder` | RefCounted | `src/core/fleet_builder.gd` | Fleet construction and validation |
| `ManeuverCalculator` | RefCounted | `src/core/maneuver_calculator.gd` | Chain-computation of tool joints and final transform |
| `ManeuverTool` | RefCounted | `src/core/maneuver_tool.gd` | Maneuver state: joint angles, speed, yaw validation |
| `ManeuverToolState` | RefCounted | `src/core/maneuver_tool_state.gd` | Activation-mode state: Navigate budget, yaw bonus, commit |
| `ShipActivationState` | RefCounted | `src/core/ship_activation_state.gd` | Activation step tracking, command spending |
| `CommandTokenManager` | RefCounted | `src/core/command_token_manager.gd` | Token pool management, add/remove/spend |
| `TooltipLayout` | RefCounted | `src/core/tooltip_layout.gd` | Pure tooltip position computation |

### Planned (Not Yet Implemented)

- **RulesEngine** — Validates actions against game rules
- **CommandProcessor** — Command dial/token processing (beyond Navigate)

## 5.3 Level 2 — UI Detail

### Implemented UI/Scene Components

| Component | Extends | File | Purpose |
|-----------|---------|------|---------|
| `GameBoard` | Node2D | `src/scenes/game_board/game_board.gd` | Main play area, ship/token rendering, camera, delegates attack to AttackExecutor |
| `AttackExecutor` | Node | `src/scenes/game_board/attack_executor.gd` | Attack simulator (free-form) and attack execution (activation Step 4): targeting, LOS, dice, defense tokens, damage |
| `ShipToken` | Node2D | `src/scenes/ship_token.gd` | Ship base rendering, command dial icon, labels |
| `ShipCardPanel` | Control | `src/scenes/ship_card_panel.gd` | Ship card display, defense tokens, command tokens |
| `CommandDialPicker` | Control | `src/ui/command_dial_picker.gd` | Centred modal for choosing command dials |
| `ActivationModal` | Control | `src/scenes/activation_modal.gd` | Centred panel for activation steps (5 sub-steps, two-phase button) |
| `ManeuverToolScene` | Node2D | `src/scenes/tools/maneuver_tool_scene.gd` | Visual maneuver tool: segments, joints, speed buttons, ghost |
| `ActionToolbar` | HBoxContainer | `src/ui/action_toolbar.gd` | Lower-right toolbar: tooltip toggle, maneuver display button |
| `PhaseIndicator` | Control | `src/ui/phase_indicator.gd` | Current phase and round display |
| `TooltipPanel` | PanelContainer | `src/ui/tooltip_panel.gd` | Hover/programmatic tooltip popup |
| `HUDLayer` | CanvasLayer | `src/scenes/hud_layer.gd` | HUD container for panels, indicators |

### Planned (Not Yet Implemented)

- **FleetBuilder** — Pre-game fleet construction interface
