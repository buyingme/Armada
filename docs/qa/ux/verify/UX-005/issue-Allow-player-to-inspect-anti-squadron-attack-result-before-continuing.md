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

### Positive reference — Network defender result presentation

A further manual Network observation identified an existing presentation path
that already demonstrates the intended final-result UX substantially better.

On the defending player's Network screen, the final attack-result modal is
presented in the desired form.

This defender-side presentation should be treated as the current positive UX
reference when implementing the common result-inspection lifecycle.

The remaining presentations should be compared against that reference,
especially:

- the Network attacker presentation;
- the Hot-Seat presentation;
- equivalent ship and squadron result paths where applicable.

This is implementation evidence, not a requirement to preserve the current
defender-side implementation structure. The implementation should first
determine why the defender path produces the desired presentation and whether
the same presentation mechanism can be reused or unified safely.

The authoritative acknowledgement and continuation requirements below remain
unchanged. A visually correct defender modal does not by itself prove that the
underlying synchronization/continuation semantics are correct.

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

## Refinement Implementation — 2026-08-15

### Confirmed refinement root cause

The failed manual ship case exposed a second presentation boundary in the
original repair. `AttackExecutor.apply_complete_attack_result()` would retain
the result only while its transient synchronous-submit flag was set, or while
reconstructing an attack. A normal accepted ship `complete_attack` result could
arrive through the production `command_executed` route after that flag was no
longer set, so the executor returned without opening the final inspection
stage. The anti-squadron/reconstruction route happened to satisfy the other
branch, which explains the inconsistent manual result.

The result presenter also labelled the final local action `Confirm Result` and
replaced the existing result body with a generic sentence. That replacement
made the completed result less useful and did not express the Project Owner's
required presentation-only acknowledgement language.

Canonical attack completion and damage application were already correct. The
defect remained entirely in accepted-result correlation and local presentation.

### Refinement implemented

- A live completed result is now correlated to the already-applied damage by
  the existing attack identity before the inspection stage is shown. It no
  longer depends only on the transient submit flag. The correlation reads
  accepted result data and presentation memory; it authorizes no gameplay.
- The final button is labelled `Acknowledge Result`.
- Entering the acknowledgement stage no longer overwrites the final result
  body. Final dice and the already-applied ship or squadron damage remain
  visible together until acknowledgement.
- Acknowledgement still emits only the local `result_confirmed` presentation
  signal. It submits no semantic command, changes no `CurrentAttackState`,
  repeats no damage or `CompleteAttackCommand`, creates no replay entry, and
  adds no serialized state.
- The passive network mirror uses the same panel behavior and dismisses only
  its local presentation.

This preserves `CurrentAttackState` and the attack commands as canonical
owners. The executor and mirror retain only transient reconstructable
presentation lifecycle state.

### Refinement verification

Focused regressions now prove:

- an accepted live ship completion opens the inspection stage even when the
  transient submit flag is absent;
- ship and anti-squadron final dice and resulting damage are visible before
  acknowledgement on the active and mirrored presentations;
- the button text is exactly `Acknowledge Result`;
- result presentation and acknowledgement do not mutate canonical attack
  state, submit a command, add replay history, or duplicate completion/damage;
- existing H9/Concentrate Fire, post-Begin completion, Hot-Seat projection,
  network mirror, save/load, reconnect, and replay behavior remains protected.

Verification on 2026-08-15:

- `test_attack_sim_panel.gd`: 65/65 passed;
- `test_attack_panel_mirror.gd`: 24/24 passed;
- `test_current_attack_production_resume.gd`: 45/45 passed;
- `test_current_attack_shared_protocol.gd`: 25/25 passed;
- full suite: 237 scripts, 4064/4064 tests, 13645 assertions passed;
- Phase-K architecture lint: 0 violations, with 4 existing allow-listed
  branches;
- `git diff --check`: passed.

Status: implementation refined after the failed 2026-08-15 manual review;
Project Owner manual Hot-Seat and Network verification is still required.


## Project Owner Manual Verification — Second Refinement Required

Result: FAILED / CONTINUATION SEMANTICS INCOMPLETE

Manual Hot-Seat verification confirms that ship and squadron attack result
presentation is now substantially more consistent.

The remaining defect is the acknowledgement/continuation contract.

### Positive result

Ship and squadron attacks now use the same general final-result presentation.

`Acknowledge Result` can appear and the final attack result can be displayed.

This common presentation direction is accepted.

### Remaining defect

The acknowledgement currently behaves as transient local presentation.

Observed behavior:

- `Acknowledge Result` may appear only briefly;
- gameplay can continue automatically without the button being pressed;
- in another Hot-Seat observation the acknowledgement did not appear at all.

This does not satisfy the required interaction.

### Authoritative Requirement

After an attack has been resolved canonically, the complete final result must
remain visible until all required viewers have explicitly acknowledged it.

For Hot-Seat:

1. Show the complete resolved attack result.
2. Show an `Acknowledge Result` button.
3. Do not continue the enclosing game flow.
4. Continue only after the Hot-Seat user presses `Acknowledge Result`.

Exactly one acknowledgement is required.

For Network:

1. Show the same complete resolved result to both players.
2. Each player has their own `Acknowledge Result` button.
3. Each player may acknowledge independently.
4. One player's acknowledgement must not dismiss the other player's result.
5. Gameplay must not continue until BOTH players have acknowledged the result.

The requirement applies equally to:

- ship → ship attacks;
- ship → squadron / anti-squadron attacks;
- squadron attacks where the same final-result lifecycle applies.

### Result Presentation Requirement

Before acknowledgement is possible, the displayed result must already contain
the resolved outcome, including:

- final dice/result;
- resulting shield/hull damage for ships where applicable;
- resulting hull damage for squadrons where applicable.

Acknowledgement must never cause the damage to be applied or become visible.

Damage is already resolved gameplay state.

### Continuation Requirement

`Acknowledge Result` is not another attack decision and must not repeat attack
resolution.

However, acknowledgement now participates in the continuation contract because
gameplay is explicitly blocked until the required acknowledgement set is
complete.

The implementation must therefore provide deterministic acknowledgement state
appropriate to the active play mode:

- Hot-Seat: one required acknowledgement;
- Network: acknowledgement from both players.

Do not implement this as an uncoordinated local UI flag if gameplay progression
depends on it.

The acknowledgement mechanism must support correct:

- Hot-Seat behavior;
- host/client synchronization;
- reconnect/reconstruction if acknowledgement is pending;
- replay/deterministic command progression where required by accepted
  architecture.

### Architecture Note

The previous implementation treated result acknowledgement as purely local,
transient presentation state.

That assumption is superseded by this clarified Project Owner requirement.

Because acknowledgement gates continuation in Network play, the next
implementation must determine the correct accepted architecture surface for
this synchronization barrier.

Do not introduce ad-hoc GameState UI flags, client-local continuation authority,
or optimistic continuation.

If satisfying the requirement requires a new semantic acknowledgement command,
purpose-specific synchronized interaction state, or another architecture
decision not already permitted by accepted authority, stop and report the
finding rather than improvising a parallel ownership model.

### Refined Acceptance Criteria

- Ship and squadron attack result handling is equivalent where applicable.
- Complete resolved damage is visible before acknowledgement.
- Result presentation remains visible indefinitely until acknowledgement.
- Button text is exactly `Acknowledge Result`.
- Hot-Seat requires exactly one acknowledgement.
- Network requires independent acknowledgement from both players.
- First network acknowledgement does not dismiss the other player's result.
- Gameplay does not continue after only one network player acknowledges.
- Gameplay continues exactly once after all required acknowledgements exist.
- Acknowledgement never reapplies attack or damage resolution.
- No duplicate `CompleteAttackCommand` is submitted.
- Pending acknowledgement survives/reconstructs correctly where required.
- Network/replay/reconnect behavior remains deterministic.

## Implementation Evidence — 2026-08-18

The accepted UX-005 semantic cutover is implemented. `CompleteAttackCommand`
retires only the individual anti-squadron attack; the exhausted iteration is
closed by `SkipAttackCommand(squadron_done)`, which atomically consumes the
matching satisfied inspection with `end_anti_squadron_attack()`. Failed
consumer execution restores both the iteration state and the satisfied
inspection.

Automated evidence:

- focused unit command/state/save/replay/projection/presentation suites:
  528 tests passed, 1,907 assertions;
- focused current-attack, timing-window, shared protocol, reconnect, and
  network-transport integration suites: 97 tests passed, 2,183 assertions;
- Phase-K architecture lint: 0 violations (4 existing allow-listed branches);
- `git diff --check`: passed.

Compatibility cutover is active: save metadata v5, replay format v7, and
network protocol v3. The existing v6 replay baseline fixtures were deliberately
not relabelled. `run_baseline_traces.sh --all` correctly rejects them; valid
UX-005 Hot-Seat and Network recordings must be generated, reviewed, and
promoted through the approved Replay Baseline Workflow before final acceptance.

Full repository verification on 2026-08-19 completed with 238 scripts,
4,069/4,069 tests, and 13,766 assertions passing.

Status: implementation evidence recorded; remains in verification pending
approved v7 baseline promotion and Project Owner manual Hot-Seat and two-human
Network verification.
