# BUG-020 — Network replay diverges during second Command Phase

Severity: High
Area: Network Replay / Command Phase
Layer: Serialization

## Expected

An application-recorded format-5 network replay should reproduce the recorded semantic command history deterministically through the network replay harness.

During the second Command Phase, the replay should execute the recorded sequence:

25. `start_round`
26. Player 1 `assign_dials`
27. Player 0 `assign_dials`
28. `advance_phase` to Ship Phase

No additional semantic command should be synthesized that changes this recorded sequence.

## Actual

The recorded network replay passes baseline-generator preflight but fails during network replay execution.

During the second Command Phase, after sequence 26 (`assign_dials` by Player 1), the replayed host automatically executes:

`advance_phase` as sequence 27

before the recorded Player 0 `assign_dials` command at sequence 27 is replayed.

The recorded sequence 28 `advance_phase → Ship Phase` is then rejected because the game is already in Ship Phase:

`Phase 2 is not the expected next phase (3).`

The ReplayDriver subsequently times out waiting for the rejected command to execute.

The client likewise times out waiting for the same replay progression.

## Reproduction

Always with the captured replay candidate.

1. Use the recorded format-5 authoritative-host network replay.
2. Run:

   `./scripts/generate_baseline_fixtures.sh --mode network --replay <replay>`

3. Candidate preflight passes.
4. Replay executes correctly through Round 1.
5. During the second Command Phase:
   - sequence 25 `start_round` executes;
   - sequence 26 Player 1 `assign_dials` executes;
   - an automatic `advance_phase` consumes sequence 27;
   - recorded sequence 28 `advance_phase` is rejected;
   - replay times out.

## Evidence

- `replay_20260812_210900_candidate_network.json`
- network candidate-generation host log
- network candidate-generation client log
- generator console output showing:
  - replay format 5
  - successful preflight
  - host=3 / client=3 failure

Recorded replay sequence:

- 25 `start_round`
- 26 Player 1 `assign_dials`
- 27 Player 0 `assign_dials`
- 28 `advance_phase`

Observed replay execution sequence:

- 25 `start_round`
- 26 Player 1 `assign_dials`
- 27 automatic `advance_phase`
- recorded progression then rejects

The replay itself passed generator structural validation and must not be edited, reordered, renumbered, or converted to bypass the failure.

## Notes

This was discovered while generating the new format-5 network baseline candidate.

The failure occurs before the later BUG-017 attack sequence, so it is not evidence that BUG-017 has regressed.

The current evidence suggests a divergence between recorded Command Phase progression and replay-time automatic/network continuation, but the exact root cause has not yet been established.

Potential investigation areas include:

- reconstructed command-dial requirements;
- simultaneous/private network Command Phase synchronization;
- automatic Command Phase completion;
- replay deferred/generated follow-up handling;
- authoritative command-sequence ownership.

Do not assume any one of these is the root cause until analyzed.

## Resolution

Root cause:
TBD

Fix:
TBD

Verification:
The unchanged captured replay must successfully complete network candidate generation with host/client authoritative final-state equality, without synthesizing an extra semantic phase-transition command or modifying the replay file.
