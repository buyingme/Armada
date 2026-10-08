# Network Mapping-1 Stale Attack-Flow Diagnosis

**Status:** Preserved architecture evidence  
**Evidence date:** 2026-10-08  
**Repository baseline:** `43da6db` plus the stopped, uncommitted exact-RNG repair  
**Task classification:** Uncertain/high-risk architecture diagnosis  
**Implementation authority:** None — this document does not authorize production changes

> This evidence records an independent, bounded diagnosis of the reproducible
> Network mapping-1 failure discovered while verifying the
> [exact authoritative RNG save-serialization repair](../implementation_workbooks/exact-authoritative-rng-save-serialization-repair-implementation-workbook.md).
> No repair, baseline promotion, protocol change, or GGS-001 Gate 2 work was
> performed.

## 1. Executive finding

The failed projection is caused by a pre-existing Network/current-attack
lifecycle defect, not by `StateFilter` and not by corruption written by the RNG
serializer.

The first invalidating authority command is a delayed, non-final
`PublishAttackFlowCommand` emitted by the remote attacker's scene flow. It is
queued while earlier commands are in flight, survives attack completion and
completed-result inspection, and is accepted after `AdvanceActivationStepCommand`
has retired the canonical attack. It writes an `ATTACK_RESOLVE_DAMAGE`
`InteractionFlow` for the completed attack into an authority state with no
active `CurrentAttackState` and no `CompletedAttackInspection`. That combination
cannot be reconstructed by `GameState.deserialize()` and is therefore rejected
when `StateFilter` validates the authority snapshot.

The reported player index `-1` is a separate, adjacent presentation defect.
It is the default sentinel returned when the host derives a remote
`resolve_damage` presentation from `CurrentAttackState.resolved_outcome`, which
deliberately omits `owner_player` and `ship_index`, and then passes that partial
dictionary to a ship lookup that assumes those fields exist. The sentinel is
not a principal assignment, reassociation result, command player, or value
stored in canonical `GameState`.

Relationship to the RNG repair: **EXPOSED**. An isolated pre-repair `HEAD`
mapping-1 run still logged the same `-1` but happened to take a faceup-damage
path whose extra acknowledgement gates rejected/drained the stale publications.
The exact repaired RNG stream took a facedown-only path, exposing the already
present lifecycle race. The RNG repair did not write either defect.

## 2. Governing boundaries

- [ADR-001](../adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md)
  and [CON-001](../contracts/CON-001-current-attack-state-and-semantic-transition-contract.md)
  make `CurrentAttackState` the sole current-attack authority. Scene flow and
  `InteractionFlow` mirrors are derived and may not resurrect a retired attack.
  A command targeting a completed/earlier attack must fail closed as stale.
- [ADR-011](../adr/ADR-011-network-match-resume-and-principal-entitlement.md)
  separates transport endpoint, principal, and player side. Inspection found
  no incorrect principal/player reassociation in this failure.
- [ADR-012](../adr/ADR-012-live-network-rng-authority-and-result-application.md)
  requires authority-owned random resolution and passive result application.
  The reproduced invalidity occurs after a correctly accepted authoritative
  result and does not require passive RNG consumption.

## 3. First divergence and exact command sequence

Temporary command-boundary instrumentation was added, used, and removed. It
checked the live authority validators and a `serialize()` → `deserialize()`
round trip after every accepted command in mapping 1.

The authority remained reconstructable after:

1. the real `RollDiceCommand` and its attack continuations;
2. `ResolveDamageCommand`;
3. `CompleteAttackCommand` and completed-result acknowledgements; and
4. `AdvanceActivationStepCommand`, which consumed the completed inspection and
   moved the canonical activation into maneuver.

The first failing boundary was the next accepted `publish_attack_flow`
(the exact sequence number varied with asynchronous delivery). A captured
payload had:

```text
step_id: ATTACK_RESOLVE_DAMAGE (18)
controller_player: 0
flow_payload.attack_id: attack:7
flow_payload.attacker_player: 0
flow_payload.defender_player: 1
final: false
```

One capture included `final_damage: 2`; another was the preceding resolve-step
snapshot without `final_damage`. Both have the same invalidating semantics.
Immediately afterward:

```text
interaction_flow.flow_type = ATTACK
interaction_flow.step_id = ATTACK_RESOLVE_DAMAGE
current_attack_state.active = false
current_attack_state.attack_id = ""
completed_attack_inspection = null
```

The live `validate_for_full_authority_installation()` checks still returned
true, revealing a defense-in-depth validation gap, but
`GameState.deserialize(state.serialize())` returned null. The explicit
reconstruction invariant rejects an ATTACK interaction flow when neither an
active current attack nor a completed inspection exists. A following
`RepairActionCommand` merely preserved this already invalid combination.

The publication originates in
[AttackExecutor](../../../src/scenes/game_board/attack_executor.gd): advancing to
Resolve Damage publishes a snapshot, and applying the accepted damage result
may patch and publish `final_damage`. On a client, the
[NetworkCommandSubmitter](../../../src/core/commands/network_command_submitter.gd)
permits one ordinary command in flight and FIFO-queues later serialized
commands. The snapshots were valid scene observations when created, but became
stale before reaching authority.

While faceup or completed-result inspection was outstanding, the canonical
gate rejected queued publications. After the acknowledgement and activation
advance consumed those gates, a remaining snapshot reached
[PublishAttackFlowCommand](../../../src/core/commands/publish_attack_flow_command.gd).
Its validation is documented and tested as “always valid,” so it did not check
the active attack id or lifecycle. Execution then overwrote the authoritative
interaction flow with the retired attack snapshot.

This is a stale-command admission defect. Queueing explains the timing; it does
not transfer attack authority to the scene mirror.

## 4. Exact origin and meaning of player index `-1`

`ResolveDamageCommand`'s full authority result identifies the target with
`owner_player` and `ship_index`. Its canonical
`CurrentAttackState.resolved_outcome` intentionally does not duplicate defender
identity.

For a remote-authored application-contract command, the transported
`presentation_result` is empty. The host path in
[GameManager](../../../src/autoload/game_manager.gd) therefore derives the
presentation for `resolve_damage` from `resolved_outcome` and passes it to
`_handle_remote_resolve_damage()`. The ship branch calls
`_find_ship_from_damage_result()`, which evaluates:

```text
owner = result.get("owner_player", -1)
ship_index = result.get("ship_index", -1)
get_player_state(owner)
```

Because both keys are absent, `owner` is the sentinel `-1` and
`get_player_state(-1)` emits `Invalid player index: -1`. No code stores that
sentinel into the authority state. The production owner that propagates the
incomplete shape is `GameManager._derive_network_presentation_result()`; the
consumer mismatch is in `GameManager._handle_remote_resolve_damage()` and
`_find_ship_from_damage_result()`. The corresponding squadron branch already
has a canonical-active-attack fallback, while the ship branch does not.

The `-1` log occurs during damage-result handling because that is when the host
tries to project the remote attacker's accepted result into scene/UI events. It
precedes the stale publication and is not what makes serialization invalid.

## 5. Why mapping 0 passes and mapping 1 fails

In mapping 0 the host is the attacker/player 0. Its own damage result follows
the local authority/presentation path; it is not reapplied on that host through
the remote-authored result-projection fallback, and its attack-flow publications
do not cross the client FIFO in the failing topology.

In mapping 1 the client is attacker/player 0 and the host is player 1. The
attacker's scene publishes flow snapshots as remote commands. Those snapshots
queue behind authoritative attack commands, while the host separately runs the
remote-authored damage-result projection that exposes the missing identity as
`-1`. The role swap therefore activates both pre-existing assumptions:

- remote ship-damage presentation is assumed to carry target identity; and
- a delayed derived attack-flow snapshot is assumed still to describe an active
  canonical attack.

Only the second assumption invalidates authority.

## 6. Why StateFilter reports the failure

[StateFilter](../../../src/core/network/state_filter.gd) receives the already
invalid serialized full-authority dictionary. Before removing secrets, it
reconstructs the dictionary with `GameState.deserialize()` and requires a valid
full-authority installation. Reconstruction fails on the stale ATTACK-flow
combination, so filtering correctly fails closed with:

```text
Network state filtering rejected an invalid authority state.
```

StateFilter neither creates nor mutates the invalid combination. Weakening it
would permit a non-reconstructable authority snapshot across the trust boundary
and would conceal the actual stale-command defect.

## 7. Save/resume and RNG causality

### Save/resume is not necessary

A temporary focused test, removed after execution, constructed a valid in-memory
SHIP-phase authority state with exact RNG, a valid match/player binding, no
active attack, and no completed inspection. Initial filtering succeeded. The
test then submitted a real non-final `PublishAttackFlowCommand` at
`ATTACK_RESOLVE_DAMAGE` through `CommandProcessor`, using a stale attack id.
Production accepted it, left the canonical attack inactive, and made
`StateFilter` reject the same invalid-authority condition. No save, load,
resume, reconnect, or reassociation was involved.

Resume/reassociation remains an important reproduction topology because it
establishes the remote-attacker mapping and asynchronous queue, but persistence
is not causal.

### RNG repair classification: EXPOSED

An isolated archive of unchanged pre-repair `HEAD` (`43da6db`) was run through
the same `--fresh-only` acceptance path. Mapping 1 passed final convergence but
still logged `Invalid player index: -1`, proving the damage-presentation defect
predates the RNG change.

That pre-repair run produced four damage and entered faceup-damage
acknowledgement. The additional inspection gates rejected queued stale
publications before activation advanced. With exact RNG preservation, the
captured repaired run produced two facedown damage and had no faceup inspection;
the queue reached a remaining stale publication after completed inspection was
consumed. The changed deterministic outcome altered scheduling/gating exposure,
not command validity or ownership.

The RNG repair therefore **EXPOSED** the authority defect. It did not cause it,
and changing RNG serialization to recover the prior accidental outcome would
be incorrect.

## 8. Existing coverage and the missing role case

- [PublishAttackFlowCommand unit tests](../../../tests/unit/test_publish_attack_flow_command.gd)
  directly execute ATTACK snapshots against an inactive default state and
  expressly assert that validation always passes. They do not cover lifecycle
  or attack-id staleness.
- [ResolveDamageCommand unit tests](../../../tests/unit/test_resolve_damage_command.gd)
  cover remote target lookup with an authority-style dictionary that includes
  `owner_player` and `ship_index`. They do not pass the identity-free
  `resolved_outcome` shape used by the host fallback.
- [Network resume and reassociation integration tests](../../../tests/integration/test_network_resume_and_reassociation.gd)
  cover swapped assignments through staging/actor selection, not the full
  remote-attacker damage/result/acknowledgement/activation/queued-publication
  sequence.
- [Current attack shared-protocol tests](../../../tests/integration/test_current_attack_shared_protocol.gd)
  exercise both attacker/defender topologies around defense submission, but not
  a delayed flow snapshot crossing canonical attack retirement.
- The acceptance harness does exercise both mappings, but the pre-repair
  deterministic mapping-1 outcome took the faceup acknowledgement path. It has
  no controlled facedown-only remote-attacker case asserting that no queued
  ATTACK publication survives inspection consumption.
- Submitter tests cover FIFO and rejection release generically, not semantic
  expiry of queued attack-flow snapshots.

The exact role mapping and lifecycle crossing are therefore not protected by a
focused regression.

## 9. Smallest credible repair seams (not implemented)

Primary authority repair:

- Make `PublishAttackFlowCommand` fail closed for a non-final ATTACK snapshot
  unless it matches the currently active canonical attack and an applicable
  lifecycle/stage. At minimum, require active canonical attack identity and
  matching `attack_id`; final clearing semantics must remain lifecycle-aware.
  This is the smallest owner-local seam consistent with ADR-001/CON-001.
- Queue coalescing or obsolete-snapshot removal may be useful supplementary
  hardening, but it is not sufficient by itself because authority would still
  accept a stale derived snapshot submitted by another path.
- Align the live full-authority validator with the deserialize invariant as
  defense in depth; do not weaken the deserialize or filter boundary.

Separate presentation repair:

- Before ship damage side effects are projected, derive the canonical defender
  from the still-matching active attack, as the squadron branch already does, or
  construct a complete local presentation result from canonical authority.
  This does not require a wire/protocol change.
- Merely suppressing `get_player_state(-1)` would remove the log but would still
  skip required presentation updates, so it is not a complete repair.

## 10. Severity, classification, and routing

The stale publication is a **High-severity production correctness defect**: in
the mapping-1 remote-attacker topology, an accepted derived command can make
full authority non-reconstructable and prevent safe client projection and
convergence. StateFilter fails closed, so this diagnosis found no hidden-state
disclosure.

Classify and route it as a separate, bounded cross-cutting
Network/current-attack command-lifecycle defect under ADR-001/CON-001 and the
ADR-011 role mapping. It should receive its own owner-tracked bug/workbook and a
focused two-mapping regression matrix. Do not absorb it into the exact-RNG
repair.

The `-1` path is a separate, pre-existing **Medium-severity remote damage
presentation/result-shape defect**. It does not corrupt canonical state, but it
logs an engine error and can omit host-side ship damage presentation. It may be
tracked beside the primary defect because the same role topology exposes it,
but its repair and acceptance criterion must remain distinct.

The stopped RNG repair must **not yet resume baseline/hash promotion or GGS-001
Gate 2**, because its required Network verification is still red. After the
separate production defects are owner-routed, repaired, and verified in both
mappings, the RNG task may resume at its bounded cross-boundary verification
step without changing RNG serialization. An explicit Owner disposition would
be required for any different gating decision.

## 11. Verification record

- Current stopped-RNG tree: `--fresh-only` Network acceptance reproduced the
  mapping-1 final projection failure; mapping 0 passed.
- Current tree with temporary boundary instrumentation: multiple mapping-1
  runs located the first failed round trip at the delayed accepted
  `publish_attack_flow`; instrumentation was removed afterward.
- Isolated pre-repair `HEAD`: `--fresh-only` passed both mappings while retaining
  the same `Invalid player index: -1` host log.
- Temporary in-memory production-command reproduction: one focused test passed
  nine assertions and reproduced StateFilter rejection without any persistence
  boundary; the test was removed afterward.
- Existing focused suites remained green while missing the diagnosed case:
  `test_publish_attack_flow_command.gd` 9/9 (16 assertions),
  `test_resolve_damage_command.gd` 24/24 (66 assertions),
  `test_network_resume_and_reassociation.gd` 12/12 (128 assertions), and
  `test_current_attack_shared_protocol.gd` 25/25 (1,058 assertions).
- No production repair, protocol/version change, fixture/baseline change, or
  RNG hash promotion was made by this diagnosis.
