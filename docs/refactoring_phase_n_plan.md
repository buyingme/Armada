# Refactoring Phase N - Rule System Completion

> **Status:** IN PROGRESS - completed slices: ✅ N0, ✅ N1, ✅ N2; N3 next.
> **Predecessor:** Phase M is closed at `b9bbe82` / `988641a` with
> RuleRegistry governance in project instructions and architecture skills.
> **Decision point:** Taking Phase N before G4.7 intentionally delays the
> spectator/reconnection/timer roadmap in exchange for a single rule-extension
> architecture.
> **Baseline at proposal:** 163 GUT scripts / 3 096 tests / 6 209 asserts /
> 0 failures, Phase K lint 0 violations / 4 allow-listed branches, baseline
> traces passing hot-seat trace/state plus ENet peer equality.

| Slice | Status | Completion note |
|---:|---|---|
| N0 | ✅ Complete | Inventory and semantic audit recorded in Section 4. |
| N1 | ✅ Complete | `RuleSurface` scaffolding and deterministic fixture coverage added. |
| N2 | ✅ Complete | Faulty Countermeasures bridge retired; UI eligibility uses RuleRegistry blockers. |
| N3 | ⏳ Next | Migrate Power Failure. |

---

## 0. Goal

Complete the migration from the legacy `EffectRegistry` / `GameEffect` runtime
system to the Phase M `RuleRegistry` system so future rules, damage cards,
keywords, upgrades, objectives, obstacles, and rule-derived UI affordances use
one maintainable extension model.

The target end state is:

- `RuleRegistry` is the only rule hook catalogue.
- Active rule status is always read from serialized entities (`GameState`,
  ships, squadrons, faceup damage cards, upgrades, objectives, obstacles,
  tokens) rather than transient registered effect instances.
- `EffectRegistry`, `GameEffect`, `DamageCardEffect`, legacy keyword effect
  subclasses, and legacy hook string dispatch are removed or reduced to
  archived documentation only.
- Immediate damage-card resolution remains command/resolver based where it is
  not a persistent rule hook; Phase N is not a rewrite of immediate effects.

---

## 1. Why Now

Phase M proved the new model with six representative production rules and
closed the governance gap. The codebase is now in a transitional state:
new rules must go through `RuleRegistry`, but remaining production behaviour
still relies on legacy effect classes and old hook names.

Current legacy production surfaces:

| Surface | Legacy source | Current call sites / notes |
|---|---|---|
| Persistent ship/crew damage cards | `DamageCardEffectFactory.PERSISTENT_EFFECT_IDS` and `DamageCardEffect` | 11 effect ids still listed after N2 removed the Faulty Countermeasures bridge. |
| Squadron keyword effects | `BomberEffect`, `EscortEffect`, `SwarmEffect` from `EffectFactory._create_keyword_effect()` | Bomber is wired through damage calculation; Escort is also enforced directly in `EngagementResolver`; Swarm has an old effect class but no production `ATTACK_MODIFY_DICE_ATTACKER` resolver was found in `src/`. |
| Attack validation/damage hooks | `ATTACK_VALIDATE_TARGET`, `ATTACK_CALC_DAMAGE`, `ATTACK_SPEND_ACCURACY`, `ATTACK_RESOLVE_CRITICAL` | Rule timing crosses target declaration, accuracy locking, critical resolution, and damage calculation. |
| Movement hooks | `MANEUVER_DETERMINE_YAWS`, `AFTER_MANEUVER_EXECUTE`, `ON_SPEED_CHANGE` | Some hooks are still invoked from scene/tool code; Phase N should move rule decisions toward core/command surfaces. |
| Command/repair hooks | `CALC_ENGINEERING_VALUE`, `ON_COMMAND_TOKEN_GAIN` | Power Failure and Life Support Failure are good low-risk bridge removals once the RuleRegistry targets exist. |

The main risk of doing nothing is architectural drift: new features will have
to understand two rule systems, two rebuild stories, and two testing idioms.
The main risk of doing Phase N poorly is a broad behavioural regression in
attack or maneuver timing. The plan therefore migrates one vertical slice at a
time and keeps the legacy bridge only until the replacement path is proven.

---

## 2. Goals And Non-Goals

### 2.1 Goals

| ID | Target |
|---|---|
| N-G1 | No production `EffectRegistry.resolve_hook(...)` calls remain in `src/`. |
| N-G2 | `DamageCardEffectFactory.PERSISTENT_EFFECT_IDS` is empty or the factory is deleted. Migrated persistent damage cards do not register legacy runtime effects after save/load. |
| N-G3 | `EffectFactory.rebuild_runtime_effects()` no longer rebuilds damage-card or keyword `GameEffect` instances. Any remaining rebuild work concerns non-rule runtime caches only. |
| N-G4 | All migrated rules are discoverable under `src/core/effects/rules/` using source-first grouping and are registered through `RuleBootstrap`. |
| N-G5 | Rule predicates read active state from serialized entities, never from serialized registry snapshots or stale local UI state. |
| N-G6 | UI rule affordances are produced by core/application projection metadata (`interaction_flow.payload` or `UIIntent.affordances`), and UI widgets only render that metadata. |
| N-G7 | Save/load, replay, hot-seat, and network gates pass after every code-bearing slice. |
| N-G8 | A static guard fails if new production code reintroduces `EffectRegistry`, `GameEffect`, `DamageCardEffect`, or legacy hook strings outside archived docs/tests. |

### 2.2 Non-Goals

- No new Armada gameplay features or new cards beyond migrating already
  implemented behaviour.
- No save-format version bump. RuleRegistry remains computed/runtime-only.
- No new RPC channel, EventBus signal, or PlayMode branch in `src/scenes/` or
  `src/ui/`.
- No broad rewrite of attack or maneuver UX. UI changes are allowed only where
  a rule needs projected eligibility or optional affordances.
- No migration of immediate damage cards that already resolve through the
  immediate-effect command/resolver path and do not use legacy effect hooks.

---

## 3. Migration Principles

1. **One rule source per file.** One card/keyword/core rule lives in one rule
   file even when it registers several hooks.
2. **Legacy-last fallback.** During a slice, callers may run RuleRegistry first
   and then the old bridge. The old bridge is removed only after tests prove
   parity.
3. **Command safety before UI polish.** Direct command/replay/network
   submissions must be rejected or modified correctly before optional UI
   affordance polish lands.
4. **No scene-owned rule predicates.** Scene/tool code may display or submit
   projected decisions; rule predicates belong in core/application surfaces.
5. **Observer hooks never submit directly.** Any follow-up command request uses
   the CommandProcessor deferred observer queue proven in Phase M6/M13.
6. **Known semantic drift must be resolved before migration.** If the old
   effect implementation disagrees with card data or rules text, Phase N fixes
   the source-of-truth rule rather than preserving the accidental old behaviour.

---

## 4. Audit And Scaffolding Findings

N0 froze the remaining legacy inventory and compared source data, RRG/FAQ
entries, and production call sites. No source code was changed in N0. The
following findings are now binding for later Phase N slices.

### 4.1 Sources Checked

| Source | Purpose |
|---|---|
| `Resources/Game_Components/damage_cards.json` | Canonical card titles, timing, and effect text for implemented damage cards. |
| `Resources/Game_Components/damage_deck/damage_deck_composition.txt` | Cross-check of damage-deck composition plus FAQ snippets not present in JSON. |
| `Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md` | Squadron keyword rules and FAQ entries for Power Failure, Damaged Controls, Disengaged Fire Control, Thruster Fissure, Counter/Swarm, and Bomber. |
| `src/core/effects/damage_card_effect.gd` and `src/core/effects/damage_card_effect_factory.gd` | Legacy persistent damage-card behaviour and active effect id list. |
| `src/core/effects/effect_factory.gd` and `src/core/effects/keywords/*.gd` | Legacy keyword rebuild and behaviour. |
| `src/core/combat/*`, `src/core/damage/*`, `src/core/commands/*`, `src/scenes/game_board/*`, `src/scenes/tools/*` | Production legacy hook call sites and metadata. |

### 4.2 Remaining Legacy Damage Cards

| Rule source | Legacy hook(s) | Source-text parity | Phase N direction |
|---|---|---|---|
| Faulty Countermeasures | `DEFENSE_VALIDATE_TOKEN` | Matches card text: exhausted defense tokens cannot be spent. | Complete in N2: RuleRegistry validator and blocker now cover command safety and UI eligibility; the id is removed from `PERSISTENT_EFFECT_IDS`. |
| Power Failure | `CALC_ENGINEERING_VALUE` | Matches card text and FAQ: halve rounded down; multiple copies apply one after the other. | N3 migrates as a RuleRegistry repair/engineering modifier. |
| Life Support Failure | `ON_COMMAND_TOKEN_GAIN` plus immediate resolver token discard | Matches card text. Immediate token discard must stay in the immediate resolver; persistent token-gain blocking must cover both GameManager token gain and `ConvertDialToTokenCommand`. | N4 migrates only the persistent restriction. |
| Depowered Armament | `ATTACK_VALIDATE_TARGET` | Matches card text: damaged ship cannot attack at long range. | N5 migrates as an attack target blocker/validator. |
| Disengaged Fire Control | `ATTACK_VALIDATE_TARGET` | Matches card text and FAQ interaction with obstruction sources such as Admiral Montferrat. | N6 migrates as an attack target blocker/validator using authoritative obstruction metadata. |
| Coolant Discharge | `ATTACK_VALIDATE_TARGET`, `ATTACK_CALC_DAMAGE` | Partially mismatched. Source text only says: "Only one attack you perform each round can target a ship." No checked source supports the legacy `+1 close damage` side effect. The legacy predicate also uses the attack executor's per-activation `current_attack` counter, while the card is worded per round and ship-target-specific. | N7 must migrate the ship-target limit only, remove the damage bonus, and define an authoritative ship-target attack count for current/future attack surfaces. |
| Blinded Gunners | `ATTACK_SPEND_ACCURACY` | Matches card text: while attacking, the damaged ship cannot spend accuracy icons. | N8 migrates with payload/UI eligibility because the visible accuracy-spending step must agree with command safety. |
| Targeter Disruption | `ATTACK_RESOLVE_CRITICAL` | Matches card text: while attacking, the damaged ship cannot resolve critical effects. | N9 migrates as a critical-effect blocker. |
| Thrust Control Malfunction | `MANEUVER_DETERMINE_YAWS` | Partially mismatched. Source text and FAQ limit the effect to the last adjustable joint at the ship's current speed. The legacy tool applies the hook to each speed row in the nav chart and the effect reduces the last array entry without checking whether that joint is adjustable. | N11/N12 must move yaw application into a core helper and implement current-speed/adjustable-joint semantics, not blindly preserve the old preview mutation. |
| Ruptured Engine | `AFTER_MANEUVER_EXECUTE` | Matches card text: after maneuver, if speed dial is greater than 1, suffer 1 damage. | N13 migrates as a deterministic post-maneuver observer follow-up. |
| Damaged Controls | `AFTER_MANEUVER_EXECUTE` | Matches card text and FAQ: resolves during the Move Ship step while executing a maneuver; overlap ship or obstacle deals 1 facedown damage in addition to other obstacle effects. | N14 migrates as a post-maneuver overlap observer using authoritative maneuver-result metadata. |
| Thruster Fissure | `ON_SPEED_CHANGE` | Mostly matches current player-driven speed-change path. FAQ states Admiral Konstantine's external speed change does not trigger it, so future non-player speed-change effects must not share this trigger automatically. | N15 migrates as a command/result-bound speed-change observer and keeps the trigger scoped to player speed changes unless a later rule explicitly broadens it. |

### 4.3 Already Migrated Legacy Call Sites To Retire

Some legacy hook call sites remain as compatibility fallbacks even though their
original damage-card rules have moved to RuleRegistry:

| Hook | Current status | Retirement path |
|---|---|---|
| `ATTACK_GATHER_DICE` | Legacy bridge still runs before RuleRegistry dice-pool modifiers; migrated Damaged Munitions and Point-Defense Failure no longer need a legacy `DamageCardEffect`. | Remove after remaining attack modifier surfaces no longer depend on `EffectRegistry`; N19 static guard should catch reintroduction. |
| `DEFENSE_VALIDATE_TOKEN` | No production resolver fallback remains after N2; Faulty Countermeasures moved to RuleRegistry blocker metadata. | Remove any remaining dead legacy declarations during N19 static-guard cleanup. |
| `REPAIR_VALIDATE_SHIELD` | Compatibility fallback after Capacitor Failure migration; no remaining `DamageCardEffect` source maps to this hook. | Remove during N19 unless another audited rule still needs it. |
| `STATUS_READY_TOKENS` | Compatibility fallback after Compartment Fire migration; no remaining `DamageCardEffect` source maps to this hook. | Remove during N19 unless another audited rule still needs it. |

### 4.4 Remaining Legacy Keyword Effects

| Keyword | Legacy state | Source-text parity | Phase N direction |
|---|---|---|---|
| Bomber | `BomberEffect` is registered by `EffectFactory` and wired through `ATTACK_CALC_DAMAGE`. | Matches RRG and FAQ: crit icons count as damage against ships, and Bomber can resolve standard critical effects. | N10 migrates as a RuleRegistry damage/critical modifier reading attacker keyword state from squadron data. |
| Escort | `EscortEffect` is registered, but no production `SQUADRON_MUST_ATTACK_ENGAGED` resolver was found. `EngagementResolver.get_valid_engaged_targets()` already filters engaged targets to Escort squadrons. | Core resolver matches the main RRG rule, but N16 must account for exceptions such as Counter and Snipe before changing behaviour. | N16/N17 should remove the inert effect class and either document/core-test the existing resolver as the rule implementation or add RuleRegistry target-blocker affordances if the attack flow needs projection metadata. |
| Swarm | `SwarmEffect` is registered, but no production `ATTACK_MODIFY_DICE_ATTACKER` resolver was found. The old effect auto-rerolls the worst die with `Dice.roll_die()` rather than offering the optional player choice or using replay-safe RNG. | Does not match the RRG optional timing as implemented in the old class. It is effectively inert in production and should not be ported as-is. | N18 either implements a real optional command-backed reroll with `GameRng` and UI affordance, or deletes the inert legacy class with a documented future keyword TODO. |

### 4.5 N0 Decisions

- Coolant Discharge's legacy `+1 close damage` behaviour is stale and must not
  be migrated unless a new primary source is found.
- Coolant Discharge's limit must be ship-target-specific and worded per round;
  using only the current attack executor's per-activation counter is not a
  durable end state.
- Thrust Control Malfunction must be implemented against the current speed and
  last adjustable joint semantics from the FAQ, not the current all-row legacy
  preview hook.
- Swarm is not currently production-wired. Any Phase N implementation must be a
  new optional, command-backed, replay-safe rule rather than a mechanical port
  of the old `SwarmEffect`.
- Escort's old effect class appears inert, but the rule itself is already
  partly enforced in `EngagementResolver`. N16 decides whether the final shape
  is core-only with docs/tests, RuleRegistry blocker metadata, or both.

### 4.6 N1 Scaffolding Outcome

- `RuleSurface` now owns stable RuleRegistry surface names and no-op-safe
   helper runners for modifiers, blockers, and observer follow-ups.
- N1 added target names for attack target blockers, attack damage modifiers,
   accuracy blockers, critical blockers, engineering modifiers, token-gain
   blockers, maneuver yaw modifiers, and post-maneuver observer surfaces.
- No production rule registrations or legacy bridge call sites changed in N1;
   fixture hooks prove deterministic ordering and empty-registry no-op output.

---

## 5. Slice Plan

`Light model?` means the slice is small enough for a cheaper coding model to
implement with a strict prompt and the normal review/gate process. `Yes +
review` means the code is likely small, but a senior pass should verify rule
semantics and command/UI surfaces before commit. `No` means the slice has
architecture or timing risk and should stay with the strongest available model
or be actively pair-reviewed.

| Slice | Scope | Risk | Light model? | Primary acceptance |
|---:|---|---|:---:|---|
| N0 | Inventory and semantic audit. Freeze the remaining legacy hook inventory, compare each legacy behaviour to `Resources/Game_Components/damage_cards.json`, RRG/card text, and production call sites. Explicitly decide whether Coolant Discharge's legacy `+1 close damage` behaviour is valid or stale. | low | No | Complete 2026-05-19; audit findings are recorded in Section 4 and block blind ports of Coolant Discharge, Thrust Control Malfunction, and Swarm. |
| N1 | Rule-surface scaffolding. Add no-behaviour-change RuleRegistry targets/helpers for attack target blockers, attack damage modifiers, accuracy blockers, critical blockers, engineering modifiers, token-gain blockers, maneuver yaw modifiers, and maneuver observers. Existing legacy bridge remains. | medium | No | Complete 2026-05-19; `RuleSurface` fixture hooks prove new surfaces run in deterministic order and preserve old output when no production rule is registered. |
| N2 | Retire the Faulty Countermeasures legacy UI bridge. Move blocked-token metadata fully to RuleRegistry blocker/projection data and remove `faulty_countermeasures` from `PERSISTENT_EFFECT_IDS`. | low | Yes | Complete 2026-05-20 with MT pass confirmed 2026-05-21; existing M7 command coverage still passes and defense-token UI eligibility no longer depends on `DEFENSE_VALIDATE_TOKEN`. |
| N3 | Migrate Power Failure. Register a `MODIFIER` for repair/engineering value and remove its legacy `CALC_ENGINEERING_VALUE` effect. | low | Yes | Stacked Power Failure cards halve/round down correctly after save/load with zero legacy effect count. |
| N4 | Migrate Life Support Failure persistent restriction. Keep the immediate token-discard effect in the immediate resolver, but move "cannot gain command tokens" to RuleRegistry validators/blockers for every token-gain surface. | medium | Yes + review | `convert_dial_to_token`, GameManager token-gain helper paths, save/load, replay, and network mirrors all block token gain from serialized faceup damage. |
| N5 | Migrate Depowered Armament. Register an attack target `BLOCKER`/`VALIDATOR` for long-range attacks by the damaged ship. | low | Yes | Long-range target declaration is blocked through RuleRegistry and old `ATTACK_VALIDATE_TARGET` is not needed for this card. |
| N6 | Migrate Disengaged Fire Control. Register an attack target `BLOCKER`/`VALIDATOR` for obstructed attacks by the damaged ship. | medium | Yes + review | Target eligibility and direct attack-flow submissions agree on obstruction blocking in hot-seat and network. |
| N7 | Migrate Coolant Discharge. Implement the source-text rule only: one ship-targeting attack each round for the damaged ship. Remove the stale close-range damage bonus. | high | No | Ship-target attack count is authoritative and replay-safe; no `ATTACK_CALC_DAMAGE` side effect remains. |
| N8 | Migrate Blinded Gunners. Move accuracy-spend blocking to RuleRegistry and make the attack payload/UI show no spendable accuracies when active. | high | No | Accuracy UI, direct submissions, save/load, and replay all derive blocking from `faceup_damage`; loaded Blinded Gunners regression remains covered. |
| N9 | Migrate Targeter Disruption. Move critical-effect blocking to RuleRegistry. | medium | Yes + review | Standard critical effect and direct damage-resolution paths respect the rule without `ATTACK_RESOLVE_CRITICAL`. |
| N10 | Migrate Bomber keyword. Replace `BomberEffect` with a squadron keyword RuleRegistry damage modifier that reads attacker keyword state from serialized squadron data. | low-medium | Yes + review | X-wing/Bomber save-load regression no longer expects `BomberEffect`; damage calculation still counts crit icons against ships only. |
| N11 | Extract maneuver rule application away from scene/tool legacy hooks. Add core/application helpers that can apply yaw modifiers and post-maneuver observer contexts from command/result data, while preserving behaviour. | high | No | No production scene/tool code owns rule predicates; legacy movement effects still pass through compatibility during transition. |
| N12 | Migrate Thrust Control Malfunction. Register a maneuver yaw `MODIFIER` and remove `MANEUVER_DETERMINE_YAWS` for the card. | medium | Yes + review | Maneuver tool yaw preview changes exactly one last adjustable joint at the current speed, after save/load, and does not reduce non-adjustable joints or every speed row. |
| N13 | Migrate Ruptured Engine. Register a post-maneuver `OBSERVER` that emits a deterministic facedown-damage follow-up command when final speed is greater than 1. | high | No | Follow-up ordering is captured in replay; network host/client state hashes match; observer does not submit synchronously. |
| N14 | Migrate Damaged Controls. Register a post-maneuver/overlap `OBSERVER` for extra facedown damage on ship/obstacle overlap. | high | No | Ship and obstacle overlap metadata comes from the authoritative maneuver result, not scene-local cached state. |
| N15 | Migrate Thruster Fissure. Register a speed-change/maneuver `OBSERVER` for deterministic facedown damage when speed changes by 1 or more. | high | No | Speed delta is recorded at command/result boundary and replay/network do not duplicate damage. |
| N16 | Keyword target-rule audit: Escort and Swarm. Decide which existing non-EffectRegistry logic is already authoritative and which behaviour still needs RuleRegistry affordances. | medium | No | Documents whether Escort moves to RuleRegistry blocker, remains a core engagement rule, or needs both; confirms Swarm is or is not currently wired. |
| N17 | Migrate Escort, if N16 keeps it in RuleRegistry scope. Replace the unused legacy `EscortEffect` with either a RuleRegistry target blocker or a documented core engagement rule outside EffectRegistry. | medium | No | No `SQUADRON_MUST_ATTACK_ENGAGED` effect remains; target filtering still obeys Escort. |
| N18 | Migrate Swarm, if N16 confirms implemented behaviour should ship now. Add attacker optional reroll affordance/command support through RuleRegistry instead of the unused legacy effect class. | high | No | Optional reroll is command-backed, `GameRng`/replay-safe, and projected as UI affordance; otherwise the old inert class is deleted with a documented TODO for future keyword implementation. |
| N19 | Retire legacy runtime system. Delete or quarantine `EffectRegistry`, `GameEffect`, `DamageCardEffect`, legacy keyword effect classes, and obsolete tests. Add a static guard forbidding production `EffectRegistry.resolve_hook`, old hook strings, and new `GameEffect` subclasses. | high | No | Full suite, lint, baseline traces pass; grep/static test proves no production legacy effect system remains. |
| N20 | Documentation and baseline closeout. Update `docs/implementation_plan.md`, arc42 crosscutting/runtime docs, rule README, risks/technical debt, and archive Phase N. | low | Yes | Docs state the new single rule architecture and the next roadmap item unambiguously. |

---

## 6. Recommended Order Rationale

1. **Start with bridge cleanup and simple modifiers (N2-N4).** These reduce
   mixed-system complexity quickly and exercise non-attack surfaces before the
   higher-risk attack/maneuver migrations.
2. **Then attack target blockers (N5-N7).** They share the same declaration
   context and can replace the largest single legacy hook family in small,
   repeatable steps.
3. **Then attack outcome blockers/modifiers (N8-N10).** Accuracy, criticals,
   and Bomber touch visible attack UI and damage calculation, so they should
   land after the target-declaration path is stable.
4. **Then maneuver observers (N11-N15).** These are deliberately late because
   they require moving rule decisions away from scene/tool code and making
   follow-up damage command ordering deterministic.
5. **Then keywords and retirement (N16-N20).** Bomber can migrate earlier
   because it is wired through damage calculation, but Escort and Swarm need an
   explicit audit: Escort is already duplicated in core engagement logic, while
   Swarm appears to have an old effect class without a production resolver.

---

## 7. Per-Slice Acceptance Gates

Every code-bearing slice must run:

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -80
bash scripts/lint_phase_k.sh
bash scripts/run_baseline_traces.sh --all
git diff --check
```

Additional gates by slice type:

| Slice type | Extra required coverage |
|---|---|
| Persistent damage-card migration | Focused rule tests, command/direct-submission tests where applicable, save/load plus `EffectFactory.rebuild_runtime_effects()` proving zero legacy effect for the migrated card. |
| UI-affordance migration | UIProjector/payload test plus panel rendering test proving UI displays metadata without owning rule text. |
| Observer/follow-up migration | Replay determinism test proving observer order and follow-up command history; network baseline traces required. |
| Movement migration | Focused maneuver/yaw/overlap tests and manual hot-seat sanity test for maneuver preview/commit timing. |
| Keyword migration | Save/load keyword-state test proving active status comes from squadron data, not registered `GameEffect` instances. |
| Legacy retirement | Static guard test plus `rg`/grep inventory showing old production surfaces are gone. |

Manual test gates should be required for N8, N11-N15, N17, and N18 because
they touch visible attack/maneuver/keyword interaction timing.

---

## 8. Lightweight Model Delegation Rules

Lightweight models may implement slices marked `Yes` or `Yes + review` only if
the prompt includes:

- the exact source card/keyword text;
- the target FlowSpec pair and RuleRegistry target string;
- the command and UI surfaces to cover;
- the expected removal from `DamageCardEffectFactory` or `EffectFactory`;
- the focused test names to add/update;
- the full verification commands above.

They should not make roadmap decisions, consolidate multiple slices, alter
FlowSpec semantics, add PlayMode branches, or edit allow-lists. For `Yes +
review` slices, a stronger model or human reviewer should explicitly check
source-rule fidelity and whether marker commands, payload metadata, save/load,
replay, and network mirrors are all covered.

Good lightweight-model candidates:

- N2 Faulty Countermeasures bridge retirement.
- N3 Power Failure.
- N5 Depowered Armament.
- N10 Bomber, after N1 scaffolding exists.
- N20 documentation closeout.

Poor lightweight-model candidates:

- N0/N1 because they define architecture and surfaces.
- N7 because the Coolant Discharge migration must remove stale behaviour and
   define an authoritative ship-target count.
- N8 because accuracy spending is visible UI plus attack-state timing.
- N11-N15 because maneuver observers require command/replay/network ordering.
- N16-N19 because they decide keyword semantics and retire foundational code.

---

## 9. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---:|---:|---|
| Migrating a legacy bug as if it were a rule | Medium | High | N0 semantic audit blocks implementation when card JSON/RRG and legacy behaviour disagree. Coolant Discharge, Thrust Control Malfunction, and Swarm are the known examples. |
| UI remains enabled while command validation rejects | Medium | High | Reuse the M7 lesson: cover marker commands, final mutation commands, payload metadata, panel rendering, and submit-result guards. |
| Observer follow-ups duplicate in replay/network | Medium | Critical | Use RuleRegistry observer queue only; add replay history assertions and run baseline traces for every observer slice. |
| Scene/tool code keeps owning rule predicates | Medium | High | N11 explicitly extracts maneuver rule application before migrating movement cards. Static guard in N19 catches legacy hook reintroduction. |
| Keyword migration removes behaviour that is already implemented elsewhere | Medium | Medium | N16 audits Escort/Swarm before deletion or migration. Existing direct resolver behaviour is either codified as core rule or connected through RuleRegistry. |
| Save/load loses active rule status | Low | Critical | Every persistent migration proves active status from serialized entities after `EffectFactory.rebuild_runtime_effects()`, with zero legacy effect for the migrated source. |
| Big-bang cleanup hides regressions | High | High | One rule or one narrow family per slice; no broad deletion until N19. |

---

## 10. Closing Criteria

Phase N is complete when:

1. No production code depends on `EffectRegistry`, `GameEffect`,
   `DamageCardEffect`, or legacy hook-string dispatch.
2. All currently implemented persistent damage-card rules and keyword effects
   either live in RuleRegistry or are explicitly documented as non-hook core
   rules outside the old effect system.
3. `src/core/effects/rules/README.md` indexes every migrated production rule.
4. `docs/game_flow.md` and arc42 describe one rule-extension architecture.
5. Full GUT, Phase K lint, baseline traces, and `git diff --check` pass.
6. `docs/implementation_plan.md` records the Phase N baseline and the next
   approved roadmap item.

---

## 11. Successor Options

After Phase N, resume the network roadmap in the existing order unless a new
priority is approved:

1. G4.7 Spectator Mode.
2. G4.8 Reconnection runtime.
3. G4.9 Turn Timers.
4. Phase 10c network requirement coverage gate.
