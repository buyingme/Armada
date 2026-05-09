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
	NETWORK, ## Separate screens, simultaneous where rules allow.
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


## Returns true when the local seat physically controls a dedicated
## camera and may rotate it to follow the active player.
##
## In network mode every peer has its own camera, so this returns true
## for any local player.  In hot-seat mode both players share one camera
## that follows the active player, so this returns true only for the
## active seat.
##
## Used by scenes (Phase K) so they can decide between "rotate camera"
## and "lock camera" behaviour without branching on
## [method is_network] directly.  Centralising the deployment-mode
## branch here keeps scenes free of [code]if PlayMode.is_*[/code]
## scattering.
##
## [param active_player] — the player_index whose turn it currently is
## (or [code]-1[/code] when there is no active turn).
## [param local_player] — the local viewer's player_index.
func seat_controls_camera(active_player: int, local_player: int) -> bool:
	if is_network():
		return true
	return active_player >= 0 and active_player == local_player
