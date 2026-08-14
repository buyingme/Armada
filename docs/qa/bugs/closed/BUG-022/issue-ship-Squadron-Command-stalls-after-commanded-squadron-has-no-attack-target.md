# BUG-022 — Ship Squadron Command stalls after commanded squadron has no attack target

Severity: High
Area: Ship Squadron Command / Squadron Activation
Layer: Command Flow

## Expected

When a squadron is activated through a ship's Squadron command and moves but has no legal attack target:

1. the unused attack action must be resolved through the appropriate authoritative semantic path;
2. the squadron activation must complete only after its canonical action state is complete;
3. if additional Squadron-command activations remain, the player must be able to activate the next eligible squadron;
4. only after the Squadron command is legitimately complete may the command dial/token be spent and the ship activation advance to the next step.

Presentation must wait for accepted canonical transitions and must not end the Squadron command after a rejected completion command.

## Actual

After a squadron activated through a ship's Squadron command moves and has no legal attack target, the modal attempts to auto-finish the squadron activation.

`CompleteSquadronActivationCommand` is correctly rejected because the squadron still has an available attack action.

Despite that rejection, presentation continues as though the squadron or Squadron command has completed.

Depending on the interaction sequence:

- the next eligible commanded squadron cannot be activated; or
- the Squadron command is ended prematurely;
- the command dial is spent;
- the ship activation attempts to advance to Repair;
- that `advance_activation_step` command is then rejected because declaration-adjacent canonical state is still invalid.

The game becomes stalled because the canonical ship/squadron activation remains incomplete while the UI required to continue it is no longer available.

## Reproduction

Reproduced twice.

### Reproduction 1

1. Activate the Nebulon-B Escort Frigate.
2. Resolve a Squadron command.
3. Activate and resolve the first commanded X-wing.
4. Activate a second commanded X-wing.
5. Move the squadron to a position with no legal attack target.
6. Allow the modal to process the no-target state.

Result:

- the activation modal disappears / progression becomes unusable;
- the game does not proceed correctly;
- the next required ship-activation interaction is unavailable.

### Reproduction 2

1. Activate the Nebulon-B and enter its Squadron command.
2. Activate a commanded X-wing.
3. Move it where no legal attack target is available.
4. Observe the automatic completion attempt.
5. Attempt to continue or end the Squadron command.

Result:

- squadron completion is rejected because an attack action remains canonically available;
- the modal can nevertheless proceed toward ending the Squadron command;
- the ship activation then stalls.

## Evidence

- `annotation_20260814_125821_001.json`
- `annotation_20260814_132727_001.json`
- `game_20260814_125441.log`
- `game_20260814_132516.log`
- `replay_20260814_125834.json`

### Canonical-state evidence

At the first captured stalled state:

- Ship Phase is active.
- Nebulon-B has:
  - active `ship_activation_identity`;
  - `squadron_command_opportunity_disposition = "OPEN"`;
  - `squadron_command_activations_committed = 2`;
  - Maneuver remains `UNREACHED`.
- The second commanded X-wing has:
  - `activation_context = "ship_squadron_command"`;
  - active squadron activation identity;
  - `move_action_committed = true`;
  - `attack_action_disposition = "available"`;
  - `activated_this_round = false`.

The canonical state therefore still represents an incomplete commanded-squadron activation even though the presentation required to continue it has disappeared.

The second reproduction captures the same basic state with one committed Squadron-command activation and an active second squadron whose movement is committed but attack action remains available.

### Log evidence

The production log exposes the failing sequence:

`No targets after move — auto-finishing activation.`

followed by:

`Command rejected [complete_squadron_activation]: Squadron still has an available action.`

In one reproduction presentation then continues with:

- Squadron command finalized;
- `spend_dial` accepted;
- Squadron command signals completion;
- ship activation advances locally toward Repair;
- authoritative `advance_activation_step` rejects with:
  `Declaration-adjacent state is invalid.`

This demonstrates that presentation progresses after a failed semantic completion rather than waiting for an accepted canonical result.

### Replay evidence

The replay records:

- sequence 74 — `activate_squadron`
- sequence 75 — `move_squadron`
- sequence 76 — `spend_dial`

There is no accepted `skip_attack` or `complete_squadron_activation` between movement of the second squadron and spending the Squadron dial.

The recorded command history therefore confirms that the commanded squadron's remaining attack action was never semantically resolved before the Squadron command was treated as complete.

## Initial Assessment

The immediate failing behavior appears to be the commanded-squadron equivalent of a pre-Begin/no-target declaration exit problem.

After movement with no legal attack target, presentation attempts to complete the squadron directly even though canonical state still contains an available attack action.

The correct semantic path likely needs to resolve/decline that remaining attack opportunity before squadron completion, rather than weakening `CompleteSquadronActivationCommand`.

A second defect may be present in the presentation lifecycle: after the completion command is rejected, the modal still progresses toward Squadron-command completion and can spend the dial / request the next ship activation step.

Do not assume these are separate root causes until the complete command/result path has been investigated.

## Relationship to BUG-018

BUG-022 is closely related conceptually to BUG-018 but occurs in a different gameplay context.

BUG-018 repaired pre-Begin Skip during Squadron Phase.

BUG-022 occurs during `ship_squadron_command` activation and additionally demonstrates premature Squadron-command completion/dial spending after an unsuccessful squadron-completion transition.

Track it separately unless investigation proves that the exact same production defect remains incompletely generalized.

## Resolution

Root cause:

`SquadronActivationModal.notify_move_completed()` treated “no target after
move” as activation completion and called `_finish_activation()` directly.
Movement does not consume an AVAILABLE canonical attack action, so the
resulting `CompleteSquadronActivationCommand` correctly rejected the
incomplete `SquadronInstance`. The modal/controller continuation nevertheless
continued its local completion path, which could finalize the ship's Squadron
command, spend its dial, and request the next ship step without an accepted
semantic resolution of the squadron attack opportunity.

Exact failing production path:

1. `MoveSquadronCommand` commits the commanded squadron's move.
2. target availability is re-derived as empty while
   `attack_action_disposition` remains `AVAILABLE`.
3. `notify_move_completed()` directly emits activation completion.
4. `CompleteSquadronActivationCommand` rejects “Squadron still has an
   available action.”
5. presentation proceeds optimistically; the replay can therefore record
   `spend_dial` without an accepted declaration Skip/completion boundary.

Fix:

The automatic no-target branch now uses the existing TWI-003/BUG-018
declaration Skip route with reason `no_targets`. The modal becomes pending,
the controller submits `SkipAttackCommand`, and presentation advances only
when the authoritative result has declined the canonical attack action. A
rejection restores the same interaction. The explicit Skip button continues
to use the same path with reason `voluntary`.

No completion validation was weakened. No command, canonical field, FSM, or
owner was added: `SquadronInstance` remains the action owner,
`SkipAttackCommand` remains the semantic transition, and dial spending still
follows accepted ship-command completion.

## Verification

After repair, verify:

- a commanded squadron that moves and has no legal attack target resolves its unused attack opportunity through an accepted semantic command;
- `CompleteSquadronActivationCommand` is not weakened to accept incomplete canonical action state;
- after the first commanded squadron completes, another eligible commanded squadron can be activated when command capacity remains;
- after the final commanded squadron completes, the Squadron command closes exactly once;
- the Squadron dial/token is spent only after valid command completion;
- the ship then advances canonically to the next activation step;
- a rejected squadron command cannot cause optimistic modal progression or dial spending;
- ship-commanded squadrons that do have legal attack targets remain able to attack normally;
- early voluntary termination of the Squadron command remains valid where allowed;
- Hot-Seat and Network behavior are equivalent;
- replay records the complete semantic progression;
- save/load and reconnect preserve any active commanded-squadron activation correctly.

Implemented regression evidence:

- `test_command_move_without_target_requests_skip_before_completion` proves
  the modal requests semantic Skip, remains pending, does not emit completion,
  and does not mutate the AVAILABLE canonical action.
- `test_commanded_move_no_target_waits_for_skip_and_preserves_capacity`
  exercises the production board in Hot-Seat: movement re-derives no targets,
  premature Complete remains invalid, the dial remains revealed, the first
  accepted Skip exposes a second commanded squadron, and final command
  completion spends the dial exactly once.
- `test_network_commanded_no_target_waits_for_mirrored_skip` proves a network
  client remains pending until the mirrored Skip, then requests dial spend and
  ship continuation; the dial is not consumed before its mirrored command.
- Command history assertions prove accepted sequences contain the declaration
  Skips, never an optimistic `complete_squadron_activation`, and spend the dial
  only at final valid completion.
- Existing BUG-018 save/replay/network declaration-Skip tests and commanded
  target-present attack tests remain green.
- Focused suites passed, including `test_squadron_activation_modal.gd`
  (37/37), `test_current_attack_production_resume.gd` (43/43), and
  `test_squadron_attack_target_recovery.gd` (16/16).
- Full repository suite: 4038/4038 passed.
- Phase-K architecture lint: 0 violations (4 existing allow-listed branches).

Project Owner manual verification:

- Verified resolved in Hot-Seat mode on 2026-08-14.
- A commanded squadron that moves and has no target resolves the remaining
  attack opportunity through the accepted declaration Skip path.
- The next commanded squadron can be activated when capacity remains, and the
  ship continues through its activation normally.

Final status: resolved, architecture-audited, and manually verified.
