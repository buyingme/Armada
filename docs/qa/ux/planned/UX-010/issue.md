# UX-010 — Transition banners and timers are used outside their intended contexts

Category: High
Area: Player Transition / Match Completion
Layer: Command Flow

## Problem

Player-transition banners and their associated timers are currently shown in gameplay situations where they are not required.

In particular, during the Squadron Phase, transitions between players can display a transition banner and wait for its timer before gameplay continues.

This unnecessarily interrupts and slows the game.

Transition banners with an enforced presentation delay are only required where the physical Hot-Seat context makes an explicit handover useful, and at match completion.

### Normal player transitions

The previously established intended behavior is:

**Hot-Seat — Command Phase**

When control must pass between players for private command-dial selection, the transition banner and timer should be used.

This provides a clear handover point before the next player performs a private interaction.

**Hot-Seat — other gameplay transitions**

Ordinary transitions between players should not introduce the transition banner/timer unless separately required.

In particular, Squadron Phase transitions should proceed without the current artificial banner delay.

**Network**

Normal player transitions should not use the transition banner or its timer.

Each player has their own screen, so the physical handover behavior required for Hot-Seat command-dial selection is unnecessary.

Network presentation should follow authoritative game state/projection without introducing presentation timing as a prerequisite for ordinary gameplay continuation.

### Match completion

Match completion is a separate case where the banner should deliberately be used.

**Network**

When the match is finished:

- the winning player's screen should display `VICTORY`;
- the losing player's screen should display `DEFEAT`;
- both presentations should correspond to the same authoritative match result;
- after a 2-second presentation period, the Result screen should be shown.

**Hot-Seat**

When the match is finished:

1. determine the winning player;
2. rotate/orient the table to the winner's side;
3. display `VICTORY`;
4. keep the victory presentation visible for 2 seconds;
5. show the Result screen.

A separate `DEFEAT` presentation is not required in Hot-Seat because the shared display is deliberately oriented toward the winner before the result is presented.

## Impact

The current transition presentation unnecessarily slows gameplay, particularly during the Squadron Phase where control can change frequently.

A transition banner is valuable when it serves a concrete UX purpose, such as protecting private command-dial selection during Hot-Seat play. Applying the same delay to ordinary transitions adds friction without providing equivalent value.

At match completion, however, a short deliberate presentation provides useful closure and makes the result immediately understandable before transitioning to the Result screen.

The banner/timer behavior therefore needs to distinguish between:

- Hot-Seat private handover;
- ordinary Hot-Seat gameplay transitions;
- Network gameplay transitions; and
- match completion.

## Evidence

Observed regression:

- During the Squadron Phase, transitions between players display a transition banner.
- The associated timer delays continuation.
- Frequent Squadron Phase player changes make this especially noticeable.

Previously established requirement:

- transition banner/timer is required for Hot-Seat Command Phase command-dial selection;
- ordinary Network player transitions do not require this presentation delay.

New match-completion requirement:

- Network winner: `VICTORY`;
- Network loser: `DEFEAT`;
- Hot-Seat: orient table toward winner and display `VICTORY`;
- after 2 seconds, transition to the Result screen.

## Investigation hint

Identify all current callers and triggering conditions for the player-transition banner and timer.

Do not solve the regression by adding Squadron-Phase-specific suppression if the underlying problem is that generic player transitions automatically trigger the banner.

Determine whether banner presentation is currently coupled too broadly to:

- active-player changes;
- phase/turn transitions;
- controller changes;
- network synchronization; or
- other generic gameplay progression.

The intended behavior should be driven by the semantic reason for the presentation rather than by every change of active player.

The required presentation cases are:

1. Hot-Seat Command Phase private command-dial handover.
2. Match completion.

Ordinary gameplay player transitions should not inherit the banner/timer merely because the active player changed.

Network gameplay continuation must not depend on client-side presentation timing.

For match completion, determine the authoritative match-result source and project the appropriate result to each screen.

The intended invariants are:

> Ordinary player transitions do not introduce unnecessary banner/timer delays.

> Hot-Seat Command Phase private handover retains its transition presentation.

> Match completion deliberately presents the authoritative result before entering the Result screen.

## Resolution

Improvement:

Not yet implemented.

Target behavior: restrict transition banners/timers to their intended UX purposes and provide explicit mode-aware match-completion presentation.

Verification:

- Hot-Seat Command Phase command-dial handover still displays the intended transition banner and timer.
- Hot-Seat Squadron Phase player transitions do not display an unnecessary transition banner/timer.
- Other ordinary Hot-Seat player transitions do not acquire unnecessary banner delays.
- Network Squadron Phase player transitions do not display the transition banner/timer.
- Other ordinary Network player transitions do not display the transition banner/timer.
- Removing the presentation delay does not alter authoritative turn/player progression.
- Network gameplay continuation does not depend on presentation timing.
- At Network match completion, the winner sees `VICTORY`.
- At Network match completion, the loser sees `DEFEAT`.
- Both Network presentations derive from the same authoritative match result.
- After 2 seconds, the Network presentation transitions to the Result screen.
- At Hot-Seat match completion, the table rotates/orients to the winner's side.
- Hot-Seat then displays `VICTORY`.
- After 2 seconds, Hot-Seat transitions to the Result screen.
- Replay/save/load/network behavior is checked where match completion or player-transition state is recoverable.
- Existing Result screen functionality remains unchanged except for the required preceding presentation sequence.
