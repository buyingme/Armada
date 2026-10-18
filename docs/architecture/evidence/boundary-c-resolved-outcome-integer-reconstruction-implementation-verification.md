# Boundary C Resolved Outcome Integer Reconstruction — Implementation Evidence

Status: **Owner proposal accepted; bounded implementation authorized;
Boundary C implementation accepted after independent audit.**
Recorded: 2026-10-18. Scope: BC-009 / AT-008, under the
[Owner-accepted Boundary C proposal](../implementation_workbooks/current-attack-resolved-outcome-json-integer-reconstruction-repair-proposal.md).
Boundary A remains accepted. Boundary B and atomic Counter implementation remain
stopped.

## Repair

[`CurrentAttackState._validated_resolved_outcome()`](../../../src/core/state/current_attack_state.gd#L598)
now selects only the three declared Squadron or five declared Ship integer keys
for the existing `target_kind`. It keeps native integers, converts finite
integral floats in `[-2^63, 2^63)` to integers, and rejects malformed present
members before casting. It duplicates the outcome before validation, so a
failed reconstruction installs no partial Attack state. Missing keys, unrelated
members, unknown target kinds, and the empty unresolved outcome retain their
previous treatment. The separate `_normalized_integral()` policy is unchanged.

`requested_hull_damage` remains distinct from capped `actual_hull_damage`:
the production Squadron excess-damage test retains requested `7`, actual `5`,
and post-resolution hull `0` across JSON reconstruction. The canonical Attack
and full GameState representations and hashes converge for the stable production
cases tested. Save 10, Network 11, and Replay 12 version constants are unchanged.

## Verification

| Gate | Result |
| --- | --- |
| [Focused unit regression](../../../tests/unit/test_current_attack_outcome_reconstruction.gd) | PASS: 8 tests, 746 assertions. Covers Squadron 0/2/7 damage, Ship shield-only and hull damage, all eight keys at signed 64-bit boundaries, malformed values, direct and JSON GameState reconstruction, atomic rejection, both player mappings, and both Network reconstruction boundaries. |
| [Real ENet controlled rejection](../../../scripts/run_boundary_c_network_rejection.sh) | PASS: 2 player mappings. In each, a valid principal, Network-11 metadata, and cursor 1 for attack:0 staged through the real receiver and received a positive acknowledgement. A second snapshot differing only in present Squadron requested_hull_damage (1 → 1e20) received a negative acknowledgement; client staging cleared, no commit occurred, and host authoritative state/hash stayed unchanged. |
| Save/Load round trip | PASS: 14 tests, 117 assertions. |
| Replay | PASS: 39 tests, 119 assertions. |
| Baseline traces | PASS: Hot-Seat trace and hash, Network peer state equality, and replay baselines; observed Network hash `f680d174b17e168b3e0416557864646d34c0feb74bde43d0f0b19234eeaf99d0`. No baseline or expected hash was promoted. |
| Network reconnect acceptance | PASS: MATCH-003 real ENet fresh-resume and Section 14.2 D compatibility scenarios. |
| Combined working-tree full suite | FAIL: 282 scripts, 4,477 tests, 4,458 passing, 19 failing, 23,444/23,501 assertions. All 19 failures begin with the stopped Boundary B publication preflight rejecting test commands without Dictionary flow_payload; follow-on timing, replay, and reconnect assertions then fail. This tree has not converged. |
| Isolated log-directory targeted rerun | PASS: the two previously failing network-bootstrap tests passed individually, 1/1 test and 2 assertions, then 1/1 test and 5 assertions. |
| Isolated baseline plus Boundary C full suite, with log directory present | PASS: 281 scripts, 4,469/4,469 tests, 23,072 assertions, 0 failures. This is the isolated Boundary C convergence result, not an integrated combined-tree result. |

The unit regression sends malformed present fields through
`StateFilter.filter_for_player_checked()` on full-authority state and through
`GameState.deserialize_passive_network()` on filtered state. For each of the
eight keys, both player mappings reject malformed type, fractional and
nonfinite values, and out-of-range integral floats including `2^63` and
`1e20`. Filtering yields no transmissible snapshot. The real ENet regression
exercises the passive snapshot receiver and its negative acknowledgement.

## Limits and disposition

The combined full suite has failures in tests exercising the pre-existing,
stopped Boundary B attack-flow publication preflight. It rejects fixture
commands with `Attack-flow publication requires a Dictionary flow payload.`
No Boundary B code or tests were changed as part of Boundary C. The combined
tree cannot be cited as integrated convergence.

The isolated environment was created from committed baseline
`ac5780dadaf93f1f56f562f97c4167b6adaaaf85` plus exactly five Boundary C
production/test files. Archive comparison found one modified baseline file
(`current_attack_state.gd`) and four added test/runner files; no Boundary B
changes were present. A first launch reached no tests because this fresh copy
needed Godot class/resource import. Import completed without script errors.
The next full suite reached all tests but initially had two log-file open
errors at 12:20:55. The isolated `res://logs` directory was born at
12:20:58, after those errors; it is ignored by Git and absent from the
committed archive. The normal project already had a writable `logs/`
directory. The runner makes a separate temporary directory for Godot's own
log, but it does not create the gameplay `res://logs/` directory used by
`GameLogger.enable_file_logging()`. `FileAccess.open()` does not create
parent directories. The only correction was to ensure that the isolated
`logs/` directory existed with user write permission before the rerun.
Both targeted tests then passed, followed by the isolated full-suite pass
recorded above.

The production-registered candidate Ship damage command supplies the hull
damage round trip. A direct invocation of the older Ship command with drawn
damage cards can serialize an empty card identity; that separate legacy command
path was not changed or used as a Boundary C success claim.

The signed Save-10 compatibility suite covers supported save/load states.
An attempted signed save of the standalone resolved-Attack fixture could be
written but did not meet the loader's existing active-Attack command-cursor
safe-point requirement; it was removed from the regression because it is not
a valid Save-10 recovery state. Full `GameState` JSON reconstruction and exact
canonical hashes are directly covered for resolved Attack states.

No replay fixture, baseline, expected hash, historical evidence, or version
constant was modified. The independent implementation audit passed and the
Owner accepted Boundary C. The isolated Boundary C full-suite gate converges.
The combined tree's 19 Boundary B failures are not Boundary C acceptance
evidence and remain an integration concern. Boundary B and atomic Counter
implementation remain stopped.
