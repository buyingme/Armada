# BUG-043 — Network Maneuver Preview Does Not Converge After Accepted Speed Change

Severity: High
Area: Ship Maneuver / Network Result Projection
Layer: Presentation / Transient Preview
Classification: Bounded Network maneuver-preview / canonical-speed convergence

## Original Symptom

During Network play, the Victory II-class Star Destroyer appeared to change
from speed 2 to speed 1 during its round-2 activation. At the beginning of
round 3 it appeared to be back at speed 2 without an intentional later change.

The original report therefore described a ship-speed persistence failure across
activation cleanup and the round transition.

## Disproven Original Diagnosis

The captured authoritative history does not contain a round-transition or
lifecycle overwrite:

- accepted `SetSpeedCommand` sequence 105 changed canonical speed from 2 to 1;
- a separate accepted `SetSpeedCommand` sequence 106 changed canonical speed
  from 1 back to 2;
- sequence 107 then submitted an `ExecuteManeuverCommand` whose transient
  maneuver payload still carried speed 1;
- maneuver execution, End Activation, Status cleanup, StartRound,
  serialization, replay, and Network reconstruction do not assign an earlier
  or scenario-default speed over `ShipInstance.current_speed`; and
- the round-3 annotation correctly captured the last accepted canonical speed,
  2.

BUG-043 is therefore not a canonical speed-persistence or Status Phase defect.

## Forensic Evidence

- `annotation_20260906_064217_001.json`
- `game_20260906_063022.log`
- `replay_20260906_070521.json`
- targeted Network submission probe performed during the BUG-043 provenance
  investigation

The log records sequence 105 at `06:34:35` and sequence 106 at `06:34:39`.
The replay records their payloads as `new_speed: 1` and `new_speed: 2`, followed
by an execute-maneuver payload with `speed: 1`.

Production tracing and the targeted probe establish:

1. the later `set_speed(2)` requires a distinct `+1` maneuver-tool input after
   the first accepted result has made canonical speed 1;
2. `NetworkCommandSubmitter.submit()` returns an `awaiting_remote` sentinel
   before the client has applied canonical mutation;
3. `ManeuverToolScene._handle_speed_change()` currently treats that non-empty
   sentinel like synchronous success and refreshes its preview from the still-
   old local `ShipInstance.current_speed`;
4. successful ordered client result application later mutates canonical speed,
   but `GameManager._handle_remote_command_effects()` handles `set_speed` with
   no presentation or maneuver-preview refresh; and
5. the live `ManeuverToolState.simulated_speed` can consequently remain 1 while
   canonical `ShipInstance.current_speed` is already 2, allowing the following
   maneuver request to carry stale preview speed.

The evidence proves the command producer and the preview divergence. It cannot
establish the player's subjective intent for the second physical input.

## Corrected Root Cause And Scope

Canonical state ownership is correct:

- `ShipInstance.current_speed` is the authoritative speed value; and
- `SetSpeedCommand` owns ordinary Navigate speed mutation and replay/Network
  command history.

The defect is at the accepted-result-to-preview convergence boundary. The
transient `ManeuverToolState` is initialized from canonical speed but is not
refreshed or invalidated when an asynchronously accepted Network speed command
updates that canonical value. The authoring client can therefore construct a
later maneuver from stale preview state.

The repair scope is limited to purpose-specific SetSpeed result projection and
the active maneuver preview/submission path. It must not create another speed
authority or reverse-synchronize preview state into `ShipInstance`.

## Expected Behavior

- An accepted `SetSpeedCommand` updates `ShipInstance.current_speed` exactly
  once on authority and passive peers.
- After acceptance, any live maneuver preview for that same ship must refresh
  from the accepted canonical speed or be invalidated and rebuilt from it.
- A subsequent `ExecuteManeuverCommand` submission must not carry a speed value
  stale relative to the accepted canonical speed.
- Host-authored and client-authored Network paths must converge to the same
  canonical speed and maneuver preview.
- Save/load and reconnect rebuild transient preview state from the restored or
  installed canonical ship state; preview state is not persisted.

## Exclusions

- No Status Phase, End Activation, or StartRound speed repair.
- No redesign of canonical speed ownership or `SetSpeedCommand` mutation.
- No UI-owned durable speed state.
- No save schema, replay format, replay reconstruction, or Network protocol
  change unless new implementation evidence proves one is necessary.
- No generic UI synchronization or pending-command framework.
- No BUG-046 architecture or behavior changes.

## Resolution

Root cause: confirmed as missing Network accepted-result convergence between
canonical `ShipInstance.current_speed` and transient maneuver preview state.

Fix: pending acceptance and implementation of the bounded BUG-043 workbook.

Required verification:

- accepted speed change updates canonical state;
- active maneuver preview converges to the accepted canonical speed;
- subsequent maneuver payload uses that speed;
- host-authored and client-authored Network paths behave equivalently;
- rejection cannot leave a stale actionable preview;
- save/load and reconnect re-derive preview state from canonical state without
  serializing preview state; and
- existing speed lifecycle, replay, and round-transition regressions remain
  green without compatibility changes.
