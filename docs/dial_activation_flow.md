# Command Dial Activation Flow

> Describes the complete lifecycle of a command dial from facedown on the
> stack through activation to the discard pile, including all objects
> involved, the event sequence, and which code handles each step.

## Objects Involved

| Object | Type | Location | Purpose |
|--------|------|----------|---------|
| **Hidden Dial** | `Dictionary` in `_dials[]` (state=`"hidden"`) | `CommandDialStack` | Facedown dial on the stack. Rendered as `cmd_dial_hidden.png` TextureRect. |
| **Revealed Dial** | Same `Dictionary`, state changed to `"revealed"` | `CommandDialStack` | Face-up dial on top of the stack after first click. Rendered as composite Control (background + command icon). |
| **Drag Preview** | `TextureRect` (command icon, 50×50, alpha 0.75) | `game_board.gd` — TurnManagementLayer | Floating sprite that follows the mouse during drag. Created on step 2, freed on drop/cancel. |
| **Help Label** | `Label` | `game_board.gd` — TurnManagementLayer | Two-line instruction text shown during drag. Freed on drop/cancel. |
| **Revealed Dial on Board** | `TextureRect` child of `ShipToken` | `ship_token.gd` | Shown behind the ship base after a board-drop activation. Hidden on End Activation. |
| **Spent Dial (Activation Marker)** | Moved from `_dials[]` to `_spent_history[]` | `CommandDialStack` | Rendered below the active stack with a gap. Shows the command that was used this round. |
| **Command Token** | `int` in `CommandTokenManager._tokens[]` | `ShipInstance.command_tokens` | Added when the player drops the dial on the ship card (token convert path). |
| **Discard Prompt** | `Label` named `DiscardPrompt` | `ShipCardPanel` cmd_token_col | Shown when overflow requires player to choose a token to discard. |
| **Duplicate Toast** | `Label` named `DuplicateToast` | `ShipCardPanel` cmd_token_col | Brief notification when a duplicate token is auto-discarded. Auto-hides after 2s. |

## Event / Signal Flow

```
[ShipCardPanel]                  [game_board.gd]               [GameManager]
       │                               │                            │
       │  (1) LEFT-CLICK on dial area  │                            │
       │   _on_dial_container_gui_input()                            │
       │   _handle_dial_stack_click()  │                            │
       │                               │                            │
       ├──► Step 1 (first click):      │                            │
       │    reveal_top()               │                            │
       │    emit command_dials_changed │                            │
       │    _populate_dial_stack()     │                            │
       │    (dial renders face-up)     │                            │
       │                               │                            │
       ├──► Step 2 (second click):     │                            │
       │    emit dial_drag_started ───►│ _on_dial_drag_started()    │
       │                               │ _create_drag_preview()     │
       │                               │ _create_drag_help_label()  │
       │                               │ _drag_active = true        │
       │                               │                            │
       │                               │  (3) MOUSE-UP (release)    │
       │                               │  _handle_drag_release()    │
       │                               │                            │
       │                  ┌────────────┼─── Path A: Board drop ─────┤
       │                  │            │                            │
       │                  │  _find_ship_token_at()                  │
       │                  │  _is_valid_drop_target()                │
       │                  │  _complete_ship_activation() ──────────►│
       │                  │            │     activate_ship()         │
       │                  │            │     get_revealed_dial()     │
       │                  │  show_revealed_dial(cmd)                │
       │                  │  _clean_up_drag()                       │
       │                  │  _show_end_activation_button()           │
       │                  │            │                            │
       │                  ├────────────┼─── Path B: Card drop ──────┤
       │                  │            │                            │
       │                  │  _find_card_panel_hit()                 │
       │                  │  _complete_token_conversion() ─────────►│
       │                  │            │  activate_ship_as_token()   │
       │                  │            │  reveal (or read revealed)  │
       │                  │            │  spend_revealed() ─► spent  │
       │                  │            │  force_add_token(cmd) ─► tk │
       │                  │  _clean_up_drag()                       │
       │                  │            │                            │
       │                  │  ── Path B1: Normal (no overflow) ─────►│
       │                  │  _show_end_activation_button()           │
       │                  │            │                            │
       │                  │  ── Path B2: Overflow (CM-004) ────────►│
       │                  │  emit token_discard_required             │
       │                  │  (End Activation delayed)               │
       │             [ShipCardPanel] ◄─ _on_token_discard_required  │
       │             _enter_discard_mode()                          │
       │             (tokens: clickable, red tint, prompt label)     │
       │                               │                            │
       │             Player clicks a token:                         │
       │             _on_discard_token_click()                      │
       │             remove_token()                                 │
       │             _exit_discard_mode()                           │
       │             emit token_discarded ──────────────────────────►│
       │                               │◄─ _on_token_discard_resolved│
       │                               │  _show_end_activation_button│
       │                  │            │                            │
       │                  │  ── Path B3: Duplicate (CM-005) ───────►│
       │                  │  auto remove_token(dup)                 │
       │                  │  emit duplicate_token_discarded          │
       │             [ShipCardPanel] ◄─ _on_duplicate_token_discarded│
       │             _show_duplicate_toast() (2s auto-hide)         │
       │                  │  _show_end_activation_button()           │
       │                  │            │                            │
       │                  ├────────────┼─── Path C: Cancel ─────────┤
       │                  │            │                            │
       │                  │  _cancel_drag()                         │
       │                  │  unreveal_top() ─► hidden again          │
       │                  │  emit command_dials_changed              │
       │                  │  _clean_up_drag()                       │
       │                  │  emit dial_drag_cancelled               │
       │                  │            │                            │
       │                  └────────────┤                            │
       │                               │                            │
       │                               │  (4) END ACTIVATION btn    │
       │                               │  emit activation_ended     │
       │                               │                            │
       │                               │ _on_board_activation_ended │
       │                               │  hide_revealed_dial()      │
       │                               │  hide_button() ───────────►│
       │                               │            _on_activation_ended()
       │                               │            spend_revealed()
       │                               │            (if not already spent)
       │                               │            activated_this_round=true
       │                               │            _activating_ship = null
       │                               │            _advance_ship_phase_turn()
```

## Dial State Machine

```
               assign_dials()
                    │
                    ▼
              ┌──────────┐
              │  HIDDEN   │ ◄─── unreveal_top() [cancel drag]
              └────┬─────┘
                   │ reveal_top() [step 1 click]
                   ▼
              ┌──────────┐
              │ REVEALED  │ ── face-up on stack, not yet dragged
              └────┬─────┘
                   │ spend_revealed() [End Activation / token convert]
                   ▼
              ┌──────────┐
              │  SPENT    │ ── activation marker in _spent_history
              └──────────┘
                   │ clear_spent_history() [next round]
                   ▼
                (removed)
```

## One-Dial Ship Edge Case (CR90)

The CR90 Corvette A has command value 1, meaning **one dial per round**.

After step 1 (reveal), the stack state is:
- `hidden_dials = []` (empty — zero hidden)
- `revealed = {command: NAVIGATE, ...}`

### Bug History

| Commit | Symptom | Root Cause |
|--------|---------|------------|
| `fc0991b` | Second click never reached `_handle_dial_stack_click` | `_create_dial_rect()` for revealed dials returned a `Control` with `custom_minimum_size` but zero `size`. Godot layout hadn't run yet, so `get_global_rect()` reported zero area. |
| `7865d88` | Same symptom persisted | `queue_free()` on old children was deferred — old dying Control nodes were still in the tree during the same frame. VBoxContainer layout wasn't recalculated. |
| `8787f11` | MISS log showed clicks at x=153 vs rect at x=8 | `_is_click_in_dial_area()` compared `mb.global_position` with `get_global_rect()`, but these use different coordinate spaces for Controls on a CanvasLayer with `canvas_items` stretch mode. |
| **Current fix** | Working | Replaced coordinate comparison with Godot's native input routing: `dial_container` has its own `gui_input` handler (MOUSE_FILTER_STOP). All intermediate containers use MOUSE_FILTER_PASS. Dynamically created children get MOUSE_FILTER_PASS via `_set_children_mouse_pass()`. |

### Visual Representation (CR90, 1 dial)

**Before step 1 (hidden):**
```
  dial_container (VBoxContainer)
    └── active_stack (VBoxContainer, separation=-offset)
          └── TextureRect [cmd_dial_hidden.png, w×h]
```

**After step 1 (revealed):**
```
  dial_container (VBoxContainer, size = w×h)
    └── active_stack (VBoxContainer, size = w×h)
          └── Control [composite: bg + icon, size = w×h]
```

**After board-drop activation:**
```
  dial_container (VBoxContainer)
    └── active_stack (VBoxContainer, empty — 0 hidden, 0 revealed)
    └── Spacer (12px)
    └── Control [spent dial: bg + icon]

  ShipToken (on board)
    └── TextureRect [revealed dial cmd icon, behind base]
```

**After End Activation:**
```
  dial_container (VBoxContainer)
    └── active_stack (VBoxContainer, empty)
    └── Spacer (12px)
    └── Control [spent dial: bg + icon]

  ShipToken → hide_revealed_dial() (TextureRect hidden)
  ship.activated_this_round = true
  _activating_ship = null
```

## Code Locations

| Responsibility | File | Key Methods |
|---------------|------|-------------|
| Dial data model | `src/core/command_dial_stack.gd` | `reveal_top()`, `unreveal_top()`, `spend_revealed()`, `get_revealed_dial()`, `get_display_state()` |
| Panel rendering | `src/ui/ship_card_panel.gd` | `_populate_dial_stack()`, `_create_dial_rect()` |
| Click handling (two-step) | `src/ui/ship_card_panel.gd` | `_on_dial_container_gui_input()`, `_handle_dial_stack_click()` |
| Magnify toggle | `src/ui/ship_card_panel.gd` | `_on_entry_gui_input()`, `_toggle_magnify()` (blocked during discard mode) |
| Token discard mode | `src/ui/ship_card_panel.gd` | `_enter_discard_mode()`, `_exit_discard_mode()`, `_on_discard_token_click()` |
| Duplicate toast | `src/ui/ship_card_panel.gd` | `_show_duplicate_toast()`, `_on_duplicate_token_discarded()` |
| Mouse filter setup | `src/ui/ship_card_panel.gd` | `_set_children_mouse_pass()` |
| Drag lifecycle | `src/scenes/game_board/game_board.gd` | `_on_dial_drag_started()`, `_handle_drag_release()`, `_cancel_drag()`, `_clean_up_drag()` |
| Activation paths | `src/scenes/game_board/game_board.gd` | `_complete_ship_activation()` (board), `_complete_token_conversion()` (card) |
| Domain activation | `src/autoload/game_manager.gd` | `activate_ship()`, `activate_ship_as_token()`, `_on_activation_ended()` |
| Stale reveal cleanup | `src/ui/ship_card_panel.gd` | `_unreveal_other_ships()` |
