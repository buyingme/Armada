Diagnosis complete. No files or evidence were modified.

1. Exact failure

The recorded sequence is:

- `48`: parent `begin_attack`
- `57`: resolves 3 damage; TIE Interceptor reaches hull 0
- `60`: valid Counter choice published for Player 1
- `61`: Counter accepted
- `62`: parent completed
- `63–64`: exact-ID acknowledgements satisfy `completed:attack:48`
- Expected next command: Counter-child `begin_attack`
- Actual `65`: original Squadron activation completes

At final acknowledgement, [CurrentAttackContinuation](/Users/Katharina/godot/Armada/src/core/state/current_attack_continuation.gd:305) resolves the Counter attacker and target, then rejects because the Counter attacker is destroyed:

```gdscript
attacker.is_destroyed() or defender.is_destroyed()
```

It therefore returns no child Begin. The generic inspection-release branch then treats the parent inspection as an ordinary completed Squadron attack and emits `CompleteSquadronActivationCommand`, producing sequence 65.

2. Generic validation assessment

Generic attack validation is not the immediate blocker.

[BeginAttackCommand](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:281) deliberately enters Counter-specific validation before the ordinary destroyed-attacker rejection. Consequently:

- standard attacks by destroyed attackers still reject;
- destroyed Counter attackers are already permitted when an exact accepted Counter projection exists;
- destroyed Counter targets still reject;
- participant identity, accepted choice, keyword, range, obstruction, inspection ID, and dice remain validated.

No child command reaches this validation in the failing session because continuation derivation stops first.

3. Canonical sufficiency

Canonical state retains the necessary information:

- the destroyed SquadronInstance remains in GameState with identity, owner, position, Counter value, and armament;
- the accepted parent projection retains all four exact Counter identities and the locked Counter-2 pool;
- inspection `completed:attack:48` retains the parent participants and result;
- the original X-wing target remains canonical and alive;
- targeting reconstruction includes retained Squadron models;
- Counter Roll derives its locked pool from the exact active child attack and canonical Counter squadron.

No new canonical field is required.

There is one subsequent presentation seam that regression coverage must close: destroyed Squadron tokens are removed from ordinary board lookup. Counter-child reconstruction currently requires an attacker token at [attack_executor.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:544), while normal lookup excludes the detached destroyed token at [game_board.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/game_board.gd:938). The bounded repair must preserve or resolve that existing detached token specifically for a validated destroyed Counter child; generic destroyed-unit targeting must remain unchanged.

4. Authority and classification

Classification: **REQUIREMENTS GAP in the accepted workbook, manifested as an implementation defect.**

The Rules Reference explicitly permits Counter after destruction. Existing Counter rule authority and N20 implementation records also state this behavior.

The accepted Counter interaction requirements defer detailed eligibility to the applicable rules authority, so they do not contradict the exception. However, the accepted workbook currently requires two “non-destroyed” Squadrons and says destroyed state derives no child at Section 6.6. That language directly contradicts the Rules Reference.

A bounded workbook correction is therefore required before implementation. No new gameplay or architecture decision is needed.

5. Smallest correction

After correcting the workbook:

- In `CurrentAttackContinuation`, allow the exact accepted Counter attacker to be destroyed.
- Continue rejecting a destroyed Counter target, missing participant, wrong identity, wrong source, unaccepted choice, missing Counter value, or illegal targeting result.
- Preserve generic destroyed-attacker rejection for every non-Counter attack.
- At presentation reconstruction, permit only an exact canonical destroyed Counter child to reuse/resolve its retained detached presentation token. Do not return destroyed units to ordinary board lookup or selection.
- Keep existing Begin, Roll, stale-source, inspection, Network-ordering, and composed-return validation unchanged.

No version, adapter, migration, owner, FSM, or canonical-state change is indicated.

6. Required regression coverage

End-to-end coverage must prove:

- Surviving Counter attacker:
  - accept and decline;
  - both real-ENet mappings;
  - full child lifecycle and composed return.

- Destroyed Counter attacker:
  - lethal parent damage still exposes Counter;
  - decline creates no child and returns normally;
  - accept produces exactly one child Begin after acknowledgements;
  - locked Declare automatically reaches Roll;
  - correct controller receives interactive presentation despite token retirement;
  - other endpoint remains passive;
  - Counter-X pool comes only from canonical state;
  - child resolves, completes, is acknowledged, and returns through the original Squadron activation;
  - exhausted and legal-Move composed-return branches both work;
  - both real-ENet mappings converge.

- Fail-closed protection:
  - destroyed ordinary attacker still rejects;
  - destroyed Counter target rejects;
  - source-less, unaccepted, stale-ID, mismatched-participant, wrong-pool, and fabricated Counter Begin reject;
  - save/load and reconnect preserve the accepted destroyed-Counter boundary;
  - Replay 12 records the explicit child Begin and synthesizes nothing.

The new BUG-074 replay remains immutable diagnostic evidence; it correctly records the failure through sequence 65. No Owner-decision gate remains, but the accepted workbook contradiction must be corrected before implementation.
