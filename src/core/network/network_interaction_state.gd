## NetworkInteractionState
##
## Domain object representing the current interaction window in a network game.
## Broadcast by the server whenever the authoritative interaction step changes.
## Consumed by all clients and the host to drive UI visibility and permission gates.
##
## Rules Reference: G4 Network Plan — §G4.6.6, T0 InteractionStateStepMap.
##
## Serialisation contract: all fields are mutable game state and must survive
## a reconnect snapshot round-trip.  See .skills/serialization_and_commands.md §1.
class_name NetworkInteractionState
extends RefCounted


# ---------------------------------------------------------------------------
# Fields
# ---------------------------------------------------------------------------

## Identifies the high-level flow that is currently active.
## Matches the [code]flow_type[/code] column of the T0 InteractionStateStepMap.
## Examples: "command_phase", "ship_activation", "attack", "displacement".
var flow_type: String = ""

## Identifies the specific step within the active flow.
## Matches the [code]step_id[/code] column of the T0 InteractionStateStepMap.
## Examples: "select_dials", "roll_dice", "defense_tokens".
var step_id: String = ""

## Player index (0 or 1) who holds authority over this interaction window.
## -1 means the server controls the transition (no player input expected).
var controller_player: int = -1

## Visibility scope for this interaction state.
## "all" — broadcast to both players.
## "owner_only" — sent only to the owning player (e.g. Command Phase dial selection).
var visible_to: String = "all"

## Optional step-specific payload (e.g. which ship/squadron is activating,
## which hull zone is being redirected to).  JSON-safe plain types only.
var payload: Dictionary = {}

## Monotonically increasing version counter per match.
## Clients use this to detect duplicates and order out-of-order updates.
var version: int = 0

## Human-readable status text for the score-header in network mode.
## Displayed to the non-controller player as "waiting for …" text per
## StatusTextPolicy.  May be empty; fallback to policy defaults when empty.
var ui_status_text: String = ""


# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

## Serialises this object to a JSON-safe Dictionary.
## Rules Reference: .skills/serialization_and_commands.md §2.1
func serialize() -> Dictionary:
	return {
		"flow_type": flow_type,
		"step_id": step_id,
		"controller_player": controller_player,
		"visible_to": visible_to,
		"payload": payload.duplicate(true),
		"version": version,
		"ui_status_text": ui_status_text,
	}


## Reconstructs a [NetworkInteractionState] from a serialised Dictionary.
## Uses [code].get(key, default)[/code] throughout for forward compatibility.
## [param data] — Dictionary produced by [method serialize].
static func deserialize(data: Dictionary) -> NetworkInteractionState:
	var s: NetworkInteractionState = NetworkInteractionState.new()
	s.flow_type = data.get("flow_type", "")
	s.step_id = data.get("step_id", "")
	s.controller_player = data.get("controller_player", -1)
	s.visible_to = data.get("visible_to", "all")
	s.payload = data.get("payload", {}).duplicate(true)
	s.version = data.get("version", 0)
	s.ui_status_text = data.get("ui_status_text", "")
	return s


# ---------------------------------------------------------------------------
# Version comparison
# ---------------------------------------------------------------------------

## Returns [code]true[/code] if this state has a strictly higher version than
## [param other].  Used to discard stale updates (idempotency rule).
func is_newer_than(other: NetworkInteractionState) -> bool:
	return version > other.version


## Returns [code]true[/code] if this state carries the same version as
## [param other].  Used to detect duplicate broadcasts (no-op guard).
func same_version(other: NetworkInteractionState) -> bool:
	return version == other.version
