# ADR-014: Canonical Immediate Faceup Damage-Card Resolution

Status: Accepted

ADR-ID: ADR-014

Title: Canonical Immediate Faceup Damage-Card Resolution

Accepted by: Project Owner

Accepted date: 2026-09-12

Decision owner: Project Owner

Binding decision input:

- Project Owner direction for the shared immediate faceup damage-card boundary,
  2026-09-12

Primary evidence:

- `Resources/Game_Components/damage_cards.json`
- `src/core/damage/damage_card.gd`
- `src/core/state/ship_instance.gd`
- `src/core/commands/resolve_immediate_effect_command.gd`
- `src/core/damage/immediate_effect_resolver.gd`
- `src/core/network/state_filter.gd`
- `src/core/damage/passive_damage_ledger.gd`
- `docs/architecture/rule_capability_packages/CAP-DMG-004-structural-damage.md`
- `docs/architecture/rule_capability_packages/CAP-DMG-005-projector-misaligned.md`
- `docs/architecture/rule_capability_packages/CAP-DMG-006-life-support-failure.md`
- `docs/architecture/rule_capability_packages/CAP-DMG-007-injured-crew.md`
- `docs/architecture/rule_capability_packages/CAP-DMG-008-shield-failure.md`
- `docs/architecture/rule_capability_packages/CAP-DMG-009-comm-noise.md`
Related:

- RG-003
- RG-004
- RG-005
- RG-013
- BC-001
- BC-003
- BC-005
- BC-005A
- BC-007
- BC-008
- BC-009
- ADR-001
- ADR-003
- ADR-006
- ADR-010
- ADR-012
- ADR-013
- CON-001
- CON-003
- TEST-003
- CAP-DMG-004 through CAP-DMG-009

Supersedes:
None

Superseded by:
None

## Acceptance note

The Project Owner has selected the canonical owner, identity, recovery,
enclosing-context, exact-once, and passive-visibility boundaries for immediate
faceup damage-card resolution. This ADR records those settled decisions.

Acceptance establishes normative architecture only. It does not authorize
production implementation, create an implementation workbook, change any card
rule, or advance a Rule Capability Package's CON-003 integration status.

An RCP may be explicitly Owner-accepted as a **normative Draft**. `Draft`
describes incomplete implementation/evidence maturity; it does not mean that
the Draft's reviewed normative content is unaccepted. `Integrated` remains a
later and separate CON-003 evidence state requiring complete applicable
evidence and explicit Owner approval.

## 1. Context and scope

Six existing immediate damage-card behaviors share one missing canonical
boundary. Current production places faceup and facedown card objects on
`ShipInstance` and resolves mutations through a semantic command, but it lacks
stable physical card identity and one recoverable owner-local fact for the
currently unresolved immediate obligation. Existing attack and debug
presentation paths also retain mutable array indices or scene-local references.

No existing accepted ADR owns the complete boundary:

- ADR-006 owns ship activation and the purpose-specific active Maneuver
  execution, not general damage-card identity or non-Maneuver resolution.
- ADR-010 requires decision-equivalent recovery but deliberately creates no new
  canonical state owner.
- ADR-012 owns live Network RNG authority and command-owned passive result
  application, not damage-card occurrence identity.
- ADR-013 owns the passive damage representation and concealment boundary, not
  authoritative unresolved immediate-resolution ownership.

Amending any one of those ADRs with the complete cross-context boundary would
distort its scope. This ADR therefore decides only physical damage-card
identity and immediate faceup damage-card obligation ownership, validation,
recovery, completion, and visibility. It does not define the six card rules.

## 2. Decision

### 2.1 Physical damage-card ownership and identity

On authority, each physical damage-card instance SHALL have stable canonical
identity. Duplicate copies of the same card type SHALL remain distinguishable
physical instances even when their title, trait, effect id, timing, and rules
text are equal.

Canonical ownership follows physical location without duplication:

1. The authoritative damage deck owns cards in its draw and discard piles.
2. When a card is dealt to a ship, that `ShipInstance` becomes the canonical
   owner of that physical instance while it remains assigned to the ship,
   whether faceup or facedown.
3. A repair or other accepted transition that returns a card to the discard
   pile transfers canonical ownership back to the authoritative damage deck.

An owner stores the physical instance once. Resolution records, commands,
projection, transport, and UI SHALL reference it; they SHALL NOT copy it into a
second writable gameplay owner. Card type or `effect_id` identifies applicable
rules but SHALL NOT identify a physical occurrence.

Stable authority identity is a canonical implementation fact. It is not
inherently public gameplay information.

### 2.2 Ship-owned active immediate-resolution record

A `ShipInstance` SHALL own at most one applicable active immediate-damage
resolution record for an unresolved immediate faceup damage-card obligation on
that ship. The record is a narrow gameplay fact subordinate to the
ShipInstance-owned physical card; it is not a new top-level gameplay owner.

The record MAY retain only facts required to recover and validate that specific
obligation, as applicable:

- source physical damage-card instance identity;
- damaged ship identity when not already inherent in the owner;
- the rules-assigned chooser or participant;
- the minimum legal-choice facts needed for decision-equivalent recovery and
  authoritative validation;
- one purpose-specific enclosing identity from Section 2.4; and
- exact-once unresolved/resolved obligation facts.

The record SHALL NOT contain a callback, route, arbitrary next command,
arbitrary continuation token, queue, stack, phase or stage machine, workflow
FSM, or arbitrary pending-work payload. It SHALL NOT become a generic command
executor, generic immediate-effect owner, generic continuation owner, or
generic Maneuver consequence owner.

An active resolution record and a pending player interaction are distinct.
Zero-choice automatic resolution SHALL NOT create an impossible pending player
decision. An automatic obligation MAY remain canonically unresolved only across
a real semantic command/recovery boundary and SHALL then complete without
player input. A record carries chooser state only while genuine rules-assigned
gameplay work remains.

#### Atomic obligation establishment

When a legal authoritative source assigns an immediate faceup damage card to a
ship, the accepted transaction SHALL atomically either:

1. assign the physical card and establish exactly one matching unresolved
   immediate-resolution record on that ShipInstance; or
2. only when the complete immediate obligation is automatic and the accepted
   architecture permits it, assign the card and resolve the complete immediate
   obligation in that same accepted transaction.

An unresolved immediate faceup obligation SHALL never exist without its
matching canonical record. The source transaction establishes the obligation;
it does not transfer dealing authority to the later resolving command. The
ShipInstance continues to own at most one active immediate-resolution record.

This mandatory atomic establishment is the exact-once boundary for cards whose
immediate and persistent halves have different lifetimes. Absence of an active
record may mean that the immediate half has already resolved only because every
assignment was required to establish and retire its obligation atomically.
Life Support Failure may therefore remain faceup after its immediate half
resolves without a generic permanent workflow flag. Recycling, reassigning, or
redealing that physical card later creates a new obligation scoped to the new
assignment and purpose-specific enclosing identity. A generic
`immediate_resolved` field SHALL NOT be introduced unless later repository
evidence establishes a separate accepted need.

### 2.3 Authoritative validation, mutation, and exact-once completion

Only the resolving authoritative semantic command owns card-specific
immediate-resolution mutation. It does not thereby own dealing, repair,
removal, discard, destruction, reassignment, or unrelated card-lifecycle
transitions. Before immediate-resolution mutation it SHALL validate, as
applicable:

- the stable physical source-card identity and its current faceup ownership by
  the damaged ship;
- the unresolved ShipInstance record;
- the damaged ship and its survival;
- the rules-assigned chooser/participant;
- the currently legal choice or automatic outcome;
- the matching purpose-specific enclosing identity; and
- command/application identity, ordering, and exact-once eligibility.

Presentation, `InteractionFlow`, controllers, transport, and passive result
handlers SHALL NOT become alternate immediate-resolution validation or mutation
owners.

On acceptance, the command SHALL atomically apply the applicable card rule and
retire or resolve the matching obligation. A stale, duplicated, wrong-card,
wrong-ship, wrong-actor, wrong-enclosure, out-of-order, or already-resolved
submission SHALL fail without mutation or enclosing return.

Mandatory atomic obligation establishment and retirement SHALL prevent an
assignment's immediate obligation from reopening. It SHALL NOT create a second
authority, generic resolution registry, or permanent per-card workflow flag.

Ordinary faceup-to-facedown completion required by the immediate rule is owned
by the resolving command and SHALL atomically retire the matching record.
Unrelated repair, removal, discard, flip, or reassignment that would invalidate
the active source card SHALL reject while its immediate obligation is
unresolved. An accepted rule MAY instead own an atomic transition that
explicitly resolves or terminates the matching obligation as part of the same
authoritative mutation. Silent deletion of either the source card or its active
obligation is forbidden.

Destruction SHALL atomically invalidate the matching immediate-resolution
record and transfer or remove assigned card ownership according to the accepted
damage-card lifecycle. No card-lifecycle transition may leave a dangling
immediate-resolution record.

### 2.4 Purpose-specific enclosing identity and composed return

An immediate damage-card obligation SHALL bind to its actual legal source using
the applicable purpose-specific identity:

- **Attack:** the matching canonical `CurrentAttackState` identity governed by
  ADR-001.
- **Maneuver:** the matching `ship_activation_identity` and active ADR-006
  Maneuver-execution identity.
- **Debug-authoritative:** the purpose-specific identity created by the
  accepted authoritative debug dealing command/application when it assigns the
  physical card. That source owns the identity for the lifetime of the debug
  application and matching immediate obligation. It creates neither a
  synthetic gameplay parent nor a live Network debug exception to ADR-013.
- **Future legal sources:** their own accepted purpose-specific identity before
  they may invoke this boundary.

These identities are a closed set of purpose-specific alternatives. They SHALL
NOT be collapsed into an opaque continuation id, arbitrary route, or generic
next-work descriptor.

After successful resolution from a source with a gameplay parent, control
returns through that enclosing owner's accepted composed-return architecture.
The card command does not decide the enclosing owner's next gameplay step. The
enclosing owner revalidates its own identity and remaining work before
continuing or completing. Successful debug resolution is terminal: it has no
gameplay composed return, and debug SHALL NOT create a synthetic gameplay
parent merely to provide a continuation target.

Destruction atomically invalidates and clears ship-dependent nested immediate
resolution state. Destruction of an attack defender does not inherently destroy
the `CurrentAttackState` owner; accepted Attack terminal cleanup still occurs
where applicable. Destruction of the actively maneuvering ship invalidates its
corresponding ADR-006 ship-activation/Maneuver-execution parent and suppresses
normal return to that nonexistent boundary. Cleanup SHALL be idempotent and
SHALL NOT leave an actionable projection or unresolved record on a destroyed
ship.

### 2.5 Recovery, serialization, and replay

Authoritative save/load SHALL serialize and restore:

- stable physical card identity and its single canonical location;
- the ShipInstance-owned active immediate-resolution record when an obligation
  is genuinely unresolved;
- rules-assigned actor and the minimum authoritative choice facts;
- the purpose-specific enclosing identity; and
- exact-once state sufficient to reject repeated resolution.

Installation SHALL reject duplicate physical identities, conflicting locations,
more than one applicable active immediate record on a ship, a record whose card
is not faceup and ship-owned, an invalid actor, or a mismatched enclosing
identity.

Save/load, scene reconstruction, Hot-Seat handoff, Network reconnect, and other
supported recovery paths SHALL yield decision-equivalent automatic or player
decision semantics from authoritative state. Transient UI objects, callbacks,
array positions, and prior presentation history SHALL not be required.

Replay SHALL retain the full authoritative damage model, deterministic seed,
stable physical identities, semantic command history, and purpose-specific
enclosing state. It SHALL re-execute accepted commands in authoritative order
and SHALL NOT depend on live passive transaction identities, passive ledgers,
or UI-local state.

### 2.6 Network/passive identity and concealment

ADR-012 and ADR-013 remain authoritative for live Network result application
and passive damage representation. The authority retains stable physical card
identity. A passive peer receives only viewer-authorized semantics needed to
render or validate its current legal participation.

ADR-013 references to a public faceup-card "identity" mean public card/type
semantics or viewer-authorized occurrence semantics. They do not imply exposure
of ADR-014's stable authority physical-card identity.

While a card is publicly faceup, a passive representation MAY carry the
narrowest existing architecture-compatible filtered or transaction identity
needed for the current command/result and recoverable decision. It SHALL NOT
expose the authority's stable physical identity merely because the card is
faceup.

When a card becomes facedown:

- its passive public `DamageCard` object and any faceup-resolution identity are
  removed atomically;
- only the ADR-013 facedown count remains on the ship;
- command intent, exposed history, result payloads, logs, diagnostics, saves,
  reconnect state, and projection SHALL NOT retain an identity that correlates
  that formerly faceup physical card with the later hidden card; and
- a later public appearance SHALL not reuse a passive identifier that reveals
  the intervening facedown identity.

A transient or viewer-filtered transaction identity MAY be used where command
or result validation requires one. It SHALL be scoped to the current public
transaction/decision, removed when no longer authorized, and incapable of
persistent faceup-to-facedown correlation. The concrete representation SHALL
reuse the narrowest accepted command/result/filtering mechanism available. This
ADR does not authorize a generic identity, secret-object, or token framework.

Passive peers SHALL NOT synthesize automatic resolution, shuffle or draw hidden
cards, originate composed returns, or reconstruct authority-only identities.
They validate and apply viewer-authorized realized facts through the resolving
command's ADR-012/013-compatible application boundary.

### 2.7 Decision-shape boundary

A genuine unresolved player decision SHALL have recoverable canonical
obligation state containing the rules-assigned chooser and only the legal-choice
facts needed for recovery and validation. An automatic branch SHALL NOT create
an artificial pending choice. A sole remaining effect may still contain a
genuine internal player decision; that decision remains canonical until
resolved. Card-specific legality belongs to its CON-003 Rule Capability Package,
not this ADR.

## 3. Architectural invariants

1. A physical damage card has one stable authority identity and one canonical
   location/owner at a time.
2. `ShipInstance` canonically owns every physical damage-card instance assigned
   to that ship.
3. Duplicate copies of the same card type are distinguishable on authority.
4. A ShipInstance has at most one applicable active unresolved immediate-damage
   resolution record.
5. Assignment atomically establishes the matching unresolved record or, only
   for a permitted fully automatic obligation, resolves it completely.
6. The active record references rather than duplicates its source physical card.
7. Card type/effect id selects behavior but never identifies the occurrence.
8. Only the resolving semantic command owns card-specific
   immediate-resolution mutation.
9. Exact-once validation rejects stale, duplicate, wrong-actor, wrong-card,
   wrong-ship, wrong-enclosure, and out-of-order submissions.
10. Active-source invalidation rejects or atomically resolves/terminates the
    matching obligation; it never silently deletes or strands either fact.
11. Pending player interaction exists only for genuine unresolved decisions.
12. Attack, Maneuver, debug, and future sources retain distinct accepted
    purpose-specific identities; debug resolution is terminal.
13. Attack defender destruction preserves applicable Attack cleanup, while
    active-maneuver-ship destruction suppresses return to its invalidated
    Maneuver parent.
14. Authoritative save/load and replay preserve full physical identity,
    ownership, exact-once state, and enclosing identity.
15. Reconnect reconstructs only viewer-authorized decision-equivalent semantics.
16. Passive state cannot correlate a formerly faceup card with its later
    facedown hidden physical identity.
17. Passive peers do not synthesize resolution or composed-return commands.
18. This boundary introduces no generic continuation, pending-work, identity,
    immediate-effect, or Maneuver consequence framework.

## 4. Relationship to accepted architecture

| Existing authority | Normative relationship |
| --- | --- |
| ADR-001 | Preserved. Attack retains `CurrentAttackState` identity and owns post-resolution attack continuation/completion. |
| ADR-003 / CON-003 | Preserved. Each card retains a distinct RCP and responsibility-specific implementation/test evidence. This ADR supplies shared architecture, not rule integration status. |
| ADR-006 | Preserved. `ShipInstance` remains the Maneuver/activation owner. Immediate resolution binds to, but neither duplicates nor redesigns, the active Maneuver execution. |
| ADR-010 | Specialized. The ShipInstance record supplies authoritative facts from which immediate-card decision-equivalent recovery is derived; presentation remains non-authoritative. |
| ADR-012 | Preserved. Authority alone resolves hidden randomness; passive peers apply viewer-authorized command-owned results and do not synthesize follow-ups. |
| ADR-013 | Preserved and specialized. Public faceup identity means public type/viewer-authorized occurrence semantics, not authority physical identity; authority stable identity does not enter the passive facedown representation, and the filtered ledger remains the only passive hidden damage state. |
| CON-001 | Preserved. Semantic commands retain validation, atomicity, history, ordering, rollback, and fail-closed ownership. |
| TEST-003 | Applicable. Interactive cards require the full lifecycle matrix; automatic branches use the justified reduced subset while still proving recovery and continuation. |

No accepted owner is replaced and no duplicate writable authority is created.

## 5. Current implementation compatibility and gaps

Current `ShipInstance` faceup/facedown collections already establish the
compatible entity-local ownership direction. `DamageDeck` already owns cards
before dealing and after discard. `ResolveImmediateEffectCommand` already owns
production mutation, and ADR-012/013 command application and passive ledger
paths provide compatible distributed primitives.

Implementation does not yet conform fully:

- `DamageCard` has no stable physical instance identity;
- commands and pending projections use mutable faceup array indices;
- `ShipInstance` has no canonical active immediate-resolution record;
- dealing does not yet prove atomic obligation establishment or fully automatic
  completion;
- chooser and enclosing identity are not completely command-validated;
- Attack/debug presentation retains transient object references in places;
- debug identity lifetime and terminal completion are not yet explicit in
  production boundaries;
- no purpose-specific ADR-006 Maneuver binding/return exists;
- card lifecycle transitions do not yet prove rejection or atomic termination
  of an active obligation;
- destruction cleanup does not yet prove atomic nested-state invalidation and
  context-specific Attack/Maneuver completion;
- decision-equivalent save/load/reconnect coverage is incomplete; and
- passive effect-specific projection and faceup-to-facedown correlation tests
  are incomplete.

These are implementation/evidence gaps. They do not create a competing
architecture option.

## 6. Explicit non-goals

This ADR does not define:

- concrete field names, serialized schemas, transaction-token formats,
  protocol/save/replay version numbers, commands, or implementation slices;
- a generic continuation owner, callback, arbitrary next-command field, queue,
  stack, phase/stage machine, workflow FSM, or pending-work container;
- a generic immediate-effect, identity, hidden-state, or Maneuver consequence
  framework;
- any of the six card-specific gameplay rules or their detailed legality;
- damage-deck recycling, shuffle, or RNG ownership beyond preserving ADR-012
  and ADR-013;
- UI composition or modal design;
- production changes, an implementation workbook, or BUG-043 reconciliation;
  or
- integration of CAP-DMG-004 through CAP-DMG-009.

Shared low-level serialization, filtering, validation, and command-application
helpers remain allowed when they do not own card rules or enclosing gameplay.

## 7. Acceptance and integration boundary

This ADR is Accepted from the explicit Project Owner decisions recorded above.
Acceptance permits later implementation planning and coordinated RCP refinement
against this boundary; it does not itself authorize implementation.

CAP-DMG-004 through CAP-DMG-009 remain `Draft`. Each may later record explicit
Owner acceptance of its normative Draft content without changing that evidence
status. Progression to `Identified`, `Implemented`, or `Tested` follows CON-003
evidence. `Integrated` requires complete applicable evidence and a separate
explicit Owner approval; neither acceptance of this ADR nor acceptance of an
RCP as a normative Draft grants `Integrated` status.

## 8. Related documents

- `docs/architecture/DOCUMENT_AUTHORITY.md`
- `docs/architecture/adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md`
- `docs/architecture/adr/ADR-003-rule-and-validation-surfaces.md`
- `docs/architecture/adr/ADR-006-canonical-ship-activation-boundary-ownership.md`
- `docs/architecture/adr/ADR-010-gameplay-interaction-decision-equivalent-recovery.md`
- `docs/architecture/adr/ADR-012-live-network-rng-authority-and-result-application.md`
- `docs/architecture/adr/ADR-013-passive-network-damage-state-representation.md`
- `docs/architecture/contracts/CON-003-rule-capability-contract.md`
- `docs/architecture/tests/TEST-003-interactive-rule-timing-window-verification.md`
- `docs/architecture/rule_capability_packages/CAP-DMG-004-structural-damage.md`
- `docs/architecture/rule_capability_packages/CAP-DMG-005-projector-misaligned.md`
- `docs/architecture/rule_capability_packages/CAP-DMG-006-life-support-failure.md`
- `docs/architecture/rule_capability_packages/CAP-DMG-007-injured-crew.md`
- `docs/architecture/rule_capability_packages/CAP-DMG-008-shield-failure.md`
- `docs/architecture/rule_capability_packages/CAP-DMG-009-comm-noise.md`
