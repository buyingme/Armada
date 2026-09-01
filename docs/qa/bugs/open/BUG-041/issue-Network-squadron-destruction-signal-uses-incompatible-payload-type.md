# BUG-041 — Network squadron destruction signal uses incompatible payload type

Severity: Medium
Area: Network command-result projection / squadron destruction
Layer: Event / Presentation Integration

## Expected

When authoritative damage destroys a squadron, Network command-result processing
should emit the normal squadron-destruction event using a payload contract that
is compatible with all registered subscribers.

Canonical destruction must be projected consistently in Hot-Seat and Network
play without runtime signal-delivery errors.

The event must remain projection/integration infrastructure only. Semantic
gameplay continuation must not depend on successful delivery of this signal.

## Actual

During the 2026-08-31 BUG-035 Network reproduction, lethal damage correctly
destroyed the defending squadron canonically, but Network command-result
processing repeatedly failed to deliver the `squadron_destroyed` signal.

Observed runtime error:

`Cannot convert argument 1 from Object to Object.`

The remote damage handler emits the destroyed `SquadronInstance`.

`SquadronInstance` is a `RefCounted`, while the `squadron_destroyed` signal and
multiple subscribers currently require a `Node`.

Affected subscribers observed in the reproduction include:

- `GameManager._on_squadron_destroyed`
- `SfxManager._on_squadron_destroyed`
- `UIPanelManager._on_score_changed`
- `ActivationSidebar._on_squadron_destroyed`

The resulting Godot diagnostic reports both values generically as `Object`, but
the proven incompatibility is:

`SquadronInstance / RefCounted → Node`

## Evidence

Primary reproduction evidence:

- `game_20260831_212220_bug035_network_commanded_squadron_stall.txt`
- `replay_20260831_212422.json`
- `annotation_20260831_212345_001.json`
- `BUG-035-2026-08-31-network-recurrence-forensic-audit.md`

The failure occurs during Network handling of lethal Squadron damage through
`GameManager._handle_remote_resolve_damage()`.

Canonical destruction itself succeeds before the signal-delivery failures:

- squadron hull reaches zero;
- the squadron is marked destroyed;
- the attack completes;
- completed-result acknowledgements subsequently execute.

The forensic BUG-035 investigation established that the failed signal delivery
does **not** cause the BUG-035 gameplay stall.

The subscribers observed failing in this reproduction do not own semantic
gameplay continuation:

- `GameManager` destruction subscriber: no semantic progression;
- `SfxManager`: audio;
- `UIPanelManager`: HUD refresh;
- `ActivationSidebar`: authoritative-state presentation refresh.

Therefore this issue is tracked independently from BUG-035.

## Reproduction

1. Start a two-human Network game.
2. Resolve an attack that lethally damages an enemy squadron.
3. Allow the authoritative Network damage result to reach the remote peer.
4. Observe Network command-result processing for the destruction event.
5. Inspect terminal/runtime output.

Expected:

- canonical destruction is applied;
- `squadron_destroyed` is delivered successfully using one consistent payload
  contract;
- subscribers refresh normally;
- no signal argument-conversion errors occur.

Actual:

- canonical destruction succeeds;
- one or more `squadron_destroyed` subscribers reject the emitted
  `SquadronInstance` because their argument type expects `Node`.

## Investigation / Repair Requirement

Determine and enforce one authoritative `squadron_destroyed` event payload
contract across:

- local authoritative destruction;
- remote Network result application;
- ordered Network-result replay/application;
- all current subscribers.

Do not repair this by adding per-subscriber casts or mode-specific payload
variants unless the architecture explicitly requires different event types.

Prefer one consistent event meaning and payload representation for all producers
and consumers.

The repair must not:

- move gameplay progression into the destruction signal;
- make successful signal delivery a prerequisite for authoritative destruction;
- add canonical debug/projection state;
- introduce Hot-Seat versus Network semantic differences.

## Verification

Regression coverage should prove at minimum:

1. lethal Squadron destruction in Hot-Seat;
2. lethal Squadron destruction on the authoritative Network peer;
3. remote Network application of that same destruction;
4. ordered Network-result application/recovery where applicable;
5. all registered `squadron_destroyed` subscribers accept the event;
6. no signal argument-conversion errors are emitted;
7. canonical destroyed state is identical regardless of presentation/event
   consumers;
8. replay or passive application does not create duplicate semantic destruction
   or gameplay progression.

## Relationship to BUG-035

This defect was discovered during the 2026-08-31 BUG-035 recurrence.

The BUG-035 forensic investigation proved that lethal destruction changed the
attacking squadron's canonical Move legality, which was relevant to BUG-035,
but the `squadron_destroyed` signal-delivery failure itself did not cause the
continuation/recovery defect.

BUG-035 therefore remains responsible for recovering the correct remaining
Squadron decision.

This issue is responsible only for the independent destruction-event payload
contract failure.
