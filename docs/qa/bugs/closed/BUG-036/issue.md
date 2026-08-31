### Additional Command-Flow Anomaly Observed

The same manual run also logged a rejected second `resolve_damage` attempt after
each of the two commanded-squadron attacks.

In both cases:

1. one authoritative `resolve_damage` command executes successfully and applies
   damage;
2. a second `resolve_damage` attempt immediately follows;
3. `CommandProcessor` rejects the second attempt with
   `Defense resolution is not complete`;
4. `complete_attack` then executes normally.

This did not produce an observed double-damage mutation because validation
rejected the duplicate attempt.

The repeated pattern should be investigated for duplicate command submission or
auto-skip-defense routing. Do not assume it shares BUG-035's
post-acknowledgement root cause.
