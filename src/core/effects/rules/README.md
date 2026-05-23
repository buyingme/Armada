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
| `damage_cards/ship/blinded_gunners.gd` | Crew damage card | `BLOCKER` on `ATTACK / ATTACK_MODIFY` for `accuracy_spend`; `VALIDATOR` on `ATTACK / ATTACK_DEFENSE_TOKENS` for `publish_attack_flow` locked-token payloads | No legacy `ATTACK_SPEND_ACCURACY` bridge remains; the attack payload reports zero spendable accuracies and direct locked-token submissions are rejected from attacker `faceup_damage`. |
| `damage_cards/ship/capacitor_failure.gd` | Ship damage card | `VALIDATOR` and `BLOCKER` on `ATTACK / ATTACK_DEFENSE_TOKENS` for Redirect spending; `VALIDATOR` and `BLOCKER` on `SHIP_ACTIVATION / REPAIR_STEP` for shield repair actions | No legacy `EffectRegistry` bridge remains; defense and repair helper UI eligibility reads blocker metadata while command validators protect replay/network submissions. |
| `damage_cards/ship/faulty_countermeasures.gd` | Ship damage card | `VALIDATOR` and `BLOCKER` on `ATTACK / ATTACK_DEFENSE_TOKENS` for exhausted defense-token spending | No legacy `EffectRegistry` bridge remains; defense-token UI eligibility and command safety both read active state from `ShipInstance.faceup_damage`. |
| `damage_cards/ship/compartment_fire.gd` | Ship damage card | `MODIFIER` on `STATUS_CLEANUP / STATUS_CLEANUP_STEP` for `defense_token_readying` | No legacy `EffectRegistry` bridge remains; status cleanup reads this rule from `RuleRegistry` and active state from `ShipInstance.faceup_damage`. |
| `damage_cards/ship/coolant_discharge.gd` | Ship damage card | `BLOCKER` for `attack_target` and `VALIDATOR` for `publish_attack_flow` on `ATTACK / ATTACK_DECLARE` | No legacy `ATTACK_VALIDATE_TARGET` or stale close-range damage bridge remains; `RollDiceCommand` records serialized per-round ship-target attack counts on `GameState` so hot-seat, replay, and network mirrors share the same source of truth. |
| `damage_cards/ship/crew_panic.gd` | Ship damage card | `ENABLER` on `SHIP_ACTIVATION / WAIT_FOR_SHIP_SELECT` for `command_dial_reveal` | No legacy `EffectRegistry` bridge remains; `UIProjector.affordances` exposes pre-reveal choice metadata for ships with faceup Crew Panic and hidden dials. |
| `damage_cards/ship/damaged_controls.gd` | Ship damage card | `OBSERVER` on `SHIP_ACTIVATION / MANEUVER_STEP` for `execute_maneuver` | No legacy `AFTER_MANEUVER_EXECUTE` bridge remains; observer follow-up reads authoritative `did_overlap` metadata from `ExecuteManeuverCommand` results and returns `PersistentEffectDamageCommand` with `draw_from_deck`. |
| `damage_cards/ship/damaged_munitions.gd` | Ship damage card | `MODIFIER` on `ATTACK / ATTACK_ROLL` for `dice_pool` | No legacy `EffectRegistry` bridge remains; the first pass exposes available die colours from the attacking ship's `faceup_damage`, and the selected colour is applied before rolling. |
| `damage_cards/ship/point_defense_failure.gd` | Ship damage card | `MODIFIER` on `ATTACK / ATTACK_ROLL` for `dice_pool` | No legacy `EffectRegistry` bridge remains; the first pass exposes available die colours when the defender is a squadron, and the selected colour is applied before rolling. |
| `damage_cards/ship/power_failure.gd` | Ship damage card | `MODIFIER` on `SHIP_ACTIVATION / REPAIR_STEP` for `engineering_value` | No legacy `EffectRegistry` bridge remains; repair engineering points are halved once per faceup copy, rounded down each time. |
| `damage_cards/ship/life_support_failure.gd` | Crew damage card | `VALIDATOR` for `convert_dial_to_token` and `BLOCKER` for `command_token_gain` on ship-activation token-conversion steps | No legacy token-gain bridge remains; immediate command-token discard still resolves through the immediate-effect command/resolver, while the persistent restriction reads `faceup_damage`. |
| `damage_cards/ship/depowered_armament.gd` | Ship damage card | `BLOCKER` for `attack_target` and `VALIDATOR` for `publish_attack_flow` on `ATTACK / ATTACK_DECLARE` | No legacy `ATTACK_VALIDATE_TARGET` bridge remains for this card; long-range target declaration is rejected from serialized attacker damage state. |
| `damage_cards/ship/disengaged_fire_control.gd` | Ship damage card | `BLOCKER` for `attack_target` and `VALIDATOR` for `publish_attack_flow` on `ATTACK / ATTACK_DECLARE` | No legacy `ATTACK_VALIDATE_TARGET` bridge remains; obstruction metadata is published in the attack-declare payload and checked against attacker `faceup_damage`. |
| `damage_cards/ship/ruptured_engine.gd` | Ship damage card | `OBSERVER` on `SHIP_ACTIVATION / MANEUVER_STEP` for `execute_maneuver` | No legacy `AFTER_MANEUVER_EXECUTE` bridge remains; observer follow-up triggers when the maneuver result speed is greater than 1 and draws damage inside `PersistentEffectDamageCommand.execute()`. |
| `damage_cards/ship/targeter_disruption.gd` | Ship damage card | `BLOCKER` for `critical_effect` on `ATTACK / ATTACK_RESOLVE_DAMAGE` | No legacy `ATTACK_RESOLVE_CRITICAL` bridge remains for this card; first-faceup critical handling reads the attacking ship's `faceup_damage`. |
| `damage_cards/ship/thrust_control_malfunction.gd` | Ship damage card | `MODIFIER` on `SHIP_ACTIVATION / MANEUVER_STEP` for `maneuver_yaw` | No legacy `MANEUVER_DETERMINE_YAWS` bridge remains; modifier reduces the last adjustable joint only at the damaged ship's current speed, including after save/load. |
| `damage_cards/ship/thruster_fissure.gd` | Ship damage card | `OBSERVER` on `SHIP_ACTIVATION / MANEUVER_STEP` for `execute_maneuver` | No legacy `ON_SPEED_CHANGE` bridge remains; observer follow-up reads player-authored `speed_delta` from the maneuver command/result boundary so external speed changes do not trigger automatically. |
| `squadron_keywords/bomber.gd` | Squadron keyword | `MODIFIER` for `attack_damage` on `ATTACK / ATTACK_RESOLVE_DAMAGE` | No legacy `BomberEffect` rebuild remains; damage calculation reads the attacking squadron's serialized keyword data and counts critical icons against ships only. |

## Compatibility Adapters

`src/core/movement/maneuver_rule_resolver.gd` centralises Phase N maneuver
preview and yaw application. Scene and tool code calls this core helper instead
of resolving legacy movement hook names directly. After N12-N15, the helper no
longer invokes `EffectRegistry`; it applies RuleRegistry yaw modifiers and
derives non-mutating warning ids from serialized `ShipInstance.faceup_damage`.

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
