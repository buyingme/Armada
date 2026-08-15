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

## Implementation Update — 2026-08-14

Confirmed root cause:

After accepted `BeginAttack`, `AttackExecutor.apply_begin_attack_result()`
retired voluntary Skip but never retired the declaration Confirm button.
Clearing the transient target candidate did not rebuild that control, so
"Confirm Attack" survived beside the committed pre-roll action.

Implemented improvement:

The accepted BeginAttack presentation boundary now hides declaration Confirm
before projecting the applicable pre-roll choice or Roll Dice action.
Authoritative `BeginAttackCommand` validation remains unchanged and continues
to reject a repeated declaration while an attack is active.

Architecture/ownership:

The change hides an obsolete derived control only after accepted command
state. `CurrentAttackState`, attack ownership, validation, and semantic command
flow are unchanged.

Regression evidence and verification:

- the production-board regression proves one accepted BeginAttack, hidden
  Confirm/Skip, visible Roll, and an active canonical attack;
- existing direct-command tests continue to prove repeated Begin rejection;
- focused `test_current_attack_production_resume.gd`: 43/43 passed (764
  assertions);
- full repository suite: 4,048/4,048 passed (13,507 assertions);
- architecture lint and `git diff --check`: passed.

Status: implemented by automated evidence; ready for Project Owner/manual UX
verification.
