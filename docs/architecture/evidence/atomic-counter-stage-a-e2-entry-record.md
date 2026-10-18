# Atomic Counter Stage A — E2 implementation-entry evidence

Status: **E2 PASS; Stage A Owner ACCEPTED and Stage B AUTHORIZED on 2026-10-18; integrated replay/baseline acceptance pending.**
Recorded: 2026-10-18. Scope: BC-009 / AT-008. This is an implementation
inventory under the [Owner-accepted consolidated workbook](../implementation_workbooks/atomic-counter-choice-lifecycle-consolidated-implementation-workbook.md),
not fixture or baseline approval. Boundary C prerequisite E1 is Owner-accepted
in commit `d67db1a`. The uncommitted Boundary B implementation remains stopped
and preserved at the E2/Stage A checkpoint; the subsequent Stage B
authorization permits its bounded reuse.

## Version and schema collision check

| Surface | Current gate and reader | Stage ownership and required result |
| --- | --- | --- |
| Save | `SaveGameMetadata.CURRENT_VERSION = 10`; `SaveGameManager` checks that constant in named load, checkpoint load, and metadata validation. `GameState` holds the exact `CurrentAttackState` and `CompletedAttackInspection` dictionaries. | Stage A introduces the disposition and inspection witness exact keys and sets Save 11. Save-10 development files reject at the existing version gate; no migration or schema inference from projection. Stage A tests both new JSON roundtrips and old-version rejection. |
| Network | `NetworkManager.PROTOCOL_VERSION = 11`; the server handshake and command envelope check the constant, including the `CommandProcessor` envelope check in the preserved Boundary B diff. Filtered passive state uses the same Attack/inspection representation. | Stage A sets Network 12 and verifies mixed Network-11 peers reject before changed snapshots or commands. It does not edit the preserved `CommandProcessor` change. Stage F proves both real-ENet mappings and reconnect. |
| Replay | `GameReplay.FORMAT_VERSION = 12`, with signing version tied to it; `GameReplay.deserialize()` checks exact format and signed capture writes that version. Existing replay command codec and the later source-bound Counter Begin semantics remain under the integrated Replay-13 gate. | Stage A sets Replay 13 and tests old-format rejection and current signing/decoding. Stages B–E implement changed command semantics. Stage F supplies genuine current replay inputs and proves ordered playback. |

The numerical allocations **Save 11 / Network 12 / Replay 13** do not
collide with any installed current version; each is the next value of its own
format. The state schema additions are exact and require the Save/Network
cutover. Changed command and Counter lifecycle semantics require the Replay
cutover. Existing format-specific assertions must be updated with the version
gates; unrelated `format_version: 1` fleet/setup records are separate formats.

## Reader, runner, and assertion inventory

- Current playback readers: `GameReplay.deserialize()`, `ReplayDriver`, the
  headless replay path used by `scripts/run_baseline_traces.sh`, and the real
  ENet replay path in `scripts/run_network_resume_acceptance.sh`. Save readers
  are `SaveGameManager` named and checkpoint loads; Network readers are the
  handshake, command envelope, and passive snapshot reconstruction.
- `scripts/run_baseline_traces.sh` currently points to historical
  `replay_hot_seat_solo.json` and `replay_network.json`. Hot-Seat compares a
  command trace and final state hash; Network compares host/client final hashes.
  Its missing-Network-input branch currently **skips successfully** and must
  become a required-input failure at Stage F.
- `scripts/run_network_resume_acceptance.sh` hardcodes the historical Network
  replay in both launch and assertion arguments. Its
  `tests/acceptance/network_resume/assertions.gd` pins Save 10, Network 11,
  Replay 12, and `protocol v11` log text. Stage F points both locations to a
  genuine Replay-13 Network recording and updates all exercised assertions.
- Direct version-only assertions **updated with Stage A** occur in
  `tests/unit/test_game_replay.gd`, `test_network_manager.gd`,
  `test_bug_043_candidate_registration.gd`, `test_h9_timing_window.gd`,
  `tests/integration/test_exact_rng_save_serialization.gd`,
  `test_network_transport.gd`, `test_concentrate_fire_shared_protocol.gd`,
  `test_h9_shared_protocol.gd`, and
  `test_bug_043_stabilization_projection_recovery.gd`.
- Assertions **inventoried for later stages, not updated in Stage A** include
  `tests/unit/test_counter_inspection_release.gd`, which asserts Save 10 within obsolete
  post-parent Counter behavior; Stages D/E own its lifecycle rewrite and
  version assertions. `test_replay_driver.gd` reads the historical format-12
  Hot-Seat replay; Stage F owns its genuine current-input replacement. Tests
  using the constants dynamically remain valid. Legacy-version rejection
  specimens retain their deliberately old values.
- `scripts/generate_baseline_fixtures.sh` reads the replay constant for
  generation. It is **not** an E2 or Stage A runner and must not be used to
  synthesize or relabel the replacement recordings.

## Immutable history and current-format input plan

The two installed baseline inputs are format 12: Hot-Seat has 175 commands;
Network has 330. Neither contains a Counter-choice publication. Their
historical paths and hashes are retained unchanged:

| Historical file in `tests/fixtures/baseline_traces/` | SHA-256 at E2 |
| --- | --- |
| `replay_hot_seat_solo.json` | `c151cff2b594fa648b805eea2ba0597321ffc6cde7f5fd1a446fadc2674ca9f9` |
| `replay_network.json` | `cb3c1c9746e8328027bb26820c99dd1b45250fb3ea11dfadcfcc677bd1e8cef4` |
| `baseline_trace_hot_seat_solo.jsonl` | `bbfbe6e68d41ed0331950283aca0cb334cc4b97aea6a0e44721207134b284571` |
| `baseline_state_hash_hot_seat_solo.txt` | `87acea7172d1f70cb810de83519b99af13cd548d42844a04220bbab848614686` |

The accepted BUG-074 Replay-12 recordings, including sequence 58's incomplete
Counter publication, and their expected hashes remain historical evidence.
The accepted final recording
[`replay_20261015_065840.json`](../../qa/bugs/closed/BUG-074/replay_20261015_065840.json)
has SHA-256 `30e0750993d45db158fcc37b08911a485fe03d824e108c9abf94db731d3f5d92`
at E2. No historical fixture, hash, or Owner evidence was changed.
The other three historical Counter recordings have SHA-256
`2a5287ad8caa5a7ac0baf71941614d98661694180b64dc737ad4883ff4c31410`,
`501151cc32560043bd3b548b5caad35205d7e2a3752a920527e039d58007e648`,
and `eb70f199759a35b032f950e91106e32cd362b0a52ddd771b1539211d47741f98`
for 2026-10-11, 2026-10-12, and 2026-10-13 respectively.
The separate BUG-074 diagnosis replay
[`replay_20261011_145937.json`](../../qa/bugs/closed/BUG-074/replay_20261011_145937.json)
has SHA-256 `40f8a313cbf30060ee061b4d4a115a4aa711a02f22ae48941af6232856f56bb0`
at E2 and is likewise immutable historical evidence.

After Stages A–E implement the accepted lifecycle, the Owner must play and
**manually record** three Replay-13 inputs through the genuine application:
one Hot-Seat baseline, one Network baseline, and one complete-publication
Counter replay. The Counter recording may also serve a baseline only if it
meets that baseline's coverage and provenance. Preserve the originals under
separate historical paths. Record game mode, build/version, participants and
Network role mapping, scenario, recording date, and replay file provenance.
The planned distinct current-input paths are
`tests/fixtures/baseline_traces/replay_hot_seat_v13.json`,
`tests/fixtures/baseline_traces/replay_network_v13.json`, and
`tests/fixtures/baseline_traces/replay_counter_v13.json`. These names reserve
separate runner inputs; **none exists or is authorized for Codex to create**
at E2/Stage A. Stage F must use the genuinely recorded Hot-Seat and Network
files and require both to exist with signed format-13 headers and ordered,
contiguous commands. The Hot-Seat trace and final-hash oracles need distinct
new paths and separate Owner approval after first-field diagnosis. Network
retains host/client final-hash convergence without an invented committed
network oracle. The Counter recording must show one complete source-matching
Counter publication, canonical choice/child/inspection history, and replay
exhaustion; it cannot be an automatically transformed Replay-12 specimen.
Codex may inspect signatures, headers, ordered commands, the single complete
Counter publication, source/child/inspection history, replay exhaustion, and
host/client convergence. It may not synthesize, transform, re-sign, relabel,
or overwrite a recording. New expected traces or hashes require first-field
canonical diagnosis and separate Owner authorization before promotion.

Stage F owns runner paths, required-input behavior, current-format replay
execution, full-suite and real-ENet evidence, and baseline comparison. Its
exit cannot pass while a runner uses Replay 12, silently skips missing input,
or an unexplained digest is promoted. Stage A may begin without new replay
files because they can only be genuinely captured after the lifecycle runs.

## Stage A implementation evidence (Owner ACCEPTED 2026-10-18)

Stage A adds `counter_disposition` as an exact active-parent Attack value
(`""`, `accepted`, `declined`) and the copied immutable inspection **I**
witness, with empty value for ordinary inspections. A pure Counter publication
consistency policy runs after full GameState reconstruction and checks the
parent or **I** source, reversed Squadron identities, retained declaration
identity when present, controller, eligibility,
positive BLUE pool, literal availability, decision mirror, and published
`final_damage` against native canonical
`resolved_outcome.requested_hull_damage` (or validated **I** result). The
policy does not mutate state, replace Boundary A type normalization, or read
flow as decision authority. Save, Network, and Replay constants now allocate
11, 12, and 13 respectively. No historical file or expected hash changed.

Focused verification on 2026-10-18:

| Proof | Result |
| --- | --- |
| New direct/JSON absent, pending, accepted, declined, inspection **I**, malformed source/role/controller/pool/availability/damage, full-state digest and Accept/Decline distinguishability, filtered passive Network snapshot, and old-version rejection tests | **4/4 PASS, 141 assertions**. Zero, positive, and excess requested damage, including destroyed Counter Squadron, pass the complete pending publication reconstruction. |
| Existing CurrentAttackState, Boundary A InteractionFlow, Boundary C outcome reconstruction | **9/9 PASS (43 assertions); 39/39 PASS (479); 8/8 PASS (746)**. |
| Replay, Network, and Save metadata unit gates | **39/39 PASS (119); 48/48 PASS (87); 17/17 PASS (42)**. |
| Current Attack shared protocol and existing production resume | **25/25 PASS (1,058); 98/98 PASS (2,871)**. |
| Additional version/schema integration and UI projection tests | Concentrate Fire **2/2**, H9 shared protocol **5/5**, Network transport **14/14**, BUG-043 registration **3/3**, H9 timing **19/19**, modal router **32/32**, UI projector **34/34**, BUG-031 move decline **4/4**, all PASS. |
| Signed Save and exact RNG integration | **6/6 PASS, 110 assertions** when run with access to its existing user-data test directory. An initial sandboxed attempt could not write that directory; no product failure was observed. |

The older `test_counter_inspection_release.gd` is **0/15** under the new
schema. Its manually constructed inspection omits the required witness and
its assertions require the obsolete two-publication parent/child continuation
and Save-10 expectations. Its lifecycle rewrite belongs to Stages D/E and
the current replay/version adaptation to Stage F; it is not an acceptance
oracle for the Stage A state-schema exit. No Stage B–F code or tests were
changed to make that history pass. The full suite, real ENet role mappings,
current Replay-13 baselines, and manual gameplay evidence remain later gates.

The Owner **accepted Stage A** and **authorized Stage B only** on 2026-10-18.
The focused Stage A exit established exact state and flow
reconstruction, source checks, negative cases, stable full-state hashes, and
version rejection all passed. Historical baseline checksums above are
unchanged. The original integrated cost forecast remains 12–16 implementation
days plus 12–16 verification days; this bounded Stage A work revealed no
cost-limit breach, but later stages and Owner recording remain pending.
