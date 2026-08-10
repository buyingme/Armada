All remaining checks passed, and the repository remained clean.

# TWI-003 Entry Gate Rerun Report

## 1. Startup Documents Read

Required startup documents read in full before verification:

1. [AGENTS.md](/Users/Katharina/godot/Armada/AGENTS.md)
2. [ARCHITECTURE.md](/Users/Katharina/godot/Armada/ARCHITECTURE.md)
3. [AI_DEVELOPMENT_PRINCIPLES.md](/Users/Katharina/godot/Armada/docs/development/AI_DEVELOPMENT_PRINCIPLES.md)
4. [AI_DEVELOPMENT_PROCESS.md](/Users/Katharina/godot/Armada/docs/development/AI_DEVELOPMENT_PROCESS.md)
5. [AI_STARTUP_GUARDRAILS.md](/Users/Katharina/godot/Armada/.ai/instructions/AI_STARTUP_GUARDRAILS.md)
6. [DOCUMENT_AUTHORITY.md](/Users/Katharina/godot/Armada/docs/architecture/DOCUMENT_AUTHORITY.md)
7. [ARCHITECTURE_ROADMAP.md](/Users/Katharina/godot/Armada/docs/architecture/ARCHITECTURE_ROADMAP.md)
8. [CODEX_WORKFLOW.md](/Users/Katharina/godot/Armada/docs/architecture/CODEX_WORKFLOW.md)

Required authority and evidence read in full:

- ADR-006
- Refined accepted TWI-003
- ADR-001, ADR-003, ADR-004, ADR-005
- CON-001, CON-003, CON-004, CON-005, CON-006
- TEST-003
- MA-ATTACK-002
- TWI-001
- Accepted TWI-002 workbook
- Final accepted TWI-002 implementation audit

## 2. Repository Baseline

- Branch: `master`
- Commit: `25062005291feb18aedb6dd8d149170113869e83`
- Commit subject: `docs(architecture): align TWI-003 with ADR-006 activation ownership`
- Commit date: `2026-08-10T07:45:46+02:00`
- Tracking state: `master...origin/master`
- Worktree before verification: clean
- Pre-existing changes: none
- Worktree after verification: clean
- ADR-006: present and Accepted; committed by `820756e`
- Refined accepted TWI-003: present in HEAD
- TWI-003 blob: `74b28f30f43d2c5a31d025a6de4956ead64545a0`
- ADR-006 blob: `6d1d0cd9a2ed0aea752bed47f9b79ae1d73adc8a`

## 3. Entry Gate Matrix

| # | Current TWI-003 criterion | Result | Evidence and notes |
|---|---|---|---|
| 1 | Required startup and authority documents read | PASS | Exact list recorded above. |
| 2 | TWI-003 production baseline clean | PASS | No tracked or untracked changes before or after verification. |
| 3 | TWI-002 production activation present and passing | PASS | Accepted implementation audit is present; production Attack Modify opening and confirmation boundaries exist; full suite and baselines passed. |
| 4 | ADR-006 Accepted | PASS | Accepted status, Project Owner metadata, and acceptance commit are present. |
| 5 | ShipInstance is sole writable ADR-006 owner; GameState aggregate-only | PASS | ADR-006 assigns all four activation-local concepts to `ShipInstance`; repository and accepted-authority searches found no competing canonical owner. |
| 6 | Save version exactly 2 | PASS | [save_game_metadata.gd](/Users/Katharina/godot/Armada/src/core/state/save_game_metadata.gd:39): `CURRENT_VERSION = 2`. |
| 7 | Replay format exactly 4; signed format is alias | PASS | [game_replay.gd](/Users/Katharina/godot/Armada/src/core/commands/game_replay.gd:32): `FORMAT_VERSION = 4`; line 35 aliases `SIGNED_FORMAT_VERSION`. |
| 8 | Every §5.2 fact maps to its accepted owner | PASS | Phase facts map to `GameState`; squadron action facts to `SquadronInstance`; the four ADR-006 facts to `ShipInstance`. Production existence is correctly deferred. |
| 9 | Required ADR-006 semantic boundaries identified | PASS | All ten required seams are recorded in §5 below. |
| 10 | No conflicting canonical owner exists | PASS | Current scene, flow, modal, GameManager, and resolver values are legacy/transient caches, not accepted canonical owners. |
| 11 | Slice 1 can be behavior-inert | PASS | Owner-local fields, invariants, snapshots, guards, queries, aggregate validation, and direct tests can be added with zero live references and without serialization. |
| 12 | No durable declaration fact lacks an owner | PASS | Complete TWI-003 §5.2 owner mapping is resolvable from accepted authority. |
| 13 | Existing commands can mutate owners atomically without a new command type | PASS | Existing entry, phase, action, Begin/Skip, Maneuver, completion, destruction, and cleanup commands provide the required transaction boundaries. |
| 14 | Protected tests and semantic command oracles identified | PASS | Preview/Confirm, rejection, BUG-002, save/load, replay, network, and reconnect suites were located and passed. |
| 15 | No implementation edit occurred | PASS | Verification was read-only; final worktree remained clean. |

## 4. ADR-006 Ownership Verification

| Canonical concept | Sole writable owner | Result |
|---|---|---|
| Stable ship-activation identity | Active `ShipInstance` | PASS |
| Squadron-command opportunity disposition | Same `ShipInstance` activation boundary | PASS |
| Maneuver opportunity disposition | Same `ShipInstance` activation boundary | PASS |
| Committed Squadron-command activation count | Same `ShipInstance` activation boundary | PASS |
| Aggregate/cross-fleet uniqueness validation | `GameState`, validation only | PASS |
| Conflicting writable owner | None found | PASS |

The fields themselves are not present in production yet, as expected. Their behavior-inert introduction belongs to Slice 1.

## 5. Semantic Transition Seam Verification

| Required seam | Existing boundary | Result |
|---|---|---|
| Ship activation entry | `ActivateShipCommand` and `ConvertDialToTokenCommand` | PASS |
| Squadron opportunity opening | Existing `AdvanceActivationStepCommand` transition into `squadron_step` | PASS |
| Squadron opportunity consumption/pass/unavailability | Existing transition leaving or bypassing the Squadron-command opportunity | PASS |
| Commanded-squadron commitment | `ActivateSquadronCommand`, extended within its existing semantic responsibility | PASS |
| Maneuver opening after no-active Skip | Existing no-active branch of `SkipAttackCommand` | PASS |
| Maneuver opening after normal Attack completion | Existing `AdvanceActivationStepCommand` submission from `_advance_activation_to_maneuver()` | PASS |
| Maneuver consumption | `ExecuteManeuverCommand` | PASS |
| Speed-zero Maneuver migration | Existing command already accepts speed zero; the current scene shortcut can be migrated to it without a new command | PASS |
| Normal activation completion | `EndActivationCommand` | PASS |
| Exceptional destruction/termination | Existing `ResolveDamageCommand`, `OverlapDamageCommand`, and `PersistentEffectDamageCommand` destruction transactions | PASS |
| Defensive round cleanup | `StatusPhaseCleanupCommand` and owner reset operations | PASS |

No new TWI-003-specific semantic command, general activation FSM, `current_step`, or predecessor graph is required.

## 6. Slice 1 Behavior-Inert Feasibility

Result: PASS.

Slice 1 can add:

- ADR-006 activation-local fields and invariants to `ShipInstance`;
- squadron action substrate to `SquadronInstance`;
- phase-local facts and aggregate uniqueness validation to `GameState`;
- owner-local snapshots, restores, resets, queries, transition guards, normal-completion eligibility, and exceptional clear behavior;
- direct owner tests.

It can do so without:

- production command integration;
- live route changes;
- production serialization;
- save/replay changes;
- replay, network, or reconnect integration;
- scene/controller changes;
- resolver semantic changes.

Searches found no premature ADR-006 field, prohibited generic FSM field, or serialization entry in production.

## 7. Compatibility Checkpoint

| Check | Required | Observed | Result |
|---|---:|---:|---|
| Save version | 2 | 2 | PASS |
| Replay format | 4 | 4 | PASS |
| Signed replay format | Alias of replay format | `SIGNED_FORMAT_VERSION := FORMAT_VERSION` | PASS |
| ADR-006 state serialized before Slice 2 | No | No fields exist or serialize | PASS |
| Slice 2 allocation | Save 2→3; replay 4→5 | Preserved in accepted TWI-003 | PASS |

## 8. Baseline Verification

- `./scripts/run_tests.sh`
  - 237 scripts
  - 3,962/3,962 tests passed
  - 11,651 assertions
  - 0 failures

- `./scripts/run_baseline_traces.sh --all`
  - Hot-seat trace: PASS
  - Hot-seat canonical state: PASS
  - Committed hot-seat comparison hash: `acc94f9f7ae16916d2b4a1da6439d4bcf478a945a8d92d24e53b08adf1b3b07d`
  - Network host/client peer equality: PASS
  - Network state hash: `09d7f126124b01d4c061435eede6b119088dc87b28ac51b8822151dc68e6b21e`
  - Overall: all replay baselines matched

- `bash scripts/lint_phase_k.sh`
  - Retired legacy effect surfaces: 0
  - Architecture violations: 0
  - Existing allow-listed branches: 4

- `git diff --check`
  - PASS; no output

- Final `git status --short --branch`
  - `## master...origin/master`
  - No worktree changes

No fixtures or expectations were altered.

## 9. Known Issues

| Issue | Entry Gate disposition |
|---|---|
| BUG-005 squadron distance-1 eligibility | DOES NOT BLOCK ENTRY GATE — mandatory Slice 2 scope. |
| BUG-002 Step 6 and second-attack behavior | DOES NOT BLOCK ENTRY GATE — protected regression evidence passed. |
| BUG-003 active/post-Begin Skip | DOES NOT BLOCK ENTRY GATE — explicitly excluded. |
| BUG-004 Tarkin projection | DOES NOT BLOCK ENTRY GATE — explicitly excluded. |
| BUG-001 / NOTE-001 network save/load bootstrap | DOES NOT BLOCK ENTRY GATE — remains a final production-verification prerequisite unless a direct declaration-state dependency is independently proven. |
| Current no-active Skip lacks durable Maneuver opening | DOES NOT BLOCK ENTRY GATE — assigned to Slice 2; existing command seam identified. |
| Current speed-zero path bypasses `ExecuteManeuverCommand` | DOES NOT BLOCK ENTRY GATE — existing command supports migration without a new semantic command. |
| Destruction cleanup is distributed across existing commands | DOES NOT BLOCK ENTRY GATE — all required semantic destruction transactions are identifiable. |

No genuine Owner ambiguity or accepted-authority conflict was found.

## 10. Entry Gate Verdict

PASS — TWI-003 Slice 1 may be prepared for implementation.

## 11. Recommended Next Step

Prepare a separate TWI-003 Slice 1 implementation task, preserving its behavior-inert boundary and checkpoint.

Slice 1 was not begun. No production code, tests, documentation, fixtures, or unrelated files were modified.
