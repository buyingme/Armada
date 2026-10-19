# Atomic Counter Stage D — choice and child implementation evidence

Status: **Stage D Owner ACCEPTED 2026-10-19 following independent audit PASS.**
Recorded 2026-10-19 under the
[Owner-accepted consolidated workbook](../implementation_workbooks/atomic-counter-choice-lifecycle-consolidated-implementation-workbook.md).
Stage C is Owner-accepted in `3dac3aa`. Stage E is separately authorized;
Stage F remains unauthorized.

## Implemented boundary

- `GameManager.counter_choice_context_for_parent()` derives the exact active
  parent source and Counter participants from canonical Attack and Squadron
  owners, requiring a complete consistent installed Counter publication. Both
  `AttackExecutor` and `AttackPanelMirror` submit Accept/Decline with that
  context through `GameManager.submit_counter_choice()`.
- `CounterChoiceCommand` commits accepted or declined disposition once in the
  parent `CurrentAttackState`; the flow boolean remains a projection.
  Existing prehook, source, and legality checks remain in force.
- A decided parent with legitimate inspection **I** completes into an
  inspection witness. Accepted **I** retains the Counter projection until a
  source-bound child Begin; Declined **I** installs the enclosing Squadron
  route. No-**I** Accept replaces the active parent with the Counter child and
  locked Declare in one accepted Begin; no-**I** Decline retires the parent and
  installs the enclosing route. Premature completion and stale or duplicate
  source commands reject without mutating state or command machinery.
- Network's child Roll publication derives from the installed child/Declare.
  Counter child completion creates legitimate **J** when required and installs
  the enclosing Squadron Phase or commanded-Ship route when **J** is not
  required. Stage E retains responsibility for board-reload recovery, exact-once
  **J** release, and composed return after interruption.

## Verification — 2026-10-19

| Check | Result |
| --- | --- |
| Stage D focused: direct/JSON Accept/Decline with **I**, no-**I** atomic Accept/Decline, exact source through both real UI submitters after pending-choice JSON reconstruction, rejected stale/duplicate/premature commands with state/history/sequence/queue equality, child locked Declare and Network Roll, **I** witness JSON, child **J**/no-**J** completion, Squadron Phase and commanded-Ship routes, full-state JSON hashes at tested boundaries | **7/7 PASS, 326 assertions** |
| Prior Stage B admission, Stage C publication, and Counter command tests | **PASS within focused reruns and the full-suite run** |
| Full repository suite with normal app-data and local Network access | **4,501 tests: 4,485 passing, 16 deferred failures; 25,149/25,218 assertions**. The failure set is unchanged from the Owner-accepted Stage C checkpoint: fifteen historical Counter inspection/release tests and one Replay-12 version assertion. |
| Bounded real-ENet `--counter-only` acceptance driver | Both peers in mapping 0 executed `counter_choice` seq 11, parent `complete_attack` seq 12, inspection **I** acknowledgments seq 13–14, child `begin_attack` seq 15, one child Roll publication seq 16, Roll/damage/completion through seq 21, **J** acknowledgments seq 23–24, and enclosing Ship return through seq 27. The overall runner timed out because its current completion predicate still requires the obsolete intermediate Resolve Damage publication; its renewal is a Stage F obligation. |
| Diff whitespace check | **PASS** |

The real-ENet observation is bounded to mapping 0 and the stated ordered
commands; it is not a passing full acceptance run or both-role-mapping claim.
The existing historical replay inputs, expected hashes, baselines, and Owner
evidence were not modified. No current-format replay was recorded.

## Owner acceptance and deferred gates

The Owner accepted the Stage D implementation after independent audit PASS and
separately authorized Stage E. This acceptance closes the Stage D checkpoint;
it does not authorize Stage F or fixture/baseline promotion.

The historical Counter inspection/release unit fixture still assumes the old
two-publication flow and Save 10 contract. Its fifteen failures remain assigned
to Stage E recovery/composed return and Stage F version/fixture renewal. The
historical Replay-12 version assertion remains a Stage F failure. Stage E must
prove board reload and resumed UI, lost-follow-up recovery, destroyed original
Squadron handling, and exact-once **J** consumption. Stage F must renew
version-compatible replay inputs and runners through genuine Owner recording,
prove both real-ENet mappings and baseline/hash convergence, and meet its
manual checkpoint. This Stage D record authorizes neither stage.
