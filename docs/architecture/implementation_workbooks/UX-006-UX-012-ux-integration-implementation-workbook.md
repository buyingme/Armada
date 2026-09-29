# UX-006–UX-012: UX Integration Implementation Workbook

Status: **Accepted by Project Owner — 2026-09-29. Implementation pending.**

The seven linked UX issues below are the requirements. This workbook records
the Owner's four decisions as implementation boundaries; it does not mark any
UX issue implemented, verified, integrated, or accepted.

## 1. Authority, baseline, and scope

This is bounded architecture work under `AGENTS.md`, `CODEX_WORKFLOW.md`, and
`DOCUMENT_AUTHORITY.md`. Preserve ADR-001 command-owned mutation, ADR-006 ship
activation ownership, ADR-007/CON-007 completed-attack inspection and Squadron
Action ownership, ADR-010 decision-equivalent recovery, ADR-014 immediate
faceup-card ownership, and the committed BUG-043/058 and BUG-063/064 boundaries.
The Owner decisions in Section 2 settle the four previously open UX design
questions; the CON-007-SQMOVE-008 replacement and the narrow ADR-007/CON-007
terminal-release amendments are accepted authority.
The [original pre-implementation audit](../evidence/UX-006-UX-012-pre-implementation-architecture-audit.md)
is the complete B1/B2 and R1–R5 evidence; its
[follow-up blocker-resolution analysis](../evidence/UX-006-UX-012-blocker-resolution-analysis.md)
supplies the accepted B1/B2 resolution path only. The focused re-audit found
only F1/F2, now refined below. The Owner accepted the workbook and affected
authority amendments after independent closure verification.

The separately authorized dial-picker isolation repair is complete:
`test_command_dial_picker.gd` passes 18/18 alone and the full suite passes
**4,338/4,338**. The test temporarily makes `GameManager` inactive during its
signal-only check and restores its previous state. Production `assign_dials`
phase validation is unchanged. Do not revisit this work without a demonstrated
regression.

In scope: UX-006–UX-012, their purpose-specific canonical records/commands,
filtered Network application, recovery, focused non-fixture tests, and required
version/registration changes. Out of scope: new gameplay legality, generic
acknowledgment/pending-work/continuation/FSM infrastructure, UI-owned gameplay
authority, BUG-043/058 redesign, unrelated UX/bugs, and any replay-fixture
creation or alteration.

## 2. Owner decisions and rationale

The Owner's letter **A** selects an option in each decision gate; it is
distinct from the A/B/C implementation-risk classification in Section 3.

| Decision | Binding implementation meaning | Rationale and excluded alternative |
| --- | --- | --- |
| **UX-006 A: source-independent faceup inspection** | One purpose-specific lifecycle applies to each newly dealt faceup card, whatever accepted command dealt it. It owns only inspection, acknowledgment, and release. Network requires both principals; Hot-Seat requires one shared-screen principal. Deal → inspect/acknowledge → that card's immediate effect, if any → next card/consequence. | A damage result must be visible before its effect or further gameplay. Card assignment, damage/deck mutation, and immediate effect remain with their existing owners. Do not reuse/expand ADR-007's completed-attack inspection or introduce a generic barrier. |
| **UX-008 A: Maneuver/obstacle pre-effect acknowledgment** | Once order is established, each obstacle occurrence receives its own recoverable context/acknowledgment before any consequence mutation. Network requires both principals; Hot-Seat one. Finish one obstacle, including any UX-006 faceup inspection and immediate effect, before the next occurrence. | The notice conveys cause and upcoming effect, not a gameplay choice. Existing obstacle legality and consequence commands remain authoritative. Repeated effects must have distinct occurrence identities, not a UI counter or generic work queue. |
| **UX-010 A: canonical terminal match result** | At authoritative match completion, one durable terminal result owns winner/result identity and presentation facts. Both Network peers project that same result; clients do not establish an outcome. Hot-Seat orients to winner and shows `VICTORY`; Network shows winner `VICTORY` and loser `DEFEAT`; Result follows a presentation-only two-second delay. | A local `game_ended` event cannot by itself prove cross-peer identity or recovery. The result is terminal-match-specific, not a match FSM. Ordinary Ship/Squadron banners remain suppressed; Hot-Seat Command Phase private handoff remains. |
| **UX-011 A: precommit action intent** | Clicking/cycling is transient. Existing authoritative legality supplies prospective ranges and legal Move/Attack/Skip intent. Choosing a legal intent requests `ActivateSquadronCommand`; only acceptance commits activation/capacity, then the existing action path executes. Rejection executes no action. Legal Skip consumes activation and marks the squadron activated. Engaged-squadron Skip restrictions remain. | Precommit information must be inspectable without spending capacity, while the accepted activation command remains the commitment boundary. The accepted CON-007-SQMOVE-008 refinement governs this distinction. |

## 3. Requirement trace and existing production seams

After these decisions, **UX-006, UX-007, UX-008, UX-009, UX-010, and UX-011
are B** (bounded integration under decided ownership); **UX-012 is A**
(presentation). UX-010 ordinary-transition suppression is A within its B
package. No C-class decision remains from the discovery gate.

| Issue | Current input → projection/command → canonical path | Required slice and evidence |
| --- | --- | --- |
| [UX-006](../../qa/ux/planned/UX-006/issue.md) | Attack `ResolveDamageCommand`/`AttackExecutor` show a source-specific closeup; candidate asteroid/other damage results publish `faceup_additions` through `CommandRouterAdapter` and often only refresh a card/toast. Debug and immediate paths route separately. | Slice 1: inventory every accepted faceup-deal source, then put inspection at the accepted deal transaction and project the same card to Hot-Seat/host/client. Gate effects and further damage until required acknowledgments. Face-down path unchanged. |
| [UX-007](../../qa/ux/planned/UX-007/issue.md) | Ship card repopulates from `ShipInstance.command_tokens` on `command_tokens_changed`; ordinary spend/discard emit it. Life Support Failure clears tokens in `ResolveImmediateEffectCommand`, but its accepted-result projection lacks that refresh. | Slice 4: reproduce a canonical-token/visible-token mismatch first; repair accepted-result notification at the existing projection seam, including effect-caused removal. Hot-Seat/host/client render from canonical tokens, without UI mutation. |
| [UX-008](../../qa/ux/planned/UX-008/issue.md) | `ObstacleOverlapAuthority` detects final overlaps; `ManeuverExecutionEvaluator` and obstacle commands order/resolve them. The current path can enter consequence without a prior synchronized context notice. | Slice 2: after accepted order, name each occurrence and upcoming rule/effect, collect principals, then permit the existing consequence. Preserve context → consequence → UX-006 inspection if faceup → immediate effect → next occurrence. |
| [UX-009](../../qa/ux/planned/UX-009/issue.md) | `DestroyUnitCommand` clears assigned faceup/facedown cards and discards into `GameState.damage_deck`; passive application updates its public discard ledger. `ShipCardPanel._on_ship_destroyed` ghosts but does not refresh damage. | Slice 5: prove canonical transfer of all card identities/counts, including the new lethal-source atomic cleanup, then refresh the exact destroyed ship column from resulting state. Save/replay/Network preserve discard; hiding alone is insufficient. |
| [UX-010](../../qa/ux/planned/UX-010/issue.md) | `UIProjector._needs_turn_banner` requests Ship/Squadron timed banners; `GameBoard` renders them. `GameManager.end_game` computes local details and `UIPanelManager` immediately shows Result. | Slices 3 and 8: remove ordinary timed turn prompts, preserve private Command handoff; install one authoritative terminal result, mode-specific victory/defeat presentation, two-second visual delay, then existing Result. |
| [UX-011](../../qa/ux/planned/UX-011/issue.md) | Squadron Phase modal click invokes `GameManager.activate_squadron`; Squadron Command controller click invokes `activate_commanded_squadron`. Both commit before action choice. Precommit command-mode Skip currently means Back. | Slice 6: inspection/cycling/ranges stay disposable, legal intent requests existing activation, accepted activation precedes action, rejected activation consumes nothing. Legal Skip consumes/marks activated and returns through existing owners. |
| [UX-012](../../qa/ux/planned/UX-012/issue.md) | `ManeuverExecutionEvaluator` already supplies obstacle IDs/types; `ShipActivationController._maneuver_choice_descriptor` uses IDs for option labels and canonical ID strings for option values. | Slice 7: type-name labels, same-type names without gratuitous numbering, unchanged distinct canonical option IDs, owner, legal alternatives, and effects. |

The shared seams are (1) accepted damage result → canonical card/token/discard
projection (006/007/009), and (2) Maneuver obstacle metadata → next decision
and presentation (008/012). Sharing these existing seams does **not** merge
the two new acknowledgment lifecycles. UX-011 and terminal match result have
their own existing purpose owners.

## 4. Canonical ownership and cross-boundary rules

### 4.1 Faceup-card inspection — UX-006

Add at most one *faceup damage-card inspection* to `GameState`, distinct from
`completed_attack_inspection`. The dealing transaction installs it with one
public faceup assignment as immutable **occurrence evidence**, even when that
same transaction destroys the ship and transfers the card to discard. Its
minimal immutable facts are a stable occurrence identity derived from accepted
command sequence/card ordinal, the damaged ship's stable public roster
identity, a snapshot of the public card description/reference visible at deal,
and required principal IDs fixed at creation; only the received-principal set
changes on acknowledgment. It is neither a second writable card owner nor an
immediate-effect obligation. Do not store physical-card identity, a next
command, effect execution state, or private deck history.
Derive the required set from the immutable match control binding for the
supported mode at creation: one distinct human principal in Hot-Seat, two in
Network. Do not synthesize automated acknowledgments or silently select a
different set for an unsupported binding; STOP if that case becomes necessary.
Validate source occurrence, public snapshot, and principal binding on full
authority and passive installation; a lethal inspection **must not require**
that the card remain assigned (`DamageDeck.discard()` turns it facedown and
clears its public assignment reference). Filter only public card content
already entitled to both viewers; reject missing, stale, duplicate, wrong
principal, malformed, or cross-ship acknowledgments without mutation.

Register a purpose-specific `AcknowledgeFaceupDamageCommand` carrying the
inspection identity. Authority validates submitting player → principal using
`MatchPlayerControlBinding`, accepts one acknowledgment, and releases the
inspection only when the immutable required set is satisfied. Network's two
distinct human principals must both act; Hot-Seat's one shared principal acts
once. No timer, modal dismissal, `InteractionFlow`, passive mirror, or client
callback can acknowledge or release. Acknowledgment/release changes no card,
damage, or effect fact. While pending, command preflight blocks a still-valid
matching immediate-card resolution, next faceup deal, and unrelated enclosing
progression. It **does not delay destruction cleanup**. The lethal source
transaction marks the ship destroyed, terminates activation/Maneuver/dependent
immediate state, transfers all assigned cards through the existing ship/deck
owners, and commits any exceptional Ship Phase return before the inspection
wait. Reuse the purpose-specific operations of `DestroyUnitCommand` inside
that source transaction; do not submit a second command inside an unfinished
transaction or add generic transaction/rollback machinery. Capture whether
the ship owned the interrupted activation *before* erasing it, then commit the
resulting narrow `GameState` Ship Phase controller outcome fact atomically.
That fact identifies the player entitled to the next Ship Phase decision after
the exceptional termination. Relevant existing turn transitions maintain it;
projection reads it,
and recovery does not infer it from `InteractionFlow` or destroyed activation
history. Reject any new stable destroyed-but-not-cleaned state. ADR-006 §3.5
and ADR-014 §2.3–2.4 remain unchanged.

After release, the surviving Attack owner, Maneuver owner (if still alive),
debug/immediate source, or exceptional phase-return boundary re-derives its
next legal action from canonical state; acknowledgment never executes the
effect. A destroyed Maneuver/immediate parent never resumes. Attack defender
destruction need not retire `CurrentAttackState`: applicable terminal Attack
cleanup still follows. Attack completed-result inspection arises only after
this card inspection and any still-valid immediate effect finish; neither
inspection substitutes for the other.

If an accepted source currently deals several faceup cards in one transaction,
make it obey the Owner's deal → inspect → effect → next-card order through its
existing source boundary. Do not install a list/queue of pending cards. STOP
if doing so requires a new generic transaction, continuation, or damage owner.

**Ship-destruction producer inventory (F2).** The current
`CommandProcessor._capture_destruction_candidates` names these semantic
transactions; audit their candidate/legacy implementations and passive
applications together. `DestroyUnitCommand` currently performs later cleanup
but does **not** produce destruction. Under B1, each producer that makes a
ship newly destroyed must perform its purpose-specific card cleanup and
exceptional return in that accepted source transaction, regardless of whether
the ship carries any cards. Terminal elimination is evaluated only from the
complete post-transaction state. No inspection is invented for a producer
that dealt no new faceup card.

| Producer group | Existing command types / required F2 boundary |
| --- | --- |
| Attack and collision damage | `resolve_damage`, `overlap_damage`, `resolve_ship_collision_damage`: clean every newly destroyed ship, including both sides of mutual collision, before post-state elimination detection. |
| Obstacle and damage-card effects | `resolve_asteroid_overlap`, `resolve_debris_overlap`, `resolve_thruster_fissure`, `resolve_damaged_controls`, `resolve_ruptured_engine`, `resolve_immediate_effect`: clean and return in the lethal source transaction; terminate invalid nested Maneuver/immediate facts. |
| Other accepted damage | `persistent_effect_damage`, `debug_deal_damage`: apply the same destruction/card-transfer rule at their existing owner boundary, without inventing a gameplay parent for debug. |
| Out-of-play Maneuver, **without damage** | `apply_maneuver_transform`: once the final transform proves the ship outside the play area, capture interrupted activation before `mark_destroyed()`, atomically terminate it and its Maneuver, transfer any already assigned cards, commit the narrow Ship Phase controller outcome, then test fleet elimination. A healthy zero-card ship still requires exceptional return and terminal detection; a card-carrying ship also requires physical card transfer/public discard. No new UX-006 inspection is created. |

For every row, passive application must install the same cleaned destruction,
public discard and controller facts from the changed owning result atomically;
save/load/reconnect must restore that post-state without queued
`DestroyUnitCommand` follow-up. Reject a stable destroyed-but-not-cleaned ship,
including the zero-card out-of-play case with missing exceptional return.

### 4.2 Obstacle pre-effect occurrence — UX-008

The active `ShipInstance` Maneuver execution owns at most one purpose-specific
pending *obstacle pre-effect acknowledgment*. It is established after the
authoritative obstacle order (including a single obstacle's automatic order)
and before that occurrence's consequence mutates gameplay. Identity binds
ship activation, Maneuver execution, ordered occurrence ordinal, canonical
obstacle ID, and the specific upcoming effect/rule; a new effect of the same
obstacle receives a new occurrence identity. The required/received principal
sets have the same match-binding semantics as Section 4.1 but are separate
facts and a separate `AcknowledgeObstaclePreEffectCommand` with exact payload.
The context shown to both peers derives the obstacle name/type, overlap, and
upcoming effect from canonical obstacle/rule information, never from label
text submitted as an ID.

`CommitManeuverObstacleOrderCommand` and the existing Maneuver/obstacle
transition open the next occurrence's pre-effect record, not its consequence.
`ManeuverExecutionEvaluator` projects the pending notice or waiting state
instead of an effect action. Authority rejects the effect command until both
Network principals (or the one Hot-Seat principal) acknowledge. The last
acknowledgment releases only this occurrence's gate; the existing Maneuver
owner re-derives and executes/offers its previously legal consequence. The
effect then completes, including any independent UX-006 faceup inspection and
immediate effect, before opening the next occurrence. Existing obstacle-order
and consequence commands retain legality, controller, and mutation ownership.
No UI-local acknowledgment, automatic passive follow-up, or generic pending
work record may advance the Maneuver.

An occurrence has distinguishable canonical **announced / awaiting principals**
and **acknowledged / awaiting consequence** representations under the same
Maneuver owner. The last acknowledgment leaves a recoverable, satisfied
occurrence until its existing effect transaction consumes it. A failed effect
transaction leaves that occurrence unchanged; it neither reopens the notice
nor asks for another acknowledgment. Load/reconnect after the last
acknowledgment derives the consequence from that record, not a queued callback.
The closed `ManeuverConsequenceProjection` replacement validator must recognize
and validate both representations and every producing/consuming transaction.

**Non-immediate asteroid release (F1).** Production currently marks an
asteroid resolved and calls `ObstacleOverlapAuthority.open_next_purpose_resolution`
inside `resolve_asteroid_overlap` when its dealt faceup card has no immediate
obligation. There is **no existing separate obstacle-completion transaction**
to invoke after UX-006 inspection. Extend the existing `ShipInstance` active
Maneuver/asteroid resolution boundary with one closed, purpose-specific
*dealt-card/obstacle-completion-outstanding* state: matching ship activation,
Maneuver execution, ordered obstacle occurrence/ID, UX-006 inspection ID, and
whether that inspection has released. It stores no card identity, damage
effect, next route, or generic continuation. The asteroid deal transaction
opens this record without marking the obstacle resolved or opening the next
one. The last matching UX-006 acknowledgment atomically records release on
this Maneuver-owned record while only releasing the inspection gate; it does
not complete the obstacle or mutate damage. Before release, completion is
illegal. After release, a new purpose-specific
`CompleteAsteroidOverlapCommand` validates the exact live Maneuver/occurrence
and released inspection, then atomically consumes the outstanding record,
marks that obstacle resolved through the existing `GameState` operation, and
opens the next ordered purpose resolution through the existing authority.
The command has no damage or card effect. A rejected/failed completion leaves
the released record unchanged, so load/reconnect can rederive the same
command without re-acknowledgment; passive application validates the entire
replacement before mutation. The immediate-card branch retains its existing
`ResolveImmediateEffectCommand` completion after UX-006 release; lethal
destruction terminates the Maneuver record instead. No presentation callback
performs either completion.

| Existing source/transition | Transaction and recoverable release |
| --- | --- |
| Attack faceup deal; other accepted deal sources, including debug | The dealing transaction creates one UX-006 snapshot. Its surviving Attack, rule, or debug owner re-evaluates after last acknowledgment; a non-immediate card then permits that owner to proceed to the next card/consequence. The next deal is a new accepted transaction, never a modal callback. |
| Faceup immediate effect | After UX-006 release, the existing immediate-effect command consumes its matching obligation. If it destroys the ship, destruction/card cleanup is atomic in this transaction; otherwise its source owner re-evaluates. Failure leaves the released inspection/source obligation recoverable without re-acknowledgment. |
| Obstacle order and pre-effect notice | `CommitManeuverObstacleOrderCommand` or the existing automatic-order transition opens the first occurrence. Last acknowledgment leaves it satisfied; the matching obstacle command consumes it while mutating its consequence. |
| Asteroid, debris, and station consequence | The applicable obstacle command or immediate-effect completion opens the next ordered occurrence only after the prior effect and any UX-006 inspection/immediate chain finish. For a surviving non-immediate asteroid, the new `CompleteAsteroidOverlapCommand` consumes the released Maneuver-owned outstanding-completion record, marks the asteroid resolved, and calls existing `open_next_purpose_resolution`; a lethal asteroid commits exceptional return and opens none. Repeated IDs/types still receive distinct ordinals. |
| Destroyed active ship | The lethal source transaction terminates Maneuver and its obstacle occurrence, performs card cleanup, and commits the phase-controller outcome. UX-006 inspection survives as a GameState snapshot; release reaches phase re-evaluation or terminal completion, never the terminated Maneuver. |

Every row requires accepted command history and canonical snapshots across
save/load/reconnect immediately after the last acknowledgment and before the
next consequence. No presentation callback or passive peer may synthesize an
effect, next occurrence, cleanup, acknowledgment, or return.

### 4.3 Terminal match result — UX-010

Separate **terminal-condition detection** from **terminal-result installation**.
After each complete accepted damage transaction, evaluate permanent destruction
of *both* fleets from canonical post-state; a mutual lethal collision is
classified only after both damage/destruction/cleanup results commit. Round
limit detection requires final Status cleanup and all existing unresolved
ready-cost choices to finish; neither round number nor STATUS phase alone is
proof. A narrow round-specific `GameState` Status-cleanup-complete fact is
committed when the existing Status cleanup transaction runs and restored on
load; completion also validates that the round's ready-cost choices are
resolved. It replaces reliance on
`InteractionFlow.payload.status_phase_cleanup_complete` for authoritative
completion. Detection needs no generic `ENDING` state or terminal-work list.

Detection immediately closes **ordinary gameplay admission**. Before result
installation, authority admits only specifically applicable UX-006 and
ADR-007 acknowledgments, still-valid matching immediate-effect resolution,
Attack terminal cleanup/`CompleteAttackCommand`, remaining final-Status
obligations, and `CompleteMatchCommand`. It does not admit another ordinary
Attack, Move, obstacle consequence, activation, phase, or later Maneuver
consequence of a surviving ship after a collision eliminates the opponent.
Never resurrect an immediate obligation terminated by destruction or fabricate
normal completion/Skip to drain leftover turn facts. Reconnect installs the
canonical facts before applying this admission rule.

Add one immutable `GameState` terminal match result installed exactly once by
an authority-only, purpose-specific `CompleteMatchCommand` only after the
initiating lethal transaction's cleanup, all outstanding UX-006 acknowledgment,
any still-valid matching immediate effect, applicable Attack terminal cleanup,
all required completed-attack acknowledgment, and (for round limit) final
Status obligations. The command derives and validates reason, winner, scores,
round, and stable terminal identity from authoritative `GameState` and
`ScoringCalculator`; callers do not submit a winning player or independently
decide outcome. When a matching satisfied completed-attack inspection exists,
this terminal transaction is its context-specific release consumer: it
validates and consumes that inspection atomically with result installation.
Failure leaves both inspection and result unchanged, with no second
acknowledgment. Normal post-attack branches offering another attack or Rogue
Move are inapplicable after terminal detection. This follows the narrow
accepted ADR-007/CON-007 amendments; BOUNDARY-003 and XO-002 remain substantive
gates, not waivers. Reject premature/duplicate completion and subsequent
gameplay commands. Remaining turn/opportunity facts cannot authorize play
after the result. `CommandProcessor` selects eligible transitions at its
existing live-authority seam and owns no workflow. `GameManager.end_game`
becomes projection and replay/save orchestration, not a second outcome owner.
Network result application carries the same validated public terminal record
to both peers; clients install/project it and never rescore to establish a
result. Hot-Seat derives winner orientation and `VICTORY` from it; each Network
viewer derives `VICTORY` or `DEFEAT` from its player identity. The two-second
timer gates only the Result screen, not terminal mutation, command history, or
Network synchronization. Rebuild/load/reconnect may restart the visual delay
from the terminal result; they must never recreate match completion.

| Path | Required authoritative order |
| --- | --- |
| Faceup assignment itself kills | One transaction deals, captures UX-006 public evidence, destroys/cleans ship and commits exceptional return → faceup acknowledgments → applicable Attack completion → completed-attack acknowledgments → terminal release/result. |
| Nonlethal assignment, lethal immediate | Deal and inspect → valid immediate-effect command destroys/cleans ship atomically → applicable Attack completion and completed-attack acknowledgment → terminal release/result. Structural Damage's extra facedown card creates no second UX-006 inspection. |
| Lethal asteroid without Attack | Obstacle pre-effect acknowledgment → lethal assignment/cleanup/exceptional return → faceup acknowledgment → terminal result if eliminated. No later obstacle or destroyed Maneuver runs. |
| Mutual lethal collision | Both damage/destruction/cleanup results commit in the collision transaction → terminal result. Do not invent faceup or completed-attack inspection. |
| Final round without elimination | Final Status cleanup → existing ready-cost decisions finish → round-specific canonical completion proof → terminal result. |

Recovery never reconstructs cleanup, acknowledgment, or exceptional return from
history. A faceup inspection may outlive its destroyed source as public
occurrence evidence; the same Attack's completed inspection never precedes its
faceup/immediate chain. Permanent destruction and round-specific Status proof
remain the terminal condition sources; the result is a separate one-time
installation. No ordinary parent gameplay is required after detection.

### 4.4 Precommit squadron intent — UX-011

Before acceptance of `ActivateSquadronCommand`, selected token, range overlay,
and chosen prospective Move/Attack/Skip intent are disposable local
presentation/interaction facts. Neither `SquadronInstance`, commanding
`ShipInstance`, `GameState`, `InteractionFlow`, nor the opponent's Network view
changes when candidates are inspected. Use the same authoritative range,
engagement, action, phase/controller, and Squadron Command capacity logic as
`ActivateSquadronCommand`/existing action commands to *derive* prospective
controls; final legality remains at command validation. In particular,
engaged-squadron Skip remains unavailable where current authoritative rules
prohibit it. Discovery found the modal's `SM-012` engaged-Skip guard, but
`SkipAttackCommand._validate_declaration_skip` does not itself test engagement.
The implementation must close that narrow canonical validation gap using the
existing authoritative engagement/keyword logic, so a direct or Network
command cannot bypass the unchanged gameplay restriction; reject atomically.
A legal intent requests the existing activation command and waits
for acceptance. On rejection, discard intent and restore candidate inspection;
no action command, activation, or capacity change occurs. On acceptance,
resume only that selected intent through the existing Move/Attack or legal
Skip/Move-decline/completion transactions. The UX-011 **whole-activation Skip
intent** must consume the full activation and mark `activated_this_round`;
any still-available action is declined through its already accepted semantic
command, never inferred from a modal close. It differs from CON-006 §11.2
declaration `SkipAttackCommand`, which may preserve a Rogue or commanded
squadron's independent Move. Reuse the existing command composition, not a
new Skip rule. A rejected action **after accepted activation** does not refund
that committed activation or Squadron Command capacity; recover the still-live
action from its canonical owner. Canceling a Move preview after accepted
activation likewise does not undo canonical activation.
While committed, do not offer another squadron until canonical
completion. Save/load/reconnect discard precommit selection/intent and
rederive candidates; replay records only accepted commands.

### 4.5 New command boundaries

| Command | Exact semantic input | Accepted mutation/result; rejection |
| --- | --- | --- |
| `AcknowledgeFaceupDamageCommand` | One public `inspection_id`; submitting `player_index` is mapped to a required match principal by authority. | Add that principal once; result reports identity, principal, and whether the inspection released. Last required acknowledgment releases only the faceup gate and, for F1's matching surviving asteroid, records that release on its Maneuver-owned outstanding-completion fact; it does not complete the obstacle. Wrong/stale/duplicate principal or identity rejects atomically. |
| `AcknowledgeObstaclePreEffectCommand` | One public `occurrence_id`; authority maps submitting `player_index` to a required match principal. | Add that principal once; result reports identity, principal, and release. Last acknowledgment clears only that occurrence's pre-effect gate. Wrong/stale/duplicate principal or identity rejects atomically. |
| `CompleteAsteroidOverlapCommand` (F1) | Exact surviving owner/ship, ship-activation, Maneuver-execution, ordered obstacle/occurrence, and released UX-006 inspection identities; selected authority-side after the non-immediate asteroid acknowledgment. | Validate the matching Maneuver-owned dealt-card/completion-outstanding record, then atomically clear it, mark the obstacle resolved, and open the next ordered purpose resolution. Failure preserves the released record; client invention, stale/duplicate identity, pending inspection, or destroyed Maneuver rejects without mutation. New purpose-specific application result, version **1**. |
| `CompleteMatchCommand` | Empty semantic payload; authority-only submission at a canonically provable terminal condition. | Compute and install exactly one public terminal result; atomically consume a matching satisfied completed-attack inspection if present, and return both changes for exact passive application. A client submission, caller-supplied winner/reason/scores, unsatisfied/mismatched inspection, premature completion, or duplicate completion rejects atomically. |

These are separate commands and exact schemas, not instances of one generic
acknowledgment or continuation command. A released gate only lets its already
existing purpose owner re-evaluate the next action; an acknowledgment command
does not execute a card effect or obstacle consequence. F1's last faceup
acknowledgment may atomically mark the matching Maneuver record released, but
only `CompleteAsteroidOverlapCommand` performs non-immediate asteroid
completion.

## 5. Ordered implementation slices

Entry gate for *all* slices: the independently verified F1/F2 refinements,
the accepted narrow ADR-007/CON-007 terminal-release amendments and
CON-007-SQMOVE-008 replacement, and Owner acceptance of this workbook. The
following order reflects actual production dependencies; no slice authorizes
another architecture or gameplay rule.

1. **UX-006 lifecycle and source inventory.** Enumerate every production
   command that assigns a newly faceup card (attack, asteroid, debug, other
   rule/effect sources). Add the Section 4.1 record, acknowledgment command,
   validation, registration/applicability, preflight, serialization, filtered
   projection, and passive accepted-result installation. Each source installs
   the record in its accepted deal transaction and defers its existing
   immediate/next-card follow-up until release. In lethal sources, reuse the
   existing destruction cleanup operations **within that source transaction**,
   commit the narrow `GameState` exceptional Ship Phase controller outcome,
   and preserve the public inspection snapshot after card transfer. Inventory
   every F2 ship-destruction producer in §4.1, including zero-card
   `apply_maneuver_transform` out-of-play destruction; update each producer's
   own atomic cleanup/result boundary. Attack completion remains a separate
   subsequent ADR-007 boundary.
2. **UX-008 obstacle sequence.** Add the Section 4.2 occurrence in the
   existing Maneuver/obstacle owner, its acknowledgment command, evaluator
   projection, command gate, state/result application, and recovery. Check
   first, repeated, and final occurrences; an asteroid faceup consequence
   enters Slice 1 before its immediate effect. Preserve single-obstacle and
   multi-obstacle order validation and all owner choices. For a surviving
   non-immediate asteroid, extend the Maneuver-owned asteroid record with the
   F1 dealt/inspection-release/completion-outstanding facts and add the
   authority-selected `CompleteAsteroidOverlapCommand`; the deal transaction
   no longer marks that obstacle resolved or opens its successor before
   inspection. Register the command and its exact result/application contract.
3. **UX-010 terminal result.** Add canonical post-transaction elimination
   detection and round-specific final Status proof; gate ordinary admission
   during required cleanup/inspection. Add the Section 4.3 command/result,
   context-specific satisfied completed-inspection release, strict terminal
   validation, authority-only Network submission, public result
   envelope/application, serialization/recovery/replay, and mode-aware banner
   → two-second Result projection. Do not infer winner on the client.
4. **UX-007 token projection.** First reproduce canonical-before/after token
   state and ship-card state on the observed path. Cover ordinary spend,
   discard, and Life Support Failure; publish post-acceptance canonical token
   refresh on host and passive client at the specific missing result seam.
   Repair no token rule absent a demonstrated separate defect.
5. **UX-009 destruction cleanup projection.** Prove existing command/ledger
   transfer for faceup, facedown, mixed cards, including Slice 1's lethal
   source transactions; if correct, refresh the exact ship's damage column
   after accepted destruction and on reconstruction. Repair an actual card
   transfer defect through the existing ship/deck cleanup owner operations;
   missing card ownership is a STOP.
6. **UX-011 precommit inspection.** Under accepted CON-007-SQMOVE-008, move
   activation submission from token click to legal
   Move/Attack/Skip intent in both Squadron Phase and Squadron Command.
   Reuse authoritative legality and add the missing engaged-Skip command guard
   described in Section 4.4; hold intended action transiently until the
   existing `ActivateSquadronCommand` accepts, then use existing action and
   completion paths. Whole-activation Skip consumes all remaining legal
   action opportunities; declaration Skip retains CON-006 §11.2's independent
   Move. A rejected activation returns to reversible inspection; rejection
   after accepted activation cannot refund it or commanded capacity.
7. **UX-012 obstacle labels.** In the existing maneuver choice descriptor,
   map each canonical obstacle ID to its type/name for visible order labels.
   Keep option IDs and submitted ordered obstacle IDs unchanged, even when
   same-type options have identical text.
8. **UX-010 ordinary transitions.** Narrow `UIProjector`/`GameBoard` prompts
   to the Hot-Seat private Command Phase handoff and terminal-result banner.
   Remove ordinary Hot-Seat/Network Ship/Squadron timed banners without
   changing phase/turn commands or waiting overlays.

The already-completed dial-picker isolation repair is **not** a slice. Likely
production areas are `src/core/state/{game_state,ship_instance}.gd`,
`src/core/commands/`, `src/core/movement/maneuver_execution_evaluator.gd`,
`src/core/network/{state_filter,ui_projector}.gd`,
`src/autoload/{command_processor,network_manager,game_manager}.gd`,
`src/scenes/game_board/`, and `src/ui/{combat,ship}/`. Touch only the files
required by each proved seam; tests belong under existing focused unit,
integration, and Network acceptance areas. Under CON-003 §12, update affected
`CAP-DMG-001`–`CAP-DMG-009` and `CAP-OBS-001`–`CAP-OBS-003` Rule Capability
Packages for changed command, projection, serialization, Network/replay, and
evidence surfaces as applicable to each rule, plus engaged-Skip
validation traceability at `SkipAttackCommand._validate_declaration_skip`.
Codex may recommend readiness but must not mark any package `Integrated`.

## 6. Serialization, protocol, and replay allocation

| Surface | Required consequence and gate |
| --- | --- |
| `GameState`/`ShipInstance` save schema | Add exact, fail-closed serialize/deserialize/validation for the immutable public faceup snapshot and received principals, announced/satisfied obstacle occurrence, F1's one Maneuver-owned dealt/released/completion-outstanding asteroid record, narrow Ship Phase controller outcome, round-specific final Status proof, and terminal result. Validate principal binding, source identity, destroyed-but-cleaned state (including zero-card out-of-play destruction), and exclusivity on full authority and passive install. `SaveGameMetadata.CURRENT_VERSION` is currently **7** and must advance to **8** for these breaking state-shape additions. Define explicit migration or rejection for ambiguous older states; never infer missing destruction/exceptional-return history. No silent old-save migration. |
| Network wire | `NetworkManager.PROTOCOL_VERSION` is currently **8**; new commands and canonical result/state semantics require **9** with strict same-version handshake. Register each Section 4.5 command, including F1's authority-selected `CompleteAsteroidOverlapCommand`, with exact applicability/payload schema; update JSON integer restoration only for actual new integer payload fields. Keep the outer command-result envelope closed. Inventory every faceup-deal, next-occurrence, and F2 destruction producer. The current ship `resolve_damage`, asteroid, debug faceup-deal, and obstacle-order application contracts are each **2**; bump each actually changed shape to **3**, including F1's deal-with-outstanding-completion and F2 atomic lethal cleanup/public discards/phase outcome where produced. `apply_maneuver_transform` and `resolve_ship_collision_damage` are also currently **2**: their changed out-of-play and dual-ship lethal result shapes require **3**. Version other actually changed immediate-effect, debris/station, damage-card effect, overlap/persistent damage, completed-attack, Status-cleanup, and source contracts after inventory; do not bump unchanged shapes. New contracted acknowledgments, F1 asteroid completion, and terminal result start at **1**. Validate exact sequence/viewer/identity and all linked changes before passive mutation. Never expose authority-only deck/RNG/private card history. |
| Passive/reconnect | `StateFilter` publishes public inspection snapshot/context, F1's Maneuver outstanding-completion/release state, cleaned destruction/discard and narrow phase/Status facts, and result, never hidden physical identity. The closed `ManeuverConsequenceProjection` replacement validator must admit and validate pending/released UX-006 inspection and UX-008 obstacle shapes plus F1's dealt → released → completed asteroid transitions for order, asteroid, immediate-effect, debris/station, and terminated-Maneuver transactions. Passive accepted-result application validates the **whole** replacement before mutation, including F1 completion and F2 atomic cleanup for every producer (zero-card out-of-play included) and matching completed-inspection consumption; rejected/malformed input is atomic. Reconnect installs the authoritative snapshot before command admission and derived acknowledge/waiting/action affordances. No passive synthesis of acknowledgment, effect, obstacle progression, cleanup, activation, or match completion. `PassiveDamageLedger.SCHEMA_VERSION` remains **1** unless that ledger's own shape demonstrably changes. |
| Replay | Record faceup/obstacle acknowledgments, F1's authority-selected non-immediate asteroid completion, terminal completion, and committed squadron actions as semantic commands in authoritative order; never record transient inspection, banners, or timers. F2 lethal cleanup/exceptional return and terminal release are parts of their accepted semantic transactions, not synthesized replay events. `GameReplay.FORMAT_VERSION` is currently **10**; command additions alone do not change its header/file schema, so no automatic format bump. If a replay-file schema change proves necessary, STOP for an explicit version/compatibility allocation. Baseline trace per-record format remains unchanged. Accepted replay fixtures must not be generated, transformed, patched, relabeled, promoted, or replaced by Codex. |

## 7. Focused production-seam evidence

Deduplicate setup and assertions where issues share an existing projection
seam, but prove every canonical responsibility:

- **006:** Every identified source, including normal attack and asteroid,
  commits card assignment plus one correct public inspection identity. Both
  Network views show the same closeup; Hot-Seat one acknowledgment, Network
  either two-principal order, one insufficient, wrong/duplicate/stale rejected
  atomically. Immediate effect is absent before release and executes afterward
  through its existing command. Sequential cards/consequences and attack's
  later ADR-007 completed-result inspection stay ordered. Face-down unchanged.
  Save/load, passive filtered install, reconnect, and non-fixture replay recover
  the same pending/received state and next existing source decision. Prove
  lethal attack and asteroid deal/cleanup in one source transaction, immutable
  inspection after the card moves to facedown discard, canonical exceptional
  Ship Phase controller outcome, and no destroyed activation/Maneuver or
  immediate obligation. Cover one-principal Network reconnect, nonlethal
  assignment followed by lethal immediate effect, and Structural Damage's
  additional facedown card. Failure after the last acknowledgment retains
  recoverable source work without requiring a second acknowledgment.
- **F1 non-immediate asteroid release:** At the real
  `resolve_asteroid_overlap` → UX-006 acknowledgment →
  `CompleteAsteroidOverlapCommand` production seam, prove the deal leaves the
  same Maneuver/obstacle outstanding and opens no next occurrence; the last
  acknowledgment only records release; completion then marks the exact
  obstacle resolved and opens the next ordered consequence once. Reject early,
  wrong-identity, repeated, destroyed-Maneuver, and failed completions without
  mutation or second acknowledgment. Save/load and one-principal Network
  reconnect between release and completion must recover the exact outstanding
  command. Passive replacement must atomically validate dealt, released, and
  completed shapes and match filtered authority after each boundary. Compare
  the immediate-card branch, which still completes through its existing
  immediate command, and the lethal branch, which opens no successor.
- **008 + 012:** One mixed-type and one same-type overlap use the same
  authority/evaluator/choice setup. Prove order IDs/owner/effects unchanged;
  type labels are presentation only and match the submitted canonical order on
  Hot-Seat, Network host, and Network client. For each occurrence, command
  history and canonical snapshots prove context/ack precedes *any* effect mutation; both
  Network peers receive it and either acknowledgment order blocks until both.
  Repeated occurrence IDs differ; first effect (including UX-006 faceup and
  immediate handling) finishes before the next opens. Test rejected/stale
  occurrence and save/load/reconnect/passive/replay without duplicate effects.
  At the `ManeuverConsequenceProjection` closed replacement seam, verify both
  announced and satisfied shapes and every transaction that opens/consumes
  the next occurrence, including immediate, debris, and station resolution.
  Reconstruct immediately after the last acknowledgment, before execution;
  failed consequence leaves the satisfied occurrence recoverable.
- **010:** Test elimination, mutual destruction, and round limit at the
  authority command seam: exactly one immutable result, one accepted terminal
  history event, rejected premature/duplicate completion, blocked ordinary
  gameplay from detection and all gameplay after installation, and identical
  host/client result without client scoring. Cover each Section 4.3 ordering
  row, including mutual collision post-state, interrupted surviving Maneuver,
  pending lethal faceup inspection, still-valid versus destroyed immediate
  obligation, completed-attack acknowledgment then atomic terminal release,
  remaining Rogue Move, final Status cleanup with unresolved ready-cost choice,
  load/reconnect without callback synthesis, and duplicate terminal submission.
  Completion failure leaves a satisfied completed inspection unconsumed. Test
  Hot-Seat winner orientation/`VICTORY`, Network winner/loser text, two-second
  presentation-only Result delay, load/reconnect/replay recovery, and the
  ordinary-turn projection truth table (private Command handoff retained;
  Ship/Squadron Hot-Seat/Network banners absent).
- **F2 destruction producers:** Exercise every §4.1 producer group at its
  owning source transaction, including legacy/candidate routes where
  applicable, with one newly destroyed ship and both sides of a collision.
  For `apply_maneuver_transform`, prove a healthy **zero-card** ship outside
  the play area still atomically terminates its activation/Maneuver and commits
  exceptional Ship Phase return; repeat with assigned faceup/facedown cards
  and prove exact card transfer/public discard. Destroy the final ship in each
  relevant path and prove post-transaction elimination detection and ordinary
  admission closure. After each result compare passive filtered authority,
  then save/load/reconnect without pending `DestroyUnitCommand` or UI-derived
  return. Invalid/incomplete passive result and interrupted cleanup fail closed;
  no stable destroyed-but-not-cleaned state is accepted.
- **007 + 009:** Accepted token mutation/discard and destruction cleanup →
  canonical state → accepted-result notification → exact ship-card rerender on
  Hot-Seat, host, and client. Token display after save/load/reconnect is
  reconstructed from canonical tokens and non-fixture replay uses the existing
  token commands. For 009, faceup/facedown/mixed card identities
  leave ship and reach authority discard/public passive ledger; reconstruction
  and replay keep the same result. No UI-local deletion/mutation. Rejected or
  unchanged operations cause no false canonical change.
- **011:** Repeated precommit candidate clicks and range inspection in each
  phase/command context produce no gameplay command, activation/capacity delta,
  or opponent authoritative change. Prospective legality matches the existing
  authoritative validator, with a focused direct-command and Network rejection
  for engaged Skip that leaves activation/capacity unchanged. Each legal
  Move/Attack/Skip intent emits one activation attempt; rejection emits no
  action and consumes nothing; acceptance precedes action. Whole-activation
  Skip consumes all remaining legal action opportunities via existing commands,
  while CON-006 declaration Skip preserves Rogue/commanded independent Move.
  Rejected action after accepted activation retains consumed activation/capacity.
  Verify marks activated, same-round rejection, commanded capacity/return,
  Hot-Seat/Network host/client, save/load/reconnect, and command-only replay.
- **Baseline:** retain the full **4,338/4,338** suite and the dial-picker
  phase-validation/isolation regression; do not change that test again absent
  new evidence.

Principal-sensitive Network proof must traverse the real authenticated
endpoint → principal → submitted-player admission path in `NetworkManager`,
including impersonated-player rejection and resumed side assignments. Direct
acknowledgment-command tests and matching peer closeups alone are insufficient.
For every new public boundary, compare passive installed state with filtered
authority state after each accepted command; malformed/inapplicable result
replacement must fail atomically. Non-fixture tests may drive replay code;
accepted fixtures remain Owner-owned.

## 8. Gates, Owner manual verification, and convergence

After the entry gate in Section 5, run focused production-seam tests, Hot-Seat
and real Network acceptance, non-fixture save/load/reconnect/replay checks,
architecture/static lint, command registration/exact schema checks, authorized
file and obsolete-path checks, `git diff --check`, then the full automated
suite. Do not paper over a failure. Owner manual visual checks cover card
closeup/ordering, obstacle cause notice and labels, token/damage columns,
reversible squadron inspection, private handoff versus ordinary turn prompts,
and mode-specific terminal banners/Result delay.

STOP for Owner review if a source cannot establish sequential inspection and
atomic lethal cleanup with existing owners/transactions, if an obstacle effect mutates before
its pre-effect gate, if existing accepted legality cannot supply prospective
Squadron intent, if terminal result cannot be authority-owned and passively
installed, if private state would leak, if new compatibility policy is needed,
or if any accepted ADR/Contract beyond the accepted narrow ADR-007/CON-007
amendments must change. UI/`InteractionFlow` must never own legality, acknowledgments,
effects, activation, outcome, or continuation. The two acknowledgment records
remain separate and purpose-specific; the terminal result is not a match FSM.

Replay renewal is **required** for the accepted Hot-Seat fixture:
`replay_hot_seat_solo.json` already contains obstacle order → asteroid faceup
damage → immediate effect without UX-008/UX-006 acknowledgments. The accepted
`replay_network.json` also contains obstacle order → asteroid resolution and
a later faceup consequence without the new two-principal acknowledgments.
Before implementation, inventory both captures' exact affected paths and any
other accepted capture that traverses the new gates. No replay bypass,
automatic acknowledgment, or format bump is authorized as a workaround;
an alternative compatibility treatment requires explicit Owner acceptance.
After all Codex-owned non-fixture implementation and verification converge,
**STOP FOR OWNER REPLAY CAPTURE**. The Owner manually records required Hot-Seat
and Network histories with the actual one- and two-principal acknowledgments.
After Owner capture, validate the genuine fixtures, rerun baseline traces and
the focused/full automated convergence; report any failures without papering
them over. Codex must not create, synthesize, reconstruct, patch, transform,
relabel, promote, or replace replay fixtures.

### Audit disposition and remaining gate

The original audit's **B1** closes in this workbook through atomic lethal-source
cleanup plus immutable public inspection and canonical exceptional Ship Phase
outcome; **B2** closes through post-transaction detection, restricted admission,
ordered cleanup, final-round proof, and atomic terminal release. Its **R1**
source/recovery mapping is in §§4.1–4.3; **R2** Skip semantics are in §4.4 and
the accepted SQMOVE-008; **R3** closed passive replacement and real transport
proof are in §§6–7; **R4** concrete Owner captures and post-capture convergence
are above; **R5** Rule Capability Package updates are in §5. These dispositions
were independently verified before Owner acceptance.
No new Owner decision is identified by the accepted B1/B2 resolution path.
The focused independent re-audit verified B1/B2 and closed R2–R5 with no
blocker or remaining Owner decision; it left only R1's **F1** non-immediate
asteroid release mapping and **F2** destruction-producer coverage. F1 is
specified in §4.2, §4.5, Slice 2, and §§6–7 using the explicit
`CompleteAsteroidOverlapCommand` and Maneuver-owned outstanding fact. F2 is
specified in §4.1, Slice 1, and §§6–7 for every existing producer, including
zero-card out-of-play Maneuver destruction. Independent closure verification
preceded Owner acceptance; these refinements do not reopen the verified
boundaries.
