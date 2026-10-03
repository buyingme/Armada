# BUG-070 / BUG-071 Normative Refinement Traceability

Status: Documentation traceability; no implementation or integration claim.
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
and targeted closure audit.
The historical diagnosis of an advance dial/token/both choice remains valid
for command commitment; it is superseded only as a top-level UI presentation.

| Behavior slice | Rule-specific traceability required before implementation acceptance | Shared boundary evidence |
| --- | --- | --- |
| Point-Defense Failure mandatory pool removal | [CAP-DMG-010](../rule_capability_packages/CAP-DMG-010-point-defense-failure-gather.md) records source, registration, gather call site, choice legality, command execution, projection, compatibility, and production evidence. | BUG-070 complete-gather, temporary/final zero, cancellation, anti-squadron continuation. |
| Damaged Munitions mandatory pool removal | [CAP-DMG-011](../rule_capability_packages/CAP-DMG-011-damaged-munitions-gather.md) records the ship-target damage-card path and production Begin → choice → Roll evidence. | BUG-070 gather ordering and final-pool evaluation. |
| Obstruction pool removal | [CAP-CORE-001](../rule_capability_packages/CAP-CORE-001-obstruction-gather.md) records choice validation, execution, reconstruction, and final-die interaction with card removal. | BUG-070 complete-gather and cancellation. |
| Concentrate Fire dial and token | [CAP-CF-001](../rule_capability_packages/CAP-CF-001-concentrate-fire-attack-effects.md) records one CF Use/Decline row, legal Dial/Token/Dial + Token follow-up choices after Use, distinct dial addition and token reroll within one command resolution, simultaneous combined commitment, H9 rederivation, result application, projection, compatibility, and recovery. | BUG-071 Resolve Attack Effects timing and BUG-070 no-rescue boundary; Owner smoke-test finding must be closed on the real production UI path. |

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
