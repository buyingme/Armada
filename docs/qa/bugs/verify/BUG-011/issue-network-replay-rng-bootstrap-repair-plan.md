# BUG-011 — Network Replay RNG Bootstrap Repair Plan

Status: Accepted
Accepted by: Project Owner
Accepted date: 2026-08-05

Classification: Networking / Serialization / Replay

Confirmed root cause: `NETWORK REPLAY RNG BOOTSTRAP DEFECT`

Authority:

- ADR-001
- ADR-003
- ADR-005
- CON-001
- TWI-002

Supporting implementation evidence:

- TWI-002 Remaining Implementation Execution Map
- Replay Baseline Workflow
- Accepted network replay RNG bootstrap investigation report
- Current replay, lobby, network configuration, game bootstrap, RNG, and
  baseline-verification implementation

This document is a bounded implementation repair specification. It is not an
ADR, Contract, Migration Assessment, implementation workbook, or replacement
for TWI-002. It does not authorize implementation before Owner acceptance.

## 1. Status And Purpose

The purpose of this plan is to define the smallest repair that makes a format-3
network replay reconstruct the match RNG from its recorded replay header.

The repair covers only the bootstrap transaction that selects the replay seed,
distributes it to both network peers, and constructs both peers' initial
`GameState.rng`. Its boundary ends before normal game initialization and replay
command execution continue.

The existing network replay fixture is evidence for this repair. The fixture is
not to be edited, converted, or regenerated to make the repair pass.

## 2. Confirmed Root Cause

The confirmed root cause is:

> NETWORK REPLAY RNG BOOTSTRAP DEFECT

The authoritative recording path writes the match RNG seed from
`GameState.rng.initial_seed` into the format-3 replay header. `GameReplay`
loads that exact recorded value, and `ReplayDriver` stores it in
`pending_replay_seed`.

Network replay then enters the ordinary lobby start path. That path currently:

1. generates a new time-derived seed in `LobbyManager.request_start_game()`;
2. distributes the new seed through the existing network game configuration;
3. causes `GameManager.bootstrap_game()` on both peers to construct the match
   from the distributed lobby seed; and
4. ignores `ReplayDriver.pending_replay_seed` because the replay is running in
   network mode.

The new lobby seed therefore replaces the replay-header seed before canonical
game initialization. Setup-time RNG consumption and later command-time RNG
consumption then proceed from a different sequence than the recorded match.
`RollDiceCommand` correctly generates canonical dice from `GameState.rng`, and
`CommitAccuracyCommand` correctly validates against canonical
`CurrentAttackState.dice_results`; neither command is the source of the defect.

The current format-3 network replay demonstrates the resulting failure. Its
recorded sequence 77 projects one Accuracy result and sequence 80 legally locks
one defense token. Replay execution regenerates different canonical dice, so
sequence 80 is rejected with `Too many Accuracy lock targets.` The subsequent
`ReplayDriver` timeout is a downstream consequence of the rejected command.

## 3. Scope

This repair includes only:

- format-3 network replay bootstrap;
- the exact replay-header RNG seed already accepted by `GameReplay`;
- replay bootstrap coordination by `ReplayDriver`;
- host selection of the seed used for the replay lobby start;
- propagation of that seed to host and client through the existing network
  game-configuration path;
- validation that both peers received the accepted replay seed;
- construction of both peers' initial `GameState.rng` from that seed;
- deterministic consumption or clearing of replay-bootstrap seed state;
- focused failure behavior before game initialization or replay command
  execution can proceed; and
- focused automated and manual regression evidence.

The repair is complete at the first boundary where both peers have installed
the replay-header seed as the initial state of their authoritative runtime RNG.
Normal setup, damage-deck initialization, command execution, dice generation,
projection, and replay exhaustion then continue through their existing paths.

## 4. Explicit Exclusions

The repair does not include:

- dice-command changes;
- Accuracy validation changes;
- `CurrentAttackState` changes;
- replay command or replay payload changes;
- replay format changes or conversion;
- trace format changes;
- baseline generator or verifier redesign;
- editing or regenerating the existing failing replay;
- normal non-replay network game seed-generation changes;
- save/load network bootstrap or BUG-001;
- timing-window, Concentrate Fire, H9, or other TWI-002 semantic changes;
- production activation, save-version, or replay-version advancement;
- BUG-010 or targeting behavior;
- network-session, transport, RPC, ordering, retry, or lobby redesign;
- a new RNG owner, replay owner, network protocol, compatibility layer, feature
  flag, or temporary bridge; and
- general replay cleanup unrelated to the confirmed bootstrap boundary.

## 5. Accepted Ownership

| Responsibility | Accepted owner or boundary |
| --- | --- |
| Recorded seed value used to reconstruct a replay | The accepted `GameReplay` header |
| Replay startup coordination and one-shot bootstrap seed state | `ReplayDriver`; it does not own gameplay RNG |
| Selection of the seed supplied at host lobby start | Existing lobby bootstrap, using fresh generation for live games and the accepted header value for network replay |
| Distribution of the host-selected seed | Existing `NetworkManager` game-configuration path |
| Authoritative runtime RNG and its evolving state | `GameState.rng` |
| Deterministic gameplay RNG consumption | Existing commands and deterministic setup/resolver paths reading `GameState.rng` |

The host and client must begin replay reconstruction with identical
`GameState.rng` initial seed and state. Neither peer, projection, scene, UI, nor
replay command payload becomes an alternative RNG authority.

Normal live network games continue to use the existing fresh, host-selected
lobby seed. The replay-header seed is authoritative only for reconstruction of
the replay that carries it.

## 6. Intended Transaction

### 6.1 Normal Network Game

For a network game with no active replay:

1. `LobbyManager` generates the existing fresh time-derived seed.
2. The host distributes that seed through the existing game configuration.
3. Both peers construct `GameState.rng` from the distributed seed.
4. No replay-bootstrap state participates.

This behavior remains unchanged.

### 6.2 Network Replay

For a network replay:

1. `GameReplay` accepts the replay and exposes its exact header seed before the
   lobby start is requested.
2. `ReplayDriver` establishes that value as the pending one-shot replay
   bootstrap input on each peer.
3. The host lobby start selects that accepted replay seed. It does not generate,
   substitute, or fall back to a fresh seed.
4. The host distributes the selected seed to both peers through the existing
   game-configuration path before scene transition and game initialization.
5. Each peer verifies that the received configuration contains the same valid
   seed as its accepted replay header. Missing, zero/fallback, or mismatched
   replay bootstrap input fails closed.
6. Each peer constructs its initial `GameState.rng` from the accepted seed
   before any setup-time RNG consumer or replay command can run.
7. Each peer consumes or clears its pending replay-bootstrap seed state exactly
   once after successful installation.
8. Existing initialization and command execution continue without another RNG
   construction, randomization, or reset.

The transaction is successful only when both peers enter normal initialization
from the same accepted seed. A peer may not continue independently with a
fallback seed.

## 7. Likely Repository Change Surface

The smallest likely production surface is:

| File or seam | Bounded responsibility in this repair |
| --- | --- |
| `src/autoload/replay_driver.gd` | Coordinate the accepted replay-header seed as one-shot network replay bootstrap input and expose deterministic success/failure state. |
| `src/autoload/lobby_manager.gd` | Select the accepted replay seed for a network replay host start while preserving fresh seed generation for every normal network start. |
| `src/autoload/game_manager.gd` | At the existing bootstrap boundary, reject missing/mismatched replay configuration, construct `GameState.rng` from the accepted network replay seed, and consume bootstrap state before initialization continues. |

Existing supporting seams expected to remain structurally unchanged:

- `src/autoload/network_manager.gd` already distributes one supplied seed to
  host and client through the accepted game-configuration path;
- `src/core/commands/game_replay.gd` already owns the format-3 replay header and
  exact seed decoding;
- `src/core/state/game_rng.gd` already constructs deterministic equal streams
  from equal non-zero seeds;
- `RollDiceCommand`, `CommitAccuracyCommand`, `CurrentAttackState`, and all
  dice/Accuracy calculation paths remain unchanged; and
- both baseline scripts and the network replay fixture remain unchanged.

Focused evidence is expected in the existing replay, lobby/bootstrap, network,
and RNG test layers. Exact test-file placement may follow existing repository
conventions, but the likely homes are:

- `tests/unit/test_replay_driver.gd`;
- the existing focused `LobbyManager` scenario/bootstrap tests;
- `tests/unit/test_network_manager.gd` for unchanged configuration propagation;
- the existing game-board/game bootstrap test surface;
- `tests/integration/test_network_transport.gd`; and
- the authoritative network baseline gate using the unchanged
  `tests/fixtures/baseline_traces/replay_network.json`.

Implementation stops if this behavior cannot be expressed through these
existing owners and the existing game-configuration path.

## 8. Atomicity And Failure Behavior

- The accepted seed selection, network distribution, peer validation, and
  initial `GameState.rng` construction form one bootstrap transaction.
- Host and client must receive and accept the same replay-header seed.
- No peer may begin normal game initialization with a missing, random,
  time-derived, mismatched, or otherwise substituted seed during network
  replay.
- Invalid or missing replay seed data must fail before replay command execution.
- A host/client seed mismatch must fail before either peer can be treated as a
  successfully bootstrapped replay participant.
- No replay command may execute before RNG bootstrap succeeds.
- Failed bootstrap must not consume replay commands or produce an accepted
  partial replay result.
- Pending replay-bootstrap state is consumed exactly once on success and cannot
  affect a later game start.
- Normal live-network start behavior must be identical to the pre-repair
  behavior.

## 9. Automated Verification

Focused automated evidence must prove all of the following:

- a valid network replay selects the exact header seed;
- the host places that exact value into the existing network game
  configuration;
- the client receives the identical value;
- both peers construct `GameState.rng` with the same `initial_seed` and initial
  state before setup proceeds;
- deterministic setup-time RNG consumption, including damage-deck
  initialization, remains identical on both peers;
- subsequent deterministic dice generation remains identical for the same
  command sequence;
- the existing format-3 `replay_network.json` reaches sequence 80 unchanged and
  accepts its one-token `commit_accuracy` command;
- the existing replay exhausts successfully;
- host and client final canonical state hashes match;
- hot-seat replay bootstrap and the committed hot-seat trace/hash gate remain
  unchanged;
- a normal fresh network game still selects a fresh lobby seed and never
  consumes replay-bootstrap state;
- missing, zero/fallback, or mismatched replay seed state fails closed before
  command execution;
- successful bootstrap consumes pending replay seed state exactly once; and
- all relevant replay, RNG, lobby/bootstrap, network, and baseline regressions
  pass.

No test may make the replay pass by replacing recorded dice, bypassing command
validation, editing replay sequence 80, or introducing a test-only bootstrap
authority.

## 10. Minimal Manual Verification

1. Run the existing format-3 network replay through
   `scripts/generate_baseline_fixtures.sh --mode network` without editing or
   rerecording it.
2. Confirm that both peers report replay exhaustion and that sequence 80
   `commit_accuracy` is accepted.
3. Confirm that the generator reports host/client final-state peer equality and
   requires no replay promotion or fixture modification.

## 11. Stop Conditions

Stop implementation and return to the Owner if any of the following is found:

- the repair requires a new authoritative RNG, replay, lobby, or network owner;
- the repair requires a new network protocol, RPC payload, transport path, or
  compatibility mode;
- the repair requires a replay-format or replay-payload change;
- the repair requires changes to dice generation, Accuracy semantics,
  `CurrentAttackState`, or any recorded replay command;
- the repair conflicts with TWI-002 or changes any TWI-002 semantic checkpoint;
- normal live-network fresh-seed behavior cannot be preserved;
- the replay seed cannot be delivered through the existing network
  game-configuration path;
- either peer must begin initialization before the seed is validated;
- the existing failing replay cannot remain byte-for-byte unchanged; or
- the defect proves to depend on BUG-001, BUG-010, targeting, save/load
  bootstrap, or another excluded behavior.

## 12. Binary Completion Criteria

The repair is complete only when every statement below is true:

- [ ] The previously failing format-3 network replay succeeds unchanged.
- [ ] Sequence 80 `commit_accuracy` is accepted.
- [ ] Host and client both initialize `GameState.rng` from the recorded replay
      header seed.
- [ ] Neither peer uses a generated or fallback seed during network replay.
- [ ] Host/client final canonical state hashes match.
- [ ] Replay execution exhausts without a command timeout.
- [ ] Hot-seat replay behavior remains unchanged.
- [ ] Normal network games retain the existing fresh lobby-seed behavior.
- [ ] Invalid, missing, or mismatched replay-bootstrap seed state fails closed
      before command execution.
- [ ] Pending replay-bootstrap state is consumed exactly once.
- [ ] No replay, trace, save, or compatibility version changes.
- [ ] No dice, Accuracy, CurrentAttackState, timing-window, TWI-002, BUG-001,
      BUG-010, targeting, generator, or verifier behavior changes.
- [ ] All focused and relevant regression evidence passes.
- [ ] No new owner, protocol, compatibility layer, feature flag, or temporary
      bridge is present.
