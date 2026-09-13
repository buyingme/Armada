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
Refined from committed Owner decisions: 2026-09-11
Audit corrections and additional Owner decisions: 2026-09-12
Owner Decision 28 timing correction: 2026-09-13

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
- Accepted command, Network, replay, save/load, and responsibility-specific
  gameplay-rule authorities retain their existing ownership. CON-003 Rule
  Capability Packages record integration traceability and completeness; they
  do not replace those gameplay authorities.
- [Ship Maneuver Owner Decision Record](ship_maneuver_owner_decisions.md)
  supplies the committed Owner interpretations and intentional digital
  deviations incorporated by the 2026-09-11 refinement.
- [Ship Maneuver Prerequisite Impact Analysis](../../architecture/discovery/ship-maneuver-prerequisite-impact-analysis.md)
  and [Ship Maneuver Consequence-Timing Discovery](../../architecture/discovery/ship-maneuver-consequence-timing-discovery.md)
  remain supporting evidence, not normative authority.

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
   │  └─ derive deterministic legal tool side/alignment
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
BUG-046, and purpose-specific ownership of obstacle or card rules. This
specification defines only the Maneuver interaction and return boundaries
required to invoke applicable obstacle and Maneuver-triggered damage-card Rule
Capabilities. Their detailed behavior remains with the accepted
responsibility-specific owners identified and evidenced by their CON-003
packages.

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

The tool and preview SHALL update immediately as legal candidate speed or yaw
changes. The legal tool side is re-derived automatically under SMI-021. An
uncommitted course may be adjusted or abandoned in
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
  Armada SHALL preserve the established deterministic automatic tool-side
  derivation. If the initially derived side would cause that overlap, the
  other legal side SHALL be used. If both sides are legal, the deterministic
  production-compatible derivation selects the side; the controller receives
  no additional left/right choice.
- If physical board congestion would prevent placement of the tool, the
  interaction SHALL still permit determination of the rules-equivalent final
  position; obstruction by intermediate ships, squadrons, or obstacles does
  not itself block the Maneuver.
- At speed zero, the top/end segment is aligned relative to the ship exactly as
  it would be for a completely straight maneuver tool.

Automatic tool-side derivation is an intentional Owner-approved digital
deviation from the RRG choice available when either tabletop placement is
legal. Speed-zero support extends that deterministic behavior and does not
introduce player side selection.

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
availability and budget, the deterministically derived legal tool side, and any
applicable integrated rule modifiers.

Acceptance atomically derives and consumes the minimum required Navigate
source or sources under SMI-030, applies the resulting canonical speed,
establishes the committed geometry/result facts, and creates one matching
active Maneuver execution record under ADR-006, or changes none of them.
Commitment does not apply the committed final board transform: canonical ship
position and orientation remain unchanged while mandatory post-commitment/
pre-movement obligations resolve. Once accepted, the selected course must be
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

The committed final board transform is applied atomically only after all
applicable post-commitment/pre-movement obligations, including Thruster
Fissure, have completed and the ship remains eligible to continue. If the ship
is destroyed before movement, that transform is not applied and the accepted
destruction and Maneuver-cleanup path terminates the execution.

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

The collision-resolution search first establishes the authoritative final ship
position and the overlap facts produced by the committed Maneuver. Intermediate
plotted positions, reduced-speed attempts, and other search positions are not
independent gameplay events and SHALL NOT trigger consequences.

The RRG expressly provides only part of the needed ordering: ship-overlap
effects, including collision damage, complete before the ship has executed its
Maneuver; obstacle consequences apply after executing; the FAQ places Damaged
Controls during Move Ship; and displaced squadrons are placed after the ship
finishes its Maneuver. Those statements do not directly dictate Armada's full
cross-category consequence hierarchy.

SMI-064 therefore applies the committed Owner hierarchy as an intentional
Armada interpretation and, where necessary, digital deviation. In particular,
required Squadron displacement occurs first, and obstacle-only Damaged Controls
then resolves before the obstacle's own consequence. Neither that relative
allocation nor the complete SMI-064 sequence SHALL be presented as directly
dictated by the RRG. Purpose-specific implementations may recognize their RRG
timing conditions at the Owner-assigned interaction boundary without
prematurely completing the Armada opportunity.

The matching Maneuver may remain `OPEN` with its active execution record after
the RRG event while mandatory post-execution consequences and nested decisions
resolve. Only SMI-070 defines the later normal `CONSUMED` boundary.

## 9. Overlap and collision resolution

### SMI-060 — Authoritative overlap determination

Overlap is determined from the committed Maneuver and the authoritative final
ship position produced by collision resolution, not from the transient ghost or
an intermediate collision-search attempt. A component crossed only during
movement is not overlapped.

Armada intentionally uses the existing simplified rectangular `ShipBase` as
the authoritative footprint for ship-overlap/collision and for the moved ship
in Squadron-displacement validation. This is an Owner-approved digital
approximation: shield-dial assemblies and plastic framing that count under the
tabletop overlap rule are not added to this digital footprint. A purpose-
specific rule such as play-area destruction may use its separately applicable
footprint.

Obstacle overlap SHALL use explicit canonical gameplay contours that accurately
represent each of the six physical core obstacle tokens. Those contours are
derived and verified once from sufficiently faithful official assets or another
approved authoritative source. Runtime sprite bounds, bounding rectangles,
`SPRITE_BOUNDS_FACTOR`, alpha masks, and presentation scaling SHALL NOT provide
authoritative obstacle geometry. Squadron bases use the one fixed project
diameter; heterogeneous Squadron base geometry is out of scope.

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

After final geometry and required Squadron displacement are established, the
ordinary ship-collision consequence deals one facedown damage card to the
moving ship and one facedown damage card to the closest ship it overlapped,
subject to applicable integrated rule modifications. If more than one ship was
overlapped, the RRG closest-ship determination governs. Only after that ordinary
consequence completes may applicable effects triggered by the ship collision
resolve. Ship-overlap execution is not complete until this damage and any
immediate mandatory consequences, including destruction, resolve
authoritatively.

The RRG requirement that ship-overlap effects, including collision damage,
complete before the ship is considered to have executed its Maneuver remains
applicable. SMI-064 additionally places Squadron displacement before those
collision consequences and collision-triggered effects after them as an Owner
interpretation; those added relative placements are not attributed to the RRG.

An active ship destroyed by an overlap consequence follows the accepted
exceptional terminal Ship Activation path. The system SHALL NOT fabricate
Maneuver consumption or End Activation merely to satisfy normal progression.

### SMI-062 — Squadron overlap and displacement

After the ship's legal final position is established, any squadron whose base
it overlaps is removed from the way and the ship finishes its physical
placement. Mandatory displacement is then a nested authoritative interaction.
Each affected `SquadronInstance` remains the owner of its canonical squadron
position.

The player who did not move the ship controls the submitted identity selection
and placement, regardless of squadron ownership. That player may explore
placement order transiently and SHALL:

- place as many as possible touching the ship that moved;
- place a squadron that cannot touch the ship touching another squadron that
  is touching the ship;
- keep every squadron inside the play area; and
- avoid overlap with any ship or squadron.

All Armada Squadron bases have the same fixed size. Authority SHALL validate
the proposed final displacement as one complete batch containing the identity
and position of every placed affected squadron and the identity of every
excluded affected squadron.

Authority SHALL first determine the maximum number of affected squadrons for
which any complete legal placement exists. The displacement-controlling player
chooses which squadron identities form that maximum-cardinality placeable
subset when more than one equally maximal identity subset is legal, and chooses
their positions. The accepted batch SHALL place exactly that maximum number.

Within a maximum-cardinality placeable subset, authority SHALL also determine
the maximum number that can legally be placed directly touching the moved ship
while every remaining placed squadron satisfies the secondary placement rule.
A submitted batch is invalid if it places fewer total squadrons, or fewer
direct-touching squadrons, than those authoritative maxima. Tentative identity
selection, order, or placement cannot establish inability to touch or place a
squadron.

Every affected Squadron identity excluded from the chosen maximum legally
placeable subset is destroyed when the complete batch is accepted. Authority
validates and applies that consequence; the displacement-controlling player
selects only among equally maximal legal identity subsets. This is an explicit
Armada Owner interpretation resolving a gap in the repository-held RRG/FAQ. It
is not an RRG-stated fallback, an optional reduction in the number placed, or
permission to manufacture additional destruction through inefficient identity
selection, order, or placement.

A squadron placed on an obstacle because of this displacement does not resolve
that obstacle's overlap effect.

Each tentative drag, placement order, or placement ghost is transient.
Mandatory displacement and its confirmed complete batch SHALL resolve through
one authoritative semantic boundary. Invalid or suboptimal placement is
rejected without ending the nested interaction. At minimum, the interaction
SHALL report the authoritative deficiency, including the required and submitted
placed and direct-touch counts where applicable. It MAY provide deterministic
guidance or a legal proposal, but SHALL NOT use an arbitrary retry counter or
random fallback. Player-controlled identity selection and placement remain the
normal interaction.

Every identity in the maximum legally placeable subset must be legally placed,
every excluded identity must be validated for the required destruction, and
the complete authoritative displacement result must be accepted before
authority-side control returns to the still-`OPEN`, matching active Maneuver
execution for re-evaluation.
`InteractionFlow`, modal state, controllers, and callbacks may present or
route the interaction but are not gameplay or completion authority. This
specification introduces no concrete command design or generic continuation
mechanism.

Required displacement completes before later ship-collision damage. If a later
collision consequence destroys the moving ship, accepted Squadron positions
and any authority-determined destruction of genuinely unplaceable squadrons are
not undone.

### SMI-063 — Obstacle overlap

A ship overlaps an obstacle when part of its base is on top of the obstacle at
its final position. Moving through an obstacle has no effect by itself. If the
ship overlaps more than one obstacle, every applicable obstacle rule is
invoked and its effects may resolve in any order as provided by the RRG. Where
no RRG rule or other accepted gameplay-rule authority assigns that ordering
choice to another player, Armada's Owner interpretation is that the controller
of the moving ship chooses the resolution order. This controller assignment is
an explicit Armada interpretation of an RRG ambiguity, not an explicit RRG
rule. An Integrated Rule Capability Package may evidence such an accepted rule
and its responsibility-specific owner, but the package does not itself own or
create the gameplay ordering.

Obstacle detection and invocation are part of baseline Maneuver execution,
including at speed zero. The detailed effect of each obstacle, any choice it
creates, and any modification by an objective, card, or special rule remain
with the applicable responsibility-specific gameplay authorities. The Rule
Capability Package records those owners and the evidence that the behavior is
complete across its applicable surfaces.
Every live nested choice, including the moving ship controller's multiple-
obstacle order choice, must resolve authoritatively and satisfy SAI-001 and
ADR-010. While the activation boundary survives, it returns through its
purpose-specific consequence owner before Maneuver completes; this requirement
creates no generic continuation owner, queue, stack, or FSM.

Invoking every applicable obstacle rule is mandatory and cannot be omitted
merely because its detailed rule logic is owned elsewhere. An invoked rule may
itself provide an optional result; that option remains governed by the rule and
its responsibility-specific implementation authority and is traced by its Rule
Capability Package.

Before an accepted release/cutover depends on their effects, the core Maneuver-
overlap slices for asteroid fields, debris fields, and the station must each
have a CON-003 Rule Capability Package at `Integrated` status, including the
explicit Owner approval required by CON-003. Only after the whole workbook is
candidate-code-complete under Owner Decision 27 may the complete paths be
activated together in the unreleased 7/10/7 Integration Candidate so required
TEST-003/runtime/Network evidence can be gathered. The candidate is not a
CON-003 status and no incomplete path may be
made reachable for incremental testing. `Integrated` records complete
traceability, evidence, tests, metadata alignment, and applicable-surface
coverage; it does not make the package a gameplay authority owner. Maneuver
owns only detection of the committed overlap, invocation of the
responsibility-specific implementation identified by that package, and return
to the still-live Maneuver boundary. It does not own the obstacle effect, its
choices, damage/discard semantics, recovery, or a generic obstacle-resolution
command. Unrelated obstacle capabilities such as attack obstruction are not
prerequisites unless required by one of those slices.

### SMI-064 — Multiple overlap categories

After authoritative final geometry is established, baseline Maneuver
consequences resolve through their purpose-specific owners in this hierarchy:

1. required Squadron displacement;
2. ordinary ship-collision consequences;
3. applicable effects triggered by ship collision;
4. any applicable obstacle-only Damaged Controls boundary not already resolved
   for the same faceup card instance during this Maneuver;
5. applicable obstacle-overlap consequences; and
6. remaining applicable post-execution Maneuver effects.

This complete hierarchy is an Owner interpretation and, where necessary, an
intentional Armada digital deviation; it is not directly dictated by the RRG.
It does not move detailed obstacle or damage-card rule ownership into Maneuver.
Effects within a category continue to obey their individual RRG-derived
behavior, accepted responsibility-specific gameplay authorities, and
applicable player-ordering rules except for the explicit cross-category Owner
allocations stated here.

The obstacle-only Damaged Controls allocation in item 4 is a settled Owner
decision. The FAQ supplies the card's during-Move-Ship timing but does not
directly order it against Squadron displacement and the obstacle's own
post-execution consequence. Armada intentionally resolves required Squadron
displacement first, then resolves each applicable faceup Damaged Controls
instance once, and only then resolves the obstacle consequence. This allocation
SHALL be identified as an Armada interpretation/deviation rather than an
RRG-derived order. A Maneuver that overlaps both a ship and an obstacle resolves
each faceup Damaged Controls instance only once, in item 3, and does not repeat
it in item 4.

Multiple applicable obstacle effects may resolve in any order as provided by
the RRG. Where no RRG rule or other accepted gameplay-rule authority assigns
that choice elsewhere, the moving ship's controller chooses their order under
the Owner interpretation in SMI-063. Applicable obstacle consequences converge
before remaining post-execution effects such as Ruptured Engine.

For a surviving normal activation, the Maneuver opportunity remains `OPEN`
throughout the complete mandatory consequence sequence.

The final geometry and completed Squadron displacement are not rolled back if a
later consequence destroys the moving ship.

### SMI-065 — Play-area destruction after ship-overlap resolution

Play-area destruction SHALL be evaluated against the moving ship's actual
final position after every applicable ship-overlap placement/reduction has
determined that position. A merely plotted out-of-bounds destination does not
destroy the ship if ship-overlap resolution leaves its actual final position
entirely inside the play area.

At the actual final position, the ship is destroyed if any portion of its base
is outside the play area. For this RRG determination, ignore the ship's shield
dials and the plastic portions of the base that frame those dials. This
purpose-specific play-area footprint SHALL encode those RRG exclusions and
SHALL NOT expand the simplified rectangular `ShipBase` with excluded tabletop
protrusions.

Destruction resolves through ADR-006's accepted exceptional terminal semantics:
the authority clears the activation and active Maneuver boundary without
fabricating normal completion, return, or End Activation.

### SMI-066 — Continuing applicability and survival

After every authoritative Maneuver consequence, authority SHALL re-evaluate
survival and the remaining applicable obligations. Each later consequence
resolves only while its trigger, subject, and required owning boundary remain
applicable.

If an earlier consequence destroys the moving ship, Armada SHALL NOT fabricate
later ship-dependent consequences, a purpose-specific return to a nonexistent
Maneuver boundary, normal Maneuver `CONSUMED`, or End Activation. Independent
consequences that remain applicable despite destruction are governed by their
own accepted gameplay-rule and responsibility-specific implementation
authorities, as traced by an Integrated Rule Capability Package where required.

Completed final geometry and Squadron displacement survive later destruction.
An independently applicable consequence belonging to another surviving game
object retains its own purpose-specific authority.

### SMI-067 — Maneuver-triggered damage-card capability boundaries

Before accepted release/cutover depends on them, the Thruster Fissure, Damaged
Controls, and Ruptured Engine prerequisite slices must each have a CON-003 Rule
Capability Package at `Integrated` status, including the explicit Owner
approval required by CON-003. Together with the three obstacle slices in
SMI-063, all six prerequisite slices SHALL satisfy that release gate. Their
complete paths may participate earlier in the same unreleased 7/10/7
Integration Candidate, but only after the whole workbook is candidate-code-
complete under Owner Decision 27, solely to gather the evidence required for
Tested readiness and Owner review; this does not advance package status.
`Integrated` is a traceability/completeness status and does not transfer
gameplay authority to the package. Maneuver SHALL expose only the authoritative
interaction and return boundaries needed by the responsibility-specific
implementations traced in those packages:

- a committed Navigate speed change exposes Thruster Fissure at its RRG
  `when`-speed-changes timing during Determine Course and before Move Ship;
- authoritative final overlap facts expose each applicable faceup Damaged
  Controls instance once for that Maneuver at item 3 or item 4 of SMI-064,
  using the Owner-assigned cross-category allocation; and
- Ruptured Engine retains its RRG `after you execute a maneuver` eligibility,
  but Armada invokes it only after obstacle consequences converge under the
  Owner-established cross-category hierarchy.

Each individual faceup damage-card instance is independently applicable and
must not be collapsed by shared name, rule ID, or `effect_id`. Facedown copies
do not provide an active effect. Same-player effects sharing a timing retain the
RRG player-order choice; different-player same-timing effects retain the RRG
first-player ordering. Detailed eligibility, damage semantics, choices,
serialization, replay, Network, recovery, and verification remain with each
accepted responsibility-specific owner and must be evidenced by the card's
Rule Capability Package. This requirement neither integrates unrelated damage
cards nor makes Maneuver or a Rule Capability Package a generic rule-effect
owner.

## 10. Completion and return to Ship Activation

### SMI-070 — Maneuver completion

For a surviving normal activation, the Maneuver completes only when:

1. one legal course, including a legal speed-zero course, has been committed;
2. the authoritative final ship transform or no-movement result is accepted;
3. all required Squadron displacement, including any genuine-unplaceability
   consequence, is complete;
4. all applicable ordinary ship-collision consequences and collision-triggered
   effects are complete;
5. all applicable damage-card interaction boundaries assigned before obstacle
   resolution by SMI-064 and SMI-067 are complete;
6. all applicable obstacle consequences and nested choices are complete;
7. all remaining applicable post-execution effects are complete; and
8. no other integrated mandatory Execute Maneuver consequence remains live.

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
and resumes from its authoritative committed-result/transform-application
state: pre-movement recovery preserves the unchanged canonical board transform
and resumes applicable obligations, while post-movement recovery uses the
already-applied canonical transform. Neither path offers a different course or
duplicates completed effects. `CONSUMED` reconstructs with no active Maneuver
execution and no live Maneuver decision.

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
- ordinary course preview, deterministic automatic tool-side alignment,
  commitment, and execution;
- authoritative final geometry, ship overlap, complete-batch Squadron
  displacement, obstacle detection/invocation, and the consequence hierarchy in
  SMI-064; and
- authoritative completion and decision-equivalent recovery.

### SMI-091 — Rule Capability-traced behavior

Cards, objectives, obstacle-specific effects, or other special rules may modify
the baseline only through their accepted responsibility-specific gameplay and
implementation authorities, with integration evidenced through the applicable
Rule Capability Package. The prerequisite Maneuver-overlap slices for asteroid
fields, debris fields, and station, plus Thruster Fissure, Damaged Controls,
and Ruptured Engine, retain those purpose-specific owners even though the
Maneuver boundary must invoke and await them. Each of those six slices must
reach CON-003 `Integrated` status with explicit Owner approval before accepted
release/cutover depends on it. Before that approval, complete paths may be
activated together only after the whole workbook is candidate-code-complete
under Owner Decision 27, in the unreleased 7/10/7 Integration Candidate to
gather TEST-003/runtime/Network evidence. The candidate is not a
CON-003 lifecycle status, does not imply Tested or Integrated, and may not make
an incomplete path reachable.

CAP-OBS-003 owns ordinary Station behavior only. If an active objective such as
Contested Outpost modifies or suppresses Station behavior and its purpose-
specific objective capability is not `Integrated`, the unsupported
configuration fails closed rather than applying ordinary Station behavior.
BUG-043 does not absorb objective integration or invent a generic Station-
modifier framework.

In particular, baseline speed zero exposes no ordinary yaw controls. A
speed-zero yaw interaction exists only when an **Integrated** rule or card
effect explicitly permits clicks of yaw at speed zero. Its legal clicks,
declaration, presentation, execution, collision result, persistence, Network
behavior, and tests remain with the applicable responsibility-specific owners
and are traced by that effect's Rule Capability Package while preserving the
canonical and completion boundaries in this document. Codex may not mark such
a package `Integrated`.

Rule behavior evidenced by an Integrated package may extend speed-zero
execution, but it SHALL NOT weaken ADR-006 commitment atomicity,
active-execution ownership, decision-equivalent recovery, nested-consequence
return, or exact-once completion invariants.

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
| SMI-AC-008 | Before commitment, candidate speed/yaw, course geometry, and preview are reversible and non-authoritative; accepted commitment atomically derives and consumes sources, applies canonical speed, establishes committed geometry/result facts and the matching active execution, leaves Maneuver `OPEN`, and leaves canonical ship position/orientation unchanged. |
| SMI-AC-009 | After all post-commitment/pre-movement obligations complete, positive-speed execution atomically applies the committed final board transform using the committed course and canonical speed; speed-zero execution preserves transform but still crosses the same authoritative execution boundary; intermediate collision-search attempts do not trigger consequences. Destruction before movement prevents final-transform application and uses exceptional cleanup. |
| SMI-AC-010 | Ship overlap searches successively lower temporary speeds without changing canonical speed; after final geometry and Squadron displacement, ordinary collision damage precedes collision-triggered effects. |
| SMI-AC-011 | Speed-zero execution evaluates applicable ship, squadron, and obstacle overlaps. |
| SMI-AC-012 | The non-moving player proposes one complete Squadron-displacement batch containing placed and excluded identities and all placed positions. Authority validates the maximum legally placeable subset, permits identity choice only among equally maximal legal subsets, validates the maximum direct-touch count and secondary placement, and destroys exactly the identities genuinely excluded from the chosen maximal subset. Suboptimal selection, order, or placement cannot cause additional destruction and receives deficiency guidance. |
| SMI-AC-013 | The asteroid, debris, and ordinary-station Maneuver slices may become reachable together only after the whole workbook reaches Owner Decision 27's `candidate-code-complete` condition in the unreleased 7/10/7 Integration Candidate, then satisfy TEST-003 `implementation-complete`/Tested readiness and reach CON-003 `Integrated` with explicit Owner approval before accepted release/cutover. Maneuver invokes the responsibility-specific implementation without transferring obstacle-rule ownership; an unsupported active Station-modifying objective configuration fails closed, and the moving ship's controller chooses among multiple RRG-permitted orders unless another accepted gameplay-rule authority assigns the choice. |
| SMI-AC-014 | For a surviving normal activation, Maneuver remains `OPEN` through all mandatory consequences; after purpose-specific authority-side return and re-evaluation, completion consumes it and retires the active execution exactly once. |
| SMI-AC-015 | Passive peers project ordered viewer-authorized canonical state and originate neither player decisions nor automatic authoritative follow-up commands; identical authority-private representation is not required. |
| SMI-AC-016 | Save/load/reconnect rebuild transient pre-commit geometry from canonical state or resume the committed Maneuver without duplication, preserving whether its canonical final transform remains unapplied or has already been applied. |
| SMI-AC-017 | A rejected Maneuver preserves authoritative state and re-exposes the same legal decision unless an exceptional terminal transition ended it. |
| SMI-AC-018 | An active ship destroyed by a Maneuver consequence uses the accepted exceptional terminal path and receives no fabricated normal completion. |
| SMI-AC-019 | The RRG-derived timing statements and the Owner-assigned cross-category hierarchy remain explicitly distinguished: ship-collision effects satisfy the RRG pre-execution requirement, while displacement-first and obstacle-only Damaged Controls after displacement but before obstacle consequences are Armada interpretations/deviations. Mandatory consequences may keep Armada Maneuver `OPEN` beyond any RRG executed-maneuver timing event. |
| SMI-AC-020 | Play-area destruction is evaluated from the actual final position after ship-overlap resolution, using RRG out-of-bounds geometry; a plotted but superseded out-of-bounds position is insufficient. |
| SMI-AC-021 | After each consequence, authority re-evaluates survival and applicability; destruction does not fabricate later ship-dependent consequences or a return to a removed Maneuver boundary, but completed final geometry and Squadron displacement remain accepted. |
| SMI-AC-022 | Under the Owner-assigned SMI-064 hierarchy, consequences resolve as Squadron displacement; ordinary collision; collision-triggered effects; applicable obstacle-only Damaged Controls not already resolved for that card instance; obstacles; remaining post-execution effects. This complete order is an Armada interpretation/deviation rather than an RRG-derived sequence, and purpose-specific rules retain responsibility-specific ownership within each boundary. |
| SMI-AC-023 | Dial effect permits speed ±1 and optional +1 yaw on one joint; token effect permits speed ±1 with no yaw; combined effects permit total speed ±2 and optional dial yaw. Armada exposes no explicit source choice or no-effect resolution. |
| SMI-AC-024 | Tool-side alignment is derived automatically and deterministically; if both sides are legal, the player receives no side-selection decision. |
| SMI-AC-025 | The ship-overlap footprint is the simplified rectangular `ShipBase`; core obstacle overlap uses verified explicit canonical contours and never runtime sprite-derived geometry. |
| SMI-AC-026 | Thruster Fissure is exposed after committed Determine Course speed-change facts exist but before the committed final board transform is applied; each Damaged Controls faceup instance is exposed once at its Owner-assigned SMI-064 boundary, and Ruptured Engine only after obstacle convergence. Their complete paths may participate in the unreleased 7/10/7 Integration Candidate for evidence only after the whole workbook reaches Owner Decision 27's `candidate-code-complete` condition, then satisfy TEST-003 `implementation-complete`/Tested readiness and reach CON-003 `Integrated` with explicit Owner approval before accepted release/cutover; detailed rule ownership remains responsibility-specific. |
| SMI-AC-027 | Multiple applicable faceup instances are not collapsed by shared card identity; a player chooses the order of that player's same-timing effects, and when both players have effects at the same timing the first player resolves all of theirs first. Facedown copies provide no active effect. |

## Appendix A — Evidence classification and traceability

| Requirement area | A. RRG game-rule authority | B. Accepted Armada authority | C. Verified implementation/test evidence | D. New Owner requirement |
| --- | --- | --- | --- | --- |
| Entry and mandatory opportunity | Ship Activation; Ship Movement | SAI-060; ADR-006 | Active ship and Maneuver disposition drive current entry/reconstruction | Speed zero must remain a live tool interaction |
| Navigate dial | Commands; LTP Navigate | MVP CM-010–CM-013; SAI-061 | `ShipActivationState` and tests provide dial budget 1 and yaw bonus | Player selects result; authority automatically prefers usable dial |
| Navigate token | Commands; LTP Navigate | MVP CM-003, CM-010–CM-013; SAI-061 | Token budget 1 and no token yaw are tested | Token auto-used only when no usable dial is available and it is sufficient |
| Combined Navigate | Commands (combined-command bullet and example) | MVP CM-003 and maneuver-tool NAV-004 | Production sums budgets; tests verify two accepted increments | Preserve combined total speed change 2 and auto-consume both when required |
| Speed bounds | Speed; Speed Chart | MVP MV-020–MV-022 | `ShipInstance`, `SetSpeedCommand`, activation state, and tests enforce 0..max | `−` stays visible and inert at 0 |
| Candidate and committed speed | Speed | ADR-006 Sections 3.3 and 4; ADR-010 | Current separate speed mutation and BUG-043 convergence tests are implementation evidence that predate the accepted atomic commitment boundary | Collapse and expand transient tool across candidate 0↔positive |
| Tool/yaw/preview | Maneuver Tool; Ship Movement; Yaw | SAI-061; ADR-010 | Tool state derives segments, chart limits, alignment, and ghost | Preserve deterministic automatic tool-side derivation with no player side choice; extend it to the top/end-segment-only speed-zero interaction |
| Commitment/execution | Ship Movement; Overlapping | SAI-060–SAI-062; amended ADR-006; Owner Decision Record Section 28 | `ExecuteManeuverCommand` persists transform, but current commitment-time transform application and early consumption are drift | Commitment establishes speed, committed result, and active execution while preserving the pre-Maneuver board transform; apply the committed transform atomically only after pre-movement obligations; retain the accepted later consequence hierarchy and speed-zero authoritative progression |
| Ship overlap | Overlapping | SAI-063 | Resolver/tests implement temporary reduction and damage path | Use the simplified rectangular `ShipBase`; after final geometry, displacement precedes ordinary collision damage and collision-triggered effects; applies at speed zero |
| Squadron displacement | Overlapping | SAI-064; SAI-001; amended ADR-006 | Current Start/Commit Displacement commands, controller flow, and placement tests are verified production behavior, not accepted lifecycle ownership | Validate one complete batch against the maximum legally placeable subset and maximum direct-touch count; the non-moving player chooses identities among equally maximal subsets; only genuinely excluded identities are destroyed |
| Obstacle overlap | Obstacles; Overlapping | SAI-065; ADR-003 responsibility-specific authority; CON-003 integration evidence; Owner Decision Record Sections 25--26 | Current approximation and effect path are incomplete | Use verified explicit canonical contours; activate only complete paths together in the unreleased candidate for evidence; require Owner-approved `Integrated` before release; fail closed for unsupported Station-modifying objectives without transferring rule ownership |
| Maneuver-triggered damage cards | Card text/data supplies Thruster Fissure's `when`, the FAQ supplies Damaged Controls' during-Move-Ship timing, and card text supplies Ruptured Engine's `after` timing | ADR-003 responsibility-specific authority; CON-003 integration evidence; amended ADR-006 consequence boundary; Owner Decision Record Section 26 | Current resolver has partial Thruster Fissure, Damaged Controls, and Ruptured Engine hooks | Limit prerequisites to the three purpose-specific slices, preserve cumulative faceup copies and ordering, activate only complete candidate paths for evidence, and require Owner-approved `Integrated` before accepted release |
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
6. Current obstacle overlap uses presentation-derived rectangular sprite
   approximations rather than the required verified canonical contours.
7. Current Squadron displacement validates placements incrementally and does
   not prove one complete batch's global maximum direct-touch count or genuine
   unplaceability.
8. Current Maneuver damage-card hooks are partial: their placement in one
   post-execution resolver does not express the required timing hierarchy, and
   shared effect identifiers can collapse independently applicable faceup card
   instances.

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
