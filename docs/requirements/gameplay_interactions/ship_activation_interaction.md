# Ship Activation — Gameplay-Interaction Requirements

> **Status:** Accepted
> **Scope:** Ship Phase / Ship Activation player-facing gameplay interactions.
> **Architecture context:** AT-002 / BC-003.
> **Authority posture:** This is a TO-BE requirements specification. It is
> subordinate to accepted ADRs and Contracts; it is not an ADR, Contract, UI
> design, or implementation plan.

Accepted by: Project Owner
Accepted date: 2026-08-21

## 1. Purpose and authority

This is the first, high-level requirements layer for Ship Activation. It
describes player-facing gameplay decisions without prescribing controls,
callbacks, scene behavior, or a generic activation state machine.

Applicable authority remains:

- [ADR-010](../../architecture/adr/ADR-010-gameplay-interaction-decision-equivalent-recovery.md)
  for decision-equivalent recovery;
- [ADR-006](../../architecture/adr/ADR-006-canonical-ship-activation-boundary-ownership.md)
  for the canonical activation boundary and its purpose-specific
  opportunities;
- [ADR-001](../../architecture/adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md),
  [CON-006](../../architecture/contracts/CON-006-attack-declaration-lifecycle-contract.md),
  and [CON-007](../../architecture/contracts/CON-007-post-attack-continuation-release-contract.md)
  for attack declaration, result inspection, and continuation; and
- applicable Armada rules and accepted rule-capability authority for detailed
  command, repair, maneuver, overlap, and eligibility logic.

The AT-002 maps are AS-IS evidence only: [high-level map](../../architecture/discovery/AT-002-active-gameplay-interaction-map.md)
and [Ship Activation map](../../architecture/discovery/AT-002-ship-activation-interaction-map.md).
`docs/game_flow.md` is historical comparison evidence only.

## 2. Scope hierarchy

```text
Ship Phase
└─ Ship Activation
   ├─ Activation candidate inspection (transient / non-binding)
   ├─ Activation commitment
   ├─ Squadron Command
   │  └─ zero or more sequential Shared Squadron Activations
   ├─ Repair
   │  └─ zero or more sequential Repair actions
   ├─ Attack
   │  └─ zero or more Shared Attacks
   ├─ Maneuver [mandatory]
   │  ├─ Determine Course
   │  └─ Execute Maneuver
   │     └─ resolve applicable overlaps
   │        ├─ ship overlap
   │        ├─ squadron overlap / displacement
   │        └─ obstacle overlap
   └─ End Activation
      └─ explicit completion → authoritative next actor/state
```

This is a requirements hierarchy, not a requirement for an authoritative
`current_step` object, a generic serialized decision object, or a generic
activation FSM.

## 3. Cross-cutting recovery requirement

**SAI-001 — Decision-equivalent recovery.** For every live mandatory or
optional decision below, Armada SHALL recover or deterministically derive:

1. whether the opportunity exists and whether it is mandatory or optional;
2. the gameplay actor entitled to decide;
3. legal choices, or the accepted authoritative source that derives them; and
4. the use, decline, commit, and completion semantics needed to continue.

Equivalent authoritative situations SHALL expose equivalent actionable
semantics regardless of supported controller, UI, scene, callback, transport,
or recovery path. Local presentation SHALL NOT be an alternative authority for
any of those semantics.

Hover and selection emphasis, camera position, drag state, animation, and
uncommitted target or maneuver previews may be discarded and locally rebuilt.

## 4. Ship Activation requirements

### SAI-010 — Activation candidate inspection

- **Trigger / availability:** During an entitled Ship Phase activation, the
  controller may inspect the command dial of an eligible owned ship.
- **Decision / legality:** Inspection may be repeated for eligible candidates;
  phase/turn state, ownership, and activation eligibility determine the
  inspectable ships.
- **Completion / result:** Inspection does not select a ship, begin an
  activation, consume a command source, or bind the controller. It may be
  abandoned in favour of another candidate.
- **Recovery:** The underlying eligibility and controller are recoverable under
  SAI-001. The currently inspected dial/candidate is not.
- **Transient presentation:** Revealed-dial display, board emphasis, prompt,
  and camera focus may be rebuilt or discarded.

### SAI-020 — Activation commitment

- **Trigger / availability:** The controller chooses a legal activation path for an
  eligible ship.
- **Controller / decision:** The entitled Ship Phase controller commits that
  ship's activation. Normally this is either using its dial at full effect or
  converting the dial to the corresponding command token; an applicable rule
  may modify or replace those normal paths.
- **Legality:** Canonical phase/turn state, ship eligibility, command-source
  state, and applicable rules determine valid commitment paths.
- **Completion / result:** The accepted semantic entry transition selects the
  active ship, establishes its ADR-006 activation identity, and initializes
  its activation boundary. It is the first binding ship-selection action.
- **Recovery:** SAI-001 SHALL recover a live commitment choice and its
  authoritative legality source. The selected active ship and ADR-006 facts,
  not the preceding inspection surface, establish the result.
- **Transient presentation:** Entry panel state, reveal animation, and token
  manipulation may be rebuilt or discarded.

### SAI-030 — Squadron Command

- **Trigger / availability:** The active ship's optional Squadron-command
  opportunity is executable under ADR-006, current command sources, and the
  applicable rules.
- **Controller / decision:** The active ship's controller may use none, one,
  or more permitted activations and may end the remaining opportunity before
  capacity is exhausted. Squadrons are selected and committed one at a time;
  the complete set is not chosen upfront.
- **Legality:** The matching activation identity, `OPEN` opportunity,
  committed count, authoritative squadron eligibility, current sources, and
  rules determine the next legal commitment. Dial-granted ordinary capacity
  is used first; after it is exhausted, an applicable token may permit further
  ordinary activations. Applicable special rules may provide or modify Squadron-activation capability according to their own authoritative timing
  and conditions. Where the controller must choose between multiple applicable
  sources, the committed source is identified.
- **Completion / result:** A commanded-squadron commitment establishes that
  squadron's authoritative `ACTIVATED` state and increments the ADR-006 count
  exactly once, then enters Shared Squadron Activation. On its completion,
  control returns to the still-live command opportunity for another eligible
  squadron or for voluntary finish. An activated squadron remains activated
  even if it performs no action and is normally excluded from later choices;
  a reactivation rule must change authoritative eligibility, never add a UI
  exception.
- **Recovery:** SAI-001 SHALL recover the opportunity, controller, currently
  derived capacity, eligible squadrons, source availability, and use/end
  semantics. Capacity and local resolver counters remain derived.
- **Transient presentation:** Range cues, candidate highlights, source
  selection display, and in-progress selection surfaces may be discarded.

### SAI-035 — Shared Squadron Activation delegation

Commanded Squadron Activation SHALL use the same fundamental gameplay
activation structure as Squadron Phase and other rule-authorized Squadron
Activation contexts. The initiation context may change legal capabilities, but
does not justify independent fundamental implementations. Detailed shared
Squadron Activation lifecycle, capabilities, and completion behavior are
deferred to a child requirements specification.

### SAI-040 — Repair

- **Trigger / availability:** An optional Repair opportunity is available for
  the active ship under applicable command and repair rules.
- **Controller / decision:** The active ship's controller may finish without
  using all capability, or resolve one legal Repair action at a time. Repair
  is not one authoritative multi-action plan.
- **Legality:** Current ship state and applicable repair rules determine legal
  actions. Engineering capability is derived from authoritative availability
  and consumption of dial, token, and special-rule sources. Dial capability is
  the preferred source, but additional token/special-rule capability may be
  added when needed to afford a legal action; the dial-derived amount need not
  first reach zero.
- **Completion / result:** Each accepted action commits/pays independently and
  changes authoritative ship state. Available sources and legal actions are
  then derived again; the controller chooses another action or finishes.
  Committing a token or special-rule source immediately consumes that source.
  Unused capability disappears when Repair ends and never refunds a committed
  source.
- **Recovery:** SAI-001 SHALL recover the live opportunity, controller, legal
  actions, source availability/consumption, and finish semantics. Temporary
  Engineering capability is deterministically derived, not persistent
  authoritative ship state.
- **Transient presentation:** Tentative multi-action plans, temporary point
  totals, damage highlights, and local panel navigation may be discarded.

### SAI-050 — Attack

- **Trigger / availability:** An optional ship attack-declaration opportunity
  is available during the active ship's Attack boundary.
- **Controller / decision:** The active ship's controller may explore legal
  target/arc candidates, abandon or replace a candidate, confirm an attack,
  or end remaining Attack opportunity. A further legal attack never compels a
  declaration.
- **Legality:** ADR-001, ADR-006, CON-006, CON-007, and applicable attack and
  rule-capability authority determine declaration legality and continuation.
- **Completion / result:** Pre-confirmation exploration is transient.
  Confirmation submits the CON-006 `BeginAttackCommand`, which creates
  authoritative `CurrentAttackState`; an accepted Skip consumes the
  declaration opportunity without creating one. The detailed shared Attack
  Flow remains delegated. Once that flow rolls attack dice, the already
  declared attack may not be voluntarily abandoned and must reach its governed
  completion. After an individual attack completes, the enclosing Attack
  opportunity determines any further legal declaration or finish.
- **Recovery:** SAI-001 SHALL recover each live declaration/Skip decision,
  controller, authoritative legality source, and continuation semantics.
  Candidate target/arc information before confirmation is not recoverable
  gameplay state.
- **Transient presentation:** Candidate previews, target/arc aids, dice
  animation, and result-panel layout may be discarded.

### SAI-060 — Maneuver

- **Trigger / availability:** The active ship's ADR-006 Maneuver opportunity
  is `OPEN`. It is mandatory for a surviving normal Ship Activation.
- **Controller / decision:** The active ship's controller determines and
  commits one legal Maneuver, including a legal speed-zero/no-movement result.
  Maneuver is not normally declinable.
- **Completion / result:** Commitment and all mandatory Execute Maneuver
  consequences complete through accepted semantic transitions; only then is
  the Maneuver opportunity `CONSUMED`.
- **Recovery:** SAI-001 SHALL recover the mandatory opportunity, controller,
  legal course/source derivation, commitment, and unresolved mandatory
  consequences.

#### SAI-061 — Determine Course

- **Decision / legality:** Determine Course is the execution-oriented,
  pre-commit interaction that exposes only currently legal and executable
  courses. It derives current movement state/chart, command sources, and
  applicable special-rule modifications; it is not a general movement
  sandbox.
- **Source priority / preview:** An applicable command dial is preferred. A
  command token is used only when additionally required for the selected legal
  course or as the applicable sole source, such as for a required speed change.
  The controller can see required source consumption before commitment.
- **Completion / result:** The course remains reversible until explicit
  commitment. Commitment consumes required dial/token/rule resources, makes
  the course authoritative, and requires execution; it cannot later be
  cancelled merely because its outcome is undesirable.
- **Recovery / transient presentation:** SAI-001 recovers legal courses and
  source/commit semantics. Uncommitted tool geometry and ghost positioning may
  be discarded. Hypothetical exploration belongs to the deferred, separate
  Maneuver Helper, not Determine Course.

#### SAI-062 — Execute Maneuver and overlap resolution

Execute Maneuver applies the committed course. A Maneuver is incomplete until
all applicable mandatory overlap consequences resolve.

##### SAI-063 — Ship overlap

Base ship-overlap resolution creates no new course choice. If the committed
course overlaps a ship, execution temporarily reduces speed and reuses the
corresponding already-committed course geometry, retrying until executable
(including temporary speed zero where necessary). Applicable overlap
consequences resolve, while the ship's actual speed setting is unchanged by
the temporary reduction. This automatic resolution and its authoritative
consequences are recoverable under SAI-001.

##### SAI-064 — Squadron overlap / displacement

If an executed Maneuver overlaps squadron(s), mandatory displacement is nested
within Execute Maneuver. The player not moving the ship controls placement,
regardless of squadron ownership. All required placement resolves before the
Maneuver completes. SAI-001 SHALL recover the obligation, controller,
affected squadrons, applicable placement-legality source, and completion
semantics; drag, measurements, and placement ghosts remain transient.

##### SAI-065 — Obstacle overlap

An obstacle overlap invokes the applicable authoritative obstacle rule. This
document does not specify individual effects. Where one creates a live player
decision, that nested decision SHALL satisfy SAI-001.

### SAI-080 — End Activation and handoff

- **Trigger / availability:** End Activation is an explicit commitment by the
  active ship's controller; activation does not end automatically merely
  because other work is complete.
- **Legality / decision:** It is legal once mandatory work is resolved,
  including Maneuver, required displacement, and other mandatory nested
  decisions. It may implicitly decline unused optional Squadron Command,
  Repair, and Attack opportunities; the controller need not close each one
  separately.
- **Completion / result:** The accepted completion transition performs ADR-006
  activation cleanup and derives the next actor and gameplay state. An
  exceptional termination remains an accepted terminal transition, not a
  fabricated End Activation decision.
- **Recovery:** SAI-001 SHALL recover completion availability, controller,
  mandatory prerequisites, and resulting actionable gameplay semantics.
  Handoff has no independent gameplay decision or authority.
- **Transient presentation:** Hot-Seat overlay, Network waiting display,
  camera/table orientation, banners, and animations present the authoritative
  result and may be discarded or rebuilt.

## 5. Explicitly deferred work

- **Shared Squadron Activation:** its detailed lifecycle, initiation-context
  capabilities, and completion semantics require a child specification.
- **Repair rules:** individual actions, costs, and rule-specific legality stay
  with their applicable rules/child specification.
- **Attack-capacity ownership:** whether attack allowances are stored or
  derived is an architecture decision still deferred; this document authorizes
  no new capacity owner or field.
- **Squadron displacement:** placement geometry, order, touching, and
  multi-squadron detail are deferred.
- **Obstacle effects:** individual effects remain governed by their authority.
- **Maneuver Helper:** its hypothetical-planning behavior is not specified.
- **Speculative rules:** future special rules do not weaken these base
  requirements; real rules integrate through accepted rule/capability
  authority.

## Appendix A — AS-IS evidence for later gap analysis (non-normative)

AT-002 found conditionally reconstructible entry, Squadron-command, Maneuver,
and handoff paths (R2), plus callback/path-dependent Repair and Squadron
displacement paths (R3). Attack was reconstructible after accepted Begin/Skip,
while its pre-Begin candidate preview was conditional. These observations do
not define TO-BE behavior, make every R2 state defective, or authorize
remediation here.

## Traceability

| Requirement area | Primary authority / decision source | AS-IS evidence |
| --- | --- | --- |
| SAI-001 | ADR-010 | AT-002 interaction maps |
| SAI-010–SAI-020 | Owner decisions D-SA-010–020; ADR-006 | AT-002 interaction maps |
| SAI-030–SAI-035 | Owner decisions D-SA-030–035; ADR-006 | AT-002 Ship Activation map |
| SAI-040 | Owner decisions D-SA-040–044; applicable repair authority | AT-002 Ship Activation map |
| SAI-050 | Owner decisions D-SA-050–052; ADR-001; CON-006; CON-007 | AT-002 Ship Activation map |
| SAI-060–SAI-065 | Owner decisions D-SA-060–067; ADR-006; applicable maneuver/overlap authority | AT-002 Ship Activation map |
| SAI-080 | Owner decisions D-SA-080–082; ADR-006 | AT-002 Ship Activation map |
