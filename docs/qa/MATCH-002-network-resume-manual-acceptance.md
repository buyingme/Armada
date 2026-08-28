# MATCH-002 Network Resume Manual Acceptance

Status: Superseded; historical QA evidence only; do not execute as an
acceptance plan

Superseded by the Project Owner's 2026-08-27 explicit session-local assignment
direction in
[ADR-011](../architecture/adr/ADR-011-network-match-resume-and-principal-entitlement.md).
This artifact is preserved only as evidence for the superseded credential/RSA
implementation. It SHALL NOT be used to accept the replacement architecture or
to justify further implementation or repair of MATCH-002. A new acceptance plan
must derive from a separately accepted replacement implementation workbook.

Historical implementation under test: uncommitted MATCH-002 working tree based
on the Owner-established 4100/4100 pre-implementation baseline.

Do not attach capability exports, private keys, challenges, signatures, or
unredacted credential-store contents to acceptance evidence.

## Historical automated prerequisite

The superseded plan required `./scripts/run_network_resume_acceptance.sh`. Its
separate-process A-D coverage had to pass before manual acceptance. The runner
used distinct host, original-client, replacement, competitor, invalid-client,
and foreign-host installation roots; reused only the installations required by
the scenario; exercised protocol-4 production ENet RPCs; and deleted
transferred private material. Retained failure logs and JSON evidence had to
remain redacted.

## Historical manual cases

| Case | Expected result | Result | Evidence |
| --- | --- | --- | --- |
| New two-process Network match | Both installations independently prepare resume access. Neither private capability crosses the Network. The board opens only after the exact verifier-fingerprint confirmation gate. | Not run | Record redacted host/client logs and the build commit. |
| Fresh-session resume | Save at a visible decision, close both applications, reuse the original host installation, reconnect the original client, stage, and explicitly publish. No board or gameplay command appears before the final gate; round, phase, pieces, actor, legal controls, and visible hidden information converge afterward. | Not run | Screenshots before publication and after convergence; redacted state-hash evidence. |
| Deliberate replacement holder | Explicitly export the remote capability and import it into a clean profile with a different name/identity. The replacement controls the unchanged saved principal/player; no host grant or binding mutation occurs. | Not run | Redacted host/replacement logs and binding hash. Never retain the export. |
| Competing holder | While the incumbent remains connected, connect a third process holding the copied capability. The competitor is rejected without eviction, snapshot, board change, cursor change, or gameplay command. | Not run | Redacted incumbent/competitor status and host state hash. |
| Ordinary reconnect | Disconnect during a visible recoverable decision, wait for confirmed disconnect, then reconnect with the valid capability. The filtered pending decision returns once, admission opens only after installation acknowledgement, and the host does not reload or republish canonical state. | Not run | Before/after decision screenshots, cursor, and redacted logs. |
| Missing/wrong entitlement and foreign host | Try a missing/wrong capability and a copied save on a different host installation. Both fail before partial board/state publication with a clear unsupported/error status. | Not run | Redacted failure status and zero-publication counters. |
| Compatibility preservation | Load an earlier same-match Network save in the unchanged live match, load an unrelated Hot-Seat named save/checkpoint, and replay a Network replay. Existing behavior remains unchanged and no entitlement traffic is synthesized for Hot-Seat/replay. | Not run | Redacted logs plus existing regression output. |

## Historical acceptance record

- Tester: pending
- Date: pending
- Commit/build: pending
- Automated process-isolated A-D result: PASS on 2026-08-26; protocol-4 ENet,
  isolated/reused installation roots, replacement/competition/reconnect,
  duplicate proof, admission acknowledgement, forged proof, and copied
  save on a foreign host all passed with retained secrets removed.
- Manual result: pending
- Notes: none
