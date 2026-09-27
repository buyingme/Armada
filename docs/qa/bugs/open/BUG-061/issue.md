# BUG-061 — Debug Immediate Choice Is Lost on Board Reconstruction

**Status:** Open

## Finding

The BUG-043 R3 production board-entry test installed a valid debug-owned Injured Crew decision and opened the normal GameBoard. The immediate controller did not reopen its modal because its only entry was the live `debug_deal_damage` result callback. No command was synthesized; the player was left without the canonical decision.

## Bounded repair

On normal board reconstruction, let the existing debug immediate controller derive its pending public card and actor from canonical state and open only a genuine player choice. Automatic records remain authority-owned. This adds no alternate gameplay owner or generic reconstruction path.
