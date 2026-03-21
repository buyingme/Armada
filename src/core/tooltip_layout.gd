## Tooltip Layout
##
## Pure positioning and viewport-clamping logic for the hover tooltip.
## Extends RefCounted so it can be tested without the scene tree.
##
## The tooltip is placed at an offset from the cursor. If it would extend
## beyond the viewport edge, the offset is flipped on the overflowing axis
## and the position is clamped so it stays fully visible.
##
## Requirements: TT-020, TT-021, TT-060.
class_name TooltipLayout
extends RefCounted


## Computes the tooltip screen position given the cursor location, tooltip
## size, viewport bounds and cursor offset.
##
## The default anchor is bottom-right of the cursor (positive offset).
## If the tooltip overflows the right or bottom edge, the offset flips to
## the opposite side on that axis. After flipping, the position is clamped
## so the tooltip never extends outside [code]viewport_size[/code].
##
## [param cursor_pos]   — current mouse position in screen pixels.
## [param tooltip_size] — measured size of the tooltip panel (width × height).
## [param viewport_size] — viewport dimensions (width × height).
## [param offset]       — desired offset from cursor (x, y).
## Returns the top-left position for the tooltip panel.
static func compute_position(
		cursor_pos: Vector2,
		tooltip_size: Vector2,
		viewport_size: Vector2,
		offset: Vector2) -> Vector2:
	var pos: Vector2 = cursor_pos + offset

	# Flip horizontally if overflowing right edge.
	if pos.x + tooltip_size.x > viewport_size.x:
		pos.x = cursor_pos.x - offset.x - tooltip_size.x

	# Flip vertically if overflowing bottom edge.
	if pos.y + tooltip_size.y > viewport_size.y:
		pos.y = cursor_pos.y - offset.y - tooltip_size.y

	# Clamp so the tooltip never goes off-screen (left/top after flip).
	pos.x = clampf(pos.x, 0.0, maxf(viewport_size.x - tooltip_size.x, 0.0))
	pos.y = clampf(pos.y, 0.0, maxf(viewport_size.y - tooltip_size.y, 0.0))

	return pos
