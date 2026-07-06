---
name: rule-integration
description: 'Use when: adding, migrating, debugging, or reviewing Armada game rules, card effects, damage cards, squadron keywords, upgrades, objectives, defense-token eligibility, command validators, RuleRegistry hooks, FlowSpec step rules, or UI affordances derived from rules.'
argument-hint: 'Describe the rule/card/keyword and affected flow step'
---

# Rule Integration

Use this skill whenever a change adds, migrates, reviews, or debugs a game rule. It exists because Phase M7 showed that a correct mutation command validator is not enough: selectable UI choices and marker commands must receive the same rule-derived eligibility as the final state mutation.

## Core Lesson

A rule integration is complete only when all surfaces agree:

- Rule surface definition: identify the applicable ADR-003 rule surfaces;
  `RuleRegistry` declares static hooks where appropriate.
- Active state source: the predicate reads authoritative serialized state (`GameState`, `ShipInstance.faceup_damage`, squadron keywords, upgrades, objective state), not stale transient caches.
- Command surface: every command that can express the illegal action is covered, including marker commands such as `commit_defense`, not only the final mutation command.
- Command applicability: `CommandApplicability`, `FlowSpec.allowed_commands`,
   and concrete command `validate()` agree for every phase/step that can produce
   the command.
- Flow ownership: every defender, opponent, non-active-player, or off-turn controller choice has an explicit `FlowSpec` row before UI work begins.
- Interaction payload: if a player can choose from UI options, publish rule-derived eligibility in `interaction_flow.payload` with JSON-safe fields.
- UI rendering: panels render disabled/available choices from payload metadata; they do not re-implement card or keyword rules.
- Preview/commit boundary: selection and range previews do not spend command
   budget or mutate serialized state; only committed command-backed actions and
   explicit lifecycle markers do.
- Rebuild/replay: save/load, replay, hot-seat, and network paths rebuild or derive the same active rule state.

## Procedure

1. Read the source rule text.
   - Use `Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md` for core rules.
   - Use card JSON/rules text for card-specific effects.
   - Add a concise `Rules Reference:` citation to public rule APIs.

2. Classify the rule surface.
   - Attack: declare target, gather/roll dice, modify dice, spend accuracies, spend defense tokens, resolve criticals, resolve damage, additional squadron targets, salvo/counter/ignition variants.
   - Commands: navigate, squadron, repair, concentrate fire, command dial/token costs, raid-token blockers, ready costs.
   - Movement: yaw, speed, maneuver execution, overlap, displacement, obstacle effects, out-of-play destruction.
   - Squadron: activation, engagement, movement gates, squadron keywords, counter/snipe/escort/rogue/grit/heavy/intel/strategic.
   - Status/setup: ready defense tokens, ready upgrade cards, setup deployment effects, pass tokens, objective setup.
   - Objectives/upgrades/tokens: objective tokens, proximity mines, grav/chaff/focus/raid tokens, special obstacles, scoring.

3. Resolve controller ownership before editing UI.
   - If the choice is made by any player other than the active/attacking local pipeline owner, update `docs/game_flow.md` and `FlowSpec` first.
   - Name the controller role, payload identity keys, allowed marker/mutation commands, transition edges, and projected modal/affordance.
   - Add command and projection tests for hot-seat, network, and replay safety before scene/UI wiring.
   - Counter is the reference pattern: the triggering attack pipeline remains with the original executor, but the Counter owner submits `counter_choice`, then owns the Counter roll/modifier/confirm commands.

4. Pick the rule surface, and the hook kind and attachment when `RuleRegistry`
   is appropriate.
   - `VALIDATOR`: rejects a command or selected option.
   - `MODIFIER`: changes a pool/value/context.
   - `OBSERVER`: creates deterministic follow-up commands after an event.
   - `BLOCKER`: marks a target/option unavailable for projection or resolution.
   - `ENABLER`: exposes optional affordances through projection/UI intent.
   - Attach to existing `FlowSpec` pairs. Rules cannot invent new steps; adding a step is a separate FlowSpec change.

5. Cover every command path.
   - Search for commands and marker commands in the flow before coding.
   - If UI submits a marker and a controller later submits a mutation command, validate both.
   - If a lifecycle marker can be submitted from multiple phases or flows,
     update `CommandApplicability`, `FlowSpec.allowed_commands`, and concrete
     command validation together.
   - Treat direct command validation as a safety net, not the only guard.
   - Rejected command results must stop local scene-side effects.

6. Keep UI rule-free.
   - Compute eligibility in core/application code and publish it as JSON-safe payload metadata.
   - Use names such as `blocked_*_indices`, `enabled_*`, or `affordances`.
   - UI panels should only render disabled controls, tooltips/labels, and selected state from that metadata.
   - Never infer card-rule state from local button events.
   - Keep selection/range previews transient. Do not consume command resources
     or activation slots when the user is only inspecting candidates.

7. Preserve active-state semantics.
   - When `RuleRegistry` is the appropriate surface, static rule definitions
     live in `RuleRegistry` and are bootstrapped.
   - Active rule status comes from serialized entities only: `GameState`, ships, squadrons, faceup damage cards, upgrades, objectives, obstacles, and tokens.
   - Do not serialize `RuleRegistry` or use it as an active-card store.
   - For upgrade cards, follow the Runtime Upgrade Pattern proven by Grand Moff
     Tarkin: static upgrade JSON and catalog data remain metadata referenced by
     `data_key`; fleet rosters store `FleetUpgradeAssignment` records; setup
     materializes equipped upgrades into `ShipInstance.runtime_upgrades`;
     command-owned behavior reads the source `runtime_upgrade_id` and writes
     mutable card/trigger/rule state on that runtime upgrade instance; UI state
     is projected through `InteractionFlow`/`UIProjector`; serialization,
     replay, reconnect, and network mirrors carry the runtime upgrade instance
     and command history, not copied static card data or local UI state.

8. Test the full surface.
   - Unit-test the rule predicate for allow/reject cases and other-entity isolation.
   - Test marker command and mutation command paths when both exist.
   - Test save/load/deserialize for persistent effects so active status is proven to come from serialized entities.
   - Test payload metadata that drives UI affordances.
   - Test UI panels render blocked/available options without owning rule logic.
   - For command submission, run baseline traces as required by Phase L/M.

### Interactive Rule Audit

For interactive upgrades or rule prompts, include a command-sequence audit:
compare the expected sequence against observed hot-seat, network host, and
network client sequences, then identify the first divergence. When logs are
available, compare host/client/game logs, command history, mirror application,
and deferred follow-ups. For temporary interactive-rule state, verify the single
authoritative owner, creation point, mutation path, and cleanup/removal point;
after each important command, name the state owner, verify projection is derived
rather than authoritative, and confirm remote command handlers classify every
mirrored command.

9. Update docs.
   - Update `docs/game_flow.md` for new payload fields, allowed commands, or rule-boundary decisions.
   - Update `docs/refactoring_phase_lm_plan.md` for phase status and lessons.
   - Update `docs/implementation_plan.md` baseline counts and open topics.
   - Update arc42 crosscutting concepts when the rule architecture changes.

## Folder Grouping Recommendation

Prefer grouping rule files by source, with per-folder README indexes so users can find a rule by the game component they know:

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

Use one rule file per card, keyword, objective, obstacle, or core rule concept. If one rule has several hooks, keep those hooks in the same file so the rule remains discoverable as a single behavior.

## Verification Commands

After source/test edits, run:

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -60
bash scripts/lint_phase_k.sh
bash scripts/run_baseline_traces.sh --all
git diff --check
```
