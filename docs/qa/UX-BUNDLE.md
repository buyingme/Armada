

===== FILE: docs/qa/ux/open/UX-001/issue-confirm-attack-remains-visible-after-confirmation.md =====

# UX-001 — Confirm Attack Remains Visible After Confirmation

Category: High
Area: Attack Execution
Layer: Projection

## Problem

After an attack has been confirmed and entered the pre-roll stage, the Confirm Attack action remains visible.

At this point, the attack has already been committed. The player should only be presented with actions that are valid for the current attack stage.

## Impact

The repeated Confirm Attack action makes the interaction flow unclear and suggests that the attack still requires confirmation.

It may also allow the player to attempt the same action more than once, even though confirmation is no longer valid.

## Evidence

annotation_20260729_065741_001.json

The captured state shows:

- an active attack;
- the attacker and defender already selected;
- obstruction resolved;
- attack stage pre_roll;
- no dice rolled yet.

## Investigation Hint

The issue appears immediately after the attack transitions to `pre_roll`.

## Resolution

Improvement:

When an attack enters the pre-roll stage:

- do not project the Confirm Attack action;
- present Roll Dice as the primary available action;
- reject any repeated Confirm Attack command if it is no longer valid.

Verification:

- Confirm an attack.
- Verify that Confirm Attack disappears immediately.
- Verify that Roll Dice remains available.
- Verify that a repeated Confirm Attack command cannot be submitted successfully.

## Layer Definition

### Presentation

Visual appearance and layout, including text, icons, colors, spacing, sizing, windows, and controls.

### Projection

Game information or available actions are missing, unclear, misleading, or inconsistent with the authoritative game state.

### Command Flow

Player interactions or game progression are confusing, inefficient, poorly timed, or require unnecessary actions.

### Architecture

The improvement appears to require a structural or system-level change rather than a local UI adjustment.

### Rules

The game rules themselves create a poor player experience, even when implemented correctly.

### Animation

Animations, transitions, visual effects, or feedback timing reduce clarity or usability.

### Input

Mouse, keyboard, controller, drag-and-drop, hit detection, focus, or other interaction behavior.

### Performance

Loading time, responsiveness, frame rate, stuttering, or delays negatively affect the experience.

### Accessibility

Readability, contrast, font size, keyboard navigation, color dependence, or other usability barriers.


===== FILE: docs/qa/ux/open/UX-003/issue-grand-Moff-Tarkin-Command-Selection-Should-Match-Ship-Command-Presentation.md =====

# UX-003 — Grand Moff Tarkin Command Selection Should Match Ship Command Presentation

Category: Polish
Area: Command Selection UI
Layer: Presentation

## Problem

The Grand Moff Tarkin command-selection dialog uses a different visual layout than the standard ship command-selection dialog.

The available command tokens are not displayed above the command buttons, resulting in an inconsistent presentation.

## Impact

Players are presented with two visually different command-selection dialogs for equivalent interactions.

This reduces consistency and makes the Tarkin dialog feel less integrated with the rest of the interface.

## Evidence

annotation_20260730_064813_001.json

The captured state shows the Grand Moff Tarkin command-selection dialog.

## Investigation hint

Compare the Grand Moff Tarkin command-selection dialog with the standard ship command-selection dialog.

## Resolution

Improvement:

Align the Grand Moff Tarkin command-selection dialog with the standard ship command-selection layout.

Specifically:

- display the command token graphics above the command buttons;
- use the same visual hierarchy and spacing as the ship command-selection dialog.

Verification:

- Open the Grand Moff Tarkin command-selection dialog.
- Compare it with the ship command-selection dialog.
- Verify that both dialogs present command tokens and command buttons using the same layout.
