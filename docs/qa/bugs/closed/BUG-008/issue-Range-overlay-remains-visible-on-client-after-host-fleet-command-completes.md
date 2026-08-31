# BUG-008 — Range overlay remains visible on client after host fleet command completes

Severity: Low–Medium
Area: Network / Range Overlay
Layer: Presentation / Projection

## Expected

When a fleet command or related interaction that displays the range overlay is
completed, the range overlay should be dismissed on all clients where it was
shown.

The client presentation should reflect that the interaction requiring the
range overlay has ended.

## Actual

During network play, after the fleet command is executed by the host, the range
overlay remains visible on the other player's client.

In the observed case, the Imperial client continued displaying the range
overlay after the host had completed the fleet-command interaction.

Gameplay otherwise appeared to continue.

## Reproduction

Observed during network play.

1. Start a network game.
2. Reach a situation in which a fleet command displays the range overlay.
3. Execute/complete the fleet command on the host.
4. Observe the other player's client.

Result:

- the host completes the fleet-command interaction;
- the range overlay remains visible on the client.

## Evidence

- `annotation_20260804_221320_002.json`

Annotation:

`I relize another bug. after fleet command has been executed by the host, the
range overlay will not vanish on the client (in this case imperial) screen.`

The captured state is in Round 3 Ship Phase after gameplay has continued,
supporting the interpretation that this is primarily stale client presentation
rather than an obvious canonical game-flow stall.

## Initial Assessment

Root cause is unknown.

This should be treated as a presentation/projection lifecycle defect unless
investigation produces evidence of an underlying canonical-state problem.

Likely investigation areas include:

- network handling of fleet-command completion;
- range-overlay dismissal events;
- host versus mirrored-client presentation cleanup;
- whether accepted command/result projection dismisses the overlay locally but
  fails to perform equivalent cleanup on the remote client;
- lifecycle cleanup when the interaction that requested the range overlay ends.

### Architecture Constraint

The range overlay is presentation/tool state and must not become canonical
gameplay state merely to repair this synchronization defect.

In particular, the repair must not introduce concepts such as
`range_overlay_visible`, equivalent UI visibility state, or range-tool
lifecycle state into `GameState` or another authoritative gameplay owner solely
for network synchronization.

Range measurement is a player-side tool. Its presentation does not require
semantic command representation or deterministic replication merely because
Hot-Seat and Network presentation differ.

The preferred repair direction is therefore:

authoritative gameplay transition
→ accepted/mirrored result
→ derived presentation lifecycle
→ local overlay cleanup

The client should derive that the interaction requiring the overlay has ended
and dismiss its local presentation accordingly.

If investigation shows that an existing canonical gameplay fact required to
derive this cleanup is missing, stop and report that architectural finding
rather than introducing new authoritative presentation state as part of the
bug fix.

## Resolution

Root cause:
TBD

Fix:
TBD

## Verification

After repair, verify:

- overlay appears correctly when required on the host;
- overlay appears correctly when required on the client;
- completing the interaction dismisses it on the host;
- completing the interaction dismisses it on the client;
- dismissal occurs after authoritative/mirrored completion rather than through
  optimistic canonical mutation;
- subsequent range-overlay interactions can still be opened normally;
- Hot-Seat behavior remains unchanged;
- replay/reconnect does not leave a stale overlay visible.

## Implementation Update — 2026-08-14

Confirmed root cause:

The ship-command range overlay was opened locally by
`SquadronPhaseController.open_for_command()` and dismissed by the local
`squadron_command_done` callback. A passive network peer did not execute that
local callback. Although its accepted mirrored `InteractionFlow` left
`SQUADRON_STEP`, `ShipActivationController.sync_activation_step_from_flow()`
did not retire the peer's transient command overlay.

Implemented fix:

When an accepted/mirrored ship-activation projection is no longer at
`SQUADRON_STEP`, each peer asks its local `SquadronPhaseController` to dismiss
the command range overlay. A later command can create a fresh overlay normally.

Architecture Constraint compliance:

The repair derives cleanup from the existing accepted `InteractionFlow` step
and mutates only the local overlay node. No `range_overlay_visible`, canonical
tool lifecycle, semantic command, network field, or serialized UI state was
introduced. `InteractionFlow` remains projection/routing state, not gameplay
or activation authority.

Regression evidence:

`test_command_range_overlay_retires_from_accepted_step_on_each_peer` proves
overlay creation, retention during the Squadron step, Hot-Seat dismissal,
passive network-client dismissal, and subsequent reuse.

Verification:

- focused `test_ship_activation_controller.gd`: 8/8 passed;
- full repository suite: 4,048/4,048 passed (13,507 assertions);
- architecture lint and `git diff --check`: passed.

Status: repaired by automated evidence; ready for Project Owner/manual Network
verification.
