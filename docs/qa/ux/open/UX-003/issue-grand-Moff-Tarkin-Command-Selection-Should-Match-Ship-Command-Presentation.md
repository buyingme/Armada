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
