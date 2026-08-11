# BUG-018 — Skipping Squadron Move Deadlocks Squadron Phase

Severity: High
Area: Squadron Phase
Layer: Command Flow

## Expected

When a squadron move is skipped during the Squadron Phase, the skipped action should be represented through the appropriate authoritative gameplay transition.

The squadron should then continue with any remaining legal action or complete its activation according to the rules.

After activation completion, the next eligible squadron should be activatable and Squadron Phase progression should continue normally.

## Actual

Skipping a squadron move leaves the Squadron Phase in a deadlocked state.

The UI reports that the squadron activation is complete, but the next eligible squadron cannot be activated and gameplay cannot continue.

The failure is reproducible.

In the second captured occurrence, the authoritative state still contains the selected squadron as an active Squadron Phase activation:

- activation_id = "squadron-activation:31"
- activation_context = "squadron_phase"
- activated_this_round = false
- move_action_committed = false
- attack_action_disposition = "available"

The Squadron Phase state also remains:

- squadron_phase_controller_player = 0
- squadron_phase_activations_committed = 0

The replay records activate_squadron as sequence 31 but contains no subsequent semantic command representing the skipped movement, further action progression, or activation completion.

The presentation therefore reports completion while canonical gameplay progression remains at the newly activated squadron.

## Reproduction

Always — reproduced in 2/2 observed attempts.

1. Reach the Squadron Phase.
2. Activate an eligible squadron.
3. Skip the squadron's movement.
4. Observe that the UI reports the activation as complete.
5. Attempt to activate another eligible squadron.
6. The next squadron cannot be activated and Squadron Phase cannot continue.

## Evidence

First occurrence:

- annotation_20260811_213210_001.json

Confirmed reproduction:

- annotation_20260811_223056_001.json
- replay_20260811_223101.json
- game_20260811_222929.log

The second replay is a normal timestamped format-5 gameplay replay. It ends after activate_squadron sequence 31, with no subsequent command corresponding to the skipped move or activation completion.

The corresponding production log shows that after the player presses Skip, the activation-completion path is entered, but complete_squadron_activation is rejected because the squadron still has an available action. This provides direct evidence that presentation/controller progression attempts completion while canonical action state is not yet complete.

## Resolution

Root cause:
TBD

Fix:
TBD

Verification:

- Add a regression reproducing Squadron Phase activation followed by skipped movement through the production interaction path.
- Verify that the required authoritative transition is submitted and accepted.
- Verify that canonical squadron activation/action state progresses correctly.
- Verify that the activation can continue or complete according to the remaining legal actions.
- Verify that the next eligible squadron can subsequently be activated.
- Verify replay contains the expected semantic command sequence.
- Verify hot-seat behavior and relevant network/replay paths remain consistent.
