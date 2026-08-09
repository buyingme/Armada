# Play-Mode Requirements Inventory

## Purpose

Capture the use cases that matter for Hot-Seat / Network unification.

Focus on what players need, not how the current implementation works. Keep entries short. Details will be added during later analysis.

### Working Direction

This inventory is incomplete and will grow as additional play-mode situations are examined.

Unless a use case demonstrates otherwise, Hot-Seat, Network, and Player-vs.-Bot should share the same authoritative gameplay rules, state transitions, and decision semantics. Play-mode differences should be limited to genuine differences such as controller location, information visibility, presentation, and whether multiple players share one physical presentation.

A mode-specific presentation or interaction mechanism should not become the authoritative source of gameplay progression merely because one play mode currently depends on it.

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

## PM-003 — Range Measurement

Situation:
A player wants to measure range during the game. Range may be measured at any time and does not itself change game state.

Common need:
Players must be able to measure range whenever they are able to interact with their presentation. Range measurement is an informational aid and does not constitute an authoritative gameplay action.

Mode-specific need:
- Hot-Seat: Because both players share one presentation, only the player currently controlling the shared presentation can practically use the range-measuring tool at that moment.
- Network: Each player may use the range-measuring tool independently at any time. Measurements are local to that player's presentation and do not need to be shown to the opponent.
- Player vs. Bot: The human player may use the range-measuring tool at any time. The bot does not require a presentation-level measuring tool.

Current behavior / notes:
Range measurement is currently transient presentation state and is not represented by gameplay commands. This is acceptable because measuring range does not mutate authoritative game state and does not need to be replayed or synchronized.

## PM-004 — Analysis and Planning Tools

Situation:
A player uses a non-authoritative tool, such as the Attack Simulator, to inspect possible game actions or plan ahead.

Common need:
Analysis tools must use the same game-rule logic as actual gameplay for any result they calculate, such as legal targets, firing arcs, line of sight, or range. Their presentation and interaction flow may differ from normal gameplay.

Mode-specific need:
None known. Analysis-tool interaction may remain local to the player using it and does not need to be projected to the opposing player's presentation.

Current behavior / notes:
The Attack Simulator currently implements only part of the intended functionality, including legal-target and related targeting analysis. It is a planning/debugging aid and does not itself change authoritative game state.

## PM-005 — Authoritative Gameplay Progression

Situation:
Gameplay moves between decision points and action opportunities, for example from an Attack opportunity to Maneuver, or into and out of a Squadron-command opportunity. The player responsible for the next action may be local, remote, or computer-controlled.

Common need:
The game must be able to determine the current authoritative gameplay progression and available action opportunity independently of presentation state and independently of which type of controller will act.

The same authoritative state transition should be used whether the acting player is a local human, a remote human, or a future bot.

Mode-specific need:
- Hot-Seat: The shared presentation may change perspective or active controls when decision responsibility changes.
- Network: Each player's presentation may project different controls or information, but both instances must represent the same authoritative gameplay progression.
- Player vs. Bot: The bot may act without presentation interaction, using the same authoritative gameplay state and legal action semantics used for human-controlled play.

Current behavior / notes:
Some existing gameplay progression is still represented partly by presentation or transient application state. This inventory does not prescribe how that state should be implemented. The requirement is that gameplay progression needed to authorize or continue play must ultimately be available from authoritative game state rather than requiring scene, modal, controller, or presentation state.

This requirement does not imply that purely informational or planning interactions must become authoritative gameplay actions. PM-003 range measurement and PM-004 analysis/planning tools remain examples of interactions that may stay local and non-authoritative.
