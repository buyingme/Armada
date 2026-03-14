# Manual Test Plan — Star Wars: Armada Digital Edition

> **Scope:** Phases 0–2b. Updated after each phase completes.
> **How to run a scene:** Godot Editor → double-click the `.tscn` → press **F6** (Run Current Scene).
> **Automated gate:** Always run `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -10` and confirm 0 failures **before** doing manual tests.

---

## Phase 0 — Scale & Assets Foundation

**What this phase adds:** The `GameScale` autoload reads `scale_config.json` and exposes ruler-derived pixel values to the whole project. No visual output — these are data-only checks.

### MT-0.1 — Project opens without errors

| Step | Action | Expected |
|------|--------|----------|
| 1 | Open the project in the Godot editor | Output panel shows no red errors |
| 2 | Wait for import to finish | No "Failed to load" messages |

### MT-0.2 — Scale values load from config

| Step | Action | Expected |
|------|--------|----------|
| 1 | In the Godot editor, open **Script → Remote** (or use the built-in debugger) and run the project with an empty main scene, OR add a temporary `_ready()` that prints `GameScale.ruler_length_px` | Output shows `720.0` |
| 2 | Same for `GameScale.play_area_side_px` | Output shows `2160.0` (720 × 3) |
| 3 | Same for `GameScale.range_close_px` | Output shows `292.0` |
| 4 | Same for `GameScale.range_medium_px` | Output shows `442.0` |

> **Note:** The quickest way is to run the automated GUT suite — `test_game_scale.gd` covers all 28 derived values. MT-0.2 is only needed if the automated tests fail and you want to isolate which value is wrong.

**Pass criteria:** No editor errors; `ruler_length_px = 720.0`; `play_area_side_px = 2160.0`.

---

## Phase 1 — Core Geometry Engine

**What this phase adds:** Pure math classes (`ShipBase`, `FiringArc`, `RangeMeasurer`, `SquadronBase`, `ManeuverCalculator`). No scene, no visual output. Manual testing is limited to confirming the project still opens cleanly.

### MT-1.1 — No regressions after geometry engine added

| Step | Action | Expected |
|------|--------|----------|
| 1 | Open the Godot editor | No new red errors compared to Phase 0 |
| 2 | Run automated GUT suite | 274 tests, 0 failures |

**Pass criteria:** 274 passing tests; editor output panel clean.

---

## Phase 2 — Game Board & Token Display

**What this phase adds:** `GameBoard` scene (play area, camera, tokens). This is the first visually testable phase.

### Setup

Open `/Users/Katharina/godot/Armada/src/scenes/game_board/game_board.tscn` in the editor and press **F6** to run it.

---

### MT-2.1 — Play area renders correctly

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run the GameBoard scene | A dark navy-blue square fills the screen |
| 2 | Check the border | A thin lighter-blue border outlines the square |
| 3 | Check for console errors | Godot Output panel shows no red errors |

**Pass criteria:** Dark `#0D1224`-ish background with visible border, no errors.

---

### MT-2.2 — Correct number of tokens placed

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run the GameBoard scene | 5 tokens total appear on the board |
| 2 | Count ship-shaped tokens (rectangular base) | Exactly **3** |
| 3 | Count squadron tokens (circular base) | Exactly **2** |

**Pass criteria:** 3 ship tokens + 2 squadron tokens = 5 total.

---

### MT-2.3 — Imperial vs Rebel deployment zones

Rules Reference: "Learning Scenario Setup", step 9, p.5–6.

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run the GameBoard scene | The **Victory II** (large ship) is in the **top third** of the board |
| 2 | Check the TIE Fighter squadron | In the **top third** of the board, left of the Victory II |
| 3 | Check the CR90 Corvette and Nebulon-B | Both in the **bottom third** of the board |
| 4 | Check the X-wing squadron | In the **bottom third**, roughly centred |

**Pass criteria:** Imperial tokens in top zone (y < 40% of board height); Rebel tokens in bottom zone (y > 60% of board height).

---

### MT-2.4 — Faction colours on base outlines

| Step | Action | Expected |
|------|--------|----------|
| 1 | Zoom in on the Victory II base outline | Outline colour is **grey-green** (Imperial) |
| 2 | Zoom in on the CR90 or Nebulon-B base outline | Outline colour is **orange-gold** (Rebel) |
| 3 | Zoom in on the TIE Fighter token | Grey-green circle outline |
| 4 | Zoom in on the X-wing token | Orange-gold circle outline |

**Pass criteria:** Imperial = grey-green; Rebel = orange-gold. Colours match `IMPERIAL_COLOUR` and `REBEL_COLOUR` constants.

---

### MT-2.5 — Ship tokens face the correct direction

Rules Reference: Imperial ships face south (toward Rebel zone); Rebel ships face north.

| Step | Action | Expected |
|------|--------|----------|
| 1 | Check the Victory II and TIE Fighter | The **front** arc (narrower end or PNG orientation) faces **downward** (toward bottom of screen) |
| 2 | Check the CR90 and Nebulon-B | The front faces **upward** (toward top of screen) |

**Pass criteria:** Imperial facing down, Rebel facing up.

---

### MT-2.6 — Camera pan (right-click drag)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Hold **right mouse button** and drag left | Board pans to the right (world moves opposite to drag) |
| 2 | Drag to the right | Board pans to the left |
| 3 | Drag toward an edge of the play area | Camera stops before losing the play area completely (boundary clamping active) |
| 4 | Release right mouse button | Pan stops immediately |

**Pass criteria:** Smooth pan; camera cannot be dragged more than ~300 px beyond the play area border.

---

### MT-2.7 — Camera zoom (scroll wheel)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Scroll **up** | View zooms in; tokens appear larger |
| 2 | Scroll **down** | View zooms out; more of the board becomes visible |
| 3 | Keep scrolling out past the minimum | Zoom stops at `ZOOM_MIN = 0.20` — the full board remains visible at maximum zoom-out |
| 4 | Keep scrolling in past the maximum | Zoom stops at `ZOOM_MAX = 5.0` |

**Pass criteria:** Zoom works in both directions; clamps at min and max.

---

### MT-2.8 — Firing arc overlay toggle

Because Phase 2 has no UI button yet, use the Godot **Remote Debugger** or a temporary script to test this:

```gdscript
# Paste into the GameBoard script temporarily, run scene, press Space:
func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed:
        var ships := get_ship_tokens()
        if ships.size() > 0:
            EventBus.firing_arc_toggled.emit(ships[0])
```

| Step | Action | Expected |
|------|--------|----------|
| 1 | Add the temp input handler above and run the scene | First ship token visible |
| 2 | Press **Space** | Semi-transparent arc wedges appear around the first ship token |
| 3 | Press **Space** again | Wedges disappear |
| 4 | Verify arc colours | FRONT = blue, LEFT (port) = green, RIGHT (starboard) = yellow, REAR = red |

**Pass criteria:** Arcs toggle on/off; four coloured zones are clearly distinguishable.

> **Remove the temp input handler before committing.**

---

### MT-2.9 — Token PNG textures load (no placeholder)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run the GameBoard scene | Each token shows its actual ship/squadron card image, not a grey placeholder or missing-texture checkerboard |
| 2 | Check all 5 tokens | Victory II, TIE Fighter, CR90, Nebulon-B, X-wing — each unique image |

**Pass criteria:** All 5 tokens display their correct PNG textures with no missing-image errors in the Output panel.

> **If images are missing:** Check that the PNGs exist at the paths `AssetLoader` resolves from `Constants` (e.g. `res://Resources/Game_Components/ships/victory_ii_class_star_destroyer/victory_ii_class_star_destroyer_token.png`). The `AssetLoader.load_ship_token()` method returns `null` on failure and logs an error via `GameLogger`.

---

### MT-2.10 — Trackpad two-finger pan

macOS only. Requires a physical trackpad (Magic Trackpad or built-in).

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run the GameBoard scene | Board fills the screen at fit zoom |
| 2 | Place two fingers on the trackpad and **swipe left** | Board pans to the right (world moves with fingers) |
| 3 | **Swipe right** | Board pans to the left |
| 4 | **Swipe up** | Board pans downward |
| 5 | **Swipe down** | Board pans upward |
| 6 | Swipe toward an edge until clamped | Camera stops before losing the play area; further swiping has no effect |

**Pass criteria:** Smooth, responsive pan in all four directions; boundary clamping prevents leaving the play area.

---

### MT-2.11 — Trackpad pinch-to-zoom

macOS only. Requires a physical trackpad.

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run the GameBoard scene | Board at fit zoom |
| 2 | Place two fingers on a **token** and **pinch open** (spread fingers) | Board zooms in; the token stays approximately under your fingers |
| 3 | **Pinch closed** (bring fingers together) | Board zooms out; the point under fingers stays fixed |
| 4 | Note the zoom level visible in the Remote Debugger or by feel | Zoom changes incrementally — no single large jump |

**Pass criteria:** Smooth zoom; world point under fingers remains anchored; no jitter or sudden jumps.

---

### MT-2.12 — Trackpad pinch zoom clamps

macOS only.

| Step | Action | Expected |
|------|--------|----------|
| 1 | Zoom out fully with the scroll wheel, then continue with a pinch-close gesture | Zoom stops at `ZOOM_MIN = 0.20`; further pinching has no effect |
| 2 | Zoom in fully with the scroll wheel, then continue with a pinch-open gesture | Zoom stops at `ZOOM_MAX = 5.0`; further spreading has no effect |

**Pass criteria:** Pinch clamps at the same min/max as the scroll wheel.

---

## Phase 2b — Debug Token Placement

**What this phase adds:** Debug mode (F12 toggle) with interactive token drag, rotation, collision prevention, deployment zone lines, and position saving (Ctrl+S).

### Setup

Open `/Users/Katharina/godot/Armada/src/scenes/game_board/game_board.tscn` in the editor and press **F6** to run it.

---

### MT-2b.1 — Debug mode toggle (F12)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run the GameBoard scene | No "DEBUG" label visible; tokens are non-interactive |
| 2 | Press **F12** | Red "DEBUG" label appears in the top-left corner of the screen |
| 3 | Two thin blue horizontal lines appear across the board | Lines are at deployment zone boundaries (roughly 1/5 from top and bottom) |
| 4 | Press **F12** again | "DEBUG" label and blue lines disappear |

**Pass criteria:** F12 toggles debug mode on/off; HUD label and deployment zone overlay visibility toggle together.

---

### MT-2b.2 — Token selection and deselection

| Step | Action | Expected |
|------|--------|----------|
| 1 | Enable debug mode (F12) | "DEBUG" label visible |
| 2 | Left-click a ship token | Token becomes selected (it starts following the mouse) |
| 3 | Move the mouse | Selected token follows the mouse cursor in real time |
| 4 | Left-click the same token again | Token is deselected; stops following the mouse |
| 5 | Left-click a squadron token | Squadron follows the mouse |
| 6 | Left-click empty space | Token is deselected |

**Pass criteria:** Single-click selects/deselects; selected token follows cursor; clicking empty space deselects.

---

### MT-2b.3 — Token rotation (trackpad magnify gesture)

macOS only — requires Magic Trackpad or built-in trackpad.

| Step | Action | Expected |
|------|--------|----------|
| 1 | Enable debug mode and select a ship token | Ship follows cursor |
| 2 | Perform a two-finger **magnify gesture** (spread apart) | Ship rotates clockwise |
| 3 | Perform the reverse (pinch together) | Ship rotates counter-clockwise |
| 4 | Check that the base outline rotates with the ship art | Both rotate together |

**Pass criteria:** Magnify gesture rotates the selected token smoothly around its centre.

---

### MT-2b.4 — Collision slide-to-contact

| Step | Action | Expected |
|------|--------|----------|
| 1 | Enable debug mode and select a ship token | Ship follows cursor |
| 2 | Drag it directly toward another token | The dragged token stops just before overlapping — it "slides to contact" |
| 3 | Continue dragging past the blocker | Once the cursor is far enough past the blocker, the token **jumps past** to the far side and resumes following |
| 4 | Repeat with a squadron token | Same slide-to-contact and jump-past behaviour |

**Pass criteria:** Tokens never overlap; slide-to-contact is smooth; jump-past works when target position is clear.

---

### MT-2b.5 — Deployment zone boundary enforcement

| Step | Action | Expected |
|------|--------|----------|
| 1 | Enable debug mode | Blue deployment zone lines visible |
| 2 | Select an **Imperial** token (Victory II or TIE Fighter) | Follows cursor |
| 3 | Drag it downward past the **top blue line** | Token stops at the blue line boundary — cannot cross it |
| 4 | Select a **Rebel** token (CR90 or X-wing) | Follows cursor |
| 5 | Drag it upward past the **bottom blue line** | Token stops at the blue line boundary — cannot cross it |

**Pass criteria:** Faction tokens are confined to their deployment zone by the blue lines.

---

### MT-2b.6 — Save positions (Ctrl+S)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Enable debug mode and move several tokens to new positions | Tokens repositioned |
| 2 | Press **Ctrl+S** | Console shows "Token positions saved successfully" |
| 3 | Close the scene and re-run it | Tokens appear at the **new** saved positions |
| 4 | Open `Resources/Game_Components/scenarios/learning_scenario.json` | `pos_x`, `pos_y`, `rotation_deg` values reflect the moved positions |

**Pass criteria:** Positions persist in JSON; reloading the scene restores them.

---

### MT-2b.7 — Camera controls unaffected by debug mode

| Step | Action | Expected |
|------|--------|----------|
| 1 | Enable debug mode (F12) | "DEBUG" visible |
| 2 | **Right-click drag** | Camera pans normally — no interference from debug mode |
| 3 | **Scroll wheel** | Zoom works normally |
| 4 | (macOS) Two-finger swipe | Pan works normally |
| 5 | Select a token, then right-click drag | Camera pans — token does **not** move from right-click |

**Pass criteria:** Camera controls (right-click pan, scroll/pinch zoom) work identically whether debug mode is on or off.

---

## Regression Checklist

Run this quick checklist any time you merge changes that touch Phase 0–2b files:

- [ ] `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -10` → **360 tests, 0 failures**
- [ ] Open Godot editor → no red errors in Output panel
- [ ] Run `game_board.tscn` → all 13 tokens appear in correct deployment zones
- [ ] Right-click drag → board pans; boundary clamping works
- [ ] Scroll wheel → zoom in/out; clamps at min/max
- [ ] (macOS) Two-finger swipe on trackpad → board pans smoothly; clamping works
- [ ] (macOS) Pinch gesture on trackpad → zooms in/out keeping world point under fingers; clamps at min/max
- [ ] F12 → "DEBUG" label + blue deployment lines appear; F12 again → disappear
- [ ] Click token in debug mode → follows mouse; click again → deselects
- [ ] Drag token into another → slide-to-contact; cursor past → jump-past
- [ ] Drag faction token past deployment line → stops at boundary
- [ ] Ctrl+S in debug mode → positions saved; reload confirms

---

*Last updated: Phase 2b — debug token placement, 360 tests passing.*
