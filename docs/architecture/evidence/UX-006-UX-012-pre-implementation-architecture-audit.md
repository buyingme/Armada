> **Evidence status:** Read-only independent architecture review evidence.
> **Normative authority:** None. Findings inform refinement of the UX-006–UX-012
> implementation workbook and affected accepted architecture/contracts.
> **Implementation authorization:** None.

## 1. Verdict

**BLOCKED**

The four Owner decisions are faithfully restated. Two unresolved composition boundaries make implementation unsafe as written; neither requires reopening those decisions.

Read-only, single-agent audit completed. No files changed or tests run. **4,338/4,338** is treated as the supplied baseline, not independently reverified.

## 2. BLOCKER findings

**B1 — Delayed destruction cleanup lacks a demonstrated recoverable owner.**

- **Documented fact:** [Workbook §4.1](../implementation_workbooks/UX-006-UX-012-ux-integration-implementation-workbook.md#L75) blocks destruction cleanup during inspection, then requires continuation from canonical source state.
- **Production fact:** Lethal asteroid damage calls [`mark_destroyed()`](../../../src/core/commands/candidate_resolve_asteroid_overlap_command.gd#L57), which [clears activation, Maneuver, immediate, and obstacle state](../../../src/core/state/ship_instance.gd#L274). The exceptional turn-return fact currently survives in a [temporary destruction follow-up](../../../src/autoload/command_processor.gd#L428), consumed by [`DestroyUnitCommand`](../../../src/core/commands/destroy_unit_command.gd#L173).
- **Audit inference:** Saving during the newly introduced inspection can lose whether destruction interrupted the active ship’s turn. The specified inspection fields do not preserve that fact, and the original source owner may already be retired.
- **Required resolution:** Specify and prove the canonical cleanup/exceptional-return boundary across inspection and recovery. Preserve [ADR-006 §3.5](../adr/ADR-006-canonical-ship-activation-boundary-ownership.md#L274) and [ADR-014 §2.3](../adr/ADR-014-canonical-immediate-faceup-damage-card-resolution.md#L229): do not retain a destroyed activation or resurrect its terminated immediate effect merely to support inspection.

**B2 — Terminal match completion is not ordered against outstanding attack/inspection work.**

- **Documented fact:** [Workbook §4.3](../implementation_workbooks/UX-006-UX-012-ux-integration-implementation-workbook.md#L142) installs a terminal result and rejects subsequent gameplay commands, without defining its precedence over pending faceup inspection, destruction cleanup, or completed-attack inspection.
- **Production fact:** Elimination currently originates from a [destruction presentation signal](../../../src/autoload/game_manager.gd#L2680). [`CompleteAttackCommand`](../../../src/core/commands/complete_attack_command.gd#L54) establishes another mandatory inspection, while [preflight permits only specific inspection consumers](../../../src/autoload/command_processor.gd#L267).
- **Audit inference:** Completing the match too early can strand mandatory work; completing it later can encounter an inspection barrier with no authorized terminal consumer. “Exactly once” alone does not settle this.
- **Required resolution:** Name the authoritative completion trigger and legal ordering, including lethal attacks, mutual destruction, and final-round obligations. If completion bypasses or consumes completed-attack inspection, explicitly review **CON-007-BOUNDARY-003, RELEASE-003, XO-002**, and ADR-007; do not assume SQMOVE-008 is the only potentially affected accepted authority.

## 3. REFINEMENT findings

**R1 — Complete the per-source release and obstacle-transition mapping.**

[Workbook §§4.1–4.2](../implementation_workbooks/UX-006-UX-012-ux-integration-implementation-workbook.md#L99) names “existing source owner” but does not map each release to its concrete transaction/reconstruction path.

Production currently [completes a non-immediate asteroid and opens the next obstacle in the dealing transaction](../../../src/core/commands/candidate_resolve_asteroid_overlap_command.gd#L63); [immediate resolution also opens the next obstacle](../../../src/core/commands/candidate_resolve_immediate_effect_command.gd#L360). Debris/station records are opened by [`open_next_purpose_resolution`](../../../src/core/geometry/obstacle_overlap_authority.gd#L125).

**Inference/correction:** Add a small source/transition table proving:

- recovery immediately after the last acknowledgment, before consequence execution;
- how an acknowledged occurrence remains distinguishable from one never announced;
- who opens the next occurrence after a non-immediate faceup inspection;
- consequence failure leaves recoverable work without reopening acknowledgment;
- sequential cards and obstacles never advance through presentation callbacks.

This is implementation-boundary clarification, not a request for generic continuation infrastructure.

**R2 — Scope “Skip consumes activation” precisely in the CON-007 replacement.**

The [proposed SQMOVE-008](../contracts/CON-007-post-attack-continuation-release-contract.md#L227) correctly separates transient intent from accepted activation, but its unqualified “legal Skip” wording can also describe existing declaration Skip.

**Fact:** [CON-006 §11.2](../contracts/CON-006-attack-declaration-lifecycle-contract.md#L930) requires Rogue/commanded declaration Skip to preserve independent movement; [`SkipAttackCommand`](../../../src/core/commands/skip_attack_command.gd#L253) implements that distinction.

**Correction:** Explicitly distinguish the UX-011 whole-activation Skip choice from `SkipAttackCommand`’s attack decline. Preserve SQMOVE-005/006 and CON-006’s matrix through the existing command composition. With that clarification, I found no additional accepted clause requiring amendment **for UX-011 itself**.

Also distinguish rejected activation from rejected action after accepted activation: [activation already commits commanded capacity](../../../src/core/commands/activate_squadron_command.gd#L98). The latter rejection must not refund it.

**R3 — Specify passive replacement and transport evidence at the actual seams.**

[Workbook §§6–7](../implementation_workbooks/UX-006-UX-012-ux-integration-implementation-workbook.md#L264) correctly requires atomic passive installation, but omits the concrete existing [Maneuver replacement validator](../../../src/core/movement/maneuver_consequence_projection.gd#L362). That validator currently recognizes obstacle completion through [specific commands](../../../src/core/movement/maneuver_consequence_projection.gd#L506).

**Correction:** Allocate the new pending/released inspection and occurrence shapes through that closed replacement path. Inventory every transaction that opens the next occurrence, including immediate, debris, and station resolution—not only faceup-deal sources.

Principal-sensitive evidence must exercise [authenticated endpoint → principal → submitted player admission](../../../src/autoload/network_manager.gd#L1629), including impersonated-player rejection and resumed side assignments. Direct acknowledgment-command tests or matching closeups alone cannot prove this responsibility.

**R4 — Make replay renewal and post-capture convergence concrete.**

[Workbook §8](../implementation_workbooks/UX-006-UX-012-ux-integration-implementation-workbook.md#L343) makes fixture renewal conditional.

**Fact:** The accepted [Hot-Seat fixture](../../../tests/fixtures/baseline_traces/replay_hot_seat_solo.json#L127) already runs obstacle order → asteroid damage → immediate effect without either new acknowledgment.

**Inference/correction:** Under the proposed gates, this history requires renewal or an explicitly accepted compatibility treatment. Identify affected captures and conditions before implementation; retain the Owner-only capture boundary. Add an explicit **post-capture** validation/baseline/full-suite convergence step. Do not bypass acknowledgments during replay or bump its format merely to address changed behavior.

**R5 — Include required rule-capability traceability updates.**

The [slice/gate scope](../implementation_workbooks/UX-006-UX-012-ux-integration-implementation-workbook.md#L200) omits the package updates required by [CON-003 §12](../contracts/CON-003-rule-capability-contract.md#L411) when command, projection, serialization, or evidence paths change.

Add affected damage/obstacle package evidence updates and engaged-Skip validation traceability to the authorized scope. The relevant production seam is [`SkipAttackCommand._validate_declaration_skip`](../../../src/core/commands/skip_attack_command.gd#L152). This preserves the settled restriction; it does not authorize new legality or `Integrated` status.

## 4. Verified strengths

- UX-006 and UX-008 remain separate purpose-specific lifecycles; principal sets, acknowledgment order, and inspection-before-effect semantics are explicit.
- UX-010 specifies one authoritative result, correct mode-specific presentation, and a presentation-only delay—not a match FSM.
- UX-011 retains `ActivateSquadronCommand` commitment, disposable inspection, unchanged legality, and no second activation lifecycle.
- UX-007/009 correctly require canonical-state evidence before projection repair. UX-012 preserves canonical obstacle IDs and legal alternatives.
- [§7 evidence](../implementation_workbooks/UX-006-UX-012-ux-integration-implementation-workbook.md#L269) addresses all seven issues’ acceptance areas. The gaps above concern authoritative composition and proof specificity, not missing entire issues.

Recovery assessment:

| Scenario | Assessment |
|---|---|
| One Network faceup acknowledgment, then reconnect; pending-inspection save/load | Specified principal sets preserve the outstanding acknowledgment. |
| Immediate effect creates further consequences | Existing immediate command retains mutation ownership; Structural Damage’s extra facedown card is an [actual production case](../../../src/core/commands/candidate_resolve_immediate_effect_command.gd#L405). Destruction needs B1. |
| Sequential faceup cards; ordered obstacles; obstacle → faceup → immediate effect | Required order is correct; concrete release/recovery mapping needs R1. |
| Reconnect between obstacle announcement and acknowledgment | Specified durable occurrence supports recovery; passive replacement needs R3. |
| Match completion followed by recovery | Result projection is specified correctly; completion ordering needs B2. |
| Repeated squadron cycling → Move/Attack/legal Skip or rejected activation | Correct transient/commit boundary. Engaged restrictions remain fixed; Skip terminology needs R2. |

## 5. Version/schema assessment

- **Save 8:** Justified by new durable state and fail-closed loading. Final sufficiency depends on resolving B1/B2’s state requirements. Current [version is 7](../../../src/core/state/save_game_metadata.gd#L39).
- **Protocol 9:** Justified by incompatible commands/state/result semantics and strict handshake. Current [version is 8](../../../src/autoload/network_manager.gd#L29).
- **Application-result versions:** Changed existing shapes moving **2 → 3**, and new contracts starting at **1**, are reasonable. The inventory is incomplete under R3; unchanged shapes should not receive automatic bumps.
- **Replay 10:** Correct to retain absent a demonstrated file-schema change. Its [header-plus-command representation](../../../src/core/commands/game_replay.gd#L107) accommodates new commands. Semantic fixture compatibility remains a separate obligation.

## 6. Recommended next step

Resolve B1/B2 in the documentation, apply R1–R5, and repeat a focused read-only audit of those changes. Then seek Owner acceptance of the workbook and narrowly scoped contract refinement. Production implementation should remain unauthorized until those boundaries are settled.
