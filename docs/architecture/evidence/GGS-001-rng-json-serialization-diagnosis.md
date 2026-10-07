# GGS-001 RNG JSON Serialization Diagnosis

Status: **Bounded diagnosis complete — Owner routing required**

Evidence date: 2026-10-07

Classification: **BOUNDED CROSS-CUTTING**

Related boundaries: `BC-001`, `BC-007`, `BC-008`, `BC-009`

Trigger:

- [GGS-001 Gate 1 measurements](GGS-001-b-lite-prototype-measurements.md)
- [GGS-001 Gate 1 feasibility test](../../../tests/experimental/ggs/test_maneuver_obstacle_order_s0_feasibility.gd)

Normative authority:

- [ADR-012](../adr/ADR-012-live-network-rng-authority-and-result-application.md)
- [ADR-011](../adr/ADR-011-network-match-resume-and-principal-entitlement.md)

This record is implementation evidence and diagnosis. It does not select a
serialization format, change a compatibility boundary, authorize a repair, or
continue GGS-001.

## 1. Verdict

The failure is an existing production authority save/load defect exposed by
GGS-001, not an experimental reconstruction defect.

`GameRng.serialize()` emits both `initial_seed` and the current native RNG
`state` as signed 64-bit integers. `GameState.serialize()` places that
dictionary directly in the authoritative state representation. The production
save path writes the representation as JSON numbers, and the production load
path parses those numbers through Godot `JSON`, which represents them as
floating-point values. Values outside the exact binary64 integer range can be
rounded before `GameRng.deserialize()` assigns them back to typed integers.

Gate 1 observed the current state change from `5975857563556095516` to
`5975857563556096000`. The same sequence is reachable through a normal signed
save and load.

Accepted [ADR-012](../adr/ADR-012-live-network-rng-authority-and-result-application.md)
already requires an authority save to preserve the full seed and current RNG
state and a load to restore that exact state before later authoritative RNG
consumption. No new RNG reconstruction contract is needed.

## 2. Owning production path

The lossy production path is:

1. `GameRng.serialize()` returns numeric `initial_seed` and `state`
   ([game_rng.gd](../../../src/core/state/game_rng.gd#L70)).
2. `GameState.serialize()` installs that dictionary as `state.rng`
   ([game_state.gd](../../../src/core/state/game_state.gd#L1044)).
3. `SaveGameManager.save_game()` signs that body and delegates persistence
   ([save_game_manager.gd](../../../src/autoload/save_game_manager.gd#L145)).
4. `SaveFileStore.write_payload()` writes it with `JSON.stringify()`
   ([save_file_store.gd](../../../src/utils/save_file_store.gd#L33)).
5. `SaveGameManager.load_game()` parses it with `JSON.parse()` and passes the
   parsed body to `GameState.deserialize()`
   ([save_game_manager.gd](../../../src/autoload/save_game_manager.gd#L190)).
6. `GameState` delegates the parsed RNG dictionary to
   `GameRng.deserialize()`, whose typed integer assignments retain the already
   rounded value ([game_state.gd](../../../src/core/state/game_state.gd#L1219),
   [game_rng.gd](../../../src/core/state/game_rng.gd#L78)).

The direct Gate 1 sequence, `JSON.stringify()` -> `JSON.parse_string()` ->
`GameState.deserialize()`, reproduces steps 4-6 without the file wrapper and
therefore exercises the same representation defect.

The signing layer does not protect the pre-JSON integer. `IntegritySigner`
intentionally JSON-round-trips the signing payload to normalize numeric
representation ([integrity_signer.gd](../../../src/utils/integrity_signer.gd#L83)).
Consequently, a file can verify successfully after its large RNG integer has
been rounded by the parser: signing and verification agree on the normalized,
lossy representation.

## 3. Affected canonical fields

Both canonical fields owned by `GameRng` are affected whenever their magnitude
exceeds JSON/binary64's exact integer range:

- `GameState.rng.initial_seed`;
- `GameState.rng.state`, the resumable current generator state.

Gate 1 used the small seed `1007001`, so only `state` failed there. That does
not make `initial_seed` safe generally. `GameRng.new(0)` obtains a native
random seed, and replay headers may also carry any signed 64-bit seed.

No command payload currently persists an RNG state. Command implementations
take temporary in-memory state snapshots only to roll back failed atomic
execution. Those locals do not cross JSON.

## 4. Production contract impact

### Authority save/load and installation

This is the directly defective path. A Hot-Seat or Network-authority save can
load successfully with a different RNG stream. `GameManager.start_new_game_from_state()`
then installs the already altered `GameState`; the installer does not cause or
repair the loss. Later dice, shuffles, damage-deck operations, or other RNG
consumers can diverge from uninterrupted play.

Named saves and any persisted checkpoint payloads share `SaveFileStore` and
the same load/deserialization path. A named save copied from a parsed
checkpoint can only preserve the checkpoint's already rounded value.

### Network resume and reconnect

Under accepted ADR-012, passive Network peers must not receive RNG. Production
`StateFilter` validates an in-memory full-authority state and then removes the
`rng` member before publication
([state_filter.gd](../../../src/core/network/state_filter.gd#L35)). Fresh
bootstrap, staged resume, and reconnect RPC dictionaries therefore do not
introduce this RNG precision loss on the passive peer.

The Network-authority side is affected when its source is a loaded save: the
host continues from the rounded RNG state and publishes authority-resolved
future outcomes. Fresh-session resume inherits the defect from authority
save/load before filtered publication. Same-live-match load does likewise.
Ordinary reconnect to an uninterrupted host does not serialize the host RNG
through JSON and is not affected by this mechanism.

The current RPC transport uses typed Godot values rather than JSON for these
snapshot calls, but this does not broaden the contract because RNG is removed
from the passive snapshot in all cases.

### Replay

Full-history replay is not directly affected. Replay reconstructs RNG from the
initial seed plus ordered semantic commands, not from a serialized current RNG
state. `GameReplay` already writes `rng_seed` as an exact decimal string and
strictly decodes it
([game_replay.gd](../../../src/core/commands/game_replay.gd#L116),
[game_replay.gd](../../../src/core/commands/game_replay.gd#L233)). Its format-11
representation demonstrates an existing repository precedent for lossless
64-bit JSON integers.

Replay comparison remains relevant: a replay from the original exact seed can
diverge from continued execution of a lossy loaded save. GGS-style arbitrary
S0 reconstruction is not a supported production replay path, so it did not
create an additional existing replay defect.

### Hashing and determinism

`CanonicalJson.hash(GameState.serialize())` includes the RNG on a full
authority. It hashes the in-memory representation and therefore changes if an
exact pre-save state is compared with its rounded post-load state
([canonical_json.gd](../../../src/utils/canonical_json.gd#L10)). This is useful
as an oracle but does not prevent the load.

Current Network candidate fingerprints compare a state with itself during a
staging attempt. If that state was loaded, both comparisons see the same
already rounded value. Passive peer state omits RNG. Those hashes therefore do
not prove pre-save/post-load RNG equivalence.

Baseline final-state hashes include full serialized RNG where the process owns
it. Existing baselines do not place a save/load boundary between the compared
states, so they do not currently expose this defect. Changing the canonical
RNG representation would change full-authority canonical state hashes even
when the numeric RNG value is unchanged.

### Compatibility boundaries

`SaveGameMetadata.CURRENT_VERSION` is the owning durable-state compatibility
boundary. Its own contract says to bump the version for a breaking change to
`GameState.serialize()` / `deserialize()`
([save_game_metadata.gd](../../../src/core/state/save_game_metadata.gd#L37)).

Replay format 11 need not change if its already lossless seed representation
and command schema stay unchanged. Network protocol 10 need not change if RNG
remains excluded from passive snapshots and no RPC schema changes. App version
is provenance rather than the owning format boundary. Canonical baseline hash
fixtures may require Owner-recorded renewal under the repository replay-fixture
workflow if the serialized full-authority representation changes.

## 5. Existing defect versus experimental path

The defect can occur today in production authoritative save/load. It is not
limited to GGS, although Gate 1 is the first located test that asserts exact
current RNG equality across a real JSON round-trip.

In-memory `GameState.serialize()` -> `GameState.deserialize()` tests do not
exercise JSON and remain exact. Production replay avoids the defect for its
seed by using a string. Passive Network state intentionally has no RNG. These
facts explain why adjacent paths can be correct while production save/load is
not.

## 6. Current test coverage and masking

The focused diagnostic runs produced:

- Gate 1: 97/98 assertions passed; the sole failure was exact current RNG
  equality after JSON (`5975857563556095516` versus
  `5975857563556096000`).
- Existing `test_game_rng.gd`, `test_save_game_manager.gd`, and
  `test_save_load_round_trip.gd`: 59/59 tests and 305 assertions passed.

The existing coverage masks or misses the behavior as follows:

- `test_game_rng.gd` round-trips only the in-memory dictionary, not JSON.
- save/load tests assert selected gameplay, deck, metadata, and reconstruction
  fields but do not compare exact `initial_seed`, exact current `state`, the
  next RNG result, or a pre-save/post-load canonical hash.
- many deterministic fixtures use small explicit seeds; current native RNG
  state can still become large, but tests commonly compare only behavior that
  does not consume RNG after loading.
- `IntegritySigner` deliberately normalizes through JSON, so successful HMAC
  verification is not an exact-integer assertion.
- replay tests reconstruct from the protected string seed or restore an
  in-memory RNG dictionary, bypassing the lossy save field.
- Network filtering tests correctly assert that RNG is absent from passive
  output and therefore cannot test authority RNG restoration.

## 7. Credible remediation options

### Option A — exact decimal strings for both RNG fields

Encode `initial_seed` and `state` as strict canonical decimal strings at the
`GameRng` ownership boundary, decode them with range/canonical-form validation,
and fail closed on malformed values. This is the smallest technically correct
representation repair and follows the existing `GameReplay.rng_seed`
precedent.

Compatibility consequences:

- changes the serialized `GameState` schema and full-authority canonical hash;
- should use a new save-format version under the existing metadata contract;
- needs an explicit policy for version-9 numeric saves;
- cannot recover low bits already lost when an old file has been parsed;
- does not by itself require replay-format or Network-protocol changes.

### Option B — exact fixed-width component encoding

Encode each signed 64-bit value as validated fixed-width hexadecimal or as two
validated 32-bit components. This is also technically lossless but introduces
more bespoke schema and decoding logic than decimal strings without a current
repository advantage.

Compatibility consequences are otherwise the same as Option A: new save
representation/version, changed canonical hashes, explicit legacy policy, and
no recovery of already lost bits.

### Option C — change the durable container away from JSON numeric semantics

Use a binary or otherwise typed exact-integer save representation for the
whole authoritative state. This could solve the field but changes signing,
inspection, storage, migration, and portability assumptions well beyond the
small defect.

Compatibility consequences include a new container/format, migration design,
new integrity canonicalization, tooling changes, and broader test/fixture work.
It is not the smallest repair.

### Rejected as technically insufficient

- casting the parsed float to `int` preserves the rounded value, not the
  original bits;
- weakening equality or accepting a close value violates ADR-012 and changes
  the future RNG stream;
- limiting only the initial seed does not constrain the native current state;
- adding a GGS-only codec creates a parallel serialization path;
- retaining a lossy numeric field for old readers while adding an exact sibling
  under the same unmarked format lets old code silently continue from the
  wrong stream.

## 8. Classification and routing

Classification: **BOUNDED CROSS-CUTTING**.

The defect is narrow and the accepted architecture already decides the
required behavior: authority load restores exact RNG state; passive Network
peers receive none; replay remains seed-plus-command-history. No RNG ownership
or reconstruction redesign is required.

It is not `LOCAL` because the correction changes a canonical serialized field
and therefore coordinates `GameRng`, `GameState`, save metadata/versioning,
signing expectations, save/load tests, determinism hashes, and legacy-save
policy. It is not `ARCHITECTURE-SENSITIVE` in the sense of needing a new broad
ownership decision; accepted ADR-012 resolves the behavioral requirement.

Recommended next workflow:

1. Owner confirms a bounded production repair work item separate from GGS-001.
2. Prepare an accepted implementation workbook for the save-format change,
   including the exact encoding, strict decoder, version-9 disposition,
   signature behavior, hash/fixture impact, and targeted authority
   save/load/replay/Network-resume tests.
3. Route compatibility and test protection through existing `BC-008` /
   `AT-009`, with `BC-009` / `AT-008` review for hash, replay, and Network
   consequences.
4. Stop for an Owner architecture decision only if support for existing
   version-9 saves, cross-installation portability, or a non-JSON container is
   required beyond a bounded versioned decoder policy.

GGS-001 should remain paused. Gate 1's exact-RNG requirement remains valid and
must not be weakened. Gate 2 remains unauthorized until the production repair
is separately accepted, implemented, verified, and the Owner explicitly
reassesses the GGS package and authorizes continuation.

## 9. Diagnostic verification and repository effect

Performed:

1. Traced `GameRng` -> `GameState` -> signed save write -> JSON parse ->
   `GameState`/`GameRng` reconstruction.
2. Traced replay seed serialization, canonical hashing, passive Network
   filtering, reconnect/resume installation, and state installation.
3. Audited accepted ADR-012 and ADR-011 plus `BC-008`, `BC-009`, `AT-008`, and
   `AT-009` ownership/routing evidence.
4. Reran the Gate 1 test and reproduced the sole 64-bit RNG mismatch.
5. Reran the three nearest existing RNG/save suites and confirmed they all
   pass without detecting it.

Only this evidence record was added by the diagnosis. No production code,
tests, GGS infrastructure/workbook, fixture, serialization format, version, or
migration was changed.
