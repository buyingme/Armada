# File Organization — Armada Project

## Project Root

```
Armada/
├── project.godot              # Godot project configuration
├── icon.svg                   # Project icon
├── export_presets.cfg         # Export configurations
├── .gitignore                 # Git ignore rules
├── .gut_editor_config.tres    # GUT test runner configuration
├── README.md                  # Project overview
│
├── src/                       # All game source code
│   ├── autoload/              # Singleton services
│   ├── core/                  # Pure game logic (no scene tree dependency)
│   ├── models/                # Data resources (ShipData, etc.)
│   ├── scenes/                # Game scenes (.tscn) with their scripts
│   ├── ui/                    # Reusable UI components
│   └── utils/                 # Utility classes
│
├── tests/                     # All test code
│   ├── unit/                  # Unit tests (mirror src/ structure)
│   ├── integration/           # Integration and scenario tests
│   └── fixtures/              # Test factories and data
│
├── addons/                    # Third-party addons
│   └── gut/                   # GUT testing framework
│
├── assets/                    # Game assets
│   ├── textures/              # Images, sprites
│   ├── audio/                 # Sound effects, music
│   ├── fonts/                 # Custom fonts
│   └── shaders/               # Shader files
│
├── Resources/                 # Reference materials (rules books)
│
├── docs/                      # Documentation
│   └── arc42/                 # arc42 architecture documentation
│
├── .github/                   # GitHub configuration
│   ├── workflows/             # CI/CD pipelines
│   ├── ISSUE_TEMPLATE/        # Issue templates
│   ├── CONTRIBUTING.md        # Contribution guidelines
│   └── PULL_REQUEST_TEMPLATE.md
│
└── .skills/                   # AI/developer skill documents
```

## File Placement Rules

### Source Code (`src/`)

| Directory | What Goes Here | Base Class |
|-----------|---------------|------------|
| `src/autoload/` | Global singletons | `Node` |
| `src/core/` | Game rules, state, logic | `RefCounted` |
| `src/models/` | Data definitions | `Resource` |
| `src/scenes/` | Visual scenes + controllers | `Node` / `Control` |
| `src/ui/` | Reusable UI widgets | `Control` |
| `src/utils/` | Helpers, utilities | `RefCounted` |

### Scenes (`src/scenes/`)

Each scene folder contains its `.tscn` file and its `.gd` script:

```
src/scenes/
├── main_menu/
│   ├── main_menu.tscn
│   └── main_menu.gd
├── game_board/
│   ├── game_board.tscn
│   └── game_board.gd
└── fleet_builder/
    ├── fleet_builder.tscn
    └── fleet_builder.gd
```

### Tests (`tests/`)

Test files mirror the source structure:

```
src/core/dice.gd           → tests/unit/test_dice.gd
src/core/game_state.gd     → tests/unit/test_game_state.gd
src/autoload/constants.gd  → tests/unit/test_constants.gd
```

### New File Checklist

When creating a new source file:

1. ✅ Place in the correct `src/` subdirectory
2. ✅ Add class-level doc comment
3. ✅ Create corresponding test file in `tests/unit/`
4. ✅ Register in autoload if it's a singleton
5. ✅ Update arc42 building block view if it's a new component
