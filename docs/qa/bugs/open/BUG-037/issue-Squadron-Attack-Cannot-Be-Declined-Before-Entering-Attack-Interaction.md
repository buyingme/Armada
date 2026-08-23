# BUG-037 — Squadron Attack Cannot Be Declined Before Entering Attack Interaction

Severity: Low
Area: Squadron Phase / Squadron Activation
Layer: Command Flow

## Expected

During a Squadron Phase Squadron Activation, when the squadron's Attack action
is still available and the player is permitted to decline that action, the
player should be able to decline Attack without first entering the Attack
interaction.

Declining Attack should use the existing authoritative Squadron Activation
semantics and result in the canonical Attack-action disposition becoming
`declined`.

The player should not need to begin Attack target-selection/presentation merely
to expose the choice to decline the Attack action.

## Actual

During Hot-Seat Squadron Phase testing, an activated X-wing squadron could not
directly decline its available Attack action from the initial Squadron
Activation interaction.

The player first had to enter the Attack interaction.

Once the Attack interaction had been entered, the existing decline/skip action
became available and worked correctly. After using it, canonical state recorded:

`attack_action_disposition == "declined"`

and the Squadron Activation completed normally.

Thus the authoritative decline behavior appears to exist and work, but the
decline choice is not exposed at the expected interaction level.

## Reproduction

1. Enter the Squadron Phase.
2. Activate an eligible squadron.
3. Reach the Squadron Activation state with the Attack action available.
4. Before entering the Attack interaction, attempt to decline the Attack action.

Result:

There is no direct way to decline Attack from the initial Squadron Activation
interaction.

5. Enter the Attack interaction.
6. Use the available decline/skip action.

Result:

The Attack action can now be declined and canonical state records the Attack
action as `declined`.

Frequency: Once

## Evidence

- `annotation_20260822_180414_002.json`
- `annotation_20260822_180522_003.json`

The first annotation captures the Squadron Activation before the workaround.
The activated X-wing is in Squadron Phase and its Attack action remains
available, but the player cannot directly decline that action.

The second annotation captures the state after entering the Attack interaction
and using the available decline action. Canonical state then records:

- the squadron remains associated with its Squadron Phase activation;
- `attack_action_disposition == "declined"`;
- `activated_this_round == true`;
- no active `CurrentAttackState` remains.

The before/after evidence therefore suggests that the underlying authoritative
decline semantics work correctly. The observed defect is that the choice is
only exposed after entering the nested Attack interaction.

## Initial Assessment

This currently appears to be a Squadron Activation interaction/command-flow
issue rather than an Attack rules or canonical-state defect.

The implementation should determine whether the Squadron Activation interaction
already derives the legal Attack-decline decision but fails to project it, or
whether the decline choice is currently derived only after entering the Attack
interaction.

Any repair should reuse the existing authoritative Attack-action disposition and
decline command/path.

Do not introduce:

- presentation-local gameplay state;
- a second decline mutation path;
- a UI-only disposition;
- direct controller mutation of Squadron Activation state.

The authoritative result of declining Attack should remain the existing
canonical `attack_action_disposition == "declined"` state.

## Relationship to BUG-035

This issue was discovered during BUG-035 Hot-Seat manual QA but is currently
classified separately.

BUG-035 concerns completed-Attack inspection/release and composed-return
convergence.

BUG-037 occurs before an Attack is committed: no active Attack needs to complete
or return through the BUG-035 post-Attack continuation path.

The fact that the existing decline action works after entering the Attack
interaction further suggests that BUG-037 is an interaction-entry/choice
exposure issue rather than another completed-Attack convergence failure.

BUG-037 should therefore not block BUG-035 unless later investigation shows a
shared authoritative defect.

## Resolution

Root cause:

Fix:

Verification:

- Activate a squadron during Squadron Phase with Attack available.
- Verify that Attack can be declined without first entering Attack
  target-selection/presentation.
- Verify that declining records the canonical Attack-action disposition as
  `declined`.
- Verify that no `CurrentAttackState` is created merely to decline Attack.
- Verify that entering and performing a legal Attack remains unchanged.
- Verify that choosing Attack and then following its normal commitment path
  remains unchanged.
- Verify that Squadron Activation converges to the same authoritative outcome
  regardless of whether Attack is declined through the direct interaction or
  through any still-supported equivalent path.
- Verify Hot-Seat behavior.
- Verify Network behavior when BUG-037 is eventually scheduled for
  implementation.
