# Attack Simulator — Requirements

> **Scope:** Phase 6a — Attacker Declaration & Visual Aids.
> Only the *selection* of the attacking hull zone / squadron and the
> corresponding visual cues on the board.  Dice rolling, defense tokens,
> and damage resolution remain in Phase 6 proper.

---

## 1. Overview

The Attack Simulator is an interactive, step-by-step tool that guides the
player through the Armada attack sequence.  Phase 6a implements the first
step: **Attacker Declaration**.

> Rules Reference: "Attack", Step 1, p.2.
> "The attacker declares the attacking hull zone or squadron."

The tool is activated from a new **"A"** button on the `ActionToolbar` (or
by pressing the **A** key).  It can be cancelled at any time.  When an
attacking hull zone or squadron is selected, the board draws visual aids
(range overlay, firing arc lines, LOS marker) to help the player evaluate
potential targets.

---

## 2. Activation & Dismissal

### AS-ACT-001 — "A" button on ActionToolbar

Add a button labelled **"A"** (for Attack) to the `ActionToolbar`, after the
existing T button.

- Styled consistently with M, R, and T buttons.
- Emits `EventBus.attack_simulator_requested` when pressed.
- Disabled during ship activation (same guard as M / R / T).

### AS-ACT-002 — Keyboard shortcut (A key)

Pressing **A** on the keyboard triggers the same action as clicking the "A"
button.  When the attack simulator is active, pressing **A** again cancels it
(toggle).  The shortcut is available whenever the toolbar buttons are not
disabled.

### AS-ACT-003 — Cancel via Escape

Pressing **Escape** at any point during the attack simulator cancels the
current session, removes all visual aids, and returns to normal board
interaction.

### AS-ACT-004 — Cancel via "A" button re-click

Clicking the "A" button (or pressing the A key) while the attack simulator
is active cancels the session — same effect as Escape.

### AS-ACT-005 — Single-instance constraint

Only one attack simulator session can be active at a time.  Activating the
attack simulator while the range overlay or targeting list is active
dismisses those first.  Conversely, activating the range overlay or targeting
list while the attack simulator is active cancels the attack simulator.

---

## 3. Info Panel

### AS-PNL-001 — Screen-space info panel

When the attack simulator is activated, a `PanelContainer` modal appears on
screen (following the project's standard modal styling from
`.skills/ui_styling.md`).  The panel shows step-by-step prompts guiding the
player through the attack sequence.

Position: anchored at the screen bottom-centre (above the toolbar) or at
the right side — whichever avoids overlapping the active ship.

### AS-PNL-002 — Initial prompt

On activation, the info panel displays:

> **Attack Simulator**
> Select a hull zone or squadron as the attacker.

This text remains until the player makes a selection or cancels.

### AS-PNL-003 — Panel dismissed on cancel

When the attack simulator is cancelled (Escape / A button), the info panel
is removed from the scene tree.

---

## 4. Attacker Selection — Hull Zone

### AS-SEL-001 — Click hull zone directly

The player directly clicks a hull zone on any **friendly ship** (belonging to
the active player) to select it as the attacking hull zone.  The click is
resolved by determining which quadrant of the ship base the click position
falls into (FRONT / LEFT / RIGHT / REAR).

> Implementation: Convert the click to the ship's local space and determine
> the hull zone from the ship's geometry (half-width, half-length, the four
> base quadrant regions).

### AS-SEL-002 — Only friendly ships respond

Clicks on enemy ships or enemy squadrons during attacker selection are
ignored.  Only tokens belonging to the active player are valid.

### AS-SEL-003 — Hull zone feedback on hover (nice-to-have)

When hovering over a friendly ship, the hull zone under the cursor is
subtly highlighted (e.g. tinted or outlined).  This is optional for the
first implementation pass.

---

## 5. Attacker Selection — Squadron

### AS-SEL-010 — Click squadron token

Clicking a friendly squadron token selects it as the attacker.  Squadrons
have a 360° arc and attack at distance 1.

> Rules Reference: "Firing Arc" — "Each squadron has a 360° firing arc."
> Rules Reference: "Attack Range" — "Each squadron's attack range is distance 1."

### AS-SEL-011 — Only friendly squadrons respond

Clicks on enemy squadrons during attacker selection are ignored.

---

## 6. Visual Aids — Hull Zone Selected

When a hull zone is selected on a ship, the following visual aids appear:

### AS-VIS-001 — Range overlay

Show the ship's range overlay image (same as the "R" tool) centred on the
selected ship.  Reuse the existing `RangeOverlayScene` component.

### AS-VIS-002 — Firing arc boundary lines

Draw two thin white lines from the ship's base to the edge of the visible
play area, along the two boundary lines that define the selected hull zone's
firing arc.

- Line colour: `Color(1.0, 1.0, 1.0, 0.6)` — white, 60 % opacity.
- Line width: 1.5 px (anti-aliased).
- Start point: each of the two inner boundary points on the ship base
  (`inner_point_<zone>_left`, `inner_point_<zone>_right` from
  `firing_arc_boundaries`).
- End point: extend the direction from inner→outer boundary point until
  the line exits the play area rectangle.

> Implementation: Use the existing `firing_arc_boundaries` data from
> `ShipData` (already available via `ShipToken.get_firing_arc_world_points()`).
> Compute the outer direction from `inner_point → outer_point` and extend
> to the play area boundary.

### AS-VIS-003 — LOS targeting point marker

Place a translucent yellow circle (6 px diameter) at the world-space position
of the selected hull zone's line-of-sight targeting point.

- Colour: `Color(1.0, 1.0, 0.0, 0.6)` — yellow, 60 % opacity.
- Diameter: 6 px.
- Position: `ShipToken.get_los_origins_world()[zone_key]`.

> Implementation: Reuse the existing `line_of_sight_origins` data from
> `ShipData` (available via `ShipToken.get_los_origins_world()`).

### AS-VIS-004 — Info panel updates

After the hull zone is selected, the info panel text updates to:

> **Attacking: \<ShipName\> — \<ZONE\> arc**
> Select a target (next step — not yet implemented).

This is a placeholder for Phase 6 proper.

---

## 7. Visual Aids — Squadron Selected

When a squadron is selected as the attacker:

### AS-VIS-010 — Close-range circle

Draw a circle centred on the squadron token showing the **close range**
(distance 1) boundary — i.e. the squadron's maximum attack range.

- Circle radius: `squadron_base_radius + GameScale.range_close_px`.
- Colour: `Color(1.0, 1.0, 1.0, 0.3)` — white, 30 % opacity.
- Line width: 1.5 px (anti-aliased).

### AS-VIS-011 — Info panel updates

After the squadron is selected, the info panel text updates to:

> **Attacking: \<SquadronName\>**
> Select a target (next step — not yet implemented).

---

## 8. Logging

### AS-LOG-001 — Logger context

All attack simulator log messages use the `"AttackSim"` logger context:

```gdscript
var _log: GameLogger = GameLogger.new("AttackSim")
```

### AS-LOG-002 — Key events to log

| Event | Level | Example |
|-------|-------|---------|
| Simulator activated | `info` | `"Attack simulator activated."` |
| Simulator cancelled | `info` | `"Attack simulator cancelled."` |
| Hull zone selected | `info` | `"Attacker selected: CR90 Corvette A — FRONT arc."` |
| Squadron selected | `info` | `"Attacker selected: X-wing Alpha."` |
| Click ignored (enemy token) | `debug` | `"Click on enemy token ignored."` |
| Hull zone determined | `debug` | `"Click at (123, 456) → FRONT hull zone."` |

---

## 9. Reuse of Existing Functions

| Existing Function | Used For |
|-------------------|----------|
| `ShipToken.get_firing_arc_world_points()` | Boundary line start/end directions |
| `ShipToken.get_los_origins_world()` | LOS marker position |
| `RangeOverlayScene.setup(token)` | Range overlay display |
| `GameScale.range_close_px` | Squadron close-range circle radius |
| `RangeFinder.get_hull_zone_edge(...)` | Hull zone geometry |
| `TargetingListBuilder.ShipInfo` / `SquadInfo` | (Future steps) |

---

## 10. Acceptance Criteria

| ID | Criterion |
|----|-----------|
| AC-AS-01 | Pressing "A" (button or key) opens the attack simulator info panel. |
| AC-AS-02 | Info panel shows "Select a hull zone or squadron as the attacker." |
| AC-AS-03 | Clicking a friendly ship hull zone selects it as the attacker. |
| AC-AS-04 | Clicking an enemy token is ignored during selection. |
| AC-AS-05 | Once a hull zone is selected, the ship's range overlay appears. |
| AC-AS-06 | Two white lines extend the firing arc boundaries to the map edge. |
| AC-AS-07 | A 6 px yellow circle marks the LOS targeting point. |
| AC-AS-08 | Info panel updates to show the selected attacker identity. |
| AC-AS-09 | Pressing Escape cancels the simulator and removes all visuals. |
| AC-AS-10 | Pressing "A" again cancels the simulator (toggle). |
| AC-AS-11 | Clicking a friendly squadron selects it as the attacker. |
| AC-AS-12 | Once a squadron is selected, a close-range circle is drawn. |
| AC-AS-13 | The "A" button is disabled during ship activation (same as M/R/T). |
| AC-AS-14 | All key events are logged with `"AttackSim"` context. |
| AC-AS-15 | Starting the attack simulator dismisses any active range overlay or targeting list. |
