# BUG-003 — Attack Can Be Skipped After Commitment

Severity: High
Area: Attack Execution
Layer: Command Flow

## Expected

An attack may be skipped or cancelled only before it reaches its commitment point.

After the attack has been confirmed and dice have been rolled:

- the attack must continue through its remaining resolution steps;
- the Skip Attack action must no longer be projected;
- any attempted skip command must be rejected by the authoritative command flow.

## Actual

The player can still skip an attack after it has been confirmed and the attack dice have been rolled.

This allows an already committed attack with authoritative dice results to be abandoned before resolution is complete.

## Reproduction

1. Activate a squadron and select a legal target.
2. Confirm the attack.
3. Roll the attack dice.
4. Attempt to skip the attack during the attack-modification stage.

Result: The attack can still be skipped after dice have been rolled.

Frequency: Always

## Evidence

annotation_20260729_065933_002.json

The captured state shows:

- an active attack with ID attack:70;
- the attacker and defender already selected;
- obstruction resolved;
- four blue dice rolled;
- authoritative dice results present;
- attack stage attack_modify;
- interaction-flow step 18.

## Investigation Hint

The issue is visible after the attack transitions from pre_roll to attack_modify.

Inspect how the availability and authorization of the Skip Attack action are derived after dice results become authoritative.

## Resolution

Root cause:

- `AttackExecutor.apply_begin_attack_result()` and the active-attack resume
  renderer continued to show the pre-Begin Skip control after
  `BeginAttackCommand` had committed `CurrentAttackState`.
- `SkipAttackCommand.validate()` already rejected an active attack with the
  non-terminal reason `voluntary`, but `GameManager.submit_skip_attack()`
  rewrote every non-terminal reason to `cancelled` whenever an attack was
  active. The wrapper therefore changed a forged/user voluntary Skip into a
  distinct terminal-cancellation semantic that authoritative validation
  legitimately accepts.

Exact failing production path:

1. `BeginAttackCommand` commits the attack and authoritative dice pool.
2. `AttackExecutor` re-projects the Skip control during live execution or
   reconstruction.
3. the control submits `reason = "voluntary"`;
4. `GameManager.submit_skip_attack()` rewrites the reason to `cancelled` and
   adds the active attack identity;
5. `SkipAttackCommand` validates the rewritten cancellation and retires the
   committed attack.

Fix:

- Removed the semantic reason rewrite from `GameManager`; callers now submit
  exactly the reason they selected and command validation remains decisive.
- Retired the voluntary Skip projection immediately after accepted Begin and
  in every active-attack reconstruction stage.
- Kept the existing explicit terminal reasons (`cancelled`, `flow_replaced`,
  and `flow_terminated`) unchanged for legitimate lifecycle termination.

This does not add a command or owner. `CurrentAttackState` remains canonical,
`SkipAttackCommand` remains the authoritative validator/mutator, and the
attack panel remains a one-way projection.

Verification:

- `test_active_attack_rejects_forged_voluntary_skip_without_mutation` proves
  direct command validation preserves the complete serialized attack/dice
  state.
- `test_game_manager_does_not_rewrite_post_commit_voluntary_skip` proves the
  production wrapper cannot bypass that validation and rejected commands do
  not enter replay history.
- Production-board tests prove pre-commit Skip remains visible, accepted Begin
  retires it, and reconstruction/network roll projection does not restore it.
- Existing ship and squadron attack protocol tests continue normal attack
  resolution and explicit lifecycle cancellation paths.
- Focused command/projection suites passed, including
  `test_attack_commands.gd` (64/64),
  `test_current_attack_production_resume.gd` (43/43), and
  `test_current_attack_shared_protocol.gd` (25/25).
- Full repository suite: 4038/4038 passed.
- Phase-K architecture lint: 0 violations (4 existing allow-listed branches).

Project Owner manual verification:

- Verified resolved in Hot-Seat mode on 2026-08-14.
- Voluntary Skip is no longer available after accepted `BeginAttack` attack
  commitment.
- Normal committed attack completion continues to work.

Final status: resolved, architecture-audited, and manually verified.

## Layer Definition

### Rules

Game mechanics or rules behave incorrectly.

### Command Flow

Commands, interactions, or game progression execute incorrectly, become unavailable, remain available when invalid, or occur in the wrong order.

### Projection

Displayed game information or available actions differ from the authoritative game state.

### Presentation

Visual elements, text, layout, or UI controls behave incorrectly without affecting the underlying game state.

### Architecture

The defect appears to originate from system ownership, lifecycle, or architectural responsibilities.

### Serialization

Save, load, reconnect, replay, or persisted game state behaves incorrectly.

### Networking

Remote synchronization, visibility, or multiplayer state differs from the authoritative game state.

### Performance

The game exhibits excessive loading time, poor responsiveness, frame drops, freezes, or resource issues.
