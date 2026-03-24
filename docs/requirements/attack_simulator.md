# Attack Simulator — Requirements

> **Scope:** Phases 6a / 6a-2 — Attacker Declaration, Target Selection
> & LOS Visualization.
> Selection of the attacking hull zone / squadron, selection of the
> defending hull zone / squadron, and the LOS line between them.
> Dice rolling, defense tokens, and damage resolution remain in Phase 6
> proper.

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

The player directly clicks a hull zone on **any ship** (friendly or enemy) to
select it as the attacking hull zone.  The click is resolved by determining
which quadrant of the ship base the click position falls into
(FRONT / LEFT / RIGHT / REAR).

> Rationale: The Attack Simulator is an analysis tool.  Players need to
> evaluate potential attacks from the opponent's ships as well as their own.

> Implementation: Convert the click to the ship's local space and determine
> the hull zone from the ship's geometry (half-width, half-length, the four
> base quadrant regions).

### AS-SEL-002 — Both friendly and enemy ships respond

Clicks on **any** ship token (regardless of owner) during attacker selection
are accepted.  There is no faction filter.

### AS-SEL-003 — Hull zone feedback on hover (nice-to-have)

When hovering over a friendly ship, the hull zone under the cursor is
subtly highlighted (e.g. tinted or outlined).  This is optional for the
first implementation pass.

---

## 5. Attacker Selection — Squadron

### AS-SEL-010 — Click squadron token

Clicking **any** squadron token (friendly or enemy) selects it as the
attacker.  Squadrons have a 360° arc and attack at distance 1.

> Rules Reference: "Firing Arc" — "Each squadron has a 360° firing arc."
> Rules Reference: "Attack Range" — "Each squadron's attack range is distance 1."

### AS-SEL-011 — Both friendly and enemy squadrons respond

Clicks on **any** squadron token during attacker selection are accepted.
There is no faction filter.

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
> Select a target.

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
> Select a target.

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
| AC-AS-03 | Clicking any ship hull zone (friendly or enemy) selects it as the attacker. |
| AC-AS-04 | ~~removed~~ — no faction filter; both friendly and enemy tokens are selectable. |
| AC-AS-05 | Once a hull zone is selected, the ship's range overlay appears. |
| AC-AS-06 | Two white lines extend the firing arc boundaries to the map edge. |
| AC-AS-07 | A 6 px yellow circle marks the LOS targeting point. |
| AC-AS-08 | Info panel updates to show the selected attacker identity. |
| AC-AS-09 | Pressing Escape cancels the simulator and removes all visuals. |
| AC-AS-10 | Pressing "A" again cancels the simulator (toggle). |
| AC-AS-11 | Clicking any squadron (friendly or enemy) selects it as the attacker. |
| AC-AS-12 | Once a squadron is selected, a close-range circle is drawn. |

---

# Phase 6a-2 — Target Selection & LOS Visualization

---

## 11. Target Selection — Hull Zone

After the attacker is selected, the player selects a defending hull zone
or squadron.  The info panel prompts **"Select a target."**

### AS-TGT-001 — Click hull zone as target

The player clicks a hull zone on **any ship** (friendly or enemy) to
select it as the defending hull zone.  The hull zone is identified the
same way as for attacker selection (click position → quadrant detection).

> Rationale: Same analysis-tool argument as AS-SEL-001 — players need to
> evaluate LOS from either side.

### AS-TGT-002 — Both factions selectable as target

Clicks on **any** ship token (regardless of owner) during target
selection are accepted.  There is no faction filter.

### AS-TGT-003 — Attacker cannot be its own target

If the player clicks the **same hull zone** that is currently the
attacker, both attacker and target are deselected (see AS-TGT-021).
A ship's other hull zones **can** be selected as the target (to
check LOS from one zone to another on the same ship).

---

## 12. Target Selection — Squadron

### AS-TGT-010 — Click squadron as target

Clicking **any** squadron token selects it as the defending squadron.

### AS-TGT-011 — Both factions selectable for squadron target

Clicks on **any** squadron token during target selection are accepted.
There is no faction filter.

### AS-TGT-012 — Attacker squadron cannot target itself

If the attacker is a squadron and the player clicks the **same**
squadron, both attacker and target are deselected (see AS-TGT-021).

---

## 13. Target Deselection

### AS-TGT-020 — Click target again to deselect target only

Re-clicking the currently selected **target** (same hull zone or same
squadron) deselects the target.  The attacker selection and its visual
aids remain active.  The simulator returns to the "Select a target"
prompt.

### AS-TGT-021 — Click attacker to deselect both

Clicking the currently selected **attacker** token (the same hull zone if
ship, or the same squadron) deselects **both** attacker and target.  All
visual aids are removed.  The simulator returns to the initial
"Select a hull zone or squadron as the attacker" prompt.

> This applies equally to ship hull zone attackers and squadron attackers.

### AS-TGT-022 — Escape still cancels everything

Pressing **Escape** at any point (attacker selected, target selected, or
both) fully cancels the attack simulator — same as AS-ACT-003.

---

## 14. Visual Aids — Target Selected

### AS-VIS-020 — LOS marker on target

Place a translucent yellow circle (6 px diameter) at the target's
line-of-sight point:

- **Ship hull zone target:** at `ShipToken.get_los_origins_world()[zone_key]`.
- **Squadron target:** at the squadron token's centre (`global_position`).

Colour, diameter, and opacity are identical to the attacker's LOS marker
(AS-VIS-003): `Color(1.0, 1.0, 0.0, 0.6)`, 6 px diameter.

### AS-VIS-021 — LOS line between attacker and target

When **both** attacker and target are selected, draw a line representing
the line-of-sight trace between them.

> Rules Reference: "Line of Sight", p.10.
> "To determine line of sight, a player uses the range ruler to trace a
> line between the attacking squadron or hull zone and the defending
> squadron or hull zone."

Line endpoints follow the Rules Reference:

| Attacker | Target | Attacker endpoint | Target endpoint |
|----------|--------|-------------------|-----------------|
| Ship HZ | Ship HZ | Attacking hull zone targeting point | Defending hull zone targeting point |
| Ship HZ | Squadron | Attacking hull zone targeting point | Closest point on squadron base circle to attacker's targeting point |
| Squadron | Ship HZ | Closest point on squadron base circle to defender's targeting point | Defending hull zone targeting point |
| Squadron | Squadron | Closest point on attacker base circle to defender's centre | Closest point on defender base circle to attacker's centre |

> Rules Reference: "When tracing line of sight to or from a squadron,
> trace the line using the point of the squadron's base that is closest
> to the opposing squadron or hull zone."
>
> Rules Reference: "When tracing line of sight to or from a hull zone,
> trace the line using the yellow targeting point printed in that hull zone."

- Line width: 2.0 px (anti-aliased) — slightly thicker than arc boundary
  lines (1.5 px) for visual distinction.

### AS-VIS-022 — LOS line colour-coded by result

The LOS line colour indicates the trace result from `LineOfSightChecker`:

| Status | Colour | Constant name |
|--------|--------|---------------|
| Clear | Yellow `Color(1.0, 1.0, 0.0, 0.8)` | `LOS_LINE_CLEAR` |
| Obstructed | Orange `Color(1.0, 0.6, 0.0, 0.8)` | `LOS_LINE_OBSTRUCTED` |
| Blocked | Red `Color(1.0, 0.0, 0.0, 0.6)` | `LOS_LINE_BLOCKED` |

> Rules Reference: "If line of sight or attack range is traced through a
> hull zone on the defender that is not the defending hull zone, the
> attacker does not have line of sight and must choose another target."
>
> Rules Reference: "If line of sight is traced through an obstacle token
> or through a ship that is not the attacker or defender, the attack is
> obstructed."

---

## 15. Info Panel — Target Phase

### AS-PNL-010 — "Select a target" prompt

After the attacker is selected (hull zone or squadron), the panel shows:

> **Attacking: \<ShipName\> — \<ZONE\> arc**
> Select a target.

or for a squadron attacker:

> **Attacking: \<SquadronName\>**
> Select a target.

(These replace the Phase 6a placeholder texts in AS-VIS-004 / AS-VIS-011.)

### AS-PNL-011 — Attacker → target + LOS result

Once **both** attacker and target are selected, the panel updates to:

> **\<AttackerName\> — \<ZONE\> → \<DefenderName\> — \<ZONE\>**
> LOS: Clear

or, for an obstructed/blocked result:

> **\<AttackerName\> — \<ZONE\> → \<DefenderName\> — \<ZONE\>**
> LOS: Obstructed by \<EntityName\>

> **\<AttackerName\> — \<ZONE\> → \<DefenderName\> — \<ZONE\>**
> LOS: Blocked

When one or both endpoints are squadrons, drop the "— \<ZONE\>" part.

---

## 16. Logging — Target Phase

### AS-LOG-010 — Target selection events

| Event | Level | Example |
|-------|-------|---------|
| Target hull zone selected | `info` | `"Target selected: VSD — LEFT arc."` |
| Target squadron selected | `info` | `"Target selected: TIE Fighter Alpha."` |
| Target deselected | `info` | `"Target deselected."` |
| Both deselected (attacker click) | `info` | `"Attacker re-clicked — both deselected."` |
| LOS result | `info` | `"LOS: Clear."` / `"LOS: Obstructed by CR90."` / `"LOS: Blocked."` |

---

## 17. Reuse of Existing Functions — Target Phase

| Existing Function | Used For |
|-------------------|----------|
| `ShipToken.get_hull_zone_at(world_pos)` | Determine defending hull zone from click |
| `ShipToken.get_los_origins_world()` | Target LOS marker position |
| `SquadronToken.get_radius_px()` | Closest-point calculation for squadron LOS |
| `RangeFinder.closest_point_on_circle()` | LOS line endpoint for squadron |
| `RangeFinder.get_hull_zone_edge()` | Hull zone geometry for LOS blocking check |
| `LineOfSightChecker.trace_los_ship_to_ship()` | Ship → Ship LOS trace |
| `LineOfSightChecker.trace_los_ship_to_squadron()` | Ship → Squadron LOS trace |
| `LineOfSightChecker.trace_los_squad_to_ship()` | Squadron → Ship LOS trace |

---

## 18. Acceptance Criteria — Target Phase

| ID | Criterion |
|----|-----------|
| AC-AS-20 | After attacker selected, panel shows "Select a target." |
| AC-AS-21 | Clicking any ship hull zone selects it as the target. |
| AC-AS-22 | Clicking any squadron selects it as the target. |
| AC-AS-23 | A 6 px yellow circle marks the target's LOS point. |
| AC-AS-24 | A yellow/orange/red LOS line connects attacker and target. |
| AC-AS-25 | LOS line is yellow when clear, orange when obstructed, red when blocked. |
| AC-AS-26 | Panel shows attacker → target identity + LOS result text. |
| AC-AS-27 | Re-clicking the target deselects it; attacker visuals remain. |
| AC-AS-28 | Clicking the attacker deselects both; returns to initial prompt. |
| AC-AS-29 | Escape cancels everything at any point. |
| AC-AS-30 | LOS line endpoints follow the Rules Reference (targeting points / closest base point). |
| AC-AS-13 | The "A" button is disabled during ship activation (same as M/R/T). |
| AC-AS-14 | All key events are logged with `"AttackSim"` context. |
| AC-AS-15 | Starting the attack simulator dismisses any active range overlay or targeting list. |
