# Replay Baseline Workflow

This document is the canonical developer guide for replay recording, baseline
candidate generation, fixture promotion, replay verification, and baseline
maintenance.

It documents the existing developer workflow. It does not define gameplay,
replay semantics, network ownership, serialization architecture, or
format-version policy. Those decisions remain with their existing architecture
and implementation owners.

Two scripts divide the tooling responsibilities:

- `scripts/generate_baseline_fixtures.sh` validates a recorded replay, generates
  temporary candidates, and safely promotes approved fixtures;
- `scripts/run_baseline_traces.sh` is the authoritative baseline verifier.

The generator never replaces or bypasses the verifier.

## 1. Purpose

Replay baseline testing detects unintended changes in the command history,
projected interaction flow, and final authoritative game state produced by a
known recorded game.

The workflow provides two complementary forms of evidence:

- **Hot-seat** is a committed deterministic oracle. Verification compares a
  replay run byte-for-byte with a committed trace and final-state hash.
- **Network** is an authoritative peer-equality check. One host and one client
  execute the same replay through the normal network path and must finish with
  equal authoritative state.

Recording, candidate generation, promotion, and verification are separate
activities:

1. **Recording** captures an application-produced replay.
2. **Candidate generation** proves that the replay can produce structurally
   valid temporary evidence.
3. **Promotion** installs reviewed candidates into the canonical fixture
   locations.
4. **Verification** evaluates the committed fixtures using the authoritative
   verifier.

Success at one stage does not imply acceptance at a later stage. In particular,
a recorded replay is not a verified baseline, and a successful candidate-only
run is not an accepted fixture update.

## 2. Core Concepts

### 2.1 Replay

A replay is an application-recorded JSON document containing:

- a header with the replay format, scenario, RNG seed, factions, initiative,
  initial command sequence, and session metadata;
- the ordered serialized command history.

The replay is the input to `ReplayDriver`. Baseline tooling must copy it
byte-for-byte and must never rewrite, normalize, convert, repair, reorder, or
renumber it.

Replay execution reconstructs gameplay from the recorded initial conditions and
the serialized commands. RNG-dependent results are produced through the normal
authoritative `GameState.rng` path; recorded projection data does not replace
canonical dice generation or command validation.

For replay reconstruction, the replay header owns the recorded RNG seed:

- hot-seat replay bootstrap consumes that seed directly;
- network replay bootstrap uses the authoritative host lobby to select the same
  recorded seed, distributes it through the existing network game-configuration
  path, and validates it on both peers before gameplay starts.

`ReplayDriver` coordinates this one-shot bootstrap input. It does not become an
RNG owner. Normal network games without an active replay continue to use a fresh
host-selected seed.

### 2.2 Baseline Trace

A baseline trace is JSON Lines output written by `BaselineTrace`.

The first line is a trace header. Every later line records the post-command
tuple:

- command sequence;
- command type;
- interaction-flow type;
- interaction-flow step;
- controlling player.

The trace is a deliberately narrow observable projection. It is not a replay,
does not contain the complete authoritative state, and cannot reconstruct a
game.

### 2.3 State Hash

A state hash is the lowercase SHA-256 digest of canonical JSON produced from the
final serialized `GameState`.

It detects authoritative final-state differences that the narrow trace does not
expose. A valid state-hash file contains exactly one 64-character lowercase
hexadecimal digest.

### 2.4 Replay Format

`GameReplay.FORMAT_VERSION` in
`src/core/commands/game_replay.gd` owns the accepted replay header and command
model version.

The application loader rejects incompatible replay formats before applying
commands. Neither baseline script converts an old replay or changes its format
header. The generator reads the current value directly from the existing format
owner rather than maintaining a separate version value.

### 2.5 BaselineTrace Format

`BaselineTrace.FORMAT_VERSION` in `src/autoload/baseline_trace.gd` owns the
trace-header and trace-record schema version.

Replay format and trace format are independent:

- a replay-format change does not automatically require a trace-format change;
- a trace-format change is required only when the trace schema changes;
- the trace schema may change without changing replay serialization.

The generator reads both current format constants from their repository owners.
It does not define or update format-version policy.

## 3. Canonical Fixture Layout

Canonical fixtures live under `tests/fixtures/baseline_traces/`.

| Mode | Canonical file | Purpose | Committed |
| --- | --- | --- | --- |
| Hot-seat | `replay_hot_seat_solo.json` | Recorded replay input | Yes |
| Hot-seat | `baseline_trace_hot_seat_solo.jsonl` | Deterministic per-command oracle | Yes |
| Hot-seat | `baseline_state_hash_hot_seat_solo.txt` | Deterministic final-state oracle | Yes |
| Network | `replay_network.json` | One authoritative-host replay used by both peers | Yes |
| Network | Network trace fixture | Not applicable; traces are diagnostic | No |
| Network | Network state-hash fixture | Not applicable; verification compares peers within one run | No |

During network verification, temporary outputs are named:

- `network_host.jsonl`;
- `network_client.jsonl`;
- `network_host.jsonl.state_hash`;
- `network_client.jsonl.state_hash`.

These temporary traces and hashes are diagnostic evidence only. They are never
canonical installation candidates and must not be committed.

## 4. Hot-Seat Workflow

Hot-seat verification is the deterministic, committed baseline oracle.

One canonical replay produces:

- one trace with runtime mode `hot_seat` and role `solo`;
- one final-state hash.

The normal workflow is:

1. Record a fresh hot-seat replay when an accepted change requires one.
2. Generate temporary candidates with
   `scripts/generate_baseline_fixtures.sh --mode hot-seat`.
3. Review the replay provenance and any intended semantic difference.
4. Promote the reviewed mode-specific fixture set explicitly.
5. Run `scripts/run_baseline_traces.sh --hot-seat`.

The verifier replays `replay_hot_seat_solo.json` and compares both generated
outputs byte-for-byte with:

- `baseline_trace_hot_seat_solo.jsonl`;
- `baseline_state_hash_hot_seat_solo.txt`.

A changed trace or hash is a regression signal until the difference has been
classified and explicitly accepted. Do not regenerate fixtures merely to make a
failure disappear.

## 5. Network Workflow

Network verification is a peer-equality check, not a committed per-command
oracle.

The verifier starts one authoritative host and one client with the same
`replay_network.json`. Each peer submits commands assigned to its local player
and observes the other player's commands through the existing authoritative
network path.

The recorded replay header seed remains authoritative for reconstruction. The
network replay bootstrap transaction is:

1. `ReplayDriver` loads the same replay and establishes its header seed as
   one-shot bootstrap input on each peer.
2. The authoritative host selects that recorded seed at the existing lobby
   start boundary instead of generating a fresh seed.
3. The existing network game configuration distributes the selected seed.
4. Both peers validate the received value against their replay header and
   construct `GameState.rng` before setup-time or command-time RNG consumption.
5. The pending bootstrap input is consumed exactly once after successful RNG
   installation.

Missing, zero, fallback, or mismatched replay seed state fails before gameplay
begins. Normal live network games remain outside this replay transaction and
continue to generate a fresh host-selected seed.

One replay drives both peers. Do not create separate host and client replay
fixtures.

### Why network has no committed trace or hash fixtures

Real transport timing permits different valid per-process command
interleavings. As a result:

- host and client diagnostic traces need not be byte-identical;
- valid network runs can produce different cross-run trace ordering;
- the repository does not use a committed network trace oracle;
- the repository does not use a committed cross-run network state-hash oracle.

Instead, the verifier requires the host and client final-state hashes from the
same run to match. This proves peer equality for that run while avoiding an
invalid assumption about transport interleaving.

The replay header does not record hot-seat/network mode or host/client role.
Verification selects the mode at startup, and `BaselineTrace` records the
runtime-derived mode and role in each generated trace header.

## 6. Recording New Replays

Record a new replay only when the accepted implementation or baseline gameplay
has intentionally changed in a way that makes the existing replay obsolete.
Do not rerecord merely because verification fails.

Replay files are written to the directory owned by `PathConfig.REPLAYS_DIR`:

| Runtime | Replay directory |
| --- | --- |
| Godot editor/source build | `<project>/replays/` |
| Packaged macOS application | `~/Library/Application Support/Armada/replays/` |

Replays use timestamped filenames. They can be saved manually with **Shift+R**
while debug mode is enabled, and are also saved automatically when the game ends
or exits when a recordable command history exists.

Always give the generator the replay's absolute filesystem path.

### 6.1 Recording a hot-seat replay

1. Start a new hot-seat game using the scenario covered by the baseline.
2. Complete the accepted baseline gameplay sequence.
3. Save the replay with **Shift+R** in debug mode, or use the replay saved when
   the game ends or exits.
4. Locate the timestamped replay in the configured replay directory.
5. Preserve it exactly as recorded and pass its absolute path to the generator.

Do not edit the replay header or command history.

### 6.2 Recording a network replay

1. Start a fresh network game through the normal lobby path. The helper
   `scripts/run_network_test.sh --gui-host` can launch two local GUI instances.
2. Complete the accepted baseline gameplay sequence.
3. Select the replay recorded by the authoritative host. Network clients do not
   own the canonical recording.
4. Preserve the host replay exactly as recorded and pass its absolute path to
   the generator.

Do not promote a client-side recording or create peer-specific replay fixtures.

### 6.3 BUG-001 restriction

`docs/qa/bugs/open/BUG-001/issue_network-save-load-session-bootstrap.md`
documents that a network session resumed from a save may restore incorrect
runtime mode, role, logging, or replay-recording context.

While BUG-001 remains open:

- record network baseline candidates only from a freshly started network game;
- do not record or promote a network replay after save/load;
- do not treat a save-loaded session's logs or replay as valid network-baseline
  provenance.

BUG-001 does not prevent recording a fresh normal network game. It also does not
prevent verification of a replay through the normal host/client replay harness.

## 7. Generating Baseline Candidates

Use `scripts/generate_baseline_fixtures.sh` with exactly one mode and one
absolute replay path. There is intentionally no `--all` generation mode.

The helper requires Godot, `jq`, `cmp`, `awk`, and either `shasum` or
`sha256sum`. Set `GODOT_BIN` when Godot is not available on `PATH` and is not in
the default macOS application location.

### 7.1 Hot-seat candidate generation

```bash
./scripts/generate_baseline_fixtures.sh \
    --mode hot-seat \
    --replay /absolute/path/to/replay.json
```

The helper creates temporary replay, trace, and state-hash candidates. It checks
that the trace header reports `hot_seat` / `solo`, that the trace's command
sequence/type identities match the replay, and that the state hash has the
required canonical digest form.

### 7.2 Network candidate generation

```bash
./scripts/generate_baseline_fixtures.sh \
    --mode network \
    --replay /absolute/path/to/replay.json
```

The helper creates a temporary replay copy, starts a host and client, and writes
temporary diagnostic traces and state hashes. Candidate generation succeeds
only when both processes succeed, the trace headers report `network` with the
correct `host` / `client` roles, both state hashes have the required canonical
digest form, and the final-state hashes match.

Only the replay is a network installation candidate. Network traces and hashes
remain temporary diagnostics.

### 7.3 Generator preflight

Before starting Godot, the generator verifies:

- the replay exists and is readable;
- the file is valid JSON;
- the header and a non-empty command array are present;
- the replay format matches the current `GameReplay.FORMAT_VERSION`;
- the RNG seed uses canonical signed 64-bit decimal-string representation;
- the initial sequence and command sequences are integral and non-negative;
- command sequences are contiguous from the initial sequence;
- a SHA-256 digest can be calculated for the source replay.

The authoritative application loader still validates the complete replay and
every command payload before playback. Generator preflight does not replace
application validation.

### 7.4 Candidate handling

Candidates are copied or generated in a uniquely named temporary directory.
The replay candidate must have the same SHA-256 digest as the source replay.

A candidate-only run:

- does not modify repository fixtures;
- does not accept or promote semantic changes;
- reports the relevant candidate digests;
- cleans up temporary processes, logs, traces, hashes, and replay copies when
  the helper exits.

### 7.5 Generator and verifier responsibilities

| Responsibility | Generator | Verifier |
| --- | --- | --- |
| Record gameplay | No | No |
| Rewrite or convert a replay | No | No |
| Check source replay structure and digest | Yes | No |
| Create temporary candidate evidence | Yes | No |
| Validate hot-seat trace identities | Yes | No |
| Validate network host/client state equality during generation | Yes | Yes, during verification |
| Install approved canonical fixtures | Only with explicit installation flags | No |
| Compare a replay run with committed canonical fixtures | After installation, by invoking the verifier | Yes; authoritative |
| Decide whether changed semantics are accepted | No | No |

## 8. Promoting Baselines

Promotion is an explicit installation transaction. Generate and review the
candidate before replacing any differing canonical fixture.

### 8.1 Protected installation

Use `--install` when every canonical destination is absent or already
byte-identical:

```bash
./scripts/generate_baseline_fixtures.sh \
    --mode hot-seat \
    --replay /absolute/path/to/replay.json \
    --install
```

If an existing canonical file differs, installation stops before changing the
repository.

### 8.2 Explicit replacement

Use both installation flags only after the candidate's semantic change has been
reviewed and fixture maintenance has been authorized:

```bash
./scripts/generate_baseline_fixtures.sh \
    --mode hot-seat \
    --replay /absolute/path/to/replay.json \
    --install \
    --replace-existing
```

The same flags apply to network mode. Network promotion replaces only
`replay_network.json`; diagnostic network traces and hashes are never promoted.

`--replace-existing` without `--install` is invalid.

### 8.3 Promotion safety and rollback

Before replacing files, the helper prints the old and new SHA-256 digest for
every mode-specific canonical destination. It then:

1. backs up existing files inside its temporary directory;
2. stages changed candidates beside their destinations;
3. verifies the staged bytes;
4. moves the staged files into place;
5. invokes `scripts/run_baseline_traces.sh` unchanged for the selected mode.

If verification fails or the helper is interrupted during installation, it
restores every previous file and removes any destination that did not exist
before the transaction. It then cleans up temporary processes, staging files,
backups, logs, and candidates.

The supplied replay is never changed. Replay promotion copies its bytes exactly
and verifies the source digest before installation.

After successful promotion, inspect the repository diff and confirm that only
the intended canonical files changed.

## 9. Running Verification

`scripts/run_baseline_traces.sh` is the authoritative verifier.

### 9.1 Hot-seat

```bash
./scripts/run_baseline_traces.sh --hot-seat
```

Running the script without a mode is equivalent to `--hot-seat`:

```bash
./scripts/run_baseline_traces.sh
```

The hot-seat gate compares the generated trace and final-state hash with the
committed fixtures.

### 9.2 Network

```bash
./scripts/run_baseline_traces.sh --network
```

The network gate runs one host and one client from `replay_network.json` and
compares their final-state hashes. Diagnostic traces are not compared with each
other or with committed fixtures.

If `replay_network.json` is absent, the verifier reports the network check as
skipped. A skip is not evidence that a network replay passed.

### 9.3 Full verification

```bash
./scripts/run_baseline_traces.sh --all
```

This runs the hot-seat and network gates. A successful generator run without
fixture installation is not equivalent to this installed-fixture verification.

## 10. Replay Format Migrations

Replay format migration is an accepted implementation change, not a baseline
tooling operation.

When the accepted replay format or semantic command model changes:

1. implement and accept the format or semantic change through its owning work;
2. record new replays using the new application behavior;
3. review the new command history and baseline gameplay provenance;
4. generate and promote the applicable canonical fixtures;
5. rerun the authoritative verifier.

Do not migrate an obsolete replay by changing only `format_version`, the RNG
seed, the initial sequence, or individual command payloads. The generator does
not convert old formats or synthesize a compatible command history.

Replay and trace versions move independently. A replay-format migration changes
`GameReplay.FORMAT_VERSION`; it changes `BaselineTrace.FORMAT_VERSION` only if
the trace schema also changes.

When an accepted production activation changes the replay format or command
model, record and review new replays under that checkpoint. Preserve historical
fixtures through version control; do not add a compatibility mode to either
baseline script.

## 11. Baseline Maintenance Policy

Baseline maintenance is an explicit review activity. A changed baseline is not
automatically evidence that the new output is correct.

### 11.1 When regeneration is required

Regenerate the applicable fixtures when an accepted change intentionally
alters:

- semantic replay commands or their order;
- the replay format or accepted command model;
- the baseline trace schema;
- canonical serialized state included in the final hash;
- the accepted baseline gameplay workflow.

Use the following distinction:

| Accepted change | Required maintenance |
| --- | --- |
| Replay format, semantic commands, command order, or baseline gameplay changes | Record new affected replay inputs, then regenerate and promote the applicable mode-specific fixtures. |
| Trace schema changes without replay serialization changes | Keep a still-compatible replay byte-for-byte; regenerate the hot-seat fixture set through the generator. Do not create network trace fixtures. |
| Canonical final-state serialization changes | Regenerate the hot-seat state-hash evidence through the normal generator transaction; rerun network peer-equality verification without committing network hashes. |
| Implementation repair that should preserve recorded behavior | Do not replace the replay or baseline. The existing fixtures must pass unchanged. |
| Unexplained verifier failure | Do not regenerate. Diagnose and classify the difference first. |

BUG-011 is an example of the preservation case: the accepted repair corrected
network replay RNG bootstrap while keeping the recorded replay, dice logic,
Accuracy validation, replay format, and baseline tooling unchanged.

### 11.2 Maintenance constraints

- Perform fixture maintenance only in an explicitly authorized maintenance task
  after the implementation and semantic change have been accepted.
- Treat the application-recorded replay as immutable input.
- Use the generator's candidate-only mode before replacing differing fixtures.
- Promote only the canonical files listed in Section 3.
- Never commit network diagnostic traces or state hashes.
- Never use baseline replacement to conceal a regression.
- Use version control for historical fixtures; do not create helper-side replay
  compatibility or conversion behavior.

## 12. Troubleshooting and Common Mistakes

| Symptom or mistake | Meaning and required response |
| --- | --- |
| Replay format mismatch | The current loader rejects the replay before command application. Record a replay under the accepted current format; do not edit the header. |
| Wrong fixture filename | The verifier uses the exact canonical names in Section 3. Rename only a misplaced canonical file; do not change script mappings casually. |
| Header editing | Changing `format_version`, RNG seed, or initial sequence does not migrate an incompatible command history. Restore or rerecord the replay. |
| Replay conversion or command normalization | Unsupported. Do not reorder commands, renumber sequences, rewrite payloads, or normalize JSON to make preflight pass. |
| Hot-seat trace identity mismatch | The generated command sequence/type identities do not match the replay. Treat this as incompatible or defective input/behavior, not a trace formatting problem. |
| Hot-seat trace or hash differs | Classify the change as intended or defective before considering promotion. Do not replace fixtures automatically. |
| Network host/client hashes differ | The peers did not finish with equal authoritative state. Do not promote the replay. |
| Network host/client traces differ but hashes match | This can be valid because transport timing permits different diagnostic interleavings. Network verification is based on peer hash equality. |
| Network replay rejects a legal RNG-dependent command | Confirm that the replay header seed reached the host lobby configuration and both peers' authoritative `GameState.rng`. Do not alter recorded dice, the command payload, or validation to make the replay pass. |
| Network verification says `SKIP` | `replay_network.json` is absent. The network baseline was not verified. |
| Separate host/client replay files | Incorrect. Both peers must run the same canonical `replay_network.json`. |
| Client-side network recording selected | Incorrect provenance. Use the authoritative host recording. |
| Save-loaded network recording selected | Invalid baseline provenance while BUG-001 remains open. Record a fresh network game through the normal lobby path. |
| Network diagnostic files appear in a proposed commit | Remove them. Network traces and hashes are temporary run evidence, not fixtures. |
| `--install` refuses replacement | One or more canonical files differ. Review the candidates, then use `--install --replace-existing` only when replacement is authorized. |
| `--replace-existing` used alone | Invalid command line. Explicit replacement also requires `--install`. |
| Candidate generation passes | This proves temporary generation checks only. It does not accept semantic changes or replace installed-fixture verification. |
| Generator output disappears after exit | Expected. Candidate-only outputs, logs, and diagnostics live in a temporary directory and are cleaned up. |

## 13. Typical Developer Workflow

Use this checklist for normal replay and baseline maintenance:

- [ ] Confirm whether the accepted implementation is expected to preserve the
      current replay and baseline outputs or intentionally change them.
- [ ] Run the authoritative verifier against the current committed fixtures to
      capture the actual failure or confirm the existing baseline.
- [ ] If behavior should remain unchanged, diagnose the implementation; do not
      record or promote replacement fixtures.
- [ ] If an accepted change makes a replay obsolete, record the accepted
      baseline gameplay again in the affected mode.
- [ ] For network recording, start a fresh lobby session, avoid save/load while
      BUG-001 remains open, and select the authoritative host replay.
- [ ] Preserve the recorded replay byte-for-byte and identify its absolute
      filesystem path.
- [ ] Run `scripts/generate_baseline_fixtures.sh` in candidate-only mode for one
      mode.
- [ ] Review replay provenance, command-history changes, generated evidence, and
      reported digests.
- [ ] Use `--install` for absent or byte-identical canonical destinations.
- [ ] Use `--install --replace-existing` only after differing fixtures have been
      reviewed and replacement is authorized.
- [ ] Confirm that the generator's post-install authoritative verification
      succeeds and does not roll back the transaction.
- [ ] Run `scripts/run_baseline_traces.sh --hot-seat`, `--network`, or `--all`
      as required for the accepted change.
- [ ] Inspect the repository diff and confirm that only the intended canonical
      fixtures changed; never include temporary network traces or hashes.
- [ ] Preserve the implementation-produced replay, generator/verifier scripts,
      and format owners unchanged unless the accepted task explicitly changes
      those surfaces.
