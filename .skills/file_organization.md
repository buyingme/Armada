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

---

## Resource Assets (`Resources/Game_Components/`)

All game art and card data lives in a flat, `snake_case` layout — no faction sub-folders.

### Structure

```
Resources/Game_Components/
├── card_data_schema.json
├── ships/            ← <name>.json + <name>_card.png + <name>_token.png
├── squadrons/        ← <name>_squadron.{json,card.png,token.png} + squad_*.png
├── defense_tokens/   ← token_<type>_<state>.png  (state = ready | exhausted)
├── command_tokens/   ← cmd_<type>.png
├── dice/             ← die_<colour>_<face>.png
├── maps/             ← map_<grid>_<name>_vN.jpg
├── tools/            ← range_ruler_<type>.png
└── scale/            ← scale_config.json
```

### Naming Rules

| Pattern | Example | Used For |
|---------|---------|---------|
| `<ship_name>.json` | `cr90_corvette_a.json` | Ship card data |
| `<ship_name>_card.png` | `cr90_corvette_a_card.png` | Ship card art |
| `<ship_name>_token.png` | `cr90_corvette_a_token.png` | Ship top-down token |
| `<name>_squadron.json` | `x_wing_squadron.json` | Squadron card data |
| `<name>_squadron_card.png` | `x_wing_squadron_card.png` | Squadron card art |
| `<name>_squadron_token.png` | `x_wing_squadron_token.png` | Squadron token |
| `token_<type>_<state>.png` | `token_evade_ready.png` | Defense token |
| `cmd_<type>.png` | `cmd_navigate.png` | Command token |
| `die_<colour>_<face>.png` | `die_red_crit.png` | Die face |
| `map_<grid>_<name>_vN.jpg` | `map_3x3_azure_v3.jpg` | Map background |
| `range_ruler_<type>.png` | `range_ruler_range.png` | Measurement tool |

**Rules:**
- All lowercase `snake_case` — no spaces, no PascalCase, no faction prefixes
- No faction sub-folders (Rebel/Imperial distinction lives in the JSON data)
- Every folder has a `README.md` documenting its contents

### Adding a New Asset

1. Drop the file in the correct sub-folder using the naming convention
2. If JSON: validate it against `card_data_schema.json`
3. Commit the Godot-generated `.import` file alongside the asset
4. Update the sub-folder `README.md` file list
