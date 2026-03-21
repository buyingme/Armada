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
2. **Phase 5b:** Wire into activation flow — activation modal, Navigate
   command, maneuver execution, ship placement.

---

## Phase 5b — Ship Movement Execution

### 13. Activation Modal

When a ship is activated during the Ship Phase (dial revealed and
assigned), a **"Show Activation Sequence"** button appears at
bottom-centre of the screen. Pressing it opens the **Activation
Modal**, which guides the player through the sub-steps of activation
in sequence. The modal is a persistent panel displayed alongside the
game board.

#### ACT-001 — Modal lifecycle
The Activation Modal does **not** auto-open.  After the command dial
is revealed and assigned (Phase 4c triggers), a "Show Activation
Sequence" button appears at bottom-centre.  Pressing the button
opens the modal.  The modal is a **centred panel** (dark-blue
`#0D1B2A` background, rounded corners) matching the
`CommandDialPicker` styling.

The modal can be dismissed with Escape or the ✕ button and
reopened at any time.  The activation ends **automatically** after
the maneuver is committed — there is no separate "End Activation"
button.

#### ACT-002 — Step sequence
The modal presents the activation sub-steps in the following order.
Each step is a distinct section of the modal that becomes active
only when the previous step is complete (or skipped).

| # | Step name | Timing | Command resolved |
|---|-----------|--------|------------------|
| 1 | Reveal Command Dial | Automatic (already done by Phase 4c) | — |
| 2 | Squadron Command (O) | After dial reveal | O dial and/or O token |
| 3 | Repair Command (Q) | After dial reveal | Q dial and/or Q token |
| 4 | Attack | After step 1 commands | P dial and/or P token (during attack sub-steps) |
| 5 | Execute Maneuver | After attack | M dial and/or M token (during Determine Course) |

Rules Reference: RRG "Ship Activation" p.16, "Commands" p.3.

**Order within step 1 commands:** Squadron (O) and Repair (Q) both
resolve "after revealing the ship's command dial". The modal presents
Squadron first, then Repair. Both are optional; each may be skipped
by pressing "Skip".

#### ACT-003 — Displayed command info
The modal shows the **revealed command** (from the dial) and each
**command token** held by the ship. For each step the relevant
command source(s) are highlighted:
- If the ship's revealed dial matches the step's command → show dial icon.
- If the ship holds a matching command token → show token icon.
- If both → show both; player can choose dial, token, or combined.

Rules Reference: CM-001 – CM-003.

#### ACT-004 — Not-yet-implemented steps (placeholder)
Steps 2 (Squadron), 3 (Repair), and 4 (Attack) display a "Not yet
implemented" badge and an auto-skip button. They cannot be interacted
with in Phase 5b.  The step label, command icon, and availability
status are still rendered so the player sees the full flow.

#### ACT-005 — Command spending rules
A ship **can** spend both a command dial and a command token of the
same type to combine their effects (counts as one resolution).
A ship **cannot** resolve the same command more than once per round.
The player must choose dial, token, or both **before** resolving.

Rules Reference: CM-002, CM-003.

#### ACT-006 — Prefer dial over token (UI default)
When the revealed dial's command matches the current step, the UI
**defaults to spending the dial** (higher effect). The player may
explicitly opt to spend only the token instead, but the dial is
pre-selected.  This incentivises saving tokens for later rounds.

#### ACT-007 — "Show Activation Sequence" button
After the command dial is revealed and assigned, a button labelled
**"Show Activation Sequence"** appears at **bottom-centre** of the
screen (same position used by `EndActivationButton`).  Pressing it:
1. Hides the "Show Activation Sequence" button.
2. Opens the Activation Modal (see ACT-001).

The button remains visible until pressed; it does **not** auto-dismiss.

### 14. Navigate Command — Execute Maneuver Step

#### NAV-001 — Timing
The Navigate command resolves during the "Determine Course" sub-step
of the Execute Maneuver step.

Rules Reference: CM-010.

#### NAV-002 — Dial effect
Spending the Navigate **dial** allows:
- Increase **or** decrease the ship's speed by 1, **and/or**
- Increase the yaw value of **one** joint by 1 for this maneuver.

Rules Reference: CM-011.

#### NAV-003 — Token effect
Spending the Navigate **token** allows:
- Increase **or** decrease the ship's speed by 1.

(No yaw bonus.)

Rules Reference: CM-012.

#### NAV-004 — Combined dial + token
If the player spends **both** a Navigate dial and a Navigate token,
their effects combine (single resolution):
- Speed may change by up to ±2, **and/or**
- Yaw of one joint increased by 1.

Rules Reference: CM-003, CM-011, CM-012.

#### NAV-005 — Speed bounds
Speed after Navigate is clamped to [0, ship_data.max_speed].
A ship at speed 0 does not display the maneuver tool; it executes
a 0-speed maneuver (stays in place).

Rules Reference: CM-013, MV-015.

#### NAV-006 — Yaw bonus joint
When the Navigate dial grants +1 yaw on one joint, the player
chooses which active joint receives the bonus by **clicking that
joint beyond its base yaw limit**.  The bonus is auto-applied to
whichever joint the player clicks; an "N" badge appears on that
joint.  If the player later clicks a different joint beyond *its*
base limit, the bonus **moves** to the new joint (old joint clicks
clamped to its reduced limit).  The bonus applies for this maneuver
only; it does not persist.

#### NAV-007 — Token-only highlight and spending
If the player changes speed but does **not** have a matching Navigate
dial (the dial was converted to token or set to a different command),
the Navigate token to be spent is highlighted with a **reddish
overlay** in the ship card panel.  When the maneuver is committed,
the Navigate token is **removed** from the ship's token pool via
`CommandTokenManager` and the overlay disappears.

#### NAV-008 — Speed change via +/− buttons
The same +/− buttons on the end segment used for Phase 5a+ simulation
are reused during Execute Maneuver.  In **activation mode** (as
opposed to simulation mode) clicking +/− actually changes the ship's
speed (writes `ShipInstance.current_speed`), subject to command
availability and bounds.

- If the ship has a Navigate **dial**: up to ±1 from the dial, plus
  up to ±1 from a token if also available (max ±2 total).
- If the ship has only a Navigate **token**: up to ±1.
- If the ship has **neither**: no speed change allowed; buttons
  disabled.

### 15. Maneuver Execution

#### EXE-001 — Two-phase Execute / Commit button
Step 5 of the Activation Modal contains a **two-phase button**
embedded in the modal panel (not a separate bottom-centre button):

1. **Phase 1 — "Execute Maneuver ►"**: Displayed when step 5
   first becomes active.  Pressing it closes the modal and shows
   the maneuver tool on the ship in activation mode.
2. **Phase 2 — "Commit Maneuver ►"**: Displayed when the modal
   is reopened after the tool is active.  Pressing it commits
   the maneuver:
   a. Ship speed is updated to the maneuver speed (if changed via Navigate).
   b. Ship position and rotation are set to the computed final
      transform (`ManeuverToolState.compute_final_transform()`).
   c. The maneuver tool is dismissed.
   d. `EventBus.ship_moved` is emitted.
   e. Navigate token is removed from `CommandTokenManager` if spent.
   f. The activation **auto-ends** — no "End Activation" button
      is shown.  The next player's turn begins immediately.

#### EXE-002 — Ship snap placement
The ship token is placed **instantly** (no animation) at the final
transform computed by the maneuver tool state.

Rules Reference: MV-010 – MV-014.

#### EXE-003 — Side selection
The tool and ship use `compute_ghost_side()` (from Phase 5a+) to
determine which side of the maneuver tool the ship's front notch
attaches to.  If the ship would overlap the tool on the computed
side, the opposite side is used.

Rules Reference: MV-012, MV-013.

#### EXE-004 — Speed 0 maneuver
If the ship's speed is 0 (either originally or after Navigate),
no maneuver tool is displayed.  The ship stays in place.
The maneuver still counts as executed.

Rules Reference: MV-015.

#### EXE-005 — Yaw bonus indicator
When a Navigate dial grants a +1 yaw bonus joint, the affected
joint's click indicator on the maneuver tool scene displays a
visual marker (e.g. a small "N" badge or different colour tint)
to distinguish the bonus click from the ship's base yaw allowance.

### 16. Activation flow integration

#### FLOW-001 — Activation trigger unchanged
Ship activation is still triggered via the existing Phase 4c
mechanism (drag-and-drop dial to ship token, or drag to card panel
to convert to token).

#### FLOW-002 — Button replaces direct End Activation
The current "End Activation" button is no longer shown immediately
after dial reveal.  Instead, a **"Show Activation Sequence"** button
appears at bottom-centre (ACT-007).  Pressing it opens the
Activation Modal, which guides the player through steps.

After the maneuver is committed, the activation **ends
automatically** — there is no manual "End Activation" button.
The simulation maneuver button ("M" in the action toolbar) is
**disabled** while any ship is in activation mode.

#### FLOW-003 — Maneuver tool in activation mode
During the Execute Maneuver step, the maneuver tool is displayed
automatically (no need to press "Display Maneuver Tool").  Joint
interaction, speed buttons, and ghost preview work identically to
Phase 5a/5a+ simulation mode, except:
- Speed changes via +/− are **real** (write to `ShipInstance`).
- Speed changes are gated by Navigate command availability.
- An optional bonus yaw joint is available if Navigate dial is spent.

#### FLOW-004 — Activation step tracking
A new core class `ShipActivationState` (RefCounted) tracks which
sub-step the activation is in and which commands have been spent
this activation.  This prevents double-spending and enforces the
sequential step order.

### 17. Updated Acceptance Criteria (Phase 5b)

| ID | Criterion |
|----|-----------|
| AC-5b-01 | "Show Activation Sequence" button appears at bottom-centre after dial reveal; pressing it opens the activation modal showing all 5 steps. |
| AC-5b-02 | Steps 2–4 (Squadron, Repair, Attack) display "Not yet implemented" and auto-skip. |
| AC-5b-03 | Step 5 (Execute Maneuver) shows "Execute Maneuver ►" button; pressing it opens the maneuver tool in activation mode. |
| AC-5b-04 | Navigate dial: allows speed ±1 AND/OR +1 yaw on one joint. |
| AC-5b-05 | Navigate token: allows speed ±1 only, no yaw bonus. |
| AC-5b-06 | Navigate dial + token combined: speed ±2 AND/OR +1 yaw. |
| AC-5b-07 | Token-only speed change highlights the token with reddish overlay. |
| AC-5b-08 | Two-phase button: "Execute Maneuver ►" opens tool → "Commit Maneuver ►" commits the move. |
| AC-5b-09 | Ship snaps instantly to final transform after Execute Maneuver. |
| AC-5b-10 | Speed 0 maneuver: no tool shown, ship stays in place, still counts as maneuver. |
| AC-5b-11 | Activation auto-ends after maneuver commit — no manual "End Activation" button. |
| AC-5b-12 | Ship's actual speed is updated after maneuver (if Navigate changed it). |
| AC-5b-13 | `EventBus.ship_moved` emitted after placement. |
| AC-5b-14 | Activation modal shows revealed dial command and available tokens per step. |
| AC-5b-15 | A command cannot be resolved more than once per activation (CM-002). |
| AC-5b-16 | Simulation maneuver button disabled during activation mode. |
| AC-5b-17 | Navigate token removed from ship's CommandTokenManager on commit. |
| AC-5b-18 | Activation Modal is centred (matching CommandDialPicker style), dismissible with Escape/✕. |
