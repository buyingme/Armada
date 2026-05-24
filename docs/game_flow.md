# Game Flow Master Document

> Phase M0 source-of-truth draft. This document describes the current
> interaction-flow skeleton in human-readable form before it is encoded as
> `FlowSpec` in M1.
>
> Scope: every `(flow_type, step_id)` pair currently projected by
> `UIProjector`, produced by `InteractionFlow.make()`, or retained as a
> legacy-compatible `InteractionStep` in `Constants`. It records controller
> role, visible modal, allowed command surface, transition edges, rule
> citation, current producer, and notes for later M slices.
>
> Non-scope for M0: no runtime behavior changes, no command gating, no
> RuleRegistry migration, and no save-format changes.

## 0. Conventions

- `controller_role` is a prose role for M0. M1 will translate these roles into
  machine-readable `FlowSpec` data.
- `allowed_commands` lists command types that currently own or drive the step.
  It is descriptive, not yet enforced. M3/M4 will split these into
  `GLOBAL`, `PHASE`, and `FLOW_STEP` declarations.
- `modal_kind` names the projected `Constants.ModalKind` value, or `NONE` when
  the flow is visible only through board/HUD state.
- `producer` names the current code surface that writes the flow. Some command
  and status-phase rows are present because `UIProjector` and legacy maps can
  project them, even if no current command writes that exact pair.
- `visibility` is currently `ALL` for every public flow listed here unless a
  row explicitly says otherwise. Command dial contents remain private inside
  command payload/filter logic, not by making the flow itself private.

### 0.1 Model Fitness Review (M0.5)

M0.5 reread every block below against three questions: can the current
`InteractionFlow` shape carry the prose requirement, are any blocks duplicate
names for one logical step, and can the current command set express the
described behaviour. No separate model-fix slice is required before `FlowSpec`,
but M1 must make `controller_role` a first-class spec column instead of leaving
each producer to recompute the resolved `controller_player`.

| Review question | Result | M1/M3 consequence |
|---|---|---|
| Does `flow_type / step_id / controller_player / payload` carry the required runtime information? | Pass. The pair identifies the interactive window, `controller_player` identifies the actor or `-1`, and `payload` carries step-specific JSON-safe data such as `ship_index`, `squadron_index`, dice/attack snapshots, and displaced-squadron references. `visible_to` remains sufficient for public-vs-filtered payload handling. | `FlowSpec` should store the semantic `controller_role` (`ACTIVE_PLAYER`, `OPPOSING_PLAYER`, `ATTACKER`, `DEFENDER`, `SYSTEM`, etc.) and derive the resolved player. `InteractionFlow` continues to store the resolved player for projection/save/load. |
| Are any blocks model duplicates? | No blocking duplication. A few rows are intentionally legacy-compatible or projection-only: `REVEAL_DIAL`/`SPEND_DIAL` overlap with today's `ACTIVATION_MODAL_OPEN`, `SQUAD_MOVE`/`SQUAD_ATTACK` overlap with modal-local Squadron state plus shared `ATTACK`, and `STATUS_CLEANUP_STEP`/`GAME_OVER_STEP` are projectable constants more than command-produced flows today. | Keep these entries in M1 for parity with `Constants` and `UIProjector`, but mark their command applicability carefully. Do not invent replacement names during M1. |
| Does any block describe behaviour the current command set cannot express? | No model-blocking gap. Current commands express the durable actions and the currently produced flows. Some phase/status/projected rows are not uniformly entered through `GameCommand.execute()` yet, and some UI-local Squadron substeps are represented by modal state plus commands rather than direct flow writes. | M0.7/M3 must classify commands as `GLOBAL`, `PHASE`, or `FLOW_STEP` so phase/system commands and projection-only rows are not rejected by future flow-step gates. |

Worked example: `SQUADRON_DISPLACEMENT / DISPLACEMENT_PLACE` records the
2026-05-11 displacement bug fixed in `c673ef0`. RRG "Overlapping", p.8 says
the player who did not move the ship places the overlapped squadrons,
regardless of squadron ownership. The current runtime can represent the
correct state: `InteractionFlow.flow_type` is `SQUADRON_DISPLACEMENT`,
`step_id` is `DISPLACEMENT_PLACE`, `controller_player` is the non-moving
player, and `payload` carries the maneuvering `ship_index` plus
`displaced_squadrons`. The bug class existed because no central table declared
`DISPLACEMENT_PLACE -> OPPOSING_PLAYER`, so `StartDisplacementCommand` had to
receive and trust an ad-hoc `controller_player`. M1's `FlowSpec` must make that
role explicit, so future producers derive the resolved controller instead of
re-inventing it.

### 0.2 Rule Runtime Boundary (N23)

N23 retired the transient `EffectRegistry` / `GameEffect` runtime. There is now
one production rule extension model: `RuleRegistry` declares static hook
definitions, while active rule status is derived from authoritative serialized
entities such as `GameState`, ship/squadron instances, faceup damage cards,
upgrades, objectives, obstacles, and tokens.

| Surface | Responsibility | Persistence contract |
|---|---|---|
| `RuleRegistry` | Static catalogue of validators, modifiers, observers, blockers, enablers, priorities, and FlowSpec attachment points. | Computed/runtime-only. It stores definitions, not active card instances. |
| `RuleSurface` | Shared target names and callback runners for command validation, projection eligibility, modifiers, and observer follow-ups. | Stateless; callers provide serialized state/context for each invocation. |
| Serialized entities | Source of active rule truth: faceup damage cards, squadron keywords, objective/upgrades/tokens, and command/result metadata. | Serialized by `GameState` or owned model classes and rebuilt through normal deserialize/load paths. |

Worked example: Blinded Gunners. The save contains a ship with serialized
`faceup_damage.effect_id == "blinded_gunners"`. After deserialize, no runtime
effect is rebuilt; the RuleRegistry `accuracy_spend` blocker reads the active
card directly from `ShipInstance.faceup_damage` in hot-seat, network, replay,
and direct command validation.

The static guard in `scripts/lint_phase_k.sh` fails if production code
reintroduces the retired runtime classes or legacy hook-string dispatch. Future
rules must therefore define a RuleRegistry surface, identify the serialized
state that proves active status, and cover command, projection, replay, and
network paths through that one source of truth.

### 0.3 Command Scope Model (M0.7)

M0.7 classifies command applicability before M3 encodes it in machine-readable
declarations. The scope is the first coarse gate; command-specific
`validate()` methods still enforce payload, target, and rules constraints.
This keeps M4 from treating every command as a modal step action and rejecting
legitimate setup, phase, replay, debug, or deterministic follow-up commands
when `interaction_flow` is empty or temporarily points at a different surface.

| Scope | Meaning | M3/M4 declaration shape |
|---|---|---|
| `GLOBAL` | Not gated by the current `interaction_flow` or by a normal gameplay phase surface. Used for synchronization snapshots, debug tooling, and cleanup commands whose own validation owns legality. | Declare the command type as globally exempt from FlowSpec step checks; keep command `validate()` as the authoritative guard. |
| `PHASE` | Legal during one or more `Constants.GamePhase` values regardless of the current modal/step. Used for phase transitions, status cleanup, command-token utility commands, and legacy effect follow-ups that are not cleanly represented as a single flow step yet. | Declare the allowed phases. M4 checks `GameState.current_phase` before command `validate()`. |
| `FLOW_STEP` | Legal only inside explicit `(flow_type, step_id)` pairs. Used for player choices and flow-control markers that are meaningful only while a concrete projected interaction is active. | Declare all allowed pairs. M4 checks `GameState.interaction_flow` before command `validate()`. |

### 0.4 Rule Integration Workflow (M7 MT lesson)

The M7 Faulty Countermeasures manual-test follow-up changed the rule migration
acceptance bar. The original direct validator correctly rejected
`spend_defense_token`, but the real UI path first sent `commit_defense` with a
list of selected token indices. Because the marker command and payload choices
were not rule-gated, the panel could still select exhausted tokens and scene
code could apply local effects even when the later mutation command was
rejected.

Future rule integrations must check all of these surfaces before a slice is
done:

- **Command parity:** every marker/commit command and every final mutation
  command that can express the illegal action is covered by the rule.
- **Non-active-player choice gate:** before implementing any choice owned by a
  defender, opponent, non-active player, or off-turn controller, first add or
  update the `FlowSpec`/this document row. The row must name the controller
  role, ownership payload, allowed command(s), transition edges, projection
  path, and hot-seat/network/replay tests before UI buttons are wired.
- **Payload affordance:** if the player chooses from a list, core/application
  code publishes rule-derived eligibility in `interaction_flow.payload`
  using JSON-safe fields such as `blocked_defense_token_indices`.
- **Renderer-only UI:** panels use those payload fields to disable or enable
  controls and do not interpret card text themselves.
- **Submit-result guard:** scene/controller local effects run only after
  `GameManager.submit_*` returns a non-empty accepted result.
- **Rebuild path:** save/load, replay, hot-seat, and network derive active rule
  state from serialized entities only.

The reusable checklist now lives in
[.github/skills/rule-integration/SKILL.md](../.github/skills/rule-integration/SKILL.md).

RRG v1.5 shows the remaining rule families that need this treatment:

| Rule family | Main future hook surfaces |
|---|---|
| Attack and dice | Declare target, gather/roll dice, spend accuracies, modify dice, resolve criticals, resolve damage, additional squadron targets, salvo/counter/ignition variants. |
| Defense tokens | Spend eligibility, accuracy locks, token state transitions, speed-0 prohibition, cost-only spends, contain/redirect/evade/brace/scatter/salvo effects. |
| Commands | Dial/token resolution, command-triggered upgrades, command-token costs, raid-token blockers, repair targeting, squadron activation counts, concentrate-fire dice. |
| Movement and geometry | Speed/yaw changes, maneuver execution, overlap, displacement ownership, obstacle effects, out-of-play destruction, huge-ship exceptions. |
| Squadrons and keywords | Engagement, movement gates, activation state, attack eligibility, counter/snipe/escort/rogue/grit/heavy/intel/strategic and unique squadron defense tokens. |
| Status and readying | Defense-token readying, upgrade-card ready costs, recurring/non-recurring cards, round-token advance, cleanup timing. |
| Objectives and setup | Objective choice, setup-area changes, obstacle placement/movement, objective ships/tokens, scoring and victory tokens. |
| Upgrades and special tokens | Commander/officer/weapon/etc. effects, grav/chaff/focus/raid/proximity mine tokens, armed/destroyed stations, ignition targeting tokens. |

Current registered command inventory for M3:

| Command | Scope | Declaration target | Reason / M-slice note |
|---|---|---|---|
| `assign_dials` | `PHASE` | `COMMAND` | Command Phase assignment is phase-gated; current command-phase flow rows are not uniformly command-produced. |
| `start_round` | `PHASE` | `SETUP`, `STATUS` | Starts the initial or next round, so it intentionally runs outside a concrete interaction step. |
| `advance_phase` | `PHASE` | `COMMAND`, `SHIP`, `SQUADRON` | Phase transition command; payload validation enforces the expected next phase and excludes `STATUS -> COMMAND`. |
| `status_phase_cleanup` | `PHASE` | `STATUS` | Deterministic end-of-round cleanup, including RuleRegistry `defense_token_readying` modifiers and remaining legacy status hooks. |
| `debug_deal_damage` | `GLOBAL` | Debug harness only | Debug tool is explicitly phase-independent and owns its own target/card validation. |
| `destroy_unit` | `GLOBAL` | Destruction cleanup | Cleanup can follow any damage source; do not tie it to the flow that discovered destruction. |
| `publish_attack_flow` | `GLOBAL` | Attack-flow synchronization snapshot | Snapshot publisher writes `interaction_flow`; gating it by the current step would block the very sync it performs. |
| `activate_ship` | `FLOW_STEP` | `SHIP_ACTIVATION / WAIT_FOR_SHIP_SELECT`, `SHIP_ACTIVATION / REVEAL_DIAL` | Ship selection / second-click activation enters the activation modal. |
| `reveal_dial` | `FLOW_STEP` | `SHIP_ACTIVATION / WAIT_FOR_SHIP_SELECT`, `SHIP_ACTIVATION / REVEAL_DIAL` | Two-click dial preview/unreveal is part of ship selection. |
| `convert_dial_to_token` | `FLOW_STEP` | `SHIP_ACTIVATION / WAIT_FOR_SHIP_SELECT`, `SHIP_ACTIVATION / ACTIVATION_MODAL_OPEN`, `SHIP_ACTIVATION / SPEND_DIAL` | Activation alternative that spends the dial into a token and may trigger token overflow. |
| `advance_activation_step` | `FLOW_STEP` | `SHIP_ACTIVATION / ACTIVATION_MODAL_OPEN`, `SHIP_ACTIVATION / SQUADRON_STEP`, `SHIP_ACTIVATION / REPAIR_STEP`, `SHIP_ACTIVATION / ATTACK_STEP`, `SHIP_ACTIVATION / MANEUVER_STEP`, `SHIP_ACTIVATION / ACTIVATION_DONE` | Authoritative activation sub-step transition marker. |
| `spend_dial` | `PHASE` | `SHIP` | Used by activation, Concentrate Fire, and Crew Panic's rule-correct hidden-dial discard path. |
| `spend_token` | `PHASE` | `SHIP` | Command-token utility spans multiple activation and attack-modify surfaces; current token-budget validation is command/UI owned. |
| `discard_token` | `PHASE` | `SHIP` | Overflow discard has no standalone flow step today. |
| `set_speed` | `PHASE` | `SHIP` | Navigate-speed mutation is budget-validated by the maneuver UI; later slices may narrow it to `MANEUVER_STEP`. |
| `repair_action` | `FLOW_STEP` | `SHIP_ACTIVATION / REPAIR_STEP` | Engineering mutations belong to the repair sub-step; `RepairResolver` keeps transient point validation. |
| `execute_maneuver` | `FLOW_STEP` | `SHIP_ACTIVATION / MANEUVER_STEP` | Maneuver submission already has activation-flow validation with legacy compatibility exemptions. |
| `overlap_damage` | `FLOW_STEP` | `SHIP_ACTIVATION / MANEUVER_STEP` | Deterministic ship-overlap damage follows maneuver resolution. |
| `start_displacement` | `FLOW_STEP` | `SHIP_ACTIVATION / MANEUVER_STEP` | Opens `SQUADRON_DISPLACEMENT / DISPLACEMENT_PLACE` after ship-squadron overlap. |
| `commit_displacement` | `FLOW_STEP` | `SQUADRON_DISPLACEMENT / DISPLACEMENT_PLACE` | Only the projected displacement controller may commit normalized placements. |
| `end_activation` | `FLOW_STEP` | `SHIP_ACTIVATION / MANEUVER_STEP`, `SHIP_ACTIVATION / ACTIVATION_DONE` | Ends the active ship after maneuver/terminal activation flow and returns to ship selection. |
| `activate_squadron` | `FLOW_STEP` | `SQUADRON_ACTIVATION / WAIT_FOR_SQUAD_SELECT` | Squadron selection enters the action-choice modal. |
| `move_squadron` | `FLOW_STEP` | `SQUADRON_ACTIVATION / ACTION_CHOICE`, `SQUADRON_ACTIVATION / SQUAD_MOVE`, `SHIP_ACTIVATION / SQUADRON_STEP` | Durable squadron position update for Squadron Phase movement or ship Squadron-command movement. |
| `complete_squadron_activation` | `PHASE` | `SHIP`, `SQUADRON` | Durable lifecycle marker for a Squadron Phase or ship Squadron-command activation that ends without a legal movement command; never use zero-distance `move_squadron` as a completion marker. |
| `skip_attack` | `FLOW_STEP` | `SHIP_ACTIVATION / ATTACK_STEP`, `SQUADRON_ACTIVATION / SQUAD_ATTACK`, `ATTACK / ATTACK_DECLARE`, `ATTACK / ATTACK_ROLL`, `ATTACK / ATTACK_MODIFY` | Replay-visible choice to pass attack or sub-step where attacker owns the choice. |
| `roll_dice` | `FLOW_STEP` | `ATTACK / ATTACK_ROLL` | Attack dice roll is meaningful only inside the attack roll step. Optional attacker/target identity metadata records ship-target attacks for Coolant Discharge without changing existing replay payload compatibility. |
| `skip_attack_modifier` | `FLOW_STEP` | `ATTACK / ATTACK_MODIFY` | Controller marker for optional attack-modifier skips such as Swarm when the projected attack controller is not the peer that owns the local attack pipeline. |
| `confirm_attack_dice` | `FLOW_STEP` | `ATTACK / ATTACK_MODIFY` | Controller marker that final dice are accepted after roll and optional attacker modifiers, including remote-controlled Counter attacks. |
| `counter_choice` | `FLOW_STEP` | `ATTACK / ATTACK_COUNTER_CHOICE` | Counter owner marker that accepts or skips the optional Counter attack; identity payload binds the choice to the pending squadron attacker/target pair. |
| `spend_defense_token` | `FLOW_STEP` | `ATTACK / ATTACK_DEFENSE_TOKENS` | Defender token spend during the defense-token window. |
| `commit_defense` | `FLOW_STEP` | `ATTACK / ATTACK_DEFENSE_TOKENS` | Defender authority marker for selected defense tokens. |
| `select_evade_die` | `FLOW_STEP` | `ATTACK / ATTACK_DEFENSE_TOKENS` | Defender authority marker for Evade target selection. |
| `select_redirect_zone` | `FLOW_STEP` | `ATTACK / ATTACK_DEFENSE_TOKENS` | Redirect zone selection after a redirect token is committed. |
| `redirect_done` | `FLOW_STEP` | `ATTACK / ATTACK_DEFENSE_TOKENS` | Defender authority marker that closes redirect allocation early. |
| `resolve_damage` | `FLOW_STEP` | `ATTACK / ATTACK_RESOLVE_DAMAGE` | Atomic damage application belongs to the attack damage-resolution step. |
| `resolve_immediate_effect` | `PHASE` | `SHIP`, `SQUADRON` | Conservative M3 scope preserves attack immediate-flow callers plus debug-deal-damage follow-ups while matching the command's current phase validation; card-specific choice validation remains in the command. Later slices may narrow this after debug follow-ups have a dedicated flow surface. |
| `persistent_effect_damage` | `PHASE` | `SHIP` | Deterministic facedown damage for persistent effects, including RuleRegistry-migrated Crew Panic and remaining overlap/maneuver damage cards. |

M3 should encode the table conservatively to preserve current behaviour first.
Later rule slices may narrow a `PHASE` declaration to `FLOW_STEP` only after
the relevant UI choice or effect has a projected flow surface and regression
coverage.

## 1. Flow Inventory

| Flow | Steps |
|---|---|
| `NONE` | `NONE` |
| `COMMAND_PHASE` | `SELECT_DIALS`, `WAIT_FOR_OPPONENT_DIALS` |
| `SHIP_ACTIVATION` | `WAIT_FOR_SHIP_SELECT`, `ACTIVATION_MODAL_OPEN`, `REVEAL_DIAL`, `SPEND_DIAL`, `SQUADRON_STEP`, `REPAIR_STEP`, `ATTACK_STEP`, `MANEUVER_STEP`, `ACTIVATION_DONE` |
| `SQUADRON_ACTIVATION` | `WAIT_FOR_SQUAD_SELECT`, `ACTION_CHOICE`, `SQUAD_MOVE`, `SQUAD_ATTACK` |
| `ATTACK` | `ATTACK_DECLARE`, `ATTACK_ROLL`, `ATTACK_MODIFY`, `ATTACK_DEFENSE_TOKENS`, `ATTACK_RESOLVE_DAMAGE`, `ATTACK_COUNTER_CHOICE`, `ATTACK_CRITICAL_CHOICE` |
| `SQUADRON_DISPLACEMENT` | `DISPLACEMENT_PLACE` |
| `STATUS_CLEANUP` | `STATUS_CLEANUP_STEP` |
| `GAME_OVER` | `GAME_OVER_STEP` |

## 2. Global Empty Flow

### `NONE / NONE`

| Field | Value |
|---|---|
| controller_role | None |
| controller_player | `-1` |
| modal_kind | `NONE` |
| allowed_commands | Global/system commands only: `start_round`, replay/debug harness commands where their own validation permits. |
| transitions | Any command or phase entry that starts a concrete flow. |
| producer | `InteractionFlow.empty()`, `PublishAttackFlowCommand(final=true)`, `CommitDisplacementCommand.execute()`, default `GameState` construction. |
| rule citation | System state, not a rules-reference step. |

Notes: Empty flow means no gameplay modal owns input. `GameCommand.validate()`
remains authoritative until M4 adds command-scope gating.

## 3. Command Phase

Rules reference: RRG "Command Phase", p.3; command dials are chosen
simultaneously in network play and sequentially by seat in hot-seat.

### `COMMAND_PHASE / SELECT_DIALS`

| Field | Value |
|---|---|
| controller_role | Both players independently; hot-seat presents one assigning seat at a time. |
| controller_player | Current assigning player for hot-seat; not an exclusivity gate in network. |
| modal_kind | `COMMAND_DIALS` |
| allowed_commands | `assign_dials` |
| transitions | All required dials submitted -> `WAIT_FOR_OPPONENT_DIALS` or phase-complete event; complete command phase -> `SHIP_ACTIVATION / WAIT_FOR_SHIP_SELECT`. |
| producer | Command-phase presentation flow (`CommandPhaseController.begin_command_dial_flow()`); `StartRoundCommand` enters COMMAND phase but does not yet write this flow. |
| rule citation | RRG "Command Phase", p.3. |

Notes: UIProjector intentionally shows "make your choices" to both viewers
for `COMMAND_PHASE`, regardless of the numeric `controller_player`.

### `COMMAND_PHASE / WAIT_FOR_OPPONENT_DIALS`

| Field | Value |
|---|---|
| controller_role | None for the local player that has submitted; remote owner may still submit. |
| controller_player | The player still expected to submit, when known. |
| modal_kind | `COMMAND_DIALS` or waiting HUD depending on caller context. |
| allowed_commands | `assign_dials` from the not-yet-submitted player. |
| transitions | Both submitted -> phase-complete event -> `SHIP_ACTIVATION / WAIT_FOR_SHIP_SELECT`. |
| producer | Legacy-compatible step retained in `Constants.LEGACY_STEP_ID_MAP`; current command-phase completion is event-driven. |
| rule citation | RRG "Command Phase", p.3. |

Notes: M1 may encode this as a canonical step even though current runtime often
expresses the wait through command-phase gate state rather than an explicit
flow write.

## 4. Ship Activation

Rules reference: RRG "Ship Phase", reveal command dial and resolve activation
steps; command dial/token rules from RRG "Command Dials" and "Command Tokens".

### `SHIP_ACTIVATION / WAIT_FOR_SHIP_SELECT`

| Field | Value |
|---|---|
| controller_role | Active activation player |
| modal_kind | `NONE` |
| allowed_commands | `activate_ship`, `convert_dial_to_token` |
| transitions | Ship selected -> `ACTIVATION_MODAL_OPEN`; no eligible ships -> phase/turn transition outside this flow. |
| producer | `AdvancePhaseCommand` on entry to Ship Phase; `EndActivationCommand` after a ship completes activation. |
| rule citation | RRG "Ship Phase", ship activation; SP-010/SP-011. |

### `SHIP_ACTIVATION / ACTIVATION_MODAL_OPEN`

| Field | Value |
|---|---|
| controller_role | Active activation player |
| modal_kind | `ACTIVATION` |
| allowed_commands | `advance_activation_step`, `spend_dial`, `spend_token`, `convert_dial_to_token` |
| transitions | Squadron command -> `SQUADRON_STEP`; repair -> `REPAIR_STEP`; attack -> `ATTACK_STEP`; maneuver -> `MANEUVER_STEP`; end -> `ACTIVATION_DONE`. |
| producer | `ActivateShipCommand`, `ConvertDialToTokenCommand`. |
| rule citation | RRG "Ship Phase" and command resolution rules. |

Notes: `ModalRouter` opens/reopens the Activation modal only from projected
activation lifecycle commands.

### `SHIP_ACTIVATION / REVEAL_DIAL`

| Field | Value |
|---|---|
| controller_role | Active activation player |
| modal_kind | `ACTIVATION` |
| allowed_commands | `activate_ship`, `reveal_dial` where legacy paths still use it. |
| transitions | Dial revealed -> `ACTIVATION_MODAL_OPEN` or `SPEND_DIAL`. |
| producer | Legacy-compatible step; current `ActivateShipCommand` usually writes `ACTIVATION_MODAL_OPEN`. |
| rule citation | RRG "Ship Phase", reveal command dial. |

### `SHIP_ACTIVATION / SPEND_DIAL`

| Field | Value |
|---|---|
| controller_role | Active activation player |
| modal_kind | `ACTIVATION` |
| allowed_commands | `spend_dial`, `convert_dial_to_token` |
| transitions | Dial spent/resolved -> `ACTIVATION_MODAL_OPEN` or selected activation sub-step. |
| producer | Legacy-compatible step; current command spending is usually a side effect inside the active sub-step. |
| rule citation | RRG "Command Dials", p.3; "Command Tokens", p.4. |

### `SHIP_ACTIVATION / SQUADRON_STEP`

| Field | Value |
|---|---|
| controller_role | Active activation player |
| modal_kind | `SQUADRON` |
| allowed_commands | `advance_activation_step`, `spend_dial`, `spend_token`, `move_squadron`, `complete_squadron_activation`, `publish_attack_flow` when a commanded squadron attacks. |
| transitions | Squadron command complete or declined -> `REPAIR_STEP`. |
| producer | `AdvanceActivationStepCommand(step_id="squadron_step")`. |
| rule citation | RRG "Squadron" command; squadron command activation rules. |

Notes: The activation-sequence reopen button is projected as
`UIIntent.affordances["activation_sequence_button"]`, not as a second modal
lifecycle path.

### `SHIP_ACTIVATION / REPAIR_STEP`

| Field | Value |
|---|---|
| controller_role | Active activation player |
| modal_kind | `ACTIVATION` |
| allowed_commands | `repair_action`, `spend_dial`, `spend_token`, `advance_activation_step` |
| transitions | Repair complete or unavailable -> `ATTACK_STEP`. |
| producer | `AdvanceActivationStepCommand(step_id="repair_step")`. |
| rule citation | RRG "Engineering", p.4; repair costs in `Constants`. |

### `SHIP_ACTIVATION / ATTACK_STEP`

| Field | Value |
|---|---|
| controller_role | Active activation player |
| modal_kind | `ACTIVATION` until an `ATTACK` flow begins |
| allowed_commands | `publish_attack_flow`, `skip_attack`, `advance_activation_step` |
| transitions | Attack starts -> `ATTACK / ATTACK_DECLARE`; attack skipped or complete -> `MANEUVER_STEP`. |
| producer | `AdvanceActivationStepCommand(step_id="attack_step")`. |
| rule citation | RRG "Attack", p.2; Ship Phase attack step. |

### `SHIP_ACTIVATION / MANEUVER_STEP`

| Field | Value |
|---|---|
| controller_role | Active activation player |
| modal_kind | `ACTIVATION` |
| allowed_commands | `execute_maneuver`, `start_displacement`, `overlap_damage`, `advance_activation_step`, `end_activation` |
| transitions | Normal maneuver complete -> `ACTIVATION_DONE`; squadron overlap -> `SQUADRON_DISPLACEMENT / DISPLACEMENT_PLACE`; final end -> `WAIT_FOR_SHIP_SELECT`. |
| producer | `AdvanceActivationStepCommand(step_id="maneuver_step")`; `ExecuteManeuverCommand` republishes the maneuver step for replay/state parity. |
| rule citation | RRG "Ship Phase", execute maneuver; RRG "Overlapping", p.8. |

### `SHIP_ACTIVATION / ACTIVATION_DONE`

| Field | Value |
|---|---|
| controller_role | Active activation player |
| modal_kind | `ACTIVATION` |
| allowed_commands | `end_activation` |
| transitions | End activation -> `WAIT_FOR_SHIP_SELECT` for the next activation player, or phase transition when no ships remain. |
| producer | `AdvanceActivationStepCommand(step_id="activation_done")`. |
| rule citation | RRG "Ship Phase"; SP-001/SP-010. |

## 5. Squadron Phase

Rules reference: RRG "Squadron Phase", p.12; two squadrons per activation by
`Constants.SQUADRONS_PER_ACTIVATION`.

### `SQUADRON_ACTIVATION / WAIT_FOR_SQUAD_SELECT`

| Field | Value |
|---|---|
| controller_role | Active squadron-phase player |
| modal_kind | `NONE` |
| allowed_commands | `activate_squadron` |
| transitions | Squadron selected -> `ACTION_CHOICE`; no eligible squadrons -> active-player/phase transition. |
| producer | `AdvancePhaseCommand` on entry to Squadron Phase; squadron turn handoff logic. |
| rule citation | RRG "Squadron Phase", p.12; SQ-003. |

### `SQUADRON_ACTIVATION / ACTION_CHOICE`

| Field | Value |
|---|---|
| controller_role | Active squadron-phase player |
| modal_kind | `SQUADRON` |
| allowed_commands | `move_squadron`, `publish_attack_flow`, `complete_squadron_activation` for no-move completion synchronization. |
| transitions | Move chosen -> `SQUAD_MOVE`; attack chosen -> `SQUAD_ATTACK` or `ATTACK / ATTACK_DECLARE`; activation done -> `WAIT_FOR_SQUAD_SELECT` or turn handoff. |
| producer | `ActivateSquadronCommand`. |
| rule citation | RRG "Squadron Phase", p.12; squadron movement/attack rules. |

### `SQUADRON_ACTIVATION / SQUAD_MOVE`

| Field | Value |
|---|---|
| controller_role | Active squadron-phase player |
| modal_kind | `SQUADRON` |
| allowed_commands | `move_squadron` |
| transitions | Move complete -> `ACTION_CHOICE` or `SQUAD_ATTACK`; activation done -> turn handoff. |
| producer | Legacy-compatible step; current modal state often tracks movement locally while `move_squadron` records the durable state. |
| rule citation | RRG "Squadron Phase", movement rules. |

### `SQUADRON_ACTIVATION / SQUAD_ATTACK`

| Field | Value |
|---|---|
| controller_role | Active squadron-phase player |
| modal_kind | `SQUADRON` until `ATTACK` flow begins |
| allowed_commands | `publish_attack_flow`, `skip_attack` |
| transitions | Attack starts -> `ATTACK / ATTACK_DECLARE`; attack skipped/complete -> `ACTION_CHOICE` or turn handoff. |
| producer | Legacy-compatible step; current attack details are represented by the shared `ATTACK` flow. |
| rule citation | RRG "Squadron Attacks", p.19. |

## 6. Attack Flow

Rules reference: RRG "Attack", p.2; defense token rules from RRG "Defense
Tokens". Current producers are `AttackFlowFSM` plus
`PublishAttackFlowCommand`, which republishes the snapshot over the command
channel for network/replay parity.

### `ATTACK / ATTACK_DECLARE`

| Field | Value |
|---|---|
| controller_role | Attacker |
| modal_kind | `ATTACK_DECLARE` |
| allowed_commands | `publish_attack_flow`, `skip_attack` |
| transitions | Target/dice context locked -> `ATTACK_ROLL`; cancelled/no target -> `NONE`. |
| producer | `AttackFlowFSM.begin()` and `restart_for_next_attack()`. |
| rule citation | RRG "Attack", declare target, p.2. |

### `ATTACK / ATTACK_ROLL`

| Field | Value |
|---|---|
| controller_role | Attacker |
| modal_kind | `ATTACK_ROLL` |
| allowed_commands | `roll_dice`, `publish_attack_flow`, `skip_attack` |
| transitions | Dice rolled -> `ATTACK_MODIFY`; cancelled -> `NONE`. |
| producer | `AttackFlowFSM.advance(Step.ROLL)`. |
| rule citation | RRG "Attack", roll attack dice, p.2. |

### `ATTACK / ATTACK_MODIFY`

| Field | Value |
|---|---|
| controller_role | Attacker |
| modal_kind | `ATTACK_MODIFY` |
| allowed_commands | `spend_dial`, `spend_token`, `publish_attack_flow`, `skip_attack`, `skip_attack_modifier`, `confirm_attack_dice` |
| transitions | Defender can spend tokens -> `ATTACK_DEFENSE_TOKENS`; no defense window -> `ATTACK_RESOLVE_DAMAGE`. |
| producer | `AttackFlowFSM.advance(Step.MODIFY)` and `patch_payload()` after dice changes. |
| rule citation | RRG "Attack", modify dice, p.2; Concentrate Fire command; Swarm keyword. |

### `ATTACK / ATTACK_DEFENSE_TOKENS`

| Field | Value |
|---|---|
| controller_role | Defender, or attacker when there is no defender player |
| modal_kind | `ATTACK_DEFENSE_TOKENS` |
| allowed_commands | `spend_defense_token`, `commit_defense`, `select_evade_die`, `select_redirect_zone`, `redirect_done`, `publish_attack_flow` |
| transitions | Defense/redirect complete -> `ATTACK_RESOLVE_DAMAGE`; cancelled -> `NONE`. |
| producer | `AttackFlowFSM.advance(Step.DEFENSE_TOKENS)` and defense payload patches, including `blocked_defense_token_indices` for rule/effect-blocked choices. |
| rule citation | RRG "Defense Tokens", p.4; RRG "Attack", spend defense tokens. |

### `ATTACK / ATTACK_RESOLVE_DAMAGE`

| Field | Value |
|---|---|
| controller_role | Attacker |
| modal_kind | `ATTACK_RESOLVE_DAMAGE` |
| allowed_commands | `resolve_damage`, `resolve_immediate_effect`, `publish_attack_flow` |
| transitions | Counter available -> `ATTACK_COUNTER_CHOICE`; immediate damage-card choice required -> `ATTACK_CRITICAL_CHOICE`; otherwise flow clears to `NONE` or restarts at `ATTACK_DECLARE` for another attack. |
| producer | `AttackFlowFSM.advance(Step.RESOLVE_DAMAGE)`. |
| rule citation | RRG "Attack", resolve damage, p.2; damage-card immediate effects. |

### `ATTACK / ATTACK_COUNTER_CHOICE`

| Field | Value |
|---|---|
| controller_role | Counter squadron owner, encoded by `counter_controller_player` / `controller_player` payload. |
| modal_kind | `ATTACK_COUNTER_CHOICE` |
| allowed_commands | `counter_choice`, `publish_attack_flow` |
| transitions | `counter_choice(accepted=true)` starts a Counter attack at `ATTACK_DECLARE`/`ATTACK_ROLL` with the Counter squadron as attacker; `accepted=false` clears to `NONE` or resumes the parent activation/squadron flow. |
| producer | `AttackFlowFSM.advance(Step.COUNTER_CHOICE)` after damage resolution when `CounterKeyword.is_counter_trigger_available()` is true. |
| rule citation | RRG "Squadron Keywords", Counter. |

Notes: Counter is the canonical off-turn attack example. The original attack
executor owns the pipeline, but the choice and accepted Counter attack are
controlled by the defending squadron's owner. Presentation must project the
choice, roll, optional Swarm modifier, and dice confirm from
`interaction_flow.payload`; it must not show scene-local buttons on the
triggering attacker's panel without a command-backed flow surface.

### `ATTACK / ATTACK_CRITICAL_CHOICE`

| Field | Value |
|---|---|
| controller_role | Card-defined chooser, currently represented as defender/controller payload from attack flow |
| modal_kind | `ATTACK_CRITICAL_CHOICE` |
| allowed_commands | `resolve_immediate_effect`, `publish_attack_flow` |
| transitions | Choice resolved -> `NONE`, or next attack/activation step as directed by attack executor. |
| producer | `AttackFlowFSM.advance(Step.CRITICAL_CHOICE)`. |
| rule citation | Damage-card immediate effect text; RRG damage cards. |

## 7. Squadron Displacement

Rules reference: RRG "Overlapping", p.8. Controller is the player who did
not move the overlapping ship, regardless of displaced squadron ownership.

### `SQUADRON_DISPLACEMENT / DISPLACEMENT_PLACE`

| Field | Value |
|---|---|
| controller_role | Opposing player / non-moving player |
| modal_kind | `DISPLACEMENT` |
| allowed_commands | `commit_displacement`; presentation may preview positions locally before commit. |
| transitions | Placements committed -> `NONE`; activation resumes through the next activation-step command. |
| producer | `StartDisplacementCommand`. |
| rule citation | RRG "Overlapping", p.8; OV-001 to OV-004. |

Notes: This is the worked example for M0.5. The current producer still carries
`controller_player` in its payload; FlowSpec will make the controller role
explicit so producers do not re-derive it ad hoc.

## 8. Status And Game Over

### `STATUS_CLEANUP / STATUS_CLEANUP_STEP`

| Field | Value |
|---|---|
| controller_role | Server/system |
| controller_player | `-1` |
| modal_kind | `STATUS_CLEANUP` |
| allowed_commands | `status_phase_cleanup`, `start_round` after cleanup completes |
| transitions | Cleanup complete -> `COMMAND_PHASE / SELECT_DIALS` for the next round, or `GAME_OVER / GAME_OVER_STEP` at game end. |
| producer | Legacy-compatible/projected step; current status cleanup command mutates durable state and phase flow is handled by phase/round commands. |
| rule citation | RRG "Status Phase", p.6; ST-001/ST-004. |

### `GAME_OVER / GAME_OVER_STEP`

| Field | Value |
|---|---|
| controller_role | None |
| controller_player | `-1` |
| modal_kind | `GAME_OVER` |
| allowed_commands | None, except local menu/save/exit surfaces outside gameplay flow. |
| transitions | Terminal state. |
| producer | Game-end/victory presentation path; projected by `UIProjector` when stored in `interaction_flow`. |
| rule citation | RRG "End of Game" / six-round limit; `Constants.MAX_ROUNDS`. |

## 9. Current Gaps To Resolve In Later M Slices

- `COMMAND_PHASE / SELECT_DIALS`, `WAIT_FOR_OPPONENT_DIALS`,
  `STATUS_CLEANUP_STEP`, and `GAME_OVER_STEP` are documented here because they
  are constants/projectable states, but current runtime does not uniformly
  enter them through `GameCommand.execute()`. M3/M4 must classify the relevant
  commands as `PHASE` or `GLOBAL` where flow-step gating would be wrong.
- `SQUAD_MOVE` and `SQUAD_ATTACK` are legacy-compatible step ids. Current
  Squadron modal state often represents these locally while durable state uses
  `ACTION_CHOICE`, `move_squadron`, and the shared `ATTACK` flow.
- Attack target declaration and many attack payload patches are still driven by
  `AttackExecutor`/`AttackFlowFSM` plus `publish_attack_flow`, not individual
  player-action commands for every UI click. M3/M4 should avoid over-gating
  these internal snapshot commands.
- Rule hooks are intentionally not encoded here. M5+ adds `RuleRegistry`; M7+
  migrates representative rules while preserving the loaded-effect rebuild
  invariant.
