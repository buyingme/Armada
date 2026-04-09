# AttackTargetResolver Extraction — Call-Site Map

> Generated from `src/scenes/game_board/attack_executor.gd` (3285 lines)
> All line numbers refer to the current state of `attack_executor.gd`.

---

## 1. Function Definitions (exact line ranges)

| # | Function | Start | End | Notes |
|---|----------|-------|-----|-------|
| 1 | `_get_ship_edge` | 1336 | 1347 | Pure geometry; no member-var reads |
| 2 | `_attack_sim_is_ship_target_in_arc` | 1349 | 1365 | Reads `_attack_sim_atk_ship`, `_attack_sim_atk_zone` |
| 3 | `_attack_sim_is_squadron_target_in_arc` | 1368 | 1389 | Reads `_attack_sim_atk_ship`, `_attack_sim_atk_zone` |
| 4 | `_attack_sim_compute_los_endpoints` | 1203 | 1221 | Reads atk/def ship/squad/zone vars + `_ZONE_NAMES` |
| 5 | `_adjust_los_for_squadrons` | 1224 | 1254 | Reads atk/def ship/squad/zone vars |
| 6 | `_attack_sim_trace_los` | 1256 | 1268 | Reads def ship/squad; calls `_build_obstruction_bodies`, `_trace_los_to_ship_target`, `_trace_los_to_squad_target` |
| 7 | `_trace_los_to_ship_target` | 1288 | 1309 | Reads `_attack_sim_atk_ship`, `_attack_sim_atk_squad`, `_attack_sim_def_ship`, `_attack_sim_def_zone` |
| 8 | `_trace_los_to_squad_target` | 1311 | 1333 | Reads atk ship/squad, def squad |
| 9 | `_determine_los_status` | 1122 | 1152 | Reads `_attack_sim_def_ship`, sets `_attack_exec_obstructed` |
| 10 | `_attack_sim_compute_range_endpoints` | 1392 | 1414 | Reads atk ship/squad, def ship/squad/zone; calls `_measure_range_from_ship`, `_get_ship_edge` |
| 11 | `_measure_range_from_ship` | 1417 | 1437 | Reads atk ship/zone, def ship/zone, def squad; calls `_get_ship_edge` |
| 12 | `_attack_exec_is_squadron_at_range` | 3052 | 3073 | Reads `_attack_sim_atk_ship`, `_attack_sim_atk_zone`; calls `_get_ship_edge` |
| 13 | `_attack_exec_zone_has_targets` | 3076 | 3089 | Calls `_get_ship_edge`, `_zone_has_enemy_ship_target`, `_zone_has_enemy_squad_target` |
| 14 | `_zone_has_enemy_ship_target` | 3091 | 3119 | Calls `_get_ship_tokens.call()`, `_get_ship_edge` |
| 15 | `_zone_has_enemy_squad_target` | 3121 | 3145 | Calls `_get_squadron_tokens.call()` |
| 16 | `has_any_attack_target` | 565 | 577 | Public. Calls `_attack_exec_zone_has_targets` |
| 17 | `_attack_exec_has_any_valid_target` | 3148 | 3167 | Reads `_attack_exec_ship_token`, `_attack_exec_fired_zones`; calls `_attack_exec_zone_has_targets` |
| 18 | `_attack_exec_has_more_squad_targets` | 3028 | 3050 | Reads `_attack_sim_atk_ship`, `_attack_exec_ship_token`, `_attack_exec_attacked_squads`; calls `_get_squadron_tokens.call()`, `_attack_sim_is_squadron_target_in_arc`, `_attack_exec_is_squadron_at_range` |

### Stays in AE but wrapped as Callable

| Function | Start | End | Notes |
|----------|-------|-----|-------|
| `_build_obstruction_bodies` | 1270 | 1286 | Reads `_token_container`, `_attack_sim_atk_ship`, `_attack_sim_def_ship` |

---

## 2. Call Sites Within `attack_executor.gd`

### `_get_ship_edge` — 8 internal call sites

| Line | Context | Caller function |
|------|---------|-----------------|
| 1357 | `var def_edge: Array[Vector2] = _get_ship_edge(def_token, def_zone as Constants.HullZone)` | `_attack_sim_is_ship_target_in_arc` |
| 1397 | `var def_edge: Array[Vector2] = _get_ship_edge(_attack_sim_def_ship, _attack_sim_def_zone as Constants.HullZone)` | `_attack_sim_compute_range_endpoints` |
| 1418 | `var atk_edge: Array[Vector2] = _get_ship_edge(_attack_sim_atk_ship, _attack_sim_atk_zone as Constants.HullZone)` | `_measure_range_from_ship` |
| 1424 | `var def_edge: Array[Vector2] = _get_ship_edge(_attack_sim_def_ship, _attack_sim_def_zone as Constants.HullZone)` | `_measure_range_from_ship` |
| 3054 | `var atk_edge: Array[Vector2] = _get_ship_edge(_attack_sim_atk_ship, _attack_sim_atk_zone as Constants.HullZone)` | `_attack_exec_is_squadron_at_range` |
| 3080 | `var atk_edge: Array[Vector2] = _get_ship_edge(ship_token, zone)` | `_attack_exec_zone_has_targets` |
| 3103 | `var def_edge: Array[Vector2] = _get_ship_edge(def_token, def_zone as Constants.HullZone)` | `_zone_has_enemy_ship_target` |

> Note: all 7 internal calls are within functions that are *themselves* being extracted. No call sites remain in non-extracted code.

### `_attack_sim_is_ship_target_in_arc` — 1 internal call site

| Line | Context | Caller function |
|------|---------|-----------------|
| 920 | `if not _attack_sim_is_ship_target_in_arc(token, zone):` | `_validate_target_ship_click` (stays in AE) |

### `_attack_sim_is_squadron_target_in_arc` — 2 internal call sites

| Line | Context | Caller function |
|------|---------|-----------------|
| 993 | `if not _attack_sim_is_squadron_target_in_arc(token):` | `_validate_target_squadron_click` (stays in AE) |
| 3040 | `if not _attack_sim_is_squadron_target_in_arc(sq_token):` | `_attack_exec_has_more_squad_targets` (being extracted) |

### `_attack_sim_compute_los_endpoints` — 1 internal call site

| Line | Context | Caller function |
|------|---------|-----------------|
| 1097 | `var endpoints: Dictionary = _attack_sim_compute_los_endpoints()` | `_attack_sim_compute_and_show_los` (stays in AE) |

### `_adjust_los_for_squadrons` — 1 internal call site

| Line | Context | Caller function |
|------|---------|-----------------|
| 1220 | `return _adjust_los_for_squadrons(atk_pt, def_pt)` | `_attack_sim_compute_los_endpoints` (being extracted) |

### `_attack_sim_trace_los` — 1 internal call site

| Line | Context | Caller function |
|------|---------|-----------------|
| 1100 | `var los_result: LineOfSightChecker.LOSResult = _attack_sim_trace_los(atk_pt, def_pt)` | `_attack_sim_compute_and_show_los` (stays in AE) |

### `_trace_los_to_ship_target` — 1 internal call site

| Line | Context | Caller function |
|------|---------|-----------------|
| 1261 | `return _trace_los_to_ship_target(atk_pt, def_pt, bodies, obstacles)` | `_attack_sim_trace_los` (being extracted) |

### `_trace_los_to_squad_target` — 1 internal call site

| Line | Context | Caller function |
|------|---------|-----------------|
| 1264 | `return _trace_los_to_squad_target(atk_pt, bodies, obstacles)` | `_attack_sim_trace_los` (being extracted) |

### `_determine_los_status` — 1 internal call site

| Line | Context | Caller function |
|------|---------|-----------------|
| 1104 | `var los_info: Dictionary = _determine_los_status(los_result, atk_pt, def_pt)` | `_attack_sim_compute_and_show_los` (stays in AE) |

### `_build_obstruction_bodies` — 1 internal call site

| Line | Context | Caller function |
|------|---------|-----------------|
| 1258 | `var bodies: Array = _build_obstruction_bodies()` | `_attack_sim_trace_los` (being extracted) |

### `_attack_sim_compute_range_endpoints` — 1 internal call site

| Line | Context | Caller function |
|------|---------|-----------------|
| 1110 | `var range_data: Dictionary = _attack_sim_compute_range_endpoints()` | `_attack_sim_compute_and_show_los` (stays in AE) |

### `_measure_range_from_ship` — 1 internal call site

| Line | Context | Caller function |
|------|---------|-----------------|
| 1394 | `return _measure_range_from_ship()` | `_attack_sim_compute_range_endpoints` (being extracted) |

### `_attack_exec_is_squadron_at_range` — 1 internal call site

| Line | Context | Caller function |
|------|---------|-----------------|
| 3043 | `if not _attack_exec_is_squadron_at_range(sq_token):` | `_attack_exec_has_more_squad_targets` (being extracted) |

### `_attack_exec_zone_has_targets` — 3 internal call sites

| Line | Context | Caller function |
|------|---------|-----------------|
| 573 | `if _attack_exec_zone_has_targets(ship_token, zone as Constants.HullZone):` | `has_any_attack_target` (being extracted) |
| 3082 | `if _zone_has_enemy_ship_target(...)` → followed by line 3086 `return _zone_has_enemy_squad_target(...)` | Self-body (being extracted) |
| 3158 | `if _attack_exec_zone_has_targets(_attack_exec_ship_token, zone as Constants.HullZone):` | `_attack_exec_has_any_valid_target` (being extracted) |

### `_zone_has_enemy_ship_target` — 1 internal call site

| Line | Context | Caller function |
|------|---------|-----------------|
| 3082 | `if _zone_has_enemy_ship_target(ship_token, zone, atk_arc_pts, atk_edge, attacker_faction):` | `_attack_exec_zone_has_targets` (being extracted) |

### `_zone_has_enemy_squad_target` — 1 internal call site

| Line | Context | Caller function |
|------|---------|-----------------|
| 3086 | `return _zone_has_enemy_squad_target(zone, atk_arc_pts, atk_edge, attacker_faction)` | `_attack_exec_zone_has_targets` (being extracted) |

### `has_any_attack_target` — 1 internal call site + 6 external

| Line | Context | Caller function |
|------|---------|-----------------|
| **Internal:** | | |
| (none) | `has_any_attack_target` is only called externally from AE | — |
| **External (game_board.gd):** | | |
| 1170 | `not _attack_executor.has_any_attack_target(...)` | `game_board.gd` |
| 1195 | `not _attack_executor.has_any_attack_target(...)` | `game_board.gd` |
| 1213 | `not _attack_executor.has_any_attack_target(...)` | `game_board.gd` |
| 1238 | `not _attack_executor.has_any_attack_target(...)` | `game_board.gd` |
| 1261 | `not _attack_executor.has_any_attack_target(...)` | `game_board.gd` |
| 1281 | `not _attack_executor.has_any_attack_target(...)` | `game_board.gd` |

### `_attack_exec_has_any_valid_target` — 2 internal call sites

| Line | Context | Caller function |
|------|---------|-----------------|
| 374 | `if not _attack_exec_has_any_valid_target():` | `start_ship_attack` (stays in AE) |
| 3209 | `if not _attack_exec_has_any_valid_target():` | `_attack_exec_prepare_next_attack` (stays in AE) |

### `_attack_exec_has_more_squad_targets` — 1 internal call site

| Line | Context | Caller function |
|------|---------|-----------------|
| 2997 | `if _attack_exec_has_more_squad_targets():` | `_finalize_squadron_attack` (stays in AE) |

---

## 3. Participant Member Variables — Declarations

| Variable | Line | Type |
|----------|------|------|
| `_attack_sim_atk_ship` | 156 | `ShipToken = null` |
| `_attack_sim_atk_zone` | 158 | `int = -1` |
| `_attack_sim_atk_squad` | 160 | `SquadronToken = null` |
| `_attack_sim_atk_name` | 162 | `String = ""` |
| `_attack_sim_atk_zone_name` | 164 | `String = ""` |
| `_attack_sim_def_ship` | 172 | `ShipToken = null` |
| `_attack_sim_def_zone` | 174 | `int = -1` |
| `_attack_sim_def_squad` | 176 | `SquadronToken = null` |
| `_attack_sim_def_name` | 178 | `String = ""` |
| `_attack_sim_def_zone_name` | 180 | `String = ""` |

---

## 4. Participant Member Variables — Assignment Sites (SET)

These are the places where the attacker/defender participant vars are assigned.
Each group represents one logical assignment site and the enclosing function.

### Site A: `_init_squadron_attack_state` (line 448) — sets attacker to squadron

| Line | Assignment |
|------|-----------|
| 466 | `_attack_sim_atk_ship = null` |
| 467 | `_attack_sim_atk_zone = -1` |
| 468 | `_attack_sim_atk_squad = squadron_token` |
| 470 | `_attack_sim_atk_zone_name = ""` |

### Site B: `_attack_sim_clear_attacker_state` (line 633) — clears attacker

| Line | Assignment |
|------|-----------|
| 634 | `_attack_sim_atk_ship = null` |
| 635 | `_attack_sim_atk_zone = -1` |
| 636 | `_attack_sim_atk_squad = null` |
| 638 | `_attack_sim_atk_zone_name = ""` |

### Site C: `_attack_sim_clear_target_state` (line 642) — clears target

| Line | Assignment |
|------|-----------|
| 643 | `_attack_sim_def_ship = null` |
| 644 | `_attack_sim_def_zone = -1` |
| 645 | `_attack_sim_def_squad = null` |
| 647 | `_attack_sim_def_zone_name = ""` |

### Site D: `_select_attacker_ship_zone` (line 736) — sets attacker to ship hull zone

| Line | Assignment |
|------|-----------|
| 744 | `_attack_sim_atk_ship = token` |
| 745 | `_attack_sim_atk_zone = zone` |
| 746 | `_attack_sim_atk_squad = null` |
| 748 | `_attack_sim_atk_zone_name = zone_name` |

### Site E: `_attack_sim_handle_squadron_click` (line 802) — attacker = squadron

| Line | Assignment |
|------|-----------|
| 815 | `_attack_sim_atk_ship = null` |
| 816 | `_attack_sim_atk_zone = -1` |
| 817 | `_attack_sim_atk_squad = token` |
| 819 | `_attack_sim_atk_zone_name = ""` |

### Site F: `_attack_sim_handle_target_ship_click` (line 857) — target = ship

| Line | Assignment |
|------|-----------|
| 880 | `_attack_sim_def_ship = token` |
| 881 | `_attack_sim_def_zone = zone` |
| 882 | `_attack_sim_def_squad = null` |
| 884 | `_attack_sim_def_zone_name = zone_name` |

### Site G: `_attack_sim_handle_target_squadron_click` (line 947) — target = squadron

| Line | Assignment |
|------|-----------|
| 966 | `_attack_sim_def_ship = null` |
| 967 | `_attack_sim_def_zone = -1` |
| 968 | `_attack_sim_def_squad = token` |
| 970 | `_attack_sim_def_zone_name = ""` |

---

## 5. `initialize()` Function

- **Location:** lines 306–314
- **Signature:** `func initialize(get_ship_tokens: Callable, get_squadron_tokens: Callable, token_container: Node2D, camera: BoardCamera) -> void:`
- This is where `AttackTargetResolver` should be created and injected with the callables.

---

## 6. Key Dependencies Consumed by Extracted Functions

| Variable | Declared | Used in extracted functions |
|----------|----------|---------------------------|
| `_get_ship_tokens` (Callable) | Line 83 | `_zone_has_enemy_ship_target` (L3095) |
| `_get_squadron_tokens` (Callable) | Line 86 | `_zone_has_enemy_squad_target` (L3125), `_attack_exec_has_more_squad_targets` (L3032) |
| `_token_container` (Node2D) | Line 89 | `_build_obstruction_bodies` (L1272) — stays in AE |
| `_ZONE_NAMES` (const Dictionary) | Line 68 | `_attack_sim_compute_los_endpoints` (L1210, 1217, 1234), `_measure_range_from_ship` — can be duplicated or passed |
| `_attack_exec_ship_token` | Line 203 | `_attack_exec_has_any_valid_target` (L3149), `_attack_exec_has_more_squad_targets` (L3029) |
| `_attack_exec_fired_zones` | Line 207 | `_attack_exec_has_any_valid_target` (L3154) |
| `_attack_exec_attacked_squads` | Line 233 | `_attack_exec_has_more_squad_targets` (L3037) |
| `_attack_exec_obstructed` | Line 285 | `_determine_los_status` (L1146) — **side-effect write** |

---

## 7. External Call Sites (outside attack_executor.gd)

### `has_any_attack_target` — called from `game_board.gd`

| Line (game_board.gd) | Context |
|-----------------------|---------|
| 1170 | `not _attack_executor.has_any_attack_target(...)` |
| 1195 | `not _attack_executor.has_any_attack_target(...)` |
| 1213 | `not _attack_executor.has_any_attack_target(...)` |
| 1238 | `not _attack_executor.has_any_attack_target(...)` |
| 1261 | `not _attack_executor.has_any_attack_target(...)` |
| 1281 | `not _attack_executor.has_any_attack_target(...)` |

> After extraction, AE keeps a thin `has_any_attack_target()` wrapper that delegates to `_target_resolver.has_any_attack_target()`, so these external sites need **no changes**.

---

## 8. Call-Site Summary — Which callers stay in AE vs. move

### Callers in AE that stay (will call `_target_resolver.xxx()`):

| Caller function (stays in AE) | Line | Calls extracted function |
|-------------------------------|------|-------------------------|
| `_validate_target_ship_click` | 920 | `_attack_sim_is_ship_target_in_arc` |
| `_validate_target_squadron_click` | 993 | `_attack_sim_is_squadron_target_in_arc` |
| `_attack_sim_compute_and_show_los` | 1097 | `_attack_sim_compute_los_endpoints` |
| `_attack_sim_compute_and_show_los` | 1100 | `_attack_sim_trace_los` |
| `_attack_sim_compute_and_show_los` | 1104 | `_determine_los_status` |
| `_attack_sim_compute_and_show_los` | 1110 | `_attack_sim_compute_range_endpoints` |
| `start_ship_attack` | 374 | `_attack_exec_has_any_valid_target` |
| `_attack_exec_prepare_next_attack` | 3209 | `_attack_exec_has_any_valid_target` |
| `_finalize_squadron_attack` | 2997 | `_attack_exec_has_more_squad_targets` |

### Intra-extracted calls (move together, become internal to resolver):

| Caller (extracted) | Line | Calls (extracted) |
|--------------------|------|-------------------|
| `_attack_sim_is_ship_target_in_arc` | 1357 | `_get_ship_edge` |
| `_attack_sim_compute_los_endpoints` | 1220 | `_adjust_los_for_squadrons` |
| `_attack_sim_trace_los` | 1258 | `_build_obstruction_bodies` (via callable) |
| `_attack_sim_trace_los` | 1261 | `_trace_los_to_ship_target` |
| `_attack_sim_trace_los` | 1264 | `_trace_los_to_squad_target` |
| `_attack_sim_compute_range_endpoints` | 1394 | `_measure_range_from_ship` |
| `_attack_sim_compute_range_endpoints` | 1397 | `_get_ship_edge` |
| `_measure_range_from_ship` | 1418-1424 | `_get_ship_edge` (×2) |
| `_attack_exec_is_squadron_at_range` | 3054 | `_get_ship_edge` |
| `_attack_exec_zone_has_targets` | 3080 | `_get_ship_edge` |
| `_attack_exec_zone_has_targets` | 3082 | `_zone_has_enemy_ship_target` |
| `_attack_exec_zone_has_targets` | 3086 | `_zone_has_enemy_squad_target` |
| `_zone_has_enemy_ship_target` | 3103 | `_get_ship_edge` |
| `has_any_attack_target` | 573 | `_attack_exec_zone_has_targets` |
| `_attack_exec_has_any_valid_target` | 3158 | `_attack_exec_zone_has_targets` |
| `_attack_exec_has_more_squad_targets` | 3040 | `_attack_sim_is_squadron_target_in_arc` |
| `_attack_exec_has_more_squad_targets` | 3043 | `_attack_exec_is_squadron_at_range` |

---

## 9. Existing `AttackTargetResolver` in Repo

An `attack_target_resolver.gd` already exists at `src/core/attack_target_resolver.gd`. It already contains partial implementations of some of these functions using a `CombatParticipants` object. The test file is at `tests/unit/test_attack_target_resolver.gd`.
