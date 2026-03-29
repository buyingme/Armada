# UI Styling Guide

> **Purpose:** Guarantee visual consistency across all modal panels, overlays,
> buttons, and labels in the project.  Every new UI element **must** follow
> these rules; every existing element already does.

---

## 1. Modal Panel Style (PanelContainer)

All modal / overlay panels that float above the game board use a single
`StyleBoxFlat` applied via `add_theme_stylebox_override("panel", style)`.

```gdscript
## Standard modal panel style — use for EVERY PanelContainer modal.
static func create_modal_style() -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
    style.border_color = Color(0.4, 0.5, 0.7, 1.0)
    style.set_border_width_all(2)
    style.set_corner_radius_all(8)
    return style
```

| Property | Value | Rationale |
|----------|-------|-----------|
| `bg_color` | `Color(0.12, 0.12, 0.18, 0.95)` | Dark blue-grey, 95 % opaque — readable over the space board |
| `border_color` | `Color(0.4, 0.5, 0.7, 1.0)` | Subtle blue highlight border |
| `border_width` | `2` all sides | Thin, uniform |
| `corner_radius` | `8` all corners | Rounded, matches Godot default feel |

### Usage example

```gdscript
func _build_ui() -> void:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
    style.border_color = Color(0.4, 0.5, 0.7, 1.0)
    style.set_border_width_all(2)
    style.set_corner_radius_all(8)
    add_theme_stylebox_override("panel", style)
```

> **Existing files that follow this pattern:**
> `CommandDialPicker`, `CommandDialOrderModal`.  All new modals must match.

---

## 2. Step Row Style (inside modals)

When a modal contains a list of steps or items, each row is a
`PanelContainer` with its own `StyleBoxFlat`:

```gdscript
## Row in "current / active" state:
style.bg_color = Color(0.18, 0.22, 0.32, 1.0)   # slightly lighter blue
style.border_color = Color(0.5, 0.6, 0.8, 1.0)   # brighter highlight
style.set_border_width_all(1)
style.set_corner_radius_all(4)

## Row in "completed / past" state:
style.bg_color = Color(0.1, 0.1, 0.14, 0.8)
style.border_color = Color(0.3, 0.35, 0.45, 0.6)

## Row in "future / dimmed" state:
style.bg_color = Color(0.08, 0.08, 0.12, 0.6)
style.border_color = Color(0.2, 0.25, 0.35, 0.4)
```

---

## 3. Inner Margins (MarginContainer)

Every modal wraps its content in a `MarginContainer`:

```gdscript
margin.add_theme_constant_override("margin_left", 16)
margin.add_theme_constant_override("margin_right", 16)
margin.add_theme_constant_override("margin_top", 12)
margin.add_theme_constant_override("margin_bottom", 12)
```

---

## 4. Typography

| Element | Method | Size |
|---------|--------|------|
| Modal title | `add_theme_font_size_override("font_size", 16)` | 16 |
| Subtitle / info | default (14) | — |
| Small info (token list) | `add_theme_font_size_override("font_size", 12)` | 12 |
| Hint text ("click to dismiss") | `add_theme_font_size_override("font_size", 11)` | 11 |
| Hint text colour | `add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))` | grey |

Prefer `add_theme_font_size_override` over `LabelSettings` for
consistency with the majority of existing UI code.

---

## 5. Modal Positioning

| Pattern | Code | Used by |
|---------|------|---------|
| **Centred on screen** | `position = (viewport_size - custom_minimum_size) * 0.5` | CommandDialPicker, CommandDialOrderModal |
| **Bottom-centre (anchored)** | Anchor-based: `PRESET_CENTER_BOTTOM`, offsets `-120`/`-40` | AttackSimPanel, **ActivationModal** |
| Bottom-centre button | `position = Vector2((vp.x - size.x) * 0.5, vp.y - size.y - 24)` | EndActivationButton |
| Right-side panel | `position = Vector2(vp.x - width - 16, 16)` | (reserved for future sidebar panels) |

> **Rule:** Modals that the user interacts with step-by-step (pickers,
> activation sequences) must be **centred** or **bottom-centred**.
> Only persistent HUD elements may be anchored to edges.
> The ActivationModal and AttackSimPanel share the same bottom-centre
> position — the ShowActivationButton is hidden while the attack panel
> is active.

---

## 6. Dismissibility

Every modal must provide a way to close / leave it:

| Pattern | Implementation | Used by |
|---------|---------------|---------|
| Click-anywhere-to-close | `_gui_input` handler: left click → `close()` + `accept_event()` | CommandDialOrderModal |
| Explicit close button | "✕ Close" or "Cancel" `Button` at bottom | ActivationModal (new) |
| Escape key | `_unhandled_input` → `KEY_ESCAPE` → `close()` | ActivationModal (new) |
| Confirm = close | CONFIRM button calls `close()` then emits signal | CommandDialPicker |

> **Rule:** If a modal has destructive state (e.g. partially assigned dials),
> leaving it should **not** lose progress — it should stay open until
> explicitly confirmed.  Read-only or step-tracking modals should always
> be dismissable via Escape or a close button.

---

## 7. VBoxContainer Separation

| Context | `separation` override |
|---------|-----------------------|
| Modal top-level VBox | `12` |
| Step list VBox | `4` |
| Inline icon + label | `4` |
| Selection area icons | `16` (HBox) |
| Stack area icons | `8` (HBox) |

---

## 8. Buttons

| Style | Values |
|-------|--------|
| `custom_minimum_size` | `Vector2(120, 36)` for action buttons; `Vector2(200, 44)` for prominent bottom-centre buttons |
| Alignment | Wrapped in `HBoxContainer` with `ALIGNMENT_CENTER` |

---

## 9. Colour Palette (quick reference)

| Role | Colour |
|------|--------|
| Panel background | `Color(0.12, 0.12, 0.18, 0.95)` |
| Panel border | `Color(0.4, 0.5, 0.7, 1.0)` |
| Active row background | `Color(0.18, 0.22, 0.32, 1.0)` |
| Active row border | `Color(0.5, 0.6, 0.8, 1.0)` |
| Completed row background | `Color(0.1, 0.1, 0.14, 0.8)` |
| Placeholder / warning amber | `Color(0.9, 0.7, 0.3)` |
| Success green (✓) | `Color(0.4, 0.9, 0.4)` |
| Dimmed text | `Color(0.6, 0.6, 0.6)` |
| Clickable action (Execute step) | `Color(0.4, 0.7, 1.0)` |

---

## 10. Reusable Anchor-Based Panels — Layout Reset Pattern

### Problem

`PanelContainer` modals positioned via `PRESET_CENTER_BOTTOM` (or any
anchor preset) and reused across multiple game phases exhibit **three
interrelated Godot layout bugs**:

1. **Stale `.size`:** After a previous session inflated the panel (e.g.
   dice + defense + redirect sections → 648 px), the `.size` property
   retains that value even after all children are removed.
2. **Offset drift:** Setting `size = Vector2.ZERO` on an anchor-based
   control causes Godot to **recalculate offsets** to preserve the
   current screen position.  Each reopen adds the old height to the
   offset, accumulating drift (~388 px per cycle).
3. **Hidden-child inflation:** Children created with `visible = false`
   still contribute to `PanelContainer`'s minimum-size computation
   during the **synchronous** `add_child()` call.  Godot only excludes
   them in the **deferred** layout pass.  The first time a panel
   becomes visible, Godot schedules that deferred pass automatically.
   On panel **reuse** (already shown once), no such pass is scheduled —
   so the 648 px sticks permanently.

### Required Pattern

Apply **all three steps** in this exact order inside `_build_ui()` and
the `show_*()` methods:

```gdscript
## In _build_ui():
func _build_ui() -> void:
    _clear_content()                     # 1. Remove old children first
    size = Vector2.ZERO                  # 2. Zero stale cached size
    offset_top = -40.0                   # 3. Re-pin canonical offsets
    offset_bottom = -40.0                #    (counteracts drift from step 2)
    # … add children …

## In every show_*() method:
func show_initial_attack_exec(ship_name: String) -> void:
    _build_ui()
    _set_prompt(…)
    visible = true
    _request_deferred_layout()           # 4. Force deferred re-layout
```

The deferred helper:

```gdscript
## Schedules a one-frame-deferred layout reset.
## Needed because hidden children inflate the PanelContainer during
## synchronous add_child(); Godot only excludes them in the deferred
## layout pass — which is not auto-scheduled on panel reuse.
func _request_deferred_layout() -> void:
    call_deferred("_deferred_layout_reset")

func _deferred_layout_reset() -> void:
    size = Vector2.ZERO
    offset_top = -40.0
    offset_bottom = -40.0
```

### Why each step matters

| Step | Without it | Symptom |
|------|-----------|---------|
| `_clear_content()` with `remove_child()` | Old VBox stays in tree during rebuild | Stale minimum-size doubles the panel height |
| `size = Vector2.ZERO` | PanelContainer keeps inflated height from previous session | Panel appears at old (large) size |
| Offset re-pin (`-40.0`) | `size = Vector2.ZERO` corrupts offsets via Godot's recalc | Panel drifts off-screen (~388 px per reopen) |
| `_request_deferred_layout()` | Hidden children inflate to ~648 px; no deferred pass corrects it on reuse | Panel too tall, extends above viewport |
| `remove_child()` before `queue_free()` | `queue_free()` is deferred — child is still in tree during current frame | PanelContainer reports stale minimum size |

### `_clear_content()` pattern

Always `remove_child()` before `queue_free()`:

```gdscript
func _clear_content() -> void:
    if _content:
        remove_child(_content)      # Exclude from min-size NOW
        _content.queue_free()       # Actual cleanup is deferred
        _content = null
```

### Checklist for reusable anchor-based panels

- [ ] `_clear_content()` uses `remove_child()` before `queue_free()`
- [ ] `_build_ui()` resets `size = Vector2.ZERO` then re-pins offsets
- [ ] VBoxContainer child gets explicit `custom_minimum_size.x`
- [ ] Every `show_*()` method calls `_request_deferred_layout()` after `visible = true`
- [ ] Anchors / presets are set only once in `_init()` via `_apply_anchor_position()`

### Files using this pattern

| File | Panel type |
|------|-----------|
| `src/ui/attack_sim_panel.gd` | Attack execution / simulator |
| `src/ui/activation_modal.gd` | Ship activation sequence |
| `src/ui/squadron_activation_modal.gd` | Squadron activation |

---

## Checklist for New UI Elements

Before committing any new `PanelContainer` modal or overlay:

- [ ] Uses `StyleBoxFlat` with the standard `bg_color` / `border_color` / radius.
- [ ] Inner content wrapped in `MarginContainer(16, 16, 12, 12)`.
- [ ] Title uses `font_size = 16`, centred.
- [ ] Positioned via `centre_on_screen()`.
- [ ] Has a dismiss mechanism (close button, Escape, or click-outside).
- [ ] Step rows (if any) use the row style colours from §2.
- [ ] VBox separation matches §7 values.
