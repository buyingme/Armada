## Deterministic shared-core timing participant used only by protocol tests.
extends RefCounted


const OPPORTUNITY: GDScript = preload(
		"res://src/core/timing_windows/timing_window_opportunity.gd")

const CAPABILITY_ID: String = "fixture.timing_participant"
const SOURCE_OWNER_KIND: String = "fixture_owner"
const SEMANTIC_KEY: String = "resolve_fixture_choice"
const SOURCES_KEY: String = "timing_fixture_sources"
const PRIVATE_SOURCES_KEY: String = "timing_fixture_private_sources"
const RESOLVED_KEY: String = "timing_fixture_resolved"
const DUPLICATE_KEY: String = "timing_fixture_duplicate_opportunity"
const FAIL_ENUMERATION_KEY: String = "timing_fixture_fail_enumeration"
const FAIL_DERIVATION_KEY: String = "timing_fixture_fail_derivation"
const VISIBILITY_KEY: String = "timing_fixture_visibility"
const USE_COMMAND_TYPE_KEY: String = "timing_fixture_use_command_type"
const DECLINE_COMMAND_TYPE_KEY: String = "timing_fixture_decline_command_type"

const VISIBILITY_PUBLIC: String = "public"
const VISIBILITY_OWNER_ONLY: String = "owner_only"
const VISIBILITY_HIDDEN_SOURCE: String = "hidden_source"

static var enumeration_calls: int = 0
static var derivation_calls: int = 0


static func reset_calls() -> void:
	enumeration_calls = 0
	derivation_calls = 0


static func enumerate_timing_window_sources(game_state: GameState,
		_timing_state: TimingWindowState) -> Variant:
	enumeration_calls += 1
	if bool(game_state.objectives.get(FAIL_ENUMERATION_KEY, false)):
		return null
	var sources: Array[Dictionary] = []
	for raw_source_id: Variant in source_ids(game_state):
		sources.append({
			OPPORTUNITY.KEY_SOURCE_OWNER_KIND: SOURCE_OWNER_KIND,
			OPPORTUNITY.KEY_RUNTIME_SOURCE_ID: str(raw_source_id),
		})
	return sources


static func derive_timing_window_opportunities(game_state: GameState,
		timing_state: TimingWindowState,
		source_owner_kind: String,
		runtime_source_id: String) -> Variant:
	derivation_calls += 1
	if bool(game_state.objectives.get(FAIL_DERIVATION_KEY, false)):
		return null
	var resolved: Dictionary = game_state.objectives.get(RESOLVED_KEY, {})
	if bool(resolved.get(runtime_source_id, false)):
		return []
	var identity_payload: Dictionary = {
		"lifecycle_id": timing_state.lifecycle_id,
		"source_owner_kind": source_owner_kind,
		"runtime_source_id": runtime_source_id,
		"semantic_key": SEMANTIC_KEY,
	}
	var opportunity: Dictionary = OPPORTUNITY.create({
		OPPORTUNITY.KEY_CAPABILITY_ID: CAPABILITY_ID,
		OPPORTUNITY.KEY_SOURCE_OWNER_KIND: source_owner_kind,
		OPPORTUNITY.KEY_RUNTIME_SOURCE_ID: runtime_source_id,
		OPPORTUNITY.KEY_SEMANTIC_KEY: SEMANTIC_KEY,
		OPPORTUNITY.KEY_CONTROLLER_PLAYER: timing_state.controller_player,
		OPPORTUNITY.KEY_RESOLUTION_KIND: OPPORTUNITY.RESOLUTION_OPTIONAL,
		OPPORTUNITY.KEY_BLOCKING: true,
		OPPORTUNITY.KEY_USE_INTENT: {
			OPPORTUNITY.INTENT_KEY_COMMAND_TYPE: str(game_state.objectives.get(
					USE_COMMAND_TYPE_KEY, "reroll_attack_die")),
			OPPORTUNITY.INTENT_KEY_PLAYER: timing_state.controller_player,
			OPPORTUNITY.INTENT_KEY_PAYLOAD: identity_payload,
		},
		OPPORTUNITY.KEY_DECLINE_INTENT: {
			OPPORTUNITY.INTENT_KEY_COMMAND_TYPE: str(game_state.objectives.get(
					DECLINE_COMMAND_TYPE_KEY, "skip_attack_modifier")),
			OPPORTUNITY.INTENT_KEY_PLAYER: timing_state.controller_player,
			OPPORTUNITY.INTENT_KEY_PAYLOAD: identity_payload,
		},
	})
	var opportunities: Array[Dictionary] = [opportunity]
	if bool(game_state.objectives.get(DUPLICATE_KEY, false)):
		opportunities.append(opportunity.duplicate(true))
	return opportunities


## Returns derived display policy only. It never grants command authority.
static func project_timing_window_opportunity(game_state: GameState,
		timing_state: TimingWindowState,
		opportunity: Dictionary,
		viewer_player: int) -> Dictionary:
	var source_id: String = str(opportunity.get(
			OPPORTUNITY.KEY_RUNTIME_SOURCE_ID, ""))
	var visibility_by_source: Dictionary = visibility_by_source(game_state)
	var visibility: String = str(visibility_by_source.get(
			source_id, VISIBILITY_PUBLIC))
	match visibility:
		VISIBILITY_PUBLIC:
			return {
				"visible": true,
				"source_visible": true,
				"display_key": CAPABILITY_ID,
			}
		VISIBILITY_OWNER_ONLY:
			return {
				"visible": viewer_player == timing_state.controller_player,
				"source_visible": viewer_player == timing_state.controller_player,
				"display_key": CAPABILITY_ID,
			}
		VISIBILITY_HIDDEN_SOURCE:
			return {
				"visible": true,
				"source_visible": viewer_player == timing_state.controller_player,
				"display_key": CAPABILITY_ID,
			}
		_:
			return {}


static func source_ids(game_state: GameState) -> Array:
	var sources: Array = game_state.objectives.get(SOURCES_KEY, []).duplicate()
	if game_state.interaction_flow != null:
		for source_id: Variant in game_state.interaction_flow.payload.get(
				PRIVATE_SOURCES_KEY, []):
			sources.append(source_id)
	return sources


static func has_source(game_state: GameState, source_id: String) -> bool:
	return source_ids(game_state).has(source_id)


static func visibility_by_source(game_state: GameState) -> Dictionary:
	var visibility: Dictionary = game_state.objectives.get(
			VISIBILITY_KEY, {}).duplicate(true)
	if game_state.interaction_flow != null:
		var private_visibility: Variant = game_state.interaction_flow.payload.get(
				VISIBILITY_KEY, {})
		if private_visibility is Dictionary:
			visibility.merge(private_visibility as Dictionary, true)
	return visibility
