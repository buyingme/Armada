## 1. Overall verdict

**PASS WITH REQUIRED REFINEMENTS**

The proposed decimal-string representation, save-format 10 cutover, existing signing algorithm, replay-11 retention, and protocol-10 retention are architecturally sound. No blocker or new architecture decision was found.

The workbook should not be accepted for implementation until the refinements below are incorporated.

## 2. Blockers

None.

## 3. Required refinements

1. **Close the complete RNG schema, not only the two values.**
   The workbook should explicitly require that `rng` is a dictionary containing exactly `initial_seed` and `state`. Reject an invalid container, extra keys, `null`, booleans, arrays, and dictionaries used as field values. Current deserialization treats RNG as optional and only binds it when non-empty ([game_state.gd](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:1224)).
   Smallest correction: extend Sections 3 and 7 with the exact two-key schema and corresponding rejection matrix.

2. **Make the int64 boundary tests unconditional.**
   Godot 4.5.1 accepts `INT64_MIN`, `INT64_MAX`, and zero as `RandomNumberGenerator.state`; it accepts both limits as seeds. Overflow text wraps during `to_int()`, but re-encoding equality rejects it.
   Smallest correction: require exact acceptance of `-9223372036854775808` and `9223372036854775807` for both fields; reject `-9223372036854775809` and `9223372036854775808`; accept state `"0"` and reject initial seed `"0"`.

3. **Cover persisted version-9 checkpoints explicitly.**
   Startup checkpoint restoration currently verifies the signature but does not check the save version before caching the payload ([save_game_manager.gd](/Users/Katharina/godot/Armada/src/autoload/save_game_manager.gd:105)); checkpoint load later applies the correct version gate ([save_game_manager.gd](/Users/Katharina/godot/Armada/src/autoload/save_game_manager.gd:395)).
   Smallest correction: add a persisted, validly signed version-9 checkpoint regression proving it cannot install and returns `version_unsupported`. It must never be rewritten or re-signed as version 10.

4. **Prevent a false-positive StateFilter test.**
   The existing RNG canary mutates the fields to JSON numbers and merely asserts they do not appear in the filtered output ([test_state_filter.gd](/Users/Katharina/godot/Armada/tests/unit/test_state_filter.gd:326)). After strict decoding, filtering could fail to `{}` and that test would still pass.
   Smallest correction: use canonical string canaries, call `filter_for_player_checked()`, assert `ok`, assert the result is non-empty, then assert the entire `rng` member is absent.

5. **Require actual post-resume RNG consumption over Network.**
   The current wording requires host restoration before “later authoritative consumption” but does not unambiguously require that consumption.
   Smallest correction: require a format-10 Network authority resume using values beyond `2^53`, followed by a real `RollDiceCommand` or equivalent production transaction. Assert the result matches an uninterrupted authority, host RNG state advances identically, the passive peer still has `rng == null`, and the passive result application converges.

6. **Clarify the replay-only seed RPC exception.**
   Ordinary live fresh start/resume/reconnect uses filtered snapshots with no RNG ([network_manager.gd](/Users/Katharina/godot/Armada/src/autoload/network_manager.gd:500)). The existing seed-bearing configuration RPC is retained only for Network replay bootstrap ([lobby_manager.gd](/Users/Katharina/godot/Armada/src/autoload/lobby_manager.gd:203), [lobby_manager.gd](/Users/Katharina/godot/Armada/src/autoload/lobby_manager.gd:241)).
   Smallest correction: state that the stop gate concerns a new **live-authority** RNG RPC; the existing replay-seed bootstrap remains permitted and unchanged.

7. **Strengthen baseline renewal classification.**
   Unchanged replay and Hot-Seat trace plus a changed hash do not alone prove that only two JSON types changed.
   Smallest correction: before promotion, require a structural pre-repair/post-repair comparison of the final serialized state from the unchanged replay, allowing differences only at `rng.initial_seed` and `rng.state`, with equal decoded int64 values. Also clarify that only the committed Hot-Seat trace must remain byte-identical; Network diagnostic traces are timing-dependent and are not byte-equality oracles.

## 4. Optional improvements

- Name the production continuation operation in the workbook instead of leaving implementer choice open; `RollDiceCommand` is the clearest cross-boundary proof.
- Update the stale `GameRng` comment implying live seeds are transmitted to all clients.
- Parameterize malformed-value tests so both RNG fields receive the same complete rejection matrix.

## 5. Save-version/compatibility assessment

Save format **9 → 10 is correct and necessary**. The representation change is breaking, format 9 cannot recover lost bits, and current named-save and checkpoint load paths already have strict current-version gates.

No migration, approximation, or compatibility adapter is needed. No other durable format boundary is affected. App version, fleet formats, setup-package formats, and trace format need not change.

## 6. Replay assessment

Replay format **11 can remain unchanged**:

- replay already writes `rng_seed` as a canonical decimal string;
- it does not persist current RNG state;
- replay remains seed-plus-command-history reconstruction;
- existing replay files and command histories need no conversion or rerecording.

Only the Hot-Seat final-state hash changes because `GameState.serialize()` changes the two RNG leaf types.

## 7. Network/ADR-012 assessment

Network protocol **10 can remain unchanged**.

Ordinary fresh start, resume, and reconnect filter the full authority representation and erase RNG before publication ([state_filter.gd](/Users/Katharina/godot/Armada/src/core/network/state_filter.gd:35)). Passive deserialization rejects any RNG-bearing snapshot. Ordinary reconnect does not JSON-round-trip the host RNG.

ADR-012’s passive omission remains valid. The authority alone must restore and consume the exact RNG; passive peers apply command-owned realized results. The replay-only seed bootstrap is a different ADR-012 execution context.

## 8. Signing/hash assessment

The existing HMAC algorithm can remain unchanged. Decimal strings survive `IntegritySigner`’s normalization round-trip exactly ([integrity_signer.gd](/Users/Katharina/godot/Armada/src/utils/integrity_signer.gd:83)).

The critical regression is correctly identified: signature validity must not imply schema validity. A correctly signed format-10 payload containing numeric, malformed, or noncanonical RNG data must still fail as `schema_invalid`.

Pre-save/post-load canonical hashes must match exactly. Baseline hash promotion additionally needs the structural comparison described above.

## 9. Verification sufficiency

After the required refinements, the verification package is sufficient to prevent recurrence. In particular, it combines:

- actual JSON and signed-file boundaries;
- exact field and hash equality;
- malformed signed input rejection;
- next RNG output equality;
- a real production RNG-consuming transaction;
- Network authority continuation with passive RNG absence;
- unchanged replay inputs and command trace;
- controlled state-hash renewal.

As currently written, the StateFilter false-positive risk, checkpoint omission, Network continuation ambiguity, and insufficiently constrained baseline renewal leave avoidable holes.

## 10. Remaining Owner decisions

- Accept the corrected workbook and authorize implementation.
- Review and authorize promotion of the new Hot-Seat state-hash fixture.
- Separately authorize any GGS-001 Gate 2 continuation after repaired Gate 1 evidence.

No further Owner decision is needed for encoding, migration, replay version, Network protocol, or RNG authority. Automatic deletion of obsolete version-9 checkpoints—rather than safe rejection—is an optional UX/lifecycle decision.

## 11. Implementation readiness

Not ready under the workbook’s current Draft status.

After the required refinements and Owner acceptance, the repair is bounded and ready to implement without migration, serializer abstraction, RNG-authority changes, GGS-specific behavior, replay 12, or protocol 11.

## 12. Files changed and verification performed

No repository files were changed. The pre-existing untracked workbook, diagnosis, measurements, and experimental test remain untouched. `git diff --check` passed.

Verification performed:

- Reproduced Gate 1: **97/98 assertions**, exact mismatch `5975857563556095516 → 5975857563556096000`.
- Existing focused suites: **137/137 tests, 519 assertions passed**.
- Network resume/reassociation integration: **12/12 tests, 128 assertions passed**.
- Hot-Seat trace/hash and Network peer-equality baselines passed.
- Real ENet fresh-resume acceptance passed under protocol 10.
- Probed Godot 4.5.1 int64 limits, overflow behavior, canonical spellings, zero state, and RNG property acceptance.
