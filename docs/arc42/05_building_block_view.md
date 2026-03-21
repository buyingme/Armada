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

> **TODO:** To be detailed during architecture phase.

### Planned Core Components

- **GameState** — Immutable snapshot of the full game state
- **RulesEngine** — Validates actions against game rules
- **PhaseController** — Manages phase transitions
- **CombatResolver** — Handles attack resolution, dice rolling, defense tokens
- **MovementResolver** — Ship movement with maneuver tool simulation
- **CommandProcessor** — Command dial/token processing
- **TooltipLayout** — Pure tooltip position computation (viewport clamping, cursor offset)

## 5.3 Level 2 — UI Detail

> **TODO:** To be detailed during architecture phase.

### Planned UI Components

- **GameBoard** — Main play area with ship/squadron rendering
- **ShipHUD** — Ship status, shields, hull, tokens display
- **DicePanel** — Dice rolling visualization
- **PhaseIndicator** — Current phase and round display
- **FleetBuilder** — Pre-game fleet construction interface
- **TooltipPanel** — Reusable hover/programmatic tooltip popup (BBCode, styled)
