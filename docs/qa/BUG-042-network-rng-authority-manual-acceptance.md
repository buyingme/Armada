# BUG-042 Network RNG Authority Manual Acceptance

Status: Pending Owner QA  
Save format: 6  
Protocol: 6  
Replay format: 9  
Builds: matching packaged macOS builds on two Macs

## Purpose

Confirm that fresh play, same-live load, fresh-session resume, and reconnect
keep random state and hidden damage information on the host while both players
observe the same public results and continue playing normally.

Do not attach unredacted saves, replay files, damage-deck contents, RNG state,
credentials, IP addresses, or player-identifying data to the QA evidence.

## Setup

1. Install the same candidate build on both Macs.
2. Start a two-human Network match on a trusted LAN.
3. Record the build identifier and which machine is host. Refer to players only
   as Host and Client in evidence.
4. Keep the game logs until every case below is complete.

## Acceptance Cases

### A. Fresh Network play

1. Begin a ship attack and exercise all four result contracts: roll dice,
   reroll an attack die, use a Concentrate Fire token reroll, and resolve both
   the RNG and long-range no-RNG evade-die branches.
2. Deal ordinary facedown damage, critical faceup damage, overlap damage,
   persistent damage, and Structural Damage. Exercise faceup and facedown
   repair, then destroy a unit and confirm cleanup occurs once.
3. Use a controlled QA fixture to exhaust the damage draw pile and cross a
   discard reshuffle boundary.
4. Confirm both boards show the same public dice, hull, shield, damage-count,
   effect, and destruction outcomes.
5. Confirm the Client never displays an opponent's facedown damage identity.

### B. Same-live save and load

1. Save after at least one random command and one damage operation.
2. Advance the match, then load that save while the original session remains
   connected.
3. Repeat a dice roll and damage operation.
4. Confirm both boards converge and input remains blocked only while the
   restored state is being installed and acknowledged.

### C. Fresh-session resume

1. Save or checkpoint, close both Network sessions, and create a new lobby.
2. Stage the save and explicitly assign both saved sides.
3. Confirm no board becomes playable before both restored views are installed
   and acknowledged.
4. Resume the next decision, then roll dice and apply damage.
5. Confirm both boards converge and no command stream stalls.
6. Export the new replay, rebuild the final state from it, and confirm a
   representative format-8 replay is rejected before any command applies.

### D. Reconnect to a live match

1. Disconnect the Client during an active match and wait for the Host to
   confirm the old association is gone.
2. Rejoin and explicitly assign the unoccupied side.
3. Confirm the reconnecting board is not playable before state installation
   and acknowledgement.
4. Continue through a random command and a hidden damage operation.
5. Confirm the ordered result stream advances and both boards converge.

### E. Authority save/load and failed-command rollback

1. From the Host, save after consuming RNG and damage cards, load the save, and
   cross a later damage reshuffle boundary.
2. With the controlled QA fixture, force a late damage-command failure, retry
   legally, and cross the same reshuffle boundary.
3. Compare both paths with uninterrupted controls and confirm the public state,
   host RNG/deck state, and replay rebuild remain deterministic.

### F. Live debug exclusion

1. On Host and Client, attempt to open the debug faceup-damage picker during
   live Network play.
2. Confirm it does not open, reveal availability, or submit a command.
3. Confirm the same debug tool still works in a local Hot-Seat debug session.

### G. BUG-035 focused regression

1. Complete the previously affected squadron attack/result acknowledgement
   flow after a Network restore.
2. Confirm the result modal closes, the next canonical decision appears, and
   neither player is left without a legal continuation.

## Evidence to Retain

- Pass/fail and brief notes for cases A–G.
- Redacted screenshots of each board after the same public result.
- Redacted log excerpts showing protocol 6, successful state acknowledgement,
  continued ordered result application, and no rejected result.
- Assigned sides plus redacted staging/install attempt and cursor transitions,
  demonstrating that installation acknowledgement precedes admission and board
  release.
- Projection-equivalence hashes after each tested sequence for both viewer
  assignments; never include the state payload itself.
- SHA-256 digests of the two generated replay files, without attaching their
  contents.
- Any reproduction steps for a failure, stopping before additional play could
  overwrite useful evidence.

## Owner Sign-off

Owner: ____________________  
Date: ____________________  
Result: Pass / Fail  
Notes: ____________________
