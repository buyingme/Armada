# UX-011 — Squadron selection commits too early and prevents pre-activation range inspection

Category: High
Area: Squadron Activation / Squadron Selection
Layer: Command Flow

## Problem

During Squadron Phase, and potentially during execution of a Squadron Command, selecting a squadron does not provide sufficient opportunity to inspect different eligible squadrons before committing the activation.

A player should be able to click between eligible squadrons and inspect the gameplay information relevant to deciding which squadron to activate, including range information, without committing the activation to the inspected squadron.

The selection/inspection of a squadron should therefore remain reversible until the player chooses an actual activation action.

For an eligible selected squadron, commitment occurs when the player chooses one of:

- Move;
- Attack; or
- Skip.

Merely clicking/selecting a squadron for inspection must not consume an activation, mark that squadron as activated, or prevent the player from selecting another eligible squadron.

### Skip semantics

`Skip` is an explicit committed activation choice.

Choosing Skip means that the player deliberately consumes the available activation for the selected squadron without moving or attacking with it.

After Skip is committed:

- the activation is consumed;
- the selected squadron becomes activated;
- that squadron cannot normally be activated again during the same game round.

Skip must therefore not behave like Cancel, Back, or deselection.

## Impact

Squadron activation requires the player to evaluate tactical options before choosing which squadron to activate.

If clicking a squadron effectively commits the player too early, the player cannot conveniently compare eligible squadrons, inspect their ranges, and decide which activation is preferable.

This creates unnecessary commitment before the player has actually chosen a gameplay action.

Separating reversible inspection from committed activation provides a clearer interaction model:

Select/inspect squadron → compare options/ranges → optionally select another squadron → choose Move, Attack, or Skip → activation committed.

This is particularly important when several squadrons are available and their relative ranges determine which squadron the player wants to activate.

## Evidence

Observed behavior:

During Squadron Phase, the player cannot conveniently cycle through different eligible squadrons to inspect range before committing to the squadron that should move or attack.

Similar behavior may exist during Squadron Command execution and should be investigated.

Expected behavior:

- click an eligible squadron;
- inspect its available information/ranges;
- click another eligible squadron;
- inspect that squadron instead;
- continue switching between eligible squadrons as required;
- commit only by choosing Move, Attack, or Skip.

## Investigation hint

Investigate Squadron Phase and Squadron Command separately before deciding whether they should use the same implementation mechanism.

Determine the current commitment boundary for squadron activation and whether squadron selection itself currently mutates authoritative activation state.

The intended interaction separates:

**Reversible exploration**

- select an eligible squadron;
- project its relevant ranges/options;
- select another eligible squadron;
- change the currently inspected squadron without consuming gameplay resources or changing activation state.

from:

**Committed gameplay action**

- Move;
- Attack;
- Skip.

Selection before commitment should be presentation/interaction state rather than an authoritative squadron activation.

Do not create authoritative commands merely to cycle between candidate squadrons if no gameplay decision has yet been committed.

Once Move, Attack, or Skip is chosen, the appropriate authoritative command/state transition should establish the committed activation.

### Skip

Investigate the existing Skip behavior carefully.

Skip is not cancellation of squadron selection.

It represents the player's decision to spend that squadron activation without performing Move or Attack.

After authoritative Skip resolution:

- the relevant activation opportunity/capacity is consumed;
- the squadron is marked activated for the current round;
- normal rules prevent that squadron from being activated again during that round.

### Squadron Command

For Squadron Command, also verify how committing a squadron interacts with:

- the command's remaining squadron-activation capacity;
- eligible-squadron determination;
- sequential Squadron Activations;
- return to the Squadron Command interaction after one squadron completes.

Pre-commit inspection must not consume Squadron Command capacity.

### Squadron Phase

For Squadron Phase, verify that pre-commit inspection does not alter the authoritative Squadron Phase allocation/activation state and that committed completion returns correctly to the phase's next required decision.

The intended invariant is:

> Selecting a squadron for inspection is reversible. A squadron activation becomes committed only when the player chooses Move, Attack, or Skip.

And:

> Skip consumes the activation and leaves the selected squadron activated for the round even though it neither moved nor attacked.

## Resolution

Improvement:

Not yet implemented.

Target behavior: allow players to freely inspect and cycle between eligible squadrons before committing an activation, with Move, Attack, and Skip forming the commitment boundary.

Verification:

- During Squadron Phase, clicking an eligible squadron allows inspection without activating it.
- Another eligible squadron can subsequently be selected.
- Repeated selection changes do not consume activations.
- Relevant range information updates for the currently inspected squadron.
- Selecting Move commits the activation to the selected squadron.
- Selecting Attack commits the activation to the selected squadron.
- Selecting Skip commits the activation to the selected squadron.
- Skip marks the squadron activated for the current round.
- A normally activated/skipped squadron cannot be activated again during that round by normal means.
- Pre-commit inspection does not change authoritative squadron activation state.
- Equivalent behavior is investigated and, where applicable, provided during Squadron Command.
- During Squadron Command, pre-commit inspection does not consume command activation capacity.
- After a committed Squadron Command activation completes, remaining command capacity and eligible squadrons are handled correctly.
- Hot-Seat behavior is verified.
- Network host behavior is verified.
- Network client behavior is verified.
- Network opponents do not receive authoritative gameplay changes merely because the active player cycles through pre-commit inspection candidates.
- Save/load, reconnect, and replay preserve only authoritative committed gameplay state and do not incorrectly turn transient inspection into a committed activation.
