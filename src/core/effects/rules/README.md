# Rule Files

`RuleRegistry` rule files declare static hook definitions for game rules. Active rule state must come from authoritative game state (`GameState`, ship/squadron instances, faceup damage cards, upgrades, objectives) or from a documented transient `EffectRegistry` bridge rebuilt from that state.

Current Phase M files are still flat while the first rules are migrated:

| Rule | Source | Hooks | Notes |
|---|---|---|---|
| `faulty_countermeasures.gd` | Damage card | `VALIDATOR` on `ATTACK / ATTACK_DEFENSE_TOKENS` for `commit_defense` and `spend_defense_token` | UI receives `blocked_defense_token_indices` from the legacy `DEFENSE_VALIDATE_TOKEN` bridge until the defense-token resolver no longer needs it. |

## Proposed Grouping

Adopt this grouping when the next rule move makes a flat folder hard to scan:

```text
src/core/effects/rules/
  README.md
  core/
    attack/
    commands/
    movement/
    status/
  damage_cards/
    ship/
    crew/
  squadron_keywords/
  ship_keywords/
  upgrades/
    commander/
    officer/
    weapons_team/
    defensive_retrofit/
    ion_cannons/
    ordnance/
    turbolasers/
    support_team/
    title/
    other/
  objectives/
    assault/
    defense/
    navigation/
  obstacles/
  tokens/
```

Prefer source-first grouping because users usually know the card, keyword, objective, obstacle, or token they are looking for before they know its internal hook surface. Keep all hooks for one rule in one file, even when the rule attaches to multiple flows.
