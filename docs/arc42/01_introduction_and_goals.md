# 1. Introduction and Goals

## 1.0 Project Status

**MVP Complete** — The Learning Scenario is fully playable end-to-end: 6-round game
with command dials, ship movement (maneuver tool), ship/squadron combat with full
attack pipeline (dice, defense tokens, damage cards), repair commands, squadron
commands, scoring, victory screen, hot-seat multiplayer, SFX, and dynamic music.
All game-state mutations route through the **Command Pattern** (26 command classes,
40+ wired call sites) for replay/multiplayer safety.
115 test scripts, 2 369 tests, 4 277 asserts — all passing.

## 1.1 Requirements Overview

**Star Wars: Armada Digital Edition** is a digital adaptation of Fantasy Flight Games' tabletop miniatures game *Star Wars: Armada*. The game enables players to command fleets of capital ships and squadrons in tactical space combat within the Star Wars universe.

### Core Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| R-001 | Implement full core game rules from the Rules Reference v1.5.0 | Must |
| R-002 | Support two-player gameplay | Must |
| R-003 | Fleet building with point-cost constraints | Must |
| R-004 | Ship movement with the maneuver tool (speed/yaw system) | Must |
| R-005 | Dice-based combat with attack/defense mechanics | Must |
| R-006 | Command dial and token system | Must |
| R-007 | Squadron activation and combat | Must |
| R-008 | Objective card system | Should |
| R-009 | AI opponent for single-player mode | Should |
| R-010 | Save/Load game functionality | Should |
| R-011 | Visual feedback and animations for game actions | Should |
| R-012 | Tutorial / Learn-to-Play mode | Could |
| R-013 | Network multiplayer | Could |

> **Note:** Detailed requirements will be extracted from the Rules Reference Guide and Learn to Play documents during the requirements analysis phase.

## 1.2 Quality Goals

| Priority | Quality Goal | Description |
|----------|-------------|-------------|
| 1 | **Rules Fidelity** | The digital implementation must faithfully reproduce the tabletop game rules. |
| 2 | **Testability** | High unit and integration test coverage to ensure correctness. |
| 3 | **Maintainability** | Clean architecture enabling easy extension with new ships, upgrades, and rules. |
| 4 | **Usability** | Intuitive UI that guides players through the game phases. |
| 5 | **Performance** | Smooth 60fps rendering with responsive game interactions. |

## 1.3 Stakeholders

| Role | Name/Description | Expectations |
|------|-----------------|--------------|
| Developer / Game Designer | Katharina | Faithful adaptation, professional code quality, extensibility |
| Players | Target audience | Fun, accurate, polished game experience |
| AI Assistant | GitHub Copilot | Clear architecture, consistent patterns, testable code |
