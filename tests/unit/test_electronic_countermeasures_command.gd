## Test: Electronic Countermeasures command-owned attack behavior
##
## Focused CAP-ECM-001 coverage for runtime ownership, availability,
## authorization, token spend integration, projection, replay, and cleanup.
extends GutTest


const ECM_SCRIPT: GDScript = preload(
		"res://src/core/effects/rules/upgrades/defensive_retrofit/electronic_countermeasures.gd")
const USE_ECM_COMMAND_SCRIPT: GDScript = preload(
		"res://src/core/commands/use_ecm_command.gd")
const DECLINE_ECM_COMMAND_SCRIPT: GDScript = preload(
		"res://src/core/commands/decline_ecm_command.gd")
const FLOW_SPEC_SCRIPT: GDScript = preload(
		"res://src/core/state/flow_spec.gd")
const FAULTY_COUNTERMEASURES_SCRIPT: GDScript = preload(
		"res://src/core/effects/rules/damage_cards/ship/faulty_countermeasures.gd")

const ECM_ASSIGNMENT_ID: String = "ecm-1"
const ECM_RUNTIME_ID: String = "1:ship:defender:upgrade:ecm-1"

var _state: GameState
var _saved_registry: Dictionary = {}
var _changed_ships: Array[ShipInstance] = []


func before_each() -> void:
	_saved_registry = GameCommand._registry.duplicate()
	GameCommand._registry.clear()
	USE_ECM_COMMAND_SCRIPT.register()
	DECLINE_ECM_COMMAND_SCRIPT.register()
	SpendDefenseTokenCommand.register()
	CommitDefenseCommand.register()
	PublishAttackFlowCommand.register()
	RuleRegistry.clear()
	ECM_SCRIPT.register()
	_state = _make_state()
	GameManager.current_game_state = _state
	_changed_ships.clear()
	EventBus.ship_defense_token_changed.connect(_on_ship_defense_token_changed)


func after_each() -> void:
	GameCommand._registry = _saved_registry
	if EventBus.ship_defense_token_changed.is_connected(
			_on_ship_defense_token_changed):
		EventBus.ship_defense_token_changed.disconnect(
				_on_ship_defense_token_changed)
	GameManager.current_game_state = null
	RuleRegistry.clear()
	RuleBootstrap.bootstrap_rules()


func test_ecm_runtime_upgrade_materializes_canonical_defaults() -> void:
	var runtime_upgrade: Dictionary = _ecm_upgrade()
	var card_state: Dictionary = runtime_upgrade.get("card_state", {})

	assert_eq(runtime_upgrade.get("data_key", ""), "electronic_countermeasures",
			"ECM runtime instance should reference static data by data_key.")
	assert_eq(runtime_upgrade.get("slot", ""), "DEFENSIVE_RETROFIT",
			"Runtime slot should preserve the assigned upgrade slot.")
	assert_false(card_state.get("exhausted", true),
			"ECM should start unexhausted.")
	assert_true(card_state.get("readied", false),
			"ECM should start ready.")
	assert_true((runtime_upgrade.get("rule_state", {}) as Dictionary).is_empty(),
			"ECM mutable rule_state should start empty.")


func test_projector_publicly_offers_ecm_when_locked_token_is_legal() -> void:
	var defender_intent: UIProjector.UIIntent = UIProjector.project(_state, 1)
	var attacker_intent: UIProjector.UIIntent = UIProjector.project(_state, 0)
	var defender_choice: Dictionary = defender_intent.affordances.get(
			ECM_SCRIPT.AFFORDANCE_KEY, {})
	var attacker_choice: Dictionary = attacker_intent.affordances.get(
			ECM_SCRIPT.AFFORDANCE_KEY, {})

	assert_eq(defender_choice.get("runtime_upgrade_id", ""), ECM_RUNTIME_ID,
			"Defender should see the public ECM opportunity.")
	assert_eq(attacker_choice.get("runtime_upgrade_id", ""), ECM_RUNTIME_ID,
			"Attacker should also observe ECM availability.")
	assert_eq((defender_choice.get("eligible_token_indices", []) as Array)[0],
			0, "Only the Accuracy-targeted token should be eligible.")


func test_no_ecm_prompt_when_no_legal_effect_exists() -> void:
	_state.interaction_flow.payload["locked_tokens"] = []
	assert_true(ECM_SCRIPT.choice_payload(
			_state, _state.interaction_flow).is_empty(),
			"No Accuracy-targeted token means no ECM prompt.")
	_state.interaction_flow.payload["locked_tokens"] = [0]
	_defender().current_speed = 0
	assert_true(ECM_SCRIPT.choice_payload(
			_state, _state.interaction_flow).is_empty(),
			"Speed 0 should keep the locked token illegal.")
	_defender().current_speed = 2
	_ecm_card_state()["exhausted"] = true
	_ecm_card_state()["readied"] = false
	assert_true(ECM_SCRIPT.choice_payload(
			_state, _state.interaction_flow).is_empty(),
			"Exhausted ECM should not project an interaction.")


func test_use_and_decline_reject_wrong_player_wrong_phase_and_missing_source() -> void:
	assert_ne(USE_ECM_COMMAND_SCRIPT.new(0, {
		"runtime_upgrade_id": ECM_RUNTIME_ID,
	}).validate(_state), "", "Wrong player should not use ECM.")
	assert_ne(DECLINE_ECM_COMMAND_SCRIPT.new(0, {
		"runtime_upgrade_id": ECM_RUNTIME_ID,
	}).validate(_state), "", "Wrong player should not decline ECM.")

	_state.current_phase = Constants.GamePhase.STATUS
	assert_ne(_use_ecm().validate(_state), "",
			"UseECMCommand should reject the wrong phase.")
	assert_ne(_decline_ecm().validate(_state), "",
			"DeclineECMCommand should reject the wrong phase.")

	_state = _make_state()
	_defender().runtime_upgrades.clear()
	assert_ne(_use_ecm().validate(_state), "",
			"Missing ECM source should reject use.")
	assert_ne(_decline_ecm().validate(_state), "",
			"Missing ECM source should reject decline.")


func test_discarded_or_disabled_ecm_is_unavailable() -> void:
	var card_state: Dictionary = _ecm_card_state()
	card_state["discarded"] = true
	card_state["readied"] = false
	assert_true(ECM_SCRIPT.choice_payload(
			_state, _state.interaction_flow).is_empty(),
			"Discarded ECM should not be offered.")
	assert_ne(_use_ecm().validate(_state), "",
			"Discarded ECM should reject use.")

	_state = _make_state()
	card_state = _ecm_card_state()
	card_state["disabled"] = true
	assert_true(ECM_SCRIPT.choice_payload(
			_state, _state.interaction_flow).is_empty(),
			"Disabled ECM should not be offered.")
	assert_ne(_use_ecm().validate(_state), "",
			"Disabled ECM should reject use.")


func test_use_ecm_exhausts_card_and_creates_pending_authorization_only() -> void:
	var token_state_before: int = int(_defender().defense_tokens[0]["state"])
	var result: Dictionary = _use_ecm().execute(_state)
	var card_state: Dictionary = _ecm_card_state()
	var pending: Dictionary = ECM_SCRIPT.pending_authorization(_ecm_upgrade())

	assert_true(result.get("exhausted", false),
			"UseECMCommand should report exhaustion.")
	assert_true(card_state.get("exhausted", false),
			"UseECMCommand should exhaust the runtime upgrade.")
	assert_false(card_state.get("readied", true),
			"UseECMCommand should mark ECM unreadied.")
	assert_eq(int(_defender().defense_tokens[0]["state"]), token_state_before,
			"UseECMCommand must not spend a defense token.")
	assert_eq((pending.get("eligible_token_indices", []) as Array)[0], 0,
			"UseECMCommand should authorize the locked token only.")
	assert_eq(int(pending.get(
			ECM_SCRIPT.PENDING_SELECTED_TOKEN_INDEX, 99)), -1,
			"UseECMCommand should not select the token.")
	assert_false(_state.interaction_flow.payload.has(
			"ecm_pending_authorization"),
			"Pending authorization must not be copied into flow payload.")
	assert_eq(_state.interaction_flow.payload.get(
			"ecm_authorized_indices", []) as Array, [0],
			"Flow payload may carry only derived ECM display indices.")


func test_decline_records_decline_without_exhausting_or_authorizing() -> void:
	var result: Dictionary = _decline_ecm().execute(_state)
	var card_state: Dictionary = _ecm_card_state()

	assert_true(result.get("declined", false),
			"DeclineECMCommand should be explicit in replay history.")
	assert_false(card_state.get("exhausted", true),
			"Decline should not exhaust ECM.")
	assert_true(ECM_SCRIPT.pending_authorization(_ecm_upgrade()).is_empty(),
			"Decline should not create pending authorization.")
	assert_true(ECM_SCRIPT.choice_payload(
			_state, _state.interaction_flow).is_empty(),
			"Decline should suppress the prompt for this attack window.")


func test_spend_defense_token_consumes_pending_authorization() -> void:
	_use_ecm().execute(_state)
	var cmd := SpendDefenseTokenCommand.new(1, {
		"ship_index": 0,
		"token_index": 0,
		"spend_method": "exhaust",
	})

	assert_eq(cmd.validate(_state), "",
			"Pending ECM should authorize the Accuracy-targeted token.")
	var result: Dictionary = cmd.execute(_state)

	assert_true(result.get("ecm_authorized", false),
			"Spend result should report ECM authorization.")
	assert_eq(_defender().defense_tokens[0]["state"],
			Constants.DefenseTokenState.EXHAUSTED,
			"SpendDefenseTokenCommand should perform the actual spend.")
	assert_true(ECM_SCRIPT.pending_authorization(_ecm_upgrade()).is_empty(),
			"Authorization should clear after the token spend.")


func test_evade_then_ecm_redirect_resolve_in_correct_order() -> void:
	_state.interaction_flow.payload["locked_tokens"] = [1]
	_use_ecm().execute(_state)
	var commit := CommitDefenseCommand.new(1, {
		"ship_index": 0,
		"selected_indices": [2, 1],
	})
	assert_eq(commit.validate(_state), "",
			"Commit should choose Evade plus the ECM-locked Redirect.")
	commit.execute(_state)
	var evade := SpendDefenseTokenCommand.new(1, {
		"ship_index": 0,
		"token_index": 2,
		"spend_method": "exhaust",
	})
	assert_eq(evade.validate(_state), "",
			"Unlocked Evade should resolve before the ECM Redirect.")
	evade.execute(_state)
	assert_false(ECM_SCRIPT.pending_authorization(_ecm_upgrade()).is_empty(),
			"Evade should not consume the pending ECM authorization.")

	var redirect := SpendDefenseTokenCommand.new(1, {
		"ship_index": 0,
		"token_index": 1,
		"spend_method": "exhaust",
	})
	assert_eq(redirect.validate(_state), "",
			"ECM should authorize the later locked Redirect spend.")
	var result: Dictionary = redirect.execute(_state)
	assert_true(result.get("ecm_authorized", false),
			"Redirect spend should report ECM authorization.")
	assert_true(ECM_SCRIPT.pending_authorization(_ecm_upgrade()).is_empty(),
			"Redirect should consume and clear the ECM authorization.")


func test_hot_seat_protocol_preserves_ecm_redirect_through_evade() -> void:
	_state.interaction_flow.payload["locked_tokens"] = [1]
	_use_ecm().execute(_state)
	var commit := CommitDefenseCommand.new(1, {
		"ship_index": 0,
		"selected_indices": [2, 1],
	})
	assert_eq(commit.validate(_state), "",
			"Hot-seat commit should accept Evade plus chosen ECM Redirect.")
	var commit_result: Dictionary = commit.execute(_state)
	assert_eq(int(commit_result.get("ecm_selected_token_index", -1)), 1,
			"Commit should preserve Redirect as the chosen ECM token.")

	var evade := SpendDefenseTokenCommand.new(1, {
		"ship_index": 0,
		"token_index": 2,
		"spend_method": "exhaust",
	})
	assert_eq(evade.validate(_state), "",
			"Queued Evade spend should resolve before Redirect.")
	evade.execute(_state)
	var evade_die := SelectEvadeDieCommand.new(1, {
		"ship_index": 0,
		"die_index": 0,
	})
	assert_eq(evade_die.validate(_state), "",
			"Evade die selection should remain legal in the attack phase.")
	evade_die.execute(_state)
	assert_eq(ECM_SCRIPT.authorized_token_indices(
			_state, _state.interaction_flow), [1],
			"Evade resolution should leave only the chosen Redirect authorized.")

	var redirect := SpendDefenseTokenCommand.new(1, {
		"ship_index": 0,
		"token_index": 1,
		"spend_method": "exhaust",
	})
	assert_eq(redirect.validate(_state), "",
			"Chosen locked Redirect should remain spendable after Evade.")
	redirect.execute(_state)
	var redirect_zone := SelectRedirectZoneCommand.new(1, {
		"ship_index": 0,
		"zone": int(Constants.HullZone.LEFT),
	})
	assert_eq(redirect_zone.validate(_state), "",
			"Redirect zone selection should remain legal after ECM spend.")
	var redirect_result: Dictionary = redirect_zone.execute(_state)
	assert_eq(int(redirect_result.get("shields_reduced", -1)), 1,
			"Redirect resolution should reduce an adjacent shield.")
	assert_true(ECM_SCRIPT.pending_authorization(_ecm_upgrade()).is_empty(),
			"Redirect spend should clear pending ECM before damage continues.")


func test_commit_defense_rejects_locked_token_without_ecm_authorization() -> void:
	var commit := CommitDefenseCommand.new(1, {
		"ship_index": 0,
		"selected_indices": [0],
	})
	assert_ne(commit.validate(_state), "",
			"CommitDefenseCommand should not mark an unauthorized locked token.")

	_use_ecm().execute(_state)
	assert_eq(commit.validate(_state), "",
			"Pending ECM should authorize the committed locked token marker.")


func test_commit_defense_rejects_multiple_ecm_locked_tokens() -> void:
	_state.interaction_flow.payload["locked_tokens"] = [0, 1]
	_use_ecm().execute(_state)
	var commit := CommitDefenseCommand.new(1, {
		"ship_index": 0,
		"selected_indices": [0, 1],
	})
	assert_ne(commit.validate(_state), "",
			"CommitDefenseCommand should reject multiple ECM locked tokens.")

	var one_locked := CommitDefenseCommand.new(1, {
		"ship_index": 0,
		"selected_indices": [2, 1],
	})
	assert_eq(one_locked.validate(_state), "",
			"One locked token plus one unlocked token should remain legal.")
	var result: Dictionary = one_locked.execute(_state)
	var pending: Dictionary = ECM_SCRIPT.pending_authorization(_ecm_upgrade())
	assert_eq(int(result.get("ecm_selected_token_index", -1)), 1,
			"CommitDefenseCommand should echo the chosen ECM token.")
	assert_eq(int(pending.get(
			ECM_SCRIPT.PENDING_SELECTED_TOKEN_INDEX, -1)), 1,
			"CommitDefenseCommand should preserve the chosen token in rule_state.")


func test_multi_locked_tokens_allow_either_one_but_not_both() -> void:
	_state.interaction_flow.payload["locked_tokens"] = [0, 1]
	_use_ecm().execute(_state)
	assert_eq(ECM_SCRIPT.authorized_token_indices(
			_state, _state.interaction_flow), [0, 1],
			"Before commit, both eligible locked tokens should be selectable.")

	var choose_brace := CommitDefenseCommand.new(1, {
		"ship_index": 0,
		"selected_indices": [0],
	})
	assert_eq(choose_brace.validate(_state), "",
			"Defender may choose the first locked token.")

	_state = _make_state()
	GameManager.current_game_state = _state
	_state.interaction_flow.payload["locked_tokens"] = [0, 1]
	_use_ecm().execute(_state)
	var choose_redirect := CommitDefenseCommand.new(1, {
		"ship_index": 0,
		"selected_indices": [1],
	})
	assert_eq(choose_redirect.validate(_state), "",
			"Defender may choose the second locked token.")
	choose_redirect.execute(_state)
	assert_eq(ECM_SCRIPT.authorized_token_indices(
			_state, _state.interaction_flow), [1],
			"After commit, only the chosen locked token should remain spendable.")

	_state = _make_state()
	GameManager.current_game_state = _state
	_state.interaction_flow.payload["locked_tokens"] = [0, 1]
	_use_ecm().execute(_state)
	var choose_both := CommitDefenseCommand.new(1, {
		"ship_index": 0,
		"selected_indices": [0, 1],
	})
	assert_ne(choose_both.validate(_state), "",
			"Defender may not choose both locked tokens with one ECM use.")


func test_use_ecm_requires_commit_to_choose_one_locked_token() -> void:
	_state.interaction_flow.payload["locked_tokens"] = [0, 1]
	_use_ecm().execute(_state)
	var commit_none := CommitDefenseCommand.new(1, {
		"ship_index": 0,
		"selected_indices": [2],
	})
	assert_ne(commit_none.validate(_state), "",
			"After using ECM, commit_defense must choose one locked token.")


func test_locked_token_without_pending_authorization_is_rejected() -> void:
	var cmd := SpendDefenseTokenCommand.new(1, {
		"ship_index": 0,
		"token_index": 0,
		"spend_method": "exhaust",
	})

	assert_ne(cmd.validate(_state), "",
			"Accuracy-targeted token should require ECM authorization.")


func test_already_spent_type_keeps_ecm_unavailable_and_rejects_pending_spend() -> void:
	_state.interaction_flow.payload["spent_defense_token_types"] = [
		int(Constants.DefenseToken.BRACE),
	]
	assert_true(ECM_SCRIPT.choice_payload(
			_state, _state.interaction_flow).is_empty(),
			"Already-spent token type should prevent an ECM prompt.")

	_state = _make_state()
	_use_ecm().execute(_state)
	_state.interaction_flow.payload["spent_defense_token_types"] = [
		int(Constants.DefenseToken.BRACE),
	]
	var spend := SpendDefenseTokenCommand.new(1, {
		"ship_index": 0,
		"token_index": 0,
		"spend_method": "exhaust",
	})
	assert_ne(spend.validate(_state), "",
			"Pending ECM cannot authorize an already-spent token type.")


func test_existing_defense_token_blocker_keeps_ecm_unavailable() -> void:
	FAULTY_COUNTERMEASURES_SCRIPT.register()
	_add_faulty_countermeasures(_defender())
	_defender().defense_tokens[0]["state"] = \
			Constants.DefenseTokenState.EXHAUSTED

	assert_true(ECM_SCRIPT.choice_payload(
			_state, _state.interaction_flow).is_empty(),
			"Existing defense-token blockers should prevent ECM availability.")


func test_pending_authorization_cannot_be_reused_or_applied_elsewhere() -> void:
	_use_ecm().execute(_state)
	var other_ship: ShipInstance = _add_ship(1, "other-defender")
	var other_cmd := SpendDefenseTokenCommand.new(1, {
		"ship_index": 1,
		"token_index": 0,
		"spend_method": "exhaust",
	})
	assert_ne(other_cmd.validate(_state), "",
			"Pending authorization cannot apply to another ship.")

	var spend := SpendDefenseTokenCommand.new(1, {
		"ship_index": 0,
		"token_index": 0,
		"spend_method": "exhaust",
	})
	spend.execute(_state)
	_defender().defense_tokens[0]["state"] = Constants.DefenseTokenState.READY
	assert_ne(spend.validate(_state), "",
			"Cleared authorization cannot be reused.")
	assert_not_null(other_ship,
			"Second defender ship should exist for the cross-ship assertion.")


func test_pending_authorization_is_attack_scoped_serialized_and_reconnect_safe() -> void:
	_use_ecm().execute(_state)
	var restored: GameState = GameState.deserialize(_state.serialize())
	var restored_ship: ShipInstance = restored.get_ship(1, 0)
	var restored_upgrade: Dictionary = restored_ship.get_runtime_upgrade(
			ECM_RUNTIME_ID)
	var pending: Dictionary = ECM_SCRIPT.pending_authorization(restored_upgrade)

	assert_false(pending.is_empty(),
			"Save/load should preserve pending ECM authorization.")
	var filtered: Dictionary = StateFilter.filter_for_player(
			_state.serialize(), 0)
	var reconnected: GameState = GameState.deserialize(filtered)
	var reconnected_upgrade: Dictionary = reconnected.get_ship(
			1, 0).get_runtime_upgrade(ECM_RUNTIME_ID)
	assert_false(ECM_SCRIPT.pending_authorization(
			reconnected_upgrade).is_empty(),
			"Reconnect should reconstruct pending ECM authorization.")
	restored.interaction_flow.payload["defender_zone"] = int(
			Constants.HullZone.LEFT)
	var spend := SpendDefenseTokenCommand.new(1, {
		"ship_index": 0,
		"token_index": 0,
		"spend_method": "exhaust",
	})
	assert_ne(spend.validate(restored), "",
			"Pending authorization should not apply to another attack scope.")


func test_reconnect_projection_preserves_pending_choice_without_reoffer() -> void:
	_state.interaction_flow.payload["locked_tokens"] = [0, 1]
	_use_ecm().execute(_state)
	var filtered: Dictionary = StateFilter.filter_for_player(
			_state.serialize(), 1)
	var reconnected: GameState = GameState.deserialize(filtered)
	var intent: UIProjector.UIIntent = UIProjector.project(reconnected, 1)

	assert_false(intent.affordances.has(ECM_SCRIPT.AFFORDANCE_KEY),
			"Reconnect after ECM use should not re-offer ECM.")
	assert_eq(reconnected.interaction_flow.payload.get(
			"ecm_authorized_indices", []) as Array, [0, 1],
			"Reconnect should preserve the pending token-choice candidates.")


func test_save_load_after_ecm_use_preserves_exhausted_card_state() -> void:
	_use_ecm().execute(_state)
	var restored: GameState = GameState.deserialize(_state.serialize())
	var restored_upgrade: Dictionary = restored.get_ship(
			1, 0).get_runtime_upgrade(ECM_RUNTIME_ID)
	var card_state: Dictionary = restored_upgrade.get("card_state", {})
	assert_true(card_state.get("exhausted", false),
			"Save/load should preserve ECM exhaustion after use.")
	assert_false(card_state.get("readied", true),
			"Save/load should preserve ECM unreadied state after use.")


func test_flow_payload_pending_authorization_is_not_authoritative() -> void:
	_state.interaction_flow.payload["ecm_pending_authorization"] = {
		"runtime_upgrade_id": ECM_RUNTIME_ID,
		"eligible_token_indices": [0],
	}
	var spend := SpendDefenseTokenCommand.new(1, {
		"ship_index": 0,
		"token_index": 0,
		"spend_method": "exhaust",
	})
	assert_ne(spend.validate(_state), "",
			"Flow payload alone must not authorize an ECM token spend.")


func test_repeated_use_ecm_is_not_offered_after_successful_use() -> void:
	_use_ecm().execute(_state)

	assert_true(ECM_SCRIPT.choice_payload(
			_state, _state.interaction_flow).is_empty(),
			"ECM prompt should not be offered again after successful use.")
	assert_ne(_use_ecm().validate(_state), "",
			"UseECMCommand should reject repeated use while pending/exhausted.")


func test_publish_attack_flow_cannot_overwrite_pending_authorization() -> void:
	_use_ecm().execute(_state)
	var before: Dictionary = ECM_SCRIPT.pending_authorization(_ecm_upgrade())
	var cmd := PublishAttackFlowCommand.new(0, {
		"step_id": int(Constants.InteractionStep.ATTACK_DEFENSE_TOKENS),
		"controller_player": 1,
		"flow_payload": {
			"attacker_player": 0,
			"attacker_ship_index": 0,
			"defender_player": 1,
			"defender_ship_index": 0,
			"defender_zone": int(Constants.HullZone.FRONT),
			"locked_tokens": [0],
			"spent_defense_token_types": [],
			"ecm_pending_authorization": {
				"runtime_upgrade_id": ECM_RUNTIME_ID,
				"eligible_token_indices": [1],
			},
		},
	})
	cmd.execute(_state)
	var after: Dictionary = ECM_SCRIPT.pending_authorization(_ecm_upgrade())

	assert_eq(after, before,
			"PublishAttackFlowCommand must not overwrite runtime ECM state.")
	assert_false(_state.interaction_flow.payload.has(
			"ecm_pending_authorization"),
			"Published flow should drop stale pending authorization payload.")
	assert_eq(_state.interaction_flow.payload.get(
			"ecm_authorized_indices", []) as Array, [0],
			"Published flow should derive display authorization from runtime.")


func test_publish_attack_flow_payload_cannot_resurrect_stale_ecm_state() -> void:
	var cmd := PublishAttackFlowCommand.new(0, {
		"step_id": int(Constants.InteractionStep.ATTACK_DEFENSE_TOKENS),
		"controller_player": 1,
		"flow_payload": {
			"attacker_player": 0,
			"attacker_ship_index": 0,
			"defender_player": 1,
			"defender_ship_index": 0,
			"defender_zone": int(Constants.HullZone.FRONT),
			"locked_tokens": [0],
			"spent_defense_token_types": [],
			"ecm_pending_authorization": {
				"runtime_upgrade_id": ECM_RUNTIME_ID,
				"eligible_token_indices": [0],
			},
			"ecm_authorized_indices": [0],
		},
	})
	cmd.execute(_state)

	assert_false(_state.interaction_flow.payload.has(
			"ecm_pending_authorization"),
			"Stale pending payload should be stripped.")
	assert_true((_state.interaction_flow.payload.get(
			"ecm_authorized_indices", []) as Array).is_empty(),
			"Stale display authorization should not survive without runtime.")
	var spend := SpendDefenseTokenCommand.new(1, {
		"ship_index": 0,
		"token_index": 0,
		"spend_method": "exhaust",
	})
	assert_ne(spend.validate(_state), "",
			"Stale flow payload must not authorize token spending.")


func test_publish_attack_flow_clears_pending_authorization_on_window_loss() -> void:
	_use_ecm().execute(_state)
	var cmd := PublishAttackFlowCommand.new(0, {
		"step_id": int(Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE),
		"controller_player": 0,
		"flow_payload": {
			"attacker_player": 0,
			"defender_player": 1,
		},
	})
	var result: Dictionary = cmd.execute(_state)

	assert_true(ECM_SCRIPT.pending_authorization(_ecm_upgrade()).is_empty(),
			"Leaving the defense-token window should clear pending ECM.")
	assert_true((result.get("ecm_cleared_runtime_upgrade_ids", []) as Array
			).has(ECM_RUNTIME_ID),
			"Cleanup result should report the cleared runtime upgrade.")


func test_commands_serialize_and_replay_decline_and_use() -> void:
	var use_cmd: GameCommand = _use_ecm()
	use_cmd.sequence = 12
	var restored_use: GameCommand = GameCommand.deserialize(use_cmd.serialize())
	assert_eq(restored_use.validate(_state), "",
			"Serialized UseECMCommand should replay from command payload.")
	restored_use.execute(_state)
	assert_false(ECM_SCRIPT.pending_authorization(_ecm_upgrade()).is_empty(),
			"Replayed UseECMCommand should recreate pending authorization.")

	_state = _make_state()
	var decline_cmd: GameCommand = _decline_ecm()
	decline_cmd.sequence = 13
	var restored_decline: GameCommand = GameCommand.deserialize(
			decline_cmd.serialize())
	assert_eq(restored_decline.validate(_state), "",
			"Serialized DeclineECMCommand should replay from command payload.")
	var decline_result: Dictionary = restored_decline.execute(_state)
	assert_true(decline_result.get("declined", false),
			"Replayed DeclineECMCommand should preserve explicit decline.")


func test_remote_ecm_use_refreshes_public_ship_state_but_decline_does_not() -> void:
	var use_cmd: GameCommand = _use_ecm()
	var use_result: Dictionary = use_cmd.execute(_state)
	GameManager._handle_remote_command_effects(use_cmd, use_result)
	assert_true(_changed_ships.has(_defender()),
			"Remote ECM use should refresh public ship-card state.")

	_state = _make_state()
	GameManager.current_game_state = _state
	_changed_ships.clear()
	var decline_cmd: GameCommand = _decline_ecm()
	var decline_result: Dictionary = decline_cmd.execute(_state)
	GameManager._handle_remote_command_effects(decline_cmd, decline_result)
	assert_true(_changed_ships.is_empty(),
			"Remote ECM decline should not emit token/card refresh events.")


func test_remote_spend_and_cleanup_mirror_ecm_state() -> void:
	_use_ecm().execute(_state)
	var spend := SpendDefenseTokenCommand.new(1, {
		"ship_index": 0,
		"token_index": 0,
		"spend_method": "exhaust",
	})
	var spend_result: Dictionary = spend.execute(_state)
	_changed_ships.clear()
	GameManager._handle_remote_command_effects(spend, spend_result)
	assert_true(_changed_ships.has(_defender()),
			"Remote ECM-authorized spend should refresh the defender ship.")
	assert_true(ECM_SCRIPT.pending_authorization(_ecm_upgrade()).is_empty(),
			"Remote mirrored spend should clear pending authorization.")

	_state = _make_state()
	GameManager.current_game_state = _state
	_use_ecm().execute(_state)
	var publish := PublishAttackFlowCommand.new(0, {
		"step_id": int(Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE),
		"controller_player": 0,
		"flow_payload": {"attacker_player": 0, "defender_player": 1},
	})
	publish.execute(_state)
	GameManager._handle_remote_command_effects(publish, {})
	assert_true(ECM_SCRIPT.pending_authorization(_ecm_upgrade()).is_empty(),
			"Remote mirrored flow cleanup should clear pending authorization.")


func test_network_mirror_preserves_ecm_authorization_through_evade_to_redirect() -> void:
	_state.interaction_flow.payload["locked_tokens"] = [1]
	_use_ecm().execute(_state)
	var commit := CommitDefenseCommand.new(1, {
		"ship_index": 0,
		"selected_indices": [2, 1],
	})
	commit.execute(_state)
	var evade := SpendDefenseTokenCommand.new(1, {
		"ship_index": 0,
		"token_index": 2,
		"spend_method": "exhaust",
	})
	evade.execute(_state)
	var publish := PublishAttackFlowCommand.new(0, {
		"step_id": int(Constants.InteractionStep.ATTACK_DEFENSE_TOKENS),
		"controller_player": 1,
		"flow_payload": {
			"attacker_player": 0,
			"attacker_ship_index": 0,
			"defender_player": 1,
			"defender_ship_index": 0,
			"defender_zone": int(Constants.HullZone.FRONT),
			"locked_tokens": [1],
			"spent_defense_token_types": [
				int(Constants.DefenseToken.EVADE),
			],
			"evade_active": false,
			"redirect_active": true,
			"ecm_pending_authorization": {
				"runtime_upgrade_id": ECM_RUNTIME_ID,
				"eligible_token_indices": [0],
			},
		},
	})
	publish.execute(_state)

	assert_eq(_state.interaction_flow.payload.get(
			"ecm_authorized_indices", []) as Array, [1],
			"Mirror payload should derive Redirect authorization from runtime.")
	var redirect := SpendDefenseTokenCommand.new(1, {
		"ship_index": 0,
		"token_index": 1,
		"spend_method": "exhaust",
	})
	assert_eq(redirect.validate(_state), "",
			"Redirect should remain authorized after mirrored Evade state.")


func test_flow_spec_allows_ecm_commands_at_defense_token_step() -> void:
	var spec: Dictionary = FLOW_SPEC_SCRIPT.get_spec(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS)
	var commands: Array = spec.get("allowed_commands", []) as Array
	assert_true(commands.has("use_ecm"),
			"UseECMCommand should be legal in the defense-token step.")
	assert_true(commands.has("decline_ecm"),
			"DeclineECMCommand should be legal in the defense-token step.")


func _make_state() -> GameState:
	var state := GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	_add_ship_to_state(state, 0, "cr90_corvette_a", "attacker")
	var defender: ShipInstance = _add_ship_to_state(
			state, 1, "victory_ii_class_star_destroyer", "defender")
	defender.add_runtime_upgrade(
			"electronic_countermeasures", ECM_ASSIGNMENT_ID,
			"DEFENSIVE_RETROFIT", 0)
	state.interaction_flow = _defense_flow(state)
	var choice: Dictionary = ECM_SCRIPT.choice_payload(
			state, state.interaction_flow)
	state.interaction_flow.payload[ECM_SCRIPT.AFFORDANCE_KEY] = choice
	return state


func _defense_flow(state: GameState) -> InteractionFlow:
	return InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			1,
			Constants.Visibility.ALL,
			{
				"attacker_player": 0,
				"attacker_ship_index": 0,
				"defender_player": 1,
				"defender_ship_index": 0,
				"defender_zone": int(Constants.HullZone.FRONT),
				"locked_tokens": [0],
				"spent_defense_token_types": [],
				"defense_tokens": state.get_ship(
						1, 0).defense_tokens.duplicate(true),
			})


func _add_ship(player: int, roster_entry_id: String) -> ShipInstance:
	return _add_ship_to_state(
			_state, player, "victory_ii_class_star_destroyer",
			roster_entry_id)


func _add_ship_to_state(state: GameState,
		player: int,
		data_key: String,
		roster_entry_id: String) -> ShipInstance:
	var ship := ShipInstance.create_from_data(
			data_key, _make_ship_data(), 2, player)
	ship.roster_entry_id = roster_entry_id
	var ps: PlayerState = state.get_player_state(player)
	ps.ships.append(ship)
	return ship


func _make_ship_data() -> ShipData:
	var data := ShipData.new()
	data.hull = 5
	data.max_speed = 2
	data.command_value = 2
	data.shields = {"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1}
	data.defense_tokens = ["brace", "redirect", "evade"]
	data.navigation_chart = [[1], [1, 1]]
	return data


func _defender() -> ShipInstance:
	return _state.get_ship(1, 0)


func _ecm_upgrade() -> Dictionary:
	return _defender().get_runtime_upgrade(ECM_RUNTIME_ID)


func _ecm_card_state() -> Dictionary:
	return _ecm_upgrade().get("card_state", {}) as Dictionary


func _use_ecm() -> GameCommand:
	return USE_ECM_COMMAND_SCRIPT.new(1, {
		"runtime_upgrade_id": ECM_RUNTIME_ID,
	})


func _decline_ecm() -> GameCommand:
	return DECLINE_ECM_COMMAND_SCRIPT.new(1, {
		"runtime_upgrade_id": ECM_RUNTIME_ID,
	})


func _add_faulty_countermeasures(ship: ShipInstance) -> DamageCard:
	var card: DamageCard = DamageCard.create("Ship", "Faulty Countermeasures")
	card.effect_id = FaultyCountermeasures.EFFECT_ID
	card.effect_text = "You cannot spend exhausted defense tokens."
	card.timing = "persistent"
	card.is_faceup = true
	ship.add_faceup_damage(card)
	return card


func _on_ship_defense_token_changed(ship: ShipInstance) -> void:
	_changed_ships.append(ship)
