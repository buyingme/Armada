# Architecture Assessment — Refactor vs. Rewrite

> **Date:** 2026-04-07
> **Author:** GitHub Copilot (architectural analysis)
> **Scope:** Evaluate the current Armada codebase against best-practice
> game-engine architecture for dynamic, rule-heavy, network-ready games.
> Recommend a path forward.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Target Architecture (Best Practice)](#2-target-architecture-best-practice)
3. [Current Architecture Inventory](#3-current-architecture-inventory)
4. [Gap Analysis — Layer by Layer](#4-gap-analysis--layer-by-layer)
5. [Scorecard](#5-scorecard)
6. [Refactor vs. Rewrite Decision](#6-refactor-vs-rewrite-decision)
7. [Recommended Architecture](#7-recommended-architecture)
8. [Migration Roadmap](#8-migration-roadmap)
9. [Risk Matrix](#9-risk-matrix)
10. [Appendix: Codebase Metrics](#appendix-codebase-metrics)

---

## 1. Executive Summary

The project is **closer to the target architecture than it might feel**.
The domain layer (`src/core/`), effect system (`src/core/effects/`), data
models, EventBus, and test infrastructure are well-built and align with
best-practice patterns. The problems are concentrated in two god-object
presentation files (`game_board.gd`, `attack_executor.gd`) and in
missing infrastructure for serialization, command/action logging, and
deterministic replay.

**Verdict: Refactor, do not rewrite.**

A rewrite would discard ~32 000 lines of working, tested source code and
~22 000 lines of test coverage (1 669 tests). The core domain layer, the
effect engine, the data pipeline, and the 64-signal EventBus are all
salvageable and well-designed. The refactoring plan already in
`docs/refactoring_plan.md` (Phases A–G) is well-sequenced and covers
every gap identified here. Phase A is already complete.

---

## 2. Target Architecture (Best Practice)

From the user's research, the ideal architecture for a rule-heavy,
network-ready digital board game is:

| Layer | Responsibility | Key Properties |
|-------|---------------|----------------|
| **Domain State** | Hold all match data | Immutable transitions, serializable, deterministic |
| **Rules Engine** | Evaluate legal moves, triggers, effects | Pure functions, data-driven, composable |
| **Phase/State Machine** | Control turn structure, timing windows | Explicit states, well-defined transitions |
| **Event System** | Carry commands and resulting effects | Ordered, auditable, replayable |
| **Effect Resolver** | Apply damage, status, movement | Priority-ordered, hook-based |
| **UI/Animation** | Show what happened | Never source of truth |

Plus these cross-cutting capabilities:

- **Command/Action model** — every player action is a serialisable object
- **Deterministic simulation** — same inputs + same seed = same outputs
- **Action log / replay** — reproduce any game from its action sequence
- **Save/load** — full state serialisation at any point
- **Network transport** — commands flow between clients and authority

---

## 3. Current Architecture Inventory

### 3.1 What Exists Today

```
src/
├── autoload/     10 files   3 394 lines   Singletons (GameManager, EventBus, Constants, …)
├── core/         40 files   8 577 lines   Pure game logic (RefCounted)
│   └── effects/   7 files     ~900 lines  Effect engine (GameEffect, EffectRegistry, …)
├── models/        4 files     367 lines   Data resources (ShipData, SquadronData, …)
├── scenes/       11 files  10 002 lines   Visual scenes + controllers
├── ui/           26 files   9 284 lines   UI widgets
└── utils/         3 files     555 lines   Helpers (Logger, AssetLoader, ScenarioSaver)

tests/            89 files  22 082 lines   1 669 tests, 2 932 asserts, 88 scripts
```

**Total: 94 source files, 32 179 lines. Test/source ratio: 0.69.**

### 3.2 Layer Dependency Compliance

| Rule | Status | Detail |
|------|--------|--------|
| Core extends RefCounted, not Node | **✅ Clean** | All 40 files in `src/core/` extend RefCounted |
| Presentation → Core (never reverse) | **⚠️ Violated** | 3 core files emit EventBus signals directly (22 emit sites in core) |
| Cross-system via EventBus only | **✅ Mostly** | 64 signals, 24 files participate. No direct cross-system node refs found |
| Data-driven game content | **✅ Clean** | Ships, squadrons, damage cards all loaded from JSON |
| Constants for game values | **✅ Clean** | `Constants` autoload with enums + static helpers |

### 3.3 Key Strengths

1. **Effect Engine is production-quality.** `GameEffect` → `EffectRegistry`
   → `EffectContext` pipeline with hook-based resolution, priority ordering,
   and owner tracking. This *is* a rules engine, and a good one.

2. **GameState + PlayerState are serialisable.** `serialize()` /
   `deserialize()` exist on both, plus `CommandDialStack` and
   `CommandTokenManager`.

3. **Test coverage is exceptional** for a Godot project. 1 669 unit tests
   with AAA pattern, descriptive names, all passing.

4. **Data-driven content pipeline.** Ship/squadron/damage card data loaded
   from JSON via `AssetLoader`. Schema-validated.

5. **Clean core domain.** `ShipInstance`, `SquadronInstance`, `Dice`,
   `DicePool`, `GameState`, `FiringArc`, `GeometryHelper`, `RangeFinder`,
   `OverlapResolver`, `ManeuverCalculator` — all RefCounted, all testable.

6. **Phase state machine exists.** `GamePhase` enum + `GameManager`
   controls SETUP → COMMAND → SHIP → SQUADRON → STATUS cycle.

### 3.4 Key Weaknesses

1. **Two god-object files** concentrate 7 189 lines (22% of codebase):
   - `game_board.gd`: 3 913 lines, 188 methods, owns input + UI + flow +
     tokens + phases + debug
   - `attack_executor.gd`: 3 275 lines, 146 methods, mixes dice rules +
     defense tokens + damage resolution + UI panels

2. **No command/action model.** Player actions are handled by signal
   callbacks that directly mutate state. No serialisable action objects.

3. **No action log.** Game events are logged textually (`GameLogger`) but
   not as structured, replayable action records.

4. **Incomplete serialisation.** `ShipInstance`, `SquadronInstance`,
   `DamageDeck`, `DamageCard`, `ShipActivationState` have no
   `serialize()` / `deserialize()`. Full save/load is not possible.

5. **Non-deterministic RNG.** `Dice.roll()` and `DamageDeck.shuffle()` use
   Godot's global RNG, not a seeded `RandomNumberGenerator`.

6. **EventBus leaks into core.** `immediate_effect_resolver.gd` (11 emit
   sites), `repair_resolver.gd` (9 sites), `squadron_command_resolver.gd`
   (2 sites) directly call `EventBus.*.emit()`. Core classes should return
   results and let the presentation layer emit signals.

7. **No state immutability.** `GameState` fields are directly mutated by
   any code that holds a reference. No snapshot/diff mechanism.

---

## 4. Gap Analysis — Layer by Layer

### 4.1 Domain State

| Best Practice | Current | Gap | Effort |
|---------------|---------|-----|--------|
| Complete serialisable state | 6/11 classes serialisable | **5 classes missing** | Phase E (Low) |
| Immutable state transitions | Direct mutation | **No immutability** | Phase G (Medium) — introduce via Command pattern |
| Deterministic RNG | Global `randi()` | **Not seeded** | G5 (Low — 2 call sites) |
| State snapshots for undo/netcode | None | **Missing** | Phase G (comes free with Command.execute() returning deltas) |

**Current alignment: ~40%**

### 4.2 Rules Engine

| Best Practice | Current | Gap | Effort |
|---------------|---------|-----|--------|
| Hook-based effect pipeline | ✅ EffectRegistry + 14 hooks | **None** | — |
| Data-driven rule definitions | ✅ JSON damage cards, keyword effects | **None** | — |
| Priority-ordered resolution | ✅ player_priority + registration order | **None** | — |
| Composable conditions/predicates | ✅ should_trigger() + EffectContext | **None** | — |
| All rules go through engine | ⚠️ Some rules hardcoded in AE/GB | **Partial** | Ongoing — move rules to effects as system grows |

**Current alignment: ~80%** — This is the strongest layer.

### 4.3 Phase / State Machine

| Best Practice | Current | Gap | Effort |
|---------------|---------|-----|--------|
| Explicit phase enum | ✅ Constants.GamePhase (5 phases) | **None** | — |
| Phase transitions in one place | ✅ GameManager orchestrates | **None** | — |
| Sub-phase state machines | ⚠️ ShipActivationState (Step enum) exists, but attack sub-phases are implicit in AE | **Partial** — attack is a 40-var implicit FSM | Phase F4 (Medium) |
| Timing windows for reactions | ✅ DEFENSE_VALIDATE_TOKEN, BEFORE_REVEAL_DIAL, etc. | **None** — hooks serve as timing windows | — |

**Current alignment: ~70%**

### 4.4 Event System

| Best Practice | Current | Gap | Effort |
|---------------|---------|-----|--------|
| Central event bus | ✅ 64 signals on EventBus singleton | **None** | — |
| Ordered, auditable log | ⚠️ Text-only GameLogger | **Structured action log missing** | Phase G (Medium) |
| Replayable action sequence | ❌ Not possible today | **Missing entirely** | Phase G (Medium) |
| Commands as first-class objects | ❌ Actions are inline callbacks | **Missing entirely** | Phase G (Medium) |

**Current alignment: ~30%** (signals exist but no action model)

### 4.5 Effect Resolver

| Best Practice | Current | Gap | Effort |
|---------------|---------|-----|--------|
| Centralised resolver with priorities | ✅ EffectRegistry.resolve_hook() | **None** | — |
| Consistent hook pipeline | ✅ 14/14 hooks wired, all damage cards functional | **None** | — |
| Extensible to upgrade cards | ✅ GameEffect base class + EffectFactory pattern | **None** — just add new subclasses | — |
| Two-phase choice resolution | ✅ ImmediateEffectResolver.get_required_choice() → resolve() | **None** | — |

**Current alignment: ~90%** — Near-complete.

### 4.6 UI / Presentation

| Best Practice | Current | Gap | Effort |
|---------------|---------|-----|--------|
| UI never decides rules | ⚠️ game_board.gd and attack_executor.gd mix rules + UI | **Major violation** in 2 files | Phases C + F |
| UI reacts to state/events | ✅ Most UI listens to EventBus signals | **Mostly clean** for ui/ widgets | — |
| Presentation layer is replaceable | ❌ Logic embedded in scene controllers | **Not replaceable** | Phases C + F |
| Animation/SFX decoupled | ✅ SFXManager + MusicManager autoloads | **None** | — |

**Current alignment: ~40%** — UI widgets are clean; scene controllers are the problem.

---

## 5. Scorecard

| Architecture Dimension | Weight | Current Score | Target | Notes |
|------------------------|--------|:---:|:---:|-------|
| Domain State (serialisable, deterministic) | 20% | 4/10 | 9/10 | Serialisation gaps, no immutability |
| Rules Engine (data-driven, hook-based) | 20% | 8/10 | 9/10 | Already strong; minor hardcoded rules in AE |
| Phase / State Machine | 15% | 7/10 | 9/10 | Good for phases; attack sub-FSM is implicit |
| Event System + Action Model | 20% | 3/10 | 9/10 | SignalBus exists; no command objects, no replay |
| Effect Resolver | 10% | 9/10 | 10/10 | Near-complete |
| Presentation Separation | 15% | 4/10 | 8/10 | God objects mix logic + UI |
| **Weighted Total** | **100%** | **5.2/10** | **9.0/10** | |

**Interpretation:** The project scores well on the rule engine and effect
system (the hardest parts to build). It scores poorly on serialisation,
action model, and presentation separation (the parts addressable by
incremental refactoring).

---

## 6. Refactor vs. Rewrite Decision

### 6.1 Arguments for Rewrite

| Argument | Strength | Counter |
|----------|----------|---------|
| God objects are too big | Medium | Phase A already done (0 oversized functions). Phases C+F have a concrete extraction plan. |
| No command pattern | Medium | Additive change (Phase G). Does not require rewriting existing logic — wraps it. |
| State is mutable | Low | Immutability can be layered on via commands. Pure immutable state is academically ideal but not required for Godot's single-threaded model. |
| EventBus in core layer | Low | 22 emit sites across 3 files. Fixable by returning result objects. |

### 6.2 Arguments for Refactor

| Argument | Strength |
|----------|----------|
| **1 669 passing tests** — rewrite would discard all of them | **Critical** |
| **Effect engine is production-quality** — would be reimplemented identically | **Strong** |
| **32K lines of working, shipped code** — months of domain knowledge embedded | **Strong** |
| **Refactoring plan exists** with 7 phases, each independently shippable | **Strong** |
| **Phase A already complete** — 0 oversized functions, proven extraction technique | **Strong** |
| Core domain layer (`src/core/`) is clean (40 files, all RefCounted, all tested) | **Strong** |
| Data pipeline (JSON → models → instances) works correctly | **Medium** |
| Godot 4.5's architecture encourages composition, not clean-room OOP — the god objects are a Godot anti-pattern, not a framework limitation | **Medium** |

### 6.3 Verdict

**Refactor.** Confidence: **High (9/10).**

The rewrite threshold is typically crossed when:
- The language/framework must change ← No
- The fundamental data model is wrong ← No (GameState + PlayerState + ShipInstance is correct)
- Tests are absent and behaviour is unknown ← No (1 669 tests)
- The coupling is so deep that every change breaks everything ← No (core layer is clean; problems are in 2 presentation files)

None of these conditions apply. The existing `refactoring_plan.md` is well-
structured and addresses every weakness identified here.

---

## 7. Recommended Architecture

### 7.1 Target Shape (After Phase G)

```
┌─────────────────────────────────────────────────────┐
│                   PRESENTATION                       │
│                                                      │
│  GameBoard        Controllers (C1–C6)    UI Widgets  │
│  (orchestrator    DisplacementCtrl       AttackPanel  │
│   ~500 lines)     DialDragCtrl          RepairPanel   │
│                   CommandPhaseCtrl       Modals, etc.  │
│                   ManeuverToolCtrl                     │
│                   SquadronPhaseCtrl                    │
│                                                      │
│  AttackExecutor   AttackUIManager                     │
│  (~1 500 lines    (panel lifecycle)                   │
│   pure FSM)                                          │
├──────────────────────┬───────────────────────────────┤
│                      │                               │
│    APPLICATION       │      EVENT SYSTEM             │
│                      │                               │
│  GameManager         │  EventBus (signals)           │
│  CommandProcessor    │  GameCommand objects           │
│  SaveGameManager     │  ActionLog (replay)           │
│  ActivationContext   │                               │
├──────────────────────┴───────────────────────────────┤
│                                                      │
│                  DOMAIN / RULES                       │
│                                                      │
│  GameState          EffectRegistry    Dice (seeded)   │
│  PlayerState        GameEffect        DicePool        │
│  ShipInstance       DamageCardEffect  RangeFinder     │
│  SquadronInstance   KeywordEffects    FiringArc       │
│  ShipActivationSt.  ImmediateEffRes.  GeometryHelper  │
│  DamageDeck/Card    EffectContext     OverlapResolver  │
│  CommandDialStack   EffectFactory     ManeuverCalc     │
│  CommandTokenMgr                     TargetingListBldr │
│                                                      │
├──────────────────────────────────────────────────────┤
│                     DATA                              │
│                                                      │
│  ShipData (JSON)   SquadronData (JSON)   UpgradeData  │
│  DamageCards JSON   scale_config.json    Scenarios     │
│                                                      │
└──────────────────────────────────────────────────────┘
```

### 7.2 What Changes vs. Today

| Component | Today | Target | Change Type |
|-----------|-------|--------|-------------|
| `game_board.gd` | 3 913 lines, 188 methods | ~500 lines, orchestrator only | **Extract** 6 controllers (Phase C) + backbone (Phase F) |
| `attack_executor.gd` | 3 275 lines, 146 methods | ~1 500 lines (FSM) + AttackUIManager | **Extract** UI management (Phase F4) |
| CommandProcessor | Does not exist | New autoload, routes all actions | **New** (Phase G) |
| GameCommand subclasses | Do not exist | ~12 command classes | **New** (Phase G) |
| ActionLog / Replay | Does not exist | Records command sequence | **New** (Phase G) |
| SaveGameManager | Does not exist | Full save/load | **New** (Phase E) |
| Serialisation | 6/11 classes | 11/11 classes | **Extend** (Phase E) |
| Deterministic RNG | Global randi() | Seeded RandomNumberGenerator | **Replace** 2 call sites (Phase G5) |
| ActivationContext | Implicit in game_board vars | Explicit RefCounted shared object | **New** (Phase F1) |
| EventBus in core | 22 emit sites in 3 files | 0 emit sites in core | **Refactor** — return results, emit in presentation (Phase E) |
| UIPanelManager | 9 vars scattered in game_board | Dedicated controller | **Extract** (Phase F3) |

### 7.3 What Stays Exactly the Same

These components are already best-practice and need zero changes:

- **EffectRegistry + GameEffect + EffectContext** — the rules engine
- **DamageCardEffect + DamageCardEffectFactory** — persistent effect pattern
- **ImmediateEffectResolver** — immediate damage card pipeline (minus EventBus emit)
- **GameState + PlayerState** — authoritative state model
- **ShipInstance, SquadronInstance** — domain entities
- **Constants, EventBus** — core infrastructure
- **All 40 core files** — geometry, range, maneuver, dice, targeting
- **All 26 UI widgets** — already presentation-only
- **All 89 test files and 1 669 tests**
- **JSON data pipeline** — ships, squadrons, damage cards, scenarios

**This amounts to roughly 75–80% of the codebase remaining untouched.**

---

## 8. Migration Roadmap

The existing `refactoring_plan.md` Phases A–G map almost perfectly to the
best-practice architecture. Below is the recommended order with alignment
to the target layers:

### Phase Mapping

| Phase | Focus | Target Layer | Status | Effort |
|-------|-------|--------------|--------|--------|
| **A** | Shrink all functions to ≤30 lines | All | **✅ Done** | — |
| **B** | Narrow interfaces, inject dependencies | Application + Presentation | Not started | 1–2 days |
| **C** | Extract 6 controllers from game_board.gd | Presentation | Not started | 3–5 days |
| **D** | UI builder cleanup + UIStyleHelper | Presentation | Not started | 2–3 days |
| **E** | Serialisation + EventBus cleanup | Domain + Event System | Not started | 3–5 days |
| **F** | ActivationContext + SquadronPhaseCtrl + UIPanelManager + AttackUIManager | Application + Presentation | Not started | 5–7 days |
| **G** | Command pattern + ActionLog + Replay + Network | Event System + Application | Not started | 10–15 days |

**Total estimated effort: 24–37 days of focused development.**

### Recommended Sequencing

```
NOW ─── Phase B ─── Phase C ─── Phase D ─── Phase E ─── Phase F ─── Phase G
         (2d)         (5d)        (3d)        (5d)        (7d)       (15d)
          │             │           │           │           │           │
          │             │           │           │           │           └─ Network-ready
          │             │           │           │           └─ Save/load works
          │             │           │           └─ Full serialisation
          │             │           └─ UI code is clean
          │             └─ game_board.gd is ~1800 lines, 6 controllers
          └─ Dependencies are injectable, testable
```

### Priority Recommendations

**If the next feature is upgrade cards:** Start with B → C → stop.
Upgrade card effects plug directly into the existing EffectRegistry — you
just need new `GameEffect` subclasses. The god-object extraction makes
the integration points clearer.

**If the next feature is save/load:** Start with E (serialisation).
Requires no prior phases — purely additive.

**If the next feature is network multiplayer:** Complete B → C → E → F → G
in sequence. This is the full pipeline.

**If the priority is just continued feature work (new ships, scenarios,
content):** The current architecture handles this fine. Content is data-
driven and plugs in without touching the god objects.

---

## 9. Risk Matrix

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Refactoring breaks attack flow | Medium | High | 1 669 tests catch regressions; commit per sub-step |
| Phase F's ActivationContext introduces subtle bugs | Medium | Medium | Existing tests cover all activation paths; add integration tests for context sharing |
| Phase G CommandProcessor doubles code paths temporarily | Low | Medium | Use adapter pattern: existing signal handlers create Command objects internally |
| Serialisation misses edge cases (mid-attack state) | Medium | Low | Start with between-round save points; full mid-turn save later |
| Scope creep during extraction | Medium | Medium | Follow refactoring_plan.md task tables exactly; resist adding features during refactoring |
| Godot 4.x breaking changes | Low | Low | Already on 4.5.1; API is stable |

---

## Appendix: Codebase Metrics

### File Size Distribution

| Range | Count | % |
|-------|------:|--:|
| < 200 lines | 55 | 59% |
| 200–500 lines | 26 | 28% |
| 500–1000 lines | 7 | 7% |
| 1000–2000 lines | 2 | 2% |
| > 2000 lines | 4** | 4% |

** `game_board.gd` (3 913), `attack_executor.gd` (3 275), plus 2 UI files
over 1 400 lines.

### Layer Distribution

| Layer | Files | Lines | % of Total |
|-------|------:|------:|-----------:|
| Autoload | 10 | 3 394 | 11% |
| Core (domain) | 40 | 8 577 | 27% |
| Models (data) | 4 | 367 | 1% |
| Scenes (presentation) | 11 | 10 002 | 31% |
| UI (presentation) | 26 | 9 284 | 29% |
| Utils | 3 | 555 | 2% |
| **Total** | **94** | **32 179** | **100%** |

### Test Metrics

| Metric | Value |
|--------|-------|
| Test files | 89 |
| Test scripts (loaded by GUT) | 88 |
| Individual tests | 1 669 |
| Assert count | 2 932 |
| Test/source line ratio | 0.69 |
| All passing | ✅ |

### Effect System Coverage

| Category | Implemented | Total |
|----------|:-----------:|:-----:|
| Damage card effects (persistent) | 16/16 | 100% |
| Damage card effects (immediate) | 6/6 | 100% |
| Effect hooks wired | 14/14 | 100% |
| Squadron keyword effects | 3 (Bomber, Escort, Swarm) | ~30% of all keywords |
| Upgrade card effects | 0 | 0% (future) |
| Objective card effects | 0 | 0% (future) |

### EventBus Signal Categories

| Category | Signals |
|----------|--------:|
| Game Flow | 5 |
| Ship Events | 9 |
| Squadron Events | 5 |
| Combat Events | 4 |
| UI Events | 3 |
| Command Phase | 8 |
| Turn Management | 6 |
| Repair / Damage | 7 |
| Ship Activation | 7 |
| Maneuver / Tools | 7 |
| Handoff / Perspective | 3 |
| **Total** | **64** |

---

## Summary Decision Table

| Question | Answer |
|----------|--------|
| **Rewrite or refactor?** | **Refactor** |
| **Confidence level** | 9/10 |
| **Current alignment with target** | 5.2/10 |
| **Alignment after refactoring plan** | ~9/10 |
| **What's already best-practice?** | Rules engine, effect system, domain models, data pipeline, test suite |
| **What needs work?** | God objects (2 files), serialisation (5 classes), command pattern, EventBus in core |
| **% of code that survives?** | ~80% unchanged, ~15% extracted/reorganised, ~5% new |
| **Existing plan quality?** | Excellent — `refactoring_plan.md` covers all identified gaps |
| **Next recommended action** | Phase B (1–2 days) — narrow interfaces, unblock Phase C extractions |

---

*End of assessment.*
