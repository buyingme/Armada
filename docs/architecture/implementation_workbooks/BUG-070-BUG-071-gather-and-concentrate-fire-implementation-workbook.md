# BUG-070 / BUG-071: Gather Completion and Concentrate Fire Implementation Workbook

Status: Accepted
Prior acceptance: Project Owner, 2026-10-03 (superseded for the BUG-071 UX interaction by this revision)
Owner re-acceptance: Project Owner, 2026-10-03
Date: 2026-10-03
Purpose: One coordinated implementation plan with separate issue acceptance.
Implementation authorization: Authorized within this workbook's revised scope. BUG-070,
BUG-071, and affected Rule Capability Packages remain open; no integration or
completion status is asserted.

Revision provenance: Owner Hot-Seat smoke testing exposed an inert CF `Use`
action and an ambiguous resource choice. The repository Rules Reference and
incorporated FAQ then clarified that combined dial/token spending is one
command resolution with simultaneous commitment. The subsequent
[Owner UX Resolution](../../qa/bugs/open/BUG-071/issue.md#owner-ux-resolution--2026-10-03)
selects a top-level CF Use/Decline row followed by a legal resource choice.
The former accepted top-level dial/token/both/neither presentation assumption
is superseded; the rules-correct combined commitment remains required. This
revision is documentation only and does not certify the interrupted code.

## 1. Scope and authority

Classification: **Uncertain/High-Risk Architecture for the production and
compatibility audit; bounded implementation under settled authority.** The
repair crosses canonical attack state, command ordering, timing, Network RNG,
save/load, and replay. No new architecture decision is proposed.

The controlling order is [DOCUMENT_AUTHORITY](../DOCUMENT_AUTHORITY.md),
[CON-001 §5.4](../contracts/CON-001-current-attack-state-and-semantic-transition-contract.md#L418),
[ADR-001](../adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md),
[ADR-012](../adr/ADR-012-live-network-rng-authority-and-result-application.md),
and applicable [CON-007](../contracts/CON-007-post-attack-continuation-release-contract.md).
The [BUG-070 Owner Resolution](../evidence/UX-006-UX-012-post-implementation-smoke-defect-diagnosis-2.md#L114)
settles the otherwise unspecified final-die and anti-squadron outcomes. The
[rules clarification](../evidence/BUG-070-pre-roll-empty-pool-rules-clarification.md),
[joint diagnosis](../evidence/BUG-070-BUG-071-joint-production-diagnosis.md),
and [normative traceability map](../evidence/BUG-070-BUG-071-normative-refinement-traceability.md)
are evidence and rule-package obligations. The repository [Rules Reference](../../../Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md)
and its [Commands FAQ](../../../Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md#L2253)
verify gameplay timing and combined command commitment. [Learn to Play](../../../Resources/SWM01-ARMADA-LEARN-TO-PLAY/SWM01-ARMADA-LEARN-TO-PLAY.md)
provides additional timing context; these rules do not resolve the two Owner-ruled edge
cases. The [TWI-002 reconciliation](TWI-002-timing-window-core-and-h9-pilot-implementation-workbook.md#bug-071-timing-reconciliation-2026-10-03)
supersedes its pre-roll dial instructions. [CON-003](../contracts/CON-003-rule-capability-contract.md)
and [TEST-003](../tests/TEST-003-interactive-rule-timing-window-verification.md)
govern applicable rule-package traceability and verification.

In scope: BUG-070 mandatory gather effects, valid intermediate zero, final
gather cancellation and enclosing return; BUG-071 post-roll dial addition and
existing token integration; canonical command/timing, presentation/recovery,
Hot-Seat, Network, save/load/reconnect, replay and compatibility. Keep separate
BUG-070 and BUG-071 evidence even where one test covers both.

Excluded: changing declaration/initial-range eligibility, unrelated rule
timing, Counter/Swarm/defense/damage/completed-result semantics, a generic
attack FSM or continuation owner, rollback/refunds, UI-owned legality, legacy
replay conversion, and production/test changes during this workbook-authoring
task. The
repair shall touch no unrelated active workbook or package status. Codex may
gather package evidence but cannot mark any package `Integrated`.

## 2. Reconfirmed production state

Read-only inspection of the current tree confirms the diagnosis's material
seams; the preserved diagnosis's version inventory also still matches
production at workbook acceptance (`save 8 / replay 10 / protocol 9 / application
contract 2`). Recheck these constants at the later implementation entry gate.

| Seam | Current finding | Repair implication |
| --- | --- | --- |
| `BeginAttackCommand`, `TargetingListBuilder`, `ShipInstance`/`SquadronInstance` | Begin derives a positive range/armament pool, installs `pre_roll`, and commits declaration, target history and opportunity. Counter has a separate initial-pool branch. | Keep Begin's commitment and initial eligibility. Never use future CF dice for declaration or refund a canceled attack. |
| `RuleBootstrap`/`RuleRegistry`, Point-Defense Failure, Damaged Munitions, obstruction | The registered card hooks expose one mandatory selected die removal before roll; obstruction is a separate choice. Card predicates are ship-to-squadron versus ship-to-ship. `resolved_pool_choices` and `obstruction_resolved` are canonical, while the hook's single pending-rule metadata is not a completion proof. | Derive every applicable unfinished gather obligation from canonical attack plus current rule sources, in fixed card-then-obstruction order. Account for a later obligation when the pool has temporarily become empty. |
| `ResolveAttackPoolChoiceCommand`, `CurrentAttackState`, `RollDiceCommand` | Rule removal rejects `after_count <= 0`; state validation rejects every active empty pool. Roll checks obstruction/dial/positive count but not unresolved registered card choices. | Admit intermediate empty `pre_roll`; validate the final boundary once; reject direct Roll past any unfinished gather effect; use an explicit cancellation command for final zero. |
| `SkipAttackCommand`, `GameState.deserialize`, `StateFilter`, `CurrentAttackContinuation` | Active Skip retires CurrentAttack but leaves `ATTACK` flow. Deserialization rejects that inactive/no-inspection combination; StateFilter first deserializes the full authority snapshot. The continuation helper has no cancellation-specific inactive route. No-inspection `squadron_done` does not check exhaustion or iteration identity. | Cancellation must atomically publish a valid enclosing command-produced flow and retain the narrow cancellation-return identity needed by anti-squadron termination. Existing enclosing owners, not presentation or an inspection, select follow-ups. |
| CF dial and token | At workbook acceptance, Begin marked both pending. Dial use/decline required `pre_roll`; use spent the revealed dial and incremented the unrolled pool. Token use/decline belonged to post-roll Attack Modify, but token derivation required possession, use spent it, and decline left it unspent. There was no confirmed ship-round CF resolution marker or advance dial/token/both choice. The later Owner smoke test found the projected `Use` inert and the resource source unclear. | Present one CF Use/Decline row and, after Use, only legal Dial/Token/Dial + Token choices. Spend selected resources at one command commitment; both are spent together when combined. Later effect commands consume retained authorization and never spend again. Preserve the token's reroll operation, not its old possession/spend predicates. |
| `TimingWindowOrchestrator`, `FlowSpec`, `CommandApplicability`, `ConfirmAttackDiceCommand` | Accepted Roll opens ship Attack Modify; opportunities are rederived after commands. Flow still lists dial in ATTACK_ROLL. Confirm only checks pending token, so a moved pending dial could be bypassed or automatically closed. | Gate timing continuation and Confirm on unresolved CF choice/effects; rederive token/H9 after the dial result. Move command applicability and projection to ATTACK_MODIFY. |
| `AttackExecutor`, `AttackPanelController`, `UIProjector`, `GameManager` | Scene sequences card → empty check → obstruction → dial → Roll. Automatic card submission failure is treated as handled, and rejection routing covers Begin/Skip but not pool choices. Resume repeats the old sequence. | Show canonical next action and recover from rejection without advancing scene state. Present post-roll CF and reconstruct from accepted state. |
| Save, Network, replay | `GameState` loads CurrentAttack before recovery. Exact save/replay versions reject mismatches. Network envelopes and ordered `CommandProcessor` application use command-specific result contracts; Roll and token already apply authority-resolved random results on passive peers. | Extend the existing command-owned result path for the dial; preserve passive RNG filtering and deterministic seed-plus-command replay. |

The code review found no separate production bot attack executor; direct command
consumers inherit command readiness. Target selection and the analysis
simulator share range/armament helpers, so include them as initial-eligibility
regressions, not separate CF authority. Also inspect the Roll-only
`ship_target_attack_counts` write when testing cancellation; it is distinct
from Begin's committed attack history and must retain its intended condition.

## 3. Fixed invariants and stop conditions

1. A positive initial range-appropriate pool is required for Begin. During
   `pre_roll`, zero may be represented only while gathering is unresolved or
   awaiting the explicit final-empty cancellation. No rolled/later-stage
   attack may carry an empty initial pool by accident.
2. A single canonical, deterministic gather-readiness derivation enumerates
   every applicable registered mandatory effect and obstruction, using stable
   attack/source identity and already resolved choices. It returns the next
   required action or complete status; scene stage, metadata hint, and a
   selected colour are not authority. Each effect records its own resolution
   once. An effect with no die available after a prior legal removal must
   complete as an explicit, validated no-die outcome if still applicable; it
   cannot remove a nonexistent die or silently disappear from the completion
   proof.
3. At complete gather, positive pool admits Roll; zero admits only the
   existing replayable individual cancellation transaction. An effect never
   cancels by itself. Empty final pool never opens Attack Modify or offers CF.
   One or more dice with blank results continue.
4. Cancellation retains Begin's committed attack count, zone, target/history,
   and legally spent resources. The individual target cannot be retried. Ship
   anti-squadron iteration independently derives the next eligible target or
   executes the existing child termination. No completed-damage inspection is
   created; CON-007 applies only to its defined completed-result boundary.
5. CF dial and token effects belong to post-roll ship Attack Modify. The
   [Rules Reference command and FAQ](../../../Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md#L2259)
   require choosing dial, token, or both *before* effects and spending both
   simultaneously when combined. One authoritative, replayable advance-choice
   command atomically validates and spends the selected dial/token, records
   the ship-round CF resolution marker, and retains the attack's chosen effect
   authorization. The top-level CF `Decline` maps to the internal `neither`
   outcome and records only a per-attack decline: no resource is spent and no
   round marker is set. A selected effect can be
   resolved/declined once after commitment; later effect commands spend
   nothing. A ship cannot resolve CF again that round, including a later
   anti-squadron target. A post-commit decline of the optional token reroll,
   including after spending `both`, does not refund the token or dial and is
   distinct from choosing `neither` before commitment. The same no-refund
   rule applies if a committed dial effect produces no added die. Combined
   token use may reroll the newly added die.
6. Dial addition requires a colour already in the *current* canonical pool,
   rolls one new die through authority RNG, appends its realized result, and
   updates the canonical pool/results in one command transaction. It cannot
   change a canceled gather. Token remains a reroll of an existing result.
   H9 and other shared opportunities rederive after each accepted result.
7. CurrentAttack owns only attack-specific retained CF choice/effect facts;
   ShipInstance owns the ship-round CF resolution marker and the narrow
   anti-squadron cancellation-return identity; TimingWindowState owns
   lifecycle identity. No presentation or result envelope is a second state
   owner. Retained selected-resource authorization must survive save/load and
   reconnect even though the physical resource was spent at commitment; it
   must bind the same attack, ship, round and timing lifecycle and cannot be
   reused by a later attack.

| CF resource choice after top-level `Use` (or internal `neither` after top-level `Decline`) | Atomic commitment and retained attack authorization | Later effect transition | Later attacks in same round |
| --- | --- | --- | --- |
| `dial` | Spend one revealed CF dial; mark ship's CF resolution for this round; retain dial effect pending, token unselected. | Add/roll a current-colour die or explicitly decline its effect; no later spend/refund. | No CF resolution, even if a token remains or is gained. |
| `token` | Spend one held CF token; mark the round; retain token reroll pending, dial unselected. | Reroll one legal existing result or explicitly decline the optional reroll; no later spend/refund. | No CF resolution, even if a dial remains. |
| `both` | Validate simultaneous possession, spend one revealed CF dial **and** one held CF token in one command transaction; mark the round once; retain both effects pending. | Resolve/decline dial addition, then use/decline the optional reroll; the added die may be selected for reroll. Neither later effect command spends a resource. | No CF resolution; declining the reroll does not restore the token. |
| `neither` (top-level `Decline`) | Retain this attack's pre-commit decline only; spend nothing and leave round marker unset. | No CF effect command is legal in this attack. | A later eligible attack may make a fresh advance choice. |
| New round | Existing round transition clears the ship-round CF marker; no active attack/old authorization may be carried across as a new resolution. | Re-derive future availability from current canonical resources and round. | One new CF resolution may be committed in the new round. |

The advance choice is the resource and once-per-round boundary, not the die
effect. Its failure leaves resource inventories, round marker, CurrentAttack,
RNG, timing state, history and cursor unchanged. Dial-result RNG is consumed
only by a later accepted dial-effect command. A decline after commitment
records an effect result, not a new CF resolution. Later attack retirement
cannot refund a committed CF resolution or clear its ship-round marker.

### BUG-071 player interaction (Owner smoke-test refinement)

The Owner-selected reusable convention presents each independently available
effect on its own horizontal `<Effect Name>    [Use] [Decline]` row. For
BUG-071, after a successful roll, project
`Concentrate Fire    [Use] [Decline]` as the single CF command opportunity,
rather than separate dial and token rows. Show it only when CF is legally
available. Keep it distinct from simultaneously available effects; this
workbook does not authorize refactoring ECM, H9, or other effects.
Presentation never decides legality or installs a gameplay owner, FSM, or
continuation authority.

CF `Use` opens a CF-specific choice showing only currently legal and available
`Dial`, `Token`, and `Dial + Token` options. A visible `Use` must lead to an
actionable choice and accepted authoritative command or an actionable
reprojection after rejection; it must not be inert. Opening this submenu is
transient presentation only: the `Use` click does not submit a command,
establish authoritative gameplay state, or persist a menu-open flag. If
save/load or reconnect occurs before a resource choice is submitted, discard
the submenu and rederive the authoritative CF opportunity. Project the
top-level `Concentrate Fire    [Use] [Decline]` row again; another `Use` click
derives the currently legal resource choices afresh. The authoritative
recovery boundary begins with the submitted resource choice. CF `Decline`
records the internal `neither` outcome without spending or setting the round
marker. A resource option commits one CF command resolution. `Dial + Token` validates
and spends both simultaneously, then resolves the dial effect first (legal
current-pool colour, authority roll, added result) and the optional token
effect second (eligible die selection, authority reroll or explicit decline).
The added die may be rerolled. Declining that reroll never refunds the spent
token. After each accepted effect result or decline, rederive the enclosing
Attack Modify interaction and remaining legal effects from canonical state.
After authoritative resource commitment, recovery and passive projection
reconstruct the committed choice or pending effect from accepted state,
including a partially resolved Dial + Token, without creating a second CF
resolution.

STOP for Owner direction if implementation reveals an accepted-authority
conflict, another unaccounted mandatory gather effect or post-roll blocker
whose coexistence cannot be derived from the accepted contracts, or a required
new architecture owner/pattern. A changed numeric version or exact command
schema under the established compatibility authorities is mechanical and is
not itself a stop. Stop at the manual replay-capture gate in §7, not at a
speculative compatibility question.

## 4. Smallest ordered production slices

### A. Canonical Gather completion — BUG-070

1. Add a narrow, pure gather-obligation/readiness helper at the existing
   attack-command/rule boundary. It derives applicable card removals and
   obstruction from canonical attacker, defender, attack identity, registry
   hooks, resolved choices, and pool. Do not persist a duplicate readiness
   flag or rely on the one pending-rule UI hint. Keep fixed, inspectable
   ordering and fail closed on unknown or inconsistent applicable hooks.
2. Relax `CurrentAttackState` validation only for valid `pre_roll` empty state;
   retain strict later-stage and serialized-state checks. Permit final-die
   removal in `ResolveAttackPoolChoiceCommand`; validate exact effect identity,
   selected available colour, one removal, and no-die resolution only when the
   prior effects have legally emptied the pool. Make duplicate/reordered
   choices fail without mutation.
3. Make `RollDiceCommand` require the complete positive gather predicate.
   Make active `SkipAttackCommand(reason="cancelled")` require complete empty
   gather for this production route, with matching attack/controller identity
   and no timing lifecycle. Preserve its terminal cleanup and all Begin
   commitments. If an existing non-gather cancellation caller needs the broad
   reason, keep that separate under its existing identity instead of weakening
   gather cancellation admission.
4. Drive automatic choice, final-empty cancellation, and post-cancel Ship or
   Squadron return from accepted command outcomes. Re-evaluate remaining
   anti-squadron targets via authoritative ship history/zone and issue the
   existing `squadron_done` transaction on exhaustion. Cover first and later
   targets and the final callback's next usable decision.
   In the same `SkipAttackCommand(reason="cancelled")` transaction that retires
   CurrentAttack, replace stale `ATTACK` flow with the applicable valid
   command-produced enclosing flow: `SHIP_ACTIVATION/ATTACK_STEP` for ship
   attacks, `SQUADRON_ACTIVATION/ACTION_CHOICE` for Squadron Phase, or
   `SHIP_ACTIVATION/SQUADRON_STEP` for a commanded squadron. Carry the existing
   ship/squadron activation identities and controller; do not manufacture a
   completed-result inspection. The active ship/squadron owner remains the
   source of next-decision legality. Use the existing
   `GameBoard._resume_active_attack_from_state`,
   `AttackExecutor.resume_inactive_ship_attack_continuation`, and
   `GameBoard._restore_declaration_adjacent_projection` routes, with only the
   bounded cancellation return/reconstruction change needed to consume the
   new valid state. Extend `CurrentAttackContinuation`'s purpose-specific
   command follow-up/reconstructed-return derivation for no-inspection
   cancellation: remaining Step 6 target is a derived decision; exhausted
   Step 6 uses `squadron_done`; exhausted Ship Attack uses its existing
   `AdvanceActivationStepCommand`; Squadron Phase and commanded squadrons use
   their existing action-completion/Move or enclosing ship-command route.
   Replay/passive peers apply only recorded semantic follow-ups.
5. For the no-inspection `squadron_done` route, cancellation records a narrow
   pending return identity on the authoritative ship: canceled attack id,
   ship activation identity, and current anti-squadron iteration identity
   (committed attack ordinal plus locked zone). Admit the child-finish command
   only when those payload identities match the current pending return, the
   attacker/controller and active Ship Attack owner still match, CurrentAttack
   and completed inspection are absent, and
   `TargetingListBuilder.authoritative_ship_target_entries` plus the ship's
   committed target history prove no eligible Step 6 target remains. Clear
   the marker atomically on accepted `squadron_done`, replacement Begin, or
   termination of that iteration; preserve it across reconstruction until
   one of those accepted transitions. Never infer exhaustion from a scene
   target list or `attacked_squads`. Premature, stale, duplicate, reordered,
   wrong-controller, and later-iteration reuse must reject atomically.

### B. CF resolution at Resolve Attack Effects — BUG-071

6. At the successful Roll → Attack Modify boundary, derive CF availability
   from the attacking ship's canonical resources and round-use state. Begin
   must no longer install an unresolved CF choice in `pre_roll`, and Roll must
   not wait for or spend a CF dial. Project one authoritative CF Use/Decline
   row. `Use` opens a purpose-specific resource selection containing only
   legal `Dial`, `Token`, and `Dial + Token` options; `Decline` maps to the
   attack-local `neither` outcome. Add one purpose-specific, replayable CF
   choice command. On `dial`, `token` or `both`, it atomically validates and
   spends the selected resource(s), sets the ship-round marker, and installs
   bound per-attack effect authorization; on `neither`, it records only the
   attack-local decline. Combined resources are spent together in one
   command resolution, never through separate dial and token resolutions.
   Snapshot and restore all affected owners on failure. A pending advance
   choice is a blocking shared-window opportunity even without token or H9.
   Reset only the ship-round marker at the existing round boundary. Validate
   attack, ship activation, round, timing lifecycle, controller and resource
   identity; no generic command framework or second registry. A projected
   `Use` must reach its resource choice and submit the chosen legal command;
   rejection must reproject an actionable current choice.
7. Move dial effect use/decline to the matching open Attack Modify lifecycle.
   Validate selected colour against the post-roll canonical pool and retained
   *spent-dial authorization*, not current dial possession. On use, atomically
   advance RNG by one die, append its result and update canonical pool/results
   and effect status; restore state/RNG on failure. On post-commit decline,
   record no addition and no refund. The real dial command must define a
   strict authority-result application contract for its viewer-authorized
   face and binding to selected colour/attack/timing identity. A passive peer
   validates and applies that result without RNG; replay reexecutes the same
   semantic command and roll from its seed. No live result is saved in history.
8. Keep the token's existing reroll operation and result contract, but change
   its opportunity and use/decline guards to require retained *spent-token
   authorization* for this attack instead of token possession. Remove the
   token spend from reroll execution; post-commit decline still leaves it
   spent. For `both`, complete/decline dial effect before the optional token
   reroll, which may target the newly added die. Rederive the enclosing Attack
   Modify rows, including token follow-up and H9, after dial and token results
   or declines. Keep timing status open while selected CF effects
   remain unresolved; prevent `ConfirmAttackDiceCommand` and automatic
   continuation until all selected CF and other blocking opportunities are
   settled. Preserve H9/Swarm ordering and ordinary confirmation.

### C. Routing, recovery, and compatibility assembly — both bugs

9. Update `FlowSpec`, `CommandApplicability`, command registration/exact
   payload declarations, `GameManager` submitters, `UIProjector`, and
   `AttackPanelController` only as required by the new/relocated commands.
   Remove the pre-roll dial offer and scene-owned empty decision from
   `AttackExecutor`; render the derived gather next action, the single post-roll
   CF Use/Decline row, and the legal CF resource choice after `Use`. Keep
   the CF row distinct from simultaneous opportunities without using row
   presentation as legality or changing unrelated effects. On local or
   Network rejection, restore an actionable projection
   from canonical state without auto-claiming success or retrying stale input.
10. Reconstruct `pre_roll` (including temporary/final zero), the *raw* valid
    post-cancellation enclosing flow before any scene callback, and
    open/closing Attack Modify from canonical `GameState`, ShipInstance and
    timing lifecycle. Before a CF resource choice is submitted, recovery
    projects the authoritative top-level CF row and discards any transient
    submenu opened by `Use`; reopening it derives current legal options.
    After accepted submission, reconstruct committed CF choice before effects,
    partial `both` after dial but before reroll, and post-dial result from
    authoritative state. The unmodified command-produced
    snapshot must deserialize, pass `StateFilter`/passive installation and
    project through real board recovery without a test clearing or replacing
    `interaction_flow`. No replay or passive peer may synthesize cancellation,
    choice, `squadron_done`, or a CF random result from presentation.
11. Activate the single §6 compatibility cutover only when all new state,
    command, result, install/recovery, and rejection paths are complete.
    Retire stale pre-roll dial command assumptions and update affected tests,
    coverage inventories and CON-003 package traceability. Keep separate
    package status; request Owner `Integrated` approval only after evidence.

## 5. Verification matrix and convergence

The following is the **minimum nonredundant acceptance allocation** under
TEST-003. Unit fixtures may construct isolated state to test predicates.
Production integration, recovery, distributed, and replay cases must reach the
state/outcome under test through the real submitted command chain and, where
listed, real board/panel orchestration. They may arrange an initial legal
game/scenario; they may not directly install Attack Modify, manually open its
timing window, insert dice results, commit attack history, clear a stale flow,
or reconstruct the cancellation/CF outcome they claim to verify. The existing
`test_concentrate_fire_shared_protocol.gd` fabricated Modify setup,
`test_current_attack_production_resume.gd` direct pre-roll setup, and
`tests/acceptance/network_resume/driver.gd` direct Roll with CF unavailable
remain useful for their original scope, but do **not** satisfy these gates.

| Level / suites to extend | Separate BUG-070 evidence | Separate BUG-071 evidence |
| --- | --- | --- |
| Unit: `test_current_attack_state.gd`, `test_attack_commands.gd`, `test_concentrate_fire_timing_window.gd`, `test_rule_point_defense_failure.gd`, `test_rule_damaged_munitions.gd` | Gather derivation/order/no-die outcome; valid temporary zero and invalid later zero; direct Roll or early cancellation rejected; exact choice identity and atomic failure. | Table in §3 for internal dial/token/both/neither outcomes, with `neither` mapped from top-level Decline; legal resource filtering, combined simultaneous spend, post-commit reroll decline/no refund, later attack and round reset; current-colour and spent-authorization guards; result schema and rollback. |
| Production integration: extend `test_current_attack_production_resume.gd` and `test_current_attack_shared_protocol.gd` with real `GameBoard`/`AttackExecutor`/`GameManager` submission and callbacks | Actual Begin → Point-Defense Failure, Damaged Munitions, obstruction, and applicable card+obstruction sequencing; temporary/final zero; first/later anti-squadron target with remaining/exhausted targets; count/zone/history/no retry; usable Ship, Squadron Phase and commanded-squadron return. Include automatic one-colour submission rejection and actionable reprojection. Do not invent simultaneous applicability of the two card predicates. | Actual Begin → complete Gather → Roll → one visible `Concentrate Fire [Use] [Decline]` row when CF is legal; `Use` opens only legal Dial/Token/Dial + Token options and submits the chosen authoritative command, while `Decline` spends nothing and opens no resource choice. Cover dial-only, token-only, combined and no-resource states (no CF row when unavailable); combined simultaneous spend, authority-rolled added result, then optional post-spend reroll use/decline including added die and no refund. Keep CF distinct from simultaneous other effects, rederive H9/remaining opportunities, block Confirm until settled, and cover spending and round reset. Detect inert `Use` and recover actionable UI after rejection. Do not replace this with the shared-protocol test's manually opened window. |
| Recovery integration: extend `test_current_attack_production_resume.gd` and `test_current_attack_shared_protocol.gd` | Capture the raw accepted cancellation state immediately after real command submission with follow-up drain deferred, before scene callbacks/follow-ups. Serialize/deserialize it unchanged, pass `StateFilter.filter_for_player_checked`, install the authority/passive state through `GameManager.start_new_game_from_state` and the existing passive installer, reconcile timing, recreate `GameBoard` through `_ready`, and project the next action. Cover temporary/final zero and Ship/Phase/commanded return, then execute the next legal command. | After real accepted Roll, click top-level CF `Use` but submit no resource choice; serialize/deserialize the unchanged canonical attack state at that boundary and exercise authority load/passive installation and Network reconnect. Assert the opened submenu is neither persisted nor reconstructed, no choice command/history/resource/round-marker change occurred, and recovery projects the top-level `Concentrate Fire [Use] [Decline]` row. Click `Use` again and assert legal Dial/Token/Dial + Token options are freshly derived. Use canonical active-state reconstruction for this save/load case; do not widen the named-save UI safe-point gate. Separately repeat recovery for a submitted/committed choice before effects, partial `both` after dial/before reroll, and settled result. Preserve exact resource/marker/result and next legal interaction across authority reconstruction and reconnect; do not reoffer a spent resource or create a second CF resolution. |
| Distributed integration: extend `test_current_attack_shared_protocol.gd`, `test_concentrate_fire_shared_protocol.gd`, and the two-process Network acceptance driver with a real Begin-based scenario | Both attacker roles and relevant side assignments; actual submit/result routing, filtered cancellation, Step 6 child finish, disconnect/reconnect and peer convergence. | Both attacker roles; actual CF row → Use → legal resource selection → choice/dial command routing and viewer result, RNG-free passive application, token decline after combined spend, disconnect/reconnect and peer convergence. Include Decline and rejected/stale selection reprojection. One representative colour per distributed path suffices; unit/integration covers permutations. |
| Replay: extend `test_current_attack_shared_protocol.gd`'s driver-compatible test and `test_replay_driver.gd` | Record actual accepted Begin/gather/choice/cancellation/child-termination history; `GameReplay` creation → JSON encode/decode → `GameReplay.deserialize` → `GameCommand.deserialize` factory → `ReplayDriver`; assert each intermediate owner/flow state and exact order, with no synthesized follow-up. | Same production chain through choice, dial RNG, optional token action/decline, H9/Confirm; assert intermediate RNG state/next draw and command order as well as final dice; no transported live result in replay. |
| Manual Hot-Seat/Network smoke and Owner fixture capture | Real control visibility, auto-choice rejection recovery, cancellation and subsequent target/enclosing decision. | Confirm one CF row with working Use/Decline; Use reveals only legal Dial/Token/Dial + Token choices and each visible choice submits successfully. Check combined spend before effects, dial colour/authority result, eligible token reroll or decline without refund, rederived Attack Modify/H9/Confirm, handoff and reconnect. Confirm CF remains distinct from simultaneously available effects without refactoring them in BUG-071. Owner records §7 fixtures only after candidate code passes non-fixture gates. |

For the real CF dial application command, extend
`test_result_application_contract.gd` and
`test_network_command_result_ordering.gd` rather than relying on their fixture
command/AssignDial cases. Test missing/malformed result, illegal face or
colour, wrong contract id/version, wrong viewer, attack/ship/round/lifecycle
context, duplicate, stale and reordered delivery. With passive RNG absent,
valid authority results apply exactly once without advancing it. Every
rejection preserves filtered canonical state, dial/token resources, CF marker,
command history, processor and Network delivery cursors, queued follow-ups,
and success presentation; a later result cannot skip the failed sequence.
Reconnect from a fresh filtered authority snapshot recovers the next valid
result without rerolling or double spending. Verify both attacker roles.

For no-inspection `squadron_done`, extend the existing inspection-bearing
remaining-target test in `test_current_attack_production_resume.gd` and the
`test_attack_commands.gd` command guards. Submit premature, stale,
duplicate, reordered and wrong-controller finishes, including an earlier
iteration's command after a later iteration of the same ship begins. Assert
the pending cancellation-return identity and all other canonical state,
history, cursor and presentation remain unchanged on rejection.

Keep explicit non-regression mapping in `test_current_attack_production_resume.gd`:
completed-result inspection and both acknowledgement orders (`test_real_game_board_anti_squadron_result_waits_for_acknowledgement`,
`test_network_host_remaining_result_acknowledges_once_and_tears_down_projection`),
faceup/immediate effects (`test_immediate_critical_resolves_before_complete_attack_without_hidden_result`,
`test_bug043_r3_resolved_attack_rebuilds_pending_immediate_choice`), enclosing
Ship Attack (`test_post_ack_anti_squadron_exhaustion_recovers_normal_ship_attack`,
`test_post_ack_anti_squadron_exhaustion_advances_to_maneuver_once`), and
terminal progression (`test_phase_squadron_acknowledgement_uses_existing_terminal_phase_path`,
`test_live_authority_resume_drains_one_deterministic_terminal_chain`).
Also retain BUG-031/BUG-035, H9, Swarm, Counter, normal attack, blanks,
Accuracy/defense/damage and `test_ux_terminal_result.gd` terminal-match
coverage. A full-suite pass alone does not replace these targeted paths.

Run focused tests per slice. At assembled candidate run the full GUT suite,
real two-process Network acceptance, Hot-Seat smoke, active-state recovery,
replay/baseline verification after Owner capture, Phase-K architecture lint,
documentation/link checks and `git diff --check`. Retain per-issue command,
state, UI and log evidence. A passing shared test never closes the other bug.

The named-save UI has a safe-point gate; do not widen it for this repair.
Active-boundary cases use canonical state serialization/reconstruction and
Network reconnect tests, while named-save tests cover permitted checkpoints,
the ship-round marker, exact version rejection, and subsequent decisions.

## 6. Compatibility disposition

This is a semantic cutover, even if some JSON fields retain their names.
Current exact-version loaders and handshake already fail closed. Recheck
allocations on entry, then activate these complete successors together:

| Owner | Current → successor | Disposition |
| --- | --- | --- |
| `SaveGameMetadata.CURRENT_VERSION` | 8 → **9** | CurrentAttack gather/CF state and ShipInstance round and cancellation-return markers change authoritative serialization/validation. Reject save-8 named saves and checkpoints at the version gate; no inference from old active attacks or pre-roll dial state. Preserve authority RNG restoration. |
| `GameReplay.FORMAT_VERSION` and signed alias | 10 → **11** | The CF choice/order and post-roll dial RNG change replay semantics. Reject **every** format-10 history before command application, whether or not it contains CF; this includes both current canonical replay inputs. No relabel, conversion or live-result persistence. Version 11 remains seed plus semantic command history. |
| `NetworkManager.PROTOCOL_VERSION` | 9 → **10** | Exact peer handshake excludes mixed old/new gather and dial semantics. Validate ordered command/result envelope and filtered canonical state in both attacker-role assignments. |
| `GameCommand.APPLICATION_CONTRACT_VERSION` | **2 retained** | Existing Roll/token result contracts keep their exact meaning. Dial changes from deterministic `none` to a new purpose-specific result contract under the existing version-2 envelope; its distinct contract id and exact result validation prevent confusion with prior traffic, and protocol 10 gates peers. Do not change unrelated contracts. |
| `BaselineTrace.FORMAT_VERSION` | **1 retained** | The trace record schema is unchanged. Trace content and final hash may change only as an accepted consequence of the new replay/semantics. |

No old save, wire peer or replay is silently reinterpreted. Exact state and
command schemas, including filtered passive visibility, must be recorded in
the implementation and tested before cutover. If entry inspection finds an
intervening allocation, choose the next free version in that authority and
document it; if accepted documents genuinely disagree about compatibility
policy, stop for Owner guidance rather than inventing a migration.

## 7. Owner steps and completion gates

Follow [CODEX_WORKFLOW replay policy](../CODEX_WORKFLOW.md#replay-fixture-renewal)
and the [Replay Baseline Workflow](../../development/REPLAY_BASELINE_WORKFLOW.md).
The replay-11 cutover invalidates the current canonical
`tests/fixtures/baseline_traces/replay_hot_seat_solo.json` and
`tests/fixtures/baseline_traces/replay_network.json` as executable inputs,
regardless of their individual command contents. At **STOP FOR OWNER REPLAY
CAPTURE**, the Owner must manually record genuine replacement replay-11
Hot-Seat and authoritative-host Network inputs through the corrected real
gameplay path, including a final-gather cancellation/enclosing return and a
post-roll CF dial addition with its authoritative die result in each applicable
mode. Retain command provenance, initial seed, version-11 header and accepted
history. The Owner also records/reviews any required renewal of
`baseline_trace_hot_seat_solo.jsonl` and
`baseline_state_hash_hot_seat_solo.txt` under the same manual-fixture policy;
Network trace/hash outputs remain diagnostic rather than committed fixtures.
Codex must not
generate, synthesize, reconstruct, patch, transform, or relabel replay or
baseline fixtures. Historical files remain available through version-control
history. Candidate code must pass §5 non-fixture production replay and
distributed/recovery tests before this Owner gate; afterward, inspect,
validate and run the authoritative verifier against only genuine recorded
replacements.

Completion requires: (1) all §3 invariants and §5 separate issue rows pass;
(2) the real production CF row, resource choice, authoritative Use path and
Decline path satisfy the Owner smoke-test resolution, including combined
simultaneous spend, dial-before-token effects, no refund and rederivation;
(3) save 9 / replay 11 / protocol 10 with contract 2 is one complete,
fail-closed cutover; (4) passive result, recovery and non-fixture replay tests
pass before Owner capture; (5) genuine Owner-recorded affected replay and
baseline evidence passes the authoritative verifier afterward; (6) full
suite, architecture lint, documentation links and diff check converge with
no unrelated regressions; and (7) affected CON-003 packages contain the
traceability-map evidence and are presented separately for Owner integration
review. The Owner re-accepted this revised workbook on 2026-10-03. This does
not assert BUG-070 or BUG-071 completion or Rule Capability Package integration.
