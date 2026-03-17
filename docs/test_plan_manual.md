# Manual Test Plan — Star Wars: Armada Digital Edition

> **Scope:** Phases 0–4c, L, plus post-Phase-L and post-Phase-4c bug fixes. Updated after each phase completes.
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

*Last updated: Phase 4c complete — drag-and-drop ship activation, composite dial rendering, spent dial positioning, initiative fix (Rebel retains for entire game), state-aware dial assignment. Post-4c bug fixes in commits `35f0f39`, `c666d52`, `36460b5`. 701 tests passing (44 scripts, 1358 asserts).*