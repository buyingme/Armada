

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


===== FILE: docs/qa/bugs/open/BUG-007/issue-Destroyed-squadron-position-still-blocks-later-squadron-placement.md =====

# BUG-007 — Destroyed squadron position still blocks later squadron placement

Severity: Medium
Area: Squadron Displacement / Placement
Layer: Gameplay / Geometry

## Expected

Once a squadron is destroyed and removed from play, its former board position
must no longer participate in placement, overlap, collision, or displacement
validation.

A displaced squadron should be allowed to occupy that location if no other
currently active ship, squadron, obstacle, or applicable placement rule blocks it.

## Actual

After a squadron is destroyed, another squadron being displaced cannot be
placed in the location previously occupied by the destroyed squadron.

The destroyed squadron therefore appears to continue influencing placement
legality even though it is no longer an active game piece.

## Reproduction

Observed once.

1. Destroy a squadron.
2. Later cause another squadron to be displaced.
3. Attempt to place the displaced squadron in the former position of the
   destroyed squadron.

Result:

- the position is rejected / unavailable;
- the destroyed squadron's former location appears to remain blocked.

## Evidence

- `annotation_20260804_220955_001.json`

The captured canonical state includes a TIE Fighter Squadron with:

- `current_hull = 0`
- `destroyed = true`

The annotation records:

`I realized that after displacing a squadron the squadron cannot be placed in a spot where there was a destroyed squadron before.`

## Initial Assessment

Root cause is unknown.

Likely investigation areas include:

- displacement placement validation;
- squadron overlap/collision queries;
- board-object enumeration used by placement legality;
- whether destroyed squadrons remain in scene-level spatial collections;
- whether gameplay geometry queries filter by `destroyed`;
- stale collision shapes or scene nodes after destruction.

The fix should not remove destroyed squadrons from canonical history if the game
still needs them for replay/save/history purposes.

Instead, destroyed entities should be excluded from live spatial occupancy and
placement legality wherever the rules require them to be out of play.

## Relationship to BUG-006

BUG-006 and BUG-007 may share a lower-level destroyed-entity filtering problem,
but they represent different failures.

BUG-006:
- destroyed squadrons reappear after save/load reconstruction.

BUG-007:
- destroyed squadrons affect live displacement/placement legality.

Keep them separate unless investigation proves one common root cause and one
repair closes both.

## Resolution

Root cause:
TBD

Fix:
TBD

## Verification

After repair, verify:

- destroyed squadron positions no longer block displacement placement;
- living squadrons still block placement where appropriate;
- ships and obstacles still participate correctly in placement legality;
- destroying a squadron removes it from live spatial occupancy immediately;
- save/load does not reintroduce destroyed spatial blockers;
- replay and network mirrors produce equivalent placement legality;
- BUG-006 behavior is checked separately.


===== FILE: docs/qa/bugs/open/BUG-008/issue-Range-overlay-remains-visible-on-client-after-host-fleet-command-completes.md =====

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


===== FILE: docs/qa/bugs/open/BUG-009/issue-Destroyed-ship-is-not-removed-immediately-on-defender-client.md =====

# BUG-009 — Destroyed ship is not removed immediately on defender client

Severity: Medium
Area: Network / Ship Destruction
Layer: Presentation / Projection

## Expected

When a ship is destroyed by an accepted attack:

1. canonical game state must mark the ship destroyed;
2. all peers must receive the authoritative result;
3. the destroyed ship must be removed or otherwise shown as destroyed on both
   attacker and defender screens without requiring another gameplay event or
   manual refresh.

The defender's local presentation must derive from the same accepted canonical
state as the attacker.

## Actual

The CR90 Corvette A reached destruction during an attack.

On the attacker's screen, the CR90 was correctly shown as destroyed.

On the defender's screen, the CR90 was not shown as destroyed immediately.

The first observation therefore appeared to show a ship surviving at zero hull,
but a follow-up observation established that destruction had occurred
canonically and was already visible to the attacker.

The defect is therefore a stale defender/client presentation rather than an
obvious failure of canonical destruction.

## Reproduction

Observed during network play.

1. Attack the CR90 until the attack destroys it.
2. Observe the attacker screen.
3. Observe the defender screen immediately after the accepted destruction.

Result:

- attacker: CR90 is shown destroyed;
- defender: CR90 remains visible / does not immediately reflect destruction.

## Evidence

- `annotation_20260804_221638_001.json`
- `annotation_20260804_221817_002.json`

### First observation

The first annotation states:

`Another bug the CR90 was not destroyed at 0 hull.`

The captured state already contains:

- `destroyed = true` for the CR90;
- lethal accumulated damage;
- no active `CurrentAttackState`.

This means the canonical snapshot itself does not support the interpretation
that destruction failed.

### Follow-up observation

The second annotation clarifies:

`on the attacker screen the CR90 was actually destroyed. only on defender
screen this is not showing up right away.`

This narrows the issue to presentation/projection synchronization on the
defender side.

## Initial Assessment

The evidence strongly suggests a remote/client presentation refresh defect.

Likely investigation areas include:

- mirrored attack/damage result handling;
- destruction notification propagation;
- ship-scene removal or visibility refresh on the defending client;
- whether local attack resolution emits a destruction/ship-refresh signal that
  the mirrored client path does not emit;
- ordering between canonical damage installation and presentation refresh;
- whether destruction is projected only after a later unrelated board refresh.

The canonical `destroyed` state must remain authoritative.

Do not repair this by introducing separate client-owned destruction state or UI
state into `GameState`.

### Architecture Constraint

Ship destruction is canonical gameplay state.

The repair should therefore follow:

authoritative damage/destruction command
→ accepted/mirrored canonical state
→ derived ship presentation refresh/removal

The defender client must not independently infer, predict, or authoritatively
mark destruction.

Likewise, presentation state such as `ship_visible`, `destroyed_marker_visible`,
or equivalent UI flags should not become new canonical gameplay fields solely
to fix this refresh issue.

If investigation shows that the canonical destruction result itself is not
being distributed correctly, stop and report that separately rather than
masking the problem with local UI mutation.

## Relationship to BUG-019

BUG-009 and BUG-019 may share a presentation-refresh seam.

BUG-009:
- accepted ship destruction is not reflected immediately on the defender client.

BUG-019:
- ship damage display does not refresh immediately after collision damage.

Both suggest that some remote damage/destruction paths may fail to trigger the
same presentation refresh used by local paths.

Keep the issues separate for traceability, but investigate them together when
the Presentation / Projection batch is implemented.

## Resolution

Root cause:
TBD

Fix:
TBD

## Verification

After repair, verify:

- lethal attack marks the ship destroyed canonically;
- attacker presentation updates immediately;
- defender presentation updates immediately;
- destroyed ship is removed/hidden consistently on both peers;
- no duplicate destruction processing occurs;
- non-lethal damage still refreshes correctly;
- destruction caused by attack, collision, critical effect, and other damage
  transactions all use the correct projection path;
- Hot-Seat behavior remains correct;
- replay/reconnect reconstruct destroyed ships correctly;
- BUG-019 regression remains green.


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


===== FILE: docs/qa/bugs/open/BUG-025/issue-nebulon-B-is-intermittently-unavailable-as-a-legal-attack-target.md =====

# BUG-025 — Nebulon-B is intermittently unavailable as a legal attack target

Severity: High
Area: Combat / Targeting
Layer: Rules / Target Availability

## Expected

Whenever the Nebulon-B Escort Frigate is a legal attack target according to the
applicable attack rules, it must be offered consistently to the attacker.

This applies independently to:

- ship → ship attacks;
- squadron → ship attacks.

Target availability must be derived from the current attacker, defender,
geometry, firing arc/range or squadron distance rule, LOS, and applicable rule
state.

Equivalent legal attack situations must not depend on stale presentation,
previous attackers, previous target evaluations, or ship-specific target-list
artifacts.

## Actual

The Nebulon-B Escort Frigate is intermittently unavailable as an attack target.

The defect is not limited to squadron attacks.

Observed during the same broader manual test sequence:

1. an Imperial TIE Fighter Squadron could not attack the Nebulon-B and had to
   skip;
2. another TIE Fighter Squadron later could attack the Nebulon-B;
3. the Victory II-class Star Destroyer also reached a situation where the
   Nebulon-B could not be attacked;
4. Rebel squadron → Victory II attacks worked normally.

The common symptom is therefore increasingly associated with target discovery
or target legality involving the Nebulon-B, rather than one particular attack
type.

## Reproduction

Reproduced through multiple independent observations.

### Squadron case

1. Reach Squadron Phase.
2. Activate an Imperial TIE Fighter Squadron near the Nebulon-B.
3. Attempt to attack the Nebulon-B.

Observed:
- Nebulon-B is not offered as an attack target;
- player must skip.

A later TIE Fighter activation can attack the Nebulon-B successfully.

### Ship case

1. Reach Ship Phase.
2. Activate the Victory II-class Star Destroyer.
3. Attempt to declare the Nebulon-B Escort Frigate as target.

Observed:
- the VSD cannot attack the Nebulon-B.

This establishes that the symptom is not limited to squadron targeting.

## Evidence

- annotation: `the tie squaron could not attck the neb-b again. I had to skip`
- annotation: `The second tie squadron could attack the neb-B. very strange...`
- annotation: `I cannot attack the neb-b with the VSD!`
- associated gameplay replay/log evidence where available.

### Ship-case canonical evidence

The VSD failure capture is:

- Round 2;
- Ship Phase;
- no active `CurrentAttackState`;
- VSD alive;
- Nebulon-B alive;
- VSD and Nebulon-B both present in canonical game state.

The annotation explicitly records:

`I cannot attack the neb-b with the VSD!`

This is independent evidence that the target-availability defect extends beyond
squadron attacks.

## Evidence significance

The combined observations provide an important cross-context comparison.

The defect cannot currently be explained simply as:

- squadron distance-1 handling;
- a generic squadron → ship attack failure;
- a faction-specific squadron problem.

Both a squadron and a ship can fail to acquire the Nebulon-B as a target.

At the same time, other attackers can successfully target ships, and another
TIE can successfully target the Nebulon-B.

This points toward an intermittent or geometry/state-dependent defect in the
common targeting pipeline or a Nebulon-B-specific target representation.

### Historical BUG-010 evidence

Earlier annotations recorded the same broader targeting symptom during a
Victory II-class Star Destroyer activation.

In the first capture:

- the VSD could not attack the Nebulon-B Escort Frigate from its side arc;
- during the same activation the VSD could attack the CR90 Corvette A from its
  front arc;
- the CR90 attack proceeded normally.

In a subsequent capture:

- the VSD still could not attack the Nebulon-B from the side arc;
- the player therefore skipped the remaining attack.

Evidence:

- `annotation_20260804_221509_003.json`
- `annotation_20260804_221913_004.json`

This historical evidence strengthens the hypothesis that the defect involves
Nebulon-B target representation, hull-zone geometry, or target aggregation
rather than a general attack-flow failure.

It also establishes that the problem predates the later squadron-targeting
observations and can occur in normal ship → ship attacks.

## Relationship to BUG-023

BUG-023 audited squadron attack distance semantics and corrected an inconsistency
where some consumers treated ship-style `close` range as equivalent to squadron
distance 1.

BUG-025 is different and broader.

The new ship → ship reproduction proves that BUG-025 cannot be explained solely
by squadron distance-1 handling.

Do not reopen BUG-023 automatically.

Its distance-1 invariant must remain protected while BUG-025 investigates the
broader target-discovery path.

## Initial Assessment

Root cause is unknown.

The new VSD reproduction substantially changes the investigation priority.

Investigate the shared targeting pipeline before making attack-type-specific
changes.

Potential investigation areas include:

- Nebulon-B hull-zone geometry;
- firing-arc and LOS calculations against the Nebulon-B;
- ship target aggregation from individual hull-zone candidates;
- transformation/rotation handling for the Nebulon-B model;
- target-list construction shared between ship and squadron attackers;
- stale target caches or previous attacker state;
- attacker/defender owner + entity-index identity;
- inconsistent filtering between candidate discovery and final presentation;
- whether one invalid hull-zone result incorrectly removes otherwise valid
  hull-zone candidates;
- differences between preview target discovery and authoritative BeginAttack
  validation.

For squadron attacks, continue to enforce the separate invariant:

**squadron attack legality = distance 1**

`close` must not be substituted for distance 1.

For ship attacks, normal ship range-band and firing-arc rules apply.

Do not merge those two range models while looking for the common defect.

Explicitly compare:

- VSD side arc → Nebulon-B;
- VSD front arc → CR90;
- other VSD arcs → Nebulon-B;
- other ships/arcs → Nebulon-B.

Determine whether the failure is tied to the Nebulon-B as a whole or only to
specific attacker/defender hull-zone combinations.

## Resolution

Root cause:
TBD

Fix:
TBD

## Verification

After repair, verify at minimum:

### Ship → ship

- VSD can attack a legal Nebulon-B hull zone;
- different Nebulon-B orientations are handled correctly;
- different attacking VSD hull zones produce correct candidate sets;
- illegal arc/range/LOS combinations remain rejected.

### Squadron → ship

- TIE → Nebulon-B is offered whenever a legal distance-1 target exists;
- distance 2 remains illegal even if ship-style range is `close`;
- multiple identical TIE Fighters are evaluated independently.

### Cross-context consistency

- one attacker cannot leave stale targeting state affecting the next attacker;
- target discovery and authoritative BeginAttack validation agree;
- Nebulon-B behaves consistently as a target for ships and squadrons;
- other ship types remain unaffected;
- Hot-Seat and Network produce the same target set;
- replay/save/load/reconnect preserve equivalent targeting behavior;
- BUG-005 and BUG-023 regressions remain green.

## Status

Open — reproduced across both squadron → ship and ship → ship attack contexts.
Exact root cause remains unknown.


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
