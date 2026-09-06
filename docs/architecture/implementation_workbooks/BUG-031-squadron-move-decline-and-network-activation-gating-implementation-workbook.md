# BUG-031: Squadron Move Decline And Network Activation Gating Implementation Workbook

Status: Accepted; implementation-ready; requirements fixed

Accepted by: Project Owner
Accepted date: 2026-09-05

Purpose: authorize only the canonical Squadron Move-decline transaction and
the Squadron Activation presentation gating required by the reproduced
BUG-031 Network stall. This workbook does not implement production code.

## 1. Classification, Authority, And Outcome

Classification: **Bounded Architecture**. The Project Owner has selected the
missing Move-decline semantic, and existing purpose-specific owners and
composed-return rules remain applicable.

Binding authority, in precedence order:

1. accepted [CON-007](../contracts/CON-007-post-attack-continuation-release-contract.md),
   including CON-007-SQMOVE-001 through 008;
2. accepted [BUG-035 workbook](BUG-035-anti-squadron-declaration-reconstruction-implementation-workbook.md)
   for action-order recovery and composed return;
3. accepted [ADR-010](../adr/ADR-010-gameplay-interaction-decision-equivalent-recovery.md);
4. accepted TWI-003 Squadron Activation ownership and action-history model;
5. the current [BUG-031 issue](../../qa/bugs/verify/BUG-031/issue-Skipping-squadron-activation-during-Squadron-command-stalls-ship-activation.md);
6. the 2026-09-05 forensic evidence in `logs/game_20260905_144326.log`; and
7. current production code as implementation evidence only.

Required outcome:

- a player may explicitly decline a legal remaining Squadron Move;
- decline is canonical, replayable gameplay history and is not movement;
- the current Squadron Activation remains the sole owner until authoritative
  completion succeeds; and
- presentation never exposes actionable child controls before authoritative
  activation acceptance or the next squadron before current completion.

This repair SHALL preserve BUG-035 Attack-to-Move recovery, CON-007 composed
return, completed-result inspection ownership, ship Squadron-command ownership,
and normal Squadron Phase ownership. It SHALL introduce no generic action,
bootstrap, continuation, interaction, pending-command, or controller framework.

## 2. Fixed Canonical State Semantics

`SquadronInstance` SHALL replace the two-state Move fact with an activation-
local Move disposition whose valid retained values are exactly:

| Disposition | Meaning |
| --- | --- |
| `available` | The Move decision has not been committed or declined. Whether it is currently legal remains derived from canonical rules and state. |
| `committed` | An accepted `MoveSquadronCommand` committed the Move action. |
| `declined` | An accepted `DeclineSquadronMoveCommand` explicitly declined a then-legal remaining Move. |

An `inactive` sentinel MAY represent the absence of retained Squadron
Activation action state. It is not a fourth player decision.

The existing `SquadronInstance` owner SHALL serialize, deserialize, snapshot,
restore, validate, and reset this disposition with the existing activation
identity and context. Scene position and presentation state SHALL never infer
the disposition.

Remaining Move is derived only when:

- Move disposition is `available`;
- the activation identity and context are valid and incomplete; and
- current canonical rule state permits movement, including engagement and
  applicable Rogue/action-order semantics.

`committed` and `declined` are terminal for that Move action. Neither returns to
`available` before the existing activation reset boundary.

## 3. Fixed Command Semantics

Add the purpose-specific, replayable semantic command:

```text
DeclineSquadronMoveCommand
command_type: decline_squadron_move
```

Its strict payload SHALL contain:

- `squadron_index`;
- `activation_id`;
- `activation_context`;
- `completed_attack_inspection_id`, as the matching non-empty identity when a
  satisfied inspection guards this decision and as the empty string otherwise;
- for ship-command context only, `ship_activation_identity`.

`command.player_index` remains the controller identity. Do not add a controller
field. Commanded context continues to validate the commanding ship owner/index
stored by the `SquadronInstance`, the matching active ship identity, the open
Squadron-command opportunity, and its committed capacity.

Validation SHALL require:

1. an active, matching, incomplete Squadron Activation;
2. Move disposition `available`;
3. a currently legal remaining Move;
4. no active child Attack;
5. the canonical controller and, where applicable, commanding ship identity;
6. valid declaration-adjacent state; and
7. an exact satisfied inspection identity when such an inspection exists, or
   an empty inspection identity when none exists.

Success SHALL atomically:

1. change Move `available -> declined`;
2. consume the matching satisfied inspection when present; and
3. return the stable squadron/activation identity and `move_disposition:
   declined` result needed for projection.

Failure SHALL roll back both disposition and inspection consumption. Stale,
duplicate, reordered, wrong-player, wrong-squadron, wrong-activation,
wrong-context, wrong-ship, missing-inspection, and wrong-inspection submissions
must reject without mutation, history advancement, capacity change, or local
completion.

`MoveSquadronCommand` remains the sole movement transaction and changes only
`available -> committed`. A zero-distance Move, if independently legal, still
records `committed`; presentation and controllers SHALL NOT submit it to encode
decline.

`CompleteSquadronActivationCommand` remains terminal-only. It SHALL reject
while a legal Move or Attack remains and SHALL never mutate Move disposition.
After decline, the existing live-authority bounded re-evaluation selects the
existing completion exactly once only when Attack also does not remain.

## 4. Composed Return And Distribution

The required post-Attack path is:

```text
completed Attack
-> required acknowledgements accepted
-> same Squadron Activation recovered with Move available
-> controller submits DeclineSquadronMoveCommand
-> authority records declined and consumes the matching inspection atomically
-> existing live-authority seam re-evaluates the same Squadron Activation
-> CompleteSquadronActivationCommand exactly once when terminal
-> existing Squadron Command owner exposes the next eligible squadron
```

If Attack remains after Move decline, no completion is synthesized; the same
Squadron Activation exposes the remaining Attack decision. If canonical rules
make Move unavailable rather than voluntarily declined, terminal eligibility
continues to be derived without manufacturing a decline.

Only live authority originates the bounded terminal follow-up. Passive Network
mirrors apply ordered recorded commands and results but synthesize neither
decline nor completion. Replay applies recorded history only. Save/load and
reconnect restore Move disposition, activation identity, command owner, command
capacity, and any inspection before projection or gameplay admission. Future
non-human controllers submit the same semantic command and receive the same
validation; they gain no direct mutation path.

## 5. Presentation Gating

### 5.1 Move decline and completion

The Squadron Activation Skip/decline control SHALL submit
`DeclineSquadronMoveCommand` when a legal Move remains. It SHALL enter a bounded
pending state keyed to the current canonical activation identity and submitted
command. It SHALL NOT call local activation completion, clear the selected
squadron, increment displayed activation progress, or enable another squadron.

On accepted decline, presentation SHALL reconstruct from canonical state. It
may show a remaining Attack decision, or wait for and project authoritative
completion. Only accepted completion permits “ready for next,” next-squadron
selection, or enclosing Squadron-command completion. Rejection restores the
same canonical activation and legal controls without phantom progress.

### 5.2 Commanded-squadron activation acceptance

A locally selected commanded squadron is only a candidate until its
`ActivateSquadronCommand` is authoritatively accepted. During Network pending:

- Move, Attack, decline/Skip, and completion controls are non-actionable;
- no activation slot or “activation N of M” progress is locally committed;
- additional selection and duplicate activation submission are blocked; and
- passive or non-controlling peers receive no actionable surface.

Matching acceptance reconstructs the accepted activation identity/context and
then enables actions exactly once. Rejection clears the matching pending intent
and returns to authoritative candidate selection without a phantom active
squadron, consumed capacity, stale controller, or “Not your squadron” result for
an otherwise valid owned candidate.

Hot-Seat may complete the same submission synchronously, but it SHALL project
the same accepted canonical boundary rather than bypass it.

## 6. Compatibility Cutover

This repair changes canonical save state and the serialized Network/replay
command vocabulary. Apply the repository's existing strict compatibility
owners in one cutover:

- `SaveGameMetadata.CURRENT_VERSION`: **5 -> 6**;
- `GameReplay.FORMAT_VERSION`: **8 -> 9**, with
  `SIGNED_FORMAT_VERSION := FORMAT_VERSION` unchanged as an alias; and
- `NetworkManager.PROTOCOL_VERSION`: **5 -> 6**.

Save version 5, replay format 8, and mixed protocol 5/6 peers SHALL reject at
their existing boundaries before state installation or command application.
Do not infer a missing Move disposition from `move_action_committed`, rewrite
headers, normalize old histories, or create a compatibility adapter. Replay-9
fixtures and affected baselines must be genuinely regenerated and reviewed
through the existing baseline workflow. `BaselineTrace.FORMAT_VERSION` remains
unchanged unless its own record schema changes.

The cutover follows, and does not amend, the still-unaccepted production status
of BUG-042: implementation and acceptance evidence must verify the combined
current working tree rather than treating protocol 5 or replay 8 as a shippable
intermediate state.

## 7. Authorized Implementation Boundary

Implementation is limited to:

- `SquadronInstance` Move disposition and its existing serialization,
  snapshot/rollback, reset, and remaining-action predicates;
- the new `DeclineSquadronMoveCommand`, normal command registration,
  applicability, strict serialization, and submission seam;
- the existing completed-inspection consumer validation and bounded
  `CommandProcessor` re-evaluation needed to consume inspection and select
  terminal completion;
- Squadron Activation modal/controller projection, pending acceptance,
  rejection recovery, and next-selection gating;
- existing save, replay, protocol version owners and affected fixtures; and
- focused unit, integration, production-path, save/load, reconnect, replay,
  Hot-Seat, Network, and baseline verification.

Not authorized:

- changes to Attack disposition or BUG-035 action-order recovery;
- changes to `CompleteSquadronActivationCommand` terminal criteria except to
  read the selected Move disposition;
- authority-side completion that bypasses the accepted recorded command;
- new ownership on `GameState`, `InteractionFlow`, scenes, modals, transport,
  or `GameManager`;
- generic action disposition, action queue, continuation descriptor, pending-
  command manager, interaction FSM, controller framework, or bootstrap system;
  or
- unrelated Ship Activation, Squadron Phase, rule, RNG, damage, or BUG-042
  redesign.

Stop for Owner guidance if the bounded command cannot consume a matching
satisfied inspection atomically, if completion cannot remain an existing
recorded command, or if implementation requires another canonical owner or a
broader framework.

## 8. Required Regressions

### A. Attack -> decline remaining Move -> completion -> next squadron

Use a real two-process ENet session with the controlling human on the client.
Enter a ship-commanded Squadron Activation through the production selection
path, execute Attack first, complete both required result acknowledgements, and
recover the same squadron with Move canonically legal and `available`.

Press the real decline/Skip control and assert:

- exactly one accepted `decline_squadron_move` with the matching activation,
  ship, squadron, and completed-inspection identities;
- authority, client mirror, save/load restoration, and reconnect restoration
  all record Move `declined`;
- no `move_squadron` command and no position mutation represent the decline;
- the inspection is consumed atomically exactly once;
- exactly one recorded `complete_squadron_activation` follows when Attack is
  exhausted;
- the current activation remains selected/non-progressed until that completion
  is accepted; and
- only then does “activation 2 of N” become actionable and the next commanded
  squadron activate successfully.

Reject stale/duplicate decline and delayed/rejected completion variants without
inspection loss, capacity drift, local “ready for next,” or unrelated
progression. Repeat the canonical transaction in Hot-Seat and replay, and
round-trip the declined state through save/load and reconnect.

### B. Selection non-actionable until activation acceptance

Use a real two-process ENet session with a client-controlled ship Squadron
command. Delay the authoritative response after the client selects an eligible
owned squadron.

Assert before acceptance:

- exactly one `activate_squadron` intent is pending;
- Move, Attack, decline/Skip, and completion cannot be submitted;
- another squadron cannot be activated;
- no local activation count, identity, or “ready” progress is committed; and
- no “Waiting for authoritative activation confirmation” error substitutes for
  a normal pending presentation.

On matching acceptance, assert that the canonical activation identity and one
command-capacity commitment install before controls enable exactly once. On
authoritative rejection, assert clean return to candidate selection with no
actionable stale modal, phantom capacity, duplicate activation, active
squadron, or erroneous “Not your squadron” message for the valid owned
candidate.

An in-memory fixture that pre-installs an active squadron does not satisfy this
regression.

## 9. Verification And Acceptance

Implementation acceptance requires:

1. focused `SquadronInstance` transition, invalid-state, serialization, and
   rollback tests for every Move disposition;
2. strict command schema, validation, atomicity, duplicate/stale identity,
   inspection, command-context, mirror, and replay tests;
3. both Section 8 real two-process regressions through production UI and ENet;
4. Hot-Seat, Network, replay-9, save-6 load, save/reconnect, and future-
   controller-facing command-path parity evidence;
5. existing BUG-031, BUG-035, CON-007, Squadron Phase, Squadron Command,
   activation-modal, current-attack, save/load, replay, and Network suites;
6. full repository tests and baseline traces, with independently reviewed
   expected fixture renewal only for the accepted semantic/version changes;
7. architecture/static checks and structural searches proving no generic
   framework or presentation-side canonical mutation was introduced; and
8. `git diff --check`, authorized-scope diff review, and manual two-human
   Network QA after automated acceptance succeeds.

Current stop-gate status: **clear for the bounded implementation specified
above**. No Owner decision remains unresolved.
