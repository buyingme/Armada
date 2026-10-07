# Exact Authoritative RNG Save Serialization Repair Implementation Workbook

Status: Owner Accepted — 2026-10-07

Purpose: authorize only the bounded production correction required to preserve
exact authoritative RNG seed and current state through the real JSON save/load
boundary. This workbook does not implement the repair.

Primary evidence:

- [GGS-001 RNG JSON serialization diagnosis](../evidence/GGS-001-rng-json-serialization-diagnosis.md)
- [GGS-001 Gate 1 measurements](../evidence/GGS-001-b-lite-prototype-measurements.md)
- [Independent workbook audit](../evidence/exact-authoritative-rng-save-serialization-repair-workbook-audit.md)

Related boundaries and work:

- `BC-008` / `AT-009` — Save/Load and Checkpoint Boundary;
- `BC-009` / `AT-008` — Replay, baseline, Network, and state-filtering review;
- accepted [ADR-012](../adr/ADR-012-live-network-rng-authority-and-result-application.md);
- accepted [ADR-011](../adr/ADR-011-network-match-resume-and-principal-entitlement.md).

## 1. Classification, Authority, And Entry Decision

Classification: **Bounded Architecture / BOUNDED CROSS-CUTTING repair**.

Accepted ADR-012 already requires authority save/load to preserve the complete
RNG seed and current state and to restore that exact state before later
authoritative RNG consumption. The diagnosis establishes the concrete defect
and owning production path. No RNG ownership, replay, Network, or generic
serialization decision remains open.

The Project Owner has fixed the compatibility policy for this repair:

1. development saves using the lossy numeric RNG representation may be
   invalidated and discarded;
2. no migration, approximate reconstruction, compatibility adapter, header
   rewrite, or best-effort recovery is required or permitted; and
3. new saves must preserve the exact authoritative RNG state.

Lost low bits in an already parsed legacy number are not recoverable. This
workbook therefore specifies a hard save-format cutover rather than a
migration.

Entry status: the diagnosed decimal-string direction has no concrete
repository blocker. `GameReplay` already uses a strictly decoded exact decimal
string for its signed 64-bit RNG seed, providing a local precedent. This
workbook remains Draft until independently audited and accepted by the Project
Owner.

## 2. Required Outcome And Invariants

After the repair:

1. Full-authority `GameState.rng` serializes as a dictionary with exactly the
   two keys `initial_seed` and `state`; both values are exact canonical decimal
   strings, never JSON numbers.
2. Each field round-trips across `JSON.stringify()` and Godot `JSON.parse()`
   without value or type ambiguity.
3. Deserialization accepts only the complete new exact representation for
   current full-authority saves, validates the complete signed 64-bit range
   and canonical spelling, and fails closed on an invalid container, missing
   or extra keys, or malformed values.
4. A loaded authoritative state has exactly the same RNG initial seed and
   current state as its uninterrupted source.
5. The next authoritative RNG outcome after load equals the next outcome from
   the uninterrupted source state, and both streams remain aligned after that
   outcome.
6. The complete canonical `GameState` hash before save equals the canonical
   hash immediately after load when no gameplay has occurred between them.
7. Damage-deck RNG rebinding after `GameState.deserialize()` continues to bind
   the restored exact `GameRng`; no second RNG is constructed.
8. Signed save verification covers the exact strings and rejects tampering.
9. Version-9 and other non-current saves reject before state installation.
10. Replay remains format 11 seed-plus-command-history reconstruction.
11. Passive Network state continues to contain no RNG, and Network protocol 10
    continues to transport no live seed or current RNG state to passive peers.
12. GGS-001 remains paused and Gate 2 remains unauthorized.

## 3. Selected Representation

The canonical full-authority RNG dictionary SHALL have this shape:

```text
rng:
  initial_seed: "<canonical signed decimal int64>"
  state: "<canonical signed decimal int64>"
```

The `rng` member SHALL be present for a full-authority representation, SHALL be
a `Dictionary`, and SHALL contain exactly those two keys. `null`, a boolean, a
number, a string, an array, an empty dictionary, a one-key dictionary, or a
dictionary with any extra key SHALL reject. Each field value SHALL itself be a
string; `null`, booleans, arrays, and dictionaries used as field values SHALL
reject. This full-authority schema does not alter the accepted passive Network
representation, where `rng` must remain absent.

Both values SHALL be produced from the owning integer with the engine's
canonical decimal conversion. Decoding SHALL require:

- value type is `String`;
- non-empty signed base-10 integer text;
- successful conversion within the signed 64-bit range;
- re-encoding the parsed integer produces exactly the input text; and
- `initial_seed` is non-zero, preserving `GameRng`'s existing rule that zero
  requests random initialization rather than identifying a reproducible seed.

The re-encoding equality rejects leading zeroes, `+` prefixes, whitespace,
`-0`, exponent notation, decimal points, and overflow-clamped text. The
current state SHALL be assigned after construction even when its parsed value
is zero; zero must not act as a deserialization sentinel.

`GameRng.deserialize()` SHALL return failure for an absent, numeric, floating,
malformed, out-of-range, or non-canonical field. `GameState.deserialize()`
SHALL validate the `rng` container as a `Variant` before any dictionary cast,
propagate codec failure, and return `null` for a full-authority representation
containing invalid RNG data. It SHALL NOT treat RNG as optional, randomize,
round, clamp, substitute zero, retain a partially reconstructed authority
state, or fall back to the legacy numeric interpretation.

The decimal validator should remain private to `GameRng` unless an already
existing exact-integer helper can be reused without broadening ownership.
This repair does not authorize a generic JSON codec or serialization
framework.

## 4. Save-Format Cutover And Compatibility

Advance:

```text
SaveGameMetadata.CURRENT_VERSION: 9 -> 10
```

Save format 10 owns the exact decimal-string RNG representation. Existing
version checks SHALL reject format 9 and every other non-current version before
state installation. No format-9 decoder or migration branch is authorized.

Additional fail-closed requirements:

- a format-10 payload carrying numeric RNG fields rejects as `schema_invalid`;
- a format-10 payload with only one RNG field, malformed text, non-canonical
  text, or an out-of-range value rejects as `schema_invalid`;
- changing a signed RNG string without a valid new signature rejects as
  `signature_invalid`; and
- version rejection remains distinct from schema and signature rejection.

The normal signed save path remains:

```text
GameRng.serialize()
-> GameState.serialize()
-> IntegritySigner.sign()
-> SaveFileStore.write_payload(JSON)
-> SaveGameManager.load_game(JSON parse)
-> IntegritySigner.verify()
-> GameState.deserialize()
-> GameRng.deserialize()
```

`IntegritySigner` requires no format or algorithm change: JSON strings survive
its normalization round-trip exactly. Implementation must prove that the
existing signer signs and verifies the new representation and detects string
tampering. Do not modify signing canonicalization unless focused evidence
shows the string representation fails that proof; such evidence triggers the
stop gate in Section 10.

Named authoritative saves and any persisted checkpoint payload using the
current save metadata boundary receive the same version-10 representation.
No separate checkpoint codec is permitted. A validly signed persisted
version-9 checkpoint may be discovered and cached by the existing startup
restoration path, but `load_game_from_checkpoint()` SHALL return
`version_unsupported` and SHALL NOT install, rewrite, re-sign, promote, or
reinterpret it as version 10. Automatic deletion of that obsolete checkpoint
is not required by this workbook.

## 5. Authorized Production Scope

| File or surface | Authorized bounded change |
| --- | --- |
| `src/core/state/game_rng.gd` | Serialize both fields as canonical decimal strings; add strict local signed-int64 decoding; reject zero `initial_seed`; restore `state` exactly without a zero sentinel; update the stale comment that implies ordinary live seeds are transmitted to all clients so it reflects ADR-012 without changing behavior. |
| `src/core/state/game_state.gd` | Propagate `GameRng.deserialize()` failure so malformed full-authority RNG data cannot produce an installable `GameState`; preserve damage-deck binding to the successfully restored RNG. |
| `src/core/state/save_game_metadata.gd` | Advance save format 9 to 10 and retain the existing strict current-version boundary. |
| `src/autoload/save_game_manager.gd` | Only adjustments directly required for version-10 failure classification or exact production integration tests. No migration or alternate load path. |
| `src/utils/integrity_signer.gd` and `src/utils/save_file_store.gd` | Verification surfaces only; no production change is expected. A required algorithm/container change stops implementation for review. |
| Version-coupled tests | Update assertions that intentionally name the current save version from 9 to 10 and add explicit format-9 rejection. Do not change replay or Network version expectations. |
| Focused RNG/save tests | Add the exact, malformed, signing, hashing, and next-outcome coverage in Sections 7 and 8. |
| Hot-Seat canonical state-hash fixture | After implementation acceptance and review, regenerate only the affected state-hash evidence through the existing baseline workflow. Keep the recorded replay and command trace unchanged. |

No other production file is authorized unless the implementation discovers a
direct caller that cannot compile or fail closed after `GameRng.deserialize()`
becomes nullable. Any such addition must remain a mechanical propagation of
the same failure contract and be reported explicitly; semantic expansion
triggers the stop gate.

## 6. Explicitly Excluded

This workbook does not authorize:

- RNG authority, algorithm, stream, seed-selection, or consumer redesign;
- replacement of Godot `RandomNumberGenerator`;
- replay format, replay seed policy, command history, or replay fixture
  redesign;
- Network protocol, RPC envelope, state-filtering, reconnect, or result-
  application redesign;
- transmission or reconstruction of RNG on passive peers;
- a generic exact-integer/JSON serialization framework;
- a binary save container or signing redesign;
- migration, approximation, repair, or reinterpretation of format-9 saves;
- GGS schema, runner, capture, fixture, infrastructure, or workbook changes;
- weakening Gate 1 exact equality; or
- continuation to GGS Gate 2.

## 7. Focused Codec And Failure Regressions

Add focused `GameRng` tests proving:

1. `serialize()` returns `TYPE_STRING` for both fields.
2. Representative positive and negative values beyond `2^53`, including the
   observed `5975857563556095516`, survive an actual
   `JSON.stringify()` -> `JSON.parse_string()` -> `GameRng.deserialize()`
   round-trip exactly.
3. `-9223372036854775808` and `9223372036854775807` are accepted and survive
   exactly for both fields. `-9223372036854775809` and
   `9223372036854775808` reject for both fields even though engine conversion
   may wrap overflow text.
4. The next `randi()` and a bounded `randi_range()` result after reconstruction
   match the uninterrupted source stream.
5. A current state of `"0"` is accepted and explicitly restored rather than
   treated as “not present.”
6. For each of `initial_seed` and `state`, one parameterized rejection matrix
   covers numeric integer, floating, missing, `null`, boolean, array,
   dictionary, empty, leading-zero, `+`-prefixed, whitespace, `-0`, exponent,
   decimal, and out-of-range encodings.
7. `initial_seed == "0"` rejects rather than randomizing.
8. The full `rng` container rejects when absent, `null`, boolean, numeric,
   string, array, empty, missing either required key, or carrying any extra
   key.
9. Every invalid container or field case causes `GameState.deserialize()` to
   return `null` without partial authority reconstruction.

These tests SHALL exercise the JSON boundary. An in-memory dictionary-only
round-trip is supporting evidence and cannot satisfy this gate.

## 8. Production Save/Load Integration Regressions

Use `SaveGameManager.save_game()` and `load_game()` with the real signed JSON
file path. The primary fixture SHALL install an exact large signed 64-bit seed
and an advanced large current state, then prove all of the following:

1. The written JSON contains quoted decimal strings for both RNG fields.
2. Reading the file through the production JSON parser retains both fields as
   strings with exact text.
3. Integrity verification succeeds for the untouched file.
4. The loaded `GameState` has exact `initial_seed` and `state` equality with
   the uninterrupted source.
5. `CanonicalJson.hash(source.serialize())` equals
   `CanonicalJson.hash(loaded.serialize())` before either branch advances.
6. The next authoritative random outcome on the loaded branch equals the next
   outcome on the uninterrupted branch.
7. At least one existing production RNG-consuming transaction or authoritative
   deck operation is executed on equivalent uninterrupted and loaded branches;
   its result, resulting RNG state, and relevant canonical state must match.
8. Saving and loading the restored state a second time remains exact.
9. A tampered digit in either RNG string fails signature verification without
   state installation.
10. A correctly signed format-10 payload with malformed or numeric RNG fields
    fails schema validation, proving the signature cannot legitimize a lossy
    representation.
11. A valid signed format-9 save rejects as `version_unsupported`; it is not
    parsed through a compatibility decoder.
12. A validly signed persisted version-9 checkpoint may be restored into the
    existing checkpoint cache, but loading it returns `version_unsupported`;
    its file/header/body remain byte-for-byte unchanged and are never re-signed
    or rewritten as version 10.

The integration fixture must use values known to be outside binary64's exact
integer range. Small seeds alone are insufficient.

## 9. Replay, Network, Hash, And Baseline Review

### Replay 11

`GameReplay.FORMAT_VERSION` and `SIGNED_FORMAT_VERSION` remain **11**.
Replay already encodes `rng_seed` as a canonical decimal string and does not
persist current `GameRng.state`. No replay schema or command changes occur.

Required evidence:

- focused replay file JSON round-trip still preserves a large signed seed;
- existing replay-11 fixtures load without alteration;
- replay command histories and the committed Hot-Seat trace remain
  byte-identical; and
- Hot-Seat replay reaches the same gameplay result, with only the expected
  canonical final-state hash representation changing.

No replay recording is required for this cutover. Existing replay JSON files
must remain byte-for-byte unchanged. If a replay or command trace changes,
stop and diagnose rather than renew it.

### Network protocol 10

`NetworkManager.PROTOCOL_VERSION` remains **10**. The representation change is
inside full-authority `GameState` persistence. `StateFilter` removes `rng`
before passive publication, and the typed RPC snapshot carries no RNG field.
The existing seed-bearing configuration RPC remains permitted solely for
Network replay bootstrap and remains unchanged; it is not an ordinary live
fresh-start, resume, or reconnect RNG transport.

Required evidence:

- a canonical string-canary test calls `filter_for_player_checked()`, asserts
  `ok == true`, asserts a non-empty filtered state, and then asserts the entire
  `rng` member is absent; absence from `{}` is not a valid test result;
- passive deserialization continues to reject any snapshot containing RNG;
- fresh start and ordinary reconnect retain their existing behavior;
- a format-10 Network authority resume uses seed/state values beyond `2^53`,
  installs the exact host RNG, and then executes a real `RollDiceCommand` on
  the resumed authority; its result and advanced host RNG state equal an
  uninterrupted authority branch, the passive peer retains `rng == null`, and
  command-owned passive result application converges to the authorized public
  result; and
- the Network baseline host/client equality check passes under protocol 10.

If implementation requires a new live-authority RNG-bearing RPC, passive RNG
reconstruction, or wire-schema change, stop. This stop gate does not prohibit
or change the existing replay-only seed bootstrap. This workbook does not
authorize a protocol cutover.

### Canonical hashes and baseline evidence

Changing the two canonical values from JSON numbers to strings intentionally
changes full-authority canonical state hashes. It does not change gameplay,
commands, command ordering, or trace schema.

After focused tests pass:

1. run the existing baseline verifier and classify the Hot-Seat final-state
   hash difference as the expected representation-only change;
2. before promotion, structurally compare the final serialized state produced
   by the unchanged replay before and after the repair; allow differences only
   at `rng.initial_seed` and `rng.state`, require the old leaves to be numbers,
   the new leaves to be canonical strings, and require their decoded signed
   64-bit values to be equal;
3. require the committed Hot-Seat JSONL trace to remain byte-identical; Network
   traces are timing-dependent diagnostics and are not byte-equality oracles;
4. use the normal candidate-generation transaction to regenerate the Hot-Seat
   state-hash evidence from the unchanged recorded replay;
5. review and promote only
   `tests/fixtures/baseline_traces/baseline_state_hash_hot_seat_solo.txt`;
6. do not replace `replay_hot_seat_solo.json`, the Hot-Seat JSONL trace, the
   Network replay, or any command fixture; and
7. rerun Hot-Seat and Network baseline verification after promotion. Network
   diagnostic traces and hashes remain uncommitted.

Fixture maintenance remains subject to the repository's
[Replay Baseline Workflow](../../development/REPLAY_BASELINE_WORKFLOW.md) and
the replay-fixture rules in [CODEX_WORKFLOW](../CODEX_WORKFLOW.md). Promotion is
a reviewed evidence step, not an automatic test update.

## 10. Implementation Sequence And Stop Gates

### Slice 1 — exact RNG codec

- Implement the string representation and strict local decoder.
- Add focused JSON-boundary and malformed-input tests.
- Make `GameState` propagate decoder failure.

Gate: exact field equality and next-output equality pass for large positive
and negative signed values.

### Slice 2 — save-format cutover and production round-trip

- Advance save format 9 to 10.
- Update intentional current-version assertions.
- Add real signed-file save/load, signature, hash, continuation, repeated-
  round-trip, and format-9 rejection tests.

Gate: the complete production boundary preserves exact state and deterministic
continuation; format 9 rejects without migration.

### Slice 3 — bounded cross-boundary verification

- Prove replay remains format 11 and unchanged.
- Prove passive Network filtering still removes RNG and protocol remains 10.
- Run relevant save/load and Network-resume integration coverage.
- Generate and review only the expected Hot-Seat state-hash candidate, then
  follow the authorized promotion workflow.

Gate: no unexplained replay, command-trace, Network, or canonical-state
divergence remains.

Stop and return to the Owner or independent auditor if any slice requires:

- recovery or loading of format-9 RNG data;
- changing the RNG algorithm or accepted authority model;
- replay format 12, Network protocol 11, or a new live-authority transported
  RNG field outside the unchanged replay-only bootstrap;
- a generic serializer, binary container, or integrity algorithm change;
- replacement or editing of recorded replay inputs;
- command/gameplay changes rather than representation-only changes;
- modification of GGS code, tests, workbook, or infrastructure to make the
  production repair pass; or
- material scope beyond the production/test surfaces in Section 5.

## 11. Required Verification Before Handoff

At minimum, implementation must run and report:

- focused `GameRng` tests;
- focused `SaveGameManager` and full save/load round-trip tests;
- persisted version-9 checkpoint rejection without rewrite or re-signing;
- affected save-version assertion suites;
- `GameReplay` exact-seed/file tests;
- `StateFilter` RNG-removal tests;
- the relevant Network resume/reconnect production integration or acceptance
  coverage;
- Hot-Seat and Network baseline verification under the unchanged replay and
  protocol versions;
- the unchanged Gate 1 feasibility test as secondary confirmation that the
  original exact-RNG assertion now passes, without authorizing Gate 2;
- repository formatting/static checks applicable to the touched GDScript; and
- `git diff --check` plus a final changed-file audit.

The final implementation evidence must identify:

- exact test values used;
- source, parsed-file, loaded, and post-next-outcome RNG states;
- pre-save and post-load canonical hashes;
- version-9 rejection result;
- replay-11 and protocol-10 preservation results;
- baseline files reviewed or promoted; and
- every changed production, test, and evidence file.

## 12. Independent Audit Dispositions

The preserved independent audit verdict was **PASS WITH REQUIRED
REFINEMENTS** and identified no blocker or new architecture decision. This
revision disposes every finding as follows:

| Audit finding | Workbook disposition |
| --- | --- |
| Blockers | None reported; no blocker disposition is required. |
| Required 1 — close the complete RNG schema | Sections 2, 3, and 7 now require a present dictionary with exactly `initial_seed` and `state`, reject invalid containers/values and extra keys, and require `GameState` to validate before casting and fail closed. |
| Required 2 — unconditional int64 boundaries | Section 7 now requires exact acceptance of both signed-int64 limits for both fields, rejection immediately outside both limits, acceptance of state `"0"`, and rejection of seed `"0"`. |
| Required 3 — persisted version-9 checkpoints | Sections 4, 8, and 11 now require a validly signed persisted version-9 checkpoint to reject at load as `version_unsupported` without rewrite, re-signing, promotion, or installation. |
| Required 4 — non-vacuous `StateFilter` test | Section 9 now requires canonical string canaries, checked filtering success, a non-empty result, and complete RNG-member absence. |
| Required 5 — actual Network post-resume consumption | Section 9 names `RollDiceCommand` and requires exact resumed/uninterrupted result and host-state equality plus passive RNG absence and result-application convergence. |
| Required 6 — replay-only seed RPC exception | Section 9 and the stop gates now distinguish the unchanged replay-only seed bootstrap from a prohibited new live-authority RNG transport. |
| Required 7 — baseline renewal classification | Section 9 now requires a structural before/after state comparison limited to the two RNG leaves with equal decoded values, Hot-Seat trace byte equality, and treats Network traces only as timing-dependent diagnostics. |
| Optional — name the continuation operation | Incorporated: `RollDiceCommand` is mandatory for the Network resume continuation proof. |
| Optional — correct stale `GameRng` comment | Incorporated in the authorized `game_rng.gd` scope as a factual ADR-012-aligned comment correction only. |
| Optional — parameterize malformed values | Incorporated: Section 7 requires the same complete parameterized rejection matrix for both fields. |

No audit finding is deferred. Automatic deletion of obsolete version-9
checkpoints remains an optional UX/lifecycle decision and is deliberately not
required; safe version rejection fully satisfies the Owner's discard policy.

## 13. Size, Risk, And Completion Boundary

Estimated implementation size: **Small–Medium code change; Medium verification
package**.

Risk: **Medium–High** because the code change is narrow but alters durable
canonical representation, signing input, deterministic continuation, and the
committed final-state hash oracle. The hard discard decision removes migration
complexity and keeps the repair bounded.

The repair is complete only when all Section 2 invariants and Sections 7–11
verification pass, the reviewed version-10 state-hash evidence is installed,
and no unexpected replay or Network cutover is required.

No newly discovered conflict or remaining encoding, compatibility, replay,
Network, or RNG-authority decision is known. The remaining Owner actions are
to accept the closure-audited workbook before implementation, separately
review and authorize promotion of the changed Hot-Seat state-hash fixture, and
separately authorize any later GGS Gate 2 continuation. Targeted closure audit
must verify the audit-disposition table, strict schema/decoder, format-9 named
save and checkpoint rejection, production and Network `RollDiceCommand`
continuation proofs, structural baseline comparison, and preservation of
replay 11 / Network protocol 10.

GGS-001 remains paused after this repair workbook is drafted. Successful
production repair does not itself authorize Gate 2; the Owner must separately
review the repaired Gate 1 evidence and explicitly authorize any GGS
continuation.
