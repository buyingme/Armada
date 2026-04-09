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
| **Autoload Services** | Singletons (GameManager, EventBus, Constants, TooltipManager, SfxManager, MusicManager, DebugMode, SaveGameManager) | `src/autoload/` |
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
| `EffectContext` | RefCounted | `src/core/effects/effect_context.gd` | Mutable data bag passed through effect hook pipeline |
| `GameEffect` | RefCounted | `src/core/effects/game_effect.gd` | Base class for all rule-modifying effects (keywords, upgrades, damage cards) |
| `EffectRegistry` | RefCounted | `src/core/effects/effect_registry.gd` | Central registry: collects effects, resolves hook points in priority order |
| `EffectFactory` | RefCounted | `src/core/effects/effect_factory.gd` | Creates and registers squadron keyword effects at game start |
| `BomberEffect` | GameEffect | `src/core/effects/keywords/bomber_effect.gd` | Bomber keyword: crits count as damage vs ships |
| `EscortEffect` | GameEffect | `src/core/effects/keywords/escort_effect.gd` | Escort keyword: engaged squadrons must target Escort first |
| `SwarmEffect` | GameEffect | `src/core/effects/keywords/swarm_effect.gd` | Swarm keyword: reroll worst die when friendly also engaged |
| `EngagementResolver` | RefCounted | `src/core/engagement_resolver.gd` | Edge-to-edge distance-1 engagement checks, valid target filtering |
| `SquadronMover` | RefCounted | `src/core/squadron_mover.gd` | Distance band + overlap validation for squadron placement |
| `LineOfSightChecker` | RefCounted | `src/core/line_of_sight_checker.gd` | LOS edge-to-edge tracing, obstruction detection |
| `OverlapResolver` | RefCounted | `src/core/overlap_resolver.gd` | Ship–ship overlap (speed reduction loop, facedown damage) and ship–squadron overlap (displacement list, placement validation, snap-to-edge) |
| `RepairResolver` | RefCounted | `src/core/repair_resolver.gd` | Repair command: dial/token budget, recover shields / discard damage cards |
| `SquadronCommandResolver` | RefCounted | `src/core/squadron_command_resolver.gd` | Squadron command: dial/token activation budget, range check, finalize spend |
| `ScoringCalculator` | RefCounted | `src/core/scoring_calculator.gd` | End-of-game scoring: ship/squadron destruction points, objective tokens, margin-of-victory table |
| `DamageCardEffectFactory` | RefCounted | `src/core/damage_card_effect_factory.gd` | Factory for damage card effects — creates `GameEffect` instances for each critical card type |
| `ImmediateEffectResolver` | RefCounted | `src/core/immediate_effect_resolver.gd` | Resolves faceup damage card immediate effects (Structural Damage, Projector Misaligned, etc.) |
| `ActivationContext` | RefCounted | `src/core/activation_context.gd` | Shared activation state (current ship, activation state, overlap flag) injected into all controllers |

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
| `LearningScenarioSetup` | RefCounted | `src/core/learning_scenario_setup.gd` | Loads learning scenario JSON and spawns initial placement |

## 5.3 Level 2 — UI Detail

### Implemented UI/Scene Components

| Component | Extends | File | Purpose |
|-----------|---------|------|---------|
| `GameBoard` | Node2D | `src/scenes/game_board/game_board.gd` | Main play area, ship/token rendering, camera, activation backbone, delegates to child controllers |
| `UIPanelManager` | Node | `src/scenes/game_board/ui_panel_manager.gd` | Owns all UI panel creation, positioning, resizing, and isolated callbacks (card panels, overlays, modals, HUD) |
| `AttackExecutor` | Node | `src/scenes/game_board/attack_executor.gd` | Attack simulator (free-form) and attack execution (activation Step 4): targeting, LOS, dice, defense tokens, damage |
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
