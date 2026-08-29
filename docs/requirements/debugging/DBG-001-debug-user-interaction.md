# DBG-001 — Debug User Interaction

Status: Accepted Owner interaction decisions
Accepted by: Project Owner
Accepted date: 2026-08-29

## Purpose and Scope

This specification defines the user interaction for the bounded authoritative
debug slice in [DBG-001 — Authoritative Debug State Mutation](DBG-001-authoritative-debug-state-mutation.md).

DBG-001 remains authoritative for canonical state, commands, replay, Network,
and rule-integration requirements. This document defines only how users enter,
operate, commit, cancel, and observe those capabilities.

## Debug Mode Availability and Ownership

F12 remains the transition between ordinary gameplay and DEBUG when DEBUG is
eligible. DEBUG may be entered and used during live gameplay only when no modal
or nested interaction has exclusive input ownership. It must not interrupt,
replace, or bypass an already-open gameplay decision interaction.

While DEBUG is active, it exclusively owns ordinary board token interaction.
Ordinary gameplay token selection and action are suspended until DEBUG ends.
There is no simultaneous ordinary-gameplay/debug token interaction, cooldown,
or automatic restoration of a previous DEBUG mode.

In Network play, DEBUG mode is host-only. The host may enter and use DEBUG;
the client must not enter or use DEBUG tooling, including presentation-only
tools exposed through DEBUG. Host debug authority remains independent of the
gameplay side the host controls. Client-originating state-changing debug
commands must still be rejected as defense in depth under DBG-001.

## Selection and Canonical Readout

In ordinary DEBUG mode, clicking a ship or squadron selects it for debug
manipulation. The selected object must have a clear visual highlight.

The existing DEBUG HUD/help surface must show a minimal readout for the
selected movable object:

- object identity;
- canonical X;
- canonical Y; and
- canonical orientation/rotation.

The readout is diagnostic only, not a general-purpose inspector or property
editor. During reposition preview it continues to show the current canonical
transform rather than the preview transform. After a successful authoritative
commit, it updates to the new canonical transform.

## Repositioning

### Preview and Commit

1. Clicking a movable token selects it, highlights it, and locks it to the
   cursor.
2. Cursor movement previews position locally without authoritative mutation.
3. The existing rotation interaction remains available during preview.
4. The next click, regardless of pointer location, commits the final preview
   position and orientation through the authoritative debug command.
5. A successful commit ends manipulation and removes the selection/highlight.

Only the final committed transform enters command, replay, and Network history.
Continuous cursor movement must not generate continuous authoritative commands.

Existing collision and board-boundary assistance remains active during preview
and placement. Debug repositioning may bypass ordinary maneuver and activation
legality, but it is not unrestricted overlapping or out-of-board placement.
This does not define new geometry rules.

### Cancel and Rejection

Before commit, Escape cancels manipulation and restores the latest canonical
transform. Leaving DEBUG also cancels the preview and restores that transform.
Cancellation creates no authoritative mutation.

If the authoritative commit is rejected, presentation must be restored to the
latest canonical transform; manipulation and its highlight must end; concise
debug rejection feedback must be shown; and retry requires a new selection and
transaction. The rejected preview must not be retained or retried
automatically.

## Damage-Card Assignment

From ordinary DEBUG mode, Shift+D enters an exclusive `DEBUG / DEAL DAMAGE`
sub-mode. The UI clearly requests selection of a ship. Clicking a valid ship
opens the damage-card picker; the user selects one card and Confirm performs
the authoritative debug damage operation.

Cancel or Escape before Confirm exits without an authoritative mutation.
Completion or cancellation normally returns to ordinary DEBUG mode. While this
sub-mode owns input, debug reposition selection must not also occur.

The command path must satisfy DBG-001's requirement that canonical deck
consumption and card materialization occur authoritatively. This document does
not define that command mechanism.

Debug authority constructs the requested test state only. If that committed
state exposes an ordinary gameplay choice, the choice belongs to the normal
authoritative gameplay controller. In Network play it may therefore belong to
the client even when the host initiated the debug mutation. The host must not
resolve it merely because it initiated DEBUG.

DEBUG ends before such a gameplay decision is presented, and control returns to
ordinary gameplay. DEBUG does not automatically resume after the decision; F12
becomes available again when the board is ordinarily debug-eligible. If no
interactive consequence is exposed, the host may remain in ordinary DEBUG
mode.

## Feedback and Safe Exit

Authoritative debug mutations must provide concise debug-specific confirmation
on success and concise debug-specific error or rejection feedback on failure.
For repositioning, confirmation plus the updated canonical readout must make
the authoritative commit boundary observable. Detailed diagnostics remain in
logs and replay rather than the ordinary UI.

Leaving DEBUG is a safe exit operation. It must cancel transient reposition
preview, cancel unconfirmed damage targeting or card picking, clear transient
debug selection/sub-mode state, and restore presentation from canonical state
where required. It must never undo an already committed authoritative debug
mutation.

## Network Presentation

The host's local reposition preview is not streamed to clients. Clients receive
only committed authoritative debug results through the normal synchronization,
projection, and filtering path defined by DBG-001.

## Presentation-Only Diagnostics and Boundaries

The architectural distinction in DBG-001 between authoritative state-changing
debug operations and observation-only diagnostics remains in force. This
specification does not expand the first slice into migration or redesign of
range, targeting, firing-arc, maneuver, attack-simulator, annotation, or other
presentation-only diagnostic tools.

In Network mode, the host-only DEBUG policy above applies to those tools as
well.

## Non-Goals

This specification does not define:

- a general-purpose debug property editor or inspector;
- continuous authoritative reposition commands;
- streamed Network reposition previews;
- player impersonation or persistent debug identity; or
- automatic restoration of DEBUG after an ordinary gameplay decision.
