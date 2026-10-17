# Attack Publication Command-Codec Integer Reconstruction Repair Proposal

Status: **Owner accepted and implementation authorized. Implementation stopped
at an accepted Replay-12 compatibility conflict; verification FAIL, not ready
for Owner implementation acceptance. Partial changes remain uncommitted.**

**Accepted architecture successor (2026-10-17):** The Project Owner accepted
the [atomic Counter architecture](atomic-counter-choice-publication-architecture-design.md)
after independent audits. The former Replay-12 compatibility conflict is
resolved at the architecture level by atomic complete publication and the
Save 11 / Network 12 / Replay 13 version policy. This does **not** resume this
stopped implementation, accept its partial changes, or authorize production
work. Section 7 defines its integration boundary with the consolidated
workbook; Sections 1–6 remain the historical proposal and stop evidence.

Purpose: restore established integer variants inside
`publish_attack_flow.payload.flow_payload` after Replay-12 JSON reconstruction.
This is Boundary B only. The [Boundary A InteractionFlow repair](interaction-flow-integer-reconstruction-repair-implementation-workbook.md#L846)
was implemented, committed, and accepted by the Project Owner; it does not
repair command data before `PublishAttackFlowCommand` executes.

Production and acceptance evidence:

- [`GameCommand` structured codec](../../../src/core/commands/game_command.gd#L381)
  and [`GameReplay.deserialize()`](../../../src/core/commands/game_replay.gd#L119);
- [central publication builder](../../../src/autoload/game_manager.gd#L2053),
  [Attack FSM](../../../src/core/combat/attack_flow_fsm.gd#L158), and
  [publication executor](../../../src/core/commands/publish_attack_flow_command.gd#L65);
- [`CommandProcessor` preflight order](../../../src/autoload/command_processor.gd#L395)
  and publication validators for
  [Coolant Discharge](../../../src/core/effects/rules/damage_cards/ship/coolant_discharge.gd#L48)
  and [Escort](../../../src/core/effects/rules/squadron_keywords/escort.gd#L48);
- [accepted BUG-074 Replay-12](../../qa/bugs/closed/BUG-074/replay_20261015_065840.json)
  and [Owner acceptance evidence](../../qa/bugs/closed/BUG-074/evidence/final-acceptance-evidence.md#L1); and
- [Boundary A production Attack inventory](interaction-flow-integer-reconstruction-repair-implementation-workbook.md#L185).

This is bounded architecture work at the Replay/Network command boundary
(`BC-009` / `AT-008`). The observed command path is a defect in numeric
reconstruction, not a new continuation owner or gameplay rule. The Project
Owner has now decided that every declared integer-only Attack publication
field must be validated before authoritative state mutation. Malformed
strings, booleans, fractional or nonfinite numbers, and other invalid values
are rejected. Valid native integers and permitted integral JSON floats are
accepted and installed as canonical integers. This intentionally tightens
malformed command acceptance. The Owner separately accepted this proposal and
authorized implementation; the stop finding in Section 6 now controls further
work.

## 1. Boundary And Proven Failure

```text
Replay-12 file JSON
-> GameReplay.deserialize() / GameCommand.canonicalize_serialized()
-> ReplayDriver / GameCommand.deserialize()
-> PublishAttackFlowCommand.validate() and execute()
-> GameState.interaction_flow
```

`GameManager.build_publish_attack_flow_command()` copies the installed Attack
flow payload into `flow_payload` for a non-final publication and emits `{}` for
a final clear. `AttackFlowFSM.patch_payload()` replaces named top-level keys;
`advance()` and `restart_for_next_attack()` retain the cumulative payload.
Therefore the complete production-backed Attack union below can be carried at
every reachable published Attack step: DECLARE, ROLL, MODIFY, DEFENSE_TOKENS,
RESOLVE_DAMAGE, CRITICAL_CHOICE, and COUNTER_CHOICE. A first-writer-only or
step-local command schema would miss retained fields. The uncalled
`_publish_clear_target_patch()` wrapper does not justify assuming that earlier
fields disappear. The final clear is a separate exact empty-payload case.

The accepted [BUG-074 format-12 replay](../../qa/bugs/closed/BUG-074/evidence/final-acceptance-evidence.md#L5)
has 83 commands and 17 `publish_attack_flow` entries. The non-final entries
include `ship_target_attacks_this_round` at sequences 23–29, 48–54, and
57–59; `accuracy_count` and `spendable_accuracy_count` at 29, 54, and 57–59;
and the five Counter identity/controller members plus `counter_dice_pool` at
59. Godot JSON exposes those numbers as floats. The current structured codec
restores several other Attack members but leaves these proven members as
floats. This is a command reconstruction mismatch even though the accepted
Replay-12 currently executes successfully.

## 2. Complete Production-Backed Integer Schema

The inventory follows the production FSM, attack executor, defense payload
builder, ECM projector, Counter choice writer, and immediate-choice writer,
then compares them with the current `GameCommand` structured branch. A field
listed as missing is optional when absent; its presence at one published step
does not make it mandatory at another.

| `flow_payload` shape | Already numerically restored by `GameCommand` | Missing command restoration |
|---|---|---|
| Direct integer-capable members | `attacker_player`, `attacker_ship_index`, `attacker_squadron_index`, `attacker_zone`, `chooser_player`, `controller_player`, `defender_player`, `defender_ship_index`, `defender_speed`, `final_damage`, `modified_damage`, `redirect_remaining`, `target_ship_index`, `target_squadron_index` | `defender_index`, `defender_squadron_index`, `ship_target_attacks_this_round`, `accuracy_count`, `spendable_accuracy_count`, `pending_card_index`, `pending_ship_index`, `pending_ship_owner_player`, `swarm_controller_player`, `counter_controller_player`, `counter_attacker_player`, `counter_attacker_squadron_index`, `counter_target_player`, `counter_target_squadron_index` |
| Accepted mixed direct field | Numeric `defender_zone` | None; preserve every string variant unchanged. |
| Integer arrays | `locked_tokens` | `blocked_defense_token_indices`, `ecm_authorized_indices`, `redirect_adjacent_zones`, `spent_defense_token_types`, `swarm_die_indices` |
| Integer dictionaries | Every `dice_pool` value | Every `counter_dice_pool` value. |
| Structured arrays | Numeric `dice_results[*].color` and `dice_results[*].face`; `defense_tokens[*].type` and `defense_tokens[*].state` | None. Keep accepted dice color/face strings unchanged. |
| Nested dictionaries | None | `pending_die_removal.controller_player`; `ecm_choice.defender_player`, `ecm_choice.defender_ship_index`, and each `ecm_choice.eligible_token_indices` entry; `choice_info.max_selections`. Empty dictionaries remain valid. |

The table covers the full Attack integer union in the accepted Boundary A
inventory, including DECLARE `dice_pool`, ROLL's pending die-removal controller,
MODIFY counts and Swarm indices, DEFENSE_TOKENS/ECM and redirect fields,
RESOLVE_DAMAGE final damage, Counter identities/pool, and CRITICAL_CHOICE
choice information. `ATTACK_DECLARE` after restart can retain any earlier
declared member. Numeric `defender_zone` is already covered; its accepted
`"front"` and other string values remain strings. Dice color/face strings,
identifiers, names, prompts, rule ids, and other opaque keys are not converted.
Booleans such as `final`, `counter_attack_available`, `is_obstructed`,
`accuracy_spend_blocked`, `evade_active`, and `redirect_active` remain booleans.
Do not add unsupported bare Attack keys (`attacker_index`, `die_index`,
`round`, `ship_index`, `token_index`, `token_type`, `zone`, `target_index`, or
`target_owner`) merely because they occur in command or canonical-state data.
`target_player` is likewise an unknown passthrough member, not a declared
integer field. Its presence, type, and value must not affect publication
validation or Escort target selection.
`ecm_pending_authorization` is excluded runtime rule state; the existing
publication execution strip remains unchanged.

Producer, consumer, and existing-test cross-check:

| Path | Production evidence | Existing protection and remaining gap |
|---|---|---|
| Snapshot and retention | `AttackExecutor._fsm_patch_payload()` and `_fsm_advance()` publish after the FSM merges or retains fields; `GameManager.build_publish_attack_flow_command()` deep-copies the installed flow. | `test_attack_flow_fsm.gd` covers merge/restart, while `test_publish_attack_flow_command.gd` covers the builder and native-dictionary execution. Neither proves the full cumulative command payload after JSON. |
| Declare, roll, modify, defense, and resolved payloads | `AttackExecutor` writes identity, pool, pending choice, accuracy, Swarm, redirect, and final-damage patches; `AttackFlowExecutor.build_defense_payload()` supplies defender/token fields; ECM decoration supplies `ecm_choice` and authorized indices. | `PublishAttackFlowCommand.execute()` installs the snapshot through `FlowSpec`; `AttackPanelMirror` consumes defense, ECM, redirect, and critical-choice projections. The existing `test_game_replay.gd` disk roundtrip covers only a subset of the structured integer shapes. |
| Counter and critical choice | `_counter_choice_payload()` writes the four Counter identities, controller, and pool; `_build_immediate_choice_payload()` writes pending card/ship identities and `choice_info`. | `CounterChoiceCommand` checks decision identity against the installed flow; `test_counter_inspection_release.gd` covers Counter state/recovery, while accepted Replay-12 covers only the Counter command-JSON shape. No current command-JSON test covers the complete critical-choice shape. |

The accepted Replay-12 is the positive proof for fields it actually contains,
not proof that absent ECM, redirect, Swarm, and critical-choice variants are
unreachable. Those variants require the focused producer-shaped cases in
Section 4.

Validation uses the accepted Boundary A range categories without adding new
gameplay meaning:

| Declared category | Existing accepted range |
|---|---|
| Required player identity | `0 .. Constants.PLAYER_COUNT - 1` |
| Optional player/controller sentinel | `-1 .. Constants.PLAYER_COUNT - 1` |
| Required entity/index identity | `0 .. 2147483647` |
| Optional entity/index sentinel | `-1 .. 2147483647` |
| Count, damage, token, die, zone, and enum projection | Existing producer/consumer range where explicit; otherwise `0 .. 2147483647`, or `-1 .. 2147483647` for a documented sentinel. |
| `dice_pool` and `counter_dice_pool` dictionary values | `-9007199254740991 .. 9007199254740991` |

Integral JSON floats must also be finite and within the exact JSON integer
ceiling. Native integers are subject to their declared category's range.
Examples: `attacker_player` and the two Counter player identities use the
required-player range; `controller_player`, `defender_player`,
`swarm_controller_player`, and `counter_controller_player` allow `-1`;
Counter squadron identities are required indices; `pending_card_index`,
`pending_ship_index`, and the relevant attacker/defender/target indices allow
their documented `-1` sentinel. Numeric `defender_zone` uses its established
optional-zone range, while every string variant is preserved unchanged.

Counter's four participant identities are validated and restored wherever
present in the cumulative Attack command payload. At
`ATTACK_COUNTER_CHOICE`, all four must be present, matching the accepted
`InteractionFlow.deserialize()` contract; at ordinary Attack steps, a partial
retained set remains valid. The existing outer-envelope, source-id,
active-attack, step, final-clear, and Counter decision/identity checks remain
in place. A correctly typed but stale identity still fails at its existing
semantic decision/installation boundary.

## 3. Smallest Command-Local Repair

Use the existing **command processing boundaries**, not `execute()`, as the
pre-mutation gates. `GameReplay.deserialize()` and `GameCommand.deserialize()`
call `GameCommand.canonicalize_serialized()` for JSON commands. A locally built
`PublishAttackFlowCommand` can reach `CommandProcessor.submit()` without that
codec. In `_submit()`, sequence/admission checks and the existing optional
exact-semantic and Network-mirror-envelope checks precede `preflight()`;
`preflight()` runs terminal, applicability, and rule validators **before**
`PublishAttackFlowCommand.validate()`. The registered Coolant Discharge and
Escort publication validators read `command.payload.flow_payload` into a
typed `Dictionary` and can call `int()` on declared Attack identity fields.
A direct command with a missing or wrong-container `flow_payload`, or a
malformed declared integer such as `attacker_player = []` or `"0"`, can
therefore fail or be coerced inside a hook before the publication's existing
type check. The codec and the later `validate()` gate alone cannot cover this
path. Escort has one separate unsafe read of an **unknown** member:
[`Escort._published_squadron()`](../../../src/core/effects/rules/squadron_keywords/escort.gd#L98)
initializes `owner` with `int(flow_payload.get("%s_player" % prefix, -1))`.
For `prefix == "target"`, that reads `target_player` and the following branch
unconditionally overwrites `owner` with `defender_player` or its established
`1 - attacker_player` fallback before `get_squadron()`. Validating
`target_player` as a declared integer would incorrectly narrow unknown-field
compatibility.

Require this exact publication-specific order inside the existing processor
path, with no new generic validation framework:

1. At the **start of `CommandProcessor.preflight()`**, before terminal,
   applicability, or rule hooks can inspect a `publish_attack_flow` command,
   run a pure, publication-specific safety check. Require a present Dictionary
   `flow_payload`; reject missing, null, or wrong-container values. Check
   every *present* declared integer-only member in the complete cumulative
   Section 2 union, including array/dictionary entries and nested declared
   fields, for the accepted type and field range. Check declared mixed fields
   under their existing string-or-valid-number rule. Reject malformed nested
   containers; ignore unknown members under existing compatibility behavior.
   In particular, do not read or validate `target_player`. Return a nonempty
   reason on failure. Do not change the submitted command or its payload,
   convert valid floats, test Counter
   requiredness, or decide attack legality here. Scope this check to
   `publish_attack_flow`; keep every other command's preflight order and
   behavior unchanged. This also protects direct callers of `preflight()`.
2. Run the existing terminal/admission, applicability, and registered rule
   preflight checks, including Coolant Discharge and Escort, on the checked
   but **unmodified** dictionary. A permitted integral JSON float remains a
   float until command validation; its finite, integral, exact, in-range
   value is safe for the hooks' existing `int()` reads. Preserve the hooks'
   existing rejection behavior.
3. Run `PublishAttackFlowCommand.validate()` for complete publication shape,
   integer normalization, Counter requiredness, and existing semantic checks.
   Only a fully valid command may proceed to `_execute_and_record()` and
   observer follow-ups.

The bounded repair retains two command-local entry points and **one shared
declared-integer policy**. Express the policy as a publication-specific pure
validation helper used by both the early preflight check and
`PublishAttackFlowCommand.validate()`; do not keep separate field lists or
ranges that can drift. The JSON codec must apply the same policy to its
deserialized candidate. Only the later codec/command reconstruction step may
canonicalize a valid candidate copy to `TYPE_INT`. No new generic command
validation framework or Boundary A code change is proposed. The only
rule-hook adjustment within this proposal's scope, subject to separate Owner
implementation authorization, is removal of Escort's unused target-player
conversion:

- In `Escort._published_squadron()` at the owner initialization before the
  `prefix == "target"` branch, keep the existing `%s_player` conversion for
  the `"attacker"` path only. For `"target"`, derive `owner` directly from
  the existing `defender_player` / `1 - attacker_player` expression. Leave the
  `target_squadron_index` read and `get_squadron(owner, squadron_index)` call
  unchanged. Do not change Escort hook registration, applicability, blocking
  rules, or any other rule hook. `target_player` stays an opaque unknown member
  through direct command submission, JSON codec reconstruction, and flow
  installation.

The two command-local entry points remain:

1. Extend the `publish_attack_flow` branch of
   `GameCommand._canonicalize_structured_payload()` to cover the full Section 2
   union. For every present declared integer-only member, reject strings
   (including `"0"`), booleans, nulls, wrong containers, fractional or
   nonfinite floats, unsafe JSON floats, and out-of-range integers. Accept a
   valid native integer or integral JSON float and output `TYPE_INT`. A
   malformed present member makes `canonicalize_serialized()` return `{}` and
   `GameCommand.deserialize()` return `null`, before a command can execute.
2. Make `PublishAttackFlowCommand.validate()` invoke the same pure declared-
   integer check, then normalize a local candidate copy of `flow_payload`
   before its existing semantic checks.
   Reject a malformed candidate with a nonempty validation reason. Install
   canonicalized command payload only after the *entire* shape and semantic
   validation succeeds. `CommandProcessor` must reject before calling
   `execute()`; the rejected command must not change canonical `GameState`,
   interaction flow, command sequence/history, or the observer follow-up queue.
   No mutation of the input dictionary or command payload occurs on a failed
   early, detailed, or semantic check.

The helper may be command-local but must not copy or modify Boundary A's
normalization code or move command validation into `InteractionFlow`.
`InteractionFlow.deserialize()` is the accepted parity contract for tests on
the resulting valid flow, not a replacement for pre-execution command
validation. Keep `PublishAttackFlowCommand.execute()` and its ECM decoration,
FlowSpec installation, and gameplay semantics unchanged.

Apply the cumulative union at every non-final published Attack step. Preserve
optional absence, `{}` optional `pending_die_removal`, `ecm_choice`, and
`choice_info`, and the existing exact final `flow_payload == {}` rule. The four
Counter identities become required only at `ATTACK_COUNTER_CHOICE`. Preserve
numeric/string mixed handling for `defender_zone` and
`dice_results[*].color`/`face`: valid numeric variants become integers;
accepted strings remain byte-for-byte strings. `defense_tokens[*].type` and
`state` remain integer-only. Unknown members and legitimate boolean fields
remain untouched. Preserve the existing outer command envelope and rejection
of missing or wrong-container `flow_payload`.

This intentionally tightens the former `_canonicalize_integer_if_numeric()`
passthrough for declared integer-only Attack fields. It does not apply that
change to mixed fields, opaque members, other command types, Boundary A, or a
generic serialization service.

## 4. Focused Verification Contract

1. **Codec shape matrix:** Build production-shaped non-final publications
   from the central builder and cumulative FSM transitions at every reachable
   Attack step, including retained predecessor fields, a restarted DECLARE,
   `pending_die_removal`, ECM, Swarm, Counter, and populated `choice_info`.
   `serialize()` -> `JSON.stringify()` -> `JSON.parse_string()` ->
   `GameCommand.canonicalize_serialized()` and `GameCommand.deserialize()`
   must restore valid integral JSON floats to exact `TYPE_INT` values. Repeat
   with valid native integers, including allowed sentinel and range edges.
   Assert exact command reserialization and command-hash convergence for
   production-backed shapes after showing all other command members are
   stable. Unknown numeric keys remain untouched and cannot support an
   unconditional hash claim. Show each newly covered field is actually
   written by a production producer or retained by the FSM.
2. **Compatibility and negative matrix:** Preserve `defender_zone` and dice
   color/face strings exactly, all listed booleans as booleans, unknown keys,
   empty/missing optional dictionaries, and the final empty flow. For every
   declared integer-only category, reject numeric strings, other strings,
   booleans, nulls, fractional `0.5`/`-1.5`, `INF`, `-INF`, `NAN`, values beyond
   the exact JSON ceiling, and values outside the Section 2 field range.
   Reject wrong declared containers and malformed array/dictionary entries;
   preserve valid unknown members without converting them. For the mixed
   `defender_zone` and dice color/face fields, preserve arbitrary existing
   strings, restore valid numeric variants, and reject boolean, null,
   container, fractional, nonfinite, or out-of-range variants. Include an
   **otherwise valid publication with `flow_payload.attacker_player = "0"`**:
   both JSON command reconstruction and live `CommandProcessor.submit()` must
   reject it. Repeat a representative malformed nested member and a missing
   Counter identity at `ATTACK_COUNTER_CHOICE`. For every rejected live
   submission, assert the exact before/after `GameState.serialize()`, full
   canonical-state digest, interaction-flow hash, command sequence/history,
   and observer follow-up queue are unchanged. With Coolant Discharge and
   Escort validators each registered and applicable at `ATTACK_DECLARE`,
   submit otherwise eligible direct publications with `flow_payload` absent,
   null, an Array, a string, and an integer; with
   `flow_payload.attacker_player = []` and then `"0"`; and with malformed
   declared player/index fields used by each hook. Include boolean,
   fractional, nonfinite, and out-of-range values, wrong declared nested
   containers, and invalid nested integer entries that neither hook directly
   reads. Every case must receive a clean rejection from the *early* check
   before either registered hook runs, with no runtime type error or payload
   mutation. Repeat through direct `preflight()` where appropriate. A
   correctly shaped publication with valid native integer members and one
   with permitted integral JSON numeric members must pass the early check,
   reach the applicable hook, and retain their exact input types/values until
   `validate()` normalizes a copy. Assert the same field verdict from early
   preflight and detailed command validation, while complete publication
   envelope/semantic legality remains in `validate()` and the existing hooks
   retain their rule checks. Include a later rule rejection and a later
   semantic-validation rejection; neither may change canonical state,
   history, sequence, or the follow-up queue. Existing exact envelope, stale
   source, invalid step, and type-correct mismatched-identity checks must
   still reject.
   Separately, run direct-command Escort publications with `target_player`
   absent and with malformed integer-like unknown values such as `[]`,
   `"bogus"`, `true`, and a Dictionary, while all declared fields are valid.
   Repeat after a genuine command JSON stringify/parse and
   `GameCommand.deserialize()`. The early check and command validator must
   ignore and preserve `target_player`; Escort preflight must complete cleanly
   without attempting its conversion. For both an allowed and a blocked
   Escort target, compare selected target identity, hook applicability, legal
   outcome, and resulting command behavior against the same publication with
   `target_player` absent. On the blocked case and on a later semantic
   rejection, assert unchanged full canonical-state digest, serialized state,
   command sequence/history, and observer follow-up queue. Assert the
   submitted payload is unchanged on rejection; the JSON command retains the
   unknown field through reconstruction. These cases must not become a new
   `target_player` schema or a broader early validation rule.
3. **Genuine Replay-12 input:** Read the immutable Owner-accepted BUG-074
   format-12 file through `GameReplay.load_from_file()`, without copying or
   rewriting it. For every recorded `publish_attack_flow`, compare the raw
   parsed JSON, canonical replay command, and `GameCommand.deserialize()`
   result. Assert exact `TYPE_INT` restoration and command hash convergence
   for recorded publications 23, 24, 26, 27, 29, 48, 49, 51, 52, 54, 57–59,
   and 65–66. Verify the Counter identities and `counter_dice_pool` at 59,
   and the `{}` final clears at 33 and 72. Do not infer ECM or critical-choice
   coverage from this one replay: use producer-shaped focused cases for those
   optional variants.
4. **Command execution and state digest:** On valid canonical attack states,
   execute reconstructed DECLARE, ROLL, MODIFY, DEFENSE_TOKENS/ECM,
   RESOLVE_DAMAGE, COUNTER_CHOICE, CRITICAL_CHOICE, and final-clear
   publications through the existing command processor. Compare the command
   acceptance/result, exact installed `InteractionFlow.serialize()`, flow
   hash, and legal next decision with an equivalent live command. Serialize
   each installed valid flow, perform a genuine JSON stringify/parse, and
   assert `InteractionFlow.deserialize()` succeeds with exact flow/hash equality;
   this proves command acceptance cannot install a flow that Boundary A would
   reject. Compare complete `GameState` hashes only after confirming non-flow
   serialized state is stable. A difference in
   `CurrentAttackState.resolved_outcome`, coordinates, or any other non-flow
   member must be identified at its first field and reported separately; never
   normalize it under Boundary B.
5. **Replay and compatibility:** Run the accepted 83-command Replay-12 to
   exhaustion and compare its established final hash without fixture or hash
   promotion. Run focused command codec/publication, Counter, ECM, replay
   driver, Save 10, Network 11/reconnect, and full repository suites, plus
   Hot-Seat and Network baseline scripts and real Network resume acceptance.
   Include valid direct publications with Coolant Discharge and Escort hooks
   registered to show rule preflight and normal execution remain intact.
   Verify current Save 10 / Network 11 / Replay 12 formats, signatures,
   fixture bytes, traces, and expected hashes remain unchanged. Run
   documentation checks and `git diff --check`.

## 5. Compatibility, Exclusions, And Owner Decision

The Owner-approved validation change is intentionally incompatible with
malformed historical `publish_attack_flow` commands: a declared integer-only
field formerly passed through as a string, boolean, null, wrong container, or
out-of-range value will now fail replay loading/command deserialization or
pre-execution command validation. This includes a string
`attacker_player = "0"`. Such values never become authoritative state. Existing valid native
integer commands and permitted integral JSON-float commands retain their
meaning and serialize with the same keys and JSON number format. Accepted
mixed strings, unrelated booleans, optional absence, and unknown keys retain
their prior compatibility behavior.

Save 10, Network 11, and Replay 12 formats, signatures, and protocol versions
remain unchanged. The accepted BUG-074 Replay-12 and existing baselines must
load and execute without fixture, trace, expected-hash, or Owner-evidence
changes. Because canonicalized command field types become exact integers,
pre-existing malformed inputs may now be rejected at replay load or at the
Network host's `CommandProcessor` gate. This is the intended compatibility
limit of the Owner decision. Any rejection of a valid accepted replay, changed
baseline, or format/signature requirement triggers the stop gate.

Excluded: `InteractionFlow.deserialize()` and the accepted Boundary A repair;
`CurrentAttackState.resolved_outcome` (Boundary C); the pending non-flow
`pos_x` precision finding; gameplay ownership, Counter continuation,
publication semantics, generic serialization architecture, command/replay/save
format or protocol changes, fixtures, expected hashes, baseline promotion, and
GGS-001 Gate 2/Candidates.

Stop and return to the Project Owner if implementation requires an excluded
surface, a new semantic requiredness or numeric-range rule beyond the accepted
Boundary A parity and the four Counter identities at Counter choice, a changed
format/version/signature, fixture or accepted-hash renewal, a new semantic
ownership rule, or work beyond the bounded cost below. A replay/digest delta
must be localized to its first differing field before any acceptance claim.

Estimated implementation cost: **Medium** — a small command-codec extension,
a pure publication-only shape/integer check at the existing preflight entry,
and a command-specific validation gate using the same declared-integer policy,
plus removal of Escort's single unused target-owner conversion, with
production-shape, malformed-input, execution, Replay-12, and compatibility
verification. Partial implementation and its stop evidence are in Section 6.

The Owner resolved the malformed integer-field policy, accepted the refined
proposal, and authorized Boundary B implementation. Section 6 records the
subsequent stop finding. Boundary C, the `pos_x` finding, and GGS-001 remain
pending and unauthorized.

## 6. Implementation Checkpoint And Compatibility Stop

Implementation began under the Owner's separate authorization. The partial,
uncommitted change adds a command-specific shared declared-integer policy,
uses it for pure publication preflight validation, JSON command reconstruction,
and publication command validation, and removes only Escort's unused
`target_player` conversion. Focused regression coverage was added without
changing fixtures, expected hashes, baselines, or Owner evidence.

Focused checks passed: the Boundary B regression file was **8/8 tests, 436
assertions**; the existing publication-command file was **15/15 tests, 36
assertions**; and the existing GameReplay file was **39/39 tests, 119
assertions**. The new replay-loading test confirms that all 83 accepted
BUG-074 commands, including 17 publications, reconstruct. These results do
not establish successful replay execution.

The first genuine accepted Replay-12 execution stopped at **cursor/sequence
58**. The publication at sequence 58 has step
`ATTACK_COUNTER_CHOICE` but lacks the four Counter participant identities.
The next publication, sequence 59, supplies those identities. The new
`PublishAttackFlowCommand.validate()` requiredness check rejects sequence 58,
and `ReplayDriver` times out waiting for its execution. The accepted replay
previously exhausted all 83 commands with final hash
`a0098afffb023b9d3b89151ee19fe3365c7f65ab68562b5f84ed87392d7fdcea`;
that hash was **not reached** in this run. This conflicts with the proposal's
simultaneous requirements that the four identities be mandatory at every
Counter-choice publication and that accepted Replay-12 behavior remain
unchanged. The immutable sequence 58/59 evidence must not be rewritten.

The full repository suite completed with **4380/4468 passing and 88 failing
tests**. The failures have not been classified, and no baseline or Network
claim follows from that run. Baseline and Network verification were not
started after the accepted-replay stop. No fixture or hash was promoted.

**STOP:** The Project Owner must decide how the Counter-choice publication
requiredness rule applies to the production two-publication transition at
sequences 58/59, without weakening the accepted Boundary A state contract or
changing the accepted replay. Do not continue implementation, normalize the
replay, or claim compatibility until that decision is recorded and the
required verification is rerun.

## 7. Accepted Atomic Counter Successor And Integration Gate (2026-10-17)

The Owner chose complete, atomic `ATTACK_COUNTER_CHOICE` publication over the
incomplete historical sequence 58. The old Replay-12 execution requirement
in Section 5 and the stop question in Section 6 are historical evidence, not
current Replay-13 acceptance criteria. All Replay-12 recordings, hashes, and
BUG-074 Owner evidence remain unchanged. Current replay baselines require
genuinely Owner-recorded Replay-13 inputs, updated runners/assertions, and
first-field diagnosis before any new hash or trace promotion.

Boundary B's shared declared-integer reconstruction policy, pure
publication-specific preflight safety check, full
`PublishAttackFlowCommand.validate()` legality check, and narrowly authorized
Escort unused-conversion removal remain the intended command-codec repair.
Preserve native integers and permitted integral JSON floats, mixed
string/numeric fields, optional fields, legitimate unknown passthrough, and
atomic rejection. The accepted
[Boundary A workbook](interaction-flow-integer-reconstruction-repair-implementation-workbook.md)
remains implemented and Owner-accepted; do not duplicate its state
normalization.

The consolidated Counter implementation workbook must audit and integrate the
preserved, uncommitted Boundary B changes against the accepted canonical
disposition, installed-publication preconditions, complete Counter identity
requirements, trusted live Network origin, and replay command ordering. It
must first establish the separately authorized Boundary C
`CurrentAttackState.resolved_outcome` reconstruction prerequisite; the Counter
publisher may not coerce a malformed canonical outcome. The integrated
correction requires Save 11 / Network 12 / Replay 13 acceptance, full-suite
convergence, real ENet and reconnect proof, and manual Owner replay capture.

**Implementation remains STOPPED.** No part of the prior authorization may be
used independently to resume the partial work or to change fixtures,
baselines, hashes, or evidence. The consolidated workbook passed independent
audit and was Owner-accepted on 2026-10-17; separate implementation
authorization is still required. Any new conflict with
the accepted architecture, unexpected state/hash divergence, or unsupported
compatibility change is a stop gate.
