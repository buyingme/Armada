# CON-007 Refinement Proposal --- Composed-Return Convergence

**Status:** Accepted\
**Target Contract:** CON-007 --- Post-Attack Continuation Release
Contract\
**Architectural Basis:** ODR-001 --- Composed-Return Convergence
Principle\
**Origin Evidence:** BUG-035\
**Scope:** Post-Attack continuation only\
**Implementation Authorization:** None

Accepted by: Project Owner
Accepted date: 2026-08-22

------------------------------------------------------------------------

# 1. Purpose

This document consolidates the Owner Q&A decisions for the proposed
CON-007 refinement.

The refinement addresses the convergence gap identified by BUG-035:

A child interaction may complete correctly, a valid release consumer may
execute correctly, and local verification may pass, while the enclosing
gameplay interaction remains unresolved.

The missing invariant is:

> After a release consumer terminates a child interaction, the enclosing
> purpose-specific interaction SHALL be re-evaluated until a stable
> outcome is reached.

This refinement is a narrow adoption of the composed-return convergence
principle defined by ODR-001.

It does not create a general continuation architecture.

------------------------------------------------------------------------

# 2. Architectural Principle

The composed-return convergence principle combines two requirements:

## A --- Observable convergence

Gameplay must not stop at an intermediate child completion, consumer
execution, or presentation event.

The system must converge until a stable gameplay outcome is reached.

## B --- Ownership preservation

Convergence SHALL be achieved through existing purpose-specific owners,
commands, and transitions.

The principle defines the required outcome, not a central implementation
mechanism.

------------------------------------------------------------------------

# 3. Owner Decisions Incorporated

## Q1 --- Core invariant

**Decision: Accept unchanged**

CON-007 shall adopt:

> Child interaction completion and enclosing interaction completion are
> separate semantic concepts.

A release consumer terminating a child interaction does not
automatically complete the enclosing gameplay hierarchy.

------------------------------------------------------------------------

## Q2 --- Stable outcome definition

**Decision: Accept unchanged**

A stable outcome is reached when either:

1.  A legal gameplay decision requiring controller input is live and
    recoverable; or
2.  Authoritative gameplay has reached a state where no further
    immediate authoritative transition is required.

A state is not stable while accepted gameplay rules require another
immediate automatic transition.

------------------------------------------------------------------------

## Q3 --- CON-007 scope boundary

**Decision: Preserve purpose-specific ownership**

CON-007 becomes the first normative adopter of composed-return
convergence.

CON-007 owns the convergence obligation after post-Attack release.

It does not own:

-   Ship Activation rules;
-   Ship Attack rules;
-   Squadron Activation rules;
-   Squadron Command rules;
-   Squadron Phase rules.

Existing purpose-specific owners remain authoritative.

------------------------------------------------------------------------

## Q4 --- CommandProcessor authority

**Decision: Bounded evaluation seam**

The CommandProcessor post-success seam may:

-   derive that further evaluation is required;
-   select or invoke an already applicable existing purpose-specific
    semantic transaction.

It may not:

-   own parent semantics;
-   define parent completion criteria;
-   own progression policy;
-   become a generic interaction hierarchy owner.

------------------------------------------------------------------------

## Q5 --- Anti-squadron exhaustion semantics

**Decision: Child termination only**

`SkipAttackCommand(reason: squadron_done)` remains a child interaction
termination command.

It:

-   closes exhausted anti-squadron iteration;
-   performs its existing authoritative mutation.

It does not:

-   decide Ship Attack continuation;
-   decide Maneuver availability;
-   advance Ship Activation directly.

The enclosing owner re-evaluates after the child interaction ends.

------------------------------------------------------------------------

## Q6 --- Verification philosophy

**Decision: Convergence-based verification**

Verification shall prove stable outcomes, not only intermediate events.

Insufficient terminal assertions:

-   inspection consumed;
-   consumer command executed;
-   modal closed;
-   UI restored;
-   intermediate mutation occurred.

Required terminal assertion:

The interaction hierarchy converged to either a recoverable live
decision or stable authoritative state.

------------------------------------------------------------------------

## Q7 --- Future adoption model

**Decision: Incremental explicit adoption**

Composed-return convergence is a general principle.

However, adoption is explicit per interaction family.

Each future interaction family must classify:

-   whether it participates;
-   where its continuation boundaries exist;
-   which owners remain authoritative.

Adoption is not automatic merely because an interaction can technically
return to an enclosing context.

No automatic repository-wide adoption is implied.

------------------------------------------------------------------------

## Q8 --- Branch matrix location

**Decision: Verification examples, not normative ownership**

Branch cases remain verification guidance.

They demonstrate the invariant but do not expand CON-007 ownership.

Examples include:

-   anti-squadron remaining target;
-   anti-squadron exhausted with remaining Ship Attack;
-   anti-squadron exhausted with Maneuver transition;
-   Squadron Activation return;
-   Squadron Command return;
-   Squadron Phase return.

------------------------------------------------------------------------

## Q9 --- Terminology

**Decision: Explicitly reference composed-return convergence**

CON-007 shall explicitly reference:

> ODR-001 --- Composed-Return Convergence Principle

Naming the principle provides traceability.

It does not create a universal composed-return contract.

------------------------------------------------------------------------

## Q10 --- Refinement scope

**Decision: Minimal additive refinement**

The CON-007 change shall be surgical.

It shall add:

-   ODR-001 traceability;
-   composed-return adoption statement;
-   stable outcome definition;
-   parent re-evaluation obligation;
-   convergence-focused verification expectations.

It shall not:

-   redesign CON-007;
-   create new architecture;
-   introduce new continuation infrastructure.

------------------------------------------------------------------------

# 4. Final Refinement Direction

The accepted direction is:

``` text
ODR-001
    |
    | defines composed-return convergence principle
    v
CON-007 refinement
    |
    +-- child completion != hierarchy completion
    |
    +-- parent re-evaluation required
    |
    +-- stable outcome required
    |
    +-- existing owners remain authoritative
    |
    +-- verification proves convergence
```

------------------------------------------------------------------------

# 5. Required CON-007 Refinement Content

The future contract edit shall introduce:

## Release boundary

Consumption of a completed-result inspection by an authorized consumer
does not by itself complete the enclosing interaction hierarchy.

Inspection consumption remains:

-   purpose-specific;
-   at-most-once;
-   tied to existing authoritative mutation paths.

## Parent re-evaluation obligation

After an authorized release consumer terminates or changes a child
interaction:

-   evaluation proceeds from canonical state through each applicable
    enclosing purpose-specific owner boundary;
-   existing commands and transitions perform authoritative progression;
-   evaluation continues until either a recoverable live legal decision is
    exposed or authoritative gameplay reaches a stable state requiring no
    further immediate transition.

## Ownership boundary

The post-success evaluation seam coordinates evaluation but does not
become a gameplay owner.

No:

-   generic continuation owner;
-   FSM;
-   interaction stack;
-   continuation command family;
-   canonical continuation state.

------------------------------------------------------------------------

# 6. Deferred Items

Deferred:

-   general composed-return contract;
-   adoption by other interaction families;
-   reaction-window adoption;
-   rule-granted attack adoption;
-   production implementation;
-   new commands, APIs, state, queues, stacks, managers, or FSMs.

------------------------------------------------------------------------

# 7. Next Workflow Step

After this Owner review draft:

1.  Run final architecture audit.
2.  Accept refinement proposal.
3.  Create a separate CON-007 contract-edit task.
4.  Resume BUG-035 implementation against the refined contract.
