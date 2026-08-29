# MATCH-003 Network Resume Manual Acceptance

Status: Partial manual acceptance — fresh Network resume passed

Build/commit: final working tree (reported 2026-08-29)

The reported fresh-resume run used two real GUI processes on the original
save-owning installation. It restored the selected Network side successfully,
including the saved Ship-phase activation order. Retain screenshots,
state/cursor comparison, logs, tester, and exact committed build when recorded.

| Case | Required result | Result |
| --- | --- | --- |
| Fresh resume (reported) | A fresh Network resume restores the selected side and keeps board/input closed until installation acknowledgements and admission. | Passed (reported); saved Ship-phase activation order restored correctly. |
| Opposite mapping | Host -> Player 0 and client -> Player 1 also succeeds. Duplicate or incomplete selections cannot publish. | Pending separate manual record |
| Reconnect | After confirmed loss, explicitly assign a new endpoint to only the unoccupied side. The host does not reload or republish canonical state. | Pending |
| Compatibility | Same-live Network load, Hot-Seat load, and replay keep their existing behavior. | Pending |
| Restrictions | A copied save on another host installation is rejected; no automatic host/client mapping is available. | Pending |

Record tester, date, build, selected mapping, protocol version, pre-publication
assignment screenshot, restored-decision screenshot, state/cursor comparison,
and any failures.
