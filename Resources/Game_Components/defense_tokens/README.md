# defense_tokens/

Defense token PNGs — both ready and exhausted states for all 5 token types.

## Naming Convention

`token_<type>_<state>.png`

- `<type>` — `brace`, `contain`, `evade`, `redirect`, `scatter`
- `<state>` — `ready` (green face-up) or `exhausted` (red face-down)

## Files

| File | Token | State |
|------|-------|-------|
| `token_brace_ready.png` | Brace | Ready |
| `token_brace_exhausted.png` | Brace | Exhausted |
| `token_contain_ready.png` | Contain | Ready |
| `token_contain_exhausted.png` | Contain | Exhausted |
| `token_evade_ready.png` | Evade | Ready |
| `token_evade_exhausted.png` | Evade | Exhausted |
| `token_redirect_ready.png` | Redirect | Ready |
| `token_redirect_exhausted.png` | Redirect | Exhausted |
| `token_scatter_ready.png` | Scatter | Ready |
| `token_scatter_exhausted.png` | Scatter | Exhausted |

## Rules Reference

"Defense Tokens", Rules Reference p.5 — tokens flip to exhausted when spent;
exhausted tokens may not be spent again until refreshed at end of round.

## GDScript Path

```gdscript
const DEF_TOK_PATH := "res://Resources/Game_Components/defense_tokens/"
```
