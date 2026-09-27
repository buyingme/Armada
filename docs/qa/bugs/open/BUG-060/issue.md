# BUG-060 — Immediate Result v2 Does Not Refresh Speed Visuals

**Status:** Open

## Finding

The BUG-043 R2 production-seam test executed a canonical Comm Noise speed resolution and passed its v2 result through the board's visual adapter and the shared Attack/debug visual helper. Neither emitted `ship_speed_changed`. The adapter has no Comm Noise event path; the helper reads obsolete top-level `action` and `new_speed` fields instead of `effect_result`.

## Bounded repair

Read the existing v2 `effect_result` and `damage_application` fields in the established visual paths. Emit speed/dial refresh from board routing for Maneuver and passive client application, while existing live Attack/debug helpers emit their own visual refresh. No gameplay state is changed by this repair.
