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
├── Resources/                 # Reference materials + game component assets
│   ├── Game_Components/       # All game assets (flat snake_case folders)
│   ├── SWM-RULES-REFERENCE-GUIDE-150/  # Rules Reference book
│   └── SWM01-ARMADA-LEARN-TO-PLAY/     # Learn to Play book
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
6. ✅ **Generate the `.uid` file** — Godot 4.5+ requires a `.uid` sidecar for every script that declares `class_name`. Run `godot --headless --import` after creating the file, then commit the resulting `.gd.uid` alongside the `.gd`. Without it, other scripts that reference the `class_name` will fail with *"Could not find type … in the current scope"*.

## Resource Assets (`Resources/Game_Components/`)

Game component assets live in a **flat, snake_case** folder structure.
Each folder co-locates data, card art, and token art for one game concept.

### Folder Layout

```
Game_Components/
├── ships/            → JSON + card PNGs + ship token PNGs
├── squadrons/        → JSON + card PNGs + token PNGs + shared base art
├── dice/             → Die face PNGs (4 per colour × 3 colours = 12)
├── defense_tokens/   → Ready + exhausted PNGs (5 types × 2 states = 10)
├── command_tokens/   → One PNG per command type (4)
├── maps/             → Play area background JPGs
├── tools/            → Range ruler PNGs (range side + distance side)
├── scale/            → scale_config.json (pixel calibration data)
└── card_data_schema.json
```

### Naming Convention

All file and folder names use **lower_snake_case**:

- ✅ `cr90_corvette_a_card.png`
- ✅ `token_brace_ready.png`
- ❌ `CR90-Corvette-A-Card.png`
- ❌ `token brace ready.png`

#### Per-Folder Patterns

| Folder | Pattern | Example |
|--------|---------|---------|
| `ships/` | `<ship_name>.json`, `<ship_name>_card.png`, `<ship_name>_token.png` | `cr90_corvette_a.json` |
| `squadrons/` | `<name>_squadron.json`, `<name>_squadron_card.png`, `<name>_squadron_token.png` | `x_wing_squadron.json` |
| `dice/` | `die_<colour>_<face>.png` | `die_red_crit.png` |
| `defense_tokens/` | `token_<type>_<state>.png` | `token_evade_ready.png` |
| `command_tokens/` | `cmd_<type>.png`, `cmd_dial_hidden.png` | `cmd_navigate.png` |
| `maps/` | `map_<grid>_<name>_v<ver>.jpg` | `map_3x3_azure_v3.jpg` |
| `tools/` | `range_ruler_<side>.png` | `range_ruler_range.png` |

### Adding New Assets

1. ✅ Use `lower_snake_case` — no spaces, no hyphens, no PascalCase
2. ✅ Place in the correct sub-folder (co-locate with related files)
3. ✅ Update the sub-folder's `README.md` file table
4. ✅ If adding a new ship/squadron, provide JSON + card PNG + token PNG together
5. ✅ JSON files must validate against `card_data_schema.json`
