# BUG-024 — Ship activation stalls after skipping remaining attack and opening Maneuver

Severity: High
Area: Ship Activation / Attack → Maneuver
Layer: Command Flow / Projection

## Expected

After a ship completes one attack and then legitimately skips its remaining attack opportunity:

1. the Attack step must end canonically;
2. the Maneuver opportunity must open;
3. the ship activation presentation must advance to Maneuver;
4. the Maneuver tool / controls must become available;
5. after executing the Maneuver, the ship activation must be able to complete normally.

The UI must derive the next step from the accepted canonical activation state and must not lose the active ship context after a successful Skip.

## Actual

During CR90 activation:

1. the first attack completes successfully;
2. the player proceeds to a possible second attack;
3. an attempted second target is rejected as illegal;
4. the player then skips the remaining attack opportunity;
5. `SkipAttackCommand` is accepted;
6. canonical state opens the Maneuver opportunity;
7. the Attack Executor closes;
8. the ship activation does not present the Maneuver step.

The game stalls.

The CR90 remains the active ship activation, so clicking the ship's dial again is rejected as not eligible, but no usable Maneuver interaction is available to continue the activation.

## Reproduction

Observed once.

1. Activate the CR90 Corvette A.
2. Complete one legal attack.
3. Proceed to the remaining attack opportunity.
4. Attempt/select another target if available.
5. Skip the remaining attack opportunity.
6. Observe the ship activation after Skip is accepted.

Result:

- Attack UI closes;
- Maneuver does not become usable/visible;
- ship remains canonically active;
- game cannot continue normally.

## Evidence

- `annotation_20260814_133210_001.json`
- `game_20260814_132858.log`

### Canonical-state evidence

At the captured stalled state:

- phase = Ship Phase;
- `current_attack_state.active = false`;
- CR90:
  - `ship_activation_identity = "ship-activation:242"`;
  - `committed_attack_count = 1`;
  - `attack_step_active = false`;
  - `squadron_command_opportunity_disposition = "CONSUMED"`;
  - `maneuver_opportunity_disposition = "OPEN"`;
  - `activated_this_round = false`.

This is consistent with an active ship activation that has completed/skipped Attack and is now canonically waiting for Maneuver.

However:

- `interaction_flow` is inactive;
- no Maneuver interaction is available.

The authoritative activation state and presentation are therefore out of sync.

### Log evidence

The relevant production sequence is:

- first attack already committed;
- later second `begin_attack` attempt rejects:
  `Attack target is not legal from authoritative board state.`
- player selects Skip;
- `SkipAttackCommand` executes successfully;
- ship Attack step changes from active to inactive;
- Attack Executor reports:
  `Attack execution done — completing attack step.`
- Attack Executor is dismissed;
- Ship activation reports:
  `Attack exec completed — advancing activation step.`

No accepted Maneuver-opening/continuation presentation follows.

Later attempts to interact with the CR90 dial report:

`not eligible (... activating=true)`

confirming that the application still considers the CR90 activation active even though its continuation UI is missing.

## Initial Assessment

The semantic Skip appears to be correct.

The canonical `ShipInstance` state already contains the expected post-Skip result:

`maneuver_opportunity_disposition = "OPEN"`

The defect therefore appears to be in the continuation/projection from accepted post-Skip activation state into the Maneuver presentation.

Potential investigation areas include:

- post-`SkipAttackCommand` continuation handling;
- `AttackExecutor` completion callback;
- `ShipActivationController` reconstruction/advancement after Attack Executor dismissal;
- differences between:
  - skipping Attack before any attack;
  - completing one attack and skipping the second opportunity;
  - completing all available attacks normally;
- stale/transient activation step state after an unsuccessful second Begin attempt.

Do not repair by mutating canonical ship activation state from the scene/controller. Maneuver must remain derived from the accepted `ShipInstance` activation boundary.

## Relationship to existing issues

BUG-024 is related to BUG-003 but represents a different failure mode.

BUG-003 concerns the legality/presentation of Skip after attack commitment.

BUG-024 concerns failure to continue into Maneuver after a legitimate Skip has already been accepted and the canonical Maneuver opportunity is OPEN.

Keep separate unless investigation proves a common root cause.

## Resolution

Root cause:

`SkipAttackCommand` already performed the correct canonical transition: it
retired the ship Attack step, opened the `ShipInstance` Maneuver opportunity,
and projected Ship Activation / Maneuver. During the same
`CommandProcessor.command_executed` fan-out, `AttackExecutor` handled the Skip
before `ModalRouter`. Its `_finish_attack_execution()` unconditionally ended
and published its local attack flow, thereby clearing the command-authored
Maneuver projection. `ModalRouter` then observed no flow and had nothing to
reconstruct.

A related reconstruction defect affected the one-attack continuation: the
executor attempted to wire panel signals before `TargetSelector` had ensured
the projected panel existed. A reconstructed remaining Skip could therefore
be visible but unusable.

Exact failing production path:

1. a legitimate `SkipAttackCommand` executes and opens canonical Maneuver;
2. the Attack Executor's command-result handler dismisses attack presentation;
3. executor teardown calls its flow end/publish operation and overwrites the
   accepted Maneuver projection with NONE;
4. `ModalRouter` runs later in the same command signal and cannot open the
   activation modal, although the active `ShipInstance` still has Maneuver
   OPEN.

Fix:

Attack Executor teardown now preserves a command-authored Maneuver projection
only when all canonical guards agree: the active ship's Attack step is
inactive, its Maneuver opportunity is OPEN, and interaction intent is exactly
Ship Activation / Maneuver. `ModalRouter` reopens activation presentation for
an accepted `skip_attack` only at that same guarded boundary. Inactive
one-attack reconstruction now creates the projected panel before wiring its
signals.

The repair does not advance or mutate activation state from presentation.
`ShipInstance` remains the activation-boundary owner; the command-owned
transition remains the only reason Maneuver is OPEN; InteractionFlow is used
only as derived routing intent.

## Verification

After repair, verify:

- ship with no attack performed can skip Attack and reach Maneuver correctly;
- ship can complete one attack, skip its remaining attack opportunity, and reach Maneuver;
- completing all available attacks normally reaches Maneuver;
- a rejected second `BeginAttack` followed by a legal Skip does not lose activation context;
- Maneuver is projected only when canonical `maneuver_opportunity_disposition == OPEN`;
- executing Maneuver consumes the opportunity;
- End Activation succeeds afterward;
- presentation does not synthesize semantic progression;
- Hot-Seat and Network behave equivalently;
- replay reproduces the same progression;
- save/load and reconnect during the post-Skip Maneuver boundary reconstruct the Maneuver interaction correctly.

Implemented regression evidence:

- `test_live_zero_attack_skip_projects_canonical_maneuver_boundary` proves a
  pre-Begin ship Skip opens Maneuver, projects an interactive modal, executes
  Maneuver, and completes End Activation.
- `test_live_remaining_attack_skip_projects_same_maneuver_boundary` starts
  after one completed attack, proves a forged second Begin is rejected without
  changing canonical progress, then proves the legitimate remaining Skip
  reaches the same Maneuver boundary with a wired control.
- Existing normal two-attack completion tests reach Maneuver without Skip.
- Scene-recreation tests prove the OPEN post-Skip boundary reconstructs from
  `ShipInstance`, including read-only non-owner projection.
- `test_network_owner_waits_then_projects_mirrored_skip_to_maneuver` proves a
  client does not advance optimistically and receives usable Maneuver only
  after the authoritative mirrored Skip.
- Command history assertions prove Maneuver execution and End Activation each
  complete once; replay/save/reconnect attack-boundary suites remain green.
- Focused production-resume tests passed (43/43), ship activation tests passed
  (21/21), reconnection tests passed (7/7), and replay-order tests passed
  (3/3).
- Full repository suite: 4038/4038 passed.
- Phase-K architecture lint: 0 violations (4 existing allow-listed branches).

Project Owner manual verification:

- Verified resolved in Hot-Seat mode on 2026-08-14.
- Accepted Skip proceeds from the canonical OPEN Maneuver opportunity into
  usable Maneuver presentation.
- Maneuver and the remainder of ship activation complete normally.

Final status: resolved, architecture-audited, and manually verified.
