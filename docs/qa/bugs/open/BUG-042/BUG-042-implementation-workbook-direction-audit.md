1. Overall verdict: WRONG IMPLEMENTATION DIRECTION

The central ADR-012 direction is correct: passive RNG outcomes should be applied by the same command transaction, with `CommandProcessor` retaining validation, history, cursor, signaling, and exact-once ownership.

The workbook as a whole is not implementation-ready because its fresh filtered-bootstrap direction is incompatible with the current filtered canonical model. It would remove the client’s independently constructed damage deck without supplying a viable passive representation or application mechanism.

2. Implementation-direction assessment

- NO ISSUE — Result-aware passive execution belongs in the existing command transaction. The proposed `GameManager → CommandProcessor → concrete command` path correctly implements ADR-012 and does not create a second mutator.
- NO ISSUE — `GameManager`’s existing ordered buffer and `CommandProcessor`’s authoritative cursor are the smallest existing ordering/exact-once seams. Current code confirms that only the result is missing from the processor call: [game_manager.gd](/Users/Katharina/godot/Armada/src/autoload/game_manager.gd:2708), [command_processor.gd](/Users/Katharina/godot/Armada/src/autoload/command_processor.gd:192).
- BLOCKER — The proposed fresh filtered bootstrap is not viable through the unchanged filtered reconstruction surface.

3. Blockers

BLOCKER — Filtered damage-deck state is not reconstructible or usable.

`StateFilter` replaces the hidden draw pile with `draw_count` and replaces opponent facedown cards with `facedown_count` [state_filter.gd](/Users/Katharina/godot/Armada/src/core/network/state_filter.gd:47). But:

- `DamageDeck.deserialize()` ignores `draw_count`, reconstructing an empty deck [damage_deck.gd](/Users/Katharina/godot/Armada/src/core/damage/damage_deck.gd:176).
- `ShipInstance.deserialize()` ignores `facedown_count`, losing the opponent’s public damage count [ship_instance.gd](/Users/Katharina/godot/Armada/src/core/state/ship_instance.gd:897).
- `ResolveDamageCommand` validates the local deck count and draws cards locally [resolve_damage_command.gd](/Users/Katharina/godot/Armada/src/core/commands/resolve_damage_command.gd:91).
- Structural Damage also draws locally [resolve_immediate_effect_command.gd](/Users/Katharina/godot/Armada/src/core/commands/resolve_immediate_effect_command.gd:191).

Current fresh Network avoids this immediate failure only because both peers construct the same hidden deck from the shared seed. Removing that seed and installing the existing filtered state would let Roll Dice and reroll pass, then make ordinary ship-damage resolution fail or diverge.

This contradicts the workbook’s claim that setup/deck effects already reach the passive peer sufficiently through filtered publication [workbook](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/BUG-042-network-rng-authority-result-application-implementation-workbook.md:144). It activates the workbook’s own stop gate against broader `StateFilter`, `GameState`, and damage-deck changes.

4. Important findings

- IMPORTANT — `src/core/commands/game_command.gd` is missing from authorized production scope. The cleanest narrow seam is a base command result-application operation that rejects by default and is implemented only by authorized commands. Otherwise `CommandProcessor` needs a hard-coded four-command allowlist or untyped method probing.
- IMPORTANT — Fresh bootstrap ordering is underspecified. Ordinary Learning Scenario canonical construction still occurs in `GameBoard` after scene entry [game_board.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/game_board.gd:297), while the lobby currently publishes seed/config before transition [lobby_manager.gd](/Users/Katharina/godot/Armada/src/autoload/lobby_manager.gd:192). The workbook must specify host construction, initial command/cursor capture, targeted filtered staging, installation ACK, admission, and scene release—and prevent early `StartRound`/fixed-command result broadcasts from reaching an uninstalled client.
- IMPORTANT — A protocol version bump is required, not merely a possible stop gate. Protocol 4 is explicitly defined to change whenever message format changes [network_manager.gd](/Users/Katharina/godot/Armada/src/autoload/network_manager.gd:28). Removing the seed/config RPC contract and changing mirror result semantics makes old/new builds incompatible.
- IMPORTANT — Result schemas need exact allowed keys and types, not only minimum fields. Current transport adds `__remote_authored` inside the result dictionary [network_manager.gd](/Users/Katharina/godot/Armada/src/autoload/network_manager.gd:1481). The workbook must require transport metadata to be separated or stripped before strict command-result validation.
- IMPORTANT — The non-command/random inventory is incomplete. It should classify setup tie-break randomness, the legacy global-RNG Evade helper, scene-side damage-deck draws, and command paths consuming the hidden shuffled deck, even when the conclusion is “outside BUG-042 and unchanged.”
- IMPORTANT — BUG-035 shares `CommandProcessor`, `GameManager`, and current-attack regression files. Behavioral scope can remain isolated, but file-level isolation is impossible. The exact BUG-035 command-continuation and presentation/reconstruction suites must be mandatory regression gates.

5. Missing or over-broad production seams

Missing:

- `src/core/commands/game_command.gd`, or an explicitly selected processor-side allowlist alternative.
- A settled hidden damage-deck/facedown-count passive reconstruction seam.
- Explicit fresh-start staging/ACK/admission semantics for both ordinary Learning Scenario and setup-package starts.
- The required protocol-version cutover and handshake compatibility tests.

The listed `CommandProcessor`, `GameManager`, `NetworkManager`, `LobbyManager`, and four command files are otherwise justified and appropriately bounded.

No broad replay, save-schema, history, principal, or current-attack redesign is required for the four direct RNG commands.

6. Command-result contract assessment

For the four direct `GameState.rng` consumers: NO ISSUE, subject to exact schema typing.

- Roll Dice: complete ordered dice plus attack identity is sufficient.
- Swarm reroll: old/new result, index, source, and complete post-array are sufficient to prove unchanged surrounding dice.
- Concentrate Fire token reroll: sufficient for atomic dice, resolution, and token-cost mutation.
- Select Evade: sufficient for both removal and reroll branches; range, pending token, and defense progression are available in filtered pre-state.

Their required legality is derivable from public current-attack, unit, token, position, flow, and timing state. None requires seed, future stream, or deck order.

The contracts must additionally prescribe strict integer/dictionary/array shapes, exact extra-field policy, equality with duplicated command fields, and metadata stripping.

7. Fresh bootstrap/resume/reconnect assessment

- Resume/reconnect RNG direction: correct. Existing filtered installation and cursor staging can support result-aware commands once the processor seam exists.
- Fresh bootstrap RNG direction: normatively correct but operationally blocked.
- Fresh/bootstrap production seam: incomplete because initial construction currently happens after scene transition, and the filtered model cannot represent later hidden-deck operations.
- A fresh passive peer would not yet be a generally playable canonical mirror.

8. Replay/save/non-command RNG assessment

- NO ISSUE — Authority save/load can remain unchanged and continue persisting full RNG state.
- NO ISSUE — Replay can remain seed-plus-command-history deterministic re-execution with no live result persistence, as ADR-012 requires [ADR-012](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-012-live-network-rng-authority-and-result-application.md:174).
- IMPORTANT — Non-command setup RNG should remain outside the new command-result mechanism, but the workbook has not proven that its realized hidden-deck effects have a sufficient existing publication path. They do not currently.
- No replay format or save-schema migration is justified.

9. Regression-matrix assessment

The RNG-specific matrix is strong, but it can pass while fresh production remains defective.

The fresh test presently stops after Roll Dice plus one reroll [workbook](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/BUG-042-network-rng-authority-result-application-implementation-workbook.md:254). It must also:

- exercise the real lobby start for both ordinary scenario and setup-package variants;
- continue a ship attack through `ResolveDamageCommand`;
- prove public damage/deck counts remain correct without exposing card order;
- use actual authority submission, RPC delivery, filtered installation, ACK, and passive result application;
- prove no initial command result is lost or applied before snapshot installation;
- assert protocol mismatch rejection across the cutover;
- run the focused BUG-035 convergence suites.

Without this, the real fresh-bootstrap defect can survive all proposed RNG assertions.

10. Slice-order/convergence assessment

IMPORTANT — The slice order is only safe if Slices 1–2 form one non-deployable migration unit. “One command at a time” temporarily creates a mixed mirror model.

Required convergence rule:

1. Add the dormant processor/base-command seam.
2. Implement and verify all authorized result contracts.
3. Do not deploy or accept an intermediate four-command catalog.
4. Resolve the hidden-deck stop gate.
5. Cut over fresh bootstrap and protocol version atomically.
6. Run production-path integration.

Slice 3 must not begin merely because the four dice commands pass.

11. Stop-gate assessment

A stop gate is triggered now.

The current filtered pre-state cannot support all canonical mutations needed after fresh bootstrap without hidden deck inputs, broader filtered-state representation, or additional viewer-specific result application. This matches ADR-012’s prohibition on requiring hidden authority inputs [ADR-012](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-012-live-network-rng-authority-and-result-application.md:125).

Protocol versioning is not itself a stop gate; it is a required narrow implementation action.

12. Is any Owner decision still missing?

The RNG decision is fully settled.

One adjacent decision is missing: how passive mirrors represent and apply hidden damage-deck draws and opponent facedown damage after filtered fresh/resume/reconnect installation. That decision must choose or authorize a bounded model, such as viewer-specific command-owned application with opaque public counts versus a revised filtered canonical representation.

It must not be improvised inside BUG-042.

13. Exact refinements required before acceptance

1. Change the current stop-gate status from clear to triggered.
2. Resolve and record the hidden damage-deck/facedown-count authority model, either in this workbook after Owner approval or in a prerequisite companion specification.
3. Add `game_command.gd` to authorized scope or explicitly mandate a processor-side four-command allowlist.
4. Define exact result schemas, types, allowed keys, command/result equality checks, and handling of `__remote_authored`.
5. Specify the complete fresh-start construction/staging/ACK/admission transaction and both fresh-start variants.
6. Require a protocol version bump and mismatch regression.
7. Make all four command conversions one non-deployable convergence unit.
8. Extend fresh production evidence through ship damage, public filtered-count convergence, and hidden-card non-disclosure.
9. Inventory all current random/hidden-deck consumers and prove each is authority-only, result/payload-driven, dead, or outside scope.
10. Add explicit BUG-035 regression gates.
11. Correct the stale “Pending ADR-012 acceptance” wording in CON-001 separately; it is administrative and does not reopen the accepted RNG decision.

14. Can it become the single implementation specification?

Not through small editorial refinement alone.

After the hidden damage-deck decision is settled and incorporated, and the missing command/protocol/bootstrap/test seams above are made explicit, the workbook can become the single implementation specification. Until then, it cannot safely authorize implementation.

No files were modified, no implementation was performed, and no tests were run.
