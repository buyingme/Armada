# Resources/Game_Components/

Flat, `snake_case` asset library for Star Wars: Armada Digital Edition.
All files are co-located by component type — no faction sub-folders.

---

## Directory Structure

```
Game_Components/
├── card_data_schema.json   ← JSON schema for all card data files
├── ships/                  ← Ship card data (JSON) + card art + ship tokens
├── squadrons/              ← Squadron card data (JSON) + card art + tokens + base art
├── defense_tokens/         ← Defense token PNGs (ready + exhausted states)
├── command_tokens/         ← Command dial token PNGs
├── dice/                   ← Dice face PNGs  ⚠ MISSING — see dice/README.md
├── maps/                   ← Play-area background JPGs  ⚠ MISSING — see maps/README.md
├── tools/                  ← Range ruler PNGs  ⚠ MISSING — see tools/README.md
└── scale/                  ← Pixel calibration data (scale_config.json)
```

---

## Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Ship card data | `<name>.json` | `cr90_corvette_a.json` |
| Ship card art | `<name>_card.png` | `cr90_corvette_a_card.png` |
| Ship token | `<name>_token.png` | `cr90_corvette_a_token.png` |
| Squadron card data | `<name>_squadron.json` | `x_wing_squadron.json` |
| Squadron card art | `<name>_squadron_card.png` | `x_wing_squadron_card.png` |
| Squadron token | `<name>_squadron_token.png` | `x_wing_squadron_token.png` |
| Defense token | `token_<type>_<state>.png` | `token_evade_ready.png` |
| Command token | `cmd_<type>.png` | `cmd_navigate.png` |
| Die face | `die_<colour>_<face>.png` | `die_red_crit.png` |
| Map background | `map_<grid>_<name>_vN.jpg` | `map_3x3_azure_v3.jpg` |
| Range ruler | `range_ruler_<type>.png` | `range_ruler_range.png` |

All names: **lower_snake_case**, no spaces, no PascalCase, no faction prefixes.

---

## Asset Status

| Folder | Assets | Status |
|--------|--------|--------|
| `ships/` | 6 JSONs, 6 card PNGs, 3 token PNGs | ✅ Complete |
| `squadrons/` | 2 JSONs, 2 card PNGs, 2 token PNGs, 5 base art | ✅ Complete |
| `defense_tokens/` | 10 PNGs (5 types × ready/exhausted) | ✅ Complete |
| `command_tokens/` | 4 PNGs | ✅ Complete |
| `scale/` | scale_config.json | ✅ Complete |
| `dice/` | 12 die face PNGs | ⚠ Missing — re-provide PNGs |
| `maps/` | 4 background JPGs | ⚠ Missing — re-provide JPGs |
| `tools/` | 2 range ruler PNGs | ⚠ Missing — re-provide PNGs |

---

## GDScript Paths

```gdscript
const GC            := "res://Resources/Game_Components/"
const SHIPS_PATH    := GC + "ships/"
const SQUADS_PATH   := GC + "squadrons/"
const DEF_TOK_PATH  := GC + "defense_tokens/"
const CMD_TOK_PATH  := GC + "command_tokens/"
const DICE_PATH     := GC + "dice/"
const MAPS_PATH     := GC + "maps/"
const TOOLS_PATH    := GC + "tools/"
const SCALE_PATH    := GC + "scale/scale_config.json"
const SCHEMA_PATH   := GC + "card_data_schema.json"
```

---

## Adding New Assets

1. Place the file in the correct sub-folder using the naming convention above.
2. If it is a JSON card data file, verify it validates against `card_data_schema.json`.
3. Godot generates `.import` metadata automatically on first import — commit that too.
4. Update the sub-folder `README.md` file list if appropriate.
