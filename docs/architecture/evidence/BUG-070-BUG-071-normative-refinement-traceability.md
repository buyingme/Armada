# BUG-070 / BUG-071 Normative Refinement Traceability

Status: Documentation traceability; no implementation or integration claim.
Date: 2026-10-03

This map applies [CON-003](../contracts/CON-003-rule-capability-contract.md)
to the bounded [CON-001 §5.4](../contracts/CON-001-current-attack-state-and-semantic-transition-contract.md#L418)
refinement. The [joint production diagnosis](BUG-070-BUG-071-joint-production-diagnosis.md#L60)
is the implementation evidence. BUG-070 and BUG-071 remain separate acceptance
obligations. No Rule Capability Package is marked `Integrated` by this map.

The coordinated [Accepted implementation workbook](../implementation_workbooks/BUG-070-BUG-071-gather-and-concentrate-fire-implementation-workbook.md)
plans the shared production repair and preserves separate issue acceptance.

| Behavior slice | Rule-specific traceability required before implementation acceptance | Shared boundary evidence |
| --- | --- | --- |
| Point-Defense Failure mandatory pool removal | Record a CON-003 package or update an existing one for source, registration and gather call site, selection legality, command execution, projection, persistence/replay/Network impact, and last-die plus multi-die tests. | BUG-070 complete-gather, temporary/final zero, cancellation, anti-squadron continuation. |
| Damaged Munitions mandatory pool removal | Record the corresponding damage-card package and the same applicable surface evidence for ship-target attacks. | BUG-070 gather ordering and final-pool evaluation. |
| Obstruction pool removal | Trace the applicable core rule behavior under CON-003, including choice validation, execution, reconstruction, and final-die interaction with card removal. | BUG-070 complete-gather and cancellation. |
| Concentrate Fire dial and token | Trace separate dial addition and token reroll behavior within a reviewable CON-003 package or packages. Cover timing and legality, command costs/results, combined use and ordering, H9 rederivation, projection, save/load, replay, Network passive application, and recovery. Preserve the token's existing post-roll timing evidence. | BUG-071 Resolve Attack Effects timing and BUG-070 no-rescue boundary. |

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
