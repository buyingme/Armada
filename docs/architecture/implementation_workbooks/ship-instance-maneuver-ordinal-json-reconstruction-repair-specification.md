# ShipInstance Maneuver Ordinal JSON Reconstruction Repair Specification

Status: **Implementation accepted by the Project Owner — 2026-10-16**

Purpose: specify the smallest owner-local correction that restores the
integer representation of `ordered_ordinal` in the two optional canonical
Maneuver records after JSON decoding, before strict `ShipInstance`
installation.

Related authority and evidence:

- accepted [ADR-006 canonical Ship Activation boundary ownership](../adr/ADR-006-canonical-ship-activation-boundary-ownership.md#L298);
- accepted [Ship Maneuver capability and BUG-043 implementation workbook](BUG-043-network-maneuver-preview-speed-convergence-implementation-workbook.md#L1237);
- [CON-001 serialization and reconstruction verification](../contracts/CON-001-current-attack-state-and-semantic-transition-contract.md#L714);
- [`ShipInstance` JSON normalization and strict installation path](../../../src/core/state/ship_instance.gd#L2250); and
- [strict optional-record validators](../../../src/core/state/ship_instance.gd#L1816).

## 1. Classification And Boundary

Classification: **Bounded Architecture / owner-local production
reconstruction repair**.

The confirmed defect is on this path:

```text
ShipInstance.serialize()
-> GameState.serialize()
-> JSON stringify/parse
-> PlayerState.deserialize()
-> ShipInstance.deserialize()
-> _normalize_save7_maneuver_integers()
-> install_maneuver_execution_for_save7()
-> strict active-Maneuver validation
```

Godot JSON parsing reconstructs JSON numbers as floats. The existing
`_normalize_save7_maneuver_integers()` function restores declared integers in
`committed_result`, `ship_collision`, and typed obstacle-resolution records,
but does not restore `ordered_ordinal` in either of these optional records:

- `active_maneuver_execution.obstacle_pre_effect`; and
- `active_maneuver_execution.asteroid_completion_outstanding`.

Both strict validators require `TYPE_INT`. A valid production-created record
with ordinal `0` therefore becomes `0.0` after JSON parsing and is rejected
before `ShipInstance` and the enclosing `GameState` can be installed.

This is an existing representation defect. The accepted authority already
defines the records as canonical facts owned by `ShipInstance`, with the
ordinal indexing `obstacle_resolution_order`. No new ownership, continuation,
record meaning, range, stored field, or architecture decision is required.

## 2. Minimum Production Correction

Change only the private Maneuver integer normalization owned by
`ShipInstance`, before the existing strict installer runs.

Within `_normalize_save7_maneuver_integers()`:

1. obtain each of `obstacle_pre_effect` and
   `asteroid_completion_outstanding` from a nonempty
   `active_maneuver_execution`;
2. require each value to remain a `Dictionary`, preserving the exact-schema
   failure posture of the strict installer;
3. leave an empty optional record unchanged;
4. for a nonempty record, normalize its required `ordered_ordinal` through the
   existing owner-local integral-field helper; and
5. return `false` immediately if normalization fails, before calling
   `install_maneuver_execution_for_save7()`.

The correction must not:

- normalize arbitrary integers recursively or by field-name suffix;
- change `InteractionFlow`, `GameCommand`, `GameState`, obstacle commands, or
  GGS code;
- infer, clamp, round, default, erase, or synthesize an ordinal;
- change either record's keys, identities, lifecycle, or continuation rules;
- move validation out of the existing strict installer; or
- introduce a new serializer, normalization registry, or gameplay owner.

## 3. Numeric And Semantic Contract

For `ordered_ordinal` in either nonempty optional record:

1. accept a native `TYPE_INT` and retain the exact integer value;
2. accept a `TYPE_FLOAT` only when it is finite and exactly integral, then
   restore it to `TYPE_INT` using the existing helper;
3. reject fractional values, `INF`, `-INF`, `NAN`, booleans, strings, nulls,
   arrays, and dictionaries;
4. pass the normalized candidate to the unchanged strict record validator;
5. reject an ordinal below zero or at or beyond
   `obstacle_resolution_order.size()`;
6. reject an in-range ordinal whose indexed obstacle does not equal the
   record's `obstacle_id`; and
7. preserve the existing exact occurrence identity, activation identity,
   execution identity, inspection, principal, transform-applied, and mutual
   exclusion checks.

The numeric helper establishes representation validity. The strict installer
continues to establish semantic validity. A float that converts to an integer
but is outside the current order is rejected by the existing range rule; it is
not made legal by normalization.

## 4. Compatibility And Format Impact

No save, checkpoint, replay, command, Network, or canonical-state format
changes. A native integer and its JSON encoding remain unchanged. The only
runtime difference is that an exactly integral JSON-decoded number at either
declared ordinal field reaches strict installation as `TYPE_INT`.

Compatibility requirements:

- existing native-int states remain accepted without rewriting;
- empty optional records remain accepted;
- an absent, malformed, or partial required record remains rejected under the
  existing exact schema;
- numeric strings and booleans do not become compatible representations;
- passive `consequence_view` extraction and validation remain unchanged;
- authority and passive Network representations use the same owner-local
  normalization before their existing aggregate validators;
- serialization emits no new field and requires no version bump; and
- no replay fixture, baseline trace, expected hash, or stored state is altered
  or promoted by this repair.

The compatibility risk is over-acceptance if normalization occurs after strict
validation, bypasses exact record checks, or converts undeclared fields. Keeping
the two explicit fields in the existing pre-install normalization function
avoids that expansion.

## 5. Focused Verification

### 5.1 Genuine positive JSON round trips

Use production commands and owner methods to create each reachable state; do
not hand-assemble the positive record under test.

1. **Pending obstacle pre-effect:** commit a genuine obstacle order so
   `open_obstacle_pre_effect()` creates a nonempty `obstacle_pre_effect`.
   Serialize the `ShipInstance`, JSON stringify/parse, deserialize it, and
   assert:
   - reconstruction succeeds;
   - `ordered_ordinal` is `TYPE_INT` with the exact original value;
   - the complete active Maneuver execution equals the live source record; and
   - the normal acknowledgment command validates and advances the same legal
     continuation as on the live source.
2. **Outstanding Asteroid completion:** acknowledge the production pre-effect,
   resolve an Asteroid branch that opens
   `asteroid_completion_outstanding`, and retain its associated faceup
   inspection state. Perform the same genuine `ShipInstance` JSON round trip
   and assert exact record restoration with `TYPE_INT` ordinal. Through an
   enclosing `GameState` JSON round trip, complete the required inspection
   acknowledgment and submit the normal `CompleteAsteroidOverlapCommand`;
   prove the outstanding record is consumed exactly once and progression opens
   the same next legal action as the uninterrupted state.
3. Repeat both states through `GameState.serialize()` -> JSON ->
   `GameState.deserialize()` so aggregate obstacle, faceup inspection,
   activation, and Maneuver invariants are exercised. Cover the passive
   Network representation where the existing fixture can provide a genuine
   filtered state without introducing a test-only owner or record.

### 5.2 Malformed and compatibility matrix

For each of the two record variants, assert reconstruction rejection for:

- `0.5` and `-1.5`;
- `INF`, `-INF`, and `NAN` supplied directly to the deserializer boundary;
- `-1`, `obstacle_resolution_order.size()`, and a larger integral value;
- `true`, `"0"`, `null`, `[]`, and `{}` as a nonempty record's ordinal;
- a missing `ordered_ordinal`;
- a wrong record container;
- an in-range integer paired with the wrong `obstacle_id`;
- an occurrence id containing a different ordinal; and
- a stale activation identity or Maneuver execution identity.

Also prove that native integer ordinals, integral JSON floats, and empty
optional dictionaries retain their existing accepted behavior. Negative tests
must assert `ShipInstance.deserialize() == null` and, where installed through
the aggregate path, `GameState.deserialize() == null`; no partial owner state
may escape.

### 5.3 Canonical convergence and regression gates

After the separately scoped InteractionFlow reconstruction differences have
been corrected or independently shown stable for the test state:

1. compare the complete live and JSON-reconstructed `GameState.serialize()`
   forms and their canonical hashes for each record variant;
2. require exact equality, including `TYPE_INT` ordinal restoration;
3. run the focused `ShipInstance`, Maneuver obstacle consequence, save/load,
   state filtering, passive reconstruction, Network resume, and canonical JSON
   suites;
4. run the full repository test suite and existing Hot-Seat and Network
   baseline checks; and
5. run documentation consistency checks and `git diff --check`.

A difference outside the two ordinal fields must identify its first exact
location and fail closed for full-state convergence. It must not be normalized,
ignored, added to this scope, or hidden by a projected digest. Fixture or hash
promotion requires separate explicit Project Owner authorization and the
repository's normal capture/review process.

## 6. Scope, Stop Gates, And Owner Acceptance

Authorized implementation scope after acceptance is limited to:

- `src/core/state/ship_instance.gd`: two explicit optional-record ordinal
  normalization calls in the existing private Maneuver normalization path;
- focused existing unit/integration test files for the verification above; and
- this specification and later audit/evidence records.

Stop and return to the Project Owner if implementation requires:

- normalizing another field or owner;
- changing an ordinal range or the meaning/order of obstacles;
- relaxing an exact record, identity, inspection, or continuation invariant;
- changing a producer, consumer, command, format, version, fixture, expected
  hash, or accepted architecture;
- coupling this repair to InteractionFlow, the Attack publication command
  codec, `CurrentAttackState.resolved_outcome`, or GGS-001; or
- adding a generic normalization mechanism or exceeding this bounded repair.

Estimated implementation cost: **Small to Medium**. The production change is
Small; genuine two-variant reconstruction, malformed-input, continuation,
aggregate digest, and compatibility verification drive the remaining cost.

The Project Owner accepted the bounded owner-local repair and its verification
evidence on 2026-10-16.

Any fixture capture, baseline renewal, or expected-hash promotion requires a
later explicit Owner authorization. Acceptance or implementation does not
authorize InteractionFlow, command-codec, `resolved_outcome`, or GGS-001 work.

Current readiness: **implementation acceptance checkpoint passed**.

## 7. Completed Implementation And Acceptance Evidence

The accepted implementation adds two explicit owner-local normalization calls
inside `_normalize_save7_maneuver_integers()`. They apply only to
`ordered_ordinal` when present in a nonempty `obstacle_pre_effect` or
`asteroid_completion_outstanding` record. The existing integral-number helper
restores an exactly integral JSON float to `TYPE_INT`; the unchanged strict
installer retains range, obstacle identity, occurrence identity, activation,
execution, inspection, mutual-exclusion, and continuation validation.

The regression tests use production methods and commands to create both
reachable optional-record variants. They prove direct `ShipInstance` and
enclosing `GameState` JSON reconstruction, exact active-Maneuver restoration,
full-state canonical-hash convergence where other state is stable, legal
continuation, exact-once Asteroid completion, and fail-closed rejection of the
malformed and mismatched cases required by §5.2.

Verification completed on 2026-10-16:

| Verification | Result |
|---|---|
| Maneuver obstacle consequence focus | **21/21 tests passed; 729 assertions** |
| `ShipInstance` focus | **92/92 tests passed; 252 assertions** |
| BUG-043 recovery integration | **18/18 tests passed; 1,495 assertions** |
| Save/load focus | **14/14 tests passed; 117 assertions** |
| State-filter and passive reconstruction focus | **30/30 tests passed; 86 assertions** |
| Canonical JSON focus | **4/4 tests passed; 6 assertions** |
| Network resume and reassociation integration | **12/12 tests passed; 128 assertions** |
| Full repository suite | **4,450/4,450 tests passed; 21,905 assertions** |
| Real ENet Network resume acceptance | **PASS**, including fresh resume and compatibility scenarios |
| Hot-Seat and Network baseline comparison | **PASS**, including Network peer equality and all replay baselines |
| Documentation consistency and `git diff --check` | **PASS** |

Save format 10, Network protocol 11, and Replay format 12 remain unchanged.
The repair adds no serialized field, format bump, command change, compatibility
migration, or canonical ownership change. Existing fixtures, expected hashes,
and approved Hot-Seat, Network, and replay baselines were preserved without
regeneration or promotion.

The Project Owner accepted this completed implementation and evidence on
2026-10-16. This acceptance closes only the ShipInstance Maneuver ordinal JSON
reconstruction repair. The InteractionFlow state-reconstruction repair, Attack
publication command-codec repair, `CurrentAttackState.resolved_outcome`
investigation, and GGS-001 remain separately pending under their existing
authority and checkpoints.
