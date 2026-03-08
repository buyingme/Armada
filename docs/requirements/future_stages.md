# Future Stage Requirements — Architecture Impact

> **Purpose:** Document post-MVP requirements that significantly influence the game architecture.
> These features are **not** implemented in the Learning Scenario MVP but must be considered
> during architectural design to avoid costly refactoring.

## Table of Contents

- [1. Fleet Building](#1-fleet-building)
- [2. Upgrade Cards](#2-upgrade-cards)
- [3. Objectives](#3-objectives)
- [4. Obstacles](#4-obstacles)
- [5. Line of Sight and Obstruction](#5-line-of-sight-and-obstruction)
- [6. Full Setup Process](#6-full-setup-process)
- [7. Additional Defense Token Types](#7-additional-defense-token-types)
- [8. Extended Squadron Keywords](#8-extended-squadron-keywords)
- [9. Unique Squadrons](#9-unique-squadrons)
- [10. Pass Tokens](#10-pass-tokens)
- [11. Size Class Mechanics](#11-size-class-mechanics)
- [12. Effect Timing System](#12-effect-timing-system)
- [13. Huge Ships](#13-huge-ships)
- [14. Flotillas](#14-flotillas)
- [15. Damage Card System](#15-damage-card-system)
- [16. Additional Factions](#16-additional-factions)
- [17. Architectural Implications Summary](#17-architectural-implications-summary)

---

## 1. Fleet Building

| ID | Requirement | Architecture Impact | Rules Source |
|----|-------------|---------------------|--------------|
| FB-001 | Each player builds a fleet with ships, squadrons, and upgrades totaling at most the agreed fleet point value (standard: 400 pts, core set: 180 pts). | Need FleetBuilder service with validation, point-counting, and constraint checking. | RRG "Fleet Building" |
| FB-002 | A fleet must be aligned with one faction. It cannot contain cards from opposing factions. | Faction filtering on all card selections. | RRG "Fleet Building" |
| FB-003 | A fleet must have exactly one flagship (ship with commander card). | Flagship tracking across fleet; commander slot is special (any ship, no upgrade icon needed). | RRG "Fleet Building"; RRG "Commanders" |
| FB-004 | A fleet cannot spend more than ⅓ of fleet points (rounded up) on squadrons. | Budget sub-constraint system. | RRG "Fleet Building" |
| FB-005 | A fleet can contain one unique squadron with defense tokens per 100 fleet points. | Dynamic constraint based on fleet point total. | RRG "Fleet Building" |
| FB-006 | A ship cannot equip more than one copy of the same upgrade card. | Duplicate detection per ship. | RRG "Fleet Building" |
| FB-007 | Unique names (bullet prefix) cannot appear more than once in a fleet across all card types. | Global unique-name registry during fleet building. | RRG "Unique Names" |
| FB-008 | Each player must choose 3 objective cards (one per category: Assault, Defense, Navigation). | Objective card data model and selection UI. | RRG "Fleet Building"; RRG "Objective Cards" |
| FB-009 | Initiative is determined by lowest fleet point total (loser picks who goes first). Ties broken by coin flip. | Initiative assignment based on fleet cost comparison. | RRG "Setup" step 3 |

**Architecture implications:**
- Fleet validation engine (RefCounted, pure logic, no scene tree)
- Upgrade slot matching system with type constraints
- Card database/registry with search and filtering
- Fleet serialization for network transmission and persistence
- Fleet list UI with drag-and-drop or similar UX

---

## 2. Upgrade Cards

| ID | Requirement | Architecture Impact | Rules Source |
|----|-------------|---------------------|--------------|
| UC-001 | Ships equip upgrade cards by matching the upgrade icons in their upgrade bar. Each icon allows one card with the matching icon. | Upgrade slot system: ship defines available slots, card defines required slot type. | RRG "Upgrade Cards" |
| UC-002 | Some upgrade cards are exhaustible — rotated 90° when used, readied during Status Phase. | Card state tracking: readied/exhausted per card instance. | RRG "Exhausted"; RRG "Status Phase" |
| UC-003 | Non-recur (→) upgrade cards do not ready automatically; require spending tokens (ready cost). | Ready cost resolver in Status Phase logic. | RRG "Readied"; RRG "Ready Cost" |
| UC-004 | Upgrade card effects have diverse timing windows: "when," "while," "before," "after," modify dice, critical effects, command headers. | **Critical:** Need a generic effect/trigger system that hooks into game events at specific timing points. | RRG "Effect Use and Timing" |
| UC-005 | The "Modification" trait restricts a ship to one Modification upgrade. | Trait-based equip validation layer. | RRG "Upgrade Cards" |
| UC-006 | Title cards are restricted to ships matching a specific ship icon. One title per ship. | Ship-type matching during equip. | RRG "Titles" |
| UC-007 | Commanders can be equipped to any non-flotilla ship (one per fleet). | Commander is a special upgrade type with fleet-level constraints. | RRG "Commanders" |
| UC-008 | Some upgrades have multi-icon costs (e.g., Weapons Team + Offensive Retrofit). | Multi-slot matching system. | RRG "Upgrade Cards" |
| UC-009 | Upgrade cards may have faction restrictions, size restrictions, ship-trait restrictions, and flagship restrictions. | Multi-constraint validation chain. | RRG "Upgrade Cards" |
| UC-010 | Discarded upgrade cards remain equipped (facedown) for scoring purposes. | Card lifecycle: active → discarded (still scored). | RRG "Upgrade Cards" |
| UC-011 | Some upgrade cards begin the game with command tokens or dials placed on them. | Per-card token/dial storage, separate from ship's own. | RRG "Upgrade Cards with Tokens or Dials" |

**Architecture implications:**
- **Effect system:** The biggest architectural challenge. Need a data-driven or scripted effect system that can:
  - Hook into game events at specific timing windows
  - Modify dice pools, speeds, yaw, damage, etc.
  - Support "exhaust to use" patterns
  - Support conditional triggers ("when attacking," "while defending," etc.)
- **Upgrade card data model:** Extend `UpgradeData` with effect definitions (possibly GDScript snippets or a DSL)
- **Card state machine:** Ready → Exhausted → (optionally) Ready with cost → Discarded

---

## 3. Objectives

| ID | Requirement | Architecture Impact | Rules Source |
|----|-------------|---------------------|--------------|
| OB-001 | Three objective categories: Assault, Defense, Navigation. | Objective card data model with category enum. | RRG "Objective Cards" |
| OB-002 | Second player brings 3 objectives; first player chooses 1. | Pre-game objective selection flow. | RRG "Objective Cards"; RRG "Setup" step 4 |
| OB-003 | Objectives can alter setup (obstacle placement, deployment zones, special tokens). | Setup process must be configurable/modifiable by objective effects. | RRG "Objective Cards" |
| OB-004 | Objectives can add special rules during gameplay (extra scoring, modified victory conditions). | Game rule modification hooks at phase/step level. | RRG "Objective Cards" |
| OB-005 | Victory tokens are collected per objective rules and add to score. | Victory token tracking per player. | RRG "Victory Tokens" |
| OB-006 | Objective tokens may be placed in the play area to mark effects. | Placeable token system on game board. | RRG "Objective Tokens" |
| OB-007 | Some objectives designate "objective ships" worth extra points. | Ship tagging/flagging system. | RRG "Objective Cards" |

**Architecture implications:**
- Objective effect system (similar to upgrade effects but at game level)
- Setup pipeline must be composable/extensible (objectives inject steps)
- Victory condition system beyond simple "destroy all ships"
- Token placement and tracking on the game board

---

## 4. Obstacles

| ID | Requirement | Architecture Impact | Rules Source |
|----|-------------|---------------------|--------------|
| OS-001 | Standard game uses 6 obstacles: 3 asteroid fields, 2 debris fields, 1 station. | Obstacle token data model with type-specific effects. | RRG "Obstacles"; RRG "Setup" step 5 |
| OS-002 | Obstacles are placed alternately during setup, with distance constraints (beyond distance 3 of edges, beyond distance 1 of each other). | Obstacle placement phase with validation. | RRG "Setup" step 5 |
| OS-003 | **Asteroid Field:** Ship overlapping receives 1 faceup damage card. Squadrons unaffected. | Overlap detection for obstacles during ship movement. | RRG "Obstacles" |
| OS-004 | **Debris Field:** Ship overlapping suffers 2 damage on any hull zone. Squadrons unaffected. | Hull zone selection prompt for debris damage. | RRG "Obstacles" |
| OS-005 | **Station:** Ship overlapping may discard 1 damage card. Squadron may recover 1 hull point. | Healing/recovery effect on overlap. | RRG "Obstacles" |
| OS-006 | Ships/squadrons can move through obstacles freely; only final position matters. | Overlap check only at final position. | RRG "Obstacles" |
| OS-007 | Attacks tracing line of sight through an obstacle token are obstructed. | Line-of-sight ray casting with obstruction detection. | RRG "Obstacles" |
| OS-008 | Expansion obstacles: Dust Fields, Exogorths, Gravity Rifts, Purrgil. | Obstacle type system must be extensible. | RRG "Obstacles" |
| OS-009 | Some obstacles can be moved during gameplay (via objective cards or obstacle type rules). | Obstacle movement system with constraints. | RRG "Obstacle and Token Movement" |

**Architecture implications:**
- Obstacle entity with type, position, overlap detection
- Movement/overlap check integration into ship movement pipeline
- Line-of-sight system must account for obstacle tokens
- Extensible obstacle type registry

---

## 5. Line of Sight and Obstruction

| ID | Requirement | Architecture Impact | Rules Source |
|----|-------------|---------------------|--------------|
| LOS-001 | When a ship attacks, line of sight is traced from the attacking hull zone's targeting point to the defending hull zone's targeting point. | Per-hull-zone targeting points as geometric data. | RRG "Line of Sight" |
| LOS-002 | When tracing to/from a squadron, use the closest point on the squadron's base. | Closest-point-on-circle calculations. | RRG "Line of Sight" |
| LOS-003 | If LOS passes through a non-defending hull zone on the defender, the attacker does not have LOS. | Hull zone geometry testing along LOS ray. | RRG "Line of Sight" |
| LOS-004 | If LOS passes through an obstacle or non-participant ship, the attack is obstructed. | Ray–polygon intersection for obstacles and ship bases. | RRG "Line of Sight" |
| LOS-005 | Obstructed attacks lose 1 die (attacker's choice) before rolling. | Dice pool modification in "Roll Attack Dice" step. | RRG "Obstructed" |
| LOS-006 | Squadrons do not block or obstruct LOS. | Exclude squadron tokens from LOS checks. | RRG "Line of Sight" |

**Architecture implications:**
- **Geometry engine:** Ray casting / line-segment intersection against:
  - Ship base polygons (hull zone boundaries)
  - Obstacle token shapes
  - Firing arc boundary lines
- Targeting point data per hull zone on each ship token
- This is a **core system** that affects all attacks — must be efficient and accurate
- The MVP can use simplified "everything is in range" for the learning scenario, but the architecture must support full LOS from the start

---

## 6. Full Setup Process

| ID | Requirement | Architecture Impact | Rules Source |
|----|-------------|---------------------|--------------|
| FS-001 | Full play area is 3' × 6' with a 3' × 4' setup area. | Configurable play area dimensions. | RRG "Setup" step 1 |
| FS-002 | Deployment zones are distance 1–3 from each player's edge within the setup area. | Deployment zone geometry calculation. | RRG "Deployment Zone" |
| FS-003 | Ships and squadrons are deployed alternately (first player starts). A deployment turn = 1 ship or 2 squadrons. | Deployment phase state machine with alternating turns. | RRG "Setup" step 6 |
| FS-004 | Ships must be placed within deployment zones with speed dial set to a valid speed from the chart. | Speed validation during deployment. | RRG "Setup" step 6 |
| FS-005 | Squadrons must be placed within distance 1–2 of a friendly ship (can be outside deployment zone but within setup area). | Distance constraint validation for squadron placement. | RRG "Setup" step 6 |
| FS-006 | If a player has 1 squadron remaining when they must place 2, they wait until all ships are placed. | Deployment ordering constraint. | RRG "Setup" step 6 |
| FS-007 | Obstacle placement is alternating, starting with second player, with distance constraints. | Multi-step obstacle placement phase. | RRG "Setup" step 5 |

**Architecture implications:**
- Multi-phase setup state machine (8 steps)
- The Learning Scenario is a simplified static setup; the full setup adds multiple interactive phases
- Setup must be a composable pipeline (objectives can inject/modify steps)
- All placement needs validation against distance constraints

---

## 7. Additional Defense Token Types

| ID | Requirement | Architecture Impact | Rules Source |
|----|-------------|---------------------|--------------|
| DT-F01 | **Contain (&):** Prevents the standard critical effect. Attacker can still use non-standard criticals. | Token effect must distinguish standard vs. non-standard critical effects. | RRG "Defense Tokens" |
| DT-F02 | **Salvo (e):** Defender performs a counter-attack using printed rear battery (vs. ship) or printed anti-squadron (vs. squadron). Attack uses same range/LOS as original. No dice can be added. Only standard critical effect. | Triggers a new mini-attack within the attack resolution flow. Must avoid infinite loops (no salvo during salvo/counter/ignition). | RRG "Defense Tokens" |
| DT-F03 | Evade token has enhanced effects: at extreme range, cancel 2 dice; against larger size class, cancel/reroll 1 additional die (but must discard token). | Size-class comparison during evade resolution. | RRG "Defense Tokens" |

**Architecture implications:**
- The Salvo token fundamentally requires the attack resolution to be **reentrant** (an attack can trigger another attack)
- Must implement attack type tagging (normal, counter, salvo, ignition) to prevent recursive triggering
- Size class comparison for enhanced Evade
- The Constants enum already includes `CONTAIN` and `SALVO` — good forward planning

---

## 8. Extended Squadron Keywords

19+ keywords defined in the RRG. Only Bomber, Escort, and Swarm are used in MVP.

| ID | Keyword | Architecture Impact | Rules Source |
|----|---------|---------------------|--------------|
| SK-001 | **Counter X** | After being attacked by a squadron, perform a counter-attack. Similar reentrant issue as Salvo. | RRG "Squadron Keywords" |
| SK-002 | **Rogue** | Can move AND attack during Squadron Phase. Changes activation behavior. | RRG "Squadron Keywords" |
| SK-003 | **Heavy** | Does not prevent engaged squadrons from moving/attacking ships. Modifies engagement rules. | RRG "Squadron Keywords" |
| SK-004 | **Intel** | Grants Grit to nearby friendlies. Aura-based keyword propagation. | RRG "Squadron Keywords" |
| SK-005 | **Grit** | Not prevented from moving when engaged by only 1 squadron (unless it lacks Heavy). | RRG "Squadron Keywords" |
| SK-006 | **Cloak** | Move distance 1 at end of Squadron Phase, even if engaged. Phase-end trigger. | RRG "Squadron Keywords" |
| SK-007 | **Relay X** | Squadron command activations can originate from this squadron's position. Range proxy for commands. | RRG "Squadron Keywords" |
| SK-008 | **Snipe X** | Attack squadrons at distance 2 (ignoring Counter). Range extension for anti-squadron. | RRG "Squadron Keywords" |
| SK-009 | **Assault** | Spend a hit icon to give defender a raid token. Introduces raid token system. | RRG "Squadron Keywords" |
| SK-010 | **Adept X** | Reroll up to X dice while attacking. Simple die modification. | RRG "Squadron Keywords" |
| SK-011 | **AI: Battery/Anti-Sqd X** | Add X dice when activated by Squadron command. Conditional die addition. | RRG "Squadron Keywords" |
| SK-012 | **Dodge X** | Defender rerolls X dice from attacker's pool. Defensive die modification. | RRG "Squadron Keywords" |
| SK-013 | **Screen** | Gain Dodge for each other friendly squadron the attacker is engaged with. Dynamic keyword accumulation. | RRG "Squadron Keywords" |
| SK-014 | **Scout** | Special deployment rules (can deploy beyond distance 1-5 of enemies). | RRG "Squadron Keywords" |
| SK-015 | **Strategic** | Move objective tokens when ending movement near them. | RRG "Squadron Keywords" |
| SK-016 | Keywords with X values are cumulative. | Keyword value stacking system. | RRG "Squadron Keywords" |

**Architecture implications:**
- **Keyword effect system:** Similar to upgrade effects but on squadrons.
  - Some modify engagement rules (Heavy, Grit, Escort, Intel)
  - Some add attacks (Counter, similar to Salvo reentrance)
  - Some modify activation behavior (Rogue, Cloak)
  - Some are passive auras (Intel, Screen)
- Keywords must be queryable at runtime (engagement checks need to know about Heavy/Escort/Grit)
- The existing `has_keyword()` and `get_keyword_value()` helpers on SquadronData are a good foundation
- Need a keyword resolution system that handles interactions (e.g., Grit + Heavy + Intel stacking)

---

## 9. Unique Squadrons

| ID | Requirement | Architecture Impact | Rules Source |
|----|-------------|---------------------|--------------|
| US-001 | Unique squadrons have individual squadron cards with special abilities. | Squadron instances need per-card data (not just shared card). | RRG "Unique Names"; LTP p.20 |
| US-002 | Unique squadrons have defense tokens (like ships). | Defense token system must work for squadrons too. | RRG "Defense Tokens" |
| US-003 | Unique squadrons use the reverse side of the squadron disk for art. | Disk display system with two sides. | LTP p.20 |
| US-004 | Only one copy of each unique squadron per fleet. | Fleet building constraint. | RRG "Unique Names" |
| US-005 | A fleet cannot have multiple unique squadrons with the same italicized squadron type. | Type-uniqueness constraint in addition to name-uniqueness. | RRG "Unique Names" |

**Architecture implications:**
- Squadron instances need individual state (defense tokens, unique abilities)
- The attack resolution defense token step already works for squadrons (same code path)
- Must support per-squadron card data beyond the shared card

---

## 10. Pass Tokens

| ID | Requirement | Architecture Impact | Rules Source |
|----|-------------|---------------------|--------------|
| PT-001 | Before deploying, if one player has fewer ships, they gain pass tokens equal to the difference (first player gets 1 fewer). | Pre-game calculation based on fleet composition. | RRG "Pass Tokens" |
| PT-002 | During Ship Phase, a player may spend a pass token instead of activating, skipping their turn. | Ship Phase turn logic must handle pass actions. | RRG "Pass Tokens" |
| PT-003 | A player cannot spend pass tokens on consecutive turns. | Turn history tracking for pass eligibility. | RRG "Pass Tokens" |
| PT-004 | Specific passing rules based on first/second player and remaining unactivated ships. | Complex turn-skip eligibility logic. | RRG "Ship Phase" |

**Architecture implications:**
- Ship Phase state machine needs pass token support
- Turn order tracking with skip/pass history
- Currently not relevant for MVP (both players have similar ship counts), but the Ship Phase state machine should be extensible

---

## 11. Size Class Mechanics

| ID | Requirement | Architecture Impact | Rules Source |
|----|-------------|---------------------|--------------|
| SC-001 | Ships have size classes: Small, Medium, Large, Huge. Each uses different physical base sizes. | Base geometry varies by size class. | RRG "Size Class" |
| SC-002 | The Evade token has enhanced effects when defending against a ship of larger size class (cancel/reroll 1 additional die, but discard the token). | Size comparison in defense token resolution. | RRG "Defense Tokens" |
| SC-003 | Some upgrade cards have size restrictions. | Size-based equip validation. | RRG "Upgrade Cards" |

**Architecture implications:**
- Ship base dimensions stored per size class
- Size comparison utility for defense token and effect resolution

---

## 12. Effect Timing System

| ID | Requirement | Architecture Impact | Rules Source |
|----|-------------|---------------------|--------------|
| ET-001 | Effects have precise timing windows: "when," "while," "before," "after" language defines when they trigger. | Need event-driven architecture with distinct trigger phases. | RRG "Effect Use and Timing" |
| ET-002 | If both players have effects with the same timing, first player resolves all of theirs first. | Player priority system for simultaneous triggers. | RRG "Effect Use and Timing" |
| ET-003 | If a player has multiple effects at the same timing, they choose the order. | Player choice for own effect ordering. | RRG "Effect Use and Timing" |
| ET-004 | Upgrade card effects are optional unless stated otherwise. Other card effects are mandatory. | Optional vs. mandatory effect system. | RRG "Effect Use and Timing" |

**Architecture implications:**
- **This is the most architecturally significant future requirement.**
- Need an event/phase system with defined timing points:
  - Before/when/while/after each game step
  - Trigger registered effects at those points
  - Resolve in player-priority order
- This effectively defines an **effect stack/queue** similar to other card games
- Design the EventBus and phase system with these hooks from the start

---

## 13. Huge Ships

| ID | Requirement | Architecture Impact | Rules Source |
|----|-------------|---------------------|--------------|
| HS-001 | Huge ships use two large bases. 6 hull zones (add right-auxiliary and left-auxiliary). | Hull zone system must support >4 zones. | RRG "Huge Ship" |
| HS-002 | Huge ships can perform up to 3 attacks per activation. | Attack count must be configurable per ship type. | RRG "Huge Ship" |
| HS-003 | Maneuver tool is placed at the rear base, not the front. | Movement system parameterized by ship type. | RRG "Huge Ship" |
| HS-004 | Revealing a command dial also assigns the matching command token. | Command reveal behavior varies by ship type. | RRG "Huge Ship" |
| HS-005 | Huge ships have scoring for "crippled" state (≥ half hull in damage). | Partial scoring system. | RRG "Huge Ship" |
| HS-006 | Special firing arcs and ignition attacks at extreme range. | Extreme range determination, special battery armaments. | RRG "Ignition"; RRG "Special Battery Armament" |

**Architecture implications:**
- Hull zone list must be dynamic (not hardcoded to 4)
- Attack activation step parameterized for max attacks
- Ship movement system needs flexibility for rear-base placement
- Consider but don't over-engineer for MVP; ensure hull zone system uses arrays/lists rather than hardcoded enums

---

## 14. Flotillas

| ID | Requirement | Architecture Impact | Rules Source |
|----|-------------|---------------------|--------------|
| FL-001 | Flotillas use two plastic models but one base. They follow ship rules with exceptions. | Ship entity needs a "flotilla" flag. | RRG "Flotillas" |
| FL-002 | When overlapping with another ship, only the flotilla takes a damage card. | Overlap damage logic varies by ship type. | RRG "Flotillas" |
| FL-003 | Flotillas cannot equip commanders. | Commander equip restriction by ship sub-type. | RRG "Flotillas" |

---

## 15. Damage Card System

| ID | Requirement | Architecture Impact | Rules Source |
|----|-------------|---------------------|--------------|
| DC-001 | The damage deck contains 52 cards with effects (faceup) and Ship/Crew traits. | Damage card data model: name, effect_text, trait (Ship/Crew), timing (immediate/persistent). | RRG "Damage" |
| DC-002 | Faceup cards have immediate or persistent effects (e.g., "Capacitor Failure" halves engineering value). | Damage card effects integrate with the effect timing system. | RRG "Damage" |
| DC-003 | Effects can reference damage cards by trait (Ship vs. Crew). | Trait-based filtering and targeting. | RRG "Damage" |
| DC-004 | Cards can be flipped faceup/facedown by game effects. | Damage card state transitions. | RRG "Damage" |
| DC-005 | When deck is empty, shuffle the discard pile to form a new deck. | Deck/discard cycle management. | RRG "Damage" |

**Architecture implications:**
- Damage card data class (separate from ship/squadron/upgrade data)
- Deck management (draw, discard, reshuffle)
- Faceup damage effects plug into the effect timing system
- The data for all 52 damage cards needs to be extracted

---

## 16. Additional Factions

| ID | Requirement | Architecture Impact | Rules Source |
|----|-------------|---------------------|--------------|
| AF-001 | Galactic Republic and Separatist Alliance factions exist. | Faction enum already includes all 4 (Constants.gd). | RRG "Faction" |
| AF-002 | Some cards have dual faction affiliation (split symbols). | Card data model needs multi-faction support. | RRG "Faction" |

**Architecture implications:**
- Already addressed by ADR-008 and the existing `Faction` enum
- Card data schemas may need an array for faction instead of a single value

---

## 17. Architectural Implications Summary

### Priority 1: Critical for MVP Architecture Design

These must be **designed** (not necessarily implemented) before MVP coding begins:

| System | Why | MVP Impact |
|--------|-----|------------|
| **Effect/Timing System** (ET-001–004, UC-004) | Every future upgrade and objective card needs this. The attack resolution pipeline, command system, and Status Phase all need timing hooks. | Define the hook points in attack resolution, movement, phases even if no effects use them yet. |
| **Reentrant Attack Resolution** (DT-F02, SK-001) | Salvo and Counter create recursive attacks. The attack pipeline must handle nested attacks. | Structure attack resolution as a callable function (not a monolithic flow) that can be invoked from within itself. |
| **Game State Serialization** (NW-001, NW-006) | Network multiplayer requires complete state snapshots. Every piece of game state must be serializable. | Already partially addressed (GameState.serialize/deserialize). Ensure ALL new state is included. |
| **Line of Sight / Geometry Engine** (LOS-001–006) | Every attack needs LOS checking post-MVP. The play area geometry system affects ship tokens, firing arcs, and obstacles. | Build the geometric primitives (points, lines, polygons, intersections) even if MVP skips LOS checks. |

### Priority 2: Design Interfaces, Implement Later

These need stable interfaces designed during MVP but implementation deferred:

| System | Why |
|--------|-----|
| **Fleet Building** (FB-001–009) | Needs card database, validation engine, and UI. Design the data access patterns now. |
| **Upgrade/Card Effect DSL** (UC-001–011) | The upgrade card effect system is complex. Define how effects will be declared and resolved. |
| **Objective System** (OB-001–007) | Objectives modify setup and scoring. The setup pipeline and scoring system must be extensible. |
| **Obstacle System** (OS-001–009) | Obstacle tokens interact with movement, LOS, and effects. Design the obstacle entity model. |
| **Extended Squadron Keywords** (SK-001–016) | Many keywords modify core systems (engagement, movement, attacks). Keyword resolution must be pluggable. |

### Priority 3: Need Not Block MVP

These can be fully deferred without architectural risk:

| System | Why |
|--------|-----|
| Huge Ships (HS-001–006) | Edge case; very few players use them. Hull zone list flexibility is the only prerequisite. |
| Flotillas (FL-001–003) | Minor ship subtype; overlap rule variation is small. |
| Pass Tokens (PT-001–004) | Additive Ship Phase feature, not a structural change. |
| Additional Factions (AF-001–002) | Already covered by enum design. |
| Campaign/Competitive Modes | Not covered in base rules extractions. |
