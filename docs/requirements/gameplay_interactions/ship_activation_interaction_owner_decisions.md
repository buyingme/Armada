# Ship Activation Interaction — Owner Decisions

**Status:** Accepted Owner Decision Record
**Scope:** Ship Phase / Ship Activation gameplay-interaction requirements
**Purpose:** Preserve Project Owner decisions made during review of `ship_activation_interaction.md` before those decisions are incorporated into the normative requirements specification.

Accepted by: Project Owner
Accepted date: 2026-08-21

## 1. Purpose and authority

This document records Project Owner decisions made during the hierarchical review of the Draft Ship Activation interaction requirements.

It is an intermediate decision record.

It does not replace accepted architecture, rules authority, contracts, or the final requirements document.

Its purposes are to:

1. preserve Owner decisions and their rationale;
2. prevent decisions from being lost during requirements refinement;
3. distinguish confirmed requirements from deferred child specifications and architecture questions;
4. provide an auditable input for refinement of `ship_activation_interaction.md`.

The review deliberately proceeds from high-level gameplay interaction toward detail. Detailed child behavior is deferred where it is not necessary to settle the parent requirement.

---

# 2. Cross-cutting interaction recovery

## D-SA-001 — Decision-equivalent recovery

### Decision

Accept the existing SAI-001 requirement as written.

Every live mandatory or optional gameplay decision must expose recoverable or deterministically derivable:

- existence of the decision/opportunity;
- whether it is mandatory or optional;
- controlling gameplay actor;
- legal choices or authoritative legality source;
- use, decline, commit, and completion semantics as applicable.

Equivalent authoritative gameplay situations must expose equivalent actionable interaction semantics regardless of UI, scene, callback, transport, or recovery path.

Transient presentation state does not need to be restored.

### Rationale

This directly applies ADR-010 to Ship Activation without creating a second gameplay authority.

The requirement concerns recovery of the gameplay decision, not exact restoration of the previous UI.

Examples of safely transient state include:

- camera state;
- hover state;
- drag state;
- animation state;
- uncommitted previews;
- panel position;
- other visual working state.

---

# 3. Ship activation selection and commitment

The original distinction between direct "Ship selection" and subsequent "Activation entry" requires revision.

The actual player interaction is based on inspecting a ship's command dial and then committing to activation.

## 3.1 Interaction flow

```text
Ship Phase activation decision
        │
        ├─ Inspect eligible ship's command dial
        │      └─ reversible / transient
        │
        ├─ Inspect another eligible ship's command dial
        │      └─ reversible / transient
        │
        └─ Commit activation
               ├─ normally: spend dial at full effect
               ├─ normally: convert dial to command token
               └─ other rule-authorized commitment path
                        │
                        ▼
               ship selection becomes committed
                        │
                        ▼
               canonical Ship Activation begins
```

## D-SA-010 — Command-dial inspection is non-binding

### Decision

The player may inspect/reveal command dials of eligible owned ships before committing to an activation.

Inspecting a dial:

- does not select the ship authoritatively;
- does not begin its activation;
- does not commit the player to that ship;
- may be abandoned in favor of inspecting another eligible ship's dial.

### Recovery

The currently inspected dial/candidate does not need to survive reconstruction.

If the interaction is rebuilt before commitment, the player may simply inspect a dial again.

### Rationale

Inspection has no consequence for gameplay state.

It is reversible working interaction rather than semantic gameplay progress.

---

## D-SA-020 — Activation commitment selects the ship

### Decision

The ship becomes selected for activation only when the player commits to a legal activation path for that ship.

Normally, after inspecting the command dial, the player commits by choosing either:

1. spend the command dial for its full effect; or
2. convert the command dial to the corresponding command token.

The commitment establishes the active ship and begins the canonical Ship Activation boundary.

### Rule extensibility

The activation-commit mechanism must be rule-extensible.

An applicable rule may modify or replace the normal dial-based commitment choices.

For example, a future rule could require activation without receiving the normal benefit of revealing/resolving the command dial.

The high-level requirement therefore must not assert that every possible Ship Activation necessarily requires one of exactly two dial operations.

### Important distinction

```text
Inspect dial
    │
    └─ no gameplay commitment

Commit legal activation path
    │
    └─ semantic commitment
           │
           ▼
      ship becomes active
```

---

# 4. Squadron command

## D-SA-030 — One optional Squadron-command opportunity

### Decision

Squadron command is one optional opportunity within Ship Activation.

The opportunity may permit multiple squadron activations, but those activations occur sequentially.

The player is not required to use the maximum available capacity.

The player may:

- use none of the available capacity;
- activate one or more eligible squadrons up to the permitted maximum;
- voluntarily end the opportunity before all possible capacity has been used.

The requirements should avoid unnecessarily distinguishing UI concepts such as separate "pass" and "close" operations where they express the same gameplay semantic of ending the remaining optional opportunity.

---

## 4.1 Squadron-command sources

A Squadron-command opportunity may obtain activation capability from:

- an applicable Squadron command dial;
- a Squadron command token;
- an applicable special rule.

The source of activation capability matters.

## D-SA-031 — Dial capacity has priority

### Decision

Where Squadron-command capacity from an applicable command dial is
available, that dial-granted capacity is used first for the ordinary
Squadron-command activation sequence.

After the dial-granted capacity is exhausted, further permitted
activations may use another available ordinary source such as a
Squadron command token.

Applicable special rules may provide or modify Squadron-activation
capability according to their own authoritative timing and conditions.

Where the player must choose between multiple applicable sources, the
source used for the activation must be identified.

### Flow

```text
Squadron-command opportunity
        │
        ├─ Squadron dial capacity available?
        │        │
        │        └─ YES
        │             │
        │             ├─ activate eligible squadron
        │             ├─ return
        │             ├─ activate another eligible squadron
        │             └─ continue until dial capacity is exhausted
        │
        └─ Further activation desired and legal?
                 │
                 ├─ use Squadron token
                 │
                 └─ use applicable special-rule source
                         │
                         ▼
                 player identifies source
```

---

## D-SA-032 — Sequential squadron activation decisions

### Decision

Squadrons are selected and activated one at a time.

After each commanded Squadron Activation completes, control returns to the still-live Squadron-command opportunity.

The player then chooses either:

- another currently eligible squadron; or
- to end the remaining Squadron-command opportunity.

The player does not need to choose the complete set of squadrons upfront.

### Flow

```text
Squadron Command
      │
      ▼
choose eligible squadron
      │
      ▼
commit Squadron Activation
      │
      ▼
Shared Squadron Activation
      │
      ▼
return to Squadron Command
      │
      ├─ choose another eligible squadron
      │
      └─ finish Squadron Command
```

---

# 5. Shared Squadron Activation

The review identified a child requirement that must be specified separately later.

## D-SA-033 — Squadron Activation uses a shared gameplay structure

### Decision

A squadron activated through a ship's Squadron command should use the same fundamental Squadron Activation controller/command structure as a squadron activated during Squadron Phase.

The project should not create independent implementations of:

- Commanded Squadron Activation; and
- Squadron Phase Activation.

Instead:

```text
Ship Activation
└─ Squadron Command
      │
      └──────────────┐
                     ▼
             Shared Squadron Activation
                     ▲
      ┌──────────────┘
      │
Squadron Phase
```

Other applicable rules may also initiate the same shared Squadron Activation structure.

### Context-dependent capability

The initiation context may change the legal capabilities available during the Squadron Activation.

Therefore:

```text
Squadron Activation
├─ shared activation lifecycle
│
├─ initiation context
│  ├─ Squadron Command
│  ├─ Squadron Phase
│  └─ rule-authorized initiation
│
└─ context-dependent capabilities
```

The fact that capabilities differ by context does not justify separate Squadron Activation implementations.

Detailed context-dependent Squadron Activation capabilities are deferred to a child requirements specification.

---

## D-SA-034 — Squadron activation commitment sets activated state

### Decision

A squadron becomes authoritatively `ACTIVATED` as soon as the player commits to activating that squadron.

It does not wait until:

- movement occurs;
- an attack occurs;
- the Squadron Activation finishes; or
- the parent Squadron-command opportunity finishes.

A squadron remains activated even if it ultimately performs no movement or attack.

### Flow

```text
Eligible squadron
      │
      ▼
player commits to activation
      │
      ▼
Squadron becomes ACTIVATED
      │
      ▼
Shared Squadron Activation begins
      │
      ├─ capabilities depend on initiation context/rules
      │
      └─ squadron may ultimately perform no move or attack
```

### Rationale

`ACTIVATED` represents commitment of the unit's activation, not successful execution of an action.

---

## D-SA-035 — Authoritative activation state determines future eligibility

### Decision

An already-activated squadron is normally excluded from subsequent activation choices.

Eligibility must derive from authoritative gameplay state rather than UI/controller memory of which squadrons previously acted.

If an applicable rule permits a ship or squadron to be activated again,
the authoritative activation state/eligibility of that object must be
changed so that the object becomes legally available for another
activation.

Consumers should not implement special UI/controller exceptions that simply ignore the authoritative `ACTIVATED` state.

### General model

```text
NOT ACTIVATED
      │
      │ commit activation
      ▼
  ACTIVATED
      │
      └─ normally excluded from further activation
```

A rule-authorized reactivation must make the object authoritatively eligible again.

---

# 6. Repair

## D-SA-040 — One optional Repair opportunity

### Decision

Repair is one optional opportunity within Ship Activation.

The player may perform multiple legal Repair actions sequentially and may voluntarily finish the Repair opportunity without exhausting all potential Repair capability.

Repair actions are not planned as one atomic package.

Instead:

```text
Repair opportunity
      │
      ▼
derive available Repair capability
      │
      ▼
choose one legal Repair action
      │
      ▼
commit / pay
      │
      ▼
authoritative ship state changes
      │
      ▼
rederive available sources and legal Repair actions
      │
      ├─ choose another action
      └─ finish Repair
```

---

## D-SA-041 — Engineering dial is the preferred source

### Decision

Engineering points granted through an applicable command dial are the preferred Repair source.

A command token or applicable special rule may provide additional Engineering points.

Dial priority is a **source-priority rule**, not a requirement that the dial-generated point pool literally reach zero before another source can be accessed.

Additional points may be added where necessary to afford a legal Repair action.

### Example

If a desired legal Repair action cannot be afforded from the
dial-derived Engineering capability alone, an available token and/or
applicable special-rule source may contribute additional Engineering
capability so that the action can be afforded.

### Flow

```text
Repair opportunity
      │
      ├─ Engineering capability from dial
      │       └─ preferred source
      │
      ├─ desired Repair action affordable?
      │       │
      │       ├─ YES → may commit action
      │       │
      │       └─ NO → additional source available?
      │                    ├─ Engineering token
      │                    └─ applicable special rule
      │
      ▼
combined temporary Engineering capability
      │
      ▼
commit legal Repair action
```

---

## D-SA-042 — Repair actions resolve sequentially

### Decision

Each Repair action is individually committed.

After a Repair action resolves:

1. authoritative ship state reflects its result;
2. available Repair sources are reconsidered;
3. current legal Repair actions are derived again;
4. the player chooses another action or finishes.

A multi-action Repair plan may be previewed by presentation if useful, but such a plan is not authoritative until its individual actions are committed.

---

## D-SA-043 — Engineering capability is transient; source availability/consumption is authoritative

### Decision

Available/current Engineering points are **not authoritative persistent ship state**.

They are transient capability derived during the currently live Repair opportunity.

Authoritative gameplay state must instead provide the information necessary to determine whether underlying sources are available or consumed, including as applicable:

- command dial availability/state;
- command token availability/state;
- applicable special-rule availability/state.

From these authoritative sources and applicable rules, the current Repair interaction can derive the temporary Engineering capability.

### Consequence

Unused Engineering points disappear when the Repair opportunity ends.

They do not become a persistent resource on the ship.

### Model

```text
Authoritative state
├─ dial available / consumed
├─ token available / consumed
└─ special-rule source available / consumed
        │
        ▼
deterministically derive
temporary Engineering capability
        │
        ▼
Repair interaction
```

---

## D-SA-044 — Committing an additional Repair source consumes it

### Decision

When the player commits a command token or applicable special-rule source to obtain additional Engineering capability, consumption of that source is immediately authoritative.

If the player later ends Repair without spending all Engineering capability generated from that source:

- the unused Engineering points disappear;
- the committed source is not refunded.

### Recovery implication

Reconstruction of an open Repair opportunity must not make already-consumed sources available again.

The UI must not own source-consumption truth.

---

# 7. Attack

## D-SA-050 — Ship Attack delegates to the shared Attack Flow

### Decision

The Ship Activation requirements do not duplicate the detailed Attack Flow.

The active ship's Attack opportunity may initiate individual attacks through the shared authoritative Attack interaction governed by the existing Attack authority/contracts.

After an individual attack completes, control returns to the enclosing ship Attack opportunity.

### Flow

```text
      └─ explore legal attack
             │
             ├─ abandon / choose another
             │
             └─ confirm attack
                     │
                     ▼
              BeginAttackCommand
                     │
                     ▼
          authoritative attack established
                     │
                     ▼
              Shared Attack Flow
                     │
                     ├─ roll attack dice
                     │    └─ thereafter attack
                     │       cannot be voluntarily abandoned
                     │
                     ▼
              attack completes
                     │
                     ▼
          return to Attack opportunity
                     │
                     ├─ another legal attack
                     └─ finish
```

---

## D-SA-051 — Attack opportunity is optional

### Decision

The player may voluntarily end the ship's Attack opportunity even when another legal attack remains available.

The existence of another legal attack does not force the player to make it.

---

## D-SA-052 — Attack declaration and dice-roll commitment semantics

### Decision

Pre-confirmation target/arc exploration is reversible.

Before confirming an attack declaration, the player may:

- inspect a potential target;
- inspect a potential attacking arc;
- abandon that candidate;
- choose another legal attack candidate;
- end the remaining Attack opportunity.

Confirming the attack declaration follows the accepted Attack declaration
lifecycle governed by CON-006. `BeginAttackCommand` establishes the
authoritative attack and creates `CurrentAttackState`.

Rolling the attack dice does not establish the authoritative attack
boundary. Instead, it establishes the later gameplay commitment that the
already-declared attack must proceed through the governed Attack Flow
rather than being voluntarily abandoned in favor of another attack.

The detailed declaration lifecycle and Attack Flow remain delegated to
the accepted Attack architecture and contracts.

### Important distinction

```text
Target / arc exploration
      │
      └─ reversible / transient
              │
              ▼
     Confirm Attack declaration
              │
              ▼
        BeginAttackCommand
              │
              ▼
   authoritative attack established
     (`CurrentAttackState`)
              │
              ▼
        Roll attack dice
              │
              ▼
   attack must proceed to valid
           completion
```

---

## D-SA-053 — Attack capacity ownership deferred

### Deferred architecture question

It may be beneficial for the ship object model to authoritatively represent attack-capacity constraints such as:

- maximum total attacks;
- maximum attacks from a particular arc;
- maximum attacks against ships;
- maximum attacks against squadrons;
- other special-rule-modified attack allowances.

This could simplify integration of special rules.

However, this is **not decided by the Ship Activation requirements review**.

A later architecture decision should determine whether such capacities should be:

1. authoritative stored ship state; or
2. deterministically derived from canonical gameplay state and applicable rules.

Do not introduce new authoritative capacity fields solely from this decision record.

---

# 8. Maneuver

Maneuver is a mandatory part of a normal surviving Ship Activation.

A speculative future special rule that skips Maneuver is not currently a hard requirement and should not weaken the base requirement.

## 8.1 Hierarchy

```text
Maneuver
├─ Determine Course
│  ├─ derive currently legal course configurations
│  ├─ derive required command resources
│  ├─ show required resource consumption
│  └─ commit course
│
└─ Execute Maneuver
   ├─ normal movement
   └─ resolve applicable overlaps
      ├─ ship overlap
      ├─ squadron overlap / displacement
      └─ obstacle overlap
```

Overlap resolution is hierarchically part of Maneuver, not a peer Ship Activation step.

---

## D-SA-060 — Maneuver is mandatory

### Decision

A surviving ship that reaches the Maneuver step must resolve a Maneuver.

A legal speed-zero maneuver/no positional movement still constitutes execution of a Maneuver.

The player cannot normally decline Maneuver.

---

## D-SA-061 — Planning interaction is Determine Course

### Decision

Use the rules terminology **Determine Course** for the pre-commit Maneuver interaction.

Determine Course is not a general movement sandbox.

It is the execution-oriented interaction through which the player determines a currently legal and executable course for the active ship.

---

## D-SA-062 — Determine Course exposes only legal/executable configurations

### Decision

During the actual Ship Activation Maneuver step, the player may configure only courses that are currently legal and executable.

The interaction should not permit construction of an unaffordable/illegal course merely for hypothetical exploration.

Legality must account for applicable authoritative gameplay/rule information, including as relevant:

- current ship movement state;
- maneuver capabilities/chart;
- applicable command dial;
- applicable command token;
- special rules that enhance or reduce movement capability.

### Separate planning tool

Hypothetical movement exploration belongs to the separate **Maneuver Helper** functionality outside the authoritative Ship Activation Maneuver interaction.

The Maneuver Helper is not specified further here.

---

## D-SA-063 — Maneuver command-source priority and preview

### Decision

An available applicable command dial is the preferred command source while determining the course.

A command token is used only where:

- it is additionally required to execute the desired legal course; or
- it is the applicable sole command source for the required modification, such as an applicable speed change.

Special rules may also increase or reduce capabilities during Determine Course.

Before commitment, the player must be able to see whether the currently determined course will consume a command token or other applicable resource.

### Important distinction

```text
Determine Course
      │
      ├─ derive legal maneuver
      ├─ derive required sources
      └─ show expected consumption
              │
              │ no resources consumed
              ▼
         COMMIT MANEUVER
              │
              ├─ consume required dial/token/rule resources
              └─ movement becomes authoritative
```

---

## D-SA-064 — Maneuver commitment is binding

### Decision

Determine Course remains reversible until the player explicitly commits the maneuver.

Before commitment:

- the player may adjust the legal course;
- no required dial/token resource is consumed.

At commitment:

- required resources are consumed;
- the chosen course becomes authoritative;
- the Maneuver must resolve.

There is no additional cancellation or second confirmation after semantic commitment merely because the resulting position, overlap, or consequences are undesirable.

---

# 9. Overlap resolution within Maneuver

Overlap resolution is part of **Execute Maneuver**.

A Maneuver is not necessarily complete merely because the ship has been moved toward its initially determined final position.

All applicable mandatory overlap consequences must resolve before Maneuver completion.

## 9.1 Overlap hierarchy

```text
Execute Maneuver
      │
      ├─ no relevant overlap
      │      └─ complete movement
      │
      └─ overlap
          ├─ Ship
          │    └─ automatic reduced-speed resolution
          │
          ├─ Squadron
          │    └─ mandatory non-moving-player placement
          │
          └─ Obstacle
               └─ applicable obstacle-rule resolution
```

---

## D-SA-065 — Ship overlap is automatic Maneuver resolution

### Decision

Ship overlap does not create a new player choice under the base overlap rules.

If the committed Maneuver would overlap another ship:

1. the game temporarily reduces the execution speed;
2. it reuses the **already committed course geometry** at the reduced speed;
3. it retries the Maneuver;
4. this continues until the ship can execute the Maneuver, including at temporary speed zero where necessary;
5. applicable ship-overlap consequences, including required damage, are resolved;
6. the ship's actual speed setting is not changed merely by this temporary reduction.

The player does not determine a new course during this resolution.

### Example

If the committed maneuver tool represents a course with two clicks at speed 2, and ship overlap requires execution at temporary speed 1, the corresponding speed-1 portion of the already committed course is used—for example, one click at speed 1.

### Flow

```text
Committed course
      │
      ▼
final position overlaps ship?
      │
      ├─ NO → continue resolution
      │
      └─ YES
            │
            ▼
      temporarily reduce execution speed
            │
            ▼
      reuse committed course at reduced speed
            │
            ├─ still overlaps → reduce/retry
            │
            └─ executable
                   │
                   ▼
           resolve overlap consequences
                   │
                   ▼
            Maneuver may complete
```

---

## D-SA-066 — Squadron overlap creates mandatory placement interaction

### Decision

If the executed ship Maneuver overlaps one or more squadrons, the resulting Squadron displacement/placement is a mandatory nested interaction within Maneuver resolution.

The controller of this interaction is the player who is **not moving the ship**, regardless of who owns the displaced squadrons.

All required Squadron displacement must resolve before the Maneuver completes.

### Delegated detail

Detailed placement legality remains governed by the applicable overlap rules and may be specified in a later child requirement.

This includes details such as:

- legal placement positions;
- placement order;
- touching requirements;
- interaction between multiple displaced squadrons;
- play-area constraints.

### Flow

```text
Ship Maneuver overlaps squadron(s)
        │
        ▼
move affected squadron(s) out of the way
        │
        ▼
ship reaches its resolved position
        │
        ▼
player NOT moving the ship controls placement
        │
        ├─ place displaced squadron
        ├─ place next displaced squadron
        └─ continue until mandatory placement resolves
        │
        ▼
Maneuver may complete
```

---

## D-SA-067 — Obstacle overlap delegates to obstacle rules

### Decision

If a ship's Maneuver overlaps an obstacle, Armada invokes the applicable authoritative obstacle rule.

The Ship Activation requirements do not duplicate individual obstacle effects.

An obstacle effect may be:

- automatic; or
- itself contain a player decision.

If an obstacle effect creates a live gameplay decision, that nested decision must satisfy ADR-010 decision-equivalent recovery requirements.

---

# 10. End Activation and handoff

## D-SA-080 — End Activation is explicit player commitment

### Decision

Ship Activation does not automatically end merely because its other work is complete.

The controlling player explicitly commits **End Activation**.

### Flow

```text
Ship Activation
      │
      ├─ mandatory work resolved
      │
      ├─ optional opportunities used or left unused
      │
      ▼
player chooses End Activation
      │
      ▼
activation completes
      │
      ▼
authoritative gameplay derives next actor/state
```

---

## D-SA-081 — End Activation may decline remaining optional opportunities

### Decision

End Activation may be committed while optional opportunities remain unused.

Committing End Activation implicitly declines those remaining optional opportunities.

Examples include:

- another legal attack remains;
- unused Repair capability remains;
- unused Squadron-command capacity remains.

The player does not need to mechanically close every optional opportunity before End Activation.

### Mandatory work

End Activation is not legal while mandatory activation work remains unresolved.

Examples include:

- mandatory Maneuver has not resolved;
- required Squadron displacement remains unresolved;
- another mandatory nested gameplay decision remains open.

### Model

```text
Remaining interaction
      │
      ├─ OPTIONAL
      │     └─ End Activation may implicitly decline it
      │
      └─ MANDATORY
            └─ must resolve before End Activation is legal
```

---

## D-SA-082 — Next actor/state is authoritative; handoff is presentation

### Decision

Once End Activation is committed, authoritative gameplay rules determine the next actor and gameplay state.

There is no separate gameplay decision whose purpose is merely to hand control to the next player.

Hot-Seat and Network presentation may differ.

Examples of presentation-only behavior include:

- Hot-Seat handoff overlay;
- Network waiting state;
- camera transition;
- active-player banner;
- other turn-transition presentation.

These surfaces present the authoritative result; they do not own gameplay progression.

---

# 11. Resulting high-level Ship Activation hierarchy

The Q&A changes the original Draft hierarchy.

The resulting high-level model is:

```text
Ship Phase
│
└─ Ship Activation
   │
   ├─ Activation candidate inspection
   │  └─ inspect eligible command dials
   │     (transient / non-binding)
   │
   ├─ Activation commitment
   │  ├─ normally use dial at full effect
   │  ├─ normally convert dial to token
   │  └─ other rule-authorized commitment
   │
   ├─ Squadron Command
   │  └─ zero or more sequential
   │     Shared Squadron Activations
   │
   ├─ Repair
   │  └─ zero or more sequential Repair actions
   │
   ├─ Attack
   │  └─ zero or more Shared Attacks
   │
   ├─ Maneuver [mandatory]
   │  ├─ Determine Course
   │  └─ Execute Maneuver
   │     └─ overlap resolution
   │        ├─ ship overlap
   │        ├─ squadron overlap / displacement
   │        └─ obstacle overlap
   │
   └─ End Activation
      └─ explicit completion
         → authoritative next actor/state
```

This hierarchy is a requirements hierarchy, not a generic serialized activation FSM.

It must not be interpreted as requiring one authoritative `current_step` field or equivalent generic progression owner.

---

# 12. Authoritative versus transient state decisions

The review established several important state-boundary decisions.

## Authoritative or authoritatively derivable

The game must authoritatively know or be able to derive, as applicable:

- which ships/squadrons are currently eligible for activation;
- whether a ship/squadron has been committed to activation;
- ship/squadron activation status required for future legality;
- availability/consumption of applicable command dials;
- availability/consumption of applicable command tokens;
- availability/consumption of applicable special-rule sources;
- legality of committed gameplay actions;
- committed Repair effects on ship state;
- committed Attack state;
- committed Maneuver and its resulting gameplay state;
- mandatory unresolved gameplay decisions;
- next actor/state after activation completion.

## Transient / reconstructible working state

The following need not themselves become authoritative gameplay state:

- which uncommitted command dial the player is currently inspecting;
- target/arc candidate before Attack commitment;
- current Determine Course tool geometry before Maneuver commitment;
- temporary Engineering-point total;
- visual range/movement overlays;
- camera;
- hover;
- drag state;
- animation;
- panel/modal positioning;
- Hot-Seat handoff choreography.

The existence of transient state does not remove the ADR-010 requirement that any underlying live gameplay decision remain recoverable.

---

# 13. Explicit deferred work

The following matters were identified but intentionally not resolved in this first-level Ship Activation requirements review.

## 13.1 Shared Squadron Activation specification

Create a later child requirements specification covering:

- shared Squadron Activation lifecycle;
- Squadron-command initiation context;
- Squadron Phase initiation context;
- other rule-authorized initiation contexts;
- context-dependent movement/attack capabilities;
- commitment and completion semantics.

Do not create separate fundamental Squadron Activation implementations merely because capabilities differ by initiation context.

---

## 13.2 Detailed Repair rules

Detailed Repair actions, individual Engineering costs, and rule-specific legality remain delegated to the applicable rules and/or a later child specification.

The current decision record establishes the interaction/resource semantics, not the complete Repair rules catalogue.

---

## 13.3 Attack-capacity ownership

Architecture decision deferred:

Should limits such as:

- total attacks;
- attacks per hull zone;
- attacks against ships;
- attacks against squadrons;
- special-rule-modified attack allowances

be stored as authoritative ship state or derived from authoritative state and applicable rules?

No new owner/state representation is authorized here.

---

## 13.4 Squadron displacement detail

A later child specification may define the detailed Squadron placement interaction, including applicable placement geometry, order, touching constraints, and multi-squadron placement behavior.

The current level establishes:

- mandatory resolution;
- controller = player not moving the ship;
- nesting under Maneuver;
- completion dependency.

---

## 13.5 Obstacle effects

Individual obstacle effects remain delegated to their authoritative rules.

Where an obstacle creates a gameplay decision, that decision must satisfy ADR-010.

---

## 13.6 Maneuver Helper

The separate Maneuver Helper may support hypothetical movement exploration outside the authoritative Ship Activation Maneuver interaction.

Its behavior is not specified here.

It must not be confused with **Determine Course**, which exposes only currently legal/executable Maneuver configurations during the actual activation.

---

## 13.7 Speculative rules

Do not weaken base requirements merely to accommodate hypothetical future rules.

Where a real special rule later modifies a base behavior, integrate that rule through the appropriate authoritative rule/capability mechanism.

Known architectural extension points should remain possible, but speculative gameplay should not be promoted into hard requirements without evidence.

---

# 14. Requirements-refinement implications

When this Owner decision record has been audited and accepted as complete, refine `ship_activation_interaction.md` accordingly.

The refinement should:

1. preserve SAI-001 unchanged;
2. revise the existing Ship-selection/Activation-entry distinction around inspection versus activation commitment;
3. refine Squadron Command around sequential shared Squadron Activations and source priority;
4. refine Repair around sequential actions, source priority, and transient Engineering capability;
5. preserve delegation to the existing shared Attack authority while documenting reversible pre-confirmation attack exploration, CON-006 declaration commitment through `BeginAttackCommand`, and mandatory continuation once attack dice have been rolled;
6. restructure Maneuver around Determine Course and Execute Maneuver;
7. move Squadron displacement beneath Maneuver overlap resolution rather than keeping it as a peer Ship Activation step;
8. add ship-overlap and obstacle-overlap requirements at the appropriate hierarchical level;
9. refine End Activation around explicit completion and implicit decline of remaining optional opportunities;
10. preserve all explicitly deferred questions as deferred rather than silently resolving them.

Do not use this refinement to:

- create a generic activation FSM;
- create a generic serialized decision object;
- make UI/controller state authoritative;
- redesign `InteractionFlow`;
- implement production code;
- resolve deferred architecture questions;
- expand detailed child specifications prematurely.
