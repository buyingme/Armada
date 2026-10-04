# BUG-070 / BUG-071 Normative Refinement Traceability

Status: Documentation and implementation evidence; no completion or integration claim.
Date: 2026-10-03

This map applies [CON-003](../contracts/CON-003-rule-capability-contract.md)
to the bounded [CON-001 §5.4](../contracts/CON-001-current-attack-state-and-semantic-transition-contract.md#L418)
refinement. The [joint production diagnosis](BUG-070-BUG-071-joint-production-diagnosis.md#L60)
is the implementation evidence. BUG-070 and BUG-071 remain separate acceptance
obligations. No Rule Capability Package is marked `Integrated` by this map.

The coordinated [implementation workbook](../implementation_workbooks/BUG-070-BUG-071-gather-and-concentrate-fire-implementation-workbook.md)
plans the shared production repair and preserves separate issue acceptance.
It was re-accepted by the Owner on 2026-10-03 following the
[BUG-071 Owner smoke-test and UX resolution](../../qa/bugs/open/BUG-071/issue.md#owner-smoke-test-findings--2026-10-03)
and targeted closure audit. The later
[final Owner effect-presentation refinement](../../qa/bugs/open/BUG-071/issue.md#owner-ux-refinement--concentrate-fire-effect-resolution)
was followed by targeted closure audit and Owner re-acceptance on 2026-10-04.
The latest accepted workbook revision records the direct post-commit CF
interaction requirements.
The historical diagnosis of an advance dial/token/both choice remains valid
for command commitment; it is superseded as a top-level UI presentation.
After commitment, any repeated CF resource/effect dropdown is also
superseded by the direct Dial modal or Token visual reroll interaction.

| Behavior slice | Rule-specific traceability required before implementation acceptance | Shared boundary evidence |
| --- | --- | --- |
| Point-Defense Failure mandatory pool removal | [CAP-DMG-010](../rule_capability_packages/CAP-DMG-010-point-defense-failure-gather.md) records source, registration, gather call site, choice legality, command execution, projection, compatibility, and production evidence. | BUG-070 complete-gather, temporary/final zero, cancellation, anti-squadron continuation. |
| Damaged Munitions mandatory pool removal | [CAP-DMG-011](../rule_capability_packages/CAP-DMG-011-damaged-munitions-gather.md) records the ship-target damage-card path and production Begin → choice → Roll evidence. | BUG-070 gather ordering and final-pool evaluation. |
| Obstruction pool removal | [CAP-CORE-001](../rule_capability_packages/CAP-CORE-001-obstruction-gather.md) records choice validation, execution, reconstruction, and final-die interaction with card removal. | BUG-070 complete-gather and cancellation. |
| Concentrate Fire dial and token | [CAP-CF-001](../rule_capability_packages/CAP-CF-001-concentrate-fire-attack-effects.md) records one CF Use/Decline row, legal Dial/Token/Dial + Token follow-up choices after Use, direct post-commit Dial die-add modal and Token visual reroll interaction with no redundant selector, distinct effects within one command resolution, simultaneous combined commitment, H9 rederivation, result application, projection, compatibility, and recovery. | BUG-071 Resolve Attack Effects timing and BUG-070 no-rescue boundary; Owner smoke-test and final effect-presentation requirements must be closed on the real production UI path. |

The shared attack lifecycle, roll admission, individual cancellation, and
enclosing continuation remain governed by CON-001 and existing Ship/Squadron
owners. Rule packages consume that boundary; they do not own cancellation.
Existing H9 traceability remains in
[CAP-H9-001](../rule_capability_packages/CAP-H9-001-h9-turbolasers.md);
its coexistence evidence must be revisited if the corrected dial result
changes H9 opportunity derivation.

Before behavioral repair is accepted, record applicable ownership, validation,
execution, projection, serialization, replay, Network/reconnect, visibility,
test, and metadata/status evidence in the affected packages. Decide save,
wire, and replay compatibility under existing version authorities; unchanged
payload shape alone is insufficient. Any needed Hot-Seat or Network replay
fixtures remain Owner-recorded manual captures under
[CODEX_WORKFLOW](../CODEX_WORKFLOW.md#replay-fixture-renewal). Existing fixtures
must not be transformed or relabeled. Package status may advance only under
CON-003, and only the Owner may approve `Integrated`.

## Implementation verification — 2026-10-04

- **BUG-070:** [production and recovery integration](../../../tests/integration/test_current_attack_production_resume.gd), [shared protocol](../../../tests/integration/test_current_attack_shared_protocol.gd), [command guards](../../../tests/unit/test_attack_commands.gd), and the [Point-Defense Failure](../../../tests/unit/test_rule_point_defense_failure.gd) and [Damaged Munitions](../../../tests/unit/test_rule_damaged_munitions.gd) suites passed. The real two-process BUG-070 Network scenarios passed for both attacker-role mappings. The Owner separately verified final-Gather cancellation and enclosing continuation manually; the renewed canonical replay fixtures are not claimed as evidence of that sequence.
- **BUG-071:** [production and recovery integration](../../../tests/integration/test_current_attack_production_resume.gd), [CF shared protocol](../../../tests/integration/test_concentrate_fire_shared_protocol.gd), [timing/resource transitions](../../../tests/unit/test_concentrate_fire_timing_window.gd), [UI presentation](../../../tests/unit/test_attack_sim_panel.gd), [result contracts](../../../tests/unit/test_result_application_contract.gd), [ordered delivery](../../../tests/unit/test_network_command_result_ordering.gd), and [replay driver](../../../tests/unit/test_replay_driver.gd) passed. The real two-process BUG-071 Network scenarios passed for both attacker-role mappings. Owner-recorded Hot-Seat replay 11 contains post-roll CF dial additions; authoritative-host Network replay 11 contains combined dial/token use and post-roll die addition.
- The installed Owner-recorded Hot-Seat replay matched its baseline trace and final-state hash; the Network replay reached peer-state equality. Save 9, replay 11, Network protocol 10, application contract 2, and baseline trace 1 remain the accepted cutover. The final full suite passed 4,383/4,383 tests (276 scripts; 20,711 assertions), Phase-K lint had zero violations, local document links resolved, and `git diff --check` passed.

This records candidate evidence for independent implementation audit and separate Owner integration review. BUG-070, BUG-071, and the affected Rule Capability Packages remain open/Draft and are not marked Complete or Integrated.

### Final audit refinements 2 and 3

- Recovery/distributed: [production recovery integration](../../../tests/integration/test_current_attack_production_resume.gd) now reconstructs command-produced committed Dial and partial Dial + Token states on authority and passive installations, retains actionable die-symbol/token controls, and checks stale Dial rejection without state, RNG, history, or cursor movement. The [two-process driver](../../../tests/acceptance/network_resume/driver.gd) and [assertions](../../../tests/acceptance/network_resume/assertions.gd) disconnect and reconnect in both attacker-role mappings for BUG-070 Gather and BUG-071 CF. The CF path uses the real board controls for Use, Dial + Token, Dial die selection, and optional token decline, with a rejected stale choice followed by an actionable retry.
- Resource boundaries: [focused CF tests](../../../tests/unit/test_concentrate_fire_timing_window.gd) cover later attack and anti-squadron suppression, eligibility after top-level Decline, round reset, and atomic rejection of a stale combined choice when either resource disappears. Rejection snapshots include resources, marker, attack/timing state, RNG, command history, and sequence cursor.

The Owner deferred final audit refinement 1 (additional non-fixture ReplayDriver evidence) to separate replay-system work. That finding is not implemented or claimed closed here. The Owner-recorded replay-11 fixtures and baselines are unchanged.
