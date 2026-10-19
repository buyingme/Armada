# Atomic Counter Stage F1 automated convergence evidence

Status: **F1 automated changes verified; Owner Replay-13 fixture clarification accepted; ready for genuine Owner recording. Fixture-dependent Stage F gates remain open; Stage F not accepted.**

Authority: [accepted consolidated workbook](../implementation_workbooks/atomic-counter-choice-lifecycle-consolidated-implementation-workbook.md), Stage F. The Owner accepted Stage E and authorized only automated convergence checkpoint F1 on 2026-10-19. Stage E was committed as `896e95f`; its accepted implementation and B-1 correction are unchanged by this checkpoint.

## F1 scope and current-format gates

- Current Save, Network, and Replay owners remain at versions 11, 12, and 13 respectively. The current replay unit assertion and Network/replay acceptance assertions now use those values.
- The real-ENet Counter runner requires one complete, canonically consistent source-bound Counter-choice publication. It no longer expects the removed intermediate Resolve Damage projection, duplicate child publication, or a terminal publication after Decline. It retains single choice, inspection consumption, child execution on Accept, composed return, role-mapping, and host/client convergence checks.
- The baseline and Network replay runners require separate current-format `replay_hot_seat_v13.json`, `replay_network_v13.json`, and `replay_counter_v13.json` inputs. Missing current inputs fail rather than pass or skip. New Hot-Seat trace/hash oracle paths are distinct from the immutable Replay-12 paths. No current replay input or oracle was produced by F1.

## Automated verification

| Gate | Result | Evidence |
| --- | --- | --- |
| Replay driver focused suite | PASS | 15/15 tests, 78 assertions. |
| Full repository regression | PASS | 4,513/4,513 tests; 26,165 assertions on the unrestricted local test runtime. A first sandboxed run was invalidated by denied local-port and application-data access. |
| Counter real ENet | PASS | Accept/Decline, surviving/destroyed variants, and both host/client role mappings; exactly one complete parent Counter publication and peer convergence. |
| Architecture lint | PASS | `scripts/lint_phase_k.sh`: 0 violations, 5 allowed branches. |
| Shell syntax and diff | PASS | Both changed shell runners pass `bash -n`; `git diff --check` passes. |
| Full Network/reconnect runner | PASS through fixture boundary | The full real-ENet run produced 21 successful process evidence records. The corrected assertion layer passed both fresh mappings, reconnect, commanded-Squadron, activation, and same-live Save-11/Network-12 compatibility checks, then stopped solely because `replay_network_v13.json` is absent. The complete runner cannot pass until Owner recording. |
| Replay-13 baseline and replay acceptance | BLOCKED ON OWNER RECORDING | `scripts/run_baseline_traces.sh --all` fails explicitly because all three distinct current-format inputs are absent. No fixture or hash was changed. |

## Owner recording checkpoint

The Owner must create three genuine application recordings through the current Replay-13 build, preserving each recorded JSON byte-for-byte:

1. A fresh Hot-Seat learning-scenario R1–R2 baseline at `tests/fixtures/baseline_traces/replay_hot_seat_v13.json`.
2. A fresh Network learning-scenario R1–R2 authoritative **host** recording at `tests/fixtures/baseline_traces/replay_network_v13.json`; start through the normal lobby and do not record from a save-resumed session.
3. A complete Counter lifecycle recording at `tests/fixtures/baseline_traces/replay_counter_v13.json` containing one complete source-bound Counter publication, an accepted choice, Counter-child execution, legitimate inspection consumption, and composed return.

Use the application's debug Shift+R save action or the replay saved automatically on game end/exit. Source-build recordings appear under the project `replays/` directory; packaged macOS recordings appear under `~/Library/Application Support/Armada/replays/`. For each file, retain the original path and SHA-256, recording date, build/version, mode, scenario, players, and Network role mapping. Copy only the genuine recording to its new reserved path. The [replay workflow](../../development/REPLAY_BASELINE_WORKFLOW.md) describes the application recording surfaces.

**Owner Replay-13 fixture clarification — 2026-10-19:** The Owner accepted the format-only correction in the [E2 entry record](atomic-counter-stage-a-e2-entry-record.md). `SIGNED_FORMAT_VERSION` aliases `FORMAT_VERSION`; it does not require an HMAC. The genuine debug Shift+R and automatic replay-save paths produce format-13 recordings without signing, while `GameReplay.sign_replay()` and verification remain separate, unchanged capabilities. The former signed-header wording conflated the format alias with an HMAC requirement. No replay loading, Network authority, or cryptographic-signing contract changed. Preserve each of the three recordings byte-for-byte, with source path, provenance, and SHA-256; do not synthesize, reconstruct, transform, or re-sign a recording, or automatically generate or install a fixture. Genuine application auto-save after Owner gameplay remains an allowed recording path.

The existing generator's `--install` still targets historical Replay-12 names and must not be used for this checkpoint. Once genuine recordings arrive, validate Replay-format-13 headers, contiguous command sequences, the single complete Counter publication, choice/child/inspection history, replay exhaustion, and host/client final-state convergence. HMAC presence is not a fixture gate. Compare the first changed trace field and canonical state-hash difference before requesting separate Owner approval for any new Hot-Seat trace/hash oracle. Historical Replay-12 inputs, traces, hashes, and BUG-074 evidence remain immutable. Final Stage F audit and Owner acceptance remain open.
