## FlowSpec
##
## Machine-readable Phase M skeleton for valid interaction-flow steps.
## It translates [code]docs/game_flow.md[/code] into static metadata without
## mutating game state or replacing current projector/command behaviour.
class_name FlowSpec
extends RefCounted


## Flow entry came from a command-produced interaction-flow state.
const SOURCE_COMMAND_PRODUCED: String = "command_produced"

## Flow entry is retained for projector, legacy-map, or presentation parity.
const SOURCE_PROJECTION_ONLY: String = "projection_only"

const _SPEC: Dictionary = {
	Constants.InteractionFlow.NONE: {
		Constants.InteractionStep.NONE: {
			"controller_role": Constants.ControllerRole.NONE,
			"modals": [Constants.ModalKind.NONE],
			"allowed_commands": [],
			"transitions": {},
			"source": SOURCE_COMMAND_PRODUCED,
			"rule_citation": "System empty flow.",
		},
	},
	Constants.InteractionFlow.COMMAND_PHASE: {
		Constants.InteractionStep.SELECT_DIALS: {
			"controller_role": Constants.ControllerRole.EITHER_PLAYER,
			"modals": [Constants.ModalKind.COMMAND_DIALS],
			"allowed_commands": ["assign_dials"],
			"transitions": {"assign_dials": "WAIT_FOR_OPPONENT_DIALS"},
			"source": SOURCE_PROJECTION_ONLY,
			"rule_citation": "RRG Command Phase, p.3.",
		},
		Constants.InteractionStep.WAIT_FOR_OPPONENT_DIALS: {
			"controller_role": Constants.ControllerRole.EITHER_PLAYER,
			"modals": [Constants.ModalKind.COMMAND_DIALS],
			"allowed_commands": ["assign_dials"],
			"transitions": {"assign_dials": "SHIP_ACTIVATION/WAIT_FOR_SHIP_SELECT"},
			"source": SOURCE_PROJECTION_ONLY,
			"rule_citation": "RRG Command Phase, p.3.",
		},
	},
	Constants.InteractionFlow.SHIP_ACTIVATION: {
		Constants.InteractionStep.WAIT_FOR_SHIP_SELECT: {
			"controller_role": Constants.ControllerRole.ACTIVE_PLAYER,
			"modals": [Constants.ModalKind.NONE],
			"allowed_commands": ["activate_ship", "reveal_dial", "convert_dial_to_token"],
			"transitions": {"activate_ship": "ACTIVATION_MODAL_OPEN"},
			"source": SOURCE_COMMAND_PRODUCED,
			"rule_citation": "RRG Ship Phase, ship activation.",
		},
		Constants.InteractionStep.ACTIVATION_MODAL_OPEN: {
			"controller_role": Constants.ControllerRole.ACTIVE_PLAYER,
			"modals": [Constants.ModalKind.ACTIVATION],
			"allowed_commands": ["advance_activation_step", "spend_dial",
					"spend_token", "convert_dial_to_token", "move_squadron",
					"execute_maneuver", "end_activation"],
			"transitions": {"advance_activation_step": "*",
					"move_squadron": "SQUADRON_STEP",
					"execute_maneuver": "MANEUVER_STEP",
					"end_activation": "WAIT_FOR_SHIP_SELECT"},
			"source": SOURCE_COMMAND_PRODUCED,
			"rule_citation": "RRG Ship Phase and command resolution rules.",
		},
		Constants.InteractionStep.REVEAL_DIAL: {
			"controller_role": Constants.ControllerRole.ACTIVE_PLAYER,
			"modals": [Constants.ModalKind.ACTIVATION],
			"allowed_commands": ["activate_ship", "reveal_dial"],
			"transitions": {"reveal_dial": "ACTIVATION_MODAL_OPEN"},
			"source": SOURCE_PROJECTION_ONLY,
			"rule_citation": "RRG Ship Phase, reveal command dial.",
		},
		Constants.InteractionStep.SPEND_DIAL: {
			"controller_role": Constants.ControllerRole.ACTIVE_PLAYER,
			"modals": [Constants.ModalKind.ACTIVATION],
			"allowed_commands": ["spend_dial", "convert_dial_to_token"],
			"transitions": {"spend_dial": "ACTIVATION_MODAL_OPEN"},
			"source": SOURCE_PROJECTION_ONLY,
			"rule_citation": "RRG Command Dials, p.3; Command Tokens, p.4.",
		},
		Constants.InteractionStep.SQUADRON_STEP: {
			"controller_role": Constants.ControllerRole.ACTIVE_PLAYER,
			"modals": [Constants.ModalKind.SQUADRON],
			"allowed_commands": ["advance_activation_step", "spend_dial",
					"spend_token", "move_squadron", "publish_attack_flow"],
			"transitions": {"advance_activation_step": "REPAIR_STEP"},
			"source": SOURCE_COMMAND_PRODUCED,
			"rule_citation": "RRG Squadron command activation rules.",
		},
		Constants.InteractionStep.REPAIR_STEP: {
			"controller_role": Constants.ControllerRole.ACTIVE_PLAYER,
			"modals": [Constants.ModalKind.ACTIVATION],
			"allowed_commands": ["repair_action", "spend_dial", "spend_token",
					"advance_activation_step"],
			"transitions": {"advance_activation_step": "ATTACK_STEP"},
			"source": SOURCE_COMMAND_PRODUCED,
			"rule_citation": "RRG Engineering, p.4.",
		},
		Constants.InteractionStep.ATTACK_STEP: {
			"controller_role": Constants.ControllerRole.ACTIVE_PLAYER,
			"modals": [Constants.ModalKind.ACTIVATION],
			"allowed_commands": ["publish_attack_flow", "skip_attack",
					"advance_activation_step"],
			"transitions": {"publish_attack_flow": "ATTACK/ATTACK_DECLARE"},
			"source": SOURCE_COMMAND_PRODUCED,
			"rule_citation": "RRG Attack, p.2; Ship Phase attack step.",
		},
		Constants.InteractionStep.MANEUVER_STEP: {
			"controller_role": Constants.ControllerRole.ACTIVE_PLAYER,
			"modals": [Constants.ModalKind.ACTIVATION],
			"allowed_commands": ["execute_maneuver", "start_displacement",
					"overlap_damage", "advance_activation_step", "end_activation"],
			"transitions": {"start_displacement": "SQUADRON_DISPLACEMENT/DISPLACEMENT_PLACE"},
			"source": SOURCE_COMMAND_PRODUCED,
			"rule_citation": "RRG Ship Phase maneuver; RRG Overlapping, p.8.",
		},
		Constants.InteractionStep.ACTIVATION_DONE: {
			"controller_role": Constants.ControllerRole.ACTIVE_PLAYER,
			"modals": [Constants.ModalKind.ACTIVATION],
			"allowed_commands": ["end_activation", "advance_activation_step"],
			"transitions": {"end_activation": "WAIT_FOR_SHIP_SELECT"},
			"source": SOURCE_COMMAND_PRODUCED,
			"rule_citation": "RRG Ship Phase; SP-001/SP-010.",
		},
	},
	Constants.InteractionFlow.SQUADRON_ACTIVATION: {
		Constants.InteractionStep.WAIT_FOR_SQUAD_SELECT: {
			"controller_role": Constants.ControllerRole.ACTIVE_PLAYER,
			"modals": [Constants.ModalKind.NONE],
			"allowed_commands": ["activate_squadron"],
			"transitions": {"activate_squadron": "ACTION_CHOICE"},
			"source": SOURCE_COMMAND_PRODUCED,
			"rule_citation": "RRG Squadron Phase, p.12; SQ-003.",
		},
		Constants.InteractionStep.ACTION_CHOICE: {
			"controller_role": Constants.ControllerRole.ACTIVE_PLAYER,
			"modals": [Constants.ModalKind.SQUADRON],
			"allowed_commands": ["activate_squadron", "move_squadron",
					"publish_attack_flow"],
			"transitions": {"activate_squadron": "ACTION_CHOICE",
					"move_squadron": "SQUAD_MOVE"},
			"source": SOURCE_COMMAND_PRODUCED,
			"rule_citation": "RRG Squadron Phase, p.12.",
		},
		Constants.InteractionStep.SQUAD_MOVE: {
			"controller_role": Constants.ControllerRole.ACTIVE_PLAYER,
			"modals": [Constants.ModalKind.SQUADRON],
			"allowed_commands": ["move_squadron"],
			"transitions": {"move_squadron": "ACTION_CHOICE"},
			"source": SOURCE_PROJECTION_ONLY,
			"rule_citation": "RRG Squadron Phase movement rules.",
		},
		Constants.InteractionStep.SQUAD_ATTACK: {
			"controller_role": Constants.ControllerRole.ACTIVE_PLAYER,
			"modals": [Constants.ModalKind.SQUADRON],
			"allowed_commands": ["publish_attack_flow", "skip_attack"],
			"transitions": {"publish_attack_flow": "ATTACK/ATTACK_DECLARE"},
			"source": SOURCE_PROJECTION_ONLY,
			"rule_citation": "RRG Squadron Attacks, p.19.",
		},
	},
	Constants.InteractionFlow.ATTACK: {
		Constants.InteractionStep.ATTACK_DECLARE: {
			"controller_role": Constants.ControllerRole.ATTACKER,
			"modals": [Constants.ModalKind.ATTACK_DECLARE],
			"allowed_commands": ["publish_attack_flow", "skip_attack"],
			"transitions": {"publish_attack_flow": "ATTACK_ROLL"},
			"source": SOURCE_COMMAND_PRODUCED,
			"rule_citation": "RRG Attack, declare target, p.2.",
		},
		Constants.InteractionStep.ATTACK_ROLL: {
			"controller_role": Constants.ControllerRole.ATTACKER,
			"modals": [Constants.ModalKind.ATTACK_ROLL],
			"allowed_commands": ["roll_dice", "publish_attack_flow", "skip_attack"],
			"transitions": {"roll_dice": "ATTACK_MODIFY"},
			"source": SOURCE_COMMAND_PRODUCED,
			"rule_citation": "RRG Attack, roll attack dice, p.2.",
		},
		Constants.InteractionStep.ATTACK_MODIFY: {
			"controller_role": Constants.ControllerRole.ATTACKER,
			"modals": [Constants.ModalKind.ATTACK_MODIFY],
			"allowed_commands": ["spend_dial", "spend_token", "publish_attack_flow",
					"skip_attack"],
			"transitions": {"publish_attack_flow": "ATTACK_DEFENSE_TOKENS"},
			"source": SOURCE_COMMAND_PRODUCED,
			"rule_citation": "RRG Attack, modify dice, p.2.",
		},
		Constants.InteractionStep.ATTACK_DEFENSE_TOKENS: {
			"controller_role": Constants.ControllerRole.DEFENDER_OR_ATTACKER,
			"modals": [Constants.ModalKind.ATTACK_DEFENSE_TOKENS],
			"allowed_commands": ["spend_defense_token", "commit_defense",
					"select_evade_die", "select_redirect_zone", "redirect_done",
					"publish_attack_flow"],
			"transitions": {"commit_defense": "ATTACK_RESOLVE_DAMAGE"},
			"source": SOURCE_COMMAND_PRODUCED,
			"rule_citation": "RRG Defense Tokens, p.4; Attack spend defense tokens.",
		},
		Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE: {
			"controller_role": Constants.ControllerRole.ATTACKER,
			"modals": [Constants.ModalKind.ATTACK_RESOLVE_DAMAGE],
			"allowed_commands": ["resolve_damage", "resolve_immediate_effect",
					"publish_attack_flow"],
			"transitions": {"resolve_damage": "ATTACK_CRITICAL_CHOICE"},
			"source": SOURCE_COMMAND_PRODUCED,
			"rule_citation": "RRG Attack, resolve damage, p.2.",
		},
		Constants.InteractionStep.ATTACK_CRITICAL_CHOICE: {
			"controller_role": Constants.ControllerRole.PAYLOAD_CONTROLLER,
			"modals": [Constants.ModalKind.ATTACK_CRITICAL_CHOICE],
			"allowed_commands": ["resolve_immediate_effect", "publish_attack_flow"],
			"transitions": {"resolve_immediate_effect": "NONE/NONE"},
			"source": SOURCE_COMMAND_PRODUCED,
			"rule_citation": "Damage-card immediate effect text; RRG damage cards.",
		},
	},
	Constants.InteractionFlow.SQUADRON_DISPLACEMENT: {
		Constants.InteractionStep.DISPLACEMENT_PLACE: {
			"controller_role": Constants.ControllerRole.OPPOSING_PLAYER,
			"modals": [Constants.ModalKind.DISPLACEMENT],
			"allowed_commands": ["commit_displacement"],
			"transitions": {"commit_displacement": "NONE/NONE"},
			"source": SOURCE_COMMAND_PRODUCED,
			"rule_citation": "RRG Overlapping, p.8; OV-001 to OV-004.",
		},
	},
	Constants.InteractionFlow.STATUS_CLEANUP: {
		Constants.InteractionStep.STATUS_CLEANUP_STEP: {
			"controller_role": Constants.ControllerRole.SYSTEM,
			"modals": [Constants.ModalKind.STATUS_CLEANUP],
			"allowed_commands": ["status_phase_cleanup", "start_round"],
			"transitions": {"start_round": "COMMAND_PHASE/SELECT_DIALS"},
			"source": SOURCE_PROJECTION_ONLY,
			"rule_citation": "RRG Status Phase, p.6; ST-001/ST-004.",
		},
	},
	Constants.InteractionFlow.GAME_OVER: {
		Constants.InteractionStep.GAME_OVER_STEP: {
			"controller_role": Constants.ControllerRole.NONE,
			"modals": [Constants.ModalKind.GAME_OVER],
			"allowed_commands": [],
			"transitions": {},
			"source": SOURCE_PROJECTION_ONLY,
			"rule_citation": "RRG End of Game; Constants.MAX_ROUNDS.",
		},
	},
}


## Returns the spec for a valid (flow_id, step_id), or an empty Dictionary.
## The returned dictionary is deep-copied so callers cannot mutate the table.
static func get_spec(flow_id: int, step_id: int) -> Dictionary:
	var spec: Dictionary = _get_spec_ref(flow_id, step_id)
	if spec.is_empty():
		return {}
	return spec.duplicate(true)


## Returns true when the given (flow_id, step_id) pair is registered.
static func has_spec(flow_id: int, step_id: int) -> bool:
	return not _get_spec_ref(flow_id, step_id).is_empty()


## Returns every registered flow/step pair for parity tests and tooling.
static func all_pairs() -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	for flow_id: Variant in _SPEC.keys():
		var step_specs: Dictionary = _SPEC.get(flow_id, {})
		for step_id: Variant in step_specs.keys():
			pairs.append({"flow_id": int(flow_id), "step_id": int(step_id)})
	return pairs


## Returns the semantic controller role for a registered pair.
static func controller_role(
		flow_id: int,
		step_id: int) -> Constants.ControllerRole:
	var spec: Dictionary = _get_spec_ref(flow_id, step_id)
	return (int(spec.get("controller_role", Constants.ControllerRole.NONE))
			as Constants.ControllerRole)


## Resolves a semantic controller role to a concrete player index.
## Returns -1 when the role is non-human or the supplied context is incomplete.
static func resolve_controller_player(
		flow_id: int,
		step_id: int,
		game_state: GameState,
		context: Dictionary = {}) -> int:
	match controller_role(flow_id, step_id):
		Constants.ControllerRole.ACTIVE_PLAYER:
			return _active_player_for(flow_id, step_id, game_state, context)
		Constants.ControllerRole.OPPOSING_PLAYER:
			return _opposing_player_for(context)
		Constants.ControllerRole.ATTACKER:
			return _attacker_for(flow_id, step_id, game_state, context)
		Constants.ControllerRole.DEFENDER_OR_ATTACKER:
			return _defender_or_attacker_for(flow_id, step_id, game_state, context)
		Constants.ControllerRole.PAYLOAD_CONTROLLER:
			return _payload_controller_for(flow_id, step_id, game_state, context)
		Constants.ControllerRole.EITHER_PLAYER:
			return _either_player_for(context)
		Constants.ControllerRole.NONE, Constants.ControllerRole.SYSTEM:
			return -1
		_:
			return -1


## Builds an [InteractionFlow] with [member InteractionFlow.controller_player]
## resolved from this spec's semantic controller role.
static func make_interaction_flow(
		flow_id: Constants.InteractionFlow,
		step_id: Constants.InteractionStep,
		game_state: GameState,
		context: Dictionary = {},
		visible_to: Constants.Visibility = Constants.Visibility.ALL,
		payload: Dictionary = {}) -> InteractionFlow:
	var controller: int = resolve_controller_player(
			int(flow_id), int(step_id), game_state, context)
	return InteractionFlow.make(
			flow_id,
			step_id,
			controller,
			visible_to,
			payload)


static func _get_spec_ref(flow_id: int, step_id: int) -> Dictionary:
	var step_specs: Dictionary = _SPEC.get(flow_id, {})
	return step_specs.get(step_id, {})


static func _active_player_for(
		flow_id: int,
		step_id: int,
		game_state: GameState,
		context: Dictionary) -> int:
	var active_player: int = _first_valid_player(context, ["active_player"])
	if active_player != -1:
		return active_player
	return _matching_flow_controller(flow_id, step_id, game_state)


static func _opposing_player_for(context: Dictionary) -> int:
	var acting_player: int = _first_valid_player(context, [
			"moving_player", "active_player"])
	return _opponent_of(acting_player)


static func _attacker_for(
		flow_id: int,
		step_id: int,
		game_state: GameState,
		context: Dictionary) -> int:
	var attacker: int = _first_valid_player(context, ["attacker_player"])
	if attacker != -1:
		return attacker
	return _matching_flow_controller(flow_id, step_id, game_state)


static func _defender_or_attacker_for(
		flow_id: int,
		step_id: int,
		game_state: GameState,
		context: Dictionary) -> int:
	var defender: int = _first_valid_player(context, ["defender_player"])
	if defender != -1:
		return defender
	var attacker: int = _first_valid_player(context, ["attacker_player"])
	if attacker != -1:
		return attacker
	return _matching_flow_controller(flow_id, step_id, game_state)


static func _payload_controller_for(
		flow_id: int,
		step_id: int,
		game_state: GameState,
		context: Dictionary) -> int:
	var controller: int = _first_valid_player(context, ["controller_player"])
	if controller != -1:
		return controller
	return _matching_flow_controller(flow_id, step_id, game_state)


static func _either_player_for(context: Dictionary) -> int:
	return _first_valid_player(context, [
			"controller_player", "active_player", "viewer_player"])


static func _matching_flow_controller(
		flow_id: int,
		step_id: int,
		game_state: GameState) -> int:
	if game_state == null or game_state.interaction_flow == null:
		return -1
	var flow: InteractionFlow = game_state.interaction_flow
	if int(flow.flow_type) != flow_id or int(flow.step_id) != step_id:
		return -1
	return _valid_or_unresolved(flow.controller_player)


static func _first_valid_player(context: Dictionary, keys: Array[String]) -> int:
	for key: String in keys:
		if context.has(key):
			var player_index: int = int(context.get(key, -1))
			if _is_valid_player(player_index):
				return player_index
	return -1


static func _opponent_of(player_index: int) -> int:
	if not _is_valid_player(player_index):
		return -1
	return Constants.PLAYER_COUNT - 1 - player_index


static func _valid_or_unresolved(player_index: int) -> int:
	if _is_valid_player(player_index):
		return player_index
	return -1


static func _is_valid_player(player_index: int) -> bool:
	return player_index >= 0 and player_index < Constants.PLAYER_COUNT