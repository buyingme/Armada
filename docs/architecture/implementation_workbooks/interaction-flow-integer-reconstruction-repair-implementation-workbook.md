# InteractionFlow Integer Reconstruction Repair Implementation Workbook

Status: **Draft — reconciled with completed production runtime proof; ready for
targeted re-audit and Project Owner review; not accepted and not implementation
authorization**

Purpose: specify the smallest production correction that restores established
integer-valued `InteractionFlow.payload` fields after JSON reconstruction,
without changing gameplay ownership, GGS behavior, replay fixtures, or the GGS
digest contract.

Primary evidence:

- [GGS-001 Gate 2 stop evidence](../evidence/GGS-001-b-lite-prototype-measurements.md#L362)
- [GGS-001 limited B-lite prototype workbook](GGS-001-limited-b-lite-prototype-implementation-workbook.md#L366)
- [`InteractionFlow` production codec](../../../src/core/state/interaction_flow.gd#L77)
- [`GameCommand` integer reconstruction precedent](../../../src/core/commands/game_command.gd#L23)

Related boundaries and work:

- `BC-008` / `AT-009` — Save/Load and Checkpoint Boundary;
- `BC-009` / `AT-008` — Replay, baseline, Network, and state-filtering review;
- `RG-003` and `RG-014` — `InteractionFlow` mutation and ownership gaps; and
- accepted [ADR-006](../adr/ADR-006-canonical-ship-activation-boundary-ownership.md#L298),
  which classifies Ship Activation `InteractionFlow` routing payloads as
  derived, non-authoritative state.

## 1. Classification, Authority, And Entry Disposition

Classification: **Bounded Architecture / bounded cross-cutting production
repair**.

The observed failure is an existing production reconstruction inconsistency.
`InteractionFlow.serialize()` deep-copies a payload containing native integer
values. Godot JSON parsing reconstructs JSON numbers as floats.
`InteractionFlow.deserialize()` restores the typed top-level fields but copies
most payloads without restoring their established integer fields. A live
Maneuver flow therefore retains `ship_index == 0` while the same flow after a
JSON round trip contains `ship_index == 0.0`.

The repository already resolves the material policy question:

1. `GameCommand` restores only explicitly declared integer fields, accepts an
   integral JSON float, and rejects nonfinite, fractional, or unsafe values.
2. `InteractionFlow` already applies field-specific restoration to Counter
   participant identities and Squadron Displacement identities.
3. Accepted ADR-006 does not make a routing payload a second gameplay owner.
   Restoring an established representation type changes no gameplay fact.
4. Accepted verification contracts compare canonical serialized state or its
   deterministic hash where hashes are used
   ([CON-001](../contracts/CON-001-current-attack-state-and-semantic-transition-contract.md#L730)).

No new normalization policy, gameplay owner, save format, replay format, or
digest definition is required. The repair may proceed after independent audit
and explicit Project Owner acceptance of this workbook. GGS-001 Gate 2 remains
stopped and is not authorized by acceptance or implementation of this repair.

### 1.1 Independent audit reconciliation

This revision closes the four audit findings without expanding the repair:

1. Sections 3.1 and 3.2 replace the family-level inventory with active
   flow/step schemas traced to production producers and consumers, including
   the omitted Attack fields, nested `ecm_choice`, and Setup
   `deployment_pick`.
2. Section 3.3 separates integer-only fields from accepted mixed-type
   `defender_zone` and dice members, preserving established strings.
3. Section 5.2 records Displacement's current native-int/JSON-float behavior as
   an explicit compatibility exception that a shared validator may not
   tighten.
4. Section 5.3 separates malformed whole-payload fallback from malformed
   declared-field failure for every covered active flow.

The accepted format versions, compatibility posture, GGS stop, and Owner stop
gates are unchanged.

### 1.2 Targeted re-audit reconciliation

The second audit identified two remaining inventory omissions. This revision:

1. models Attack payload reachability from the FSM's cumulative merge,
   transition, reconstruction, restart, and clearing behavior rather than only
   the fields first written at each step; and
2. adds the production declaration-skip `squadron_index` projection to
   `SQUADRON_ACTIVATION/WAIT_FOR_SQUAD_SELECT` and requires exact flow evidence
   plus full-state digest evidence when the non-flow state is proven stable.

These are evidence corrections inside the existing normalization scope. They
do not change any compatibility rule, malformed-input disposition, stop gate,
format, or authorization status.

### 1.3 Final audit reconciliation

The final audit found one legacy unit-test expectation that contradicts the
cumulative Attack schema. The workbook now explicitly requires replacing that
expectation: the four Counter participant identity fields are normalized to
`TYPE_INT` wherever they are present at any reachable Attack step, including
`ATTACK_DECLARE`. Their presence remains optional at ordinary Attack steps;
all four are mandatory only at `ATTACK_COUNTER_CHOICE`.

The bounded test-impact sweep in Section 7.5 found no additional contract
contradiction. This correction changes no field inventory, range,
malformed-input behavior, architecture, or authorization boundary.

### 1.4 Production runtime-proof reconciliation

The completed runtime proof separates three reconstruction boundaries that
must not be treated as one defect or one authorization package:

| Boundary | Proven path | Disposition in this workbook |
|---|---|---|
| **A — InteractionFlow state reconstruction** | `GameState` JSON -> `GameState.deserialize()` -> `InteractionFlow.deserialize()` | This workbook's only production repair boundary. Restore the declared integer representation of production-backed `InteractionFlow.payload` fields. |
| **B — Attack publication command reconstruction** | Replay-12 JSON -> `GameCommand.deserialize()` -> `PublishAttackFlowCommand` | Independently proven command-codec mismatch. It is excluded from this implementation workbook and specified in the separate [Attack publication command-codec repair proposal](attack-publication-command-codec-integer-reconstruction-repair-proposal.md). |
| **C — Current attack outcome reconstruction** | `GameState` JSON -> `CurrentAttackState.deserialize()` -> `resolved_outcome` | Independently observed unresolved reconstruction mismatch. It is a bounded investigation follow-up, not an assumed requirement of either repair. |

The runtime proof also distinguishes exact flow reconstruction from whole-state
hash convergence. Boundary A must reproduce the exact serialized
`InteractionFlow`. A whole-state hash is evidence for A only when the test has
also established that every other serialized state surface is stable. A
difference outside `interaction_flow` fails closed and is reported at its own
boundary; it is not repaired, normalized, ignored, or used to enlarge this
workbook.

## 2. Current Production Path And Defect Boundary

The shared reconstruction path is:

```text
InteractionFlow.serialize()
-> GameState.serialize()
-> optional JSON stringify/parse
-> GameState.deserialize() or deserialize_passive_network()
-> InteractionFlow.deserialize()
```

The last step casts `flow_type`, `step_id`, `controller_player`, and
`visible_to`, but normally deep-copies `payload`. The current exceptions are:

- `ATTACK / ATTACK_COUNTER_CHOICE`: all four Counter player/squadron identities
  are required, validated, and restored to integers; and
- `SQUADRON_DISPLACEMENT`: `owner_player`, `ship_index`, and each displaced
  squadron's `owner` and `squadron_index` are validated and restored.

The known Gate 2 path uses
`SHIP_ACTIVATION / MANEUVER_STEP.payload.ship_index`, which is not covered by
either exception. The first replay command remains legal because its command
payload is independently canonicalized and Ship Activation presentation reads
the flow value through `int()`. The final serialized state retains `0.0`, so
`CanonicalJson.hash()` differs from the uninterrupted state's hash.

That observation establishes Boundary A only. The completed runtime proof also
found Boundary B in JSON-reconstructed `publish_attack_flow` commands and
Boundary C in `CurrentAttackState.resolved_outcome`. Neither is routed through
`InteractionFlow.deserialize()`, so neither can be an exit criterion or an
implementation requirement for this repair.

## 3. Production Payload Shape Inventory

This inventory is derived from the production command producers, flow
resolvers, rule projectors, `FlowSpec`, and their consumers. “Integer field”
means that an existing producer emits, or an existing consumer interprets, the
value as an integer identity, index, count, enum, or discrete result. The
inventory does not move ownership into `InteractionFlow`.

### 3.1 Non-Attack flows by active step

| Flow and active step | Production producer and consumer | Declared integer members when present | Disposition |
|---|---|---|---|
| `NONE/NONE`, `COMMAND_PHASE/SELECT_DIALS`, `COMMAND_PHASE/WAIT_FOR_OPPONENT_DIALS`, `SHIP_ACTIVATION/WAIT_FOR_SHIP_SELECT`, `GAME_OVER/GAME_OVER_STEP` | Phase commands and UI projection | `active_player` only where a transition projection carries it | Normalize the optional scalar; an ordinary empty payload remains valid. |
| `SQUADRON_ACTIVATION/WAIT_FOR_SQUAD_SELECT` | Phase entry/completion and `SkipAttackCommand` declaration-skip return | `active_player` and optional `squadron_index` | Normalize fields that are present. Phase entry and ordinary completion may publish an empty payload; a completed Squadron Phase declaration skip publishes the declined Squadron's route identity. |
| `SHIP_ACTIVATION/ACTIVATION_MODAL_OPEN`, `REVEAL_DIAL`, `SPEND_DIAL`, `REPAIR_STEP`, `ATTACK_STEP`, `MANEUVER_STEP`, `ACTIVATION_DONE` | Ship activation commands, maneuver resolver, repair resolver, modal routing | `ship_index` | Normalize the optional route identity. `MANEUVER_STEP.ship_index` is the observed Gate 2 mismatch. |
| `SHIP_ACTIVATION/SQUADRON_STEP` | Squadron command activation and completion commands | `ship_index`, `squadron_index` | Normalize both optional route identities. String activation identities remain strings. |
| `SQUADRON_ACTIVATION/ACTION_CHOICE`, `SQUAD_MOVE`, `SQUAD_ATTACK` | Squadron activation, movement, completion, and attack continuation | `squadron_index`; `ship_index` only where a commanded-activation continuation projects it | Normalize only the fields present. String activation and inspection identities remain strings. |
| `SHIP_ACTIVATION/TARKIN_COMMAND_CHOICE` | `GrandMoffTarkin` projection and `TarkinChoiceCommand` | `owner_player`, `source_ship_index`, every `available_commands` entry | Normalize both scalars and the integer array. |
| `SQUADRON_DISPLACEMENT/DISPLACEMENT_PLACE` | displacement candidate/start commands and displacement UI | `owner_player`, `ship_index`, `displaced_squadrons[*].owner`, `displaced_squadrons[*].squadron_index` | Preserve the existing special reconstruction contract in Section 5.2 exactly. |
| `SETUP/SETUP_OBSTACLE_PLACEMENT` | `SetupInteractionFlowResolver` and setup placement command/UI | `first_player`, payload `controller_player`, `obstacle_count` | Normalize the three optional scalars. |
| `SETUP/SETUP_SHIP_DEPLOYMENT`, `SETUP_SQUADRON_DEPLOYMENT` | `SetupDeploymentValidator` -> `SetupInteractionFlowResolver`; setup placement command/UI | `first_player`, payload `controller_player`, `deployment_pick.owner_player`, `deployment_pick.required_count` | Normalize direct fields and the two nested fields. `deployment_pick` is either `{}` or the established `{owner_player, component_type: "squadron", roster_entry_ids: Array[String], required_count}` shape. Preserve strings and string arrays unchanged. |
| `SETUP/SETUP_REVIEW` | `SetupInteractionFlowResolver` and review UI | `first_player` | Normalize the optional scalar. |
| `STATUS_CLEANUP/STATUS_CLEANUP_STEP` | status cleanup command and ECM/status rule projectors | `ecm_ready_cost_choices[*].owner_player`, `ecm_ready_cost_choices[*].ship_index`, `optional_status_rules[*].owner_player`, `optional_status_rules[*].ship_index` | Normalize declared members in each descriptor; preserve rule ids, runtime ids, prompts, and command strings. |

Steps not listed for a flow have no production-created integer payload shape
in the reviewed code. A future producer must extend this table and the private
schema explicitly; suffix-based or recursive discovery is prohibited.

### 3.2 Attack reachability and integer schema

Attack payloads are cumulative rather than step-local:

1. `BeginAttackCommand` installs `ATTACK_DECLARE` with `attack_id`.
2. `_publish_attack_declare_patch()` merges identity fields,
   `ship_target_attacks_this_round`, and `dice_pool` into that same payload.
3. `AttackFlowFSM.patch_payload()` replaces only the named top-level keys;
   `advance()` republishes the whole accumulated dictionary without clearing
   fields from the prior step.
4. current-attack reconstruction maps canonical pre-roll state to
   `ATTACK_ROLL` and may add `pending_die_removal.controller_player` there.
5. defense, redirect, resolved-damage, Counter, and critical-choice patches all
   retain the earlier declaration, roll, and modify fields.
6. `restart_for_next_attack()` intentionally preserves the FSM payload. The
   existing `build_clear_target_patch()` and `_publish_clear_target_patch()`
   can overwrite a subset of target/dice/defense fields, but the reviewed
   production tree has no caller of `_publish_clear_target_patch()`. A later
   declaration overwrites its current identity and pool fields while other
   earlier integer fields can remain reachable.

Consequently, deserialization must apply the complete production-backed Attack
integer union at **every reachable Attack step**. A field's first producer does
not limit the steps at which it can appear. This is a normalization schema,
not approval of stale presentation data or a change to clearing behavior.

The direct integer-capable union produced into, or retained in, the production
Attack `InteractionFlow` is:

```text
attacker_player             attacker_ship_index
attacker_squadron_index
attacker_zone               controller_player
defender_index              defender_player
defender_ship_index         defender_speed
defender_squadron_index     defender_zone
ship_target_attacks_this_round
accuracy_count             spendable_accuracy_count
chooser_player             final_damage
modified_damage            redirect_remaining
pending_card_index         pending_ship_index
pending_ship_owner_player
swarm_controller_player
counter_controller_player  counter_attacker_player
counter_attacker_squadron_index
counter_target_player      counter_target_squadron_index
target_ship_index           target_squadron_index
```

The structured integer-capable union is:

- every value in `dice_pool` and `counter_dice_pool`;
- every entry in `locked_tokens`, `blocked_defense_token_indices`,
  `ecm_authorized_indices`, `redirect_adjacent_zones`,
  `spent_defense_token_types`, and `swarm_die_indices`;
- `dice_results[*].color` and `dice_results[*].face` under the mixed-type rule
  in Section 3.3;
- `defense_tokens[*].type` and `defense_tokens[*].state`;
- `pending_die_removal.controller_player`;
- `ecm_choice.defender_player`, `ecm_choice.defender_ship_index`, and every
  `ecm_choice.eligible_token_indices` entry; and
- `choice_info.max_selections` when the critical-choice projection carries a
  nonempty production choice descriptor.

All union members are optional when absent from an ordinary Attack projection.
The four Counter participant identity fields are normalized wherever present,
including at `ATTACK_DECLARE`; only `ATTACK_COUNTER_CHOICE` retains the
existing requirement that all four be present. Attack panel reconstruction,
controller resolution, ECM/Swarm affordance projection, and Counter validation
consume the accumulated payload; none provides a step transition that removes
earlier numeric fields.

The step table records first production and the reachable retained shape:

| Attack step | First production or mutation at this step | Reachable integer schema after transition/retention |
|---|---|
| `ATTACK_DECLARE` | Identity/zone fields, `ship_target_attacks_this_round`, and `dice_pool`. A restarted declaration can also retain integer members introduced by the preceding attack because restart preserves the payload and the clear-target wrapper is not called. | Full Attack union. |
| `ATTACK_ROLL` | The DECLARE payload is retained. Reconstructed pre-roll rule choice can add `pending_die_removal.controller_player`; live gather publications may already have merged the same descriptor before the roll transition. | Full Attack union. |
| `ATTACK_MODIFY` | Adds or updates `dice_results`, `accuracy_count`, `spendable_accuracy_count`, Swarm controller/die indices, and other modifier capability fields. Declaration, pool, and pending-choice fields remain reachable. | Full Attack union. |
| `ATTACK_DEFENSE_TOKENS` | Adds or updates `modified_damage`, token indices/state, ECM indices and nested `ecm_choice`, redirect zones/budget, and post-Evade dice. All declaration/roll/modify fields are retained. | Full Attack union. `ecm_choice` remains `{}` or the established projector shape. |
| `ATTACK_RESOLVE_DAMAGE` | Adds `final_damage` when publication is permitted; all prior fields remain reachable whether the transition comes through defense or directly from modify. | Full Attack union. |
| `ATTACK_CRITICAL_CHOICE` | Adds `chooser_player`, `pending_card_index`, `pending_ship_index`, and `pending_ship_owner_player`; all resolved and earlier fields remain reachable. | Full Attack union. |
| `ATTACK_COUNTER_CHOICE` | Adds required `counter_attacker_player`, `counter_attacker_squadron_index`, `counter_target_player`, `counter_target_squadron_index`, optional `counter_controller_player`, and `counter_dice_pool`; all parent-attack fields remain reachable. | Full Attack union, with the existing four-field Counter requirement still authoritative. |

Bare `attacker_index`, `die_index`, `round`, `ship_index`, `token_index`,
`token_type`, `zone`, `target_index`, and `target_owner` are excluded. The
reviewed Attack flow writers do not place those keys in
`InteractionFlow.payload`; similarly named values in command payloads,
canonical attack state, rule state, targeting candidates, or local scene plans
do not establish an InteractionFlow schema. Adding any such bare field later
requires a demonstrated production flow writer and a workbook update.

`pending_ecm_authorization` and its runtime `attack_scope` are upgrade rule
state and are removed before the public flow projection. They are not current
serialized `InteractionFlow.payload` shapes and are excluded from this repair.

### 3.3 Accepted mixed-type and excluded fields

The following fields have an established mixed representation and use
**numeric-only normalization**:

- `defender_zone`: `TYPE_INT` and integral `TYPE_FLOAT` are the numeric
  variants; accepted `TYPE_STRING` values, including the evidenced legacy
  `"front"`, remain byte-for-byte strings. The existing command codec does not
  constrain the string vocabulary, so this repair must preserve every string
  without mapping names to enum values or changing case.
- `dice_results[*].color` and `dice_results[*].face`: `TYPE_INT` and integral
  `TYPE_FLOAT` are the numeric variants; every existing `TYPE_STRING` label,
  including the evidenced `"hit"` face, remains byte-for-byte unchanged.
- `defense_tokens[*].type` and `defense_tokens[*].state`: current production
  emits integers, while the existing command precedent treats nested members
  as numeric. The flow repair accepts only valid numeric variants here; it does
  not introduce new string spellings.

A nonnumeric value in an integer-only field is malformed. A string in one of
the two accepted string-capable shapes above is preserved and is not treated as
malformed merely because it is not numeric. Other container types remain
malformed.

Fields holding coordinates, rotations, continuous range/timing values, or
other legitimate floats are excluded. String identifiers, prompts, rule ids,
roster keys, `deployment_pick.component_type`, and
`deployment_pick.roster_entry_ids` are preserved. Unknown keys remain
unchanged.

The typed top-level `flow_type`, `step_id`, `controller_player`, and
`visible_to` members are outside this repair. Tightening their accepted input
types would be a separate compatibility change.

## 4. Production Risk By Boundary

| Boundary | Reachability and risk | Required proof |
|---|---|---|
| Save/Load | Save files cross actual JSON. The safe-point gate currently excludes Setup and a ship mid-activation, and permits only selection/status/game-over steps. That limits the known Maneuver defect's current named-save reachability. Safe-point payloads and future compatible boundaries still use the shared codec. A valid save signature does not restore types because signing intentionally normalizes JSON numbers. | Current-version signed save/load at each allowed nonempty payload shape; unchanged failure classification for malformed state. |
| Checkpoint | Persisted checkpoint payloads use the same state representation and load deserializer. Their capture policy reduces active-decision exposure but does not create a separate codec. | Existing checkpoint load and reconstruction checks; no new checkpoint representation. |
| Network/reconnect | State filtering calls `GameState.deserialize()` on an in-memory dictionary. RPC snapshot transport retains Godot Variant integer types and does not itself JSON-round-trip the payload. Thus ordinary uninterrupted reconnect is not known to create this type change. A host state originating from JSON and any future JSON transport still reaches the same codec. Strict consumers on passive peers can fail to reopen a modal if malformed or float-valued payloads arrive. | Full-authority filter round trip plus passive snapshot reconstruction for Ship Activation, Attack, Displacement, Setup, and Status representative shapes; host/client canonical equality where the representation is viewer-visible. |
| Full-history replay | Production replay rebuilds from scenario/seed and ordered commands, not arbitrary serialized `GameState` S0. Replay-12 separately proves that the `publish_attack_flow` branch of the command codec does not restore every integer field carried by recorded Attack publications. That is Boundary B, not an `InteractionFlow.deserialize()` responsibility. | For this repair, prove no command-format or fixture change. Route command-payload type differences to the separate command-codec proposal instead of changing this workbook. |
| Decision recovery | Many consumers call `int()` and preserve semantic behavior despite type drift. Type-sensitive consumers exist: Counter recovery and modal routing require `TYPE_INT`; attack publication requires integer attacker identity; displacement modal routing requires integer owner/ship identities. Counter and Displacement are protected today, but equivalent direct Attack fields are not. | JSON-rebuilt state must reopen the same actionable decision, accept the same ordinary command, and serialize the same declared integer types. |
| Canonical digest | `CanonicalJson` intentionally distinguishes `0` from `0.0`. Boundary A can make the reconstructed flow match its live source while Boundary C still leaves the enclosing state unequal. | Require exact pre/post `interaction_flow.serialize()` equality and hash equality. Compare the complete state hash only in cases where all non-flow state is independently shown stable; otherwise report the first unrelated divergence and stop that aggregate assertion. |

## 5. Selected Repair Specification

Implement Boundary A only in `InteractionFlow.deserialize()` and private
helpers/constants owned by `InteractionFlow`, unless focused implementation
evidence requires a mechanical caller adjustment.

### 5.1 Flow/step-specific schema

Define private schema tables keyed by `flow_type` and, where shapes differ,
`step_id`. Each schema may declare:

- direct integer fields;
- integer arrays;
- integer dictionaries;
- nested dictionary fields; and
- arrays of dictionaries with declared integer members.

Apply the schema after deep-copying the payload and before returning the flow.
Only declared fields are touched. Do not recursively convert arbitrary JSON
numbers and do not infer integer semantics from a field-name suffix.

The existing Counter and Displacement behavior must be expressed through, or
remain compatible with, the same private validation primitives. Their stricter
required-field and range rules remain unchanged.

Do not import `GameCommand`, move this policy into `GameState`, add a generic
serialization registry, or create a new runtime service. The command schema is
evidence and a pattern, not an owner for flow reconstruction.

### 5.2 Integer conversion contract

For every declared integer-only field that is present, except the preserved
Displacement special case below:

1. accept `TYPE_INT` when it satisfies that field's range;
2. accept `TYPE_FLOAT` only when finite, exactly integral, within the field's
   range, and no greater than the repository's exact JSON integer ceiling;
3. replace an accepted float with the corresponding native integer;
4. reject the entire `InteractionFlow` for a boolean, string, null, container,
   fractional float, nonfinite float, or out-of-range value; and
5. never round, clamp, default, erase, or reinterpret an invalid present value.

Use the narrowest already-established range category:

| Category | Allowed range |
|---|---|
| Required player identity | `0 .. Constants.PLAYER_COUNT - 1` |
| Optional player/controller sentinel | `-1 .. Constants.PLAYER_COUNT - 1` |
| Required entity/index identity | `0 .. 2147483647` |
| Optional entity/index sentinel | `-1 .. 2147483647` |
| Count, ordinal, damage, speed, token, die, zone, or enum projection | The producer/consumer's existing range when explicit; otherwise `-1 .. 2147483647` for a documented sentinel field or `0 .. 2147483647` |
| JSON-safe general integer used inside an existing integer dictionary | `-9007199254740991 .. 9007199254740991` |

Implementation must not invent a narrower semantic range when current
production accepts a broader value. Discovery of two plausible ranges with
different accepted behavior triggers the stop gate in Section 10.

Mixed-type fields in Section 3.3 use the same numeric checks only when the
value is numeric. An accepted string is copied unchanged; it is not parsed,
case-folded, or checked against a newly invented vocabulary.

#### Preserved Displacement compatibility

`SQUADRON_DISPLACEMENT/DISPLACEMENT_PLACE` keeps its current production
behavior exactly:

- a native `TYPE_INT` in `owner_player`, `ship_index`, or a displaced entry's
  `owner`/`squadron_index` is accepted by the codec without a new numeric range
  check;
- a JSON-reconstructed `TYPE_FLOAT` is accepted only when finite, integral,
  and within `-2147483647 .. 2147483647`, then restored to `TYPE_INT`;
- other types and out-of-range numeric floats reject reconstruction; and
- existing command/installation validation remains responsible for whether a
  representable identity names the correct player, ship, or Squadron.

This intentional native-int/JSON-float asymmetry is existing compatibility,
not the model for new schemas. A shared helper may be used only behind a
Displacement-specific wrapper that proves this exact behavior. Reusing a new
player/index range validator directly for Displacement, or rejecting a native
integer that the current codec accepts, is prohibited.

### 5.3 Presence, containers, and malformed-input disposition

Whole-payload container handling is a separate compatibility rule from a
malformed declared field inside a dictionary:

| Flow / step | `payload` is not a Dictionary | Dictionary payload contains malformed declared field/container | Required-shape exception |
|---|---|---|---|
| `ATTACK/ATTACK_COUNTER_CHOICE` | Return `null`. | Return `null`. | All four Counter participant identities remain required. |
| `SQUADRON_DISPLACEMENT/DISPLACEMENT_PLACE` | Return a non-null flow with `payload == {}`. | Apply the existing special behavior: an empty dictionary is valid; a nonempty dictionary requires both direct identities, an Array `displaced_squadrons`, Dictionary entries, and both entry identities. A failure returns `null`. | Existing behavior is preserved verbatim. |
| Other active Ship, Squadron, Attack, Setup, Status, Command, NONE, and Game Over steps | Return a non-null flow with `payload == {}`. | If a declared field is present and malformed, return `null`. | Ordinary declared fields remain optional; absence is preserved. |

The whole-payload `{}` fallback is required by the existing
`test_deserialize_handles_non_dictionary_payload` compatibility test. The
repair must not reinterpret a non-Dictionary payload as a field-level schema
failure for ordinary flows.

For dictionary payloads:

- absent optional fields remain absent;
- an empty optional `ecm_choice` or `deployment_pick` dictionary remains
  valid;
- an empty optional `choice_info` dictionary remains valid; a nonempty
  `choice_info` normalizes `max_selections` when present and preserves the
  remaining choice descriptor unchanged;
- if any of those nested fields is present and nonempty, normalize the declared
  integer members that are present; the repair does not add exact-key or
  required-string validation to these producer-owned projections;
- a present `ecm_choice`, `deployment_pick`, or `choice_info` value with the
  wrong container type returns `null`;
- a malformed declared numeric member inside any of those nested dictionaries
  returns `null`;
- a present declared array/dictionary with the wrong container type, or a
  non-Dictionary entry in a declared structured array, returns `null`;
- unknown keys and accepted string variants are preserved unchanged; and
- no schema requires an exact whole-payload key set, because rule projections
  are extensible and carry optional capability data.

## 6. Required Negative Cases

For each new integer-only scalar, array, dictionary, and nested-entry helper,
prove rejection of:

1. fractional values such as `0.5` and `-1.5`;
2. `INF`, `-INF`, and `NAN` at direct and nested positions;
3. values beyond the declared range, including invalid player `2`, required
   identity `-1`, index `2147483648`, and exact-JSON integer overflow;
4. booleans, numeric strings, nulls, arrays, or dictionaries in scalar fields;
5. a non-array integer-array field and a non-dictionary integer-dictionary
   field;
6. a non-dictionary entry inside a declared structured array;
7. a mismatched integral value that has the correct type but identifies the
   wrong ship, Squadron, player, attack, or source, through the existing
   consumer/installation validation rather than the numeric codec; and
8. partial required Counter and nonempty Displacement identity shapes.

Also prove the compatibility exceptions rather than treating them as generic
negative cases:

- preserve accepted string `defender_zone` and string dice color/face values
  exactly, while rejecting fractional, nonfinite, or out-of-range numeric
  variants in the same positions;
- reject wrong `ecm_choice`, `deployment_pick`, and `choice_info` containers
  and malformed declared numeric members, while preserving `{}`, missing
  optional integer members, and their noninteger strings/string arrays;
- preserve a non-Dictionary whole payload as `{}` for every flow other than
  Counter choice, including Displacement, and keep Counter choice fail-closed;
- for Displacement, reject fractional/nonfinite/out-of-32-bit-range floats and
  wrong types, but demonstrate that native integers outside that float range
  retain the codec's current acceptance before existing semantic consumers
  decide whether they are actionable; and
- preserve unknown fields, including unknown numeric fields, without
  normalization.

The numeric codec establishes representation validity. It must not silently
turn a representable but stale identity into a valid gameplay decision.

## 7. Focused Regression Plan

### 7.1 Unit codec coverage

Extend `tests/unit/test_interaction_flow.gd` with actual
`JSON.stringify()` -> `JSON.parse_string()` ->
`InteractionFlow.deserialize()` coverage for:

- every non-Attack flow/step row in Section 3.1, including the Gate 2
  Ship Activation/Maneuver `ship_index`, commanded and Squadron Phase route
  identities, and Tarkin scalars/array;
- every Attack step in Section 3.2 with a representative reachable cumulative
  payload, rather than an artificial step-local payload;
- `ATTACK_DECLARE.dice_pool`, `ATTACK_ROLL` with retained declaration fields
  and `pending_die_removal.controller_player`, and each later step with fields
  retained from every reachable predecessor;
- replace
  `test_counter_identity_normalization_is_not_a_generic_adapter`'s legacy
  `ATTACK_DECLARE` float expectation with assertions that every present Counter
  participant identity is restored to `TYPE_INT`; rename the test to describe
  normalization wherever present and assert separately that a partial set is
  accepted at `ATTACK_DECLARE` because the four-field presence requirement is
  exclusive to `ATTACK_COUNTER_CHOICE`;
- a restarted `ATTACK_DECLARE` shape that preserves prior integer-capable
  fields not overwritten by the next declaration, proving the schema matches
  current restart/clearing behavior without changing that behavior;
- the previously omitted `ship_target_attacks_this_round`,
  `spendable_accuracy_count`, Counter/Swarm fields,
  `pending_die_removal.controller_player`, and the complete declared numeric
  surface of nested `ecm_choice`, plus production-backed
  `choice_info.max_selections`;
- accepted mixed numeric/string `defender_zone` and dice variants, asserting
  numeric `TYPE_INT` restoration and exact string preservation;
- Setup obstacle/controller fields and both deployment steps with `{}` and a
  populated `deployment_pick`, including `owner_player` and `required_count`;
- `SQUADRON_ACTIVATION/WAIT_FOR_SQUAD_SELECT` with optional
  `squadron_index` from the production declaration-skip transition;
- Status ready-cost owner/ship fields in both projected descriptor arrays;
- Counter's required participant identities and whole-payload failure; and
- Displacement direct/nested identities plus its preserved asymmetric range
  behavior.

For every positive case, assert `TYPE_INT`, exact value, preservation of
unrelated keys, and stable reserialization. Apply the negative matrix in
Section 6 without duplicating every negative value for every field. Add an
explicit table-driven disposition test for every row in Section 5.3, including
the existing non-Dictionary-to-`{}` behavior.

### 7.2 Aggregate reconstruction coverage

Add focused integration cases proving:

1. `GameState.serialize()` -> JSON round trip -> `GameState.deserialize()`
   restores representative Ship/Maneuver, Setup deployment-pick, Status,
   Attack, Counter, and Displacement flows with exact
   `interaction_flow.serialize()` equality and equal InteractionFlow hashes;
2. `StateFilter.filter_for_player_checked()` accepts the authority state,
   preserves declared integers for the authorized viewer, and still strips a
   hidden payload for an unauthorized viewer;
3. `GameState.deserialize_passive_network()` preserves the same declared
   integer types for a filtered representative snapshot;
4. a JSON-rebuilt Maneuver obstacle-order boundary yields the same evaluator
   decision and accepts the same normal first command as the live state, without
   any GGS schema, runner, Candidate, or fixture;
5. representative Attack (including ECM), Setup partial-pick, Status, Counter,
   and Displacement decisions remain actionable through their existing
   consumers after reconstruction;
6. a mismatched but type-correct identity remains rejected by the existing
   consumer/installation rule, proving that reconstruction did not change
   command semantics;
7. representative production-reachable Attack flows at DECLARE, ROLL,
   MODIFY, DEFENSE_TOKENS, RESOLVE_DAMAGE, COUNTER_CHOICE, and CRITICAL_CHOICE
   survive a real JSON round trip with exact flow equality, including retained
   predecessor fields, `choice_info.max_selections`, and a restarted DECLARE
   payload; compare the complete full-state canonical hash only after the test
   proves every non-flow serialized surface stable; and
8. an actual Squadron Phase declaration skip that completes the activation
   produces `SQUADRON_ACTIVATION/WAIT_FOR_SQUAD_SELECT` with optional
   `squadron_index`; after JSON reconstruction the field is `TYPE_INT`, the
   route remains consumable, and the complete state hash equals the live
   post-command state hash after non-flow stability is established.

For mixed-type fields, compare the exact pre/post InteractionFlow form
separately for an integer production shape and a legacy accepted string shape.
Full-state hash comparison is conditional on proven non-flow stability. For
malformed inputs, assert the Section 5.3 disposition rather than inventing a
canonical hash for rejected state.

If `CurrentAttackState.resolved_outcome`, a reconstructed command, or any other
non-flow surface differs, the test must identify the first exact divergence,
fail closed for full-state convergence, and route it to its owning follow-up.
It may still report the Boundary A flow result separately; it may not weaken or
rewrite the canonical digest comparison.

The Maneuver case is production codec evidence only. It must not recreate the
removed GGS prototype or assert that GGS Gate 2 may resume.

### 7.3 Existing verification gates

Run, at minimum:

- the complete `InteractionFlow`, game-flow command, Setup, Attack recovery,
  Counter recovery, displacement, state-filter, save/load, replay-driver, and
  canonical-JSON focused suites;
- the full repository test suite;
- Hot-Seat and Network baseline verification through the existing scripts;
- Network resume/reconnect acceptance; and
- documentation consistency checks and `git diff --check`.

Replay verification in this package is a non-regression gate for Boundary A;
it does not claim to repair the proven Replay-12 command-codec mismatch. No
replay fixture, expected hash, baseline trace, or state-hash file may be
changed during implementation. A baseline difference must be reported with
the first exact field divergence and routed through the stop gate.

### 7.4 Audit-finding verification obligations

| Reconciled finding | Required targeted proof |
|---|---|
| Complete flow/step inventory | A table-driven producer-shape test covers every Section 3.1 row and every Section 3.2 Attack step through a real JSON round trip. Attack cases use production-reachable accumulated payloads and cover DECLARE `dice_pool`, ROLL `pending_die_removal.controller_player`, retained predecessor fields, restart retention, `ecm_choice`, `choice_info.max_selections`, and the required Counter identities. Both Setup deployment steps cover `deployment_pick`. Every case compares exact pre/post InteractionFlow form; representative full states compare hashes only after non-flow stability is proven. |
| Accepted mixed types | Numeric `defender_zone` and dice color/face variants restore to `TYPE_INT`; evidenced string values and an additional arbitrary existing string value remain byte-for-byte unchanged. Fractional, nonfinite, unsafe, boolean, null, and container variants follow the field-level failure rule. Valid string cases compare exact pre/post flow form; full-state hashes remain conditional on non-flow stability. |
| Displacement compatibility | Lock the current matrix: native integer accepted without a new range constraint; finite integral JSON float accepted only through the existing signed 32-bit bound; fractional, nonfinite, outside-bound float, string, boolean, and missing required members reject. Existing displacement decision recovery and canonical hash convergence pass for production-valid values. |
| Whole payload versus field failure | For Counter, Displacement, and one representative from every other covered flow family, test non-Dictionary whole payload, `{}`, absent optional field, malformed present scalar, wrong nested container, and malformed nested member. Assert exactly the Section 5.3 return value and payload, including ordinary whole-payload fallback to `{}`. |
| Squadron declaration-skip return | Drive the production Squadron Phase declaration-skip command through activation completion to `WAIT_FOR_SQUAD_SELECT`, assert the optional `squadron_index` route identity, JSON-roundtrip it through `GameState.deserialize()`, compare the exact reconstructed flow, and compare the entire state hash only after confirming all non-flow state is stable. |

### 7.5 Existing test-impact consistency sweep

The pre-implementation sweep identifies the following required test action:

| Existing test | Current expectation | Required implementation-stage update |
|---|---|---|
| `tests/unit/test_interaction_flow.gd::test_counter_identity_normalization_is_not_a_generic_adapter` | After changing the fixture step to `ATTACK_DECLARE` and JSON-roundtripping it, all four Counter participant identities remain `TYPE_FLOAT` because normalization is limited to Counter choice. | Replace the float assertions with `TYPE_INT` and exact-value assertions. Rename the test to state that Counter identities normalize wherever present. Add or retain a separate partial-identity `ATTACK_DECLARE` case that reconstructs successfully, proving that normalization does not make the fields mandatory outside `ATTACK_COUNTER_CHOICE`. |

No other existing expectation contradicts the contract:

- `test_counter_identity_json_round_trip_restores_all_four_integers`, the
  partial Counter-choice failure test, and the Counter-choice invalid-value
  matrix already match the required `ATTACK_COUNTER_CHOICE` behavior and stay
  unchanged.
- `test_real_save10_and_reconnect_restore_counter_parent_identity` expects
  `TYPE_FLOAT` in raw parsed Save-10 JSON before `GameState`/
  `InteractionFlow` deserialization. That remains valid and must not be changed;
  its post-load assertions already require restored Counter identity.
- strict consumer tests in `test_counter_inspection_release.gd` and
  `test_modal_router.gd` inject a float directly into live runtime state and
  assert rejection. They do not cross the deserialization normalization
  boundary and remain valid.
- replay command tests that expect parsed JSON numbers to be floats before
  `GameCommand.deserialize()` concern the independent command codec and remain
  valid.

Any implementation result that requires changing one of those unaffected
expectations triggers review before the test is altered.

## 8. Compatibility, Stored Format, And Hash Impact

No save-format, replay-format, command-format, Network-protocol, or GGS-format
change is proposed.

The stored JSON representation of a normal serialized integer remains the same
JSON number text. Existing signatures remain valid because verification covers
the parsed JSON-normalized representation. The repair changes only the native
Variant type produced after deserialization for fields whose integer semantics
already existed.

The canonical hash of the reconstructed `InteractionFlow` can change when the
old codec left float-valued routing fields. That is the intended Boundary A
correction: the reconstructed flow should converge with the live source flow.
Hashes of uninterrupted command-built states should not change because those
fields are already integers. A complete `GameState` hash is expected to
converge only when all other reconstructed state is stable; the observed
`resolved_outcome` mismatch prevents this workbook from claiming unconditional
whole-state convergence.

Consequences:

- do not bump a format merely for the repair;
- do not rewrite existing saves, commands, histories, fixtures, or hashes;
- verify current signed saves at supported safe points still load;
- report any committed baseline/hash delta before altering evidence; and
- require explicit Owner approval for any fixture renewal, format cutover, or
  accepted-hash change discovered by verification.

### 8.1 Bounded `resolved_outcome` follow-up

Boundary C is recorded for investigation only:

1. reproduce the first exact pre/post JSON difference within
   `CurrentAttackState.resolved_outcome` using a production-created resolved
   attack;
2. trace each differing member to its producer, validator, serializer, and
   consumer;
3. determine whether the field has established integer semantics, an accepted
   mixed representation, or an unresolved policy choice;
4. assess Save/Load, Network/reconnect, replay, decision recovery, and
   canonical-hash significance; and
5. return a separate repair proposal only if authority resolves the intended
   representation and a production correction is warranted.

This follow-up may inspect code and run bounded proof tests. It does not
authorize production changes, test changes, fixture/hash changes, or inclusion
of `resolved_outcome` in either integer-reconstruction repair.

## 9. Authorized Scope After Acceptance

| Surface | Bounded change |
|---|---|
| `src/core/state/interaction_flow.gd` | Add private flow/step schema declarations and strict field-specific integer normalization; retain Counter and Displacement invariants. |
| `tests/unit/test_interaction_flow.gd` | Add positive JSON round trips and bounded negative helper/schema coverage. |
| Existing focused integration test files | Add aggregate, filtering, passive reconstruction, decision-recovery, and digest-convergence assertions without fixtures. |
| This workbook and later audit/evidence documents | Record audited scope and measured verification only. |

No production consumer should require modification. A consumer change beyond a
mechanical assertion/message adjustment stops implementation for review.

Explicitly excluded:

- GGS code, Candidate capture, Candidate files, fixtures, or Gate 2 resumption;
- GGS final-digest redesign or semantic digest projection;
- generic continuation ownership or gameplay architecture changes;
- broad generic JSON-number normalization;
- `GameCommand` schema or command-format changes;
- `CurrentAttackState.resolved_outcome` reconstruction changes;
- save/replay/Network format or protocol changes;
- replay fixture or expected-hash renewal; and
- normalization of opaque or undeclared Setup/rule payload subtrees beyond the
  established `deployment_pick`, `ecm_choice`, `choice_info`, and status-choice
  shapes listed in Section 3.

## 10. Stop Gates And Owner Decisions

Stop implementation and return to the Project Owner if evidence requires:

1. choosing between materially different accepted numeric meanings or ranges;
2. converting an unknown/opaque field rather than a declared integer field;
3. changing an authoritative gameplay fact, owner, command, or recovery rule;
4. changing any stored format, protocol, compatibility boundary, signature
   algorithm, or GGS digest contract;
5. altering a replay fixture, baseline trace, or accepted expected hash;
6. modifying production consumers to tolerate malformed flow data;
7. adding a generic serialization framework or new service; or
8. expanding beyond a bounded Medium repair after measured implementation
   effort is reassessed.

Owner decisions required before Boundary A implementation:

1. accept or reject this bounded normalization scope after independent audit;
2. confirm no format bump for integral-number type restoration; and
3. authorize the bounded implementation and verification package separately
   from GGS-001.

The command-codec proposal requires its own acceptance and implementation
authorization. The `resolved_outcome` item requires a separate authorization
to investigate; any later repair would require a reviewed proposal and another
explicit authorization. No decision on Boundary B or C is a prerequisite for
auditing Boundary A, but any unrelated divergence remains fail-closed for a
whole-state hash claim.

Any later GGS-001 continuation requires its own renewed economic authorization
and Gate 2 checkpoint. Completion of this repair does not provide it.

## 11. Cost, Risks, And Exit Criteria

Estimated work packages:

| Package | Estimate | Authorization state |
|---|---|---|
| Boundary A — InteractionFlow state repair | **Medium**: Small production-code change plus Medium inventory, negative-case, recovery, and compatibility verification. | Requires targeted re-audit, Owner acceptance, and separate implementation authorization. |
| Boundary B — Attack publication command codec | **Small to Medium**: Small codec extension plus focused Replay-12, application, and compatibility verification. | Separate proposal; requires separate Owner acceptance and implementation authorization. |
| Boundary C — `resolved_outcome` investigation | **Small** bounded diagnosis and repair recommendation. Any implementation cost remains unestimated until the representation and affected consumers are known. | Requires separate Owner authorization to investigate; no repair is authorized. |

Primary risks:

- omitting an established nested integer field and retaining a latent digest or
  strict-consumer divergence;
- over-normalizing a legitimate float or accepted string variant;
- imposing a new range that rejects a currently supported sentinel;
- mistaking projected routing data for canonical gameplay authority; and
- renewing a baseline before determining whether a delta is intended.

Exit requires all of the following:

1. independent audit confirms the inventory, negative-space exclusions, range
   categories, and verification matrix;
2. the Project Owner accepts the audited workbook and explicitly authorizes
   implementation;
3. every declared integer-only field and every numeric variant of a mixed-type
   field survives a JSON round trip as `TYPE_INT`, while accepted string
   variants remain unchanged;
4. every malformed-input class follows the exact disposition in Section 5.3,
   including the preserved whole-payload `{}` fallback;
5. representative live and reconstructed decisions and exact InteractionFlow
   forms converge; complete-state hashes converge only in cases with proven
   non-flow stability, while any unrelated difference is reported and fails
   closed for that hash assertion;
6. focused, full-suite, baseline, and Network resume verification pass without
   fixture or expected-hash alteration; and
7. implementation evidence reports actual effort, remaining risks, and any
   discovered baseline impact.

Current readiness: **ready for targeted independent re-audit and subsequent
Project Owner review; no production implementation or GGS continuation is
authorized**.
