# 5. Building Block View

## 5.1 Level 1 — System Overview

```
┌─────────────────────────────────────────────────┐
│            Star Wars: Armada Digital             │
│                                                  │
│  ┌────────────┐  ┌──────────┐  ┌─────────────┐  │
│  │   UI /     │  │  Game    │  │   Data      │  │
│  │   Scenes   │──│  Core    │──│   Layer     │  │
│  │            │  │          │  │             │  │
│  └────────────┘  └──────────┘  └─────────────┘  │
│         │              │              │           │
│  ┌────────────┐  ┌──────────┐  ┌─────────────┐  │
│  │  Assets    │  │ Autoload │  │   Tests     │  │
│  │            │  │ Services │  │             │  │
│  └────────────┘  └──────────┘  └─────────────┘  │
└─────────────────────────────────────────────────┘
```

### Component Descriptions

| Block | Description | Location |
|-------|-------------|----------|
| **UI / Scenes** | Visual scenes, HUD elements, menus, game board rendering | `src/scenes/`, `src/ui/` |
| **Game Core** | Rules engine, game state, phase management, combat resolution | `src/core/` |
| **Data Layer** | Data models as Godot Resources (ships, squadrons, upgrades) | `src/models/` |
| **Autoload Services** | Singletons (GameManager, EventBus, Constants, TooltipManager, SfxManager, MusicManager, DebugMode, SaveGameManager, CommandProcessor) | `src/autoload/` |
| **Assets** | Textures, audio, fonts, shaders | `assets/` |
| **Tests** | Unit and integration tests | `tests/` |

## 5.2 Level 2 — Game Core Detail

### Implemented Core Components

| Component | Extends | File | Purpose |
|-----------|---------|------|---------|
| `GameState` | RefCounted | `src/core/game_state.gd` | Round, phase, fleet and ship tracking |
| `PlayerState` | RefCounted | `src/core/player_state.gd` | Per-player fleet data, ship/squadron lists |
| `Dice` | RefCounted | `src/core/dice.gd` | Single die roll and face tables |
| `DicePool` | RefCounted | `src/core/dice_pool.gd` | Pool assembly and batch rolling |
| `ManeuverCalculator` | RefCounted | `src/core/maneuver_calculator.gd` | Chain-computation of tool joints and final transform |
| `ManeuverToolState` | RefCounted | `src/core/maneuver_tool_state.gd` | Activation-mode state: Navigate budget, yaw bonus, commit |
| `ShipActivationState` | RefCounted | `src/core/ship_activation_state.gd` | Activation step tracking, command spending |
| `CommandTokenManager` | RefCounted | `src/core/command_token_manager.gd` | Token pool management, add/remove/spend |
| `TooltipLayout` | RefCounted | `src/core/tooltip_layout.gd` | Pure tooltip position computation |
| `EffectContext` | RefCounted | `src/core/effects/effect_context.gd` | Mutable data bag passed through RuleRegistry callbacks |
| `RuleRegistry` | RefCounted | `src/core/effects/rule_registry.gd` | Static catalogue for validators, modifiers, observers, blockers, and enablers |
| `RuleSurface` | RefCounted | `src/core/effects/rule_surface.gd` | Shared target names and callback runners for rule surfaces |
| `FlowHook` | RefCounted | `src/core/effects/flow_hook.gd` | Deterministic hook descriptor used by RuleRegistry |
| `InteractionFlow` (Phase I) | RefCounted | `src/core/state/interaction_flow.gd` | Serializable description of the active interactive UI step (`flow_type`, `step_id`, `controller_player`, `visible_to`, `payload`). Held inside `GameState`. Mutated only by `GameCommand.execute()`. |
| `AttackFlowFSM` (Phase I) | RefCounted | `src/core/combat/attack_flow_fsm.gd` | Pure state machine for attack sub-steps (declare → roll → modify → defense → resolve → critical). Reads/writes `InteractionFlow.step_id` via commands. Replaces the implicit ~40-variable FSM in `attack_executor.gd`. |
| `UIProjector` (Phase I) | RefCounted | `src/core/network/ui_projector.gd` | Pure function `project(state, local_player_index) -> UIIntent`. Single source of truth for which modal is open, who can act, what HUD text shows. Replaces `is_network()` branching across presentation code. |
| `SquadronKeywordRuleHelper` | RefCounted | `src/core/effects/rules/squadron_keywords/squadron_keyword_rule_helper.gd` | Shared keyword lookup, engagement, attack-kind, and affordance predicates |
| `EngagementResolver` | RefCounted | `src/core/engagement_resolver.gd` | Edge-to-edge distance-1 engagement checks, valid target filtering |
| `SquadronMover` | RefCounted | `src/core/squadron_mover.gd` | Distance band + overlap validation for squadron placement |
| `LineOfSightChecker` | RefCounted | `src/core/line_of_sight_checker.gd` | LOS edge-to-edge tracing, obstruction detection |
| `OverlapResolver` | RefCounted | `src/core/overlap_resolver.gd` | Ship–ship overlap (speed reduction loop, facedown damage) and ship–squadron overlap (displacement list, placement validation, snap-to-edge) |
| `RepairResolver` | RefCounted | `src/core/repair_resolver.gd` | Repair command: dial/token budget, recover shields / discard damage cards |
| `SquadronCommandResolver` | RefCounted | `src/core/squadron_command_resolver.gd` | Squadron command: dial/token activation budget, range check, finalize spend |
| `ScoringCalculator` | RefCounted | `src/core/scoring_calculator.gd` | End-of-game scoring: ship/squadron destruction points, objective tokens, margin-of-victory table |
| `DamageRuleHelper` | RefCounted | `src/core/effects/rules/damage_cards/damage_rule_helper.gd` | Shared faceup-damage lookup and predicate helpers for damage-card rule files |
| `ImmediateEffectResolver` | RefCounted | `src/core/immediate_effect_resolver.gd` | Resolves faceup damage card immediate effects (Structural Damage, Projector Misaligned, etc.) |
| `ActivationContext` | RefCounted | `src/core/activation_context.gd` | Shared activation state (current ship, activation state, overlap flag) injected into all controllers |
| `GameCommand` | RefCounted | `src/core/game_command.gd` | Abstract base for all player-initiated game actions — serialize, validate, execute |
| `GameRng` | RefCounted | `src/core/game_rng.gd` | Deterministic seeded RNG wrapper for dice rolls and deck shuffles |
| `GameReplay` | RefCounted | `src/core/game_replay.gd` | Replay recording/playback — v1 JSON file format, header + command array |
| `FleetSetupPackage` | RefCounted | `src/core/setup/fleet_setup_package.gd` | Serializable setup-package shell with deterministic canonical hash for embedded roster payloads and objective setup state |
| `FleetSetupPackageBuilder` | RefCounted | `src/core/setup/fleet_setup_package_builder.gd` | Builds match-ready setup packages from validated player rosters, local fleet ids, or host/client roster mappings |
| `FleetRosterSetupHelper` | RefCounted | `src/core/setup/fleet_roster_setup_helper.gd` | Converts embedded setup-package rosters into runtime player, ship, and squadron state without local fleet-library dependencies |
| `SetupValidationResult` | RefCounted | `src/core/setup/setup_validation_result.gd` | JSON-safe setup-package validation errors and warnings, including player-scoped fleet-validation issues |
| `LearningScenarioPreparer` | RefCounted | `src/core/setup/learning_scenario_preparer.gd` | Scene-independent Learning Scenario preparation: instance creation, normalized position seeding, and GameState registration |
| `FleetRoster` | RefCounted | `src/core/fleet/fleet_roster.gd` | Editable fleet-builder roster payload separate from runtime `PlayerState` |
| `FleetShipEntry` | RefCounted | `src/core/fleet/fleet_ship_entry.gd` | Serializable ship roster entry with deterministic upgrade-assignment ordering |
| `FleetSquadronEntry` | RefCounted | `src/core/fleet/fleet_squadron_entry.gd` | Serializable squadron roster entry |
| `FleetUpgradeAssignment` | RefCounted | `src/core/fleet/fleet_upgrade_assignment.gd` | Serializable upgrade assignment attached to a ship roster entry |
| `FleetObjectiveSelection` | RefCounted | `src/core/fleet/fleet_objective_selection.gd` | Serializable Assault/Defense/Navigation objective selection |
| `FleetValidationResult` | RefCounted | `src/core/fleet/fleet_validation_result.gd` | JSON-safe validation errors and warnings for future fleet construction rules |
| `FleetCatalog` | RefCounted | `src/core/fleet/fleet_catalog.gd` | Deterministic catalog query helper with metadata filters and linked rules-reference lookup |
| `FleetBuilderOptions` | RefCounted | `src/core/fleet/fleet_builder_options.gd` | Core-backed option provider for fleet-builder point formats, factions, upgrade groups, objective categories, and rules-reference filters |
| `FleetValidator` | RefCounted | `src/core/fleet/fleet_validator.gd` | Deterministic fleet-construction validator for baseline rules plus upgrade slot/restriction legality |
| `FleetLibraryManager` | RefCounted | `src/core/fleet/fleet_library_manager.gd` | Local fleet library persistence with version snapshots and FB8 JSON import/export helpers |
| `FleetRosterDraftHelper` | RefCounted | `src/core/fleet/fleet_roster_draft_helper.gd` | UI-facing helper for local fleet draft mutations that keeps roster edits behind core APIs |
| `FleetRosterSummary` | RefCounted | `src/core/fleet/fleet_roster_summary.gd` | Computes fleet-builder point totals for ships, squadrons, upgrades, and point limits |
| `FleetUpgradeSlotResolver` | RefCounted | `src/core/fleet/fleet_upgrade_slot_resolver.gd` | Finds first open matching ship upgrade slots for builder assignment flows |

### Additional Core Components

| Component | Extends | File | Purpose |
|-----------|---------|------|---------|
| `ShipInstance` | RefCounted | `src/core/ship_instance.gd` | Runtime ship state: shields, damage cards, defense tokens, speed |
| `SquadronInstance` | RefCounted | `src/core/squadron_instance.gd` | Runtime squadron state: hull, activation, defense tokens |
| `ShipBase` | RefCounted | `src/core/ship_base.gd` | Ship geometry: base polygon, hull zone edges |
| `SquadronBase` | RefCounted | `src/core/squadron_base.gd` | Squadron geometry: circular base |
| `FiringArc` | RefCounted | `src/core/firing_arc.gd` | Arc polygon and point-in-arc tests |
| `RangeFinder` | RefCounted | `src/core/range_finder.gd` | Edge-to-edge closest-point range measurement |
| `RangeMeasurer` | RefCounted | `src/core/range_measurer.gd` | High-level range-band lookup |
| `TokenMover` | RefCounted | `src/core/token_mover.gd` | Debug token drag with collision avoidance |
| `CommandDialStack` | RefCounted | `src/core/command_dial_stack.gd` | Per-ship dial queue: assign, reveal, peek |
| `DamageCard` | RefCounted | `src/core/damage_card.gd` | Single damage card: face-up/down, effect ID |
| `DamageDeck` | RefCounted | `src/core/damage_deck.gd` | 33-card damage deck with shuffle and draw |
| `TargetingListBuilder` | RefCounted | `src/core/targeting_list_builder.gd` | Builds targeting data for all ship/squadron pairs |
| `AttackState` | RefCounted | `src/core/attack_state.gd` | Shared attack-flow state (attacker/defender identity, dice, CF, defense, deferred damage) |
| `CombatParticipants` | RefCounted | `src/core/combat_participants.gd` | Immutable data class bundling attacker/defender token/zone identity |
| `AttackTargetResolver` | RefCounted | `src/core/attack_target_resolver.gd` | Pure-geometry target queries: arc check, LOS, range, zone-has-targets |
| `AttackDiceResolver` | RefCounted | `src/core/attack_dice_resolver.gd` | Armament resolution, dice pool computation, CF logic, damage calc |
| `DefenseTokenResolver` | RefCounted | `src/core/defense_token_resolver.gd` | Defense token availability, spend-method resolution, token effects |
| `DamageDealer` | RefCounted | `src/core/damage_dealer.gd` | Final damage calc, shield absorption, hull tracking, card dealing |
| `LearningScenarioSetup` | RefCounted | `src/core/learning_scenario_setup.gd` | Loads learning scenario JSON and spawns initial placement |
| `CanonicalJson` | RefCounted | `src/utils/canonical_json.gd` | Utility for sorted-key JSON stringification and stable SHA-256 payload hashes |

## 5.3 Level 2 — UI Detail

### Implemented UI/Scene Components

| Component | Extends | File | Purpose |
|-----------|---------|------|---------|
| `GameBoard` | Node2D | `src/scenes/game_board/game_board.gd` | Main play area, ship/token rendering, camera, activation backbone, delegates to child controllers |
| `FleetBuilderScene` | Control | `src/scenes/fleet_builder/fleet_builder.gd` | Local fleet-builder MVP with Fleet Data catalog/fleet tabs, grouped upgrade filtering, roster/objective editing and objective inspection, selected card-rule/art rendering, validation rendering, and filtered rules-reference browsing |
| `FleetLibraryPanel` | VBoxContainer | `src/ui/fleet_builder/fleet_library_panel.gd` | Reusable fleet-builder library widget for save/open/save-as/duplicate/delete, version restore, and JSON import/export controls backed by `FleetLibraryManager` |
| `FleetLibraryPanelActions` | RefCounted | `src/ui/fleet_builder/fleet_library_panel_actions.gd` | UI-independent operation adapter for the fleet library panel's save/open/restore/import/export calls |
| `FleetLibraryPanelView` | RefCounted | `src/ui/fleet_builder/fleet_library_panel_view.gd` | Builder helper that constructs the fleet library panel controls while keeping the coordinator script focused on behavior |
| `FleetLibraryListPresenter` | RefCounted | `src/ui/fleet_builder/fleet_library_list_presenter.gd` | Presenter helper that formats saved-fleet and version rows for the Fleets tab lists |
| `UIPanelManager` | Node | `src/scenes/game_board/ui_panel_manager.gd` | Owns all UI panel creation, positioning, resizing, and isolated callbacks (card panels, overlays, modals, HUD) |
| `AttackExecutor` | Node | `src/scenes/game_board/attack_executor.gd` | Attack execution (activation Step 4): dice sequence, defense tokens, damage resolution. Delegates targeting to `TargetSelector` and pure computation to `AttackDiceResolver`, `DefenseTokenResolver`, `DamageDealer` |
| `TargetSelector` | Node | `src/scenes/game_board/target_selector.gd` | Attacker/target selection pipeline shared by attack simulator and execution. Emits `target_locked` to AE on valid target |
| `TargetingListController` | Node | `src/scenes/game_board/targeting_list_controller.gd` | Targeting list modal lifecycle + `TargetingListBuilder` integration |
| `DisplacementController` | Node | `src/scenes/game_board/displacement_controller.gd` | Squadron displacement flow after ship maneuver overlap |
| `DialDragController` | Node | `src/scenes/game_board/dial_drag_controller.gd` | Command dial drag-and-drop to activate ships |
| `CommandPhaseController` | Node | `src/scenes/game_board/command_phase_controller.gd` | Command Phase dial assignment flow |
| `DebugController` | Node | `src/scenes/game_board/debug_controller.gd` | Debug overlay, HUD, zone tracking, scenario saving |
| `ManeuverToolController` | Node | `src/scenes/game_board/maneuver_tool_controller.gd` | Maneuver tool selection, creation, and dismissal |
| `RangeToolController` | Node | `src/scenes/game_board/range_tool_controller.gd` | Range overlay selection, creation, and dismissal |
| `SquadronPhaseController` | Node | `src/scenes/game_board/squadron_phase_controller.gd` | Squadron Phase activation flow: movement, attack delegation, engagement |
| `ShipToken` | Node2D | `src/scenes/ship_token.gd` | Ship base rendering, command dial icon, labels |
| `ShipCardPanel` | Control | `src/ui/ship_card_panel.gd` | Ship card display, defense tokens, command tokens |
| `CommandDialPicker` | Control | `src/ui/command_dial_picker.gd` | Centred modal for choosing command dials |
| `CommandDialOrderModal` | Control | `src/ui/command_dial_order_modal.gd` | Multi-ship dial assignment order modal |
| `ActivationModal` | Control | `src/ui/activation_modal.gd` | Centred panel for activation steps (5 sub-steps, two-phase Execute/Commit button, End Activation button, collision label) |
| `DisplacementModal` | Control | `src/ui/displacement_modal.gd` | Squadron displacement checklist modal — check/uncheck, commit placement |
| `RepairPanel` | Control | `src/ui/repair_panel.gd` | Repair command UI: recover shields / discard damage cards |
| `TargetingListModal` | Control | `src/ui/targeting_list_modal.gd` | Targeting list showing valid ship/squadron targets for attack |
| `AttackSimPanel` | Control | `src/ui/attack_sim_panel.gd` | Free-form attack simulation panel |
| `DefenseTokenDisplay` | Control | `src/ui/defense_token_display.gd` | Reusable defense token row widget |
| `SquadronActivationModal` | Control | `src/ui/squadron_activation_modal.gd` | Squadron phase activation modal: move + attack flow, rogue/command dual mode |
| `SquadronMoveOverlay` | Control | `src/ui/squadron_move_overlay.gd` | Visual overlay for squadron movement range bands |
| `ShowSquadronModalButton` | Control | `src/ui/show_squadron_modal_button.gd` | Button to open squadron activation modal during squadron phase |
| `ShowActivationButton` | Control | `src/ui/show_activation_button.gd` | "Show Activation Sequence" button shown after dial reveal |
| `ExecuteManeuverButton` | Control | `src/ui/execute_maneuver_button.gd` | Two-phase Execute/Commit maneuver button |
| `EndActivationButton` | Control | `src/ui/end_activation_button.gd` | "End Activation ►" button to deliberately end ship activation |
| `ManeuverToolScene` | Node2D | `src/scenes/tools/maneuver_tool_scene.gd` | Visual maneuver tool: segments, joints, speed buttons, ghost |
| `ActionToolbar` | HBoxContainer | `src/ui/action_toolbar.gd` | Lower-right toolbar: tooltip toggle, M/R/T/A tool buttons, audio controls (⏸/▶ ⏭ −/+) |
| `PhaseIndicator` | Control | `src/ui/phase_indicator.gd` | Current phase and round display |
| `TooltipPanel` | PanelContainer | `src/ui/tooltip_panel.gd` | Hover/programmatic tooltip popup |
| `HandoffOverlay` | Control | `src/ui/handoff_overlay.gd` | Player turn handoff overlay |
| `YourTurnBanner` | Control | `src/ui/your_turn_banner.gd` | Animated "Your Turn" banner at start of player's activation |
| `VictoryScreen` | Control | `src/ui/victory_screen.gd` | End-of-game victory/defeat screen with scoring breakdown |
| `DebugHelpPanel` | Control | `src/ui/debug_help_panel.gd` | Debug keybinding help overlay |

### Save / Load Subsystem (Phase J)

| Component | Extends | File | Purpose |
|-----------|---------|------|---------|
| `SaveGameManager` | Node (autoload) | `src/autoload/save_game_manager.gd` | Save/load orchestration: per-mode checkpoints, named saves, HMAC sign/verify, dirty tracking, network-client refusal, network-host save broadcast |
| `SaveGameMetadata` | RefCounted | `src/core/state/save_game_metadata.gd` | Save header schema (`save_format_version`, `display_name`, `scenario_id`, `round`, `phase`, `game_mode`, `created_at`, `app_version`, `hmac`); `to_dict` / `from_dict` round-trip |
| `IntegritySigner` | RefCounted | `src/utils/integrity_signer.gd` | Shared HMAC sign/verify used by saves and replays |
| `GameMenuModal` | Control | `src/ui/save/game_menu_modal.gd` | In-game ESC menu (Resume / Save / Load / Quit) — mode-aware visibility (hot-seat · network-host · network-client); replaced the legacy quit-confirmation modal in Phase J3 |
| `SaveGameDialog` | Control | `src/ui/save/save_game_dialog.gd` | Name + validate + overwrite-confirm + write to disk; broadcasts host save notification on network |
| `LoadGameDialog` | Control | `src/ui/save/load_game_dialog.gd` | Two-section list (Hot-seat / Network) + per-mode "Resume Last Checkpoint" rows; context-aware (`main_menu` / `lobby` / `in_game`) gating; routes host network loads through `LobbyManager.host_load_save` for RPC broadcast |
| `SaveOnQuitDialog` | Control | `src/ui/save/save_on_quit_dialog.gd` | "Save first?" prompt shown when quitting with a dirty checkpoint |

### Data Layer

| Component | Extends | File | Purpose |
|-----------|---------|------|---------|
| `ShipData` | Resource | `src/models/ship_data.gd` | Ship card data loaded from JSON |
| `SquadronData` | Resource | `src/models/squadron_data.gd` | Squadron card data loaded from JSON |
| `UpgradeData` | Resource | `src/models/upgrade_data.gd` | Upgrade card data (placeholder for future use) |
| `TokenPlacement` | RefCounted | `src/models/token_placement.gd` | Scenario placement data |

### Utilities

| Component | Extends | File | Purpose |
|-----------|---------|------|---------|
| `AssetLoader` | RefCounted | `src/utils/asset_loader.gd` | JSON loading, card art lookup, data parsing |
| `GameLogger` | RefCounted | `src/utils/logger.gd` | Structured logging with file output |
| `ScenarioSaver` | RefCounted | `src/utils/scenario_saver.gd` | Debug position export to JSON |
