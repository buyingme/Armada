# Rule Files

`RuleRegistry` rule files declare static hook definitions for game rules. Active rule state must come from authoritative game state (`GameState`, ship/squadron instances, faceup damage cards, upgrades, objectives) or from a documented transient `EffectRegistry` bridge rebuilt from that state.

Phase M rule files now use source-first grouping so contributors can find a
rule by the component printed on the table before they know its hook surface.

## Shared Surface Names

Use `RuleSurface` for common RuleRegistry target strings and callback runners.
Phase N added no-op-safe surfaces for attack-target blocking, attack-damage
modification, accuracy and critical blocking, engineering and token-gain rules,
maneuver yaw modification, and post-maneuver observer follow-ups. Rule files
still register static hooks through `RuleRegistry`; `RuleSurface` only names and
executes surfaces that callers explicitly choose.

| Rule | Source | Hooks | Notes |
|---|---|---|---|
| `damage_cards/ship/capacitor_failure.gd` | Ship damage card | `VALIDATOR` and `BLOCKER` on `ATTACK / ATTACK_DEFENSE_TOKENS` for Redirect spending; `VALIDATOR` and `BLOCKER` on `SHIP_ACTIVATION / REPAIR_STEP` for shield repair actions | No legacy `EffectRegistry` bridge remains; defense and repair helper UI eligibility reads blocker metadata while command validators protect replay/network submissions. |
| `damage_cards/ship/faulty_countermeasures.gd` | Ship damage card | `VALIDATOR` on `ATTACK / ATTACK_DEFENSE_TOKENS` for `commit_defense` and `spend_defense_token` | UI receives `blocked_defense_token_indices` from the legacy `DEFENSE_VALIDATE_TOKEN` bridge until the defense-token resolver no longer needs it. |
| `damage_cards/ship/compartment_fire.gd` | Ship damage card | `MODIFIER` on `STATUS_CLEANUP / STATUS_CLEANUP_STEP` for `defense_token_readying` | No legacy `EffectRegistry` bridge remains; status cleanup reads this rule from `RuleRegistry` and active state from `ShipInstance.faceup_damage`. |
| `damage_cards/ship/crew_panic.gd` | Ship damage card | `ENABLER` on `SHIP_ACTIVATION / WAIT_FOR_SHIP_SELECT` for `command_dial_reveal` | No legacy `EffectRegistry` bridge remains; `UIProjector.affordances` exposes pre-reveal choice metadata for ships with faceup Crew Panic and hidden dials. |
| `damage_cards/ship/damaged_munitions.gd` | Ship damage card | `MODIFIER` on `ATTACK / ATTACK_ROLL` for `dice_pool` | No legacy `EffectRegistry` bridge remains; the first pass exposes available die colours from the attacking ship's `faceup_damage`, and the selected colour is applied before rolling. |
| `damage_cards/ship/point_defense_failure.gd` | Ship damage card | `MODIFIER` on `ATTACK / ATTACK_ROLL` for `dice_pool` | No legacy `EffectRegistry` bridge remains; the first pass exposes available die colours when the defender is a squadron, and the selected colour is applied before rolling. |

## Grouping

Use this grouping for future rule files:

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
