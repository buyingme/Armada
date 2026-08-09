# BUG-012 — Parameterized Attack Modify choices do not submit and leave the attack stalled

Severity: High
Area: Attack Timing Window
Layer: Command Flow

## Expected

During a ship attack with an active shared `ATTACK_MODIFY` timing window:

Parameterized Attack Modify opportunities are resolved in two stages: first the player decides whether to use the optional effect; only after accepting the effect is any rule-specific parameter (such as selecting a die) collected locally. The final parameter selection constitutes the player’s commitment and submits the complete semantic command.

- selecting **Use Concentrate Fire Token** should enter the required die-selection interaction;
- selecting an eligible die should submit the complete replayable Concentrate Fire command;
- selecting **Use H9** should likewise enter the required die-selection interaction and submit the complete H9 command;
- after each accepted Use or Decline choice, the timing-window orchestrator should re-derive remaining opportunities and continue the attack;
- once all blocking opportunities are resolved, the attack should proceed to dice confirmation and Accuracy.

More precicely this means for H9 and CF tolken:

Use: No
→ submit explicit Decline command immediately

Use: Yes
→ enter local parameter-selection mode
→ no authoritative mutation yet

Eligible die click
→ complete the semantic command payload
→ submit the replayable command
→ authoritative validation and mutation
→ the submitted command cannot be withdrawn or modified through the same interaction.

## Actual

The shared Attack Modify choices appear correctly in live gameplay, including Concentrate Fire and H9.

After choosing **Use Concentrate Fire Token**, however:

- no complete Concentrate Fire semantic command appears in authoritative command history;
- the attack remains active at `attack_modify`;
- the timing window remains open;
- `cf_token_resolution` remains `pending`;
- H9 remains unresolved;
- no subsequent die-selection or command-submission interaction allows the attack to continue.

The only available recovery was to use **Skip Attack**, which cancelled the entire attack and closed the timing window.

The replay contains:

- `begin_attack`
- `use_concentrate_fire_dial`
- `roll_dice`
- `skip_attack`

It does not contain any of the expected shared-window resolution commands:

- `use_concentrate_fire_token_reroll`
- `decline_concentrate_fire_token_reroll`
- `use_h9`
- `decline_h9`
- `confirm_attack_dice`

This indicates that the live parameterized interaction did not reach authoritative command submission.

## Reproduction

1. Start the debug scenario with:
   - Victory II-class Star Destroyer;
   - H9 Turbolasers equipped;
   - a Concentrate Fire token available.
2. Begin a ship attack.
3. Spend the Concentrate Fire dial if available.
4. Roll attack dice.
5. Observe that the shared Attack Modify choices appear.
6. Select **Use Concentrate Fire Token**.
7. Observe that the attack does not continue:
   - no usable die-selection flow completes;
   - no semantic CF-token command is recorded;
   - H9 cannot subsequently be resolved;
   - the timing window remains open.
8. Use **Skip Attack** to resume gameplay.
9. Observe that the attack is cancelled instead of completed.

Frequency: Once during the initial production-activation smoke test; appears deterministic from the captured state and replay.

## Evidence

- `annotation_20260806_094530_001.json`
  - active attack at `attack_modify`;
  - active `attack_modify` timing window;
  - `cf_token_resolution = pending`;
  - H9 runtime `rule_state` still empty;
  - no participant resolved.  [oai_citation:0‡annotation_20260806_094530_001.json](sediment://file_00000000dba881f4a617077d8d40649b)

- `annotation_20260806_094556_002.json`
  - attack and timing window inactive only after Skip Attack;
  - gameplay resumed because the attack was cancelled;
  - H9 still has no used or declined guard.  [oai_citation:1‡annotation_20260806_094556_002.json](sediment://file_00000000f79081f487406bf7baaaa903)

- `replay_20260806_094633.json`
  - sequence 42: `begin_attack`;
  - sequence 43: `use_concentrate_fire_dial`;
  - sequence 44: `roll_dice`;
  - sequence 45: `skip_attack`;
  - no CF-token Use/Decline command;
  - no H9 Use/Decline command;
  - no `confirm_attack_dice`.  [oai_citation:2‡replay_20260806_094633.json](sediment://file_00000000b44081f4ae09b5bbd28226c2)

## Resolution

Root cause:

Unknown.

The evidence strongly suggests a failure in the live parameterized command-routing seam between:

- projected generic Attack Modify choice;
- player selecting Use;
- entering die-selection mode;
- constructing the complete command payload;
- submitting the replayable semantic command through GameManager.

Concentrate Fire token Use and H9 Use may share this same broken live-interaction path because both require a selected die and cannot be represented by a simple parameter-free Use intent.

The captured authoritative state does not indicate corruption:

- the attack remains active;
- the timing window remains open;
- unresolved choices remain pending;
- no false semantic command is recorded.

The system therefore appears to fail closed, but the live interaction cannot complete.

Fix:

Perform a bounded forensic investigation of the full live routing path:

`UIProjector`
→ generic timing-window opportunity
→ `AttackSimPanel`
→ Use selection
→ die-selection interaction
→ command payload completion
→ `GameManager`
→ command submission
→ authoritative command history

Determine:

- whether the projected Use intent lacks required selected-die fields;
- whether the panel enters a valid die-selection mode;
- whether the selected die is applied to the pending command template;
- whether GameManager receives and submits the completed command;
- whether CF and H9 share the same failing path;
- whether Skip Attack is merely an exposed cancellation escape or independently incorrect.

Do not redesign timing-window ownership or command semantics unless the investigation proves an accepted architecture gap.

Verification:

- CF token Use completes through live die selection.
- H9 Use completes through live die selection.
- CF token Decline and H9 Decline remain functional.
- Complete semantic commands appear in authoritative history.
- Dice and token/guard mutations occur exactly once.
- Remaining opportunities are re-derived correctly.
- The attack proceeds to confirmation and Accuracy after all blockers resolve.
- Skip Attack is not required to recover from a valid Attack Modify choice.
- Hot-seat, network, replay, save/load, reconnect, and projection remain deterministic.
- Existing CF/H9 automated protocol tests continue to pass.
