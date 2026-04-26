## AttackFlowFSM
##
## Authoritative state machine for the attack interaction flow.
## Tracks the current attack step and writes it into
## [GameState.interaction_flow] so that both clients (and reconnecting
## spectators) can render the correct UI from a single state snapshot.
##
## Steps and legal transitions:
## [codeblock]
##   IDLE
##     -> DECLARE             (attack target locked)
##     -> END                 (attack cancelled / no target)
##   DECLARE
##     -> ROLL                (player presses Roll Dice)
##     -> END
##   ROLL
##     -> MODIFY              (after dice are shown)
##     -> END
##   MODIFY
##     -> DEFENSE_TOKENS      (defender can spend tokens)
##     -> RESOLVE_DAMAGE      (defender has nothing to spend)
##     -> END
##   DEFENSE_TOKENS
##     -> RESOLVE_DAMAGE      (defender done)
##     -> END
##   RESOLVE_DAMAGE
##     -> CRITICAL_CHOICE     (immediate-effect card requires a player choice)
##     -> END                 (no choice required)
##   CRITICAL_CHOICE
##     -> END                 (choice resolved)
## [/codeblock]
##
## **Phase I3a (this commit)** — additive only.  The FSM tracks step IDs
## and updates [GameState.interaction_flow]; existing attack_executor.gd
## logic remains unchanged.  Subsequent I3 sub-steps will progressively
## move command production into the FSM.
##
## See [code]docs/refactoring_phase_i_plan.md[/code] §I3.
class_name AttackFlowFSM
extends RefCounted


# ---------------------------------------------------------------------------
# Step definitions
# ---------------------------------------------------------------------------

## FSM step values.  Map 1-to-1 onto [enum Constants.InteractionStep]
## entries via [member STEP_TO_INTERACTION].
enum Step {
	IDLE,
	DECLARE,
	ROLL,
	MODIFY,
	DEFENSE_TOKENS,
	RESOLVE_DAMAGE,
	CRITICAL_CHOICE,
	END,
}


## Mapping from [enum Step] to [enum Constants.InteractionStep] for
## populating [GameState.interaction_flow.step_id].
const STEP_TO_INTERACTION: Dictionary = {
	Step.IDLE: Constants.InteractionStep.NONE,
	Step.DECLARE: Constants.InteractionStep.ATTACK_DECLARE,
	Step.ROLL: Constants.InteractionStep.ATTACK_ROLL,
	Step.MODIFY: Constants.InteractionStep.ATTACK_MODIFY,
	Step.DEFENSE_TOKENS: Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
	Step.RESOLVE_DAMAGE: Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE,
	Step.CRITICAL_CHOICE: Constants.InteractionStep.ATTACK_CRITICAL_CHOICE,
	Step.END: Constants.InteractionStep.NONE,
}


## Legal step transitions.  END is reachable from every active step.
const _LEGAL_TRANSITIONS: Dictionary = {
	Step.IDLE: [Step.DECLARE, Step.END],
	Step.DECLARE: [Step.ROLL, Step.END],
	Step.ROLL: [Step.MODIFY, Step.END],
	Step.MODIFY: [Step.DEFENSE_TOKENS, Step.RESOLVE_DAMAGE, Step.END],
	Step.DEFENSE_TOKENS: [Step.RESOLVE_DAMAGE, Step.END],
	Step.RESOLVE_DAMAGE: [Step.CRITICAL_CHOICE, Step.END],
	Step.CRITICAL_CHOICE: [Step.END],
	Step.END: [Step.IDLE, Step.DECLARE],  # End may restart for a new attack.
}


# ---------------------------------------------------------------------------
# Fields
# ---------------------------------------------------------------------------

## Current FSM step.
var current_step: Step = Step.IDLE

## Player index of the attacker (controller of DECLARE/ROLL/MODIFY).
var attacker_player: int = -1

## Player index of the defender (controller of DEFENSE_TOKENS,
## CRITICAL_CHOICE).  −1 for squadron-vs-squadron with no defender player.
var defender_player: int = -1

## Optional payload mirrored into [member InteractionFlow.payload].
## Plain JSON-safe types only.
var payload: Dictionary = {}


# ---------------------------------------------------------------------------
# Transitions
# ---------------------------------------------------------------------------

## Resets the FSM to IDLE without writing to [param game_state].
## Used between attacks; call [method begin] to start a new one.
func reset() -> void:
	current_step = Step.IDLE
	attacker_player = -1
	defender_player = -1
	payload = {}


## Starts a new attack flow.  Sets attacker / defender / payload and
## transitions IDLE → DECLARE.  Writes [GameState.interaction_flow].
func begin(game_state: GameState, p_attacker: int, p_defender: int,
		p_payload: Dictionary = {}) -> void:
	current_step = Step.IDLE
	attacker_player = p_attacker
	defender_player = p_defender
	payload = p_payload.duplicate(true)
	_transition(game_state, Step.DECLARE)


## Advances to [param next_step].  Rejects illegal transitions by
## returning [code]false[/code] and leaving state unchanged.  Callers are
## expected to honour the [enum Step] transition table; the FSM stays
## silent so that defensive double-calls (idempotency probes) are cheap.
func advance(game_state: GameState, next_step: Step) -> bool:
	if not _is_legal_transition(current_step, next_step):
		return false
	_transition(game_state, next_step)
	return true


## Convenience: terminate the flow.
func end(game_state: GameState) -> void:
	advance(game_state, Step.END)
	# After END, clear interaction_flow so the next non-attack flow can own it.
	if game_state != null:
		game_state.interaction_flow = InteractionFlow.empty()


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

## Returns the [enum Constants.InteractionStep] equivalent of the current
## FSM step.
func get_interaction_step() -> Constants.InteractionStep:
	return STEP_TO_INTERACTION.get(current_step,
			Constants.InteractionStep.NONE) as Constants.InteractionStep


## Returns the player index whose UI must drive the current step.
##
##   DECLARE / ROLL / MODIFY            -> attacker
##   DEFENSE_TOKENS / CRITICAL_CHOICE   -> defender (or attacker if no defender)
##   IDLE / END                         -> -1
func get_controller_player() -> int:
	match current_step:
		Step.DECLARE, Step.ROLL, Step.MODIFY, Step.RESOLVE_DAMAGE:
			return attacker_player
		Step.DEFENSE_TOKENS, Step.CRITICAL_CHOICE:
			if defender_player >= 0:
				return defender_player
			return attacker_player
		_:
			return -1


## Returns true when [param player_index] must act on the current step.
func is_actor(player_index: int) -> bool:
	return get_controller_player() == player_index


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _is_legal_transition(from: Step, to: Step) -> bool:
	var allowed: Array = _LEGAL_TRANSITIONS.get(from, []) as Array
	return allowed.has(to)


func _transition(game_state: GameState, next: Step) -> void:
	current_step = next
	if game_state == null:
		return
	game_state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			get_interaction_step(),
			get_controller_player(),
			Constants.Visibility.ALL,
			payload)


static func _name(s: Step) -> String:
	match s:
		Step.IDLE: return "IDLE"
		Step.DECLARE: return "DECLARE"
		Step.ROLL: return "ROLL"
		Step.MODIFY: return "MODIFY"
		Step.DEFENSE_TOKENS: return "DEFENSE_TOKENS"
		Step.RESOLVE_DAMAGE: return "RESOLVE_DAMAGE"
		Step.CRITICAL_CHOICE: return "CRITICAL_CHOICE"
		Step.END: return "END"
		_: return "UNKNOWN"
