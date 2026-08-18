extends GutTest


const HOT_ID: String = "mp-123e4567-e89b-42d3-a456-426614174000"
const HUMAN_ID: String = "mp-123e4567-e89b-42d3-a456-426614174001"
const AUTO_ID: String = "mp-123e4567-e89b-42d3-a456-426614174002"


func test_hot_seat_binding_controls_both_players() -> void:
	var binding: MatchPlayerControlBinding = MatchPlayerControlBinding.deserialize({
		"principals": [{"principal_id": HOT_ID, "kind": "HUMAN"}],
		"player_principal_ids": [HOT_ID, HOT_ID],
	})
	assert_not_null(binding)
	assert_true(binding.controls_player(HOT_ID, 0))
	assert_true(binding.controls_player(HOT_ID, 1))
	assert_eq(binding.distinct_principal_ids(
			MatchPlayerControlBinding.KIND_HUMAN), [HOT_ID])


func test_structural_human_and_automated_shapes_are_valid() -> void:
	var binding: MatchPlayerControlBinding = MatchPlayerControlBinding.deserialize({
		"principals": [
			{"principal_id": AUTO_ID, "kind": "AUTOMATED"},
			{"principal_id": HUMAN_ID, "kind": "HUMAN"},
		],
		"player_principal_ids": [HUMAN_ID, AUTO_ID],
	})
	assert_not_null(binding)
	assert_eq(binding.distinct_principal_ids(
			MatchPlayerControlBinding.KIND_HUMAN), [HUMAN_ID])
	var automated: MatchPlayerControlBinding = MatchPlayerControlBinding.create_new(
			["AUTOMATED", "AUTOMATED"], [0, 1])
	assert_not_null(automated)
	assert_eq(automated.distinct_principal_ids(
			MatchPlayerControlBinding.KIND_HUMAN), [])
	var network: MatchPlayerControlBinding = MatchPlayerControlBinding.create_two_human()
	assert_not_null(network)
	assert_eq(network.distinct_principal_ids(
			MatchPlayerControlBinding.KIND_HUMAN).size(), 2)


func test_invalid_or_mutated_shapes_fail_closed() -> void:
	assert_null(MatchPlayerControlBinding.deserialize({
		"principals": [{"principal_id": HOT_ID, "kind": "HUMAN", "bad": true}],
		"player_principal_ids": [HOT_ID, HOT_ID],
	}))
	assert_null(MatchPlayerControlBinding.deserialize({
		"principals": [{"principal_id": "mp-not-a-uuid", "kind": "HUMAN"}],
		"player_principal_ids": ["mp-not-a-uuid", "mp-not-a-uuid"],
	}))
	var binding: MatchPlayerControlBinding = MatchPlayerControlBinding.deserialize({
		"principals": [{"principal_id": HOT_ID, "kind": "HUMAN"}],
		"player_principal_ids": [HOT_ID, HOT_ID],
	})
	var copy: Dictionary = binding.serialize()
	copy["player_principal_ids"][0] = HUMAN_ID
	assert_eq(binding.principal_id_for_player(0), HOT_ID)
