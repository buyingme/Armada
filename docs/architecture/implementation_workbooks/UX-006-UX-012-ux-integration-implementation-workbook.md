# UX-006–UX-012: UX Integration Implementation Workbook

Status: **Draft — decision blocked; no implementation authorization**

Purpose: record the bounded discovery, accepted-owner implementation slices, and
Owner decisions needed before UX-006–UX-012 may be implemented as one package.
The seven `docs/qa/ux/planned/UX-*/issue.md` records are the UX requirements.
This workbook does not mark them implemented, verified, or accepted.

## 1. Route, authority, and baseline

This is uncertain/high-risk architecture discovery under `AGENTS.md` and
`CODEX_WORKFLOW.md`: several requested acknowledgements would block gameplay.
`DOCUMENT_AUTHORITY.md` gives accepted ADRs and Contracts precedence over
implementation convenience. Applicable accepted boundaries are ADR-001
(command-owned mutation), ADR-006 (ship activation), ADR-007 and CON-007
(purpose-specific completed-attack inspection and squadron action/release),
ADR-010 (decision-equivalent recovery), and ADR-014 (immediate faceup damage).
The committed BUG-043/058 and BUG-063/064 implementation is the code baseline,
not permission to enlarge those architectures. The UX-005 workbook is historical
implementation evidence; ADR-007/CON-007 are the governing accepted scope.

The prior reported full-suite baseline was 4,337/4,338, with the dial-picker
test as the sole known failure. A separately authorized test-isolation fix now
passes the dial-picker script 18/18 and the full suite 4,338/4,338. That fix
changed only the test; no production code or replay fixtures were changed.

## 2. Classification and requirement trace

`A` is presentation/transient interaction under existing authority; `B` is a
bounded integration at an existing owner; `C` needs an Owner architecture,
ownership, or semantic decision. A mixed issue takes its highest classification.
For every row, the linked issue remains the complete requirement and acceptance
list; the table maps it to the observed production boundary.

| Issue | Class | Current path and exact seam | Required outcome, authority, and recovery |
| --- | --- | --- | --- |
| [UX-006](../../qa/ux/planned/UX-006/issue.md) | **C** | Attack `ResolveDamageCommand`/candidate damage application and `AttackExecutor` have an attack-specific faceup presentation. Candidate asteroid damage publishes `damage_application.faceup_additions` through `CommandRouterAdapter`, which emits `damage_card_dealt(ship, null, true)`; `GameBoard` shows a toast and the ship card refreshes. Debug/immediate paths have their own routing. | Every newly dealt faceup card, whatever its source, needs closeup on both Network peers and required acknowledgement before continuation; facedown behavior stays unchanged. The faceup assignment and immediate effect remain canonical command/ship/deck facts. A durable, principal-sensitive, recoverable acknowledgment barrier and its ordering against immediate effects are not authorized outside the completed-attack purpose. UI closure cannot release gameplay. Save/load, reconnect, filtered Network projection, and replay would need the accepted barrier and semantic acknowledgments. |
| [UX-007](../../qa/ux/planned/UX-007/issue.md) | **B** | `ShipCardPanel` renders canonical `ShipInstance.command_tokens` on `EventBus.command_tokens_changed`. Ordinary spend/discard paths emit it. `ResolveImmediateEffectCommand` clears all tokens for Life Support Failure, while `GameManager._handle_remote_immediate_effect` and `CommandRouterAdapter._emit_candidate_damage_events` refresh damage/dial/hull but do not publish token refresh for that effect. | After *every* accepted token mutation, immediately project canonical tokens on Hot-Seat, host, and client. Treat Speed-0/obstacle causation as unproven. Verify the actual failing token path first; if canonical tokens are wrong, record a separate gameplay defect and STOP. No UI-local token mutation. Rebuild after load/reconnect from canonical state; replay retains existing commands. |
| [UX-008](../../qa/ux/planned/UX-008/issue.md) | **C** | `ObstacleOverlapAuthority` and `ManeuverExecutionEvaluator` derive overlap, order, and next `commit_maneuver_obstacle_order`/obstacle consequence. The command path currently proceeds from overlap to effect/choice. | Before each obstacle effect, identify obstacle and impending rule/effect; in Network both principals acknowledge before the effect. This needs an authoritative pre-effect barrier, required-principal semantics, and a recoverable handoff to existing obstacle commands. It cannot be a modal/timer gate. Asteroid faceup presentation follows consequence and then UX-006. Save/load, reconnect, passive application, and replay ordering need an Owner-approved purpose-specific boundary. |
| [UX-009](../../qa/ux/planned/UX-009/issue.md) | **B** | `DestroyUnitCommand.execute` already clears all assigned faceup/facedown cards and discards them into `GameState.damage_deck`; its passive application updates the public discard ledger. `CommandRouterAdapter` publishes `ship_destroyed`; `ShipCardPanel._on_ship_destroyed` ghosts the row but does not refresh its damage column. | Prove command-owned transfer of every former card to the authoritative discard pile on host and passive mirror, then refresh the destroyed ship's card from canonical state. Do not merely hide cards. Save/load and replay must preserve the discard result; reconnect must rebuild the empty column. If the production path fails to discard, repair only that existing destruction owner or STOP if ownership is missing. |
| [UX-010](../../qa/ux/planned/UX-010/issue.md) | **C** (ordinary transitions **A**) | `UIProjector.project_turn_transition` limits handoff overlay to shared-screen Command Phase but `_needs_turn_banner` also requests a timed banner in Ship/Squadron Phase. `GameBoard` renders it. `GameManager.end_game` locally derives scores/winner, emits `game_ended(details)`, and `UIPanelManager.show_game_end` immediately shows `VictoryScreen`. | Suppress ordinary Hot-Seat/Network turn banners while retaining the Hot-Seat private Command Phase handoff. Match completion needs winner-oriented Hot-Seat `VICTORY`, Network winner `VICTORY`/loser `DEFEAT`, then a two-second presentation before the existing Result screen. The authoritative match-result identity, delivery to both peers, and recovery/replay after completion are not established by the local event alone. A timer may delay presentation only, never authoritative game termination. |
| [UX-011](../../qa/ux/planned/UX-011/issue.md) | **C** | In Squadron Phase, `SquadronActivationModal._validate_squadron_selection` calls `GameManager.activate_squadron` on click. In Squadron Command, `SquadronPhaseController.try_handle_squadron_click` calls `activate_commanded_squadron` on click. Existing `ActivateSquadronCommand` changes canonical activation/capacity; modal range/options are then projected. Precommit command-mode Skip is presently Back. | Clicking/cycling must remain transient; Move/Attack/Skip choice commits and Skip consumes an activation, marks activated, and forbids normal reactivation. CON-007-SQMOVE-008 explicitly forbids exposing current Squadron Activation action controls before accepted `ActivateSquadronCommand`. That conflicts with using the existing action buttons as precommit choices. Owner must decide the action-intent/activation-acceptance ordering and amend the accepted contract if needed. Do not commit inspection, make `InteractionFlow` owner, duplicate range legality, or synthesize Network/replay commands. |
| [UX-012](../../qa/ux/planned/UX-012/issue.md) | **A** | `ManeuverExecutionEvaluator` supplies canonical obstacle IDs plus `obstacle_type`; `ShipActivationController._maneuver_choice_descriptor` builds option IDs from ordered canonical IDs but uses those IDs as labels. | Render each ordering with obstacle type names (including same-type names without gratuitous numbering), retaining each distinct canonical ID payload, ship-owner decision, legal alternatives, and effects. Labels are transient projection, not authoritative selection keys. Rebuild identically after load/reconnect; replay records existing order command only. |

## 3. Ownership and shared seams

| Boundary | Existing owner and allowed role | Issues |
| --- | --- | --- |
| Damage result/card lifecycle | Damage/deck, `ShipInstance`, command result, public application ledger; `CommandRouterAdapter` and `ShipCardPanel` project accepted facts. | 006, 007 (Life Support Failure), 009 |
| Maneuver overlap decision | Canonical maneuver/obstacle state and existing obstacle commands; `ManeuverExecutionEvaluator` derives next decision; `ShipActivationController` labels and routes it. | 008, 012; 006 follows asteroid faceup damage |
| Squad activation | `ActivateSquadronCommand` and squadron/command capacity facts; modal and controller may hold disposable inspection only. | 011 |
| Turn/end presentation | `UIProjector` and `GameBoard` project current turn; `GameManager`/`ScoringCalculator` currently emit local match details; `UIPanelManager` renders Result. | 010 |

Share the accepted damage-application projection for faceup event discovery and
post-destruction refresh where it already carries the relevant canonical fact;
do not merge the distinct faceup-result and obstacle-*pre-effect* barriers.
Share the obstacle metadata-to-label projection for UX-012 with UX-008 context
only after UX-008's gate is decided. Do not create seven independent state
owners or a generic decision, acknowledgment, continuation, transaction, or FSM
layer. `InteractionFlow` remains derived interaction state.

## 4. Dial-picker baseline failure

`tests/unit/test_command_dial_picker.gd::test_confirm_emits_signal_and_closes`
creates a standalone `ShipInstance` and emits the global
`EventBus.command_picker_confirmed`. `GameManager` is also subscribed and,
when prior suite tests leave `is_game_active` with phase `SQUADRON` (phase 3),
tries `AssignDialCommand` using that unrelated state/ship. Both
`CommandApplicability` and `AssignDialCommand.validate` correctly restrict
`assign_dials` to Command Phase. Isolated execution passes 18/18, confirming
suite-state coupling; there is no demonstrated production defect. The test now
temporarily sets `GameManager.is_game_active = false` during the synchronous
signal emission and immediately restores its prior value. It retains the
emitted ship/commands and closed-picker assertions; production phase validation
is unchanged. Verification: dial-picker script 18/18, full suite 4,338/4,338.

## 5. Decision-blocked slices and minimum Owner decisions

These C issues prevent safe unified implementation authorization. The
following are questions, **not** selected designs:

1. **UX-006:** Which purpose-specific canonical owner records each pending
   faceup-card inspection, required principals, received acknowledgments, and
   exact release point across attack, asteroid, debug, and other accepted
   sources? How is it ordered against immediate-card obligations and an
   already-pending completed-attack inspection? Alternatives are separate
   source-specific barriers with explicit composition, or an explicitly
   accepted broader faceup lifecycle. The former adds per-source seams; the
   latter changes ADR-007's deliberately narrow scope. In either case the
   Owner must decide identity, principal set, and release semantics.
2. **UX-008:** Which canonical maneuver/obstacle owner gates the next effect
   before mutation, and which existing semantic transaction resumes it after
   both Network acknowledgments? Alternatives are a purpose-specific
   pre-effect obstacle record/command at the existing maneuver boundary, or
   an approved different durable coordination boundary. A UI-local notice
   cannot meet the requirement; extending completed-attack inspection is
   outside ADR-007. Decide repeated overlaps, ordering, and recovery identity.
3. **UX-010 match completion:** Is the existing `GameManager.end_game` result
   accepted as the authoritative match-result source, and how is one result
   delivered/recovered on host and client? Alternatives are an approved
   canonical terminal result or an explicitly accepted derivation from the
   same canonical terminal facts with reason/identity transport. Local
   independent `game_ended` events alone do not prove same-result delivery.
4. **UX-011:** May precommit Move/Attack/Skip intent controls be shown before
   accepted activation despite CON-007-SQMOVE-008, or must there be a distinct
   non-action inspection/commit affordance? The first needs a narrow accepted
   contract refinement and a defined choice → `ActivateSquadronCommand` →
   existing action ordering (including rejection, Move cancel, Skip and
   command capacity). The second preserves the contract but requires Owner
   confirmation that the resulting UX satisfies the issue. Also decide whether
   the requested precommit Skip is available while engaged: the current modal
   disables Skip when engaged (`SM-012: must attack`), whereas the issue states
   Skip's consumption semantics without spelling out this legality exception.
   Preserve the accepted gameplay restriction unless the Owner explicitly
   changes it; do not create a UI-only legality rule. Choose the semantics
   before changing the modal or command timing.

## 6. Conditional implementation slices after Owner resolution

Entry gate: Owner resolves Section 5 in accepted authority and accepts an
amended workbook. Slices below are bounded only where existing ownership is
already clear; C slices must be specified after their decisions.

1. **Baseline isolation — completed separately:** the dial-picker test-only
   correction and isolated/full verification are recorded in Section 4. No
   further dial-picker change is authorized by this Draft absent a regression.
2. **UX-007 token projection:** first reproduce the observed stale path with
   canonical before/after token counts and ship-card state. Cover at least
   ordinary spend/discard and Life Support Failure. At the accepted
   command-result projection seam (`GameManager` remote application and/or
   `CommandRouterAdapter` local/passive callback as applicable), publish a
   token refresh for actual accepted token change; rebuild from canonical
   `ShipInstance.command_tokens`. Do not emit from speculative UI work.
3. **UX-009 destruction:** verify faceup/facedown/mixed discard counts and
   identity via `DestroyUnitCommand` and passive result/ledger. Refresh the
   exact destroyed ship's damage column after accepted destruction, including
   reconstruction. Keep existing destruction, deck, and private-history owner.
4. **UX-012 labels:** map `action.obstacles[].obstacle_id` to its
   `obstacle_type` in the choice descriptor; display type names, preserve the
   ordered ID string as option identity and submitted payload. Do not deduce
   legality from labels or collapse distinct authoritative options merely
   because their labels match.
5. **UX-010 ordinary transitions:** narrow `UIProjector`/`GameBoard` turn
   prompt projection to the Hot-Seat Command Phase private handoff. Remove
   timed ordinary Ship/Squadron/Network banner dependency; leave canonical
   turn/phase commands unchanged. Match completion waits for Section 5.3.
6. **C slices:** after accepted decisions, implement UX-008's pre-effect gate
   before obstacle consequence, UX-006's post-deal faceup inspection, and
   UX-011's precommit inspection/accepted activation ordering. The exact
   authorized files, command/schema/version changes, principal validation,
   and replay-capture gate must be added to this workbook before coding.

Likely existing A/B file areas: `src/core/network/ui_projector.gd`,
`src/scenes/game_board/{game_board,ship_activation_controller,command_router_adapter}.gd`,
`src/scenes/game_board/ui_panel_manager.gd`, `src/ui/ship/ship_card_panel.gd`,
`src/autoload/game_manager.gd`, and focused tests under `tests/unit/` or
`tests/integration/`. Command, `GameState`, Network protocol, save schema, and
replay/version files are **not** authorized by this Draft.

## 7. Evidence obligations and convergence

Evidence must exercise the production seam, not just a visible end state.
Deduplicate shared evidence deliberately:

- **Token projection (007):** accepted mutation → canonical token delta →
  post-application notification → exact ship-card re-render; unchanged/rejected
  operation causes no false token mutation. Test Hot-Seat and both Network
  perspectives, including Life Support Failure and observed failure path.
- **Damage lifecycle (009):** one matrix of facedown, faceup, and mixed cards
  proves command-owned removal/discard, passive public/private correctness,
  ship-card refresh, save/load/reconnect reconstruction, and non-fixture replay
  command parity. Reuse this matrix for UX-006 source inventory where relevant.
- **Obstacle projection (012):** mixed-type and same-type labels, distinct
  canonical ID payloads, both legal orders, unchanged owner and consequences;
  Hot-Seat and both Network perspectives. Reuse the same overlap setup for
  UX-008 after its decision, but add pre-effect and two-principal gating proof.
- **Turn presentation (010 A):** projection truth table for Hot-Seat Command
  handoff, Hot-Seat Ship/Squadron, Network Ship/Squadron, and no timer-controlled
  authority progression. After the result decision, prove one result on both
  Network peers, winner/loser text, Hot-Seat winner orientation, two-second
  visual sequence, and Result-screen transition including recovery.
- **Faceup inspection (006 after decision):** attack, asteroid, and every
  identified faceup source; both Network peers; either ack order; one ack
  insufficient; duplicate/stale/wrong-principal rejection; immediate-effect
  order; unchanged facedown path; save/load/reconnect/replay equivalence.
- **Squadron inspection (011 after decision):** repeated phase and command-mode
  candidate cycling leaves canonical activation/capacity and opponent state
  unchanged; range/options derive accepted legality. Each Move/Attack/Skip
  path commits once; rejection leaves capacity unchanged; Skip marks activated
  and blocks reactivation; command capacity/return and phase progression;
  Hot-Seat, Network host/client, save/load/reconnect, and replay record only
  accepted gameplay commands.
- **Dial fixture:** isolated and full-suite execution, with production
  `assign_dials` phase rejection retained.

After any authorized implementation: run focused production-seam tests,
relevant Hot-Seat and real Network acceptance, non-fixture save/load/reconnect
and replay verification, architecture/static checks, schema/registration checks
if changed, `git diff --check`, and the full automated suite. Do not paper over
failures or broaden BUG-043/058. Do not generate, synthesize, reconstruct,
patch, transform, relabel, promote, or replace accepted replay fixtures.
If accepted authority requires genuine replay renewal, end Codex work at
**STOP FOR OWNER REPLAY CAPTURE**; the Owner manually records required Hot-Seat
and Network evidence. Owner manual tests must inspect card closeups/ordering,
token and damage columns, obstacle labels/context, reversible squadron
inspection, handoff suppression, and mode-specific endgame presentation.

STOP for Owner review on any new gameplay owner, unresolved acknowledgment
composition, altered completed-attack inspection, generic continuation/FSM,
UI-owned legality/progression, missing canonical discard/result authority,
unapproved protocol/save/replay change, or need to change an accepted contract.
No implementation begins from this Draft.
