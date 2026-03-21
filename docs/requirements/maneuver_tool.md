# Maneuver Tool — Requirements

> **Scope:** Mathematical model, graphical representation, ship attachment,
> joint interaction, and "Display Maneuver Tool" UI flow.
> Full ship movement (activation gating, overlap handling, Navigate command
> speed changes) will be added in Phase 5b.

## 1. Overview

The **maneuver tool** is a segmented measuring device used to move ships. It
consists of **5 physical segments** connected by **4 joints**. The base (root)
segment attaches to the ship's front notch; the remaining segments extend
forward. Each joint can be "clicked" to one of **5 discrete angle positions**
relative to the preceding segment.

**Rules Reference:** RRG "Maneuver Tool" p.10, "Ship Movement" p.16–17,
"Speed Chart" p.18, "Yaw" p.22; LTP "Execute Maneuver" p.8–9.

## 2. Physical Pieces

| Index | Image file | Role |
|-------|-----------|------|
| 0 | `root_filled.png` | Base segment — attaches to ship via guides/notches |
| 1 | `segment_filled.png` | Middle segment 1 |
| 2 | `segment_filled.png` | Middle segment 2 |
| 3 | `segment_filled.png` | Middle segment 3 |
| 4 | `segment_end.png` | End segment (arrow tip) |

Each segment image contains two important landmark types:
- **Intersection points** — the pivot centres where adjacent segments connect
  (i.e. the joint axis). Segment *N* has an "exit" intersection and segment
  *N+1* has a matching "entry" intersection that must coincide.
- **Contact points** — the guide/notch positions where the base segment
  connects to the ship token.

These pixel coordinates will be provided by the user and stored in
`scale_config.json` under a `"maneuver_tool"` section (see § 6).

## 3. Mathematical Model

### MT-M-001 — Segment representation
Each segment is a straight **line** defined by two endpoints (start, end) in
local coordinates. The centre line runs from the entry intersection to the exit
intersection of the segment piece.

### MT-M-002 — Joint angles
There are **4 joints** numbered 0–3 (joint 0 between segments 0–1, joint 3
between segments 3–4). Each joint has exactly **5 discrete angle positions**:

| Clicks | Angle (°) | Description |
|--------|-----------|-------------|
| −2 | −45.0 | Hard port (left) |
| −1 | −22.5 | Slight port |
|  0 |   0.0 | Straight |
| +1 | +22.5 | Slight starboard (right) |
| +2 | +45.0 | Hard starboard |

Positive angles = clockwise (starboard). The constant **`YAW_DEGREES_PER_CLICK`**
is **22.5°** (updated from the previous tabletop-accurate 11.25°).

### MT-M-003 — Chain computation
Given the ship's transform and an array of 4 joint angles, the model computes
the world-space position and rotation of every joint and segment endpoint by
chaining transforms:

1. Start at the ship's front notch (orientation = ship heading).
2. Advance by segment 0's length along the current heading.
3. At joint 0, apply the joint angle (rotate heading).
4. Advance by segment 1's length.
5. Repeat for joints 1–3 and segments 2–4.

The result is an `Array[Transform2D]` with 5 entries (one per joint *exit*,
plus the tip of segment 4).

### MT-M-004 — Speed determines active joints
At speed *N* (1–4), only joints 0 to *N−1* are active. Inactive joints
remain straight (0°). Speed 0 = no movement.
Rules Reference: RRG "Maneuver Tool" p.10 — "players ignore the segments
beyond the final joint."

### MT-M-005 — Yaw validation
The navigation chart on each ship card defines the **maximum click count**
per joint per speed. The model must reject any joint angle that exceeds the
ship's allowed yaw.
Rules Reference: RRG "Speed Chart" p.18, "Yaw" p.22.

### MT-M-006 — Navigate command yaw bonus
A Navigate command (dial or token) can increase the yaw value of **one** joint
by 1 click for the current maneuver, and/or change speed ±1.
Rules Reference: RRG "Commands" p.3; MV-006, CM-011.

## 4. Graphical Representation

### MT-G-001 — Segment sprites
Each segment is rendered as a `Sprite2D` (or `TextureRect`) using the
corresponding PNG image (`root_filled`, `segment_filled`, `segment_end`).

### MT-G-002 — Alignment to joints
Each sprite is positioned and rotated so that its **intersection points**
(measured from the PNG) align exactly with the mathematical joint positions
computed by the model. The entry intersection of segment *N+1* must overlay
the exit intersection of segment *N*.

### MT-G-003 — Joint click interaction
Each joint region is **clickable**.
- **Left mouse click** on a joint → click the joint **to the left** (port, −1).
- **Right mouse click** on a joint → click the joint **to the right**
  (starboard, +1).
- Angles clamp at ±2 clicks (−45° to +45°). The graphical representation
  updates immediately to reflect the new angle.

### MT-G-004 — Visual feedback for active/inactive joints
At a given speed, only active joints are clickable and rendered at full
opacity. Inactive joints and their segments are dimmed or hidden.
Rules Reference: MT-M-004.

### MT-G-005 — Ship attachment point
The root segment attaches to the **left side** of the ship's base front edge
by default. The ship token's front-left corner is at local coordinates
`(-half_w, -half_l)` and front-right corner at `(+half_w, -half_l)`.
The root segment's `contact_left` and `contact_right` points align with the
front-left corner `(0, 0)` in ship-notch coordinates, where:
- Left side attachment: contact point maps to `(-half_w, -half_l)` world space.
- Right side attachment: contact point maps to `(+half_w, -half_l)` world space.

The tool extends in the ship's **facing direction** (−Y in local space).

### MT-G-006 — Side selection
The tool can be placed on either side of the ship's base. The player must
choose the side. If the ship would overlap the tool in its final position on
one side, the other side must be used.
Rules Reference: RRG "Ship Movement"; MV-012, MV-013.

### MT-G-007 — Preview ghost
While the tool is being configured (Determine Course step), a translucent
"ghost" ship is rendered at the projected final position to preview the
result of the maneuver.

### MT-G-008 — Contact points on all segments
Each segment piece (root, middle, end) has `contact_left` and `contact_right`
points measured from the PNG. At the **end of a maneuver**, the ship's front
notch slides over the joint guides at the segment matching the ship's speed.
These contact points define where the ship's notch lands on each joint:
- **Root:** contact points = guide pins that attach to the ship at the start.
- **Middle/End segments:** contact points = where the ship base's notch
  would land when the ship is placed at that joint.

## 5. UI Flow

### MT-U-001 — Action toolbar (lower-right)
A small toolbar in the **lower-right corner** of the screen groups action
buttons. The existing **tooltip toggle** button moves into this toolbar.
The toolbar is always visible on the game board.

### MT-U-002 — "Display Maneuver Tool" button
The toolbar contains a **"Display Maneuver Tool"** button (icon or label).
Pressing it enters **ship selection mode**: the cursor changes or a prompt
appears ("Select a ship").

### MT-U-003 — Ship selection prompt
While in ship selection mode:
- Clicking a **ship token** on the board selects that ship.
- Pressing Escape or clicking the button again cancels selection mode.
- A `TooltipManager.show_text()` prompt indicates the selection mode.

### MT-U-004 — Tool appears on selected ship
When a ship is selected, the maneuver tool appears **attached to the left
side** of the ship's base front edge, with all joints straight (0°).
The tool's speed is set to the ship's current speed.

### MT-U-005 — Interactive joint adjustment
While the tool is displayed, the player can left/right-click joints to
adjust angles (MT-G-003). The tool redraws in real time.

### MT-U-006 — Dismissing the tool
Clicking the "Display Maneuver Tool" button again, pressing Escape, or
clicking elsewhere on the board dismisses the tool.

## 6. Data — Pixel Coordinates in `scale_config.json`

The `"maneuver_tool"` section in `scale_config.json` stores all pixel
measurements taken from the segment PNG images. This is consistent with the
existing pattern where `base_graphics` stores sprite measurements and
`physical_dimensions_mm` stores real-world sizes.

### MT-D-001 — Config structure

```json
{
  "maneuver_tool": {
    "yaw_degrees_per_click": 22.5,
    "root": {
      "image": "root_filled.png",
      "entry_intersection": { "x": 18, "y": 118 },
      "exit_intersection": { "x": 18, "y": 18 },
      "contact_left":  { "x": 0, "y": 99 },
      "contact_right": { "x": 35, "y": 99 }
    },
    "segment": {
      "image": "segment_filled.png",
      "entry_intersection": { "x": 21, "y": 149 },
      "exit_intersection": { "x": 21, "y": 18 },
      "contact_left":  { "x": 3, "y": 100 },
      "contact_right": { "x": 38, "y": 100 }
    },
    "segment_end": {
      "image": "segment_end.png",
      "entry_intersection": { "x": 21, "y": 149 },
      "contact_left":  { "x": 3, "y": 100 },
      "contact_right": { "x": 38, "y": 100 },
      "speed_reduction_button": { "x": 11, "y": 77 },
      "speed_increase_button":  { "x": 30, "y": 77 }
    }
  }
}
```

**Note:** `segment_end` has no `exit_intersection` — the arrow tip is the
visual terminus.

**Orientation:** `entry_intersection` is the **ship side** of each piece
(higher Y = bottom of PNG). `exit_intersection` is the **forward side**
(lower Y = top of PNG). The tool extends in the ship's facing direction.

### MT-D-002 — Contact points on all segments
Every segment has `contact_left` and `contact_right` fields. On the root,
these represent the guide pins. On middle/end segments, these represent where
the ship base's left/right notch would rest when placed at that joint.

### MT-D-003 — Segment length derivation
The mathematical segment length is the pixel distance between
`entry_intersection` and `exit_intersection` within each PNG.
Root: `|118 − 18| = 100 px`. Middle: `|149 − 18| = 131 px`.

## 7. Acceptance Criteria

| ID | Criterion |
|----|-----------|
| AC-01 | Mathematical model computes joint positions for all 5×5×5×5 angle combinations at speed 4 without error. |
| AC-02 | Setting a joint angle beyond ±2 clicks is rejected. |
| AC-03 | Yaw validation correctly checks against any ship's navigation chart at all speeds. |
| AC-04 | Graphical segments align with mathematical joint positions — no visible gap or overlap at joints. |
| AC-05 | Left-clicking a joint rotates it to the left (port); right-clicking rotates to the right (starboard). |
| AC-06 | Inactive joints (beyond current speed) are non-interactive and visually dimmed. |
| AC-07 | Ghost ship preview appears at the correct final position matching the mathematical model. |
| AC-08 | The tool attaches to the left side of the selected ship by default. |
| AC-09 | All pixel coordinates are read from `scale_config.json`, not hardcoded. |
| AC-10 | Navigate command correctly increases one joint's max yaw by 1. |
| AC-11 | Unit tests cover: chain computation, yaw validation, speed filtering, navigate bonus. |
| AC-12 | `YAW_DEGREES_PER_CLICK` = 22.5° throughout all code. |
| AC-13 | "Display Maneuver Tool" button appears in a lower-right toolbar alongside the tooltip toggle. |
| AC-14 | Pressing the button prompts "Select a ship"; clicking a ship shows the tool aligned to its left side. |
| AC-15 | Pressing Escape or the button again dismisses the tool / cancels selection. |
| AC-16 | Contact points on each segment match the measured PNG coordinates. |

## 8. Dynamic Alignment

### MT-A-001 — Default alignment
The maneuver tool defaults to the **left** side of the ship base: the
ship's front-left corner is aligned to the root segment's `contact_right`,
and the ghost's front-left corner is aligned to the end segment's
`contact_right`.

### MT-A-002 — Automatic side switching
After any joint angle change, the tool scans joints from the **end segment
backwards** (highest active joint first). The **first joint with a non-zero
click value** determines the alignment side for **both** the root
attachment and the ghost:
- Click < 0 (port / left bend) → side = **left**: ship's front-left
  corner aligned to the root's `contact_right`, ghost's front-left corner
  aligned to the end segment's `contact_right`. The tool is on the
  **left** side of the ship, same side as the bend direction.
- Click > 0 (starboard / right bend) → side = **right**: ship's
  front-right corner aligned to the root's `contact_left`, ghost's
  front-right corner aligned to the end segment's `contact_left`. The
  tool is on the **right** side of the ship, same side as the bend
  direction.

If all joints are straight (0), the alignment remains **left** (default).

### MT-A-003 — Overlap prevention intent
Because the tool follows the bend direction, the ghost ship preview
always appears on the **opposite** side from the bend — preventing
overlap between the ghost and the maneuver tool segments.

### MT-A-004 — Root and ghost switch together
Both the root segment attachment **and** the ghost placement use the
same computed side. When the alignment side flips, the tool visually
re-attaches to the other side of the ship base and the ghost
correspondingly moves to the opposite side of the end segment.

## 9. Speed Simulation

### MT-S-001 — Speed buttons on end segment
The end segment displays two clickable buttons:
- **"−" button** at `speed_reduction_button` pixel position: decreases
  simulated speed by 1.
- **"+" button** at `speed_increase_button` pixel position: increases
  simulated speed by 1.

Button positions are read from `scale_config.json` → `maneuver_tool` →
`segment_end` → `speed_reduction_button` / `speed_increase_button`.
Each button renders as a 20 px diameter circle with a centred "−" or "+" label.

### MT-S-002 — Simulated speed bounds
The simulated speed is clamped to `[1, ship_data.max_speed]`. The ship's
`ShipData.max_speed` defines the upper bound. Speed 0 is not reachable
(a ship with speed 0 has no maneuver tool).

### MT-S-003 — Nav chart adapts to simulated speed
When the simulated speed changes, the tool re-evaluates:
1. **Active segment count** = simulated_speed + 1.
2. **Active joints** = 0 to simulated_speed − 1.
3. **Max yaw per joint** = `nav_chart[simulated_speed − 1][joint_index]`.
4. Any joint click that now exceeds the new max yaw is clamped to the new
   maximum (retaining its sign).

### MT-S-004 — Segment count adapts
Increasing simulated speed adds segments; decreasing removes them. The
visual tool immediately redraws to show the correct number of active
segments for the simulated speed.

### MT-S-005 — Speed label on ghost
The ghost ship preview displays the simulated speed at the same position
where the ship token renders its speed value (i.e. using the ship JSON's
`token_label_offsets.speed` with the same font size and sprite-scale
conversion as `ShipToken._draw_label_on()`).

### MT-S-006 — Simulation is preview-only
The simulated speed does **not** modify the ship's `ShipInstance.current_speed`.
It is purely a what-if preview. Actual speed changes occur during the
Navigate command in Phase 5b.

## 10. Updated Data — `scale_config.json` additions

### MT-D-003a — Speed button coordinates
The `segment_end` section gains two new fields:

```json
"segment_end": {
  "image": "segment_end.png",
  "entry_intersection": { "x": 21, "y": 149 },
  "contact_left":  { "x": 3, "y": 100 },
  "contact_right": { "x": 38, "y": 100 },
  "speed_reduction_button": { "x": 11, "y": 77 },
  "speed_increase_button":  { "x": 30, "y": 77 }
}
```

## 11. Updated Acceptance Criteria

| ID | Criterion |
|----|-----------|
| AC-17 | Root attachment and ghost alignment auto-switch together: bending left → tool on left side (ship + ghost front-left corner to tool's right contact); bending right → tool on right side (ship + ghost front-right corner to tool's left contact). |
| AC-18 | All joints straight → root attachment and ghost both default to left alignment. |
| AC-19 | Speed +/− buttons render on the end segment at configured pixel positions. |
| AC-20 | Clicking + increases simulated speed; − decreases it. Both clamp to [1, max_speed]. |
| AC-21 | Segment count and active joints adapt when simulated speed changes. |
| AC-22 | Joint angles are clamped to the new nav chart row after speed change. |
| AC-23 | Simulated speed label appears on the ghost at the ship's speed label position. |
| AC-24 | Simulated speed does not modify ShipInstance.current_speed. |
| AC-25 | Speed button positions are read from scale_config.json, not hardcoded. |

## 12. Implementation Notes

### Architecture

| Component | Layer | Extends | File |
|-----------|-------|---------|------|
| `ManeuverTool` (math model + state) | Core | `RefCounted` | `src/core/maneuver_tool.gd` |
| `ManeuverCalculator` (existing) | Core | `RefCounted` | `src/core/maneuver_calculator.gd` — `YAW_DEGREES_PER_CLICK` = 22.5° ✅ |
| `ManeuverToolScene` (visual) | Presentation | `Node2D` | `src/scenes/tools/maneuver_tool_scene.gd` + `.tscn` |
| `ActionToolbar` (lower-right) | Presentation | `HBoxContainer` | `src/ui/action_toolbar.gd` — hosts tooltip toggle + maneuver tool button |
| `GameScale` extensions | Autoload | `Node` | `src/autoload/game_scale.gd` — load `maneuver_tool` config |
| Pixel data | Data | — | `Resources/Game_Components/scale/scale_config.json` |

### Relationship to existing code

- `ManeuverCalculator` already has `compute_tool_joints()` and
  `compute_final_transform()`. The `ManeuverTool` model will *use*
  `ManeuverCalculator` for the chain computation but add state management
  (current joint angles, active speed, yaw validation with nav chart).
- `ManeuverCalculator.YAW_DEGREES_PER_CLICK` already updated to 22.5°.
- The tooltip toggle button currently lives on the `TooltipManager`'s own
  CanvasLayer. It will be moved into the new `ActionToolbar`.

### Phasing

1. **Phase 5a (this ticket):** Mathematical model, graphical representation,
   action toolbar, ship selection flow, tool display with interactive joints.
2. **Phase 5b:** Wire into activation flow — attach to ship during Execute
   Maneuver step, compute final position, handle overlaps, Navigate command.
