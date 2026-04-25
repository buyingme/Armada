## InteractionFlow
##
## Authoritative description of the active interactive UI state.
## Held inside [GameState.interaction_flow]; mutated only inside
## [GameCommand.execute()].  Travels with [GameState] across the network
## (via [code]command_result[/code]) and across save/load (via
## [code]GameState.serialize()[/code]).
##
## Replaces the legacy parallel RPC interaction-state channel
## (G4.6.6 T1a).  See [code]docs/refactoring_phase_i_plan.md[/code].
##
## Rules: see [code].skills/architecture_patterns.md[/code] §5 and
## [code].skills/serialization_and_commands.md[/code] §1–§2.
class_name InteractionFlow
extends RefCounted


# ---------------------------------------------------------------------------
# Fields
# ---------------------------------------------------------------------------

## High-level flow currently active.
var flow_type: Constants.InteractionFlow = Constants.InteractionFlow.NONE

## Specific step within the active flow.
var step_id: Constants.InteractionStep = Constants.InteractionStep.NONE

## Player index (0 or 1) that holds authority over this interaction window.
## −1 means the server controls the transition (no player input expected).
var controller_player: int = -1

## Visibility scope of [member payload].  Filtered by [StateFilter] before
## a snapshot leaves the server.
var visible_to: Constants.Visibility = Constants.Visibility.ALL

## Optional step-specific data (e.g. ship_index, attack_id, available
## defense tokens).  JSON-safe plain types only — no Vector2, Color, or
## pixel values.  See [code].skills/serialization_and_commands.md[/code]
## §2.2.
var payload: Dictionary = {}


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Constructs a flow descriptor with all fields set.
## Convenience for [GameCommand.execute()] mutation sites.
static func make(
		flow_type: Constants.InteractionFlow,
		step_id: Constants.InteractionStep,
		controller_player: int,
		visible_to: Constants.Visibility = Constants.Visibility.ALL,
		payload: Dictionary = {}) -> InteractionFlow:
	var f: InteractionFlow = InteractionFlow.new()
	f.flow_type = flow_type
	f.step_id = step_id
	f.controller_player = controller_player
	f.visible_to = visible_to
	f.payload = payload.duplicate(true)
	return f


# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

## Serialises this flow to a JSON-safe Dictionary.
## Enums are stored as int per the serialization contract.
func serialize() -> Dictionary:
	return {
		"flow_type": int(flow_type),
		"step_id": int(step_id),
		"controller_player": controller_player,
		"visible_to": int(visible_to),
		"payload": payload.duplicate(true),
	}


## Reconstructs an [InteractionFlow] from a serialised Dictionary.
## Uses [code].get(key, default)[/code] throughout for forward compatibility.
static func deserialize(data: Dictionary) -> InteractionFlow:
	var f: InteractionFlow = InteractionFlow.new()
	f.flow_type = (int(data.get("flow_type", 0))) as Constants.InteractionFlow
	f.step_id = (int(data.get("step_id", 0))) as Constants.InteractionStep
	f.controller_player = int(data.get("controller_player", -1))
	f.visible_to = (int(data.get("visible_to", 0))) as Constants.Visibility
	var raw_payload: Variant = data.get("payload", {})
	if raw_payload is Dictionary:
		f.payload = (raw_payload as Dictionary).duplicate(true)
	else:
		f.payload = {}
	return f


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns [code]true[/code] when [param player_index] is the player who
## must act on this interaction window.
func is_actor(player_index: int) -> bool:
	return controller_player == player_index


## Returns a fresh empty flow (NONE/NONE/-1/ALL/{}).
## Use as the default when [GameState] is reset.
static func empty() -> InteractionFlow:
	return InteractionFlow.new()


## Equality by all five fields.  Used by I2's invariant test.
func equals(other: InteractionFlow) -> bool:
	if other == null:
		return false
	if flow_type != other.flow_type:
		return false
	if step_id != other.step_id:
		return false
	if controller_player != other.controller_player:
		return false
	if visible_to != other.visible_to:
		return false
	return _payloads_equal(payload, other.payload)


static func _payloads_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a.keys():
		if not b.has(k):
			return false
		if a[k] != b[k]:
			return false
	return true
