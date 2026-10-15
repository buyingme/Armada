# BUG-074 Destroyed-Counter Child Release Diagnosis

Status: Owner-accepted diagnosis and permanent implementation evidence  
Date: 2026-10-13  
Scope: destroyed defending Squadron accepting Counter after the triggering attack

## Immutable Owner Evidence

This report references, but does not modify, the original Owner-recorded
[format-12 replay](replay_20261013_204337.json) and
[Network log](game_20261013_204000.log). Those artifacts remain the source
evidence for this incident and are immutable.

## Recorded Failure Sequence

The replay and log establish this sequence:

| Sequence | Recorded event |
| --- | --- |
| 48 | `begin_attack` creates parent `attack:48`: X-wing Squadron attacks TIE Interceptor Squadron. |
| 57 | `resolve_damage` applies three damage to the TIE Interceptor, reducing it to zero hull and destroying it. |
| 60 | The parent publishes the Counter choice with the accepted canonical Counter participants and pool; the log reports `Counter available — awaiting defender choice.` |
| 61 | Player 1 accepts Counter for `attack:48`. |
| 62 | The parent attack completes. |
| 63–64 | Player 1 and Player 0 acknowledge the exact completed parent result. |
| — | No authoritative Counter-child `begin_attack` follows the satisfied parent inspection. |
| 65 | The original Squadron activation completes instead. |

The absence of the child Begin is recorded evidence. The explanation for that
absence below is established by correlating the recorded state with the
authoritative continuation and command-validation code; it is not an inferred
replay event.

## Canonical Cause

The parent lifecycle is canonically sufficient to establish the exact Counter:
the accepted source-scoped Counter projection retains the accepted choice, all
four participant identities, and authoritative dice pool, and the exact parent
inspection becomes satisfied after both acknowledgements.

The failure occurs in
[`CurrentAttackContinuation._derive_counter_inspection_release()`](../../../../../src/core/state/current_attack_continuation.gd#L305).
Its participant guard rejects the child when either participant is destroyed.
That incorrectly rejects the destroyed Counter attacker permitted by the
Counter rule. The evaluator then falls through to the ordinary completed-
attack release path, which derives completion of the original Squadron
activation. That accounts for recorded sequence 65 and for the missing child
Begin.

This is not a reason to weaken generic destroyed-unit validation. The existing
[`BeginAttackCommand` Counter branch](../../../../../src/core/commands/begin_attack_command.gd#L245)
already validates the Counter identity before the generic destroyed-attacker
rejection while continuing to reject a destroyed defender. The exception is
therefore bounded to an exact, legally established Counter child.

Canonical state retains everything needed for that child: exact participant
identity and ownership, position, Counter keyword and armament, accepted
source-scoped choice, authoritative Counter pool, satisfied inspection, and
the surviving Counter target. No new canonical field, owner, fallback, or
lifecycle mechanism is required.

## Authority And Workbook Contradiction

The Rules Reference permits a squadron to resolve Counter even when it is
destroyed by the triggering attack; see
[`Counter`](../../../../../Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md#L1280).
The existing rule plan also records that Counter can trigger after defender
destruction in
[`Phase N20`](../../../../refactoring_phase_n_plan.md#L373). The accepted
Counter interaction requirements leave eligibility and dice to that applicable
rules authority; see
[`counter_attack_interaction.md`](../../../../requirements/gameplay_interactions/counter_attack_interaction.md).

Section 6.6 of the accepted
[Network attack-flow implementation workbook](../../../../architecture/implementation_workbooks/network-attack-flow-lifecycle-and-remote-damage-presentation-repair-implementation-workbook.md#66-authoritative-counter-inspection-release)
instead required both Counter participants to be non-destroyed and classified
any destroyed participant as ineligible. That requirement contradicted the
higher rule authority. The accepted correction is precise: the destroyed
Counter attacker is eligible only for the exact established Counter child;
the Counter target must remain eligible and non-destroyed.

Classification: requirements gap in the accepted workbook, manifested as an
implementation defect. The correction requires no new Owner gameplay or
architecture decision.

## Detached-Token Presentation Risk

Destruction retires the Squadron token from the ordinary token container and
retains it as a hidden detached presentation resource in
[`GameBoard._retire_destroyed_squadron_token()`](../../../../../src/scenes/game_board/game_board.gd#L921).
Ordinary Squadron lookup and selection intentionally search the live token
container and must not be broadened to make destroyed Squadrons selectable.

After the authoritative child Begin, Network reconstruction can lack the
scene-local pending Counter token. The normal attack reconstruction route then
requires an attacking Squadron token in
[`AttackExecutor._resolve_resume_references()`](../../../../../src/scenes/game_board/attack_executor.gd#L544),
while its retained-token handling is currently scoped to a destroyed defender.
Consequently, merely allowing child derivation risks a valid child whose
presentation cannot rebind on one peer.
The bounded implementation has two presentation paths. Uninterrupted gameplay
may reuse the existing detached token for the exact active, legally established
Counter child. Save/load or reconnect must reconstruct a presentation-only
transient instance of the existing Squadron token type from exact canonical
active-child identity and presentation facts. The reconstructed instance must
remain detached from ordinary lookup and selection, confer no attack
eligibility, and be cleaned up deterministically at Counter termination or
before replacement during repeated reconstruction/reconnect. Neither path may
leave duplicate or orphaned tokens.

## Required Regression Boundaries

Implementation acceptance must prove all of the following end to end:

- surviving and destroyed Counter attackers, each through accept and decline;
- the exact accepted parent source, participants, keyword, Counter pool, and
  inspection produce one child Begin; Begin independently validates that the
  supplied satisfied inspection source equals the accepted Counter-choice
  source in both live-derived and explicit replay paths, while a destroyed
  Counter target and any non-Counter destroyed attacker fail closed;
- both real-ENet role mappings start before the production no-defense
  `commit_accuracy` → `resolve_damage` boundary and use the actual Counter
  choice UI/command path, without a preconstructed Counter state;
- uninterrupted play may reuse the exact detached token, while Save-10 load and
  reconnect reconstruct a presentation-only transient existing-type token from
  exact canonical active-child state without exposing it to ordinary target or
  attacker selection; repeated reconstruction/reconnect and Counter termination
  clean up deterministically with no duplicate or orphaned token;
- the controlling endpoint receives the child Roll and subsequent applicable
  interactions, while the other endpoint receives only passive presentation;
- Save 10/load/reconnect preserve the exact accepted parent, inspection,
  child, and composed-return boundaries for surviving and destroyed cases;
- Replay 12 deterministically applies the explicit recorded command history
  without deriving or synthesizing continuation commands and without changing
  any Owner-controlled fixture;
- child completion and exact-ID acknowledgements compose back through the
  original Squadron activation: a legal Move/decline opportunity retains the
  satisfied child inspection until atomic consumption, while an exhausted
  Squadron consumes it through authoritative completion and reaches the next
  stable enclosing decision; and
- stale publication, source identity, terminal clearing, Counter identity,
  inspection release, generic destroyed-unit validation, and version checks
  remain green.

The bounded repair may touch only the existing Counter continuation and
presentation/reconstruction seams needed for this exception. Save remains 10,
Network remains 11, and replay/signed replay remains 12.
