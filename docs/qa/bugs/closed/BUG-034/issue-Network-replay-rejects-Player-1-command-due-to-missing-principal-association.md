# BUG-034 — Network replay rejects Player 1 command due to missing principal association

Severity: High
Area: Network Replay / Player Principal Authorization
Layer: Networking

## Expected

An application-recorded format-6 Network replay should reproduce the recorded
authoritative command history through the Network replay harness.

The replay header contains the canonical `match_player_control_binding` with two
distinct HUMAN principals mapped to gameplay players 0 and 1.

During replay, commands recorded for either player should therefore progress
through the supported Network replay path without failing because the replay
transport lacks the transient principal association required for that recorded
player.

In particular, after Player 0 completes the first ship activation, the recorded
Player 1 command

sequence 13: `reveal_dial`

should execute and replay should continue with the remaining recorded command
history.

Live Network principal authorization must remain enforced; replay must not
require weakening or bypassing that authorization globally.

## Actual

The format-6 replay passes baseline-generator preflight and begins Network replay
successfully.

Commands through sequence 12 execute.

When replay reaches the recorded Player 1 `reveal_dial` at sequence 13, the host
rejects the submission because the submitting peer has no matching principal
association:

`Peer 928501659 has no matching principal association for [reveal_dial].`

The ReplayDriver then times out waiting for sequence 13 to execute:

`ReplayDriver: timeout waiting for command_executed (cursor=13, type=reveal_dial, is_local=false)`

The client also times out waiting for the same command progression:

`ReplayDriver: timeout waiting for command_executed (cursor=13, type=reveal_dial, is_local=true)`

Network baseline candidate generation therefore terminates with:

`Network replay failed: host=3 client=3`

The failure occurs before the previously identified later Network replay
divergence and prevents generation of the format-6 Network baseline candidate.

## Reproduction

Always with the captured replay candidate.

1. Record the supplied format-6 Network replay through normal application
   gameplay.

2. Run:

   `./scripts/generate_baseline_fixtures.sh --mode network --replay replay_20260818_124005_candidate-network.json`

3. Observe that preflight passes:
   - replay format: 6
   - trace format: 1

4. Replay executes sequences 0–12 successfully.

5. Player 0 completes its first ship activation.

6. Replay attempts sequence 13:
   - Player 1
   - `reveal_dial`
   - ship index 0

7. The host reports that the submitting peer has no matching principal
   association.

8. Sequence 13 does not execute.

9. Both ReplayDrivers time out and Network candidate generation fails with
   host=3 / client=3.

## Evidence

- `replay_20260818_124005_candidate-network.json`
- `host_20260818_124218.log`
- `client_20260818_124218.log`
- Network baseline-generator console output

The replay header contains a format-6 canonical
`match_player_control_binding` with two distinct HUMAN principals, one for each
gameplay player.

Relevant recorded command sequence:

- 5 Player 0 `reveal_dial`
- 6–12 Player 0 activation progression
- 13 Player 1 `reveal_dial`
- 14 Player 1 `convert_dial_to_token`
- subsequent Player 1 activation commands

Observed replay progression stops at sequence 13.

Host evidence:

`Peer 928501659 has no matching principal association for [reveal_dial].`

followed by:

`ReplayDriver: timeout waiting for command_executed (cursor=13, type=reveal_dial, is_local=false)`

Client evidence:

`ReplayDriver: timeout waiting for command_executed (cursor=13, type=reveal_dial, is_local=true)`

The replay candidate passes format-6 structural preflight and must not be edited,
reassigned, or have its principal binding changed to bypass the failure.

The evidence indicates a mismatch between Network replay command submission and
the transient peer-to-principal association required by principal authorization.
The exact root cause and correct lifecycle/ownership repair remain to be
established.

## Resolution

Root cause:
`NetworkCommandSubmitter.submit_replay()` reused the live Network submission
path. That path correctly requires a transient peer-to-principal association,
but the accepted replay boundary intentionally has no live peer entitlement for
the recorded principals. Consequently sequence 13 was rejected before command
execution.

Fix:
Replay submission now uses the dedicated replay-only RPC seam, gated by active
Network replay bootstrap, and executes the recorded command through the replay
follow-up path. The live Network submit path and principal authorization remain
unchanged.

Verification:
The unchanged captured format-6 Network replay executed sequence 13 and the
remaining history successfully. Candidate generation, guarded fixture
installation, and the authoritative Network verifier passed. The resulting
Network baseline hash is
`170ceb3e57b35db059a00e57415efb82441c3977bb9a7ada0cccc93b71063e2b`.

No later independent replay failure was observed in the approved baseline
workflow.
