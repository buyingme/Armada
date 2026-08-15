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

## Implementation Update — 2026-08-14

Confirmed root cause:

`TarkinChoiceModal` built each command as a text-only button and did not use the
existing command-token assets or the standard icon-above-action hierarchy.

Implemented improvement:

Each Tarkin command choice now uses the existing command-token PNG mapping,
an icon above the semantic command button, centered choice columns, and
consistent spacing. The existing `TarkinChoiceCommand` submission signals and
payload are unchanged.

Architecture/ownership:

Only presentation construction changed. Asset/component consistency did not
cause gameplay refactoring and introduced no UI-owned command state.

Regression evidence and verification:

- `test_command_choices_reuse_token_graphics_and_standard_hierarchy` proves
  the expected graphic and layout hierarchy;
- existing interactive/passive and semantic submission tests remain passing;
- focused Tarkin modal/router suites: 5/5 and 28/28 passed;
- full repository suite: 4,048/4,048 passed (13,507 assertions);
- architecture lint and `git diff --check`: passed.

Status: implemented by automated evidence; ready for Project Owner/manual UX
comparison.
