# BUG-043 Production-Boundary Conformance Reassessment

**Status:** Evidence / Read-Only Reassessment
**Repository baseline:** `d304d26`
**Scope:** BUG-043 stabilization production boundaries following BUG-050–053
**Purpose:** Determine whether BUG-050–053 are isolated defects or evidence of a bounded family of production adapter/conformance failures.

> This document is an evidence artifact, not an architecture decision, contract, requirement, or implementation workbook.
>
> It identifies concrete production-boundary defects and risks against existing accepted authority. It does not introduce new gameplay authority or authorize generic integration infrastructure.

**BUG-050–053 reveal a meaningful, finite integration pattern—not four safely isolated leftovers.** Current code contains additional adapter mismatches within the accepted stabilization scope.

Read-only review at `d304d26`; worktree remained clean. No files changed, tests run, or repairs attempted. “CONFORMANT” below is limited to the named handoff; checked-in tests are evidence inspected, not rerun.

Authority: the [accepted BUG-043 workbook, §12](../implementation_workbooks/BUG-043-network-maneuver-preview-speed-convergence-implementation-workbook.md#L1154), its [stabilization refinement](BUG-043-obligation-to-evidence-reconciliation.md#L101), and the applicable accepted ownership, recovery, principal, and passive-state contracts.

| Handoff: producer → adapter → consumer | Conversion and current evidence | Classification |
|---|---|---|
| Applied Maneuver transform/destruction → processor capture → `destroy_unit` and Ship Phase return | Explicit capture now includes `apply_maneuver_transform`, including destruction without damage cards. [Production](../../../src/autoload/command_processor.gd#L368); [V3 regression](../../../tests/unit/test_candidate_apply_maneuver_transform_command.gd#L109). | **CONFORMANT** — BUG-050 repaired |
| Evaluator `player_index:int` → Maneuver descriptor → modal `chooser:"owner"\|"opponent"` | Explicit comparison against canonical ship owner; numeric actor retained separately for submission. [Adapter](../../../src/scenes/game_board/ship_activation_controller.gd#L1261); V4 checks chooser and reconstruction equivalence. | **CONFORMANT** — BUG-051 repaired |
| Modal obstacle-order string → `split()` → command `obstacle_ids:Array[String]` | Produces `PackedStringArray`; command requires ordinary `Array`. [Exact defect](../../../src/scenes/game_board/ship_activation_controller.gd#L1283); recorded V6 rejection. | **KNOWN DEFECT** — BUG-053 |
| Thruster evaluator’s public-reference list → pending action/modal → command requiring one `public_card_ref:String` | Reference is outside `payload`; confirmation adds only `hull_zone`. Required identity never reaches command. [Producer](../../../src/core/movement/maneuver_execution_evaluator.gd#L35), [adapter](../../../src/scenes/game_board/ship_activation_controller.gd#L1284), [consumer](../../../src/core/commands/candidate_resolve_thruster_fissure_command.gd#L9). | **KNOWN DEFECT** — D1 |
| Maneuver hull/Station/immediate options → modal IDs or typed selections → exact command unions | Hull strings remain strings; Station ordinal/token/dial IDs explicitly become integers; Shield selections remain ordinary string arrays, including empty selection. Branch-only fields are preserved. [Adapters](../../../src/scenes/game_board/ship_activation_controller.gd#L1284). V4 proves presentation; direct command tests cover unions. | **CONFORMANT**, excluding D1 and BUG-053 |
| Attack/debug immediate descriptor → shared modal/helper → canonical automatic/choice union | Legacy descriptor cardinality and automatic branches differ from the new command contract. [Descriptor](../../../src/core/damage/immediate_effect_resolver.gd#L74), [helper](../../../src/autoload/game_manager.gd#L2146), [validator](../../../src/core/commands/candidate_resolve_immediate_effect_command.gd#L305). | **KNOWN DEFECT** — D2 |
| Save-7 JSON → ship/objective deserializers → strict Maneuver/immediate/obstacle owners | Declared integer fields are explicitly restored; geometric floats retained. Empty records and automatic actor `-1` remain distinct. [Ship normalization](../../../src/core/state/ship_instance.gd#L1930), [objectives](../../../src/core/state/game_state.gd#L985); V5 round-trips and fractional rejection. | **CONFORMANT** — repaired BUG-052 fields |
| Saved displacement flow → `InteractionFlow.deserialize()` → displacement submission | Flow envelope enums/controller normalize, but nested payload identities remain JSON floats; submit adapter explicitly requires integers. [Deserializer](../../../src/core/state/interaction_flow.gd#L81), [consumer](../../../src/autoload/game_manager.gd#L1457). | **KNOWN DEFECT** — D3 |
| Installed pending state → normal board initialization/router → actionable Maneuver/displacement modal | Normal reconstruction is gated by completed-Attack inspection; displacement routing additionally requires a live command. [Board](../../../src/scenes/game_board/game_board.gd#L1384), [router](../../../src/scenes/game_board/modal_router.gd#L313). | **KNOWN DEFECT** — D4 |
| Authority completion facts → filtered snapshot → passive evaluator | Filtering correctly omits authority-only markers, but evaluator treats their default absence as unresolved work. [Public card conversion](../../../src/core/damage/damage_card.gd#L163), [obstacle filtering](../../../src/core/network/state_filter.gd#L50), [consumer](../../../src/core/movement/maneuver_execution_evaluator.gd#L169). | **KNOWN DEFECT** — D5 |
| Numeric command actor → authenticated endpoint/principal → authoritative submission | Canonical player identity is checked independently of endpoint/viewer identity. Replacement assignment precedes admission. [Ingress](../../../src/autoload/network_manager.gd#L1564); V6 reached wrong-principal rejection, client commitment and replacement assignment before BUG-053. | **CONFORMANT** for inspected principal mapping |
| Automatic immediate actor `-1` → owner-number fallback → ordinary player submitter | Numeric fallback exists, but automatic Attack/debug work uses ordinary `.submit()`, unlike the authoritative route. [Helper](../../../src/autoload/game_manager.gd#L2166), [host gate](../../../src/core/commands/network_host_command_submitter.gd#L22). | **CREDIBLE SAME-FAMILY RISK** — R1 |
| Accepted command/result → protocol-7 envelope → ordered passive application | Explicit application contract/version/viewer checks; command-owned application; ordered cursor and duplicate rejection. RPC dictionaries preserve runtime numeric types. [Envelope](../../../src/autoload/network_manager.gd#L1810), [application](../../../src/autoload/command_processor.gd#L790). Direct passive tests exist; remaining V6 composition is incomplete. | **CONFORMANT** for inspected transport/application boundary |
| Immediate result v2 → visual signal adapter → speed/dial/shield presentation | Old helper reads top-level legacy fields; v2 puts effect facts under `effect_result` and damage facts under `damage_application`. Other refresh paths compensate partly. [Legacy consumer](../../../src/core/damage/immediate_effect_signals.gd#L29), [current event adapter](../../../src/scenes/game_board/command_router_adapter.gd#L217). | **CREDIBLE SAME-FAMILY RISK** — R2 |
| Recorded semantic commands → replay-10 JSON canonicalization → `submit_replay` | Explicit scalar, integer-array and nested-identity normalization; exact seed string; floats preserved; processor follow-ups suppressed. [Command adapter](../../../src/core/commands/game_command.gd#L312), [replay loader](../../../src/core/commands/game_replay.gd#L124). Numeric round-trip tests exist; V8 composite remains outstanding. | **CONFORMANT** at representation boundary |
| Unrelated gameplay, additional geometry permutations, generic type cleanup | Outside this reassessment; no identified adapter dependency warrants expansion. | **NO FURTHER INSPECTION** |

**1. Shared bounded pattern**

The recurring failure is incomplete adaptation between existing representations: canonical identity and lifecycle facts, UI descriptors, semantic payloads, serialized values, and passive state. Strict consumers often correctly reject what a stale producer supplies.

The evidence also repeatedly stops just before the consequential boundary: displaying a descriptor does not prove confirmation; loading state does not prove resumed submission; explicitly invoking reconstruction does not prove normal startup invokes it.

**2. Additional code-demonstrable defects**

- **D1 — Thruster source identity disappears.** The evaluator supplies `public_card_refs` alongside a payload lacking `public_card_ref`. The modal adapter never transfers a reference. A genuine confirmation therefore fails the exact payload schema. Existing controller testing [injects the missing reference itself](../../../tests/unit/test_ship_activation_controller.gd#L365), while V2 constructs the command directly.

- **D2 — Adjacent immediate adapters retain stale branch semantics.** With exactly one Injured Crew token, the resolver opens a choice and the helper adds `defense_token_index`; canonical validation permits that field only when multiple tokens exist. With Comm Noise and neither speed nor dial available, the empty-choice helper omits mandatory `comm_noise_action:"none"`. Speed-only Comm Noise is also presented as an opponent choice although canonical authority classifies it as automatic.

- **D3 — Recovered displacement cannot pass its submission adapter.** Save-7 leaves `interaction_flow.payload.owner_player` and `ship_index` as floats; `submit_commit_displacement()` rejects them before constructing a command. V5 checks the flow envelope and evaluator’s waiting state, not successful resumed displacement submission.

- **D4 — Reconstruction helpers are not fully connected to production entry.** Ordinary pending Maneuver states do not satisfy the board’s completed-inspection gate. Even an explicit router reconstruction passes `null`, which displacement immediately rejects. The V6 driver [explicitly invokes the controller projection](../../../tests/acceptance/network_resume/driver.gd#L1547), masking the first omission.

- **D5 — Filtered recovery loses information that the evaluator still assumes it owns.** For example, resolve the first of two Ruptured Engine instances and reconnect while the second is pending: filtered cards omit both execution markers, so the evaluator selects the first instance again. Authority rejects that stale choice. Similarly, completed obstacle markers disappear while overlap re-derivation still interprets absence as unresolved. **The filtering is contractually correct; publishing those authority-only markers is not the repair.**

**3. High-confidence risks worth closing**

- **R1:** Prove automatic immediate resolution across differing host/ship principals. Mapping sentinel `-1` to an owner number does not establish authority-origin submission. Also verify that player ingress rejects the workbook’s authority-only branches.
- **R2:** Exercise v2 immediate results through actual visual consumers, especially Comm Noise speed/dial changes. The legacy result-field mismatch is concrete; the complete user-visible impact depends on compensating refresh paths.
- **R3:** Close adjacent Attack/debug recovery through their real entry points. [Attack recovery](../../../src/scenes/game_board/attack_executor.gd#L643) maps resolved attacks to “await recorded completion” without rebuilding the immediate choice; [debug presentation](../../../src/scenes/game_board/command_router_adapter.gd#L156) depends on the original damage-result callback. These are positive same-family warning signs, not merely absent tests.

**4. Inspected and conformant**

The repaired BUG-050 cleanup, BUG-051 chooser conversion, and BUG-052 ship/objective integer restoration; Maneuver Station/hull/token/dial/Shield selection conversions; canonical target-versus-actor lookup; principal reassignment and wrong-principal rejection; protocol result envelopes and ordered application; and replay command numeric normalization.

No additional packed-array variant was found in the inspected Shield or displacement payload producers.

**5. Minimum package before resuming V6**

Record and disposition D1–D5 alongside BUG-053, then repair only their existing adapters and reconstruction entry points. Close R1–R3 with focused production-seam evidence and repair only demonstrated failures.

The minimum evidence should:

- Confirm actual modal selections through strict command validation, including Thruster identity and the adjacent automatic/choice edge cases.
- Resume and submit displacement after a signed Save-7 round-trip.
- Open pending decisions through normal board/reconnect startup, without test-side projection calls.
- Reconnect after one persistent-card or obstacle consequence has already completed.
- Preserve wrong-principal rejection, authority-only automatic work, and passive non-synthesis.

Then resume the existing V6 composite and V8 semantic-history replay. Missing V8 evidence alone does not justify a replay repair or additional fixture families.

**6. Owner architecture decision**

**None is presently required.** Existing contracts define the required representations and ownership. Newly discovered defects need the refinement’s scope disposition before implementation, but that is not a new architecture decision. No repair was performed, including BUG-053.
