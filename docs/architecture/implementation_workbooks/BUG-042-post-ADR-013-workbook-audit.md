# BUG-042 workbook audit

## 1. Verdict

**NEEDS MAJOR REWORK**

The revised workbook has the correct architectural center: authority-only live RNG, a damage-specific passive ledger, command-owned result application, projection equivalence, and a hard protocol cutover. It is not the wrong direction.

It is not yet implementation-authorizing because four material gaps remain:

1. the live Network debug-damage contract violates ADR-013 secrecy;
2. destruction cleanup is still presentation-triggered and can be duplicated or reordered;
3. restored/replaced `DamageDeck` instances lose their deterministic RNG binding;
4. changing semantic damage-command payloads while keeping replay format 7 is unresolved and requires an Owner compatibility decision.

No files were modified.

## 2. Overall implementation-direction assessment

The proposed `GameCommand → CommandProcessor → GameManager` result-application seam fits current production topology.

Current mirror execution already:

- checks sequence before execution;
- runs processor preflight and command validation;
- records history and advances the cursor only after successful execution;
- suppresses passive observer follow-ups;
- buffers out-of-order network results and ignores stale/duplicate sequences.

Evidence: [command_processor.gd](/Users/Katharina/godot/Armada/src/autoload/command_processor.gd:268), [command_processor.gd](/Users/Katharina/godot/Armada/src/autoload/command_processor.gd:557), [game_manager.gd](/Users/Katharina/godot/Armada/src/autoload/game_manager.gd:2674).

The workbook’s narrow passive-result command hook therefore satisfies ADR-012 without creating a generic snapshot/result mutation owner. Its strict separation of command, application result, presentation result, and routing metadata is also sound.

The problems are not with this center seam. They arise where current presentation, debug, replay, and state-replacement paths bypass or outlive that seam.

## 3. Production inventory and negative-space assessment

### Direct live `GameState.rng` consumers

The workbook’s count of four direct semantic command consumers is exact:

1. `RollDiceCommand`;
2. `RerollAttackDieCommand`;
3. `UseConcentrateFireTokenRerollCommand`;
4. `SelectEvadeDieCommand`.

The long-range Evade branch currently captures RNG state before deciding the range branch, so the workbook correctly requires removing that unnecessary dereference.

Non-command holders/consumers are also correctly identified:

- `FleetSetupBootstrapper`;
- `LearningScenarioPreparer` and `LearningScenarioSetup`;
- current scene-time `GameBoard` setup;
- `DamageDeck` initial shuffle and discard reshuffle;
- save/replay serialization and reconstruction.

### Seven current damage-command owners

The workbook’s seven commands are the exact presently reachable command classes that can own canonical damage mutation:

| Command | Current production entry |
|---|---|
| `ResolveDamageCommand` | Attack damage resolution |
| `OverlapDamageCommand` | `ShipActivationController` scene pre-draw |
| `PersistentEffectDamageCommand` | `GameBoard` pre-draw and rule follow-ups |
| `ResolveImmediateEffectCommand` | Immediate-damage controller |
| `RepairActionCommand` | Repair resolver/UI |
| `DestroyUnitCommand` | `GameManager._on_ship_destroyed()` |
| `DebugDealDamageCommand` | Host debug UI |

However, this is not an exact valid target catalog: `DebugDealDamageCommand` cannot remain a live Network contract under ADR-013. The valid live target is therefore six gameplay contracts plus local/Hot-Seat-only debug behavior.

### Relevant missed production surfaces

The workbook’s file inventory is incomplete:

- `DebugController` queries hidden draw-pile membership to set each damage option’s `available` flag. It is absent from Section 8. [debug_controller.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/debug_controller.gd:445)
- `CommandSubmitter.submit_authoritative()` delegates to ordinary `submit()` on clients. Therefore a passive presentation reaction can send a supposedly engine-owned `DestroyUnitCommand` back to the authority. [command_submitter.gd](/Users/Katharina/godot/Armada/src/core/commands/command_submitter.gd:19)
- `ResolveDamageCommand` restores a deck by deserializing a replacement instance, losing its RNG reference. [resolve_damage_command.gd](/Users/Katharina/godot/Armada/src/core/commands/resolve_damage_command.gd:250)
- `DefenseTokenResolver.apply_evade_reroll()` calls `Dice.roll_die()` without `GameState.rng`. Its current helper has no reachable caller; classify it explicitly as legacy/dead, not as a fifth live consumer. [defense_token_resolver.gd](/Users/Katharina/godot/Armada/src/core/combat/defense_token_resolver.gd:231)
- Lobby/setup tie-break fallbacks use global randomness. They are setup-choice generation, not live `GameState.rng` command consumption, but should be explicitly excluded rather than omitted.
- Existing format-7 replay fixtures contain the damage payload forms that the workbook removes. [replay_20260830_080743.json](/Users/Katharina/godot/Armada/docs/qa/bugs/closed/BUG-039/replay_20260830_080743.json:841)

### Reachable versus dead helpers

- `ImmediateEffectResolver.resolve()` contains direct mutation code, but no production caller reaches it; current production uses only its classification/choice helpers. The workbook classifies this correctly.
- `AttackExecutor` retains a damage pre-draw helper without a live caller. It is legacy/dead and safe to remove in the scoped conversion.
- The scene pre-draws in `ShipActivationController` and `GameBoard` are live and must be migrated.

## 4. Result-transaction assessment

The actual path is:

1. player or engine submits a semantic command;
2. authority deserializes and principal-validates it;
3. `CommandProcessor` performs sequence, applicability, rule, and command validation;
4. the authority command executes;
5. only success enters history and advances cursor;
6. authority broadcasts;
7. passive `GameManager` buffers by sequence;
8. contiguous entries call `submit_mirror`;
9. only successful mirror execution reaches presentation and clears the submission gate.

Evidence: [network_manager.gd](/Users/Katharina/godot/Armada/src/autoload/network_manager.gd:1436), [command_processor.gd](/Users/Katharina/godot/Armada/src/autoload/command_processor.gd:285), [game_manager.gd](/Users/Katharina/godot/Armada/src/autoload/game_manager.gd:2708).

Accordingly:

- **Validation before canonical mutation:** supported by the proposed seam.
- **Command-owned passive mutation:** supported.
- **History/cursor after commit:** supported.
- **Rejection leaves history/cursor/success presentation unchanged:** supported, provided each converted command fully prevalidates before mutation.
- **Duplicate/stale result handling:** current buffering already rejects reapplication.
- **Delayed/out-of-order handling:** current buffering waits for the contiguous sequence.
- **Later sequence after rejected contiguous entry:** correctly remains blocked.
- **No generic mutation service:** the proposed narrow opt-in hook is acceptable.

The current `__remote_authored` contamination is real: the authority inserts it directly into the result dictionary before broadcasting. [network_manager.gd](/Users/Katharina/godot/Armada/src/autoload/network_manager.gd:1481) Moving it to host-local transport metadata is required.

One transaction boundary remains broken: destruction cleanup is generated later by presentation signals, not by the accepted damage transaction/follow-up owner. That exception prevents an overall atomicity finding.

## 5. RNG-command assessment

The four contracts contain only viewer-public realized facts:

- `roll_dice`: complete public dice results;
- ordinary rerolls: the replacement public face;
- CF token reroll: replacement face, with token/state changes derived from intent and pre-state;
- Evade: public operation plus replacement face when applicable.

None requires passive RNG, seed, future-stream state, hidden order, or unrelated hidden facts. All can validate from command intent, accepted order, current attack/flow state, and the realized public face.

Authority and replay can continue to execute their normal semantic command against full RNG. Passive Network execution uses the transported result only. The semantic commands remain sufficient for deterministic new replay generation.

Indirect classification:

- damage reshuffle consumes RNG through the authority’s `DamageDeck`, not a fifth RNG command;
- setup shuffling belongs to authority construction;
- scene/controller damage pre-draws are damage-command migration work;
- global setup tie-breaks are outside live gameplay command RNG;
- `DefenseTokenResolver`’s global reroll helper is dead legacy;
- profile IDs, lobby codes, music shuffling, and save identifiers are non-gameplay randomness.

## 6. Damage-ledger and projection-equivalence assessment

The selected passive representation is exactly ADR-013’s required state:

\[
\text{draw count} + \text{public discard identities} +
\sum \text{facedown counts} + \sum \text{public faceup objects}
\]

The workbook’s ledger therefore has the right information and no excess hidden state.

### Transition proof

| Transition | Passive delta | Identity boundary |
|---|---|---|
| Hidden draw → facedown | `draw_count − 1`, ship count `+1` | No identity transported |
| Hidden draw → faceup | `draw_count − 1`, add supplied public card | Identity enters state in this transition |
| Faceup → facedown | Remove public object, ship count `+1` | Identity disappears |
| Facedown repair | Ship count `−1`, append supplied discard card | Identity becomes public at discard |
| Faceup repair | Remove known faceup object, append it to discard | Already public |
| Destruction | Clear facedown count; append supplied identities and known faceup objects | Previously hidden identities become public at cleanup |
| Persistent/additional damage | Consume aggregate draw, increment count | No hidden identity |
| Overlap | Consume two aggregate draws, increment two ship counts | No hidden identity |
| Exhaustion/reshuffle | Move public discard count into hidden draw count, clear discard, then consume | Order remains unknown |
| Structural Damage | Consume one aggregate draw and move known immediate card faceup→facedown | No remaining facedown identity |
| Resume/reconnect | Reinstall the same ledger projection | No reconstruction |

The workbook correctly requires faceup cards drawn after a public-discard reshuffle to be members of the pre-reshuffle public multiset. [workbook](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/BUG-042-network-rng-authority-result-application-implementation-workbook.md:347)

Projection equivalence is an effective primary oracle: after each accepted sequence, filtering authority state must equal the normalized passive state for the viewer. The incremental ledger rules are sufficient to satisfy it.

Known divergence risks are:

- destruction cleanup being submitted at different times or twice;
- a filtered installer dropping ledger-only fields;
- unstable or duplicated roster identifiers;
- presentation code mutating or reconstructing missing damage facts;
- loaded authority reshuffle using a different RNG after lost binding.

## 7. Command/history/log secrecy assessment

### BLOCKER: live debug availability oracle

The debug UI exposes whether each named effect remains in the hidden draw pile:

```gdscript
"available": _has_effect_available(effect_id)
```

and `_has_effect_available()` queries the authority deck directly. [debug_controller.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/debug_controller.gd:568)

This reveals hidden deck membership to the host player. By combining public faceup/discard facts and known deck composition, it can also identify or narrow identities presently facedown. A rejected request for an unavailable effect is a second oracle.

ADR-013 provides no Network debug exception. The workbook’s proposed live `debug_deal_damage` contract is therefore inconsistent with settled authority.

The narrow correction is to make debug damage non-admissible in live Network play and keep it local/Hot-Seat only.

### Command payload strictness

The workbook makes application-result schemas exact but does not state equally explicit unknown-field rejection for changed semantic command payloads.

Current canonicalization duplicates and preserves arbitrary payload fields. [game_command.gd](/Users/Katharina/godot/Armada/src/core/commands/game_command.gd:226) Merely ceasing to read `moving_card`, `other_card`, `card_data`, or `draw_from_deck` does not prevent a stale or malicious sender from placing those identities in:

- the command envelope;
- accepted semantic history;
- diagnostics;
- replay export.

Protocol-5 live admission must enforce exact command-intent schemas for every converted command before execution/history.

Other secrecy-directed migrations—generic facedown repair choices, removal of persistent/overlap pre-draws, removal of identity-based remote presentation, and both-player StateFilter hiding—are correct.

## 8. StateFilter and filtered-installation assessment

Current `StateFilter`:

- removes RNG;
- emits `draw_count` plus discard;
- hides opponent facedown cards;
- returns the owning player’s full facedown arrays unchanged. [state_filter.gd](/Users/Katharina/godot/Armada/src/core/network/state_filter.gd:55)

Current ordinary deserialization then loses the filtered-only facts:

- `GameState.deserialize()` understands only full `damage_deck` data and ignores `draw_count`; [game_state.gd](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:703)
- `ShipInstance.deserialize()` reads `facedown_damage` but not `facedown_count`. [ship_instance.gd](/Users/Katharina/godot/Armada/src/core/state/ship_instance.gd:897)

The workbook correctly requires a passive-aware installer to consume and validate the ledger before ordinary full-state deserialization discards it.

Stable `owner:roster_entry_id` keying is workable across fresh, resume, reconnect, and destruction because ships remain in roster state after destruction. Empty/duplicate IDs must reject at installation, as specified.

Required refinement: `StateFilter` should explicitly accept only a full authority representation. Re-filtering an already-passive serialization must reject or follow a separately defined passive-normalization path; it must not silently treat the ledger as an authority deck.

Production code currently assuming a usable `DamageDeck` includes `GameBoard`, `AttackExecutor`, `ShipActivationController`, repair construction, and debug damage. The workbook covers most of these, but live debug must be removed and the board’s cached `_damage_deck` must remain null on passive peers without triggering fallback construction.

## 9. Fresh-bootstrap and protocol assessment

Current fresh Network start distributes a shared seed and each peer constructs state after scene entry. [lobby_manager.gd](/Users/Katharina/godot/Armada/src/autoload/lobby_manager.gd:145), [game_board.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/game_board.gd:1283) That must change.

Current resume already provides most of the needed ownership split:

| Stage | Current owner | Assessment |
|---|---|---|
| Lobby/setup validation | `LobbyManager`, `NetworkManager` | Necessary and enforceable |
| Full authority construction | `GameManager` plus setup builders | Necessary; currently too late |
| Cursor capture | `CommandProcessor`/`GameManager` | Necessary |
| Per-viewer filtering | `NetworkManager` + `StateFilter` | Necessary |
| Snapshot/association staging | Existing resume attempt machinery | Reusable |
| Client validation/staging ACK | `NetworkManager`/`LobbyManager` | Reusable |
| Commit and passive installation | `LobbyManager` + `GameManager` | Reusable |
| Installation ACK | `NetworkManager` | Necessary before admission |
| Admission | `NetworkManager` | Enforceable |
| Scene release | `LobbyManager` | Enforceable |

### Unsupported part of the proposed exact order

Workbook step 3 installs the authority state and executes initial commands before client staging, while the failure text later says a pre-publication failure can roll back to the lobby. [workbook](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/BUG-042-network-rng-authority-result-application-implementation-workbook.md:539)

Current `GameManager.start_new_game()` installation:

- resets processor/history;
- publishes `current_game_state`;
- installs submitters;
- marks the game active;
- emits `game_started`;
- starts the round. [game_manager.gd](/Users/Katharina/godot/Armada/src/autoload/game_manager.gd:317)

There is no current reversible tentative-install transaction covering those effects. Existing resume deliberately stages first and calls `start_new_game_from_state()` only at commit. [lobby_manager.gd](/Users/Katharina/godot/Armada/src/autoload/lobby_manager.gd:367)

The workbook must either:

- move authority publication/initial commands to a clear post-staging linearization point; or
- specify a purpose-specific, fully reversible tentative installation and its rollback owner.

It may not leave the implementer to invent a generic candidate-state processor or bootstrap FSM.

### Protocol cutover

A protocol bump is mandatory. Current version is 4, and the handshake already rejects unequal versions before admission. [network_manager.gd](/Users/Katharina/godot/Armada/src/autoload/network_manager.gd:29), [network_manager.gd](/Users/Katharina/godot/Armada/src/autoload/network_manager.gd:1239)

Protocol 5 coherently groups:

- new result envelope;
- targeted viewer results;
- removed shared live seed;
- passive damage ledger;
- changed command payload schemas;
- fresh authority-first installation.

No 4↔5 adapter or downgrade is appropriate.

## 10. Save/load and replay assessment

### Authority save/load

Authority saves correctly retain full RNG, full deck order, discard, faceup/facedown identities, and lifecycle state. Passive ledgers and live result payloads must remain absent from saves.

### BLOCKER: RNG rebinding after load and rollback

`GameState.deserialize()` restores `DamageDeck` and `GameRng` independently but never calls `damage_deck.set_rng(state.rng)`. [game_state.gd](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:703)

`DamageDeck.deserialize()` creates a deck with no RNG reference. [damage_deck.gd](/Users/Katharina/godot/Armada/src/core/damage/damage_deck.gd:176)

At the next discard reshuffle it silently falls back to global `Array.shuffle()`. [damage_deck.gd](/Users/Katharina/godot/Armada/src/core/damage/damage_deck.gd:133)

The same defect occurs when `ResolveDamageCommand` restores a deck after a failed atomic attempt.

Disposition:

- it is a prerequisite to BUG-042’s required save/load continuation proof;
- because BUG-042 explicitly requires uninterrupted-vs-loaded equivalence through reshuffle, the narrow rebind belongs in BUG-042 scope;
- alternatively, a separately tracked fix must land before BUG-042, and the workbook must name it as a prerequisite;
- it must not remain implicit.

### Replay

New replays can remain seed-plus-corrected-semantic-history and need no live result payloads.

The current compatibility claim is not resolved, however:

- replay format 7 owns the accepted command model and is rejected strictly on mismatch; [game_replay.gd](/Users/Katharina/godot/Armada/src/core/commands/game_replay.gd:119)
- current format-7 fixtures contain `persistent_effect_damage.card_data` and `draw_from_deck`; [replay_20260830_080743.json](/Users/Katharina/godot/Armada/docs/qa/bugs/closed/BUG-039/replay_20260830_080743.json:841)
- the repository workflow says semantic command-model migrations require explicit replay-format treatment and new reviewed fixtures. [REPLAY_BASELINE_WORKFLOW.md](/Users/Katharina/godot/Armada/docs/development/REPLAY_BASELINE_WORKFLOW.md:471)

Keeping format 7 while rejecting the old fields makes existing format-7 artifacts fail after acceptance. Keeping the fields silently contradicts the workbook’s strict removal and live-history secrecy unless a replay-only normalization boundary is defined.

This is an unresolved Owner compatibility decision.

## 11. End-to-end trace assessment

| Trace | Assessment |
|---|---|
| **A. Fresh → BeginAttack → RollDice → damage** | Directionally complete after fixing bootstrap linearization. Authority owns setup/RNG/deck; filtered passive install precedes admission; RollDice uses a public result; damage applies a ledger delta; projection equivalence is the postcondition. |
| **B. Facedown damage → repair/discard** | Complete in the proposed contract. Initial draw exposes no identity; repair chooses an ordinal; authority’s accepted repair result publishes the card exactly when it enters discard; both viewers converge. |
| **C. Exhaustion/reshuffle → subsequent draw** | Complete for fresh authority. Passive clears public discard into an aggregate hidden count and validates any subsequently public card against the pre-reshuffle multiset. No order/RNG is exposed. |
| **D. Resume/reconnect with mixed damage → next command** | Complete if the passive-aware installer consumes ledger fields and restores cursor before admission. Existing resume/reconnect owners can enforce this. |
| **E. Authority save → load → later RNG attack/damage** | **Cannot complete as written.** Dice RNG restores, but the loaded deck’s next reshuffle uses global RNG because its binding was lost. |
| **F. BUG-035 overlapping lethal attack** | **Cannot complete as written.** Destruction cleanup is emitted through presentation and can interleave differently with attack continuation depending on command authorship. |

## 12. Slice and scope assessment

Slices 1 and 2 are independently reviewable and mergeable as characterization/model work, provided no runtime passive path is enabled.

Slices 3–7 form one mandatory non-deployable migration:

- envelope producer and consumer;
- processor result mode;
- all direct RNG consumers;
- passive ledger;
- every live damage transition;
- filtered installer;
- fresh/resume/reconnect;
- scene/read-model migration;
- protocol 5.

The workbook correctly says intermediate combinations must not deploy.

Required scope additions:

- `src/scenes/game_board/debug_controller.gd`;
- destruction event/follow-up generation and all three current emitters;
- explicit deck-to-RNG rebind after deserialization and rollback restoration;
- replay format owner, fixtures, and baseline workflow if the Owner selects a bump;
- exact live command-payload validation.

Potentially unnecessary scope:

- an exact two-ACK fresh bootstrap is a category-C choice. Reuse of the existing resume machinery is reasonable, but the workbook should require the safety invariants rather than an unsupported tentative-install design unless that design is explicitly justified.
- no generic result, continuation, hidden-state, or snapshot infrastructure is warranted.

Obsolete or stopped-predecessor residue remains in:

- the claim that no Owner decision remains;
- the claim that the inventory is complete;
- the live Network debug contract;
- unchanged replay format 7;
- the pre-staging authority installation/rollback sequence.

## 13. Regression and verification assessment

The workbook’s planned verification is otherwise strong. It requires:

- real fresh/resume/reconnect paths;
- both-viewer projection equivalence;
- protocol mismatch;
- result rejection and exact-once behavior;
- secrecy inspection;
- save/load continuation;
- deterministic replay;
- exhaustion/reshuffle;
- repair/publication;
- destruction;
- overlap/persistent/additional damage;
- BUG-035 lethal/non-lethal recovery;
- full tests, baseline traces, quality checks, and diff checks.

Missing explicit regressions:

1. Network debug UI must not expose hidden draw membership; preferably debug damage is unavailable entirely.
2. A lethal damage result must produce exactly one authority-owned destruction cleanup command for both attacker/defender ownership directions.
3. Passive presentation must never submit `DestroyUnitCommand`.
4. Duplicate/stale `DestroyUnitCommand` must reject rather than enter history with zero cleanup.
5. ResolveDamage rollback followed by deck exhaustion must preserve the same RNG stream.
6. Existing format-7 replay fixtures must either reject cleanly under a bumped version or be processed by the Owner-selected compatibility rule.
7. Live protocol-5 commands containing removed identity fields must reject before history.
8. Both-viewer production proof must specify swapped host/client assignments or an equivalent real dual-view harness—not only two in-memory filtered reconstructions.
9. Duplicate `resolve_damage` protection should be exercised through the actual transport/processor seam, not only helper validation.

## 14. Architecture versus implementation choices

| Mechanism | Category | Assessment |
|---|---|---|
| Authority-only live RNG | **A** | Mandated by ADR-012 |
| Passive damage ledger with exactly four fact classes | **A** | Mandated by ADR-013 |
| Command-owned passive result application | **A** | Mandated |
| Narrow opt-in `GameCommand` result hook | **B/C** | Forced seam, sensible implementation choice |
| Ordered buffering in `GameManager` | **B** | Existing topology |
| Separate metadata/application/presentation envelope | **C** | Acceptable if presentation remains noncanonical |
| Targeted per-viewer result delivery | **A/B** | Required for visibility and current endpoint associations |
| Exact string key `"owner:roster_entry_id"` | **C** | Harmless local representation choice |
| Separate `DestroyUnitCommand` after lethal damage | **B/C** | Existing pattern, but owner/order must be specified |
| Live Network debug result contract | **C** | Unnecessary and architecture-conflicting |
| Exact ten-stage/two-ACK fresh sequence | **C** | Over-specified unless tentative-state failure semantics are made concrete |
| Protocol 5 hard cutover | **B** | Forced by incompatible wire/bootstrap/state schemas |
| Replay format remaining 7 | **C** | Unsupported until compatibility decision |
| RNG rebinding after full-state replacement | **B** | Forced by current `DamageDeck` topology |

## 15. Blockers

### BLOCKER 1 — Live debug secrecy conflict

The host debug modal and unsuccessful effect selection reveal hidden deck membership. The workbook cannot retain `debug_deal_damage` as a live Network contract under ADR-013.

### BLOCKER 2 — Destruction is not authority-follow-up-owned

Current presentation emits `EventBus.ship_destroyed`; `GameManager` then submits `DestroyUnitCommand`. [game_manager.gd](/Users/Katharina/godot/Armada/src/autoload/game_manager.gd:2568)

The passive submitter delegates `submit_authoritative()` to ordinary network submission. Depending on which player authored the lethal damage:

- the passive attempt may be rejected by principal ownership;
- or both authority and passive can submit cleanup;
- a duplicate cleanup currently validates because `DestroyUnitCommand` checks only that the ship exists. [destroy_unit_command.gd](/Users/Katharina/godot/Armada/src/core/commands/destroy_unit_command.gd:35)

The order relative to BUG-035 attack continuation also varies by submission route. The workbook must define one authority-only generation point and remove semantic submission from presentation.

### BLOCKER 3 — Authority deck RNG is lost after replacement

Both full-state loading and `ResolveDamageCommand` rollback produce a replacement `DamageDeck` with no RNG binding. Required deterministic continuation cannot be achieved without an explicit rebind.

### BLOCKER 4 — Replay compatibility is unresolved

The workbook both removes identity-bearing semantic fields and says replay format 7 remains unchanged. Current format-7 artifacts contain those fields. Repository replay authority does not establish which incompatible interpretation should win.

## 16. Important and minor findings

### IMPORTANT

- Protocol-5 semantic command payloads need exact allowed-field schemas, not only corrected constructors and strict application results.
- Fresh bootstrap step 3 installs/publishes authority state before staging but provides no enforceable rollback of `GameManager`, command history, signals, or initial commands.
- Destruction cleanup ordering relative to attack continuation and persistent-effect phase continuation is unspecified.
- Both-viewer production equivalence needs a concrete real-process role-swap or dual-endpoint method.
- `StateFilter` needs a defined authority-only input boundary so a passive state is not accidentally re-filtered as full authority state.

### MINOR

- The dead `DefenseTokenResolver` global-RNG helper and dead `ImmediateEffectResolver` mutation code should be recorded explicitly as non-production.
- Global lobby/setup random tie-break paths should be classified as setup configuration randomness outside `GameState.rng`.
- The composite ship-key encoding is discretionary, though sufficiently narrow.
- The long-range Evade no-RNG correction is well justified.
- The workbook’s protocol atomicity and no-partial-deployment wording is otherwise adequate.

## 17. Missing Owner decisions or architecture conflicts

One genuine Owner decision remains:

**Replay compatibility boundary.** Choose one:

1. bump replay format to 8, reject format 7 before command application, and regenerate/review baseline fixtures; or
2. authorize a replay-only normalization/migration for the removed damage payload fields while continuing to reject them in live protocol-5 commands.

Given the repository’s existing replay-version policy and the workbook’s “remove, not retain as compatibility” stance, a format bump is the cleaner choice. That remains an Owner decision because the workbook currently excludes replay-format change.

The debug contract is an architecture conflict, not an open design decision: ADR-013 resolves it in favor of disabling that capability in live Network play.

No reopening of ADR-012 or ADR-013 is necessary.

## 18. Three most plausible residual production failure modes

### 1. Duplicate or differently ordered destruction cleanup

- **Mechanism:** authority and passive presentation both react to `ship_destroyed`; passive `submit_authoritative()` becomes a normal network submission; `DestroyUnitCommand` is repeatable.
- **Would current workbook verification catch it?** Not reliably. Generic exact-once tests and destruction helper tests may pass without exercising both player-ownership directions through the real EventBus/network seam.
- **Smallest refinement:** require a two-process lethal-damage test asserting one `DestroyUnitCommand`, authority-only generation, fixed ordering relative to attack continuation, and zero passive submission.

### 2. Hidden damage identity inferred through debug UI/rejection

- **Mechanism:** option availability and rejected named-card requests reveal hidden draw-pile membership.
- **Would current workbook verification catch it?** The broad secrecy canary could, but no listed test opens the production debug modal or exercises debug rejection.
- **Smallest refinement:** remove live Network debug damage and add an explicit test that the feature cannot submit while Network play is active.

### 3. Existing format-7 replay is silently misinterpreted or rejected mid-history

- **Mechanism:** old `card_data`/`draw_from_deck` payloads reach new strict commands under an unchanged accepted format number.
- **Would current workbook verification catch it?** No. The replay matrix can pass using newly recorded corrected histories.
- **Smallest refinement:** add an existing format-7 fixture test implementing the Owner-selected clean rejection or normalization boundary.

## 19. Exact workbook refinements required

1. Remove `DebugDealDamageCommand` from the live Network result catalog; retain it only for full local/Hot-Seat contexts.
2. Add `DebugController` to scope and require live Network debug damage to be unavailable before any hidden-deck query.
3. Specify destruction cleanup as exactly one authority-owned deterministic follow-up. Presentation may emit visuals but must not submit semantic cleanup.
4. Specify cleanup ordering relative to current-attack/BUG-035 and persistent-effect continuations.
5. Strengthen `DestroyUnitCommand` validation so stale/duplicate cleanup rejects.
6. Define exact allowed fields for every changed live semantic command and reject removed/unknown identity-bearing fields before execution and history.
7. Add explicit RNG rebinding after full authority deserialization and every replacement-deck rollback.
8. Add a rollback-then-reshuffle determinism regression in addition to save/load reshuffle.
9. Record the RNG-rebinding defect as within BUG-042 or as a named prerequisite that must land first.
10. Obtain the Owner replay-compatibility decision and update format, fixtures, scope, and tests accordingly.
11. Revise fresh bootstrap so authority publication has one clear linearization point and pre-publication failure has an enforceable rollback.
12. If retaining staging ACK plus installation ACK for fresh play, justify both as reuse of the existing bounded resume mechanism; do not create a generic bootstrap FSM.
13. Require the passive installer to consume ledger-only fields before full deserialization and require `StateFilter` to reject non-authority input.
14. Expand the negative-space inventory with the debug controller, passive `submit_authoritative` behavior, dead Evade helper, global setup randomness, and both replacement-deck sites.
15. Require real-process both-viewer equivalence through swapped assignments or an equivalent dual-view production harness.
16. Add production-seam regressions for live command unknown fields, debug exclusion, destruction exact-once, duplicate `resolve_damage`, and legacy replay disposition.
17. Replace the workbook claims “complete inventory,” “remaining Owner decision: none,” and “existing replay format unchanged” with the audited dispositions above.

## 20. Can it become implementation-authorizing?

**Yes, after those refinements and the replay compatibility decision.**

The accepted architectural direction does not need to change. Once the debug contradiction, destruction owner/order, RNG rebinding, replay boundary, strict command schemas, and bootstrap linearization are made explicit, the workbook can become a coherent single implementation specification.
