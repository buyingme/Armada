

===== FILE: docs/qa/bugs/open/BUG-003/issue-cant-skip-after-commit.md =====

# BUG-003 — Attack Can Be Skipped After Commitment

Severity: High
Area: Attack Execution
Layer: Command Flow

## Expected

An attack may be skipped or cancelled only before it reaches its commitment point.

After the attack has been confirmed and dice have been rolled:

- the attack must continue through its remaining resolution steps;
- the Skip Attack action must no longer be projected;
- any attempted skip command must be rejected by the authoritative command flow.

## Actual

The player can still skip an attack after it has been confirmed and the attack dice have been rolled.

This allows an already committed attack with authoritative dice results to be abandoned before resolution is complete.

## Reproduction

1. Activate a squadron and select a legal target.
2. Confirm the attack.
3. Roll the attack dice.
4. Attempt to skip the attack during the attack-modification stage.

Result: The attack can still be skipped after dice have been rolled.

Frequency: Always

## Evidence

annotation_20260729_065933_002.json

The captured state shows:

- an active attack with ID attack:70;
- the attacker and defender already selected;
- obstruction resolved;
- four blue dice rolled;
- authoritative dice results present;
- attack stage attack_modify;
- interaction-flow step 18.

## Investigation Hint

The issue is visible after the attack transitions from pre_roll to attack_modify.

Inspect how the availability and authorization of the Skip Attack action are derived after dice results become authoritative.

## Resolution

Root cause:

Fix:

Verification:

- Confirm and roll dice for an attack.
- Verify that Skip Attack is no longer projected after the attack becomes committed.
- Verify that a skip command submitted during attack_modify is rejected.
- Verify that rejecting the command does not alter the attack state or dice results.
- Verify that the attack can continue through normal resolution.
- Verify the behavior for both ship and squadron attacks.

## Layer Definition

### Rules

Game mechanics or rules behave incorrectly.

### Command Flow

Commands, interactions, or game progression execute incorrectly, become unavailable, remain available when invalid, or occur in the wrong order.

### Projection

Displayed game information or available actions differ from the authoritative game state.

### Presentation

Visual elements, text, layout, or UI controls behave incorrectly without affecting the underlying game state.

### Architecture

The defect appears to originate from system ownership, lifecycle, or architectural responsibilities.

### Serialization

Save, load, reconnect, replay, or persisted game state behaves incorrectly.

### Networking

Remote synchronization, visibility, or multiplayer state differs from the authoritative game state.

### Performance

The game exhibits excessive loading time, poor responsiveness, frame drops, freezes, or resource issues.


===== FILE: docs/qa/bugs/open/BUG-004/issue-Command-Token-Not-Refreshed-After-Grand-Moff-Tarkin-Selection.md =====

# BUG-004 — Command Token Not Refreshed After Grand Moff Tarkin Selection

Severity: Medium
Area: Grand Moff Tarkin
Layer: Projection

## Expected

After selecting a command token with Grand Moff Tarkin, the selected command token should immediately appear on the affected ship.

## Actual

The selected command token is correctly stored in the authoritative game state, but it is not immediately displayed in the UI.

The command token only becomes visible after an unrelated interaction causes the ship card to refresh (for example, enlarging and closing the ship card).

## Reproduction

1. Trigger the Grand Moff Tarkin command selection.
2. Choose a command token.
3. Observe the ship card.
4. Enlarge and close the ship card.

Result:
The command token only appears after the manual refresh.

Frequency: Always

## Evidence

annotation_20260730_064931_002.json

The captured state shows:

- Grand Moff Tarkin command selection has completed;
- the selected command token is already stored on the Imperial ship;
- `last_ship_phase_choice` has been recorded;
- the interaction has returned to the normal Ship Phase;
- the UI has not refreshed to display the updated command token.

20260814: manual retesting confirms that bug is still present. hot-set has been tested.
game_20260814_122718.log
replay_20260814_122914.json
annotation_20260814_122857_001.json

## Resolution

Root cause:

Fix:

Verification:

- Select a command token using Grand Moff Tarkin.
- Verify that the command token becomes visible immediately.
- Verify that no manual UI refresh is required.
- Verify reconnect, save/load, and repeated Tarkin activations continue to display the correct token.


===== FILE: docs/qa/bugs/open/BUG-006/issue-destroyed-squadrons-reappear-after-loading-a-save.md =====

# BUG-006 — Destroyed Squadrons Reappear After Loading a Save

Severity: High
Area: Save Loading / Board Projection
Layer: Projection

## Expected

When a saved or seed game is loaded, squadrons marked as destroyed must not appear on the active game board.

Their destroyed state may remain in the authoritative save data for scoring, history, or replay purposes, but they must not be instantiated as active board pieces or presented as selectable game entities.

This behavior must be consistent in both hot-seat and network play.

## Actual

Squadrons destroyed before the save was created reappear on the board when that save is loaded.

They are displayed at the positions where they were destroyed, even though the loaded game state marks them as destroyed with zero remaining hull.

The issue occurs in both hot-seat and network play.

## Reproduction

### Hot-seat

1. Start or continue a hot-seat game.
2. Destroy one or more squadrons.
3. Create a save after the squadrons have been destroyed.
4. Load the save as a seed or continued game.
5. Inspect the positions where the squadrons were destroyed.

Result:
The destroyed squadrons appear again at their final board positions.

### Network

1. Start or continue a network game.
2. Destroy a squadron.
3. Create a save after the squadron has been destroyed.
4. Load the save as a seed or continued network game.
5. Inspect the position where the squadron was destroyed.

Result:
The destroyed squadron appears again at its final board position.

Frequency: Always

## Evidence

NEWLearningScenario_HotSeat_R3_Ship.json

The hot-seat save contains two destroyed X-wing squadrons:

- player 0, squadron index 2:
  - current_hull: 0
  - destroyed: true
  - position approximately (0.5692, 0.4962)
- player 0, squadron index 3:
  - current_hull: 0
  - destroyed: true
  - position approximately (0.5316, 0.4996)

NEW_LearningScenario_Network_R3_Ship.json

The network save contains one destroyed TIE fighter squadron:

- player 1, squadron index 3:
  - current_hull: 0
  - destroyed: true
  - position approximately (0.5232, 0.4042)

Both saves were created during Round 3 of the Ship Phase, after the affected squadrons had already been destroyed.

The persisted state correctly records the squadrons as destroyed. The defect is that loading the state causes them to be displayed again on the active board.

## Resolution

Root cause:

Fix:

Verification:

- Load the provided hot-seat save.
- Verify that both destroyed X-wing squadrons remain absent from the board.
- Load the provided network save.
- Verify that the destroyed TIE fighter squadron remains absent from the board.
- Verify that surviving squadrons are still instantiated at their saved positions.
- Verify that destroyed squadrons are not selectable, targetable, movable, or included in active interaction projections.
- Verify that destroyed squadrons remain available where required for scoring, history, replay, or other authoritative state uses.
- Verify the behavior for both host and remote network clients.
- Save and reload a game containing newly destroyed squadrons and verify that they do not reappear.
- Verify that ships or other destroyed entity types are not affected by the same load-projection defect.

## Layer Definition

### Rules

Game mechanics or rules behave incorrectly.

### Command Flow

Commands, interactions, or game progression execute incorrectly, become unavailable, or occur in the wrong order.

### Projection

Displayed game information differs from the authoritative game state.

### Presentation

Visual elements, text, layout, or UI controls behave incorrectly without affecting the underlying game state.

### Architecture

The defect appears to originate from system ownership, lifecycle, or architectural responsibilities.

### Serialization

Save, load, reconnect, replay, or persisted game state behaves incorrectly.

### Networking

Remote synchronization, visibility, or multiplayer state differs from the authoritative game state.

### Performance

The game exhibits excessive loading time, poor responsiveness, frame drops, freezes, or resource issues.


===== FILE: docs/qa/bugs/open/BUG-013/issue-Stale-Attack-Modify-UI-remains-visible-after-successful-command-completion.md =====

# BUG-013 — Stale Attack Modify UI remains visible after successful command completion

Severity: Medium

Area: Attack Modify / Interaction Flow

Layer: Projection | Presentation

## Expected

After a player commits an Attack Modify choice (for example H9 Turbolasers):

- the authoritative semantic command is accepted;
- the authoritative game state changes;
- the updated attack pool is immediately projected to every relevant viewer;
- the active player (hot-seat) or both peers (network) see the updated attack result before any further interaction becomes available;
- the player has sufficient time to inspect the updated result before continuing.

The UI must never allow the next gameplay decision to be made from stale visual information.

## Actual

After committing an H9 die modification:

- the semantic command executes successfully;
- gameplay continues correctly;
- Accuracy assignment uses the modified authoritative die;
- however the displayed die face is not updated before the next interaction begins.

The player therefore performs the next decision while viewing stale attack dice.

## Reproduction

Often

1. Start the debug scenario containing H9 Turbolasers.
2. Begin a ship attack.
3. Roll attack dice.
4. Select **Use** for H9.
5. Select a legal die.
6. Observe the displayed attack pool.
7. Continue into Accuracy assignment.

The authoritative game state contains the modified die, but the displayed die still shows its previous face.

## Evidence

- annotation_20260806_121329_001.json
- replay_20260806_121343.json

The replay shows:

- `use_h9` executes successfully.
- `confirm_attack_dice` succeeds.
- `commit_accuracy` succeeds.
- The attack completes normally.

The replay therefore demonstrates that the authoritative command path is correct. The defect is confined to projection and presentation of the updated attack state.

## Resolution

### Root cause

Projection/presentation is not refreshed after an accepted Attack Modify semantic command.

The authoritative command mutates the canonical attack state correctly, but the updated projection is not shown before gameplay continues.

### Fix

After every accepted Attack Modify semantic command that changes information relevant to subsequent player decisions:

- immediately re-project the authoritative state;
- deliver the updated projection to every relevant viewer;
- display the updated attack result before allowing continuation.

This requirement applies generically to Attack Modify interactions (H9, Concentrate Fire, and future parameterized attack modifiers).

Gameplay ownership must remain unchanged:

- commands remain authoritative;
- projection remains derived;
- presentation remains non-authoritative.


### Verification

Verify that:

- H9 immediately displays the changed Accuracy die.
- Concentrate Fire immediately displays rerolled dice.
- Hot-seat active player sees the updated attack pool before continuing.
- Both network peers observe the same updated projection before continuation.
- Replay, reconnect, and save/load remain deterministic.
- No changes occur to command ownership, replay history, validation, or timing-window ownership.

## Additional Manual Smoke-Test Evidence

A later manual smoke test after the initial BUG-013 repair confirmed that the primary projection defect has been resolved:

- H9 die modifications are projected immediately after the semantic command is accepted.
- Concentrate Fire reroll results are projected before gameplay continues.
- The authoritative game state and displayed dice remain synchronized.

However, one remaining presentation defect was observed.

annotation_20260806_142147_001.json
replay_20260806_142212.json

### Remaining issue

After H9 has been resolved and gameplay has advanced into the Defense step, the UI may still display the stale instruction:

> "Select an eligible die for Upgrade H9 Turbolasers"

At this point:

- the H9 semantic command has already completed successfully;
- the Timing Window has already continued correctly;
- no further H9 interaction is available;
- gameplay is already in the Defense stage.

This stale instruction is presentation-only.

The replay and authoritative game state continue correctly, and no duplicate H9 command can be submitted.

### Updated Scope

BUG-013 is therefore reduced to a presentation lifecycle issue.

The remaining repair is limited to ensuring that transient Attack Modify interaction prompts are dismissed immediately after successful command acceptance and are never shown after gameplay has advanced beyond the corresponding interaction.

No additional command, validation, replay, networking, timing-window, or gameplay changes are required.

## Additional Design Requirement

Attack Modify interactions shall follow this interaction model:

1. The player selects **Use** or **Decline**.
2. Choosing **Use** performs **no authoritative gameplay change**.
3. Any required parameters (such as die selection) are collected locally.
4. The final parameter selection is the player's explicit commitment.
5. That commitment submits exactly one complete semantic command.
6. After the command is accepted, the updated authoritative state must be projected and displayed before further interaction becomes available.
7. Only after the player has seen the updated result may gameplay continue.

This interaction model shall be applied consistently to all current and future parameterized Attack Modify effects.


===== FILE: docs/qa/bugs/open/BUG-016/issue-Defense-token-confirmation-sometimes-requires-multiple-clicks.md =====

# BUG-016 — Defense token confirmation sometimes requires multiple clicks

Severity: Low
Area: Ship Combat – Defense Token Resolution
Layer: Presentation | Command Flow

## Expected

When the defending player confirms defense token usage, the interaction should be accepted immediately after a single valid input and the attack sequence should continue without additional user interaction.

## Actual

During one network playtest, confirming defense token usage on the CR90 required several repeated clicks before the command was accepted. The attack sequence eventually continued successfully without becoming stuck.

The issue occurred once during the first playthrough after the H9 integration. It could not be reproduced during a subsequent test using the same scenario.

## Reproduction

Once

No reliable reproduction steps are currently known.

Observed during:
- Network play
- First gameplay after H9 integration
- CR90 defending against a Victory II-class Star Destroyer attack
- ECM interaction active

## Evidence

- annotation.json
- replay_20260807_103712.json
- replay_20260807_112425.json

The annotation captures the interaction while the attack is in the defense stage with ECM authorization active. The replay of the affected session and a subsequent successful replay have both been preserved for later comparison.

## Resolution

Root cause: Unknown.

Potential areas for investigation:
- Duplicate or delayed UI input handling.
- Interaction flow synchronization.
- Defense token confirmation command processing.
- Network timing or projector refresh timing during ECM-enabled defense resolution.

Fix: Pending investigation.

Verification:
- Reproduce the issue under identical network conditions.
- Verify that a single confirmation click always submits the defense token command.
- Execute multiple network playthroughs including ECM-enabled defense token resolution without repeated input requirements.


===== FILE: docs/qa/bugs/open/BUG-019/issue-Ship-damage-display-does-not-refresh-immediately-after-collision-damage.md =====

# BUG-019 — Ship damage display does not refresh immediately after collision damage

Severity: Low
Area: Ship UI / Damage Display
Layer: Presentation

## Expected

When a ship receives damage cards from a collision, the ship UI should immediately update to reflect the new damage state.

The displayed damage-card count/state should remain synchronized with the authoritative game state without requiring any additional UI interaction.

## Actual

After collision damage is applied, the authoritative game state contains the new damage card, but the ship UI does not immediately refresh.

The correct damage display appears only after magnifying/opening the ship card.

The issue is present on both host and client.

## Reproduction

Once

Observed sequence:

1. Cause a ship to receive damage from a collision.
2. Observe the ship UI after the damage is applied.
3. The newly dealt damage card is not reflected immediately.
4. Magnify/open the ship card.
5. The UI refreshes and then shows the correct damage state.

## Evidence

- `annotation_20260812_210816_001.json`
- `client_20260812_210323.log`

The captured authoritative state already contains the newly dealt facedown damage card, indicating that the underlying game state is correct and the defect is limited to UI refresh/presentation.

## Resolution

Root cause:
TBD

Fix:
TBD

Verification:
Reproduce collision damage and verify that the ship UI refreshes immediately on both host and client without requiring the ship card to be magnified or reopened.


===== FILE: docs/qa/bugs/open/BUG-020/issue-Network-replay-diverges-during-second-Command-Phase.md =====

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


===== FILE: docs/qa/bugs/open/BUG-021/issue-Grand-Moff-Tarkin-modal-drifts-off-center-in-later-rounds.md =====

# BUG-021 — Grand Moff Tarkin modal drifts off-center in later rounds

Severity: Low
Area: Modal UI / Grand Moff Tarkin
Layer: Presentation

## Expected

The Grand Moff Tarkin choice modal should appear centered consistently whenever it is opened.

Its position should remain stable across rounds and repeated openings.

Other modal dialogs should likewise retain their intended screen position when reopened.

## Actual

The Grand Moff Tarkin modal appears off-center.

In subsequent rounds, the modal moves progressively farther to the right side of the screen.

The underlying Grand Moff Tarkin interaction remains active and usable; the observed defect concerns the modal position/presentation.

It is currently unclear whether this is specific to the Grand Moff Tarkin modal or a more general modal-positioning issue.

## Reproduction

Once

Observed sequence:

1. Start a game with Grand Moff Tarkin.
2. Reach the Ship Phase and open the Tarkin command-choice modal.
3. Continue into later rounds.
4. Observe the Tarkin modal when it opens again.
5. The modal is no longer centered and appears progressively shifted to the right.

## Evidence

- `annotation_20260814_113440_001.json`

The captured state shows the Grand Moff Tarkin choice interaction active in round 2 for Player 1, while the reported defect concerns only the modal's screen position.

## Resolution

Root cause:
TBD

Fix:
TBD

Verification:
Open the Grand Moff Tarkin modal repeatedly across multiple rounds and verify that it remains centered each time.

Also check other reusable modal dialogs to determine whether the same position drift occurs more generally.


===== FILE: docs/qa/bugs/open/BUG-022/issue-ship-Squadron-Command-stalls-after-commanded-squadron-has-no-attack-target.md =====

# BUG-022 — Ship Squadron Command stalls after commanded squadron has no attack target

Severity: High
Area: Ship Squadron Command / Squadron Activation
Layer: Command Flow

## Expected

When a squadron is activated through a ship's Squadron command and moves but has no legal attack target:

1. the unused attack action must be resolved through the appropriate authoritative semantic path;
2. the squadron activation must complete only after its canonical action state is complete;
3. if additional Squadron-command activations remain, the player must be able to activate the next eligible squadron;
4. only after the Squadron command is legitimately complete may the command dial/token be spent and the ship activation advance to the next step.

Presentation must wait for accepted canonical transitions and must not end the Squadron command after a rejected completion command.

## Actual

After a squadron activated through a ship's Squadron command moves and has no legal attack target, the modal attempts to auto-finish the squadron activation.

`CompleteSquadronActivationCommand` is correctly rejected because the squadron still has an available attack action.

Despite that rejection, presentation continues as though the squadron or Squadron command has completed.

Depending on the interaction sequence:

- the next eligible commanded squadron cannot be activated; or
- the Squadron command is ended prematurely;
- the command dial is spent;
- the ship activation attempts to advance to Repair;
- that `advance_activation_step` command is then rejected because declaration-adjacent canonical state is still invalid.

The game becomes stalled because the canonical ship/squadron activation remains incomplete while the UI required to continue it is no longer available.

## Reproduction

Reproduced twice.

### Reproduction 1

1. Activate the Nebulon-B Escort Frigate.
2. Resolve a Squadron command.
3. Activate and resolve the first commanded X-wing.
4. Activate a second commanded X-wing.
5. Move the squadron to a position with no legal attack target.
6. Allow the modal to process the no-target state.

Result:

- the activation modal disappears / progression becomes unusable;
- the game does not proceed correctly;
- the next required ship-activation interaction is unavailable.

### Reproduction 2

1. Activate the Nebulon-B and enter its Squadron command.
2. Activate a commanded X-wing.
3. Move it where no legal attack target is available.
4. Observe the automatic completion attempt.
5. Attempt to continue or end the Squadron command.

Result:

- squadron completion is rejected because an attack action remains canonically available;
- the modal can nevertheless proceed toward ending the Squadron command;
- the ship activation then stalls.

## Evidence

- `annotation_20260814_125821_001.json`
- `annotation_20260814_132727_001.json`
- `game_20260814_125441.log`
- `game_20260814_132516.log`
- `replay_20260814_125834.json`

### Canonical-state evidence

At the first captured stalled state:

- Ship Phase is active.
- Nebulon-B has:
  - active `ship_activation_identity`;
  - `squadron_command_opportunity_disposition = "OPEN"`;
  - `squadron_command_activations_committed = 2`;
  - Maneuver remains `UNREACHED`.
- The second commanded X-wing has:
  - `activation_context = "ship_squadron_command"`;
  - active squadron activation identity;
  - `move_action_committed = true`;
  - `attack_action_disposition = "available"`;
  - `activated_this_round = false`.

The canonical state therefore still represents an incomplete commanded-squadron activation even though the presentation required to continue it has disappeared.

The second reproduction captures the same basic state with one committed Squadron-command activation and an active second squadron whose movement is committed but attack action remains available.

### Log evidence

The production log exposes the failing sequence:

`No targets after move — auto-finishing activation.`

followed by:

`Command rejected [complete_squadron_activation]: Squadron still has an available action.`

In one reproduction presentation then continues with:

- Squadron command finalized;
- `spend_dial` accepted;
- Squadron command signals completion;
- ship activation advances locally toward Repair;
- authoritative `advance_activation_step` rejects with:
  `Declaration-adjacent state is invalid.`

This demonstrates that presentation progresses after a failed semantic completion rather than waiting for an accepted canonical result.

### Replay evidence

The replay records:

- sequence 74 — `activate_squadron`
- sequence 75 — `move_squadron`
- sequence 76 — `spend_dial`

There is no accepted `skip_attack` or `complete_squadron_activation` between movement of the second squadron and spending the Squadron dial.

The recorded command history therefore confirms that the commanded squadron's remaining attack action was never semantically resolved before the Squadron command was treated as complete.

## Initial Assessment

The immediate failing behavior appears to be the commanded-squadron equivalent of a pre-Begin/no-target declaration exit problem.

After movement with no legal attack target, presentation attempts to complete the squadron directly even though canonical state still contains an available attack action.

The correct semantic path likely needs to resolve/decline that remaining attack opportunity before squadron completion, rather than weakening `CompleteSquadronActivationCommand`.

A second defect may be present in the presentation lifecycle: after the completion command is rejected, the modal still progresses toward Squadron-command completion and can spend the dial / request the next ship activation step.

Do not assume these are separate root causes until the complete command/result path has been investigated.

## Relationship to BUG-018

BUG-022 is closely related conceptually to BUG-018 but occurs in a different gameplay context.

BUG-018 repaired pre-Begin Skip during Squadron Phase.

BUG-022 occurs during `ship_squadron_command` activation and additionally demonstrates premature Squadron-command completion/dial spending after an unsuccessful squadron-completion transition.

Track it separately unless investigation proves that the exact same production defect remains incompletely generalized.

## Resolution

Root cause:
TBD

Fix:
TBD

## Verification

After repair, verify:

- a commanded squadron that moves and has no legal attack target resolves its unused attack opportunity through an accepted semantic command;
- `CompleteSquadronActivationCommand` is not weakened to accept incomplete canonical action state;
- after the first commanded squadron completes, another eligible commanded squadron can be activated when command capacity remains;
- after the final commanded squadron completes, the Squadron command closes exactly once;
- the Squadron dial/token is spent only after valid command completion;
- the ship then advances canonically to the next activation step;
- a rejected squadron command cannot cause optimistic modal progression or dial spending;
- ship-commanded squadrons that do have legal attack targets remain able to attack normally;
- early voluntary termination of the Squadron command remains valid where allowed;
- Hot-Seat and Network behavior are equivalent;
- replay records the complete semantic progression;
- save/load and reconnect preserve any active commanded-squadron activation correctly.


===== FILE: docs/qa/bugs/open/BUG-023/issue-legal-squadron-attack-target-is-not-offered-during-Squadron-Phase.md =====

# BUG-023 — Legal distance-1 squadron attack target is not offered during Squadron Phase

Severity: High
Area: Squadron Phase / Targeting
Layer: Projection / Command Flow

## Expected

When a squadron is activated during the Squadron Phase and has a legal target at **distance 1**:

1. the legal target must be detected by the production targeting logic;
2. the squadron activation UI must present the Attack option;
3. the player must be able to select the legal target and begin the attack;
4. Move and Attack availability must reflect the squadron's canonical action state and the same distance-1 targeting rules used by command validation.

Important rule distinction:

**Squadron attacks are legal only at distance 1.**

This must not be treated as equivalent to the ship-attack range band `close`. A target may be at close range while still being at distance 2 and therefore illegal for a squadron attack.

## Actual

A TIE Fighter Squadron is activated during the Squadron Phase.

The production targeting diagnostics identify a hull zone of the Nebulon-B Escort Frigate at:

- `distance = 1`
- `range = close`

and explicitly accept it as a valid target:

`-> HIT ship 'Nebulon-B Escort Frigate' zone=FRONT`

However, the Squadron Phase controller subsequently reports:

`can_move=true, targets=false`

and the activation UI offers only movement.

The player therefore cannot begin an otherwise legal distance-1 squadron attack.

## Reproduction

Observed once.

1. Reach the Squadron Phase.
2. Activate the TIE Fighter Squadron shown in the evidence.
3. The Nebulon-B Escort Frigate has at least one hull zone at distance 1.
4. Observe the available squadron actions.

Result:

- production targeting identifies a valid distance-1 target;
- the Squadron Phase activation UI reports no attack targets;
- Attack cannot be selected.

## Evidence

- `annotation_20260814_130328_001.json`
- `game_20260814_130128.log`

### Canonical-state evidence

At the captured state:

- phase = Squadron Phase;
- controller = Player 1;
- active squadron is a TIE Fighter Squadron;
- `activation_context = "squadron_phase"`;
- `attack_action_disposition = "available"`;
- `move_action_committed = false`;
- `activated_this_round = false`.

The canonical action state therefore still permits the squadron to perform an attack if a legal distance-1 target exists.

### Production targeting evidence

For the relevant TIE Fighter, the log records:

Nebulon-B FRONT:

- distance ≈ 82 px
- `distance=1`
- `range=close`
- accepted:
  `-> HIT ship 'Nebulon-B Escort Frigate' zone=FRONT`

Other hull zones demonstrate why `close` must not be used as the squadron legality criterion.

For example, Nebulon-B REAR is reported as:

- `distance=2`
- `range=close`

This is still close range in ship-range terminology, but it is **not legal squadron attack distance**.

Despite the valid FRONT distance-1 target, the Squadron Phase controller then reports:

`Squadron overlay shown for tie_fighter_squadron (can_move=true, targets=false).`

This demonstrates a mismatch between legal distance-1 target discovery and the action availability projected to the player.

### Attack Simulator evidence

The Attack Simulator visually identifies the Nebulon-B as being at `close` range.

This is supporting geometrical evidence only.

It must **not** be used as proof of squadron attack legality unless the simulator also evaluates the explicit distance-1 rule. `close` and `distance 1` are not interchangeable.

The simulator should itself be reviewed to ensure that squadron attack planning communicates and applies distance-1 legality rather than ship-style close-range legality.

## Initial Assessment

The evidence suggests a mismatch between production distance-1 target discovery and the Squadron Phase action-availability projection.

The targeting diagnostics clearly distinguish:

- discrete squadron attack distance (`distance=1`, `distance=2`, etc.);
- ship-style range bands (`close`, `medium`, `long`).

The repair must preserve this distinction.

Potential investigation areas include:

- whether Squadron Phase target availability accidentally filters by `range == close` instead of `distance == 1`;
- whether valid distance-1 ship hull-zone results are lost when converting targeting-builder results into squadron activation targets;
- whether different consumers use inconsistent range representations;
- whether the Attack Simulator applies ship-style range-band logic to squadron attacks.

## Relationship to BUG-005

BUG-023 is closely related to the same range-model distinction addressed by BUG-005.

BUG-005 concerned squadron attacks being allowed beyond distance 1 because close-range classification was used too broadly.

BUG-023 concerns a legal distance-1 target being omitted from normal Squadron Phase attack availability.

Investigation should explicitly audit all squadron attack consumers to ensure they use **distance 1**, not generic `close` range, as the legality criterion.

Do not assume BUG-005 is fully unrelated merely because its direct regression tests pass; BUG-023 may expose another consumer of the old range-band model.

## Resolution

Root cause:
TBD

Fix:
TBD

## Verification

After repair, verify explicitly:

- squadron → ship attack is available at distance 1;
- squadron → squadron attack is available at distance 1;
- distance 2 is rejected even when ship-style range is `close`;
- all greater distances are rejected;
- normal Squadron Phase projection and BeginAttack validation use the same distance-1 predicate;
- commanded-squadron attacks use the same predicate;
- Attack Simulator uses or clearly displays the same squadron distance-1 legality;
- moving a squadron causes target availability to be re-derived correctly;
- Hot-Seat and Network produce equivalent legal-target availability.


===== FILE: docs/qa/bugs/open/BUG-024/issues-hip-activation-stalls-after-skipping-remaining-attack-and-opening-Maneuver.md =====

# BUG-024 — Ship activation stalls after skipping remaining attack and opening Maneuver

Severity: High
Area: Ship Activation / Attack → Maneuver
Layer: Command Flow / Projection

## Expected

After a ship completes one attack and then legitimately skips its remaining attack opportunity:

1. the Attack step must end canonically;
2. the Maneuver opportunity must open;
3. the ship activation presentation must advance to Maneuver;
4. the Maneuver tool / controls must become available;
5. after executing the Maneuver, the ship activation must be able to complete normally.

The UI must derive the next step from the accepted canonical activation state and must not lose the active ship context after a successful Skip.

## Actual

During CR90 activation:

1. the first attack completes successfully;
2. the player proceeds to a possible second attack;
3. an attempted second target is rejected as illegal;
4. the player then skips the remaining attack opportunity;
5. `SkipAttackCommand` is accepted;
6. canonical state opens the Maneuver opportunity;
7. the Attack Executor closes;
8. the ship activation does not present the Maneuver step.

The game stalls.

The CR90 remains the active ship activation, so clicking the ship's dial again is rejected as not eligible, but no usable Maneuver interaction is available to continue the activation.

## Reproduction

Observed once.

1. Activate the CR90 Corvette A.
2. Complete one legal attack.
3. Proceed to the remaining attack opportunity.
4. Attempt/select another target if available.
5. Skip the remaining attack opportunity.
6. Observe the ship activation after Skip is accepted.

Result:

- Attack UI closes;
- Maneuver does not become usable/visible;
- ship remains canonically active;
- game cannot continue normally.

## Evidence

- `annotation_20260814_133210_001.json`
- `game_20260814_132858.log`

### Canonical-state evidence

At the captured stalled state:

- phase = Ship Phase;
- `current_attack_state.active = false`;
- CR90:
  - `ship_activation_identity = "ship-activation:242"`;
  - `committed_attack_count = 1`;
  - `attack_step_active = false`;
  - `squadron_command_opportunity_disposition = "CONSUMED"`;
  - `maneuver_opportunity_disposition = "OPEN"`;
  - `activated_this_round = false`.

This is consistent with an active ship activation that has completed/skipped Attack and is now canonically waiting for Maneuver.

However:

- `interaction_flow` is inactive;
- no Maneuver interaction is available.

The authoritative activation state and presentation are therefore out of sync.

### Log evidence

The relevant production sequence is:

- first attack already committed;
- later second `begin_attack` attempt rejects:
  `Attack target is not legal from authoritative board state.`
- player selects Skip;
- `SkipAttackCommand` executes successfully;
- ship Attack step changes from active to inactive;
- Attack Executor reports:
  `Attack execution done — completing attack step.`
- Attack Executor is dismissed;
- Ship activation reports:
  `Attack exec completed — advancing activation step.`

No accepted Maneuver-opening/continuation presentation follows.

Later attempts to interact with the CR90 dial report:

`not eligible (... activating=true)`

confirming that the application still considers the CR90 activation active even though its continuation UI is missing.

## Initial Assessment

The semantic Skip appears to be correct.

The canonical `ShipInstance` state already contains the expected post-Skip result:

`maneuver_opportunity_disposition = "OPEN"`

The defect therefore appears to be in the continuation/projection from accepted post-Skip activation state into the Maneuver presentation.

Potential investigation areas include:

- post-`SkipAttackCommand` continuation handling;
- `AttackExecutor` completion callback;
- `ShipActivationController` reconstruction/advancement after Attack Executor dismissal;
- differences between:
  - skipping Attack before any attack;
  - completing one attack and skipping the second opportunity;
  - completing all available attacks normally;
- stale/transient activation step state after an unsuccessful second Begin attempt.

Do not repair by mutating canonical ship activation state from the scene/controller. Maneuver must remain derived from the accepted `ShipInstance` activation boundary.

## Relationship to existing issues

BUG-024 is related to BUG-003 but represents a different failure mode.

BUG-003 concerns the legality/presentation of Skip after attack commitment.

BUG-024 concerns failure to continue into Maneuver after a legitimate Skip has already been accepted and the canonical Maneuver opportunity is OPEN.

Keep separate unless investigation proves a common root cause.

## Resolution

Root cause:
TBD

Fix:
TBD

## Verification

After repair, verify:

- ship with no attack performed can skip Attack and reach Maneuver correctly;
- ship can complete one attack, skip its remaining attack opportunity, and reach Maneuver;
- completing all available attacks normally reaches Maneuver;
- a rejected second `BeginAttack` followed by a legal Skip does not lose activation context;
- Maneuver is projected only when canonical `maneuver_opportunity_disposition == OPEN`;
- executing Maneuver consumes the opportunity;
- End Activation succeeds afterward;
- presentation does not synthesize semantic progression;
- Hot-Seat and Network behave equivalently;
- replay reproduces the same progression;
- save/load and reconnect during the post-Skip Maneuver boundary reconstruct the Maneuver interaction correctly.


===== FILE: docs/qa/bugs/verify/BUG-011/issue-network-replay-rng-bootstrap-repair-plan.md =====

# BUG-011 — Network Replay RNG Bootstrap Repair Plan

Status: Accepted
Accepted by: Project Owner
Accepted date: 2026-08-05

Classification: Networking / Serialization / Replay

Confirmed root cause: `NETWORK REPLAY RNG BOOTSTRAP DEFECT`

Authority:

- ADR-001
- ADR-003
- ADR-005
- CON-001
- TWI-002

Supporting implementation evidence:

- TWI-002 Remaining Implementation Execution Map
- Replay Baseline Workflow
- Accepted network replay RNG bootstrap investigation report
- Current replay, lobby, network configuration, game bootstrap, RNG, and
  baseline-verification implementation

This document is a bounded implementation repair specification. It is not an
ADR, Contract, Migration Assessment, implementation workbook, or replacement
for TWI-002. It does not authorize implementation before Owner acceptance.

## 1. Status And Purpose

The purpose of this plan is to define the smallest repair that makes a format-3
network replay reconstruct the match RNG from its recorded replay header.

The repair covers only the bootstrap transaction that selects the replay seed,
distributes it to both network peers, and constructs both peers' initial
`GameState.rng`. Its boundary ends before normal game initialization and replay
command execution continue.

The existing network replay fixture is evidence for this repair. The fixture is
not to be edited, converted, or regenerated to make the repair pass.

## 2. Confirmed Root Cause

The confirmed root cause is:

> NETWORK REPLAY RNG BOOTSTRAP DEFECT

The authoritative recording path writes the match RNG seed from
`GameState.rng.initial_seed` into the format-3 replay header. `GameReplay`
loads that exact recorded value, and `ReplayDriver` stores it in
`pending_replay_seed`.

Network replay then enters the ordinary lobby start path. That path currently:

1. generates a new time-derived seed in `LobbyManager.request_start_game()`;
2. distributes the new seed through the existing network game configuration;
3. causes `GameManager.bootstrap_game()` on both peers to construct the match
   from the distributed lobby seed; and
4. ignores `ReplayDriver.pending_replay_seed` because the replay is running in
   network mode.

The new lobby seed therefore replaces the replay-header seed before canonical
game initialization. Setup-time RNG consumption and later command-time RNG
consumption then proceed from a different sequence than the recorded match.
`RollDiceCommand` correctly generates canonical dice from `GameState.rng`, and
`CommitAccuracyCommand` correctly validates against canonical
`CurrentAttackState.dice_results`; neither command is the source of the defect.

The current format-3 network replay demonstrates the resulting failure. Its
recorded sequence 77 projects one Accuracy result and sequence 80 legally locks
one defense token. Replay execution regenerates different canonical dice, so
sequence 80 is rejected with `Too many Accuracy lock targets.` The subsequent
`ReplayDriver` timeout is a downstream consequence of the rejected command.

## 3. Scope

This repair includes only:

- format-3 network replay bootstrap;
- the exact replay-header RNG seed already accepted by `GameReplay`;
- replay bootstrap coordination by `ReplayDriver`;
- host selection of the seed used for the replay lobby start;
- propagation of that seed to host and client through the existing network
  game-configuration path;
- validation that both peers received the accepted replay seed;
- construction of both peers' initial `GameState.rng` from that seed;
- deterministic consumption or clearing of replay-bootstrap seed state;
- focused failure behavior before game initialization or replay command
  execution can proceed; and
- focused automated and manual regression evidence.

The repair is complete at the first boundary where both peers have installed
the replay-header seed as the initial state of their authoritative runtime RNG.
Normal setup, damage-deck initialization, command execution, dice generation,
projection, and replay exhaustion then continue through their existing paths.

## 4. Explicit Exclusions

The repair does not include:

- dice-command changes;
- Accuracy validation changes;
- `CurrentAttackState` changes;
- replay command or replay payload changes;
- replay format changes or conversion;
- trace format changes;
- baseline generator or verifier redesign;
- editing or regenerating the existing failing replay;
- normal non-replay network game seed-generation changes;
- save/load network bootstrap or BUG-001;
- timing-window, Concentrate Fire, H9, or other TWI-002 semantic changes;
- production activation, save-version, or replay-version advancement;
- BUG-010 or targeting behavior;
- network-session, transport, RPC, ordering, retry, or lobby redesign;
- a new RNG owner, replay owner, network protocol, compatibility layer, feature
  flag, or temporary bridge; and
- general replay cleanup unrelated to the confirmed bootstrap boundary.

## 5. Accepted Ownership

| Responsibility | Accepted owner or boundary |
| --- | --- |
| Recorded seed value used to reconstruct a replay | The accepted `GameReplay` header |
| Replay startup coordination and one-shot bootstrap seed state | `ReplayDriver`; it does not own gameplay RNG |
| Selection of the seed supplied at host lobby start | Existing lobby bootstrap, using fresh generation for live games and the accepted header value for network replay |
| Distribution of the host-selected seed | Existing `NetworkManager` game-configuration path |
| Authoritative runtime RNG and its evolving state | `GameState.rng` |
| Deterministic gameplay RNG consumption | Existing commands and deterministic setup/resolver paths reading `GameState.rng` |

The host and client must begin replay reconstruction with identical
`GameState.rng` initial seed and state. Neither peer, projection, scene, UI, nor
replay command payload becomes an alternative RNG authority.

Normal live network games continue to use the existing fresh, host-selected
lobby seed. The replay-header seed is authoritative only for reconstruction of
the replay that carries it.

## 6. Intended Transaction

### 6.1 Normal Network Game

For a network game with no active replay:

1. `LobbyManager` generates the existing fresh time-derived seed.
2. The host distributes that seed through the existing game configuration.
3. Both peers construct `GameState.rng` from the distributed seed.
4. No replay-bootstrap state participates.

This behavior remains unchanged.

### 6.2 Network Replay

For a network replay:

1. `GameReplay` accepts the replay and exposes its exact header seed before the
   lobby start is requested.
2. `ReplayDriver` establishes that value as the pending one-shot replay
   bootstrap input on each peer.
3. The host lobby start selects that accepted replay seed. It does not generate,
   substitute, or fall back to a fresh seed.
4. The host distributes the selected seed to both peers through the existing
   game-configuration path before scene transition and game initialization.
5. Each peer verifies that the received configuration contains the same valid
   seed as its accepted replay header. Missing, zero/fallback, or mismatched
   replay bootstrap input fails closed.
6. Each peer constructs its initial `GameState.rng` from the accepted seed
   before any setup-time RNG consumer or replay command can run.
7. Each peer consumes or clears its pending replay-bootstrap seed state exactly
   once after successful installation.
8. Existing initialization and command execution continue without another RNG
   construction, randomization, or reset.

The transaction is successful only when both peers enter normal initialization
from the same accepted seed. A peer may not continue independently with a
fallback seed.

## 7. Likely Repository Change Surface

The smallest likely production surface is:

| File or seam | Bounded responsibility in this repair |
| --- | --- |
| `src/autoload/replay_driver.gd` | Coordinate the accepted replay-header seed as one-shot network replay bootstrap input and expose deterministic success/failure state. |
| `src/autoload/lobby_manager.gd` | Select the accepted replay seed for a network replay host start while preserving fresh seed generation for every normal network start. |
| `src/autoload/game_manager.gd` | At the existing bootstrap boundary, reject missing/mismatched replay configuration, construct `GameState.rng` from the accepted network replay seed, and consume bootstrap state before initialization continues. |

Existing supporting seams expected to remain structurally unchanged:

- `src/autoload/network_manager.gd` already distributes one supplied seed to
  host and client through the accepted game-configuration path;
- `src/core/commands/game_replay.gd` already owns the format-3 replay header and
  exact seed decoding;
- `src/core/state/game_rng.gd` already constructs deterministic equal streams
  from equal non-zero seeds;
- `RollDiceCommand`, `CommitAccuracyCommand`, `CurrentAttackState`, and all
  dice/Accuracy calculation paths remain unchanged; and
- both baseline scripts and the network replay fixture remain unchanged.

Focused evidence is expected in the existing replay, lobby/bootstrap, network,
and RNG test layers. Exact test-file placement may follow existing repository
conventions, but the likely homes are:

- `tests/unit/test_replay_driver.gd`;
- the existing focused `LobbyManager` scenario/bootstrap tests;
- `tests/unit/test_network_manager.gd` for unchanged configuration propagation;
- the existing game-board/game bootstrap test surface;
- `tests/integration/test_network_transport.gd`; and
- the authoritative network baseline gate using the unchanged
  `tests/fixtures/baseline_traces/replay_network.json`.

Implementation stops if this behavior cannot be expressed through these
existing owners and the existing game-configuration path.

## 8. Atomicity And Failure Behavior

- The accepted seed selection, network distribution, peer validation, and
  initial `GameState.rng` construction form one bootstrap transaction.
- Host and client must receive and accept the same replay-header seed.
- No peer may begin normal game initialization with a missing, random,
  time-derived, mismatched, or otherwise substituted seed during network
  replay.
- Invalid or missing replay seed data must fail before replay command execution.
- A host/client seed mismatch must fail before either peer can be treated as a
  successfully bootstrapped replay participant.
- No replay command may execute before RNG bootstrap succeeds.
- Failed bootstrap must not consume replay commands or produce an accepted
  partial replay result.
- Pending replay-bootstrap state is consumed exactly once on success and cannot
  affect a later game start.
- Normal live-network start behavior must be identical to the pre-repair
  behavior.

## 9. Automated Verification

Focused automated evidence must prove all of the following:

- a valid network replay selects the exact header seed;
- the host places that exact value into the existing network game
  configuration;
- the client receives the identical value;
- both peers construct `GameState.rng` with the same `initial_seed` and initial
  state before setup proceeds;
- deterministic setup-time RNG consumption, including damage-deck
  initialization, remains identical on both peers;
- subsequent deterministic dice generation remains identical for the same
  command sequence;
- the existing format-3 `replay_network.json` reaches sequence 80 unchanged and
  accepts its one-token `commit_accuracy` command;
- the existing replay exhausts successfully;
- host and client final canonical state hashes match;
- hot-seat replay bootstrap and the committed hot-seat trace/hash gate remain
  unchanged;
- a normal fresh network game still selects a fresh lobby seed and never
  consumes replay-bootstrap state;
- missing, zero/fallback, or mismatched replay seed state fails closed before
  command execution;
- successful bootstrap consumes pending replay seed state exactly once; and
- all relevant replay, RNG, lobby/bootstrap, network, and baseline regressions
  pass.

No test may make the replay pass by replacing recorded dice, bypassing command
validation, editing replay sequence 80, or introducing a test-only bootstrap
authority.

## 10. Minimal Manual Verification

1. Run the existing format-3 network replay through
   `scripts/generate_baseline_fixtures.sh --mode network` without editing or
   rerecording it.
2. Confirm that both peers report replay exhaustion and that sequence 80
   `commit_accuracy` is accepted.
3. Confirm that the generator reports host/client final-state peer equality and
   requires no replay promotion or fixture modification.

## 11. Stop Conditions

Stop implementation and return to the Owner if any of the following is found:

- the repair requires a new authoritative RNG, replay, lobby, or network owner;
- the repair requires a new network protocol, RPC payload, transport path, or
  compatibility mode;
- the repair requires a replay-format or replay-payload change;
- the repair requires changes to dice generation, Accuracy semantics,
  `CurrentAttackState`, or any recorded replay command;
- the repair conflicts with TWI-002 or changes any TWI-002 semantic checkpoint;
- normal live-network fresh-seed behavior cannot be preserved;
- the replay seed cannot be delivered through the existing network
  game-configuration path;
- either peer must begin initialization before the seed is validated;
- the existing failing replay cannot remain byte-for-byte unchanged; or
- the defect proves to depend on BUG-001, BUG-010, targeting, save/load
  bootstrap, or another excluded behavior.

## 12. Binary Completion Criteria

The repair is complete only when every statement below is true:

- [ ] The previously failing format-3 network replay succeeds unchanged.
- [ ] Sequence 80 `commit_accuracy` is accepted.
- [ ] Host and client both initialize `GameState.rng` from the recorded replay
      header seed.
- [ ] Neither peer uses a generated or fallback seed during network replay.
- [ ] Host/client final canonical state hashes match.
- [ ] Replay execution exhausts without a command timeout.
- [ ] Hot-seat replay behavior remains unchanged.
- [ ] Normal network games retain the existing fresh lobby-seed behavior.
- [ ] Invalid, missing, or mismatched replay-bootstrap seed state fails closed
      before command execution.
- [ ] Pending replay-bootstrap state is consumed exactly once.
- [ ] No replay, trace, save, or compatibility version changes.
- [ ] No dice, Accuracy, CurrentAttackState, timing-window, TWI-002, BUG-001,
      BUG-010, targeting, generator, or verifier behavior changes.
- [ ] All focused and relevant regression evidence passes.
- [ ] No new owner, protocol, compatibility layer, feature flag, or temporary
      bridge is present.
