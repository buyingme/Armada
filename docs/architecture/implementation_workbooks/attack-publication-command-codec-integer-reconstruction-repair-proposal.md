# Attack Publication Command-Codec Integer Reconstruction Repair Proposal

Status: **Draft proposal — separately scoped; not accepted and not
implementation authorization**

Purpose: define the smallest production correction for integer representation
loss proven on the Replay-12 JSON -> `GameCommand` codec ->
`PublishAttackFlowCommand` path, without changing InteractionFlow state
reconstruction, replay data, command formats, gameplay ownership, or GGS.

Related work:

- [InteractionFlow integer reconstruction repair workbook](interaction-flow-integer-reconstruction-repair-implementation-workbook.md#L1)
- [`GameCommand` codec](../../../src/core/commands/game_command.gd#L29)
- [`PublishAttackFlowCommand`](../../../src/core/commands/publish_attack_flow_command.gd#L39)
- [BUG-074 accepted Replay-12 evidence](../evidence/hot-seat-baseline-canonical-state-rebaseline-approval-record.md#L98)

## 1. Boundary And Runtime Evidence

This proposal owns only:

```text
Replay-12 JSON
-> GameCommand.deserialize()/canonicalize_serialized()
-> PublishAttackFlowCommand.flow_payload
```

The completed runtime proof showed that the existing structured
`publish_attack_flow` codec already restores several direct fields,
`dice_pool`, `locked_tokens`, `defense_tokens`, and mixed-type `dice_results`,
but leaves these integer-valued fields from recorded Replay-12 Attack
publications as JSON floats:

- direct counts: `ship_target_attacks_this_round`, `accuracy_count`, and
  `spendable_accuracy_count`;
- Counter identities/controllers: `counter_controller_player`,
  `counter_attacker_player`, `counter_attacker_squadron_index`,
  `counter_target_player`, and `counter_target_squadron_index`; and
- `counter_dice_pool` values.

Those fields are present in the accepted Replay-12 production history and have
production Attack publication writers. This proposal does not add fields based
only on names or on the broader state-reconstruction inventory.

## 2. Smallest Repair

Extend only the existing `publish_attack_flow` structured canonicalization in
`GameCommand`:

1. add the three direct counts and five Counter identity/controller fields to
   explicit integer canonicalization;
2. canonicalize every `counter_dice_pool` value using the existing integer
   dictionary helper; and
3. preserve all current mixed-type handling, unknown-field preservation,
   exact safe-integer checks, malformed-input rejection, and command envelope
   behavior.

No command name, serialized key, format version, replay fixture, expected hash,
or `PublishAttackFlowCommand` execution rule changes. Do not share policy with
`InteractionFlow.deserialize()` by introducing a registry or new service.

## 3. Verification Gates

Implementation evidence must pass all of these gates:

1. **Focused codec round trip:** serialize a production-shaped
   `PublishAttackFlowCommand`, JSON stringify/parse it, deserialize it, and
   prove every listed field is `TYPE_INT` with the exact original value.
2. **Negative matrix:** reject fractional, nonfinite, outside-safe-integer,
   boolean, string, null, and wrong-container values at each new scalar or
   dictionary category; preserve unknown keys unchanged.
3. **Replay-12 command proof:** load the accepted fixture unchanged and prove
   that every affected recorded publication reconstructs to the exact intended
   command payload before execution.
4. **Publication application:** execute representative reconstructed DECLARE,
   MODIFY, RESOLVE_DAMAGE, and COUNTER_CHOICE publications and prove the exact
   resulting `InteractionFlow` matches the equivalent live command.
5. **Replay regression:** run Replay-12 and the focused replay suite without
   modifying fixtures or hashes. A final-state difference outside the applied
   publication flow, including `CurrentAttackState.resolved_outcome`, fails
   closed and is reported under its own boundary rather than absorbed into this
   repair.
6. **Compatibility:** run existing command codec, publication command,
   Counter, replay-driver, full-suite, Hot-Seat baseline, Network baseline, and
   Network resume checks; run documentation checks and `git diff --check`.

## 4. Exclusions And Stop Gates

Excluded:

- `InteractionFlow.deserialize()` and state-reconstruction schemas;
- `CurrentAttackState.resolved_outcome` normalization;
- replay fixtures, expected hashes, stored formats, and version changes;
- publication semantics, attack lifecycle ownership, and generic codec
  architecture; and
- GGS implementation, Candidates, fixtures, or Gate 2 resumption.

Stop and return to the Project Owner if implementation requires any excluded
surface, a format/version change, fixture or accepted-hash renewal, a new
numeric meaning/range decision, or more than this bounded codec extension.

## 5. Cost And Owner Decision

Estimated cost: **Small to Medium** — Small production-code change plus focused
unit, Replay-12, publication-application, and compatibility verification.

The Project Owner must separately accept this proposal and authorize its
implementation. Acceptance or implementation of the InteractionFlow state
repair does not authorize this command-codec repair, and neither repair
authorizes investigation or correction of `resolved_outcome`.
