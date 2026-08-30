# BUG-040 — Network ship activation stalls after Crew Panic dial discard

Severity: High
Area: Ship activation / critical damage / Network
Layer: Gameplay interaction / projection / continuation

## Expected

When **Crew Panic** triggers before a ship reveals its command dial, the player may choose to discard that dial.

If the dial is discarded:

1. the dial is discarded authoritatively;
2. the ship does not reveal a dial that round;
3. the ship nevertheless enters its normal activation through the authoritative Ship Activation path;
4. the controlling player's gameplay UI presents the resulting activation state;
5. play continues through the remaining legal activation decisions.

The resulting authoritative activation must be recoverable consistently in Hot-Seat and Network play.

## Actual

In Network play, choosing the **discard dial** option for Crew Panic causes the client-side ship activation to stall.

The authoritative command history proceeds through the Crew Panic discard and activation commands, and canonical state records an active ship activation, but the client does not proceed into the usable ship activation interaction.

Gameplay therefore stalls.

## Reproduction

1. Start a Network game with two human players.
2. Give a ship controlled by the client a faceup **Crew Panic** damage card.
3. Reach that ship's activation.
4. When Crew Panic triggers, choose to **discard the command dial** rather than suffer damage.
5. Observe the client after the choice resolves.

### Actual

The ship's usable activation does not proceed on the client and gameplay stalls.

### Expected

The command dial is discarded without being revealed, and the ship proceeds into its normal activation with the remaining legal activation decisions presented to its controller.

## Evidence

### Annotation

`annotation_20260830_150123_001.json`

The captured state records the stalled Network interaction after the Crew Panic discard-dial choice.

At capture time:

- phase remains `SHIP`;
- the affected ship is not destroyed;
- the ship has canonical activation identity `ship-activation:22`;
- Squadron Command and Maneuver opportunities are initialized as `UNREACHED`;
- `interaction_flow` remains associated with player 1 and ship 0.

This indicates that canonical Ship Activation has been established even though the client does not successfully continue through its presentation/interaction path.

### Replay

`replay_20260830_150133.json`

The replay records the relevant authoritative sequence:

- `spend_dial`
  - player 1;
  - ship 0;
  - `mode: "discard"`.

followed by:

- `activate_ship`
  - player 1;
  - ship 0;
  - `reason: "crew_panic"`;
  - `skip_reveal: true`.

The evidence therefore does not currently support a diagnosis that Crew Panic fails to create the authoritative activation.

Instead, the observed failure occurs after or around recovery/projection of the resulting Network Ship Activation.

## Resolution

Root cause: TBD.

### Current diagnostic boundary

The evidence establishes that:

1. the Crew Panic discard choice reaches authoritative command processing;
2. the dial discard is represented authoritatively;
3. an authoritative `activate_ship` command follows;
4. canonical state contains a new ship activation identity;
5. Network client gameplay nevertheless stalls rather than exposing the usable activation.

The precise root cause is not yet established.

Investigation should compare the Crew Panic `skip_reveal` activation path with an ordinary Network ship activation and determine where the resulting canonical activation ceases to be correctly projected/recovered on the controlling client.

Do not introduce a Crew Panic-specific presentation state or alternative activation path. The resulting Ship Activation should use the same canonical activation ownership and recovery mechanisms as other ship activations.

Fix: TBD.

## Verification

BUG-040 may be accepted as resolved when:

1. In Network play, a client-controlled ship with Crew Panic can choose **discard dial**.
2. The selected dial is discarded authoritatively and is not revealed.
3. The ship receives its canonical activation identity.
4. The controlling client immediately receives the correct next Ship Activation interaction.
5. The player can proceed through the remaining legal activation steps and complete the activation normally.
6. The opposing peer observes the correct projected gameplay state.
7. The equivalent Crew Panic **suffer damage** branch continues to work.
8. Hot-Seat Crew Panic behavior remains correct.
9. Save/load/reconnect or decision-equivalent recovery does not strand the `skip_reveal` activation state.
10. Replay reproduces the authoritative command/state sequence correctly.
11. Ordinary Network ship activation without Crew Panic remains unaffected.

## Relationship to other issues

BUG-040 was discovered during manual verification of BUG-032 and BUG-039.

BUG-032 and BUG-039 were successfully verified in both Hot-Seat and Network play and can be closed independently.

BUG-040 is a separate defect concerning the Network continuation/projection of a Crew Panic activation after choosing to discard the command dial.
