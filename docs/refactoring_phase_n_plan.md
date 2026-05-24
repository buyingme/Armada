# Refactoring Phase N - Rule System Completion

> **Status:** IN PROGRESS - completed slices: ✅ N0, ✅ N1, ✅ N2, ✅ N3, ✅ N4, ✅ N5, ✅ N6, ✅ N7, ✅ N8, ✅ N9, ✅ N10, ✅ N11, ✅ N12, ✅ N13, ✅ N14, ✅ N15, ✅ N16, ✅ N17, ✅ N18, ✅ N19, ✅ N20, ✅ N21, ✅ N22; N17-N22 MT pass confirmed 2026-05-23; N23 next.
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
| N3 | ✅ Complete | Power Failure bridge removed; RuleRegistry engineering modifier covered by focused tests, full-suite gate, and MT pass. |
| N4 | ✅ Complete | Life Support Failure token-gain bridge removed; immediate discard remains command/resolver based. MT pass confirmed. |
| N5 | ✅ Complete | Depowered Armament target bridge removed; blocked long-range targets keep Skip Attack available. MT pass confirmed. |
| N6 | ✅ Complete | Disengaged Fire Control migrated to RuleRegistry attack-target blocker/validator for obstructed attacks. MT pass confirmed 2026-05-22. |
| N7 | ✅ Complete | Coolant Discharge source-text ship-target-per-round rule implemented with serialized command-backed count; stale close damage removed. MT pass confirmed 2026-05-22. |
| N8 | ✅ Complete | Blinded Gunners migrated to RuleRegistry accuracy-spend blocker plus locked-token publish validator. MT pass confirmed 2026-05-22. |
| N9 | ✅ Complete | Targeter Disruption migrated to a RuleRegistry critical-effect blocker. MT pass confirmed 2026-05-23. |
| N10 | ✅ Complete | Bomber migrated to a squadron keyword attack-damage modifier; save/load no longer rebuilds `BomberEffect`. MT pass confirmed 2026-05-23. |
| N11 | ✅ Complete | Maneuver rule application extracted into `ManeuverRuleResolver`; scene/tool legacy hook ownership removed while behaviour is preserved, and pre-commit hints warn for Ruptured Engine, Damaged Controls, and Thruster Fissure damage. MT pass confirmed 2026-05-23. |
| N12 | ✅ Complete | Thrust Control Malfunction migrated to RuleRegistry current-speed maneuver yaw modifier; legacy all-row yaw hook removed. MT pass confirmed 2026-05-23. |
| N13 | ✅ Complete | Ruptured Engine migrated to execute-maneuver observer follow-up with command-owned damage-deck draw. MT pass confirmed 2026-05-23. |
| N14 | ✅ Complete | Damaged Controls migrated to execute-maneuver overlap observer using authoritative maneuver-result metadata. MT pass confirmed 2026-05-23. |
| N15 | ✅ Complete | Thruster Fissure migrated to execute-maneuver speed-delta observer scoped to player-authored maneuver speed changes. MT pass confirmed 2026-05-23. |
| N16 | ✅ Complete | Squadron keyword compliance audit completed for Heavy, Escort, Counter, Bomber, and Swarm. Bomber damage works through RuleRegistry but still needs explicit critical-effect eligibility coverage; Heavy, Escort, Counter, and Swarm are not production-compliant yet. |
| N17 | ✅ Complete | Keyword foundation added: shared keyword lookup, standard/Counter attack-kind metadata, non-Heavy engagement predicates, attacker-target-specific engagement checks, target-legality payload fields, and optional attack-modifier affordance metadata. No live gameplay targeting or movement behaviour changed. MT pass confirmed 2026-05-23. |
| N18 | ✅ Complete | Heavy engagement rules now permit movement and ship attacks only when every unobstructed engaging enemy has Heavy; `move_squadron`, target declaration, and UI availability share obstruction-aware serialized squadron keyword predicates. MT pass confirmed 2026-05-23. |
| N19 | ✅ Complete | Escort now uses RuleRegistry target blockers/validators, blocks non-Escort squadron targets while engaged with Escort, exempts Counter attacks, and removes the inert legacy effect class. MT pass confirmed 2026-05-23. |
| N20 | ✅ Complete | Counter projects an explicit defender-owned `ATTACK_COUNTER_CHOICE` flow, accepts/skips through `CounterChoiceCommand`, starts a locked Counter attack with X blue dice, carries attack-kind metadata, prevents Counter recursion, validates roll dice through RuleRegistry, reuses the existing attack panel in hot-seat, projects remote Counter roll/Swarm/confirm controls through the network mirror, and triggers even when the original attack deals zero damage. MT pass confirmed 2026-05-23. |
| N21 | ✅ Complete | Swarm now offers an optional command-backed reroll through `RerollAttackDieCommand`, uses `GameState.rng`, revalidates obstruction-aware engagement from `GameState`, updates attack payload dice deterministically, and removes the inert legacy effect class. MT pass confirmed 2026-05-23. |
| N22 | ✅ Complete | Bomber critical-effect permission is keyword-aware, non-Bomber squadron criticals remain blocked, and the all-keyword regression suite covers Heavy/Escort/Counter/Swarm/Bomber together. MT pass confirmed 2026-05-23. |

N18-N22 verification: full GUT passed at 179 scripts / 3 211 tests / 6 560
asserts with 0 failures, Phase K lint reported 0 violations / 4 allow-listed
branches, baseline traces passed hot-seat trace/state plus real ENet host/client
state-hash equality, and `git diff --check` was clean. The network replay
fixture omits one old `move_squadron` command that attempted to move an engaged
non-Heavy squadron and is now rejected by the authoritative Heavy validator.

Post-playtest keyword follow-up verification: full GUT passed at 181 scripts /
3 239 tests / 6 616 asserts with 0 failures, Phase K lint reported 0
violations / 4 allow-listed branches, baseline traces passed with network-state
hash `50c9edaf428b32bda280a5f7a3104b8bb82066eed4d7fd407087197a8ad6f293`, and
`git diff --check` was clean. The follow-up fixes Counter panel reset/reuse,
locks accepted Counter attacks to their rule-defined target/dice pool, validates
Counter roll dice through RuleRegistry, keeps the network-only attack mirror
closed in hot-seat Counter/Swarm follow-ups, triggers Counter on zero-damage
squadron attacks, and threads obstruction-aware squadron engagement through
Heavy, Escort, Swarm, movement validation, target selection, and Swarm reroll
command validation.

Command-backed Counter ownership follow-up verification: full GUT passed at
185 scripts / 3 262 tests / 6 657 asserts with 0 failures, Phase K lint
reported 0 violations / 4 allow-listed branches, baseline traces passed with
network-state hash
`e00bd2c154663d70b70d95b35230bc9aa128996587b24de935748da265f0d214`, and
`git diff --check` was clean. The follow-up promotes Counter accept/skip to a
dedicated flow/command surface, lets the projected Counter owner control the
accepted Counter roll, Swarm reroll/skip, and dice confirm over the network,
and records the project rule that all defender/opponent/off-turn choices must
define ownership, payload identity, command surfaces, and projection before UI
buttons are wired.

Squadron no-move activation completion follow-up verification: full GUT passed
at 185 scripts / 3 269 tests / 6 669 asserts with 0 failures, Phase K lint
reported 0 violations / 4 allow-listed branches, baseline traces passed with
network-state hash
`1d70beddcb69cee6b956d1725537d4c09b25c87840f1e86ea5964e5c8b58c334`, and
`git diff --check` was clean. The follow-up replaces zero-distance
`move_squadron` skip synchronization with `complete_squadron_activation`, so
engaged attack-only squadrons blocked by the Heavy movement validator still
advance passive network modal counters and hand off the Squadron Phase turn.

Network Swarm reroll affordance follow-up verification: full GUT passed at
185 scripts / 3 272 tests / 6 676 asserts with 0 failures, Phase K lint
reported 0 violations / 4 allow-listed branches, baseline traces passed with
network-state hash
`7e3725022a42514f9cf9d368670da262e13cc8e2f72f7d2236fdd6c33e9f8580`, and
`git diff --check` was clean. The follow-up keeps hits, crits, and all other
dice results selectable for Swarm, ignores network `awaiting_remote` sentinels
until authoritative roll/reroll results arrive, and applies standard-attack
Swarm reroll echoes through the active attack pipeline.
User MT pass confirmed 2026-05-23 for the complete N17-N22 keyword foundation
and live keyword batch.

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
closed the governance gap. Phase N then migrated the remaining damage-card and
squadron-keyword behaviour to `RuleRegistry` surfaces before N23 removed the
legacy runtime effect system from production.

N23 legacy-runtime retirement status:

| Surface | Legacy source | Current call sites / notes |
|---|---|---|
| Persistent ship/crew damage cards | Deleted `DamageCardEffectFactory` / `DamageCardEffect` runtime | Migrated damage-card rules read `ShipInstance.faceup_damage` through RuleRegistry or immediate command/resolver paths. Damage commands no longer register transient persistent effects. |
| Squadron keyword effects | Deleted legacy keyword effect classes and rebuild factory | Heavy, Escort, Counter, Swarm, and Bomber critical permission are RuleRegistry/core-command backed and derive active status from serialized squadron keyword data. |
| Attack validation/damage hooks | Removed legacy attack hook dispatch | Targeter Disruption, Bomber, Blinded Gunners, Coolant Discharge, Depowered Armament, Disengaged Fire Control, Damaged Munitions, and Point-Defense Failure use RuleRegistry surfaces only. |
| Movement hooks | Removed legacy movement hook dispatch | N12-N15 movement damage cards use RuleRegistry yaw/observer surfaces and command/result metadata for deterministic follow-ups. |
| Command/repair hooks | Removed legacy command and repair hook fallbacks | Power Failure, Life Support Failure, Capacitor Failure, and Compartment Fire use RuleRegistry modifiers, validators, or blockers only. |

The main risk of doing nothing was architectural drift: new features would
have to understand two rule systems, two rebuild stories, and two testing
idioms. N23 removes that dual-runtime state from production. The main remaining
risk for Phase N is documenting the new single architecture clearly enough that
future slices do not reintroduce a bridge.

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
| `Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md` | Squadron keyword rules and FAQ entries for Power Failure, Damaged Controls, Disengaged Fire Control, Thruster Fissure, Heavy, Escort, Counter, Bomber, and Swarm. |
| Deleted `src/core/effects/damage_card_effect*.gd` and `effect_factory.gd` history | Legacy persistent damage-card behaviour and active effect id list audited before N23 deletion. |
| Deleted `src/core/effects/keywords/bomber_effect.gd` history | Legacy keyword rebuild behaviour audited before N23 deletion. |
| `src/core/combat/*`, `src/core/damage/*`, `src/core/commands/*`, `src/scenes/game_board/*`, `src/scenes/tools/*` | Production RuleRegistry call sites and command/result metadata. |

### 4.2 Remaining Legacy Damage Cards

| Rule source | Legacy hook(s) | Source-text parity | Phase N direction |
|---|---|---|---|
| Faulty Countermeasures | `DEFENSE_VALIDATE_TOKEN` | Matches card text: exhausted defense tokens cannot be spent. | Complete in N2: RuleRegistry validator and blocker now cover command safety and UI eligibility; the id is removed from `PERSISTENT_EFFECT_IDS`. |
| Power Failure | `CALC_ENGINEERING_VALUE` | Matches card text and FAQ: halve rounded down; multiple copies apply one after the other. | Complete in N3: RuleRegistry repair/engineering modifier, zero legacy effect after save/load, MT pass confirmed 2026-05-22. |
| Life Support Failure | `ON_COMMAND_TOKEN_GAIN` plus immediate resolver token discard | Matches card text. Immediate token discard must stay in the immediate resolver; persistent token-gain blocking must cover both GameManager token gain and `ConvertDialToTokenCommand`. | Complete in N4: immediate discard remains, persistent restriction is RuleRegistry validator/blocker, MT pass confirmed 2026-05-22. |
| Depowered Armament | `ATTACK_VALIDATE_TARGET` | Matches card text: damaged ship cannot attack at long range. | Complete in N5: attack-target blocker plus `publish_attack_flow` validator; blocked target UI keeps Skip Attack available. MT pass confirmed 2026-05-22. |
| Disengaged Fire Control | `ATTACK_VALIDATE_TARGET` | Matches card text and FAQ interaction with obstruction sources such as Admiral Montferrat. | Complete in N6: `attack_target` blocker and `publish_attack_flow` validator read obstruction metadata plus attacker `faceup_damage`; no legacy effect rebuild remains. MT pass confirmed 2026-05-22. |
| Coolant Discharge | `ATTACK_VALIDATE_TARGET`, `ATTACK_CALC_DAMAGE` | Partially mismatched. Source text only says: "Only one attack you perform each round can target a ship." No checked source supports the legacy `+1 close damage` side effect. The legacy predicate also uses the attack executor's per-activation `current_attack` counter, while the card is worded per round and ship-target-specific. | Complete in N7: source-text ship-target-per-round blocker/validator uses serialized `GameState.ship_target_attack_counts` recorded by `roll_dice`; stale close-range damage is not migrated. MT pass confirmed 2026-05-22. |
| Blinded Gunners | `ATTACK_SPEND_ACCURACY` | Matches card text: while attacking, the damaged ship cannot spend accuracy icons. | Complete in N8: RuleRegistry `accuracy_spend` blocker drives zero spendable accuracies and a defense-step publish validator rejects non-empty `locked_tokens`. MT pass confirmed 2026-05-22. |
| Targeter Disruption | `ATTACK_RESOLVE_CRITICAL` | Matches card text: while attacking, the damaged ship cannot resolve critical effects. | Complete in N9: RuleRegistry critical-effect blocker reads attacker `faceup_damage`; N23 removed the legacy fallback. |
| Thrust Control Malfunction | `MANEUVER_DETERMINE_YAWS` | Partially mismatched. Source text and FAQ limit the effect to the last adjustable joint at the ship's current speed. The legacy tool applied the hook to each speed row in the nav chart and reduced the last array entry without checking whether that joint was adjustable. | Complete in N12: RuleRegistry maneuver-yaw modifier applies only to the current speed's last adjustable joint, including after save/load. |
| Ruptured Engine | `AFTER_MANEUVER_EXECUTE` | Matches card text: after maneuver, if speed dial is greater than 1, suffer 1 damage. | Complete in N13: execute-maneuver observer returns a `PersistentEffectDamageCommand` follow-up with deterministic draw-from-deck execution. |
| Damaged Controls | `AFTER_MANEUVER_EXECUTE` | Matches card text and FAQ: resolves during the Move Ship step while executing a maneuver; overlap ship or obstacle deals 1 facedown damage in addition to other obstacle effects. | Complete in N14: execute-maneuver observer reads authoritative `did_overlap` result metadata. Current production overlap metadata covers ship overlap/stayed-in-place paths; future obstacle metadata should feed the same command field. |
| Thruster Fissure | `ON_SPEED_CHANGE` | Mostly matches current player-driven speed-change path. FAQ states Admiral Konstantine's external speed change does not trigger it, so future non-player speed-change effects must not share this trigger automatically. | Complete in N15: execute-maneuver observer reads command/result `speed_delta`, so external `SetSpeedCommand`-style effects do not trigger this rule automatically. |

### 4.3 Retired Legacy Call Sites

N23 removed all production compatibility fallbacks for legacy hook strings.
The Phase K/N lint guard now fails if production code reintroduces these
symbols or old runtime effect classes.

| Hook | Current status | Retirement path |
|---|---|---|
| `ATTACK_GATHER_DICE` | Removed. Damaged Munitions and Point-Defense Failure use RuleRegistry dice-pool modifiers only. | Guarded by `scripts/lint_phase_k.sh`. |
| `DEFENSE_VALIDATE_TOKEN` | Removed. Faulty Countermeasures and Capacitor Failure use RuleRegistry validators/blockers. | Guarded by `scripts/lint_phase_k.sh`. |
| `REPAIR_VALIDATE_SHIELD` | Removed. Capacitor Failure repair eligibility uses RuleRegistry validators/blockers. | Guarded by `scripts/lint_phase_k.sh`. |
| `STATUS_READY_TOKENS` | Removed. Compartment Fire uses a RuleRegistry readying modifier. | Guarded by `scripts/lint_phase_k.sh`. |
| `CALC_ENGINEERING_VALUE` | Removed. Power Failure uses a RuleRegistry engineering modifier. | Guarded by `scripts/lint_phase_k.sh`. |
| `ON_COMMAND_TOKEN_GAIN` | Removed. Life Support Failure uses RuleRegistry validators/blockers. | Guarded by `scripts/lint_phase_k.sh`. |
| `ATTACK_VALIDATE_TARGET` | Removed. Attack-target restrictions use RuleRegistry blockers/validators. | Guarded by `scripts/lint_phase_k.sh`. |
| `ATTACK_RESOLVE_CRITICAL` | Removed. Targeter Disruption and Bomber critical permission use RuleRegistry critical blockers. | Guarded by `scripts/lint_phase_k.sh`. |
| `ATTACK_CALC_DAMAGE` | Removed. Bomber damage uses a RuleRegistry attack-damage modifier. | Guarded by `scripts/lint_phase_k.sh`. |
| `MANEUVER_DETERMINE_YAWS`, `AFTER_MANEUVER_EXECUTE`, `ON_SPEED_CHANGE` | Removed. Movement damage cards use RuleRegistry yaw/observer surfaces. | Guarded by `scripts/lint_phase_k.sh`. |

### 4.4 Squadron Keyword Compliance

| Keyword | Current implementation | Source-text parity | Phase N direction |
|---|---|---|---|
| Heavy | Implemented through shared serialized keyword predicates, squadron movement command validation, squadron activation availability, target selection, and a RuleRegistry `publish_attack_flow` validator. Engagement predicates now include ship/obstacle obstruction context from live tokens or serialized `GameState`. | Compliant for the core rule: Heavy enemies do not prevent movement or ship attacks; mixed engagement with any unobstructed non-Heavy enemy still blocks those options. | Complete in N18; future Grit/Snipe keyword work should reuse the same attack-kind and obstruction-aware engagement boundary. |
| Escort | Implemented through a RuleRegistry `attack_target` blocker and `publish_attack_flow` validator. The inert legacy class and rebuild path are deleted. | Compliant for core attacks: attackers engaged with an unobstructed Escort cannot target non-Escort squadrons, and Counter attacks are exempt. | Complete in N19; future Snipe metadata should keep feeding the same blocker/validator context. |
| Counter X | Implemented as an explicit `ATTACK_COUNTER_CHOICE` flow with `CounterChoiceCommand`, locked Counter dice validation, and projected remote attack controls for the accepted Counter roll/Swarm/confirm surfaces. Attack-kind metadata prevents Counter recursion, and hot-seat reuses the existing attack panel without layering stale UI. | Compliant for the core optional attack: eligible squadron defenders can Counter after non-Counter squadron attacks regardless of damage, use X blue dice, and may Counter even if destroyed. | Complete in N20; the accept/skip choice is now a replay/network-visible marker command instead of scene-local UI state. |
| Bomber | Damage calculation and critical-effect permission both read the attacking squadron's serialized Bomber keyword through RuleRegistry hooks. | Compliant for current damage/critical surfaces: critical icons add damage against ships and only Bomber squadron attackers can resolve a critical effect. | Complete in N22; all-keyword regressions cover non-Bomber squadron critical blocking. |
| Swarm | Implemented as an optional RuleRegistry affordance rendered by the attack panel and applied by `RerollAttackDieCommand` with `GameState.rng`. The inert legacy class and rebuild path are deleted. UI projection and command validation both rederive obstruction-aware engagement. | Compliant for current attack flow: Swarm can reroll one die when attacking a squadron engaged with another unobstructed friendly squadron, including Counter attacks. | Complete in N21; future optional-effect marker standardization can reuse the same command-backed reroll command. |

### 4.5 N0 Decisions

- Coolant Discharge's legacy `+1 close damage` behaviour is stale and must not
  be migrated unless a new primary source is found.
- Coolant Discharge's limit must be ship-target-specific and worded per round;
  using only the current attack executor's per-activation counter is not a
  durable end state.
- Thrust Control Malfunction must be implemented against the current speed and
  last adjustable joint semantics from the FAQ, not the current all-row legacy
  preview hook.
- N16 confirmed Heavy, Escort, Counter, and Swarm were not
   production-compliant. N18-N22 now implement the live rules for all five
   squadron keywords requested for the phase: Heavy, Escort, Counter, Bomber,
   and Swarm.
- N16 confirmed Bomber damage was RuleRegistry-backed but its critical-effect
   permission needed explicit keyword awareness; N22 adds that blocker coverage.

### 4.6 N1 Scaffolding Outcome

- `RuleSurface` now owns stable RuleRegistry surface names and no-op-safe
   helper runners for modifiers, blockers, and observer follow-ups.
- N1 added target names for attack target blockers, attack damage modifiers,
   accuracy blockers, critical blockers, engineering modifiers, token-gain
   blockers, maneuver yaw modifiers, and post-maneuver observer surfaces.
- No production rule registrations or legacy bridge call sites changed in N1;
   fixture hooks prove deterministic ordering and empty-registry no-op output.

### 4.7 N16 Squadron Keyword Audit Outcome

N16 re-ran the keyword audit against production call sites, source rules, and
tests before touching behaviour. The audited RRG v1.5.0 "Squadron Keywords"
rules are:

- Heavy: "You do not prevent engaged squadrons from attacking ships or moving."
- Escort: "Squadrons you are engaged with cannot attack squadrons that lack
   escort unless performing a counter attack."
- Counter X: "After a squadron performs a non-counter attack against you, you
   may attack that squadron with an anti-squadron armament of blue dice equal to
   X, even if you are destroyed."
- Bomber: "While attacking a ship, each of your critical icons adds 1 damage to
   the damage total and you can resolve a critical effect."
- Swarm: "While attacking a squadron engaged with another squadron, you may
   reroll 1 die."

Findings:

- `SQUADRON_MUST_ATTACK_ENGAGED` appears only in `EscortEffect`; no production
   resolver invokes that hook.
- `ATTACK_MODIFY_DICE_ATTACKER` appears only in `SwarmEffect`; no production
   resolver invokes that hook.
- Heavy has no production rule surface; current movement and ship-target gates
   block engaged squadrons without checking whether every engaging enemy has
   Heavy.
- Counter has no production rule surface; there is no attack-kind metadata,
   post-defense trigger, command, UI affordance, or replay-safe counter attack
   flow.
- `EngagementResolver.get_valid_engaged_targets()` and
   `EngagementResolver.is_swarm_eligible()` are pure helpers with no production
   callers in `src/`.
- `TargetSelector` currently prevents an engaged squadron from targeting ships,
   but it does not apply Escort filtering. Its squadron-target guard also checks
   whether the selected defender is engaged by any enemy, not specifically
   whether it is engaged with the attacker.
- Bomber's RuleRegistry damage modifier is production-wired, save/load tested,
   and matches the damage-total clause. The critical-effect clause still needs a
   keyword-aware regression because the current faceup-card gate sees critical
   icons without receiving the squadron attacker's keyword state.
- No production Snipe attack flow exists yet. N20 Counter metadata should still
   name attack kind generically so future Snipe can share the same rule boundary.

Decisions:

- N17 added shared keyword-rule scaffolding: authoritative keyword lookup,
   engagement predicates that can answer "engaged by at least one non-Heavy",
   attack-kind metadata, and target/reroll affordance payload conventions.
- N17 completed that scaffolding in `SquadronKeywordRuleHelper` and
   `RuleSurface` constants without wiring live gameplay behaviour.
- N18 implements Heavy. N19 implements Escort. N20 implements Counter. N21
   implements Swarm. N22 hardens Bomber's critical-effect clause and runs the
   all-keyword regression sweep.
- N18-N22 intentionally remove the inert Escort/Swarm legacy effect classes;
   N23 handles final runtime-system retirement and static guards.
- N16 intentionally makes no gameplay behaviour changes. It records the
   architectural decision point so the upcoming keyword slices do not preserve
   accidental legacy behaviour.

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
| N3 | Migrate Power Failure. Register a `MODIFIER` for repair/engineering value and remove its legacy `CALC_ENGINEERING_VALUE` effect. | low | Yes | Complete 2026-05-22 with MT pass: stacked Power Failure cards halve/round down correctly after save/load with zero legacy effect count. |
| N4 | Migrate Life Support Failure persistent restriction. Keep the immediate token-discard effect in the immediate resolver, but move "cannot gain command tokens" to RuleRegistry validators/blockers for every token-gain surface. | medium | Yes + review | Complete 2026-05-22 with MT pass: `convert_dial_to_token`, GameManager token-gain helper paths, and save/load rebuild all block token gain from serialized faceup damage. |
| N5 | Migrate Depowered Armament. Register an attack target `BLOCKER`/`VALIDATOR` for long-range attacks by the damaged ship. | low | Yes | Complete 2026-05-22 with MT pass: long-range target declaration is blocked through RuleRegistry, old `ATTACK_VALIDATE_TARGET` is not needed for this card, and the blocked-target panel still offers Skip Attack. |
| N6 | Migrate Disengaged Fire Control. Register an attack target `BLOCKER`/`VALIDATOR` for obstructed attacks by the damaged ship. | medium | Yes + review | Complete 2026-05-22 with MT pass: target eligibility and direct attack-flow submissions agree on obstruction blocking. |
| N7 | Migrate Coolant Discharge. Implement the source-text rule only: one ship-targeting attack each round for the damaged ship. Remove the stale close-range damage bonus. | high | No | Complete 2026-05-22 with MT pass: ship-target attack count is serialized, command-backed, replay-safe, and no `ATTACK_CALC_DAMAGE` side effect remains. |
| N8 | Migrate Blinded Gunners. Move accuracy-spend blocking to RuleRegistry and make the attack payload/UI show no spendable accuracies when active. | high | No | Complete 2026-05-22 with MT pass: accuracy UI payload, direct submissions, save/load, and replay derive blocking from `faceup_damage`. |
| N9 | Migrate Targeter Disruption. Move critical-effect blocking to RuleRegistry. | medium | Yes + review | Complete 2026-05-23 with MT pass: standard critical effect and direct damage-resolution paths respect the rule without registering `ATTACK_RESOLVE_CRITICAL`. |
| N10 | Migrate Bomber keyword. Replace `BomberEffect` with a squadron keyword RuleRegistry damage modifier that reads attacker keyword state from serialized squadron data. | low-medium | Yes + review | Complete 2026-05-23 with MT pass: X-wing/Bomber save-load regression no longer expects `BomberEffect`; damage calculation still counts crit icons against ships only. |
| N11 | Extract maneuver rule application away from scene/tool legacy hooks. Add core/application helpers that can apply yaw modifiers and post-maneuver observer contexts from command/result data, while preserving behaviour. | high | No | Complete 2026-05-23 with MT pass: no production scene/tool code owns movement hook predicates; legacy movement effects still pass through compatibility during transition, and activation UI warns before maneuver damage triggers. |
| N12 | Migrate Thrust Control Malfunction. Register a maneuver yaw `MODIFIER` and remove `MANEUVER_DETERMINE_YAWS` for the card. | medium | Yes + review | Complete 2026-05-23 with MT pass: maneuver yaw modifier changes exactly one last adjustable joint at the current speed, after save/load, and does not reduce non-adjustable joints or every speed row. |
| N13 | Migrate Ruptured Engine. Register a post-maneuver `OBSERVER` that emits a deterministic facedown-damage follow-up command when final speed is greater than 1. | high | No | Complete 2026-05-23 with MT pass: observer returns a deferred `PersistentEffectDamageCommand`; draw-from-deck happens in command execution for replay/network determinism. |
| N14 | Migrate Damaged Controls. Register a post-maneuver/overlap `OBSERVER` for extra facedown damage on ship/obstacle overlap. | high | No | Complete 2026-05-23 with MT pass: `ExecuteManeuverCommand` carries authoritative `did_overlap` metadata from the move result. |
| N15 | Migrate Thruster Fissure. Register a speed-change/maneuver `OBSERVER` for deterministic facedown damage when speed changes by 1 or more. | high | No | Complete 2026-05-23 with MT pass: `ExecuteManeuverCommand` carries player-authored `speed_delta`; observer follow-ups do not synthesize on mirrored clients. |
| N16 | Squadron keyword compliance audit. Compare Heavy, Escort, Counter, Bomber, and Swarm against RRG/source data and production call sites. | medium | No | Complete 2026-05-23; Bomber damage is wired, Bomber critical eligibility needs hardening, and Heavy/Escort/Counter/Swarm require implementation slices before Phase N closes. |
| N17 | Keyword rule foundation. Add shared core predicates/surfaces for squadron keyword lookup, engagement-by-non-Heavy, target legality, attack-kind metadata, and optional attack modifier affordances. | high | No | Complete 2026-05-23 with MT pass; `SquadronKeywordRuleHelper` and `RuleSurface` constants add no live gameplay behaviour, and focused tests prove Heavy/non-Heavy engagement, standard/Counter attack kind, attacker-target-specific engagement, and JSON-safe payload conventions. |
| N18 | Implement Heavy. Engaged squadrons may move and attack ships when every engaging enemy has Heavy; mixed engagement with any non-Heavy still blocks movement and ship attacks. | high | No | Complete 2026-05-23 with MT pass: movement availability, `move_squadron`, ship target declaration, and direct publish validators derive Heavy from serialized squadron data. |
| N19 | Implement Escort. Replace the unused legacy `EscortEffect` with a RuleRegistry target blocker/validator backed by core engagement predicates and projection-safe metadata. | high | No | Complete 2026-05-23 with MT pass: no `SQUADRON_MUST_ATTACK_ENGAGED` effect remains; target filtering obeys Escort and Counter attacks are exempt. |
| N20 | Implement Counter X. Add optional post-defense counter-attack affordance and command support for squadron defenders after non-Counter squadron attacks. | high | No | Complete 2026-05-23 with MT pass: Counter uses X blue dice, can trigger after defender destruction, does not recurse from Counter attacks, and publishes attack-kind metadata. |
| N21 | Implement Swarm. Replace inert `SwarmEffect` with an optional attacker reroll affordance/command that applies during standard and Counter squadron attacks when the defender is engaged with another squadron. | high | No | Complete 2026-05-23 with MT pass: reroll choice is command-backed, uses `GameState.rng`, updates attack payload/dice deterministically, works with Counter attacks, and no `ATTACK_MODIFY_DICE_ATTACKER` effect remains. |
| N22 | Bomber closeout and all-keyword regression. Harden Bomber critical-effect eligibility and verify the five keyword rules together. | high | No | Complete 2026-05-23 with MT pass: Bomber damage and critical-effect permission are keyword-aware; non-Bomber squadron critical icons do not create faceup damage; keyword regressions and replay/network gates pass. |
| N23 | Retire legacy runtime system. Delete or quarantine `EffectRegistry`, `GameEffect`, `DamageCardEffect`, legacy keyword effect classes, and obsolete tests. Add a static guard forbidding production `EffectRegistry.resolve_hook`, old hook strings, and new `GameEffect` subclasses. | high | No | Complete 2026-05-23: deleted legacy runtime classes/tests, removed `GameState.effect_registry` and resolver hook fallbacks, added the Phase K/N static guard. Latest verification after the Squadron command preview-commit UX follow-up: full GUT 181 / 3 189 / 6 534, lint 0 violations / 4 allow-listed branches, baseline traces pass hot-seat + network peer equality. |
| N24 | Documentation and baseline closeout. Update `docs/implementation_plan.md`, arc42 crosscutting/runtime docs, rule README, risks/technical debt, and archive Phase N. | low | Yes | Docs state the new single rule architecture, all five requested squadron keywords, and the next roadmap item unambiguously. |

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
5. **Then keywords and retirement (N16-N24).** Bomber migrated earlier because
   it was wired through damage calculation, but N16 expands the keyword closeout
   to Heavy, Escort, Counter, Bomber, and Swarm. Heavy/Escort must share core
   engagement predicates, Counter introduces attack-kind metadata, Swarm needs
   command-backed optional rerolls, and Bomber needs explicit critical-effect
   eligibility coverage before the legacy system can be retired.

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
| Persistent damage-card migration | Focused rule tests, command/direct-submission tests where applicable, and serialize/deserialize coverage proving active status comes from serialized entities without transient runtime effects. |
| UI-affordance migration | UIProjector/payload test plus panel rendering test proving UI displays metadata without owning rule text. |
| Observer/follow-up migration | Replay determinism test proving observer order and follow-up command history; network baseline traces required. |
| Movement migration | Focused maneuver/yaw/overlap tests and manual hot-seat sanity test for maneuver preview/commit timing. |
| Keyword migration | Save/load keyword-state test proving active status comes from serialized squadron data. |
| Legacy retirement | Static guard test plus `rg`/grep inventory showing old production surfaces are gone. |

Manual test gates should be required for N6-N8, N11-N15, and N18-N22 because
they touch visible attack/maneuver/keyword interaction timing. N3-N5 were
batched behind one MT gate by user request; MT pass was confirmed 2026-05-22.
N6-N8 were likewise batched behind one MT gate; MT pass was confirmed
2026-05-22. N9-N11 were batched behind one MT gate by user request; automated
gates passed and MT pass was confirmed 2026-05-23.
N12-N15 were batched behind one MT gate by user request; automated gates passed
and MT pass was confirmed 2026-05-23.
N17-N22 were batched behind one MT gate by user request; automated gates passed
and MT pass was confirmed 2026-05-23.

---

## 8. Lightweight Model Delegation Rules

Lightweight models may implement slices marked `Yes` or `Yes + review` only if
the prompt includes:

- the exact source card/keyword text;
- the target FlowSpec pair and RuleRegistry target string;
- the command and UI surfaces to cover;
- the expected RuleRegistry source-state path and any deleted legacy surface;
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
- N24 documentation closeout.

Poor lightweight-model candidates:

- N0/N1 because they define architecture and surfaces.
- N7 because the Coolant Discharge migration must remove stale behaviour and
   define an authoritative ship-target count.
- N8 because accuracy spending is visible UI plus attack-state timing.
- N11-N15 because maneuver observers require command/replay/network ordering.
- N16-N23 because they decide keyword semantics, add attack timing, and retire
   foundational code.

---

## 9. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---:|---:|---|
| Migrating a legacy bug as if it were a rule | Medium | High | N0 semantic audit blocks implementation when card JSON/RRG and legacy behaviour disagree. Coolant Discharge, Thrust Control Malfunction, and Swarm are the known examples. |
| UI remains enabled while command validation rejects | Medium | High | Reuse the M7 lesson: cover marker commands, final mutation commands, payload metadata, panel rendering, and submit-result guards. |
| Observer follow-ups duplicate in replay/network | Medium | Critical | Use RuleRegistry observer queue only; add replay history assertions and run baseline traces for every observer slice. |
| Scene/tool code keeps owning rule predicates | Medium | High | N11 explicitly extracts maneuver rule application before migrating movement cards. Static guard in N23 catches legacy hook reintroduction. |
| Keyword migration removes behaviour that is already implemented elsewhere | Medium | Medium | N16 audits Heavy, Escort, Counter, Bomber, and Swarm before migration. Existing direct resolver helpers are either codified as core rules or connected through RuleRegistry. |
| Save/load loses active rule status | Low | Critical | Every persistent migration proves active status from serialized entities after serialize/deserialize, with no transient effect registry or rebuild bridge. |
| Big-bang cleanup hides regressions | High | High | One rule or one narrow family per slice; no broad deletion until N23. |

---

## 10. Closing Criteria

Phase N is complete when:

1. No production code depends on `EffectRegistry`, `GameEffect`,
   `DamageCardEffect`, or legacy hook-string dispatch.
2. Heavy, Escort, Counter, Bomber, and Swarm are implemented through
   RuleRegistry/core command surfaces with active status derived from serialized
   squadron keyword data.
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
