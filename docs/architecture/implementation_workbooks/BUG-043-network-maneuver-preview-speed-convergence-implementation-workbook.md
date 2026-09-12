# BUG-043: Network Maneuver Preview Speed Convergence Implementation Workbook

Status: Accepted — current executable refinement pending independent audit

Accepted by: Project Owner
Accepted date: 2026-09-07
Refined against current production: 2026-09-10

Purpose: perform the current Maneuver semantic cutover required by amended
ADR-006 and the accepted Ship Maneuver requirements. This workbook replaces
the former pre-commit `SetSpeedCommand` repair plan; it does not redesign the
accepted architecture.

## 1. Authority, Scope, And Cutover Ownership

This is **Bounded Architecture** work. Binding authority is:

1. accepted
   [ADR-006](../adr/ADR-006-canonical-ship-activation-boundary-ownership.md);
2. accepted
   [ADR-010](../adr/ADR-010-gameplay-interaction-decision-equivalent-recovery.md);
3. accepted
   [Ship Activation requirements](../../requirements/gameplay_interactions/ship_activation_interaction.md),
   [Ship Activation Owner decisions](../../requirements/gameplay_interactions/ship_activation_interaction_owner_decisions.md),
   and
   [Ship Maneuver requirements](../../requirements/gameplay_interactions/ship_maneuver_interaction.md);
4. accepted ADR-003/CON-003 and the applicable accepted command, Network,
   replay, save/load, filtering, and continuation authority, including
   ADR-008 and ADR-011 through ADR-013; and
5. current production and tests as implementation evidence only.

**BUG-043 alone owns the current Maneuver semantic cutover.**
[TWI-003](TWI-003-authoritative-current-attack-state-implementation-workbook.md)
records the historical attack-declaration/Ship Activation integration. It is
not a second implementation plan for the active Maneuver execution record,
commitment, consequences, completion, or current compatibility cutover.

Required final state:

```text
OPEN + no active execution       = uncommitted transient exploration
OPEN + matching active execution = committed Maneuver resolving consequences
CONSUMED + no active execution   = completed Maneuver
```

No lifecycle enum, general activation/Maneuver FSM, stack, queue, callback
owner, serialized route, or generic pending-work/continuation framework is
permitted.

## 2. Current Production Baseline And Disposition

### 2.1 Inspected seams

| Current seam | Current evidence | Required disposition |
| --- | --- | --- |
| `ShipInstance` and `GameState` | `ShipInstance` serializes the historical four activation-boundary facts. `GameState` validates their aggregate shape. No active Maneuver execution record exists. | **Refined:** add the fifth ADR-006 concept to `ShipInstance`; keep `GameState` aggregate/validation-only. |
| `ExecuteManeuverCommand` / `GameManager.submit_execute_maneuver()` | Payload accepts caller-authored final transform, `did_overlap`, and `speed_delta`; execution immediately calls `consume_open_maneuver_opportunity()`. | **Superseded:** retain this command as the atomic commitment/placement transaction, replace its payload and direct consumption semantics. |
| `ManeuverToolState`, `ManeuverToolScene`, `ShipActivationState` | Candidate speed/yaw and geometry exist, but activation mode currently submits `SetSpeedCommand` and treats accepted canonical speed as preview convergence. | **Refined:** keep these surfaces transient; remove their pre-commit canonical writes and resource ownership. |
| Navigate resources | `CommandDialStack`, `CommandTokenManager`, `SpendDialCommand`, and `SpendTokenCommand` own ordinary resource operations; the current controller submits separate spends after movement. | **Refined:** the resource objects remain canonical, but the Maneuver commitment mutates them directly inside its one transaction. Separate spend commands are not used for this interaction. |
| `OverlapResolver` | Pure ship-overlap reduction and squadron-overlap helpers exist; scene code currently constructs geometry and submits damage before Maneuver acceptance. | **Refined:** extend/reuse this pure model-space seam from authority; scene overlap remains advisory only. |
| `OverlapDamageCommand` | Atomically deals ship-overlap damage and uses the viewer-authorized passive damage contract, but lacks activation/execution binding. | **Refined:** bind it to the active Maneuver and make its success return to the Maneuver evaluator. |
| `StartDisplacementCommand` / `CommitDisplacementCommand` | Canonical positions commit, but `InteractionFlow`, modal callbacks, and `GameBoard._resume_after_remote_displacement()` currently drive return. | **Refined:** retain the commands and position ownership; derive opening from the execution and return through authority-side evaluation. Flow/modal state is projection. |
| Obstacle consequences | Setup placements and stable `placement_order` exist in `GameState.objectives`; catalog metadata is present, but obstacle gameplay packages are marked `NOT_INTEGRATED` and no Maneuver obstacle command exists. | **Refined with prerequisite gate:** BUG-043 adds exact detection/invocation/ordering integration, but SHALL NOT invent detailed obstacle effects or mark a package Integrated. Section 7.4 is a mandatory convergence stop until applicable packages exist. |
| Play-area destruction | No Maneuver-specific final-position check exists. Current movement clamping helpers are not the RRG destruction rule. | **Refined:** add a pure RRG footprint query and invoke it only after ship-overlap placement/reduction fixes the actual final position. |
| Authority continuation | `CommandProcessor._enqueue_post_success_continuation()` already composes purpose-specific timing, attack, squadron, and phase continuations. | **Refined:** add one Maneuver-specific evaluator at this exact seam; do not use scene/UI callbacks or the processor's transient FIFO as recovery evidence. |
| Save/load/reconnect | `GameState.serialize()/deserialize()`, `SaveGameManager.reconstruction_cursor_for()`, `StateFilter`, and Network snapshot installation are canonical-first. Current safe points and validation do not understand committed-but-`OPEN`. | **Refined:** serialize/validate the owner record, validate its sequence against the cursor, filter only as viewer authorization requires, then re-derive exploration or remaining consequences. |
| Replay | `GameReplay` replays semantic command history and suppresses synthesized mirror/replay follow-ups. Current format records the historical `SetSpeed -> execute_maneuver` path. | **Superseded for Maneuver:** format 10 records commitment and accepted consequence commands only; transient exploration is absent. |
| Network | Host validates through `NetworkManager`/`NetworkHostCommandSubmitter`; clients apply ordered results through `GameManager._apply_network_command_result()` and `CommandProcessor.submit_mirror()`; rejection is routed by `_on_network_command_rejection()`. | **Still valid, refined:** use those seams for the new command schemas and consequence return. Passive peers never originate automatic follow-ups. |

### 2.2 Former workbook instruction disposition

| Former instruction | Disposition | Current instruction |
| --- | --- | --- |
| Canonical `ShipInstance.current_speed` | **Still valid** | It is the starting speed and is updated only in accepted atomic commitment for this interaction. |
| Transient tool geometry | **Still valid** | Candidate speed, yaw, side/alignment, destination, and warnings remain disposable. |
| Ship plus activation identity guards | **Refined** | Commitment also creates and later consequence commands validate a stable execution identity. |
| `awaiting_remote` is not acceptance | **Still valid** | Pending work changes no canonical speed, resource, position, record, or disposition. |
| Rebuild preview from canonical state after rejection/reconstruction | **Refined** | Rebuild exploration only for `OPEN` without a record; resume consequences for `OPEN` with a record. |
| Accepted pre-commit `SetSpeedCommand` drives preview convergence | **Superseded** | Exploration is transient; convergence occurs at accepted Maneuver commitment. |
| Preserve SetSpeed snapshots and rejection rollback | **Obsolete** | Discard unaccepted candidate state and re-derive from canonical state. |
| Require preview speed to equal canonical speed before submit | **Superseded** | Validate `expected_starting_speed` and the legal selected result at commitment. |
| Existing ordered Network application/rejection behavior | **Refined** | Retain it for commitment and bound consequence commands under protocol 7. |

The former SetSpeed-centered slices SHALL NOT survive as a compatibility path.
`SetSpeedCommand` remains available for valid speed effects outside this Ship
Activation Maneuver interaction.

## 3. Exact Canonical Allocation

### 3.1 `ManeuverExecutionRecord`

Add `src/core/state/maneuver_execution_record.gd` as a JSON-safe value object.
`ShipInstance.active_maneuver_execution: ManeuverExecutionRecord` is its sole
writable owner; `null` means no active execution. `GameState` only validates
cross-owner uniqueness and references.

The record has exactly these fields:

| Field | Type/default | Reason it is stored |
| --- | --- | --- |
| `execution_identity` | `String`, non-empty | Stable identity for every nested command and recovery boundary. Derive on accepted commitment as `"maneuver-execution:%d" % ExecuteManeuverCommand.sequence`; it cannot be recovered safely from current transform/resources. |
| `ship_activation_identity` | `String`, non-empty | Binds the record to its owning ADR-006 activation and rejects stale commands/reconstruction. |
| `speed_delta` | `int`, `selected_speed - expected_starting_speed` | Thruster Fissure applicability is not derivable after canonical speed changes. |
| `overlapped_ship_owner` | `int`, `-1` for none | The closest ship selected by RRG overlap reduction is not derivable from the post-reduction final position. |
| `overlapped_ship_index` | `int`, `-1` for none | Completes the stable owner/index reference above. Both values are `-1` or both are valid. |
| `ship_overlap_damage_resolved` | `bool` | Damage completion cannot be inferred from damage counts. It starts `true` when no ship overlap was found and `false` otherwise. |
| `rrg_executed_maneuver_reached` | `bool` | The RRG event is non-derivable and distinct from Armada completion. It becomes true only after placement, overlap damage, immediate results, survival, and final-position play-area evaluation permit that boundary. |
| `selected_obstacle_placement_order` | `int`, `-1` | Stores at most one recoverable moving-controller ordering choice while its rule-owned effect/decision is live. This is purpose-specific choice evidence, not a queue. |
| `resolved_obstacle_placement_orders` | `Array[int]` | Final-position geometry still overlaps an obstacle after its effect resolves; this exact-once evidence prevents reinvocation. Entries are unique setup `placement_order` values. |
| `resolved_maneuver_effect_ids` | `Array[String]` | Persistent after-execute effects may remain applicable after they resolve; unique effect IDs prevent duplicate automatic damage on recovery/re-evaluation. |

Do **not** store committed/current speed, Navigate source inventory, final
transform, ship/squadron positions, damage state, obstacle placement/type,
controller, `InteractionFlow`, a stage/phase enum, or a pending-work list.
Those facts already have canonical owners or are derived. Course/yaw is used
inside the atomic commitment/placement command and replay payload; no save can
observe a half-executed command, so it is not duplicated in the active record.

`ManeuverExecutionRecord.validate()` and `deserialize()` fail closed on unknown
or missing fields, invalid identities, duplicate arrays, negative values other
than the defined `-1` sentinels, mismatched overlap references, a selected
obstacle already resolved, or `rrg_executed_maneuver_reached == true` while
ship-overlap damage remains unresolved.

### 3.2 Creation, mutation, retirement, and invariants

`ShipInstance` gains narrow operations; no caller writes record fields directly:

- `commit_maneuver_execution(record, expected_activation_identity)` requires
  Maneuver `OPEN`, no current record, and matching activation;
- `resolve_ship_overlap_damage(execution_identity)` flips only the matching
  false evidence;
- `reach_rrg_executed_maneuver(execution_identity)` requires overlap damage
  resolved and flips the event evidence exactly once;
- `select_maneuver_obstacle(execution_identity, placement_order)`,
  `resolve_maneuver_obstacle(...)`, and
  `resolve_maneuver_effect(...)` update only their named evidence; and
- `complete_maneuver_execution(...)` requires the completion evaluator's
  current positive proof, atomically changes `OPEN -> CONSUMED`, and sets the
  record to `null`.

`ship_activation_boundary_snapshot()/restore()`, owner validation,
`serialize()/deserialize()`, `mark_destroyed()`, normal completion, exceptional
clear, and round reset include the optional record. Valid combinations are only
the three states in Section 1. A record requires the same non-empty activation
identity and Maneuver `OPEN`; `CONSUMED` requires no record; destroyed/inactive
ships require no record.

`GameState._serialized_declaration_fields_are_complete()` requires the new
ship field at save version 7, and declaration-adjacent aggregate validation
rejects more than one active ship/execution or any invalid owner-local record.

## 4. Exact Atomic Commitment And Geometry

### 4.1 Command and payload

`ExecuteManeuverCommand` remains the sole commitment/placement transaction.
Replace its live/replay/wire payload with exactly:

```text
ship_index: int
ship_activation_identity: String
expected_starting_speed: int
selected_speed: int
yaw_clicks: Array[int]
yaw_bonus_joint: int        # -1 when unused
```

Remove `pos_x`, `pos_y`, `rotation_deg`, `did_overlap`, and `speed_delta` from
authored payloads. Authority derives them. Tool side/alignment is also derived
from the accepted yaw using `ManeuverToolState.compute_ghost_side()`; it is not
a duplicate authored fact. Update `GameCommand` integer/array canonicalization
and exact schema validation accordingly. Unknown/legacy fields reject.

### 4.2 Validation and atomic mutation

`ExecuteManeuverCommand.validate()` must, without mutation:

1. validate Ship Phase, entitled command principal, owner/index, live and
   non-destroyed ship, matching activation identity, Maneuver `OPEN`, no active
   execution, and valid declaration-adjacent aggregate;
2. require `expected_starting_speed == ShipInstance.current_speed`;
3. validate selected speed `0..max_speed`, a navigation-chart column for every
   positive selected speed, exact yaw length/click bounds after
   `ManeuverRuleResolver.apply_yaw_modifiers()`, and legal optional dial yaw;
4. derive Navigate sources from current canonical resources: no change/no yaw
   spends nothing; dial is preferred for a change of one; token alone is used
   only when no usable Navigate dial exists and no yaw is selected; dial plus
   token is required for a change of two; yaw requires the dial and may share
   that dial's speed-one effect; and
5. reject if those exact sources are unavailable, already consumed, or the
   candidate requires a second Navigate resolution.

This is the accepted Owner-approved digital deviation. Do not add source-choice
or no-effect interactions.

`execute()` snapshots the activation boundary, speed, transform, command dial
stack, command tokens, and `interaction_flow`. It then performs one transaction:

1. re-derive the same Navigate source set;
2. consume it directly through `CommandDialStack.spend_revealed()` and/or
   `CommandTokenManager.spend_token(NAVIGATE)`—not separate commands;
3. set canonical speed to `selected_speed`;
4. construct a pure `ManeuverToolState` from canonical model/rule facts;
5. derive attachment, legal side, attempted transform, ship-overlap temporary
   speed reduction, closest stable ship reference, and actual final transform
   through `ManeuverCalculator` plus an extended `OverlapResolver`;
6. apply the actual final canonical transform;
7. create the exact record from Section 3; and
8. if no ship-overlap damage is outstanding, evaluate play-area destruction
   at the actual final position and, if the ship survives, mark the RRG event.

Any failure restores every snapshot, produces no result/history advance, and
leaves Maneuver as uncommitted `OPEN`. The returned public result contains the
ship index, identities, selected speed, derived source booleans, yaw, actual
normalized transform, overlap reference/sentinel, RRG-event flag, and
destruction flag. It contains no private hidden identity.

### 4.3 Pure geometry allocation

Move no authority into scenes. Extend the existing pure movement geometry:

- `ManeuverCalculator` owns model-space attachment/final-course derivation now
  duplicated by `ManeuverToolScene._compute_attachment()`;
- `OverlapResolver.check_ship_ship_overlap()` accepts stable
  `{owner, ship_index, ShipBase}` entries and returns the stable closest
  reference, not an index into a scene-token array;
- `OverlapResolver.find_overlapped_squadrons()` derives owner/index references
  from canonical squadron positions;
- add `find_overlapped_obstacle_placement_orders()` over canonical
  `GameState.objectives["obstacles"]`, `AssetLoader` catalog shape metadata,
  and unique setup `placement_order`; and
- add an explicit RRG play-area query using only the ship base footprint. It
  excludes shield dials and plastic dial frames, unlike the ship-overlap
  footprint. A transient plotted destination never calls this query.

## 5. Consequence Ownership And Exact Completion

### 5.1 Authority-side evaluator

Add `src/core/state/maneuver_execution_continuation.gd`, following the existing
purpose-specific `CurrentAttackContinuation` pattern. It is a pure evaluator,
not stored state. `CommandProcessor._enqueue_post_success_continuation()` calls
it after successful commitment/consequence commands in live-authority mode.
Mirror and replay modes never synthesize a command.

`process_successful_command(game_state, command, result, mode)` and
`derive_reconstructed_maneuver_release(game_state)` always re-read the active
ship, activation identity, execution identity, survival, final geometry,
record evidence, current rule applicability, and current `InteractionFlow`.
They return at most one next command. Existing observer FIFO delivery may carry
that returned command but is not canonical evidence and is never serialized.

The evaluator uses this order:

1. stop if no matching active record or the moving ship was destroyed;
2. return bound `OverlapDamageCommand` when record evidence requires it;
3. reach the RRG executed-Maneuver boundary only after ship-overlap damage,
   immediate results, play-area evaluation, and survival permit it;
4. after the RRG event, derive unresolved mandatory integrated Maneuver effects;
5. derive squadron displacement and complete it before obstacles where no
   accepted rule overrides the fallback;
6. derive unresolved obstacle overlaps; one unresolved obstacle is automatic,
   multiple unresolved obstacles expose the moving-controller choice;
7. re-evaluate after every accepted consequence; and
8. return the exact normal completion command only when none remains.

### 5.2 Concrete owner map

| Consequence | Concrete transaction/evaluator | Completion evidence and return |
| --- | --- | --- |
| Ship-overlap placement/reduction | `ExecuteManeuverCommand` using `ManeuverCalculator`/`OverlapResolver` | Canonical transform plus stored closest ship reference; no scene token write is authoritative. |
| Ship-overlap damage | Existing `OverlapDamageCommand`, extended payload: `ship_index`, `other_owner`, `other_ship_index`, `ship_activation_identity`, `maneuver_execution_identity` | The command validates the stored reference, deals both cards, flips `ship_overlap_damage_resolved`, handles destruction, then returns through `ManeuverExecutionContinuation`. |
| RRG executed-Maneuver boundary | `ExecuteManeuverCommand` when no overlap damage is pending; otherwise the accepted bound `OverlapDamageCommand` after immediate/survival checks | `rrg_executed_maneuver_reached` flips once. Existing Ruptured Engine, Damaged Controls, and Thruster Fissure hooks move from raw `execute_maneuver` observation to this evidence/result boundary. |
| Play-area destruction | The same command that establishes the actual final position (`ExecuteManeuverCommand`) or completes required ship-overlap damage (`OverlapDamageCommand`) calls the pure RRG footprint query | Out-of-area calls `ShipInstance.mark_destroyed()` and clears bound flow/record through ADR-006 exceptional cleanup. `CommandProcessor` includes `execute_maneuver` as a destruction candidate for ordinary `DestroyUnitCommand` card cleanup. No completion/return is emitted. |
| Squadron displacement opening | Existing `StartDisplacementCommand`, now automatically returned by `ManeuverExecutionContinuation` | Payload is exactly `ship_index`, `ship_activation_identity`, `maneuver_execution_identity`; controller and affected squadrons are derived and returned for public projection. |
| Squadron placement | Existing `CommitDisplacementCommand` | Payload is exactly `ship_index`, `ship_activation_identity`, `maneuver_execution_identity`, and `placements`. It validates the non-moving controller, exact currently derived affected set, and every placement with `OverlapResolver`; canonical squadron positions prove completion. Success clears projected flow and returns authority-side. |
| Multiple-obstacle order and effect invocation | New narrow `ResolveManeuverObstacleCommand`, registered beside movement commands | Payload is exactly `ship_index`, `ship_activation_identity`, `maneuver_execution_identity`, and `obstacle_placement_order`. It validates that the obstacle is currently overlapped and unresolved; with multiple candidates only the moving controller may choose. It invokes the obstacle's Integrated package. If that package opens a nested choice, the package's accepted purpose-specific state/command owns that choice while the record retains only the selected obstacle; BUG-043 does not invent a generic `choice` payload. It records resolution only in the same accepted transaction as the package-owned effect. Section 7.4 gates missing packages or concrete package-owned choice seams. |
| Persistent after-execute damage | Existing `PersistentEffectDamageCommand`, extended with both identities | It applies one currently applicable effect, records that `effect_id` only in the same successful transaction, handles destruction, then returns authority-side. `ManeuverRuleResolver` supplies deterministic applicability/order; old raw-command observer generation is retired to prevent duplicates. |
| Normal Maneuver completion | Existing `AdvanceActivationStepCommand` with `step_id == "activation_done"`, returned automatically by `ManeuverExecutionContinuation` | Validation requires the evaluator's current positive completion proof. Execution atomically calls `complete_maneuver_execution()`, producing `OPEN + record -> CONSUMED + no record`, then publishes `ACTIVATION_DONE`. Duplicate/stale completion rejects. |
| End Activation | Existing `EndActivationCommand` | Remains a separate player interaction after `CONSUMED`; it does not complete Maneuver. |

Every bound command validates owner/index plus both identities. A mismatch,
already-resolved evidence, absent record, non-`OPEN` Maneuver, wrong controller,
or no-longer-applicable consequence rejects before mutation/history/cursor.

### 5.3 Destruction

`OverlapDamageCommand`, bound `PersistentEffectDamageCommand`,
`ResolveImmediateEffectCommand` when reached from a bound obstacle/effect, and
every integrated obstacle-effect command must use the existing
`ShipInstance.mark_destroyed()` exceptional behavior. The destroying
transaction also clears any bound displacement/obstacle `InteractionFlow` and
publishes the existing next-selection flow where applicable. Later cleanup may
return damage cards through `DestroyUnitCommand`, but no path changes Maneuver
to `CONSUMED`, creates `ACTIVATION_DONE`, calls End Activation, or returns to a
nonexistent record.

## 6. Network, Rejection, Recovery, And Exact-Once Behavior

### 6.1 Live Network allocation

- Authoring remains `ShipActivationController ->
  GameManager.submit_execute_maneuver() -> active CommandSubmitter`.
  The controller sends the Section 4.1 intent only and gates duplicate input on
  `NetworkCommandSubmitter.awaiting_remote`.
- Authority admission and execution remain
  `NetworkManager._submit_command_to_server() ->
  NetworkHostCommandSubmitter -> CommandProcessor` with existing principal,
  sequence, command-applicability, and command validation.
- Accepted propagation remains `NetworkManager._distribute_command_result()`.
  Deterministic public commands mirror through `submit_mirror()`; hidden damage
  commands retain their existing ADR-012/ADR-013 application-result contracts.
- Ordered passive application remains
  `GameManager._queue_network_command_result()` /
  `_apply_network_command_result()`. `_handle_remote_execute_maneuver()` snaps
  only from accepted canonical transform. `start_displacement`, bound damage,
  obstacle, completion, and destruction results project through existing
  command-executed/router paths.
- Rejection remains `_send_command_rejection()` ->
  `GameManager._on_network_command_rejection()`. Only a matching ship and
  activation pending intent is released; stale/unrelated rejection cannot
  dismiss or rebuild the current interaction. Rebuild discards candidate state
  and re-derives from canonical state.
- Only live authority invokes `ManeuverExecutionContinuation`. Passive peers
  apply recorded accepted results; they do not originate commitment,
  consequence, completion, or automatic follow-up.

`StateFilter` may transmit the public execution identity and public completion
evidence needed to project/reconstruct the viewer's entitled decision. It must
continue redacting hidden dial and damage identities. Passive state therefore
need not be byte-identical to full authority; `GameState.deserialize_passive_network()`
validates decision-equivalent viewer-authorized representation.

### 6.2 Save/load, reconnect, and reconstructed release

`ShipInstance.serialize()/deserialize()` carries the record exactly once.
`SaveGameManager.reconstruction_cursor_for()` additionally parses the sequence
suffix in `maneuver-execution:<sequence>` and requires
`next_command_sequence > sequence`, matching timing/attack identity checks.

After `GameState.deserialize()` or `deserialize_passive_network()` validates
the record and after the command cursor is restored:

- `OPEN + null` reconstructs a fresh straight transient tool from canonical
  speed/resources/rules;
- `OPEN + matching record` does not reopen course selection or repeat movement,
  speed, or Navigate consumption. `GameManager.release_reconstructed_maneuver()`
  calls `derive_reconstructed_maneuver_release()` only on full live authority;
  a still-live player choice is projected instead;
- `CONSUMED + null` exposes no Maneuver decision; and
- invalid combinations reject installation before scene projection/admission.

`SaveGameManager._SAFE_STEPS` must permit the accepted public Maneuver and
displacement/obstacle decision steps only after the new canonical validation
and cursor rules exist. A save never serializes a transient preview,
`awaiting_remote`, an undrained command transaction, or scene callback.

Replay executes the recorded semantic commands in sequence and synthesizes no
follow-up. Reconnect snapshots install the filtered record and any rule-owned
nested state before `UIProjector`/`ModalRouter` derives the entitled surface.

## 7. Compatibility Allocation

### 7.1 Save format: 6 -> 7

**Bump required.** `ShipInstance` gains a required canonical field whose
absence cannot distinguish historical direct consumption from the accepted
commitment/completion model. Set `SaveGameMetadata.CURRENT_VERSION = 7` in the
same atomic semantic cutover. The current exact-version loader rejects version
6 before installation; do not default a missing record or infer it from
`InteractionFlow`, speed, transform, or history. Version 7 saves require the
record key on every ship and validate all three canonical combinations.

### 7.2 Replay format: 9 -> 10

**Bump required independently of save format.** Replay 9 permits the obsolete
pre-commit `SetSpeedCommand -> ExecuteManeuverCommand` history and the old
Execute payload/direct-consumption meaning. Set `GameReplay.FORMAT_VERSION = 10`
and retain `SIGNED_FORMAT_VERSION = FORMAT_VERSION`. Reject format 9 before
applying commands. Do not translate, normalize, patch, or reconstruct old
Maneuver histories. Format 10 records the new commitment plus every accepted
consequence/completion command; transient exploration records nothing.

### 7.3 Network protocol: 6 -> 7

**Bump required independently of both file formats.** The live
`execute_maneuver`, overlap/displacement, persistent-effect, obstacle, and
completion schemas/semantics change, and old peers would diverge or consume
Maneuver early. Set `NetworkManager.PROTOCOL_VERSION = 7`; the existing
handshake hard-rejects protocol 6. No mixed-session adapter or dual vocabulary
is permitted.

### 7.4 Obstacle capability convergence gate

Current core obstacle metadata explicitly reports `rules_integration.status ==
"NOT_INTEGRATED"`. BUG-043 owns detection, ordering, bound invocation, return,
and completion gating; it does not own the asteroid, debris, station, objective,
or special-rule effect definitions.

Before Slice 3 may converge, every obstacle type reachable in the supported QA
scenario must have its normal ADR-003/CON-003 Rule Capability Package accepted
and implemented on the `ResolveManeuverObstacleCommand` contract. Codex may
gather evidence but may not mark a package `Integrated`. If a reachable
obstacle lacks that package, stop the implementation at this gate; do not mark
the obstacle resolved, skip it, or invent its effect in BUG-043.

This is a known implementation dependency under accepted rule architecture,
not a new canonical-owner decision.

## 8. Executable Implementation Slices

### Slice 0 — Entry gate and protected baseline

Authorized surfaces: read-only production/test inspection and the implementation
report.

Entry condition: accepted authority unchanged; dirty worktree inventoried;
save/replay/protocol exactly `6/9/6`; TWI-003 substrate/current declaration
tests present; obstacle package statuses recorded.

Responsibility: record current direct writes/submissions, current test count,
baseline hashes, replay fixtures requiring replacement, and protected tests.

Convergence gate: no edit; exact baseline recorded.

Architecture STOP: any second activation owner, an accepted authority conflict,
or inability to implement through `ShipInstance`, existing command processor,
and purpose-specific commands.

### Slice 1 — Owner record and pure derivation, behavior-inert

Authorized production surfaces:

- `src/core/state/maneuver_execution_record.gd`;
- `src/core/state/ship_instance.gd`, `game_state.gd`;
- `src/core/movement/maneuver_calculator.gd`, `overlap_resolver.gd`, and
  `maneuver_rule_resolver.gd`; and
- test helpers needed by the focused existing test homes.

Responsibility: add the exact dormant owner record, validation/snapshot helpers,
stable model references, and pure course/ship/squadron/obstacle/play-area
queries. No live command, serializer, format, Network, scene, or route reads
the record yet.

Focused tests: `tests/unit/test_ship_instance.gd`, `test_game_state.gd`,
`test_maneuver_rule_resolver.gd`, `test_overlap_resolver.gd`, and
`test_maneuver_tool_state.gd`.

Entry condition: Slice 0 passes.

Convergence gate: record invariants and pure geometry pass; production command
history, serialization shapes, versions, and baselines remain unchanged; zero
live references outside the listed owner/pure helpers.

Architecture STOP: a field outside Section 3.1 is needed, scene objects are
needed for authority geometry, or a general lifecycle/queue is proposed.

### Slice 2 — Atomic semantic and compatibility cutover

This is one indivisible cutover; it must not be released partially.

Authorized production surfaces:

- `execute_maneuver_command.gd`, `game_command.gd`,
  `command_applicability.gd`, `flow_spec.gd`, `command_processor.gd`;
- `ship_instance.gd`, `game_state.gd`, `maneuver_execution_record.gd`,
  `maneuver_execution_continuation.gd`;
- `game_manager.gd`, `network_manager.gd`, `state_filter.gd`,
  `ui_projector.gd`, current command submitters/router adapters;
- `maneuver_tool_state.gd`, `maneuver_tool_scene.gd`,
  `ship_activation_state.gd`, `ship_activation_controller.gd`;
- `overlap_damage_command.gd`, `start_displacement_command.gd`,
  `commit_displacement_command.gd`, `persistent_effect_damage_command.gd`,
  `advance_activation_step_command.gd`, `end_activation_command.gd`, and
  destruction/immediate-effect commands only for identity-bound cleanup;
- `save_game_metadata.gd`, `save_game_manager.gd`, `game_replay.gd`; and
- directly affected tests/fixtures declarations, but not captured replay data.

Responsibility: activate serialization and exact schemas; cut transient
exploration away from SetSpeed/spend commands; implement atomic commitment,
speed zero, ship-overlap damage, RRG boundary, final-position destruction,
automatic rule effects, derived displacement, exact completion, rejection,
reconstruction, passive application, and versions `7/10/7` together.

Focused tests:

- `tests/unit/test_movement_commands.gd`,
  `test_command_atomic_failure.gd`, `test_ship_instance.gd`,
  `test_game_state.gd`, `test_ship_activation_controller.gd`,
  `test_maneuver_rule_resolver.gd`, `test_rule_ruptured_engine.gd`,
  `test_rule_damaged_controls.gd`, and `test_rule_thruster_fissure.gd`;
- replace the current uncommitted
  `tests/unit/test_bug_043_maneuver_speed_convergence.gd` expectations that
  encode pre-commit SetSpeed with transient/atomic-commit expectations;
- `tests/integration/test_ship_activation.gd`,
  `test_current_attack_production_resume.gd`, and a focused
  `test_maneuver_execution_recovery.gd` only if no existing integration home
  can express committed-open recovery;
- `tests/unit/test_network_command_result_ordering.gd`,
  `test_result_application_contract.gd`, `test_network_manager.gd`,
  `test_save_game_manager.gd`, `test_save_load_round_trip.gd`, and
  `test_game_replay.gd`; and
- `tests/integration/test_rule_order_replay.gd` plus Network transport/reconnect
  homes for authority-only follow-up and passive non-synthesis.

Entry condition: Slice 1 converged; all affected production/test files clean or
owned by the task; new version values unallocated elsewhere; exact obstacle
package status understood.

Convergence gate:

- no production path submits `SetSpeedCommand`, `SpendDialCommand`, or
  `SpendTokenCommand` for Determine Course/Maneuver commitment;
- positive and speed-zero commits use the identical command/record/evaluator;
- injected late failure restores speed, transform, resources, record, flow,
  history, and cursor;
- `OPEN + record` survives round trip/reconnect and resumes without duplicate
  spend, movement, damage, RRG event, displacement, or rule effect;
- destruction clears without `CONSUMED`, return, or End Activation;
- old command schemas and versions reject; and
- no scene callback can consume Maneuver or advance to activation done.

Architecture STOP: partial cutover would be required, a new owner or generic
continuation is needed, passive state is required to possess hidden authority
representation, or obstacle detail is pulled into BUG-043 without its package.

### Slice 3 — Obstacle package integration and complete consequence convergence

Authorized surfaces: `ResolveManeuverObstacleCommand`, its registration/schema,
the exact already-governed obstacle Rule Capability Package production/tests,
`ManeuverExecutionContinuation`, and projection/recovery tests. No unrelated
obstacle or objective work.

Responsibility: connect every supported **Integrated** obstacle package to the
Section 5.2 bound command, including rule-owned choices, atomic completion
evidence, destruction, and authority return. Do not change package rule meaning
or status in this workbook.

Focused tests: existing rule-package homes plus overlap ordering, moving-player
choice, save/reconnect mid-choice, speed-zero overlap, exact-once effect,
displacement-first fallback, and destruction-stop cases.

Entry condition: Slice 2 converged and Section 7.4's package prerequisite is
satisfied by repository authority/evidence.

Convergence gate: every geometrically applicable supported obstacle invokes
exactly once; all nested choices recover decision-equivalently; only then can
completion be returned.

Architecture STOP: a package is missing/not Integrated, its accepted owner or
command contract conflicts with Section 5.2, or a generic obstacle work queue
would be required.

### Slice 4 — Replay convergence boundary

Authorized surfaces before capture: replay code/tests and fixture references,
not replay fixture contents.

Responsibility: prove format-10 rejection/application, record exact semantic
history, and make all automated non-fixture replay tests pass.

Entry condition: Slices 2 and 3 converge; production Hot-Seat and Network
Maneuver scenarios run correctly without baseline replay comparison.

Convergence gate before Owner handoff: all changed semantics/formats stable;
exact required captures documented; no further production edit expected.

**STOP FOR OWNER FIXTURE CAPTURE**

The Owner manually records genuine format-10 Hot-Seat and Network fixtures
through the real gameplay paths, including positive-speed Navigate commitment,
speed zero, ship overlap, displacement, obstacle consequence, normal
completion, and one destruction branch as supported by the baseline suites.
Codex must never generate, synthesize, reconstruct, patch, transform, relabel,
or programmatically regenerate replay fixtures. After Owner capture, Codex may
inspect, validate, hash, integrate, and verify them.

Architecture STOP: captured history still contains pre-commit Maneuver
`set_speed`, omits required consequence/completion commands, or differs between
real Hot-Seat and Network semantic paths.

### Slice 5 — Exit gate

Entry condition: Owner fixtures supplied and validated; all earlier gates pass.

Required automated evidence:

- focused unit/integration/Network/reconnect/save-load/replay tests above;
- transient `2 -> 1 -> 2`, dial preference, token fallback, dial+token speed
  two, no-effect/no-spend, stale identity, rejection, and duplicate submission;
- speed-zero no-movement plus all applicable consequences;
- actual-final-position play-area cases with overlap reduction and excluded
  dial/frame geometry;
- displacement-before-obstacle, multiple-obstacle controller choice,
  re-evaluation, exact-once recovery, and destruction-stop regressions;
- full suite;
- architecture lint and `git diff --check`; and
- Hot-Seat and Network baseline verification with Owner fixtures.

Manual QA: one real Hot-Seat and two-process Network run for each authoring
side, covering transient exploration, accepted atomic mutation, passive
viewer-authorized projection, matching rejection, reconnect in uncommitted and
committed `OPEN`, speed zero, nested displacement/obstacle choice, normal
completion, and destruction.

Convergence gate: all evidence passes; only authorized files changed; no
duplicate IDs/anchors or broken references; no legacy Maneuver SetSpeed route;
protocol-6/save-6/replay-9 artifacts reject at their correct boundaries.

## 9. Final STOP Conditions And Readiness

Stop and return for architecture/Owner direction if implementation requires:

1. a canonical owner other than the active `ShipInstance`;
2. a generic FSM, stage enum, continuation/pending-work record, stack, or queue;
3. durable uncommitted preview/candidate state or reverse synchronization;
4. pre-commit canonical SetSpeed or separate Navigate-spend commands;
5. a second Maneuver cutover workbook or compatibility vocabulary;
6. private authority representation on passive peers merely for equality;
7. ordinary speed-zero yaw without an Integrated package; or
8. changing accepted obstacle effect meaning/status inside BUG-043.

No new architecture decision or Owner decision is currently identified. The
concrete Maneuver allocation is executable through current purpose-specific
patterns. Implementation remains blocked at Section 7.4 for any supported
obstacle whose Rule Capability Package is still not Integrated, and replay
work must stop at the Section 8 fixture-capture boundary.
