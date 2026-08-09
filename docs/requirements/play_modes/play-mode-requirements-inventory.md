# Play-Mode Requirements Inventory

## Purpose

Capture the use cases that matter for Hot-Seat / Network unification.

Focus on what players need, not how the current implementation works. Keep entries short. Details will be added during later analysis.

## PM-XXX — [Short name]

**Situation:**
[When does this occur?]

**Common need:**
[What must the game/player be able to do or understand?]

**Mode-specific need:**
[Only what genuinely must differ between Hot-Seat and Network. "None known" is valid.]

**Current behavior / notes:**
[Optional. Known current behavior, historical solution, uncertainty, or possible simplification.]

## PM-001 — Decision Maker Changes

Situation:
Responsibility for the next decision changes between players, including temporary or minor decisions.

Common need:
It must always be clear which player is currently expected to act or make a decision.

Mode-specific need:
- Hot-Seat: The shared presentation switches to the current human decision maker's table perspective. The acting player sees the table from their board edge, with their own ship cards at the top left and the opposing player's ship cards at the top right.
- Network: Each human player always views the table from their own fixed table side. The perspective does not change when decision responsibility changes.
- Player vs. Bot: The human player always views the table from their own fixed table side. The perspective does not change when the bot becomes the decision maker.

Current behavior / notes:
A short, clearly perceptible visual indication should communicate changes in decision responsibility. Perspective changes are required only where multiple human players share the same presentation, as in Hot-Seat. Physical table rotation is an implementation choice, not itself the requirement.

## PM-002 — Secret Command Dial Information

Situation:
Players select their command dial stacks in round one, replenish them in subsequent rounds, inspect their own command stacks, and reveal command dials when activating ships.

Common need:
A player's command dial stack is private information. Each player may inspect their own command stack at any time but must never see the opposing player's command stack.

When a command dial is revealed as part of a ship activation, that revealed dial becomes public game information and is visible to both players.

Mode-specific need:
- Hot-Seat: Because both players share one presentation, command dial selection, replenishment, and inspection must prevent the other player from seeing the private command stack. Initial selection and replenishment therefore occur sequentially.
- Network: Each player sees only their own private command information on their separate game instance. Players may therefore perform command dial selection or replenishment simultaneously.
- Player vs. Bot: The human player must never see the bot's command stack. The bot must never have access to the human player's command stack. Each side may access its own command stack at any time.

Current behavior / notes:
Hot-Seat currently performs command dial selection sequentially, while Network allows both players to make their choices simultaneously. Revealing a command dial during ship activation is public and common to all play modes.


