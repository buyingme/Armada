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
| **Centred on screen** | `position = (viewport_size - custom_minimum_size) * 0.5` | CommandDialPicker, CommandDialOrderModal, **ActivationModal** |
| Bottom-centre button | `position = Vector2((vp.x - size.x) * 0.5, vp.y - size.y - 24)` | EndActivationButton |
| Right-side panel | `position = Vector2(vp.x - width - 16, 16)` | (reserved for future sidebar panels) |

> **Rule:** Modals that the user interacts with step-by-step (pickers,
> activation sequences) must be **centred**.  Only persistent HUD elements
> may be anchored to edges.

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

## Checklist for New UI Elements

Before committing any new `PanelContainer` modal or overlay:

- [ ] Uses `StyleBoxFlat` with the standard `bg_color` / `border_color` / radius.
- [ ] Inner content wrapped in `MarginContainer(16, 16, 12, 12)`.
- [ ] Title uses `font_size = 16`, centred.
- [ ] Positioned via `centre_on_screen()`.
- [ ] Has a dismiss mechanism (close button, Escape, or click-outside).
- [ ] Step rows (if any) use the row style colours from §2.
- [ ] VBox separation matches §7 values.
