# BUG-059 — Automatic Immediate Resolution Uses the Player Submission Gate

**Status:** Open

## Finding

The BUG-043 R1 production-seam test demonstrated that `GameManager.submit_resolve_immediate_effect()` sends an automatic immediate command (`actor_player == -1`) through ordinary `submit()`. When the Network host and damaged ship have different principals, the host player gate rejects that authority-owned continuation.

A second R1 ingress test demonstrated the converse: when the host principal does control the ship owner, ordinary Network host `submit()` accepted an automatic immediate command from the player surface. Numeric actor identity alone did not enforce authority origin.

## Evidence

`test_r1_automatic_immediate_uses_authority_submission_across_principals` first failed because the recording submitter observed one player submission and no authoritative submission. The canonical command still carried the ship owner as its numeric actor, as required by the accepted workbook.

## Bounded repair

Route only canonical automatic immediate records through the existing `submit_authoritative()` surface. Reject the workbook's authority-only Maneuver branches at both Network player-ingress paths, while preserving the numeric actor identity for authority-generated commands. Keep player-choice branches on ordinary `submit()` and retain canonical command validation and principal checks. The issue is within the authorized BUG-043 R1 repair scope.
