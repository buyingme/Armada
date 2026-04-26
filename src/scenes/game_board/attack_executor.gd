## AttackExecutor
##
## Manages the attack execution flow from ship/squadron activation
## (Phases 6b/6c): dice rolling, defense tokens, damage resolution.
##
## Target selection (attacker, hull zone, target) is delegated to
## [TargetSelector], which emits [signal TargetSelector.target_locked]
## when a valid target is confirmed. AE connects to that signal and
## begins the dice sequence.
##
## Requirements: AE-*, AT-001–007.
## Rules Reference: "Attack", Steps 2–6, pp.2–3.
class_name AttackExecutor
extends Node

## Preloaded script reference for calling static functions without triggering
## STATIC_CALLED_ON_INSTANCE warnings (Constants is an autoload instance).
const ConstantsScript := preload("res://src/autoload/constants.gd")

## Hull-zone index → display name mapping.
const _ZONE_NAMES: Dictionary = {
	Constants.HullZone.FRONT: "FRONT",
	Constants.HullZone.LEFT: "LEFT",
	Constants.HullZone.RIGHT: "RIGHT",
	Constants.HullZone.REAR: "REAR",
}

## Emitted when the attack execution step is fully complete.
## GameBoard should advance the activation state and reopen the modal.
signal attack_exec_completed

## Emitted when the player cancels attack execution (Escape).
## GameBoard should reopen the activation modal without advancing.
signal attack_exec_cancelled

# ---------------------------------------------------------------------------
# External references (set via initialize)
# ---------------------------------------------------------------------------

## Camera node reference (for perspective rotation during defense step).
var _camera: BoardCamera = null

## Shared damage deck for the game.
var _damage_deck: DamageDeck = null

## Resolver for immediate faceup damage card effects (DM-005).
var _immediate_resolver: ImmediateEffectResolver = ImmediateEffectResolver.new()

## Handoff overlay reference for hot-seat player transitions (DM-011).
var _handoff_overlay: HandoffOverlay = null

## Choice modal for immediate damage card effects (DM-011).
var _opponent_choice_modal: OpponentChoiceModal = null

## Pending faceup card that needs a player choice before its effect resolves.
var _pending_immediate_card: DamageCard = null

## Pending ship instance for the deferred immediate effect.
var _pending_immediate_ship: ShipInstance = null

## Pending choice descriptor for the deferred immediate effect.
var _pending_immediate_choice: Dictionary = {}

## Logger instance.
var _log: GameLogger = GameLogger.new("AttackExecutor")

## Pure-computation resolver for armament, dice pools, CF detection,
## obstruction removal, damage calculation, and damage-card blocking.
var _dice_resolver: AttackDiceResolver = null

## Pure-computation resolver for defense token spending, token effects,
## canonical sorting, redirect checks, and faceup card determination.
var _defense_resolver: DefenseTokenResolver = DefenseTokenResolver.new()

## Pure-computation helper for damage resolution: shield absorption,
## hull tracking, destruction checks, damage summaries, and card dealing
## decisions.
var _damage_dealer: DamageDealer = DamageDealer.new()

## Shared mutable state for the current attack flow.
## Holds attacker/defender identity, dice, defense, and tracking fields.
## Defaults to a fresh instance (for tests); overwritten by [method initialize]
## with the shared state from [TargetSelector].
var _state: AttackState = AttackState.new()

## Authoritative attack-flow FSM (Phase I3).  Tracks the current attack
## step and writes it into [GameState.interaction_flow] so reconnecting
## clients can rebuild attack UI from a single state snapshot.
var _flow_fsm: AttackFlowFSM = AttackFlowFSM.new()

## Target selector — owns attacker/target selection, visual aids, and
## the AttackSimPanel. Created and wired in [method initialize].
var _target_selector: TargetSelector = null

# ---------------------------------------------------------------------------
# Null-safe accessors for TargetSelector sub-objects
# ---------------------------------------------------------------------------

## Returns the shared attack panel, or null if TargetSelector is absent.
func _get_panel() -> AttackSimPanel:
	if _target_selector:
		return _target_selector.get_panel()
	return null


## Returns the visual overlay, or null if TargetSelector is absent.
func _get_overlay() -> AttackSimOverlay:
	if _target_selector:
		return _target_selector.get_overlay()
	return null

# ---------------------------------------------------------------------------
# Phase 6c: Accuracy, Defense Tokens, Damage Resolution
# ---------------------------------------------------------------------------

## Reference to the game's [EffectRegistry] for hook resolution.
## Set via [method set_effect_registry] after game initialisation.
var _effect_registry: EffectRegistry = null

# ===========================================================================
# Public Interface
# ===========================================================================

## Initializes the executor with references to board infrastructure.
## [param target_selector] — TargetSelector (already added as child by GB).
## [param camera] — BoardCamera reference for rotation during defense.
func initialize(target_selector: TargetSelector,
		camera: BoardCamera) -> void:
	_target_selector = target_selector
	_state = target_selector.get_state()
	_camera = camera
	_dice_resolver = AttackDiceResolver.new()
	# Connect target_locked so the dice sequence starts automatically.
	if not _target_selector.target_locked.is_connected(
			_on_target_locked):
		_target_selector.target_locked.connect(_on_target_locked)
	# Network: receive dice results from broadcast.  G4.6.5.
	if not EventBus.network_dice_result.is_connected(
			_on_network_dice_result):
		EventBus.network_dice_result.connect(_on_network_dice_result)

## Sets the [EffectRegistry] for hook resolution during attacks.
func set_effect_registry(registry: EffectRegistry) -> void:
	_effect_registry = registry

## Sets the shared damage deck reference.
func set_damage_deck(deck: DamageDeck) -> void:
	_damage_deck = deck

## Sets the handoff overlay reference for hot-seat immediate-effect choices.
func set_handoff_overlay(overlay: HandoffOverlay) -> void:
	_handoff_overlay = overlay

## Called by TargetSelector when a valid target is confirmed in exec mode.
## Begins the dice sequence.
func _on_target_locked(range_band: String, _dice_text: String) -> void:
	_attack_exec_begin_sequence(range_band)

## Starts the attack execution flow from the activation modal.
## Requirements: AE-FLOW-001, AE-ACT-001.
func start_ship_attack(ship_token: ShipToken) -> void:
	_log.info("Attack step entered — starting attack execution flow.")
	if ship_token == null:
		_log.info("Cannot start attack — no ship token.")
		return
	# Dismiss any other active tool first.
	_target_selector.dismiss_other_tools_requested.emit()
	_target_selector.dismiss()
	_init_ship_attack_state(ship_token)
	_flow_fsm.begin(GameManager.current_game_state,
			_get_attacker_player(), -1, {})
	_target_selector.enter_attacker_selection(true, _get_ship_name())
	var panel: AttackSimPanel = _get_panel()
	# Connect Done button if not already connected.
	if panel and not panel.attack_done_pressed.is_connected(
			_finish_attack_execution):
		panel.attack_done_pressed.connect(_finish_attack_execution)
	_connect_attack_panel_signals()
	if panel:
		panel.show_skip_attack_button()
	# Auto-skip if no valid targets exist from any hull zone.
	## Rules Reference: "Attack", p.2 — a ship is not required to attack.
	if not _attack_exec_has_any_valid_target():
		_log.info("No valid targets from any hull zone — auto-skipping.")
		GameManager.submit_skip_attack(
				_get_attacker_player(), "no_targets")
		if panel:
			panel.hide_skip_attack_button()
		_finish_attack_execution()
		return
	_target_selector.show_ship_range_overlay(_state.exec_ship_token)
	_log.info("Attack execution: range overlay shown, awaiting hull zone.")

## Initialises attack execution state for a ship attacker.
func _init_ship_attack_state(ship_token: ShipToken) -> void:
	_state.exec_mode = true
	_state.exec_ship_token = ship_token
	_state.fired_zones.clear()
	_state.current_attack = 0
	_state.dice_results.clear()
	_state.dice_pool.clear()
	_state.range_band = ""
	_state.cf_dial_used = false
	_state.cf_token_used = false
	_state.attacked_squads.clear()

## Starts the squadron attack execution flow from the Squadron Activation
## Modal. Pre-selects the squadron as attacker; enters target selection.
## Requirements: SQA-ATK-001, SQA-ATK-002.
func start_squadron_attack(squadron_token: SquadronToken) -> void:
	_log.info("Squadron attack step entered.")
	if squadron_token == null:
		_log.info("Cannot start squadron attack — no token.")
		return
	_target_selector.dismiss_other_tools_requested.emit()
	_target_selector.dismiss()
	_init_squadron_attack_state(squadron_token)
	_flow_fsm.begin(GameManager.current_game_state,
			_get_attacker_player(), -1, {})
	_target_selector.enter_squadron_target_selection(squadron_token)
	var panel: AttackSimPanel = _get_panel()
	if panel and not panel.attack_done_pressed.is_connected(
			_finish_attack_execution):
		panel.attack_done_pressed.connect(_finish_attack_execution)
	_connect_attack_panel_signals()
	if panel:
		panel.show_initial_squadron_exec(_state.attacker_name)
		panel.show_skip_attack_button()
	_log.info("Squadron attack: target selection active for %s."
			% _state.attacker_name)

## Initialises attack execution state for a squadron attacker.
func _init_squadron_attack_state(
		squadron_token: SquadronToken) -> void:
	_state.exec_mode = true
	_state.squad_exec_mode = true
	_state.exec_squad_token = squadron_token
	_state.exec_ship_token = null
	_state.fired_zones.clear()
	_state.current_attack = 0
	_state.dice_results.clear()
	_state.dice_pool.clear()
	_state.range_band = ""
	_state.cf_dial_used = false
	_state.cf_token_used = false
	_state.attacked_squads.clear()
	var inst: SquadronInstance = squadron_token.get_squadron_instance()
	var squad_name: String = "Squadron"
	if inst and inst.squadron_data:
		squad_name = inst.squadron_data.squadron_name
	_state.attacker_ship = null
	_state.attacker_zone = -1
	_state.attacker_squadron = squadron_token
	_state.attacker_name = squad_name
	_state.attacker_zone_name = ""

## Dismisses the attack executor, delegating visual cleanup to TargetSelector.
## Requirements: AS-ACT-003, AS-PNL-003, AS-TGT-022.
func dismiss() -> void:
	_target_selector.dismiss()
	_log.info("Attack executor dismissed.")

## Whether the executor has any active UI.
func is_active() -> bool:
	return _target_selector.is_active()

## Whether in attacker-selection mode.
func is_selecting() -> bool:
	return _target_selector.is_selecting()

## Whether in target-selection mode.
func is_target_selecting() -> bool:
	return _target_selector.is_target_selecting()

## Whether in attack execution mode (from activation modal).
func is_in_exec_mode() -> bool:
	return _state.exec_mode

## Returns true if the given ship has at least one valid attack target
## from any of its four hull zones. Unlike [method _attack_exec_has_any_valid_target]
## this does NOT exclude fired zones — it is used before the attack step
## begins to decide whether the modal should auto-skip the Attack step.
## Rules Reference: "Attack", p.2 — a ship is not required to attack.
func has_any_attack_target(ship_token: ShipToken) -> bool:
	return _target_selector.has_any_attack_target(ship_token)

# ===========================================================================
# Internal Helpers
# ===========================================================================

## Resets all attack execution state variables.
func _reset_exec_state() -> void:
	_state.clear_all()

## Resets deferred damage card state.
func _reset_deferred_damage_state() -> void:
	_state.reset_deferred_damage()

## Completes the attack execution step. Cleans up and signals GameBoard.
## Requirements: AE-FLOW-003, AE-CONF-002.
func _finish_attack_execution() -> void:
	_log.info("Attack execution done — completing attack step.")
	dismiss()
	_reset_exec_state()
	# Phase I3: end the attack flow and clear interaction_flow.
	_flow_fsm.end(GameManager.current_game_state)
	_flow_fsm.reset()
	attack_exec_completed.emit()

## Builds a [CombatParticipants] from the current attacker/target state.
func _build_current_participants() -> CombatParticipants:
	return _target_selector.build_current_participants()

## Returns the damage total for the current dice pool, using the correct
## formula for the combatant types. Critical icons only count as damage when
## both attacker and defender are ships; if either combatant is a squadron
## the no-critical formula is used.
## After the base calculation, the ATTACK_CALC_DAMAGE hook is resolved
## so keyword effects (e.g. Bomber) can adjust the total.
## Rules Reference: "Dice Icons", p.5 — "Critical: If the attacker and
## defender are ships, this icon adds one damage to the damage total."
func _calc_attack_damage(results: Array[Dictionary]) -> int:
	var parts: CombatParticipants = _build_current_participants()
	return _dice_resolver.calc_damage(results, parts, _effect_registry)

## Returns the ship display name for the exec ship.
func _get_ship_name() -> String:
	if _state.exec_ship_token and _state.exec_ship_token.get_ship_data():
		return _state.exec_ship_token.get_ship_data().ship_name
	return ""

# ===========================================================================
# Phase 6b-2 — Attack Sequence Orchestration
# ===========================================================================

## Connects the Phase 6b-2 panel signals to executor handlers.
func _connect_attack_panel_signals() -> void:
	if _get_panel() == null:
		return
	_connect_attack_sequence_signals()
	_connect_defense_phase_signals()

## Connects Phase 6b-2 attack sequence signals.
func _connect_attack_sequence_signals() -> void:
	var p: AttackSimPanel = _get_panel()
	if not p.cf_dial_colour_selected.is_connected(
			_on_attack_cf_dial_colour):
		p.cf_dial_colour_selected.connect(_on_attack_cf_dial_colour)
	if not p.cf_dial_skipped.is_connected(_on_attack_cf_dial_skipped):
		p.cf_dial_skipped.connect(_on_attack_cf_dial_skipped)
	if not p.obstruction_die_selected.is_connected(
			_on_obstruction_die_selected):
		p.obstruction_die_selected.connect(_on_obstruction_die_selected)
	if not p.roll_dice_pressed.is_connected(_on_attack_roll_dice):
		p.roll_dice_pressed.connect(_on_attack_roll_dice)
	if not p.cf_token_reroll_requested.is_connected(
			_on_attack_cf_token_reroll):
		p.cf_token_reroll_requested.connect(_on_attack_cf_token_reroll)
	if not p.cf_token_reroll_skipped.is_connected(
			_on_attack_cf_token_skipped):
		p.cf_token_reroll_skipped.connect(_on_attack_cf_token_skipped)
	if not p.confirm_pressed.is_connected(_on_attack_confirm):
		p.confirm_pressed.connect(_on_attack_confirm)
	if not p.skip_attack_pressed.is_connected(_on_attack_skip):
		p.skip_attack_pressed.connect(_on_attack_skip)

## Connects Phase 6c defense signals.
func _connect_defense_phase_signals() -> void:
	var p: AttackSimPanel = _get_panel()
	if not p.accuracy_confirmed.is_connected(
			_on_attack_accuracy_confirmed):
		p.accuracy_confirmed.connect(_on_attack_accuracy_confirmed)
	if not p.defense_token_selected.is_connected(
			_on_attack_defense_token_spent):
		p.defense_token_selected.connect(_on_attack_defense_token_spent)
	if not p.defense_tokens_done.is_connected(
			_on_attack_defense_done):
		p.defense_tokens_done.connect(_on_attack_defense_done)
	if not p.redirect_zone_selected.is_connected(
			_on_attack_redirect_zone_selected):
		p.redirect_zone_selected.connect(
				_on_attack_redirect_zone_selected)
	if not p.evade_die_confirmed.is_connected(
			_on_evade_die_selected):
		p.evade_die_confirmed.connect(_on_evade_die_selected)
	if not p.redirect_done_pressed.is_connected(
			_on_redirect_done_early):
		p.redirect_done_pressed.connect(_on_redirect_done_early)

## Begins the Phase 6b-2 attack sequence after target and range are known.
## Checks for a CF dial and starts the appropriate step.
## For squadron attackers, CF dials are not available — skip straight to roll.
## Requirements: AE-CF-001, AE-CF-002, SQA-ATK-001.
## Rules Reference: "Concentrate Fire", p.3 — "While attacking, the ship
## may add 1 die to its attack pool of a color that is already in its
## attack pool."
func _attack_exec_begin_sequence(range_band: String) -> void:
	if _get_panel() == null:
		return
	if _state.exec_ship_token == null and _state.exec_squad_token == null:
		return
	# --- ATTACK_VALIDATE_TARGET hook (Coolant Discharge, Depowered
	# Armament, Disengaged Fire Control) — reject attack if cancelled.
	# Rules Reference: RRG "Damage Cards", p.4; ET-001.
	if _is_attack_blocked_by_damage(range_band):
		return
	_state.dice_pool = _compute_attack_pool_dict(range_band)
	_apply_gather_dice_hook()
	_get_panel().show_skip_attack_button()
	# Empty pool guard: if no dice remain after gather-dice hooks, the
	# attack cannot be declared.
	# Rules Reference: "Attack", Step 1, p.2 — "The attacker must be
	# able to add at least one die to the attack pool."
	var _begin_total: int = DicePool.get_total_count(_state.dice_pool)
	if _begin_total <= 0:
		_log.info("No dice in pool — cannot declare attack.")
		# During Step 6 squadron loop: auto-skip this target and re-check.
		# Rules Reference: "Attack", Step 1, p.2 — attacker must add at
		# least one die.  A squadron that yields 0 dice at this range is
		# not a legal target; skip it and look for the next one.
		if _state.attacked_squads.size() > 0 \
				and _state.defender_squadron:
			_auto_skip_zero_dice_squadron()
			return
		if _get_panel():
			_get_panel().show_empty_pool_auto_skip()
		return
	# Obstruction: attacker must remove 1 die before rolling.
	# Rules Reference: "Obstructed", RRG v1.5.0, p.10.
	# Requirements: AE-OBS-001, AE-OBS-002.
	if _state.obstructed:
		_handle_obstruction_step()
		return
	# Check CF dial availability (ship attackers only).
	if _state.exec_ship_token and not _state.cf_dial_used \
			and _attack_exec_has_cf_dial():
		var available: Array[String] = _get_cf_dial_colours(
				_state.dice_pool)
		if available.size() > 0:
			_get_panel().show_cf_dial_section(available)
			_log.info("CF dial available — offering colours: %s." % [
					str(available)])
			return
	_attack_exec_show_roll_button()

## Applies the ATTACK_GATHER_DICE effect hook to the pool.
func _apply_gather_dice_hook() -> void:
	var parts: CombatParticipants = _build_current_participants()
	_state.dice_pool = _dice_resolver.apply_gather_hook(
			_state.dice_pool, _effect_registry, parts)

## Checks whether a persistent damage card effect blocks this attack.
## Builds an ATTACK_VALIDATE_TARGET context with range, obstruction,
## and attack count, then resolves the hook.
## Returns true (attack blocked) if any effect sets cancelled.
## Rules Reference: RRG "Damage Cards", p.4; "Coolant Discharge",
## "Depowered Armament", "Disengaged Fire Control".
func _is_attack_blocked_by_damage(range_band: String) -> bool:
	var parts: CombatParticipants = _build_current_participants()
	var blocked: bool = _dice_resolver.is_blocked_by_damage_at_range(
			_effect_registry, parts, _state.obstructed,
			_state.current_attack, range_band)
	if blocked:
		_log.info("Attack blocked by damage card effect.")
		if _get_panel():
			_get_panel().show_empty_pool_auto_skip()
		TooltipManager.show_text(
				"Attack blocked by damage card.", Vector2.INF, 2.0, true)
	return blocked

## Handles obstruction die removal: auto-remove, auto-skip, or prompt.
func _handle_obstruction_step() -> void:
	var removable: Array[String] = []
	for colour_key: String in _state.dice_pool:
		if int(_state.dice_pool[colour_key]) > 0:
			removable.append(colour_key)
	if removable.size() == 0:
		_log.info("Obstruction: pool empty — skipping attack.")
		_get_panel().show_obstruction_auto_skip()
		return
	if removable.size() == 1:
		_attack_exec_remove_obstruction_die(removable[0])
		return
	_state.obstruction_step = true
	_get_panel().show_obstruction_die_choice(removable)
	_log.info(
			"Obstruction: awaiting die removal choice from %s."
			% [str(removable)])

## Checks whether the activated ship has a revealed CF dial.
## Requirements: AE-CF-001.
func _attack_exec_has_cf_dial() -> bool:
	return _dice_resolver.has_cf_dial(_state.exec_ship_token)

## Returns which colour keys are available for CF dial extra die.
## Only colours already in the pool may be chosen.
## Requirements: AE-CF-003.
## Rules Reference: "Concentrate Fire", p.3.
func _get_cf_dial_colours(pool: Dictionary) -> Array[String]:
	return _dice_resolver.get_cf_dial_colours(pool)

## Computes the string-keyed dice pool for the current attacker/target.
## Same logic as _compute_attack_dice_text but returns the Dictionary.
func _compute_attack_pool_dict(range_band: String) -> Dictionary:
	var parts: CombatParticipants = _build_current_participants()
	return _dice_resolver.compute_pool_for_parts(parts, range_band)

## Resolves the attacker's armament dictionary for the current
## attacker/target pair.  Handles ship (battery / anti-squadron) and
## squadron (battery / anti-squadron) attackers.
## Rules Reference: "Attack", Step 2, p.2; "Squadron Attacks", RRG p.19.
func _resolve_attacker_armament() -> Dictionary:
	var parts: CombatParticipants = _build_current_participants()
	return _dice_resolver.resolve_armament(parts)

## Shows the Roll Dice button.
func _attack_exec_show_roll_button() -> void:
	if _get_panel():
		_get_panel().hide_cf_dial_section()
		_get_panel().hide_obstruction_section()
		_get_panel().show_roll_button()
	_log.info("Awaiting dice roll.")

## Removes 1 die of the given [param colour_key] from the pool due to
## obstruction, updates the dice count display, and continues the sequence.
## Requirements: AE-OBS-001, AE-OBS-002.
## Rules Reference: "Obstructed", RRG v1.5.0, p.10.
func _attack_exec_remove_obstruction_die(colour_key: String) -> void:
	_state.dice_pool = _dice_resolver.remove_obstruction_die(
			_state.dice_pool, colour_key)
	_log.info("Obstruction: removed 1 %s die. Pool: %s." % [
			colour_key, DicePool.format_pool(_state.dice_pool)])
	# Update dice count display.
	if _get_panel():
		var dice_text: String = DicePool.format_pool(_state.dice_pool)
		_get_panel().show_dice_count(dice_text)
		_get_panel().hide_obstruction_section()
	# Check if pool is now empty — auto-skip.
	var total: int = DicePool.get_total_count(_state.dice_pool)
	if total <= 0:
		_log.info("Obstruction: pool empty after removal — skipping attack.")
		if _get_panel():
			_get_panel().show_obstruction_auto_skip()
		return
	# Continue to CF dial or Roll.
	_attack_exec_continue_after_obstruction()

## Called when the attacker selects a die colour to remove for obstruction.
## Requirements: AE-OBS-002.
func _on_obstruction_die_selected(colour_key: String) -> void:
	if not _state.obstruction_step:
		return
	_state.obstruction_step = false
	_attack_exec_remove_obstruction_die(colour_key)

## Continues the attack sequence after the obstruction die has been removed.
## Checks CF dial availability and proceeds to roll if none.
func _attack_exec_continue_after_obstruction() -> void:
	if _state.exec_ship_token and not _state.cf_dial_used \
			and _attack_exec_has_cf_dial():
		var available: Array[String] = _get_cf_dial_colours(
				_state.dice_pool)
		if available.size() > 0:
			if _get_panel():
				_get_panel().show_cf_dial_section(available)
			_log.info("CF dial available — offering colours: %s." % [
					str(available)])
			return
	_attack_exec_show_roll_button()

## Called when the player selects a colour for the CF dial extra die.
## Requirements: AE-CF-003, AE-CF-004.
func _on_attack_cf_dial_colour(colour_key: String) -> void:
	_log.info("CF dial: adding 1 %s die." % colour_key)
	# Add die to the pool.
	var current: int = int(_state.dice_pool.get(colour_key, 0))
	_state.dice_pool[colour_key] = current + 1
	# Spend the dial via command system.
	var inst: ShipInstance = _state.exec_ship_token.get_ship_instance()
	if inst and inst.command_dial_stack:
		GameManager.submit_spend_dial(inst)
	_state.cf_dial_used = true
	# Update dice count display.
	if _get_panel():
		var dice_text: String = DicePool.format_pool(_state.dice_pool)
		_get_panel().show_dice_count(dice_text)
	# Proceed to roll.
	_attack_exec_show_roll_button()

## Called when the player skips the CF dial.
## Requirements: AE-CF-005.
func _on_attack_cf_dial_skipped() -> void:
	_log.info("CF dial skipped.")
	_attack_exec_show_roll_button()

## Called when the player presses "Roll Dice".
## Requirements: AE-DICE-001, AE-DICE-003, SFX-004, SFX-005, SFX-006.
func _on_attack_roll_dice() -> void:
	_flow_fsm.advance(GameManager.current_game_state,
			AttackFlowFSM.Step.ROLL)
	_log.info("Rolling dice: %s." % DicePool.format_pool(
			_state.dice_pool))
	# Play dice-roll SFX based on attacker type and faction.
	_play_dice_roll_sfx()
	# Submit dice roll via command for deterministic replay.
	var atk_player: int = _get_attacker_player()
	var roll_result: Dictionary = GameManager.submit_roll_dice(
			atk_player, _state.dice_pool)
	# Network client: result arrives asynchronously via broadcast.
	# Wait for _apply_dice_roll_result() to be called from the
	# network command handler.
	if roll_result.is_empty():
		return
	_apply_dice_roll_result(roll_result)


## Applies a dice roll result to the attack state and updates the UI.
## Called inline for host/hot-seat or from the network broadcast handler.
func _apply_dice_roll_result(roll_result: Dictionary) -> void:
	_flow_fsm.advance(GameManager.current_game_state,
			AttackFlowFSM.Step.MODIFY)
	var raw: Array = roll_result.get("dice_results", [])
	_state.dice_results.clear()
	for entry: Variant in raw:
		if entry is Dictionary:
			_state.dice_results.append(entry as Dictionary)
	# Show results.
	if _get_panel():
		_get_panel().hide_roll_button()
		_get_panel().show_dice_results(_state.dice_results)
	# Log results.
	var damage: int = _calc_attack_damage(_state.dice_results)
	_log.info("Dice rolled: %d dice, %d damage." % [
			_state.dice_results.size(), damage])
	# Check CF token for reroll.
	if _attack_exec_has_cf_token():
		if _get_panel():
			_get_panel().show_cf_token_section()
		_log.info("CF token available — offering reroll.")
		return
	# No token — show confirm.
	_attack_exec_show_confirm()


## Network callback: receives dice results from server broadcast.
## G4.6.5 — async dice resolution for network clients.
func _on_network_dice_result(result: Dictionary) -> void:
	if _state == null or not _state.dice_results.is_empty():
		return # Already have results or no active attack.
	_apply_dice_roll_result(result)


## Plays the appropriate SFX for a dice roll based on whether the attacker
## is a ship (turbolasers) or squadron (rhythmic burst, faction-dependent).
## Requirements: SFX-004, SFX-005, SFX-006.
func _play_dice_roll_sfx() -> void:
	if _state.squad_exec_mode and _state.exec_squad_token:
		# Squadron attack — rhythmic burst.
		var inst: SquadronInstance = (
				_state.exec_squad_token.get_squadron_instance())
		if inst and inst.squadron_data:
			var faction: Constants.Faction = inst.squadron_data.faction
			match faction:
				Constants.Faction.GALACTIC_EMPIRE:
					SfxManager.play_rhythmic(
							"tie_shooting",
							"imperial_squadron_rhythm_ms")
				_:
					SfxManager.play_rhythmic(
							"x_wing_shooting",
							"rebel_squadron_rhythm_ms")
		else:
			SfxManager.play_sfx("turbolasers")
	else:
		# Capital ship attack — turbolaser salvo.
		SfxManager.play_sfx("turbolasers")

## Checks whether the activated ship has a CF command token.
## Requirements: AE-CF-010.
func _attack_exec_has_cf_token() -> bool:
	return _dice_resolver.has_cf_token(_state.exec_ship_token)

## Called when the player selects a die and confirms reroll (CF token).
## Requirements: AE-CF-011, AE-CF-012, AE-CF-014.
func _on_attack_cf_token_reroll(die_index: int) -> void:
	if die_index < 0 or die_index >= _state.dice_results.size():
		return
	var old_result: Dictionary = _state.dice_results[die_index]
	var color: Constants.DiceColor = (
			old_result["color"] as Constants.DiceColor)
	# Reroll the die.
	var new_face: Constants.DiceFace = Dice.roll_die(color)
	var new_result: Dictionary = {"color": color, "face": new_face}
	_state.dice_results[die_index] = new_result
	_log.info("CF token: rerolled die %d (%s) → %s." % [
			die_index, str(old_result["face"]), str(new_face)])
	# Spend the token via command system.
	var inst: ShipInstance = _state.exec_ship_token.get_ship_instance()
	if inst and inst.command_tokens:
		GameManager.submit_spend_token(inst, int(Constants.CommandType.CONCENTRATE_FIRE))
	# Update display.
	if _get_panel():
		_get_panel().update_die_result(die_index, new_result)
		_get_panel().hide_cf_token_section()
	# Show confirm.
	_attack_exec_show_confirm()

## Called when the player skips the CF token reroll.
## Requirements: AE-CF-013.
func _on_attack_cf_token_skipped() -> void:
	_log.info("CF token reroll skipped.")
	if _get_panel():
		_get_panel().hide_cf_token_section()
	_attack_exec_show_confirm()

## Shows the Confirm button after dice are finalised.
## Requirements: AE-CONF-001.
func _attack_exec_show_confirm() -> void:
	if _get_panel():
		_get_panel().show_confirm_button()
	var damage: int = _calc_attack_damage(_state.dice_results)
	_log.info("Final dice: %d damage. Awaiting confirm." % damage)

## Called when the player presses "Confirm" to accept the dice results.
## Starts the accuracy spending step (Step 3), then defense (Step 4),
## then damage resolution (Step 5).
## Requirements: AE-CONF-002, AE-ACC-001, AE-DEF-001, AE-DMG-001.
## Rules Reference: "Attack", Steps 3–5.
func _on_attack_confirm() -> void:
	var damage: int = _calc_attack_damage(_state.dice_results)
	_log.info(
			"Attack confirmed: %d damage. Starting Step 3 (accuracy)."
			% damage)
	if _get_panel():
		_get_panel().hide_confirm_button()
	# Reset Phase 6c state for this attack.
	_state.locked_tokens.clear()
	_state.spent_tokens.clear()
	_state.defense_commit_queue.clear()
	_state.modified_damage = damage
	_state.scatter_used = false
	_state.redirect_remaining = 0
	_state.redirect_zone = -1
	_state.contain_used = false
	_state.brace_used = false
	_state.redirect_step = false
	_state.evade_step = false
	# Zero damage — skip accuracy and defense entirely since there is
	# nothing to mitigate.  Go straight to damage resolution which will
	# show "No damage dealt." and advance to the next attack.
	if damage == 0:
		_log.info("No damage in roll — skipping accuracy & defense.")
		_state.accuracy_step = false
		_state.defense_step = false
		_attack_exec_resolve_damage()
		return
	_attack_exec_start_accuracy()

# ===========================================================================
# Phase 6c-1 — Accuracy Spending (Step 3)
# ===========================================================================

## Starts the accuracy spending step.
## If the defender is a ship and the attacker rolled accuracy icons,
## show the accuracy UI. Otherwise, skip to defense tokens.
## Requirements: AE-ACC-001–008.
## Rules Reference: "Accuracy", p.2 — "The attacker can spend one or more
## of his accuracy icons to choose the same number of the defender's
## defense tokens. The chosen tokens cannot be spent during this attack."
func _attack_exec_start_accuracy() -> void:
	_state.accuracy_step = true
	var acc_count: int = _resolve_accuracy_count()
	# Only ships have defense tokens; squadrons skip accuracy step.
	if _state.defender_ship == null or acc_count == 0:
		_log.info("No accuracy icons or squadron defender — skipping "
				+"accuracy step.")
		_state.accuracy_step = false
		_attack_exec_start_defense()
		return
	var def_inst: ShipInstance = _state.defender_ship.get_ship_instance()
	if def_inst == null:
		_state.accuracy_step = false
		_attack_exec_start_defense()
		return
	var lockable: int = _count_lockable_tokens(def_inst)
	if lockable == 0:
		_log.info("Defender has no lockable tokens — skipping accuracy.")
		_state.accuracy_step = false
		_attack_exec_start_defense()
		return
	_log.info("Accuracy step: %d icons, %d lockable tokens." % [
			acc_count, lockable])
	if _get_panel():
		_get_panel().show_accuracy_section(
				def_inst.defense_tokens, acc_count)
		_get_panel().hide_confirm_button()

## Counts accuracy icons, applying the ATTACK_SPEND_ACCURACY hook.
func _resolve_accuracy_count() -> int:
	var acc_count: int = Dice.count_accuracy(_state.dice_results)
	if acc_count > 0 and _effect_registry:
		var acc_ctx: EffectContext = EffectContext.new()
		if _state.attacker_ship is ShipToken:
			acc_ctx.attacker = (
					_state.attacker_ship as ShipToken).get_ship_instance()
		acc_ctx = _effect_registry.resolve_hook(
				&"ATTACK_SPEND_ACCURACY", acc_ctx)
		if acc_ctx.cancelled:
			_log.info("Accuracy spending blocked by damage card effect.")
			return 0
	return acc_count

## Counts non-discarded defense tokens on a ship instance.
func _count_lockable_tokens(def_inst: ShipInstance) -> int:
	return _defense_resolver.count_lockable_tokens(def_inst)

## Called when the player confirms accuracy spending.
## Stores the locked token indices and proceeds to defense step.
## Requirements: AE-ACC-006.
func _on_attack_accuracy_confirmed() -> void:
	if _get_panel():
		_state.locked_tokens = (
				_get_panel().get_accuracy_locked_indices())
		_get_panel().hide_accuracy_section()
	_state.accuracy_step = false
	_log.info("Accuracy confirmed: locked tokens %s." % [
			str(_state.locked_tokens)])
	_attack_exec_start_defense()

# ===========================================================================
# Phase 6c-2 — Defense Token Spending (Step 4)
# ===========================================================================

## Starts the defense token spending step.
## If the defender is a ship with spendable tokens, show the defense UI.
## Otherwise, skip to damage resolution.
## Requirements: AE-DEF-001–016.
## Rules Reference: "Spend Defense Tokens", p.5 — "The defender can spend
## one or more of his defense tokens."
func _attack_exec_start_defense() -> void:
	_state.defense_step = true
	_state.spent_tokens.clear()
	_state.defense_commit_queue.clear()
	if _state.defender_ship == null:
		_state.defense_step = false
		_attack_exec_resolve_damage()
		return
	var def_inst: ShipInstance = _state.defender_ship.get_ship_instance()
	if def_inst == null:
		_state.defense_step = false
		_attack_exec_resolve_damage()
		return
	if not _can_defender_spend_tokens(def_inst):
		_state.defense_step = false
		_attack_exec_resolve_damage()
		return
	# Phase I3: record defender so FSM knows who controls DEFENSE_TOKENS.
	_flow_fsm.defender_player = def_inst.owner_player
	_flow_fsm.advance(GameManager.current_game_state,
			AttackFlowFSM.Step.DEFENSE_TOKENS)
	# Rotate camera to the defender's perspective (AE-DEF-011).
	if _camera and PlayMode.is_hot_seat():
		_camera.rotate_to_player(def_inst.owner_player)
	_log.info("Defense step: %d spendable tokens, %d damage." % [
			_count_spendable_defense_tokens(def_inst),
			_state.modified_damage])
	if _get_panel():
		_get_panel().show_defense_section(
				def_inst.defense_tokens,
				_state.locked_tokens,
				_state.modified_damage,
				def_inst.current_speed)

## Returns true if the defender has spendable tokens and speed > 0.
func _can_defender_spend_tokens(def_inst: ShipInstance) -> bool:
	var result: bool = _defense_resolver.can_spend_tokens(
			def_inst, _state.locked_tokens,
			_effect_registry, _state.defender_zone)
	if not result:
		if def_inst.current_speed == 0:
			_log.info("Defender speed 0 — cannot spend defense tokens.")
		else:
			_log.info("No spendable defense tokens — skipping defense step.")
	return result

## Returns the number of spendable (non-discarded, non-locked, not
## blocked by persistent effects) tokens.
## Rules Reference: "Defense Tokens", p.5; "Faulty Countermeasures".
func _count_spendable_defense_tokens(inst: ShipInstance) -> int:
	return _defense_resolver.count_spendable_tokens(
			inst, _state.locked_tokens,
			_effect_registry, _state.defender_zone)

## Called when the player spends a defense token.
## [param token_index] — index in the defender's defense_tokens array.
## [param spend_method] — "exhaust" or "discard".
## Requirements: AE-DEF-001–016.
## Rules Reference: "Defense Tokens", p.5 — each token type at most once.
func _on_attack_defense_token_spent(token_index: int,
		spend_method: String) -> void:
	if _state.defender_ship == null:
		return
	var def_inst: ShipInstance = _state.defender_ship.get_ship_instance()
	if def_inst == null:
		return
	if token_index < 0 or token_index >= def_inst.defense_tokens.size():
		return
	var token: Dictionary = def_inst.defense_tokens[token_index]
	var token_type: Constants.DefenseToken = (
			token["type"] as Constants.DefenseToken)
	if not _is_defense_token_spendable(token_index, token):
		return
	var actual_method: String = _resolve_spend_method(spend_method, token)
	# Route through command system for replay determinism.
	GameManager.submit_spend_defense_token(
			def_inst, token_index, actual_method)
	_state.spent_tokens[token_type] = actual_method
	EventBus.ship_defense_token_changed.emit(def_inst)
	EventBus.defense_token_spent.emit(
			_state.defender_ship, token_type)
	_log.info("Defense token spent: %s (%s)." % [
			Constants.DEFENSE_TOKEN_NAMES.get(token_type, "?"),
			actual_method])
	_apply_defense_token_effect(token_type, def_inst)

## Returns true if the token at the given index can be spent.
## Checks discard state, one-per-type limit, accuracy locks, and
## persistent damage card effects (DEFENSE_VALIDATE_TOKEN hook).
## Rules Reference: "Defense Tokens", p.5; "Faulty Countermeasures".
func _is_defense_token_spendable(token_index: int,
		token: Dictionary) -> bool:
	var result: bool = _defense_resolver.is_token_spendable(
			token_index, token, _state.spent_tokens,
			_state.locked_tokens, _get_defender_instance(),
			_effect_registry, _state.defender_zone)
	if not result:
		_log.info("Token %d not spendable — ignoring." % token_index)
	return result

## Resolves the actual spend method: exhausted tokens must be discarded.
func _resolve_spend_method(spend_method: String,
		token: Dictionary) -> String:
	return _defense_resolver.resolve_spend_method(spend_method, token)

## Returns the current defender's ShipInstance, or null.
func _get_defender_instance() -> ShipInstance:
	if _state.defender_ship == null:
		return null
	return _state.defender_ship.get_ship_instance()


## Returns the attacker's owner_player index.
## Works for both ship and squadron attack modes.
func _get_attacker_player() -> int:
	if _state.squad_exec_mode and _state.exec_squad_token:
		var sq: SquadronInstance = \
				_state.exec_squad_token.get_squadron_instance()
		if sq:
			return sq.owner_player
	if _state.exec_ship_token:
		var si: ShipInstance = \
				_state.exec_ship_token.get_ship_instance()
		if si:
			return si.owner_player
	return 0

## Returns true if a persistent damage card effect blocks spending this
## token.  Resolves the DEFENSE_VALIDATE_TOKEN hook and checks the
## context's cancelled flag.
## Rules Reference: "Faulty Countermeasures"; "Capacitor Failure".
func _is_token_blocked_by_effect(inst: ShipInstance,
		token: Dictionary) -> bool:
	return _defense_resolver.is_token_blocked_by_effect(
			inst, token, _effect_registry, _state.defender_zone)

## Applies the effect of a defense token to the current attack.
## Requirements: AE-DEF-006–016.
## Rules Reference: "Defense Tokens", p.5; individual token entries.
func _apply_defense_token_effect(token_type: Constants.DefenseToken,
		def_inst: ShipInstance) -> void:
	match token_type:
		Constants.DefenseToken.SCATTER:
			_apply_scatter_effect()
		Constants.DefenseToken.EVADE:
			_attack_exec_start_evade()
			return # Evade step handles button disable
		Constants.DefenseToken.BRACE:
			_apply_brace_effect()
		Constants.DefenseToken.REDIRECT:
			_attack_exec_start_redirect(def_inst)
			return # Redirect step handles button disable
		Constants.DefenseToken.CONTAIN:
			_state.contain_used = true
			_log.info("Contain: standard critical effect prevented.")
		_:
			_log.info("Unhandled defense token type: %s" \
					% str(token_type))
	if _get_panel():
		_get_panel().disable_defense_token_button(
				_get_token_button_index_for_type(token_type))

## Applies the Scatter defense token effect.
## Rules Reference: "Scatter", p.11.
func _apply_scatter_effect() -> void:
	_state.scatter_used = true
	_state.modified_damage = _defense_resolver.apply_scatter(
			_state.modified_damage)
	_log.info("Scatter: all damage cancelled.")
	if _get_panel():
		_get_panel().update_defense_damage(0)
		_get_panel().disable_defense_token_button(-1)

## Applies the Brace defense token effect.
## Rules Reference: "Brace", RRG v1.5.0, p.3.
func _apply_brace_effect() -> void:
	_state.brace_used = true
	_state.modified_damage = _defense_resolver.apply_brace(
			_state.modified_damage)
	_log.info("Brace: damage halved to %d." % [
			_state.modified_damage])
	if _get_panel():
		_get_panel().update_defense_damage(
				_state.modified_damage)

## Returns the button index for a given token type in the current attack.
func _get_token_button_index_for_type(
		token_type: Constants.DefenseToken) -> int:
	if _state.defender_ship == null:
		return -1
	var def_inst: ShipInstance = _state.defender_ship.get_ship_instance()
	if def_inst == null:
		return -1
	return _defense_resolver.get_token_button_index(
			token_type, def_inst.defense_tokens,
			_state.spent_tokens)

## Starts the Evade die-selection sub-step.
## The defender must click a die to remove (long) or reroll (med/close).
## Requirements: AE-DEF-007–009.
## Rules Reference: "Evade", RRG v1.5.0, p.5 — "At long range, the
## defender cancels one attack die of its choice. At medium or close
## range, the defender chooses one attack die to be rerolled."
func _attack_exec_start_evade() -> void:
	if _state.dice_results.is_empty():
		_log.info("Evade: no dice to target — skipping.")
		return
	_state.evade_step = true
	var range_band: String = _state.range_band
	_log.info("Evade: awaiting die selection (%s range)." % range_band)
	if _get_panel():
		_get_panel().show_evade_die_selection(range_band)

## Called when the defender selects a die during evade die-selection.
## At long range: remove the die. At medium/close: reroll it.
## Requirements: AE-DEF-007–009.
func _on_evade_die_selected(die_index: int) -> void:
	if not _state.evade_step:
		return
	if die_index < 0 or die_index >= _state.dice_results.size():
		_log.info("Evade: invalid die index %d." % die_index)
		return
	_state.evade_step = false
	if _get_panel():
		_get_panel().hide_evade_die_selection()
	if _state.range_band == Constants.RANGE_BAND_LONG:
		_apply_evade_remove(die_index)
	else:
		_apply_evade_reroll(die_index)
	if _get_panel():
		_get_panel().update_defense_damage(
				_state.modified_damage)
		_get_panel().disable_defense_token_button(
				_get_token_button_index_for_type(
				Constants.DefenseToken.EVADE))
	_process_next_defense_commit()

## Evade at long range: removes the selected die.
func _apply_evade_remove(die_index: int) -> void:
	var parts: CombatParticipants = _build_current_participants()
	var result: Dictionary = _defense_resolver.apply_evade_remove(
			die_index, _state.dice_results, parts,
			_effect_registry)
	_state.dice_results = result["dice_results"]
	_state.modified_damage = result["damage"]
	_log.info("Evade (long): removed die %d. Damage now %d." % [
			die_index, _state.modified_damage])
	if _get_panel():
		_get_panel().show_dice_results(
				_state.dice_results)

## Evade at medium/close range: rerolls the selected die.
func _apply_evade_reroll(die_index: int) -> void:
	var parts: CombatParticipants = _build_current_participants()
	var result: Dictionary = _defense_resolver.apply_evade_reroll(
			die_index, _state.dice_results, parts,
			_effect_registry)
	_state.dice_results = result["dice_results"]
	_state.modified_damage = result["damage"]
	var new_face: Constants.DiceFace = (
			result["new_face"] as Constants.DiceFace)
	_log.info("Evade (%s): rerolled die %d → %s. Damage now %d."
			% [_state.range_band, die_index, str(new_face),
			_state.modified_damage])
	if _get_panel():
		var color: Constants.DiceColor = (
				_state.dice_results[die_index]["color"]
				as Constants.DiceColor)
		_get_panel().update_die_result(die_index, {
			"color": color, "face": new_face})

## Starts the redirect sub-step: shows adjacent zone buttons.
## Requirements: AE-DEF-011–013.
## Rules Reference: "Redirect", p.11 — "the defender chooses one hull zone
## adjacent to the defending hull zone and may suffer up to that adjacent
## zone's remaining shields in that zone instead."
func _attack_exec_start_redirect(_def_inst: ShipInstance) -> void:
	_state.redirect_step = true
	# The redirect budget is all the current damage.
	_state.redirect_remaining = _state.modified_damage
	# Get adjacent zones to the defending hull zone.
	var def_zone: Constants.HullZone = (
			_state.defender_zone as Constants.HullZone)
	var adjacent: Array = ConstantsScript.get_adjacent_hull_zones(def_zone)
	_log.info(
			"Redirect: %d damage to redirect from %s. Adjacent: %s"
			% [_state.redirect_remaining,
			ConstantsScript.hull_zone_to_string(def_zone),
			str(adjacent)])
	if _get_panel():
		_get_panel().show_redirect_section(
				adjacent, _state.redirect_remaining)

## Called when the player selects a hull zone for redirect.
## Each click redirects 1 damage to that zone (limited by zone shields).
## Requirements: AE-DEF-012, AE-DEF-013.
func _on_attack_redirect_zone_selected(zone: int) -> void:
	if not _state.redirect_step:
		return
	if _state.defender_ship == null:
		return
	var def_inst: ShipInstance = \
			_state.defender_ship.get_ship_instance()
	if def_inst == null:
		return
	var zone_enum: Constants.HullZone = zone as Constants.HullZone
	if not _apply_single_redirect(zone_enum, def_inst):
		return
	if _get_panel():
		_get_panel().update_defense_damage(
				_state.modified_damage)
	if not _check_redirect_continuation(def_inst):
		_state.redirect_step = false
		_process_next_defense_commit()

## Applies one point of redirect damage to the given hull zone.
## Returns false if the zone has no shields or no damage remains.
func _apply_single_redirect(zone_enum: Constants.HullZone,
		def_inst: ShipInstance) -> bool:
	var zone_str: String = ConstantsScript.hull_zone_to_string(zone_enum)
	if not _defense_resolver.can_redirect_to_zone(
			zone_enum, def_inst, _state.redirect_remaining):
		_log.info("Redirect: cannot redirect to %s." % zone_str)
		return false
	# Route through command system for replay determinism.
	GameManager.submit_select_redirect_zone(def_inst, int(zone_enum))
	EventBus.ship_shields_changed.emit(
			def_inst, zone_str,
			int(def_inst.current_shields.get(zone_str, 0)))
	_state.redirect_remaining -= 1
	_state.modified_damage -= 1
	_log.info("Redirect: 1 damage to %s shield. Remaining: %d/%d." % [
			zone_str, _state.redirect_remaining,
			_state.modified_damage])
	return true

## Checks if redirect can continue. Returns true if more redirect is
## possible and the UI was updated; false if redirect is done.
func _check_redirect_continuation(
		def_inst: ShipInstance) -> bool:
	var def_zone: Constants.HullZone = (
			_state.defender_zone as Constants.HullZone)
	var can_continue: bool = _defense_resolver.can_redirect_continue(
			_state.redirect_remaining, def_zone, def_inst)
	if can_continue and _get_panel():
		_get_panel().update_redirect_remaining(
				_state.redirect_remaining)
		return true
	if _get_panel():
		_get_panel().hide_redirect_section()
	return false

## Called when the player presses "Commit Defense".
## Reads selected token indices from the panel and processes them
## sequentially via [method _process_next_defense_commit].
## Requirements: AE-DEF-003.
func _on_attack_defense_done() -> void:
	var selected: Array[int] = []
	if _get_panel():
		selected = _get_panel().get_defense_selected_indices()
		_get_panel().disable_all_defense_buttons()
	if selected.is_empty():
		_log.info("No defense tokens selected — proceeding to damage.")
		_state.defense_step = false
		if _get_panel():
			_get_panel().hide_defense_section()
		_attack_exec_resolve_damage()
		return
	# Sort tokens into canonical resolution order (RRG "Defense Tokens"):
	# Scatter → Evade → Brace → Redirect → Contain.
	# This ensures Brace halves damage before Redirect distributes it.
	_state.defense_commit_queue = _sort_defense_tokens_canonical(selected)
	_log.info("Defense commit: %d tokens queued." %
			_state.defense_commit_queue.size())
	_process_next_defense_commit()

## Canonical defense token resolution order.
## Rules Reference: \"Defense Tokens\", p.5 — effects resolve in a
## fixed sequence: Scatter (cancel) → Evade (dice mod) → Brace
## (halve total) → Redirect (distribute) → Contain (prevent crit).
## Kept as a local alias so existing tests referencing
## [code]AttackExecutor._DEFENSE_RESOLVE_ORDER[/code] still work.
const _DEFENSE_RESOLVE_ORDER: Dictionary = {
	Constants.DefenseToken.SCATTER: 0,
	Constants.DefenseToken.EVADE: 1,
	Constants.DefenseToken.BRACE: 2,
	Constants.DefenseToken.REDIRECT: 3,
	Constants.DefenseToken.CONTAIN: 4,
}

## Sorts token indices into canonical RRG resolution order.
func _sort_defense_tokens_canonical(
		indices: Array[int]) -> Array[int]:
	if _state.defender_ship == null:
		return indices
	var def_inst: ShipInstance = \
			_state.defender_ship.get_ship_instance()
	if def_inst == null:
		return indices
	return _defense_resolver.sort_tokens_canonical(
			indices, def_inst.defense_tokens)

## Processes the next defense token in the commit queue.
## When the queue is empty, hides the defense UI and resolves damage.
func _process_next_defense_commit() -> void:
	if _state.defense_commit_queue.is_empty():
		_log.info("Defense commit complete. Modified damage: %d." % [
				_state.modified_damage])
		_state.defense_step = false
		if _get_panel():
			_get_panel().hide_defense_section()
		_attack_exec_resolve_damage()
		return
	var token_index: int = _state.defense_commit_queue.pop_front()
	_log.info("Processing committed token index %d." % token_index)
	# Reuse the existing spending logic (validates, applies, starts
	# sub-steps for Evade/Redirect).
	_on_attack_defense_token_spent(token_index, "exhaust")
	# For simple tokens (Scatter, Brace, Contain) the method returns
	# synchronously. For Evade/Redirect, sub-steps will call
	# _process_next_defense_commit() when they finish.
	if not _state.evade_step and not _state.redirect_step:
		_process_next_defense_commit()

## Called when the player presses "Done Redirecting" in the redirect
## section, ending the redirect sub-step early.
func _on_redirect_done_early() -> void:
	if not _state.redirect_step:
		return
	_log.info("Redirect ended early by player.")
	_state.redirect_step = false
	if _get_panel():
		_get_panel().hide_redirect_section()
	_process_next_defense_commit()

# ===========================================================================
# Phase 6c-3 — Damage Resolution (Step 5)
# ===========================================================================

## Resolves damage against the defender.
## For ships: shields absorb damage first, then damage cards are dealt.
## Standard critical: if at least one critical icon and Contain was not
## used, the first damage card is dealt faceup.
## Requirements: AE-DMG-001–014.
## Rules Reference: "Damage", p.4 — "Damage is applied one point at a
## time."
func _attack_exec_resolve_damage() -> void:
	# Phase I3: MODIFY/DEFENSE_TOKENS -> RESOLVE_DAMAGE is always legal.
	if _flow_fsm.current_step != AttackFlowFSM.Step.RESOLVE_DAMAGE:
		_flow_fsm.advance(GameManager.current_game_state,
				AttackFlowFSM.Step.RESOLVE_DAMAGE)
	var final_damage: int = _damage_dealer.calculate_final_damage(
			_state.modified_damage, _state.scatter_used)
	# Brace is already applied during Step 4 (canonical order before
	# Redirect), so _state.modified_damage is already halved.
	_log.info("Resolving damage: %d total." % final_damage)
	if final_damage <= 0:
		_log.info("No damage to resolve.")
		if _get_panel():
			_get_panel().show_damage_info(
					_damage_dealer.build_no_damage_info())
		_attack_exec_finalize_after_delay()
		return
	# --- Squadron defender ---
	if _state.defender_squadron:
		_resolve_squadron_damage(final_damage)
		_attack_exec_finalize_after_delay()
		return
	# --- Ship defender ---
	if _state.defender_ship:
		_resolve_ship_damage(final_damage)
		# If the damage summary overlay is being shown, wait for the player
		# to dismiss it before resolving immediate effects and finalising.
		if _state.awaiting_damage_summary:
			EventBus.damage_summary_dismissed.connect(
					_on_damage_summary_dismissed_continue,
					CONNECT_ONE_SHOT)
			return
		# No summary overlay — resolve deferred immediate effects now.
		_resolve_deferred_immediate_effect()
		# If a choice-based immediate effect is pending, show the modal
		# flow instead of finalising immediately (DM-011).
		if _pending_immediate_card != null:
			_start_immediate_choice_flow()
			return
		_attack_exec_finalize_after_delay()
		return
	_log.error("No defender found for damage resolution!")
	_attack_exec_finalize_attack()

## Resolves damage against a squadron.
## Squadrons have no shields — damage goes directly to hull.
## Routes through [ResolveDamageCommand] for replay determinism.
## Requirements: AE-DMG-002.
func _resolve_squadron_damage(damage: int) -> void:
	var sq_inst: SquadronInstance = (
			_state.defender_squadron.get_squadron_instance())
	if sq_inst == null:
		_log.error("Squadron instance is null — cannot resolve damage.")
		return
	var actual: int = mini(damage, sq_inst.current_hull)
	var destroyed: bool = (sq_inst.current_hull - actual) <= 0
	# All mutations happen inside the command.
	GameManager.submit_resolve_squadron_damage(
			sq_inst, damage, actual, destroyed)
	# Post-command: emit UI events from post-mutation state.
	EventBus.squadron_hull_changed.emit(sq_inst, sq_inst.current_hull)
	_log.info("Squadron took %d damage. Hull: %d/%d." % [
			actual, sq_inst.current_hull,
			sq_inst.squadron_data.hull])
	if _get_panel():
		_get_panel().show_damage_info(
				_damage_dealer.build_squadron_damage_info(
						actual, sq_inst.current_hull,
						sq_inst.squadron_data.hull))
	if destroyed:
		_log.info("Squadron destroyed!")
		EventBus.squadron_destroyed.emit(_state.defender_squadron)
		_fade_out_token(_state.defender_squadron)

## Resolves damage against a ship.
## Shields absorb damage first. Remaining damage becomes damage cards.
## Standard critical: first card is faceup if any critical icon present
## and Contain was not spent.
## Routes through [ResolveDamageCommand] for replay determinism.
## Requirements: AE-DMG-003–014.
## Rules Reference: "Damage", p.4.
func _resolve_ship_damage(damage: int) -> void:
	var def_inst: ShipInstance = (
			_state.defender_ship.get_ship_instance())
	if def_inst == null:
		_log.error("Ship instance is null — cannot resolve damage.")
		return
	var def_zone_str: String = ConstantsScript.hull_zone_to_string(
			_state.defender_zone as Constants.HullZone)
	# Pre-compute shield absorption.
	var shield_budget: int = int(
			def_inst.current_shields.get(def_zone_str, 0))
	var shield_damage: int = mini(shield_budget, damage)
	var remaining: int = damage - shield_damage
	# Pre-draw damage cards and serialize for the command payload.
	var first_card_faceup: bool = _determine_first_card_faceup()
	var card_data: Array = _pre_draw_damage_cards(
			remaining, first_card_faceup)
	# Determine destruction.
	var destroyed: bool = (
			def_inst.get_total_damage() + card_data.size()
			>= def_inst.ship_data.hull)
	# Submit — all mutations happen inside the command.
	GameManager.submit_resolve_ship_damage(
			def_inst, def_zone_str, shield_damage, card_data, destroyed)
	# Post-command: emit events from post-mutation state.
	_emit_post_resolve_events(
			def_inst, def_zone_str, shield_damage,
			card_data, destroyed)

## Pre-draws damage cards from the deck and returns serialized card data.
## Cards are drawn but NOT added to the ship — the command does that.
func _pre_draw_damage_cards(count: int,
		first_card_faceup: bool) -> Array:
	var card_data: Array = []
	for i: int in range(count):
		var card: DamageCard = _draw_next_damage_card(i, count)
		if card == null:
			break
		if _damage_dealer.should_deal_faceup(i, first_card_faceup):
			card.is_faceup = true
		card_data.append(card.serialize())
	return card_data


## Emits all UI events after [ResolveDamageCommand] has executed.
## Handles shield changes, card events, hull change, damage summary,
## and destruction signalling.
func _emit_post_resolve_events(def_inst: ShipInstance,
		def_zone_str: String, shield_absorbed: int,
		card_data: Array, destroyed: bool) -> void:
	_emit_shield_events(def_inst, def_zone_str, shield_absorbed)
	var cards_dealt: int = card_data.size()
	var faceup_card_name: String = _emit_card_events(
			def_inst, card_data)
	_emit_ship_damage_events(def_inst, cards_dealt)
	var summary: String = _build_damage_summary(
			def_inst, def_zone_str, shield_absorbed,
			cards_dealt, faceup_card_name)
	if _get_panel():
		_get_panel().show_damage_info(summary)
	_log.info("Damage resolved: %s" % summary)
	EventBus.damage_resolved.emit(_state.defender_ship,
			shield_absorbed + cards_dealt)
	if destroyed:
		_log.info("Ship destroyed! %s" % def_inst.data_key)
		EventBus.ship_destroyed.emit(_state.defender_ship)
		_fade_out_token(_state.defender_ship)


## Emits shield change events if shields were absorbed.
func _emit_shield_events(def_inst: ShipInstance,
		def_zone_str: String, shield_absorbed: int) -> void:
	if shield_absorbed > 0:
		EventBus.ship_shields_changed.emit(
				def_inst, def_zone_str,
				int(def_inst.current_shields.get(def_zone_str, 0)))
		_log.info("Shields absorbed %d damage in %s." % [
				shield_absorbed, def_zone_str])


## Emits card-dealt events and registers persistent effects.
## Retrieves newly added cards from the ship's damage arrays.
## Returns the faceup card name (empty if none).
func _emit_card_events(def_inst: ShipInstance,
		card_data: Array) -> String:
	var faceup_card_name: String = ""
	var faceup_count: int = _count_faceup(card_data)
	var facedown_count: int = card_data.size() - faceup_count
	var dealt_faceup_cards: Array = []
	# Retrieve newly added faceup cards from the ship.
	if faceup_count > 0:
		var start: int = def_inst.faceup_damage.size() - faceup_count
		for i: int in range(start, def_inst.faceup_damage.size()):
			var card: DamageCard = def_inst.faceup_damage[i] as DamageCard
			_post_process_faceup_card(card, def_inst)
			faceup_card_name = card.title
			dealt_faceup_cards.append(card)
	# Retrieve newly added facedown cards from the ship.
	if facedown_count > 0:
		var start: int = def_inst.facedown_damage.size() - facedown_count
		for i: int in range(start, def_inst.facedown_damage.size()):
			var card: DamageCard = def_inst.facedown_damage[i] as DamageCard
			EventBus.damage_card_dealt.emit(def_inst, card, false)
			_log.info("Dealt facedown damage card to %s."
					% def_inst.ship_data.ship_name)
	_log.info("Card loop done: %d card(s) dealt." % card_data.size())
	if card_data.size() > 0:
		_state.awaiting_damage_summary = true
		EventBus.damage_summary_requested.emit(
				def_inst, dealt_faceup_cards, facedown_count,
				def_inst.ship_data.ship_name)
	return faceup_card_name


## Counts faceup cards in a serialized card data array.
func _count_faceup(card_data: Array) -> int:
	var count: int = 0
	for cd: Variant in card_data:
		if (cd as Dictionary).get("is_faceup", false):
			count += 1
	return count

## Determines if the first damage card should be dealt faceup (critical).
func _determine_first_card_faceup() -> bool:
	var attacker: ShipInstance = null
	if _state.attacker_ship is ShipToken:
		attacker = (
				_state.attacker_ship as ShipToken).get_ship_instance()
	var faceup: bool = _defense_resolver.determine_first_card_faceup(
			_state.dice_results, _state.contain_used,
			_effect_registry, attacker)
	_log.info("Damage cards: first_faceup=%s, contain=%s." % [
			faceup, _state.contain_used])
	return faceup

## Draws the next damage card from the deck, with logging.
func _draw_next_damage_card(index: int,
		total: int) -> DamageCard:
	_log.info("Dealing card %d/%d …" % [index + 1, total])
	if _damage_deck == null:
		_log.error("No damage deck available!")
		return null
	var card: DamageCard = _damage_deck.draw_card()
	if card == null:
		_log.error("Damage deck is empty!")
		return null
	_log.info("Drew card: '%s' [%s] (timing=%s, effect_id=%s)."
			% [card.title, card.trait_type, card.timing,
			card.effect_id])
	return card

## Post-processes a faceup damage card after the command has added it.
## Registers persistent effects, emits events, and defers immediates.
## Does NOT mutate game state — the card is already on the ship.
func _post_process_faceup_card(card: DamageCard,
		def_inst: ShipInstance) -> void:
	if _effect_registry and _damage_dealer.should_register_persistent(card):
		DamageCardEffectFactory.register_effect(
				card, def_inst, _effect_registry)
		_log.info("Persistent effect registered for '%s'." % card.title)
	EventBus.damage_card_flipped.emit(def_inst, card, true)
	EventBus.damage_card_dealt.emit(def_inst, card, true)
	_log.info(
			"Dealt FACEUP damage card: '%s' [%s] (standard critical)."
			% [card.title, card.trait_type])
	if _damage_dealer.has_immediate_effect(card):
		_state.deferred_immediate_card = card
		_state.deferred_immediate_ship = def_inst
		_log.info("Immediate effect deferred for '%s' "
				% card.title + "(awaiting summary dismiss).")

## Emits hull change and ship damaged events after cards are dealt.
func _emit_ship_damage_events(def_inst: ShipInstance,
		cards_dealt: int) -> void:
	if cards_dealt <= 0:
		return
	var new_hull: int = _damage_dealer.calculate_hull_remaining(
			def_inst.ship_data.hull, def_inst.get_total_damage())
	EventBus.ship_hull_changed.emit(def_inst, new_hull)
	EventBus.ship_damaged.emit(
			_state.defender_ship, cards_dealt,
			_state.defender_zone as Constants.HullZone)
	_log.info("Hull remaining: %d/%d after %d card(s) dealt to %s." % [
			new_hull, def_inst.ship_data.hull, cards_dealt,
			def_inst.ship_data.ship_name])

## Builds the damage summary string for the panel.
func _build_damage_summary(def_inst: ShipInstance,
		def_zone_str: String, shield_absorbed: int,
		cards_dealt: int, faceup_card_name: String) -> String:
	var hull_remaining: int = _damage_dealer.calculate_hull_remaining(
			def_inst.ship_data.hull, def_inst.get_total_damage())
	return _damage_dealer.build_damage_summary(
			def_zone_str, shield_absorbed, cards_dealt,
			faceup_card_name, hull_remaining, def_inst.ship_data.hull)

## Resolves the immediate one-shot effect of a faceup damage card, if any.
## Auto-resolve cards (Structural Damage, Projector Misaligned, Life Support
## Failure) are handled immediately. Choice cards (Injured Crew, Shield
## Failure, Comm Noise) are deferred — the pending state is stored and the
## choice modal is shown after the damage summary.
## Rules Reference: RRG "Damage Cards", p.4; DM-005, DM-011.
func _resolve_immediate_card_effect(card: DamageCard,
		ship: ShipInstance) -> void:
	if not ImmediateEffectResolver.is_immediate(card):
		return
	var choice_info: Dictionary = _immediate_resolver.get_required_choice(
			card, ship)
	if choice_info.is_empty():
		# Auto-resolve (no player choice needed).
		# Pre-draw extra card for structural_damage.
		var extra_card_data: Dictionary = {}
		if card.effect_id == "structural_damage" and _damage_deck:
			var extra: DamageCard = _damage_deck.draw_card()
			if extra:
				extra_card_data = extra.serialize()
		var result: Dictionary = GameManager.submit_resolve_immediate_effect(
				ship, card, {}, extra_card_data)
		if not result.is_empty():
			_emit_immediate_signals(card, ship, result)
			_log.info("Immediate effect resolved: '%s'." % card.title)
		else:
			_log.warn("Immediate effect failed: '%s'." % card.title)
		return
	# Choice-based card — store pending state for the modal flow.
	_pending_immediate_card = card
	_pending_immediate_ship = ship
	_pending_immediate_choice = choice_info
	_log.info("Immediate effect deferred for modal: '%s' (chooser=%s)."
			% [card.title, choice_info.get("chooser", "?")])

## Resolves the deferred immediate effect stored during the card loop.
## Called after the DamageSummaryOverlay is dismissed (or immediately if no
## summary was shown).  Clears the deferred state afterwards.
func _resolve_deferred_immediate_effect() -> void:
	if _state.deferred_immediate_card == null:
		return
	var card: DamageCard = _state.deferred_immediate_card
	var ship: ShipInstance = _state.deferred_immediate_ship
	_state.deferred_immediate_card = null
	_state.deferred_immediate_ship = null
	_resolve_immediate_card_effect(card, ship)

## Callback when the player dismisses the [DamageSummaryOverlay].
## Resolves deferred immediate effects, then continues the attack flow
## (choice modal or finalize).
func _on_damage_summary_dismissed_continue() -> void:
	_state.awaiting_damage_summary = false
	_log.info("Damage summary dismissed — resolving deferred effects.")
	_resolve_deferred_immediate_effect()
	if _pending_immediate_card != null:
		_start_immediate_choice_flow()
		return
	_attack_exec_finalize_after_delay()

# ---------------------------------------------------------------------------
# Phase 10a — Immediate Effect Choice Modal Flow (DM-011)
# ---------------------------------------------------------------------------

## Starts the immediate-effect choice flow: handoff (if hot-seat) → modal.
## Called from [method _attack_exec_resolve_damage] when a pending choice
## exists. On completion, resolves the effect and finalises the attack.
func _start_immediate_choice_flow() -> void:
	_ensure_choice_modal()
	var chooser: String = _pending_immediate_choice.get("chooser", "opponent")
	var chooser_player: int = _get_chooser_player_index(chooser)
	# Phase I3: chooser controls the CRITICAL_CHOICE step.
	_flow_fsm.defender_player = chooser_player
	_flow_fsm.advance(GameManager.current_game_state,
			AttackFlowFSM.Step.CRITICAL_CHOICE)
	_log.info("Immediate choice flow: chooser='%s' (player %d), card='%s'."
			% [chooser, chooser_player,
			_pending_immediate_choice.get("card_title", "?")])
	if PlayMode.is_hot_seat() and _camera:
		_camera.rotate_to_player(chooser_player)
		if _handoff_overlay:
			_handoff_overlay.show_handoff(
					chooser_player, "Damage Card Choice")
			var vp_size: Vector2 = Vector2(1280, 720)
			if get_viewport():
				vp_size = get_viewport().get_visible_rect().size
			_handoff_overlay.update_size(vp_size)
			if not EventBus.handoff_accepted.is_connected(
					_on_immediate_handoff_accepted):
				EventBus.handoff_accepted.connect(
						_on_immediate_handoff_accepted,
						CONNECT_ONE_SHOT)
			return
	# Non-hot-seat or no handoff overlay: show modal directly.
	_show_immediate_choice_modal()

## Called when the handoff "Ready" button is pressed during the
## immediate-effect choice flow.
func _on_immediate_handoff_accepted() -> void:
	_show_immediate_choice_modal()

## Creates and shows the OpponentChoiceModal with the pending choice.
func _show_immediate_choice_modal() -> void:
	_ensure_choice_modal()
	if not _opponent_choice_modal.choice_confirmed.is_connected(
			_on_immediate_choice_confirmed):
		_opponent_choice_modal.choice_confirmed.connect(
				_on_immediate_choice_confirmed, CONNECT_ONE_SHOT)
	_opponent_choice_modal.open(_pending_immediate_choice)

## Called when the player confirms their selection in the choice modal.
func _on_immediate_choice_confirmed(selection: Dictionary) -> void:
	var card: DamageCard = _pending_immediate_card
	var ship: ShipInstance = _pending_immediate_ship
	# Clear pending state.
	_pending_immediate_card = null
	_pending_immediate_ship = null
	_pending_immediate_choice = {}
	if card == null or ship == null:
		_log.error("Immediate choice confirmed but no pending card/ship!")
		_attack_exec_finalize_after_delay()
		return
	var ok: bool = false
	var extra_card_data: Dictionary = {}
	if card.effect_id == "structural_damage" and _damage_deck:
		var extra: DamageCard = _damage_deck.draw_card()
		if extra:
			extra_card_data = extra.serialize()
	var result: Dictionary = GameManager.submit_resolve_immediate_effect(
			ship, card, selection, extra_card_data)
	if not result.is_empty():
		ok = true
		_emit_immediate_signals(card, ship, result)
		_log.info("Immediate effect resolved: '%s' (choice=%s)." % [
				card.title, str(selection)])
	else:
		_log.warn("Immediate effect failed: '%s' (choice=%s)." % [
				card.title, str(selection)])
	# Update hull/shield display after the effect.
	var new_hull: int = ship.ship_data.hull - ship.get_total_damage()
	EventBus.ship_hull_changed.emit(ship, new_hull)
	_attack_exec_finalize_after_delay()


## Emits the appropriate EventBus signals after a
## [ResolveImmediateEffectCommand] executes.
func _emit_immediate_signals(card: DamageCard,
		ship: ShipInstance, result: Dictionary) -> void:
	var eid: String = result.get("effect_id", "") as String
	match eid:
		"structural_damage":
			EventBus.damage_card_flipped.emit(ship, card, false)
		"projector_misaligned":
			var zone: String = result.get("zone", "") as String
			if not zone.is_empty():
				EventBus.ship_shields_changed.emit(
						ship, zone,
						int(result.get("new_shields", 0)))
			EventBus.damage_card_flipped.emit(ship, card, false)
		"life_support_failure":
			EventBus.command_tokens_changed.emit(ship)
		"injured_crew":
			EventBus.ship_defense_token_changed.emit(ship)
			EventBus.damage_card_flipped.emit(ship, card, false)
		"shield_failure":
			var changes: Array = result.get("shield_changes", [])
			for sc: Variant in changes:
				var d: Dictionary = sc as Dictionary
				EventBus.ship_shields_changed.emit(
						ship, d.get("zone", ""),
						int(d.get("new_shields", 0)))
			EventBus.damage_card_flipped.emit(ship, card, false)
		"comm_noise":
			var action: String = result.get("action", "") as String
			if action == "reduce_speed":
				EventBus.ship_speed_changed.emit(
						ship, int(result.get("new_speed", 0)))
			elif action == "change_dial":
				EventBus.command_dials_changed.emit(ship)
			EventBus.damage_card_flipped.emit(ship, card, false)


## Returns the player index for the given chooser role relative to the
## current attack's defender.
func _get_chooser_player_index(chooser: String) -> int:
	if _state.defender_ship:
		var def_inst: ShipInstance = (
				_state.defender_ship.get_ship_instance())
		if def_inst:
			return _damage_dealer.get_chooser_player_index(
					chooser, def_inst.owner_player)
	return 0

## Lazily creates the OpponentChoiceModal on a high CanvasLayer.
func _ensure_choice_modal() -> void:
	if _opponent_choice_modal != null:
		return
	_opponent_choice_modal = OpponentChoiceModal.new()
	_opponent_choice_modal.name = "OpponentChoiceModal"
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "ChoiceModalLayer"
	layer.layer = 95
	add_child(layer)
	layer.add_child(_opponent_choice_modal)

## Waits briefly to show the damage info, then proceeds to finalize.
func _attack_exec_finalize_after_delay() -> void:
	# Small delay so the player can see the damage info.
	var timer: SceneTreeTimer = get_tree().create_timer(1.2)
	timer.timeout.connect(_attack_exec_finalize_attack)

## Finalises the attack: records the zone as fired, checks for follow-up
## attacks (two-hull-zone rule, squadron Step 6 loop).
## Requirements: AE-2HZ-001, AE-2HZ-003, AE-2HZ-004, AE-SQ-001,
## AE-SQ-003, AE-SQ-004.
## Rules Reference: "Attack", Step 6, p.2.
func _attack_exec_finalize_attack() -> void:
	if _get_panel():
		_get_panel().hide_damage_info()
		_get_panel().hide_defense_section()
		_get_panel().hide_accuracy_section()
		_get_panel().hide_redirect_section()
	_rotate_camera_to_attacker()
	# --- Squadron defender: Step 6 loop ---
	if _state.defender_squadron:
		_finalize_squadron_attack()
		return
	# --- Ship defender: two-hull-zone logic ---
	if _state.attacker_zone >= 0:
		_state.fired_zones.append(_state.attacker_zone)
	_attack_exec_mark_spent_zone()
	_state.current_attack += 1
	if _state.current_attack < 2:
		_attack_exec_prepare_next_attack()
		return
	_finish_attack_execution()

## Rotates the camera back to the attacker’s perspective (AE-DEF-011).
func _rotate_camera_to_attacker() -> void:
	if not _camera or not PlayMode.is_hot_seat():
		return
	if _state.exec_ship_token:
		var atk_inst: ShipInstance = (
				_state.exec_ship_token.get_ship_instance())
		if atk_inst:
			_camera.rotate_to_player(atk_inst.owner_player)
	elif _state.exec_squad_token:
		var sq_inst: SquadronInstance = (
				_state.exec_squad_token.get_squadron_instance())
		if sq_inst:
			_camera.rotate_to_player(sq_inst.owner_player)

## Handles the Step 6 squadron loop finalisation.
func _finalize_squadron_attack() -> void:
	_state.attacked_squads.append(_state.defender_squadron)
	if _get_overlay():
		_get_overlay().add_spent_zone_marker(
				_state.defender_squadron.global_position)
	if _attack_exec_has_more_squad_targets():
		_attack_exec_prepare_next_squadron()
		return
	_end_squadron_loop()

## Auto-skips a squadron target that yielded 0 dice (out of armament
## range).  Marks it as attacked so it won't be retried, then either
## continues the loop or exits it.
## Requirements: AE-SQ-003.
## Rules Reference: "Attack", Step 1, p.2 — "The attacker must be
## able to add at least one die to the attack pool."
func _auto_skip_zero_dice_squadron() -> void:
	_log.info("Auto-skipping squadron (0 dice at this range).")
	_state.attacked_squads.append(_state.defender_squadron)
	_target_selector.clear_target_state()
	if _attack_exec_has_more_squad_targets():
		_attack_exec_prepare_next_squadron()
		return
	_end_squadron_loop()

## Ends the Step 6 squadron loop: marks the zone as fired and either
## prepares the next hull-zone attack or finishes the attack step.
func _end_squadron_loop() -> void:
	if _state.attacker_zone >= 0:
		_state.fired_zones.append(_state.attacker_zone)
	_attack_exec_mark_spent_zone()
	_state.current_attack += 1
	if _state.current_attack < 2:
		_state.attacked_squads.clear()
		_attack_exec_prepare_next_attack()
		return
	_finish_attack_execution()

## Draws a red dot on the spent hull zone's LOS marker position.
## Requirements: AE-2HZ-002.
func _attack_exec_mark_spent_zone() -> void:
	if _get_overlay() and _state.attacker_ship:
		var los_pts: Dictionary = (
				_state.attacker_ship.get_los_origins_world())
		var zone_key: String = _ZONE_NAMES.get(
				_state.attacker_zone, "FRONT")
		var los_pos: Vector2 = los_pts.get(zone_key, Vector2.ZERO)
		_get_overlay().add_spent_zone_marker(los_pos)

## Checks whether there are more enemy squadrons in the current arc
## that have not yet been attacked during this hull zone's attack AND
## that would produce at least one die at their range.
## Requirements: AE-SQ-003.
## Rules Reference: "Attack", Step 1, p.2 — attacker must add ≥1 die;
## Step 6, p.2 — new defender must be in arc and at range.
func _attack_exec_has_more_squad_targets() -> bool:
	var parts: CombatParticipants = _build_current_participants()
	if not parts.atk_is_ship():
		return false
	var armament: Dictionary = _get_anti_squadron_armament()
	if armament.is_empty():
		return false
	var attacker_faction: int = parts.get_atk_faction()
	for sq_token: SquadronToken in _target_selector.get_squadron_tokens_callable().call():
		if sq_token.get_faction() == attacker_faction:
			continue
		var sq_inst: SquadronInstance = sq_token.get_squadron_instance()
		if sq_inst and sq_inst.is_destroyed():
			continue
		if sq_token in _state.attacked_squads:
			continue
		if not _target_selector.get_target_resolver().is_squadron_target_in_arc(
				parts, sq_token):
			continue
		if not _target_selector.get_target_resolver().is_squadron_at_range(
				parts, sq_token):
			continue
		# Check that armament produces ≥1 die at this range.
		var range_band: String = _get_squadron_range_band(
				parts, sq_token)
		var pool: Dictionary = DicePool.get_attack_pool(
				armament, range_band)
		if DicePool.get_total_count(pool) > 0:
			return true
	return false

## Returns the anti-squadron armament of the current ship attacker.
func _get_anti_squadron_armament() -> Dictionary:
	if _state.attacker_ship == null:
		return {}
	var ship_data: ShipData = _state.attacker_ship.get_ship_data()
	if ship_data == null:
		return {}
	return ship_data.anti_squadron_armament

## Computes the range band to a squadron target from the current
## attacker hull zone.
func _get_squadron_range_band(parts: CombatParticipants,
		sq_token: SquadronToken) -> String:
	var atk_edge: Array[Vector2] = _target_selector.get_target_resolver().get_ship_edge(
			parts.atk_ship,
			parts.atk_zone as Constants.HullZone)
	var atk_arc_pts: Dictionary = parts.atk_ship \
			.get_firing_arc_world_points()
	if atk_arc_pts.is_empty():
		return Constants.RANGE_BAND_BEYOND
	var range_data: Dictionary = (
			RangeFinder.measure_attack_range_squadron_endpoints(
			atk_edge, sq_token.global_position,
			sq_token.get_radius_px(),
			parts.atk_zone as Constants.HullZone,
			atk_arc_pts))
	var dist: float = range_data.get("distance", INF)
	if dist >= INF:
		return Constants.RANGE_BAND_BEYOND
	return GameScale.get_range_band(dist)

## Returns true if the attacker has valid targets from ANY unfired
## hull zone.
## Requirements: AE-SKIP-003.
func _attack_exec_has_any_valid_target() -> bool:
	return _target_selector.get_target_resolver().has_any_valid_target(
			_state.exec_ship_token, _state.fired_zones)

## Prepares the board for attacking the next squadron in the same arc.
## Resets target and dice state but keeps the hull zone locked.
## Requirements: AE-SQ-004, AE-SQ-005.
## Rules Reference: "Attack", Step 6, p.2 — "Treat each repetition of
## steps 2 through 6 as a new attack for the purposes of resolving
## card effects."
func _attack_exec_prepare_next_squadron() -> void:
	_log.info("Preparing next squadron target (Step 6 loop). " \
			+"Attacked so far: %d." \
			% _state.attacked_squads.size())
	# Reset target and dice state.
	_state.dice_results.clear()
	_state.dice_pool.clear()
	_state.range_band = ""
	# Clean up target visuals, keep spent zone markers.
	_target_selector.prepare_next_squadron_target()
	# Update panel with "Select next squadron" prompt.
	if _get_panel():
		_get_panel().hide_dice_count()
		_get_panel().hide_dice_results()
		_get_panel().hide_confirm_button()
		_get_panel().hide_cf_dial_section()
		_get_panel().hide_cf_token_section()
		_get_panel().hide_roll_button()
		var ship_name: String = ""
		if _state.exec_ship_token.get_ship_data():
			ship_name = \
					_state.exec_ship_token.get_ship_data().ship_name
		_get_panel().show_select_next_squadron(
				ship_name, _state.attacker_zone_name)
		_get_panel().show_skip_attack_button()

## Prepares the board for a second hull zone attack.
## Resets target state and returns to hull zone selection.
## Requirements: AE-2HZ-004, AE-2HZ-005.
func _attack_exec_prepare_next_attack() -> void:
	_log.info("Preparing second attack (attack %d/2)." % [
			_state.current_attack + 1])
	if not _attack_exec_has_any_valid_target():
		_log.info(
				"No valid targets for second attack — auto-skipping.")
		_finish_attack_execution()
		return
	_reset_for_next_attack()
	_show_next_attack_panel()
	_target_selector.show_ship_range_overlay(_state.exec_ship_token)

## Resets target and dice state for the next hull zone attack.
func _reset_for_next_attack() -> void:
	_state.reset_for_next_attack()
	_target_selector.prepare_next_hull_zone()

## Updates the panel for the next hull zone selection.
func _show_next_attack_panel() -> void:
	if _get_panel():
		_get_panel().hide_dice_count()
		var ship_name: String = ""
		if _state.exec_ship_token.get_ship_data():
			ship_name = \
					_state.exec_ship_token.get_ship_data().ship_name
		_get_panel().show_initial_attack_exec(ship_name)
		_get_panel().show_skip_attack_button()

## Called when the player presses "Skip Attack".
## During hull zone selection: ends the attack step immediately.
## During the Step 6 squadron loop: ends the loop and proceeds to
## the next hull zone (or finishes if both are done).
## Requirements: AE-SKIP-001, AE-SKIP-002, AE-SQ-006.
func _on_attack_skip() -> void:
	# If we're in the Step 6 squadron loop (attacked >=1 squadron and
	# still target-selecting for the next one), treat as "done with
	# this hull zone's anti-squadron attacks."
	if _state.attacked_squads.size() > 0 and \
			_target_selector.is_target_selecting():
		_log.info(
				"Squadron loop skipped — moving to next hull zone.")
		GameManager.submit_skip_attack(
				_get_attacker_player(), "squadron_done")
		_end_squadron_loop()
		return
	_log.info("Attack skipped by player.")
	GameManager.submit_skip_attack(
			_get_attacker_player(), "voluntary")
	_finish_attack_execution()

## Fades out a destroyed token over 0.8 seconds, then hides it.
## Called when a ship or squadron is destroyed during an attack.
## Rules Reference: GF-004 — destroyed ships are removed from play.
func _fade_out_token(token: Node2D) -> void:
	if token == null:
		return
	# Disable input immediately so the token cannot be clicked during the
	# fade animation.  Visibility is set to false after the tween.
	token.set_process_unhandled_input(false)
	var tween: Tween = token.create_tween()
	tween.tween_property(token, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func() -> void:
		token.visible = false
		# Reset alpha so the token could theoretically be shown again.
		token.modulate.a = 1.0
	)
