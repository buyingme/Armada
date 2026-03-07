# Star Wars: Armada — Digital Edition

A digital adaptation of the *Star Wars: Armada* tabletop miniatures game, built with the Godot Engine 4.5+.

## Project Status

🟡 **Phase: Project Setup** — Development environment established, architecture foundations in place.

## Overview

This project aims to faithfully recreate *Star Wars: Armada* as a computer game. Players command fleets of capital ships and fighter squadrons in tactical space combat within the Star Wars universe.

### Current Phase: Setup

- [x] Godot 4.5 project structure
- [x] Core architecture (autoloads, event bus, game state)
- [x] GUT testing framework with initial tests
- [x] arc42 documentation structure
- [x] GitHub workflow (CI, templates, contributing guide)
- [x] Skill documents for consistent development

### Next Phases

1. **Requirements Extraction** — Analyze Rules Reference and Learn to Play documents
2. **Architecture Definition** — Detailed component design, interfaces, and ADRs
3. **Core Implementation** — Rules engine, combat, movement
4. **UI/Visuals** — Game board, ship rendering, HUD
5. **Polish** — Animations, sound, UX

## Project Structure

```
Armada/
├── src/                    # Game source code
│   ├── autoload/           # Singletons (GameManager, EventBus, Constants)
│   ├── core/               # Pure game logic (scene-tree independent)
│   ├── models/             # Data resources (ShipData, SquadronData, etc.)
│   ├── scenes/             # Visual scenes with controllers
│   ├── ui/                 # Reusable UI components
│   └── utils/              # Utilities (Logger, helpers)
├── tests/                  # GUT tests
│   ├── unit/               # Unit tests
│   ├── integration/        # Integration tests
│   └── fixtures/           # Test data factories
├── assets/                 # Textures, audio, fonts, shaders
├── addons/gut/             # GUT testing framework
├── docs/arc42/             # Architecture documentation (arc42)
├── Resources/              # Reference materials (rules books)
├── .github/                # CI/CD, issue templates, contributing guide
└── .skills/                # Coding standards and AI instructions
```

## Prerequisites

- **Godot Engine 4.5+** ([download](https://godotengine.org/download))
- **Git** for version control

## Getting Started

```bash
# Clone the repository
git clone <repository-url>
cd Armada

# Open in Godot
godot project.godot
```

## Running Tests

```bash
# All tests
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

# Unit tests only
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit

# Integration tests only
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit
```

Or use the GUT panel in the Godot editor.

## Documentation

- **Architecture:** [docs/arc42/](docs/arc42/README.md) — arc42 documentation
- **Contributing:** [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md) — workflow, commit conventions, PR process
- **Coding Standards:** [.skills/](.skills/README.md) — style guide, patterns, testing standards

## Technology Stack

| Component | Technology |
|-----------|-----------|
| Game Engine | Godot 4.5+ |
| Language | GDScript |
| Testing | GUT (Godot Unit Testing) v9.3.0 |
| Documentation | arc42 |
| CI/CD | GitHub Actions |

## License

This is a fan project for personal/educational use. *Star Wars* and *Armada* are trademarks of Lucasfilm Ltd. and Fantasy Flight Games respectively.
