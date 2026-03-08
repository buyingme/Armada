# squadrons/

Squadron card data (JSON), card art (PNG), squadron token art (PNG), and
shared base/UI art for squadron display elements.

## Naming Convention

| Asset type | Pattern | Example |
|-----------|---------|---------|
| Card data | `<name>_squadron.json` | `x_wing_squadron.json` |
| Card art | `<name>_squadron_card.png` | `x_wing_squadron_card.png` |
| Squadron token | `<name>_squadron_token.png` | `x_wing_squadron_token.png` |
| Shared base art | `squad_<descriptor>.png` | `squad_base.png` |

## Files

| File | Type |
|------|------|
| `x_wing_squadron.json` | Data (Rebel) |
| `x_wing_squadron_card.png` | Card art (Rebel) |
| `x_wing_squadron_token.png` | Token (Rebel) |
| `tie_fighter_squadron.json` | Data (Imperial) |
| `tie_fighter_squadron_card.png` | Card art (Imperial) |
| `tie_fighter_squadron_token.png` | Token (Imperial) |
| `squad_base.png` | Shared base art |
| `squad_base_buttons.png` | Shared base buttons |
| `squad_outline.png` | Shared outline art |
| `squad_tab_blue.png` | Rebel faction tab |
| `squad_tab_orange.png` | Imperial faction tab |

## JSON Schema

All `.json` files must validate against `../card_data_schema.json`.

## GDScript Path

```gdscript
const SQUADS_PATH := "res://Resources/Game_Components/squadrons/"
```
