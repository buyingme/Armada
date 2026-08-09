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
