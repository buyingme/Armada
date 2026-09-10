# Ship Activation Maneuver — Gameplay-Interaction Requirements

> **Status:** Accepted
> **Scope:** The complete baseline Maneuver Step within Ship Activation.
> **Parent interaction:** SAI-060 through SAI-065 in
> [Ship Activation — Gameplay-Interaction Requirements](ship_activation_interaction.md).
> **Architecture context:** ADR-006, ADR-010, AT-002 / BC-003.
> **Authority posture:** This is a TO-BE player-interaction requirements
> specification. It is subordinate to accepted ADRs and Contracts; it is not
> an ADR, Contract, Rule Capability Package, UI design, or implementation plan.

Accepted by: Project Owner
Accepted date: 2026-09-10

## 1. Purpose and authority

This document specifies the complete baseline player interaction for the
mandatory Ship Activation Maneuver Step. It refines the accepted parent
requirements without redefining Ship Activation ownership, command
architecture, Network authority, persistence, replay, or generic interaction
recovery.

Authority is divided by question type:

- `Resources/SWM-RULES-REFERENCE-GUIDE-150/`
  `SWM-RULES-REFERENCE-GUIDE-150.md` (**RRG**) is definitive for the game
  rules in this specification, especially **Commands**, **Maneuver Tool**,
  **Obstacles**, **Overlapping**, **Ship Activation**, **Ship Movement**,
  **Speed**, **Speed Chart**, and **Yaw**.
- `Resources/SWM01-ARMADA-LEARN-TO-PLAY/`
  `SWM01-ARMADA-LEARN-TO-PLAY.md` (**LTP**) is supporting game-rule evidence.
  Where its abbreviated learning rules omit RRG detail, the RRG governs.
- [Ship Activation — Gameplay-Interaction Requirements](ship_activation_interaction.md)
  governs the enclosing player interaction, including SAI-001 and SAI-060
  through SAI-065.
- [ADR-006](../../architecture/adr/ADR-006-canonical-ship-activation-boundary-ownership.md)
  governs the canonical Ship Activation identity and Maneuver opportunity.
- [ADR-010](../../architecture/adr/ADR-010-gameplay-interaction-decision-equivalent-recovery.md)
  governs decision-equivalent recovery and the transient presentation
  boundary.
- Accepted command, Network, replay, save/load, and rule-capability authority
  retains its existing ownership. This document cross-references those
  boundaries and does not replace them.

The current implementation and tests are evidence for established behavior,
not independent normative authority. Known implementation drift is recorded
in Appendix B and is not normalized into these requirements.

## 2. Scope and interaction hierarchy

```text
Ship Activation
└─ Maneuver [mandatory while the normal activation survives]
   ├─ Enter Maneuver
   ├─ Determine Course [reversible until commitment]
   │  ├─ derive canonical speed and legal navigation chart
   │  ├─ present maneuver tool and preview
   │  ├─ select a legal Navigate-modified speed/yaw result
   │  │  └─ preview automatically derived minimum source consumption
   │  ├─ adjust legal yaw
   │  └─ choose legal tool side/alignment
   ├─ Commit Maneuver [binding]
   ├─ Execute Maneuver
   │  ├─ determine final ship position
   │  ├─ resolve ship overlap
   │  ├─ resolve squadron overlap / displacement
   │  └─ resolve obstacle overlap
   └─ Complete Maneuver
      └─ enclosing Ship Activation exposes End Activation when legal
```

This hierarchy describes gameplay interaction. It does not require a generic
serialized step object, a generic continuation framework, a new command type,
or a second owner for canonical state.

In scope are Determine Course, the baseline Navigate command, maneuver-tool
interaction, preview, commitment, execution, all overlaps caused by that
execution, nested squadron displacement, rejection recovery, Network
projection, and reconstruction of a live Maneuver decision.

Out of scope are Squadron movement, Attack, the hypothetical Maneuver Helper,
generic movement or Network architecture, generic UI framework design,
BUG-046, and the detailed behavior of individual cards or other special
rules.

## 3. Cross-cutting state and authority requirements

### SMI-001 — Decision-equivalent recovery

Every live Maneuver decision SHALL satisfy SAI-001 and ADR-010. From the
current authoritative gameplay situation, Armada SHALL recover or
deterministically derive:

1. that the Maneuver opportunity exists and is mandatory;
2. the active ship and the player entitled to control it;
3. the current canonical speed and ship maximum speed;
4. the applicable navigation chart, yaw modifiers, Navigate sources, and
   legal source capability;
5. the legal course choices and their automatically derived minimum source
   consumption;
6. whether no Maneuver has committed or a matching active Maneuver execution
   is resolving;
7. every unresolved mandatory overlap consequence and its controller; and
8. the semantic path that either completes Maneuver and returns to Ship
   Activation or exceptionally terminates the destroyed ship's activation.

Equivalent authoritative situations SHALL expose equivalent actionable
Maneuver semantics in Hot-Seat and Network play and after supported UI rebuild,
save/load, or reconnect.

### SMI-002 — Canonical and transient state boundary

- `ShipInstance.current_speed` remains the canonical current-speed authority.
- Before commitment, candidate Navigate speed and yaw changes remain transient
  and do not change `ShipInstance.current_speed` or consume Navigate resources.
- Canonical ship position, rotation, command resources, damage, displaced
  squadron positions, Ship Activation identity, and Maneuver opportunity
  disposition remain with their accepted owners.
- The activation-scoped active Maneuver execution record defined by ADR-006 is
  authoritative after commitment and remains active until normal Maneuver
  completion or exceptional termination.
- Maneuver-tool nodes, visible segments, joint widgets, alignment display,
  ghost ship, warning text, hover state, camera state, and uncommitted course
  geometry are transient and non-authoritative.
- Transient state SHALL project canonical state one way. It SHALL NOT create,
  overwrite, consume, or repair canonical gameplay state.
- A missing or rebuilt maneuver tool SHALL NOT remove, complete, or make
  optional an `OPEN` Maneuver opportunity.

### SMI-003 — Authoritative mutation and Network projection

Binding speed changes, maneuver results, resource spends, damage, displacement
placements, opportunity consumption, and activation progression SHALL use the
accepted authoritative semantic-command architecture. A presentation callback
or local scene mutation is not an alternative authority.

In Network play, only the entitled player originates player-authored gameplay
decisions. The authority validates and accepts them through the existing
command path and alone originates any automatic authoritative follow-up
transition required after an accepted decision or consequence. Passive peers
apply ordered accepted results and project the viewer-authorized canonical
representation of the resulting state; they need not receive or reproduce an
identical authority-private internal representation. They SHALL NOT originate
either gameplay decisions or automatic authoritative follow-up commands.

### SMI-004 — Rejection and stale-intent recovery

A rejected or stale Maneuver commitment SHALL atomically leave canonical
speed, Navigate resources, committed result, and active Maneuver execution
unchanged. The live Maneuver opportunity remains actionable unless an accepted
exceptional terminal transition ended it. Before input is re-enabled, the
Maneuver interaction SHALL re-derive legal sources, candidate speed, tool
geometry, preview, and commitment availability from the matching canonical
ship and Ship Activation identity.

A result or rejection for another ship or an obsolete activation identity
SHALL NOT mutate, dismiss, consume, or rebuild the current activation's
interaction.

## 4. Entering the Maneuver Step

### SMI-010 — Entry conditions

The Maneuver interaction becomes live when the active ship's matching
ADR-006 Maneuver opportunity is `OPEN`. For a surviving normal Ship
Activation it is mandatory and is not ordinarily declinable.

Entry SHALL derive the active ship, controlling player, current speed,
maximum speed, applicable navigation chart, available Navigate dial/token
sources, and applicable integrated rule modifiers from authoritative state.
Scene-local activation progress or a modal page alone SHALL NOT establish
entry or entitlement.

### SMI-011 — Initial presentation

For canonical speed greater than zero, entry activates a maneuver tool for the
active ship, initially straight and limited to the segments and joints
applicable to that speed. It exposes legal candidate joint adjustment, legal
candidate speed-change controls, a final-position/facing preview, and an
explicit Maneuver commitment action.

For canonical speed zero, entry still activates a live maneuver-tool
interaction. It shows only the tool's top/end segment and the `+` and `−`
speed-change buttons. It does not show ordinary yaw controls or a translated
ghost destination. The `−` button remains visible but cannot change speed
below zero; `+` is effective only when a legal Navigate speed increase is
available.

Speed zero therefore means a minimal live Maneuver interaction, not absence of
the tool and not automatic Maneuver completion.

This speed-zero presentation is an Armada Owner/UI requirement. The RRG
establishes that a speed-zero maneuver executes without movement and may have
rule-authorized exceptional yaw; it does not prescribe this digital control
layout.

## 5. Determine Course

### SMI-020 — Reversible course exploration

During Determine Course, the controller may explore currently legal courses
before commitment. The tool is straightened when the interaction is created.
At positive speed, each active joint may then be adjusted left or right only
within the yaw value shown for that joint at the current candidate speed,
including an applicable Navigate dial bonus.

The tool and preview SHALL update immediately as legal candidate speed, yaw,
or side choices change. An uncommitted course may be adjusted or abandoned in
favor of another legal course. These actions do not change
`ShipInstance.current_speed`, consume Navigate resources, move the canonical
ship, create an active Maneuver execution, or commit its final transform.

Determine Course is execution-oriented and exposes only courses that can be
legally executed. Unrestricted hypothetical exploration belongs to the
separate deferred Maneuver Helper.

### SMI-021 — Tool geometry and alignment

- The candidate Maneuver speed selects the speed-chart column and the joint at
  which the ship would finish its movement. Before commitment, that candidate
  is derived from canonical current speed plus the selected legal Navigate
  effect and remains transient.
- Segments beyond that final joint have no movement effect and need not be
  presented as active course geometry.
- The tool begins attached to a legal side of the front of the ship's base.
- The preview places the ship on the same side of the tool at the start and
  finish.
- The ship may not overlap the maneuver tool at its ordinary final position.
  If one side would cause that overlap, the other side SHALL be used. If
  neither side would cause it, the controller may choose either side.
- If physical board congestion would prevent placement of the tool, the
  interaction SHALL still permit determination of the rules-equivalent final
  position; obstruction by intermediate ships, squadrons, or obstacles does
  not itself block the Maneuver.
- At speed zero, the top/end segment is aligned relative to the ship exactly as
  it would be for a completely straight maneuver tool.

### SMI-022 — Preview meaning

At positive speed, the preview shows the prospective final ship position and
facing derived from the current legal course. It may also warn of currently
derivable collisions, overlap consequences, or integrated rule effects.

Preview collision detection and warnings are advisory transient projections.
Canonical overlap determination and consequences occur through authoritative
execution after commitment. Preview absence, error, or staleness SHALL NOT
change the rules result.

## 6. Navigate resolution

### SMI-030 — Timing and automatic source derivation

A baseline Navigate command may resolve during Determine Course. The player
selects the desired legal speed/yaw result and does not explicitly select a
Navigate dial, token, or combination. Before commitment, the controller may
change that candidate result and inspect the automatically derived source
requirement. No source is consumed, no canonical speed changes, and no
authoritative yaw bonus exists during this exploration.

At commitment, authoritative rules derive and atomically consume the minimum
Navigate resources required for the selected result:

1. prefer an available, usable transient Navigate dial over a stored Navigate
   token;
2. use a token when no usable dial is available and the token alone is
   sufficient; and
3. use dial and token together when both are required, including a selected
   speed change of two.

The interaction SHALL show the derived source consumption before commitment.
If both are required, they are spent simultaneously as one Navigate
resolution. A ship cannot resolve Navigate more than once in the round. Armada
does not expose a separate interaction to resolve Navigate while deliberately
producing no effect.

A selected course that requires no Navigate modification derives no Navigate
source consumption and does not resolve Navigate.

This result-first, pre-commit-transient, commit-time minimum-source derivation
is an intentional Owner-approved digital rules deviation. The RRG requires a
tabletop player to decide whether to spend the dial, token, or both before
resolving the command and permits resolving a command without producing its
effect. Armada adopts the digital commitment timing and narrows the source and
no-effect choices to simplify the interaction; it does not claim strict RRG
equivalence for that choice surface.

### SMI-031 — Navigate dial effect

When the derived authoritative source is a Navigate dial, its RRG effect
permits the controller to:

- increase or decrease the ship's speed by one; and/or
- increase the yaw value of one joint by one for this Maneuver.

The yaw increase applies to one active joint chosen by the controller. A `-`
yaw value becomes `I`, `I` becomes `II`, and `II` cannot be increased. The
bonus is Maneuver-scoped and does not alter the printed navigation chart.

### SMI-032 — Navigate token effect

When the derived authoritative source is a Navigate token, its RRG effect
permits the controller to increase or decrease the ship's speed by one. A
token alone grants no yaw increase.

### SMI-033 — Combined Navigate dial and token

When authority derives a Navigate dial and token together, both RRG effects
apply in the same Navigate resolution. The established baseline result is:

- a total speed change of up to two, subject to the legal speed bounds; and/or
- the dial's increase of one yaw value on one joint.

Thus dial alone provides a speed-change budget of one plus its optional yaw
effect; token alone provides a speed-change budget of one and no yaw effect;
dial plus token provides a combined speed-change budget of two plus the dial's
optional yaw effect. Combining sources does not permit a second Navigate
resolution.

### SMI-034 — Speed bounds and controls

Every Navigate speed result SHALL be within:

```text
minimum speed = 0
maximum speed = the ship's maximum-speed value
```

A ship cannot accelerate into a speed-chart column in which it has no yaw
values. Attempts beyond either bound or beyond the available Navigate budget
do not change the candidate and consume no source.

The `+` and `−` controls remain present throughout the live maneuver-tool
interaction. A control whose next increment is illegal remains non-effective.
In particular, at speed zero `−` remains visible but has no effect.

### SMI-035 — Candidate and committed speed changes

Before Maneuver commitment, each legal `+` or `−` operation changes only the
transient candidate speed. The tool SHALL be re-derived from that candidate:

- positive speed to zero collapses the tool to the speed-zero representation;
- zero to positive speed expands and re-derives the normal tool;
- positive speed to another positive speed selects the candidate speed-chart
  column, active segments, joints, and final-position preview; and
- any retained yaw selection that is not legal at the candidate speed is
  removed or clamped without changing canonical state.

Candidate exploration may return to the canonical starting speed or another
legal candidate without consuming Navigate resources or increasing the
available Navigate budget. Only accepted Maneuver commitment applies the
selected resulting speed to `ShipInstance.current_speed`, as part of the
coherent authoritative boundary defined by ADR-006.

## 7. Maneuver commitment

### SMI-040 — Explicit commitment boundary

The controller explicitly commits the selected legal course. Until that
action, tool geometry, yaw selection, alignment, and final-transform preview
remain reversible and non-authoritative.

Commitment SHALL validate the matching ship and Ship Activation identity, the
`OPEN` Maneuver opportunity, absence of an active Maneuver execution, canonical
starting speed, candidate resulting speed, legal yaw, Navigate source
availability and budget, legal tool side, and any applicable integrated rule
modifiers.

Acceptance atomically derives and consumes the minimum required Navigate
source or sources under SMI-030, applies the resulting canonical speed,
establishes the committed Maneuver result, and creates one matching active
Maneuver execution record under
ADR-006, or changes none of them. Once accepted, the selected course must be
executed and cannot be cancelled merely because its result or overlap
consequences are undesirable.

### SMI-041 — Commitment is not Maneuver completion

Commitment begins authoritative execution; it does not itself complete the
Maneuver opportunity. The matching ADR-006 Maneuver disposition remains
`OPEN` while any mandatory ship overlap, damage, obstacle consequence,
squadron displacement, or other integrated mandatory consequence remains
unresolved.

For a surviving activation boundary, `OPEN` without an active Maneuver
execution is uncommitted exploration; `OPEN` with the matching active execution
is one committed Maneuver resolving mandatory consequences; and `CONSUMED`
with no active execution is the normal completed state. An active execution
prevents a second commitment for the same activation.

These normal state combinations do not require an `OPEN` opportunity to
survive destruction. ADR-006 exceptional termination clears the destroyed
ship's activation identity, dispositions, active execution, and owned nested
state without fabricating Maneuver consumption.

No presentation-only flag may stand in for committed authoritative results or
for completion of those consequences.

## 8. Execute Maneuver

### SMI-050 — Ordinary ship movement

At positive speed, authoritative execution places the ship at the position and
facing produced by the committed course at the joint corresponding to its
canonical speed. Only the starting and final positions matter for overlap;
ships may move through ships, squadrons, and obstacles.

The canonical position and rotation change only through the accepted Maneuver
execution path. Animation or instantaneous visual placement is presentation
and does not define the rules result.

### SMI-051 — Speed-zero execution

When canonical speed remains zero at commitment:

- the ship performs no physical translation or ordinary yaw;
- its canonical position and facing remain unchanged;
- it is nevertheless considered to have executed a Maneuver;
- its unchanged final position is evaluated for all applicable ship,
  squadron, and obstacle overlaps; and
- if the activation survives, after all mandatory consequences resolve,
  Maneuver completes through the same accepted authoritative Ship Activation
  progression as any other legal Maneuver.

Speed zero SHALL NOT bypass the authoritative Maneuver execution path, consume
the opportunity through scene-local state, or skip applicable overlap effects.

### SMI-052 — RRG executed-maneuver event

The RRG event at which a ship has executed or finished its maneuver is distinct
from Armada's later canonical transition of the Maneuver opportunity to
`CONSUMED`.

Ship-overlap placement/reduction, overlap damage, and their immediate results
resolve before the RRG executed-maneuver event. Applicable consequences whose
timing is after executing or finishing a maneuver resolve after that event.
This includes baseline post-execution overlap work and permits future
**Integrated** Rule Capability Packages to recognize the RRG event without
prematurely completing the Armada opportunity.

The matching Maneuver may remain `OPEN` with its active execution record after
the RRG event while mandatory post-execution consequences and nested decisions
resolve. Only SMI-070 defines the later normal `CONSUMED` boundary.

## 9. Overlap and collision resolution

### SMI-060 — Authoritative overlap determination

Overlap is determined from the committed Maneuver and the ship's resulting
final-position attempt, not from the transient ghost. A component crossed only
during movement is not overlapped. Applicable base geometry defined by the RRG
governs detection, including the ship's shield dials and their plastic frames;
squadron activation sliders are ignored.

Touching without one base lying on top of another is not overlap. The
authoritative execution path SHALL determine and record the final result and
all canonical consequences.

### SMI-061 — Ship overlap

If the attempted final position overlaps another ship, the moving ship cannot
finish there normally. Execution SHALL:

1. temporarily reduce the Maneuver speed by one without changing
   `ShipInstance.current_speed`;
2. retry the corresponding committed course at the reduced speed;
3. repeat until the ship can finish without ship overlap or the temporary
   speed reaches zero; and
4. if necessary at temporary speed zero, leave the ship at its original
   position.

If the committed Maneuver already begins at speed zero, there is no lower
speed to try: the ship remains in place and proceeds directly to the applicable
overlap consequences.

The temporary reduction creates no new course decision. The committed yaw
geometry applicable to each reduced speed is reused; later tool portions that
do not apply at that speed have no movement effect. A ship forced to a reduced
speed by ship overlap may overlap the maneuver tool at its final position.
Its canonical current speed returns/remains at the speed shown by its speed
dial after execution.

After the legal final position is determined, deal one facedown damage card to
the moving ship and one facedown damage card to the closest ship it overlapped,
subject to applicable integrated rule modifications. If more than one ship was
overlapped, the RRG closest-ship determination governs. Ship-overlap execution
is not complete until this damage and any immediate mandatory consequences,
including destruction, resolve authoritatively.

Only after the ship-overlap placement/reduction, damage, and immediate results
complete has the ship reached the RRG executed-maneuver event described by
SMI-052.

An active ship destroyed by an overlap consequence follows the accepted
exceptional terminal Ship Activation path. The system SHALL NOT fabricate
Maneuver consumption or End Activation merely to satisfy normal progression.

### SMI-062 — Squadron overlap and displacement

After the ship's legal final position is established, any squadron whose base
it overlaps is removed from the way and the ship finishes its physical
placement. Mandatory displacement is then a nested authoritative interaction.
Each affected `SquadronInstance` remains the owner of its canonical squadron
position.

The player who did not move the ship controls placement of every displaced
squadron, regardless of squadron ownership. That player may place them in any
order and SHALL:

- place as many as possible touching the ship that moved;
- place a squadron that cannot touch the ship touching another squadron that
  is touching the ship;
- keep every squadron inside the play area; and
- avoid overlap with any ship or squadron.

A squadron placed on an obstacle because of this displacement does not resolve
that obstacle's overlap effect.

Each tentative drag or placement ghost is transient. Mandatory displacement
and its confirmed squadron positions SHALL resolve through an authoritative
semantic transition. Invalid placement is rejected without completing that
squadron's placement or ending the nested interaction.

All affected squadrons must be legally placed and the authoritative
displacement result accepted before authority-side control returns to the
still-`OPEN`, matching active Maneuver execution for re-evaluation.
`InteractionFlow`, modal state, controllers, and callbacks may present or
route the interaction but are not gameplay or completion authority. This
specification introduces no concrete command design or generic continuation
mechanism.

### SMI-063 — Obstacle overlap

A ship overlaps an obstacle when part of its base is on top of the obstacle at
its final position. Moving through an obstacle has no effect by itself. If the
ship overlaps more than one obstacle, every applicable obstacle rule is
invoked and its effects may resolve in any order as provided by the RRG. Where
no RRG rule or **Integrated** Rule Capability Package assigns that ordering
choice to another player, Armada's Owner interpretation is that the controller
of the moving ship chooses the resolution order. This controller assignment is
an explicit Armada interpretation of an RRG ambiguity, not an explicit RRG
rule.

Obstacle detection and invocation are part of baseline Maneuver execution,
including at speed zero. The detailed effect of each obstacle, any choice it
creates, and any modification by an objective, card, or special rule remain
with the corresponding accepted rule authority or Rule Capability Package.
Every live nested choice, including the moving ship controller's multiple-
obstacle order choice, must resolve authoritatively and satisfy SAI-001 and
ADR-010. While the activation boundary survives, it returns through its
purpose-specific consequence owner before Maneuver completes; this requirement
creates no generic continuation owner, queue, stack, or FSM.

Invoking every applicable obstacle rule is mandatory and cannot be omitted
merely because its detailed rule logic is owned elsewhere. An invoked rule may
itself provide an optional result; that option remains governed by the rule and
its Rule Capability Package.

### SMI-064 — Multiple overlap categories

Ship, squadron, and obstacle overlap consequences that apply to the same
executed Maneuver SHALL resolve while they remain applicable. Resolution
ordering SHALL follow the RRG and applicable integrated Rule Capability
Package authority. Ship-overlap resolution and its damage complete before the
RRG executed-maneuver event.
Where those sources do not uniquely determine the relative order of mandatory
squadron displacement and post-execution obstacle effects, Armada resolves
squadron displacement first and obstacle effects second. Multiple applicable
obstacle effects may resolve in any order as provided by the RRG, with the
controller assignment in SMI-063 where no rule assigns another player. An
explicit RRG or Integrated Rule Capability Package order takes precedence over
the fallback.

For a surviving normal activation, the Maneuver opportunity remains `OPEN`
throughout the complete mandatory consequence sequence.

The RRG explicitly establishes the rules-event ordering of ship-overlap
placement/reduction and damage before the executed-maneuver event, and obstacle
effects after execution. Where neither the RRG nor an Integrated Rule
Capability Package determines the relative order between mandatory squadron
displacement and post-execution obstacle effects, displacement-first is an
Armada Owner interpretation.

### SMI-065 — Play-area destruction after ship-overlap resolution

Play-area destruction SHALL be evaluated against the moving ship's actual
final position after every applicable ship-overlap placement/reduction has
determined that position. A merely plotted out-of-bounds destination does not
destroy the ship if ship-overlap resolution leaves its actual final position
entirely inside the play area.

At the actual final position, the ship is destroyed if any portion of its base
is outside the play area. For this RRG determination, ignore the ship's shield
dials and the plastic portions of the base that frame those dials. This
geometry is deliberately different from ship-overlap geometry under SMI-060,
which includes those parts.

Destruction resolves through ADR-006's accepted exceptional terminal semantics:
the authority clears the activation and active Maneuver boundary without
fabricating normal completion, return, or End Activation.

### SMI-066 — Continuing applicability and survival

After the RRG executed-maneuver event, each consequence resolves only while
its trigger, subject, and required owning boundary remain applicable. After
each authoritative consequence, the authority SHALL re-evaluate survival and
the remaining applicable obligations.

If an earlier consequence destroys the moving ship, Armada SHALL NOT fabricate
later ship-dependent consequences, a purpose-specific return to a nonexistent
Maneuver boundary, normal Maneuver `CONSUMED`, or End Activation. Independent
consequences that remain applicable despite destruction are governed by their
own accepted rule authority or Integrated Rule Capability Package.

## 10. Completion and return to Ship Activation

### SMI-070 — Maneuver completion

For a surviving normal activation, the Maneuver completes only when:

1. one legal course, including a legal speed-zero course, has been committed;
2. the authoritative final ship transform or no-movement result is accepted;
3. all applicable ship-overlap damage and immediate mandatory results are
   complete;
4. all required squadron displacement is complete;
5. all applicable obstacle consequences and nested choices are complete; and
6. no other integrated mandatory Execute Maneuver consequence remains live.

Only then may the accepted normal completion transition atomically change the
matching ADR-006 Maneuver opportunity from `OPEN` to `CONSUMED` and retire the
matching active Maneuver execution exactly once. Absence of that record, an
identity mismatch, or an outstanding mandatory consequence rejects normal
completion before mutation.

### SMI-071 — Return and End Activation

After Maneuver is `CONSUMED`, control returns to the enclosing Ship Activation
owner. That owner exposes the accepted explicit End Activation interaction
when all other mandatory prerequisites are satisfied. End Activation, not the
Maneuver presentation or a displacement callback, performs the normal
activation cleanup and next-actor transition.

If the active ship was destroyed during Maneuver consequences, the accepted
exceptional terminal transition applies instead and no End Activation decision
is fabricated.

While that boundary survives, every purpose-specific mandatory-consequence
transition binds to the matching activation and Maneuver execution identities
and returns authority-side to the active Maneuver boundary for re-evaluation.
The authority may originate the automatic completion transition only when
ADR-006 permits it. A passive peer projects the accepted result and SHALL NOT
originate that follow-up.

## 11. Save/load, reconnect, replay, and reconstruction

### SMI-080 — Re-derivation of a live Maneuver

Save/load and reconnect install canonical gameplay state through existing
owners. If the matching Maneuver opportunity is still `OPEN`, Armada SHALL
reconstruct the live interaction from the active ship and Ship Activation
identity, canonical speed, command resources, applicable rule state, the
presence or absence of the matching active Maneuver execution record, and any
purpose-specific unresolved nested consequence.

`OPEN` without an active execution reconstructs uncommitted exploration.
Uncommitted candidate speed, yaw, and tool geometry are not persisted; the
fresh tool starts from canonical speed. In particular, canonical speed zero
reconstructs the minimal top-segment and `+`/`−` representation, while positive
speed reconstructs the normal tool.

`OPEN` with the matching active execution reconstructs the committed Maneuver
and resumes its remaining mandatory authoritative consequences rather than
offering a different course or duplicating completed effects. `CONSUMED`
reconstructs with no active Maneuver execution and no live Maneuver decision.

### SMI-081 — Replay and passive Network behavior

Replay applies accepted semantic commands in authoritative history order and
does not persist or replay transient tool manipulation. A passive Network peer
projects its viewer-authorized canonical representation of accepted speed,
active Maneuver execution, movement, damage, displacement, opportunity, and
progression results in order; it need not reproduce identical authority-
private internal state. Neither reconstruction nor passive projection may
originate a player decision or an automatic authoritative follow-up command.

## 12. Baseline versus Rule Capability Package behavior

### SMI-090 — Baseline behavior

The baseline defined here includes:

- the mandatory ordinary Maneuver opportunity;
- the printed speed chart and ordinary yaw limits;
- Owner-approved automatic minimum-source derivation for Navigate dial, token,
  and combined resolution;
- canonical speed bounds and live speed-zero representation;
- ordinary course preview, alignment, commitment, and execution;
- RRG ship, squadron, and obstacle overlap integration; and
- authoritative completion and decision-equivalent recovery.

### SMI-091 — Deferred integrated rule behavior

Cards, objectives, obstacle-specific effects, or other special rules may
modify the baseline only through their accepted Rule Capability Package and
applicable rule authority. This document does not invent speculative upgrade
behavior.

In particular, baseline speed zero exposes no ordinary yaw controls. A
speed-zero yaw interaction exists only when an **Integrated** rule or card
effect explicitly permits clicks of yaw at speed zero. Its legal clicks,
declaration, presentation, execution, collision result, persistence, Network
behavior, and tests belong to that effect's Rule Capability Package while
preserving the canonical and completion boundaries in this document. Codex
may not mark such a package `Integrated`.

An Integrated package may extend speed-zero execution behavior, but it SHALL
NOT weaken ADR-006 commitment atomicity, active-execution ownership,
decision-equivalent recovery, nested-consequence return, or exact-once
completion invariants.

## 13. Acceptance requirements

| ID | Required result |
| --- | --- |
| SMI-AC-001 | `OPEN` without an active Maneuver execution reconstructs uncommitted exploration; `OPEN` with the matching execution reconstructs its unresolved mandatory consequences; `CONSUMED` has no active execution. |
| SMI-AC-002 | Positive-speed entry presents the normal straight tool, legal active joints, speed controls, and preview derived from canonical speed. |
| SMI-AC-003 | Speed-zero entry presents only the top/end segment and visible `+`/`−` controls; `−` has no effect. |
| SMI-AC-004 | The player selects a legal Navigate result, not its source; authority derives the minimum source set, prefers a usable transient dial, uses a sufficient token only without a usable dial, and automatically combines dial plus token for a result requiring both. |
| SMI-AC-005 | All speed results enforce minimum 0 and the ship's maximum-speed value, including unavailable speed-chart columns. |
| SMI-AC-006 | Candidate speed changes are transient, leave canonical speed/resources unchanged, and re-derive the tool; accepted commitment atomically applies the resulting canonical speed. |
| SMI-AC-007 | A rejected, unrelated, duplicate, or stale-identity commitment changes none of canonical speed, resources, committed result, active execution, or opportunity state. |
| SMI-AC-008 | Before commitment, candidate speed/yaw, course geometry, and preview are reversible and non-authoritative; accepted commitment atomically derives and consumes sources, applies speed/result, and creates the matching active execution while leaving Maneuver `OPEN`. |
| SMI-AC-009 | Positive-speed execution uses the committed course and canonical speed; speed-zero execution preserves transform but still executes a Maneuver. |
| SMI-AC-010 | Ship overlap retries at successively lower temporary speeds without changing canonical speed, then applies required overlap damage. |
| SMI-AC-011 | Speed-zero execution evaluates applicable ship, squadron, and obstacle overlaps. |
| SMI-AC-012 | The non-moving player completes every required squadron displacement under RRG placement constraints; accepted positions remain on their `SquadronInstance`s and authority-side control returns to the active Maneuver boundary. |
| SMI-AC-013 | Every applicable obstacle rule is invoked; rule-provided optional results remain optional, and the moving ship's controller chooses among multiple RRG-permitted orders unless an RRG rule or Integrated Rule Capability Package assigns another player or order. |
| SMI-AC-014 | For a surviving normal activation, Maneuver remains `OPEN` through all mandatory consequences; after purpose-specific authority-side return and re-evaluation, completion consumes it and retires the active execution exactly once. |
| SMI-AC-015 | Passive peers project ordered viewer-authorized canonical state and originate neither player decisions nor automatic authoritative follow-up commands; identical authority-private representation is not required. |
| SMI-AC-016 | Save/load/reconnect rebuild transient pre-commit geometry from canonical state or resume committed mandatory consequences without duplication. |
| SMI-AC-017 | A rejected Maneuver preserves authoritative state and re-exposes the same legal decision unless an exceptional terminal transition ended it. |
| SMI-AC-018 | An active ship destroyed by a Maneuver consequence uses the accepted exceptional terminal path and receives no fabricated normal completion. |
| SMI-AC-019 | Ship-overlap placement/reduction and damage precede the RRG executed-maneuver event; post-execution consequences may keep Armada Maneuver `OPEN` after that event until normal completion. |
| SMI-AC-020 | Play-area destruction is evaluated from the actual final position after ship-overlap resolution, using RRG out-of-bounds geometry; a plotted but superseded out-of-bounds position is insufficient. |
| SMI-AC-021 | After each consequence, authority re-evaluates survival and applicability; destruction does not fabricate later ship-dependent consequences or a return to a removed Maneuver boundary. |
| SMI-AC-022 | Where neither RRG nor an Integrated Rule Capability Package fixes squadron-displacement versus obstacle order, mandatory displacement resolves first. |
| SMI-AC-023 | Dial effect permits speed ±1 and optional +1 yaw on one joint; token effect permits speed ±1 with no yaw; combined effects permit total speed ±2 and optional dial yaw. Armada exposes no explicit source choice or no-effect resolution. |

## Appendix A — Evidence classification and traceability

| Requirement area | A. RRG game-rule authority | B. Accepted Armada authority | C. Verified implementation/test evidence | D. New Owner requirement |
| --- | --- | --- | --- | --- |
| Entry and mandatory opportunity | Ship Activation; Ship Movement | SAI-060; ADR-006 | Active ship and Maneuver disposition drive current entry/reconstruction | Speed zero must remain a live tool interaction |
| Navigate dial | Commands; LTP Navigate | MVP CM-010–CM-013; SAI-061 | `ShipActivationState` and tests provide dial budget 1 and yaw bonus | Player selects result; authority automatically prefers usable dial |
| Navigate token | Commands; LTP Navigate | MVP CM-003, CM-010–CM-013; SAI-061 | Token budget 1 and no token yaw are tested | Token auto-used only when no usable dial is available and it is sufficient |
| Combined Navigate | Commands (combined-command bullet and example) | MVP CM-003 and maneuver-tool NAV-004 | Production sums budgets; tests verify two accepted increments | Preserve combined total speed change 2 and auto-consume both when required |
| Speed bounds | Speed; Speed Chart | MVP MV-020–MV-022 | `ShipInstance`, `SetSpeedCommand`, activation state, and tests enforce 0..max | `−` stays visible and inert at 0 |
| Candidate and committed speed | Speed | ADR-006 Sections 3.3 and 4; ADR-010 | Current separate speed mutation and BUG-043 convergence tests are implementation evidence that predate the accepted atomic commitment boundary | Collapse and expand transient tool across candidate 0↔positive |
| Tool/yaw/preview | Maneuver Tool; Ship Movement; Yaw | SAI-061; ADR-010 | Tool state derives segments, chart limits, alignment, and ghost | Top/end segment only at baseline speed 0; straight alignment; digital source derivation |
| Commitment/execution | Ship Movement; Overlapping | SAI-060–SAI-062; amended ADR-006 | `ExecuteManeuverCommand` persists transform, but current early consumption is drift | Distinguish the RRG executed event from later Armada consumption; speed-zero uses authoritative progression |
| Ship overlap | Overlapping | SAI-063 | Resolver/tests implement temporary reduction and damage path | Applies at speed zero |
| Squadron displacement | Overlapping | SAI-064; SAI-001; amended ADR-006 | Current Start/Commit Displacement commands, controller flow, and placement tests are verified production behavior, not accepted lifecycle ownership | Maneuver remains open until displacement completes |
| Obstacle overlap | Obstacles; Overlapping | SAI-065; CON-003 for integrated rule packages | No complete baseline Maneuver obstacle path was found | Applies at speed zero; effect detail remains rule-owned |
| Play-area destruction | Destroyed Ships and Squadrons; Overlapping; Play Area; Movement FAQ | ADR-006 exceptional termination | No complete evidence of the required post-overlap final-position boundary was found | Evaluate actual final position after ship-overlap resolution |
| Completion/recovery | Overlapping; Ship Activation | SAI-060, SAI-080; ADR-006; ADR-010 | Current paths reconstruct some surfaces but contain drift below | Consume only after every mandatory consequence |

## Appendix B — Current implementation drift (non-normative)

The following observed behavior is not intended architecture and SHALL NOT be
copied into requirements or future work merely because it exists:

1. The current speed-zero controller shortcut suppresses the maneuver tool,
   bypasses `ExecuteManeuverCommand`, advances through scene-local state, and
   does not evaluate all RRG overlaps. ADR-006 already identifies that route as
   a migration risk.
2. The current normal path consumes the ADR-006 Maneuver opportunity through
   `ExecuteManeuverCommand` before required squadron displacement completes.
   SAI-060, SAI-064, and the Owner decision require the opportunity to remain
   `OPEN` through all mandatory consequences.
3. Current Maneuver execution does not provide a complete baseline obstacle-
   overlap integration path.
4. Current separate pre-commit speed mutation and resource handling cross the
   authoritative boundary before the atomic Maneuver commitment required by
   amended ADR-006.
5. Existing implementation naming and callbacks around local
   `ShipActivationState`, modal steps, preview warnings, and displacement
   return are implementation evidence only. They do not authorize a generic
   activation FSM or continuation framework.

The following accepted workbooks remain implementation specifications that
require later reconciliation; they are not requirements authority for this
document:

- TWI-003 predates ADR-006's accepted committed-but-`OPEN` active Maneuver
  execution boundary.
- The BUG-043 workbook predates the Owner decision, now accepted in ADR-006,
  that pre-commit Navigate speed/yaw exploration is transient and does not
  change canonical speed or consume resources.

Amended ADR-006 resolves the normative Maneuver ownership, commitment,
consequence-return, ordering, recovery, and completion boundary. No additional
Maneuver contract or ADR is required before this requirements document can be
audited or before the existing workbooks are reconciled under repository
governance.
