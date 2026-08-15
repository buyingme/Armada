# BUG-016 — Defense tokens can become unspendable after ECM selection

Severity: Medium
Area: Ship Combat – Defense Token Resolution / ECM
Layer: Presentation | Command Flow

## Expected

During defense-token resolution, selecting Electronic Countermeasures to authorize a defense token must leave the complete defense-token interaction usable.

After selecting the ECM-authorized token, the defending player must be able to spend all otherwise legal defense tokens without having to reset or repeat the ECM selection.

## Actual

The defense-token interaction can enter a state where defense tokens cannot be spent after selecting the ECM Redirect choice.

The issue can be recovered by:

1. deselecting the ECM Redirect choice;
2. selecting the ECM Redirect choice again;
3. spending the defense tokens.

After this deselect/reselect sequence, defense-token spending works normally.

This confirms the earlier intermittent BUG-016 observation and provides a reproducible interaction sequence.

## Reproduction

Confirmed/reproduced during network play.

Observed sequence:

1. CR90 defends against a Victory II-class Star Destroyer attack.
2. Accuracy locks a defense token.
3. Electronic Countermeasures is used to authorize the locked token.
4. Select the ECM Redirect choice.
5. Attempt to spend the desired defense tokens.
6. Defense-token spending does not work correctly.
7. Deselect the ECM Redirect choice.
8. Select the ECM Redirect choice again.
9. Defense tokens can now be spent.

The earlier BUG-016 observation also occurred during ECM-enabled defense resolution and required repeated interaction before defense-token confirmation succeeded.

## Evidence

Existing BUG-016 evidence:
- annotation.json
- replay_20260807_103712.json
- replay_20260807_112425.json

New confirmation evidence:
- associated 2026-08-14 annotation and gameplay log.

The new captured authoritative state shows:

- attack active in the Defense stage;
- CR90 as defender;
- one Accuracy-locked token;
- ECM authorization for defense-token index 2;
- active `pending_ecm_authorization`;
- selected ECM token index 2.

The captured state does not indicate general attack-state corruption.

The reproducible recovery after deselecting and reselecting the ECM choice suggests that the failure may involve interaction state, projected ECM choice state, or synchronization between ECM selection and ordinary defense-token spending.

## Initial Assessment

Root cause remains unknown, but the issue is now reproducible and more narrowly scoped than the original BUG-016 report.

Investigate the interaction boundary between:

- ECM authorization;
- local ECM token selection;
- projected defense-token availability;
- defense-token click/input handling;
- command construction/submission;
- authoritative re-projection after ECM choice changes.

Determine the first failing boundary before changing command or rule semantics.

Do not change ECM or defense-token authoritative ownership unless investigation establishes that canonical state is incorrect.

## Resolution

Root cause:

The latest host log establishes the first failing boundary. After
`use_ecm` was accepted at sequence 81, repeated `commit_defense` submissions
were rejected with `Defense tokens are not in canonical resolution order`.
The canonical attack, ECM authorization, token legality, and command
validation were correct.

`AttackPanelMirror` constructed `selected_indices` in local click order. The
authoritative `CommitDefenseCommand` deliberately requires the RRG resolution
order used by the primary attack executor. Deselecting and reselecting changed
the UI array order, which explains why the workaround appeared to repair ECM.

Fix:

Before submitting the existing `CommitDefenseCommand`, the network defender
mirror now orders selected token indices with the existing shared
`AttackFlowExecutor.sort_defense_tokens_canonical()` rule. No ECM state,
defense-token state, timing-window ownership, command semantics, or validation
was changed.

This is an input-normalization repair at the derived interaction boundary. The
command remains authoritative and continues to reject forged/non-canonical
payloads.

## Verification

After repair, verify:

- selecting an ECM-authorized defense token works on the first attempt;
- all other legal defense tokens remain immediately spendable;
- no deselect/reselect workaround is required;
- the locked token remains unavailable unless correctly authorized by ECM;
- ECM is exhausted exactly once when used;
- defense tokens are spent exactly once;
- attack resolution continues normally;
- repeated ECM-enabled attacks do not reproduce the issue;
- hot-seat and network behavior remain equivalent;
- replay, save/load, reconnect, and projection remain deterministic.

Automated regression evidence added in
`tests/unit/test_attack_panel_mirror.gd` creates a real pending ECM
authorization, selects the ECM Redirect and an immediately legal Evade in
reverse click order, and proves that the first submitted command is ordered
Evade then Redirect and passes authoritative validation. Existing ECM,
defense-token ordering, shared attack protocol, H9/CF resume, save/load,
reconnect, and replay coverage remains green.

Verification on 2026-08-14:

- focused suites: `test_attack_panel_mirror.gd` 24/24,
  `test_electronic_countermeasures_command.gd` 40/40,
  `test_defense_token_ordering.gd` 23/23,
  `test_current_attack_shared_protocol.gd` 25/25, and
  `test_current_attack_production_resume.gd` 44/44 passed;
- full suite: 237 scripts, 4057/4057 tests, 13573 assertions passed;
- Phase-K architecture lint: 0 violations, with 4 existing allow-listed
  branches.

The repaired behavior is ready for Project Owner/manual Hot-Seat and Network
verification.
