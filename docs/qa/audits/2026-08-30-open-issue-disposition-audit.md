# Open BUG / UX Disposition Audit — 2026-08-30

Status: Accepted QA disposition assessment
Accepted by: Project Owner
Date: 2026-08-30

Purpose:
Establish the current disposition of historically non-closed BUG and UX
records against the current repository, accepted architecture, implementation,
regression evidence, and retained manual evidence.

This audit is a cleanup and triage record. It does not replace the individual
issue records as historical evidence.

## Audit result

Issue closure and movement remain explicit administrative actions. VERIFY
items remain non-closed until their stated verification is completed.

Read-only audit complete. Eleven non-closed issue identities were found.

| ID | documented state | current evidence | proposed disposition | confidence | required next action |
|---|---|---|---|---|---|
| BUG-008 | VERIFY | Accepted-flow cleanup now retires the Squadron-command range overlay on every peer; exact regression exists at [test_ship_activation_controller.gd:224](/Users/Katharina/godot/Armada/tests/unit/test_ship_activation_controller.gd:224) and passed currently. | **VERIFY** | High | Minimum manual check: in two-player Network, open a Squadron-command range overlay, finish/leave the Squadron step, confirm it disappears on both peers, then open another overlay successfully. |
| BUG-009 | VERIFY | Mirrored lethal damage now resolves the local token from canonical destroyed state. The exact defender-side removal regression at [test_game_board_scenario_bootstrap.gd:393](/Users/Katharina/godot/Armada/tests/unit/test_game_board_scenario_bootstrap.gd:393) passed. No retained real two-peer acceptance exists. | **VERIFY** | High | Minimum manual check: destroy a ship by attack in Network and confirm it disappears immediately on attacker and defender screens without another event or refresh. |
| BUG-011 | VERIFY; repair plan marked Accepted | The accepted RNG-bootstrap repair persists: replay seed selection, validation, and exact-once consumption are implemented at [lobby_manager.gd:223](/Users/Katharina/godot/Armada/src/autoload/lobby_manager.gd:223), [replay_driver.gd:187](/Users/Katharina/godot/Armada/src/autoload/replay_driver.gd:187), and [game_manager.gd:365](/Users/Katharina/godot/Armada/src/autoload/game_manager.gd:365). Current seed-focused tests passed, and the current real two-peer network replay exhausted with peer-equal final hashes. | **CLOSED — verified** | High | Administrative closure only; retain the old format-3 evidence as repair provenance. |
| BUG-020 | OPEN | Its only reproducer is format 5. Accepted UX-005 compatibility allocation requires format 7 and explicitly rejects earlier formats; current deserialization enforces equality at [game_replay.gd:32](/Users/Katharina/godot/Armada/src/core/commands/game_replay.gd:32) and [game_replay.gd:119](/Users/Katharina/godot/Armada/src/core/commands/game_replay.gd:119). The current format-7 two-peer replay passes. | **OBSOLETE / NOT APPLICABLE** | High | Close as obsolete. If the same extra `advance_phase` occurs in a valid format-7 recording, open a new issue linked to BUG-020 rather than altering its legacy replay. |
| BUG-030 | VERIFY | Accepted host-local Redirect results now project the canonical shield refresh. Exact regression [test_network_command_result_ordering.gd:236](/Users/Katharina/godot/Armada/tests/unit/test_network_command_result_ordering.gd:236) passed, but the recorded Rebel-host scenario was not manually rerun. | **VERIFY** | High | Minimum manual check: Rebel host redirects incoming damage; confirm host and client immediately show identical reduced shields on card and token. |
| BUG-031 | OPEN; record duplicated internally | The historical rejected `complete_squadron_activation` route has credibly been replaced by atomic declaration Skip: it records `declined`, completes when appropriate, restores canonical flow, and does not synthesize the rejected completion command ([skip_attack_command.gd:253](/Users/Katharina/godot/Armada/src/core/commands/skip_attack_command.gd:253)). Current command-context and mirrored-network regressions pass, including [test_current_attack_production_resume.gd:2600](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_production_resume.gd:2600). The exact “one activation, skip next, end early” Network run has not been repeated. | **VERIFY** | Medium-high | Minimum manual check: in Network, use a multi-activation Squadron command, complete one squadron, directly Skip the next before Begin, end early, and confirm no completion/adjacent-state rejection and normal progression to Repair. |
| BUG-033 | OPEN | Still vulnerable. `end_game()` only changes local manager state and emits the local `game_ended` signal ([game_manager.gd:641](/Users/Katharina/godot/Armada/src/autoload/game_manager.gd:641)); the victory screen listens to that local signal ([ui_panel_manager.gd:459](/Users/Katharina/godot/Armada/src/scenes/game_board/ui_panel_manager.gd:459)). Although `GAME_OVER` projection definitions exist, `end_game()` does not install or distribute that canonical flow. | **OPEN — relevant** | High | Forensically trace host/client Round-6 and elimination transitions, then define the authoritative replicated end-game transaction before any repair. |
| BUG-035 | OPEN; latest note says automated checkpoint complete | Accepted workbook explicitly says automated acceptance is complete but final two-human Network QA remains pending. Current exact coverage includes host acknowledgement/reconstruction, anti-squadron child return, commanded-squadron terminal branches, replay/mirror behavior, and stable outcomes; examples: [test_current_attack_production_resume.gd:571](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_production_resume.gd:571), [test_current_attack_production_resume.gd:974](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_production_resume.gd:974), and [test_current_attack_production_resume.gd:2276](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_production_resume.gd:2276). | **VERIFY** | High | Minimum manual check: two-human Network attack where both principals acknowledge independently; verify no stale result UI and correct continuation. Include one anti-squadron exhaustion/remaining-target return or one terminal commanded-squadron return. |
| BUG-036 | OPEN; only a 20-line anomaly note | Its independently diagnosed no-defense race is directly covered by [test_current_attack_production_resume.gd:2579](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_production_resume.gd:2579): `commit_accuracy` produces exactly one `resolve_damage` and one `complete_attack`. The focused production suite passed, and the later accepted BUG-035 workbook incorporated exact-once continuation verification. | **CLOSED — verified** | High | Administrative closure; retain as a distinct issue rather than merging it into BUG-035. |
| BUG-037 | OPEN | The captured X-wing was `is_engaged = true` ([annotation:651](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-037/annotation_20260822_180324_002.json:651)). Accepted squadron behavior explicitly disables Skip for an engaged squadron ([squadron_activation_ui.md:125](/Users/Katharina/godot/Armada/docs/requirements/squadron_activation_ui.md:125)), and current UI implements that at [squadron_activation_modal.gd:907](/Users/Katharina/godot/Armada/src/ui/combat/squadron_activation_modal.gd:907). The issue’s expected direct-decline behavior therefore does not apply to its evidence. | **OBSOLETE / NOT APPLICABLE** | High | Close as not applicable. Preserve the later post-entry Skip observation separately as historical evidence; it is not the requested direct-decline entitlement. |
| UX-005 | VERIFY | The accepted ADR-007/CON-007 semantic cutover is implemented, format-7 fixtures are active, focused UX-005/BUG-035 tests pass, and current hot-seat/network baselines pass. The accepted workbook and issue still explicitly reserve final manual Hot-Seat/two-human Network acceptance. | **VERIFY** | High | Minimum manual check: resolve ship and anti-squadron attacks in two-human Network; final result must remain inspectable, each human acknowledges once, continuation waits for both, and no duplicate mutation occurs. This can be combined with BUG-035 verification. |

### Counts

| Proposed disposition | Count |
|---|---:|
| CLOSED — verified | 2 |
| CLOSED — superseded | 0 |
| VERIFY | 6 |
| OPEN — relevant | 1 |
| OBSOLETE / NOT APPLICABLE | 2 |
| NEEDS INVESTIGATION | 0 |
| **Total** | **11** |

### Prioritized manual-verification checklist

1. **BUG-035 + UX-005 combined:** two-human Network completed-result acknowledgement, including one nested continuation branch.
2. **BUG-031:** multi-squadron command, complete one, directly skip the next, end early, and reach Repair without rejection.
3. **BUG-009:** lethal Network attack removes the destroyed ship immediately on both peers.
4. **BUG-030:** host-owned Redirect shield damage refreshes identically on host and client.
5. **BUG-008:** command range overlay retires on both peers and can be reopened.

### Safe administrative closure without further testing

- **BUG-011 — CLOSED — verified**
- **BUG-036 — CLOSED — verified**
- **BUG-020 — OBSOLETE / NOT APPLICABLE**
- **BUG-037 — OBSOLETE / NOT APPLICABLE**

There are no justified **CLOSED — superseded** dispositions; where a later path credibly replaced an older one but exact acceptance remains absent, I retained **VERIFY**.

### Still requiring technical investigation

- **BUG-033** requires technical investigation and remains genuinely open. The present local-only end-game signal path explains why later generic projection work does not establish client victory-screen delivery.
- No issue warrants the separate **NEEDS INVESTIGATION** disposition. BUG-031 needs targeted manual verification first; only a failure would justify renewed technical investigation.

### Materially misleading historical records

- **BUG-011:** still under `verify`, with unchecked plan criteria, despite an implemented accepted repair and current two-peer replay verification.
- **BUG-020:** still `open`, although its format-5 artifact is intentionally unsupported after the accepted strict format-7 cutover.
- **BUG-031:** `open`, but later atomic Skip work credibly replaced the failing transaction; additionally, its issue text is duplicated verbatim within the file.
- **BUG-035:** the headline `Open` status understates the latest accepted state: automated workbook acceptance is complete and only final two-human Network QA remains.
- **BUG-036:** remains an incomplete anomaly note even though its exact race has a current passing regression.
- **BUG-037:** its expected behavior conflicts with its own captured `engaged` state and the accepted engagement rule.
- Both [BUG-INDEX.md](/Users/Katharina/godot/Armada/docs/qa/BUG-INDEX.md) and [UX-INDEX.md](/Users/Katharina/godot/Armada/docs/qa/UX-INDEX.md) are empty, so directory placement currently acts as the de facto registry.

No files, statuses, or commits were changed. The pre-existing modifications to `BUG-BUNDLE.md` and `UX-BUNDLE.md` remained untouched.
