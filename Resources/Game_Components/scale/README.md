# scale/

Pixel-measurement calibration data used to convert the on-screen range ruler
image into game distances.

## Files

| File | Purpose |
|------|---------|
| `scale_config.json` | Ruler pixel measurements (manually measured by project owner) |

## scale_config.json Values

- `ruler_total_length_px`: 720
- Range bands: close ≤ 292 px, medium ≤ 442 px, long ≤ 720 px
- Distance bands (px): 181 / 294 / 434 / 577 / 720

All values were hand-measured from `tools/range_ruler_range.png` at the project
working resolution. Update this file if the ruler image is replaced or rescaled.

## Usage in GDScript

```gdscript
const SCALE_CONFIG_PATH: String = "res://Resources/Game_Components/scale/scale_config.json"
```
