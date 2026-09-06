## Unit coverage for the purpose-specific Squadron Move decline command.
extends GutTest


func test_command_uses_decline_type_and_exact_squadron_phase_schema() -> void:
	var command := DeclineSquadronMoveCommand.new(0, {
		"squadron_index": 1,
		"activation_id": "squadron-activation:12",
		"activation_context": SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE,
		"completed_attack_inspection_id": "",
	})

	assert_eq(command.command_type, DeclineSquadronMoveCommand.TYPE)
	assert_eq(command._validate_payload_schema(), "")


func test_command_rejects_extra_generic_payload_fields() -> void:
	var command := DeclineSquadronMoveCommand.new(0, {
		"squadron_index": 1,
		"activation_id": "squadron-activation:12",
		"activation_context": SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE,
		"completed_attack_inspection_id": "",
		"queued_payload": {},
	})

	assert_ne(command._validate_payload_schema(), "")
