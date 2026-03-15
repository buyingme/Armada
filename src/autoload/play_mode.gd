## PlayMode
##
## Singleton that tracks the current play mode (hot-seat or network).
## In hot-seat mode, both players share a single screen with handoff
## overlays and perspective rotation. In network mode, each player
## has their own screen and always sees their own perspective.
##
## Requirements: PM-001–004.
extends Node


## Available play modes.
enum Mode {
	HOT_SEAT, ## Shared screen, sequential turns with handoff overlays.
	NETWORK,  ## Separate screens, simultaneous where rules allow.
}

## The currently active play mode. Defaults to HOT_SEAT for MVP.
## Requirements: PM-004 — MVP implements hot-seat; network is stubbed.
var current_mode: Mode = Mode.HOT_SEAT


## Returns true if the game is running in hot-seat (shared screen) mode.
## Requirements: PM-002 — hot-seat has handoff screens and perspective rotation.
func is_hot_seat() -> bool:
	return current_mode == Mode.HOT_SEAT


## Returns true if the game is running in network mode.
## Requirements: PM-003 — network mode has no handoff or rotation.
func is_network() -> bool:
	return current_mode == Mode.NETWORK


## Sets the play mode. Should be called before starting a game.
## [param mode] — the desired play mode.
func set_mode(mode: Mode) -> void:
	current_mode = mode
