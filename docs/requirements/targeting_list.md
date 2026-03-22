# Targeting List — Requirements

> **Scope:** Range-finding algorithm, firing-arc test, line-of-sight algorithm,
> obstruction detection, targeting list modal UI.
> Covers ship-to-ship and ship-to-squadron targeting for the active player's
> fleet. Prepared for obstacle obstruction (future) via an extensible interface.

## 1. Overview

The **targeting list** is a read-only information panel showing all valid
attack opportunities for the active player's ships. For each friendly ship it
lists:

1. **Outgoing targets** — every enemy ship/squadron within firing arc and
   attack range of each hull zone, with range band, dice available, and
   obstruction status.
2. **Incoming threats** — every enemy ship that has the friendly ship inside
   one of its firing arcs and at attack range, with range band and
   obstruction status.

The list is opened via a toolbar button labelled **"T"** and displayed as a
dismissible modal panel. It is a **static snapshot** computed once on open.

When a maneuver tool ghost is visible, the list also includes a hypothetical
section showing targeting from/to the ghost's projected position.

**Rules Reference:**
- RRG "Attack", Step 1, p.2
- RRG "Attack Range", p.3
- RRG "Firing Arc", p.8
- RRG "Line of Sight", p.10
- RRG "Measuring Firing Arc and Range", p.10
- RRG "Obstructed", p.13
- RRG "Range and Distance", p.14

---

## 2. Glossary

| Term | Definition | Source |
|------|-----------|--------|
| Firing arc | The infinite sector between two adjacent firing-arc lines printed on a ship token. Includes the line widths. | RRG "Firing Arc" |
| Attack range | Range measured from the closest point of the attacking hull zone to the closest point of the defending hull zone (or squadron base), ignoring any defender portion outside the attacker's firing arc. | RRG "Measuring Firing Arc and Range" |
| Range band | Close, medium, or long as determined by ruler markings. Beyond = outside all three bands. | RRG "Range and Distance" |
| Line of sight (LOS) | A line traced between the attacking hull zone's yellow targeting point and the defending hull zone's targeting point (or closest point of a squadron base). | RRG "Line of Sight" |
| Obstruction | An attack is obstructed if LOS passes through an obstacle token or a ship that is neither the attacker nor defender. Squadrons never obstruct. | RRG "Obstructed" |
| Maximum attack range | Close if only black dice; medium if ≥1 blue die; long if ≥1 red die. | RRG "Attack Range" |

---

## 3. Range-Finding Algorithm

### TL-RNG-001 — Attack range measurement (ship → ship)

Measure attack range **from** the closest point on the attacking hull zone's
edge **to** the closest point on the defending hull zone's edge **that lies
inside the attacker's firing arc**.

This measurement depends on the arc containment test (TL-ARC-006 step 1)
having already identified which portion of the defending hull zone is within
the arc. Only those within-arc edge points participate in the closest-point
computation. Portions of the defender outside the arc are ignored, even if
geometrically closer.

> RRG "Measuring Firing Arc and Range":
> "To measure attack range from a ship, measure from the closest point of the
> attacking hull zone. To measure attack range to a ship, measure to the
> closest point of the defending hull zone."
> "When measuring attack range for a ship, ignore any portion of the defender
> that is outside the attacking hull zone's firing arc, even if that portion
> is at a closer range."

### TL-RNG-002 — Attack range measurement (ship → squadron)

Measure from the closest point on the attacking hull zone's edge to the
closest point on the squadron's circular base, considering only the portion of
the squadron base inside the firing arc.

> RRG "Measuring Firing Arc and Range":
> "To measure attack range to or from a squadron, measure to or from the
> closest point of the squadron's base."

### TL-RNG-003 — Attack range measurement (squadron → ship)

Squadrons have a 360° firing arc and attack at **distance 1** (close range).
Measure from the closest point on the squadron's base to the closest point on
the nearest defending hull zone.

> RRG "Attack Range": "Each squadron's attack range is distance 1."
> RRG "Firing Arc": "Each squadron has a 360° firing arc."

### TL-RNG-004 — Maximum attack range per hull zone

A hull zone's maximum attack range is:
- **Close** if its battery armament contains only black dice.
- **Medium** if it contains at least one blue die.
- **Long** if it contains at least one red die.

A target beyond the maximum attack range of a hull zone is **not attackable**
from that hull zone. Do not list it.

> RRG "Attack Range", bullet 1.

### TL-RNG-005 — Maximum attack range per squadron

A squadron's attack range against ships is determined by its
`battery_armament` (same rule as TL-RNG-004). Against other squadrons, its
range is determined by `anti_squadron_armament`.

Note: In the core game, all squadron attacks are distance 1 (close range).
The dice determine damage, not range. For targeting-list purposes, a squadron
can target any enemy at distance 1.

### TL-RNG-006 — Range band classification

Given a pixel distance, classify into close / medium / long / beyond using
the existing `GameScale.get_range_band()` function and the thresholds from
`scale_config.json`.

---

## 4. Firing-Arc Test

### TL-ARC-001 — Point-in-arc test (convex sector)

Given the four firing-arc boundary lines of a ship (8 points: inner + outer
per boundary), determine whether a world-space point lies inside a given
hull zone's firing arc. The firing arc is the infinite sector between the
two boundary lines that border that hull zone.

- **FRONT** arc: between the front-left and front-right boundary lines,
  extending forward from the ship.
- **LEFT** arc: between the front-left and rear-left boundary lines,
  extending to the left.
- **RIGHT** arc: between the front-right and rear-right boundary lines,
  extending to the right.
- **REAR** arc: between the rear-left and rear-right boundary lines,
  extending rearward.

> RRG "Firing Arc": "Firing arcs are infinite; they do not end at the end of
> the range ruler."

### TL-ARC-002 — Arc boundary inclusion

A firing arc includes the width of its boundary lines. For digital
implementation: a point exactly on a boundary line is considered inside
**both** adjacent arcs.

> RRG "Firing Arc", bullet 2.

### TL-ARC-003 — Defender portion in arc

When testing whether a defending hull zone is "inside the firing arc", check
whether **any** portion of the defending hull zone's edge falls inside the
arc. For practical purposes: sample representative edge points along the
defending hull zone's edge (at minimum: the two hull-zone edge endpoints —
i.e. the base corners where the hull zone's boundary lines meet the base
perimeter — plus several intermediate points along the edge).

**Note:** Targeting points (yellow dots) are **not** used for the arc or
range test. They are exclusively for line-of-sight traces (§ 5).

> RRG "Measuring Firing Arc and Range": "If a portion of any component is
> inside the area between those extended firing arc lines, that component is
> inside the firing arc."
> RRG "Measuring Firing Arc and Range", bullet 5: "Targeting points are not
> used when measuring range; they are exclusively for determining line of
> sight."

### TL-ARC-004 — Squadron in-arc test

For squadron targets, check whether any portion of the squadron's circular
base is inside the firing arc. Practically: test the circle centre plus points
at 0°, 90°, 180°, 270° on the circle edge.

### TL-ARC-006 — Two-step targeting process (arc then range)

Determining whether a hull zone can target a defending hull zone is a
sequential two-step process:

1. **Arc containment test:** Extend the firing arc boundary lines (they are
   infinite rays) outward from the attacking ship. Check if **any** portion
   of the defending hull zone's edge falls within the resulting arc sector
   (TL-ARC-001, TL-ARC-003). If no portion is inside the arc, the hull
   zone **cannot target** that defending hull zone — stop.
2. **Range measurement (within arc only):** Of the defender's hull-zone edge
   points that lie **inside** the arc, find the one closest to the attacking
   hull zone's edge. This closest-within-arc distance is the attack range
   (TL-RNG-001). Any portion of the defender outside the arc is ignored for
   range, even if geometrically closer.

Both conditions must be satisfied: the defending hull zone must be inside the
firing arc **and** at attack range of the attacking hull zone.

> RRG "Attack", Step 1: "the defending squadron or hull zone must be inside
> the attacking hull zone's firing arc **and** at attack range of the
> attacking hull zone."
> RRG "Measuring Firing Arc and Range": "When measuring attack range for a
> ship, ignore any portion of the defender that is outside the attacking hull
> zone's firing arc, even if that portion is at a closer range."

### TL-ARC-005 — Hull-zone edge geometry

Each hull zone's edge is the segment of the ship base perimeter that lies
between the two boundary lines bordering that hull zone.

The hull zone edge approximation for closest-point calculations:
- For **rectanglular bases**: the hull zone edge is one side of the base
  rectangle (front edge, left edge, right edge, rear edge).
- The edges do **not** include the plastic frame or shield dials.

> RRG "Hull Zones": "A hull zone is a section of a ship token delineated by
> the two firing arc lines that border it. It does **not** include any part of
> the plastic base."
> RRG "Measuring Firing Arc and Range", bullet 4: "ignore … ships' shield
> dials and the plastic portions of the base."

---

## 5. Line-of-Sight Algorithm

### TL-LOS-001 — LOS between two ship hull zones

Trace a line from the **targeting point** (yellow dot) of the attacking hull
zone to the **targeting point** of the defending hull zone.

> RRG "Line of Sight": "When tracing line of sight to or from a hull zone,
> trace the line using the yellow targeting point printed in that hull zone."

### TL-LOS-002 — LOS from ship hull zone to squadron

Trace from the attacking hull zone's targeting point to the **closest point**
on the squadron's base.

> RRG "Line of Sight": "When tracing line of sight to or from a squadron,
> trace the line using the point of the squadron's base that is closest to the
> opposing squadron or hull zone."

### TL-LOS-003 — LOS from squadron to ship hull zone

Trace from the **closest point** on the squadron's base (closest to the
defending hull zone's targeting point) to that targeting point.

### TL-LOS-004 — LOS / range path blocked by defender's other hull zones

If the **LOS line** or the **attack range measurement path** passes through a
hull zone on the defender that is **not** the declared defending hull zone, the
attacker does not have LOS. This target is **not listed**.

This means two checks:
1. The LOS segment (targeting point → targeting point) must not enter the
   defender's base through a different hull zone's edge.
2. The range segment (closest attacker edge point → closest defender edge
   point within arc) must not pass through a different hull zone's edge on
   the defender.

If either path crosses a non-defending hull zone, there is no LOS.

> RRG "Line of Sight", bullet 4: "If line of sight **or attack range** is
> traced through a hull zone on the defender that is not the defending hull
> zone, the attacker does not have line of sight."

Implementation: check whether each segment intersects the base rectangle of
the defender at a point that belongs to a different hull zone than the declared
defending zone. Since ship bases are rectangular and hull zones correspond to
base sides, check if either segment enters the defender's base through a
different edge than the defending hull zone's edge.

### TL-LOS-005 — LOS blocked / obstructed by intervening ships

If LOS passes through a ship that is **neither** the attacker nor the
defender, the attack is **obstructed** (not blocked — it can still happen,
but one die is removed).

> RRG "Line of Sight", bullet 5: "If line of sight is traced through … a ship
> that is not the attacker or defender, the attack is obstructed."

Implementation: for each other ship on the board, check whether the LOS
segment intersects that ship's oriented bounding rectangle (the base).

### TL-LOS-006 — Squadrons never obstruct

Squadrons do not block or obstruct line of sight. Ignore all squadron tokens
when tracing LOS.

> RRG "Line of Sight", bullet 8.

### TL-LOS-007 — Attacker's other hull zones do not block

The attacker's own hull zones do not block its own LOS.

> RRG "Line of Sight", bullet 9.

### TL-LOS-008 — Obstacle obstruction (future-ready interface)

Design the LOS check to accept an array of **obstruction bodies** (each
defined by a convex polygon or a transform + half-extents). At present this
array is empty (Learning Scenario has no obstacles). When obstacles are added,
each obstacle token's collision shape will be passed in.

> RRG "Line of Sight", bullet 5: "If line of sight is traced through an
> obstacle token … the attack is obstructed."
> RRG "Obstructed": "An attack is obstructed if line of sight is traced through
> an obstacle token or another ship that is not the defender."

### TL-LOS-009 — Shield dial and plastic frame ignored

When testing LOS intersection with ship bases, ignore shield dials and the
plastic frame. Use the printed ship token rectangle only.

> RRG "Line of Sight", bullet 5 sub-bullet 1.

---

## 6. Targeting List Content

### TL-LIST-001 — Per friendly ship: outgoing targets

For each friendly ship (belonging to the active player), for each hull zone:
1. Determine all enemy ships/squadrons that have **any portion** inside the
   hull zone's firing arc (TL-ARC-001 / TL-ARC-003 / TL-ARC-004).
2. Measure attack range to each candidate (TL-RNG-001 / TL-RNG-002).
3. Filter by maximum attack range of the hull zone (TL-RNG-004).
4. Check LOS (TL-LOS-001 / TL-LOS-002). Exclude if blocked (TL-LOS-004).
5. Check obstruction (TL-LOS-005 / TL-LOS-008).
6. List each valid target with: range band, arc name, dice summary,
   obstruction flag.

### TL-LIST-002 — Per friendly ship: incoming threats

For each enemy ship, for each of its hull zones:
1. Check whether the friendly ship has any portion inside that enemy hull
   zone's firing arc.
2. Measure attack range from the enemy hull zone to the friendly ship.
3. Filter by maximum attack range.
4. Check LOS and obstruction.
5. List each valid threat with: enemy ship name, arc name, range band,
   obstruction flag.

### TL-LIST-003 — Dice summary format

Show the dice colours and counts available at the measured range band.
Dice selection follows the range ruler icons:
- At **close** range: all dice (black + blue + red).
- At **medium** range: blue + red dice only (no black).
- At **long** range: red dice only.

Format example: `"2 red, 1 blue"` or `"3 black, 1 blue"`.

> RRG "Attack", Step 2: "Gather only the dice that are appropriate for the
> range of the attack as indicated by the icons on the range ruler."

### TL-LIST-004 — Ghost hypothetical section

When a maneuver tool ghost preview is visible, include an additional
**"Projected position"** section at the end of the list. This section shows
outgoing targets and incoming threats for the ghost's ship **as if** it were
at the ghost's world position and rotation, using the same ship data.

Label this section clearly (e.g. italic or header: *"Projected position
(after maneuver)"*).

### TL-LIST-005 — Empty states

- If a friendly ship has no valid outgoing targets: show
  `"— No targets in range —"`.
- If a friendly ship has no incoming threats: show
  `"— No incoming threats —"`.
- If the ghost section yields no results: show
  `"— No targets or threats at projected position —"`.

### TL-LIST-006 — Outgoing target line format

Each line for one arc's target reads:

> `<EnemyName> at <range> range of <ARC> arc (<dice>) [— obstructed]`

Example:
> `Victory I at medium range of FRONT arc (2 red, 1 blue) — obstructed`

Group by hull zone; one line per target per arc. If a target is in multiple
arcs, it appears once per arc.

### TL-LIST-007 — Incoming threat line format

Each line reads:

> `<FriendlyName> is at <range> range of <EnemyName>'s <ARC> arc [— obstructed]`

Example:
> `CR90 Corvette A is at close range of Victory I's FRONT arc — obstructed`

### TL-RNG-007 — Anti-squadron armament for ship → squadron targeting

When listing outgoing ship → squadron targets, use the ship's
**anti-squadron armament** (a single global value) instead of the hull zone's
battery armament. The anti-squadron armament determines both:
- The **dice** shown in the targeting entry.
- The **maximum attack range** (close-only if all black; medium if ≥1 blue;
  long if ≥1 red).

The firing arc and range measurement rules are unchanged — the squadron must
still be inside the attacking hull zone's arc and at attack range.

> Rules Reference: "Armament", bullet 3:
> "A ship has one anti-squadron armament that is used regardless of which
> hull zone is attacking."
> Rules Reference: "Attack", Step 2:
> "If the defender is a squadron, gather the attack dice indicated in the
> attacker's anti-squadron armament."

### TL-LIST-008 — Incoming squadron threats

For each friendly ship, also list **incoming threats from enemy squadrons**.
An enemy squadron threatens a friendly ship if:
1. The squadron is at **distance 1** (close range) of the friendly ship.
2. The squadron has a non-empty `battery_armament`.

Distance is measured from the closest point of the squadron's base to the
closest point of the ship's base (any hull zone). Each threat entry shows:
squadron name, range band (always "close" at distance 1), and dice from the
squadron's `battery_armament` at that range.

LOS is not checked for squadron → ship threats (squadrons cannot obstruct,
and no intervening hull zone check applies to squadron attackers).

> Rules Reference: "Attack", Step 1:
> "If the attacker is a squadron, the defending squadron or hull zone must be
> at distance 1."
> Rules Reference: "Firing Arc":
> "Each squadron has a 360° firing arc."

### TL-LIST-010 — SquadInfo carries armament data

The `SquadInfo` data structure must include `battery_armament` and
`anti_squadron_armament` fields so the builder can determine squadron dice
and range. The `_collect_squad_infos()` function in the game board must
populate these from the squadron's JSON data.

---

## 7. UI Modal

### TL-UI-001 — "T" button in ActionToolbar

Add a button labelled **"T"** (for Targeting) to the `ActionToolbar`, next to
the existing "M" and "R" buttons.

- Emits `EventBus.targeting_list_requested` when pressed.
- Disabled during ship activation (same conditions as M and R).
- Styled consistently with M and R buttons.

### TL-UI-002 — Modal panel

The targeting list is displayed as a `PanelContainer` modal following the
project's standard modal styling (`.skills/ui_styling.md`).

- Anchored at screen centre or right side (non-blocking view of the board).
- Scrollable if content exceeds viewport height.
- Contains a `RichTextLabel` or `VBoxContainer` with formatted text.

### TL-UI-003 — Dismissal

The modal is dismissed by:
- Pressing Escape.
- Pressing the "T" button again (toggle).

### TL-UI-003a — Keyboard shortcut (T key)
Pressing the **T** key on the keyboard triggers the same action as clicking
the "T" button. When the modal is visible, pressing **T** again closes it
(toggle). The shortcut is available whenever the toolbar buttons are not
disabled.

### TL-UI-004 — Snapshot semantics

The list is computed once when the modal opens. It does **not** live-update.
Closing and reopening recomputes.

### TL-UI-005 — Section headers

The modal uses clear section headers:
- **Bold ship name** as header per friendly ship.
- Sub-header `"Outgoing targets:"` and `"Incoming threats:"` per ship.
- Optional `"Projected position (after maneuver):"` if ghost is active.

### TL-UI-006 — Colour coding (optional, nice-to-have)

- Close range: grey text.
- Medium range: blue text.
- Long range: red text.
- Obstructed: append `"— obstructed"` in orange.

---

## 8. Core Algorithm Classes

### TL-ALGO-001 — `RangeFinder` (RefCounted)

Pure-logic class in `src/core/` responsible for:
- Closest-point-on-hull-zone-edge computation.
- Closest-point-on-squadron-base computation.
- Range measurement between hull zones, and between hull zone and squadron.
- Firing-arc-contains-point test.
- Maximum attack range from armament data.

No scene-tree dependency.

### TL-ALGO-002 — `LineOfSightChecker` (RefCounted)

Pure-logic class in `src/core/` responsible for:
- Segment-vs-oriented-rectangle intersection test.
- Segment-vs-convex-polygon intersection test (for future obstacles).
- LOS trace between two targeting points, returning: `{has_los: bool,
  obstructed: bool, obstructed_by: Array[String]}`.
- Accepts an array of obstruction bodies (ships + future obstacles).

No scene-tree dependency.

### TL-ALGO-003 — `TargetingListBuilder` (RefCounted)

Orchestrator class in `src/core/` that:
- Takes all ship tokens + squadron tokens + active player index.
- Uses `RangeFinder` and `LineOfSightChecker` to compute the full
  targeting list.
- Returns a structured result (array of per-ship entries with outgoing and
  incoming sub-arrays).
- Optional: accepts a ghost transform + ship data for the hypothetical
  section.

No scene-tree dependency (receives world positions as parameters).

---

## 9. Data Dependencies

### TL-DATA-001 — Firing arc boundary data

Already present in each ship JSON under `firing_arc_boundaries`. Eight
Vector2 points (inner + outer per boundary). Already parsed by `ShipData`
and convertible to world space via `ShipToken.get_firing_arc_world_points()`.

### TL-DATA-002 — Line-of-sight targeting points

Already present in each ship JSON under `line_of_sight_origins`. Four
Vector2 points (FRONT, LEFT, RIGHT, REAR). Already parsed by `ShipData`
and convertible via `ShipToken.get_los_origins_world()`.

### TL-DATA-003 — Battery armament data

Already present in each ship JSON under `battery_armament` (per hull zone,
per dice colour) and `anti_squadron_armament`. Already parsed by `ShipData`.

### TL-DATA-004 — Ship base geometry

Available via `ShipToken.get_half_width()` and `ShipToken.get_half_length()`.
Combined with `global_position` and `global_rotation`, this defines the
oriented base rectangle for LOS intersection tests.

### TL-DATA-005 — Squadron base geometry

Available via `SquadronToken.get_radius_px()` and `global_position`.
Circular base for range measurement and arc containment.

### TL-DATA-006 — Range thresholds

Available via `GameScale.range_close_px`, `GameScale.range_medium_px`,
`GameScale.range_long_px`, and `GameScale.get_range_band()`.

---

## 10. Acceptance Criteria

| ID | Criterion |
|----|-----------|
| AC-TL-01 | Pressing "T" opens a modal showing targeting info for all friendly ships. |
| AC-TL-02 | Each friendly ship section lists outgoing targets grouped by hull zone. |
| AC-TL-03 | Each outgoing target line shows: enemy name, range band, arc, dice summary. |
| AC-TL-04 | Obstructed targets are marked `"— obstructed"`. |
| AC-TL-05 | Incoming threats section lists enemy arcs that can target the friendly ship. |
| AC-TL-06 | Targets beyond the hull zone's maximum attack range are excluded. |
| AC-TL-07 | Targets without LOS (blocked by defender's other hull zone) are excluded. |
| AC-TL-08 | Intervening ships (not attacker/defender) cause obstruction flag. |
| AC-TL-09 | Squadrons are included as targets (ship → squadron) with correct range. |
| AC-TL-10 | Dice summary respects range-based filtering (no black at medium+, no blue at long). |
| AC-TL-11 | Ghost section appears when maneuver tool ghost is visible. |
| AC-TL-12 | Ghost section shows targeting from/to the projected ghost position. |
| AC-TL-13 | Modal dismissed by Escape or re-pressing "T". |
| AC-TL-14 | "T" button disabled during ship activation (same as M and R). |
| AC-TL-15 | `RangeFinder`, `LineOfSightChecker`, `TargetingListBuilder` extend `RefCounted` (no scene-tree dependency). |
| AC-TL-16 | `LineOfSightChecker` accepts an extensible array of obstruction bodies for future obstacle support. |
| AC-TL-17 | Empty states shown when no targets/threats exist. |
| AC-TL-18 | All core algorithm classes have unit tests (AAA pattern, descriptive names). |
| AC-TL-20 | Ship → squadron outgoing targets show anti-squadron armament dice, not battery armament. |
| AC-TL-21 | Ship → squadron max attack range is based on anti-squadron armament colours. |
| AC-TL-22 | Enemy squadrons at distance 1 of a friendly ship appear as incoming threats with battery armament dice. |
| AC-TL-23 | `SquadInfo` includes `battery_armament` and `anti_squadron_armament` fields populated from JSON data. |

---

## 11. Geometry Reference

### Hull zone edge as a line segment

For a ship at position `P`, rotation `θ`, half-width `hw`, half-length `hl`:

| Hull zone | Edge start (local) | Edge end (local) |
|-----------|--------------------|-------------------|
| FRONT | `(-hw, -hl)` | `(+hw, -hl)` |
| REAR | `(-hw, +hl)` | `(+hw, +hl)` |
| LEFT | `(-hw, -hl)` | `(-hw, +hl)` |
| RIGHT | `(+hw, -hl)` | `(+hw, +hl)` |

World coordinates: `P + local.rotated(θ)`

### Firing arc as a half-plane pair

Each firing arc is the intersection of two half-planes, each defined by a
boundary line (inner → outer direction). A point is inside the arc if it is
on the correct side of both boundary half-planes.

### LOS targeting points

Stored in `line_of_sight_origins` in PNG pixel space. Converted to world
space via `ShipToken.png_to_world()` or the equivalent calculation for the
ghost.
