# Manual Test Plan — Star Wars: Armada Digital Edition

> **Scope:** Full Learning Scenario MVP — Phases 0–12, all post-phase bug fixes, refactoring phases A–H, and Phase G (command pattern).
> **Status:** **MVP COMPLETE** — all phases delivered and manually verified. Phase G (command infra) in progress.
> **How to run a scene:** Godot Editor → double-click the `.tscn` → press **F6** (Run Current Scene).
> **Automated gate:** Always run `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -10` and confirm 0 failures **before** doing manual tests.
> **Current baseline:** 104 scripts, 2 098 tests, all passing.

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

## Phase 5d-2 — Targeting List: Squadron Sections & Hull Zone Detail

**Scope:** Squadron outgoing/incoming sections in targeting list modal; per-defending-hull-zone detail for ship→ship targets; UI formatting with zone labels.
**Note:** All features were implemented incrementally across Phases 5d, 5d-fix, 7, 7b, and 8 rather than as a dedicated session. This section documents the manual verification checks.

### MT-5d-2.1 — Squadron outgoing targets: ship at distance 1

| Step | Action | Expected |
|------|--------|----------|
| 1 | Place a friendly X-wing squadron at distance 1 of an enemy ship | Targeting list shows a squadron section with the enemy ship as an outgoing target |
| 2 | Verify dice display | Battery armament dice shown (from squadron JSON data), not anti-squadron dice |
| 3 | Move squadron beyond distance 1 | Enemy ship disappears from outgoing targets |

### MT-5d-2.2 — Squadron outgoing targets: enemy squadron at distance 1

| Step | Action | Expected |
|------|--------|----------|
| 1 | Place a friendly X-wing near an enemy TIE Fighter at distance 1 | Targeting list shows the TIE Fighter as an outgoing target with anti-squadron dice |
| 2 | Verify range display | Shows "in range" (no hull zone label) |

### MT-5d-2.3 — Squadron incoming threats section

| Step | Action | Expected |
|------|--------|----------|
| 1 | Place an enemy Victory I with anti-sq armament in arc of a friendly squadron | Incoming threats section shows the Victory I |
| 2 | Place an enemy TIE Fighter at distance 1 of the friendly squadron | TIE Fighter appears in incoming threats |
| 3 | Move the TIE Fighter beyond distance 1 | TIE Fighter disappears from incoming threats |

### MT-5d-2.4 — Ship→ship hull zone detail

| Step | Action | Expected |
|------|--------|----------|
| 1 | Open targeting list for a ship with multiple enemy hull zones reachable | Each reachable defending hull zone appears as a separate line |
| 2 | Verify format | Lines show "Name FRONT→REAR at medium range (2 red, 1 blue)" style with attacking→defending zone labels |
| 3 | Verify colour coding | Range-band colours match: grey (close), blue (medium), red (long) |

### MT-5d-2.5 — Squadron section header styling

| Step | Action | Expected |
|------|--------|----------|
| 1 | Open targeting list with both ship and squadron sections | Squadron headers use green colour, distinct from gold ship headers |
| 2 | Sections appear in order: ship outgoing, ship incoming, squadron outgoing, squadron incoming | Correct ordering |

**Pass criteria:** Squadron sections render with correct outgoing/incoming data; hull zone detail lines show per-zone breakdown; colour and formatting match spec.

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
| 4 | Ship has Repair dial but full hull and full shields (nothing to repair) | Step 3 auto-skips with log "Ship at full strength"; dial/token is still consumed |

**Pass criteria:** Repair step is interactive when resources exist AND the ship has something to repair. Auto-skips when no resources or nothing to repair.

---

### MT-9.4 — RepairPanel operations

| Step | Action | Expected |
|------|--------|----------|
| 1 | Click "Execute Repair ►" on a ship with Repair dial | RepairPanel opens showing available engineering points |
| 2 | RepairPanel shows "Move Shields (1 pt)" with zone buttons | Each valid adjacent zone pair has a button |
| 3 | Click a "Move Shields" button | Shield moves between zones; points decrease by 1; UI refreshes |
| 4 | RepairPanel shows "Recover Shields (2 pts)" with zone buttons | Only zones below maximum show buttons |
| 5 | Click "Recover Shields" on a zone | Shield count increases by 1; points decrease by 2 |
| 6 | RepairPanel shows "Discard Damage Card (3 pts)" with card buttons | Faceup cards shown by name (▲), facedown cards shown as generic (▼); both are discardable |
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

---

## Phase 9.5 — Squadron Command (Dial & Token)

**What this phase adds:** Ships with a revealed Squadron dial and/or Squadron command token can activate friendly squadrons at close–medium range during their activation. Each activated squadron can move **and** attack in either order (same as Rogue). The activation modal now shows a real "Execute Squadron ►" button instead of auto-skipping.

### MT-9.5.1 — Squadron step visible in activation modal

| Step | Action | Expected |
|------|--------|----------|
| 1 | Assign a **Squadron** dial to a ship that has friendly squadrons nearby | Dial reveals on drop |
| 2 | Click "Show Activation Sequence" | Activation modal opens |
| 3 | Observe step 2 (Squadron) | Shows **"Execute Squadron ►"** button (not "No squadron available") |
| 4 | Observe step row styling | Squadron step is highlighted as the current active step |

### MT-9.5.2 — Squadron step auto-skipped without resources

| Step | Action | Expected |
|------|--------|----------|
| 1 | Assign a **Navigate** dial to a ship (no Squadron token either) | Dial reveals |
| 2 | Click "Show Activation Sequence" | Activation modal opens |
| 3 | Observe step 2 (Squadron) | Shows "No squadron available" and auto-skips past it |

### MT-9.5.3 — Squadron command activates squadrons

| Step | Action | Expected |
|------|--------|----------|
| 1 | Click "Execute Squadron ►" on a ship with Squadron dial (squadron_value=2) | Squadron activation modal opens in command mode |
| 2 | Title bar shows "Squadron Command — [Ship Name]" | Correct ship name displayed |
| 3 | Click a friendly squadron **within** close–medium range | Squadron is selected; move/attack buttons appear |
| 4 | Move the squadron, then attack with it (or vice versa) | Both actions complete; activation count decrements |
| 5 | Second squadron selection prompt appears | "Click a friendly squadron at close–medium range" |
| 6 | Select and activate a second squadron | Both move and attack complete |
| 7 | After 2 activations, modal closes | `command_done` fires; activation modal re-opens at Repair step |

### MT-9.5.4 — Out-of-range squadron rejected

| Step | Action | Expected |
|------|--------|----------|
| 1 | Open squadron command for a ship | Command mode modal opens |
| 2 | Click a friendly squadron that is **far away** (beyond medium range) | Toast: "Squadron out of range — must be at close–medium range." |
| 3 | Squadron is not selected | Modal stays in WAITING_FOR_SELECTION |

### MT-9.5.5 — Done button ends command early

| Step | Action | Expected |
|------|--------|----------|
| 1 | Open squadron command for a ship with squadron_value=3 | 3 activations available |
| 2 | Activate 1 squadron (move + attack) | 2 remaining |
| 3 | Click "Done" button | Command ends early; dial/token consumed; activation modal re-opens |

### MT-9.5.6 — Token-only grants 1 activation

| Step | Action | Expected |
|------|--------|----------|
| 1 | Convert a Squadron dial to a token (drag dial to ship card) | Token added |
| 2 | Assign a Navigate dial next round; activate the ship | Ship has Navigate dial + Squadron token |
| 3 | Click "Execute Squadron ►" | Command mode opens with 1 activation only |
| 4 | Activate 1 squadron | Command completes; token consumed |

### MT-9.5.7 — Dial + token combined

| Step | Action | Expected |
|------|--------|----------|
| 1 | Give a ship a Squadron dial and a Squadron token | E.g., VSD (sq_val=3) + token = 4 |
| 2 | Activate the ship and click "Execute Squadron ►" | 4 activations available |
| 3 | Activate 4 squadrons | All complete; both dial and token consumed |

**Pass criteria:** Squadron command works with dial, token, and combined; range filtering rejects distant squadrons; early Done correctly finalizes.

---

## Phase 5b-2 — Overlap Handling

**What this phase adds:** Ship–ship overlap detection with automatic temporary speed reduction and facedown damage to both ships. Ship–squadron overlap detection with displacement modal (squadron checklist + commit) for the opposing player. Amber collision message inside activation modal. “End Activation ►” button (player must deliberately end activation). Modal stays open after commit.

**Automated coverage:** `test_overlap_resolver.gd` — 13 tests covering overlap detection, speed reduction, placement validation, snap-to-edge. `test_displacement_modal.gd` — 14 tests covering open/close, check/uncheck, all_checked, first_unchecked, single-squadron edge case. `test_activation_modal.gd` — 11 new tests covering End Activation button visibility/signal/close, modal-stays-open, collision label. Manual tests below cover visual/interaction aspects only.

### MT-5b2.1 — Ship–ship overlap causes speed reduction and damage

| Step | Action | Expected |
|------|--------|----------|
| 1 | Position two opposing ships such that one will overlap the other after maneuver | Ships on collision course |
| 2 | Activate the moving ship and commit maneuver | Amber collision label in activation modal: “⚠ Collision detected! Speed temporarily reduced to N (was M).” + per-ship damage lines |
| 3 | Observe ship position | Ship is at the reduced-speed position, not overlapping the other ship |
| 4 | Open ship card panels for both ships | Each shows 1 additional facedown damage card |

### MT-5b2.2 — Ship stays in place at speed 0

| Step | Action | Expected |
|------|--------|----------|
| 1 | Position two ships directly overlapping (debug drag) | Ships on top of each other |
| 2 | Activate the top ship and commit maneuver | Amber collision label in activation modal: “⚠ Collision detected! Speed temporarily reduced to 0.” + damage messages |
| 3 | Observe ship position | Ship remains at its original position |
| 4 | Both ships take 1 facedown damage | Card panels updated |

### MT-5b2.3 — Ship–squadron overlap triggers displacement modal with screen flip

| Step | Action | Expected |
|------|--------|----------|
| 1 | Position a squadron in the path of a moving ship | Squadron will be overlapped |
| 2 | Activate the ship and commit maneuver | "Show Activation Sequence" button hides; camera rotates 180° to the opposing player's perspective |
| 3 | Displacement Modal appears | Title: "Squadron Displacement"; lists displaced squadron(s) with ► on the first row; "Commit Placement ►" button disabled |
| 4 | First squadron auto-placed at ship edge, mouse-follow active | Squadron snapped to ship edge, follows cursor |
| 5 | Left-click to lock position | ✓ checkmark on that squadron's row; next unchecked auto-selected |
| 6 | Click a checked row in the modal | Row unchecks, squadron re-enters mouse-follow for repositioning |
| 7 | Lock all squadrons | All rows show ✓; "Commit Placement ►" button enabled |
| 8 | Press "Commit Placement ►" | Modal closes; camera rotates back to active player; activation modal re-opens showing all 5 steps checked + “End Activation ►” button; press it to end activation; "Your Turn" banner shown for next player |

### MT-5b2.4 — Multiple displaced squadrons handled via modal checklist

| Step | Action | Expected |
|------|--------|----------|
| 1 | Position multiple squadrons in the ship's path | Multiple overlap |
| 2 | Commit the maneuver | Modal lists all displaced squadrons; first row highlighted with ► |
| 3 | Lock the first squadron | ✓ on first row; second row auto-selected with ► |
| 4 | Lock remaining; press Commit | Camera flips back; activation modal re-opens with all steps checked + “End Activation ►”; press it to end; next player's turn |


### MT-5b2.5 — End Activation button flow (no overlap)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a ship with no obstructions and commit maneuver | Activation modal stays open (does not close after commit) |
| 2 | Observe modal | All 5 step rows show green ✓; “End Activation ►” button appears at bottom |
| 3 | Press “End Activation ►” | Modal closes; `activation_ended` fires; next player’s turn starts; "Your Turn" banner shown |

### MT-5b2.6 — Collision label visibility in modal

| Step | Action | Expected |
|------|--------|----------|
| 1 | Commit a maneuver that causes a ship–ship overlap | Activation modal stays open |
| 2 | Observe modal | Amber label between step rows and End Activation button: "⚠ Collision detected! Speed temporarily reduced to N (was M)." followed by per-ship damage lines |
| 3 | Press “End Activation ►” | Modal closes; activation ends normally |
| 4 | Activate a different ship (no collision) and commit | Modal re-opens with no collision label (label hidden) |


**Pass criteria:** Ship–ship overlap auto-resolves with speed reduction and damage; amber collision label shown inside activation modal; displacement shows modal checklist with check/uncheck, snap-to-edge mouse-follow, Commit button; "Show Activation Sequence" hidden during displacement; camera flips to opponent before displacement and back after; activation modal re-opens with all steps checked after commit; “End Activation ►” button must be pressed to end activation; "Your Turn" banner appears for the next player after end activation.


---

## Phase 10b — UI Polish (Card Detail View, Activation Sidebar, Movement Preview)

**What this phase adds:** Right-click on a ship card panel entry opens a full-screen card detail overlay (UI-002). An activation sidebar (UI-014) on the top centre shows all ships/squadrons grouped by faction with activated/unactivated status and initiative marker. Ghost ship preview now pulses opacity (UI-010). A `set_collision_preview()` API is available on the maneuver tool for future "BLOCKED" indicator wiring.

### MT-10b.1 — Card detail overlay via right-click

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a game and observe the ship card panels on left and right edges | Both panels display ship entries with names and defense tokens |
| 2 | Right-click on a Rebel ship entry in the left panel | Full-screen semi-transparent overlay appears with the ship's card artwork centred and a title label at the top |
| 3 | Observe the overlay | Card image is large (up to 85% viewport height, 60% viewport width), background is dark semi-transparent |
| 4 | Click anywhere on the overlay | Overlay dismisses |
| 5 | Right-click on an Imperial ship entry in the right panel | Overlay appears again with that ship's card artwork |
| 6 | Press Escape | Overlay dismisses |

### MT-10b.2 — Activation sidebar (lower-left slide-in)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a game; advance to Ship Phase | A narrow panel (20 px peek) appears at the lower-left edge listing all ships and squadrons grouped by faction |
| 2 | Click the peek strip | Panel slides out (0.25 s ease) showing full entries; Rebel names in orange, Imperial names in green; initiative player's faction has a star marker; ships show filled circle prefix, squadrons show diamond prefix |
| 3 | Click the panel again | Panel slides back to the 20 px peek |
| 4 | Activate a ship | That ship's entry dims (grey); while activating, the entry is shown in **bold** |
| 5 | Complete the ship's activation | Bold removed; entry stays grey |
| 6 | Advance to Squadron Phase | Sidebar remains visible; all squadron entries are bright (faction-coloured) |
| 7 | Advance past Squadron Phase (e.g., to Status Phase) | Sidebar hides |

### MT-10b.3 — Ghost ship static preview

| Step | Action | Expected |
|------|--------|----------|
| 1 | Display the maneuver tool on a ship | Ghost preview appears at projected final position at ~0.35 alpha (static, no animation) |
| 2 | Click a joint to change yaw | Ghost updates position smoothly |
| 3 | Dismiss the maneuver tool | Ghost disappears cleanly |

**Pass criteria:** Right-click opens card detail overlay with correct artwork; overlay dismisses on click or Escape; sidebar slides in/out from lower-left with faction colours (Rebel orange, Imperial green) and bold highlighting for the currently-activating unit; activated units dim; ghost ship preview appears at static alpha.

---

## Damage Card Display in Ship Card Panel

**What this phase adds:** A rightmost damage column in each ship card panel entry showing faceup damage card thumbnails (individually right-clickable for detail overlay) and a facedown counter badge (card-back + ×N). Live EventBus updates refresh the column when cards are dealt, flipped, or repaired. Magnify scaling is supported. A toast notification appears when any damage card is dealt.

### MT-DMG.1 — Faceup damage card thumbnails

| Step | Action | Expected |
|------|--------|----------|
| 1 | Deal faceup damage to a ship (e.g., via a critical hit during an attack) | A small thumbnail of the damage card art appears in the rightmost column of that ship's card panel entry |
| 2 | Deal a second faceup damage card to the same ship | A second thumbnail appears below the first |
| 3 | Hover over a faceup thumbnail | Tooltip shows the card title (e.g., "Blinded Gunners") |
| 4 | Right-click on a faceup thumbnail | Card detail overlay opens showing the full damage card artwork and title |
| 5 | Dismiss the overlay (click or Escape) | Overlay closes; thumbnail remains |

### MT-DMG.2 — Facedown damage counter badge

| Step | Action | Expected |
|------|--------|----------|
| 1 | Deal facedown (non-critical) damage to a ship | The damage column shows a single card-back thumbnail with a "×1" label next to it |
| 2 | Deal two more facedown damage cards | The label updates to "×3" — still only one card-back image |
| 3 | Verify the badge position | The facedown badge appears below any faceup thumbnails |

### MT-DMG.3 — Mixed faceup and facedown display

| Step | Action | Expected |
|------|--------|----------|
| 1 | Deal a mix of faceup and facedown damage to one ship | Faceup thumbnails appear at the top of the column, facedown badge at the bottom |
| 2 | Count the column items | Number of faceup thumbnails matches faceup cards; badge shows correct ×N for facedown count |

### MT-DMG.4 — Live update on damage dealt

| Step | Action | Expected |
|------|--------|----------|
| 1 | Observe a ship with no damage | Damage column is empty (no thumbnails or badge) |
| 2 | Resolve an attack that deals damage | Damage column updates immediately — new thumbnails/badge appear without needing to close or reopen the panel |
| 3 | A toast notification appears briefly | Toast reads "Ship Name — CRIT: Card Title" for faceup, or "Ship Name — damage card dealt" for facedown |

### MT-DMG.5 — Live update on card flip and repair

| Step | Action | Expected |
|------|--------|----------|
| 1 | A faceup damage card is flipped facedown (e.g., via an effect) | The thumbnail disappears from faceup section; facedown badge count increments by 1 |
| 2 | A facedown damage card is discarded via repair | Facedown badge count decrements; if count reaches 0, badge disappears |

### MT-DMG.6 — Magnify scaling

| Step | Action | Expected |
|------|--------|----------|
| 1 | Click a ship card panel entry to magnify it | The damage column thumbnails and badge scale up proportionally with the rest of the entry |
| 2 | Click again to un-magnify | Damage column returns to normal size |

### MT-DMG.7 — Panel width adjusts for damage column

| Step | Action | Expected |
|------|--------|----------|
| 1 | Observe a ship with several damage cards | The card panel width has expanded to accommodate the damage column without clipping |
| 2 | Compare with an undamaged ship | The undamaged ship's entry has no extra width from an empty damage column |

### MT-DMG.8 — No damage column when undamaged

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a fresh game, observe card panels | No damage column content visible on any ship — entries look identical to before this feature |

**Pass criteria:** Faceup damage thumbnails appear individually with correct art and are right-clickable for detail overlay; facedown damage shows as a single card-back with ×N badge; columns update live when cards are dealt, flipped, or repaired; toast appears on card deal; magnify scales the damage column; panel width adjusts; no visual change for undamaged ships.


## Damage Summary Overlay

**What this feature adds:** A full-screen overlay that displays damage cards in a flat horizontal row: `[faceup₁] [faceup₂] … [card-back] ×N`. Two triggers:
1. **After an attack** — shows only the cards just dealt (title: "Ship Name — Damage Dealt"). The faceup critical card remains faceup until the player clicks to dismiss, after which the immediate card effect resolves.
2. **Click damage column** in the ship card panel — shows ALL damage cards currently on that ship (title: "Ship Name — Damage Cards"). No deferred effects.

### MT-DSO.1 — Overlay appears after damage cards dealt

| Step | Action | Expected |
|------|--------|----------|
| 1 | Resolve an attack that deals at least 1 damage card to a ship | A dark semi-transparent overlay appears covering the full screen |
| 2 | Observe the overlay title | Shows "Ship Name — Damage Dealt" in amber text at the top |
| 3 | Observe the hint at the bottom | Shows "Click anywhere or press Escape to close" in muted grey |

### MT-DSO.2 — Horizontal row layout

| Step | Action | Expected |
|------|--------|----------|
| 1 | Resolve an attack with 1 faceup + 2 facedown cards | Row shows: [faceup card] [card-back] ×2 — all at the same vertical position, centred on screen |
| 2 | Hover over the faceup card | Tooltip shows the card title |
| 3 | Observe the card state in the ship card panel (behind the overlay) | The card still shows as faceup — it has NOT been flipped facedown yet |

### MT-DSO.3 — Facedown counter always visible

| Step | Action | Expected |
|------|--------|----------|
| 1 | Resolve an attack that deals 1 facedown card (no critical) | Row shows: [card-back] ×1 |
| 2 | Resolve an attack that deals 3 facedown cards | Row shows: [card-back] ×3 |

### MT-DSO.4 — Dismiss triggers immediate effect

| Step | Action | Expected |
|------|--------|----------|
| 1 | Overlay shows a faceup card with an immediate effect (e.g., Structural Damage, Projector Misaligned) | The card is still faceup — effect has NOT resolved yet |
| 2 | Click anywhere to dismiss the overlay | Overlay disappears; the immediate effect resolves (e.g., Structural Damage deals an extra facedown card, card flips facedown in the panel) |
| 3 | Observe the ship card panel | Facedown badge count increases by 1 (Structural Damage) or the card now shows as facedown (most immediate effects) |

### MT-DSO.5 — Dismiss with Escape key

| Step | Action | Expected |
|------|--------|----------|
| 1 | Overlay is visible after damage dealt | Overlay is showing |
| 2 | Press Escape | Overlay dismisses; immediate effects resolve; attack flow continues to finalize |

### MT-DSO.6 — Choice-based card defers to modal

| Step | Action | Expected |
|------|--------|----------|
| 1 | Resolve an attack dealing a choice-based faceup card (Injured Crew, Shield Failure, or Comm Noise) | Overlay shows the faceup card |
| 2 | Dismiss the overlay | The opponent choice modal appears (possibly after a hot-seat handoff overlay) |
| 3 | Make the choice and confirm | The choice card effect resolves; attack finalizes |

### MT-DSO.7 — Panel click shows all damage cards

| Step | Action | Expected |
|------|--------|----------|
| 1 | A ship has 2 faceup + 3 facedown damage cards | Ship card panel shows thumbnails + badge |
| 2 | Click any faceup thumbnail or the facedown badge | DamageSummaryOverlay opens with title "Ship Name — Damage Cards" |
| 3 | Observe the row | Shows: [faceup₁] [faceup₂] [card-back] ×3 — all current damage |
| 4 | Dismiss the overlay | No immediate effects triggered — this is an inspection-only view |

### MT-DSO.8 — Viewport resize while overlay is open

| Step | Action | Expected |
|------|--------|----------|
| 1 | Overlay is visible | Overlay covers the full screen |
| 2 | Resize the window | Overlay resizes to match the new viewport size |

### MT-DSO.9 — Row scales down for many cards

| Step | Action | Expected |
|------|--------|----------|
| 1 | A ship has many damage cards (e.g. 5+ faceup) | All cards fit within the viewport — row scales down proportionally if needed |

**Pass criteria:** Overlay shows cards in a flat horizontal row (faceup left, card-back + ×N right); ×N always shown (including ×1); faceup card NOT flipped until overlay dismissed after attack; panel click shows ALL damage cards with "Damage Cards" title; row scales down when many cards; Escape also dismisses.

---

## Phase 11 — Splash Screen & Main Menu

> **Launch with:** `./scripts/run_game.sh`
> **Requirements:** UI-029 – UI-033

### MT-11.1 — Splash screen displays on launch

| Step | Action | Expected |
|------|--------|----------|
| 1 | Launch the game via `./scripts/run_game.sh` | The `splash.jpg` image fills the viewport as a background |
| 2 | Observe the title text | "ARMADA" (large) and "digital" (smaller) are centred horizontally in the top 1/3 |
| 3 | Wait and do NOT click or press any key | The main menu modal does NOT appear immediately |

### MT-11.2 — Menu modal appears after 2 seconds

| Step | Action | Expected |
|------|--------|----------|
| 1 | On the splash screen, wait ~2 seconds without input | A modal panel appears in the centre of the screen |
| 2 | Observe the modal | Contains 4 buttons: "New Game", "Load Game", "Learning Scenario", "Quit" |
| 3 | Observe the splash background | The splash image remains visible behind the modal |

### MT-11.3 — Input skips splash timer

| Step | Action | Expected |
|------|--------|----------|
| 1 | Launch the game | Splash screen appears, no modal yet |
| 2 | Click anywhere (or press any key) before 2 seconds | Menu modal appears immediately |

### MT-11.4 — "Learning Scenario" starts the game

| Step | Action | Expected |
|------|--------|----------|
| 1 | Menu modal is visible | 4 buttons shown |
| 2 | Click "Learning Scenario" | Scene transitions to the game board with all learning scenario tokens placed |

### MT-11.5 — Placeholder buttons show toast

| Step | Action | Expected |
|------|--------|----------|
| 1 | Menu modal is visible | 4 buttons shown |
| 2 | Click "New Game" | A "Coming Soon" toast appears near the bottom of the screen |
| 3 | Click "Load Game" | A "Coming Soon" toast appears near the bottom of the screen |
| 4 | Wait ~2 seconds | Toast disappears |

### MT-11.6 — Quit closes the application

| Step | Action | Expected |
|------|--------|----------|
| 1 | Menu modal is visible | 4 buttons shown |
| 2 | Click "Quit" | Application window closes |

**Pass criteria:** Splash image fills viewport; title text in top 1/3; menu reveals after 2 s or on input; Learning Scenario transitions to game board; New Game / Load Game show "Coming Soon" toast; Quit closes the app.

### MT-11.7 — In-game ESC shows quit confirmation

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start the Learning Scenario from the main menu | Game board loads |
| 2 | Press Escape when no modal or tool is active | A centred confirmation dialog appears: "Quit game and exit to main menu?" with Yes and No buttons |
| 3 | The game board is visible behind the dialog | Dialog overlays the board |

### MT-11.8 — Quit confirmation "No" resumes the game

| Step | Action | Expected |
|------|--------|----------|
| 1 | Quit confirmation dialog is visible | Yes and No buttons shown |
| 2 | Click "No" | Dialog closes; game resumes normally |

### MT-11.9 — Quit confirmation Escape dismisses

| Step | Action | Expected |
|------|--------|----------|
| 1 | Quit confirmation dialog is visible | Yes and No buttons shown |
| 2 | Press Escape | Dialog closes; game resumes (same as clicking No) |

### MT-11.10 — Quit confirmation "Yes" returns to main menu

| Step | Action | Expected |
|------|--------|----------|
| 1 | Quit confirmation dialog is visible | Yes and No buttons shown |
| 2 | Click "Yes" | Scene transitions to the main menu (splash screen with menu modal) |

### MT-11.11 — ESC does not open quit dialog when other modal is active

| Step | Action | Expected |
|------|--------|----------|
| 1 | Open any modal (e.g. targeting list, maneuver tool, card detail overlay) | Modal is visible |
| 2 | Press Escape | The active modal closes; the quit confirmation does NOT appear |

**Updated pass criteria:** All original criteria plus: ESC shows quit dialog when no modal active; No/Escape dismiss it; Yes returns to main menu; ESC does not trigger quit when another modal is consuming it.

---

## Phase 12 — Sound & Music

**What this phase adds:** SFX for button interactions, dice rolls, and movement; dynamic background music with crossfade, shuffled in-game playlist, destruction overrides, and victory themes.

### MT-12.1 — Main menu music plays on load

| Step | Action | Expected |
|------|--------|----------|
| 1 | Launch the game | Splash screen appears |
| 2 | Wait for menu modal to appear | `rebel_theme.mp3` begins playing (background music) |

### MT-12.2 — Menu button SFX

| Step | Action | Expected |
|------|--------|----------|
| 1 | Menu modal is visible | 4 buttons shown |
| 2 | Click "New Game" | `droid_sound.wav` plays; "Coming Soon" toast appears |
| 3 | Click "Learning Scenario" | `droid_sound.wav` plays; scene transitions to game board |

### MT-12.3 — Gameplay music starts on game start

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start Learning Scenario from menu | Game board loads |
| 2 | Listen for music | A random in-game track (`in_game_N.mp3`) plays; rebel_theme fades out with crossfade |

### MT-12.4 — Confirm/skip button SFX during gameplay

| Step | Action | Expected |
|------|--------|----------|
| 1 | During Command Phase, assign dials and confirm | `droid_sound.wav` on Confirm button |
| 2 | Press Ready on player handoff | `droid_sound.wav` plays |
| 3 | Open activation modal, press Close (✕) | `skip_beep.wav` plays |
| 4 | In activation modal, skip a step | `skip_beep.wav` plays |

### MT-12.5 — Ship movement SFX

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a ship, reach Execute Maneuver step | Modal shows "Execute Maneuver ►" |
| 2 | Click "Execute Maneuver ►" | `droid_sound.wav` plays (shows maneuver tool) |
| 3 | Click "Commit Maneuver ►" | `star_destroyer_flyby.mp3` plays |

### MT-12.6 — Dice roll SFX (capital ship)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Declare an attack from a ship hull zone | Attack panel appears |
| 2 | Click "Roll Dice" | `turbolasers_shooting.mp3` plays |

### MT-12.7 — Dice roll SFX (squadron — rhythmic)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a Rebel squadron (X-wing) and choose Attack | Target selection begins |
| 2 | Select target and click "Roll Dice" | Multi-burst `x-wing_shooting.mp3` plays (4 shots with rhythm pattern) |
| 3 | Same with Imperial squadron (TIE) | Multi-burst `tie_shooting.mp3` plays (3 shots) |

### MT-12.8 — Squadron movement SFX

| Step | Action | Expected |
|------|--------|----------|
| 1 | Move a Rebel squadron and commit | `x-wing_flyby.mp3` plays |
| 2 | Move an Imperial squadron and commit | `tie_flyby.mp3` plays |

### MT-12.9 — Shuffled playlist advances on track end

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a game and note the first in-game track playing | An in-game track is audible |
| 2 | Wait for the track to finish (or shorten tracks for testing) | A different in-game track crossfades in |
| 3 | Repeat until several tracks have played | Each track is different; no immediate repeats |

### MT-12.10 — Destruction override music

| Step | Action | Expected |
|------|--------|----------|
| 1 | Destroy a Rebel ship (capital ship) | Music switches to `imperial_march.mp3` |
| 2 | Wait ~60 seconds | Music resumes shuffled playlist (crossfade to next in-game track) |

### MT-12.11 — Victory music

| Step | Action | Expected |
|------|--------|----------|
| 1 | Play to game end (round 6) with Imperial winning | `imperial_march.mp3` plays on victory screen |
| 2 | Play to game end with Rebel winning | `rebel_theme.mp3` plays on victory screen |

### MT-12.12 — Quit confirmation SFX

| Step | Action | Expected |
|------|--------|----------|
| 1 | Press ESC during gameplay (no modals active) | Quit dialog appears |
| 2 | Click "No" | `skip_beep.wav` plays; dialog closes |
| 3 | Press ESC again, click "Yes" | `droid_sound.wav` plays; transitions to main menu |

**Pass criteria:** Music plays with crossfade transitions at menu load, game start, track advancement, ship destruction, and victory. SFX fire on all confirm/skip buttons without doubling. Dice rolls produce correct SFX (turbolasers vs rhythmic squadron shots). Movement SFX plays on commit (ship flyby or faction-specific squadron flyby). Volume levels are consistent and not distorted.

---

## Post-Phase 12 — Bug Fixes (Music Loop, Modal Cleanup, Obstruction Dice)

**What this batch fixes:**
1. **Bug 1 (MUS-LOOP):** Background music tracks did not loop — they played once and stopped.
2. **Bug 2/3 (MODAL-CLEANUP):** Squadron modal, activation modal, and repair panel remained visible when a new phase started or an activation ended.
3. **Bug 5 (OBS-DICE):** Obstruction did not remove a die from the attack pool — the attacker must choose which die colour to remove.

### MT-BF.01 — Music looping

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a game, leave it idle on round 1 | Background music track plays |
| 2 | Wait for the track to finish its full duration (~2–3 min) | Track seamlessly loops from the beginning — no silence gap |

### MT-BF.02 — Modal cleanup on phase change

| Step | Action | Expected |
|------|--------|----------|
| 1 | Open the Squadron Activation modal during Squadron Phase | Modal is visible |
| 2 | End the Squadron Phase (complete all activations) | Modal disappears; Status Phase UI appears cleanly |
| 3 | Open a ship activation, open the Repair panel | Repair panel is visible |
| 4 | End that ship's activation | Repair panel and activation modal both close |

### MT-BF.03 — Obstruction die removal (defender chooses)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Position ships so a squadron obstructs LOS between attacker and defender | Obstruction detected log message appears |
| 2 | Observe the attack panel after dice pool is gathered | Orange label "Obstructed — remove 1 die:" appears with colour buttons for each available colour |
| 3 | Click a colour button (e.g. "Red") | That die is removed from the pool count, obstruction section hides, CF dial or Roll Dice proceeds |
| 4 | Repeat with only 1 colour in the pool | Die is auto-removed (no choice shown), attack continues |
| 5 | Repeat with an empty pool edge case | "(no removable dice — skipped)" message appears briefly, attack continues |

**Pass criteria:** Music loops indefinitely. Modals are cleaned up on phase/activation transitions. Obstruction removes exactly 1 die chosen by the attacker (or auto-removed when only 1 colour exists).

---

## Ghost Destroyed Ships & Squadrons

**What this adds:** After a ship or squadron is destroyed, its Ship Card Panel entry is dimmed to 35% opacity with a red "DESTROYED" label, its Activation Sidebar entry is dimmed to 50%, and it is skipped in all phase-transition logic (dial assignment, activation selection, status phase cleanup).

**Rules basis:** RRG p.7 — "All ship and upgrade cards belonging to destroyed ships are inactive."

### MT-GHOST.01 — Ship Card Panel ghosting on destruction

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a game with the learning scenario | Both players' ships visible in Ship Card Panel |
| 2 | Attack a ship until it is destroyed | Ship token removed from board; destruction SFX plays |
| 3 | Check the destroyed ship's card panel entry | Entry is dimmed (35% opacity), red "DESTROYED" label visible, entry is non-interactive (clicks do nothing) |
| 4 | Click on the dimmed entry | No dial drag initiated, no activation triggered |

### MT-GHOST.02 — Activation Sidebar ghosting

| Step | Action | Expected |
|------|--------|----------|
| 1 | Destroy a ship during Ship Phase | Ship marked with ✕ in sidebar |
| 2 | Observe the destroyed entry in the Activation Sidebar | Text is dimmed to ~50% opacity, colour is dark red |
| 3 | Destroy a squadron during Squadron Phase | Same ✕ and dimming for the squadron entry |

### MT-GHOST.03 — Destroyed ships skipped in Command Phase

| Step | Action | Expected |
|------|--------|----------|
| 1 | Destroy a player's ship | Ship removed from board |
| 2 | Advance to next round's Command Phase | Dial picker does NOT request a dial for the destroyed ship |
| 3 | Submit dials for remaining ships | Phase advances normally |

### MT-GHOST.04 — Destroyed ships skipped in Ship Phase activation

| Step | Action | Expected |
|------|--------|----------|
| 1 | Destroy one of a player's two ships | One ship destroyed |
| 2 | Advance to Ship Phase | Only the surviving ship can be activated |
| 3 | Activate the surviving ship | Phase advances (auto-pass for other player or next phase) |

### MT-GHOST.05 — Status Phase skips destroyed ships

| Step | Action | Expected |
|------|--------|----------|
| 1 | Destroy a ship, advance to Status Phase | Destroyed ship's defense tokens remain exhausted (not readied) |
| 2 | Observe the surviving ships | Their defense tokens are readied, activation flags reset |

**Pass criteria:** Destroyed ships/squadrons are visually dimmed and non-interactive. They are skipped in all phase transitions. Only surviving units participate in the game loop.

---

## Audio Controls in ActionToolbar

**What this adds:** Four new buttons in the lower-right ActionToolbar — play/pause toggle (⏸/▶), next track (⏭), volume down (−), and volume up (+) — separated from the tool buttons by a thin divider.

**Requirements:** MUS-011, MUS-012, MUS-013, MUS-014.

### MT-AUDIO.01 — Play/pause toggle

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a game; music is playing | ⏸ button visible in toolbar |
| 2 | Click ⏸ | Music pauses; button text changes to ▶; skip_beep SFX plays |
| 3 | Click ▶ | Music resumes from where it paused; button text changes back to ⏸ |

### MT-AUDIO.02 — Next track

| Step | Action | Expected |
|------|--------|----------|
| 1 | During gameplay, note the current track | Music is playing |
| 2 | Click ⏭ | Current track crossfades to next track in shuffled playlist; skip_beep SFX plays |
| 3 | If previously paused, click ⏭ | Music resumes on the next track; toggle label shows ⏸ |

### MT-AUDIO.03 — Volume controls

| Step | Action | Expected |
|------|--------|----------|
| 1 | Click + multiple times | Music volume increases audibly; no distortion at 100% |
| 2 | Click − multiple times | Music volume decreases audibly; at 0% music is silent |
| 3 | Click + after reaching 0% | Volume starts increasing again from 10% |
| 4 | Click − when already at 0% | No change; no error |
| 5 | Click + when already at 100% | No change; no error |

### MT-AUDIO.04 — Audio buttons always enabled

| Step | Action | Expected |
|------|--------|----------|
| 1 | Enter an activation that disables M/R/T/A buttons | Tool buttons are greyed out |
| 2 | Click ⏸, ⏭, −, + | All four audio buttons still respond (not disabled); music control works |

### MT-AUDIO.05 — Destruction override + skip

| Step | Action | Expected |
|------|--------|----------|
| 1 | Destroy a capital ship so override music plays | Imperial March or Rebel Theme starts |
| 2 | Click ⏭ | Override is cancelled; next track in shuffled playlist plays |

**Pass criteria:** All four audio buttons work at any time. Volume clamps at 0–100%. Play/pause label toggles correctly. Skip cancels destruction overrides. Audio buttons are never disabled by tool-button gating.

---

## Refactoring Phase A — Manual Verification

### MT-A1-02.01 — Activation modal step display after refactoring

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a game, assign command dials, advance to Ship Phase | Ship Phase HUD appears |
| 2 | Click a ship to open Activation Modal | Modal opens with 5 step rows; current step highlighted blue, future steps dimmed |
| 3 | Walk through activation: Reveal → Squadron → Repair → Attack → Maneuver | Each step highlights in turn; completed steps show green ✓ |
| 4 | After all steps complete | "End Activation ►" button appears |
| 5 | Press Escape to dismiss modal, click ship to re-open | Modal re-opens with preserved state |
| 6 | Resize window while modal is open | Layout remains intact |

### MT-A1-02.02 — Squadron modal cleanup at round boundary

| Step | Action | Expected |
|------|--------|----------|
| 1 | Advance to Squadron Phase, activate squadron(s) | Squadron modal appears and works normally |
| 2 | Complete all squadron activations for both players | Modal disappears; game transitions through Status Phase to next round's Command Phase |
| 3 | Verify no stale squadron modal is visible during Command Phase | No squadron modal present |

### MT-A1-02.03 — Defense tokens readied visually after Status Phase

| Step | Action | Expected |
|------|--------|----------|
| 1 | During Ship Phase, perform an attack and spend a defense token (Brace/Evade) | Token turns red/exhausted in Ship Card Panel |
| 2 | Complete the round (Ship → Squadron → Status → Command) | After Status Phase, exhausted tokens flip back to green/ready in Ship Card Panel |

### MT-A1-03.01 — Squadron modal after refactoring

| Step | Action | Expected |
|------|--------|----------|
| 1 | Advance to Squadron Phase | Squadron modal appears with correct title/subtitle |
| 2 | Click a squadron to activate | Move/Attack/Skip buttons appear |
| 3 | Move the squadron, commit move | "Commit Move" button appears and works |
| 4 | Attack or skip | Activation completes normally |
| 5 | During Ship Phase, use a Squadron command | Squadron command modal opens with ship name title and range restriction |
| 6 | Press Escape to dismiss, re-open | State preserved |

### MT-A1-04.01 — Ship card panel rendering after refactoring

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a game | Both players' ship cards appear in the sidebar with correct card art, defense tokens, and command dials |
| 2 | Click a ship card entry | Entry magnifies; click again to shrink back; art, tokens, and dials scale correctly |
| 3 | Advance to Command Phase, set dials | Dial stack shows correct facedown dials with overlap; after reveal, top dial shows command icon |
| 4 | Deal damage to a ship | Faceup damage thumbnails appear with tooltips; facedown cards show card-back badge with ×N count |
| 5 | Enter Discard Token mode, click a token | Token is removed, sidebar updates correctly |

### MT-A1-06.01 — Repair panel rendering after refactoring

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a ship with a Repair command dial | Repair panel appears with correct title, repair point count, and action buttons |
| 2 | Click shield restoration or discard-damage actions | Panel interaction works; shield/damage updates reflected in Ship Card Panel |
| 3 | Dismiss panel via "Done" | Panel disappears cleanly |

### MT-A1-07.01 — Displacement modal after refactoring

| Step | Action | Expected |
|------|--------|----------|
| 1 | Trigger a ship overlap that requires squadron displacement | Displacement modal appears listing affected squadrons |
| 2 | Select displacement positions | Commit button becomes enabled |
| 3 | Press Commit | Squadrons move to new positions; modal closes |

### MT-A1-08.01 — Game board UI after refactoring

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a game | Board loads with ship/squadron tokens, ship card panels, turn HUD, and action toolbar |
| 2 | Enter Command Phase | Dial picker modal opens; assign dials normally |
| 3 | Enter Ship Phase, activate a ship | Activation modal sequence (Reveal → Squadron → Repair → Attack → Maneuver) works |
| 4 | Perform Execute Maneuver | Maneuver tool + ghost preview appear; overlapping tokens displaced |
| 5 | Enter Squadron Phase | Squadron activation modal works normally |

### MT-A1-09.01 — Attack execution after refactoring

| Step | Action | Expected |
|------|--------|----------|
| 1 | Press "A" or click the Attack toolbar button | Enters attack simulator mode with range overlay |
| 2 | Click an attacker hull zone, then a valid target | LOS line drawn; range line drawn; dice pool displayed in panel |
| 3 | Click the attacker's own ship as target | Tooltip "Cannot target the same ship." appears; click rejected |
| 4 | During Ship Phase, press "Execute Attack ►" | Full attack sequence: attacker zone → target → dice → accuracy → defense → damage |
| 5 | Spend a defense token (Brace, Evade, Redirect, Scatter) | Token effect applied correctly; token exhausts visually |
| 6 | Attack multiple hull zones (Victory-class) | After first attack, next zone offered; previously fired zone locked |
| 7 | Perform anti-squadron attack loop | Each squadron targeted once; "already attacked" tooltip for duplicates |

### MT-A1-10.01 — Game manager functions after refactoring

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a game with fixed round-1 commands | Pre-assigned dials appear; command phase skipped in round 1 |
| 2 | In Command Phase (round 2+), assign and confirm dials | Phase transitions normally after all ships assigned |
| 3 | Activate a ship, convert dial to token | "Activate as Token" adds the command token correctly |

---

## Refactoring Phase A4 — Remaining Oversized Functions

Phase A4 completed the extraction of all remaining oversized functions
(> 30 body lines) across 13 files. Pure structural refactoring — no
game-logic changes. GUT baseline unchanged: 87 scripts, 1648 tests,
1647 passing, 1 pre-existing failure.

### MT-A4.01 — Core logic after refactoring

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a ship, execute maneuver | Maneuver tool and ghost preview behave correctly; final position matches expected |
| 2 | Maneuver into another ship | Overlap resolution triggers; pushed ship repositions; no stuck tokens |
| 3 | Perform ship-to-ship attack | Range/LOS measurement works; dice pool correct for hull zone |
| 4 | Perform ship-to-squadron attack | Range/LOS measurement works; damage applied correctly |
| 5 | Activate Repair command | Engineering points calculated correctly; hull/shield repair works |
| 6 | Trigger a Comm Noise damage card | Opponent choice modal appears with reduce-speed and change-dial options |

### MT-A4.02 — Visual/presentation after refactoring

| Step | Action | Expected |
|------|--------|----------|
| 1 | Launch game from main menu | Splash background, title labels, and menu modal render correctly |
| 2 | Open the board; observe ship tokens | Firing arc boundary lines display correctly on all ships |
| 3 | Reveal a command dial | Dial icon sprite appears behind the ship at correct scale and position |
| 4 | Start maneuver; observe speed +/- buttons | Circle buttons draw correctly; ghost label text renders cleanly |
| 5 | Hover over a token; check tooltip | Tooltip background, text, and shadow colours match config |
| 6 | Open targeting list (via "T" key or toolbar) | All ship/squadron targets listed with correct range, LOS, and threat info |
---

## Post-A4 Bug Fixes — Attack Flow, Squadron Ghost, Modal Drift

Three gameplay bugs found during post-A4 playtesting, plus a
learning-scenario data update to rules-compliant round-1 commands.

**Bug 1 — Attack flow stall:** Dismissing the damage summary overlay
without selecting a new target caused the attack panel to never
reappear. Fix: emit `dismissed` signal on early return and rename
a skin texture to match the expected filename.

**Bug 2 — Squadron ghost timing:** The activated-visual flag was
set *after* `EventBus.squadron_activation_ended` emitted, so the
board handler saw the old (non-activated) state. Fix: move
`set_activated_visual(true)` before the signal emit.

**Bug 3 — Modal horizontal drift:** Both the ActivationModal and
AttackSimPanel drifted leftward by ~20 px per reopen cycle.
Root cause: `size = Vector2.ZERO` in `_build_ui()` and
`_deferred_layout_reset()` zeroed the horizontal width; when
content children inflated the panel beyond `custom_minimum_size.x`
(360 → 401 px), Godot preserved the left edge and grew rightward,
shifting the visual centre leftward each cycle. Fix: changed to
`size.y = 0` (vertical only) in both panels. Updated §10 pattern
in `.skills/ui_styling.md` and ADR-011.

GUT baseline after fixes: 88 scripts, 1 652 tests, all passing.

### MT-PostA4.01 — Attack flow completes without stalling

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start an attack against any ship | Attack panel appears with dice |
| 2 | Complete the attack (confirm dice, skip/use defense tokens, resolve damage) | Damage summary overlay appears |
| 3 | Dismiss the damage summary overlay | Attack panel closes cleanly; activation modal returns |
| 4 | Repeat 2–3 more attacks in the same game | No stalls; attack flow restarts correctly each time |

### MT-PostA4.02 — Squadron activation visual persists

| Step | Action | Expected |
|------|--------|----------|
| 1 | Enter Squadron Phase | Squadron tokens are clickable |
| 2 | Activate a squadron (click → move/attack → done) | Squadron shows activated visual (dimmed/marked) |
| 3 | Activate remaining squadrons | Each squadron retains its activated visual after completion |
| 4 | Advance to Status Phase and back to next round | Activated visuals reset at round start |

### MT-PostA4.03 — Attack panel stays centred across reopens

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start an attack | Attack panel appears centred at bottom of screen |
| 2 | Complete the attack and dismiss the damage summary | Panel closes |
| 3 | Start another attack | Panel reappears at the **same** centred position |
| 4 | Repeat 3–4 more attacks | Panel horizontal position remains stable — no leftward drift |

### MT-PostA4.04 — Activation modal stays centred across reopens

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a ship | Activation modal appears centred at bottom |
| 2 | Complete all steps, end activation | Modal closes |
| 3 | Activate the next ship | Modal reappears at the **same** centred position |
| 4 | Repeat for all ships in the round | Modal horizontal position remains stable |

---

## Phase 9.6 — Wire Remaining Damage Card Effect Hooks

**What this phase adds:** Connects the 8 unresolved effect hooks so that all 22 damage card effects actually fire during gameplay. Fixes the Projector Misaligned logic bug and the Crew Panic unregister leak.

**Prerequisite:** Post-A4 bug fixes complete. All 88 scripts / 1 652 tests passing.

### MT-9.6.01 — Ruptured Engine triggers after maneuver at speed ≥ 2

| Step | Action | Expected |
|------|--------|----------|
| 1 | Deal Ruptured Engine faceup to a ship (e.g. via attack critical) | Card appears faceup on ship card panel |
| 2 | On that ship's next activation, execute a maneuver at speed 2 | After maneuver commits, ship suffers 1 facedown damage card (hull decreases by 1) |
| 3 | Repeat maneuver at speed 1 | No extra damage dealt |

### MT-9.6.02 — Damaged Controls triggers on overlap

| Step | Action | Expected |
|------|--------|----------|
| 1 | Deal Damaged Controls faceup to a ship | Card appears faceup on ship card panel |
| 2 | Maneuver that ship so it overlaps another ship | Normal overlap resolution + 1 additional facedown damage card from Damaged Controls |

### MT-9.6.03 — Thrust Control Malfunction reduces yaw

| Step | Action | Expected |
|------|--------|----------|
| 1 | Deal Thrust Control Malfunction faceup to a ship | Card appears faceup |
| 2 | Start that ship's maneuver | Last adjustable joint has 1 less yaw click available than the chart shows |

### MT-9.6.04 — Thruster Fissure triggers on speed change

| Step | Action | Expected |
|------|--------|----------|
| 1 | Deal Thruster Fissure faceup to a ship | Card appears faceup |
| 2 | During that ship's maneuver, press speed +/- to change speed | Ship suffers 1 facedown damage card immediately |
| 3 | Execute the maneuver at the same speed (no change) | No extra damage |

### MT-9.6.05 — Crew Panic triggers before dial reveal

| Step | Action | Expected |
|------|--------|----------|
| 1 | Shift+D a ship → select Crew Panic | Card appears faceup |
| 2 | Click the ship's dial stack (first click) | Dial reveals normally |
| 3 | Click the revealed dial (second click) | **Crew Panic modal appears immediately** — no drag preview visible |
| 4 | Choose "Suffer 1 facedown damage" | Ship takes 1 facedown damage; **drag starts** and dial preview follows cursor |
| 5 | Drop dial on ship token | Ship activates with full command effect |
| 6 | (Alternative at step 4) Choose "Discard command dial" | Dial disappears from card panel; ship activates with no command (Activation Sequence button appears) |
| 7 | End Activation → confirm activation ends cleanly | No orphan drag preview, no stale modal |

### MT-9.6.06 — Compartment Fire blocks token readying

| Step | Action | Expected |
|------|--------|----------|
| 1 | Deal Compartment Fire faceup to a ship | Card appears faceup |
| 2 | Spend (exhaust) a defense token during an attack | Token shows exhausted state |
| 3 | Advance to Status Phase | Affected ship's defense tokens do NOT ready; other ships' tokens ready normally |

### MT-9.6.07 — Life Support Failure blocks token gain

| Step | Action | Expected |
|------|--------|----------|
| 1 | Deal Life Support Failure faceup to a ship | All command tokens discarded immediately; card stays faceup |
| 2 | Attempt to convert a dial to a token on that ship | Token gain is blocked; tooltip or message explains why |

### MT-9.6.08 — Attack validation effects (Depowered Armament, Disengaged FC, Coolant Discharge)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Deal Depowered Armament to a ship | Card appears faceup |
| 2 | Try to attack a target at long range from that ship | Attack is blocked; tooltip: "Cannot attack at long range (Depowered Armament)" |
| 3 | Attack at close or medium range | Attack proceeds normally |
| 4 | Deal Disengaged Fire Control to a ship | Card appears faceup |
| 5 | Try to attack an obstructed target | Attack is blocked; tooltip explains |
| 6 | Deal Coolant Discharge to a ship | Card appears faceup; first ship attack works normally (+1 damage at close range) |
| 7 | Try to start a second ship attack in the same activation | Attack is blocked (once per round limit) |

### MT-9.6.09 — Capacitor Failure blocks shield recovery

| Step | Action | Expected |
|------|--------|----------|
| 1 | Deal Capacitor Failure to a ship | Card appears faceup |
| 2 | Spend a Repair command to recover shields on a zone that has 0 shields | Recovery is blocked |
| 3 | Recover shields on a zone with ≥ 1 shield | Recovery works normally |

### MT-9.6.10 — Projector Misaligned (corrected logic)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Deal Projector Misaligned faceup to a ship with shields: Front=3, Right=1, Left=2, Rear=1 | Zone with most shields (Front, 3) loses ALL shields → Front becomes 0. Other zones unchanged. Card flips facedown. |
| 2 | (Tied case) Ship with Front=2, Rear=2, Left=1, Right=1 | Choice modal: "Choose a hull zone" between Front and Rear. Selected zone loses all shields. |

### MT-9.6.11 — Crew Panic is persistent (fires every round)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Shift+D a ship → select Crew Panic | Card appears faceup |
| 2 | Activate ship, choose "Discard command dial" | Dial discarded; ship activates without command; **Crew Panic card stays faceup** |
| 3 | Next round: activate same ship | Crew Panic modal appears again |
| 4 | Choose "Suffer 1 facedown damage" this time | Damage dealt; drag starts; activation proceeds normally |
| 5 | Next round: activate same ship again | Crew Panic modal appears yet again (card is still faceup and registered) |

---

## Phase 9.7 — Debug Faceup Damage Dealing (Shift+D)

**What this phase adds:** A debug-mode cheat key (Shift+D) that lets the tester deal any faceup damage card to any ship, bypassing combat. Enables rapid manual testing of all 22 damage card effects.

**Prerequisite:** Debug mode toggle (F12) working. Phase 9.6 complete (all hooks wired).

### MT-9.7.01 — Debug deal faceup damage via Shift+D

| Step | Action | Expected |
|------|--------|----------|
| 1 | Press F12 to enable debug mode | Debug HUD appears; help panel shows Shift+D under "Cheats" |
| 2 | Press Shift+D | Tooltip: "Click a ship to deal faceup damage" |
| 3 | Click a ship token | OpponentChoiceModal opens listing all 22 damage card types |
| 4 | Select "Ruptured Engine" and confirm | Card dealt faceup to ship; card panel updates; persistent effect registered |
| 5 | Execute a maneuver at speed 2 on that ship | Ruptured Engine fires — extra facedown damage dealt |
| 6 | Press Shift+D again, click same ship, select "Structural Damage" | Immediate effect resolves: extra facedown card dealt, Structural Damage flips facedown |
| 7 | Press Shift+D then Escape | Targeting mode cancelled; no modal appears |
| 8 | Without debug mode (F12 off), press Shift+D | Nothing happens |

---

## Refactoring Phase B1 — Replace `_board` Reference With Callables

**What this phase changes:** `attack_executor.gd` no longer holds a `Node2D`
reference to `GameBoard`. Two `Callable` parameters (`_get_ship_tokens`,
`_get_squadron_tokens`) are injected via `initialize()`. No new behaviour —
purely an interface change that eliminates a circular type-dodge.

**Commit:** `d7a93e1` — Tests: 1 669 (88 scripts, 2 932 asserts).

### MT-B1.01 — Attack Simulator shows valid targets

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run the game board scene (F6) | Board loads, tokens appear |
| 2 | Hover a ship's hull zone | Valid enemy targets in arc + range highlight correctly (ship and squadron) |
| 3 | Move hover to a different hull zone | Highlights update to match the new arc |

### MT-B1.02 — Ship-to-ship attack resolves normally

| Step | Action | Expected |
|------|--------|----------|
| 1 | Initiate a ship attack on an enemy ship | Attack flow starts: dice roll, modification steps, damage applied |
| 2 | Complete the attack | Flow ends cleanly; damage shows in card panel |

### MT-B1.03 — Multi-squadron attack prompt

| Step | Action | Expected |
|------|--------|----------|
| 1 | Initiate a ship attack against a squadron | Attack flow proceeds with anti-squadron dice |
| 2 | After first squadron attack resolves | "More targets?" prompt appears if additional squadrons are in arc + range |

### MT-B1.04 — Capacitor Failure blocks Redirect at zero shields

| Step | Action | Expected |
|------|--------|----------|
| 1 | Deal Capacitor Failure (Shift+D) to a ship with 0 shields on the defending zone | Card appears faceup |
| 2 | Attack that ship on the zero-shield zone | Redirect token is blocked (greyed out / cannot spend) |
| 3 | Attack the same ship on a zone with ≥ 1 shields | Redirect token is available normally |

---

## Refactoring Phase C1 — Extract DisplacementController

**What this phase changes:** All 12 displacement functions and 6 state variables
moved from `game_board.gd` into a new `DisplacementController` (child Node2D).
No new behaviour — purely structural; the controller communicates back via signal.

**Commit:** `a9e18c7` — Tests: 1 669 (88 scripts, 2 932 asserts).

### MT-C1.01 — Squadron displacement after ship maneuver

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a ship adjacent to enemy squadrons | Activation flow starts |
| 2 | Execute a maneuver that overlaps the squadrons | Camera rotates to opponent view; displacement modal appears listing displaced squadron(s) |
| 3 | Mouse-follow each squadron to the ship edge; left-click to lock | Squadron snaps to edge; tints red if placement invalid, white if valid |
| 4 | Click "Commit" when all squadrons placed | Modal closes; camera rotates back to active player |
| 5 | Confirm activation resumes | End Activation button appears; flow continues normally |

---

## Refactoring Phase C2 — Extract DialDragController

**What this phase changes:** 3 drag-state variables and 8+ drag functions
(start, preview, release, cancel, cleanup) moved from `game_board.gd` into a
new `DialDragController` (child Node2D).  GameBoard receives `ship_activated`
and `token_converted` signals to set up activation state.

**Commit:** `0b1595e` — Tests: 1 669 (88 scripts, 2 932 asserts).

### MT-C2.01 — Dial drag to ship token (full activation)

| Step | Action | Expected |
|------|--------|----------|
| 1 | In Ship Phase, click a ship's hidden dial in the card panel | Dial reveals (first click) |
| 2 | Click the revealed dial again | Floating semi-transparent dial preview appears and follows mouse |
| 3 | Drag the preview over the owning ship token on the board; release | Activation sound plays; dial sprite shows behind ship base; "Show Activation Sequence" button appears |
| 4 | Complete the activation sequence | Flow proceeds normally through all steps |

### MT-C2.02 — Dial drag to card panel (token conversion)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Click a ship's hidden dial, then click the revealed dial | Floating preview appears |
| 2 | Drag the preview back over the same ship's card panel entry; release | Activation sound plays; dial is spent; command token added to ship; "Show Activation Sequence" button appears |

### MT-C2.03 — Dial drag miss (cancel)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a dial drag | Floating preview appears |
| 2 | Release the mouse over empty space (not on ship or card panel) | Preview disappears; dial returns to hidden state; no activation occurs |

---

## Refactoring Phase C3 — Extract CommandPhaseController

**What this phase changes:** 3 command-phase variables (`_ships_needing_dials`,
`_command_dial_picker`, `_command_dial_order_modal`) and 7 functions moved from
`game_board.gd` into a new `CommandPhaseController` (child Node).  The
controller owns its own CanvasLayer (layer 60) for the picker and order-modal
UI.  `game_board.gd` calls `begin_command_dial_flow()` from
`_on_handoff_accepted` and connects the controller's `phase_complete` signal to
`_update_phase_hud`.

**Commit:** `8042b86` — Tests: 1 669 (88 scripts, 2 932 asserts).

### MT-C3.01 — Command dial assignment flow

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a new game; reach the Command Phase | Handoff overlay appears for the first player |
| 2 | Accept the handoff | Command Dial Picker opens for the first ship needing a dial |
| 3 | Select a command in the picker; confirm | Dial is assigned; picker advances to the next ship |
| 4 | Assign dials for all remaining ships of the current player | After the last ship, picker closes; if a second player exists, handoff overlay appears again |
| 5 | Complete dials for all players | Phase transitions to Ship Phase (phase HUD updates) |

### MT-C3.02 — Command dial order modal

| Step | Action | Expected |
|------|--------|----------|
| 1 | During Command Phase, reach a ship that already has dial(s) in its stack | "Command Dial Order" modal appears allowing reorder / confirmation |
| 2 | Confirm the order | Picker advances to next ship normally |

---

## Refactoring Phase C4 — Extract DebugController

**What this phase changes:** 5 debug-related variables (`_deploy_overlay`,
`_debug_label`, `_debug_help_panel`, `_was_in_deploy_zone`, `_scenario_saver`)
and 7 functions (including `_on_debug_mode_changed`) moved from `game_board.gd`
into a new `DebugController` (child Node).  The controller creates its own
CanvasLayer for the DEBUG HUD and connects DebugMode signals internally.
`game_board.gd` calls three public methods: `handle_debug_click()`,
`check_zone_crossing_toast()`, and `reset_zone_tracking()`.

**Commit:** `6121dc6` — Tests: 1 669 (88 scripts, 2 932 asserts).

### MT-C4.01 — Debug mode toggle

| Step | Action | Expected |
|------|--------|----------|
| 1 | Press the debug toggle key (`) | "DEBUG" label appears at top-left; deployment zone overlay becomes visible; help panel shows shortcuts |
| 2 | Press the toggle key again | All debug overlays disappear |

### MT-C4.02 — Debug select / deselect / drag

| Step | Action | Expected |
|------|--------|----------|
| 1 | Enable debug mode; click a ship token | Token highlights (selected) |
| 2 | Move the mouse | Token follows mouse with collision resolution |
| 3 | Click empty space | Token deselects; stops following mouse |

### MT-C4.03 — Deployment zone crossing toast

| Step | Action | Expected |
|------|--------|----------|
| 1 | In debug mode, select a token near its deployment zone edge | Token follows mouse |
| 2 | Drag the token outside its deployment zone boundary | Toast appears: "<ship name> is outside deployment zone" |
| 3 | Drag it back inside the zone, then outside again | Toast fires again on each crossing |

### MT-C4.04 — Save positions (debug)

| Step | Action | Expected |
|------|--------|----------|
| 1 | In debug mode, press the save-positions shortcut | Console logs "Token positions saved successfully" (or the file is written) |

---

## Refactoring Phase C5 — Extract ManeuverToolController

**What this phase changes:** 2 maneuver-tool variables (`_maneuver_tool_selecting`,
`_maneuver_tool_scene`) and 4 functions moved from `game_board.gd` into a new
`ManeuverToolController` (child Node).  The controller exposes `get_scene()` for
activation-flow code that reads ManeuverToolScene state, and
`show_activation_tool()` for the activation-mode creation path.
`game_board.gd` uses a `_dismiss_maneuver_tool_with_preview()` wrapper to pass
the activation ship for navigate-token preview cleanup.

### MT-C5.01 — Simulation maneuver tool (M key / toolbar)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Press M or click the Maneuver Tool toolbar button | Toast "Select a ship" appears; cursor is in selection mode |
| 2 | Click a ship token | Maneuver tool attaches to the ship (joint handles visible) |
| 3 | Press M again (or Escape) | Maneuver tool dismisses |

### MT-C5.02 — Activation-mode maneuver tool

| Step | Action | Expected |
|------|--------|----------|
| 1 | During Ship Phase, activate a ship with speed > 0 | Activation sequence modal appears |
| 2 | Reach the Maneuver step | Maneuver tool appears on the activating ship in activation mode (Execute button in modal) |
| 3 | Adjust joints and click Execute | Ship snaps to final position; tool dismisses |

### MT-C5.03 — Ghost range overlay toggle

| Step | Action | Expected |
|------|--------|----------|
| 1 | Show the maneuver tool on a ship (M key + click) | Tool visible |
| 2 | Press R (range overlay shortcut) | Range overlay appears on the ghost preview (not requiring separate ship selection) |
| 3 | Press R again | Ghost range overlay dismisses |
**Commit:** `4aac035` — Tests: 1 669 (88 scripts, 2 932 asserts).
---

## Refactoring Phase C6 — Extract RangeToolController

**What this phase changes:** 2 range-overlay variables (`_range_overlay_selecting`,
`_range_overlay_scene`) and 4 functions (`_show_range_overlay`, `_dismiss_range_overlay`,
`_cancel_range_overlay_selection`, `_handle_range_overlay_escape`) moved from
`game_board.gd` into a new `RangeToolController` (child Node).
`game_board.gd` keeps `_on_range_overlay_requested` for the toggle logic which
delegates to the controller, and the separate `_squad_cmd_range_overlay` which has
its own lifecycle.

### MT-C6.01 — Range overlay via R key

| Step | Action | Expected |
|------|--------|----------|
| 1 | Press R | Toast "Select a ship" appears; cursor is in selection mode |
| 2 | Click a ship token | Range overlay (coloured arcs + range bands) attaches to the ship |
| 3 | Press R again | Range overlay dismisses |

### MT-C6.02 — Range overlay Escape handling

| Step | Action | Expected |
|------|--------|----------|
| 1 | Press R to enter selection mode | Toast "Select a ship" visible |
| 2 | Press Escape | Selection cancelled; toast disappears |
| 3 | Press R, then click a ship | Overlay visible |
| 4 | Press Escape | Overlay dismisses |

### MT-C6.03 — Ghost range overlay (maneuver tool active)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Show maneuver tool on a ship (M + click) | Tool visible |
| 2 | Press R | Range overlay appears on the ghost preview |
| 3 | Press R again | Ghost overlay dismisses |

**Commit:** `8526886` — Tests: 1 669 (88 scripts, 2 932 asserts).
---

## Refactoring Phase C7 — Extract SquadronPhaseController

**What this phase changes:** 7 squadron-phase variables and 21 functions
moved from `game_board.gd` into a new `SquadronPhaseController` (child Node).
The controller owns the `SquadronActivationModal`, `ShowSquadronModalButton`,
`SquadronMoveOverlay`, squadron command range overlay, and all movement/attack
delegation logic. Cross-cluster refs (attack executor, activation button)
injected as Callables at `initialize()`.

### MT-C7.01 — Squadron Phase activation flow

| Step | Action | Expected |
|------|--------|----------|
| 1 | Reach Squadron Phase (after all ships activated) | Handoff overlay → Squadron Activation Modal appears |
| 2 | Click a friendly squadron in the modal | Movement + armament overlay appears on the squadron |
| 3 | Click "Move" then drag the squadron | Token follows mouse within speed ring |
| 4 | Left-click to commit placement | Token locks; updated target availability shown |
| 5 | Click "Attack" (if targets available) | Attack executor opens for squadron attack |
| 6 | Complete or skip attack | Activation done; modal opens for next activation |

### MT-C7.02 — Squadron command mode (during Ship Phase)

| Step | Action | Expected |
|------|--------|----------|
| 1 | During Ship Phase, activate a ship with Squadron dial | Activation modal reaches Squadron step |
| 2 | Squadron command modal opens in command mode | Range overlay on the activating ship; squadron list shown |
| 3 | Activate squadrons via the modal | Each activation completes; resolver tracks remaining |
| 4 | Finish or exhaust activations | Modal closes; activation step advances |

### MT-C7.03 — Squadron modal dismiss + reopen

| Step | Action | Expected |
|------|--------|----------|
| 1 | During Squadron Phase, dismiss the modal (Escape / ✕) | "Show Squadron Modal" button appears at bottom |
| 2 | Click the "Show Squadron Modal" button | Modal reopens |

**Commit:** `35cb7e3` — Tests: 1 669 (88 scripts, 2 932 asserts).

**Bug fix commits:**
- `f2098d2` — Inline lambda extraction (multi-line lambda in function-call args silently Nil'd)
- `30ae6c8` — `get_global_mouse_position()` on Node base + null guards on all call sites
- `8ca3bf9` — `_ready()` init order: controller must exist before `create_ui()` is called

---

## Phase D1 — Section Builder Methods (Return-Pattern Normalize)

> **Commit:** `c35653b` — refactor(ui): D1 — normalize `_build_*` methods to return pattern
> **Tests:** 1 669 (88 scripts, 2 932 asserts)

**What this phase changes:** Converts all `_build_*()` section methods across 13 UI files from void (adding to parent/member) to the return pattern (create, configure, return). No user-visible behaviour change — this is a purely internal consistency refactor.

**Manual testing goal:** Confirm that every affected modal/panel still renders correctly and functions as before.

### MT-D1.01 — Command Dial Picker visual check

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a game, reach Command Phase | Command Dial Picker opens for first ship |
| 2 | Verify title shows ship name + round | Title, subtitle, command icons, stack area all render correctly |
| 3 | Select commands and press CONFIRM | Picker closes; dial assigned |

### MT-D1.02 — Activation Modal visual check

| Step | Action | Expected |
|------|--------|----------|
| 1 | Reach Ship Phase, click a ship to activate | Activation modal opens at bottom-centre |
| 2 | Verify 5 step rows with correct labels | Header labels, step rows, End Activation button, Close/Escape hint all present |
| 3 | Execute maneuver + attack through the modal | All steps advance; modal closes on End Activation |

### MT-D1.03 — Attack Sim Panel visual check

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start an attack (Execute Attack in activation modal) | Attack panel opens at bottom-centre |
| 2 | Verify sections: title, dice count, roll button | All sections render; hidden sections stay hidden |
| 3 | Roll dice, go through CF/accuracy/defense/redirect steps | Each section appears and functions when its step activates |

### MT-D1.04 — Squadron Activation Modal visual check

| Step | Action | Expected |
|------|--------|----------|
| 1 | Reach Squadron Phase | Squadron modal opens with title + prompt |
| 2 | Click a friendly squadron | Action buttons (Move/Attack/Skip) appear |
| 3 | Dismiss (Escape) and reopen via button | Modal reopens correctly |

### MT-D1.05 — Repair Panel + Displacement Modal

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a ship with a Repair dial | Repair panel opens with title, points, actions, buttons |
| 2 | If displacement triggers after overlap resolution | Displacement modal opens with header, squadron rows, commit button |

### MT-D1.06 — Victory Screen + Opponent Choice Modal

| Step | Action | Expected |
|------|--------|----------|
| 1 | Play to game end (or force via debug) | Victory screen shows with title, scores, Play Again / Quit buttons |
| 2 | If a damage card requires opponent choice | Opponent choice modal shows with title, effect text, option buttons, Confirm |

### MT-D1.07 — Targeting List + Quit Confirmation

| Step | Action | Expected |
|------|--------|----------|
| 1 | Press "T" during Ship Phase | Targeting list modal opens with scrollable ship/squadron sections |
| 2 | Press Escape to open quit confirmation | Quit modal shows question label + Yes/No buttons |

**Pass criteria:** All modals/panels render identically to pre-D1. No visual regressions, no missing widgets, no layout drift. All buttons function. 1 669 tests pass.

---

## Phase D2 — UIStyleHelper Utility

**Scope:** `src/utils/ui_style_helper.gd` created; 10 files converted to
`UIStyleHelper.create_modal_panel_style()`, 3 files converted to
`UIStyleHelper.create_dismiss_hint()`. GUT covers constants and factories
(30 tests). Manual tests verify visual parity only.

**Commits:**
- (this commit) — UIStyleHelper utility + replacements across 10 modal panels + 3 dismiss hints

### MT-D2.01 — Activation Modal Panel Style

| Step | Action | Expected |
|------|--------|----------|
| 1 | Open game, activate a ship with a dial | Activation modal appears — same dark-blue background, blue border, rounded corners, same spacing |
| 2 | Check dismiss hint at bottom | "Press Escape to dismiss" text is small, grey, centred |

### MT-D2.02 — Attack Sim Panel Style

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start an attack (select attacker zone → select target) | Attack sim panel appears — identical panel style, no layout drift |

### MT-D2.03 — Squadron Activation Modal Style

| Step | Action | Expected |
|------|--------|----------|
| 1 | Enter squadron phase, click a squadron | Squadron activation modal opens — dark panel, same border, no content margin gaps |

### MT-D2.04 — Command Dial Picker Style

| Step | Action | Expected |
|------|--------|----------|
| 1 | During Command Phase, right-click a ship | Command dial picker appears — same panel look, no margin changes |

### MT-D2.05 — Repair Panel + Displacement Modal

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a ship with a Repair command | Repair panel opens — same panel style, "Press Escape to finish" hint in grey |
| 2 | Force displacement after overlap resolution | Displacement modal opens — same panel look, rounded corners |

### MT-D2.06 — Targeting List + Quit Confirmation + Opponent Choice

| Step | Action | Expected |
|------|--------|----------|
| 1 | Press "T" during Ship Phase | Targeting list modal — same panel style as before D2 |
| 2 | Press Escape to open quit confirmation | Quit modal — same panel, same buttons |
| 3 | If opponent choice modal triggers | Same panel style, same layout |

### MT-D2.07 — Command Dial Order Modal

| Step | Action | Expected |
|------|--------|----------|
| 1 | Right-click a ship's dial stack (after dials assigned) | Command dial order modal opens — slightly darker background (intentional variant), same border, "Click anywhere to close" hint in grey |

**Pass criteria:** All modals/panels render identically to pre-D2. No visual regressions. Panel backgrounds, borders, corner radii, margins, and dismiss hint text all match previous appearance. 1 699 tests pass (89 scripts, 2 966 asserts).

---

## Phase D3 — Split ShipCardPanel

> **Goal:** Extract construction and populate logic from `ShipCardPanel` into
> `ShipCardEntryBuilder` and `DamageCardDisplay`. Pure structural refactoring —
> no visual or behavioural changes.

### MT-D3.01 — Card Panel Renders Identically

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run the game board scene (F6) | Both Rebel and Imperial card panels appear with ship cards, defense tokens, command dials, command tokens — identical to pre-D3 |
| 2 | Click a ship card to magnify it | Entry expands smoothly, tokens/dials/damage scale correctly |
| 3 | Click again to un-magnify | Entry returns to normal size |

### MT-D3.02 — Damage Display Works

| Step | Action | Expected |
|------|--------|----------|
| 1 | Deal faceup and facedown damage to a ship (via debug or gameplay) | Faceup damage thumbnails and facedown "×N" badge appear in the card panel |
| 2 | Click a faceup damage thumbnail | Damage summary overlay opens showing all damage on that ship |
| 3 | Click the facedown badge | Same damage summary overlay opens |

### MT-D3.03 — EventBus Updates Reflect

| Step | Action | Expected |
|------|--------|----------|
| 1 | Exhaust a defense token (via gameplay) | Token appearance changes in the card panel (dimmed/rotated) |
| 2 | Assign command dials and reveal one | Dial stack updates correctly — revealed dial shows icon, hidden dials show card back |
| 3 | Gain or spend a command token | Command token column updates in real-time |

### MT-D3.04 — Token Discard Mode

| Step | Action | Expected |
|------|--------|----------|
| 1 | Trigger token overflow (give a ship a 5th token) | Discard prompt appears, tokens turn pinkish and are clickable |
| 2 | Click a token to discard | Token removed, discard mode exits, column refreshes |

**Pass criteria:** All card panel visuals and interactions identical to pre-D3. No regressions in token display, dial stacks, damage cards, magnify, or discard mode. 1 699 tests pass (89 scripts, 2 966 asserts).

---

## Phase E — Serialization & EventBus Cleanup

Phase E is pure core-logic and autoload work (no visual changes).
All validation is covered by GUT tests — **no manual testing required.**

**GUT baseline:** 90 scripts, 1 737 tests, 3 083 asserts — all passing.

### MT-E.01 — Save/Load Smoke Test ✅

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run the game, play through at least one phase transition | Normal gameplay |
| 2 | Press **F12** to enable debug mode | Debug HUD appears; help panel shows F5/F8 under "Save / Load" |
| 3 | Press **F5** | Console logs "Quicksave complete."; file appears at `saves/quicksave.json` in project folder |
| 4 | Open `saves/quicksave.json` in a text editor | JSON contains `current_round`, `player_states` with ships/squadrons arrays, `damage_deck` draw/discard piles |
| 5 | Press **F8** | Console logs "Quickload OK — round X, phase Y, p0 score Z, p1 score W" |

**Pass criteria:** JSON file is well-formed, round-trip preserves all fields. ✅ Tested manually.

---

## Refactoring Phase F — Backbone & ActivationContext Extraction

Phase F extracts shared activation state (F1) and UI panel lifecycle (F3)
from `game_board.gd`. Pure structural refactoring — no game-logic changes.

**GUT baseline:** 92 scripts, 1 754 tests, 3 113 asserts — all passing.

### MT-F.01 — Full Game Flow Regression

| Step | Action | Expected |
|------|--------|----------|
| 1 | Launch game → Start Learning Scenario | Board loads; both fleets placed; card panels visible for active player |
| 2 | Complete command phase (assign dials to all ships) | Dials appear in card panel; phase transitions to Ship Phase |
| 3 | Activate a ship: reveal dial, execute maneuver, perform attack | Activation modal steps work; maneuver executes; attack resolves |
| 4 | Complete all ship activations | Ship phase ends; transitions to Squadron Phase |
| 5 | Activate all squadrons (or pass) | Squadron phase ends; transitions to Status Phase |
| 6 | Observe Status Phase auto-advance | Tokens ready; round counter increments; handoff overlay appears |

**Pass criteria:** Complete game loop works identically to pre-refactoring.

### MT-F.02 — UI Panel Lifecycle (UIPanelManager)

| Step | Action | Expected |
|------|--------|----------|
| 1 | On board load, verify card panels | Rebel card panel (left) and Imperial card panel (right) visible with ship entries |
| 2 | Click a ship entry in card panel | Card detail overlay appears centred with ship art and stats |
| 3 | Press Escape | Card detail overlay dismisses |
| 4 | Trigger damage on a ship (via attack or Shift+D in debug) | Damage summary overlay appears when requested |
| 5 | Press Escape, then press Escape again | Quit confirmation modal appears |
| 6 | Click "Cancel" on quit modal | Modal dismisses; game continues |
| 7 | Resize the window | All panels reposition correctly (card panels stay at edges, modals re-centre) |
| 8 | Observe phase HUD label during phase transitions | Label updates: "Command Phase", "Ship Phase", "Squadron Phase", "Status Phase" |
| 9 | Observe player handoff overlay between rounds | "Your Turn" banner appears; handoff overlay shows player name |

**Pass criteria:** All UI panels create, display, resize, and dismiss correctly.

### MT-F.03 — Activation Context Shared State

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start ship activation (click eligible ship) | Activation modal appears; ship is highlighted |
| 2 | During maneuver: overlap another ship | Overlap resolves; "End Activation" button appears after maneuver |
| 3 | After maneuver, start attack | Attack executor can see the activating ship and its state |
| 4 | Complete activation | Ship marked as activated; activation context cleared |
| 5 | Observe that no other system retains stale activation state | Next ship activation starts fresh |

**Pass criteria:** Activation state flows correctly through all controllers
(ManeuverToolController, DisplacementController, AttackExecutor,
SquadronPhaseController) via shared ActivationContext.

### MT-F.04 — Save/Load With New Structure

| Step | Action | Expected |
|------|--------|----------|
| 1 | Enable debug mode (F12), play into round 2 | Normal gameplay |
| 2 | Press F5 to quicksave | "Quicksave complete." logged |
| 3 | Press F8 to quickload | "Quickload OK" logged; round/phase/scores restored |
| 4 | Continue playing after load | Game state is consistent; no errors in console |

**Pass criteria:** Save/load works correctly with UIPanelManager structure.

### MT-F4a.01 — Attack Targeting Still Works After Resolver Extraction

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a game (F6 on `game_board.tscn`) and reach the Ship Phase | Normal gameplay |
| 2 | Activate a ship and complete its maneuver | Maneuver completes normally |
| 3 | Click "Declare Attack" to enter attack simulator | Attack sim overlay appears with hull zone selectors |
| 4 | Select an attacking hull zone (e.g. Front) | Zone highlights; valid targets become clickable |
| 5 | Click an enemy ship hull zone as target | LOS line drawn, range displayed, dice pool shown |
| 6 | Observe LOS status text | "Clear" or "Obstructed" displayed correctly |
| 7 | Observe range band | Correct band (Close/Medium/Long) displayed |
| 8 | Confirm the attack and play through dice/defense | Attack resolves; damage applied |
| 9 | If ship has anti-squadron armament, target an enemy squadron | Squadron target in arc, LOS and range work |
| 10 | Complete the attack; observe "no more targets" auto-skip if applicable | Zones with no valid targets are auto-skipped |

**Pass criteria:** All attack targeting, LOS, range, and arc validation
work identically to before the extraction. No visual or behavioural
regressions.

### MT-FIX.01 — Squadron Loop Blocks Ship Targets

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a game and reach the Ship Phase | Normal gameplay |
| 2 | Activate a ship, complete maneuver, enter attack | Attack sim appears |
| 3 | Select a hull zone with enemy squadrons and an enemy ship in arc | Zone selected |
| 4 | Attack a squadron and resolve damage | Step 6 loop prompt: "Select next squadron" |
| 5 | Click the enemy ship instead of a squadron | Tooltip: "Can only target squadrons during anti-squadron attacks." Ship is rejected |

**Pass criteria:** During the Step 6 squadron loop, ship targets are
blocked with a tooltip. Only squadrons can be selected. ✅

### MT-FIX.02 — Auto-Skip 0-Dice Squadron in Step 6 Loop

| Step | Action | Expected |
|------|--------|----------|
| 1 | Set up scenario: Neb-B with 2 enemy squadrons at medium range and 1 at long range in its FRONT arc | Scenario ready |
| 2 | Attack from the FRONT arc, target and resolve the 1st squadron | Step 6 loop continues |
| 3 | Target and resolve the 2nd squadron | Loop auto-ends — the 3rd squadron at long range is filtered (0 blue dice at long) |
| 4 | Observe: no "Select next squadron" prompt appears | System immediately proceeds to 2nd hull zone or finishes |

**Pass criteria:** Squadrons that yield 0 dice at their range are
filtered from the candidate list. The Step 6 loop auto-ends without
requiring the player to click or skip. ✅

### MT-FIX.03 — Reject Hull Zone With No Valid Targets

| Step | Action | Expected |
|------|--------|----------|
| 1 | During attack execution, after the first attack completes | 2nd hull zone selection appears |
| 2 | Click a hull zone that has no enemy ships or squadrons in arc/range | Tooltip: "No valid targets in [ZONE] arc." Zone is not selected |
| 3 | Click a hull zone that DOES have valid targets | Zone is selected normally; target selection begins |

**Pass criteria:** Hull zones with no valid targets are rejected at
selection time with a clear tooltip message. ✅

### MT-F4b.01 — Dice Pool & Damage Still Work After Resolver Extraction

**Purpose:** Confirm that attack dice pool computation, Concentrate Fire
dial/token interaction, obstruction die removal, and damage calculation
all still function correctly after extracting `AttackDiceResolver`.
This is a pure-refactoring verification — no game-logic changes.

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a game and advance to Ship Phase | Both players' ships can activate |
| 2 | Activate a ship, select front arc, click enemy ship at close range | Dice pool shows correct colours (red + blue + black for close) |
| 3 | If CF dial is available, accept or skip | CF dial adds 1 die of chosen colour, or skip proceeds to roll |
| 4 | Roll dice | Results display with correct damage total |
| 5 | If CF token available, reroll or skip | Reroll replaces one die, damage recalculates |
| 6 | Place an obstruction between ships and repeat attack from another zone | Obstruction die removal offered (auto or choice), pool updates |
| 7 | Attack a squadron from a ship (anti-squadron armament) | Dice pool shows anti-squadron dice; crits don't count as damage |

**Pass criteria:** All attack flows produce identical behaviour to
pre-extraction. Dice counts, damage totals, CF interaction, and
obstruction removal work as before. ✅

### MT-F4c.01 — Defense Tokens Still Work After Resolver Extraction

**Purpose:** Confirm that all five defense token types, accuracy locking,
canonical resolution ordering, redirect zone selection, and faceup
damage card determination still function correctly after extracting
`DefenseTokenResolver`. Pure-refactoring verification — no game-logic changes.

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a game and advance to Ship Phase | Both players' ships can activate |
| 2 | Attack an enemy ship that has defense tokens | Defense token section appears with correct tokens |
| 3 | If accuracy dice appear, lock a token | Locked token is greyed out and cannot be spent |
| 4 | Select Brace and commit | Damage total is halved (rounded up) |
| 5 | In a new attack, select Scatter and commit | Damage total drops to 0 |
| 6 | In a new attack, select Evade at long range and pick a die | Selected die is removed, damage recalculates |
| 7 | In a new attack, select Evade at close/medium range and pick a die | Selected die is rerolled, damage recalculates |
| 8 | In a new attack, select Redirect and click adjacent hull zone | Damage redirects 1 point per click to that zone's shields |
| 9 | Click "Done Redirecting" before full budget is spent | Redirect ends early, remaining damage stays |
| 10 | Select Contain, attack produces critical | First damage card is NOT dealt faceup |
| 11 | Attack without Contain, attack produces critical | First damage card IS dealt faceup |
| 12 | Defender at speed 0 is attacked | No defense tokens can be spent |
| 13 | Select Brace + Redirect together | Brace halves first (canonical order), then Redirect distributes the halved total |

**Pass criteria:** All defense token flows produce identical behaviour to
pre-extraction. Token spending, accuracy locks, canonical ordering,
redirect zone selection, and critical determination all work as before. ✅

### MT-F4d.01 — Damage Resolution Still Works After DamageDealer Extraction

**Purpose:** Confirm that damage dealing, shield absorption, hull tracking,
destruction detection, damage summaries, faceup/facedown card dealing, and
immediate-effect flows still function correctly after extracting
`DamageDealer`. Pure-refactoring verification — no game-logic changes.

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a game and advance to Ship Phase | Both players' ships can activate |
| 2 | Attack an enemy ship and deal damage | Damage summary panel shows shields absorbed, cards dealt, hull remaining |
| 3 | Attack with enough damage to deplete shields | Shields reduce, remaining damage becomes cards |
| 4 | Attack producing a critical (no Contain spent) | First damage card dealt faceup, CRIT name shown in summary |
| 5 | Attack producing a critical with Contain spent | First damage card NOT dealt faceup |
| 6 | Deal faceup "Structural Damage" card | Immediate effect auto-resolves (extra facedown card) |
| 7 | Deal faceup "Injured Crew" card | Choice modal appears for opponent to pick a token to discard |
| 8 | Use Scatter to reduce damage to 0 | "No damage dealt" shown, no cards dealt |
| 9 | Attack a squadron | Squadron takes direct hull damage, correct hull display |
| 10 | Destroy a squadron | Squadron fades out after hull reaches 0 |
| 11 | Destroy a ship (deal damage >= hull) | Ship fades out, destroyed event fires |

**Pass criteria:** All damage resolution flows produce identical behaviour
to pre-extraction. Shield absorption, card dealing, destruction detection,
damage summaries, and immediate-effect modals all work as before.
---

### MT-BUG.01 — Destroyed Units Filtered from Targeting and Activation

**Purpose:** Verify that destroyed squadrons and ships cannot be targeted,
activated, or interacted with after being destroyed. Covers the fix in
commit `a69a14c`.

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start game, destroy an enemy squadron via attack | Squadron fades out, disappears |
| 2 | On next activation, try to click where the destroyed squadron was | No targeting highlight, click is ignored |
| 3 | Open squadron activation modal | Destroyed squadron does NOT appear as selectable |
| 4 | Advance to next round | Destroyed squadron does NOT reappear or flash |
| 5 | Attack and destroy a second squadron in the same game | Confirm the first destroyed squadron is still gone |
| 6 | Verify an attacking ship/squadron cannot select a destroyed unit | Tooltip "Target already destroyed" or no highlight |
| 7 | Destroy all 2 enemy squadrons (Starter scenario) | Subsequent activations skip squadron targeting cleanly |

**Pass criteria:** Destroyed units are never selectable, never reset visually
on round change, and never block or confuse the targeting flow.
---

## Debug Feature — Annotation Snapshots & Toast Notifications

### MT-DBG-ANN.01 — Annotation via Shift+A

**Purpose:** Verify that Shift+A opens the annotation modal, saves the
annotated game state to `saves/annotations/`, logs it, and shows a toast.

| Step | Action | Expected |
|------|--------|----------|
| 1 | Launch with `--debug` (or F12 to enable) | Debug HUD visible; help panel shows "Shift + A — Annotate game state" |
| 2 | Press Shift+A during gameplay | Annotation modal appears, centred, with text input, OK/Cancel buttons |
| 3 | Type "Test annotation at round 2" and press Enter | Modal closes; toast "Annotation #1 saved." appears at top-centre and fades |
| 4 | Check `saves/annotations/` directory | A JSON file exists; contains `annotation`, `timestamp`, `round`, `phase`, `counter`, `game_state` keys |
| 5 | Open the JSON file | `annotation` field matches typed text; `game_state` contains full serialized state |
| 6 | Press Shift+A again, type another note, click OK | Toast shows "Annotation #2 saved."; second JSON file appears |
| 7 | Press Shift+A then press Escape | Modal closes; no file created; no toast |
| 8 | Press Shift+A with empty text and press Enter or click OK | OK button is disabled; nothing happens |
| 9 | Disable debug mode (F12 off), press Shift+A | Nothing happens — shortcut is inactive |

**Pass criteria:** Annotations are saved with correct metadata and full game
state. Modal is usable via keyboard (Enter/Escape) and buttons. Toast fades
correctly. Shortcut only works in debug mode.

### MT-DBG-ANN.02 — Toast on Quicksave / Quickload

**Purpose:** Verify toast notifications appear for F5 (quicksave) and
F8 (quickload) in debug mode.

| Step | Action | Expected |
|------|--------|----------|
| 1 | Enable debug mode, press F5 | Toast "Quicksave complete." appears at top-centre and fades after ~2s |
| 2 | Press F8 | Toast "Quickload OK — round N." appears and fades |
| 3 | Delete `saves/quicksave.json`, press F8 | Toast "Quickload failed — no save file." appears |

**Pass criteria:** All three toast variants appear, are readable, fade out
on their own, and do not interfere with gameplay clicks.

---

## Playtest Bugfixes — Round 1–4 Annotations

> These tests verify the 6 bugs found during the round 1–4 playtest session.
> GUT tests cover dice pool gating, signal emissions, and overlay math.
> Manual tests below cover visual / interaction checks only.

### MT-PTBF.01 — Engaged Squadron Cannot Attack Ships (Bug E)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a squadron that is engaged with an enemy squadron | Squadron modal appears |
| 2 | Click the engaged squadron in the modal | Attack target selection begins |
| 3 | Attempt to click an enemy ship | Click rejected; tooltip shows "Engaged — must attack an engaged enemy squadron." |
| 4 | Click the engaged enemy squadron | Attack resolves normally |

**Pass criteria:** Engaged squadrons can only target engaged enemy squadrons; ship clicks are rejected with tooltip.

### MT-PTBF.02 — Zero-Dice Zones Do Not Highlight (Bug B)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Begin a ship attack with a ship that has BLACK-only front armament | Hull zone selector appears |
| 2 | Place an enemy ship at long range (beyond close) | Front zone should NOT show red highlight (0 black dice at range) |
| 3 | Move the enemy into close range | Front zone highlights red (black dice valid at close) |

**Pass criteria:** Hull zone highlights only appear when the dice pool has ≥ 1 die at the measured range.

### MT-PTBF.03 — Repair Hull Updates Token Display (Bug F)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Damage a ship to below full hull | Hull counter shows reduced number |
| 2 | Issue a Repair command and repair a damage card | Hull counter increments immediately after card removal |

**Pass criteria:** Hull counter display updates without requiring a round change or panel toggle.

### MT-PTBF.04 — Dial Sprite Hides on Phase Transition (Bug D)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate the last ship in the ship activation phase | Dial sprite appears above the ship |
| 2 | Complete its activation (finish attack/move) | Phase transitions to squadron phase; dial sprite disappears |
| 3 | Verify no ghost dial remains on any ship | Board is clear of stale dial sprites |

**Pass criteria:** No dial sprite persists after the phase transition to squadron phase.

### MT-PTBF.05 — Squadron Attack Circle Uses Distance 1 (Bug C)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Hover or select a squadron to show the attack sim overlay | Circle appears around the squadron base |
| 2 | Compare circle radius to ruler distance 1 | Circle edge matches distance-1 marking, NOT close range |

**Pass criteria:** The overlay circle radius is `base_radius + distance_bands_px[0]`, visibly smaller than close range.

### MT-PTBF.06 — Sidebar Highlights Active Squadron (Bug A)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Enter squadron phase | Activation sidebar appears with squadron list |
| 2 | Select a squadron from the modal | The corresponding sidebar entry highlights (same as ship activation flow) |
| 3 | Complete the squadron's activation | Highlight clears or moves to next |

**Pass criteria:** The active squadron is always visually indicated in the sidebar during squadron phase.

---

## Phase H — Targeting Geometry Centralisation

> Phase H replaced inline geometry approximations with canonical
> `RangeFinder` calls and removed dead code. These tests verify that
> range-dependent gameplay behaviour remains correct.
>
> **Status: All passed** — 2026-04-11.

### MT-H.01 — Squadron Command Range (H4)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Start a game; assign a Squadron command dial to a ship | Ship reveals Squadron dial |
| 2 | Advance to the ship activation phase and activate that ship | Squadron command step begins |
| 3 | Observe which squadrons are highlighted as eligible | Only friendly squadrons within close–medium range of the ship's hull zone edges are selectable |
| 4 | Place a friendly squadron far from the ship (> medium range) | That squadron is NOT listed as eligible |

**Pass criteria:** Squadron command eligibility uses accurate hull-zone polyline range, not circle approximation. Eligible list matches expectations from ruler overlays.

**Result: PASS** (2026-04-11)

### MT-H.02 — Squadron Phase Engagement Check (H3)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Enter squadron phase with two enemy squadrons near each other | Phase begins |
| 2 | Select one of the engaged squadrons | Modal shows "engaged" status and limits movement to distance 1 |
| 3 | Select a squadron far from enemies | Modal shows "not engaged" and allows full movement |

**Pass criteria:** Engagement detection matches ruler distance 1 visually; no false positives or negatives.

**Result: PASS** (2026-04-11)

### MT-H.03 — Squadron Attack Targeting (H5)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Position a squadron at close range of an enemy ship | Squadron can attack the ship |
| 2 | Position a squadron at medium range of an enemy ship | Squadron cannot target the ship (squadrons attack at close only) |
| 3 | Position two enemy squadrons within distance 1 | They can attack each other |

**Pass criteria:** Targeting list correctly reflects close-only range for squadron→ship and distance-1 for squadron→squadron.

**Result: PASS** (2026-04-11)
---

## Phase F5 — AttackExecutor Orchestration Split

> F5a created `AttackState`; F5b migrated 40 member variables from AE
> into that shared context. These tests verify that all attack flows
> still work correctly after the internal restructuring.
>
> **Status: F5b passed** — 2026-04-11. F5c passed — 2026-04-11. F5d passed — 2026-04-12.

### MT-F5b.01 — Ship Attack Full Flow

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a ship → enter Attack step | Hull zone selection appears |
| 2 | Select a hull zone → select a target | Dice pool shown, roll button active |
| 3 | Roll dice → spend accuracy/defense tokens → resolve damage | Damage applied correctly |
| 4 | Choose a second hull zone → complete second attack | Flow completes without error |

**Pass criteria:** Full two-attack activation completes. No errors in log.

**Result: PASS** (2026-04-11)

### MT-F5b.02 — Squadron Attack

| Step | Action | Expected |
|------|--------|----------|
| 1 | Enter Squadron Phase → activate a squadron | Attack option available |
| 2 | Attack an enemy squadron or ship | Dice roll → damage → resolution completes |

**Pass criteria:** Squadron attack flow works identically to pre-F5b.

**Result: PASS** (2026-04-11)

### MT-F5b.03 — Attack Simulator

| Step | Action | Expected |
|------|--------|----------|
| 1 | Open attack simulator (free-form, not from activation) | Attacker selection mode |
| 2 | Select attacker hull zone → select target | Info panel shows correct names/zones |
| 3 | Dismiss simulator | All state cleaned up, no lingering UI |

**Pass criteria:** Simulator displays correct attacker/defender info. Clean dismiss.

**Result: PASS** (2026-04-11)

### MT-F5c.01 — Targeting List Toggle

| Step | Action | Expected |
|------|--------|----------|
| 1 | Press T (or toolbar button) | Targeting list modal opens with ship/squadron data |
| 2 | Press T again | Modal closes |
| 3 | Open modal, press Escape | Modal closes |

**Pass criteria:** Toggle and Escape dismissal work identically to pre-F5c.

**Result: PASS** (2026-04-11)

### MT-F5c.02 — Ghost Ship in Targeting List

| Step | Action | Expected |
|------|--------|----------|
| 1 | Select a ship's maneuver tool (M) | Maneuver tool visible |
| 2 | Press T to open targeting list | Ghost entry appears in targeting data |

**Pass criteria:** Ghost ship projection shows in targeting list when maneuver tool is active.

**Result: PASS** (2026-04-11)

> F5d extracted `TargetSelector` from `AttackExecutor`. All attacker/target
> selection logic (simulator and exec) now lives in TS. AE delegates to TS
> via `_target_selector` and receives a `target_locked` signal when a valid
> target is confirmed then diverges into the dice sequence.
>
> **Status: F5d passed** — 2026-04-12.

### MT-F5d.01 — Attack Simulator via TargetSelector

| Step | Action | Expected |
|------|--------|----------|
| 1 | Open attack simulator (Q or toolbar) | Attacker selection mode (panel + arcs visible) |
| 2 | Click a friendly ship → select hull zone | Arc highlight + range overlay shown |
| 3 | Click an enemy ship in range | Target locks; dice pool text shown in panel |
| 4 | Press Escape | Simulator dismissed, all overlays cleared |
| 5 | Re-open simulator → select same attacker/target | Same result; no stale state from step 4 |

**Pass criteria:** Simulator completes full select → lock → dismiss cycle twice without errors.

**Result: PASS** (2026-04-12)

### MT-F5d.02 — Ship Attack Execution (Activation)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a ship → enter Attack step | Hull zone chooser appears |
| 2 | Select a hull zone → click an enemy in range | Target locks; dice auto-roll proceeds |
| 3 | Resolve the full attack (spend tokens, deal damage) | Damage applied; attack complete modal shown |
| 4 | Select a second hull zone → attack again | Second attack completes normally |
| 5 | Press Escape mid-target-selection | Returns to hull zone chooser (not full cancel) |

**Pass criteria:** Full two-attack activation with interrupt test. No errors in log.

**Result: PASS** (2026-04-12)

### MT-F5d.03 — Squadron Attack Execution

| Step | Action | Expected |
|------|--------|----------|
| 1 | Squadron Phase → activate a squadron | Attack option available |
| 2 | Click an enemy squadron/ship in range | Target locks; dice roll → resolve → damage |
| 3 | If multi-target squadron, second target prompt appears | Second attack resolves correctly |

**Pass criteria:** Squadron attack works identically to pre-F5d.

**Result: PASS** (2026-04-12)

---

## Refactoring Phase G — Command Pattern (Multiplayer Foundation)

> Phase G introduces the Command pattern: every player action becomes a
> serializable, validatable, replayable object. This phase is **infrastructure-only** —
> the existing game flow (direct method calls) is unchanged for now. The commands
> are exercised via GUT unit tests (104 scripts, 2 098 tests). The manual tests
> below verify that the game still works identically after adding the new autoload
> and command classes (regression gate).

### MT-G.01 — Full Game Round Regression After Command Infrastructure

| Step | Action | Expected |
|------|--------|----------|
| 1 | Launch Learning Scenario from main menu | Game board loads; both fleets deployed; Round 1 starts |
| 2 | Command Phase: assign all 4 dials for player 1, then player 2 | All dials assigned; phase advances to Ship Phase |
| 3 | Ship Phase: activate a ship → dial reveals → choose Keep | Ship activates normally; dial sprite shows; activation sidebar visible |
| 4 | Perform an attack from the activated ship | Target selection → dice roll → defense tokens → damage all work |
| 5 | Execute a maneuver | Speed dial + maneuver tool works; ship moves |
| 6 | End activation | Ship shows activated visual; next ship's turn begins |
| 7 | Complete the round through Status Phase | Tokens ready; round counter increments; new Command Phase begins |

**Pass criteria:** Full round plays identically to pre-Phase-G. No new errors in
the Output panel. CommandProcessor autoload loads without conflict.

**Result: PASS** (2026-04-12)

### MT-G.02 — Convert Dial to Token + Overflow Discard Regression

| Step | Action | Expected |
|------|--------|----------|
| 1 | Ship Phase: activate a ship → choose **Convert** on the dial choice | Dial consumed; matching command token appears on ship |
| 2 | Repeat conversion for same token type until ship has max tokens | Overflow discard modal appears (choose which to discard) |
| 3 | Discard the older token | Token count stays at max; discarded token removed |

**Pass criteria:** Convert-to-token flow unchanged. Overflow modal appears and
resolves correctly. No console errors.

**Result: PASS** (2026-04-12)

### MT-G.03 — Squadron Activation Regression

| Step | Action | Expected |
|------|--------|----------|
| 1 | Advance to Squadron Phase | Squadron activation modal appears |
| 2 | Activate a squadron | Squadron highlights; move overlay shows if not engaged |
| 3 | Move the squadron (if not engaged) | Squadron moves to valid position |
| 4 | Attack with the squadron | Target selection → dice roll → damage resolves |
| 5 | End squadron activation | Squadron shows activated ring; next squadron or phase advance |

**Pass criteria:** Squadron phase flows identically to pre-Phase-G.

**Result: PASS** (2026-04-12)

### MT-G.04 — Deterministic RNG Verification

| Step | Action | Expected |
|------|--------|----------|
| 1 | Run GUT tests: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 \| grep -i "game_rng"` | Test file `test_game_rng.gd` runs; 0 failures |
| 2 | Play a full round; observe dice rolls | Dice produce visual results (not always the same — seed is random per game) |

> **Note:** `GameRng` is a `RefCounted` class instantiated per `GameState`, not a
> Node autoload. Each game gets its own seeded RNG via `GameState.rng`. The seed
> is serialized with save games and determinism is verified by unit tests
> (same seed → same sequence).

**Pass criteria:** GameRng unit tests pass. Dice use seeded RNG via `GameState.rng`.

**Result: PASS** (2026-04-12)

---

## Hotfix — Target Deselection During Attack Execution

> Fixed dice-phase guard in TargetSelector: changed from `dice_pool.size() > 0`
> (fires on pool computation) to `dice_results.size() > 0` (fires after actual
> dice roll). Before rolling, the player can freely deselect and re-select
> targets. After rolling, clicks are hard-blocked.

### MT-HF.01 — Pre-Roll Target Deselection

| Step | Action | Expected |
|------|--------|----------|
| 1 | Activate a ship → enter Attack step | Hull zone chooser appears |
| 2 | Select a hull zone → click an enemy squadron in range | Target locks; dice pool shows; Roll button visible |
| 3 | Click the **same** squadron again | Target deselected; dice UI clears; back to "Select a target" prompt |
| 4 | Click a **different** valid target | New target locks; new dice pool computed; Roll button visible |
| 5 | Click Roll | Dice roll proceeds normally |

**Pass criteria:** Deselection before rolling works; new target selection works; no stuck state.

**Result: PASS** (2026-04-12)

### MT-HF.02 — Post-Roll Click Block

| Step | Action | Expected |
|------|--------|----------|
| 1 | Select hull zone → click enemy target → click Roll | Dice rolled; results shown |
| 2 | Click any enemy ship or squadron | Click has no effect (guard blocks) |
| 3 | Complete the attack normally | Attack resolves correctly |

**Pass criteria:** After dice are rolled, target clicks are blocked; attack flow completes.

**Result: PASS** (2026-04-12)