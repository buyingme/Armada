# BUG-043 Entry Gate Report

Captured: 2026-09-13

## Repository baseline

- Route: uncertain/high-risk architecture; accepted workbook is the sole implementation specification.
- Branch/worktree: `master`, `/Users/Katharina/godot/Armada`.
- HEAD: `155d9ff5a05a93843f482d6908a9598d640d6d71` (`docs: accept BUG-043 maneuver implementation workbook`).
- Tracking: `master...origin/master [ahead 10]`.
- Entry worktree: the user-owned legacy BUG-043 patch listed below; no unattributed overlap.
- Entry diff stat: 10 tracked files, 575 insertions, 42 deletions, plus one untracked test.

The legacy patch is owned by the Project Owner and is preserved as migration
evidence/removal scope. It modifies:

- `docs/requirements/gameplay_interactions/ship_maneuver_interaction.md`
- `docs/requirements/gameplay_interactions/ship_maneuver_owner_decisions.md`
- `src/autoload/game_manager.gd`
- `src/core/movement/maneuver_tool_state.gd`
- `src/core/state/ship_activation_state.gd`
- `src/scenes/game_board/ship_activation_controller.gd`
- `src/scenes/tools/maneuver_tool_scene.gd`
- `tests/unit/test_attack_commands.gd`
- `tests/unit/test_network_command_result_ordering.gd`
- `tests/unit/test_ship_activation_state.gd`
- untracked `tests/unit/test_bug_043_maneuver_speed_convergence.gd`

Its implementation direction is the obsolete pre-commit SetSpeed convergence
path identified by the accepted workbook. It will be reconciled at the WP6
legacy-removal boundary, without destructive overwrite of unrelated Owner work.

## Authority hashes

| Authority | SHA-256 |
| --- | --- |
| Accepted BUG-043 workbook | `d828941a9daf78ecdec9cfa8b82209d39698af5692e8e88313fccc6b71aaf1a1` |
| ADR-006 | `15058129adc5ed3b2e9e5282153c9ed8036e1b2e003608a4cdc3e434fef46b79` |
| ADR-014 | `e4ff09495e8a604748d642d3f4feee8dca4b7c921155de0567ee191275aa8e88` |
| Ship Maneuver requirements | `e2558e330aca2ee9a76c4ba0a30335205e7beb5872831197394e61d5be18fc92` |
| Ship Maneuver Owner decisions | `8a4305145aee473c1e488cc8e6f2b1fbf5f1db302061cbf8f7f132166469aa76` |
| CON-003 | `729bb39f0c6b7e33b65d03b52a2a9fadb3631ada9da46e09b9d1b9fa014108e3` |
| TEST-003 | `e6b31ae033c90263bcd8cdaead80c86c6924459425a95f21ce8f9226335c6a7c` |
| CAP-DMG-001 | `9fe63ec06bc7d4bc3884cde241b790332f48d8b9dce6d803b7a076fedafb2088` |
| CAP-DMG-002 | `6e336d771ec7cca5ac905e0e2fed4fe07666bfd3abb934418f02e53f8878f96c` |
| CAP-DMG-003 | `55bafe04e62595a6b33d9c7d79f1d305837e32fb8fe8688f5c3a692fee287565` |
| CAP-DMG-004 | `c90304e1bf21a49ec1d5998d16137724634517b513e99aa1d4a467082dbcea64` |
| CAP-DMG-005 | `d629382336f7b2c969a1e29bb452b5e4ca6ab230ba8a70eea83802a491c080eb` |
| CAP-DMG-006 | `5bf810bd3ecb51d2bd3f82175b3b9a888b4d33667b6cf3850494622f310438fc` |
| CAP-DMG-007 | `4d33904fcd0bf6cac26aec39c107f0a2d5f14c07af204a6c63ea46914774eb91` |
| CAP-DMG-008 | `0302cf11d81532e104d34798eb736c7ac1489ab59d0b25541007ef7a25d2a08d` |
| CAP-DMG-009 | `a7032f7e8f10492067fb96b22dc4108a027086106170874d5e11d056d8686b68` |
| CAP-OBS-001 | `da76c87c54d2adc95722d9745dba4793ed961648709c9766dc94eb3504e84bde` |
| CAP-OBS-002 | `f09b2d0512d2fe2c4b79aea9f2af56663c7b67543aa4c0d5cdaf05a602dc9bd6` |
| CAP-OBS-003 | `ac407e2c94cecf2604e2b393da5af5e69b86e2bb11cd7654cf3bc9d8950a102c` |

## Versions and package state

| Owner | Required | Observed | Result |
| --- | ---: | ---: | --- |
| SaveGameMetadata | 6 | 6 | PASS |
| GameReplay | 9 | 9 | PASS |
| GameReplay signed alias | equals format | alias of format | PASS |
| NetworkManager protocol | 6 | 6 | PASS |
| GameCommand application contract | 1 | 1 | PASS |
| PassiveDamageLedger schema | exact four-field schema 1 | schema 1: `schema_version`, `draw_count`, `discard_pile`, `facedown_counts` | PASS |

All twelve RCPs exist as distinct packages. Each is `Draft`, and each records
Owner approval as not requested. No package claims `Integrated`.

## Production seam revalidation

All Section 2.3 seams exist with their expected current signatures and
ownership: ShipInstance/GameState activation state; ExecuteManeuverCommand and
GameManager commitment path; transient maneuver tool state/scene/controller;
ManeuverCalculator and OverlapResolver; StartDisplacementCommand and
CommitDisplacementCommand; DamageCard, DamageDeck, PassiveDamageLedger and
ShipInstance damage collections; ResolveImmediateEffectCommand,
ImmediateEffectResolver, DebugDealDamageCommand and Attack damage commands;
the three Maneuver-card RuleRegistry implementations and
PersistentEffectDamageCommand; setup obstacle placement/catalog data;
FlowSpec, CommandApplicability and UIProjector; CommandProcessor authority-side
post-success composition; SaveGameMetadata/SaveGameManager; GameReplay and
replay driver; NetworkManager and StateFilter.

Observed missing active Maneuver, stable physical-card identity, active
immediate record, exact application correlations, authoritative contour, and
purpose-specific consequence surfaces match the workbook's expected
implementation gaps rather than entry blockers.

## Contour gate

Entry originally found no approved real-token contour evidence. The Project
Owner subsequently approved `obstacle-alpha-mask-contour-evidence-v3`, SHA-256
`edd2c9597e75a4a092b7c3cc9fe8b899d421b02720a8731b1eb5e6578f505eb0`,
on 2026-09-16. Section 18's contour gate is therefore passed for that exact
immutable dataset and post-gate WP3b work may proceed.

## Existing replay evidence inventory

Read-only inventory; no file was copied, edited, transformed, relabeled, or
promoted:

| Existing file | SHA-256 |
| --- | --- |
| `tests/fixtures/baseline_traces/replay_hot_seat_solo.json` | `267d018150e71b7134c92b5fdc6223b8bd40da19d387d4c133087e15b386244b` |
| `tests/fixtures/baseline_traces/baseline_trace_hot_seat_solo.jsonl` | `66c94615a28a9761bcc9b5f8236e417d7da7b3f3c7646e8e6a87650a328873b5` |
| `tests/fixtures/baseline_traces/replay_network.json` | `cf69fae08e3d2059e8a9d6d7057fb5e13854fcdd296b880befe4017a168e8f36` |
| `tests/acceptance/network_resume/network_replay_v7.json` | `9dad85420f64c8df0b7c59b274ed33cd56ee57c53dc9520c2191fdd519c40bd9` |
| `docs/qa/bugs/open/BUG-043/replay_20260906_070521.json` | `8baebb230e8ce498b863f5bd87c1bdb819f55907da5e65158e725b2abe4efba3` |
| `docs/qa/bugs/open/BUG-043/annotation_20260906_064217_001.json` | `a9c0260a787146c60b0e2dc12a621fa50be8590221c7c071a94286cc5f3e1d86` |

The full-suite entry run emitted one ignored temporary replay as an existing
test-harness side effect. Per the Owner's clarification, it was deleted and was
not inspected, retained, transformed, or used as evidence.

## Entry verification

- Full suite: PASS — 251 scripts, 4,206 tests, 4,206 passing, 0 failing,
  15,403 assertions, no skips reported.
- Phase-K/N architecture lint: PASS — 0 retired legacy effect surfaces,
  0 violations, 5 existing allow-listed branches.
- `git diff --check`: PASS.
- Pre-existing relevant failures: none.
- Pre-existing unrelated failures: none.

## Verdict

PASS. The accepted sole-workbook authority transition is present at HEAD, all
entry allocations match, the legacy patch is attributed, and no entry failure
prevents WP1 foundation work. Real-contour-dependent work remains blocked at
the Section 18 Owner gate.
