## Unit tests for [AttackFlowFSM] (Phase I3a).
##
## Covers state-transition validity, controller-player resolution,
## interaction-flow population, and edge cases (no defender, illegal
## transitions, end+restart).
extends GutTest


func _make_state() -> GameState:
	return GameState.new()


# ---------------------------------------------------------------------------
# Initial state
# ---------------------------------------------------------------------------

func test_new_fsm_starts_idle() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	assert_eq(fsm.current_step, AttackFlowFSM.Step.IDLE,
			"New FSM must start in IDLE.")
	assert_eq(fsm.attacker_player, -1, "Attacker defaults to -1.")
	assert_eq(fsm.defender_player, -1, "Defender defaults to -1.")
	assert_eq(fsm.payload, {}, "Payload defaults to empty dict.")


func test_get_interaction_step_in_idle_is_none() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	assert_eq(fsm.get_interaction_step(),
			Constants.InteractionStep.NONE,
			"IDLE maps to InteractionStep.NONE.")


func test_get_controller_in_idle_is_minus_one() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	assert_eq(fsm.get_controller_player(), -1,
			"IDLE has no controller.")


# ---------------------------------------------------------------------------
# begin()
# ---------------------------------------------------------------------------

func test_begin_transitions_to_declare() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {"foo": "bar"})
	assert_eq(fsm.current_step, AttackFlowFSM.Step.DECLARE,
			"begin() must transition to DECLARE.")
	assert_eq(fsm.attacker_player, 0)
	assert_eq(fsm.defender_player, 1)
	assert_eq(fsm.payload, {"foo": "bar"})


func test_begin_writes_interaction_flow() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {})
	assert_eq(gs.interaction_flow.flow_type,
			Constants.InteractionFlow.ATTACK,
			"interaction_flow.flow_type must be ATTACK.")
	assert_eq(gs.interaction_flow.step_id,
			Constants.InteractionStep.ATTACK_DECLARE,
			"step_id must be ATTACK_DECLARE.")
	assert_eq(gs.interaction_flow.controller_player, 0,
			"DECLARE controller is the attacker.")


func test_begin_with_null_state_does_not_crash() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	fsm.begin(null, 0, 1, {})
	assert_eq(fsm.current_step, AttackFlowFSM.Step.DECLARE,
			"Null game_state is permitted (test mode).")


func test_begin_duplicates_payload() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	var src: Dictionary = {"k": [1, 2]}
	fsm.begin(gs, 0, 1, src)
	src["k"] = [9]
	assert_ne(fsm.payload["k"], src["k"],
			"begin() must deep-copy payload to insulate from caller.")


# ---------------------------------------------------------------------------
# Legal transitions (full happy path)
# ---------------------------------------------------------------------------

func test_full_happy_path_with_defense() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {})
	# DECLARE -> ROLL
	assert_true(fsm.advance(gs, AttackFlowFSM.Step.ROLL))
	assert_eq(fsm.current_step, AttackFlowFSM.Step.ROLL)
	# ROLL -> MODIFY
	assert_true(fsm.advance(gs, AttackFlowFSM.Step.MODIFY))
	assert_eq(fsm.current_step, AttackFlowFSM.Step.MODIFY)
	# MODIFY -> DEFENSE_TOKENS
	assert_true(fsm.advance(gs, AttackFlowFSM.Step.DEFENSE_TOKENS))
	assert_eq(fsm.current_step, AttackFlowFSM.Step.DEFENSE_TOKENS)
	# DEFENSE_TOKENS -> RESOLVE_DAMAGE
	assert_true(fsm.advance(gs, AttackFlowFSM.Step.RESOLVE_DAMAGE))
	assert_eq(fsm.current_step, AttackFlowFSM.Step.RESOLVE_DAMAGE)
	# RESOLVE_DAMAGE -> END
	assert_true(fsm.advance(gs, AttackFlowFSM.Step.END))
	assert_eq(fsm.current_step, AttackFlowFSM.Step.END)


func test_modify_can_skip_defense_when_no_tokens() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {})
	fsm.advance(gs, AttackFlowFSM.Step.ROLL)
	fsm.advance(gs, AttackFlowFSM.Step.MODIFY)
	assert_true(fsm.advance(gs, AttackFlowFSM.Step.RESOLVE_DAMAGE),
			"MODIFY -> RESOLVE_DAMAGE is legal (no defense tokens branch).")


func test_resolve_damage_to_critical_choice() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {})
	fsm.advance(gs, AttackFlowFSM.Step.ROLL)
	fsm.advance(gs, AttackFlowFSM.Step.MODIFY)
	fsm.advance(gs, AttackFlowFSM.Step.RESOLVE_DAMAGE)
	assert_true(fsm.advance(gs, AttackFlowFSM.Step.CRITICAL_CHOICE),
			"Critical-effect branch is legal from RESOLVE_DAMAGE.")
	assert_true(fsm.advance(gs, AttackFlowFSM.Step.END))


# ---------------------------------------------------------------------------
# Illegal transitions
# ---------------------------------------------------------------------------

func test_idle_to_roll_is_illegal() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	assert_false(fsm.advance(gs, AttackFlowFSM.Step.ROLL),
			"IDLE -> ROLL must be rejected.")
	assert_eq(fsm.current_step, AttackFlowFSM.Step.IDLE,
			"State must be unchanged after illegal transition.")


func test_declare_to_resolve_is_illegal() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {})
	assert_false(fsm.advance(gs, AttackFlowFSM.Step.RESOLVE_DAMAGE),
			"DECLARE -> RESOLVE_DAMAGE must be rejected.")


func test_roll_to_defense_is_illegal() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {})
	fsm.advance(gs, AttackFlowFSM.Step.ROLL)
	assert_false(fsm.advance(gs, AttackFlowFSM.Step.DEFENSE_TOKENS),
			"ROLL -> DEFENSE_TOKENS must be rejected.")


func test_defense_to_critical_is_illegal() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {})
	fsm.advance(gs, AttackFlowFSM.Step.ROLL)
	fsm.advance(gs, AttackFlowFSM.Step.MODIFY)
	fsm.advance(gs, AttackFlowFSM.Step.DEFENSE_TOKENS)
	assert_false(fsm.advance(gs, AttackFlowFSM.Step.CRITICAL_CHOICE),
			"DEFENSE_TOKENS -> CRITICAL_CHOICE must be rejected.")


func test_critical_to_resolve_is_illegal() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {})
	fsm.advance(gs, AttackFlowFSM.Step.ROLL)
	fsm.advance(gs, AttackFlowFSM.Step.MODIFY)
	fsm.advance(gs, AttackFlowFSM.Step.RESOLVE_DAMAGE)
	fsm.advance(gs, AttackFlowFSM.Step.CRITICAL_CHOICE)
	assert_false(fsm.advance(gs, AttackFlowFSM.Step.RESOLVE_DAMAGE),
			"CRITICAL_CHOICE only transitions to END.")


# ---------------------------------------------------------------------------
# end() behaviour
# ---------------------------------------------------------------------------

func test_end_clears_interaction_flow() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {})
	assert_eq(gs.interaction_flow.flow_type,
			Constants.InteractionFlow.ATTACK)
	fsm.end(gs)
	assert_eq(gs.interaction_flow.flow_type,
			Constants.InteractionFlow.NONE,
			"end() must clear interaction_flow back to NONE.")
	assert_eq(gs.interaction_flow.step_id,
			Constants.InteractionStep.NONE)


func test_end_from_declare_is_legal() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {})
	fsm.end(gs)
	assert_eq(fsm.current_step, AttackFlowFSM.Step.END)


func test_reset_returns_to_idle() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {"x": 1})
	fsm.advance(gs, AttackFlowFSM.Step.ROLL)
	fsm.reset()
	assert_eq(fsm.current_step, AttackFlowFSM.Step.IDLE)
	assert_eq(fsm.attacker_player, -1)
	assert_eq(fsm.defender_player, -1)
	assert_eq(fsm.payload, {})


func test_can_restart_after_end() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {})
	fsm.end(gs)
	# After END the FSM accepts a new DECLARE without reset().
	assert_true(fsm.advance(gs, AttackFlowFSM.Step.DECLARE))
	assert_eq(fsm.current_step, AttackFlowFSM.Step.DECLARE)


# ---------------------------------------------------------------------------
# Controller-player resolution
# ---------------------------------------------------------------------------

func test_attacker_controls_declare() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {})
	assert_eq(fsm.get_controller_player(), 0,
			"DECLARE controller is the attacker.")


func test_attacker_controls_roll() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {})
	fsm.advance(gs, AttackFlowFSM.Step.ROLL)
	assert_eq(fsm.get_controller_player(), 0)


func test_attacker_controls_modify() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {})
	fsm.advance(gs, AttackFlowFSM.Step.ROLL)
	fsm.advance(gs, AttackFlowFSM.Step.MODIFY)
	assert_eq(fsm.get_controller_player(), 0)


func test_defender_controls_defense_tokens() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {})
	fsm.advance(gs, AttackFlowFSM.Step.ROLL)
	fsm.advance(gs, AttackFlowFSM.Step.MODIFY)
	fsm.advance(gs, AttackFlowFSM.Step.DEFENSE_TOKENS)
	assert_eq(fsm.get_controller_player(), 1,
			"DEFENSE_TOKENS controller is the defender.")
	assert_eq(gs.interaction_flow.controller_player, 1,
			"interaction_flow must reflect defender control.")


func test_attacker_controls_resolve_damage() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {})
	fsm.advance(gs, AttackFlowFSM.Step.ROLL)
	fsm.advance(gs, AttackFlowFSM.Step.MODIFY)
	fsm.advance(gs, AttackFlowFSM.Step.RESOLVE_DAMAGE)
	assert_eq(fsm.get_controller_player(), 0,
			"RESOLVE_DAMAGE controller is the attacker.")


func test_defender_controls_critical_choice() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {})
	fsm.advance(gs, AttackFlowFSM.Step.ROLL)
	fsm.advance(gs, AttackFlowFSM.Step.MODIFY)
	fsm.advance(gs, AttackFlowFSM.Step.RESOLVE_DAMAGE)
	fsm.advance(gs, AttackFlowFSM.Step.CRITICAL_CHOICE)
	assert_eq(fsm.get_controller_player(), 1)


func test_attacker_controls_defense_when_no_defender() -> void:
	# Squadron-vs-squadron salvo: defender_player = -1.
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, -1, {})
	fsm.advance(gs, AttackFlowFSM.Step.ROLL)
	fsm.advance(gs, AttackFlowFSM.Step.MODIFY)
	fsm.advance(gs, AttackFlowFSM.Step.DEFENSE_TOKENS)
	assert_eq(fsm.get_controller_player(), 0,
			"With no defender, attacker remains controller.")


func test_is_actor_true_for_controller() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {})
	assert_true(fsm.is_actor(0))
	assert_false(fsm.is_actor(1))


func test_is_actor_swaps_at_defense_tokens() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {})
	fsm.advance(gs, AttackFlowFSM.Step.ROLL)
	fsm.advance(gs, AttackFlowFSM.Step.MODIFY)
	fsm.advance(gs, AttackFlowFSM.Step.DEFENSE_TOKENS)
	assert_false(fsm.is_actor(0))
	assert_true(fsm.is_actor(1))


# ---------------------------------------------------------------------------
# InteractionFlow population
# ---------------------------------------------------------------------------

func test_each_step_populates_interaction_flow() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {})
	var expected: Dictionary = {
		AttackFlowFSM.Step.ROLL: Constants.InteractionStep.ATTACK_ROLL,
		AttackFlowFSM.Step.MODIFY: Constants.InteractionStep.ATTACK_MODIFY,
		AttackFlowFSM.Step.DEFENSE_TOKENS:
				Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
		AttackFlowFSM.Step.RESOLVE_DAMAGE:
				Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE,
	}
	for step: AttackFlowFSM.Step in [
			AttackFlowFSM.Step.ROLL,
			AttackFlowFSM.Step.MODIFY,
			AttackFlowFSM.Step.DEFENSE_TOKENS,
			AttackFlowFSM.Step.RESOLVE_DAMAGE]:
		fsm.advance(gs, step)
		assert_eq(gs.interaction_flow.step_id,
				expected[step] as Constants.InteractionStep,
				"step_id must match for %d" % int(step))


func test_payload_is_mirrored_into_interaction_flow() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {"attack_id": "atk-7"})
	assert_eq(gs.interaction_flow.payload.get("attack_id", ""), "atk-7")


func test_visibility_is_all() -> void:
	# Phase I3a: attack flow uses ALL visibility (UI is public).
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {})
	assert_eq(gs.interaction_flow.visible_to,
			Constants.Visibility.ALL,
			"Attack flow visibility is ALL (public UI).")


# ---------------------------------------------------------------------------
# STEP_TO_INTERACTION mapping
# ---------------------------------------------------------------------------

func test_step_to_interaction_covers_all_steps() -> void:
	for step: int in AttackFlowFSM.Step.values():
		assert_true(AttackFlowFSM.STEP_TO_INTERACTION.has(step),
				"Mapping must define %d." % step)


func test_step_to_interaction_attack_steps_are_attack_prefixed() -> void:
	# Sanity: every active step except IDLE/END maps to an ATTACK_* step.
	var attack_steps: Array = [
		AttackFlowFSM.Step.DECLARE,
		AttackFlowFSM.Step.ROLL,
		AttackFlowFSM.Step.MODIFY,
		AttackFlowFSM.Step.DEFENSE_TOKENS,
		AttackFlowFSM.Step.RESOLVE_DAMAGE,
		AttackFlowFSM.Step.CRITICAL_CHOICE,
	]
	for s: AttackFlowFSM.Step in attack_steps:
		var mapped: int = int(AttackFlowFSM.STEP_TO_INTERACTION[s])
		assert_ne(mapped, int(Constants.InteractionStep.NONE),
				"Active step must not map to NONE.")


# ---------------------------------------------------------------------------
# patch_payload (Phase I3b)
# ---------------------------------------------------------------------------

func test_patch_payload_merges_keys() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {"range_band": "long"})
	fsm.patch_payload(gs, {"dice_pool": {"red": 2}})
	assert_eq(fsm.payload.get("range_band", ""), "long",
			"patch must preserve unrelated keys.")
	assert_eq((fsm.payload.get("dice_pool", {}) as Dictionary).get(
			"red", 0), 2)


func test_patch_payload_overwrites_existing_keys() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {"range_band": "long"})
	fsm.patch_payload(gs, {"range_band": "medium"})
	assert_eq(fsm.payload.get("range_band", ""), "medium")


func test_patch_payload_publishes_to_interaction_flow() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {})
	fsm.patch_payload(gs, {"modified_damage": 3})
	assert_eq(gs.interaction_flow.payload.get("modified_damage", 0), 3,
			"interaction_flow must reflect patched payload.")


func test_patch_payload_preserves_step_id() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {})
	fsm.advance(gs, AttackFlowFSM.Step.ROLL)
	fsm.patch_payload(gs, {"x": 1})
	assert_eq(gs.interaction_flow.step_id,
			Constants.InteractionStep.ATTACK_ROLL,
			"patch_payload must not change step_id.")


func test_patch_payload_deep_copies_nested_dict() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	var gs: GameState = _make_state()
	fsm.begin(gs, 0, 1, {})
	var nested: Dictionary = {"red": 2, "blue": 1}
	fsm.patch_payload(gs, {"dice_pool": nested})
	nested["red"] = 99
	assert_eq((fsm.payload["dice_pool"] as Dictionary).get("red", 0), 2,
			"patch must deep-copy nested dictionaries.")


func test_patch_payload_with_null_state_is_safe() -> void:
	var fsm: AttackFlowFSM = AttackFlowFSM.new()
	fsm.patch_payload(null, {"k": 1})
	assert_eq(fsm.payload.get("k", 0), 1,
			"patch_payload still mutates payload when state is null.")
