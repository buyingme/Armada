# Hover Tooltip System — Requirements

> **ID prefix:** TT (ToolTip)
> **Status:** Draft
> **Related requirements:** UI-002, UI-018, UI-022, UI-024, UI-027

---

## 1  Purpose

Provide a **single, reusable tooltip infrastructure** that displays contextual
help text when the player hovers over (or interacts with) any interactive
region of the application.  The system unifies all transient help text —
including the existing drag help label (UI-027) and the discard-mode prompt —
under one consistent mechanism.

---

## 2  Functional Requirements

### 2.1  Hover Trigger

| ID | Requirement | Rationale |
|----|-------------|-----------|
| TT-001 | The tooltip appears after the mouse pointer has remained stationary over a registered interactive region for a **configurable delay** (default 200 ms). | Prevents flicker on casual mouse movement. |
| TT-002 | The tooltip disappears **immediately** when the mouse leaves the registered region. | Standard UX convention. |
| TT-003 | If the mouse moves from one registered region directly into another, the delay timer **restarts** for the new region. | Avoids stale text; each region earns its own delay. |
| TT-004 | A registered region may specify a delay of **0 ms** to show the tooltip instantly (e.g., drag help text that must appear the moment a drag begins). | Supports the existing drag-help-on-start semantics (UI-027). |

### 2.2  Programmatic Show / Hide

| ID | Requirement | Rationale |
|----|-------------|-----------|
| TT-005 | External code may **show** a tooltip immediately (bypassing hover detection) by calling a public API with text + optional anchor position. | Needed for drag help text (UI-027), discard prompts, and any future transient instructions that are not hover-based. |
| TT-006 | External code may **hide** the tooltip immediately by calling a public API. | Needed when an interaction ends (drag drop, discard complete). |
| TT-007 | A programmatic show **overrides** any hover-triggered tooltip; hover tooltips resume once the programmatic text is hidden. | Prevents conflicts when both systems fire simultaneously. |

### 2.3  Tooltip Content

| ID | Requirement | Rationale |
|----|-------------|-----------|
| TT-010 | Tooltip text supports **BBCode** (Godot `RichTextLabel` format) for inline bold, color, and `[img]` tags (e.g., command icons). | Rich formatting improves readability for complex instructions. |
| TT-011 | Tooltip text may contain **multiple lines** (explicit `\n` or BBCode `[br]`). | Some hints are multi-line (e.g., UI-027 drag help). |
| TT-012 | Each registered region provides its tooltip text via a **callback** (Callable), not a static string. The callback is invoked when the tooltip is about to be shown, allowing **context-sensitive text** that reflects the current game state. | Example: a dial stack's tooltip changes depending on whether the ship is activatable, already activated, or belongs to the opponent. |
| TT-013 | If the callback returns an **empty string**, the tooltip is suppressed for that hover. | Allows regions to conditionally opt out. |

### 2.4  Positioning

| ID | Requirement | Rationale |
|----|-------------|-----------|
| TT-020 | The tooltip popup **follows the mouse cursor** with a configurable pixel offset (default: 12 px right, 16 px below the cursor). | Classic cursor-following tooltip UX. |
| TT-021 | The tooltip is **clamped to the viewport** so it never extends beyond the visible screen area. Clamping flips the tooltip to the opposite side of the cursor when there is insufficient space. | Prevents offscreen clipping. |
| TT-022 | The tooltip has a configurable **maximum width** (default: 320 px). Text wraps within this width. | Prevents excessively wide tooltips. |

### 2.5  Visual Style

| ID | Requirement | Rationale |
|----|-------------|-----------|
| TT-030 | Font size: **18 px** (matching the existing drag help label). | Visual consistency. |
| TT-031 | Text colour: `Color(1.0, 1.0, 1.0, 0.9)` (white, 90 % alpha). | Matches drag help label. |
| TT-032 | Text shadow: `Color(0.0, 0.0, 0.0, 0.8)`, offset `(1, 1)` px. | Matches drag help label. |
| TT-033 | Background: semi-transparent dark panel (`Color(0.05, 0.05, 0.1, 0.85)`) with `4 px` corner radius. | Provides contrast without obscuring the game board; thematic dark-blue tint. |
| TT-034 | Internal padding: `8 px` horizontal, `6 px` vertical. | Comfortable spacing between text and panel edge. |
| TT-035 | `mouse_filter = MOUSE_FILTER_IGNORE` — the tooltip panel never consumes mouse events. | Tooltip must not interfere with interaction below it. |

### 2.6  Configuration

| ID | Requirement | Rationale |
|----|-------------|-----------|
| TT-040 | All numeric parameters (delay, offset, max width, font size, padding, corner radius) are loaded from `scale_config.json` under a new `"tooltip"` section. | Data-driven configuration consistent with existing `card_panel` pattern. |
| TT-041 | `GameScale` exposes the loaded tooltip values as typed properties. | Single point of access for tooltip configuration. |
| TT-042 | Sensible defaults are used if the `"tooltip"` section is absent from `scale_config.json`. | Backward-compatible; doesn't break existing config. |

### 2.7  Lifecycle & Integration

| ID | Requirement | Rationale |
|----|-------------|-----------|
| TT-050 | The tooltip system lives on a **dedicated CanvasLayer** with a layer value **above all other UI layers** (≥ 100). | Tooltip must always render on top. |
| TT-051 | The tooltip system is a **singleton** (autoload or unique node) accessible from any scene. | Reusable across the entire application. |
| TT-052 | Registration and deregistration of tooltip regions must be **safe across scene transitions** — regions are automatically deregistered when their owning `Control` node is freed. | Prevents dangling references and use-after-free. |
| TT-053 | Existing drag help label (`_create_drag_help_label` in `game_board.gd`) and discard-mode prompt (`_enter_discard_mode` in `ship_card_panel.gd`) are **migrated** to use the new tooltip system's programmatic show/hide API. Their dedicated Label nodes are removed. | Eliminates duplicated styling and positioning code. |

### 2.8  Global Toggle

| ID | Requirement | Rationale |
|----|-------------|-----------|
| TT-070 | The entire hover-tooltip system can be switched **on or off** at runtime via a global boolean (`tooltips_enabled`). | Some players find tooltips distracting once they know the game. |
| TT-071 | A small **toggle button** (icon-only, ~28 × 28 px) is displayed in the **lower-right corner** of the screen on a dedicated CanvasLayer (same layer as the tooltip). | Always accessible, unobtrusive. |
| TT-072 | The button shows a **tooltip icon** (e.g., a question-mark or speech-bubble glyph) and visually indicates the current state: **bright** when tooltips are enabled, **dimmed / struck-through** when disabled. | Clear affordance without text. |
| TT-073 | Clicking the button toggles `tooltips_enabled`. When tooltips are disabled: hover detection still tracks regions but never shows the popup; programmatic `show_text()` calls (drag help, discard prompt) are **still honoured** because they are essential gameplay instructions, not optional hints. | Distinguishes "nice-to-have hints" from "required instructions". |
| TT-074 | The enabled/disabled state is **persisted** to `user://settings.cfg` (or equivalent) so the preference survives application restarts. | Player preference retention. |
| TT-075 | The toggle button's size, padding from screen edge, and icon resource path are loaded from `scale_config.json → "tooltip"`. | Data-driven, consistent with TT-040. |

### 2.9  Testability

| ID | Requirement | Rationale |
|----|-------------|-----------|
| TT-060 | Core tooltip logic (delay timer, viewport clamping, text callback invocation) must be testable **without the scene tree** via `RefCounted` helper classes. | Project architecture rule: core logic is scene-tree independent. |
| TT-061 | At least one integration test verifies that registering a `Control`, hovering it, and waiting for the delay produces a visible tooltip. | End-to-end validation. |
| TT-062 | Unit tests verify: viewport clamping logic, callback-returns-empty suppression, programmatic show overriding hover, delay reset on region change. | Key behavioural edge cases. |
| TT-063 | Unit test verifies: when `tooltips_enabled = false`, hover callbacks are not invoked and the panel stays hidden; but `show_text()` still works. | Toggle behaviour. |

### 2.10  Contextual Hover Hints (ShipCardPanel)

| ID | Region | Condition | Tooltip Text | Rationale |
|----|--------|-----------|-------------|----------|
| TT-080 | `dial_container` | Ship Phase, eligible, hidden dials > 0, no revealed dial | `"Click to reveal dial\nand activate ship"` | Teaches the player that clicking starts the two-step activation flow. |
| TT-081 | `dial_container` | Ship Phase, eligible, dial already revealed | `"Drag to ship for full command\nDrag to card for command token"` | Shows the drag options before the drag starts (pre-drag affordance). |
| TT-082 | `dial_container` | Not Ship Phase eligible (wrong phase, already activated, wrong player, another ship activating) | `"Click to show\ncommand stack order"` | Clarifies the non-activation dial-click path (opens dial order modal). |
| TT-083 | `dial_container` | Viewer does not own the ship (`_viewer_player` mismatch) | `""` (suppress) | Opponent dials are secret — no tooltip should hint at interaction. |
| TT-084 | `dial_container` | Discard mode active (`_discard_mode_ship != null`) | `""` (suppress) | Dial interaction is blocked during discard; tooltip would be misleading. |
| TT-085 | `entry_container` | Discard mode NOT active | `"Click to magnify"` | Standard card magnify affordance for new players. |
| TT-086 | `entry_container` | Discard mode active | `""` (suppress) | Magnify is blocked during discard mode. |

---

## 3  Initial Tooltip Assignments (MVP)

These are the first regions to be wired up once the infrastructure is in place:

| Region | Trigger | Example Text |
|--------|---------|--------------|
| Ship card entry (ShipCardPanel) | Hover | `"Click to enlarge"` |
| Command dial stack (top dial) | Hover | Context-dependent: `"Click to view dial order"` / `"Drag to ship for full effect · Drag to card for token"` |
| Defense token icon | Hover | `"Brace — reduce damage by half"` (token type description) |
| Command token icon | Hover | `"Navigate token — gain 1 yaw"` |
| Dial drag active | Programmatic (0 ms) | `"Drag to ship for full command effect\nDrag to ship card for command token"` (replaces UI-027 drag help label) |
| Discard mode active | Programmatic (0 ms) | `"Click a token to discard"` (replaces discard prompt) |
| Duplicate toast | Programmatic (0 ms, auto-hide 2 s) | `"Duplicate token discarded: Navigate"` (replaces duplicate toast) |

---

## 4  Out of Scope (for now)

- Animated show/hide transitions (fade-in / fade-out) — can be added later.
- Tooltip arrow / pointer triangle pointing at the source element.
- Gamepad / keyboard focus tooltips (mouse-only for MVP).
- Tooltip pinning (click to keep open).

---

## 5  Acceptance Criteria

1. Hovering any registered region for ≥ 200 ms shows a styled tooltip at the cursor.
2. Moving the mouse away hides the tooltip instantly.
3. Drag help text appears instantly when a dial drag starts and disappears on drop.
4. Discard prompt appears instantly when discard mode activates.
5. All existing tests pass (0 regressions); new tests cover TT-060–063.
6. All configurable values are driven from `scale_config.json`.
7. `scale_config.json` without a `"tooltip"` section still works (defaults).
8. A toggle button in the lower-right corner enables/disables hover tooltips.
9. Disabling tooltips suppresses hover popups but not programmatic instructions.
10. The toggle state persists across application restarts.
