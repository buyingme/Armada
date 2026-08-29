# DBG-001: Authoritative Debug State Mutation Implementation Workbook

Status: Accepted; requirements fixed; not authorization to
implement outside this workbook

Created: 2026-08-29

Accepted by: Project Owner
Accepted date: 2026-08-29

Purpose: the smallest trusted DBG-001 slice: authoritative ship/squadron
repositioning, authoritative selected faceup damage-card assignment and damage
deck consumption, and the required DEBUG interaction, Hot-Seat, Network,
replay, save/load, projection, and canonical readout evidence. No production
code or tests are changed by this workbook.

## 1. Authority, Boundary, And Fixed Outcome

Classification: **Uncertain/High-Risk Architecture** for planning because the
settled behavior crosses canonical commands, match authority, projection,
Network, replay, and save/load. The two accepted DBG-001 requirements resolve
the target behavior; code below is AS-IS evidence only.

Binding authority, in precedence order:

- [DBG-001 authoritative state mutation](../../requirements/debugging/DBG-001-authoritative-debug-state-mutation.md);
- [DBG-001 debug user interaction](../../requirements/debugging/DBG-001-debug-user-interaction.md);
- [DOCUMENT_AUTHORITY](../DOCUMENT_AUTHORITY.md), [CODEX_WORKFLOW](../CODEX_WORKFLOW.md), and `AGENTS.md`; and
- current code and tests named in this workbook, for implementation seams only.

Fixed first scope: ship repositioning, squadron repositioning, selected
faceup damage-card assignment with canonical deck consumption, minimal
canonical transform readout, and the acceptance evidence required by DBG-001.

Not in scope: any other debug mutator; range/arc/targeting/annotation tools;
property editor/inspector; generic debug command, mutation, controller, or
interaction framework; streamed preview; generic replay/history mechanism;
normal maneuver/squadron-move reuse; gameplay rule redesign; or BUG-032
diagnosis, repair, or resolution claim.

## 2. Verified AS-IS Map And Replacement Boundary

| Concern | Verified owner/path | AS-IS fact | DBG-001 disposition |
| --- | --- | --- | --- |
| Ship canonical transform | `ShipInstance.pos_x`, `pos_y`, `rotation_deg` in `src/core/state/ship_instance.gd`; serialize/deserialize via `GameState` | `ExecuteManeuverCommand` mutates these fields, but also consumes Ship Activation/Maneuver lifecycle and validates speed/yaw/identity. | Add a debug-only transform transaction; do **not** reuse maneuver. |
| Squadron canonical transform | `SquadronInstance.pos_x`, `pos_y`, `rotation_deg` in `src/core/state/squadron_instance.gd` | `MoveSquadronCommand` mutates only position and also consumes activation/action/engagement semantics; it has no debug rotation. | Add the same debug-only transform transaction; do **not** reuse squadron move. |
| Legacy debug drag/rotate | `DebugMode.selected_token`; `GameBoard._process`, `_handle_debug_rotate`, `_move_*_token` in `src/scenes/game_board/game_board.gd` | Direct `Node2D.position`/`rotation`; canonical transform and history are unchanged. `TokenMover` is pure preview geometry in `src/core/movement/token_mover.gd`. | Retain only as transient preview; remove as a commit path. |
| Existing transform projection | `GameBoard._on_ship_repositioned_remotely()` / `_on_squadron_repositioned_remotely()` and existing EventBus signals | Rebuild/load already spawns tokens from canonical transform; remote move/maneuver snaps tokens from canonical transform. | Generalize this existing projection seam to accepted debug reposition results; no optimistic client/host commit. |
| Damage deck / card owner | `GameState.damage_deck`; `DamageDeck` in `src/core/damage/damage_deck.gd` | `draw_card()` pops the current draw-pile top and reshuffles discard only after draw depletion; `serialize()` preserves both pile orders. `DebugController._debug_deal_faceup_card()` currently draws then overwrites identity before submission. | Add only `DamageDeck.take_debug_draw_card_by_effect_id(effect_id)` plus a non-mutating availability query: select the top-most matching **current draw-pile** card, `remove_at` it, and preserve all remaining order; do not inspect/mutate discard or reshuffle for debug selection. Command owns the call. |
| Debug damage command | `DebugDealDamageCommand` in `src/core/commands/debug_deal_damage_command.gd`; facade `GameManager.submit_debug_deal_damage()` | Payload contains presentation-created `card_data`; execute adds it to the ship but does not consume deck. | Keep the purpose-specific command type/provenance; narrow payload to target + requested effect, remove presentation card/deck mutation. |
| Immediate damage consequences | Authoritative mutation: `ResolveImmediateEffectCommand` → `GameManager.submit_resolve_immediate_effect()`; attack presentation: `AttackExecutor` and `AttackPanelMirror._apply_critical_choice_modal()` | `resolve_immediate_effect` is phase-valid in Ship/Squadron with `InteractionFlow.NONE` (`CommandApplicability` and `tests/unit/test_command_processor_applicability.gd`), but its current normal presentation entry is attack-flow-gated (`ATTACK_CRITICAL_CHOICE`); `DebugController` is the current no-attack presenter and also resolves/pre-draws. | Retire debug-owned resolution. Add the accepted board-owned `DamageCardImmediateEffectController` for the no-active-attack debug-dealt-card handoff; it derives target/card and chooser from canonical state and the accepted result, not the DEBUG operator. Keep attack presentation/continuation in its existing owners. Structural Damage's ordinary sequential extra draw belongs in `ResolveImmediateEffectCommand.execute()`, never a UI caller. |
| DEBUG / input ownership | F12 is global in `src/autoload/debug_mode.gd`; board routing is `GameBoard._input`, `_unhandled_input`, `_on_token_clicked`, `_on_squadron_clicked`; `OpponentChoiceModal._unhandled_input()` consumes Escape and has only `choice_confirmed` | Current order lets gameplay/setup/tool handlers receive token/input before DEBUG and F12 has no eligibility/Network gate. The required debug damage picker cannot cancel. | Move only DEBUG-entry and DEBUG-mode routing to `DebugController`/`GameBoard`; use a bounded DEBUG-eligibility predicate over existing owners. Add a debug-only cancellable picker path; leave ordinary modal calls non-cancellable. Do not create a general input arbiter. |
| Match authorization | ordinary host submitter: `NetworkHostCommandSubmitter.submit()`; client admission: `NetworkManager._submit_command_to_server()` | Both require principal-controls-player for `command.player_index`; this prevents host debug of the other side and permits a client debug command when it uses its own side. | Add a command-type-specific host-debug branch at these two existing boundaries, before ordinary gameplay-side authorization. |
| Distribution/history / normalization | `CommandProcessor._ready()` registry; `GameCommand.deserialize()` → `canonicalize_serialized()` → `_INTEGER_PAYLOAD_FIELDS`; `CommandProcessor` history/replay/mirror; `NetworkManager.handle_host_command()` / `_submit_command_to_server()`; `GameManager._apply_network_command_result()` | JSON restores numeric values as floats unless a command type declares integer fields. `debug_deal_damage` is already declared; the new type will not be. | Register `DebugRepositionCommand` in the existing registry and add `debug_reposition: ["owner_player", "unit_index"]` to `_INTEGER_PAYLOAD_FIELDS`. Reuse the existing history/mirror path; the two debug command types are provenance. |
| Durability/filter/projection | `GameState.serialize()/deserialize()`, `SaveGameManager`, `StateFilter.filter_for_player()`, loaded-token spawn | `StateFilter` strips `rng`, replaces deck `draw_pile` with `draw_count`, retains public discard, and retains faceup damage while filtering opponent facedown cards. | Prove full authoritative state equality for host/replay/save-load separately. For a client assert the expected filtered projection only; never require byte equality with host state. |

The normal gameplay commands above must not be reused: their complete
lifecycle/continuation semantics do not represent debug setup. Their field
assignment is insufficient justification for reuse.

## 3. Narrow Target Design

### 3.1 Commands and canonical mutations

Add one purpose-specific `DebugRepositionCommand` (`debug_reposition`), not
two commands and not a generic property setter. Exact payload:

```text
{ target_kind: "ship" | "squadron", owner_player: int, unit_index: int,
  pos_x: float, pos_y: float, rotation_deg: float }
```

`player_index` is the operator envelope/history identity only; it is not the
target owner or a replay authorization claim. `target_kind` is closed to the
two first-scope movable entity kinds. The command validates target existence,
non-destruction, finite normalized transform values, and the existing bounded
board/collision placement result derived with `TokenMover`/fixed `GameScale`
geometry from canonical transforms. It atomically writes exactly the selected
instance's `pos_x`, `pos_y`, and `rotation_deg`; it consumes no activation,
opportunity, phase, maneuver, or squadron action fact.

Register the type in `CommandProcessor._ready()` and declare exactly
`"debug_reposition": ["owner_player", "unit_index"]` in
`GameCommand._INTEGER_PAYLOAD_FIELDS`. `GameCommand.deserialize()` then
normalizes JSON integral floats through its existing shared
`canonicalize_serialized()` path for Network and replay; `pos_x`, `pos_y`, and
`rotation_deg` remain legitimate floats and are not coerced.

The host DEBUG preview remains local and uses the existing `TokenMover`; it is
not serialized or broadcast. Commit sends only the final normalized transform.
On rejection, the board projects the previous canonical transform. There is no
continuous command stream.

Retain and refactor `DebugDealDamageCommand` rather than adding a second
damage setup command. Its accepted payload is exactly:

```text
{ owner_player: int, ship_index: int, effect_id: String }
```

`DamageDeck` receives two deliberately narrow debug-selection operations:

```text
has_debug_draw_card_effect_id(effect_id) -> bool       # no mutation
take_debug_draw_card_by_effect_id(effect_id) -> DamageCard | null
```

They operate on the current authoritative **draw pile** only. `take...` scans
from `size() - 1` downward (the normal draw top) for the first matching real
card, removes that exact entry with `remove_at(index)`, and returns it. It does
not call `draw_card()`, draw/overwrite a different identity, reshuffle, read
or alter discard, or expose arbitrary insertion/removal/reordering. The UI
uses the read-only query to mark an unavailable effect unavailable; availability
can change before host acceptance, in which case validation rejects unchanged.

`DebugDealDamageCommand.validate()` checks target, nonempty `effect_id`, deck,
and `has...` before any deck mutation. Its `execute()` calls `take...` only
after those checks, sets that returned real card faceup, and appends it through
the total `ShipInstance.add_faceup_damage()` operation; there is no later
rejecting branch. A null take returns failure without mutation. This gives a
single command-owned, failure-safe transaction without a rollback/editor API,
preserves remaining draw order and discard invariants, and records the target
and top-most-match selection rule deterministically. Missing target/deck/card
rejects unchanged and enters no history. The chosen `effect_id`, target,
command type, and ordinary follow-up commands provide replay provenance; no
debug flag is added to canonical gameplay state or correlation framework.

Its accepted result adds the narrow deterministic dealt-card identity:

```text
{ owner_player: int, ship_index: int, card_index: int, effect_id: String }
```

`card_index` is the index of the real card appended to `ship.faceup_damage`
by this accepted execution. `owner_player` + `ship_index` identify the
canonical ship; `card_index` + `effect_id` identify and guard the resulting
faceup card. This is a result-contract extension only, not new durable state,
payload identity, replay correlation, or Network protocol. The accepted
no-attack presenter re-resolves this identity from canonical state and declines
to present if it no longer matches.

For Structural Damage, narrow the existing `ResolveImmediateEffectCommand`:
validate sufficient canonical deck availability and, only after acceptance,
call the ordinary `GameState.damage_deck.draw_card()` in
`_execute_structural_damage()`, attach the actual result facedown, then resolve
the triggering card. Remove its presentation-supplied `extra_card_data` route
from `GameManager.submit_resolve_immediate_effect()`,
`AttackExecutor._draw_structural_damage_extra()`, and the debug route. This is
limited to the existing Structural Damage command, not a generic deck redesign;
it retains normal empty-draw-pile reshuffle semantics, records the draw in the
command sequence/canonical deck state, and prevents a debug-side pre-draw.
If making that command-owned transaction failure-safe would require a new deck
owner or generic deck architecture, stop.

### 3.2 Host-only Network authorization

Use the existing submission boundaries only:

1. `NetworkHostCommandSubmitter.submit()` accepts `debug_reposition` and
   `debug_deal_damage` when the local process is the authoritative host,
   independent of `command.player_index` and target owner; ordinary command
   types keep the existing `host_principal_controls_player()` check unchanged.
2. `NetworkManager._submit_command_to_server()` rejects those two command
   types from every remote client before the ordinary principal/player check,
   sends ordinary rejection feedback, and records/broadcasts nothing.
3. All other accepted host debug commands use the existing deferred submit,
   ordered broadcast, client `submit_mirror()`, and history path. No new RPC,
   peer identity, host impersonation, or gameplay authorization exception is
   introduced.

### 3.3 DEBUG interaction ownership and handoff

`DebugMode` remains the local DEBUG state/diagnostic holder, but F12 admission
is moved from its global key handler to the board-owned DEBUG controller. A
single concrete `GameBoard` eligibility callback checks the existing active
modal/nested interaction owners named in Section 2 and host eligibility
(`NetworkManager` role/local presence). It denies entry quietly while an owner
is exclusive; it is not a reusable interaction framework.

While DEBUG is active, route ordinary board token clicks, drag preview,
rotation, Escape, Shift+D, and F12 exit to `DebugController` before setup,
target, tool, attack, squadron, or ordinary selection routing. It has only
three local states: ordinary DEBUG, transient reposition preview, and
`DEBUG / DEAL DAMAGE` selection/picker. Existing diagnostic tools remain local
but are host-only in Network play. Entry is host-only; clients cannot enable or
use any DEBUG surface.

Reposition preview starts from the selected instance's canonical transform,
keeps the HUD readout on that canonical transform, and may update only the
selected token transform/highlight. Next left click commits; Escape/F12 exit
cancels, clears selection/sub-mode/highlight, and snaps from canonical state.
An accepted result ends preview and shows concise confirmation; a rejection
ends it, restores canonical projection, and shows concise feedback.

Shift+D enters exclusive targeting; target click opens the existing card picker;
Cancel/Escape before Confirm makes no command. Extend `OpponentChoiceModal`
with a debug-only `open_debug_cancellable(...)` path (or equally narrow
debug-only option) that shows Cancel and emits a cancel signal only for this
picker. `DebugController` handles that signal by `close_and_clear()`, clearing
the target/sub-mode and returning to ordinary DEBUG with no mutation. Its
ordinary `open(...)` calls, including attack and Crew Panic, retain their
current required-choice Escape behavior. Confirm closes/disables the debug
cancellable path, clears its cancellation callback, and submits only the
purpose-specific command; from that instant Escape cannot cancel a pending or
accepted command. Rejection returns to ordinary DEBUG with feedback. On
accepted debug damage that creates an immediate-effect choice,
`DebugController` ends DEBUG and clears its target/picker state before normal
gameplay presentation begins.

**Accepted immediate-effect handoff — no active attack.** Add
`DamageCardImmediateEffectController` as a board-owned normal gameplay
controller. `GameBoard._create_board_components()` creates it, and
`GameBoard._create_command_router_adapter()` injects it into
`CommandRouterAdapter.initialize(...)`. `CommandRouterAdapter._route_to_controllers()`
remains a dispatcher only: for an accepted `debug_deal_damage` result it calls
`DamageCardImmediateEffectController.react_to_debug_damage_result(command,
result)` after the existing debug visual reaction; it neither derives choices
nor owns continuation.

The controller receives the accepted result identity
`owner_player`, `ship_index`, `card_index`, and `effect_id`; obtains the ship
with `GameManager.current_game_state.get_ship(owner_player, ship_index)`;
obtains `ship.faceup_damage[card_index]`; and verifies its `effect_id`. It
calls only `ImmediateEffectResolver.get_required_choice(card, ship)` to decide
whether a choice exists and whether its chooser is `owner` or `opponent`.
It derives the chooser player from that result relative to `ship.owner_player`,
not from `command.player_index` or the DEBUG operator. A missing/mismatched
canonical target/card or no required choice produces no modal.
After canonical target/card identity revalidation, when
`ImmediateEffectResolver.get_required_choice(card, ship)` returns no required
choice, `DamageCardImmediateEffectController` submits the existing
`GameManager.submit_resolve_immediate_effect(ship, card, {})` path; it does not
restore DEBUG ownership or pre-draw/mutate the damage deck in presentation.

For Hot-Seat, the controller performs the existing ordinary player handoff
needed for the derived chooser, then opens the existing `OpponentChoiceModal`.
For Network, every peer receives the ordinary accepted command result through
the existing mirror/result path; only the peer whose
`NetworkManager.get_local_player_index()` equals the derived chooser opens the
modal. On confirm, that local normal gameplay controller calls the existing
`GameManager.submit_resolve_immediate_effect(ship, card, selection)`, which
creates `ResolveImmediateEffectCommand` through the ordinary submitter. The
controller owns only this damage-card presentation and confirmation state.

`DamageCardImmediateEffectController` does not create `CurrentAttack`, call
`AttackExecutor`, call `AttackPanelMirror`, publish `InteractionFlow` or
attack-flow state, or retain a DEBUG reference/continuation. Existing attack
damage summary, critical-choice modal, remote mirror, and current-attack
continuation remain wholly in `AttackExecutor`, `AttackPanelController`, and
`AttackPanelMirror`. Auto-resolve remains command-owned through the existing
`ResolveImmediateEffectCommand` path in
`DamageCardImmediateEffectController`; it does not restore DEBUG ownership.

### 3.4 Projection/readout

Extend the existing command-result routing/EventBus transform projection for
`debug_reposition`, using the current canonical-to-token snap helpers for both
local accepted and mirrored results. Do not leave host presentation at a
preview transform or add a client preview stream. Extend `DebugHelpPanel` (or
its existing HUD surface) with selected object identity plus canonical X/Y/
rotation only; it is read-only and not a property editor.

## 4. Ordered Implementation Slices

1. **Canonical commands and deck transaction.** Register `debug_reposition`;
   declare its integer payload normalization; implement its closed transform
   payload/validation/rollback; replace debug damage `card_data` with the
   command-owned top-most-match draw-pile removal contract; move Structural
   Damage's existing extra draw into its existing command. Update command
   applicability declarations and focused state/command tests.
2. **Submission, history, projection, durability proof.** Add the two exact
   host/client authorization guards; add facades; route accepted reposition and
   damage results through the existing projection/mirror path; prove Hot-Seat,
   host/client, history/replay, save/load, deck, and filtered-client projection.
3. **Bounded DEBUG interaction cutover and immediate-effect handoff.** Make board-owned F12 eligibility and
   host-only DEBUG routing exclusive; replace direct transform commit with
   preview/commit/cancel; add the debug-only cancellable card picker, readout,
   success/rejection feedback, and interaction tests. Remove the old
   presentation-authority selection/commit routes. Create and route the
   bounded `DamageCardImmediateEffectController`; extend the accepted debug
   damage result with card identity; then prove normal owner/opponent choice
   presentation without an active attack.
4. **Convergence audit.** Remove the replaced direct presentation-authority
   calls, verify no parallel debug path remains reachable, run the required
   gates, and conduct concise manual Hot-Seat and two-human Network QA. Do not
   expand the debug menu.

Each slice is independently buildable/testable. Slice 3 may not land before
Slices 1–2 prove the command/projection path. Its immediate-card portion uses
the accepted bounded handoff seam and must not expand into generic interaction
or attack-flow work.

## 5. Focused Evidence And Verification

### Required tests

| Evidence | Test path/seam |
| --- | --- |
| Transform payload, JSON integer normalization, target/type/bounds/collision rejection, atomic rollback, canonical fields, serialization/history | New `tests/unit/test_debug_reposition_command.gd`; extend `tests/unit/test_command_applicability.gd` and `tests/unit/test_command_processor.gd` with `GameCommand.deserialize()` float-to-int and nonintegral rejection cases. |
| Selected-card contract | Extend `tests/unit/test_damage_deck.gd` and `tests/unit/test_debug_deal_damage_command.gd`: read-only availability; top-most matching current-draw selection; exact card removal; stable remaining order; unchanged discard; unavailable/missing target rejection with unchanged deck/ship/history; no `card_data` identity injection. |
| Structural extra card | Extend `tests/unit/test_resolve_immediate_effect_command.gd`: after accepted Structural Damage resolution, exactly one normal deck draw becomes facedown; a failure does not draw; no caller supplies a card identity. |
| Canonical preview/commit/cancel/rejection and picker | Extend `tests/unit/test_debug_mode.gd` and `tests/unit/test_debug_help_panel.gd`; add focused `tests/unit/test_debug_controller.gd` and `tests/unit/test_opponent_choice_modal.gd`: canonical-only readout during preview, one command on commit, no command on Escape/F12/picker Cancel, highlight/sub-mode exclusion, Confirm disables cancellation, and ordinary required-choice Escape remains non-cancelling. |
| Non-attack immediate-effect handoff | Add focused `tests/unit/test_damage_card_immediate_effect_controller.gd` and integration coverage at `tests/integration/test_debug_authoritative_protocol.gd`: an accepted `debug_deal_damage` result supplies target/card identity; with no active `CurrentAttack` and no attack-flow publication, the controller re-finds the canonical faceup card, uses `ImmediateEffectResolver` to derive owner/opponent, ends DEBUG before modal presentation, and submits only through `GameManager.submit_resolve_immediate_effect()` / `ResolveImmediateEffectCommand`. In Hot-Seat, the ordinary chooser handoff/modal reaches the owner or opponent as required. In Network, only the chooser peer opens the modal; the host DEBUG initiator does not become chooser merely by initiating debug damage. |
| Network admission, mirror, filtered projection | Extend `tests/integration/test_network_transport.gd` and `tests/unit/test_network_manager.gd` around `NetworkManager._submit_command_to_server()` / `NetworkHostCommandSubmitter.submit()` / `GameManager._apply_network_command_result()`: host debug works independently of target side; forged/direct client `debug_reposition` and `debug_deal_damage` attempts get a targeted rejection, no broadcast/history/state mutation; ordinary gameplay principal checks remain unchanged. |
| Replay / save-load / filter | Extend `tests/unit/test_game_replay.gd`, `tests/unit/test_save_load_round_trip.gd`, and `tests/unit/test_state_filter.gd`: authoritative host, replay, and save/load final serialized states agree (including full deck order/RNG where serialized); client assertions compare `StateFilter.filter_for_player(host_state, client)` only. |
| Rule convergence only | One DBG-001 proof that the accepted faceup card reaches the existing `ResolveImmediateEffectCommand` through `DamageCardImmediateEffectController` normal owner/opponent handoff, with replay/save-load reproducing the accepted dealt-card identity and resulting authoritative state where resolution occurs. It is not a BUG-032 test, diagnosis, or resolution claim. |

Required assertions: preview/cancel create no command and preserve canonical
state; commit creates exactly one debug command; rejection creates no history;
host target-side independence works; client submission is rejected before
ordinary gameplay authorization and remains unrecorded; client receives only
accepted canonical results; no-active-attack immediate choice is presented only
to its resolver-derived chooser after DEBUG has ended; the host debug initiator
is not substituted as chooser; no `CurrentAttack` or attack-flow state is
created; and replay/mirror synthesize no commands.

For Network client projection, assert the committed public transform, public
faceup damage-card result, `damage_deck.draw_count` and public `discard_pile`,
and no local preview state. Also assert filtered state has no `rng` and no
`damage_deck.draw_pile` / hidden draw ordering. Do **not** compare a client
reconstruction byte-for-byte with host state. Separately compare complete
authoritative host/replay/save-load state (including deterministic deck order
and serialized RNG) for equality. Normal choice entitlement remains unchanged.

### Commands before acceptance

```bash
./scripts/run_tests.sh -f tests/unit/test_debug_reposition_command.gd
./scripts/run_tests.sh -f tests/unit/test_debug_deal_damage_command.gd
./scripts/run_tests.sh -f tests/unit/test_damage_deck.gd
./scripts/run_tests.sh -f tests/unit/test_resolve_immediate_effect_command.gd
./scripts/run_tests.sh -f tests/integration/test_network_transport.gd
./scripts/quality_check.sh
bash scripts/lint_phase_k.sh
./scripts/run_baseline_traces.sh --all
git diff --check
```

`quality_check.sh` already runs the complete GUT suite; do not add a duplicate
full-suite invocation. Confirm its pass count has not decreased. Run focused
structural searches/review to prove, once replacements are active, that the
following parallel paths are removed or disabled: presentation-only final
reposition commit (preview remains permitted); debug UI `DamageDeck.draw_card()`
or identity override / `card_data`; `DebugController` immediate-choice or
auto-resolution orchestration; `AttackExecutor._draw_structural_damage_extra()`
and facade-supplied Structural `extra_card_data`; and remote-client admission
of either state-changing debug type. This does not claim removal of unrelated
normal gameplay deck callers. Baseline fixture changes are not implied; add a
focused replay fixture only if existing test APIs cannot exercise history.

### Concise manual QA

1. Hot-Seat: F12 only enters with no exclusive gameplay interaction; reposition
   each entity, verify HUD canonical values after commit, and cancel once with
   Escape/F12.
2. Hot-Seat: Shift+D target/picker cancel then confirm; verify one deck card,
   replay and reload result. For an immediate choice card, verify DEBUG ends,
   the resolver-derived owner/opponent receives the ordinary modal, and the
   existing immediate-effect command resolves it without an attack.
3. Two-human Network: client cannot enter DEBUG; host repositions and damages
   either side; client sees only accepted public result and no preview. For an
   immediate choice card, the entitled chooser receives the ordinary modal even
   when the host initiated DEBUG. Do not attempt forged/direct command injection
   in manual QA; it belongs only to the automated Network admission coverage above.

## 6. Stop Gates, Exclusions, And Audit Checklist

Stop and request Owner direction rather than improvise if any of these is
required:

1. a new/missing canonical transform, deck, damage, or immediate-effect owner;
2. weakening ordinary gameplay command authorization, admitting a client debug
   command, or treating host/player-side identity as equivalent;
3. a generic debug mutation/controller/interaction/property framework;
4. a new generic replay/history/correlation or Network protocol architecture;
5. a geometry rule that cannot be reproduced from canonical transforms and the
   existing pure placement helper without presentation authority;
6. contradiction of either accepted DBG-001 document or accepted architecture;
7. any work that diagnoses, repairs, tests-to-resolution, or claims resolution
   of BUG-032.

**Resolved Owner decision — normal immediate-effect presentation outside an
attack.** Implement only the accepted board-owned
`DamageCardImmediateEffectController` seam in Section 3.3. Stop if the
accepted `debug_deal_damage` result cannot carry the small
`owner_player`/`ship_index`/`card_index`/`effect_id` identity extension, or if
the controller cannot re-find and verify that identity in canonical state.
Neither condition authorizes a generic controller/continuation framework,
synthetic attack, attack-flow publication, or DEBUG-owned choice.

All other planned seams preserve accepted decisions: one closed
`debug_reposition` command, retained `debug_deal_damage` with a narrow deck
operation, exact host/client guards, and debug-only picker cancellation. The
existing BUG-032 dependency remains: DBG-001 establishes trustworthy setup
only and neither diagnoses nor repairs BUG-032.

Independent workbook audit is ready when a reviewer can verify every Section 2
path/symbol, the Section 3 deck and accepted result-identity contracts,
normalization, filtered-view assertions, cancellation boundary, controller
handoff/removal checks, and residual identity stop condition; trace each slice
to a test row; and confirm the workbook neither changes accepted Owner
decisions nor expands the first-scope boundary.
