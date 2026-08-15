## AttackExecutor
##
## Manages the attack execution flow from ship/squadron activation
## (Phases 6b/6c): dice rolling, defense tokens, damage resolution.
##
## Target selection (attacker, hull zone, target) is delegated to
## [TargetSelector], which owns the transient declaration candidate. AE
## submits Begin only after the panel emits explicit declaration confirmation.
##
## Requirements: AE-*, AT-001–007.
## Rules Reference: "Attack", Steps 2–6, pp.2–3.
class_name AttackExecutor
extends Node

## Preloaded script reference for calling static functions without triggering
## STATIC_CALLED_ON_INSTANCE warnings (Constants is an autoload instance).
const ConstantsScript := preload("res://src/autoload/constants.gd")
const AttackFlowExecutorScript := preload(
		"res://src/core/combat/attack_flow_executor.gd")
const ECM_SCRIPT: GDScript = preload(
		"res://src/core/effects/rules/upgrades/defensive_retrofit/electronic_countermeasures.gd")

const RESUME_KEY_OK: String = "ok"
const RESUME_KEY_REASON: String = "reason"
const RESUME_KEY_ATTACK_ID: String = "attack_id"
const RESUME_KEY_TRANSITION: String = "transition"
const RESUME_KEY_REQUIRES_INPUT: String = "requires_input"
const RESUME_KEY_FLOW: String = "projection_flow"
const RESUME_KEY_ACTIVATING_SHIP: String = "activating_ship"
const RESUME_KEY_ACTIVATING_SHIP_TOKEN: String = "activating_ship_token"
const RESUME_KEY_ENCLOSING_CONTINUATION: String = "enclosing_continuation"

const RESUME_RULE_CHOICE: String = "resolve_attack_pool_choice"
const RESUME_CF_DIAL: String = "resolve_concentrate_fire_dial"
const RESUME_ROLL: String = "roll_dice"
const RESUME_TIMING_WINDOW: String = "timing_window"
const RESUME_CONFIRM: String = "confirm_attack_dice"
const RESUME_ACCURACY: String = "commit_accuracy"
const RESUME_DEFENSE: String = "commit_defense"
const RESUME_SPEND_DEFENSE: String = "spend_defense_token"
const RESUME_EVADE: String = "select_evade_die"
const RESUME_REDIRECT: String = "select_redirect_zone"
const RESUME_DAMAGE: String = "resolve_damage"
const RESUME_AWAIT_RECORDED_COMPLETION: String = "await_recorded_completion"

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

## Pure payload-construction helper extracted to core/combat in K14a.
var _flow_executor: RefCounted = AttackFlowExecutorScript.new()

## Target selector — owns attacker/target selection, visual aids, and
## the AttackSimPanel. Created and wired in [method initialize].
var _target_selector: TargetSelector = null

## Transient — rule id whose pre-roll die-removal choice is pending.
var _attack_pool_die_choice_rule_id: String = ""

## Transient — rule id for the currently displayed optional reroll prompt.
var _pending_reroll_rule_id: String = ""

## Original attacking squadron waiting to be targeted by a Counter attack.
var _pending_counter_target: SquadronToken = null

## Squadron that may perform the pending Counter attack.
var _pending_counter_attacker: SquadronToken = null

## Range remembered while BeginAttackCommand is awaiting network authority.
var _pending_begin_range: String = ""

## The one semantic declaration command awaiting an authoritative result.
## Empty when Confirm/Skip/candidate replacement are interactive.
var _pending_declaration_command: String = ""

## True only while a standard squadron target selection has not yet produced
## an accepted BeginAttackCommand. The local FSM may render DECLARE, but the
## canonical InteractionFlow remains owned by the enclosing activation.
var _pre_begin_squadron_selection: bool = false

## Prevents duplicate presentation reactions to one resolved attack.
var _applied_damage_attack_id: String = ""

var _pending_finalize_after_completion: bool = false
var _pending_counter_begin: bool = false
var _pending_finish_after_skip: bool = false
var _pending_squadron_done_after_skip: bool = false
var _pending_zero_squad_skip: bool = false
var _defense_command_pending: bool = false
var _defense_submit_in_progress: bool = false
var _awaiting_result_acknowledgement: bool = false

## Reconstruction restores the active individual attack from CurrentAttackState
## and derives enclosing ship-attack progress from its ShipInstance owner.
var _reconstructed_current_attack: bool = false

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
# Phase I6b-3 — InteractionFlow publication helpers
# ---------------------------------------------------------------------------

## Advances the attack FSM and broadcasts the resulting
## [InteractionFlow] snapshot to all peers.
##
## The FSM mutates [member GameState.interaction_flow] locally; in
## network mode the helper additionally submits a
## [PublishAttackFlowCommand] so the defender peer's projector sees
## the new step (notably
## [constant Constants.InteractionStep.ATTACK_DEFENSE_TOKENS]).  In
## hot-seat the broadcast is a no-op.
func _fsm_advance(next_step: AttackFlowFSM.Step) -> void:
	var gs: GameState = GameManager.current_game_state
	_flow_fsm.advance(gs, next_step)
	if gs:
		GameManager.submit_publish_attack_flow(gs.interaction_flow)


## Patches the attack FSM payload and broadcasts the updated
## [InteractionFlow] snapshot to all peers.  Network-only broadcast
## (see [method _fsm_advance]).
func _fsm_patch_payload(patch: Dictionary) -> void:
	var gs: GameState = GameManager.current_game_state
	_flow_fsm.patch_payload(gs, patch)
	if gs and gs.interaction_flow \
			and gs.interaction_flow.step_id \
					== Constants.InteractionStep.ATTACK_DEFENSE_TOKENS:
		var decorated: Dictionary = ECM_SCRIPT.decorate_projection_payload(
				gs, gs.interaction_flow.payload)
		_flow_fsm.patch_payload(gs, decorated)
	if gs:
		GameManager.submit_publish_attack_flow(gs.interaction_flow)


## Broadcasts the current [InteractionFlow] snapshot to all peers
## without mutating the FSM.  Used after [method AttackFlowFSM.begin]
## and [method AttackFlowFSM.end] which are not routed through
## [method _fsm_advance].  Network-only.
func _publish_flow_snapshot() -> void:
	var gs: GameState = GameManager.current_game_state
	if gs:
		GameManager.submit_publish_attack_flow(gs.interaction_flow)


## Clears defender / target identity fields in
## [member InteractionFlow.payload] so the read-only attack panel
## mirror on the non-attacker peer drops the stale "→ <old target>"
## title between consecutive attacks (2-hull-zone rule and Step 6
## squadron loop).  The next DECLARE patch will repopulate the
## payload for the new target.  Phase I6b-3 R1b follow-up.
func _publish_clear_target_patch() -> void:
	_fsm_patch_payload(_flow_executor.build_clear_target_patch())


## Builds an attacker / target identity patch for
## [member GameState.interaction_flow.payload].  Called once when the
## attack sequence begins so the defender peer's mirror panel can
## render attacker ship/zone, target ship-or-squadron, and human-
## readable display names from `interaction_flow.payload` alone.
##
## Phase I6b-3 R1a — pure payload addition; no game-logic side
## effects.  All fields are plain ints/strings (serialisation safe).
##
## Returns a dictionary suitable for [method _fsm_patch_payload].
func _compute_attack_identity_patch() -> Dictionary:
	return _flow_executor.compute_attack_identity_patch(
			_state, GameManager.current_game_state)

# ---------------------------------------------------------------------------
# Phase 6c: Accuracy, Defense Tokens, Damage Resolution
# ---------------------------------------------------------------------------

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
	# Network: receive dice results from broadcast.  G4.6.5.
	if not EventBus.network_dice_result.is_connected(
			_on_network_dice_result):
		EventBus.network_dice_result.connect(_on_network_dice_result)

## Sets the shared damage deck reference.
func set_damage_deck(deck: DamageDeck) -> void:
	_damage_deck = deck

## Sets the handoff overlay reference for hot-seat immediate-effect choices.
func set_handoff_overlay(overlay: HandoffOverlay) -> void:
	_handoff_overlay = overlay


## Rebuilds the smallest production consumer needed for one validated active
## CurrentAttackState. Stable model references are resolved before any scene or
## InteractionFlow projection is changed. The returned plan is derived only
## from canonical current-attack facts and accepted model/runtime owners.
func resume_current_attack(
		ship_token_for_instance: Callable,
		squadron_token_for_instance: Callable) -> Dictionary:
	var game_state: GameState = GameManager.current_game_state
	if game_state == null:
		return _resume_failure("Missing canonical game state.")
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack == null or not attack.active:
		return _resume_failure("No active canonical attack to resume.")
	if not ship_token_for_instance.is_valid() \
			or not squadron_token_for_instance.is_valid():
		return _resume_failure("Attack token resolvers are unavailable.")
	var refs: Dictionary = _resolve_resume_references(
			game_state, attack, ship_token_for_instance,
			squadron_token_for_instance)
	if not bool(refs.get(RESUME_KEY_OK, false)):
		return refs
	_reset_exec_state()
	_install_resume_scene_references(attack, refs)
	_sync_ship_attack_progress_from_authority()
	_sync_scene_from_current_attack()
	var plan: Dictionary = _derive_resume_plan(game_state, attack)
	if not bool(plan.get(RESUME_KEY_OK, false)):
		_reset_exec_state()
		return plan
	var projection: Dictionary = _build_resume_projection(
			game_state, attack, plan)
	var flow_step: AttackFlowFSM.Step = int(
			plan.get("flow_step", AttackFlowFSM.Step.IDLE)) as AttackFlowFSM.Step
	if not _flow_fsm.restore_projection(
			flow_step, attack.attacker_player, attack.defender_player,
			projection):
		_reset_exec_state()
		return _resume_failure("Canonical attack stage has no projection step.")
	var flow: InteractionFlow = FlowSpec.make_interaction_flow(
			Constants.InteractionFlow.ATTACK,
			_flow_fsm.get_interaction_step(),
			game_state,
			{
				"attacker_player": attack.attacker_player,
				"defender_player": attack.defender_player,
				"controller_player": int(plan.get(
						"controller_player", attack.attacker_player)),
			},
			Constants.Visibility.ALL,
			projection)
	game_state.interaction_flow = flow
	_reconstructed_current_attack = true
	_render_resume_projection(plan)
	plan[RESUME_KEY_FLOW] = flow
	return plan


## Rebuilds a declaration presentation after an individual attack has been
## retired while its serialized ShipInstance still proves that the enclosing
## Attack step has a legal continuation. No command or Preview is synthesized.
## An empty result means that no inactive continuation exists.
func resume_inactive_ship_attack_continuation(
		ship_token_for_instance: Callable) -> Dictionary:
	var game_state: GameState = GameManager.current_game_state
	if game_state == null:
		return {}
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack != null and attack.active:
		return {}
	if not ship_token_for_instance.is_valid():
		return _resume_failure("Attack token resolver is unavailable.")
	var candidates: Array[ShipInstance] = \
			_inactive_ship_attack_continuations(game_state)
	if candidates.is_empty():
		return {}
	if candidates.size() != 1:
		return _resume_failure(
				"Canonical ship attack continuation is ambiguous.")
	var ship: ShipInstance = candidates[0]
	var ship_token: ShipToken = \
			ship_token_for_instance.call(ship) as ShipToken
	if ship_token == null:
		return _resume_failure(
				"Canonical ship attack continuation token is missing.")
	var continuation: String = \
			CompleteAttackCommand.CONTINUATION_SQUADRON \
			if ship.anti_squadron_attack_zone >= 0 \
			else CompleteAttackCommand.CONTINUATION_NORMAL_ATTACK
	var projection: Dictionary = {}
	if not _flow_fsm.restore_projection(
			AttackFlowFSM.Step.DECLARE, ship.owner_player, -1, projection):
		return _resume_failure(
				"Canonical ship attack continuation has no declaration route.")
	var prior_flow: InteractionFlow = game_state.interaction_flow
	var flow: InteractionFlow = FlowSpec.make_interaction_flow(
			Constants.InteractionFlow.ATTACK,
			_flow_fsm.get_interaction_step(),
			game_state,
			{
				"attacker_player": ship.owner_player,
				"defender_player": -1,
				"controller_player": ship.owner_player,
			},
			Constants.Visibility.ALL,
			projection)
	game_state.interaction_flow = flow
	var local_player: int = NetworkManager.get_local_player_index()
	if local_player < 0 or local_player == ship.owner_player:
		var presentation: Dictionary = _render_inactive_ship_continuation(
				ship_token, continuation)
		if not bool(presentation.get(RESUME_KEY_OK, false)):
			_flow_fsm.reset()
			game_state.interaction_flow = prior_flow
			return presentation
	return {
		RESUME_KEY_OK: true,
		RESUME_KEY_REASON: "",
		RESUME_KEY_ATTACK_ID: "",
		RESUME_KEY_TRANSITION: continuation,
		RESUME_KEY_REQUIRES_INPUT: true,
		RESUME_KEY_FLOW: flow,
		RESUME_KEY_ACTIVATING_SHIP: ship,
		RESUME_KEY_ACTIVATING_SHIP_TOKEN: ship_token,
		RESUME_KEY_ENCLOSING_CONTINUATION: continuation,
	}


func _inactive_ship_attack_continuations(
		game_state: GameState) -> Array[ShipInstance]:
	var result: Array[ShipInstance] = []
	for player_index: int in range(Constants.PLAYER_COUNT):
		var player: PlayerState = game_state.get_player_state(player_index)
		if player == null:
			continue
		for ship: ShipInstance in player.ships:
			if not ship.attack_step_active \
					or ship.committed_attack_count <= 0:
				continue
			if ship.anti_squadron_attack_zone >= 0 \
					or ship.committed_attack_count < 2:
				result.append(ship)
	return result


func _render_inactive_ship_continuation(
		ship_token: ShipToken, continuation: String) -> Dictionary:
	_target_selector.dismiss_other_tools_requested.emit()
	_target_selector.dismiss()
	_reset_exec_state()
	_init_ship_attack_state(ship_token)
	_target_selector.ensure_panel_for_projection()
	_wire_attack_done_and_panel_signals()
	if continuation == CompleteAttackCommand.CONTINUATION_SQUADRON:
		_target_selector._select_attacker_ship_zone(
				ship_token, _state.attacker_zone)
		if _state.attacker_ship != ship_token \
				or not _target_selector.is_target_selecting():
			_target_selector.dismiss()
			_reset_exec_state()
			return _resume_failure(
					"Canonical Step 6 continuation has no eligible target.")
		_target_selector.prepare_next_squadron_target()
		_show_next_squadron_panel_prompt()
	else:
		_target_selector.enter_attacker_selection(true, _get_ship_name())
		var panel: AttackSimPanel = _get_panel()
		if panel != null:
			panel.show_skip_attack_button()
		_target_selector.show_ship_range_overlay(_state.exec_ship_token)
	return {RESUME_KEY_OK: true}


## Authors only a deterministic next command for live authority. User choices,
## timing continuations, replay/mirror steps, BeginAttack and CompleteAttack are
## never synthesized by reconstruction.
func resume_live_progression(plan: Dictionary) -> bool:
	if not bool(plan.get(RESUME_KEY_OK, false)) \
			or bool(plan.get(RESUME_KEY_REQUIRES_INPUT, true)) \
			or not _is_live_defense_authority():
		return false
	var attack: CurrentAttackState = _current_attack()
	if attack == null or not attack.active \
			or attack.attack_id != str(plan.get(RESUME_KEY_ATTACK_ID, "")) \
			or attack.stage != str(plan.get("stage", "")) \
			or attack.defense_stage != str(plan.get("defense_stage", "")):
		return false
	match str(plan.get(RESUME_KEY_TRANSITION, "")):
		RESUME_RULE_CHOICE:
			var colours: Array[String] = _string_values(
					plan.get("available_colours", []))
			if colours.size() != 1:
				return false
			var choice_kind: String = str(plan.get("choice_kind", ""))
			var rule_id: String = str(plan.get("rule_id", ""))
			var result: Dictionary = GameManager.submit_attack_pool_choice(
					attack.attacker_player, choice_kind, colours[0], rule_id)
			return not result.is_empty()
		RESUME_ACCURACY:
			var result: Dictionary = GameManager.submit_commit_accuracy(
					attack.attacker_player, [])
			return not result.is_empty()
		RESUME_DEFENSE:
			return _submit_commit_defense([])
		RESUME_SPEND_DEFENSE:
			var cursor_before: int = CommandProcessor.get_next_sequence()
			_process_next_defense_commit()
			return CommandProcessor.get_next_sequence() > cursor_before
		RESUME_DAMAGE:
			var cursor_before: int = CommandProcessor.get_next_sequence()
			_attack_exec_resolve_damage()
			return CommandProcessor.get_next_sequence() > cursor_before
	return false


func _resolve_resume_references(
		game_state: GameState,
		attack: CurrentAttackState,
		ship_token_for_instance: Callable,
		squadron_token_for_instance: Callable) -> Dictionary:
	var attacker: RefCounted = _resume_entity(
			game_state, attack.attacker_kind,
			attack.attacker_player, attack.attacker_index)
	var defender: RefCounted = _resume_entity(
			game_state, attack.defender_kind,
			attack.defender_player, attack.defender_index)
	if attacker == null or defender == null:
		return _resume_failure("Canonical attack entity reference is missing.")
	var attacker_token: Variant = ship_token_for_instance.call(attacker) \
			if attack.attacker_kind == CurrentAttackState.KIND_SHIP \
			else squadron_token_for_instance.call(attacker)
	var defender_token: Variant = ship_token_for_instance.call(defender) \
			if attack.defender_kind == CurrentAttackState.KIND_SHIP \
			else squadron_token_for_instance.call(defender)
	if attack.attacker_kind == CurrentAttackState.KIND_SHIP \
			and not attacker_token is ShipToken:
		return _resume_failure("Canonical attacking ship has no board token.")
	if attack.attacker_kind == CurrentAttackState.KIND_SQUADRON \
			and not attacker_token is SquadronToken:
		return _resume_failure("Canonical attacking squadron has no board token.")
	if attack.defender_kind == CurrentAttackState.KIND_SHIP \
			and not defender_token is ShipToken:
		return _resume_failure("Canonical defending ship has no board token.")
	if attack.defender_kind == CurrentAttackState.KIND_SQUADRON \
			and not defender_token is SquadronToken:
		return _resume_failure("Canonical defending squadron has no board token.")
	return {
		RESUME_KEY_OK: true,
		"attacker": attacker,
		"defender": defender,
		"attacker_token": attacker_token,
		"defender_token": defender_token,
	}


func _resume_entity(game_state: GameState, kind: String,
		owner: int, index: int) -> RefCounted:
	if kind == CurrentAttackState.KIND_SHIP:
		return game_state.get_ship(owner, index)
	if kind == CurrentAttackState.KIND_SQUADRON:
		return game_state.get_squadron(owner, index)
	return null


func _install_resume_scene_references(
		attack: CurrentAttackState, refs: Dictionary) -> void:
	_clear_projected_participants()
	_state.exec_mode = true
	_state.squad_exec_mode = \
			attack.attacker_kind == CurrentAttackState.KIND_SQUADRON
	_state.attack_kind = attack.attack_kind
	_state.attacker_zone = attack.attacker_zone
	_state.defender_zone = attack.defender_zone
	if attack.attacker_kind == CurrentAttackState.KIND_SHIP:
		_state.exec_ship_token = refs.get("attacker_token") as ShipToken
		_state.attacker_ship = _state.exec_ship_token
		_state.attacker_name = _ship_instance_name(
				refs.get("attacker") as ShipInstance)
		_state.attacker_zone_name = str(_ZONE_NAMES.get(
				attack.attacker_zone, ""))
	else:
		_state.exec_squad_token = refs.get("attacker_token") as SquadronToken
		_state.attacker_squadron = _state.exec_squad_token
		_state.attacker_name = _squadron_instance_name(
				refs.get("attacker") as SquadronInstance)
	if attack.defender_kind == CurrentAttackState.KIND_SHIP:
		_state.defender_ship = refs.get("defender_token") as ShipToken
		_state.defender_name = _ship_instance_name(
				refs.get("defender") as ShipInstance)
		_state.defender_zone_name = str(_ZONE_NAMES.get(
				attack.defender_zone, ""))
	else:
		_state.defender_squadron = refs.get("defender_token") as SquadronToken
		_state.defender_name = _squadron_instance_name(
				refs.get("defender") as SquadronInstance)


func _clear_projected_participants() -> void:
	_state.exec_ship_token = null
	_state.exec_squad_token = null
	_state.attacker_ship = null
	_state.attacker_squadron = null
	_state.defender_ship = null
	_state.defender_squadron = null
	_state.attacker_name = ""
	_state.attacker_zone_name = ""
	_state.defender_name = ""
	_state.defender_zone_name = ""


func _derive_resume_plan(game_state: GameState,
		attack: CurrentAttackState) -> Dictionary:
	var plan: Dictionary = {
		RESUME_KEY_OK: true,
		RESUME_KEY_REASON: "",
		RESUME_KEY_ATTACK_ID: attack.attack_id,
		RESUME_KEY_REQUIRES_INPUT: true,
		"stage": attack.stage,
		"defense_stage": attack.defense_stage,
		"controller_player": attack.attacker_player,
	}
	match attack.stage:
		CurrentAttackState.STAGE_PRE_ROLL:
			plan["flow_step"] = AttackFlowFSM.Step.ROLL
			return _derive_pre_roll_resume_plan(attack, plan)
		CurrentAttackState.STAGE_ATTACK_MODIFY:
			plan["flow_step"] = AttackFlowFSM.Step.MODIFY
			if game_state.timing_window_state.active:
				plan[RESUME_KEY_TRANSITION] = RESUME_TIMING_WINDOW
				return plan
			if attack.attacker_kind == CurrentAttackState.KIND_SHIP:
				return _resume_failure(
						"Ship Attack Modify has no timing lifecycle.")
			plan[RESUME_KEY_TRANSITION] = RESUME_CONFIRM
			return plan
		CurrentAttackState.STAGE_ACCURACY:
			plan["flow_step"] = AttackFlowFSM.Step.MODIFY
			plan[RESUME_KEY_TRANSITION] = RESUME_ACCURACY
			plan[RESUME_KEY_REQUIRES_INPUT] = _accuracy_resume_requires_input()
			return plan
		CurrentAttackState.STAGE_DEFENSE:
			plan["flow_step"] = AttackFlowFSM.Step.DEFENSE_TOKENS
			return _derive_defense_resume_plan(game_state, attack, plan)
		CurrentAttackState.STAGE_RESOLVED:
			plan["flow_step"] = AttackFlowFSM.Step.RESOLVE_DAMAGE
			plan[RESUME_KEY_TRANSITION] = RESUME_AWAIT_RECORDED_COMPLETION
			plan[RESUME_KEY_REQUIRES_INPUT] = true
			return plan
		CurrentAttackState.STAGE_DAMAGE:
			return _resume_failure(
					"Current attack has no command-owned transition from damage stage.")
	return _resume_failure("Unsupported canonical current-attack stage.")


func _derive_pre_roll_resume_plan(
		attack: CurrentAttackState, plan: Dictionary) -> Dictionary:
	var context: EffectContext = _derive_gather_dice_context()
	var rule_id: String = str(context.get_meta_value(
			EffectContext.META_PENDING_DIE_REMOVAL_RULE_ID, ""))
	if not rule_id.is_empty() and not attack.resolved_pool_choices.has(rule_id):
		var available: Array[String] = _metadata_die_colours(
				context.get_meta_value(
						EffectContext.META_AVAILABLE_DIE_COLOURS, []))
		if not available.is_empty():
			plan[RESUME_KEY_TRANSITION] = RESUME_RULE_CHOICE
			plan[RESUME_KEY_REQUIRES_INPUT] = available.size() > 1
			plan["choice_kind"] = "rule"
			plan["rule_id"] = rule_id
			plan["choice_title"] = str(context.get_meta_value(
					EffectContext.META_PENDING_DIE_REMOVAL_TITLE,
					"Remove 1 die:"))
			plan["available_colours"] = available
			return plan
	if attack.obstructed and not attack.obstruction_resolved:
		var obstruction_colours: Array[String] = _pool_colours(attack.dice_pool)
		if obstruction_colours.is_empty():
			return _resume_failure("Obstructed attack has no removable die.")
		plan[RESUME_KEY_TRANSITION] = RESUME_RULE_CHOICE
		plan[RESUME_KEY_REQUIRES_INPUT] = obstruction_colours.size() > 1
		plan["choice_kind"] = ResolveAttackPoolChoiceCommand.REASON_OBSTRUCTION
		plan["rule_id"] = ""
		plan["available_colours"] = obstruction_colours
		return plan
	if attack.cf_dial_resolution == CurrentAttackState.RESOLUTION_PENDING:
		plan[RESUME_KEY_TRANSITION] = RESUME_CF_DIAL
		plan["available_colours"] = _get_cf_dial_colours(attack.dice_pool)
		return plan
	plan[RESUME_KEY_TRANSITION] = RESUME_ROLL
	return plan


func _derive_defense_resume_plan(game_state: GameState,
		attack: CurrentAttackState, plan: Dictionary) -> Dictionary:
	plan["controller_player"] = attack.defender_player
	_state.defense_step = true
	if attack.defense_stage == CurrentAttackState.DEFENSE_PENDING:
		plan[RESUME_KEY_TRANSITION] = RESUME_DEFENSE
		var defender: RefCounted = _get_canonical_defender()
		plan[RESUME_KEY_REQUIRES_INPUT] = defender != null \
				and (_defense_resolver.can_spend_tokens(
						defender, attack.accuracy_locked_tokens,
						attack.defender_zone) \
					or (defender is ShipInstance \
						and _resume_has_ecm_choice(game_state, attack)))
		return plan
	if attack.defense_stage == CurrentAttackState.DEFENSE_COMPLETE:
		plan["controller_player"] = attack.attacker_player
		plan[RESUME_KEY_TRANSITION] = RESUME_DAMAGE
		plan[RESUME_KEY_REQUIRES_INPUT] = false
		return plan
	if attack.defense_stage != CurrentAttackState.DEFENSE_RESOLVING:
		return _resume_failure("Unsupported canonical defense stage.")
	var token_index: int = _next_canonical_defense_token(attack)
	var defender: RefCounted = _get_canonical_defender()
	var tokens: Array[Dictionary] = _defense_tokens(defender)
	if defender == null or token_index < 0 \
			or token_index >= tokens.size():
		return _resume_failure("Canonical defense queue is inconsistent.")
	var token: Dictionary = tokens[token_index]
	var token_type: int = int(token.get("type", -1))
	var token_state: int = int(token.get("state", -1))
	plan["token_index"] = token_index
	plan["token_type"] = token_type
	if token_type == int(Constants.DefenseToken.EVADE) \
			and token_state != int(Constants.DefenseTokenState.READY):
		_state.evade_step = true
		plan[RESUME_KEY_TRANSITION] = RESUME_EVADE
		return plan
	if token_type == int(Constants.DefenseToken.REDIRECT) \
			and token_state != int(Constants.DefenseTokenState.READY):
		_state.redirect_step = true
		_state.redirect_remaining = attack.derive_damage(game_state)
		plan[RESUME_KEY_TRANSITION] = RESUME_REDIRECT
		plan["redirect_remaining"] = _state.redirect_remaining
		plan["redirect_adjacent_zones"] = _adjacent_zone_ints(
				attack.defender_zone)
		return plan
	if token_state == int(Constants.DefenseTokenState.DISCARDED):
		return _resume_failure("Unresolved simple defense token is discarded.")
	plan[RESUME_KEY_TRANSITION] = RESUME_SPEND_DEFENSE
	plan[RESUME_KEY_REQUIRES_INPUT] = false
	return plan


func _accuracy_resume_requires_input() -> bool:
	var parts: CombatParticipants = _build_current_participants()
	var result: Dictionary = _dice_resolver.resolve_accuracy_spend(
			_state.dice_results, parts)
	if int(result.get("spendable_accuracy_count", 0)) <= 0:
		return false
	var defender: RefCounted = _get_canonical_defender()
	return defender != null and _count_lockable_tokens(defender) > 0


func _resume_has_ecm_choice(game_state: GameState,
		attack: CurrentAttackState) -> bool:
	var payload: Dictionary = {
		"attacker_player": attack.attacker_player,
		"attacker_ship_index": attack.attacker_index \
				if attack.attacker_kind == CurrentAttackState.KIND_SHIP else -1,
		"attacker_squadron_index": attack.attacker_index \
				if attack.attacker_kind == CurrentAttackState.KIND_SQUADRON else -1,
		"defender_player": attack.defender_player,
		"defender_ship_index": attack.defender_index,
		"defender_zone": attack.defender_zone,
	}
	var flow: InteractionFlow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			attack.defender_player,
			Constants.Visibility.ALL,
			payload)
	return not ECM_SCRIPT.choice_payload(game_state, flow).is_empty()


func _build_resume_projection(game_state: GameState,
		attack: CurrentAttackState, plan: Dictionary) -> Dictionary:
	var payload: Dictionary = _compute_attack_identity_patch()
	payload["attack_id"] = attack.attack_id
	payload["range_band"] = attack.range_band
	payload["dice_pool"] = attack.dice_pool
	payload["dice_results"] = attack.dice_results
	payload["is_obstructed"] = attack.obstructed
	payload["locked_tokens"] = attack.accuracy_locked_tokens
	payload["modified_damage"] = attack.derive_damage(game_state)
	var defender: RefCounted = _get_canonical_defender()
	if defender != null:
		payload.merge(_flow_executor.build_defense_payload(
				_state, defender, game_state, _defense_resolver), true)
	if str(plan.get(RESUME_KEY_TRANSITION, "")) == RESUME_RULE_CHOICE:
		payload["pending_die_removal"] = {
			"rule_id": str(plan.get("rule_id", "")),
			"title": str(plan.get("choice_title", "Remove 1 die:")),
			"available_colours": _string_values(
					plan.get("available_colours", [])),
			"controller_player": attack.attacker_player,
		}
	if str(plan.get(RESUME_KEY_TRANSITION, "")) == RESUME_EVADE:
		payload["evade_active"] = true
		payload["evade_range_band"] = attack.range_band
	if str(plan.get(RESUME_KEY_TRANSITION, "")) == RESUME_REDIRECT:
		payload["redirect_active"] = true
		payload["redirect_adjacent_zones"] = plan.get(
				"redirect_adjacent_zones", [])
		payload["redirect_remaining"] = int(plan.get(
				"redirect_remaining", 0))
	return payload


func _render_resume_projection(plan: Dictionary) -> void:
	var local_player: int = NetworkManager.get_local_player_index()
	if local_player >= 0 and local_player != _get_attacker_player():
		return
	var panel: AttackSimPanel = _target_selector.ensure_panel_for_projection()
	if panel == null:
		return
	_connect_attack_panel_signals()
	if _state.squad_exec_mode:
		panel.show_initial_squadron_exec(_state.attacker_name)
	else:
		panel.show_initial_attack_exec(_state.attacker_name)
	panel.show_target_selected(
			_state.attacker_name, _state.attacker_zone_name,
			_state.defender_name, _state.defender_zone_name,
			DicePool.format_pool(_state.dice_pool), _state.range_band)
	panel.hide_skip_attack_button()
	if not _state.dice_results.is_empty():
		panel.show_dice_results(_state.dice_results)
	match str(plan.get(RESUME_KEY_TRANSITION, "")):
		RESUME_RULE_CHOICE:
			var colours: Array[String] = _string_values(
					plan.get("available_colours", []))
			if str(plan.get("choice_kind", "")) \
					== ResolveAttackPoolChoiceCommand.REASON_OBSTRUCTION:
				_state.obstruction_step = true
				panel.show_obstruction_die_choice(colours)
			else:
				_attack_pool_die_choice_rule_id = str(plan.get("rule_id", ""))
				panel.show_attack_pool_die_choice(
						_attack_pool_die_choice_rule_id,
						str(plan.get("choice_title", "Remove 1 die:")), colours)
		RESUME_CF_DIAL:
			panel.show_cf_dial_section(_string_values(
					plan.get("available_colours", [])))
		RESUME_ROLL:
			panel.show_roll_button()
		RESUME_CONFIRM:
			panel.show_confirm_button()
		RESUME_ACCURACY:
			_state.accuracy_step = true
			if bool(plan.get(RESUME_KEY_REQUIRES_INPUT, false)):
				var defender: RefCounted = _get_canonical_defender()
				var parts: CombatParticipants = _build_current_participants()
				var result: Dictionary = _dice_resolver.resolve_accuracy_spend(
						_state.dice_results, parts)
				panel.show_accuracy_section(
						_defense_tokens(defender),
						int(result.get("spendable_accuracy_count", 0)))
		RESUME_DEFENSE, RESUME_SPEND_DEFENSE, RESUME_EVADE, RESUME_REDIRECT:
			var defender: RefCounted = _get_canonical_defender()
			if defender != null:
				_show_defense_section(defender)
			if str(plan.get(RESUME_KEY_TRANSITION, "")) == RESUME_EVADE:
				panel.show_evade_die_selection(
						_state.range_band, local_player < 0)
			elif str(plan.get(RESUME_KEY_TRANSITION, "")) == RESUME_REDIRECT:
				panel.show_redirect_section(
						plan.get("redirect_adjacent_zones", []) as Array,
						int(plan.get("redirect_remaining", 0)), local_player < 0)


func _pool_colours(pool: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key: String in [DicePool.RED_KEY, DicePool.BLUE_KEY, DicePool.BLACK_KEY]:
		if int(pool.get(key, 0)) > 0:
			result.append(key)
	return result


func _adjacent_zone_ints(zone: int) -> Array[int]:
	var result: Array[int] = []
	for raw_zone: Variant in ConstantsScript.get_adjacent_hull_zones(
			zone as Constants.HullZone):
		result.append(int(raw_zone))
	return result


func _string_values(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw is Array:
		for value: Variant in raw as Array:
			result.append(str(value))
	return result


func _ship_instance_name(ship: ShipInstance) -> String:
	if ship != null and ship.ship_data != null:
		return ship.ship_data.ship_name
	return "Ship"


func _squadron_instance_name(squadron: SquadronInstance) -> String:
	if squadron != null and squadron.squadron_data != null:
		return squadron.squadron_data.squadron_name
	return "Squadron"


func _resume_failure(reason: String) -> Dictionary:
	return {
		RESUME_KEY_OK: false,
		RESUME_KEY_REASON: reason,
	}

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
	# Preview is transient. Keep the canonical Ship Activation / Attack-step
	# route unchanged until Begin or Skip is accepted.
	_flow_fsm.begin(null,
			_get_attacker_player(), -1, {})
	_target_selector.enter_attacker_selection(true, _get_ship_name())
	_wire_attack_done_and_panel_signals()
	var panel: AttackSimPanel = _get_panel()
	if panel:
		panel.show_skip_attack_button()
	# Auto-skip if no valid targets exist from any hull zone.
	## Rules Reference: "Attack", p.2 — a ship is not required to attack.
	if not _attack_exec_has_any_valid_target():
		_auto_skip_ship_attack(panel)
		return
	_target_selector.show_ship_range_overlay(_state.exec_ship_token)
	_log.info("Attack execution: range overlay shown, awaiting hull zone.")


## Connects the attack-panel "Done" button to
## [method _finish_attack_execution] (idempotent) and wires every
## attack-panel signal in one place.  Shared between ship and
## squadron entry points.
func _wire_attack_done_and_panel_signals() -> void:
	var panel: AttackSimPanel = _get_panel()
	if panel and not panel.attack_done_pressed.is_connected(
			_finish_attack_execution):
		panel.attack_done_pressed.connect(_finish_attack_execution)
	_connect_attack_panel_signals()


## Auto-skip branch of [method start_ship_attack]: submits a
## [SkipAttackCommand] with reason `"no_targets"` and waits for acceptance
## before any presentation teardown.
func _auto_skip_ship_attack(panel: AttackSimPanel) -> void:
	_log.info("No valid targets from any hull zone — auto-skipping.")
	_pending_declaration_command = "skip_attack"
	_target_selector.set_declaration_submission_pending(true)
	_pending_finish_after_skip = true
	var result: Dictionary = GameManager.submit_skip_attack(
			_get_attacker_player(), "no_targets")
	if _is_waiting_for_remote_command_result(result):
		return
	if result.is_empty():
		_pending_finish_after_skip = false
		_restore_declaration_after_rejection(
				"Automatic declaration Skip was rejected.")
		if panel:
			panel.show_skip_attack_button()
		return
	apply_skip_attack_result(result)

## Initialises attack execution state for a ship attacker.
func _init_ship_attack_state(ship_token: ShipToken) -> void:
	_flow_executor.init_ship_exec_state(_state, ship_token)
	_sync_ship_attack_progress_from_authority()

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
	_pre_begin_squadron_selection = true
	# Target choice is transient until BeginAttackCommand succeeds. Advance the
	# local FSM only; do not publish an ATTACK InteractionFlow that contradicts
	# inactive CurrentAttackState.
	_flow_fsm.begin(null,
			_get_attacker_player(), -1, {})
	_target_selector.enter_squadron_target_selection(squadron_token)
	_wire_attack_done_and_panel_signals()
	var panel: AttackSimPanel = _get_panel()
	if panel:
		panel.show_initial_squadron_exec(_state.attacker_name)
		panel.show_skip_attack_button()
	_log.info("Squadron attack: target selection active for %s."
			% _state.attacker_name)

## Initialises attack execution state for a squadron attacker.
func _init_squadron_attack_state(
		squadron_token: SquadronToken) -> void:
	_flow_executor.init_squadron_exec_state(_state, squadron_token)

## Dismisses the attack executor, delegating visual cleanup to TargetSelector.
## Requirements: AS-ACT-003, AS-PNL-003, AS-TGT-022.
func dismiss() -> void:
	_target_selector.dismiss()
	_log.info("Attack executor dismissed.")


## Removes the primary attacker presentation without mutating canonical attack
## or interaction-flow state. Used when this peer does not own the canonical
## attacker role. Attacker-only panel callbacks are disconnected before the
## transient executor state is cleared.
func deactivate_primary_presentation() -> void:
	_disconnect_attack_panel_signals()
	var panel: AttackSimPanel = _get_panel()
	if panel != null and panel.attack_done_pressed.is_connected(
			_finish_attack_execution):
		panel.attack_done_pressed.disconnect(_finish_attack_execution)
	if _target_selector != null and _target_selector.is_active():
		dismiss()
	_reset_exec_state()
	_flow_fsm.reset()


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


## Whether this executor is presenting a canonical ship Attack step. This is a
## projection-lifecycle query only; command validation retains gameplay authority.
func owns_authoritative_ship_attack_presentation() -> bool:
	var ship: ShipInstance = _authoritative_attack_ship()
	return _state.exec_mode and ship != null and ship.attack_step_active

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
	_attack_pool_die_choice_rule_id = ""
	_pending_begin_range = ""
	_pending_declaration_command = ""
	_pre_begin_squadron_selection = false
	_applied_damage_attack_id = ""
	_pending_finalize_after_completion = false
	_pending_counter_begin = false
	_pending_finish_after_skip = false
	_pending_squadron_done_after_skip = false
	_pending_zero_squad_skip = false
	_defense_command_pending = false
	_defense_submit_in_progress = false
	_awaiting_result_acknowledgement = false
	_reconstructed_current_attack = false
	_state.clear_all()

## Resets deferred damage card state.
func _reset_deferred_damage_state() -> void:
	_state.reset_deferred_damage()

## Completes the attack execution step. Cleans up and signals GameBoard.
## Requirements: AE-FLOW-003, AE-CONF-002.
func _finish_attack_execution() -> void:
	var game_state: GameState = GameManager.current_game_state
	var was_pre_begin_squadron_selection: bool = \
			_pre_begin_squadron_selection
	var preserve_ship_maneuver_projection: bool = \
			_has_open_ship_maneuver_projection(game_state)
	assert(game_state == null or not game_state.current_attack_state.active,
			"Attack execution cannot end while CurrentAttackState is active.")
	assert(game_state == null or not game_state.timing_window_state.active,
			"Attack execution cannot end while TimingWindowState is active.")
	_log.info("Attack execution done — completing attack step.")
	dismiss()
	_reset_exec_state()
	# A pre-Begin squadron skip completes the enclosing procedural action but
	# never owned canonical attack flow, so it must not clear that flow.
	if not was_pre_begin_squadron_selection \
			and not preserve_ship_maneuver_projection:
		_flow_fsm.end(GameManager.current_game_state)
	_flow_fsm.reset()
	if not was_pre_begin_squadron_selection \
			and not preserve_ship_maneuver_projection:
		_publish_flow_snapshot()
	attack_exec_completed.emit()


func _has_open_ship_maneuver_projection(game_state: GameState) -> bool:
	if game_state == null or game_state.interaction_flow == null \
			or game_state.interaction_flow.flow_type \
					!= Constants.InteractionFlow.SHIP_ACTIVATION \
			or game_state.interaction_flow.step_id \
					!= Constants.InteractionStep.MANEUVER_STEP:
		return false
	var ship: ShipInstance = GameManager.get_activating_ship()
	return ship != null and not ship.attack_step_active \
			and ship.maneuver_opportunity_disposition \
					== ShipInstance.ACTIVATION_DISPOSITION_OPEN

## Builds a [CombatParticipants] from the current attacker/target state.
func _build_current_participants() -> CombatParticipants:
	return _target_selector.build_current_participants()

## Returns the damage total for the current dice pool, using the correct
## formula for the combatant types. Critical icons only count as damage when
## both attacker and defender are ships; if either combatant is a squadron
## the no-critical formula is used.
## After the base calculation, RuleRegistry damage modifiers can adjust the
## total.
## Rules Reference: "Dice Icons", p.5 — "Critical: If the attacker and
## defender are ships, this icon adds one damage to the damage total."
func _calc_attack_damage(results: Array[Dictionary]) -> int:
	var parts: CombatParticipants = _build_current_participants()
	return _dice_resolver.calc_damage(results, parts)

## Returns the ship display name for the exec ship.
func _get_ship_name() -> String:
	if _state.exec_ship_token and _state.exec_ship_token.get_ship_data():
		return _state.exec_ship_token.get_ship_data().ship_name
	return ""


func _should_show_local_attack_controls() -> bool:
	var local_player: int = NetworkManager.get_local_player_index()
	if local_player < 0:
		return true
	return local_player == _get_attacker_player()


func _current_attack() -> CurrentAttackState:
	var game_state: GameState = GameManager.current_game_state
	return game_state.current_attack_state if game_state != null else null


## Refreshes legacy scene state as a one-way presentation mirror.
func _sync_scene_from_current_attack() -> void:
	var attack: CurrentAttackState = _current_attack()
	if attack == null or not attack.active:
		return
	_sync_projected_participants(attack)
	_sync_ship_attack_progress_from_authority()
	_state.range_band = attack.range_band
	_state.obstructed = attack.obstructed
	_state.dice_pool = attack.dice_pool
	_state.dice_results = attack.dice_results
	_state.cf_dial_used = attack.cf_dial_resolution in [
		CurrentAttackState.RESOLUTION_USED,
		CurrentAttackState.RESOLUTION_DECLINED,
	]
	_state.cf_token_used = attack.cf_token_resolution in [
		CurrentAttackState.RESOLUTION_USED,
		CurrentAttackState.RESOLUTION_DECLINED,
	]
	_state.locked_tokens = attack.accuracy_locked_tokens
	_state.modified_damage = attack.derive_damage(GameManager.current_game_state)
	_state.scatter_used = _has_resolved_defense_effect(
			attack, Constants.DefenseToken.SCATTER)
	_state.brace_used = _has_resolved_defense_effect(
			attack, Constants.DefenseToken.BRACE)
	_state.contain_used = _has_resolved_defense_effect(
			attack, Constants.DefenseToken.CONTAIN)
	_state.redirect_remaining = _state.modified_damage
	_state.accuracy_step = attack.stage == CurrentAttackState.STAGE_ACCURACY \
			and not attack.accuracy_complete
	_state.defense_step = attack.stage == CurrentAttackState.STAGE_DEFENSE \
			and attack.defense_stage != CurrentAttackState.DEFENSE_COMPLETE
	_state.obstruction_step = attack.stage == CurrentAttackState.STAGE_PRE_ROLL \
			and attack.obstructed and not attack.obstruction_resolved


## Re-renders canonical current-attack dice through the existing scene mirror.
## This is presentation-only: the canonical state remains owned and mutated by
## semantic commands on CurrentAttackState.
func refresh_current_attack_dice_projection() -> void:
	if not is_in_exec_mode():
		return
	_sync_scene_from_current_attack()
	var panel: AttackSimPanel = _get_panel()
	if panel == null:
		return
	if _state.dice_results.is_empty():
		panel.hide_dice_results()
	else:
		panel.show_dice_results(_state.dice_results)


## Refreshes scene-local attack counters and token references as a one-way
## projection of the activating ShipInstance's serialized progress.
func _sync_ship_attack_progress_from_authority() -> void:
	var ship: ShipInstance = _authoritative_attack_ship()
	if ship == null or not ship.attack_step_active:
		return
	_state.fired_zones.assign(ship.used_attack_hull_zones)
	_state.current_attack = ship.committed_attack_count
	_state.attacked_squads.clear()
	var game_state: GameState = GameManager.current_game_state
	if game_state != null and _target_selector != null:
		for target: Dictionary in ship.anti_squadron_target_history:
			var squadron: SquadronInstance = game_state.get_squadron(
					int(target.get("owner", -1)), int(target.get("index", -1)))
			if squadron == null:
				continue
			var token: SquadronToken = \
					_target_selector.squadron_token_for_instance(squadron)
			if token != null:
				_state.attacked_squads.append(token)
	if ship.anti_squadron_attack_zone >= 0:
		_state.attacker_zone = ship.anti_squadron_attack_zone
		_state.attacker_zone_name = str(_ZONE_NAMES.get(
				ship.anti_squadron_attack_zone, ""))


func _authoritative_attack_ship() -> ShipInstance:
	if _state.exec_ship_token == null:
		return null
	return _state.exec_ship_token.get_ship_instance()


func _sync_projected_participants(attack: CurrentAttackState) -> void:
	if _target_selector == null:
		return
	var game_state: GameState = GameManager.current_game_state
	var refs: Dictionary = _resolve_resume_references(
			game_state, attack,
			Callable(_target_selector, "ship_token_for_instance"),
			Callable(_target_selector, "squadron_token_for_instance"))
	if bool(refs.get(RESUME_KEY_OK, false)):
		_install_resume_scene_references(attack, refs)
	else:
		_log.warn("Canonical participant projection failed: %s" % [
				str(refs.get(RESUME_KEY_REASON, "unknown reason"))])


func _has_resolved_defense_effect(attack: CurrentAttackState,
		token_type: int) -> bool:
	for effect: Dictionary in attack.resolved_defense_effects:
		if int(effect.get("token_type", -1)) == token_type:
			return true
	return false


func _build_begin_attack_payload(
		range_band: String,
		declaration_candidate: Dictionary = {}) -> Dictionary:
	if not declaration_candidate.is_empty():
		return {
			"attacker_player": int(declaration_candidate.get(
					"attacker_player", -1)),
			"attacker_kind": str(declaration_candidate.get(
					"attacker_kind", "")),
			"attacker_index": int(declaration_candidate.get(
					"attacker_index", -1)),
			"attacker_zone": int(declaration_candidate.get(
					"attacker_zone", -1)),
			"defender_player": int(declaration_candidate.get(
					"defender_player", -1)),
			"defender_kind": str(declaration_candidate.get(
					"defender_kind", "")),
			"defender_index": int(declaration_candidate.get(
					"defender_index", -1)),
			"defender_zone": int(declaration_candidate.get(
					"defender_zone", -1)),
			"attack_kind": str(declaration_candidate.get(
					"attack_kind",
					SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD)),
			"range_band": range_band,
			"obstructed": bool(declaration_candidate.get(
					"obstructed", false)),
		}
	var identity: Dictionary = _compute_attack_identity_patch()
	var attacker_kind: String = str(identity.get("attacker_kind", ""))
	var defender_kind: String = str(identity.get("target_kind", ""))
	return {
		"attacker_player": int(identity.get("attacker_player", -1)),
		"attacker_kind": attacker_kind,
		"attacker_index": int(identity.get(
				"attacker_ship_index" if attacker_kind == "ship" \
				else "attacker_squadron_index", -1)),
		"attacker_zone": int(identity.get("attacker_zone", -1)),
		"defender_player": int(identity.get("defender_player", -1)),
		"defender_kind": defender_kind,
		"defender_index": int(identity.get(
				"target_ship_index" if defender_kind == "ship" \
				else "target_squadron_index", -1)),
		"defender_zone": int(identity.get("defender_zone", -1)),
		"attack_kind": str(identity.get(
				SquadronKeywordRuleHelper.PAYLOAD_ATTACK_KIND,
				SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD)),
		"range_band": range_band,
		"obstructed": _state.obstructed,
	}

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
	if not p.attack_pool_die_selected.is_connected(
			_on_attack_pool_die_selected):
		p.attack_pool_die_selected.connect(_on_attack_pool_die_selected)
	if not p.roll_dice_pressed.is_connected(_on_attack_roll_dice):
		p.roll_dice_pressed.connect(_on_attack_roll_dice)
	if not p.cf_token_reroll_requested.is_connected(
			_on_attack_cf_token_reroll):
		p.cf_token_reroll_requested.connect(_on_attack_cf_token_reroll)
	if not p.cf_token_reroll_skipped.is_connected(
			_on_attack_cf_token_skipped):
		p.cf_token_reroll_skipped.connect(_on_attack_cf_token_skipped)
	if not p.counter_attack_requested.is_connected(_on_counter_attack_requested):
		p.counter_attack_requested.connect(_on_counter_attack_requested)
	if not p.counter_attack_skipped.is_connected(_on_counter_attack_skipped):
		p.counter_attack_skipped.connect(_on_counter_attack_skipped)
	if not p.declaration_confirm_pressed.is_connected(
			_on_declaration_confirm):
		p.declaration_confirm_pressed.connect(_on_declaration_confirm)
	if not p.confirm_pressed.is_connected(_on_attack_confirm):
		p.confirm_pressed.connect(_on_attack_confirm)
	if not p.result_confirmed.is_connected(_on_attack_result_confirmed):
		p.result_confirmed.connect(_on_attack_result_confirmed)
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
	if not p.ecm_use_requested.is_connected(_on_ecm_use_requested):
		p.ecm_use_requested.connect(_on_ecm_use_requested)
	if not p.ecm_decline_requested.is_connected(_on_ecm_decline_requested):
		p.ecm_decline_requested.connect(_on_ecm_decline_requested)
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


func _disconnect_attack_panel_signals() -> void:
	var panel: AttackSimPanel = _get_panel()
	if panel == null:
		return
	_disconnect_attack_sequence_signals(panel)
	_disconnect_defense_phase_signals(panel)


func _disconnect_attack_sequence_signals(panel: AttackSimPanel) -> void:
	_disconnect_panel_signal(panel.cf_dial_colour_selected,
			_on_attack_cf_dial_colour)
	_disconnect_panel_signal(panel.cf_dial_skipped, _on_attack_cf_dial_skipped)
	_disconnect_panel_signal(panel.obstruction_die_selected,
			_on_obstruction_die_selected)
	_disconnect_panel_signal(panel.attack_pool_die_selected,
			_on_attack_pool_die_selected)
	_disconnect_panel_signal(panel.roll_dice_pressed, _on_attack_roll_dice)
	_disconnect_panel_signal(panel.cf_token_reroll_requested,
			_on_attack_cf_token_reroll)
	_disconnect_panel_signal(panel.cf_token_reroll_skipped,
			_on_attack_cf_token_skipped)
	_disconnect_panel_signal(panel.counter_attack_requested,
			_on_counter_attack_requested)
	_disconnect_panel_signal(panel.counter_attack_skipped,
			_on_counter_attack_skipped)
	_disconnect_panel_signal(panel.declaration_confirm_pressed,
			_on_declaration_confirm)
	_disconnect_panel_signal(panel.confirm_pressed, _on_attack_confirm)
	_disconnect_panel_signal(panel.result_confirmed,
			_on_attack_result_confirmed)
	_disconnect_panel_signal(panel.skip_attack_pressed, _on_attack_skip)


func _disconnect_defense_phase_signals(panel: AttackSimPanel) -> void:
	_disconnect_panel_signal(panel.accuracy_confirmed,
			_on_attack_accuracy_confirmed)
	_disconnect_panel_signal(panel.defense_token_selected,
			_on_attack_defense_token_spent)
	_disconnect_panel_signal(panel.defense_tokens_done, _on_attack_defense_done)
	_disconnect_panel_signal(panel.ecm_use_requested, _on_ecm_use_requested)
	_disconnect_panel_signal(panel.ecm_decline_requested,
			_on_ecm_decline_requested)
	_disconnect_panel_signal(panel.redirect_zone_selected,
			_on_attack_redirect_zone_selected)
	_disconnect_panel_signal(panel.evade_die_confirmed, _on_evade_die_selected)
	_disconnect_panel_signal(panel.redirect_done_pressed,
			_on_redirect_done_early)


func _disconnect_panel_signal(panel_signal: Signal,
		callback: Callable) -> void:
	if panel_signal.is_connected(callback):
		panel_signal.disconnect(callback)


## Explicitly confirms the current transient declaration candidate.
func _on_declaration_confirm() -> void:
	if not is_in_exec_mode() or _state.attack_kind \
			== SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER:
		return
	if not _pending_declaration_command.is_empty():
		return
	var current: CurrentAttackState = _current_attack()
	if current != null and current.active:
		return
	var candidate: Dictionary = _target_selector.get_declaration_candidate()
	if candidate.is_empty():
		return
	_attack_exec_begin_sequence(
			str(candidate.get("range_band", "")), candidate)


## Begins the Phase 6b-2 attack sequence after explicit declaration Confirm,
## or from the separate rule-owned Counter path.
## Checks for a CF dial and starts the appropriate step.
## For squadron attackers, CF dials are not available — skip straight to roll.
## Requirements: AE-CF-001, AE-CF-002, SQA-ATK-001.
## Rules Reference: "Concentrate Fire", p.3 — "While attacking, the ship
## may add 1 die to its attack pool of a color that is already in its
## attack pool."
func _attack_exec_begin_sequence(
		range_band: String,
		declaration_candidate: Dictionary = {}) -> void:
	if _get_panel() == null:
		return
	if _state.exec_ship_token == null and _state.exec_squad_token == null:
		return
	_attack_pool_die_choice_rule_id = ""
	# --- Attack-target damage rules/effects (Depowered Armament, Coolant
	# Discharge, Disengaged Fire Control) — reject attack if blocked.
	# Rules Reference: RRG "Damage Cards", p.4; ET-001.
	if _is_attack_blocked_by_damage(range_band):
		return
	if not declaration_candidate.is_empty():
		_pending_declaration_command = "begin_attack"
		_target_selector.set_declaration_submission_pending(true)
	_pending_begin_range = range_band
	var begin_result: Dictionary = GameManager.submit_begin_attack(
			_get_attacker_player(), _build_begin_attack_payload(
					range_band, declaration_candidate))
	if _is_waiting_for_remote_command_result(begin_result):
		return
	if begin_result.is_empty():
		_pending_begin_range = ""
		if _pending_declaration_command == "begin_attack":
			_restore_declaration_after_rejection(
					"Begin attack was rejected.")
		return
	# A live CommandRouter may already have consumed the synchronous result.
	if not _pending_begin_range.is_empty():
		apply_begin_attack_result(begin_result)


func apply_begin_attack_result(_result: Dictionary) -> void:
	if _pending_begin_range.is_empty():
		return
	var range_band: String = _pending_begin_range
	_pending_begin_range = ""
	if _pending_declaration_command == "begin_attack":
		_complete_declaration_submission()
	_pre_begin_squadron_selection = false
	_sync_scene_from_current_attack()
	var gather_context: EffectContext = _derive_gather_dice_context()
	_publish_attack_declare_patch(range_band)
	_get_panel().hide_confirm_button()
	_get_panel().hide_skip_attack_button()
	if _handle_attack_pool_die_choice(gather_context):
		return
	# Empty pool guard: if no dice remain after gather-dice hooks, the
	# attack cannot be declared.
	# Rules Reference: "Attack", Step 1, p.2 — "The attacker must be
	# able to add at least one die to the attack pool."
	if DicePool.get_total_count(_state.dice_pool) <= 0:
		_handle_empty_attack_pool()
		return
	# Obstruction: attacker must remove 1 die before rolling.
	# Rules Reference: "Obstructed", RRG v1.5.0, p.10.
	# Requirements: AE-OBS-001, AE-OBS-002.
	if _state.obstructed:
		_handle_obstruction_step()
		return
	if _try_offer_cf_dial():
		return
	_attack_exec_show_roll_button()


## Applies a targeted network rejection without synthesizing a fallback
## transition. The prior transient candidate and declaration presentation stay
## available.
func apply_declaration_command_rejection(
		command: GameCommand, reason: String) -> void:
	if command != null and command.command_type == "skip_attack" \
			and _pending_squadron_done_after_skip:
		_pending_squadron_done_after_skip = false
		_log.info("Step 6 decline was rejected — %s" % reason)
		return
	if command == null \
			or command.command_type != _pending_declaration_command \
			or command.player_index != _get_attacker_player():
		return
	if command.command_type == "begin_attack":
		_pending_begin_range = ""
	elif command.command_type == "skip_attack":
		_pending_finish_after_skip = false
	_restore_declaration_after_rejection(reason)


func _restore_declaration_after_rejection(reason: String) -> void:
	_pending_declaration_command = ""
	_target_selector.set_declaration_submission_pending(false)
	_log.info("Declaration command rejected — %s" % reason)


func _complete_declaration_submission() -> void:
	_pending_declaration_command = ""
	_target_selector.set_declaration_submission_pending(false)
	_target_selector.clear_declaration_candidate()


## Builds and publishes the DECLARE-step patch (range band + dice pool +
## attacker/target identity) to [member InteractionFlow.payload] so the
## defender peer's mirror panel can resolve names + indices from the
## flow snapshot alone.  Phase I3b / I6b-3 R1a.
func _publish_attack_declare_patch(range_band: String) -> void:
	var declare_patch: Dictionary = _compute_attack_identity_patch()
	declare_patch["range_band"] = range_band
	declare_patch["dice_pool"] = _state.dice_pool.duplicate(true)
	declare_patch["is_obstructed"] = _state.obstructed
	declare_patch["ship_target_attacks_this_round"] = \
			_current_ship_target_attack_count()
	_fsm_patch_payload(declare_patch)


## Handles the empty-pool branch of [method _attack_exec_begin_sequence].
## During the Step 6 squadron loop the current target is auto-skipped;
## otherwise the panel shows the empty-pool auto-skip affordance.
## Rules Reference: "Attack", Step 1, p.2 — attacker must add at least
## one die.
func _handle_empty_attack_pool() -> void:
	_log.info("No dice in pool — cannot declare attack.")
	if _state.attacked_squads.size() > 0 and _state.defender_squadron:
		_auto_skip_zero_dice_squadron()
		return
	if _get_panel():
		_get_panel().show_empty_pool_auto_skip()


## Offers the CF dial colour selection when the attacker has an
## unspent CF command dial and at least one matching die colour in
## the pool.  Returns [code]true[/code] when the CF dial section was
## shown (caller must not advance to the roll step).
func _try_offer_cf_dial() -> bool:
	if _state.exec_ship_token == null or _state.cf_dial_used:
		return false
	if not _attack_exec_has_cf_dial():
		return false
	var available: Array[String] = _get_cf_dial_colours(_state.dice_pool)
	if available.is_empty():
		return false
	_get_panel().show_cf_dial_section(available)
	_log.info("CF dial available — offering colours: %s." % [str(available)])
	return true

## Re-derives gather metadata for presentation; BeginAttackCommand owns pool.
func _derive_gather_dice_context() -> EffectContext:
	var parts: CombatParticipants = _build_current_participants()
	return _dice_resolver.apply_gather_context(
			_state.dice_pool, parts)


## Handles mandatory pre-roll die-removal choices exposed by RuleRegistry.
## Returns true when the attack flow is waiting for player input.
func _handle_attack_pool_die_choice(context: EffectContext) -> bool:
	if context == null:
		return false
	var rule_id: String = str(context.get_meta_value(
			EffectContext.META_PENDING_DIE_REMOVAL_RULE_ID, ""))
	if rule_id == "":
		return false
	var available: Array[String] = _metadata_die_colours(
			context.get_meta_value(EffectContext.META_AVAILABLE_DIE_COLOURS, []))
	if available.is_empty():
		return false
	if available.size() == 1:
		_attack_pool_die_choice_rule_id = rule_id
		_apply_attack_pool_die_choice(rule_id, available[0])
		return true
	var title: String = str(context.get_meta_value(
			EffectContext.META_PENDING_DIE_REMOVAL_TITLE, "Remove 1 die:"))
	_attack_pool_die_choice_rule_id = rule_id
	_publish_attack_pool_die_pending_choice(rule_id, title, available)
	_get_panel().show_attack_pool_die_choice(
			rule_id, title, available)
	_log.info("%s: awaiting die choice from %s." % [rule_id, str(available)])
	return true


func _metadata_die_colours(raw_colours: Variant) -> Array[String]:
	var colours: Array[String] = []
	if not raw_colours is Array:
		return colours
	var colour_values: Array = raw_colours as Array
	for raw_colour: Variant in colour_values:
		var colour_key: String = str(raw_colour).to_upper()
		if colour_key != "" and int(_state.dice_pool.get(colour_key, 0)) > 0:
			colours.append(colour_key)
	return colours


func _publish_attack_pool_die_pending_choice(rule_id: String,
		title: String,
		available_colours: Array[String]) -> void:
	_fsm_patch_payload({
		"dice_pool": _state.dice_pool.duplicate(true),
		"pending_die_removal": {
			"rule_id": rule_id,
			"title": title,
			"available_colours": available_colours.duplicate(),
			"controller_player": _get_attacker_player(),
		},
	})


func _apply_attack_pool_die_choice(rule_id: String, colour_key: String) -> bool:
	var result: Dictionary = GameManager.submit_attack_pool_choice(
			_get_attacker_player(), "rule", colour_key, rule_id)
	if _is_waiting_for_remote_command_result(result):
		return true
	if result.is_empty():
		return false
	apply_attack_pool_choice_result(result)
	return true


func apply_attack_pool_choice_result(result: Dictionary) -> void:
	var choice_kind: String = str(result.get("choice_kind", ""))
	if choice_kind != "rule":
		return
	var rule_id: String = str(result.get("rule_id", ""))
	if _attack_pool_die_choice_rule_id != rule_id:
		return
	_sync_scene_from_current_attack()
	var removed: String = str(result.get("color", ""))
	_update_pool_after_attack_pool_die_choice(rule_id, removed)
	_attack_pool_die_choice_rule_id = ""
	_attack_exec_continue_after_attack_pool_die_choice()


func _update_pool_after_attack_pool_die_choice(rule_id: String,
		removed_colour: String) -> void:
	_log.info("%s: removed 1 %s die. Pool: %s." % [
			rule_id, removed_colour, DicePool.format_pool(_state.dice_pool)])
	if _get_panel():
		_get_panel().show_dice_count(DicePool.format_pool(_state.dice_pool))
		_get_panel().hide_obstruction_section()
	_fsm_patch_payload({
		"dice_pool": _state.dice_pool.duplicate(true),
		"pending_die_removal": {},
		"resolved_die_removal": {
			"rule_id": rule_id,
			"colour": removed_colour,
		},
	})


func _on_attack_pool_die_selected(reason_id: String, colour_key: String) -> void:
	if reason_id == "" or reason_id != _attack_pool_die_choice_rule_id:
		return
	if _attack_pool_die_choice_rule_id == "":
		return
	if not _apply_attack_pool_die_choice(reason_id, colour_key):
		return


func _attack_exec_continue_after_attack_pool_die_choice() -> void:
	if DicePool.get_total_count(_state.dice_pool) <= 0:
		_handle_empty_attack_pool()
		return
	if _state.obstructed:
		_handle_obstruction_step()
		return
	if _try_offer_cf_dial():
		return
	_attack_exec_show_roll_button()

## Checks whether a persistent damage-card rule blocks this attack.
## Builds an attack-target context with range, obstruction, and attack count.
## Returns true when a migrated RuleRegistry blocker rejects.
## Rules Reference: RRG "Damage Cards", p.4; "Coolant Discharge",
## "Depowered Armament", "Disengaged Fire Control".
func _is_attack_blocked_by_damage(range_band: String) -> bool:
	var parts: CombatParticipants = _build_current_participants()
	var blocked: bool = _dice_resolver.is_blocked_by_damage_at_range(
			parts, _state.obstructed,
			_current_ship_target_attack_count(), range_band)
	if blocked:
		_log.info("Attack blocked by damage card effect.")
		if _get_panel():
			_get_panel().show_attack_blocked_skip(
					"Attack blocked by damage card. Select another target or skip.")
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
	_state.obstruction_step = true
	var result: Dictionary = GameManager.submit_attack_pool_choice(
			_get_attacker_player(),
			ResolveAttackPoolChoiceCommand.REASON_OBSTRUCTION, colour_key)
	if _is_waiting_for_remote_command_result(result) or result.is_empty():
		return
	apply_obstruction_choice_result(result)


func apply_obstruction_choice_result(result: Dictionary) -> void:
	if not _state.obstruction_step:
		return
	_state.obstruction_step = false
	_sync_scene_from_current_attack()
	var colour_key: String = str(result.get("color", ""))
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
	var result: Dictionary = GameManager.submit_use_concentrate_fire_dial(
			_get_attacker_player(), colour_key)
	if _is_waiting_for_remote_command_result(result) or result.is_empty():
		return
	apply_concentrate_fire_dial_result(result)


func apply_concentrate_fire_dial_result(result: Dictionary) -> void:
	if _state.cf_dial_used:
		return
	_sync_scene_from_current_attack()
	_log.info("CF dial resolved: %s." % str(result.get("resolution", "")))
	# Update dice count display.
	if _get_panel():
		var dice_text: String = DicePool.format_pool(_state.dice_pool)
		_get_panel().show_dice_count(dice_text)
	# Proceed to roll.
	_attack_exec_show_roll_button()

## Called when the player skips the CF dial.
## Requirements: AE-CF-005.
func _on_attack_cf_dial_skipped() -> void:
	var result: Dictionary = GameManager.submit_decline_concentrate_fire_dial(
			_get_attacker_player())
	if _is_waiting_for_remote_command_result(result) or result.is_empty():
		return
	apply_concentrate_fire_dial_result(result)

## Called when the player presses "Roll Dice".
## Requirements: AE-DICE-001, AE-DICE-003, SFX-004, SFX-005, SFX-006.
func _on_attack_roll_dice() -> void:
	_fsm_advance(AttackFlowFSM.Step.ROLL)
	_log.info("Rolling dice: %s." % DicePool.format_pool(
			_state.dice_pool))
	# Play dice-roll SFX based on attacker type and faction.
	_play_dice_roll_sfx()
	# Submit dice roll via command for deterministic replay.
	var atk_player: int = _get_attacker_player()
	var roll_result: Dictionary = GameManager.submit_roll_dice(
			atk_player, _state.dice_pool, _build_roll_attack_context())
	# Network client: result arrives asynchronously via broadcast.
	# Wait for _apply_dice_roll_result() to be called from the
	# network command handler.
	if _is_waiting_for_remote_command_result(roll_result):
		return
	if roll_result.is_empty():
		return
	var attack: CurrentAttackState = _current_attack()
	if attack == null \
			or attack.stage != CurrentAttackState.STAGE_ATTACK_MODIFY \
			or _flow_fsm.current_step != AttackFlowFSM.Step.ROLL:
		return
	_apply_dice_roll_result(roll_result)


## Applies a dice roll result to the attack state and updates the UI.
## Called inline for host/hot-seat or from the network broadcast handler.
func _apply_dice_roll_result(roll_result: Dictionary) -> void:
	_fsm_advance(AttackFlowFSM.Step.MODIFY)
	_sync_scene_from_current_attack()
	# Phase I3b: publish dice results to interaction_flow.
	_fsm_patch_payload({
		"dice_results": _state.dice_results.duplicate(true),
	})
	# Show results.
	if _get_panel() and _should_show_local_attack_controls():
		_get_panel().hide_roll_button()
		_get_panel().show_dice_results(_state.dice_results)
	# Log results.
	var damage: int = _calc_attack_damage(_state.dice_results)
	_log.info("Dice rolled: %d dice, %d damage." % [
			_state.dice_results.size(), damage])
	var attack: CurrentAttackState = _current_attack()
	if attack != null \
			and attack.attacker_kind == CurrentAttackState.KIND_SHIP:
		return
	if _try_offer_swarm_reroll():
		return
	# Squadron attackers retain their procedural post-roll confirmation path.
	_attack_exec_show_confirm()


## Network callback: receives dice results from server broadcast.
## G4.6.5 — async dice resolution for network clients.
func _on_network_dice_result(result: Dictionary) -> void:
	if _state == null or not is_in_exec_mode() \
			or _flow_fsm.current_step != AttackFlowFSM.Step.ROLL:
		return
	var attack: CurrentAttackState = _current_attack()
	if attack == null or not attack.active \
			or attack.stage != CurrentAttackState.STAGE_ATTACK_MODIFY:
		return
	# Synchronous canonical projection may already have populated the scene dice
	# cache. The derived Roll -> Modify handoff is a separate presentation step.
	_apply_dice_roll_result(result)


## Plays the appropriate SFX for a dice roll based on whether the attacker
## is a ship (turbolasers) or squadron (rhythmic burst, faction-dependent).
## Requirements: SFX-004, SFX-005, SFX-006.
func _play_dice_roll_sfx() -> void:
	if _state.squad_exec_mode and _state.attacker_squadron:
		# Squadron attack — rhythmic burst.
		var inst: SquadronInstance = (
				_state.attacker_squadron.get_squadron_instance())
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

func _try_offer_swarm_reroll() -> bool:
	if _state.swarm_reroll_used or not _is_swarm_reroll_available():
		return false
	_pending_reroll_rule_id = SwarmKeyword.RULE_ID
	_state.swarm_reroll_used = true
	_publish_swarm_payload(true)
	if _get_panel() and _should_show_local_attack_controls():
		_get_panel().show_swarm_reroll_section()
	_log.info("Swarm available — offering one die reroll.")
	return true


func _is_swarm_reroll_available() -> bool:
	if not _state.attacker_squadron or not _state.defender_squadron:
		return false
	var attacker: SquadronInstance = \
			_state.attacker_squadron.get_squadron_instance()
	var target: SquadronInstance = \
			_state.defender_squadron.get_squadron_instance()
	return SquadronKeywordRuleHelper.is_swarm_eligible(
			attacker, _state.attacker_squadron.global_position,
			target, _state.defender_squadron.global_position,
			_build_attack_squadron_positions(),
			_build_attack_obstruction_bodies())


func _build_attack_squadron_positions() -> Array[Dictionary]:
	var positions: Array[Dictionary] = []
	if _target_selector == null:
		return positions
	for token: SquadronToken in _target_selector.get_squadron_tokens_callable().call():
		var inst: SquadronInstance = token.get_squadron_instance()
		if inst and not inst.is_destroyed():
			positions.append({"instance": inst, "position": token.global_position})
	return positions


func _build_attack_obstruction_bodies() -> Array:
	if _target_selector == null:
		return []
	return _target_selector.build_engagement_obstruction_bodies()


func _publish_swarm_payload(available: bool) -> void:
	var indices: Array[int] = []
	for index: int in range(_state.dice_results.size()):
		indices.append(index)
	_fsm_patch_payload({
		SwarmKeyword.PAYLOAD_AVAILABLE: available,
		SwarmKeyword.PAYLOAD_CONTROLLER_PLAYER: _get_attacker_player(),
		SwarmKeyword.PAYLOAD_DIE_INDICES: indices,
	})

## Legacy modifier-panel callback retained only for procedural Swarm.
func _on_attack_cf_token_reroll(die_index: int) -> void:
	if _pending_reroll_rule_id != SwarmKeyword.RULE_ID:
		return
	_on_attack_swarm_reroll(die_index)

## Legacy modifier-panel skip callback retained only for procedural Swarm.
func _on_attack_cf_token_skipped() -> void:
	if _pending_reroll_rule_id != SwarmKeyword.RULE_ID:
		return
	var result: Dictionary = GameManager.submit_skip_attack_modifier(
			_get_attacker_player(), SwarmKeyword.RULE_ID)
	if not _is_waiting_for_remote_command_result(result) \
			and not result.is_empty():
		_apply_attack_modifier_result(result)


func _on_attack_swarm_reroll(die_index: int) -> void:
	if die_index < 0 or die_index >= _state.dice_results.size():
		return
	var result: Dictionary = GameManager.submit_reroll_attack_die(
			_get_attacker_player(), die_index, _state.dice_results,
			SwarmKeyword.RULE_ID)
	if _is_waiting_for_remote_command_result(result):
		return
	if result.is_empty():
		return
	_apply_attack_modifier_result(result)


func _apply_attack_modifier_result(result: Dictionary) -> void:
	var source: String = str(result.get("source_rule_id", ""))
	if source != SwarmKeyword.RULE_ID \
			or _pending_reroll_rule_id != source:
		return
	_sync_scene_from_current_attack()
	var die_index: int = int(result.get("die_index", -1))
	var new_result: Dictionary = result.get("new_result", {}) as Dictionary
	if _get_panel():
		if die_index >= 0 and not new_result.is_empty():
			_get_panel().update_die_result(die_index, new_result)
		_get_panel().hide_cf_token_section()
	_pending_reroll_rule_id = ""
	_publish_swarm_payload(false)
	_fsm_patch_payload({"dice_results": _state.dice_results.duplicate(true)})
	_attack_exec_show_confirm()

## Shows the Confirm button after dice are finalised.
## Requirements: AE-CONF-001.
func _attack_exec_show_confirm() -> void:
	if _get_panel() and _should_show_local_attack_controls():
		_get_panel().show_confirm_button()
	var damage: int = _calc_attack_damage(_state.dice_results)
	_log.info("Final dice: %d damage. Awaiting confirm." % damage)


func _is_waiting_for_remote_command_result(result: Dictionary) -> bool:
	return bool(result.get("awaiting_remote", false))

## Called when the player presses "Confirm" to accept the dice results.
## Starts the accuracy spending step (Step 3), then defense (Step 4),
## then damage resolution (Step 5).
## Requirements: AE-CONF-002, AE-ACC-001, AE-DEF-001, AE-DMG-001.
## Rules Reference: "Attack", Steps 3–5.
func _on_attack_confirm() -> void:
	var result: Dictionary = GameManager.submit_confirm_attack_dice(
			_get_attacker_player())
	if _is_waiting_for_remote_command_result(result) or result.is_empty():
		return
	apply_attack_confirm_result(result)


func apply_attack_confirm_result(_result: Dictionary) -> void:
	var attack: CurrentAttackState = _current_attack()
	if attack == null or attack.stage != CurrentAttackState.STAGE_ACCURACY \
			or _state.accuracy_step:
		return
	_sync_scene_from_current_attack()
	var damage: int = _calc_attack_damage(_state.dice_results)
	_log.info(
			"Attack confirmed: %d damage. Starting Step 3 (accuracy)."
			% damage)
	if _get_panel():
		_get_panel().hide_confirm_button()
	_flow_executor.reset_for_confirm(_state, damage)
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
	var def_inst: RefCounted = _get_canonical_defender()
	if def_inst == null or acc_count == 0:
		_log.info("No accuracy icons or canonical defender — skipping "
				+"accuracy step.")
		_commit_accuracy_selection([])
		return
	var lockable: int = _count_lockable_tokens(def_inst)
	if lockable == 0:
		_log.info("Defender has no lockable tokens — skipping accuracy.")
		_commit_accuracy_selection([])
		return
	_log.info("Accuracy step: %d icons, %d lockable tokens." % [
			acc_count, lockable])
	if _get_panel():
		_get_panel().show_accuracy_section(
				_defense_tokens(def_inst), acc_count)
		_get_panel().hide_confirm_button()

## Counts accuracy icons, applying RuleRegistry accuracy blockers.
func _resolve_accuracy_count() -> int:
	var parts: CombatParticipants = _build_current_participants()
	var result: Dictionary = _dice_resolver.resolve_accuracy_spend(
			_state.dice_results, parts)
	_fsm_patch_payload({
		"accuracy_count": int(result.get("accuracy_count", 0)),
		"spendable_accuracy_count": int(result.get(
				"spendable_accuracy_count", 0)),
		"accuracy_spend_blocked": bool(result.get("blocked", false)),
	})
	if bool(result.get("blocked", false)):
		_log.info("Accuracy spending blocked by damage card effect.")
	return int(result.get("spendable_accuracy_count", 0))


func _current_ship_target_attack_count() -> int:
	var game_state: GameState = GameManager.current_game_state
	if game_state == null or _state.attacker_ship == null:
		return 0
	var attacker: ShipInstance = _state.attacker_ship.get_ship_instance()
	return game_state.get_ship_target_attack_count(attacker)


func _build_roll_attack_context() -> Dictionary:
	var identity: Dictionary = _compute_attack_identity_patch()
	return {
		"attacker_kind": str(identity.get("attacker_kind", "")),
		"attacker_player": int(identity.get("attacker_player", -1)),
		"attacker_ship_index": int(identity.get("attacker_ship_index", -1)),
		"attacker_squadron_index": int(identity.get(
				"attacker_squadron_index", -1)),
		"target_kind": str(identity.get("target_kind", "")),
		"target_ship_index": int(identity.get("target_ship_index", -1)),
		"target_squadron_index": int(identity.get(
				"target_squadron_index", -1)),
		"defender_player": int(identity.get("defender_player", -1)),
		"defender_zone": int(identity.get("defender_zone", -1)),
		SquadronKeywordRuleHelper.PAYLOAD_ATTACK_KIND:
				SquadronKeywordRuleHelper.attack_kind_from_payload(identity),
	}

## Counts non-discarded defense tokens on the canonical defender.
func _count_lockable_tokens(def_inst: RefCounted) -> int:
	return _defense_resolver.count_lockable_tokens(def_inst)

## Called when the player confirms accuracy spending.
## Stores the locked token indices and proceeds to defense step.
## Requirements: AE-ACC-006.
func _on_attack_accuracy_confirmed() -> void:
	var locked_tokens: Array[int] = []
	if _get_panel():
		locked_tokens = _get_panel().get_accuracy_locked_indices()
		_get_panel().hide_accuracy_section()
	_commit_accuracy_selection(locked_tokens)


func _commit_accuracy_selection(locked_tokens: Array[int]) -> void:
	var result: Dictionary = GameManager.submit_commit_accuracy(
			_get_attacker_player(), locked_tokens)
	if _is_waiting_for_remote_command_result(result) or result.is_empty():
		return
	apply_accuracy_result(result)


func apply_accuracy_result(_result: Dictionary) -> void:
	if not _state.accuracy_step:
		return
	_sync_scene_from_current_attack()
	_state.accuracy_step = false
	_log.info("Accuracy confirmed: locked tokens %s." % [
			str(_state.locked_tokens)])
	_attack_exec_start_defense()

# ===========================================================================
# Phase 6c-2 — Defense Token Spending (Step 4)
# ===========================================================================

## Starts the defense token spending step.
## If the canonical defender has spendable defense-token capabilities, show
## the defense UI.
## Otherwise, skip to damage resolution.
## Requirements: AE-DEF-001–016.
## Rules Reference: "Spend Defense Tokens", p.5 — "The defender can spend
## one or more of his defense tokens."
func _attack_exec_start_defense() -> void:
	_state.defense_step = true
	_state.spent_tokens.clear()
	_state.defense_commit_queue.clear()
	var def_inst: RefCounted = _resolve_defense_step_defender()
	if def_inst == null:
		_state.defense_step = false
		var attack: CurrentAttackState = _current_attack()
		if attack != null \
				and attack.defense_stage == CurrentAttackState.DEFENSE_PENDING:
			_submit_commit_defense([])
		else:
			_attack_exec_resolve_damage()
		return
	# Phase I3: record defender so FSM knows who controls DEFENSE_TOKENS.
	_flow_fsm.defender_player = int(def_inst.get("owner_player"))
	_fsm_advance(AttackFlowFSM.Step.DEFENSE_TOKENS)
	# Phase I3b / I6b slice 2: publish defender identity + locked tokens
	# + modified damage so the defender client can render the defense UI
	# from interaction_flow alone.
	_fsm_patch_payload(_flow_executor.build_defense_payload(
			_state, def_inst, GameManager.current_game_state,
			_defense_resolver))
	# Rotate camera to the defender's perspective (AE-DEF-011).
	# Phase K4: hot-seat detected via `local_player_index < 0` (no
	# network session).  In network each peer's camera is locked to
	# its own seat, so the rotate-to-defender behaviour is hot-seat-
	# only.
	if _camera and NetworkManager.get_local_player_index() < 0:
		_camera.rotate_to_player(int(def_inst.get("owner_player")))
	_log.info("Defense step: %d spendable tokens, %d damage." % [
			_count_spendable_defense_tokens(def_inst),
			_state.modified_damage])
	_show_defense_section(def_inst)


## Resolves a canonical defender with an applicable token interaction.
func _resolve_defense_step_defender() -> RefCounted:
	var def_inst: RefCounted = _get_canonical_defender()
	if def_inst == null:
		return null
	if not _can_defender_spend_tokens(def_inst):
		return null
	return def_inst


## Opens the defense section on the local attack panel.  In network mode
## the attacker peer renders the section in read-only mode so it can
## watch the defender's input without authoring it; in hot-seat the
## attacker panel is interactive.  Phase I6b-3 R6 / Phase K4.
func _show_defense_section(def_inst: RefCounted) -> void:
	if _get_panel() == null:
		return
	_get_panel().show_defense_section(
			_defense_tokens(def_inst),
			_state.locked_tokens,
			_state.modified_damage,
			_defender_speed(def_inst),
			{
				"interactive": NetworkManager.get_local_player_index() < 0,
				"blocked_indices": _get_blocked_defense_token_indices(def_inst),
				"ecm_choice": _ecm_choice_payload(),
				"ecm_authorized_indices": _ecm_authorized_token_indices(),
			})

## Returns true if the defender has spendable tokens and speed > 0.
func _can_defender_spend_tokens(def_inst: RefCounted) -> bool:
	var result: bool = _defense_resolver.can_spend_tokens(
			def_inst, _state.locked_tokens,
			_state.defender_zone)
	if not result and def_inst is ShipInstance \
			and _can_defender_use_ecm(def_inst as ShipInstance):
		return true
	if not result:
		if def_inst is ShipInstance \
				and (def_inst as ShipInstance).current_speed == 0:
			_log.info("Defender speed 0 — cannot spend defense tokens.")
		else:
			_log.info("No spendable defense tokens — skipping defense step.")
	return result


func _can_defender_use_ecm(def_inst: ShipInstance) -> bool:
	var gs: GameState = GameManager.current_game_state
	var attack: CurrentAttackState = _current_attack()
	if gs == null or def_inst == null or attack == null:
		return false
	var defender_ship_index: int = gs.find_ship_index(def_inst)
	var payload: Dictionary = {
		"attacker_player": attack.attacker_player,
		"attacker_ship_index": attack.attacker_index \
				if attack.attacker_kind == CurrentAttackState.KIND_SHIP else -1,
		"defender_player": def_inst.owner_player,
		"defender_ship_index": defender_ship_index,
		"defender_zone": _state.defender_zone,
		"locked_tokens": _state.locked_tokens.duplicate(true),
		"spent_defense_token_types": [],
	}
	var flow: InteractionFlow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			def_inst.owner_player,
			Constants.Visibility.ALL,
			payload)
	return not ECM_SCRIPT.choice_payload(gs, flow).is_empty()

## Returns the number of spendable, non-discarded, non-locked tokens that are
## not blocked by RuleRegistry defense-token blockers.
## Rules Reference: "Defense Tokens", p.5; "Faulty Countermeasures".
func _count_spendable_defense_tokens(inst: RefCounted) -> int:
	return _defense_resolver.count_spendable_tokens(
			inst, _state.locked_tokens,
			_state.defender_zone)


## Returns non-discarded token indices blocked by RuleRegistry.
func _get_blocked_defense_token_indices(
		inst: RefCounted) -> Array[int]:
	return _flow_executor.build_blocked_defense_token_indices(
			_state, inst, _defense_resolver)

## Called when the player spends a defense token.
## [param token_index] — index in the defender's defense_tokens array.
## [param spend_method] — "exhaust" or "discard".
## Requirements: AE-DEF-001–016.
## Rules Reference: "Defense Tokens", p.5 — each token type at most once.
func _on_attack_defense_token_spent(token_index: int,
		spend_method: String) -> bool:
	var def_inst: RefCounted = _get_canonical_defender()
	if def_inst == null:
		return false
	var tokens: Array[Dictionary] = _defense_tokens(def_inst)
	if token_index < 0 or token_index >= tokens.size():
		return false
	var token: Dictionary = tokens[token_index]
	var token_type: Constants.DefenseToken = (
			token["type"] as Constants.DefenseToken)
	if not _is_defense_token_spendable(token_index, token):
		return false
	var actual_method: String = _resolve_spend_method(spend_method, token)
	# Route through command system for replay determinism.
	_defense_command_pending = true
	_defense_submit_in_progress = true
	var result: Dictionary = GameManager.submit_spend_defense_token(
			def_inst, token_index, actual_method)
	if _is_waiting_for_remote_command_result(result):
		_defense_submit_in_progress = false
		return true
	if result.is_empty():
		_defense_submit_in_progress = false
		_defense_command_pending = false
		_log.warn("Defense token spend command rejected — skipping effects.")
		return false
	apply_defense_token_result(result)
	_defense_submit_in_progress = false
	return true


func apply_defense_token_result(result: Dictionary) -> void:
	var token_type: int = int(result.get("token_type", -1))
	if token_type < 0 or _state.spent_tokens.has(token_type):
		return
	_defense_command_pending = false
	var actual_method: String = str(result.get("spend_method", ""))
	_state.spent_tokens[token_type] = actual_method
	_sync_scene_from_current_attack()
	var def_inst: RefCounted = _get_canonical_defender()
	if def_inst == null:
		return
	_publish_spent_defense_token_types()
	EventBus.ship_defense_token_changed.emit(def_inst)
	EventBus.defense_token_spent.emit(
			_get_defender_token(), token_type)
	_log.info("Defense token spent: %s (%s)." % [
			Constants.DEFENSE_TOKEN_NAMES.get(token_type, "?"),
			actual_method])
	_apply_defense_token_effect(token_type, def_inst)

## Returns true if the token at the given index can be spent.
## Checks discard state, one-per-type limit, accuracy locks, and
## RuleRegistry defense-token blockers.
## Rules Reference: "Defense Tokens", p.5; "Faulty Countermeasures".
func _is_defense_token_spendable(token_index: int,
		token: Dictionary) -> bool:
	var result: bool = _defense_resolver.is_token_spendable(
			token_index, token, _state.spent_tokens,
			_state.locked_tokens, _get_canonical_defender(),
			_state.defender_zone)
	if not result and _ecm_token_authorized(token_index):
		return true
	if not result:
		_log.info("Token %d not spendable — ignoring." % token_index)
	return result


func _publish_spent_defense_token_types() -> void:
	var gs: GameState = GameManager.current_game_state
	if gs == null or gs.interaction_flow == null:
		return
	var spent: Array[int] = []
	for token_type: Variant in _state.spent_tokens.keys():
		spent.append(int(token_type))
	gs.interaction_flow.payload["spent_defense_token_types"] = spent


func _ecm_choice_payload() -> Dictionary:
	var gs: GameState = GameManager.current_game_state
	if gs == null or gs.interaction_flow == null:
		return {}
	return ECM_SCRIPT.choice_payload(gs, gs.interaction_flow)


func _ecm_authorized_token_indices() -> Array[int]:
	var result: Array[int] = []
	var gs: GameState = GameManager.current_game_state
	if gs == null or gs.interaction_flow == null:
		return result
	return ECM_SCRIPT.authorized_token_indices(gs, gs.interaction_flow)


func _ecm_token_authorized(token_index: int) -> bool:
	if not _state.locked_tokens.has(token_index):
		return false
	if not _ecm_authorized_token_indices().has(token_index):
		return false
	var spent_types: Array[int] = []
	for token_type: Variant in _state.spent_tokens.keys():
		spent_types.append(int(token_type))
	return ECM_SCRIPT.is_token_otherwise_spendable(
			_get_defender_instance(), token_index, spent_types,
			_state.defender_zone)

## Resolves the actual spend method: exhausted tokens must be discarded.
func _resolve_spend_method(spend_method: String,
		token: Dictionary) -> String:
	return _defense_resolver.resolve_spend_method(spend_method, token)

## Resolves the current defender from canonical owner-local identity.
func _get_canonical_defender() -> RefCounted:
	var attack: CurrentAttackState = _current_attack()
	var game_state: GameState = GameManager.current_game_state
	if attack == null or not attack.active or game_state == null:
		return null
	return _resume_entity(game_state, attack.defender_kind,
			attack.defender_player, attack.defender_index)


func _defense_tokens(defender: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if defender != null:
		result.assign(defender.get("defense_tokens") as Array)
	return result


func _defender_speed(defender: RefCounted) -> int:
	return (defender as ShipInstance).current_speed \
			if defender is ShipInstance else -1


## Returns the canonical defender as a ship, or null for another kind.
func _get_defender_instance() -> ShipInstance:
	return _get_canonical_defender() as ShipInstance


func _get_defender_token() -> Node:
	var attack: CurrentAttackState = _current_attack()
	if attack == null:
		return null
	return _state.defender_ship if attack.defender_kind \
			== CurrentAttackState.KIND_SHIP else _state.defender_squadron


## Returns the attacker's owner_player index.
## Works for both ship and squadron attack modes.
func _get_attacker_player() -> int:
	var attack: CurrentAttackState = _current_attack()
	if attack != null and attack.active:
		return attack.attacker_player
	if _state.attacker_squadron:
		var current_sq: SquadronInstance = \
				_state.attacker_squadron.get_squadron_instance()
		if current_sq:
			return current_sq.owner_player
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

## Returns true if a RuleRegistry blocker prevents spending this token.
## Rules Reference: "Faulty Countermeasures"; "Capacitor Failure".
func _is_token_blocked_by_effect(inst: RefCounted,
		token: Dictionary) -> bool:
	return _defense_resolver.is_token_blocked_by_effect(
			inst, token, _state.defender_zone)

## Applies the effect of a defense token to the current attack.
## Requirements: AE-DEF-006–016.
## Rules Reference: "Defense Tokens", p.5; individual token entries.
func _apply_defense_token_effect(token_type: Constants.DefenseToken,
		def_inst: RefCounted) -> void:
	match token_type:
		Constants.DefenseToken.SCATTER:
			_apply_scatter_effect()
		Constants.DefenseToken.EVADE:
			_attack_exec_start_evade()
			return # Evade step handles button disable
		Constants.DefenseToken.BRACE:
			_apply_brace_effect()
		Constants.DefenseToken.REDIRECT:
			if def_inst is ShipInstance:
				_attack_exec_start_redirect(def_inst as ShipInstance)
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
	# CurrentAttackState already applied the semantic effect. Scene state only
	# projects the canonical derived damage.
	_log.info("Scatter: all damage cancelled.")
	if _get_panel():
		_get_panel().update_defense_damage(0)
		_get_panel().disable_defense_token_button(-1)

## Applies the Brace defense token effect.
## Rules Reference: "Brace", RRG v1.5.0, p.3.
func _apply_brace_effect() -> void:
	_state.brace_used = true
	# CurrentAttackState already applied Brace in derive_damage(). Reapplying it
	# here would halve the canonical damage a second time.
	_log.info("Brace: damage halved to %d." % [
			_state.modified_damage])
	if _get_panel():
		_get_panel().update_defense_damage(
				_state.modified_damage)

## Returns the button index for a given token type in the current attack.
func _get_token_button_index_for_type(
		token_type: Constants.DefenseToken) -> int:
	var def_inst: RefCounted = _get_canonical_defender()
	if def_inst == null:
		return -1
	return _defense_resolver.get_token_button_index(
			token_type, _defense_tokens(def_inst),
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
	# Phase I6b-3 R3: publish the evade sub-step so the defender peer's
	# mirror can render the die-selection section.  Cleared in
	# [method apply_defender_evade_die].
	_fsm_patch_payload({
		"evade_active": true,
		"evade_range_band": range_band,
	})
	# Phase I6b-3 R6 / K4: in network mode the attacker panel renders
	# the same evade prompt read-only (`local_player_index < 0` =>
	# hot-seat => interactive).
	if _get_panel():
		_get_panel().show_evade_die_selection(
				range_band, NetworkManager.get_local_player_index() < 0)

## Called when the defender selects a die during evade die-selection.
## Submits a [SelectEvadeDieCommand] so the remove-die / reroll-die
## pipeline runs identically in hot-seat and network play.  In network
## mode this handler runs on the defender peer's [AttackPanelMirror],
## not on the attacker's [AttackSimPanel].
## Requirements: AE-DEF-007–009.
## Phase I6b-3 R3.
func _on_evade_die_selected(die_index: int) -> void:
	if not _state.evade_step:
		return
	if die_index < 0 or die_index >= _state.dice_results.size():
		_log.info("Evade: invalid die index %d." % die_index)
		return
	_submit_select_evade_die(die_index)


## Builds and submits the [SelectEvadeDieCommand] for the current
## defender.  Side effects (remove or reroll, damage update, FSM
## continuation) happen on the attacker peer when
## [method apply_defender_evade_die] is triggered from the
## [signal CommandProcessor.command_executed] broadcast.
func _submit_select_evade_die(die_index: int) -> void:
	var def_inst: RefCounted = _get_canonical_defender()
	if def_inst == null:
		_log.warn("Evade-die submit with no canonical defender — ignoring.")
		return
	GameManager.submit_select_evade_die(def_inst, die_index)


## Applies a defender's evade-die selection on the attacker peer.
## Called from [GameBoard] when the
## [signal CommandProcessor.command_executed] signal fires for a
## [SelectEvadeDieCommand].  Performs the actual remove (long range)
## or reroll (medium / close range), updates the damage readout, and
## proceeds with the next defense-token in the commit queue.
##
## In hot-seat the attacker peer is also the submitter, so this runs
## right after submission completes (single-step).  In network play
## the defender peer submitted the command and the attacker peer's
## executor reacts here.
func apply_defender_evade_die(die_index: int) -> void:
	if not is_in_exec_mode():
		return
	if not _state.evade_step:
		return
	_state.evade_step = false
	_sync_scene_from_current_attack()
	if _get_panel():
		_get_panel().hide_evade_die_selection()
	# Phase I6b-3 R3 follow-up: clear evade sub-step flags + publish
	# the post-modification dice strip + modified damage in one
	# broadcast so the defender mirror hides the section and
	# re-renders the rerolled / removed die together.
	_fsm_patch_payload({
		"evade_active": false,
		"evade_range_band": "",
		"dice_results": _state.dice_results.duplicate(true),
		"modified_damage": _state.modified_damage,
	})
	_refresh_post_evade_panel()


## Refreshes the local attack panel after an evade die-modification:
## updates the damage readout and disables the Evade token button.
## Extracted from [method apply_defender_evade_die] to keep that
## handler under the 30-line cap.
func _refresh_post_evade_panel() -> void:
	if _get_panel() == null:
		return
	_get_panel().update_defense_damage(_state.modified_damage)
	_get_panel().disable_defense_token_button(
			_get_token_button_index_for_type(
					Constants.DefenseToken.EVADE))

## Evade at long range: removes the selected die.
func _apply_evade_remove(die_index: int) -> void:
	var parts: CombatParticipants = _build_current_participants()
	var result: Dictionary = _defense_resolver.apply_evade_remove(
			die_index, _state.dice_results, parts)
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
			die_index, _state.dice_results, parts)
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
	_publish_redirect_substep_patch(adjacent)
	# Phase I6b-3 R6: in network mode the attacker peer renders the
	# same redirect zone-selection section in [b]read-only[/b] mode
	# (zone buttons disabled, Done button hidden).  The interactive
	# zone buttons live on the defender peer's [AttackPanelMirror].
	# Phase K4: discriminator is `local_player_index < 0` (hot-seat).
	if _get_panel():
		_get_panel().show_redirect_section(
				adjacent, _state.redirect_remaining,
				NetworkManager.get_local_player_index() < 0)


## Publishes the redirect sub-step into [InteractionFlow.payload] so
## the defender peer's [AttackPanelMirror] can render the interactive
## zone buttons.  Adjacent zones are stored as plain ints for
## serialisation safety.  Phase I6b-3 R4.
func _publish_redirect_substep_patch(adjacent: Array) -> void:
	var adjacent_ints: Array = []
	for zn: Variant in adjacent:
		adjacent_ints.append(int(zn))
	_fsm_patch_payload({
		"redirect_active": true,
		"redirect_adjacent_zones": adjacent_ints,
		"redirect_remaining": _state.redirect_remaining,
	})

## Called when the player selects a hull zone for redirect on the
## attacker peer's local panel (hot-seat) or when the defender peer's
## mirror submits a [SelectRedirectZoneCommand] (network).  In both
## modes the click reduces to a single command submission so the
## bookkeeping path is unified via [method apply_defender_redirect_zone].
##
## Requirements: AE-DEF-012, AE-DEF-013.
func _on_attack_redirect_zone_selected(zone: int) -> void:
	if not _state.redirect_step:
		return
	var def_inst: ShipInstance = _get_defender_instance()
	if def_inst == null:
		return
	var zone_enum: Constants.HullZone = zone as Constants.HullZone
	if not _defense_resolver.can_redirect_to_zone(
			zone_enum, def_inst, _state.redirect_remaining):
		var zone_str: String = ConstantsScript.hull_zone_to_string(zone_enum)
		_log.info("Redirect: cannot redirect to %s." % zone_str)
		return
	# Submit; the bookkeeping (decrement, continuation, next-commit)
	# happens on the attacker peer in [method apply_defender_redirect_zone]
	# triggered from [signal CommandProcessor.command_executed].
	GameManager.submit_select_redirect_zone(def_inst, int(zone_enum))


## Applies the redirect bookkeeping on the attacker peer after a
## [SelectRedirectZoneCommand] has been broadcast.  Called by
## [GameBoard._on_command_executed_project_ui].  In hot-seat the local
## peer is also the attacker, so this runs immediately after the
## submission completes.  In network play the defender peer submitted
## the command and the attacker peer's executor reacts here.
##
## Phase I6b-3 R4.
func apply_defender_redirect_zone(zone: int) -> void:
	if not is_in_exec_mode():
		return
	if not _state.redirect_step:
		return
	var def_inst: ShipInstance = _get_defender_instance()
	if def_inst == null:
		return
	var zone_enum: Constants.HullZone = zone as Constants.HullZone
	var zone_str: String = ConstantsScript.hull_zone_to_string(zone_enum)
	_emit_redirect_shield_refresh(def_inst, zone_str)
	_sync_scene_from_current_attack()
	_log.info("Redirect: 1 damage to %s shield. Remaining: %d/%d." % [
			zone_str, _state.redirect_remaining,
			_state.modified_damage])
	if _get_panel():
		_get_panel().update_defense_damage(_state.modified_damage)
	# Phase I6b-3 R4: re-publish the updated remaining-budget and
	# modified damage so the defender peer's mirror can refresh both.
	_fsm_patch_payload({
		"redirect_remaining": _state.redirect_remaining,
		"modified_damage": _state.modified_damage,
	})
	var attack: CurrentAttackState = _current_attack()
	var redirect_pending: bool = attack != null \
			and not _has_resolved_defense_effect(
					attack, Constants.DefenseToken.REDIRECT)
	if not redirect_pending or not _check_redirect_continuation(def_inst):
		_finish_redirect_substep()


## Emits the on-board ship visual refresh for a redirect's shield
## mutation.  The shield mutation itself happens inside
## [SelectRedirectZoneCommand.execute] (replicated to both peers); the
## attacker-peer signal emit lives here so the redirect sub-step in
## [method apply_defender_redirect_zone] stays under the 30-line cap.
func _emit_redirect_shield_refresh(def_inst: ShipInstance,
		zone_str: String) -> void:
	EventBus.ship_shields_changed.emit(
			def_inst, zone_str,
			int(def_inst.current_shields.get(zone_str, 0)))


## Tears down the redirect sub-step on the attacker peer when no more
## redirect is possible, clears the payload flags so the defender
## peer's mirror hides its interactive section, and advances to the
## next defense commit.  Phase I6b-3 R4.
func _finish_redirect_substep() -> void:
	_state.redirect_step = false
	_fsm_patch_payload({
		"redirect_active": false,
		"redirect_adjacent_zones": [],
		"redirect_remaining": 0,
	})


## Applies the [i]Done Redirecting[/i] cleanup on the attacker peer
## after a [RedirectDoneCommand] has been broadcast.  Called by
## [GameBoard._on_command_executed_project_ui].  Phase I6b-3 R4.
func apply_defender_redirect_done() -> void:
	if not is_in_exec_mode():
		return
	if not _state.redirect_step:
		return
	_log.info("Redirect ended early by player.")
	_sync_scene_from_current_attack()
	_state.redirect_step = false
	_fsm_patch_payload({
		"redirect_active": false,
		"redirect_adjacent_zones": [],
		"redirect_remaining": 0,
	})
	if _get_panel():
		_get_panel().hide_redirect_section()

## Checks if redirect can continue. Returns true if more redirect is
## possible and the UI was updated; false if redirect is done.
func _check_redirect_continuation(
		def_inst: ShipInstance) -> bool:
	var can_continue: bool = _flow_executor.can_continue_redirect(
			_state, def_inst, _defense_resolver)
	if can_continue and _get_panel():
		_get_panel().update_redirect_remaining(
				_state.redirect_remaining)
		return true
	if _get_panel():
		_get_panel().hide_redirect_section()
	return false

## Called when the player presses "Commit Defense".
## Reads selected token indices from the panel and submits a
## [CommitDefenseCommand] so the spend pipeline runs identically in
## hot-seat and network play.  In network mode this handler runs on
## the defender peer's [AttackPanelMirror], not on the attacker's
## [AttackSimPanel].
## Requirements: AE-DEF-003.
## Phase I6b-3 R2 — closes NW-006.
func _on_attack_defense_done() -> void:
	var selected: Array[int] = []
	if _get_panel():
		selected = _get_panel().get_defense_selected_indices()
	if _submit_commit_defense(selected) and _get_panel():
		_get_panel().disable_all_defense_buttons()


func _on_ecm_use_requested(runtime_upgrade_id: String) -> void:
	var def_inst: ShipInstance = _get_defender_instance()
	if def_inst == null:
		return
	var result: Dictionary = GameManager.submit_use_ecm(
			def_inst, runtime_upgrade_id)
	if result.is_empty():
		_log.warn("Electronic Countermeasures use rejected.")
		return
	_show_defense_section(def_inst)


func _on_ecm_decline_requested(runtime_upgrade_id: String) -> void:
	var def_inst: ShipInstance = _get_defender_instance()
	if def_inst == null:
		return
	var result: Dictionary = GameManager.submit_decline_ecm(
			def_inst, runtime_upgrade_id)
	if result.is_empty():
		_log.warn("Electronic Countermeasures decline rejected.")
		return
	_show_defense_section(def_inst)


## Builds and submits the [CommitDefenseCommand] for the current
## defender.  Side effects (queueing, spend submissions, FSM advance)
## happen on the attacker peer when [method apply_defender_commit] is
## triggered from the [signal CommandProcessor.command_executed]
## broadcast.
## Returns false when command validation rejects the commit.
func _submit_commit_defense(selected: Array[int]) -> bool:
	var def_inst: RefCounted = _get_canonical_defender()
	if def_inst == null:
		_log.warn("Commit defense with no canonical defender — ignoring.")
		return false
	# Sort into canonical resolution order before sending so all peers
	# process tokens deterministically.
	var canonical: Array[int] = _flow_executor.sort_defense_tokens_canonical(
			selected, _defense_tokens(def_inst))
	var result: Dictionary = GameManager.submit_commit_defense(def_inst, canonical)
	if result.is_empty():
		_log.warn("Defense commit command rejected — controls remain enabled.")
		return false
	return true


## Applies a defender's commit on the attacker peer.  Called from
## [GameBoard] when the [signal CommandProcessor.command_executed]
## signal fires for a [CommitDefenseCommand].  The indices are already
## in canonical resolution order.
##
## In hot-seat the attacker peer is also the submitter, so this runs
## right after submission completes (single-step).  In network play
## the defender peer submitted the command and the attacker peer's
## executor reacts here.
func apply_defender_commit(selected: Array[int]) -> void:
	if not is_in_exec_mode():
		return
	if not _state.defense_step:
		return
	_sync_scene_from_current_attack()
	var attack: CurrentAttackState = _current_attack()
	if attack == null or attack.committed_defense_tokens != selected:
		_log.warn("Defense commit projection does not match canonical state.")
		return
	if selected.is_empty():
		_log.info("No defense tokens selected — proceeding to damage.")
		if _get_panel():
			_get_panel().hide_defense_section()
		return
	_log.info("Defense commit: %d canonical tokens." % selected.size())


## Re-sorts the committed token indices into canonical RRG resolve
## order (Scatter → Evade → Brace → Redirect → Contain) before
## queueing.  The hot-seat producer
## ([method _submit_commit_defense]) sorts before submitting, but the
## network defender peer
## ([method AttackPanelMirror._on_defense_tokens_done]) submits in
## click order; without this re-sort a `[Brace, Evade]` click order
## halves damage with Brace first and then Evade overwrites
## `_state.modified_damage` from raw dice, undoing the brace.
## Rules Reference: "Defense Tokens", p.5.
func _canonicalise_committed_tokens(
		selected: Array[int]) -> Array[int]:
	var def_inst: RefCounted = _get_canonical_defender()
	if def_inst == null:
		return selected
	return _flow_executor.sort_defense_tokens_canonical(
			selected, _defense_tokens(def_inst))

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
## Compatibility shim kept for existing tests that call this method
## directly; production code delegates through AttackFlowExecutor.
func _sort_defense_tokens_canonical(
		indices: Array[int]) -> Array[int]:
	var def_inst: RefCounted = _get_canonical_defender()
	# This method is retained only as a compatibility seam for isolated tests
	# that predate CurrentAttackState. Production commitment sorting calls the
	# helper directly with the canonical defender resolved above.
	if def_inst == null and _state.defender_ship != null:
		def_inst = _state.defender_ship.get_ship_instance()
	if def_inst == null and _state.defender_squadron != null:
		def_inst = _state.defender_squadron.get_squadron_instance()
	if def_inst == null:
		return indices
	return _flow_executor.sort_defense_tokens_canonical(
			indices, _defense_tokens(def_inst))

## Derives the next unresolved token from CurrentAttackState. Only the live
## authority authors the deterministic SpendDefenseToken follow-up; mirrors
## consume the recorded commands and render their results.
func _process_next_defense_commit() -> void:
	var attack: CurrentAttackState = _current_attack()
	if attack == null or not attack.active:
		return
	var token_index: int = _next_canonical_defense_token(attack)
	if token_index < 0:
		_log.info("Defense commit complete. Modified damage: %d." % [
				_state.modified_damage])
		if _get_panel():
			_get_panel().hide_defense_section()
		if _is_live_defense_authority():
			_attack_exec_resolve_damage()
		return
	if not _is_live_defense_authority():
		return
	_log.info("Processing committed token index %d." % token_index)
	# Reuse the existing spending logic (validates, applies, starts
	# sub-steps for Evade/Redirect).
	var spent: bool = _on_attack_defense_token_spent(token_index, "exhaust")
	if not spent:
		_log.warn("Canonical defense follow-up was rejected; progression stopped.")
		return
	if _defense_command_pending:
		return
	# For a synchronous live submit, CommandProcessor may already have drained
	# the canonical continuation chain. Re-reading the attack makes this
	# compatibility path inert in that case; decision sub-steps resume through
	# the authoritative post-success seam after their explicit command.
	if not _state.evade_step and not _state.redirect_step:
		_process_next_defense_commit()


func _next_canonical_defense_token(attack: CurrentAttackState) -> int:
	var resolved: Dictionary = {}
	for effect: Dictionary in attack.resolved_defense_effects:
		resolved[int(effect.get("token_index", -1))] = true
	for token_index: int in attack.committed_defense_tokens:
		if not resolved.has(token_index):
			return token_index
	return -1


func _is_live_defense_authority() -> bool:
	if CommandProcessor.is_replaying:
		return false
	return NetworkManager.role == NetworkManager.Role.NONE \
			or NetworkManager.is_server()

## Called when the player presses "Done Redirecting" in the redirect
## section, ending the redirect sub-step early.  Submits a
## [RedirectDoneCommand]; the bookkeeping happens on the attacker peer
## in [method apply_defender_redirect_done] triggered from
## [signal CommandProcessor.command_executed].  Phase I6b-3 R4.
func _on_redirect_done_early() -> void:
	if not _state.redirect_step:
		return
	var def_inst: ShipInstance = _get_defender_instance()
	if def_inst == null:
		return
	GameManager.submit_redirect_done(def_inst)

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
		_fsm_advance(AttackFlowFSM.Step.RESOLVE_DAMAGE)
	var attack: CurrentAttackState = _current_attack()
	if attack == null or not attack.active:
		return
	var result: Dictionary
	if attack.defender_kind == CurrentAttackState.KIND_SHIP:
		result = GameManager.submit_resolve_ship_damage(
				_get_defender_instance())
	else:
		var squadron: SquadronInstance = \
				_get_canonical_defender() as SquadronInstance
		result = GameManager.submit_resolve_squadron_damage(squadron)
	if _is_waiting_for_remote_command_result(result) or result.is_empty():
		return
	apply_damage_result(result)


func apply_damage_result(result: Dictionary) -> void:
	var attack_id: String = str(result.get("attack_id", ""))
	if attack_id.is_empty() or _applied_damage_attack_id == attack_id:
		return
	var attack: CurrentAttackState = _current_attack()
	if attack == null or attack.attack_id != attack_id \
			or attack.stage != CurrentAttackState.STAGE_RESOLVED:
		return
	_applied_damage_attack_id = attack_id
	_sync_scene_from_current_attack()
	var final_damage: int = int(result.get("final_damage",
			result.get("hull_damage", 0)))
	# Phase I3c: publish final damage so UIProjector can render the
	# damage summary on the defender's screen.
	_fsm_patch_payload({"final_damage": final_damage})
	# Brace is already applied during Step 4 (canonical order before
	# Redirect), so _state.modified_damage is already halved.
	_log.info("Resolving damage: %d total." % final_damage)
	if final_damage <= 0:
		_resolve_zero_damage()
		return
	if str(result.get("target_type", "")) == "squadron":
		_apply_squadron_damage_result(result)
		if _pending_counter_attacker != null:
			return
		_attack_exec_finalize_after_delay()
		return
	if str(result.get("target_type", "")) == "ship":
		_continue_ship_damage_resolution(result)
		return
	_log.error("No defender found for damage resolution!")
	_attack_exec_finalize_attack()


## Zero-damage resolution path: show the "no damage" panel and offer Counter
## for eligible squadron defenders before finalising.
## Rules Reference: RRG "Squadron Keywords" — Counter triggers after a
## squadron performs a non-Counter attack, regardless of damage.
func _resolve_zero_damage() -> void:
	_log.info("No damage to resolve.")
	if _get_panel():
		_get_panel().show_damage_info(
				_damage_dealer.build_no_damage_info())
	if _maybe_offer_counter_attack():
		return
	_attack_exec_finalize_after_delay()


## Ship-defender damage resolution: deals damage cards then either
## defers finalisation (waiting on the damage summary overlay) or
## proceeds into the immediate-effect choice flow / standard delay.
func _continue_ship_damage_resolution(result: Dictionary) -> void:
	_apply_ship_damage_result(result)
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

## Resolves damage against a squadron.
## Squadrons have no shields — damage goes directly to hull.
## Routes through [ResolveDamageCommand] for replay determinism.
## Requirements: AE-DMG-002.
func _resolve_squadron_damage(_damage: int) -> void:
	var sq_inst: SquadronInstance = \
			_get_canonical_defender() as SquadronInstance
	if sq_inst == null:
		_log.error("Squadron instance is null — cannot resolve damage.")
		return
	var result: Dictionary = GameManager.submit_resolve_squadron_damage(sq_inst)
	if result.is_empty():
		return
	apply_damage_result(result)


func _apply_squadron_damage_result(result: Dictionary) -> void:
	var sq_inst: SquadronInstance = \
			_get_canonical_defender() as SquadronInstance
	if sq_inst == null:
		return
	var actual: int = int(result.get("actual_damage", 0))
	var destroyed: bool = bool(result.get("destroyed", false))
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
	_maybe_offer_counter_attack()


func _maybe_offer_counter_attack() -> bool:
	if not _is_counter_available():
		return false
	_pending_counter_attacker = _state.defender_squadron
	_pending_counter_target = _state.attacker_squadron
	_start_counter_choice_flow()
	if _get_panel() and NetworkManager.get_local_player_index() < 0:
		_get_panel().show_counter_section()
	_log.info("Counter available — awaiting defender choice.")
	return true


func _is_counter_available() -> bool:
	var attacker: SquadronInstance = null
	var defender: SquadronInstance = null
	if _state.attacker_squadron:
		attacker = _state.attacker_squadron.get_squadron_instance()
	if _state.defender_squadron:
		defender = _state.defender_squadron.get_squadron_instance()
	return CounterKeyword.is_counter_trigger_available(
			_state.attack_kind, attacker, defender)


func _publish_counter_payload(available: bool) -> void:
	_fsm_patch_payload(_counter_choice_payload(available))


func _start_counter_choice_flow() -> void:
	_flow_fsm.defender_player = _get_counter_controller_player()
	_fsm_advance(AttackFlowFSM.Step.COUNTER_CHOICE)
	_publish_counter_payload(true)


func _get_counter_controller_player() -> int:
	if _pending_counter_attacker == null:
		return -1
	var squadron: SquadronInstance = \
			_pending_counter_attacker.get_squadron_instance()
	return squadron.owner_player if squadron != null else -1


func _counter_dice_pool() -> Dictionary:
	var squadron: SquadronInstance = null
	if _pending_counter_attacker:
		squadron = _pending_counter_attacker.get_squadron_instance()
	var dice_count: int = SquadronKeywordRuleHelper.get_keyword_value(
			squadron, SquadronKeywordRuleHelper.KEYWORD_COUNTER)
	if dice_count <= 0:
		return {}
	return {"BLUE": dice_count}


func _counter_choice_payload(available: bool) -> Dictionary:
	var controller: int = _get_counter_controller_player()
	return {
		CounterKeyword.PAYLOAD_AVAILABLE: available,
		CounterKeyword.PAYLOAD_CONTROLLER_PLAYER: controller,
		CounterKeyword.PAYLOAD_DICE_POOL: _counter_dice_pool(),
		"controller_player": controller,
		"counter_attacker_player": controller,
		"counter_attacker_squadron_index": _counter_attacker_index(),
		"counter_target_player": _counter_target_player(),
		"counter_target_squadron_index": _counter_target_index(),
	}


func _counter_attacker_index() -> int:
	return _squadron_index_for_token(_pending_counter_attacker)


func _counter_target_player() -> int:
	var squadron: SquadronInstance = _squadron_instance_for_token(
			_pending_counter_target)
	return squadron.owner_player if squadron != null else -1


func _counter_target_index() -> int:
	return _squadron_index_for_token(_pending_counter_target)


func _squadron_index_for_token(token: SquadronToken) -> int:
	var game_state: GameState = GameManager.current_game_state
	var squadron: SquadronInstance = _squadron_instance_for_token(token)
	if game_state == null or squadron == null:
		return -1
	return game_state.find_squadron_index(squadron)


func _squadron_instance_for_token(token: SquadronToken) -> SquadronInstance:
	if token == null:
		return null
	return token.get_squadron_instance()


func _on_counter_attack_requested() -> void:
	if _pending_counter_attacker == null or _pending_counter_target == null:
		return
	GameManager.submit_counter_choice(
			_get_counter_controller_player(), true,
			_counter_choice_payload(true))


func _on_counter_attack_skipped() -> void:
	if _pending_counter_attacker == null or _pending_counter_target == null:
		return
	GameManager.submit_counter_choice(
			_get_counter_controller_player(), false,
			_counter_choice_payload(true))


## Applies an accepted [CounterChoiceCommand] result on the peer that owns
## the active attack pipeline.
func apply_counter_choice_result(result: Dictionary) -> void:
	if _pending_counter_attacker == null or _pending_counter_target == null:
		return
	if _get_panel():
		_get_panel().hide_counter_section()
	_publish_counter_payload(false)
	if bool(result.get("accepted", false)):
		_pending_counter_begin = true
		return
	_pending_counter_attacker = null
	_pending_counter_target = null
	_attack_exec_finalize_after_delay()


## Projects one accepted roll result into the active attack presentation.
func apply_roll_result(command: GameCommand,
		result: Dictionary) -> void:
	var attack: CurrentAttackState = _current_attack()
	if command == null or attack == null or not attack.active:
		return
	if command.player_index != attack.attacker_player \
			or attack.stage != CurrentAttackState.STAGE_ATTACK_MODIFY \
			or _flow_fsm.current_step != AttackFlowFSM.Step.ROLL:
		return
	_apply_dice_roll_result(result)


## Applies a remote optional attack-modifier skip to the attack pipeline.
func apply_remote_attack_modifier_skip(command: GameCommand,
		result: Dictionary) -> void:
	if not _is_attack_pipeline_command(command):
		return
	_apply_attack_modifier_result(result)


## Applies a broadcast Swarm reroll result to the attack pipeline.
func apply_remote_counter_reroll_result(command: GameCommand,
		result: Dictionary) -> void:
	if not _is_attack_pipeline_command(command):
		return
	_apply_attack_modifier_result(result)


## Applies a remote dice-confirm marker to the attack pipeline.
func apply_remote_attack_confirm(command: GameCommand,
		result: Dictionary) -> void:
	if not _is_attack_pipeline_command(command):
		return
	if _pending_reroll_rule_id == SwarmKeyword.RULE_ID:
		_pending_reroll_rule_id = ""
		_publish_swarm_payload(false)
	apply_attack_confirm_result(result)


func _is_counter_pipeline_command(command: GameCommand) -> bool:
	if command == null:
		return false
	if _state.attack_kind != SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER:
		return false
	return command.player_index == _get_attacker_player()


func _is_attack_pipeline_command(command: GameCommand) -> bool:
	if command == null:
		return false
	return command.player_index == _get_attacker_player()


func _apply_swarm_reroll_result(result: Dictionary) -> void:
	_apply_attack_modifier_result(result)


func _begin_counter_attack() -> void:
	var counter_attacker: SquadronToken = _pending_counter_attacker
	var counter_target: SquadronToken = _pending_counter_target
	_pending_counter_attacker = null
	_pending_counter_target = null
	_reset_for_counter_attack(counter_attacker, counter_target)
	_state.range_band = Constants.RANGE_BAND_CLOSE
	_target_selector.lock_current_target_selection()
	var game_state: GameState = GameManager.current_game_state
	_flow_fsm.begin(game_state, _get_attacker_player(), -1, {})
	if _should_show_local_attack_controls():
		_reset_panel_for_counter_attack()
	elif _get_panel():
		_get_panel().close()
	_log.info("Counter accepted: %s attacks %s." % [
			_state.attacker_name, _state.defender_name])
	_attack_exec_begin_sequence(Constants.RANGE_BAND_CLOSE)


func _reset_for_counter_attack(attacker: SquadronToken,
		defender: SquadronToken) -> void:
	_state.reset_for_next_attack()
	_state.attack_kind = SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER
	_state.attacker_squadron = attacker
	_state.defender_squadron = defender
	_state.attacker_name = _squadron_name(attacker)
	_state.defender_name = _squadron_name(defender)
	_state.squad_exec_mode = true
	_state.exec_squad_token = attacker


func _reset_panel_for_counter_attack() -> void:
	var panel: AttackSimPanel = _get_panel()
	if panel == null:
		return
	panel.show_counter_attack_exec(_state.attacker_name,
			_state.defender_name, DicePool.format_pool(_state.dice_pool))


func _counter_dice_pool_for_state() -> Dictionary:
	var attacker: SquadronInstance = null
	if _state.attacker_squadron:
		attacker = _state.attacker_squadron.get_squadron_instance()
	var dice_count: int = SquadronKeywordRuleHelper.get_keyword_value(
			attacker, SquadronKeywordRuleHelper.KEYWORD_COUNTER)
	return {"BLUE": dice_count}


func _squadron_name(token: SquadronToken) -> String:
	if token == null:
		return "Squadron"
	var squadron: SquadronInstance = token.get_squadron_instance()
	if squadron != null and squadron.squadron_data != null:
		return squadron.squadron_data.squadron_name
	return "Squadron"

## Resolves damage against a ship.
## Shields absorb damage first. Remaining damage becomes damage cards.
## Standard critical: first card is faceup if any critical icon present
## and Contain was not spent.
## Routes through [ResolveDamageCommand] for replay determinism.
## Requirements: AE-DMG-003–014.
## Rules Reference: "Damage", p.4.
func _resolve_ship_damage(_damage: int) -> void:
	var def_inst: ShipInstance = _get_defender_instance()
	if def_inst == null:
		_log.error("Ship instance is null — cannot resolve damage.")
		return
	var result: Dictionary = GameManager.submit_resolve_ship_damage(def_inst)
	if result.is_empty():
		return
	apply_damage_result(result)


func _apply_ship_damage_result(result: Dictionary) -> void:
	var def_inst: ShipInstance = _get_defender_instance()
	if def_inst == null:
		return
	var def_zone_str: String = str(result.get("hull_zone", ""))
	var shield_damage: int = int(result.get("shield_absorbed", 0))
	var card_data: Array = result.get("damage_cards", []) as Array
	var destroyed: bool = bool(result.get("destroyed", false))
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
	var faceup_count: int = _flow_executor.count_faceup_cards(card_data)
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

## Determines if the first damage card should be dealt faceup (critical).
func _determine_first_card_faceup() -> bool:
	var faceup: bool = _flow_executor.determine_first_card_faceup(
			_state, _defense_resolver)
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
## Emits faceup-card events and defers immediate effects.
## Uses AttackFlowExecutor pure helper to determine card properties.
## Does NOT mutate game state — the card and any persistent hooks are
## already applied by [ResolveDamageCommand].
func _post_process_faceup_card(card: DamageCard,
		def_inst: ShipInstance) -> void:
	# Use pure helper to determine card properties.
	var card_info: Dictionary = _flow_executor.prepare_faceup_card(
			card, _damage_dealer)

	# Always emit card events.
	EventBus.damage_card_flipped.emit(def_inst, card, true)
	EventBus.damage_card_dealt.emit(def_inst, card, true)
	_log.info(
			"Dealt FACEUP damage card: '%s' [%s] (standard critical)."
			% [card.title, card.trait_type])

	# Defer immediate effect if present.
	if card_info.get("has_immediate", false):
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
	return _flow_executor.build_damage_summary(
			_damage_dealer, def_inst, def_zone_str,
			shield_absorbed, cards_dealt, faceup_card_name)

## Resolves the immediate one-shot effect of a faceup damage card, if any.
## Auto-resolve cards (Structural Damage, Projector Misaligned, Life Support
## Failure) are handled immediately. Choice cards (Injured Crew, Shield
## Failure, Comm Noise) are deferred — the pending state is stored and the
## choice modal is shown after the damage summary.
## Uses AttackFlowExecutor pure helper to decide flow: auto-resolve or defer.
## Rules Reference: RRG "Damage Cards", p.4; DM-005, DM-011.
func _resolve_immediate_card_effect(card: DamageCard,
		ship: ShipInstance) -> void:
	# Use pure helper to decide whether to auto-resolve or defer.
	var flow_decision: Dictionary = _flow_executor.decide_immediate_effect_flow(
			card, ship, _immediate_resolver)
	if not flow_decision.get("should_process", false):
		return
	if not flow_decision.get("should_defer", true):
		_auto_resolve_immediate_effect(card, ship, flow_decision)
		return
	# Choice-based card — store pending state for the modal flow.
	var choice_info: Dictionary = flow_decision.get("choice_info", {})
	_pending_immediate_card = card
	_pending_immediate_ship = ship
	_pending_immediate_choice = choice_info
	_log.info("Immediate effect deferred for modal: '%s' (chooser=%s)."
			% [card.title, choice_info.get("chooser", "?")])


## Submits a choice-less immediate-effect resolution (auto path) and
## emits the resulting visual signals.  Used when
## [method AttackFlowExecutor.decide_immediate_effect_flow] reports
## [code]should_defer = false[/code] (e.g. `structural_damage`).
func _auto_resolve_immediate_effect(card: DamageCard,
		ship: ShipInstance, flow_decision: Dictionary) -> void:
	var extra_card_data: Dictionary = {}
	if flow_decision.get("card_id", "") == "structural_damage":
		extra_card_data = _draw_structural_damage_extra(card)
	var result: Dictionary = GameManager.submit_resolve_immediate_effect(
			ship, card, {}, extra_card_data)
	if not result.is_empty():
		_emit_immediate_signals(card, ship, result)
		_log.info("Immediate effect resolved: '%s'." % card.title)
	else:
		_log.warn("Immediate effect failed: '%s'." % card.title)

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
##
## Phase I6b-3 R5 — chooser-controlled critical-choice modal.  In
## network mode the modal is opened by [AttackPanelMirror] on the
## chooser's peer when the chooser is not the local (attacker) peer;
## the published payload carries the full [code]choice_info[/code] +
## the [code]pending_card_data[/code] / ship indices needed to
## reconstruct the [DamageCard] / [ShipInstance] on the remote peer
## and submit a [ResolveImmediateEffectCommand].
func _start_immediate_choice_flow() -> void:
	_ensure_choice_modal()
	var chooser: String = _pending_immediate_choice.get("chooser", "opponent")
	var chooser_player: int = _get_chooser_player_index(chooser)
	# Phase I3: chooser controls the CRITICAL_CHOICE step.
	_flow_fsm.defender_player = chooser_player
	_fsm_advance(AttackFlowFSM.Step.CRITICAL_CHOICE)
	_fsm_patch_payload(_build_immediate_choice_payload(chooser, chooser_player))
	_log.info("Immediate choice flow: chooser='%s' (player %d), card='%s'."
			% [chooser, chooser_player,
			_pending_immediate_choice.get("card_title", "?")])
	# Phase I6b-3 R5 / Phase K4: in a network session the modal is
	# opened by the chooser peer's [AttackPanelMirror] from the
	# payload; only the local-attacker case opens here.
	var local_pi: int = NetworkManager.get_local_player_index()
	if local_pi >= 0:
		_dispatch_immediate_choice_network(chooser_player, local_pi)
		return
	# Hot-seat: handoff overlay rotates camera + waits for chooser to
	# dismiss before opening the modal.
	if _try_open_immediate_choice_handoff(chooser_player):
		return
	# Non-hot-seat or no handoff overlay: show modal directly.
	_show_immediate_choice_modal()


## Builds the FSM payload patch describing the pending immediate-effect
## choice so the chooser peer can render the modal from
## [member InteractionFlow.payload] alone.  Pure dictionary construction.
func _build_immediate_choice_payload(chooser: String,
		chooser_player: int) -> Dictionary:
	var card_index: int = -1
	var ship_owner: int = -1
	var ship_index: int = -1
	var card_data: Dictionary = {}
	if _pending_immediate_card != null and _pending_immediate_ship != null:
		card_index = _pending_immediate_ship.faceup_damage.find(
				_pending_immediate_card)
		ship_owner = _pending_immediate_ship.owner_player
		var gs: GameState = GameManager.current_game_state
		if gs:
			ship_index = gs.find_ship_index(_pending_immediate_ship)
		card_data = _pending_immediate_card.serialize()
	return {
		"chooser": chooser,
		"chooser_player": chooser_player,
		"card_title": _pending_immediate_choice.get("card_title", ""),
		"choice_info": _pending_immediate_choice.duplicate(true),
		"pending_card_data": card_data,
		"pending_card_index": card_index,
		"pending_ship_owner_player": ship_owner,
		"pending_ship_index": ship_index,
	}


## Network-mode dispatch for the immediate-effect choice modal.
## Opens locally iff the local peer is the chooser; otherwise logs and
## waits for the remote chooser to submit
## [ResolveImmediateEffectCommand].
func _dispatch_immediate_choice_network(chooser_player: int,
		local_pi: int) -> void:
	if chooser_player == local_pi:
		_show_immediate_choice_modal()
		return
	_log.info("Immediate choice deferred to remote chooser peer "
			+"(chooser_player=%d local=%d)."
			% [chooser_player, local_pi])


## Hot-seat handoff path for the immediate-effect choice modal.  Rotates
## the camera, shows the handoff overlay, and arms a one-shot listener
## that opens the modal once the chooser presses "Ready".  Returns
## [code]true[/code] when the handoff was armed (caller must not open
## the modal directly), [code]false[/code] when no camera/overlay is
## available and the caller should fall back to opening the modal now.
func _try_open_immediate_choice_handoff(chooser_player: int) -> bool:
	if _camera == null:
		return false
	_camera.rotate_to_player(chooser_player)
	if _handoff_overlay == null:
		return false
	var player_label: String = UIProjector.player_display_label(
			GameManager.current_game_state, chooser_player)
	_handoff_overlay.show_handoff(
			chooser_player, "Damage Card Choice", player_label)
	var vp_size: Vector2 = Vector2(1280, 720)
	if get_viewport():
		vp_size = get_viewport().get_visible_rect().size
	_handoff_overlay.update_size(vp_size)
	if not EventBus.handoff_accepted.is_connected(
			_on_immediate_handoff_accepted):
		EventBus.handoff_accepted.connect(
				_on_immediate_handoff_accepted, CONNECT_ONE_SHOT)
	return true

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
	var extra_card_data: Dictionary = _draw_structural_damage_extra(card)
	var result: Dictionary = GameManager.submit_resolve_immediate_effect(
			ship, card, selection, extra_card_data)
	if not result.is_empty():
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


## Draws the extra damage card required by the `structural_damage`
## immediate effect and returns its serialised payload, or an empty
## dictionary for other effect IDs / when no damage deck is wired.
func _draw_structural_damage_extra(card: DamageCard) -> Dictionary:
	if card.effect_id != "structural_damage" or _damage_deck == null:
		return {}
	var extra: DamageCard = _damage_deck.draw_card()
	if extra == null:
		return {}
	return extra.serialize()


## Phase I6b-3 R5 — runs on the attacker peer when the chooser peer's
## [ResolveImmediateEffectCommand] is broadcast back via
## [signal CommandProcessor.command_executed].  The command's
## [code]execute()[/code] already mutated state on both peers; this
## helper emits the visual signals (mirroring the local-mode
## [method _on_immediate_choice_confirmed] tail) and finalises the
## attack.  Idempotent — early-returns when no immediate choice is
## pending (e.g. attacker peer was the chooser and ran the local
## handler).
func apply_remote_immediate_choice(result: Dictionary) -> void:
	if _pending_immediate_card == null or _pending_immediate_ship == null:
		return
	var card: DamageCard = _pending_immediate_card
	var ship: ShipInstance = _pending_immediate_ship
	_pending_immediate_card = null
	_pending_immediate_ship = null
	_pending_immediate_choice = {}
	_emit_immediate_signals(card, ship, result)
	if ship.ship_data:
		var new_hull: int = ship.ship_data.hull - ship.get_total_damage()
		EventBus.ship_hull_changed.emit(ship, new_hull)
	_log.info("Immediate effect resolved (remote chooser): '%s'."
			% card.title)
	_attack_exec_finalize_after_delay()


## Emits the appropriate EventBus signals after a
## [ResolveImmediateEffectCommand] executes.  Delegates to the shared
## [ImmediateEffectSignals] helper so the attacker peer, the passive
## peer mirror, and the debug-damage tool all fire identical visuals.
func _emit_immediate_signals(card: DamageCard,
		ship: ShipInstance, result: Dictionary) -> void:
	ImmediateEffectSignals.emit(card, ship, result)


## Returns the player index for the given chooser role relative to the
## current attack's defender.
func _get_chooser_player_index(chooser: String) -> int:
	var def_inst: ShipInstance = _get_defender_instance()
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
	var attack: CurrentAttackState = _current_attack()
	if attack != null and attack.active:
		_pending_finalize_after_completion = true
		var result: Dictionary = GameManager.submit_complete_attack(
				attack.attacker_player)
		if not _is_waiting_for_remote_command_result(result) \
				and not result.is_empty() \
				and _pending_finalize_after_completion:
			apply_complete_attack_result(result)
		return
	_finalize_completed_attack()


func apply_complete_attack_result(result: Dictionary) -> void:
	if _pending_counter_begin:
		_pending_counter_begin = false
		_begin_counter_attack()
		return
	if _awaiting_result_acknowledgement:
		return
	var completed_attack_id: String = str(result.get("attack_id", ""))
	var accepted_live_completion: bool = not completed_attack_id.is_empty() \
			and completed_attack_id == _applied_damage_attack_id
	if not _pending_finalize_after_completion \
			and not _reconstructed_current_attack \
			and not accepted_live_completion:
		return
	_pending_finalize_after_completion = false
	_present_completed_attack_result()


## Presents the already-completed canonical result without performing another
## gameplay mutation. The local acknowledgement only resumes presentation.
func _present_completed_attack_result() -> void:
	var panel: AttackSimPanel = _get_panel()
	if panel == null:
		_finalize_completed_attack()
		return
	_awaiting_result_acknowledgement = true
	panel.show_result_confirmation()


func _on_attack_result_confirmed() -> void:
	if not _awaiting_result_acknowledgement:
		return
	_awaiting_result_acknowledgement = false
	_finalize_completed_attack()


func _finalize_completed_attack() -> void:
	if _get_panel():
		_get_panel().hide_confirm_button()
		_get_panel().hide_damage_info()
		_get_panel().hide_defense_section()
		_get_panel().hide_accuracy_section()
		_get_panel().hide_redirect_section()
	_rotate_camera_to_attacker()
	_sync_ship_attack_progress_from_authority()
	var projected_ship: ShipInstance = _authoritative_attack_ship()
	if projected_ship != null:
		_log.debug("Post-Complete projection from authoritative progress: %s" %
				JSON.stringify(projected_ship.attack_progress_snapshot()))
	if _reconstructed_current_attack \
			and not owns_authoritative_ship_attack_presentation():
		_finish_attack_execution()
		return
	if _state.squad_exec_mode:
		_finish_attack_execution()
		return
	# --- Squadron defender: Step 6 loop ---
	if _state.defender_squadron:
		_finalize_squadron_attack()
		return
	# --- Ship defender: two-hull-zone logic ---
	_continue_after_normal_attack()

## Rotates the camera back to the attacker’s perspective (AE-DEF-011).
## Phase K4: hot-seat detected via `local_player_index < 0`.  In
## network each peer's camera is locked to its own seat, so the
## rotate-back behaviour is hot-seat-only.
func _rotate_camera_to_attacker() -> void:
	if not _camera or NetworkManager.get_local_player_index() >= 0:
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
	if _get_overlay():
		_get_overlay().add_spent_zone_marker(
				_state.defender_squadron.global_position)
	_sync_ship_attack_progress_from_authority()
	var ship: ShipInstance = _authoritative_attack_ship()
	if ship != null and ship.anti_squadron_attack_zone >= 0:
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
	var attack: CurrentAttackState = _current_attack()
	if attack != null and attack.active:
		_pending_zero_squad_skip = true
		var result: Dictionary = GameManager.submit_skip_attack(
				attack.attacker_player, "cancelled")
		if _is_waiting_for_remote_command_result(result):
			return
		if result.is_empty():
			_pending_zero_squad_skip = false
			return
		if _pending_zero_squad_skip:
			apply_skip_attack_result(result)
		return
	_finish_zero_dice_squadron()


func _finish_zero_dice_squadron() -> void:
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
	_sync_ship_attack_progress_from_authority()
	_continue_after_normal_attack()


## Continues after one committed normal ship attack using only the activating
## ShipInstance's authoritative progress. Scene teardown cannot consume it.
func _continue_after_normal_attack() -> void:
	_attack_exec_mark_spent_zone()
	var ship: ShipInstance = _authoritative_attack_ship()
	if ship != null and ship.attack_step_active \
			and ship.committed_attack_count < 2:
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
	# Phase I6b-3 R1b: clear target identity in the published payload
	# so the non-attacker peer's mirror drops the previous squadron's
	# title until the next target is locked in.
	_publish_clear_target_patch()
	# Phase I6b-3 R2 follow-up: restart the FSM so it leaves
	# RESOLVE_DAMAGE and re-enters DECLARE.  Without this every
	# subsequent _fsm_advance() silently fails (illegal transition)
	# and the published InteractionFlow stays stuck at
	# ATTACK_RESOLVE_DAMAGE for the next attack, breaking the
	# defender mirror.
	var gs_restart: GameState = GameManager.current_game_state
	_flow_fsm.restart_for_next_attack(gs_restart)
	if gs_restart:
		GameManager.submit_publish_attack_flow(gs_restart.interaction_flow)
	# Clean up target visuals, keep spent zone markers.
	_target_selector.prepare_next_squadron_target()
	# Update panel with "Select next squadron" prompt.
	_show_next_squadron_panel_prompt()


## Resets the attack panel widgets for the next squadron-target loop
## iteration and shows the "Select next squadron" prompt with the
## skip-attack affordance.  Pure panel choreography — no flow-state
## mutation.
func _show_next_squadron_panel_prompt() -> void:
	if _get_panel() == null:
		return
	_get_panel().hide_dice_count()
	_get_panel().hide_dice_results()
	_get_panel().hide_confirm_button()
	_get_panel().hide_cf_dial_section()
	_get_panel().hide_cf_token_section()
	_get_panel().hide_roll_button()
	var ship_name: String = ""
	if _state.exec_ship_token.get_ship_data():
		ship_name = _state.exec_ship_token.get_ship_data().ship_name
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
	# Phase I6b-3 R1b: clear target identity in the published payload
	# so the non-attacker peer's mirror drops the first attack's title
	# until the second attack's DECLARE patch repopulates it.
	_publish_clear_target_patch()
	# Phase I6b-3 R2 follow-up: restart the FSM so it leaves
	# RESOLVE_DAMAGE and re-enters DECLARE for the second attack
	# (see _attack_exec_prepare_next_squadron for full rationale).
	var gs_restart: GameState = GameManager.current_game_state
	_flow_fsm.restart_for_next_attack(gs_restart)
	if gs_restart:
		GameManager.submit_publish_attack_flow(gs_restart.interaction_flow)
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
	if not _pending_declaration_command.is_empty():
		return
	# If we're in the Step 6 squadron loop (attacked >=1 squadron and
	# still target-selecting for the next one), treat as "done with
	# this hull zone's anti-squadron attacks."
	var ship: ShipInstance = _authoritative_attack_ship()
	if ship != null and ship.anti_squadron_attack_zone >= 0 and \
			_target_selector.is_target_selecting():
		_log.info(
				"Squadron loop skipped — moving to next hull zone.")
		var game_state: GameState = GameManager.current_game_state
		var ship_index: int = game_state.find_ship_index(ship) \
				if game_state != null else -1
		_pending_squadron_done_after_skip = true
		var loop_skip: Dictionary = GameManager.submit_skip_attack(
				_get_attacker_player(), "squadron_done", ship_index)
		if _is_waiting_for_remote_command_result(loop_skip):
			return
		if loop_skip.is_empty():
			_pending_squadron_done_after_skip = false
			return
		if _pending_squadron_done_after_skip:
			apply_skip_attack_result(loop_skip)
		return
	_log.info("Attack skipped by player.")
	var attack: CurrentAttackState = _current_attack()
	var declaration_skip: bool = attack == null or not attack.active
	if declaration_skip:
		_pending_declaration_command = "skip_attack"
		_target_selector.set_declaration_submission_pending(true)
	_pending_finish_after_skip = true
	var result: Dictionary = GameManager.submit_skip_attack(
			_get_attacker_player(), "voluntary")
	if _is_waiting_for_remote_command_result(result):
		return
	if result.is_empty():
		_pending_finish_after_skip = false
		if declaration_skip:
			_restore_declaration_after_rejection(
					"Skip attack was rejected.")
		return
	if _pending_finish_after_skip:
		apply_skip_attack_result(result)


func apply_skip_attack_result(result: Dictionary) -> void:
	if _pending_zero_squad_skip:
		_pending_zero_squad_skip = false
		_finish_zero_dice_squadron()
		return
	if _pending_squadron_done_after_skip:
		_pending_squadron_done_after_skip = false
		_end_squadron_loop()
		return
	if not _pending_finish_after_skip:
		return
	_pending_finish_after_skip = false
	if _pending_declaration_command == "skip_attack":
		_complete_declaration_submission()
	_finish_attack_execution()

## Fades out a destroyed token over 0.8 seconds, then hides it.
## Called when a ship or squadron is destroyed during an attack.
## Rules Reference: GF-004 — destroyed ships are removed from play.
func _fade_out_token(token: Node2D) -> void:
	if token == null or token.has_meta(&"destruction_fade_started"):
		return
	token.set_meta(&"destruction_fade_started", true)
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
