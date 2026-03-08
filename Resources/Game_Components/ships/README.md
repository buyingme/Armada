# ships/

Ship card data (JSON), card art (PNG), and top-down ship token art (PNG).

## Naming Convention

| Asset type | Pattern | Example |
|-----------|---------|---------|
| Card data | `<name>.json` | `cr90_corvette_a.json` |
| Card art | `<name>_card.png` | `cr90_corvette_a_card.png` |
| Ship token | `<name>_token.png` | `cr90_corvette_a_token.png` |

Name = full ship name in `lower_snake_case`, no faction prefix.

## Files

| File | Type | Faction |
|------|------|---------|
| `cr90_corvette_a.json` | Data | Rebel |
| `cr90_corvette_a_card.png` | Card art | Rebel |
| `cr90_corvette_a_token.png` | Ship token | Rebel |
| `cr90_corvette_b.json` | Data | Rebel |
| `cr90_corvette_b_card.png` | Card art | Rebel |
| `nebulon_b_escort_frigate.json` | Data | Rebel |
| `nebulon_b_escort_frigate_card.png` | Card art | Rebel |
| `nebulon_b_escort_frigate_token.png` | Ship token | Rebel |
| `nebulon_b_support_refit.json` | Data | Rebel |
| `nebulon_b_support_refit_card.png` | Card art | Rebel |
| `victory_i_class_star_destroyer.json` | Data | Imperial |
| `victory_i_class_star_destroyer_card.png` | Card art | Imperial |
| `victory_ii_class_star_destroyer.json` | Data | Imperial |
| `victory_ii_class_star_destroyer_card.png` | Card art | Imperial |
| `victory_ii_class_star_destroyer_token.png` | Ship token | Imperial |

> Note: `cr90_corvette_b` and `victory_i_class_star_destroyer` are missing their
> ship token PNGs — provide when available using the `<name>_token.png` pattern.

## JSON Schema

All `.json` files must validate against `../card_data_schema.json`.

## GDScript Path

```gdscript
const SHIPS_PATH := "res://Resources/Game_Components/ships/"
```
