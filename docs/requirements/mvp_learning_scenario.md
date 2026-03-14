# MVP Requirements — Learning Scenario

> **Scope:** Implement the Learning Scenario from the core set Learn to Play booklet (pages 5–18).
> This is a fixed-fleet, no-upgrades, no-objectives introductory game that exercises all core mechanics.

## Table of Contents

- [1. Game Overview](#1-game-overview)
- [2. Setup Requirements](#2-setup-requirements)
- [3. Game Flow](#3-game-flow)
- [4. Command Phase](#4-command-phase)
- [5. Ship Phase](#5-ship-phase)
- [6. Squadron Phase](#6-squadron-phase)
- [7. Status Phase](#7-status-phase)
- [8. Commands](#8-commands)
- [9. Attack Resolution](#9-attack-resolution)
- [10. Defense Tokens](#10-defense-tokens)
- [11. Damage](#11-damage)
- [12. Ship Movement](#12-ship-movement)
- [13. Squadron Mechanics](#13-squadron-mechanics)
- [14. Overlapping](#14-overlapping)
- [15. Winning and Scoring](#15-winning-and-scoring)
- [16. Game Components (Digital)](#16-game-components-digital)
- [17. UI Requirements](#17-ui-requirements)
- [18. Network Multiplayer Considerations](#18-network-multiplayer-considerations)
- [19. Debug Mode](#19-debug-mode)

---

## 1. Game Overview

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| GO-001 | The game is a competitive two-player game. Each player controls a fleet of ships and squadrons. | LTP p.6 "Object of the Game" |
| GO-002 | The game is played over exactly 6 rounds. | LTP p.6; RRG "Round" |
| GO-003 | Each round consists of 4 phases in order: Command → Ship → Squadron → Status. | LTP p.6; RRG "Round" |
| GO-004 | The game ends immediately if all of one player's **ships** are destroyed (squadrons alone do not prevent elimination). | LTP p.11; RRG "Winning and Losing" |
| GO-005 | The golden rule: if a component's effect contradicts the rulebook, the component's effect takes precedence. | RRG p.1 "Golden Rules" |
| GO-006 | The word "cannot" is absolute and cannot be overridden by other effects. | RRG p.1 "Golden Rules" |

## 2. Setup Requirements

### 2.1 Play Area

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| SU-001 | The play area is 3' × 3' (Learning Scenario). The entire play area serves as the setup area. | LTP p.5 "Learning Scenario Setup" step 1 |
| SU-002 | The system must render a 2D top-down view of the play area. | ADR-006 |
| SU-003 | All graphics are 2D PNGs provided by the user. The system must support loading and displaying these assets. | User requirement |

### 2.2 Fixed Fleet Composition

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| SU-010 | The Rebel player fields: CR90 Corvette A, Nebulon-B Escort Frigate, X-wing Squadron (×1). | LTP p.5 step 4 |
| SU-011 | The Imperial player fields: Victory II-class Star Destroyer, TIE Fighter Squadron (×1). | LTP p.5 step 4 |
| SU-012 | No upgrade cards, objective cards, or obstacle tokens are used. | LTP p.3 ("using only the essential components and rules") |

### 2.3 Initialization

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| SU-020 | The Rebel player has initiative. The initiative token displays the blue side with the ★ icon. | LTP p.5 step 3 |
| SU-021 | All ships start with speed dials set to 2. | LTP p.5 step 6 |
| SU-022 | All shield dials are set to maximum values per ship card data. | LTP p.5 step 6 |
| SU-023 | Command dials are placed near ship cards: CR90=1, Nebulon-B=2, Victory II=3 (matching command values). | LTP p.5 step 6 |
| SU-024 | All squadron disks are set to maximum hull points. | LTP p.5 step 7 |
| SU-025 | All activation sliders display the blue side. | LTP p.5 step 7 |
| SU-026 | Defense tokens matching each ship card are placed next to the ship card in READY state. | LTP p.5 step 8 |
| SU-027 | Ships and squadrons are placed at fixed positions as shown in the Learning Scenario diagram. | LTP p.5 step 9 |
| SU-028 | The round token "1" is placed beside the play area. | LTP p.5 step 10 |
| SU-029 | The damage deck (52 cards) is shuffled and placed facedown. | LTP p.5 step 10 |
| SU-030 | Command tokens are placed in a shared supply. | LTP p.5 step 11 |

### 2.4 Ship Card Data (Learning Scenario)

All ship/squadron data is sourced from the verified JSON files in `Resources/Game_Components/ships/` and `Resources/Game_Components/squadrons/`.

| Ship | Faction | Size | Hull | Cmd | Sqd | Eng | Speed | Shields (F/L/R/R) | Defense Tokens |
|------|---------|------|------|-----|-----|-----|-------|-------------------|----------------|
| CR90 Corvette A | Rebel | Small | 4 | 1 | 1 | 2 | 4 | 2/2/2/1 | Evade, Evade, Redirect |
| Nebulon-B Escort | Rebel | Small | 5 | 2 | 2 | 3 | 3 | 3/1/1/2 | Evade, Brace, Redirect |
| Victory II-class | Empire | Medium | 8 | 3 | 3 | 4 | 2 | 3/3/3/1 | Redirect, Evade, Brace, Redirect |

| Squadron | Faction | Hull | Speed | Anti-Sqd | Battery | Keywords |
|----------|---------|------|-------|----------|---------|----------|
| X-wing | Rebel | 5 | 3 | 4 Blue | 1 Red | Bomber, Escort |
| TIE Fighter | Empire | 3 | 4 | 3 Blue | 1 Blue | Swarm |

## 3. Game Flow

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| GF-001 | Rounds are numbered 1–6. The current round number is tracked and displayed. | LTP p.6; RRG "Round" |
| GF-002 | Within each round, phases execute in strict order: Command → Ship → Squadron → Status. | LTP p.6 |
| GF-003 | At the end of the Status Phase, the round number increments. If round 6 is complete, the game ends. | LTP p.11; RRG "Status Phase" |
| GF-004 | If all of one player's ships are destroyed at any point, the game ends immediately. | LTP p.11; RRG "Winning and Losing" |

## 4. Command Phase

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| CP-001 | During this phase, players **secretly and simultaneously** choose commands on command dials for each of their ships. | LTP p.7; RRG "Command Phase" |
| CP-002 | Each ship must be assigned command dials until it has a number of dials equal to its command value. | RRG "Command Phase" |
| CP-003 | In the first round, each ship receives its full complement of dials (CR90=1, Neb-B=2, VSD=3). | LTP p.7 |
| CP-004 | In subsequent rounds, each ship receives exactly 1 new dial, placed **under** any existing dials. | LTP p.7; RRG "Command Phase" |
| CP-005 | A command is chosen by setting the dial to one of 4 commands: Navigate (M), Squadron (O), Repair (Q), Concentrate Fire (P). | LTP p.7 |
| CP-006 | Dials are placed facedown (hidden from opponent). Players can view their own dials at any time but must preserve the order. | RRG "Command Dials" |
| CP-007 | A ship with a faceup command dial on its ship card (i.e., already activated this round) cannot be activated again. | RRG "Command Dials" |
| CP-008 | **[Network sync point]** Both players must submit all dial selections before proceeding to the Ship Phase. The server must validate that each ship has the correct number of dials. | ADR-007 |

## 5. Ship Phase

### 5.1 Activation Order

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| SP-001 | The player with initiative activates one ship first. Then the opponent activates one ship. Players alternate. | LTP p.8; RRG "Ship Phase" |
| SP-002 | When a ship finishes activation, its revealed command dial is placed faceup on its ship card (marking it as activated). | LTP p.8 |
| SP-003 | If a player has no unactivated ships remaining, they must pass their turn for the rest of the phase. | LTP p.8; RRG "Ship Phase" |
| SP-004 | Players cannot activate ships that have already been activated this round. | RRG "Ship Phase" |

### 5.2 Ship Activation Steps

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| SP-010 | A ship activation consists of exactly 3 steps, in order: (1) Reveal Command Dial, (2) Attack, (3) Execute Maneuver. | LTP p.8; RRG "Ship Activation" |
| SP-011 | **Reveal Command Dial:** The top facedown dial is revealed and placed next to the ship. The player can either: (a) keep it to spend later at the appropriate time for its full effect, or (b) spend it immediately to gain the matching command token. | LTP p.8; RRG "Command Dials" |
| SP-012 | **[Network sync point]** The revealed command dial and the player's choice (keep or convert to token) must be communicated to all clients. | ADR-007 |
| SP-013 | **Attack:** The ship may perform up to 2 attacks, each from a **different hull zone**. | LTP p.8; RRG "Attack" |
| SP-014 | A ship cannot attack from the same hull zone more than once per activation. | RRG "Attack" |
| SP-015 | **Execute Maneuver:** The ship must execute a maneuver (movement is mandatory). | LTP p.8; RRG "Ship Activation" |
| SP-016 | During the first round of the learning scenario, attacks can be skipped (ships not in range). | LTP p.8 |

## 6. Squadron Phase

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| SQ-001 | After all ships have been activated, the Squadron Phase begins. | LTP p.10 |
| SQ-002 | Squadrons that were activated by a Squadron command during the Ship Phase are already activated and cannot activate again. | LTP p.10; RRG "Squadron Activation" |
| SQ-003 | The initiative player activates **two** unactivated squadrons. Then the opponent activates **two**. Players alternate. | LTP p.10; RRG "Squadron Phase" |
| SQ-004 | If a player has only 1 unactivated squadron when choosing the first, they activate only that one. | RRG "Squadron Phase" |
| SQ-005 | If a player has no unactivated squadrons, they pass for the rest of the phase. | RRG "Squadron Phase" |
| SQ-006 | A squadron activated during this phase may **either** move **or** attack, but **not both**. | LTP p.10; RRG "Squadron Phase" |
| SQ-007 | A squadron activated by a Squadron command (during Ship Phase) can move **and** attack in either order. | LTP p.12; RRG "Commands" |
| SQ-008 | After activation, the squadron's activation slider is toggled to track that it was activated. | LTP p.11; RRG "Squadron Activation" |
| SQ-009 | A squadron cannot activate if its slider state doesn't match the initiative token. | RRG "Squadron Activation" |

## 7. Status Phase

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| ST-001 | All exhausted defense tokens are readied (flipped to their readied side). | LTP p.11; RRG "Status Phase" |
| ST-002 | The initiative token is flipped to its other side. This determines the unactivated color for the next round's squadrons. | LTP p.11; RRG "Status Phase" |
| ST-003 | The first player places the round token with the next highest number (advancing the round counter). | LTP p.11; RRG "Status Phase" |
| ST-004 | All faceup command dials on ship cards are cleared (ships become available for next round's activation). | Implied by CP-007 / activation flow |

## 8. Commands

### 8.1 General Command Rules

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| CM-001 | A command is resolved by spending a command dial or command token with the matching icon at the appropriate time. | RRG "Commands" |
| CM-002 | A ship cannot resolve the same command more than once per round. | RRG "Commands" |
| CM-003 | A ship can spend both a dial and a token to combine effects (counts as a single resolution). The decision to spend dial, token, or both must be made before resolving. | RRG "Commands" |
| CM-004 | A ship assigned a command token that exceeds its command value must immediately discard one. | RRG "Command Tokens" |
| CM-005 | A ship cannot have duplicate command tokens (same type). If assigned a duplicate, it is immediately discarded. | RRG "Command Tokens" |
| CM-006 | A command token can be spent in the same round it was gained. | RRG "Command Tokens" |
| CM-007 | After a ship finishes activation, if it did not spend its command dial, that dial is discarded (placed faceup on ship card). | RRG "Command Dials" |

### 8.2 Navigate (M)

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| CM-010 | **Timing:** Resolved during the "Determine Course" step of movement. | RRG "Commands" |
| CM-011 | **Dial effect:** Increase or decrease speed by 1 **and/or** increase the yaw value of one joint by 1 for this maneuver. | RRG "Commands"; LTP p.11 |
| CM-012 | **Token effect:** Increase or decrease speed by 1. | RRG "Commands"; LTP p.11 |
| CM-013 | Minimum speed is 0. Maximum speed is per the ship's speed chart. | LTP p.11; RRG "Speed" |

### 8.3 Squadron (O)

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| CM-020 | **Timing:** Resolved after revealing the ship's command dial. | RRG "Commands" |
| CM-021 | **Dial effect:** Activate up to [squadron value] friendly squadrons at close–medium range. Each activated squadron can attack **and** move in either order. Squadrons are chosen and activated one at a time. | RRG "Commands"; LTP p.12 |
| CM-022 | **Token effect:** Activate **one** friendly squadron following the same rules. | RRG "Commands"; LTP p.12 |

### 8.4 Repair (Q)

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| CM-030 | **Timing:** Resolved after revealing the ship's command dial. | RRG "Commands" |
| CM-031 | **Dial effect:** Gain engineering points equal to the ship's engineering value. Spend on repair effects. | RRG "Commands"; LTP p.12 |
| CM-032 | **Token effect:** Gain engineering points equal to **half** the engineering value, rounded **up**. | RRG "Commands"; LTP p.12 |
| CM-033 | **Move Shields (1 pt):** Reduce one hull zone's shields by 1 and increase another's by 1 (not exceeding max). | RRG "Commands" |
| CM-034 | **Recover Shields (2 pts):** Recover 1 shield on any hull zone (not exceeding max). | RRG "Commands" |
| CM-035 | **Repair Hull (3 pts):** Discard one faceup or facedown damage card from this ship. | RRG "Commands" |
| CM-036 | Effects can be resolved in any order and each can be paid for multiple times if engineering points permit. | RRG "Commands" |
| CM-037 | Remaining engineering points are lost after the command resolves. They do not persist. | RRG "Commands" |

### 8.5 Concentrate Fire (P)

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| CM-040 | **Timing:** Resolved during the "Resolve Attack Effects" step of an attack. | RRG "Commands" |
| CM-041 | **Dial effect:** Add one attack die to the pool. That die must be a color already in the pool. | RRG "Commands"; LTP p.12 |
| CM-042 | **Token effect:** Reroll one attack die in the pool. | RRG "Commands"; LTP p.12 |

## 9. Attack Resolution

### 9.1 Attack Steps

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| AT-001 | An attack proceeds through up to 6 steps in order. | RRG "Attack" |
| AT-002 | **Step 1: Declare Target.** The attacker declares an attacking hull zone and a defending hull zone (or squadron). The defender must be inside the attacking hull zone's firing arc and at attack range. | RRG "Attack" step 1 |
| AT-003 | **Step 2: Roll Attack Dice.** Gather dice from the attacking hull zone's battery armament (vs. ship) or anti-squadron armament (vs. squadron). Only dice colors valid for the attack range may be gathered. If no valid dice can be gathered, the attack is canceled. | RRG "Attack" step 2 |
| AT-004 | **Step 3: Resolve Attack Effects.** The attacker may: (a) modify dice via card effects or Concentrate Fire command, (b) spend accuracy (G) icons to lock the defender's defense tokens. | RRG "Attack" step 3 |
| AT-005 | **Step 4: Spend Defense Tokens.** The defender may spend one or more defense tokens. | RRG "Attack" step 4 |
| AT-006 | **Step 5: Resolve Damage.** The attacker may resolve one critical effect. Then total damage is determined and the defender suffers it, one point at a time. | RRG "Attack" step 5 |
| AT-007 | **Step 6: Declare Additional Squadron Target.** If the attacker is a ship and the defender was a squadron, the attacker may declare another enemy squadron as a new defender and repeat steps 2–6. The new target must be in the same hull zone's arc and at range. Each squadron can be targeted only once per attack. | RRG "Attack" step 6 |

### 9.2 Attack Dice and Range

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| AT-010 | Three dice colors exist: Red, Blue, Black. | LTP p.13 |
| AT-011 | **Long range:** Only red dice may be rolled. | LTP p.13; RRG "Attack Range" |
| AT-012 | **Medium range:** Red and blue dice may be rolled. | LTP p.13; RRG "Attack Range" |
| AT-013 | **Close range:** Red, blue, and black dice may be rolled. | LTP p.13; RRG "Attack Range" |
| AT-014 | A hull zone's maximum attack range is: close (only black), medium (has blue), or long (has red). | RRG "Attack Range" |

### 9.3 Dice Icons

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| AT-020 | **Hit (F):** Adds 1 to the damage total. | RRG "Dice Icons" |
| AT-021 | **Critical (E):** If both attacker and defender are ships, adds 1 to damage total and can trigger critical effect. | RRG "Dice Icons" |
| AT-022 | **Accuracy (G):** Attacker may spend to lock one defender defense token (preventing its use this attack). | RRG "Dice Icons" |
| AT-023 | A blank face has no icons and no effect. | RRG "Dice Icons" |

### 9.4 Damage Calculation

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| AT-030 | If attacker or defender is a squadron: damage = sum of all Hit icons only. | RRG "Attack" step 5 |
| AT-031 | If both attacker and defender are ships: damage = sum of all Hit + Critical icons. | RRG "Attack" step 5 |
| AT-032 | **Standard critical effect:** "If the defender is dealt at least one damage card by this attack, deal the first damage card faceup." | RRG "Critical Effects" |
| AT-033 | Squadrons cannot resolve or suffer critical effects (in MVP, no exceptions). | RRG "Critical Effects" |
| AT-034 | The attacker can resolve only **one** critical effect per attack. | RRG "Critical Effects" |

### 9.5 Firing Arc Rules

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| AT-040 | Each ship has 4 firing arcs defined by firing arc lines printed on the ship token (front, left, right, rear). | LTP p.9; RRG "Firing Arc" |
| AT-041 | Firing arcs are infinite—they extend beyond the range ruler. | RRG "Firing Arc" |
| AT-042 | Firing arcs include the width of the firing arc lines that border them. | RRG "Firing Arc" |
| AT-043 | Squadrons have a 360° firing arc. | LTP p.10; RRG "Firing Arc" |

### 9.6 Measuring Range

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| AT-050 | Attack range from a ship is measured from the closest point of the attacking hull zone to the closest point of the defending hull zone. | RRG "Measuring Firing Arc and Range" |
| AT-051 | Attack range to/from a squadron is measured to/from the closest point of the squadron's base. | RRG "Measuring Firing Arc and Range" |
| AT-052 | When measuring range for a ship, ignore any portion of the defender outside the firing arc, even if closer. | RRG "Measuring Firing Arc and Range" |
| AT-053 | Each squadron's attack range is distance 1. | RRG "Attack Range" |

### 9.7 Ship Attack Constraints

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| AT-060 | A ship can perform two attacks during its activation, from different hull zones. | RRG "Attack" |
| AT-061 | A ship can attack the same target with different attacks (different hull zones). | RRG "Attack" |
| AT-062 | A ship can attack an engaged squadron. | RRG "Attack" |
| AT-063 | Ships and squadrons cannot attack friendly units. | RRG "Attack" |

## 10. Defense Tokens

### 10.1 General Rules

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| DT-001 | Defense tokens begin the game readied. | RRG "Defense Tokens" |
| DT-002 | When a readied token is spent, it is flipped to exhausted. | RRG "Defense Tokens" |
| DT-003 | When an exhausted token is spent, it is discarded (removed from game). | RRG "Defense Tokens" |
| DT-004 | The defender cannot spend more than one token of each type per attack. | RRG "Defense Tokens" |
| DT-005 | A single defense token cannot be spent more than once per attack. | RRG "Defense Tokens" |
| DT-006 | If the defender's speed is 0, it cannot spend defense tokens. | RRG "Defense Tokens"; LTP p.14 |
| DT-007 | **[Network sync point]** Defense token spending choices must be communicated to all clients. | ADR-007 |

### 10.2 Token Types (MVP)

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| DT-010 | **Redirect (B):** The defender chooses one hull zone adjacent to the defending zone. Damage may be applied to the chosen zone's shields (up to shields remaining) before applying remaining damage to the defending zone. | RRG "Defense Tokens"; LTP p.14 |
| DT-011 | **Evade (D):** At long range, cancel one attack die (defender's choice). At medium range, choose one die to reroll. At close range/distance 1, no effect. | RRG "Defense Tokens"; LTP p.14 |
| DT-012 | **Brace (C):** During "Resolve Damage," the total damage is reduced to half, rounded up. | RRG "Defense Tokens"; LTP p.14 |
| DT-013 | **Scatter (A):** Cancel all attack dice. | RRG "Defense Tokens"; LTP p.14 |

### 10.3 MVP-Excluded Token Types (for architecture awareness)

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| DT-020 | **Contain (&):** Prevents attacker from resolving the standard critical effect. The architecture must support this token type. | RRG "Defense Tokens" |
| DT-021 | **Salvo (e):** Defender performs a counter-attack after damage resolution. The architecture must support this token type. | RRG "Defense Tokens" |

## 11. Damage

### 11.1 Ship Damage

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| DM-001 | Ship damage is suffered one point at a time. | RRG "Damage"; LTP p.15 |
| DM-002 | For each point, first reduce shields in the defending hull zone by 1. If shields are at 0, draw one facedown damage card instead. | RRG "Damage"; LTP p.15 |
| DM-003 | When a ship has damage cards equal to or exceeding its hull value, it is immediately destroyed. | RRG "Damage"; LTP p.15 |
| DM-004 | When damage is suffered without a hull zone specified, the ship's owner chooses which hull zone suffers all damage. | RRG "Damage" |
| DM-005 | Faceup damage cards have immediate or persistent effects. They remain faceup unless an effect flips them. | RRG "Damage" |
| DM-006 | Facedown damage cards remain facedown. Players cannot inspect them. | RRG "Damage" |
| DM-007 | Damage cards are dealt one at a time. | RRG "Damage" |
| DM-008 | If no cards remain in the damage deck, shuffle the discard pile to form a new deck. | RRG "Damage" |
| DM-009 | Each damage card has either the "Ship" or "Crew" trait (no inherent effect in MVP, but must be tracked). | RRG "Damage" |

### 11.2 Squadron Damage

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| DM-020 | Squadron damage reduces hull points by the damage amount. The squadron disk is rotated to show remaining hull. | LTP p.15; RRG "Damage" |
| DM-021 | When a squadron is reduced to 0 hull points, it is destroyed. | RRG "Destroyed Ships and Squadrons" |

### 11.3 Destruction

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| DM-030 | When a ship is destroyed, remove it from the play area. Discard its damage cards. Return tokens/dials to supply. | RRG "Destroyed Ships and Squadrons" |
| DM-031 | When a squadron is destroyed, remove it from the play area. | RRG "Destroyed Ships and Squadrons" |
| DM-032 | Destroyed ships/squadrons are no longer in play. Their cards become inactive. | RRG "Destroyed Ships and Squadrons" |
| DM-033 | If any portion of a ship's or squadron's base is outside the play area, it is destroyed (ignore activation sliders and shield dial frames). | RRG "Destroyed Ships and Squadrons" |

## 12. Ship Movement

### 12.1 Determine Course

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| MV-001 | The maneuver tool has multiple segments connected by joints, numbered 0–4. | LTP p.8 |
| MV-002 | The maneuver tool is straightened first, then joints are clicked left or right. | LTP p.8; RRG "Ship Movement" |
| MV-003 | The ship's speed chart determines how many times each joint can be clicked (yaw value) at the current speed. "-" means the joint must stay straight, "I" = 1 click, "II" = 2 clicks. | LTP p.8; RRG "Speed Chart" |
| MV-004 | Each column on the speed chart corresponds to a speed number. Each row corresponds to a maneuver tool joint (top row = first joint). | LTP p.8 |
| MV-005 | The maneuver tool can be placed and adjusted freely during "Determine Course" to preview positions. A ship is not committed until the guides are inserted into its base. | RRG "Premeasuring" |
| MV-006 | A Navigate command can modify speed and/or yaw during this step (see CM-010 through CM-013). | LTP p.11; RRG "Commands" |

### 12.2 Move Ship

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| MV-010 | The maneuver tool's flat-end guides are inserted into notches on one side of the ship's base front. | LTP p.10; RRG "Ship Movement" |
| MV-011 | The ship is slid away from the first-segment guides and placed at the joint corresponding to its current speed. | RRG "Ship Movement" |
| MV-012 | The ship must stay on the same side of the maneuver tool (start and finish). | LTP p.10; RRG "Ship Movement" |
| MV-013 | The ship cannot overlap the maneuver tool in its final position. If it would, the tool must be placed on the other side. | LTP p.10; RRG "Ship Movement" |
| MV-014 | Ships can move through other ships, squadrons, and obstacles. Only start and end positions matter. | RRG "Ship Movement" |
| MV-015 | A ship executing a 0-speed maneuver does not move but is still considered to have executed a maneuver. | RRG "Ship Movement" |

### 12.3 Speed

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| MV-020 | Minimum speed for all ships is 0 (not on speed chart). Maximum speed is per speed chart. | RRG "Speed" |
| MV-021 | Speed is constant until a Navigate command or card effect changes it. | RRG "Speed" |
| MV-022 | Speed is tracked on the speed dial. | LTP p.8 |

## 13. Squadron Mechanics

### 13.1 Squadron Movement

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| SM-001 | To move, place the range ruler (distance side up) with the distance 1 end touching the squadron's base. | LTP p.10; RRG "Squadron Movement" |
| SM-002 | The squadron is picked up and placed anywhere along the ruler, up to the distance band matching its speed value. | LTP p.10; RRG "Squadron Movement" |
| SM-003 | A squadron cannot be placed overlapping another squadron or ship. | RRG "Squadron Movement" |
| SM-004 | Squadrons can move through ships, squadrons, and obstacles. Only start/end positions matter. | RRG "Squadron Movement" |
| SM-005 | A squadron can choose to remain in its current position and is still considered to have moved. | RRG "Squadron Movement" |

### 13.2 Engagement

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| SM-010 | A squadron at distance 1 of one or more enemy squadrons is **engaged** with all of them. | LTP p.11; RRG "Engagement" |
| SM-011 | An engaged squadron **cannot move**. | LTP p.11; RRG "Engagement" |
| SM-012 | An engaged squadron **must** attack an engaged squadron (cannot attack a ship). | LTP p.11; RRG "Engagement" |
| SM-013 | Squadrons do not engage ships or friendly squadrons. | RRG "Engagement" |
| SM-014 | Squadrons do not engage while moving—only starting and final positions matter. | RRG "Engagement" |
| SM-015 | A squadron is no longer engaged when the last squadron engaged with it is destroyed. | RRG "Engagement" |

### 13.3 Squadron Attacks

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| SM-020 | A squadron can attack one enemy squadron or one hull zone of an enemy ship at distance 1. | LTP p.10; RRG "Attack Range" |
| SM-021 | Squadrons have a 360° firing arc. | LTP p.10; RRG "Firing Arc" |
| SM-022 | When attacking a ship, the squadron uses its battery armament. All die colors are valid at distance 1. | LTP p.13 |
| SM-023 | When attacking a squadron, the squadron uses its anti-squadron armament. | RRG "Attack" step 2 |
| SM-024 | Squadrons ignore critical (E) icons when attacking (no critical effects unless keyword specifies). | LTP p.13; RRG "Critical Effects" |

### 13.4 Squadron Keywords (MVP)

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| SM-030 | **Bomber (I):** While attacking a ship, each critical (E) icon adds 1 damage to the total and the squadron can resolve a critical effect. | RRG "Squadron Keywords" |
| SM-031 | **Escort (H):** Squadrons engaged with an Escort squadron cannot attack squadrons that lack Escort. | RRG "Squadron Keywords" |
| SM-032 | **Swarm (J):** While attacking a squadron engaged with another friendly squadron, the attacker may reroll 1 die. | RRG "Squadron Keywords" |

### 13.5 Activation Tracking

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| SM-040 | Each squadron has an activation slider (two-sided: blue and another color). | LTP p.11 |
| SM-041 | Toggling the slider after activation tracks whether the squadron has been activated this round. | LTP p.11; RRG "Squadron Activation" |
| SM-042 | The initiative token's color/icon indicates which slider state means "not yet activated." | LTP p.11 |

## 14. Overlapping

### 14.1 Ship Overlaps Squadrons

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| OV-001 | If a ship's final position overlaps one or more squadrons, the ship finishes its move normally. | LTP p.17; RRG "Overlapping" |
| OV-002 | The **opposing** player places all overlapped squadrons (regardless of owner) so their bases touch the ship's base. | LTP p.17; RRG "Overlapping" |
| OV-003 | If a squadron cannot be placed touching the ship, it must be placed touching another squadron that is touching the ship. | RRG "Overlapping" |
| OV-004 | If a squadron is placed on an obstacle as a result of being overlapped, it does not resolve obstacle effects. | RRG "Overlapping" (future awareness) |

### 14.2 Ship Overlaps Ship

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| OV-010 | If a ship's final position would overlap another ship, it cannot finish normally. Its speed is temporarily reduced by 1 and it attempts to move at the new speed. This repeats until successful or speed reaches 0 (ship stays in place). | LTP p.17; RRG "Overlapping" |
| OV-011 | After moving (even at speed 0), deal one facedown damage card to the moving ship **and** the closest ship it overlapped. | LTP p.17; RRG "Overlapping" |
| OV-012 | The speed dial does not change (temporary reduction only). | RRG "Overlapping" |
| OV-013 | A ship at temporarily reduced speed is allowed to overlap the maneuver tool in its final position. | RRG "Overlapping" |

### 14.3 Placement Constraints

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| OV-020 | Squadrons cannot be placed overlapping other squadrons or ships. | RRG "Overlapping"; RRG "Squadron Movement" |
| OV-021 | Ships and squadrons can move **through** other units without issue. Only final positions matter. | RRG "Overlapping" |

## 15. Winning and Scoring

| ID | Requirement | Rules Source |
|----|-------------|--------------|
| WN-001 | The game ends immediately when all ships of one player are destroyed. The opponent wins. | LTP p.11; RRG "Winning and Losing" |
| WN-002 | If neither player is eliminated after 6 rounds, the player with the highest score wins. | LTP p.11; RRG "Winning and Losing" |
| WN-003 | A player's score = total fleet point cost of each destroyed enemy ship + each destroyed enemy squadron. | LTP p.11; RRG "Scoring" |
| WN-004 | If scores are tied after 6 rounds, the second player (without initiative) wins. | RRG "Winning and Losing" |

## 16. Game Components (Digital)

These are the digital representations required for the MVP.

| ID | Component | Count | Format | Notes |
|----|-----------|-------|--------|-------|
| GC-001 | Play area background | 1 | PNG | Space-themed 2D background |
| GC-002 | Ship tokens (top-down) | 3 | PNG | CR90A, Neb-B, VSD-II with firing arc lines and hull zones |
| GC-003 | Ship bases | 2 sizes | PNG/procedural | Small (43×71mm), Medium (63×102mm) with notch markings |
| GC-004 | Squadron tokens | 2 | PNG | X-wing, TIE Fighter on circular bases |
| GC-005 | Ship cards | 3 | PNG or data-driven UI | All ship stats displayed |
| GC-006 | Squadron cards | 2 | PNG or data-driven UI | All squadron stats displayed |
| GC-007 | Attack dice | 3 colors × 3 | PNG with face textures | Red (8 faces), Blue (8 faces), Black (8 faces) |
| GC-008 | Command dials | 4 icons | PNG | Navigate, Squadron, Repair, Conc. Fire |
| GC-009 | Speed dials | 3 | UI widget | Speed 0–4 per ship |
| GC-010 | Shield dials | 12 | UI widget | 4 per ship, showing current/max shields |
| GC-011 | Defense tokens | ~9 | PNG | Evade, Redirect, Brace (ready/exhausted sides) |
| GC-012 | Damage cards | 52 | PNG or data | Faceup (with effect text) and facedown representations |
| GC-013 | Round tokens | 6 | PNG or UI | Numbers 1–6 |
| GC-014 | Range ruler | 1 | PNG/procedural | Dual-sided: range (close/medium/long) and distance (1–5) |
| GC-015 | Maneuver tool | 1 | Procedural | 5 segments with clickable joints, speed number labels |
| GC-016 | Initiative token | 1 | PNG | Two-sided (blue/red) |
| GC-017 | Activation sliders | Visual indicator | UI widget | Toggle state on squadron bases |
| GC-018 | Command tokens | 4 types | PNG | Navigate, Squadron, Repair, Conc. Fire |

## 17. UI Requirements

| ID | Requirement | Notes |
|----|-------------|-------|
| UI-001 | The play area must be pannable and zoomable. | Players need to inspect distant ships |
| UI-002 | Ship cards, squadron cards, and damage cards must be viewable in detail on click/hover. | Full card view overlay |
| UI-003 | The current game phase and round number must always be visible. | HUD element |
| UI-004 | The active player and which ship/squadron is being activated must be clearly indicated. | Visual highlight |
| UI-005 | Command dial selection must use a secret UI (hidden from opponent in network play). | Dial picker widget |
| UI-006 | Defense token states (ready/exhausted/discarded) must be clearly distinguishable. | Shown next to ship card in side panel (UI-016/017); color coding: green/red/removed |
| UI-007 | Shield dial values must be readable on ship bases. | Rotatable dial or numeric display |
| UI-008 | Dice rolls must have visual feedback (rolling animation, result display). | Dice area + result summary |
| UI-009 | The damage deck count must be visible. | Remaining cards in deck |
| UI-010 | Movement preview must show the ship's projected final position before committing. | Ghost/transparent preview |
| UI-011 | Firing arc visualization must be toggleable to help players determine valid targets. | Overlay on ship tokens |
| UI-012 | Range ruler visualization must be available for measuring distances. | Draggable measurement tool |
| UI-013 | Squadron engagement status must be visually indicated. | Line/glow between engaged squadrons |
| UI-014 | Turn order / activation status must be shown for all ships and squadrons. | Sidebar or token markers |
| UI-015 | Attack resolution steps must be presented sequentially with clear prompts for each decision point. | Step-by-step attack dialog |
| UI-016 | Ship cards are displayed in side panels outside the play area: Rebel cards on the left, Imperial cards on the right. | CanvasLayer panels; always visible regardless of camera |
| UI-017 | Defense tokens are displayed next to their ship card in the side panel, **not** on the ship token on the board. | Per SU-026; ready/exhausted/discarded states per UI-006 |
| UI-018 | Left-clicking a ship card entry in the side panel toggles a magnified view (2.5× default, configurable via `scale_config.json` → `card_panel.magnify_factor`). A second click restores normal size. | Zoom toggle per entry; all components (card + tokens) scale together |

## 18. Network Multiplayer Considerations

Per ADR-007, the architecture is designed with network multiplayer from day one.

| ID | Requirement | Notes |
|----|-------------|-------|
| NW-001 | All game state must be serializable/deserializable for network transmission. | GameState, PlayerState already support this |
| NW-002 | Use authoritative server model: the server validates all state changes. | Prevents cheating, ensures consistency |
| NW-003 | **Sync points** — the following events require client–server synchronization: command dial submissions (CP-008), command dial reveals (SP-012), dice rolls (AT-003), accuracy spending (AT-004), defense token spending (DT-007), damage card draws, movement execution, squadron activation choices. | Each is a discrete network message |
| NW-004 | Dice rolls must use server-side RNG. Clients receive results, not seeds. | Prevents client-side manipulation |
| NW-005 | Secret information (facedown command dials, opponent's hand) must only be sent to the owning player. | Information hiding |
| NW-006 | The game must support reconnection. A disconnected player can rejoin and receive the full current state. | Serialized GameState snapshot |
| NW-007 | Simultaneous actions (Command Phase) must use a "both submitted" gate before revealing. | Prevents information leak |
| NW-008 | Turn timers should be configurable (optional) to prevent stalling. | Player settings |

## 19. Debug Mode

> **Scope:** Developer tooling for interactive token placement during setup.
> Available in both the Learning Scenario setup and (future) main game setup.
> All features in this section are gated behind a global debug mode toggle.

### 19.1 Debug Mode Toggle

| ID | Requirement | Notes |
|----|-------------|-------|
| DBG-001 | A global debug mode toggle must exist, controllable at startup or runtime. When disabled, all debug interactions are inactive. | Project setting or autoload flag |
| DBG-002 | When debug mode is active, a visible indicator (e.g. "DEBUG" label) must be displayed in the HUD. | Prevents confusion about active state |
| DBG-003 | Debug mode must not interfere with existing camera controls (right-click pan, scroll/pinch zoom). | UI-001 |

### 19.2 Token Selection & Movement

| ID | Requirement | Notes |
|----|-------------|-------|
| DBG-010 | In debug mode, left-clicking a token (ship or squadron) **selects** it. Left-clicking the same token again or clicking empty space **deselects** it. | Single-selection model |
| DBG-011 | While a token is selected, it follows the mouse cursor position in real time. | Continuous movement |
| DBG-012 | While a token is selected, a two-finger trackpad gesture (rotation / magnify gesture) **rotates** the token around its centre. | Uses same gesture type as camera zoom, but routed differently when a token is selected |

### 19.3 Collision Prevention

| ID | Requirement | Notes |
|----|-------------|-------|
| DBG-020 | While moving, if the selected token's footprint at the mouse-cursor position would overlap another token, the selected token is displayed at the **closest legal position** whose centre has the **minimum Euclidean distance to the mouse cursor**, such that no overlap exists with any other token, deployment zone boundary, or play-area edge. The token must never penetrate another token's footprint. | Mirrors deployment-zone clamping behaviour (DBG-032); replaces the old "slide along movement vector" approach |
| DBG-021 | *(Removed — subsumed by DBG-020/DBG-022.)* Jump-past is no longer a separate concept: if the mouse cursor is beyond a blocker and the footprint fits, the direct projection in DBG-020 naturally resolves to the mouse position itself (no overlap → no correction needed). | — |
| DBG-022 | Closest-legal-position resolution uses **direct geometric projection**: for each blocking token, compute the nearest non-overlapping position by pushing the selected token outward from the blocker along the line connecting the blocker's centre to the mouse cursor, to the exact contact distance (Minkowski sum boundary). When multiple blockers constrain the position, the candidate closest to the mouse wins, provided it does not violate any other constraint. | Projection-based; independent of the token's previous position |

### 19.4 Deployment Zone Visualisation & Enforcement

| ID | Requirement | Notes |
|----|-------------|-------|
| DBG-030 | In debug mode, two thin blue horizontal lines are drawn across the play area, each at **distance band 3** (434 px at current 720 px ruler scale) inward from the **top** and **bottom** board edges respectively. | `GameScale.distance_bands_px[2]` |
| DBG-031 | The **Imperial deployment zone** is the strip between the top board edge and the top blue line. The **Rebel deployment zone** is the strip between the bottom board edge and the bottom blue line. | Matches LTP p.5 setup diagram |
| DBG-032 | When a token belonging to a faction is dragged toward its deployment zone boundary (the blue line), the boundary acts as a collision wall: the token slides to contact but cannot cross it. Same slide-to-contact / jump-past logic as token–token collisions (DBG-020, DBG-021). | Faction-aware boundary |

### 19.5 Position Persistence

| ID | Requirement | Notes |
|----|-------------|-------|
| DBG-040 | In debug mode, a **"Save Positions"** action (button or keyboard shortcut) writes the current world-space positions and rotations of all tokens back to the active scenario JSON file (e.g. `learning_scenario.json`), overwriting the placement entries. | Enables iterative visual layout |
| DBG-041 | The saved positions must use the same normalised coordinate format (`position_x`, `position_y` as fractions of play area, `rotation_degrees`) already used in scenario JSON files, so they are immediately reloadable. | Roundtrip consistency |

---

## Traceability Matrix

| Category | Req Count | Source |
|----------|-----------|--------|
| Game Overview | 6 | LTP, RRG |
| Setup | 18 | LTP, ADR |
| Game Flow | 4 | LTP, RRG |
| Command Phase | 8 | LTP, RRG, ADR |
| Ship Phase | 6+10 = 16 | LTP, RRG |
| Squadron Phase | 9 | LTP, RRG |
| Status Phase | 4 | LTP, RRG |
| Commands | 22 | RRG, LTP |
| Attack Resolution | 28 | RRG, LTP |
| Defense Tokens | 10 | RRG, LTP, ADR |
| Damage | 12 | RRG, LTP |
| Ship Movement | 13 | LTP, RRG |
| Squadron Mechanics | 18 | LTP, RRG |
| Overlapping | 8 | LTP, RRG |
| Winning/Scoring | 4 | LTP, RRG |
| Game Components | 18 | Derived |
| UI Requirements | 15 | Derived |
| Network Multiplayer | 8 | ADR-007 |
| Debug Mode | 13 | Dev tooling |
| **Total** | **~206** | |
