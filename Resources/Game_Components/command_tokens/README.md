# command_tokens/

Command dial token PNGs — one per command type.

## Naming Convention

`cmd_<type>.png`

## Files

| File | Command |
|------|---------|
| `cmd_concentrate_fire.png` | Concentrate Fire |
| `cmd_navigate.png` | Navigate |
| `cmd_repair.png` | Repair |
| `cmd_squadron.png` | Squadron |

## Rules Reference

"Commands", Rules Reference p.3 — each ship reveals its top command dial token
at the start of the Ship Phase to gain a command benefit.

## GDScript Path

```gdscript
const CMD_TOK_PATH := "res://Resources/Game_Components/command_tokens/"
```
