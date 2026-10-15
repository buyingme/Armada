# Counter Parent-Identity Save-10 Round-Trip Resolution

Status: Owner-resolved implementation STOP evidence — 2026-10-09

## Stopped evidence

The real Save-10 JSON round trip preserved the accepted parent Counter
projection and its values, but Godot decoded these four nested payload numbers
as floats:

- `counter_attacker_player`: `1.0`
- `counter_attacker_squadron_index`: `0.0`
- `counter_target_player`: `0.0`
- `counter_target_squadron_index`: `0.0`

The completed inspection retained its exact required and received principals
and was satisfied. `CurrentAttackContinuation` correctly refused to derive the
child Begin because its runtime contract requires all four fields to have
canonical `TYPE_INT`. No gameplay, command, continuation, inspection,
StateFilter, or identity validator was weakened to pass this gate.

## Boundary verification

`GameState.deserialize()` and `GameState.deserialize_passive_network()` use
the same internal reconstruction path and delegate a non-empty
`interaction_flow` to `InteractionFlow.deserialize()`. That method is the
existing canonical boundary and already performs narrowly scoped restoration
of exact JSON-decoded identity numbers for Squadron displacement flows.

`InteractionFlow.serialize()` emits a plain JSON-safe dictionary and Save 10
stores it through the normal JSON encoder. JSON numbers do not carry an
integer-versus-floating-point type distinction through Godot's parser.
Preserving the integer type in the serializer would therefore require a
different representation or schema marker, with broader save/network
consequences. That narrower serializer alternative is not available within the
unchanged schema.

Repository producers and validators identify exactly four parent Counter
participant identity fields: the four listed above. They are produced by the
existing Counter choice path and consumed by `CounterChoiceCommand`,
`BeginAttackCommand`, and `CurrentAttackContinuation`. No additional parent
Counter identity field was found.

## Owner-authorized resolution

At `InteractionFlow.deserialize()` only, for an
`ATTACK_COUNTER_CHOICE` projection, restore each of the four fields to an
integer when its decoded value is numeric, finite, mathematically integral,
and valid for that field. Player values are limited to the canonical player
range; Squadron indices must be non-negative and within the supported integer
range. Any missing, partial, fractional, boolean, non-numeric, non-finite, or
out-of-range identity rejects the reconstructed flow and therefore the whole
state.

This correction restores canonical runtime type after the existing JSON round
trip. It adds no default, adapter, migration, durable state, lifecycle owner,
or continuation owner. Command-time and continuation exact-integer validation
remain unchanged. Save 10, Network 11, and replay 12 remain unchanged.

Replay fixtures remain Owner-controlled. The separate exact-RNG baseline/hash
promotion remains paused, and GGS-001 Gate 2 remains unauthorized.

## Verification reached

The authorized correction passed the focused boundary suite, including the
real signed Save-10 write/read path, passive reconnect reconstruction,
satisfied-inspection child-Begin derivation, fail-closed malformed cases, and
unchanged command/continuation exact-integer checks.

Both real-ENet Counter mappings passed under protocol 11. In mapping 0 the
child Counter attacker was client-controlled; in mapping 1 it was
host-controlled. Both produced the same ordered history:

1. acknowledgement sequence 8;
2. final acknowledgement sequence 9;
3. authoritative child Begin sequence 10; and
4. child-source publication sequence 11.

Both peers converged at cursor 12, the parent projection survived until Begin,
the inspection was consumed exactly once, the child projection replaced the
parent, passive peers synthesized no continuation, and delayed parent clearing
rejected without mutation. Fresh real-ENet mapping 0 and mapping 1 also passed.

Full convergence passed with 4,072 unit tests / 14,338 assertions and 346
integration tests / 7,029 assertions. `git diff --check` passed. Save remains
10, Network remains 11, and replay remains 12. Neither Owner-controlled replay
fixture was changed; both committed inputs remain format 11.

The implementation has therefore reached the workbook's manual replay-fixture
recording gate and stops there. No fixture-dependent replay/baseline promotion
has been performed.
