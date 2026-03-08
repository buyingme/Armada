# Game Components — README

All game assets organised in a **flat, snake_case** folder structure.
Each sub-folder co-locates data (JSON), card art (PNG), and token art (PNG)
for the same game concept so nothing drifts apart.

## Folder Structure

```
Game_Components/
├── ships/            → Ship card data (JSON), card art, ship tokens
├── squadrons/        → Squadron card data (JSON), card art, tokens, shared base art
├── dice/             → Attack dice face PNGs (4 per colour × 3 colours)
├── defense_tokens/   → Defense token PNGs (ready + exhausted per type)
├── command_tokens/   → Command dial token PNGs (one per command type)
├── maps/             → Play area background JPGs
├── tools/            → Range ruler PNGs (range side + distance side)
├── scale/            → Scale calibration JSON (pixel measurements)
└── card_data_schema.json  → JSON schema all ship/squadron data validates against
```

## Naming Convention

All file and folder names use **lower_snake_case** — no spaces, no hyphens,
no PascalCase. See `.skills/file_organization.md` § Resource Assets for the
full naming rules.

## What Goes Where

| Category | Folder | Status | Notes |
|----------|--------|--------|-------|
| Ship data + card art + tokens | `ships/` | 6 JSON, 6 card PNGs, 3 token PNGs | 2 ship tokens still needed |
| Squadron data + card art + tokens | `squadrons/` | 2 JSON, 2 card/token PNGs, 5 base PNGs | Complete for MVP |
| Dice faces | `dice/` | **MISSING** — 12 PNGs needed | Can be procedural |
| Defense tokens | `defense_tokens/` | 10 PNGs (5 types × ready/exhausted) | Complete |
| Command tokens | `command_tokens/` | 4 PNGs | Complete |
| Play area backgrounds | `maps/` | 4 JPGs | Complete |
| Range ruler | `tools/` | **MISSING** — 2 PNGs needed | Also used for scale calibration |
| Scale config | `scale/` | 1 JSON | Pixel measurements from ruler |

See `docs/implementation_plan.md` for full asset specifications.
