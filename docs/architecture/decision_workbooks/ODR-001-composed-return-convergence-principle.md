# ODR-001 --- Composed-Return Convergence Principle

**Status:** Accepted\
**Document type:** Owner Decision Record\
**Location:**
`docs/architecture/decision_workbooks/ODR-001-composed-return-convergence-principle.md`

Accepted by: Project Owner
Accepted date: 2026-08-22

**Scope:** Gameplay interaction architecture\
**Origin evidence:** BUG-035 --- repeated post-Attack continuation
convergence failures\
**Initial normative adoption target:** CON-007 refinement\
**Related authorities:** ADR-001, ADR-006, ADR-007, ADR-010,
CON-006, CON-007, Ship Activation interaction requirements

------------------------------------------------------------------------

# 1. Purpose

This Owner Decision Record captures the architectural principle derived
from the BUG-035 investigation regarding nested gameplay interaction
completion and return to enclosing gameplay contexts.

The purpose is not to introduce a generic continuation framework.

The purpose is to define:

-   the required gameplay convergence outcome;
-   the ownership boundaries that must remain intact;
-   the verification expectations for nested gameplay interactions.

BUG-035 demonstrated that local correctness proofs were insufficient. A
child interaction could correctly:

-   complete;
-   consume its inspection/result lifecycle;
-   execute its consumer command;
-   pass focused automated tests;

while the enclosing gameplay hierarchy remained unresolved.

Therefore acceptance must prove composed interaction convergence, not
only correctness of individual transitions.

------------------------------------------------------------------------

# 2. Core architectural decision

## Decision

Observable rule:
Gameplay must converge.

Ownership rule:
Existing purpose-specific owners remain authoritative.

Adoption rule:
Interaction families explicitly classify composed-return participation.

The long-term architecture target is a general composed-return
convergence principle:

> When a nested gameplay interaction completes, gameplay must converge
> through the existing enclosing purpose-specific interaction boundaries
> until it reaches either a recoverable live gameplay decision or an
> accepted stable gameplay state.

This defines the required observable gameplay outcome.

It does not define a central implementation mechanism.

The implementation model remains purpose-specific:

-   each enclosing interaction owns its own semantic decisions;
-   each enclosing interaction owns its own authoritative transitions;
-   composed return only ensures that existing owners are evaluated
    until convergence.

------------------------------------------------------------------------

# 3. A+B hybrid model

The composed-return principle combines two requirements.

## Observable requirement (A)

Gameplay must not stop at an intermediate child completion.

``` text
Child interaction completes
        |
        v
Immediate parent re-evaluates
        |
        +----------------+
        |                |
        v                v
Live decision      Automatic transition required
        |                |
        v                v
Recover/present    Existing authoritative
decision           command/transition
        |                |
        +--------+-------+
                 |
                 v
          Continue through
          enclosing owners
                 |
                 v
          Stable outcome
```

## Ownership mechanism (B)

The mechanism remains purpose-specific.

Composed return does not introduce:

-   a generic continuation owner;
-   a global continuation manager;
-   a generic cross-context continuation FSM;
-   a serialized interaction stack;
-   UI/controller-owned progression;
-   duplicate mutation paths.

------------------------------------------------------------------------

# 4. Stable outcome definition

A composed-return flow has converged when one of the following is true:

1.  A legal gameplay decision requiring controller input is live and
    recoverable.

or

2.  Authoritative gameplay has progressed to a stable state where no
    further immediate continuation is required.

A state is not stable if accepted gameplay rules require another
immediate automatic transition.

------------------------------------------------------------------------

# 5. Authoritative automatic progression

When composed-return evaluation determines that an enclosing interaction
has no remaining player decision but an authoritative transition is
required:

-   the existing purpose-specific command/transition mechanism performs
    the progression;
-   composed return only derives that progression is required;
-   recovery logic never directly mutates gameplay state.

The command/transition path remains identical to normal gameplay.

------------------------------------------------------------------------

# 6. Intermediate consumer commands

A command terminating a nested interaction does not automatically
terminate the composed-return obligation.

Example:

``` text
Attack completion
        |
        v
Anti-squadron iteration exhausted
        |
        v
SkipAttackCommand(reason: squadron_done)
        |
        v
Anti-squadron interaction ends
        |
        v
Re-evaluate enclosing Ship Attack opportunity
        |
        v
Continue until stable outcome
```

Consumption of a completed-result inspection and completion of the wider
gameplay hierarchy are separate concerns.

------------------------------------------------------------------------

# 7. Live decision recovery

If re-evaluation exposes a live legal player decision:

-   the decision itself is the stable outcome;
-   legal choices are derived from authoritative state;
-   presentation reconstructs the decision;
-   no synthetic command is created only to open UI.

Semantic commitment continues through existing authoritative command
paths.

------------------------------------------------------------------------

# 8. Owner-validated context decisions

## Ship Attack / anti-squadron

Anti-squadron exhaustion terminates only the anti-squadron interaction.

The enclosing Ship Attack opportunity is re-evaluated:

``` text
Anti-squadron iteration ends
        |
        v
Ship Attack re-evaluates
        |
        +----------------+
        |                |
        v                v
Another attack      No attack remains
exists              |
        |           v
        v       Ship Attack completion
Recover attack       |
decision             v
                 Maneuver
```

`SkipAttackCommand(reason: squadron_done)` only terminates the immediate
anti-squadron interaction.

It does not directly advance the ship to Maneuver.

------------------------------------------------------------------------

## Squadron Activation

When an Attack completes inside Squadron Activation:

-   return to the enclosing Squadron Activation;
-   Squadron Activation determines whether another legal action remains;
-   Shared Attack does not determine Squadron Activation continuation.

------------------------------------------------------------------------

## Squadron Command

When a commanded Squadron Activation completes:

-   return to Squadron Command;
-   Squadron Command owns remaining capacity and eligible activation
    decisions.

If Squadron Command becomes terminal:

-   Squadron Command uses its existing authoritative completion
    mechanism;
-   the enclosing Ship Activation owner determines the next applicable
    Ship Activation step. This is an ownership rule, not merely a sequencing
    rule.

The composed-return principle does not hard-code Repair as the next
step.

The Squadron Activation itself never advances directly to Repair.

------------------------------------------------------------------------

## Squadron Phase

When a Squadron Activation completes during Squadron Phase:

-   return to Squadron Phase allocation/turn ownership;
-   Squadron Phase determines the next step;
-   Shared Squadron Activation does not determine phase progression.

------------------------------------------------------------------------

# 9. Normative adoption strategy

The general composed-return principle is the target state.

CON-007 is the first normative adopter because BUG-035 evidence is
within post-Attack continuation.

Initial adoption:

-   amend CON-007;
-   preserve the broader principle as a roadmap/future architecture
    item;
-   do not create a generic composed-return contract immediately.

A future ADR/contract may be introduced when another interaction family
adopts the principle.

------------------------------------------------------------------------

# 10. Explicit composed-return classification

Interaction families that adopt or may participate in composed-return
boundaries must explicitly classify their composed-return participation
during requirements/contract work. The classification must not be inferred
only during implementation.

If an interaction can return control to an enclosing gameplay context:

-   composed-return convergence becomes a mandatory acceptance
    criterion;
-   verification must continue until a stable outcome is reached.

A successful intermediate consumer command is not sufficient proof of
correct continuation.

------------------------------------------------------------------------

# 11. Verification principle

Future verification must prove:

``` text
Completed child interaction
        |
        v
Required consumer commands/transitions
        |
        v
Parent re-evaluation
        |
        v
Further enclosing transitions if required
        |
        v
Stable outcome
```

Tests must not stop at:

-   successful consumer command;
-   cleared inspection;
-   closed modal;
-   restored panel;
-   intermediate state mutation.

The terminal assertion is stable gameplay convergence.

------------------------------------------------------------------------

# 12. Review status

This Owner Decision Record has been accepted by the Project Owner.

Future refinements should preserve the accepted decisions unless superseded
by a later Owner decision.
