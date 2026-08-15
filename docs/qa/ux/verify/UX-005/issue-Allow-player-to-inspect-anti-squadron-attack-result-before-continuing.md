# UX-005 — Allow player to inspect anti-squadron attack result before continuing

Area: Combat UI / Anti-Squadron Attack / most likely also ship attack
Layer: Presentation / Interaction

## Observation

During an anti-squadron attack, (most likely also shif attack) the attack result disappears immediately when the current action is committed.

This makes it difficult for the player to inspect the final attack result before gameplay continues.

The current interaction also makes the meaning of the final confirmation less clear than it could be.

## Desired Experience

Separate committing the player's attack choices from acknowledging the final resolved result.

Suggested interaction:

1. Player performs the attack and makes all required attack choices.
2. `Commit Attack` commits the attack choices/resolution.
3. The final resolved attack result remains visible.
4. Player explicitly selects `Confirm Result`.
5. Only then does the presentation close and gameplay continue.

The exact button labels may be adjusted to fit the existing UI vocabulary, but the distinction should remain clear:

- commit gameplay choices;
- inspect resolved result;
- acknowledge result and continue.

## Why

The player should have sufficient time to understand the outcome of an anti-squadron or ship attack.

The result should not disappear as a side effect of the same interaction that commits the attack.

## Acceptance

- Final anti-squadron and ship attack results remain visible after attack choices are committed.
- The player can inspect the resolved result without time pressure.
- A separate explicit confirmation continues gameplay.
- No duplicate attack command or gameplay mutation occurs when confirming the displayed result.
- The result-confirmation interaction is presentation/continuation only unless authoritative gameplay semantics require otherwise.
- Hot-seat and network behavior remain consistent.

## Implementation

### Confirmed root cause

The attack executor displayed damage briefly, then a fixed 1.2-second timer
submitted the existing authoritative `CompleteAttackCommand` and immediately
ran local finalization. Finalization hid the damage and dice presentation while
continuing the enclosing ship/squadron activation. The passive network mirror
also did not project the terminal `resolve_damage` result or retain a completed
result after the canonical attack became inactive.

The gameplay transition itself was correct; the defect was the local
post-result presentation lifecycle.

### Implemented fix

After `CompleteAttackCommand` has been accepted and
`CurrentAttackState` is inactive, the attacker panel now retains its final dice
and damage and exposes a distinct `Confirm Result` acknowledgement. That signal
only resumes the existing local finalization/continuation; it submits no
command and performs no attack mutation.

The passive network mirror now projects the accepted ship or squadron damage
result before ownership routing, retains it after canonical completion, and
lets that peer dismiss only its own local result. Ordinary gameplay choices
continue to use their existing command-owned paths; the dice-finalization
button now uses `Commit Attack`, distinct from `Confirm Result`.

The two acknowledgement flags are transient, reconstructable presentation
state. No result-visible field, semantic acknowledgement command, current-step
authority, save/replay field, or compatibility path was added.

## Verification

Automated production-path regressions prove:

- normal ship damage completes canonically once, remains visible, and only
  advances the enclosing activation after `Confirm Result`;
- anti-squadron damage follows the same inspect/acknowledge lifecycle;
- mirrored ship and anti-squadron results are visible to the passive peer and
  local acknowledgement closes only that mirror;
- `Confirm Result` emits neither normal attack confirmation nor declaration
  confirmation and cannot repeat `CompleteAttackCommand`;
- final dice and damage remain displayed while the result is awaiting
  acknowledgement;
- existing H9/CF timing, post-Begin completion, network protocol, save/load,
  reconnect, and replay tests remain green.

Verification on 2026-08-14:

- focused `test_attack_sim_panel.gd`: 65/65 passed;
- focused `test_attack_panel_mirror.gd`: 24/24 passed;
- focused `test_current_attack_production_resume.gd`: 44/44 passed;
- focused `test_current_attack_shared_protocol.gd`: 25/25 passed;
- full suite: 237 scripts, 4057/4057 tests, 13573 assertions passed;
- Phase-K architecture lint: 0 violations, with 4 existing allow-listed
  branches.

The implemented lifecycle is ready for Project Owner/manual Hot-Seat and
Network verification, including both ship and anti-squadron attacks.

## Project Owner Manual Verification — 2026-08-15

Result: FAILED / REFINEMENT REQUIRED

Manual verification confirmed that the implemented result-acknowledgement
lifecycle does not yet fully satisfy the intended UX.

### Finding 1 — Ship attacks do not provide the final acknowledgement

Anti-squadron attacks show the intended final-result acknowledgement.

Normal ship attacks do not provide the equivalent final result-inspection
stage.

This contradicts the acceptance requirement that both anti-squadron and ship
attack results remain visible until explicitly acknowledged.

### Finding 2 — Final acknowledgement wording is misleading

The final result interaction currently uses wording equivalent to
`Commit Attack`.

At this point there is no attack decision left to commit. The authoritative
attack result has already been resolved.

The final presentation-only action should instead be labelled:

`Acknowledge Result`

`Commit Attack` should be reserved for an interaction that actually commits
gameplay choices.

### Finding 3 — Damage must be visible before acknowledgement

For the anti-squadron result, the resulting damage is not shown as part of the
result being inspected. The damage becomes visible only after the final
confirmation.

This reverses the intended presentation order.

The desired lifecycle is:

1. Resolve the attack and damage canonically.
2. Display the final dice/result.
3. Display the resulting damage.
4. Keep the complete resolved result visible without a timeout.
5. Offer `Acknowledge Result`.
6. Only after acknowledgement dismiss the result presentation and continue.

The acknowledgement itself must not cause, commit, or repeat damage.

### Refined Acceptance Criteria

- Both ship attacks and anti-squadron attacks use the same final
  result-inspection concept where applicable.
- The complete authoritative attack result is resolved before acknowledgement.
- Final dice remain visible.
- Resulting damage is already visible while acknowledgement is pending.
- The result remains visible without a timeout.
- The final presentation-only button is labelled `Acknowledge Result`.
- `Commit Attack` is used only where an actual gameplay decision is committed.
- Pressing `Acknowledge Result` performs no attack, damage, or other gameplay
  mutation.
- Acknowledgement only dismisses the local result presentation and resumes the
  appropriate enclosing presentation/continuation.
- Hot-Seat and Network behavior remain consistent.
