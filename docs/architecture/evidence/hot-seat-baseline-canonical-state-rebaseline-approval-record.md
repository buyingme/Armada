# Hot-Seat Baseline Canonical-State Rebaseline Approval Record

**Status:** OWNER APPROVED AND PROMOTED — verification passed  
**Assessment date:** 2026-10-15  
**Scope:** broader canonical-state rebaseline for the existing Owner-controlled
Hot-Seat replay

## Immutable input and provenance

The assessed input is the existing
[`replay_hot_seat_solo.json`](../../../tests/fixtures/baseline_traces/replay_hot_seat_solo.json).
Its SHA-256 identity is:

`c151cff2b594fa648b805eea2ba0597321ffc6cde7f5fd1a446fadc2674ca9f9`

The Project Owner identifies this replay as the Owner-recorded Hot-Seat
replacement required by the accepted Network attack-flow workbook's manual
fixture boundary. The replay header independently records:

- replay format 12;
- application version `0.1.0` and Godot `4.5.1-stable (official)`;
- Debug Scenario (`debug_scenario`);
- capture timestamp `2026-10-11T06:53:10`;
- initial sequence `0` and canonical RNG seed
  `-395203029187618860`; and
- one Human principal controlling both Hot-Seat players.

No separate Hot-Seat capture log was found. Provenance therefore rests on the
Owner's explicit designation, the accepted manual-recording gate, and the
immutable header and digest above. The replay was not generated, transformed,
repaired, reordered, header-edited, or re-signed during this assessment.

## Clean-process verification

The authoritative Hot-Seat verifier was run in a fresh process against the
unchanged replay on 2026-10-15.

- The replay contains 175 contiguous commands, sequences `0–174`.
- ReplayDriver consumed the complete history successfully; no command
  rejection or incomplete-history failure occurred.
- The generated trace matched the committed
  [`baseline_trace_hot_seat_solo.jsonl`](../../../tests/fixtures/baseline_traces/baseline_trace_hot_seat_solo.jsonl)
  byte-for-byte. The committed trace contains one format-1 Hot-Seat/Solo header
  plus 175 contiguous records ending with `tarkin_choice` at sequence `174`.
- The generated final canonical-state hash was reproducibly
  `582100885f33fcdf4a308c6ef83e3419ce74db8f26c7b94aa13ed02434d90ac8`.
- The verifier's only failure was the expected-hash comparison against
  `87c9eb298aaef702b46974ce860ba952679e261347a933edca086cc897f939a9`.

This independently repeats the same `582100…` result preserved by the earlier
bounded hash investigation.

## Terminal canonical-state review

The canonical state producing `582100…` satisfies the reviewed stable-state
checklist:

- round 4, Ship Phase, initiative Player 0;
- the live interaction is Player 0's stable ship-selection decision;
- no active attack or unresolved completed-attack inspection;
- no faceup-damage inspection, timing window, or terminal match result;
- no live Ship or Squadron activation identity or unresolved nested
  continuation;
- both ships survive with internally consistent hull, shield, damage-card,
  command, defense-token, and upgrade state;
- the TIE Interceptor is destroyed with zero hull, while the X-wing remains
  live; and
- activation-scoped dispositions and progress are reset consistently for the
  new round.

The replay exercises four rounds, both Ship and Squadron activation paths, five
attacks, damage and result acknowledgement, defense-token and redirect paths,
Concentrate Fire, H9 Turbolasers, Electronic Countermeasures, maneuver,
displacement, and obstacle resolution. It is not relied on for Counter-child or
Network-publication coverage; those have separate accepted evidence.

## Approval boundary

This is a **broader canonical-state rebaseline**, not promotion of an
exact-RNG-only representation change. Converting only the current final state's
two RNG strings to their former numeric representation produces `30d9…`, not
the old expected `87c9…` hash. The canonical-state provenance that produced
`87c9…` cannot be fully reconstructed, and the historical canonical drift is
therefore not fully classified.

Owner approval would authorize changing only
[`baseline_state_hash_hot_seat_solo.txt`](../../../tests/fixtures/baseline_traces/baseline_state_hash_hot_seat_solo.txt)
from `87c9…` to the reviewed `582100…` digest. The replay and committed command
trace remain byte-for-byte unchanged. Approval does not authorize replay
replacement, trace replacement, production changes, exact-RNG baseline work
beyond this explicit combined review, or GGS-001 Gate 2.

## Owner approval and promotion result

The Project Owner explicitly approved this broader canonical-state rebaseline.
The authorized transaction changed only
`baseline_state_hash_hot_seat_solo.txt`, replacing `87c9…` with the reviewed
`582100…` digest. The Replay-12 input and format-1 command trace retained their
pre-promotion SHA-256 identities:

- replay: `c151cff2b594fa648b805eea2ba0597321ffc6cde7f5fd1a446fadc2674ca9f9`;
- trace: `bbfbe6e68d41ed0331950283aca0cb334cc4b97aea6a0e44721207134b284571`.

Post-promotion verification passed:

- Hot-Seat command-trace byte equality;
- Hot-Seat final-state hash equality at
  `582100885f33fcdf4a308c6ef83e3419ce74db8f26c7b94aa13ed02434d90ac8`;
  and
- real-ENet Network host/client final-state equality at
  `1d0bb7d11639c7632bb7106db0400ffbeab7858b233335c55ce7afeb18f0db53`.

This promotion does not retroactively classify the historical canonical drift
between `87c9…` and the current state. The old hash's complete canonical-state
provenance remains unavailable, exactly as disclosed for Owner review. The
promotion follows the [Replay Baseline Workflow](../../development/REPLAY_BASELINE_WORKFLOW.md)
as an explicitly reviewed broader rebaseline, not as an exact-RNG-only change.
