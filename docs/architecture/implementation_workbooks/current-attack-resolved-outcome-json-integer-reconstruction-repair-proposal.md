# CurrentAttackState Resolved Outcome JSON Integer Reconstruction — Repair Proposal

Status: **Owner proposal accepted; bounded implementation authorized;
Boundary C implementation accepted after independent audit.**
Prepared: 2026-10-17. Boundary C is a separate prerequisite for the
Owner-accepted [atomic Counter implementation workbook](atomic-counter-choice-lifecycle-consolidated-implementation-workbook.md#L42)
(BC-009 / AT-008). Boundary A is accepted; Boundary B remains stopped.

## 1. Confirmed production defect

`ResolveDamageCommand` creates a native-integer Squadron outcome in
[`_execute_squadron()`](../../../src/core/commands/resolve_damage_command.gd#L310)
and native-integer Ship outcomes in
[`_execute_ship()`](../../../src/core/commands/resolve_damage_command.gd#L150)
and [`_resolved_ship_attack()`](../../../src/core/commands/resolve_damage_command.gd#L274).
The candidate Ship command has the same outcome shape in
[`CandidateResolveDamageCommand.execute()`](../../../src/core/commands/candidate_resolve_damage_command.gd#L185).
`CurrentAttackState.serialize()` copies the value; `GameState.serialize()` embeds
it. Godot JSON parsing changes its numbers to floats. On reconstruction,
[`GameState._deserialize_representation()`](../../../src/core/state/game_state.gd#L1243)
calls `CurrentAttackState.load_from_serialized()`, whose other declared integer
members are normalized, but
[`_validated_resolved_outcome()`](../../../src/core/state/current_attack_state.gd#L598)
only duplicates this dictionary. Installation therefore succeeds with floats.

| Outcome kind | Native integer members that become floats | Unchanged members |
| --- | --- | --- |
| Squadron | `requested_hull_damage`, `actual_hull_damage`, `post_resolution_hull` | `target_kind` string, `destroyed` boolean |
| Ship | `affected_zone`, `final_damage`, `shield_absorbed`, `post_resolution_shields`, `hull_damage` | `target_kind` string, `destroyed` boolean |

Bounded read-only proof used the real `ResolveDamageCommand.execute()` after an
invariant-valid Attack setup, then `GameState.serialize()` → `JSON.stringify()`
→ `JSON.parse_string()` → `GameState.deserialize()`. Squadron damage `0`, `2`,
and `7` against hull `5` all reconstructed successfully, but the three fields
above changed from `TYPE_INT` to `TYPE_FLOAT`; the excess case preserved the
distinct values requested `7`, actual `5`, post-hull `0`. A Ship damage `2`
case changed exactly the five Ship fields. A recursive serialized-state
comparison found no other differences in these four probes. Both the Attack
hash and full-state hash diverged. The cause is representation, not a changed
damage calculation: [`CanonicalJson`](../../../src/utils/canonical_json.gd#L10)
emits distinct `2` and `2.0` strings before SHA-256.

## 2. Smallest repair consistent with current authority

Change only `CurrentAttackState._validated_resolved_outcome()` on its existing
load/install path. Select the declared integer keys by the existing
`target_kind`, duplicate the outcome, and normalize each **present** declared
key with an outcome-specific representability guard, then the existing
integer conversion where safe. Do **not** call `_normalized_integral()` on an
unchecked float: its float branch does not guard signed 64-bit
representability before `int()` conversion. For each of the eight
declared keys, apply this policy before any conversion or Attack-state install:

| Input | Outcome-specific policy |
| --- | --- |
| Native `TYPE_INT` | Accept unchanged, including `-9223372036854775808` and `9223372036854775807`. |
| `TYPE_FLOAT` | Accept only when finite, mathematically integral, and in the half-open range `[-2^63, 2^63)`; then convert to `TYPE_INT`. Compare against the exact float powers of two **before** calling `int()`. |
| Other type or float outside those conditions | Reject the whole replacement; do not cast, default, or partially install. |

The exclusive upper bound matters: converting `INT64_MAX` to a float rounds it
to `2^63`, which is outside signed 64-bit range. A JSON-decoded `2^63` must
reject even if its source text was `9223372036854775807`; native
`INT64_MAX` remains valid. Likewise `-2^63` is an inclusive, exactly
representable float boundary. Do not claim exact roundtrip preservation for a
JSON integer whose value the float parser cannot represent exactly. This
guard is confined to the eight outcome fields; existing unrelated integer
normalization policies are unchanged.

Reject a present declared key if it is boolean, string, null, fractional,
nonfinite, out of range, or otherwise malformed. Preserve its numerical value;
never round, clamp, default, infer from `actual_hull_damage`, or change a Ship outcome
into a Squadron outcome. Leave the empty outcome for unresolved Attack stages
unchanged. Preserve unrelated keys and values, including mixed representations,
because this repair does not authorize a new exact-key schema or a recursive
normalizer. The existing Attack stage checks continue to govern empty versus
nonempty outcomes. Unknown `target_kind` values receive no new interpretation;
any stricter rejection belongs to a separate schema decision. The accepted
Counter consistency check, when later implemented, separately rejects an
absent, negative, or malformed native Squadron
`requested_hull_damage` before publication.

This follows owner-local integer reconstruction already used by
[`CurrentAttackState._validated_data()`](../../../src/core/state/current_attack_state.gd#L286)
and the purpose-specific completed-inspection outcome validator in
[`CompletedAttackInspection`](../../../src/core/state/completed_attack_inspection.gd#L165).
It changes no damage producer, command codec, `InteractionFlow`, generic JSON
parser, projection, or replay format. A stricter required/exact outcome schema
would be a separate architecture decision, not a prerequisite of this repair.

## 3. Production consumers and recovery impact

| Path | Effect and verification obligation |
| --- | --- |
| Save/Load | Signed Save-10 JSON is parsed and verified before `GameState.deserialize()` in [`SaveGameManager`](../../../src/autoload/save_game_manager.gd#L204). [`IntegritySigner`](../../../src/utils/integrity_signer.gd#L83) already normalizes JSON number representation for signing, so validation should precede outcome reconstruction without changing signatures. Valid current saves should load with native outcome integers and the same semantic state. Reject malformed present declared values without changing signatures or saved files. |
| Network reconstruction and reconnect | [`StateFilter`](../../../src/core/network/state_filter.gd#L36) reconstructs full authority before filtering; [`NetworkManager._receive_resume_snapshot()`](../../../src/autoload/network_manager.gd#L836) reconstructs a passive client snapshot before staging it at fresh resume/reconnect. Both use the same Attack validator. Malformed present outcome integers must be rejected at **both** boundaries: filtering returns failure with no transmissible snapshot, and the client rejects staging, acknowledges failure, and never commits the snapshot. Neither path may partially install authoritative state. Verify both role mappings, filtered visibility, cursor, and canonical outcome agreement. Fingerprints and state hashes must be compared on the correct full or filtered representation. |
| Replay | [`GameReplay`](../../../src/core/commands/game_replay.gd#L108) stores ordered serialized commands, not an Attack-state snapshot. Replay execution produces native outcomes. A replay or resume path that reconstructs `GameState` from JSON benefits from the repair; command order, result schema, and history stay unchanged. |
| Live consumers | [`GameManager`](../../../src/autoload/game_manager.gd#L2965) exports `resolved_outcome` for remote damage presentation. [`AttackExecutor`](../../../src/scenes/game_board/attack_executor.gd#L3455) and its completion display, and [`AttackPanelMirror`](../../../src/scenes/game_board/attack_panel_mirror.gd#L245), read/cast outcome totals. [`CompleteAttackCommand`](../../../src/core/commands/complete_attack_command.gd#L40) transfers the outcome into `CompletedAttackInspection`, whose validator already restores declared integers. Existing casts may hide the defect visually; they do not repair canonical state. |
| Deterministic hashing | Compare exact `current_attack_state.serialize()` and hash before/after JSON reconstruction. Compare complete `GameState.serialize()` and hash only after first-field inspection confirms all unrelated state stable; report independent `pos_x` or GGS-001 divergence separately. No accepted hash is promoted merely because peers agree or a replay completes. |

## 4. Canonical decision ownership

This normalization creates no committed decision. The accepted
[`CON-001` Counter rules](../contracts/CON-001-current-attack-state-and-semantic-transition-contract.md#L889)
make the active parent Attack the canonical owner of requested Squadron damage
and require a complete Counter publication to use that native integer, never
the capped applied amount. At the resolved, prepublication boundary, requests
`5` and `7` against remaining hull `5` have the same applied damage and
destruction state but require different valid `final_damage` publications.
The parent outcome is the distinguishable witness through Save/Load and
reconnect; a flow payload, callback, queued follow-up, or replay history cannot
replace it. JSON reconstruction must retain that witness's value **and type**.
Counter Accept/Decline ownership, transfer to inspection **I**, atomic
consumption, and child/enclosing return remain governed by the accepted
Counter workbook; Boundary C changes none of those commands or owners.

## 5. Focused verification and compatibility gates

1. Through production damage commands, cover Squadron requested `0`, positive
   below remaining hull, and excess over remaining hull, plus Ship shield-only
   and hull-damage outcomes (including the candidate/passive Ship producer).
   Assert every declared member's native type and value, Attack equality/hash,
   and complete-state equality/hash only where all other fields are stable.
2. Test direct Attack installation and genuine full `GameState` JSON
   reconstruction. Native integers must remain integers on direct install;
   decoded finite integral floats within the signed 64-bit range must become
   integers without changing value. Assert JSON roundtrip convergence where
   the source integer is exactly preserved by float parsing; malformed present
   declared values must fail before state install. For each declared outcome
   key, exercise native `INT64_MIN` and `INT64_MAX`; the representable floats immediately
   below and above `-2^63`, `-2^63` itself, the representable float immediately
   below `+2^63`, and `+2^63`; fractional and nonfinite floats; and oversized
   whole floats including `1e20` and `-1e20`. Assert `+2^63` rejects even when produced by
   converting `INT64_MAX` to float. Compare retained native types and values
   at accepted boundaries, and assert rejection before any `int()` cast for
   out-of-range floats. Do not infer that an unrepresentable JSON source
   integer survives float parsing exactly. Keep these representability tests
   separate from the Counter rule that rejects negative requested damage.
   Assert that unrelated fields and unknown keys, including their strings and
   booleans, and empty unresolved outcomes are unaffected. Do not accept a
   missing Squadron requested value as a Counter recovery witness.
3. Inject malformed **present** fields into an otherwise valid resolved Attack
   and test the two Network paths independently. Through
   `StateFilter.filter_for_player_checked()` on a full-authority state, assert
   failure and absence of any transmissible filtered snapshot. Through the
   passive client snapshot receiver and `GameState.deserialize_passive_network()`,
   assert staging rejection, negative acknowledgement, no commit, and no
   partial authoritative-state install. Cover malformed type, fractional,
   nonfinite where direct input permits, and out-of-range integral float,
   including `2^63`/`1e20`, in both paths and both player mappings.
4. Exercise current signed Save-10 safe points, Network-11 filtered snapshot
   and reconnect in both player mappings, ordered Replay-12 execution, and
   accepted baseline traces without altering fixtures or hashes. Check the
   first divergent canonical field if a full-state assertion fails. No format
   or protocol bump is needed for this isolated representation repair because
   it adds no field or JSON syntax and restores established native semantics.
   Existing malformed outcome members that were previously copied through may
   now reject; that is the narrow compatibility limit.
5. Keep the accepted Counter package's separate Save-11 / Network-12 /
   Replay-13 cutover and Owner-recorded replay fixtures at its later E2/E4
   gates. Boundary C acceptance is E1; it cannot authorize Boundary B restart,
   Counter implementation, fixture regeneration, or hash promotion.

Boundary A's completed `InteractionFlow` reconstruction remains untouched.
The stopped Boundary B command-codec work remains untouched. Boundary C must
be accepted independently before the consolidated Counter package may claim
reconstructed `final_damage` or full-state digest convergence. GGS-001 and
coordinate precision remain separate findings.

**Proposal acceptance and implementation are distinct.** The Owner accepted
this proposal and authorized its bounded implementation. The repair and tests
are recorded in the
[implementation evidence](../evidence/boundary-c-resolved-outcome-integer-reconstruction-implementation-verification.md);
the independent implementation audit passed and the Owner accepted the
Boundary C implementation. No unresolved Owner behavior decision remains
for this narrow reconstruction.
The combined-tree 19 failures are attributed to stopped Boundary B; the
isolated Boundary C full suite converged after its ignored gameplay log
directory was present. This isolated pass does not establish combined-tree
convergence. Boundary C satisfies the separate implementation-acceptance
requirement of Counter gate E1; this does not resume Boundary B or authorize
Counter implementation.
