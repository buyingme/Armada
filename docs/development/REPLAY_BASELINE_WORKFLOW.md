# Replay Baseline Workflow

This document is the canonical developer guide for recording replay inputs,
generating baseline candidates, promoting accepted fixtures, and running the
replay baseline verifier.

It documents developer tooling. It does not define gameplay, replay semantics,
network ownership, serialization architecture, or format-version policy.
`scripts/run_baseline_traces.sh` remains the authoritative baseline verifier.

## 1. Purpose

Replay baseline testing detects unintended changes in the command history,
projected interaction flow, and final authoritative game state produced by a
known recorded game.

The baseline workflow provides two complementary checks:

- hot-seat verifies a committed deterministic command-by-command oracle and
  final-state hash;
- network verifies that an authoritative host and its client mirror finish the
  same replay run with equal authoritative state.

Baseline maintenance is an explicit review activity. A changed baseline is not
automatically evidence that new output is correct.

## 2. Replay, Baseline Trace, and State Hash

### Replay

A replay is a JSON document containing:

- a header with the replay format, scenario, RNG seed, factions, initiative,
  initial command sequence, and session metadata;
- the ordered serialized command history.

The replay is the input to `ReplayDriver`. It is recorded by the application and
must never be rewritten, normalized, converted, or repaired by baseline tooling.

### Baseline trace

A baseline trace is JSON Lines output written by `BaselineTrace`. The first line
is a trace header. Each later line records the post-command tuple:

- command sequence;
- command type;
- interaction-flow type;
- interaction-flow step;
- controlling player.

The trace is a deliberately narrow observable projection. It is not a replay and
cannot reconstruct gameplay state.

### State hash

A state hash is the lowercase SHA-256 digest of canonical JSON produced from the
final serialized `GameState`. It detects authoritative state differences that
the narrow trace does not expose.

## 3. Hot-Seat and Network Baselines

### Hot-seat

Hot-seat is a committed deterministic oracle. One replay produces:

- one canonical trace for the `hot_seat` / `solo` role;
- one canonical final-state hash.

Verification compares the generated trace and state hash byte-for-byte with the
committed fixtures.

### Network

Network baseline verification starts one host and one client with the same
replay. Each peer submits the commands assigned to its local player and observes
the other player's commands through the existing authoritative network path.

Network traces are diagnostic. Real transport timing permits different valid
per-process interleavings, so the repository does not commit network trace or
state-hash fixtures. The verifier compares the host and client final-state
hashes produced during the same run.

The current network check proves peer equality within a run. It does not provide
a committed cross-run network hash oracle. Network bootstrap obtains its shared
RNG seed from the lobby configuration rather than applying the replay header's
seed directly.

One replay drives both peers. Do not create separate host and client replay
fixtures.

## 4. Replay and BaselineTrace Formats

Replay format and BaselineTrace format are independent:

- `GameReplay.FORMAT_VERSION` identifies the accepted replay header and command
  model;
- `BaselineTrace.FORMAT_VERSION` identifies the trace-header and trace-record
  schema.

A replay-format change does not automatically require a trace-format change. A
trace-format change is required only when the trace schema changes. Conversely,
a trace schema can change without changing replay serialization.

The generator reads both current constants from their existing repository
owners. It does not contain or update format-version policy.

## 5. Canonical Fixture Layout

Canonical fixtures live under `tests/fixtures/baseline_traces/`.

Hot-seat:

- `replay_hot_seat_solo.json`
- `baseline_trace_hot_seat_solo.jsonl`
- `baseline_state_hash_hot_seat_solo.txt`

Network:

- `replay_network.json`

There are intentionally no committed network trace or network state-hash
fixtures. During verification, temporary network outputs are named
`network_host.jsonl`, `network_client.jsonl`, and their corresponding
`.state_hash` files.

## 6. Recording a New Replay

### Hot-seat recording

1. Start a new hot-seat game using the scenario covered by the baseline.
2. Complete the accepted baseline gameplay sequence.
3. Save the replay from debug mode with Shift+R, or use the replay automatically
   saved when the game ends or exits.
4. Locate the timestamped replay under the configured replay directory.
5. Supply its absolute filesystem path to the generator.

Use the replay exactly as recorded. Do not edit its header or command history.

### Network recording

1. Start a fresh network game through the normal lobby path. The helper
   `scripts/run_network_test.sh --gui-host` can launch two local GUI instances.
2. Complete the accepted baseline gameplay sequence.
3. Use the replay recorded by the authoritative host. Do not promote a
   client-side recording as the network fixture.
4. Supply the host replay's absolute filesystem path to the generator.

The replay header does not record hot-seat/network mode or host/client role.
Mode is selected when verification starts, and `BaselineTrace` records the
runtime-derived mode and role in each generated trace.

### BUG-001 restriction

`docs/qa/bugs/open/BUG-001/issue_network-save-load-session-bootstrap.md`
documents that a network session resumed from a save may restore incorrect
runtime mode, role, logging, or replay-recording context.

While BUG-001 remains open:

- record network baseline candidates only from a freshly started network game;
- do not record or promote a network replay after save/load;
- do not treat a save-loaded session's logs or replay as network-baseline
  provenance.

BUG-001 does not prevent recording a fresh normal network game or verifying a
replay through the normal host/client replay harness.

## 7. Generating Candidates

Use `scripts/generate_baseline_fixtures.sh` with one mode and one absolute replay
path. There is intentionally no `--all` generation mode.

Hot-seat candidate-only run:

```bash
./scripts/generate_baseline_fixtures.sh \
    --mode hot-seat \
    --replay /absolute/path/to/replay.json
```

Network candidate-only run:

```bash
./scripts/generate_baseline_fixtures.sh \
    --mode network \
    --replay /absolute/path/to/replay.json
```

Before starting Godot, the helper verifies:

- the replay exists and is readable;
- the file is valid JSON;
- header and non-empty command array are present;
- replay format matches the repository's current format owner;
- the RNG seed uses canonical signed 64-bit decimal-string representation;
- initial and command sequences are integral, non-negative, and contiguous;
- the source replay SHA-256 digest.

The authoritative application loader still validates the complete replay and
command payloads before playback.

Candidates are copied or generated inside a uniquely named temporary directory.
The replay copy must have the same SHA-256 digest as the supplied source.

Hot-seat generation produces temporary replay, trace, and state-hash candidates.
It also checks that trace command sequence/type identities match the replay.

Network generation produces a temporary replay copy plus host/client diagnostic
traces and hashes. Only host/client final-state equality is accepted. Network
diagnostic outputs are never installation candidates.

Candidate-only runs do not modify repository fixtures. Temporary outputs and
processes are cleaned up when the helper exits.

## 8. Promoting Fixtures

### Protected installation

Use `--install` when canonical destinations are absent or already
byte-identical:

```bash
./scripts/generate_baseline_fixtures.sh \
    --mode hot-seat \
    --replay /absolute/path/to/replay.json \
    --install
```

If any existing canonical file differs, installation stops before changing the
repository.

### Explicit replacement

Use both installation flags only after the candidate's semantic change has been
reviewed and fixture maintenance is authorized:

```bash
./scripts/generate_baseline_fixtures.sh \
    --mode hot-seat \
    --replay /absolute/path/to/replay.json \
    --install \
    --replace-existing
```

For network mode the same flags replace only `replay_network.json`.

Before replacement, the helper prints old and new SHA-256 digests for every
mode-specific canonical file. Existing files are backed up in the helper's
temporary directory. Changed candidates are staged beside their destinations
and moved into place.

After installation, the helper invokes the existing verifier unchanged for the
selected mode. If verification fails or the helper is interrupted during
installation, it restores every previous file and removes any destination that
was absent before the transaction. Temporary processes, staging files, backups,
logs, and candidates are then removed.

The helper never changes the supplied replay. Installing a replay copies its
bytes exactly and verifies its source digest before promotion.

## 9. Running Verification

Hot-seat verification:

```bash
./scripts/run_baseline_traces.sh --hot-seat
```

Network verification:

```bash
./scripts/run_baseline_traces.sh --network
```

Full verification:

```bash
./scripts/run_baseline_traces.sh --all
```

`run_baseline_traces.sh` is authoritative. The generator does not replace or
bypass it. A successful candidate-only run is not equivalent to successful
installed-fixture verification.

## 10. Common Mistakes

- **Replay format mismatch:** the current loader rejects every replay format
  other than the repository's current format before command application.
- **Wrong filename:** the verifier uses the exact canonical names in Section 5.
- **Header editing:** changing only `format_version`, RNG seed, or initial
  sequence does not migrate an incompatible command history.
- **Replay conversion:** the generator never converts old replay formats or
  reconstructs semantic commands.
- **Command normalization:** do not reorder commands, renumber sequences, or
  rewrite JSON to make preflight pass.
- **Stale trace/hash:** a new accepted replay or canonical state shape may make
  old hot-seat trace or hash fixtures obsolete.
- **Committing network diagnostics:** host/client traces and hashes are temporary
  evidence, not canonical fixtures.
- **Separate network replays:** both peers must run the same canonical replay.
- **Client recording:** use the authoritative host replay for network baseline
  maintenance.
- **Save-loaded network recording:** do not use it while BUG-001 is open.
- **Silent overwrite:** `--install` refuses differing files; replacement requires
  the additional explicit `--replace-existing` flag.
- **Treating generated output as acceptance:** inspect semantic command drift and
  obtain the required review before promoting changed fixtures.

## 11. Maintenance Policy

Baseline regeneration is expected when an accepted change intentionally alters:

- semantic replay commands or their order;
- the replay format;
- the baseline trace schema;
- canonical serialized state included in the final hash;
- the accepted baseline gameplay workflow.

Regeneration is not justified solely because the verifier fails. First classify
the difference as intended or defective.

Fixture maintenance must occur only in an explicitly authorized maintenance
task after the implementation and semantic trace have been accepted. Replay
format migrations require a replay recorded with the new semantic command
model. Do not update an obsolete replay by changing only its format header.

When production activation changes the accepted replay format or command model,
record and review a new replay under that checkpoint, regenerate the applicable
fixtures, and rerun the authoritative verifier. Preserve the historical replay
only through version control; do not add a compatibility mode to the helper.
