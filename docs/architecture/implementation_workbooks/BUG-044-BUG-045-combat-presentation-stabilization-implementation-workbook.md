# BUG-044 + BUG-045: Combat Presentation Stabilization Implementation Workbook

Status: Accepted

Accepted by: Project Owner
Accepted date: 2026-09-06

Purpose: define the smallest architecture-preserving implementation package for
the completed-attack waiting presentation defect in BUG-044 and the live
destroyed-squadron board-retirement defect in BUG-045. This Draft does not
authorize production changes until accepted through repository governance.

## 1. Classification And Authority

Classification: **Bounded Architecture**. Canonical attack acknowledgement,
damage, and destruction behavior is already accepted and is not changed here.
The defects are downstream presentation/projection failures.

Binding authority, in precedence order:

1. accepted ADR-001 command-owned mutation;
2. accepted CON-001 current-attack state and semantic-transition contract;
3. accepted ADR-007 and CON-007 modal/continuation projection and authoritative
   interaction gating;
4. accepted ADR-010 reconnect projection and recovery convergence; and
5. the committed BUG-042/BUG-031/BUG-035 stabilization baseline.

The BUG-044 and BUG-045 issues and current production paths are implementation
evidence only. This workbook introduces no new architectural pattern.

## 2. Fixed Findings And Required Outcomes

### 2.1 BUG-044

Canonical completed-attack inspection and required-player acknowledgement are
correct. `UIProjector` correctly returns `attack_result_waiting` for a local
player who has acknowledged while another required acknowledgement remains.

The earliest incorrect transition is presentation-local:
`AttackExecutor.present_completed_attack_result_projection()` initializes the
panel through `AttackSimPanel.show_initial_attack_exec("Completed Attack")`.
That initializer installs the unrelated `Select attacking hull zone.` prompt.
For the already-acknowledged viewer, the executor then shows the result and
hides Confirm without replacing that prompt.

Required outcome: while completed inspection remains canonical, the panel must
show only completed-result/acknowledgement or waiting presentation. It must not
show a hull-zone instruction. The existing acknowledgement commands,
required-player set, completion rule, and recovered continuation remain
unchanged.

### 2.2 BUG-045

`ResolveDamageCommand` already owns canonical squadron destruction and commits
`current_hull == 0` plus `destroyed == true`. The earliest incorrect transition
is the host's live board projection after that accepted mutation.

`AttackExecutor` publishes canonical hull change, but its destruction cleanup
also depends on the executor-local retained defender board reference. That
reference can be cleared while synchronous command signals dismiss/reset the
presentation. `GameBoard` has a state-derived ship hull handler and an existing
idempotent squadron fade/hide retirement path, but no corresponding canonical
squadron-hull projection handler. Fade/hide alone does not retire a token from
board lookup or membership.

Required outcome: host and client board retirement must be derived from the
canonical `SquadronInstance` state delivered after accepted damage. `GameBoard`
must resolve the matching board token and narrowly enhance its existing
idempotent retirement path so that the exact token leaves selection,
collision/interaction, and board lookup/membership. Existing visual fade/hide
behavior may remain where useful, but is not token removal by itself. No
UI-owned destroyed flag, second destruction owner, or generic
destruction/projection framework is permitted.

BUG-006 remains separate: it concerns save/load reconstruction. The existing
load/bootstrap rule that does not spawn canonically destroyed squadrons is not
redesigned here.

## 3. Scope

In scope:

- the completed-result/waiting prompt and control state installed by
  `AttackExecutor`/`AttackSimPanel` while completed inspection is active;
- both required-player acknowledgement orders;
- canonical squadron hull/destruction presentation notification on authority
  and passive Network peers;
- `GameBoard` lookup and idempotent retirement of a token from a destroyed
  `SquadronInstance`;
- focused automated regressions and one real Network combat acceptance flow.

Explicit exclusions:

- attack declaration, resolution, acknowledgement, continuation, or modal
  priority semantics;
- damage/destruction mutation ownership;
- a generic presentation, continuation, action, or mutation framework;
- new UI-owned destruction or acknowledgement state;
- save format, replay format, command schema, or Network protocol changes;
- BUG-006 save/load reconstruction repair;
- BUG-043: its superseded canonical speed-persistence framing is retired.
  Current evidence identifies a separate bounded Network maneuver-preview /
  canonical-speed convergence defect after an accepted speed change. BUG-043
  remains STOPPED and out of scope; no speed-persistence investigation or
  repair is authorized here; and
- all BUG-046 architecture and behavior.

## 4. Entry Gates And STOP Conditions

Implementation may begin only after this workbook is accepted.

STOP and return to the Owner if any slice appears to require:

1. changing who must acknowledge, when acknowledgement commits, or when the
   completed inspection closes;
2. allowing any attack action while required acknowledgement is outstanding;
3. moving squadron destruction out of its accepted canonical command owner;
4. storing destruction state in a board token, panel, or other presentation
   object independently of `SquadronInstance`;
5. adding a broad presentation/continuation/action/mutation abstraction;
6. changing a command, Network protocol, save schema, or replay format; or
7. extending into BUG-006, BUG-043, or BUG-046.

Any unexpected replay-format change is an implementation STOP. The STOP report
must identify the exact Hot-Seat and Network fixtures and their capture
conditions required before implementation may resume. Those fixtures must be
manually recorded through real gameplay by the Owner. Codex must not generate,
synthesize, patch, transform, relabel, or programmatically regenerate replay
fixtures; generated compatibility, mechanical migration, or silent
reinterpretation is not acceptable.

## 5. Implementation Slices

### Slice A — BUG-044 completed-result waiting presentation

1. Add or use a narrowly named completed-result presentation operation in
   `AttackSimPanel`; do not route this state through the initial attack/hull-zone
   prompt initializer.
2. In `AttackExecutor.present_completed_attack_result_projection()`, render
   from the existing projected completed-inspection state:
   - local acknowledgement outstanding: completed result plus the existing
     acknowledgement control;
   - local acknowledgement complete but another player outstanding: completed
     result plus an explicit waiting presentation, with no actionable control;
   - all acknowledgements complete: allow the existing authoritative recovery
     path to restore the enclosing gameplay instruction.
3. Keep `UIProjector`, acknowledgement commands, modal routing, and canonical
   completed-inspection state unchanged unless a focused regression proves an
   implementation mismatch. Such a mismatch is a STOP under Section 4.

### Slice B — BUG-045 canonical-state-derived token retirement

1. Ensure accepted squadron damage publishes the canonical
   `SquadronInstance` and its resulting hull/destruction state on both authority
   and passive Network application paths.
2. Add the squadron analogue of `GameBoard`'s state-derived ship hull handling.
   When the canonical instance is destroyed or has zero hull, resolve its live
   board token and invoke the narrowly enhanced idempotent retirement path. The
   path must retire that exact token from selection, collision/interaction, and
   board lookup/membership; fade/hide may remain a visual effect only.
3. Remove the correctness dependency on
   `AttackExecutor._state.defender_squadron` surviving command callbacks.
   Executor-local references may support transient animation only; they may not
   decide whether canonical destruction is presented.
4. Preserve harmless duplicate notification tolerance. Repeated canonical
   refresh or legacy destruction notification must not leave a token, remove an
   unrelated token, or fail after the first idempotent removal.
5. Verify retirement clears selection, input/collision participation, and
   lookup membership. It must remain idempotent without retaining UI-owned
   destruction state or adding a generic projection framework.

## 6. Focused Regression Requirements

### BUG-044

- A completed attack with two required acknowledgements projects the result for
  both viewers.
- Attacker acknowledges first: attacker sees completed-result waiting, no
  hull-zone instruction, and no Confirm control until defender acknowledges.
- Defender acknowledges first: defender sees waiting while attacker retains the
  acknowledgement control; neither sees an unrelated hull-zone instruction.
- After the second acknowledgement, the existing continuation restores the
  correct enclosing instruction exactly once.
- Reconnect/reprojection into each partial-acknowledgement state produces the
  same presentation as uninterrupted play.

### BUG-045

- Accepted damage that sets a squadron to zero hull/destroyed retires its board
  token from canonical instance state on the authority peer.
- The passive peer retires the same token after accepted result application.
- Multiple squadrons destroyed in succession are each retired.
- Repeated removal notification is idempotent.
- No destroyed token remains selectable, collidable, or discoverable through
  board lookup.
- Nonlethal squadron hull change does not retire the token.
- Existing save/load reconstruction tests remain green as a BUG-006 boundary
  guard; this workbook adds no save/load workaround.

Focused suites must include the affected projector/modal, attack executor or
panel, GameBoard projection, damage command, and Network command-result paths.
The committed BUG-042/BUG-031 focused baselines must remain green. The existing
BUG-035 live commanded-squadron regression is also mandatory: Attack -> lethal
destruction of the final non-Heavy engager -> completed-result acknowledgement
-> recovery of the same squadron's legal Move. This preserves BUG-035,
CON-007 composed return, and the existing canonical recovery boundary without
changing their semantics.

## 7. Real Network Acceptance Scenario

Run one deterministic real two-process Network combat session with captured
host/client logs. The acceptance setup must contain at least two guaranteed
squadron kills and cover both bugs together:

1. In a host-author/client-passive attack, canonically destroy the first enemy
   squadron.
2. Confirm `destroyed == true` and `current_hull == 0` in canonical state, and
   confirm that the exact token is retired on both host and client: it is not
   selectable, collidable/interactable, or discoverable through board lookup
   or membership.
3. Attacker acknowledges the completed result first. Before defender
   acknowledgement, confirm the attacker still sees completed-result waiting
   and never a hull-zone instruction.
4. Defender acknowledges; confirm one clean continuation.
5. In a client-author/host-passive attack, canonically destroy the second enemy
   squadron. Confirm the same canonical state and complete retirement on both
   boards, proving successive lethal squadron destruction without a stale
   token.
6. Defender acknowledges the second completed result first. Before attacker
   acknowledgement, confirm the defender sees completed-result waiting while
   the attacker retains the acknowledgement control, with no hull-zone
   instruction. Then confirm one clean continuation after the attacker
   acknowledges.
7. Reconnect once while an acknowledgement remains outstanding. Confirm the
   reconnected viewer reconstructs the same completed-result waiting state and
   both boards still omit destroyed squadrons.

Record command sequence, player identity, acknowledgement order, canonical
squadron id/state, and visible board/prompt outcome in the acceptance evidence.

## 8. Mode And Persistence Verification

- **Hot-Seat:** run the focused completed-result acknowledgement and destroyed
  squadron projection scenario because the modified presentation components are
  shared.
- **Network:** the real acceptance scenario in Section 7 is mandatory, in
  addition to automated Network coverage, including both host-author /
  client-passive and client-author / host-passive lethal-destruction paths.
- **Reconnect:** mandatory for BUG-044 partial acknowledgement and BUG-045 board
  reprojection as specified in Section 7.
- **Save/load:** run existing destroyed-squadron reconstruction coverage only as
  a non-regression boundary for BUG-006; no new persistence behavior is in
  scope.
- **Replay:** run existing attack/damage replay regression. No format or fixture
  change is expected. The BUG-035 live commanded-squadron regression is
  mandatory non-regression evidence alongside BUG-031, BUG-042, and CON-007.
  Apply the manual fixture STOP in Section 4 if replay-format expectations fail.

## 9. Completion Criteria

This package is complete only when:

1. both acknowledgement orders have focused automated coverage and no
   completed-inspection state displays a hull-zone action prompt;
2. canonical squadron destruction removes the correct live board token on host
   and client without executor-local lifetime dependence;
3. the combined real Network acceptance scenario passes with retained evidence;
4. the required Hot-Seat, reconnect, save/load boundary, and replay regressions
   pass, including the mandatory BUG-035 Attack -> lethal final non-Heavy
   engager destruction -> acknowledgement -> same-squadron legal-Move recovery
   regression and the existing BUG-031, BUG-042, and CON-007 gates;
5. no command, state, protocol, save, or replay format changes were introduced;
   and
6. BUG-043 and BUG-046 remain untouched and stopped pending their separate
   Owner-directed work.
