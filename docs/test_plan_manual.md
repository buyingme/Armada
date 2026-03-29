# Manual Test Plan — Star Wars: Armada Digital Edition

> **Scope:** Phases 0–5d, 4g, 2c, L, 6a, 6a-4, 6b-1, 6b-3, 7b, 8, 9, plus post-Phase-L, post-Phase-4c, and post-Phase-5d LOS bug fixes (v1 + v2), plus AttackExecutor extraction refactoring. Updated after each phase completes.
> **How to run a scene:** Godot Editor → double-click the `.tscn` → press **F6** (Run Current Scene).
> **Automated gate:** Always run `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -10` and confirm 0 failures **before** doing manual tests.
> **Current baseline:** 84 scripts, 1564 tests — 1563 passing (1 pre-existing Nebulon-B placement failure).

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

## Phase 3 — Game State Wiring

**What this phase adds:** Runtime game state (`ShipInstance`, `SquadronInstance`, `DamageDeck`), shield/hull/speed value labels drawn on ship tokens, ship card panels on the sides of the board (Rebel left, Imperial right) with defense token sprite display, and EventBus-driven state↔visual sync.

### Setup

Run `scripts/run_board.sh` or open `game_board.tscn` and press **F6**.

---

### MT-3.1 — Shield values displayed on ship tokens ✅

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run the board scene and zoom in on the **CR90 Corvette** | Four white bold numbers visible near the edges of the token artwork |
| 2 | Check the **front** shield value (top edge area) | Shows **2** |
| 3 | Check the **left** shield value (left edge area) | Shows **2** |
| 4 | Check the **right** shield value (right edge area) | Shows **2** |
| 5 | Check the **rear** shield value (bottom edge area) | Shows **1** |

**Pass criteria:** All four shield values are visible, white, bold, correctly positioned, and show the right integers for the CR90 Corvette A.

---

### MT-3.2 — Hull and speed values displayed on ship tokens ✅

| Step | Action | Expected |
|------|--------|----------|
| 1 | Zoom in on the **CR90 Corvette** | Two numbers visible in the upper body of the token |
| 2 | Check the **hull** value (left side, upper area) | Shows **4** |
| 3 | Check the **speed** value (right side, upper area) | Shows **4** |
| 4 | Zoom in on the **Nebulon-B Escort Frigate** | Hull = **5**, Speed = **3** |
| 5 | Zoom in on the **Victory II Star Destroyer** | Hull = **8**, Speed = **2** |

**Pass criteria:** Hull and speed are integer values (no decimals), white, bold, positioned correctly per ship type.

---

### MT-3.3 — Labels render on top of token artwork ✅

| Step | Action | Expected |
|------|--------|----------|
| 1 | Zoom in closely on any ship token (zoom level 3–5×) | The white numbers are drawn **on top of** the ship token PNG, not behind it |
| 2 | Check that no numbers are obscured by the token artwork | All 6 values (4 shields, hull, speed) are legible |

**Pass criteria:** Labels are always in front of the token sprite, never hidden behind it.

---

### MT-3.4 — Ship card panels on sides of the board ✅

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run the board scene | A panel of ship cards appears on the **left** side of the viewport |
| 2 | Identify the left-panel cards | Shows Rebel ships: **CR90 Corvette A**, **Nebulon-B Escort Frigate** (with card artwork) |
| 3 | Look at the **right** side of the viewport | A panel of ship cards appears for Imperial ships |
| 4 | Identify the right-panel cards | Shows **Victory II Star Destroyer** (with card artwork) |
| 5 | Check that panels stay fixed when panning/zooming | Panels remain anchored to viewport edges, not the game board |
| 6 | Check Rebel panel alignment | Panel is flush to the **left** screen edge + top |
| 7 | Check Imperial panel alignment | Panel is flush to the **right** screen edge + top |

**Pass criteria:** Rebel ship cards on the left, Imperial ship cards on the right; panels are viewport-fixed (CanvasLayer) and do not scroll with the board.

---

### MT-3.5 — Defense tokens displayed on ship card panels ✅

| Step | Action | Expected |
|------|--------|----------|
| 1 | Look at the **CR90 Corvette A** entry on the left panel | A vertical column of defense token sprites appears **to the left** of the card image |
| 2 | Count and identify the tokens | **3 tokens**: Evade, Evade, Redirect (matching the ship card) |
| 3 | Check the **Victory II Star Destroyer** entry on the right panel | **3 tokens**: Brace, Redirect, Redirect |
| 4 | Check the **Nebulon-B Escort Frigate** entry on the left panel | **3 tokens**: Evade, Brace, Brace |
| 5 | Check token sprite appearance | Each shows the coloured "ready" state artwork |
| 6 | Check token vertical alignment | Tokens align to the **top** of the card, not centered |
| 7 | Zoom in on the ship tokens on the **board** itself | **No** defense token sprites on the board tokens |

**Pass criteria:** Correct number and type of defense tokens per ship on the card panels; all in "ready" state; tokens in a vertical column to the left of each card, top-aligned; no defense tokens on board tokens.

---

### MT-3.6 — Labels follow the ship when dragged ✅

| Step | Action | Expected |
|------|--------|----------|
| 1 | Enable debug mode (F12) | DEBUG label visible |
| 2 | Select and drag a ship token | Shield/hull/speed labels move with the token |
| 3 | Rotate the ship (magnify gesture on trackpad) | Labels rotate with the token |
| 4 | Check the ship card panel | The card panel entry is unchanged — it does not move or rotate |

**Pass criteria:** Value labels track the ship's position and rotation during debug-mode drag; card panels remain fixed on the viewport edge.

---

### MT-3.7 — Value labels on all ship types match card data ✅

Cross-reference each ship's displayed values against the card data JSON files. All values should be integers.

| Ship | Front Shield | Left Shield | Right Shield | Rear Shield | Hull | Speed |
|------|:---:|:---:|:---:|:---:|:---:|:---:|
| CR90 Corvette A | 2 | 2 | 2 | 1 | 4 | 4 |
| Nebulon-B Escort Frigate | 3 | 1 | 1 | 2 | 5 | 3 |
| Victory II Star Destroyer | 3 | 3 | 3 | 1 | 8 | 2 |

**Pass criteria:** Every value matches the table above with no decimal points.

---

### MT-3.8 — Map background still displays correctly ✅

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run the board scene | The space/planet map background is visible beneath all tokens |
| 2 | Check that value labels are legible against the map | White bold text is readable on the map background |

**Pass criteria:** Map loads; labels remain legible over the background art.

---

### MT-3.9 — Ship card magnify on left-click ✅

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run the board scene | Ship card panels visible on left and right sides |
| 2 | Left-click on a **CR90 Corvette A** card entry | The card and its defense tokens enlarge to **3×** normal size |
| 3 | Left-click on the same entry again | The card and tokens return to normal size |
| 4 | Left-click on the **Victory II** entry on the right panel | That entry magnifies independently; other entries stay normal |
| 5 | Check that defense tokens scale with the card | Token sprites grow/shrink proportionally with the card image |
| 6 | Zoom out from the **Victory II** entry | Entry returns to normal size and **stays right-aligned** to the screen edge |

**Pass criteria:** Each card entry toggles between normal and 3× magnified on click; only the clicked entry changes size; panel repositions correctly after resize on both left and right sides.

---

## Phase 4 — Command Phase

**What this phase adds:** Command dial stacks displayed below defense tokens in ship card panels, Command Dial Picker modal for assigning dials, Command Dial Order modal for reviewing own dials, command token display right of ship cards, and opponent viewing restrictions.

### Setup

Run `scripts/run_board.sh` or open `game_board.tscn` and press **F6**. The game must be in the Command Phase (round 1) for picker tests.

---

### MT-4.1 — Command dial stack displayed below defense tokens

| Step | Action | Expected |
|------|--------|----------|
| 1 | Complete Command Phase dial assignment for all ships | Dials appear below defense token columns in ship card panel entries |
| 2 | Check the **CR90 Corvette A** panel entry | **1** hidden dial (matching command value 1) below the token column |
| 3 | Check the **Nebulon-B Escort Frigate** panel entry | **2** hidden dials stacked vertically with ~20 px overlap offset |
| 4 | Check the **Victory II Star Destroyer** panel entry | **3** hidden dials stacked vertically with ~20 px overlap offset |
| 5 | Verify all hidden dials show facedown art | Every hidden dial displays `cmd_dial_hidden.png` (no command icon) |
| 6 | Verify dials stack downward | Dials overlap vertically, first dial at top |

**Pass criteria:** Dial count matches command value per ship; all hidden dials show facedown art; dials stack downward with visible overlap.

---

### MT-4.2 — Command Dial Picker modal opens and closes

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a new game (round 1, Command Phase) | Picker modal appears centred on screen for the first ship |
| 2 | Check selection area | 4 command icons in a row: Navigate, Squadron, Concentrate Fire, Repair |
| 3 | Check stack area | Empty (no dials assigned yet) |
| 4 | Check CONFIRM button | Greyed out / disabled |

**Pass criteria:** Modal is centred; icons in correct cycle order; CONFIRM disabled when stack is empty.

---

### MT-4.3 — Dial Picker selection mechanic

| Step | Action | Expected |
|------|--------|----------|
| 1 | Click the **Navigate** icon in the selection area | A Navigate dial appears in the stack area |
| 2 | Click the **Repair** icon in the selection area | A Repair dial appears below the Navigate dial |
| 3 | Click a dial in the stack area to remove it | The dial is removed; stack updates |
| 4 | Add dials in a different order | Stack reflects the order dials were added |

**Pass criteria:** Clicking adds dials to stack; dials can be removed by clicking them in the stack.

---

### MT-4.4 — Round 1 multi-dial assignment

| Step | Action | Expected |
|------|--------|----------|
| 1 | Open picker for **Victory II** (command value 3) in round 1 | Stack area is empty; CONFIRM disabled |
| 2 | Add 1 dial to the stack | CONFIRM still disabled (need 3 total) |
| 3 | Add 2 more dials to the stack (3 total) | CONFIRM becomes enabled |
| 4 | Click CONFIRM | Modal closes; dials assigned to ship |

**Pass criteria:** Round 1 requires exactly N dials (command value); CONFIRM only enables when all dials are placed.

---

### MT-4.5 — Rounds 2+ single-dial assignment

| Step | Action | Expected |
|------|--------|----------|
| 1 | Advance to round 2, enter Command Phase | Picker opens for a ship |
| 2 | Check the picker | Only 1 new dial slot available |
| 3 | Add 1 dial and click CONFIRM | Modal closes; new dial placed under existing stack |

**Pass criteria:** Rounds 2+ allow exactly 1 new dial; placed at bottom of existing stack.

---

### MT-4.6 — Command Dial Order modal (own dials)

| Step | Action | Expected |
|------|--------|----------|
| 1 | After dials are assigned, click on a **friendly** ship’s command dial stack in the side panel | Command Dial Order modal opens |
| 2 | Check the modal title | Shows “Command Dial Order — <ship name>” |
| 3 | Check the modal layout | Queued (hidden) dials displayed in a **horizontal row**, in stack order (leftmost = top = next to be revealed), each showing its **command icon** |
| 4 | Check below each dial | A **position label** (#1, #2, …) is displayed below each dial |
| 5 | Click anywhere on the modal | Modal closes |

**Pass criteria:** Modal shows all queued hidden dials in stack order with command icons and position labels; click dismisses.

---

### MT-4.7 — Opponent dial viewing restriction

| Step | Action | Expected |
|------|--------|----------|
| 1 | Click on the **opponent's** command dial stack in the side panel | **Nothing happens** — no modal opens |
| 2 | Check opponent's dial stack rendering | Dials show as hidden (`cmd_dial_hidden.png`) with no icon |

**Pass criteria:** Cannot inspect opponent's unrevealed dials; no dial order modal for opponent.

---

### MT-4.8 — Command tokens displayed right of ship card

| Step | Action | Expected |
|------|--------|----------|
| 1 | During Ship Phase, convert a revealed dial to a command token | A command token icon appears to the **right** of the ship card in the panel |
| 2 | Convert a second (different type) dial to a token | A second token appears in a vertical stack |
| 3 | Check token artwork | Uses `cmd_<type>.png` matching the command type |

**Pass criteria:** Command tokens display in a vertical stack to the right of the ship card; correct icons per type.

---

### MT-4.9 — Spent dial as activation marker

| Step | Action | Expected |
|------|--------|----------|
| 1 | During Ship Phase, activate a ship (reveal its top dial) | The hidden dial stack loses its top dial |
| 2 | After the ship finishes activation | A faceup (revealed) dial appears **below** the remaining hidden dials in the panel |
| 3 | Check the spent dial artwork | Shows `cmd_dial_hidden.png` + `cmd_<type>.png` icon composite (revealed state) |

**Pass criteria:** Spent dial renders below hidden stack as an activation marker; shows the revealed command icon.

---

### MT-4.10 — Magnify includes dial stack and command tokens

| Step | Action | Expected |
|------|--------|----------|
| 1 | Left-click a ship card entry that has dial stack and command tokens | The entry magnifies to 3× including the card, defense tokens, dial stack, and command tokens |
| 2 | Left-click again to unmagnify | All components return to normal size together |

**Pass criteria:** Magnify toggle scales all panel components (card, defense tokens, dial stack, command tokens) proportionally.

---

## Regression Checklist

Run this quick checklist any time you merge changes that touch Phase 0–4b files:

- [ ] `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -10` → **0 failures**
- [ ] Open Godot editor → no red errors in Output panel
- [ ] Run `game_board.tscn` → all 5 tokens appear in correct deployment zones
- [ ] Ship tokens show white bold shield / hull / speed numbers at correct positions
- [ ] Ship card panels visible: Rebel cards on left (left-aligned), Imperial cards on right (right-aligned), with defense token columns to the left of each card
- [ ] Defense tokens top-aligned to their card
- [ ] Command dial stacks visible below defense tokens (after dial assignment)
- [ ] Command tokens visible right of ship card (after token conversion)
- [ ] Right-click drag → board pans; boundary clamping works
- [ ] Scroll wheel → zoom in/out; clamps at min/max
- [ ] (macOS) Two-finger swipe on trackpad → board pans smoothly; clamping works
- [ ] (macOS) Pinch gesture on trackpad → zooms in/out keeping world point under fingers; clamps at min/max
- [ ] F12 → "DEBUG" label + blue deployment lines appear; F12 again → disappear
- [ ] Click token in debug mode → follows mouse; click again → deselects
- [ ] Drag token into another → slide-to-contact; cursor past → jump-past
- [ ] Drag faction token past deployment line → stops at boundary
- [ ] Ctrl+S in debug mode → positions saved; reload confirms
- [ ] Round starts → initiative player (Rebel) assigns dials first; handoff overlay shows before Imperial player
- [ ] Active player switch → board camera rotates 180° smoothly; card panels swap sides
- [ ] Ship/Squadron phase → "Your Turn" banner appears briefly on player switch
- [ ] "End Activation" button visible during Ship/Squadron phases only; click triggers player switch
- [ ] Game starts with handoff overlay ("Rebel Player — Your Turn") before any dials are assigned
- [ ] Mouse/trackpad controls work correctly at both 0° and 180° camera rotation (no inversion)
- [ ] Clicking opponent's command dial stack has no effect (no modal opens)

### MT-4b: Turn Management & Board Perspective

**Precondition:** Launch the game board scene (`game_board.tscn`) in hot-seat mode.

#### MT-4b.1 — Sequential Command Phase & Handoff Overlay
- [ ] Round 1 starts: initiative player (Rebel) is assigned dials first
- [ ] After Rebel finishes all dial assignments, a full-screen handoff overlay appears: "Imperial Player — Your Turn" with a "Ready" button
- [ ] Clicking "Ready" dismisses the overlay and the Imperial player assigns dials
- [ ] After Imperial finishes, the Command Phase completes and transitions to Ship Phase

#### MT-4b.2 — Board Camera Perspective Rotation
- [ ] When the active player changes, the board camera rotates 180° smoothly (~0.5 s)
- [ ] Rebel perspective: Rebel ships at the bottom, Imperial at the top
- [ ] Imperial perspective: Imperial ships at the bottom, Rebel at the top
- [ ] Board stays centred during the rotation animation

#### MT-4b.3 — Ship Card Panel Swap
- [ ] When it's the Rebel player's turn: Rebel cards on the left, Imperial on the right
- [ ] When it's the Imperial player's turn: Imperial cards on the left, Rebel on the right
- [ ] Panels swap positions smoothly when the active player changes

#### MT-4b.4 — "Your Turn" Banner (Ship/Squadron Phase)
- [ ] When entering Ship Phase, a brief "Your Turn" banner appears for the active player
- [ ] Banner auto-dismisses after ~2 seconds or on click
- [ ] Banner shows correct player name ("Rebel Player" or "Imperial Player")

#### MT-4b.5 — End Activation Button
- [ ] "End Activation" button is visible during Ship and Squadron phases
- [ ] Button is hidden during Command and Status phases
- [ ] Clicking the button passes control to the other player (handoff appears)

#### MT-4b.6 — Phase HUD Updates
- [ ] Phase HUD shows correct phase name and round number at all times
- [ ] Active player name is visible in the HUD during Ship/Squadron phases

---

*Last updated: Phase 4b implementation complete — PlayMode autoload, active player tracking, sequential command phase, board perspective rotation, card panel swap, HandoffOverlay, YourTurnBanner, EndActivationButton, GameManager turn management. Post-Phase-L bug fixes applied (initial handoff, camera rotation, mouse controls, dial access). 672 tests passing (43 scripts, 1316 asserts).*

---

## Phase L — Game Logging Tooling

**Precondition:** Launch the game board scene via `./scripts/run_board.sh --logging` (or combine with `--debug`).

#### MT-L.1 — Log File Creation
- [ ] Run `./scripts/run_board.sh --logging` and play through at least one full round
- [ ] Verify a log file was created at `user://logs/game_<YYYYMMDD>_<HHMMSS>.log` (on macOS: `~/Library/Application Support/Godot/app_userdata/Star Wars Armada/logs/`)
- [ ] File name contains the session start timestamp

#### MT-L.2 — Session Header Content
- [ ] Open the log file and verify the first block contains:
  - `=== Star Wars: Armada — Game Session Log ===`
  - App version, Godot version, OS name
  - Play mode (e.g. "hot_seat")
  - A separator line (`---`)

#### MT-L.3 — Round & Phase Logging
- [ ] Log contains `round_started round=1` at the start of round 1
- [ ] Phase transitions appear in order: `phase_changed … Command`, `… Ship`, `… Squadron`, `… Status`
- [ ] `round_ended round=1` appears after the Status Phase completes

#### MT-L.4 — Active Player & Command Logging
- [ ] `active_player_changed player=1` / `player=2` entries appear at player transitions
- [ ] `command_picker_confirmed` entries log the player and chosen command type
- [ ] `command_dials_submitted` appears when a player's command dials are all assigned
- [ ] `command_phase_complete` appears when both players finish dials

#### MT-L.5 — Ship/Squadron Phase Logging
- [ ] `activation_ended` entries appear when a ship or squadron ends activation
- [ ] `auto_pass` entries appear when a player has no remaining unactivated ships/squads
- [ ] `handoff_accepted` entries appear after the handoff overlay is dismissed

#### MT-L.6 — Game End Logging
- [ ] Play through to game end (or trigger it): `game_ended` entry appears in the log
- [ ] State snapshot logged at end includes ship/squadron counts per player

#### MT-L.7 — Logging Disabled by Default
- [ ] Run `./scripts/run_board.sh` (no `--logging` flag)
- [ ] Confirm no new log file is created in the logs directory

#### MT-L.8 — Combined Flags
- [ ] `./scripts/run_board.sh --debug --logging` enables both debug visuals and file logging
- [ ] `./scripts/run_board.sh --logging --debug` (reversed order) also works

---

*Last updated: Phase L implementation complete — LoggingMode autoload, GameLogger file output, event-driven logging for all game phases, `--logging` CLI flag, launch script updates. 672 tests passing (43 scripts, 1316 asserts).*

---

## Post-Phase-L Bug Fixes

**What these fixes address:** Issues discovered during manual playtesting of hot-seat mode after Phase L. All fixes are in commits `581e030`–`5db1b48`.

### Setup

Run `scripts/run_board.sh` or open `game_board.tscn` and press **F6**.

---

### MT-BF.1 — Initial handoff overlay appears at game start

| Step | Action | Expected |
|------|--------|----------|
| 1 | Launch the game board scene | A full-screen handoff overlay appears immediately: **"Rebel Player — Your Turn"** with a "Ready" button |
| 2 | Click "Ready" | Overlay dismisses; Command Dial Picker opens for the first Rebel ship |
| 3 | Do **not** see any dials being assigned before the overlay | No picker opens before the "Ready" click |

**Pass criteria:** Game starts with handoff overlay for Rebel player; dial assignment only begins after overlay is dismissed.

---

### MT-BF.2 — Board camera rotates on player switch

| Step | Action | Expected |
|------|--------|----------|
| 1 | Complete Rebel player's command dial assignment | Handoff overlay shows "Imperial Player — Your Turn" |
| 2 | Click "Ready" | Board rotates 180° smoothly (~0.5 s) |
| 3 | Check orientation | Imperial ships are now at the **bottom** of the screen; Rebel ships at the **top** |
| 4 | Complete Imperial dial assignment | Phase transitions to Ship; board may rotate back for the initiative player |

**Pass criteria:** Camera rotation is visually smooth; Imperial perspective has Imperial ships at bottom. No jitter or snap.

---

### MT-BF.3 — Mouse controls work correctly at 180° rotation

| Step | Action | Expected |
|------|--------|----------|
| 1 | Switch to Imperial player (board rotated 180°) | Imperial perspective active |
| 2 | **Right-click drag** to the right | Board pans to the **left** (same as at 0°, not inverted) |
| 3 | **Right-click drag** downward | Board pans **upward** |
| 4 | **Scroll wheel up** | Zooms in toward cursor position |
| 5 | (macOS) **Two-finger swipe left** | Board pans right — direction matches finger movement, not inverted |
| 6 | (macOS) **Pinch-to-zoom** | Zoom direction correct; world point under fingers stays anchored |

**Pass criteria:** All mouse/trackpad controls behave identically at 0° and 180° rotation — no inversion.

---

### MT-BF.4 — Opponent command dial stacks are hidden

| Step | Action | Expected |
|------|--------|----------|
| 1 | As Rebel player, assign command dials for all ships | Dials appear in Rebel panel |
| 2 | Click on the **Imperial** ship's dial stack in the right panel | **Nothing happens** — no Command Dial Order modal opens |
| 3 | Switch to Imperial player via handoff | Imperial is now active |
| 4 | Click on the **Rebel** ship's dial stack in the right panel | **Nothing happens** — cannot view Rebel dials |
| 5 | Click on the **Imperial** ship's own dial stack | Command Dial Order modal opens showing Imperial dials |

**Pass criteria:** Active player can only view their own command dial stacks; clicking opponent stacks has no effect.

---

### MT-BF.5 — Phase sequence integrity (no double advance)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a new game; assign dials for all Rebel ships | Handoff to Imperial |
| 2 | Assign dials for all Imperial ships | Phase transitions to **Ship Phase** |
| 3 | Verify phase HUD | Shows "Ship Phase", **not** "Squadron Phase" |
| 4 | Check the game log (if `--logging` enabled) | Phase sequence: Command → Ship (no skip to Squadron) |

**Pass criteria:** After both players submit dials, the game advances to Ship Phase only — never skips directly to Squadron.

---

## Phase 4c — Ship Activation via Dial Drag-and-Drop

**What this phase adds:** Players activate ships during the Ship Phase by dragging the topmost command dial from the card panel onto the matching ship token on the board. The revealed dial appears behind the ship base. Pressing "End Activation" spends the dial, marks the ship activated, and advances the turn.

### MT-4c.1 — Drag initiation from card panel

| Step | Action | Expected |
|------|--------|----------|
| 1 | Complete the Command Phase (assign dials for both players) | Ship Phase starts; "Your Turn" banner for Rebel |
| 2 | Dismiss the banner | No "End Activation" button visible yet |
| 3 | Click on the topmost dial in the Rebel ship's dial stack | A semi-transparent dial icon appears and follows the mouse cursor |
| 4 | Move the mouse around | The floating dial tracks the cursor smoothly |

**Pass criteria:** Clicking the top dial during Ship Phase starts a drag with a visible floating preview.

### MT-4c.2 — Successful drop activates ship

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a dial drag (MT-4c.1) | Floating dial follows mouse |
| 2 | Move the mouse over the matching Rebel ship token on the board and release | Floating preview disappears; a command icon appears behind the ship's aft edge (~1 cm gap) |
| 3 | Check the card panel dial stack | Top dial now shows revealed (command icon instead of facedown) |
| 4 | Check for End Activation button | "End Activation" button is now visible |

**Pass criteria:** Dropping the dial on the correct ship reveals it on the board and in the panel, and shows the End Activation button.

### MT-4c.3 — Invalid drop cancels drag

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a dial drag from Rebel ship | Floating dial follows mouse |
| 2 | Release the mouse on empty space (not on any ship token) | Floating preview disappears; no activation occurs |
| 3 | Verify no "End Activation" button | Button remains hidden |
| 4 | Start a new drag and drop it on the **Imperial** ship token | Floating preview disappears; no activation occurs (wrong ship) |

**Pass criteria:** Dropping the dial on invalid targets (empty space, wrong ship) cancels the drag without side effects.

### MT-4c.4 — End Activation spends dial and advances turn

| Step | Action | Expected |
|------|--------|----------|
| 1 | Successfully activate a Rebel ship (MT-4c.2) | Dial shown behind ship, End Activation visible |
| 2 | Click "End Activation" | Dial sprite removed from board; card panel shows spent dial icon below stack |
| 3 | Observe turn transition | "Your Turn" banner appears for Imperial player |
| 4 | Dismiss banner and activate Imperial ship the same way | Imperial ship activated |
| 5 | Click "End Activation" for Imperial ship | Both ships activated; phase cascades to next round |
| 6 | Check phase HUD | Shows "Round 2 — Command Phase" |

**Pass criteria:** Full Ship Phase round-trip: both players activate one ship each, turns alternate correctly, phase advances to next round.

### MT-4c.5 — Guard conditions prevent invalid activation

| Step | Action | Expected |
|------|--------|----------|
| 1 | During Command Phase, click on a ship's dial stack | Opens dial order modal (no drag starts) |
| 2 | During Ship Phase, try clicking the dial stack of an already-activated ship | Opens dial order modal (no drag) |
| 3 | During Ship Phase, try clicking the opponent's dial stack | Nothing happens (viewer restriction) |

**Pass criteria:** Dial drag only starts for unactivated ships owned by the active player during Ship Phase.

---

### MT-4c.6 — Composite dial graphic on board

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a Rebel ship by dragging its dial onto the ship token | Dial reveals behind the ship base on the board |
| 2 | Zoom in on the revealed dial graphic | Shows a **composite**: the `cmd_dial_hidden.png` circle as background with the command icon (`cmd_<type>.png`) overlaid at ~75% scale in the centre |
| 3 | Verify the icon matches the assigned command | E.g. Navigate shows the arrow icon |

**Pass criteria:** Revealed dial on board is a two-layer composite (background + icon), not a single flat image.

### MT-4c.7 — Spent dial positioned below active stack with gap

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a ship and click "End Activation" | The board dial disappears |
| 2 | Check the ship's card panel entry | A spent (faceup) dial appears **below** the remaining hidden dial stack |
| 3 | Verify a visible gap (~12 px) separates the spent dial from the hidden stack above it | Clear visual separation between active and spent dials |
| 4 | Verify the spent dial is horizontally centred | Not stretched or left-aligned |

**Pass criteria:** Spent dial renders below the active stack with visible separation and is centred.

### MT-4c.8 — Revealed dial hidden from card panel stack

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a ship (drag dial to ship token) | Revealed dial appears on the board behind the ship |
| 2 | Check the ship's card panel dial stack | The revealed dial is **not** shown in the card panel stack — only hidden dials and spent dials remain |
| 3 | The board is the only place showing the revealed dial | Confirmed |

**Pass criteria:** During activation, the revealed dial is only visible on the board token, not duplicated in the card panel stack.

### MT-4c.9 — Initiative stays with Rebel player across rounds

| Step | Action | Expected |
|------|--------|----------|
| 1 | Complete round 1 (Command → Ship → Squadron → Status) | Round 2 begins |
| 2 | Check who assigns dials first in round 2 | **Rebel player** (initiative player) assigns first |
| 3 | Complete round 2 and check round 3 | Rebel still assigns first |
| 4 | Check the "Your Turn" banner in Ship Phase of any round | Rebel always activates first |

**Pass criteria:** Initiative never changes — Rebel player always goes first in every phase, every round. Per RRG "Initiative" p.8: "The first player retains initiative for the entire game."

### MT-4c.10 — Round 2+ dial assignment for all ships

| Step | Action | Expected |
|------|--------|----------|
| 1 | Complete round 1 (all ships activated) | Round 2 begins, Command Phase |
| 2 | Rebel assigns dials — check that **both** CR90 and Nebulon-B get a dial picker | Picker opens for each Rebel ship that needs a new dial |
| 3 | Imperial assigns dials — Victory II gets a dial picker | Picker opens for the Victory II |
| 4 | Verify Nebulon-B now has 2 hidden dials in its stack | 1 from round 1 (leftover) + 1 new = 2 |
| 5 | Complete Ship Phase — verify Nebulon-B can be activated | Drag works normally for Nebulon-B |

**Pass criteria:** In round 2+, every ship that needs a dial gets the picker; no ships are silently skipped. The state-aware `get_dials_needed()` correctly determines how many dials each ship requires.

### MT-4c.11 — Command dial picker shows existing stack context

| Step | Action | Expected |
|------|--------|----------|
| 1 | In round 2, open the dial picker for a ship with existing dials (e.g. Nebulon-B) | Picker modal opens |
| 2 | Check the stack area | Shows the **existing** hidden dials already in the stack |
| 3 | Add 1 new dial | New dial added below existing dials |
| 4 | Confirm | Stack now has the existing dials + new one |

**Pass criteria:** Round 2+ picker shows existing queued dials for context, not an empty stack.

---

## Phase 4d — Keep-or-Convert Dial Choice

**What this phase adds:** Two drag targets for dial activation — dragging to the **ship token on the board** keeps the dial for its full command effect (existing), while dragging to the **ship card panel entry** converts it to a command token. A help text label guides the player during drag.

### MT-4d.1 — Help text appears during dial drag

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a game, reach Ship Phase | Active player's ship has a hidden dial |
| 2 | Click the topmost dial in the card panel to begin dragging | Semi-transparent dial follows mouse AND a text label appears near the bottom of the screen |
| 3 | Read the help text | Text says "Drag to ship for full command effect" / "Drag to ship card for command token" (two lines) |
| 4 | Release the mouse on an empty area (cancel drag) | Help text disappears |

**Pass criteria:** Help text is visible during the entire drag and disappears when drag ends (drop or cancel).

### MT-4d.2 — Drag to ship token (board drop) still works

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start dial drag from card panel | Drag preview + help text appear |
| 2 | Drop the dial onto the ship's token on the board | Ship activates normally: revealed dial appears behind the base, "End Activation" button appears |
| 3 | Check the card panel | Dial stack shows revealed dial removed, activation marker below |
| 4 | Press "End Activation" | Dial is spent, turn advances to next player |

**Pass criteria:** Board drop activation works exactly as before Phase 4d, with the addition of help text.

### MT-4d.3 — Drag to ship card (token conversion)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start dial drag from card panel | Drag preview + help text appear |
| 2 | Drop the dial onto the same ship's card entry in the card panel | Ship activates |
| 3 | Check the ship card panel | A new command token appears in the right column matching the dial's command type |
| 4 | Check the board | NO revealed dial appears behind the ship's base on the board |
| 5 | Check the card panel dial stack | The dial has moved to the spent area immediately (activation marker) |
| 6 | Press "End Activation" | Activation ends, turn advances to next player |

**Pass criteria:** Card drop converts dial to token, shows token in panel, no board dial, dial goes directly to spent area.

### MT-4d.4 — Token conversion with duplicate token

| Step | Action | Expected |
|------|--------|----------|
| 1 | (Requires a ship that already has a NAVIGATE token — may need to do a card drop conversion in a previous round) | Ship has an existing token |
| 2 | Start a dial drag for the same command type as the existing token | Drag begins |
| 3 | Drop onto the ship card entry | Ship activates; duplicate token is added then **auto-discarded** (CM-005) |
| 4 | Verify token count in the right column | Same as before — no duplicate |
| 5 | Check for notification | Brief "Duplicate Navigate discarded" toast appears near the command token column and fades after ~2 seconds |

**Pass criteria:** Duplicate auto-discard per CM-005 fires a brief notification; dial is still spent; token count unchanged.

---

## Phase 4e — Command Token Overflow Discard

**What this phase adds:** When a dial-to-token conversion would cause a ship's tokens to exceed its command value, the new token is temporarily added and the player must click one of the ship's command tokens to discard. For duplicates, the token is auto-discarded with a brief notification. The "End Activation" button is delayed until any overflow is resolved.

### MT-4e.1 — Overflow discard prompt appears (CR90, command value 1)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a game, reach Ship Phase for a CR90 (command value 1) | CR90 has one hidden dial |
| 2 | In a previous activation, convert a dial to a command token | CR90 now holds 1 token (at capacity) |
| 3 | In a subsequent round, drag a NEW dial onto the card panel (token path) | Both old and new tokens appear in the column; a red "Discard a token" prompt label appears at the top of the token column |
| 4 | Verify "End Activation" button is NOT visible | Button should be hidden until discard is resolved |
| 5 | Click one of the two tokens | The clicked token is removed; prompt disappears; "End Activation" button appears |

**Pass criteria:** Overflow triggers discard mode; tokens are clickable; End Activation blocked until resolved.

### MT-4e.2 — Token highlight and cursor in discard mode

| Step | Action | Expected |
|------|--------|----------|
| 1 | Trigger overflow discard (as in MT-4e.1 steps 1–3) | Discard prompt visible |
| 2 | Hover the mouse over each token | Cursor changes to pointing hand |
| 3 | Observe token appearance | Tokens have a slight reddish tint (modulate) |

**Pass criteria:** Visual feedback (cursor + tint) makes tokens clickable during discard mode.

### MT-4e.3 — Duplicate token auto-discard with notification

| Step | Action | Expected |
|------|--------|----------|
| 1 | Have a ship with an existing NAVIGATE token | Token present in the right column |
| 2 | Convert a NAVIGATE dial to token | Duplicate is auto-discarded immediately |
| 3 | Observe the token column | A yellow "Duplicate Navigate discarded" toast appears, then auto-hides after ~2 seconds |
| 4 | Verify token count | Still 1 NAVIGATE token (count unchanged) |
| 5 | Verify "End Activation" button | Appears immediately (no discard prompt needed) |

**Pass criteria:** Duplicate auto-discard is seamless with notification; no discard mode entered.

### MT-4e.4 — No discard prompt when under capacity

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start with a ship that has 0 tokens and command value ≥ 2 | Token column is empty |
| 2 | Convert a dial to a token | Token appears in the column normally |
| 3 | Verify no prompt or special UI | No discard prompt, no tint, no toast |
| 4 | "End Activation" button appears immediately | Button visible |

**Pass criteria:** Normal flow is unchanged — no discard UI when under capacity.

---

---

## Phase 4f — Hover Tooltip Infrastructure

**What this phase adds:** A reusable, globally switchable tooltip system (`TooltipManager` autoload) that displays contextual BBCode-rich help text on hover with configurable delay. A global toggle button (lower-right corner) lets players disable hover hints while keeping essential programmatic tooltips (drag help, discard prompt) active. All ad-hoc labels (drag help, discard prompt, duplicate toast) are migrated to `TooltipManager.show_text()`.

### MT-4f.1 — Toggle button renders and persists

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run the GameBoard scene | A small (28×28 px) "?" toggle button appears in the lower-right corner |
| 2 | Click the toggle button | Button text changes from "?" to "⦸" (or vice-versa); tooltip hover hints are disabled/enabled accordingly |
| 3 | Quit and restart the scene | Toggle state is preserved (persisted to `user://settings.cfg`) |

**Pass criteria:** Toggle button visible, clickable, state persists across sessions.

### MT-4f.2 — Drag help tooltip replaces old label

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a game, reach Ship Phase, begin dragging a command dial | A tooltip appears near the cursor with drag instructions (BBCode styled) |
| 2 | Drop or cancel the drag | Tooltip hides immediately |
| 3 | Verify no old-style centred label | No full-width centred help label appears on the board |

**Pass criteria:** Drag help uses TooltipManager; old `_drag_help_label` is gone.

### MT-4f.3 — Discard prompt tooltip replaces old label

| Step | Action | Expected |
|------|--------|----------|
| 1 | Trigger a command token overflow (see MT-4e.1 steps 1–3) | A tooltip appears with "Click a command token to discard" |
| 2 | Click a token to resolve | Tooltip hides |

**Pass criteria:** Discard prompt uses TooltipManager, not an ad-hoc Label.

### MT-4f.4 — Duplicate toast tooltip with auto-hide

| Step | Action | Expected |
|------|--------|----------|
| 1 | Have a ship with an existing NAVIGATE token | Token present |
| 2 | Convert a NAVIGATE dial to token | A tooltip appears briefly: "Duplicate Navigate discarded" |
| 3 | Wait ~2 seconds | Tooltip auto-hides |

**Pass criteria:** Toast uses TooltipManager with auto-hide duration; no old Label.

### MT-4f.5 — Tooltip renders above all other UI

| Step | Action | Expected |
|------|--------|----------|
| 1 | Trigger any tooltip (drag help, discard prompt, or hover) | Tooltip panel renders on top of all other UI elements (HUD, card panels, etc.) |
| 2 | Check for any clipping or z-order issues | Tooltip is always fully visible |

**Pass criteria:** CanvasLayer 100 ensures tooltip is the topmost UI element.

---

## Post-Phase 4f — Dial Alignment & Layout Fixes

**What this fixes:** Command dial stack visual alignment issues (dial shift on reveal/spend) and adds a 10 px gap between defense tokens and the dial stack.

### MT-4f-fix.1 — Dial centering on reveal and spend

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run the GameBoard scene, reach Ship Phase | Ship card panel visible with hidden dials (white circle icons) |
| 2 | Click a dial stack to reveal the top dial | Revealed dial icon stays horizontally centred — no leftward or rightward shift |
| 3 | Drag the revealed dial to the ship | Dial is spent; spent dial icon appears centred below the active stack |
| 4 | Compare alignment of hidden, revealed, and spent dials | All three types are horizontally centred within the same column width |

**Pass criteria:** No horizontal shift when dials transition between hidden → revealed → spent states.

### MT-4f-fix.2 — Gap between defense tokens and dial stack

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run a game with ships that have defense tokens | Defense token row visible in left column of ship entry |
| 2 | Observe spacing between last defense token and first dial | A visible ~10 px gap separates the token row from the dial container |
| 3 | Compare with magnified view | Gap scales proportionally when the card panel is magnified |

**Pass criteria:** Tokens and dials are visually separated; no cramped overlap.

### MT-4f-fix.3 — Contextual hover hints on ship card panel

| Step | Action | Expected |
|------|--------|----------|
| 1 | Ensure tooltip toggle is enabled ("?" visible in lower-right corner) | Toggle shows "?" |
| 2 | Hover over a dial stack area | After short delay, a tooltip appears describing the current dial action (e.g., "Click to reveal top dial" during Ship Phase, "Click to open dial order" otherwise) |
| 3 | Hover over a ship card thumbnail | Tooltip appears with "Click to magnify / unmagnify" |
| 4 | Move cursor away | Tooltip hides |
| 5 | Disable toggle (click "?" → "⦸") | Hovering no longer shows dial or card hints |

**Pass criteria:** Contextual hover hints appear for dial stack and card entry; respect toggle state.

---

## Phase 5a — Maneuver Tool Visualization & Toolbar

**What this phase adds:** An action toolbar in the lower-right corner (housing the existing tooltip toggle + a new "Display Maneuver Tool" button), a ship-selection prompt, ManeuverToolScene that renders the segmented maneuver tool attached to a ship with interactive joints (left-click = port, right-click = starboard), and a ghost ship preview at the projected final position.

### MT-5a.1 — Action toolbar appears in lower-right

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run game board scene (F6) | Lower-right corner shows a toolbar with two buttons: "?" (tooltip toggle) and "M" (maneuver tool) |
| 2 | Click "?" button | Tooltip toggle state changes (same behaviour as before relocation) |
| 3 | Resize the window | Toolbar stays anchored in the lower-right corner |

### MT-5a.2 — Ship selection mode and tool display

| Step | Action | Expected |
|------|--------|----------|
| 1 | Click the "M" button in the toolbar | A "Select a ship" prompt appears (via tooltip system) |
| 2 | Click on a ship token on the board | The maneuver tool appears attached to the left side of that ship's front edge |
| 3 | Verify segment sprites | Multiple translucent segment images are visible in a chain extending forward from the ship |
| 4 | Verify ghost preview | A semi-transparent ship token image appears at the projected final position |

### MT-5a.3 — Joint interaction (left/right click)

| Step | Action | Expected |
|------|--------|----------|
| 1 | With tool displayed, left-click near a joint (between segment sprites) | The downstream segments rotate to the left (port); joints within ±2 click range |
| 2 | Right-click near the same joint | The downstream segments rotate to the right (starboard) |
| 3 | Click beyond max yaw | No further rotation occurs (click is rejected) |
| 4 | Verify ghost preview updates | Ghost ship position/rotation changes to match the new joint angles |

### MT-5a.4 — Dismissal

| Step | Action | Expected |
|------|--------|----------|
| 1 | Press Escape while tool is displayed | Tool disappears, game returns to normal state |
| 2 | Click "M" again, select a ship, then click "M" again | Tool disappears (toggle behaviour) |
| 3 | Click "M", then press Escape before selecting a ship | Selection mode cancelled, no tool shown |

### MT-5a.5 — No regressions

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run automated GUT suite | 792 tests, 49 scripts, 0 failures |
| 2 | Complete a full Command Phase | Dials assign normally; no interaction with maneuver tool flow |

**Pass criteria:** Toolbar visible; button triggers selection; tool renders with correct segment sprites; joints clickable; ghost preview updates; Escape dismisses; 792 tests pass.

---

## Phase 5a+ — Dynamic Alignment & Speed Simulation

**What this phase adds:** Ghost ship preview auto-switches side based on joint bending direction (bending left → ghost on right, bending right → ghost on left). Speed +/− buttons on the end segment allow previewing different speeds without modifying ship state. The ghost displays the simulated speed number.

### MT-5a+.1 — Dynamic root and ghost alignment

| Step | Action | Expected |
|------|--------|----------|
| 1 | Display maneuver tool on a ship | Tool attaches on the left side of the ship; ghost on the left (default) |
| 2 | Left-click a joint (port / left bend) | Tool stays on left side of ship; ghost stays on left; tool bends left |
| 3 | Right-click a joint (starboard / right bend) | Tool switches to right side of ship; ghost switches to right; tool bends right |
| 4 | Set multiple joints: an early joint left, last joint right | Tool on right, ghost on right (last non-zero joint = starboard wins) |
| 5 | Reset all joints to straight | Tool and ghost both return to left (default) |

### MT-5a+.2 — Speed +/− buttons visible

| Step | Action | Expected |
|------|--------|----------|
| 1 | Display maneuver tool at speed ≥ 1 | Two 20 px circular buttons ("−" and "+") are visible on the end segment, symbols centred |
| 2 | Buttons are at the correct position | They appear in the upper area of the end segment, side by side |

### MT-5a+.3 — Speed simulation via buttons

| Step | Action | Expected |
|------|--------|----------|
| 1 | Click "+" button | Segment count increases by 1; new segment appears; ghost moves further forward |
| 2 | Click "+" until max speed | Button click has no effect beyond max speed; segment count stays at max_speed + 1 |
| 3 | Click "−" button from max | Segment count decreases by 1; last segment disappears |
| 4 | Click "−" until speed 1 | Button click has no effect below speed 1; tool shows root + 1 segment |
| 5 | Verify joint clicks adapt | If a previously bent joint is no longer active after speed decrease, it resets to 0 |

### MT-5a+.4 — Speed label on ghost

| Step | Action | Expected |
|------|--------|----------|
| 1 | Display tool at default speed | Ghost shows the current speed number at the speed label position on the token |
| 2 | Click "+" to increase speed | Speed number on ghost updates to the new simulated speed |
| 3 | Click "−" to decrease speed | Speed number on ghost updates to the new simulated speed |

### MT-5a+.5 — Simulation is preview-only

| Step | Action | Expected |
|------|--------|----------|
| 1 | Change simulated speed via +/− | The ship's actual speed in the card panel does not change |
| 2 | Dismiss the tool and re-display it | Tool starts at the ship's actual speed, not the simulated one |

### MT-5a+.6 — No regressions

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run automated GUT suite | 812 tests, 49 scripts, 0 failures |
| 2 | All Phase 5a manual tests still pass | Joint clicks, dismissal, toolbar — no regression |

**Pass criteria:** Ghost auto-switches sides; speed buttons render and work; speed label appears; simulation doesn't modify ship state; 812 tests pass.

---

## Phase 5b — Ship Movement Execution

**What this phase adds:** After a command dial is revealed (Phase 4c/4d), a "Show Activation Sequence" button replaces the immediate End Activation. Pressing it opens a centred Activation Modal (matching CommandDialPicker style) that shows the five sub-steps (Reveal, Squadron, Repair, Attack, Execute Maneuver). Steps 2–4 auto-skip with "Not yet implemented" badges. In the Execute Maneuver step, a two-phase button ("Execute Maneuver ►" / "Commit Maneuver ►") controls the maneuver tool. Navigate command allows speed ±1/±2 and +1 yaw on any joint. After committing, the activation auto-ends and the next player's turn starts. The simulation maneuver button is disabled during activation.

### MT-5b.1 — Activation sequence button appears after dial reveal

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a game and complete the Command Phase | All ships have dials assigned |
| 2 | Drag a command dial onto a ship (or its card) to activate it | The ship's revealed dial icon appears behind the base |
| 3 | Verify the bottom-centre button | "Show Activation Sequence" button appears (NOT "End Activation") |
| 4 | Verify no other buttons are visible | End Activation and Execute Maneuver are hidden |

### MT-5b.2 — Activation Modal opens and auto-skips

| Step | Action | Expected |
|------|--------|----------|
| 1 | Press "Show Activation Sequence" | The button hides; a centred panel appears (dark blue `#0D1B2A` background, rounded corners, matching CommandDialPicker style) |
| 2 | Panel title | "Ship Activation" at the top |
| 3 | Dial/token info | Shows the revealed dial command and any command tokens the ship has |
| 4 | Step 1 (Reveal) | Shows checkmark ✓ (already completed) |
| 5 | Steps 2–4 auto-skip | Each placeholder step briefly shows "Not yet implemented" in amber, then gets a ✓ after ~0.3s |
| 6 | Step 5 (Execute Maneuver) | Shows "Execute Maneuver ►" button as the active step after auto-skip finishes |

### MT-5b.3 — Modal dismiss and reopen

| Step | Action | Expected |
|------|--------|----------|
| 1 | Press Escape or the ✕ Close button on the modal | Modal closes; "Show Activation Sequence" button reappears |
| 2 | Press "Show Activation Sequence" again | Modal reopens at the same step (Execute Maneuver still active) |

### MT-5b.4 — Two-phase Execute/Commit button

| Step | Action | Expected |
|------|--------|----------|
| 1 | With step 5 active, press "Execute Maneuver ►" | Modal closes; maneuver tool appears attached to the ship in activation mode |
| 2 | Reopen the modal ("Show Activation Sequence") | Button now reads "Commit Maneuver ►" |
| 3 | Set joints and optionally change speed | Ghost shows the expected final position |
| 4 | Press "Commit Maneuver ►" | Ship snaps to ghost position; maneuver tool disappears; modal closes; activation auto-ends; next player's turn starts |

### MT-5b.5 — Navigate command: speed change via +/− buttons

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a ship with a Navigate dial revealed | After pressing Execute, maneuver tool appears in activation mode |
| 2 | Click "+" on the end segment | Ship's actual speed increases by 1; maneuver tool gains a segment |
| 3 | Click "+" again (dial budget spent) | No effect — budget exhausted (unless token available) |
| 4 | Click "−" to reverse the change | Speed returns to original; budget fully restored (reversible) |
| 5 | Activate a ship with Navigate dial + Navigate token | Two speed changes allowed (±2 total) |
| 6 | Check bounds | Cannot go below 0 or above max_speed |

### MT-5b.6 — Navigate command: yaw bonus on any joint

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a ship with Navigate dial at speed ≥ 2 | Maneuver tool appears; no "N" badge yet (bonus not pre-assigned) |
| 2 | Click a joint beyond its base yaw limit | Click succeeds; an "N" badge appears on that joint (bonus auto-applied) |
| 3 | Click a **different** joint beyond its base limit | Bonus moves to the new joint; "N" badge moves; old joint's clicks clamped to its reduced limit |
| 4 | Verify the bonus joint allows 1 extra click vs nav chart | Compare with the ship's navigation chart — bonus joint has +1 max yaw |

### MT-5b.7 — Navigate token spend on commit

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a ship with only a Navigate token (dial = different command) | Speed ±1 available |
| 2 | Change speed via +/− | Navigate token in card panel shows reddish overlay (spend preview) |
| 3 | Press "Commit Maneuver ►" | Ship moves; Navigate token **removed** from card panel; overlay gone |

### MT-5b.8 — Simulation maneuver blocked during activation

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a ship and press "Execute Maneuver ►" | Maneuver tool appears in activation mode |
| 2 | Check lower-right toolbar "M" button | Button is greyed out / disabled |
| 3 | Try clicking the "M" button | Nothing happens — simulation tool does not appear |
| 4 | After committing the maneuver | "M" button re-enabled |

### MT-5b.9 — Speed 0 skips maneuver tool

| Step | Action | Expected |
|------|--------|----------|
| 1 | Set a ship to speed 0 (via Navigate or initial state) and activate | No maneuver tool displayed |
| 2 | Ship stays in place | Position unchanged; maneuver counts as executed |
| 3 | Activation auto-ends | Next player's turn starts immediately (no End Activation button) |

### MT-5b.10 — Token conversion flow still works

| Step | Action | Expected |
|------|--------|----------|
| 1 | Drag a dial onto the ship card panel to convert to token | Token conversion happens, then "Show Activation Sequence" appears |
| 2 | Token overflow triggers discard prompt | Discard prompt appears before activation sequence button |

### MT-5b.11 — Auto-end activation after commit

| Step | Action | Expected |
|------|--------|----------|
| 1 | Commit a maneuver (press "Commit Maneuver ►") | Ship snaps to position; modal closes |
| 2 | Verify no "End Activation" button appears | Activation ends automatically |
| 3 | Verify next player's turn starts | Command dial prompt or next ship's activation begins |
| 4 | Complete a full game round | Command Phase → Ship Phase (activate all ships) → Squadron Phase → Status Phase → Round 2 |

### MT-5b.12 — No regressions

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run automated GUT suite | 847 tests, 50 scripts, 0 failures |
| 2 | All Phase 5a/5a+ manual tests still pass | Toolbar, joints, ghost, simulation — no regression |

**Pass criteria:** Activation sequence button appears after dial reveal; modal opens centred with auto-skip; two-phase Execute/Commit button; maneuver tool in activation mode (speed changes gated by Navigate, reversible, yaw bonus on any joint); Commit snaps ship and auto-ends activation; Navigate token removed from ship on commit; simulation maneuver blocked during activation; speed 0 works; 847 tests pass.

---

## Phase 5c — Range Overlay Tool

**What this phase adds:** An "R" button in the lower-right toolbar (next to the existing "M" maneuver button) that shows per-firing-arc range bands around a selected ship. Bands are coloured grey (close), blue (medium), and red (long) with curved edges at constant distance from the ship base. White lines mark the firing arc boundaries, extending 1.2× ruler length. The overlay is a visual aid only — no gameplay effect. Both M and R buttons are disabled during ship activation.

### MT-5c.1 — R button appears in toolbar

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run the GameBoard scene | Lower-right toolbar shows three buttons: tooltip toggle (🗨), M, and R |
| 2 | Hover over the R button | Tooltip reads "Range Overlay" |
| 3 | R button style | Same flat style as M button — white text at 0.7 alpha, brightens on hover |

### MT-5c.2 — Ship selection mode

| Step | Action | Expected |
|------|--------|----------|
| 1 | Click the R button | Tooltip "Select a ship" appears at screen centre |
| 2 | Click the R button again (toggle) | Selection mode cancelled; tooltip disappears |
| 3 | Press Escape during selection mode | Selection mode cancelled; tooltip disappears |

### MT-5c.3 — Range overlay image displayed

| Step | Action | Expected |
|------|--------|----------|
| 1 | Click R, then click any ship token | Pre-rendered overlay image appears around the ship |
| 2 | Overlay content | Arc boundary lines + coloured range bands (close/medium/long) baked into the image |
| 3 | Overlay position | Centred on the ship token; aligned with ship's rotation |
| 4 | Z-order | Overlay renders **below** all ship and squadron tokens |
| 5 | Per-ship type | CR90, Neb-B, and VSD each have their own overlay graphic |

### MT-5c.4 — Arc boundary lines and range bands visible

| Step | Action | Expected |
|------|--------|----------|
| 1 | With range overlay visible | 4 boundary lines radiate from the ship base |
| 2 | Range bands | Three coloured bands around each hull zone |
| 3 | Band order | Inner = close, middle = medium, outer = long |

### MT-5c.5 — Dismiss and toggle

| Step | Action | Expected |
|------|--------|----------|
| 1 | With overlay visible, press Escape | Overlay disappears |
| 2 | Click R again, select a ship, then click R once more | Overlay toggles off |
| 3 | Click R, select a ship; then click R, select a **different** ship | Previous overlay replaced by new one |

### MT-5c.6 — Small ship (CR90) overlay

| Step | Action | Expected |
|------|--------|----------|
| 1 | Show range overlay on CR90 Corvette A | Overlay centred on ship, arcs and bands look correct |
| 2 | Front arc | Narrower forward sector |
| 3 | Left and right arcs symmetric | Mirrored band shapes |

### MT-5c.7 — Medium ship (Victory-class) overlay

| Step | Action | Expected |
|------|--------|----------|
| 1 | Show range overlay on Victory I or II | Overlay is larger (medium base), centred correctly |
| 2 | Front arc is wider than CR90's | Larger base = wider front sector |
| 3 | Rear arc is visible | Rear bands render correctly behind the ship |

### MT-5c.8 — R button disabled during activation

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a ship (drag dial onto it) | Press "Show Activation Sequence" → "Execute Maneuver ►" |
| 2 | Check the R button | Greyed out / disabled (same as M button) |
| 3 | Try clicking the R button | Nothing happens |
| 4 | Commit the maneuver | R button re-enabled |

### MT-5c.9 — No regressions

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run automated GUT suite | 862 tests, 50 scripts, 0 failures |
| 2 | All Phase 5a/5b manual tests still pass | Maneuver tool, activation, Navigate — no regression |
| 3 | M button still works | Simulation maneuver tool unaffected |

**Pass criteria:** R button visible and styled correctly; click R → select ship → pre-rendered overlay image appears centred on ship, below all tokens; toggle/escape dismisses; disabled during activation; small ship and medium ship overlays look correct; 862 tests pass.

---

## Phase 5d — Targeting List Tool

**What this phase adds:** A "T" button opens a modal showing all valid attack targets (outgoing) and incoming threats for the active player's ships. Includes firing-arc containment, range measurement, and line-of-sight/obstruction checks. Ghost hypothetical section when maneuver tool ghost is visible.

### MT-5d.1 — T button visible and styled

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start game board scene | "T" button visible in the ActionToolbar alongside "M" and "R" |
| 2 | Hover over T button | Same styling as M and R buttons |
| 3 | Check alignment | T button positioned after R button |

### MT-5d.2 — Targeting list modal opens

| Step | Action | Expected |
|------|--------|----------|
| 1 | Press T button | Modal panel appears showing targeting list |
| 2 | Check content | Shows sections for each friendly ship |
| 3 | Check outgoing targets | Each ship lists outgoing targets per hull zone with range band, dice, and arc |
| 4 | Check incoming threats | Each ship lists incoming threats from enemy arcs |

### MT-5d.3 — Range and arc correctness

| Step | Action | Expected |
|------|--------|----------|
| 1 | With Learning Scenario layout, open targeting list | Range bands shown match expected values (e.g. close/medium/long) |
| 2 | Compare with visual range overlay | Targets shown at ranges that match what the range overlay would show |
| 3 | Check all four hull zones per ship | Targets appear under the correct arc (FRONT, LEFT, RIGHT, REAR) |

### MT-5d.4 — Dice summary

| Step | Action | Expected |
|------|--------|----------|
| 1 | Check a target at close range | Dice summary includes black, blue, and red dice as appropriate |
| 2 | Check a target at medium range | No black dice in summary |
| 3 | Check a target at long range | Only red dice in summary |

### MT-5d.5 — Dismiss and toggle

| Step | Action | Expected |
|------|--------|----------|
| 1 | With modal visible, press Escape | Modal disappears |
| 2 | Press T again | Modal reappears (recomputed) |
| 3 | Press T while modal is visible | Modal closes (toggle) |

### MT-5d.6 — Ghost hypothetical section

| Step | Action | Expected |
|------|--------|----------|
| 1 | Open maneuver tool on a ship and set speed | Ghost preview visible |
| 2 | Press T to open targeting list | Additional "Projected position (after maneuver)" section appears |
| 3 | Check ghost section content | Shows targets/threats from the ghost's projected position |
| 4 | Dismiss maneuver tool, press T again | Ghost section no longer appears |

### MT-5d.7 — Empty states

| Step | Action | Expected |
|------|--------|----------|
| 1 | If a ship has no outgoing targets | Shows "— No targets in range —" |
| 2 | If a ship has no incoming threats | Shows "— No incoming threats —" |

### MT-5d.8 — T button disabled during activation

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a ship | T button greyed out / disabled |
| 2 | Try pressing T | Nothing happens |
| 3 | Commit the maneuver | T button re-enabled |

### MT-5d.9 — Scrolling

| Step | Action | Expected |
|------|--------|----------|
| 1 | Open targeting list with many entries | Content is scrollable if longer than viewport |
| 2 | Scroll down | All entries visible and rendered correctly |

### MT-5d.10 — No regressions

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run automated GUT suite | 916 tests, 53 scripts, 0 failures |
| 2 | All Phase 5a/5b/5c manual tests still pass | Maneuver tool, range overlay — no regression |
| 3 | M and R buttons still work | Unaffected by T button addition |

**Pass criteria:** T button visible and styled; click T → modal with correct targets per arc, range bands, dice summaries; obstruction flagged; ghost section present when maneuver ghost active; toggle/escape dismiss; disabled during activation; scrollable; 916 tests pass.

---

## Phase 5e — Keyboard Shortcuts for Tools

**What this phase adds:** Pressing **M**, **R**, or **T** on the keyboard activates the Maneuver Tool, Range Overlay, and Targeting List respectively — identical to clicking the toolbar buttons. Shortcuts are disabled during ship activation (same guard as the buttons). The debug help panel shows a new "Tools" section listing these shortcuts.

### MT-5e.1 — M key toggles Maneuver Tool

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start game board scene | No maneuver tool visible |
| 2 | Press **M** on the keyboard | "Select a ship" prompt appears (same as clicking the M button) |
| 3 | Click a ship | Maneuver tool appears on the ship |
| 4 | Press **M** again | Maneuver tool is dismissed |

### MT-5e.2 — R key toggles Range Overlay

| Step | Action | Expected |
|------|--------|----------|
| 1 | Press **R** on the keyboard | "Select a ship" prompt appears |
| 2 | Click a ship | Range overlay appears |
| 3 | Press **R** again | Range overlay is dismissed |

### MT-5e.3 — T key toggles Targeting List

| Step | Action | Expected |
|------|--------|----------|
| 1 | Press **T** on the keyboard | Targeting list modal opens |
| 2 | Press **T** again | Modal closes (toggle) |

### MT-5e.4 — Shortcuts disabled during activation

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a ship (drag dial to ship) | Activation modal appears, toolbar buttons disabled |
| 2 | Press **M**, **R**, or **T** | Nothing happens — shortcuts are blocked |
| 3 | Complete/close the activation | Shortcuts work again |

### MT-5e.5 — Shortcuts visible in debug help panel

| Step | Action | Expected |
|------|--------|----------|
| 1 | Press F12 to enter debug mode | Debug help panel appears on left |
| 2 | Look for "Tools" section | "Tools" section header visible below "Camera" |
| 3 | Verify shortcut listing | M → Maneuver Tool, R → Range Overlay, T → Targeting List shown |

### MT-5e.6 — No regressions

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run automated GUT suite | All existing tests pass, 0 failures |
| 2 | All Phase 5a–5d manual tests still pass | M/R/T buttons still work via click |
| 3 | Escape still dismisses tools | Escape key behaviour unchanged |

**Pass criteria:** M/R/T keys toggle their respective tools; shortcuts blocked during activation; shortcuts shown in help panel; existing button clicks and Escape handling unaffected; all tests pass.

---

## Phase 4g — Fixed Round-1 Commands

**What this phase adds:** The learning scenario can optionally pre-assign command dials for round 1 instead of requiring players to pick them manually. When `use_fixed_round1_commands` is `true` in the scenario JSON, the command phase is completely skipped in round 1. Ships begin with their dial stacks pre-filled: CR90 → Repair; Nebulon-B → Navigate (top), Squadron (bottom); VSD → Repair (top), Navigate (middle), Concentrate Fire (bottom). A brief "Round 1 commands pre-assigned" toast appears.

### MT-4g.1 — Game starts in Ship Phase (round 1 skips command phase)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Launch the game board scene (F6) | No command dial picker appears |
| 2 | Observe the HUD phase indicator | Shows "Ship Phase" (not "Command Phase") |
| 3 | Observe the round indicator | Shows round 1 |
| 4 | Check for toast notification | Brief "Round 1 commands pre-assigned" toast appears and auto-hides after ~3 seconds |

### MT-4g.2 — Dial stacks are pre-filled correctly

| Step | Action | Expected |
|------|--------|----------|
| 1 | Click on the CR90 dial stack (own perspective) | Shows 1 hidden dial |
| 2 | Activate CR90 (drag dial to ship) | Revealed dial shows Repair |
| 3 | Check Nebulon-B stack | Shows 2 hidden dials |
| 4 | Activate Nebulon-B (drag top dial to ship) | Revealed dial shows Navigate |
| 5 | Switch to Imperial player, activate VSD | Revealed dial shows Repair |

### MT-4g.3 — Round 2+ command phase works normally

| Step | Action | Expected |
|------|--------|----------|
| 1 | Complete round 1 (activate all ships, end activations) | Round advances to 2 |
| 2 | Observe the round-2 flow | Command dial picker UI appears for each ship |
| 3 | Assign dials normally | Dials assigned; game continues normally |

### MT-4g.4 — Disabling fixed commands restores normal flow

| Step | Action | Expected |
|------|--------|----------|
| 1 | Edit `learning_scenario.json`: set `use_fixed_round1_commands` to `false` | File saved |
| 2 | Launch the game board scene (F6) | Command dial picker appears in round 1 as before |
| 3 | No toast appears | No "pre-assigned" notification |

### MT-4g.5 — No regressions

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run automated GUT suite | 933 tests, 54 scripts, 0 failures |
| 2 | All previous manual tests still pass | No regression in turn management, dial assignment, ship activation |

**Pass criteria:** Round 1 skips command phase; all ships have correct pre-assigned dials in correct stack order; toast appears; round 2+ is normal; toggling `use_fixed_round1_commands: false` restores normal flow; 933 tests pass.

---

*Last updated: Phase 4g — Fixed round-1 commands for the learning scenario.*

---

## Phase 2c — Relaxed Deployment Zones (Debug Mode)

**Requirements covered:** DBG-032 (revised), DBG-033, DBG-034
**Automated tests:** 16 new tests in `test_relaxed_deploy_zones.gd` — TokenMover zone bypass, is_in_deploy_zone checks, play area + collision still enforced.

### MT-2c.1 — Ship crosses deployment zone in debug mode

| Step | Action | Expected |
|------|--------|----------|
| 1 | Launch game board with `--debug-mode` (F12 or CLI) | DEBUG label and blue deployment lines visible |
| 2 | Click an Imperial ship token to select it | Token follows mouse |
| 3 | Drag the ship below the top blue deployment line | Ship moves freely past the line — no clamping |
| 4 | Observe toast notification | "CR90 Corvette A is outside deployment zone" (or ship name) toast appears briefly |
| 5 | Drag the ship back above the line | No toast — token re-entered zone |
| 6 | Drag below again | Toast fires again (one-shot per crossing) |

### MT-2c.2 — Squadron crosses deployment zone in debug mode

| Step | Action | Expected |
|------|--------|----------|
| 1 | Select a Rebel squadron in debug mode | Token follows mouse |
| 2 | Drag it above the bottom blue deployment line | Squadron crosses freely |
| 3 | Observe toast | Toast shows squadron name + "outside deployment zone" |

### MT-2c.3 — Token-token collision still enforced

| Step | Action | Expected |
|------|--------|----------|
| 1 | Drag a ship into another ship (outside deployment zone) | Ship is pushed away from the blocker — collision resolution still works |
| 2 | Drag a squadron into a ship | Same push-out behaviour |

### MT-2c.4 — Play area boundary still enforced

| Step | Action | Expected |
|------|--------|----------|
| 1 | Drag a token toward the edge of the play area | Token stops at the play area boundary — cannot exit |

### MT-2c.5 — Zone enforcement in non-debug mode (future)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Disable debug mode (F12) | Debug HUD disappears, deployment zone lines hidden |
| 2 | Note: Token dragging is only available in debug mode | This test validates that the `enforce_deploy_zones` default is `true` — covered by GUT |

### MT-2c.6 — No regressions

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run automated GUT suite | 949 tests, 55 scripts, 0 failures |
| 2 | All previous manual tests still pass | No regression in existing debug mode features |

**Pass criteria:** Tokens cross deployment zone freely in debug mode; toast fires once per crossing; collision + play area boundaries still enforced; 949 tests pass.

---

## Phase 5d-fix — Squadron Targeting Armament Fix

**Scope:** Ship→squadron targeting uses anti-squadron armament; incoming threats include enemy squadrons at distance 1.

### MT-5d-fix.1 — Ship→squadron shows anti-squadron dice

| Step | Action | Expected |
|------|--------|----------|
| 1 | Place a Victory I (anti-sq: 1 blue) near an enemy X-wing squadron | Targeting list shows the X-wing as an outgoing target with **1 blue die** |
| 2 | Compare with the ship's front battery (3 red) | Dice shown are the anti-squadron armament, **not** the hull zone battery |

### MT-5d-fix.2 — Ship with no anti-squadron armament excludes squadrons

| Step | Action | Expected |
|------|--------|----------|
| 1 | If a ship has empty anti-squadron armament, place an enemy squadron in arc | Squadron does **not** appear as an outgoing target |

### MT-5d-fix.3 — Enemy squadron appears as incoming threat

| Step | Action | Expected |
|------|--------|----------|
| 1 | Place an enemy squadron at close range (distance 1) of a friendly ship | Targeting list shows the squadron in the **incoming threats** section |
| 2 | Move the enemy squadron beyond distance 1 | Squadron disappears from incoming threats |

### MT-5d-fix.4 — No regressions

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run automated GUT suite | 956 tests, 55 scripts, 0 failures |
| 2 | All previous manual tests still pass | No regression in ship→ship targeting or other features |

**Pass criteria:** Anti-squadron armament used for ship→squadron dice; squadron incoming threats appear at distance 1 only; 956 tests pass.

---

## Phase 6a — Attack Simulator: Attacker Declaration

**What this phase adds:** An "A" toolbar button (and keyboard shortcut) that enters an attacker-selection mode. Clicking a hull zone on a ship or clicking a squadron declares it as the attacker, then shows visual aids: range overlay, firing-arc boundary lines extended to map edge (hull zone), LOS marker highlight (hull zone), or close-range circle (squadron). An info panel describes the current step.

### MT-6a.1 — "A" button activates attack simulator

| Step | Action | Expected |
|------|--------|----------|
| 1 | Launch the game board scene (F6) | Board renders with ships, squadrons, and toolbar |
| 2 | Click the **A** button in the bottom-right toolbar | Info panel appears with prompt "Select a hull zone or squadron as the attacker" |
| 3 | Verify button visual state | "A" button appears pressed/active |

### MT-6a.2 — "A" keyboard shortcut activates attack simulator

| Step | Action | Expected |
|------|--------|----------|
| 1 | With no other tool active, press the **A** key | Same info panel appears as MT-6a.1 step 2 |
| 2 | Press **A** again | Info panel disappears; simulator deactivated |

### MT-6a.3 — Hull zone selection shows visual aids

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate attack simulator (A button or key) | Info panel prompts for attacker selection |
| 2 | Click on the **front** hull zone of a friendly ship | Range overlay appears centred on the ship |
| 3 | Observe arc boundary lines | Two thin white lines (≈1.5 px, 60 % opacity) extend from the ship's front arc boundaries to the map edge |
| 4 | Observe LOS marker | A yellow translucent circle (≈6 px, 60 % opacity) appears at the front hull zone's LOS origin |
| 5 | Info panel updates | Panel shows "Attacker: [ship name] — Front" (or similar confirmation) |

### MT-6a.4 — Different hull zones produce different arcs

| Step | Action | Expected |
|------|--------|----------|
| 1 | Cancel current selection (Escape) | Visual aids disappear; back to selection prompt |
| 2 | Click the **left** hull zone of a ship | Arc boundary lines match the left firing arc; LOS marker at left hull zone origin |
| 3 | Cancel and click **right** hull zone | Arc boundary lines match the right firing arc; LOS marker at right origin |
| 4 | Cancel and click **rear** hull zone | Arc boundary lines match the rear firing arc; LOS marker at rear origin |

### MT-6a.5 — Squadron selection shows close-range circle

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate attack simulator | Info panel prompts for attacker selection |
| 2 | Click on a friendly squadron | A white translucent circle (30 % opacity) with radius = close range appears around the squadron |
| 3 | No arc boundary lines or LOS marker | Only the close-range circle is drawn (squadrons have no arcs) |
| 4 | Info panel updates | Panel shows "Attacker: [squadron name]" |

### MT-6a.6 — Escape cancels attack simulator

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate attack simulator and select a hull zone | Visual aids visible |
| 2 | Press **Escape** | All visual aids disappear; info panel dismissed; toolbar button deactivated |
| 3 | Activate again, but press Escape **before** selecting | Info panel dismissed; simulator deactivated cleanly |

### MT-6a.7 — Toggle "A" button cancels attack simulator

| Step | Action | Expected |
|------|--------|----------|
| 1 | Click "A" to activate; visual aids or info panel present | Simulator active |
| 2 | Click "A" again | Everything dismissed — same as Escape |

### MT-6a.8 — Enemy tokens are selectable as attacker

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate attack simulator | Info panel visible |
| 2 | Click on an enemy ship hull zone | Selection occurs; visual aids appear for that hull zone |
| 3 | Cancel, then click on an enemy squadron | Selection occurs; close-range circle appears |

### MT-6a.9 — Other tools deactivate when "A" is pressed

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate the range overlay (R) on a ship | Range overlay visible |
| 2 | Press **A** | Range overlay from R tool dismissed; attack simulator activates |
| 3 | Activate targeting list (T) | Targeting list visible |
| 4 | Press **A** | Targeting list dismissed; attack simulator activates |

### MT-6a.10 — No regressions

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run automated GUT suite | All tests pass, 0 failures, expected script count |
| 2 | Verify M, R, T toolbar buttons still work | Each tool activates and deactivates normally |
| 3 | Ship/squadron dragging in debug mode unaffected | Tokens drag and snap as before |

**Pass criteria:** "A" button and key activate the simulator; hull zone click shows range overlay + arc lines + LOS marker; squadron click shows close-range circle; Escape and toggle dismiss cleanly; both friendly and enemy tokens selectable; no regressions; all GUT tests pass.

---

## Phase 6a-2 — Target Selection & LOS Visualization

**Baseline:** 59 scripts, 1004 tests, 1879 asserts (Phase 6a).

### MT-6a-2.1 — Target hull zone selection

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate attack simulator, select a ship hull zone as attacker | Attacker visuals shown; panel says "Select a target." |
| 2 | Click a hull zone on a **different** ship | Yellow 6 px marker appears on target's LOS targeting point |
| 3 | A yellow/orange/red LOS line connects attacker's LOS point to target's LOS point | Line colour matches LOS result (clear/obstructed/blocked) |
| 4 | Panel updates to show attacker → target identity + LOS result | e.g. "CR90 — FRONT → VSD — LEFT \| LOS: Clear" |

### MT-6a-2.2 — Target squadron selection

| Step | Action | Expected |
|------|--------|----------|
| 1 | Select a ship hull zone as attacker | Attacker visuals shown |
| 2 | Click an enemy squadron | Yellow marker at squadron centre; LOS line from attacker's targeting point to closest point on squadron base |
| 3 | Panel shows attacker → squadron + LOS result | LOS status text is correct |

### MT-6a-2.3 — Squadron attacker → ship target

| Step | Action | Expected |
|------|--------|----------|
| 1 | Select a squadron as attacker | Close-range circle shown |
| 2 | Click a ship hull zone | Yellow marker at target's LOS point; LOS line from closest point on squadron base to target's targeting point |
| 3 | Panel shows squadron → ship hull zone + LOS result | LOS status text matches line colour |

### MT-6a-2.4 — Squadron attacker → squadron target

| Step | Action | Expected |
|------|--------|----------|
| 1 | Select a squadron as attacker | Close-range circle shown |
| 2 | Click a different squadron | Yellow marker at target centre; LOS line from closest point on attacker base to closest point on target base |
| 3 | Panel shows squadron → squadron + LOS result | Expected: "Clear" if no ship blocks the line |

### MT-6a-2.5 — Target deselection (click target again)

| Step | Action | Expected |
|------|--------|----------|
| 1 | With both attacker and target selected | LOS line + target marker visible |
| 2 | Click the **target** hull zone / squadron again | Target marker and LOS line disappear; attacker visuals remain |
| 3 | Panel returns to "Select a target." | Attacker identity still shown |
| 4 | Click a new target | New LOS line + marker appear |

### MT-6a-2.6 — Both deselection (click attacker)

| Step | Action | Expected |
|------|--------|----------|
| 1 | With both attacker and target selected | LOS line + both markers visible |
| 2 | Click the **attacker** hull zone / squadron | All visuals removed (including arc lines and range overlay) |
| 3 | Panel returns to "Select a hull zone or squadron as the attacker." | Full reset to initial state |

### MT-6a-2.7 — LOS colour coding

| Step | Action | Expected |
|------|--------|----------|
| 1 | Select attacker and target with clear LOS path | Yellow line (`Color(1.0, 1.0, 0.0, 0.8)`) |
| 2 | Select attacker and target with an intervening ship between them | Orange line (`Color(1.0, 0.6, 0.0, 0.8)`); panel says "Obstructed by [ship]" |
| 3 | Select attacker and target where LOS enters defender through wrong hull zone | Red line (`Color(1.0, 0.0, 0.0, 0.6)`); panel says "Blocked" |

### MT-6a-2.8 — No regressions

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run automated GUT suite | All tests pass, 0 failures, expected script count |
| 2 | Verify Phase 6a attacker selection still works | Attacker visuals appear correctly |
| 3 | Escape cancels at any point (attacker only, attacker+target) | Clean dismiss, no orphaned visuals |
| 4 | M, R, T toolbar buttons still work | No interference |

**Pass criteria:** Target selection works for all four attacker/target combinations (ship→ship, ship→squad, squad→ship, squad→squad); LOS line colour matches trace result; deselection (target re-click, attacker click, Escape) all behave correctly; panel text updates properly; no regressions; all GUT tests pass.

---

## Phase 6a-3 — Same-Ship Guard, Arc Validation & Range Line

**What this phase adds:** Three validation/visualisation improvements to the Attack Simulator target selection: (1) Hull zones on the same ship as the attacker cannot be selected as the target — a tooltip reading "Cannot target the same ship." appears briefly. (2) If the target is not inside the attacker's firing arc, the click is rejected with a tooltip "Defender is not in arc." (3) A range measurement line is drawn alongside the LOS line, coloured by range band (grey = close, blue = medium, red = long, purple = beyond). The range line connects the closest points on the attacking and defending geometries. The panel body now also shows the range band.

**Prerequisites:** Phase 6a-2 committed and working. Learning Scenario board visible.

### MT-6a-3.1 — Same-ship guard

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate "A", click a hull zone on a ship to select attacker | Attacker visuals shown; panel says "Select a target." |
| 2 | Click a **different** hull zone on the **same** ship | Click rejected; tooltip "Cannot target the same ship." appears for ~2 s |
| 3 | Click a hull zone on a **different** ship | Target accepted normally; LOS + range line drawn |

### MT-6a-3.2 — Arc check — ship target not in arc

| Step | Action | Expected |
|------|--------|----------|
| 1 | Select a hull zone attacker (e.g. FRONT) | Attacker visuals with arc lines |
| 2 | Click a hull zone on a ship that is clearly **behind** the attacker (not in the front arc) | Click rejected; tooltip "Defender is not in arc." appears for ~2 s |
| 3 | Click a hull zone on a ship that **is** inside the front arc | Target accepted; LOS + range line drawn |

### MT-6a-3.3 — Arc check — squadron target not in arc

| Step | Action | Expected |
|------|--------|----------|
| 1 | Select a hull zone attacker (e.g. LEFT) | Attacker visuals shown |
| 2 | Click a squadron that is outside the left arc | Click rejected; tooltip "Defender is not in arc." |
| 3 | Click a squadron that is inside the left arc | Target accepted; LOS + range line drawn |

### MT-6a-3.4 — Squadron attacker skips arc check

| Step | Action | Expected |
|------|--------|----------|
| 1 | Select a squadron as attacker | Close-range circle shown |
| 2 | Click a hull zone on a ship in any direction | Target accepted (no arc restriction); LOS + range line drawn |
| 3 | Click a different squadron in any direction | Target accepted; both lines drawn |

### MT-6a-3.5 — Range line colour coding

| Step | Action | Expected |
|------|--------|----------|
| 1 | Select attacker and target at close range | Grey range line (`Color(0.7, 0.7, 0.7, 0.8)`) |
| 2 | Select attacker and target at medium range | Blue range line (`Color(0.2, 0.4, 1.0, 0.8)`) |
| 3 | Select attacker and target at long range | Red range line (`Color(1.0, 0.15, 0.15, 0.8)`) |
| 4 | Select attacker and target beyond ruler range | Purple range line (`Color(0.6, 0.1, 0.9, 0.8)`) |

### MT-6a-3.6 — Both lines drawn simultaneously

| Step | Action | Expected |
|------|--------|----------|
| 1 | Select attacker hull zone and target hull zone | Two lines visible: LOS line (yellow/orange/red by LOS result) and range line (grey/blue/red/purple by range band) |
| 2 | Note that the lines have **different endpoints** | LOS line goes targeting-point → targeting-point; range line goes closest-edge-point → closest-edge-point |
| 3 | Deselect target (click target again) | Both lines disappear; attacker visuals remain |

### MT-6a-3.7 — Panel shows range band

| Step | Action | Expected |
|------|--------|----------|
| 1 | Select attacker and target at medium range with clear LOS | Panel body: "LOS: Clear · Range: Medium" |
| 2 | Select attacker and target at long range with obstructed LOS | Panel body: "LOS: Obstructed by [ship] · Range: Long" |
| 3 | Select attacker and target beyond range | Panel body includes "Range: Beyond" |

### MT-6a-3.8 — No regressions

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run automated GUT suite | All tests pass, 0 failures, expected script count |
| 2 | Verify Phase 6a attacker selection still works | Attacker visuals appear correctly |
| 3 | Verify Phase 6a-2 LOS line + deselection still works | Colour-coded LOS line, deselection behaviour unchanged |
| 4 | Escape cancels at any point | Clean dismiss, no orphaned visuals |
| 5 | M, R, T toolbar buttons still work | No interference |

**Pass criteria:** Same-ship clicks rejected with tooltip; out-of-arc clicks rejected with tooltip; squadron attackers bypass arc check; range line drawn with correct colour for each band; both LOS and range lines visible simultaneously; panel shows range band text; no regressions; all GUT tests pass.

---

## Phase 6a-4 — Hull-Zone Edge Polyline Fix (HZ-EDGE-001)

**What this phase fixes:** Hull-zone edges were previously approximated using rectangle corners. FRONT and REAR edges now use polylines derived from arc boundary outer points + template corners. This affects arc validation, range measurement, and targeting lists — especially for the VSD where the FRONT arc wraps around corners.

> **Automated coverage note:** The fix is primarily in `RangeFinder` (pure logic) and is covered by 10 new GUT tests. The manual tests below verify visual correctness that cannot be checked automatically.

### MT-6a-4.1 — VSD front-arc targeting uses correct edge geometry

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run the board scene with two ships: a VSD (Imperial) facing a CR90 (Rebel), positioned so the CR90 is directly ahead of the VSD | Both ships visible on board |
| 2 | Press **A** to open attack simulator. Click VSD FRONT hull zone as attacker | FRONT arc lines drawn correctly |
| 3 | Click CR90 hull zone as target | Target accepted; LOS line + range line drawn to the correct hull zone edge, not the full template width |
| 4 | Position CR90 near the edge of the VSD's FRONT arc (close to the boundary line) | Range line endpoint tracks the nearest in-arc point of the CR90's edge, not the rectangle corner |

### MT-6a-4.2 — Targeting list shows correct ranges after fix

| Step | Action | Expected |
|------|--------|----------|
| 1 | Press **T** to open targeting list | Modal opens |
| 2 | Check range band for VSD FRONT → CR90 target | Range band matches the visual range line colour from MT-6a-4.1 |
| 3 | Check that LEFT/RIGHT hull zones from targeting list match visual arcs | Edge geometry does not extend beyond the actual arc boundaries |

### MT-6a-4.3 — No regressions

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run automated GUT suite | 59 scripts, 1055 tests, 1963 asserts, 0 new failures |
| 2 | Verify Phase 6a attacker selection still works | Attacker visuals appear correctly |
| 3 | Verify Phase 6a-3 range line + LOS line still works | Both lines visible, colour-coded correctly |
| 4 | Press T — targeting list still functional | All entries present, no crashes |

**Pass criteria:** VSD front edge wraps corners correctly; range measurements use arc-derived polylines; targeting list results consistent with visual range lines; no regressions; all GUT tests pass.

---

## Phase 6b-1 — Attack Execution: Target Selection & Visuals

**What this phase adds:** During a ship's activation, the Attack step now has an "Execute Attack ►" button. Pressing it closes the activation modal, shows the range overlay, and enters a target-selection flow. The player selects an attacking hull zone, then a target. LOS markers and LOS line are drawn (no arc lines, no range line). The dice pool is computed by colour and displayed. A "Done" button completes the attack step and re-opens the activation modal.

> **Automated coverage note:** `DicePool` (range filtering, formatting) is fully covered by 19 GUT tests. Manual tests below verify the interactive selection flow, visual correctness, and modal integration.

### MT-6b-1.1 — Execute Attack button appears and works

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a ship: click it, assign a command, drop the dial | Ship activated, "Show Activation Sequence" button appears |
| 2 | Click "Show Activation Sequence" | Activation modal opens; Squadron and Repair steps auto-skip |
| 3 | Modal stops at step 4 (Attack) | "Execute Attack ►" button visible and enabled |
| 4 | Click "Execute Attack ►" | Modal closes; range overlay appears around the activated ship; info panel appears below ship with prompt "Select attacking hull zone." |

### MT-6b-1.2 — Hull zone selection and target selection

| Step | Action | Expected |
|------|--------|----------|
| 1 | After step 4 above, click a hull zone on the activated ship | Yellow LOS marker appears on the hull zone; no arc boundary lines drawn; panel updates to "Select a target." |
| 2 | Click a hull zone on an enemy ship | Yellow LOS marker on target; yellow LOS line drawn between attacker and target; panel shows LOS status and range band |
| 3 | Dice count appears in the panel | Shows colour breakdown (e.g. "Dice: 2 red, 1 blue"); "Done" button visible |

### MT-6b-1.3 — Deselection behaviour

| Step | Action | Expected |
|------|--------|----------|
| 1 | With both selected, click target again | Target deselected; LOS line disappears; dice count hidden; attacker hull zone and LOS marker remain |
| 2 | Click a different enemy hull zone | New target selected; LOS line redrawn; dice count updated |
| 3 | Click the attacker hull zone | Both attacker and target deselected; range overlay restored; panel shows initial prompt |

### MT-6b-1.4 — Faction guard and activation guard

| Step | Action | Expected |
|------|--------|----------|
| 1 | Try clicking a non-activated friendly ship as attacker | Tooltip: "Only the activated ship can attack." — click rejected |
| 2 | Try clicking a friendly ship as target | Tooltip: "Cannot target a friendly ship." — click rejected |
| 3 | Try clicking a friendly squadron as target | Tooltip: "Cannot target a friendly squadron." — click rejected |
| 4 | Try clicking a squadron as attacker | Tooltip: "Select a hull zone on the activated ship." — click rejected |

### MT-6b-1.5 — Attack vs squadron shows anti-squadron armament

| Step | Action | Expected |
|------|--------|----------|
| 1 | Select a hull zone on the activated ship | Attacker selected |
| 2 | Click an enemy squadron | Target marker appears; LOS line drawn; dice count shows anti-squadron armament (e.g. "1 blue") |

### MT-6b-1.6 — Done button and Escape behaviour

| Step | Action | Expected |
|------|--------|----------|
| 1 | With target selected, click "Done" | Attack visuals dismissed; activation modal re-opens at Maneuver step; Attack step shows checkmark |
| 2 | Alternatively: press Escape during target selection | Attack cancelled; activation modal re-opens at Attack step (not advanced) |

### MT-6b-1.7 — No visual differences: no arc lines, no range line

| Step | Action | Expected |
|------|--------|----------|
| 1 | Select hull zone + target during attack execution | Only LOS markers and LOS line visible — NO arc boundary lines extending from the hull zone, NO range measurement line |
| 2 | Dismiss and use attack simulator (A key) with same ship | Arc boundary lines AND range line now visible (simulator mode unchanged) |

### MT-6b-1.8 — No regressions

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run automated GUT suite | 60 scripts, 1074 tests, 1989 asserts, 0 new failures |
| 2 | Verify attack simulator (A key) still works | All simulator visuals and behaviour unchanged |
| 3 | Verify maneuver step still works | Execute Maneuver button appears and functions correctly |
| 4 | Verify M, R, T toolbar buttons still work | No interference |
| 5 | Escape cancels at any point | Clean dismiss, no orphaned visuals |

**Pass criteria:** Execute Attack button appears at Attack step; hull zone selection shows only LOS markers (no arc lines); target selection shows LOS line + dice count; faction guards reject friendly targets; "Done" completes attack step; Escape cancels; attack simulator unaffected; all GUT tests pass.

---

## Phase 6b-2 — Attack Execution: Dice Rolling, Concentrate Fire & Two-Hull-Zone Sequencing

**What this phase adds:** After target selection, the player can optionally spend a Concentrate Fire dial to add a die, roll the dice pool (shown as die-face PNG images), optionally spend a CF token to reroll one die, then confirm the attack. The sequence supports two hull zone attacks per activation with the first zone marked as spent (red dot). Damage resolution is skipped for now.

> **Automated coverage note:** `DicePool.to_engine_pool()` and `Dice.get_face_image_path()` are covered by GUT tests. Manual tests below verify the interactive CF dial/token flow, dice display, two-hull-zone sequencing, and skip behaviour.

### MT-6b-2.1 — Concentrate Fire dial adds a die

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a ship with a Concentrate Fire command dial (keep as dial, do not convert) | Ship activated with CF dial visible behind base |
| 2 | Press "Execute Attack ►", select a hull zone, select an enemy target | Dice count shown (e.g. "Dice: 2 red, 1 blue") |
| 3 | Panel shows "Spend CF dial for +1 die?" with colour buttons | Only colours in the hull zone's armament appear (e.g. [+ Red] [+ Blue] for CR90 FRONT) |
| 4 | Press a colour button (e.g. [+ Red]) | Dice count updates (e.g. "Dice: 3 red, 1 blue"); CF dial sprite disappears from ship token; colour buttons removed |
| 5 | "Roll Dice" button now visible | Button is clickable |

### MT-6b-2.2 — Concentrate Fire dial can be skipped

| Step | Action | Expected |
|------|--------|----------|
| 1 | Same setup as MT-6b-2.1 (CF dial kept) | CF dial prompt appears |
| 2 | Press "Skip" on the CF dial prompt | Dice count unchanged; "Roll Dice" button appears; CF dial sprite remains on ship |

### MT-6b-2.3 — Dice rolling shows face images

| Step | Action | Expected |
|------|--------|----------|
| 1 | After CF dial decision (or immediately if no CF dial), press "Roll Dice" | Die face PNG images appear in a horizontal row (~32×32 px each) |
| 2 | Each die image matches its colour (red/blue/black) and shows a valid face | Images loaded from `Resources/Game_Components/dice/` |
| 3 | "Roll Dice" button disappears | Dice count label replaced by actual die images |

### MT-6b-2.4 — Concentrate Fire token reroll

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a ship that holds a CF command token (from a previous round's conversion) | Token visible in ship card panel |
| 2 | Execute attack, select hull zone + target, roll dice | Dice results shown; "Spend CF token to reroll 1 die?" prompt appears |
| 3 | Click a die image | Selected die gets a yellow border highlight |
| 4 | Press "Reroll" | Selected die re-rolled; new face image replaces old; reroll UI removed; CF token removed from ship |

### MT-6b-2.5 — CF token reroll can be skipped

| Step | Action | Expected |
|------|--------|----------|
| 1 | Same setup as MT-6b-2.4 | CF token reroll prompt visible |
| 2 | Press "Skip" | Reroll UI removed; CF token remains on ship; "Confirm" button appears |

### MT-6b-2.6 — Confirm ends current attack (damage skipped)

| Step | Action | Expected |
|------|--------|----------|
| 1 | After dice rolled (and optional reroll), press "Confirm" | Current hull zone attack ends; no damage applied to target; log shows dice results |
| 2 | Panel transitions to second hull zone selection | Prompt: "Select second attacking hull zone." |

### MT-6b-2.7 — Two hull zone sequencing with red dot

| Step | Action | Expected |
|------|--------|----------|
| 1 | After first hull zone Confirm | First hull zone's LOS marker has a translucent red dot (6 px) |
| 2 | Try clicking the first (spent) hull zone | Tooltip: "This hull zone has already attacked." — click rejected |
| 3 | Select a different hull zone | Hull zone accepted; target selection proceeds |
| 4 | Select target, roll dice, Confirm | Second hull zone attack complete; attack step finishes |
| 5 | Activation modal re-opens | Attack step shows checkmark; Maneuver step is active |

### MT-6b-2.8 — Skip first hull zone, still get second opportunity

| Step | Action | Expected |
|------|--------|----------|
| 1 | During hull zone selection, press "Skip Attack" | First hull zone skipped; transitions to second hull zone opportunity (no red dot) |
| 2 | Select a hull zone, target, roll, Confirm | Second attack completes; attack step done |

### MT-6b-2.9 — Skip both hull zones

| Step | Action | Expected |
|------|--------|----------|
| 1 | Press "Skip Attack" during first hull zone selection | Transitions to second hull zone opportunity |
| 2 | Press "Skip Attack" again | Attack step complete; activation modal re-opens with Attack checkmarked |

### MT-6b-2.10 — CF dial available for second hull zone if not spent on first

| Step | Action | Expected |
|------|--------|----------|
| 1 | CF dial kept; skip the CF dial prompt during first hull zone attack (press "Skip") | CF dial not spent |
| 2 | After first Confirm, select second hull zone + target | CF dial prompt appears again for the second attack |
| 3 | Spend it this time | Die added; dial sprite hidden; dial spent |

### MT-6b-2.11 — No regressions

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run automated GUT suite | Expected script count, expected test count, 0 new failures |
| 2 | Verify attack simulator (A key) still works | All simulator visuals unchanged |
| 3 | Verify Phase 6b-1 target selection still works | LOS markers, LOS line, faction guards |
| 4 | Verify maneuver step still works | Execute Maneuver functions correctly |
| 5 | Escape cancels at any point | Clean dismiss, no orphaned visuals |

**Pass criteria:** CF dial adds a die and spends the dial; CF token rerolls one die and spends the token; dice face PNGs displayed correctly; two hull zone attacks work with red dot and zone blocking; skip buttons work at all stages; no damage applied (placeholder); no regressions; all GUT tests pass.

---

## Phase 6b-3 — Anti-Squadron Multi-Target Sequencing

**What this phase adds:** After confirming an attack against an enemy squadron, the ship can declare another enemy squadron in the same arc as the next target (Rules Reference: "Attack", Step 6). Each attacked squadron gets a red dot marker. The loop continues until no eligible targets remain or the player presses Skip.

### Setup

Open `src/scenes/game_board/game_board.tscn` and press **F6**. Position the Rebel ships so that at least two Imperial/enemy squadrons are within the same firing arc at attack range (or use the Learning Scenario default placement where the X-wing and TIE Fighter may be in arc).

---

### MT-6b-3.1 — Squadron attack loop basic flow

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a Rebel ship, reach Attack step | Attack panel appears: "Select attacking hull zone." |
| 2 | Click a hull zone that has enemy squadrons in arc | Panel: "Attacking: {ship} — {zone} arc / Select a target." |
| 3 | Click an enemy squadron in that arc | LOS line + range shown; dice count + CF dial (if available) shown |
| 4 | Complete the dice sequence: CF dial → Roll → optional Reroll → Confirm | Dice results confirmed; red dot appears on the squadron's centre |
| 5 | If another enemy squadron remains in arc | Panel: "{ship} — {zone} arc / Select next squadron in arc, or Skip." |
| 6 | Click the next enemy squadron | LOS + range + dice for the new squadron; new attack sequence starts |
| 7 | Complete and Confirm | Second red dot on that squadron; loop continues or finishes |

**Pass criteria:** Each confirmed squadron shows a red dot; the full dice sequence repeats per squadron; hull zone stays locked throughout.

---

### MT-6b-3.2 — Already-attacked squadron guard

| Step | Action | Expected |
|------|--------|----------|
| 1 | Complete an attack against a squadron (Step 4 above) | Red dot on that squadron |
| 2 | During "Select next squadron" prompt, click the already-attacked squadron | Tooltip: "{name} has already been attacked." — target not set |

**Pass criteria:** Already-attacked squadrons are blocked with a tooltip.

---

### MT-6b-3.3 — Hull zone locked during squadron loop

| Step | Action | Expected |
|------|--------|----------|
| 1 | During "Select next squadron" prompt, click the attacker ship's hull zone | Tooltip: "Hull zone is locked during anti-squadron attacks." — not deselected |

**Pass criteria:** Hull zone cannot be deselected during the anti-squadron loop.

---

### MT-6b-3.4 — Skip during squadron loop

| Step | Action | Expected |
|------|--------|----------|
| 1 | After attacking one squadron, see "Select next squadron" prompt | Skip Attack button visible |
| 2 | Press Skip Attack | Loop ends; hull zone marked as fired (red dot on zone LOS); proceeds to second hull zone selection (or finishes if second HZ already done) |

**Pass criteria:** Skip ends the squadron loop and moves to second hull zone — does NOT end the entire attack step.

---

### MT-6b-3.5 — No more targets auto-finishes loop

| Step | Action | Expected |
|------|--------|----------|
| 1 | Position so only one enemy squadron is in the arc | |
| 2 | Attack and Confirm against that squadron | Red dot on squadron; no "select next" prompt; hull zone marked as fired; proceeds to next hull zone or finishes |

**Pass criteria:** Loop auto-finishes when no eligible targets remain.

---

### MT-6b-3.6 — No regressions

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run automated GUT suite | 60 scripts, 1107 tests, 0 new failures |
| 2 | Verify ship-vs-ship attack (two hull zones) still works | Red dots on HZ LOS, zone blocking, same as Phase 6b-2 |
| 3 | Escape cancels at any point | Clean dismiss |

**Pass criteria:** All Phase 6b-2 behaviours unchanged; GUT passes; anti-squadron loop works per MT-6b-3.1–5.

---

## Phase 6c — Attack Steps 3–5: Accuracy, Defense Tokens & Damage Resolution

**What this phase adds:** After dice confirmation, the attacker can spend accuracy
icons to lock the defender's defense tokens. The defender then spends defense tokens
(Scatter, Evade, Brace, Redirect, Contain) to modify damage. Finally, damage is
resolved: shields absorb first, then hull damage cards are dealt (with standard
critical effect), and ships/squadrons are destroyed if damage exceeds hull.

### Setup

Open `src/scenes/game_board/game_board.tscn` and press **F6**. Start a game with the
Learning Scenario. Advance to a ship activation and initiate an attack against an enemy
ship (select hull zone, target, roll dice, confirm with Confirm Attack).

---

### MT-6c.1 — Accuracy spending (skip when no accuracies)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Attack and confirm dice that contain NO accuracy icons | No accuracy section shown; proceeds directly to defense step |
| 2 | Attack a target that has no defense tokens (e.g. a squadron) | No accuracy section even if dice have accuracy icons; skips to defense/damage |

**Pass criteria:** Accuracy step is auto-skipped when irrelevant.

---

### MT-6c.2 — Accuracy spending (interactive)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Attack with dice that have ≥1 accuracy icon against a defender with defense tokens | Accuracy section appears: "Spend accuracies to lock tokens (0/N)" with defender's token buttons |
| 2 | Click a token button to toggle it ON | Button turns green/highlighted; count updates: "(1/N)" |
| 3 | Click the same button again | Button toggles OFF; count back to "(0/N)" |
| 4 | Toggle tokens ON up to accuracy budget, then try one more | Extra toggle has no effect — budget enforced |
| 5 | Click "Confirm Accuracy" | Accuracy section hides; proceeds to defense step with locked tokens excluded |

**Pass criteria:** Toggling works within budget; locked tokens cannot be spent in defense.

---

### MT-6c.3 — Defense token spending (basic flow)

| Step | Action | Expected |
|------|--------|----------|
| 1 | After accuracy step, see defense section | Camera rotates to defender; defense section shows spendable tokens with current damage total and "Commit Defense" button |
| 2 | Click a READY token (e.g. Brace) | Button turns **green** with a **✓** suffix — token is *selected* but not yet spent |
| 3 | Click "Commit Defense" | Token is exhausted; damage updates (halved, rounded up); defense section hides; damage resolution begins |

**Pass criteria:** Token selection → commit two-phase flow works; visual highlight on selected token.

---

### MT-6c.3a — Defense token deselect before commit

| Step | Action | Expected |
|------|--------|----------|
| 1 | In defense section, click a READY token | Button turns green with ✓ (selected) |
| 2 | Click the same token again | Green highlight and ✓ removed — token returns to original colour (white for ready, orange for exhausted) |
| 3 | Verify `get_defense_selected_indices()` is empty | No tokens selected |
| 4 | Click "Commit Defense" with no tokens selected | Defense step ends immediately; damage resolution proceeds with unmodified damage |

**Pass criteria:** Deselection restores visual state; committing with no selection skips defense.

---

### MT-6c.3b — One-per-type enforcement during selection

| Step | Action | Expected |
|------|--------|----------|
| 1 | Defender has two Redirect tokens (one READY, one EXHAUSTED) | Both shown as clickable buttons |
| 2 | Click the READY Redirect | Green ✓ highlight |
| 3 | Click the EXHAUSTED Redirect | First Redirect deselected (returns to white); second one highlighted green ✓ |
| 4 | Select an Evade (different type) alongside Redirect | Both tokens highlighted — different types allowed simultaneously |

**Pass criteria:** Only one token of each type can be selected; selecting a second same-type auto-deselects the first.

---

### MT-6c.3c — Commit queue with Evade + Redirect

| Step | Action | Expected |
|------|--------|----------|
| 1 | Select Evade **and** Redirect tokens, then click "Commit Defense" | All token buttons disabled; commit button hidden |
| 2 | Evade sub-step: dice become clickable (cyan tint) | Pick a die — die removed/rerolled, queue continues |
| 3 | Redirect sub-step: zone buttons appear with "Done Redirecting" button | Click zones to redirect damage, or click "Done Redirecting" to finish early |
| 4 | After all tokens processed | Defense section hides; damage resolution begins |

**Pass criteria:** Multiple selected tokens processed sequentially through queue; evade and redirect sub-steps pause and resume correctly.

---

### MT-6c.4 — Defense token: Scatter

| Step | Action | Expected |
|------|--------|----------|
| 1 | Defender spends Scatter token | Damage drops to 0; defense step ends immediately; no further tokens can be spent |

**Pass criteria:** Scatter cancels all damage and immediately ends defense.

---

### MT-6c.5 — Defense token: Evade (long range)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Attack at long range; defender spends Evade | Dice become clickable with cyan tint; prompt says "click a die to remove" |
| 2 | Click a die of your choice | The clicked die is removed from the pool; damage total decreases; dice return to normal |

**Pass criteria:** Defender manually selects which die to remove at long range.

---

### MT-6c.6 — Defense token: Evade (medium/close range)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Attack at medium or close range; defender spends Evade | Dice become clickable with cyan tint; prompt says "click a die to reroll" |
| 2 | Click a die of your choice | The clicked die is rerolled; damage total may change; dice return to normal |

**Pass criteria:** Defender manually selects which die to reroll at medium/close.

---

### MT-6c.6a — Defense token: Brace (deferred to Step 5)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Defender spends Brace token | Damage label shows "Modified damage: N (Brace pending → M)" where M = ceil(N/2); damage is NOT halved yet |
| 2 | Defender clicks "Done" to end defense step | Damage resolution applies brace: final damage is halved (rounded up) |
| 3 | Defender spends Evade AFTER Brace | Evade modifies dice normally; brace pending preview updates to reflect new total |

**Pass criteria:** Brace halving deferred to Step 5; pending indicator shown during Step 4; Evade+Brace interaction correct.

---

### MT-6c.7 — Defense token: Redirect

| Step | Action | Expected |
|------|--------|----------|
| 1 | Defender spends Redirect | Redirect section appears showing adjacent hull zones with remaining redirect capacity |
| 2 | Click an adjacent hull zone button | 1 damage redirected to that zone's shields; remaining count decreases |
| 3 | Click again (if capacity remains) | Another damage redirected |
| 4 | All redirect capacity spent or shields exhausted | Redirect section auto-closes; returns to defense token selection |

**Pass criteria:** Per-click redirect allocation to adjacent zones; limited by shields.

---

### MT-6c.8 — Defense tokens: speed 0 block

| Step | Action | Expected |
|------|--------|----------|
| 1 | Set defender speed to 0 (if possible) and attack | Defense step is auto-skipped; no tokens can be spent; log message indicates speed 0 |

**Pass criteria:** Speed 0 defenders cannot spend defense tokens per rules.

---

### MT-6c.9 — Defense token: exhausted must discard

| Step | Action | Expected |
|------|--------|----------|
| 1 | Exhaust a defender token in one attack | Token shows exhausted state |
| 2 | In a subsequent attack, spend the same token (now exhausted) | Token is discarded (removed permanently); effect still applies |

**Pass criteria:** EXHAUSTED tokens are discarded on spend, not just re-exhausted.

---

### MT-6c.10 — Damage resolution: ship (shields absorb)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Attack a ship with shields remaining in the attacked zone | Damage info section shows: "Damage: N → Zone shields: M → Shields absorb K, hull takes J" |
| 2 | After resolution | Ship's shield count on the attacked zone decreases; damage cards visible on ship if hull damage dealt |

**Pass criteria:** Shields absorb damage first; remaining goes to hull as cards.

---

### MT-6c.11 — Damage resolution: standard critical

| Step | Action | Expected |
|------|--------|----------|
| 1 | Attack with a critical icon in the dice pool; no Contain token spent | First damage card dealt to hull is faceup (critical effect) |
| 2 | Same attack but defender spends Contain | All hull damage cards are facedown (standard crit blocked) |

**Pass criteria:** Standard critical makes first card faceup unless Contain used.

---

### MT-6c.12 — Ship destruction

| Step | Action | Expected |
|------|--------|----------|
| 1 | Deal enough damage to a ship so total damage ≥ hull value | Ship is removed from the board (hidden); `ship_destroyed` log entry appears |

**Pass criteria:** Ship destroyed and removed when damage reaches hull.

---

### MT-6c.13 — Squadron damage resolution

| Step | Action | Expected |
|------|--------|----------|
| 1 | Attack an enemy squadron (from anti-squadron armament) | Damage dealt directly to squadron hull (no shields) |
| 2 | Deal enough damage to destroy the squadron | Squadron hidden from board; `squadron_destroyed` log entry |

**Pass criteria:** Squadron takes direct hull damage; destroyed when hull ≤ 0.

---

### MT-6c.14 — Full attack flow end-to-end

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a ship attack: select hull zone → target ship → roll dice → confirm | Accuracy step (if applicable) |
| 2 | Complete accuracy spending | Defense step begins with camera rotation |
| 3 | Select defense tokens (click to highlight green ✓, mix of types) | Tokens highlighted but not yet spent |
| 4 | Click "Commit Defense" | Tokens spent sequentially; damage updated; evade/redirect sub-steps pause queue |
| 5 | After all tokens processed | Damage resolved: shields absorb, cards dealt |
| 5 | After 1.2s delay | Attack finalizes; proceeds to second hull zone or attack done |
| 6 | Complete second hull zone attack | Ship's attack step fully complete |

**Pass criteria:** Complete attack flow from declaration through damage, including two hull zones.

---

### MT-6c.15 — No regressions

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run automated GUT suite | 64 scripts, 1173 tests, 0 new failures |
| 2 | Verify dice rolling + CF dial/token still works | Same as Phase 6b-2 |
| 3 | Verify anti-squadron loop still works | Same as Phase 6b-3 |
| 4 | Escape cancels at any point | Clean dismiss |

**Pass criteria:** All prior phase behaviours unchanged; GUT passes; full attack sequence works per MT-6c.1–14.

---

### MT-6c.16 — Auto-skip attack when no valid targets

| Step | Action | Expected |
|------|--------|----------|
| 1 | Position a ship far from all enemies (no targets in any arc/range) | Ship on board with no reachable enemies |
| 2 | Activate the ship and enter the Attack step via the activation modal | Attack step auto-skips immediately; log shows "No valid targets from any hull zone — auto-skipping"; activation advances to Maneuver step |
| 3 | Verify the activation modal re-opens | Activation modal shows with Maneuver step active |

**Pass criteria:** Ship with no valid targets auto-skips the entire attack step without requiring player interaction.

---

### MT-6c.17 — Skip Attack button at hull zone selection

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a ship and enter the Attack step | Attack panel appears with "Select attacking hull zone" prompt AND a visible "Skip Attack" button |
| 2 | Click "Skip Attack" without selecting a hull zone | Confirmation prompt appears: "Really skip attack?" with Yes / No buttons; Skip Attack button hidden |
| 3 | Click "No" | Confirmation dismissed; Skip Attack button reappears |
| 4 | Click "Skip Attack" again, then click "Yes" | Attack step ends cleanly; activation advances to Maneuver step |

**Pass criteria:** Player can skip attacks at any point, even before selecting a hull zone. Skipping requires Yes/No confirmation.

---

### MT-6c.18 — Auto-skip second attack when no remaining targets

| Step | Action | Expected |
|------|--------|----------|
| 1 | Attack from one hull zone and resolve damage normally | First attack completes; board transitions to second hull zone selection |
| 2 | If no valid targets exist from any remaining unfired hull zone | Second attack auto-skips; attack step ends; activation advances to Maneuver |

**Pass criteria:** Second attack auto-skips when no remaining hull zones have valid targets.

---

### MT-6c.19 — Attack step auto-checkmarked in modal when no targets

| Step | Action | Expected |
|------|--------|----------|
| 1 | Place ships so the activating ship has no enemy in arc/range from any hull zone | Setup: e.g. place enemy off-board or far beyond range |
| 2 | Activate the ship (reveal dial) and press "Show Activation Sequence" | Activation modal opens |
| 3 | Observe the auto-skip sequence | Squadron → Repair → **Attack** all auto-skip with 0.3s delays; Attack row briefly shows "No targets" badge in amber |
| 4 | After auto-skip finishes | Maneuver step is the active step; Attack row shows ✓ checkmark; "Execute Attack ►" button was **never** shown |

**Pass criteria:** When no valid targets exist, the Attack step is auto-skipped in the modal without showing the Execute Attack button. The player proceeds directly to the Maneuver step.

---

## Post-Phase-5d LOS Bug Fix

**What this fix changes:** `LineOfSightChecker._los_blocked_by_other_hull_zone()` now classifies the LOS entry point by its position on the defender's base (1/3-length division) instead of assigning the entire rectangle edge to one hull zone. This corrects false "LOS Blocked" results when the entry point is in the correct hull zone but on a side edge.

### MT-LOS-FIX.1 — Nebulon-B RIGHT arc → VSD REAR is now clear

| Step | Action | Expected |
|------|--------|----------|
| 1 | Place Nebulon-B roughly abeam and slightly behind the VSD (so the RIGHT arc faces the VSD's rear quarter) | Both ships on board |
| 2 | Open the Targeting List (T button) | Targeting modal shows outgoing targets from Nebulon-B |
| 3 | Check that VSD REAR appears as a valid target from the Nebulon-B RIGHT arc | REAR zone listed with range and dice; LOS status is "Clear" or "Obstructed" (not "Blocked") |

**Pass criteria:** The Nebulon-B can target the VSD's REAR hull zone from its RIGHT arc when positioned abeam. LOS is no longer falsely blocked.

### MT-LOS-FIX.2 — LOS entering the correct hull zone through a side edge

| Step | Action | Expected |
|------|--------|----------|
| 1 | Place an attacker directly to the LEFT of a defender | Attacker abeam defender |
| 2 | Open Targeting List from attacker's perspective | Modal shows targets |
| 3 | Look at LEFT zone entry | LEFT zone is reachable (LOS line enters LEFT edge in the LEFT zone) |
| 4 | Look at RIGHT zone entry | RIGHT zone is blocked (LOS would cross the base from LEFT zone to RIGHT zone) |

**Pass criteria:** LOS correctly allows targeting zones whose portion of the side edge is crossed by the LOS line, and blocks zones where the line enters through a different hull zone.

---

## Post-Phase-5d LOS Bug Fix v2 — Arc-Boundary Intersection

**What this fix changes:** Replaces the 1/3-length heuristic with the real arc boundary lines from each ship's JSON data. `LineOfSightChecker._los_blocked_by_arc_boundaries()` checks whether the LOS segment crosses any of the 4 arc boundary lines (front_left, front_right, rear_left, rear_right). Each boundary is defined by inner_point → outer_point. When LOS is blocked, the game log now includes the boundary name, inner/outer points, and intersection coordinates. The 1/3-length approach is kept as a fallback when arc data is unavailable.

### MT-LOS-FIX2.1 — Nebulon-B FRONT arc → VSD LEFT is now clear

| Step | Action | Expected |
|------|--------|----------|
| 1 | Place Nebulon-B so its FRONT arc faces the VSD's LEFT side | Both ships on board |
| 2 | Open the Targeting List (T button) | Modal shows outgoing targets from Nebulon-B |
| 3 | Check that VSD LEFT appears as a valid target from the Nebulon-B FRONT arc | LEFT zone listed with range and dice; LOS status is "Clear" or "Obstructed" (not "Blocked") |

**Pass criteria:** The Nebulon-B can target the VSD's LEFT hull zone from its FRONT arc. LOS is no longer falsely blocked.

### MT-LOS-FIX2.2 — Debug logging shows boundary details when blocked

| Step | Action | Expected |
|------|--------|----------|
| 1 | Position attacker so LOS to a specific zone IS blocked (e.g. from right side to FRONT) | Setup requires LOS to cross an arc boundary |
| 2 | Click on the ship to trigger targeting / LOS computation | Game log output visible |
| 3 | Check the game log for the LOS blocked entry | Log shows "LOS boundary crossed: <name>, inner: (x,y), outer: (x,y), intersection: (x,y)" |

**Pass criteria:** When LOS is blocked, the log contains the boundary name and coordinate data for debugging.

### MT-LOS-FIX2.3 — Correct zones still reachable from each side

| Step | Action | Expected |
|------|--------|----------|
| 1 | Place attacker directly to the LEFT of a defender | Attacker abeam defender |
| 2 | Open Targeting List | Modal shows targets |
| 3 | Check LEFT zone | LEFT zone is reachable (LOS does not cross any arc boundary) |
| 4 | Check FRONT/REAR/RIGHT zones | FRONT, REAR, RIGHT are blocked (LOS crosses at least one boundary to reach them) |

**Pass criteria:** Only the hull zone on the same side as the attacker is reachable; all others are blocked by arc boundaries.

---

## Refactoring: AttackExecutor Extraction

**What this refactoring changes:** All attack simulator and attack execution logic (~2000 lines) was extracted from `game_board.gd` into a new `attack_executor.gd` file. `GameBoard` now delegates to `AttackExecutor` via a clean 13-method + 3-signal interface. No game logic was changed — this is a pure structural refactoring. Every test case below should behave identically to before.

### Setup

Open `src/scenes/game_board/game_board.tscn` in the editor and press **F6**.

---

### MT-AE.1 — Automated test baseline unchanged

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` | 65 scripts, 1250 tests |
| 2 | Check failures | Exactly 1 failure (pre-existing Nebulon-B deployment) |

**Pass criteria:** Same test count and same single pre-existing failure as before the refactoring.

---

### MT-AE.2 — Attack Simulator toggle (free-form mode)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run GameBoard scene, press **A** | Attack Simulator activates — toolbar button highlights, cursor changes |
| 2 | Click on a friendly ship | Hull zone outlines appear around the ship (attacker selected) |
| 3 | Click on an enemy ship or squadron | LOS line drawn, range displayed, dice pool shown in targeting info |
| 4 | Press **A** again (or click the toolbar button) | Attack Simulator deactivates — all overlays dismissed |
| 5 | Press **Escape** while an attacker is selected | Attacker deselected, simulator returns to selecting mode |

**Pass criteria:** All attack simulator interactions work identically to before the extraction.

---

### MT-AE.3 — Attack Simulator: LOS and range display

| Step | Action | Expected |
|------|--------|----------|
| 1 | Select an attacker hull zone, then click a target | LOS line appears between attacker and target |
| 2 | Check the LOS label | Shows "Clear" or "Obstructed" with range band (Close/Medium/Long) |
| 3 | Move camera to verify line endpoints | Line starts at attacker hull zone, ends at target's nearest edge |
| 4 | Select a target that is out of range | Range shows "Out of Range" or equivalent, no dice pool |

**Pass criteria:** LOS lines, range labels, and obstruction checks display correctly.

---

### MT-AE.4 — Attack Execution from Activation Modal (Step 4)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a ship (drag command dial) and open the Activation Modal | Modal shows 5 steps |
| 2 | Click "Attack" step | Attack executor enters target selection mode for the activated ship |
| 3 | Click a valid enemy target | Dice panel appears with rolled dice |
| 4 | If ship has Concentrate Fire dial: check that CF reroll option appears | Dice panel shows "Reroll" button |
| 5 | Click Confirm | Attack proceeds to accuracy/defense phase |

**Pass criteria:** Activation modal correctly triggers attack execution, dice roll shows correct pool for hull zone and range.

---

### MT-AE.5 — Defense Tokens

| Step | Action | Expected |
|------|--------|----------|
| 1 | During an attack execution, reach the defense token step | Defense token overlay appears on the defender |
| 2 | Click Evade token | One die removed (long range) or rerolled (medium range) |
| 3 | Click Brace (on a different attack) | Total damage halved (rounded up) |
| 4 | Click Scatter | Attack cancelled, 0 damage dealt |
| 5 | Click Redirect | Redirect prompt appears asking for zone(s) to redirect damage |
| 6 | Verify spent tokens change state | Green → red (exhausted), or red → removed |

**Pass criteria:** All five defense token types function correctly, token states update visually.

---

### MT-AE.6 — Accuracy Spending

| Step | Action | Expected |
|------|--------|----------|
| 1 | Roll dice that include accuracy icon(s) | Accuracy spending step appears |
| 2 | Click a defender defense token to lock it | Token visually marked as locked, cannot be spent |
| 3 | Click Done / Skip | Proceed to defense token step |

**Pass criteria:** Accuracy icons lock defense tokens, locked tokens cannot be spent by defender.

---

### MT-AE.7 — Damage Resolution

| Step | Action | Expected |
|------|--------|----------|
| 1 | Complete an attack against a ship | Damage applied: shields reduced first |
| 2 | Exceed shields on the targeted zone | Overflow damage goes to hull, damage cards drawn |
| 3 | Check ship card panel | Shield values updated, hull bar reduced, damage cards visible |

**Pass criteria:** Shield → hull overflow works correctly, damage cards appear in ship card panel.

---

### MT-AE.8 — Two-Hull-Zone Attack Sequence

| Step | Action | Expected |
|------|--------|----------|
| 1 | Attack with a ship that has targets in multiple hull zones | After first HZ attack resolves, prompted to attack from another zone |
| 2 | Choose to attack from second hull zone | New target selection for second zone, cannot re-target same squadron |
| 3 | Skip the second attack | Attack step completes, modal reopens |

**Pass criteria:** Multi-zone attack sequence works; each zone can only attack once per activation.

---

### MT-AE.9 — Anti-Squadron Attack (Step 6 Loop)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Attack with a ship that has multiple squadrons in range | After attacking one squadron, prompted for next |
| 2 | Attack a second squadron from the same hull zone | Dice rolled for second target |
| 3 | Skip remaining targets | Attack completes |

**Pass criteria:** Squadron targets cycle correctly, each squadron attacked at most once per zone.

---

### MT-AE.10 — Skip Attack and Escape Cancel

| Step | Action | Expected |
|------|--------|----------|
| 1 | In the Activation Modal, click Attack when targets exist | Attack execution begins |
| 2 | Press **Escape** during target selection | Attack cancelled, modal reopens at Attack step (not advanced) |
| 3 | Click "Skip Attack" (if no targets or after attacking) | Attack step completes normally |

**Pass criteria:** Escape cancels without advancing; skip advances the activation step.

---

### MT-AE.11 — Dismiss Other Tools on Attack

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate the Range Overlay (press R) | Range overlay visible |
| 2 | Press A to activate Attack Simulator | Range overlay dismissed automatically |
| 3 | Activate the Maneuver Tool (press M) | Maneuver tool visible |
| 4 | Press A to activate Attack Simulator | Maneuver tool dismissed automatically |

**Pass criteria:** Attack simulator dismisses other tools when activated, preventing visual conflicts.

---

## Phase 7: Squadron Phase — Effect Pipeline, Engagement & Activation

**What this phase adds:** An Effect/Hook pipeline for rule-modifying effects (Bomber, Escort, Swarm keywords), engagement resolution (distance-1 edge-to-edge), squadron movement validation, and interactive alternating squadron activation (2 per turn). The phase replaces the placeholder that auto-passed all squadrons.

### Setup

Open `src/scenes/game_board/game_board.tscn` in the editor and press **F6**.

---

### MT-7.1 — Automated test baseline

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` | 71 scripts, 1325 tests |
| 2 | Check failures | Exactly 1 failure (pre-existing Nebulon-B deployment) |

**Pass criteria:** 1324 passing, 1 pre-existing failure. No new failures.

---

### MT-7.2 — Squadron phase starts after ship phase

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a game and complete all ship activations in a round | Phase changes to Squadron Phase |
| 2 | Observe the phase indicator | Shows "Squadron Phase" |
| 3 | Check game log | Log shows squadron phase has begun and which player is active |

**Pass criteria:** Squadron phase starts automatically after the last ship activation ends.

---

### MT-7.3 — Squadron phase auto-skips when no squadrons

| Step | Action | Expected |
|------|--------|----------|
| 1 | (If possible) Start a scenario with no squadrons on either side | Phase should skip directly to Status Phase |
| 2 | Check game log | Log shows squadron phase was skipped due to no squadrons |

**Pass criteria:** If neither player has squadrons, the phase auto-skips to Status Phase. (Note: Learning scenario always has squadrons, so you may need to manually destroy all squadrons or modify setup to verify.)

---

### MT-7.4 — Initiative player activates first

| Step | Action | Expected |
|------|--------|----------|
| 1 | Enter the Squadron Phase | Initiative player (player with initiative token) is set as active player |
| 2 | Check phase indicator / game log | Active player matches initiative holder |

**Pass criteria:** The initiative player always gets the first turn in the squadron phase.

---

### MT-7.5 — Squadron activation: 2-per-turn limit

| Step | Action | Expected |
|------|--------|----------|
| 1 | During a player's squadron turn, activate 1 squadron | Squadron starts its activation |
| 2 | Complete the first squadron's activation | Counter increments to 1 |
| 3 | Activate a second squadron | Squadron activates successfully |
| 4 | Complete the second squadron's activation | Turn automatically ends, switches to opponent |

**Pass criteria:** After 2 squadron activations, the turn switches to the other player without player action.

---

### MT-7.6 — Alternating turns

| Step | Action | Expected |
|------|--------|----------|
| 1 | Player A completes their 2 squadron activations | Turn switches to Player B |
| 2 | Player B completes their 2 squadron activations | Turn switches back to Player A |
| 3 | Repeat until all squadrons exhausted | Phase ends |

**Pass criteria:** Players alternate turns correctly. Each player gets 2 activations per turn.

---

### MT-7.7 — Auto-pass when player has no unactivated squadrons

| Step | Action | Expected |
|------|--------|----------|
| 1 | One player has fewer squadrons than the other | After the smaller-fleet player runs out of unactivated squadrons, their turns are automatically passed |
| 2 | The larger-fleet player continues activating | Remaining squadrons activate normally |

**Pass criteria:** When a player runs out of squadrons to activate, the other player gets all remaining turns.

---

### MT-7.8 — Phase ends when all squadrons activated

| Step | Action | Expected |
|------|--------|----------|
| 1 | Both players activate all their squadrons | Squadron phase ends |
| 2 | Check the next phase | Status Phase begins |
| 3 | Verify squadron activation flags are reset | In the next round's squadron phase, all squadrons are available again |

**Pass criteria:** Phase transitions to Status Phase after all squadrons are activated.

---

### MT-7.9 — Activated squadron visual indicator

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a squadron | Squadron's visual appearance changes to indicate activation (e.g., opacity change, border, or glow) |
| 2 | Check unactivated squadrons | They retain their normal appearance |

**Pass criteria:** Activated and unactivated squadrons are visually distinguishable. (Note: visual indicator may not yet be implemented in the presentation layer — verify what exists.)

---

### MT-7.10 — Bomber keyword affects damage vs ships

| Step | Action | Expected |
|------|--------|----------|
| 1 | During an attack, have a squadron with the Bomber keyword attack a ship | Damage calculation includes critical results as damage |
| 2 | Compare with a non-Bomber squadron attacking a ship | Non-Bomber crits count as 0 damage; Bomber crits count as 1 |

**Pass criteria:** Bomber keyword correctly modifies damage calculation against ships. (This is tested by GUT unit tests; visual verification requires inspecting damage results in the attack flow.)

---

### MT-7.11 — No regressions: full game flow

| Step | Action | Expected |
|------|--------|----------|
| 1 | Play through a full round: Command → Ship → Squadron → Status | All phases complete without errors |
| 2 | Play through multiple rounds | Game flow repeats correctly, no crashes |
| 3 | Verify ship attacks still work normally | Attack simulator and execution unchanged |
| 4 | Verify ship movement still works | Maneuver tool unchanged |
| 5 | Verify defense tokens still work | Token spending unchanged |

**Pass criteria:** All existing functionality (ship activation, movement, attacks, defense tokens) works identically to before Phase 7.

---

## Phase 7b — Squadron Activation UI

**What this phase adds:** An interactive modal that guides the player through squadron activation: select → choose action (Move / Attack / Skip) → execute → next. Includes movement + armament range overlays, engagement-based button restrictions, visual dimming of activated tokens, and re-open button when the modal is dismissed.

**Automated gate:** 75 scripts, 1385 tests, 1384 passing, 1 pre-existing failure. Run the GUT suite first.

---

### MT-7b.1 — Squadron modal appears after handoff

| Step | Action | Expected |
|------|--------|----------|
| 1 | Advance the game to the Squadron Phase | Handoff overlay / "Your Turn" banner shows |
| 2 | Dismiss the handoff | Squadron Activation Modal appears at bottom-centre |
| 3 | Check modal title | Shows "Squadron Phase — [Faction Name]" |
| 4 | Check subtitle | Shows "Activate squadron 1 of 2" |

**Pass criteria:** Modal appears correctly after handoff and displays the right faction and activation count.

---

### MT-7b.2 — Select a squadron to activate

| Step | Action | Expected |
|------|--------|----------|
| 1 | Click on a friendly unactivated squadron | Modal transitions to show squadron name + action buttons |
| 2 | Check overlay circles | Movement range circle (brownish) + armament range circle (green/red) appear centred on the squadron |
| 3 | Click on an enemy squadron | Error message shown: "Not your squadron" |
| 4 | Click on an already-activated squadron | Error message shown: "Already activated this round" |

**Pass criteria:** Only valid friendly unactivated squadrons can be selected. Overlays appear on selection.

---

### MT-7b.3 — Engagement-based button restrictions

| Step | Action | Expected |
|------|--------|----------|
| 1 | Select an ENGAGED squadron (enemy at distance 1) | Move button is disabled with tooltip "Engaged — cannot move" |
| 2 | Check Skip button | Skip is disabled with tooltip "Engaged — must attack an engaged enemy" |
| 3 | Check Attack button | Attack is enabled |
| 4 | Select an UNENGAGED squadron | All three buttons (Move, Attack, Skip) are enabled |

**Pass criteria:** Engaged squadrons cannot move or skip, per SM-011/SM-012.

---

### MT-7b.4 — Squadron movement (snap + commit)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Select unengaged squadron, press Move | Prompt: "Click on the board to place the squadron" |
| 2 | Click within the movement range circle | Squadron token snaps to clicked position, "Commit Move" button appears |
| 3 | Click outside the movement range | Error: "Too far: exceeds distance N." — token stays at original position |
| 4 | Click overlapping another squadron | Error: "Overlaps another squadron." |
| 5 | Press "Commit Move" | Move is finalised, activation ends, squadron dims |
| 6 | Press Escape during movement | Squadron reverts to original position, returns to action choice |

**Pass criteria:** Movement validates distance and overlap, commits correctly, and Escape reverts.

---

### MT-7b.5 — Squadron attack flow

| Step | Action | Expected |
|------|--------|----------|
| 1 | Select a squadron, press Attack | Attack executor opens with the squadron pre-selected as attacker |
| 2 | Complete the attack via the attack flow | Attack resolves, modal shows "Activation complete" |
| 3 | Cancel the attack (Escape) | Returns to action choice buttons |

**Pass criteria:** Attack delegates to the existing AttackExecutor in squadron mode.

---

### MT-7b.6 — Skip activation

| Step | Action | Expected |
|------|--------|----------|
| 1 | Select an unengaged squadron, press Skip | Activation ends, squadron dims to alpha 0.4 |
| 2 | Verify engagement restriction | Skip button is disabled for engaged squadrons |

**Pass criteria:** Skip ends the activation without performing any action.

---

### MT-7b.7 — Activated visual (alpha dimming)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a squadron (via any action) | Token's alpha reduces to ~0.4 (visibly dimmer) |
| 2 | Check unactivated squadrons | They remain at full alpha (1.0) |
| 3 | Advance to next round (Status Phase resets) | All squadron alphas restore to 1.0 |

**Pass criteria:** Activated squadrons are visually distinguished by reduced opacity.

---

### MT-7b.8 — Modal dismiss and re-open

| Step | Action | Expected |
|------|--------|----------|
| 1 | Press "✕ Close" or Escape on the modal | Modal hides, "Show Squadron Modal" button appears at bottom-centre |
| 2 | Press the "Show Squadron Modal" button | Modal re-opens with its previous state |

**Pass criteria:** Dismissing the modal doesn't cancel activation flow; player can always re-open.

---

### MT-7b.9 — No regressions: full game flow

| Step | Action | Expected |
|------|--------|----------|
| 1 | Play through Command → Ship → Squadron → Status | All phases transition correctly |
| 2 | Verify ship activation flow unchanged | Dial drag, activation modal, maneuver tool work |
| 3 | Verify attack flow unchanged | Ship attacks work identically |
| 4 | After 2 squadron activations, turn passes to opponent | Turn management unchanged |

**Pass criteria:** All existing functionality works identically to before Phase 7b.

---

## Phase 8 — Status Phase & Game Flow

**What this phase adds:** ScoringCalculator for fleet-point scoring, elimination checks triggered by ship/squadron destruction, VictoryScreen overlay at game end, live score display in the phase HUD, and a 0.8 s fade-out tween on destroyed tokens.

**Commits:** `9b34f3f` (8a: scoring + elimination), `f280634` (8b: victory screen), `e780aba` (8c: HUD scores).
**Test baseline after phase:** 79 scripts, 1431 tests, 1430 passing.

### MT-8.1 — Phase HUD shows live scores

| Step | Action | Expected |
|------|--------|----------|
| 1 | Launch the Learning Scenario (F5) | Phase HUD label visible at top-centre |
| 2 | Read the HUD text during Command Phase | Shows `Round 1 — Command Phase  \|  Rebel: 0  \|  Imperial: 0` |
| 3 | Advance to Ship Phase | HUD updates to `Round 1 — Ship Phase  \|  Rebel: 0  \|  Imperial: 0` |

**Pass criteria:** HUD displays round, phase name, and both faction scores (both 0 at start).

### MT-8.2 — Score updates on destruction

| Step | Action | Expected |
|------|--------|----------|
| 1 | Play until a ship or squadron is destroyed via combat | HUD score for the destroying player increases |
| 2 | Verify the increase matches the destroyed unit's point cost | Score equals the sum of all destroyed enemy point costs |

**Pass criteria:** Scores reflect fleet points of destroyed enemy units in real time.

### MT-8.3 — Destroyed token fade-out

| Step | Action | Expected |
|------|--------|----------|
| 1 | Destroy a ship or squadron in combat | Token fades to transparent over ~0.8 seconds |
| 2 | After fade completes | Token is no longer visible (but still in scene tree) |

**Pass criteria:** Smooth fade-out animation, no abrupt disappearance.

### MT-8.4 — Game ends after round 6

| Step | Action | Expected |
|------|--------|----------|
| 1 | Play through 6 full rounds (Command → Ship → Squadron → Status × 6) | VictoryScreen overlay appears after round 6 Status Phase |
| 2 | VictoryScreen displays winner, scores, round number, and reason | Winner is faction with higher fleet points; reason is "All 6 rounds completed" |
| 3 | Scores match the HUD values shown before the screen appeared | No discrepancy |

**Pass criteria:** Game correctly ends after 6 rounds with accurate scoring.

### MT-8.5 — Elimination ends game immediately

| Step | Action | Expected |
|------|--------|----------|
| 1 | Destroy all enemy ships (not just squadrons) during combat | VictoryScreen appears immediately (not deferred to Status Phase) |
| 2 | Reason text shows "Fleet eliminated" | Winner is the non-eliminated player |
| 3 | Scores are computed at the moment of elimination | Points reflect all destroyed units up to that point |

**Pass criteria:** Elimination triggers instant game end with correct scoring.

### MT-8.6 — VictoryScreen buttons

| Step | Action | Expected |
|------|--------|----------|
| 1 | On VictoryScreen, click **Play Again** | Scene reloads; a fresh game starts from round 1 |
| 2 | On VictoryScreen, click **Quit** | Application closes |

**Pass criteria:** Both buttons function correctly.

### MT-8.7 — VictoryScreen styling

| Step | Action | Expected |
|------|--------|----------|
| 1 | Trigger VictoryScreen (round 6 end or elimination) | Dark overlay covers entire screen |
| 2 | Winner text is displayed in gold, centred | Text is legible against dark background |
| 3 | Scores for both factions shown | Layout is centred and readable |

**Pass criteria:** VictoryScreen is visually clean and informative.

### MT-8.8 — No regressions: full game flow

| Step | Action | Expected |
|------|--------|----------|
| 1 | Play through Command → Ship → Squadron → Status for at least 2 rounds | All phases transition correctly |
| 2 | Verify ship activation flow unchanged | Dial drag, activation modal, maneuver tool work |
| 3 | Verify attack flow unchanged | Ship and squadron attacks work identically |
| 4 | Verify squadron activation unchanged | Modal opens, select, move, attack, skip all work |
| 5 | Status phase resets tokens and advances round | Defense tokens ready, activation flags cleared |

**Pass criteria:** All existing functionality works identically to before Phase 8.

---

## Phase 9 — Repair Command & Damage Cards

**What this phase adds:** Full damage card system (52 cards, 22 types), immediate and persistent damage effects via EffectRegistry, RepairResolver for engineering point allocation, RepairPanel UI in activation flow, and ship destruction cleanup.

### Setup

Run the game board scene: `src/scenes/game_board/game_board.tscn` via **F6**.

---

### MT-9.1 — Damage card dealt facedown on hull damage

| Step | Action | Expected |
|------|--------|----------|
| 1 | Attack a ship and deal hull damage (total damage exceeds shields in target zone) | Damage card dealt for each hull point of damage |
| 2 | Check game log for "dealt facedown damage card" messages | One message per hull damage dealt |
| 3 | Damage cards are from the damage deck (not infinite) | Deck draw count decreases |

**Pass criteria:** Hull damage correctly deals facedown damage cards.

---

### MT-9.2 — Critical hit flips card faceup with effect

| Step | Action | Expected |
|------|--------|----------|
| 1 | Deal a critical hit to a ship (at least one critical result in dice pool) | First damage card is dealt faceup |
| 2 | Check game log for faceup card details | Card title and effect text shown |
| 3 | If card is immediate (e.g., "Structural Damage", "Shield Failure") | Effect resolves instantly; log confirms effect applied |
| 4 | If card is persistent (e.g., "Ruptured Engine", "Damaged Controls") | Card stays faceup; effect remains registered |

**Pass criteria:** Critical hits flip the first card faceup and resolve effects correctly.

---

### MT-9.3 — Repair step appears in activation modal

| Step | Action | Expected |
|------|--------|----------|
| 1 | Assign a Repair (Engineering) command dial to a ship | Dial visible in command stack |
| 2 | Activate that ship — advance through Reveal and Squadron steps | Activation modal shows step 3: "Execute Repair ►" button |
| 3 | Ship has NO Repair dial or token | Step 3 shows "No repair available" and auto-skips |

**Pass criteria:** Repair step is interactive when resources exist, auto-skips otherwise.

---

### MT-9.4 — RepairPanel operations

| Step | Action | Expected |
|------|--------|----------|
| 1 | Click "Execute Repair ►" on a ship with Repair dial | RepairPanel opens showing available engineering points |
| 2 | RepairPanel shows "Move Shields (1 pt)" with zone buttons | Each valid adjacent zone pair has a button |
| 3 | Click a "Move Shields" button | Shield moves between zones; points decrease by 1; UI refreshes |
| 4 | RepairPanel shows "Recover Shields (2 pts)" with zone buttons | Only zones below maximum show buttons |
| 5 | Click "Recover Shields" on a zone | Shield count increases by 1; points decrease by 2 |
| 6 | RepairPanel shows "Discard Damage Card (3 pts)" with card buttons | Only ships with faceup damage cards show discard buttons |
| 7 | Click a card discard button | Card removed from ship; points decrease by 3 |
| 8 | Click "Done" | Panel closes; activation advances to Attack step |

**Pass criteria:** All three repair operations work correctly with proper point deduction.

---

### MT-9.5 — Ship destruction cleans up damage cards

| Step | Action | Expected |
|------|--------|----------|
| 1 | Destroy a ship (deal enough damage to exceed hull) | Ship token fades out |
| 2 | Check game log | "Ship destroyed" message, damage cards cleared |
| 3 | No orphaned damage card effects remain | No errors in subsequent rounds from the destroyed ship's effects |

**Pass criteria:** Destroyed ships release all damage cards and unregister effects cleanly.

---

### MT-9.6 — No regressions: full game flow with damage

| Step | Action | Expected |
|------|--------|----------|
| 1 | Play a full game (all 6 rounds) with attacks dealing damage | No crashes or errors |
| 2 | Verify activation flow: Reveal → Squadron → Repair → Attack → Maneuver | All steps transition correctly |
| 3 | Verify damage deck reshuffles discards when empty | Game continues without deck exhaustion errors |
| 4 | Verify persistent effects apply in subsequent attacks | E.g., "Ruptured Engine" reduces max speed |

**Pass criteria:** Complete game with damage cards functioning throughout all rounds.
