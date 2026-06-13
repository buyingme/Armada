# Reality Gap Register

> Scope: compares the documented/intended architecture in Arc42, project docs,
> Copilot instructions, and skills with the actual implementation architecture
> recorded in `docs/current_state_architecture_maps.md`.
>
> This register does not assume that the documented architecture is correct, and
> it does not assume that the implementation is wrong. Each discrepancy is an
> architectural decision candidate. This document does not propose refactorings,
> rewrite contracts, or modify code.

## Classification Key

| ID | Meaning |
|---|---|
| 1 | Code likely should move toward docs |
| 2 | Docs likely outdated |
| 3 | Both may be valid, owner decision needed |
| 4 | Temporary legacy gap |
| 5 | Missing contract |
| 6 | Missing tests |

## Top Risks

| Risk | Source gaps | Current concern |
|---|---|---|
| Divergent authority for interaction flow | RG-003, RG-004, RG-014 | Some docs require command-only `InteractionFlow` mutation, while the code-derived map records scene-owned attack flow writes and publication snapshots. |
| Rule behavior split across multiple surfaces | RG-005, RG-006, RG-012 | New rules can be implemented inconsistently if Codex assumes `RuleRegistry` is already the only effective rule surface. |
| Accidental spread of orchestration hubs | RG-001, RG-002, RG-007 | `GameManager`, direct wrapper calls, and scene-owned workflow are real current architecture, but may or may not be intended as the long-term norm. |
| Stale architectural reference material | RG-008, RG-009, RG-010, RG-011 | Arc42/runtime docs contain obsolete paths, component names, counts, and behavior descriptions that can mislead implementation work. |
| Unverified invariant coverage | RG-013 | The architecture docs state many invariants, but the current map does not record which invariants are protected by tests. |

## Open Owner Decisions

| Decision candidate | Related gaps |
|---|---|
| Is the long-term architecture clean layered, autoload-centered, scene-orchestrated, or an explicit hybrid? | RG-001 |
| Is EventBus intended to be the exclusive cross-system communication mechanism, or one integration mechanism beside `GameManager` wrappers and downward calls? | RG-002 |
| Is direct `InteractionFlow` mutation by attack workflow accepted, temporary, or to be contained behind commands only? | RG-003, RG-014 |
| Should all future rule work go through `RuleRegistry`, or should resolver/command-owned rule surfaces remain first-class for core rules? | RG-005, RG-006 |
| What is the accepted responsibility boundary for `GameManager`? | RG-007 |
| Which Arc42 sections are authoritative after the directory reorganization and Phase M/N rule work? | RG-008, RG-009, RG-010, RG-011, RG-012 |
| Which architectural invariants must have explicit regression tests before related work continues? | RG-013 |

## Areas Where Codex Must Not Spread Legacy Patterns

- Do not add new direct `GameState.interaction_flow` writers outside existing attack/setup/flow surfaces without recording the gap and using an explicit command or existing local pattern.
- Do not add new rule predicates in UI panels when a command/resolver/projection payload can own the decision.
- Do not add new `GameManager` wrapper responsibilities unless the surrounding code already uses that wrapper path for the same command family.
- Do not add new `PlayMode.is_network()` / `PlayMode.is_hot_seat()` branches in `src/scenes/` or `src/ui/` except where already allowed by current lint/contracts.
- Do not treat stale Arc42 file paths or component names as source-of-truth class inventory.
- Do not assume `RuleRegistry` coverage exists for a rule family merely because the docs describe it as the production extension architecture.

## Gap Entries

### RG-001 - Layered Architecture vs Hybrid Runtime Shape

| Field | Value |
|---|---|
| Classification | 3 - Both may be valid, owner decision needed |
| Documented/intended behavior | Architecture is layered: Presentation -> Application -> Domain -> Data/Infrastructure. Arc42 presents layers in `docs/arc42/04_solution_strategy.md` lines 14-26. Copilot states `Architecture: Layered` in `.github/copilot-instructions.md` line 10. |
| Actual/observed behavior | The current implementation is not purely layered. The actual map records `GameManager` as a large orchestration hub, `EventBus` as an integration backbone, and scene controllers owning runtime workflow state in `docs/current_state_architecture_maps.md` lines 17-21 and 91-101. |
| Evidence from both documents | Intended: Arc42 solution strategy lines 14-26; Copilot line 10. Actual: current-state map lines 17-21, 95-101, 128-134. |
| Risk | New work may be designed against a simplified layered model and miss real runtime dependencies, especially scene/autoload responsibilities. |
| Blocks current work? | No. Current work can continue if it follows the existing local architecture intentionally. |
| Decision needed later | Decide whether the hybrid autoload/scene/command architecture is the accepted architecture or a transition state toward stricter layering. |
| Temporary rule for future Codex work | Treat layering docs as design intent, but follow the current local dependency shape when making narrow changes. Do not introduce new cross-layer patterns without naming the affected gap. |

### RG-002 - EventBus Exclusivity vs Mixed Integration Paths

| Field | Value |
|---|---|
| Classification | 3 - Both may be valid, owner decision needed |
| Documented/intended behavior | Arc42 says all inter-system communication uses `EventBus` in `docs/arc42/08_crosscutting_concepts.md` lines 3-9. `.skills/architecture_patterns.md` lines 29-39 also says all cross-system communication goes through `EventBus`. |
| Actual/observed behavior | The current-state map records a mixed model: EventBus reactions, direct scene/autoload calls into `GameManager`, command submitter paths, and projected UI paths. See `docs/current_state_architecture_maps.md` lines 194-215 and 229-234. |
| Evidence from both documents | Intended: Arc42 08 lines 3-9; architecture skill lines 29-39. Actual: current-state map lines 194-215 and 229-234. |
| Risk | Contributors may either overuse EventBus for request/response workflows or add direct calls where signals are expected, increasing inconsistency. |
| Blocks current work? | No. It blocks only architecture cleanup decisions, not ordinary feature work. |
| Decision needed later | Decide whether EventBus is exclusive, preferred for notifications only, or one of several accepted integration paths. |
| Temporary rule for future Codex work | Use the existing local path for the same workflow family: signals for notifications/reactions, `GameManager.submit_*` where the current command family already uses wrappers, and direct downward calls only inside the same composed subsystem. |

### RG-003 - Command-Only `InteractionFlow` Mutation vs Attack FSM Writes

| Field | Value |
|---|---|
| Classification | 4 - Temporary legacy gap |
| Documented/intended behavior | `InteractionFlow` is a serializable field of `GameState` mutated only inside `GameCommand.execute()`. This appears in `docs/arc42/04_solution_strategy.md` lines 34-36, `.skills/architecture_patterns.md` lines 54-94, `.github/copilot-instructions.md` lines 136 and 140, and `docs/game_flow.md` lines 62-87. |
| Actual/observed behavior | The current-state map records the attack workflow path as `AttackExecutor` / `TargetSelector` sequencing, combat resolver calculation, local `AttackFlowFSM` patching of `GameState.interaction_flow`, command persistence, and network snapshot publication. See `docs/current_state_architecture_maps.md` lines 215, 287, and 330. |
| Evidence from both documents | Intended: Arc42 solution strategy lines 34-36; architecture skill lines 68-94; Copilot lines 136 and 140. Actual: current-state map lines 215 and 330. |
| Risk | Save/replay/network determinism can be harder to reason about because some flow changes are local first and command-published later, not exclusively command-produced. |
| Blocks current work? | Partially. It does not block using the current attack path, but it should block adding new non-command flow writers outside established surfaces. |
| Decision needed later | Decide whether attack flow publication is an accepted special case, a temporary bridge, or should be converted to command-only mutation. |
| Temporary rule for future Codex work | Do not introduce new direct `InteractionFlow` mutation surfaces. If attack flow work must touch this area, preserve existing publication behavior and document any new writer explicitly. |

### RG-004 - UI Projection Contract vs Scene-Owned Workflow State

| Field | Value |
|---|---|
| Classification | 3 - Both may be valid, owner decision needed |
| Documented/intended behavior | Docs describe `UIProjector.project(state, local_player_index)` as the single source of modal/HUD/sidebar decisions, with no mode/authority branching in presentation. See `docs/arc42/04_solution_strategy.md` lines 35-36 and `.skills/architecture_patterns.md` lines 70-80 and 96-105. |
| Actual/observed behavior | The current-state map records scene-owned workflow state and rule-relevant option assembly in presentation: `AttackExecutor`, `AttackPanelController`, `TargetSelector`, setup placement, squadron modal state, and local previews. See `docs/current_state_architecture_maps.md` lines 42, 73-74, 98, 128, 215, 251-252, and 323-333. |
| Evidence from both documents | Intended: Arc42 solution strategy lines 35-36; architecture skill lines 70-80 and 96-105. Actual: current-state map lines 73-74, 215, and 330. |
| Risk | Presentation code can become an alternate rule/authority layer unless payload/projection boundaries are kept explicit. |
| Blocks current work? | No, but it affects any work touching modal authority, attack panels, defender choices, setup previews, or network/hot-seat projection. |
| Decision needed later | Decide which scene-owned states are acceptable transient preview state and which should be moved into command/projector contracts later. |
| Temporary rule for future Codex work | Keep preview-only state transient. Rule-derived choices that affect legality must be validated by commands/resolvers and, where UI choice lists are involved, represented in JSON-safe payload metadata. |

### RG-005 - RuleRegistry-Only Rule Architecture vs Hybrid Rule Implementation

| Field | Value |
|---|---|
| Classification | 3 - Both may be valid, owner decision needed |
| Documented/intended behavior | Arc42 says `RuleRegistry` is the only production rule-extension architecture as of Phase N24 in `docs/arc42/08_crosscutting_concepts.md` lines 467-480. The rule-integration skill requires static rule definitions in `RuleRegistry` and UI rendering from payload metadata in `.github/skills/rule-integration/SKILL.md` lines 13-27 and 67-78. |
| Actual/observed behavior | The current-state map records a hybrid rule model: static `RuleRegistry` hooks plus resolver-owned rules, command-owned validation, setup/fleet validators, and scene-owned previews/payload assembly. See `docs/current_state_architecture_maps.md` lines 10-15, 64-74, 99, and 241-252. |
| Evidence from both documents | Intended: Arc42 08 lines 467-480 and 545-552; rule skill lines 13-27. Actual: current-state map lines 10-15, 64-74, 241-252. |
| Risk | New rules may be split inconsistently across rule hooks, commands, resolvers, and UI, causing divergent hot-seat/network/replay behavior. |
| Blocks current work? | No for narrow changes that follow existing surfaces. Yes for adding or migrating rules without first identifying every affected rule surface. |
| Decision needed later | Decide whether resolver/command-owned rule logic remains first-class for core rules or whether all future rule extension should converge on `RuleRegistry`. |
| Temporary rule for future Codex work | For any rule change, identify every current surface: hook, resolver, command validation, payload/projection, and UI rendering. Do not assume `RuleRegistry` alone covers existing behavior. |

### RG-006 - Rule File Catalogue Targets vs Registered Rule Coverage

| Field | Value |
|---|---|
| Classification | 5 - Missing contract |
| Documented/intended behavior | Rule docs describe future/source-first groupings for core rules, ship keywords, upgrades, objectives, obstacles, and tokens under `src/core/effects/rules/`. See `.github/skills/rule-integration/SKILL.md` lines 94-130 and `docs/arc42/08_crosscutting_concepts.md` lines 545-552 and 589-593. |
| Actual/observed behavior | The current-state map records only registered ship damage-card rules and five squadron keyword rules in the active bootstrap catalogue. Other categories are organization targets, not registered production rule scripts. See `docs/current_state_architecture_maps.md` lines 76-89. |
| Evidence from both documents | Intended: rule skill lines 94-130; Arc42 08 lines 545-552 and 589-593. Actual: current-state map lines 76-89. |
| Risk | Codex may place new rule behavior into a category folder and assume it is active even if bootstrap, command coverage, and projection coverage are missing. |
| Blocks current work? | Only blocks new rule categories where no existing runtime contract says how they are registered and invoked. |
| Decision needed later | Decide when a rule category becomes production-supported and what bootstrap/test/projection requirements make it active. |
| Temporary rule for future Codex work | Treat unregistered rule folders as organization guidance, not active runtime behavior. New rule files must include registration and call-site coverage if they are meant to affect gameplay. |

### RG-007 - `GameManager` Narrow Role/LOC Ceiling vs Orchestration Hub

| Field | Value |
|---|---|
| Classification | 3 - Both may be valid, owner decision needed |
| Documented/intended behavior | `.skills/architecture_patterns.md` lines 142-147 list `GameManager` as game lifecycle and round/phase progression. `.github/copilot-instructions.md` line 146 says not to grow `game_manager.gd` beyond the Phase K LOC ceiling and to put new behavior into focused helpers. |
| Actual/observed behavior | The current-state map records `GameManager` as an orchestration hub owning active state reference, active player, activation trackers, command submitter strategy, command wrapper methods, setup/bootstrap/load handoff, network-result side effects, and EventBus emissions. See `docs/current_state_architecture_maps.md` lines 43, 97, 130, 213, 233, and 299. |
| Evidence from both documents | Intended: architecture skill lines 142-147; Copilot line 146. Actual: current-state map lines 43, 130, 233, and 299. |
| Risk | Future work may keep adding responsibilities to a central hub because the current code already does, while docs imply a narrower boundary. |
| Blocks current work? | No, but it affects where new orchestration code should be placed. |
| Decision needed later | Decide whether `GameManager` is an accepted application service hub or a constrained lifecycle facade. |
| Temporary rule for future Codex work | Do not add new `GameManager` responsibility categories. Use existing wrapper methods for matching command families, and prefer existing focused controllers/helpers when the surrounding code already has one. |

### RG-008 - Arc42 Building Block Inventory vs Current Repository Structure

| Field | Value |
|---|---|
| Classification | 2 - Docs likely outdated |
| Documented/intended behavior | `docs/arc42/05_building_block_view.md` lists many core files under older flat paths such as `src/core/game_state.gd`, `src/core/dice.gd`, `src/core/engagement_resolver.gd`, and `src/core/immediate_effect_resolver.gd` in lines 37-112. It also lists components such as `DamageRuleHelper`, `FiringArc`, `RangeMeasurer`, `AttackDicePanel`, and stale UI paths. |
| Actual/observed behavior | The current-state map records the actual repository topology under `src/core/state`, `src/core/combat`, `src/core/damage`, `src/core/movement`, `src/core/geometry`, `src/scenes`, and `src/ui`. See `docs/current_state_architecture_maps.md` lines 105-122 and 124-134. |
| Evidence from both documents | Intended/stale: Arc42 05 lines 37-112 and 118-160. Actual: current-state map lines 105-134. |
| Risk | File creation, imports, and architectural analysis may target nonexistent or outdated paths/classes. |
| Blocks current work? | No, if Codex verifies files with `rg --files` before editing. |
| Decision needed later | Decide which Arc42 inventory tables should be treated as historical and which should be updated to current structure. |
| Temporary rule for future Codex work | Always verify paths/classes from Arc42 against the repository before using them. Do not create compatibility files solely to satisfy stale documentation. |

### RG-009 - Runtime Movement Description vs Command-Backed Normalized Movement

| Field | Value |
|---|---|
| Classification | 2 - Docs likely outdated |
| Documented/intended behavior | `docs/arc42/06_runtime_view.md` lines 198-225 describe activation movement as speed buttons writing `ShipInstance.current_speed` and commit writing `Ship.global_position` / `Ship.global_rotation`. |
| Actual/observed behavior | The current-state map records durable positions as normalized state and movement committed through command-backed mutation, with maneuver/range tools as transient presentation state. See `docs/current_state_architecture_maps.md` lines 36, 217, 281-284, and 333. |
| Evidence from both documents | Intended/stale: Arc42 06 lines 198-225. Actual: current-state map lines 36, 217, 281-284, and 333. |
| Risk | New movement work may mutate scene nodes as if they were authoritative instead of committing normalized state through command paths. |
| Blocks current work? | No, but it should block using Arc42 runtime movement sequence as implementation authority. |
| Decision needed later | Decide whether Arc42 runtime movement should be revised to describe current command-backed state ownership. |
| Temporary rule for future Codex work | Treat scene movement as preview/rendering unless existing command code commits normalized `pos_x`, `pos_y`, and `rotation_deg`. |

### RG-010 - Status Phase Initiative Description vs Current Initiative Ownership

| Field | Value |
|---|---|
| Classification | 2 - Docs likely outdated |
| Documented/intended behavior | `docs/arc42/06_runtime_view.md` line 26 says Status Phase readies exhausted tokens and flips initiative. |
| Actual/observed behavior | The current-state map records round/phase/initiative as serialized `GameState` state and `GameManager` active-player orchestration, with no current-state note that initiative flips during status. See `docs/current_state_architecture_maps.md` lines 29, 281, and 299. |
| Evidence from both documents | Intended/stale: Arc42 06 line 26. Actual: current-state map lines 29, 281, and 299. |
| Risk | Status-phase work could implement an incorrect initiative transition based on stale runtime prose. |
| Blocks current work? | No, unless modifying status phase, round transition, or first-player behavior. |
| Decision needed later | Confirm the authoritative game rule for initiative retention/transfer and update docs or code accordingly. |
| Temporary rule for future Codex work | Do not change initiative behavior from runtime prose alone. Verify the current code path and rules reference before status-phase changes. |

### RG-011 - Resource-Based Data Description vs JSON/AssetLoader Reality

| Field | Value |
|---|---|
| Classification | 2 - Docs likely outdated |
| Documented/intended behavior | Arc42 describes game content as Godot Resources, including `.tres` authoring, in `docs/arc42/04_solution_strategy.md` line 10 and `docs/arc42/08_crosscutting_concepts.md` lines 11-17. |
| Actual/observed behavior | The current-state map records static data as JSON/assets under `Resources/Game_Components/`, loaded through `AssetLoader` into model resources or dictionaries. See `docs/current_state_architecture_maps.md` lines 48, 254-263, and 337-346. |
| Evidence from both documents | Intended/stale: Arc42 04 line 10; Arc42 08 lines 11-17. Actual: current-state map lines 48 and 337-346. |
| Risk | New content may be added in the wrong format or path if Codex follows old `.tres` wording. |
| Blocks current work? | No. |
| Decision needed later | Decide whether docs should describe the JSON-backed content pipeline as canonical, or whether `.tres` Resources remain a target architecture. |
| Temporary rule for future Codex work | Use the current `Resources/Game_Components/` JSON and `AssetLoader` pipeline for game content unless a specific task establishes a different contract. |

### RG-012 - Command/Rule Inventory Counts vs Current Command Surface

| Field | Value |
|---|---|
| Classification | 2 - Docs likely outdated |
| Documented/intended behavior | Arc42 solution strategy states 26 concrete command classes and 40+ wired call sites in `docs/arc42/04_solution_strategy.md` line 34. Arc42 serialization text also refers to `GameCommand` and all 26 subclasses in `docs/arc42/08_crosscutting_concepts.md` lines 66-72. |
| Actual/observed behavior | The current-state map records a broader command surface across command phase, activation, attack, defense, setup, movement, damage, status, save/replay, and network paths. See `docs/current_state_architecture_maps.md` lines 41, 131, 227-239, and 274-293. |
| Evidence from both documents | Intended/stale: Arc42 04 line 34; Arc42 08 lines 66-72. Actual: current-state map lines 41, 131, and 227-239. |
| Risk | Coverage estimates and architecture reviews based on old counts will miss newer command families. |
| Blocks current work? | No, if command inventory is discovered from files/registries rather than prose counts. |
| Decision needed later | Decide whether Arc42 should stop using fixed command counts or update them from generated inventory. |
| Temporary rule for future Codex work | Never rely on prose command counts. Search `src/core/commands/` and command registration paths before changing command surfaces. |

### RG-013 - Architectural Invariants vs Test Coverage Visibility

| Field | Value |
|---|---|
| Classification | 6 - Missing tests |
| Documented/intended behavior | Copilot and skills require tests for new core/model classes and public methods, full rule surfaces, command applicability, projection, save/load, replay, and baseline traces. See `.github/copilot-instructions.md` lines 92-97 and 160-175, and `.github/skills/rule-integration/SKILL.md` lines 80-87 and 132-140. |
| Actual/observed behavior | The current-state map records test/tooling dependencies but does not map which architectural invariants are covered by tests. See `docs/current_state_architecture_maps.md` lines 265-272. |
| Evidence from both documents | Intended: Copilot lines 92-97 and 160-175; rule skill lines 80-87. Actual: current-state map lines 265-272. |
| Risk | Codex may assume an invariant is tested because it is documented, or miss adding focused tests when touching a gap area. |
| Blocks current work? | No for documentation-only work. It may block high-risk source changes if no relevant tests can be identified. |
| Decision needed later | Decide which architecture gaps require explicit regression tests before owner decisions or future migrations. |
| Temporary rule for future Codex work | When touching any gap area in code, identify the existing tests that protect it or add focused tests for the changed behavior. Do not claim architectural compliance from documentation alone. |

### RG-014 - Actual Map Internal Tension Around `InteractionFlow` Ownership

| Field | Value |
|---|---|
| Classification | 5 - Missing contract |
| Documented/intended behavior | The intended docs define `InteractionFlow` as domain state mutated by command execution only. See `.skills/architecture_patterns.md` lines 54-94 and `.github/copilot-instructions.md` lines 136 and 140. |
| Actual/observed behavior | The current-state map has two descriptions that need an ownership decision: line 287 says active interaction flow is mutated by command execution and attack-flow publishing, while line 330 says attack execution workflow writes/patches `GameState.interaction_flow`. |
| Evidence from both documents | Intended: architecture skill lines 54-94; Copilot lines 136 and 140. Actual: current-state map lines 287 and 330. |
| Risk | Future work may cite either row to justify different mutation paths, creating ambiguous authority. |
| Blocks current work? | No for using current attack behavior. Yes for introducing a new flow owner or changing flow publication semantics. |
| Decision needed later | Decide and document whether attack FSM writes are command-equivalent publication details, accepted direct writes, or legacy exceptions. |
| Temporary rule for future Codex work | Treat `InteractionFlow` ownership as unresolved. Preserve existing behavior in narrow fixes and avoid expanding direct-write ownership. |

### RG-015 - Setup Contract Detail vs Architecture Map Abstraction

| Field | Value |
|---|---|
| Classification | 5 - Missing contract |
| Documented/intended behavior | `docs/setup_flow.md` is an accepted mandatory contract for setup UI work, with trigger, controller, visibility, required information, actions, state contract, validation, transition, and tests required for each step. See `docs/setup_flow.md` lines 9-32 and 56-67. |
| Actual/observed behavior | The current-state map records setup at architecture level: setup package, setup state in `GameState.objectives`, setup `InteractionFlow`, validators, setup commands, and transient previews. See `docs/current_state_architecture_maps.md` lines 31, 219, 287-289, and 331. |
| Evidence from both documents | Intended: setup contract lines 9-32 and 56-67. Actual: current-state map lines 31, 219, 287-289, and 331. |
| Risk | Architecture work may appear complete while a setup UI change still lacks step-level contract compliance. |
| Blocks current work? | Blocks setup UI/source changes only when the affected step is not covered by an accepted contract or the change crosses beyond the documented step. |
| Decision needed later | Decide whether setup contract conformance should be tracked in the architecture map or only in `docs/setup_flow.md`. |
| Temporary rule for future Codex work | For setup UI or setup presentation work, read `docs/setup_flow.md` first and treat the step contract as controlling over broad architecture summaries. |

### RG-016 - Historical Phase Docs vs Current Architecture References

| Field | Value |
|---|---|
| Classification | 2 - Docs likely outdated |
| Documented/intended behavior | `docs/` contains implementation and refactoring phase plans that record historical states, migration slices, and temporary legacy paths. Examples include `docs/implementation_plan.md`, `docs/refactoring_phase_k_plan.md`, `docs/refactoring_phase_lm_plan.md`, and archived files under `docs/old/`. |
| Actual/observed behavior | The current-state map treats these as part of documentation topology but records current implementation separately. See `docs/current_state_architecture_maps.md` lines 117-120 and 348-362. |
| Evidence from both documents | Intended/historical: phase docs in `docs/` and `docs/old/`. Actual: current-state map lines 117-120 and 348-362. |
| Risk | Codex may treat a historical plan slice as current contract, especially where older phase docs mention legacy bridges or deleted patterns. |
| Blocks current work? | No, if current code and current-state map are checked before acting. |
| Decision needed later | Decide which historical docs remain active references and which should be marked archival outside `docs/old/`. |
| Temporary rule for future Codex work | Use phase plans for context, not authority, unless the user explicitly names a phase plan as controlling for the task. Verify current code and current-state map before applying phase-plan instructions. |
