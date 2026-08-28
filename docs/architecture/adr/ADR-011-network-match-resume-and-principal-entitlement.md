# ADR-011: Network Match Resume and Session-Local Controller Assignment

Status: Accepted

ADR-ID: ADR-011

Title: Network Match Resume and Session-Local Controller Assignment

Accepted by: Project Owner

Original accepted date: 2026-08-26

Amended by Project Owner: 2026-08-27

Decision owner: Project Owner

Binding decision source:

- `docs/architecture/decision_workbooks/ODR-003-network-match-resume-and-replacement-principal-entitlement.md`

Supersedes:

- ADR-011's 2026-08-26 persistent-human-entitlement requirements, as detailed
  in Section 8

Superseded by:
None

Related:

- ADR-008
- ADR-010
- MATCH-001
- MATCH-002 as implementation/design evidence only
- AT-006
- AT-008
- AT-009
- BC-006
- BC-007
- BC-008
- RG-007
- RG-013
- RG-016

## Acceptance note

The Project Owner amended ODR-003 and this ADR on 2026-08-27. Persistent proof
that a resumed human is the human who previously controlled a saved side is no
longer a product requirement. Fresh-session Network resume instead uses
explicit, host-authoritative, pre-publication assignment of connected humans to
the unchanged saved canonical player sides.

This amendment authorizes no implementation. Accepted MATCH-001 remains the
current binding and fail-closed implementation boundary until a separately
authorized implementation replaces the fresh-session restriction. MATCH-002's
RSA capability/verifier/credential design is non-normative implementation
evidence where it conflicts with this amendment and must not be repaired in
place as part of this decision change.

## 1. Context and scope

ADR-008 establishes an immutable match-lifetime binding between gameplay
players and durable match principals, separate from transient Network peers.
MATCH-001 implements that boundary and currently permits a Network load only in
the same live match when the loaded binding exactly matches the live binding
and all existing associations remain valid.

The original ADR-011 required each human claimant to prove possession of a
persistent match-scoped capability before fresh resume or reconnect. That
workflow is disproportionate to the current product requirement. The product
does not need to prove continuity of a physical person across sessions. It does
need to preserve canonical saved game-side identity and establish unambiguous
current-session command authority.

This ADR decides only the fresh-session Network resume assignment policy and
the corresponding reconnect rule after that resumed session becomes live. It
does not create a generic controller framework or broaden scope into bot
support.

## 2. Retained canonical authority

The following remain normative:

1. **Canonical gameplay state.** `GameState` remains the canonical owner of the
   restored gameplay facts, including the saved match-player-control binding
   and every fact required to reconstruct the next legal gameplay decision or
   accepted stable state.
2. **Durable canonical control identity.** The saved principal records, kinds,
   and gameplay-player mapping are restored exactly and remain immutable for
   the match lifetime.
3. **Concept separation.** Gameplay player, match principal, physical human,
   current Network endpoint, and presentation/controller state are distinct.
4. **Transient session association.** Current endpoint-to-existing-principal
   association is host-held runtime Network state. It is not canonical gameplay
   state and never becomes a principal-rebinding surface.
5. **Gameplay legality.** Existing rule, turn, initiative, activation, attack,
   timing, and command validators continue to decide whether an action is
   legal. Association answers only whether the submitter may act for the
   applicable canonical side.
6. **Presentation.** Viewer-specific UI, modals, camera, waiting state, and
   other presentation are re-derived and do not assign a side, establish
   canonical identity, or progress gameplay.

For this decision, a saved `HUMAN` principal is a durable match-scoped
canonical control identity. Its classification does not prove or require that
the same physical human controls it in a later session. A new human controller
may exercise that unchanged identity through a transient session association.

## 3. Session-local controller association

A fresh-resume controller association represents exactly this current-session
authority:

> A particular connected human endpoint may submit player-originated input for
> a particular saved canonical player side, through the unchanged saved
> principal bound to that side.

It does not represent:

- continuity or authentication of a physical person;
- a global account, installation identity, or profile identity;
- ownership of the save;
- replacement, rebinding, creation, deletion, or reclassification of a saved
  principal;
- authority derived from host/client role, lobby position, readiness order,
  player index, peer ID, display name, or UI state; or
- permission to bypass gameplay legality.

The association may be staged while the save is validated. It becomes
authoritative for the resumed session only when the authoritative host commits
the complete and exclusive assignment set at the pre-publication boundary. It
ends when the applicable endpoint association or Network session ends.

## 4. Fresh-session resume and publication

### 4.1 Assignment authority

The authoritative session host is the sole authority that establishes the
current-session assignments. The host SHALL explicitly assign every
participating connected human endpoint, including the host endpoint, to a saved
canonical player side before publication.

The host may assign itself to either saved side. The client may be assigned to
the other side. This is an explicit choice; gameplay side SHALL NOT be derived
automatically from host/client role, connection order, lobby slot, readiness,
display name, profile ID, peer ID, or prior-session endpoint identity.

UI selection, proposal, confirmation, and consent details are implementation
design. Whatever UI is selected, only the host's validated complete assignment
commit establishes authoritative session associations.

### 4.2 Completeness and exclusivity

For the current two-human Network resume shape, the committed assignment SHALL
be a one-to-one mapping between the two participating connected human endpoints
and the two saved human-controlled canonical player sides:

1. every saved human-controlled side has exactly one assigned endpoint;
2. every participating endpoint is assigned to exactly one saved side;
3. no endpoint or saved side is duplicated;
4. no association conflicts with another staged or active association; and
5. the assignment resolves through the exact saved principal binding without
   modifying it.

Missing, incomplete, ambiguous, duplicate, or competing assignment SHALL block
publication. Partial fresh resume, absent-human progression, shared control,
and spectator participation are not created by this ADR.

### 4.3 Ordering and atomicity

A successful fresh-session resume SHALL preserve this conceptual ordering:

```text
validated save artifact
  -> exact canonical gameplay reconstruction
  -> immutable saved principal binding preserved
  -> explicit connected-human-to-saved-side assignments staged
  -> completeness and exclusivity validated
  -> transient endpoint-to-existing-principal associations committed
  -> correctly filtered endpoint state installed/acknowledged
  -> canonical restored match published as live
  -> player-originated command admission enabled
  -> next legal gameplay decision or accepted stable state recovered
  -> viewer-specific presentation re-derived
```

Preparation may stage the candidate and proposed assignments, but the complete
set SHALL succeed atomically from the perspective of live gameplay. No partial
restored match, principal-dependent player input, or side-specific hidden
information may be published through an incomplete or conflicting assignment.

Canonical reconstruction SHALL restore the accepted command sequence or
cursor and every canonical fact required for the next legal decision or
accepted stable state. It SHALL NOT repair state with inferred progression,
synthetic gameplay commands, or presentation callbacks.

## 5. Competing assignment and reconnect

At most one active endpoint association SHALL exist for each saved HUMAN
principal/player side. A new assignment SHALL fail while an incumbent
association remains active or its loss has not been confirmed. The host SHALL
NOT silently evict an incumbent merely to assign another endpoint.

After confirmed disconnect or association loss:

1. the host invalidates only the transient association;
2. the canonical principal, principal kind, gameplay state, and saved mapping
   remain unchanged;
3. player-originated command admission for that side remains closed;
4. the host may explicitly assign the unoccupied side to a connected endpoint;
5. the endpoint receives and acknowledges only the correctly filtered current
   state; and
6. command admission for that side reopens only after the new association and
   reconstruction gates succeed.

The endpoint may represent the previous human or a different human. Reconnect
does not require a persistent credential and SHALL NOT infer side from a freed
slot, host/client role, reused peer ID, display name, or profile ID. It does not
reload or republish the host's canonical match.

## 6. Save trust and portability

The controller-assignment policy does not require the original physical host,
original host role, original host-side human, or an entitlement-verifier
installation. A current host with a valid supported save could, in principle,
perform the explicit assignment regardless of which saved side that host's
human selects.

This ADR does not, however, establish that a copied save is authentic,
readable, discoverable, or supported on another installation. The current
original-save-owning-installation restriction therefore remains the supported
MVP boundary under existing save-integrity and file-storage authority, not as a
human-entitlement rule.

Cross-host, cross-installation, cross-device, cloud, and copied-save
portability require a separate Owner decision and corresponding save-integrity,
file-transfer, compatibility, and UX design. Portability does not follow merely
from removing persistent human credentials.

## 7. Relationship to existing authority and capabilities

| Existing authority/capability | Relationship to amended ADR-011 |
| --- | --- |
| ADR-008 | Retained for `GameState` ownership, immutable gameplay-player/principal binding, mode/cardinality semantics, and separation of gameplay player, principal, peer, and UI state. ADR-011 narrowly supersedes ADR-008 Section 9's anticipated match-scoped proof requirement for fresh resume/reconnect: accepted host-authoritative explicit assignment is now sufficient current-controller authority, while fail-closed association and no-rebinding rules remain. |
| ADR-010 | Retained for decision-equivalent recovery and non-authoritative presentation. Assignment cannot synthesize progression or change the recovered decision. |
| MATCH-001 | Retained as accepted implementation authority for canonical binding, command authorization, save/replay durability, same-live-match load, and the current fail-closed fresh-lobby gate. This ADR defines the later replacement for that fresh-session gate but does not authorize implementation. |
| MATCH-002 | Implementation/design evidence only. Its staged publication, filtering, association, reconnect, and verification seam analysis may be reused. Its RSA capability, verifier registry, credential store, challenge proof, capability UI, and credential-driven compatibility requirements conflict with this amendment and are not requirements. |
| Hot-Seat | Unchanged. Its one HUMAN principal controls both gameplay sides; no Network fresh-session assignment protocol is introduced. |
| Same-live-match Network load | Unchanged. It retains the exact-binding and still-valid-association gate and does not reassign controllers. |
| Replay | Unchanged. It reconstructs saved historical canonical identity without live peer association, live entitlement, or session controller assignment. |
| Hidden information | The validated assignment determines the filtered view delivered to each endpoint. Role, lobby order, and incomplete proposals grant no view authority. |
| Command authorization | The host resolves endpoint -> committed session association -> unchanged saved principal -> gameplay player before existing legality validation. |
| AUTOMATED principals | Unchanged. This ADR does not assign humans to AUTOMATED principals or define bot execution, substitution, kind change, or a generic controller framework. |

## 8. Normative disposition of the original ADR-011

| Original ADR-011 requirement | Disposition |
| --- | --- |
| Preserve exact canonical gameplay state and immutable saved principal binding | **Retained** |
| Separate durable principal, transient association, canonical state, reconstructed session state, and presentation | **Retained**, with physical human made an explicit separate concept |
| Host owns transient associations and enforces them at command admission | **Retained** |
| One match-scoped capability and proof per HUMAN principal | **Superseded** by explicit session-local assignment |
| Host must prove entitlement to its own principal and cannot assign another principal | **Superseded**; the host explicitly assigns every endpoint, including itself, but cannot rebind canonical identity |
| Capability transfer enables a replacement human | **No longer applicable**; any connected human may be explicitly assigned without persistent proof |
| Every HUMAN principal has exactly one claimant before publication | **Refined and retained** as exactly one assigned connected endpoint per saved human-controlled side before publication |
| One active association per HUMAN principal; reject competition without eviction | **Retained** |
| Fresh resume and reconnect use the same credential standard | **Superseded**; both use explicit session-local association, with reconnect allowed only after confirmed association loss |
| No partial publication or principal-dependent input before all gates pass | **Retained** |
| Decision-equivalent reconstruction and non-authoritative presentation | **Retained** |
| Original-host-installation MVP required for entitlement validation | **Superseded as an entitlement requirement**; retained only as the current save-integrity/support boundary pending a separate portability decision |
| Credential/verifier/secret persistence and redaction requirements | **No longer applicable to the target architecture**; ordinary secret-handling rules still apply to unrelated data |
| No principal rebind, host/client inference, generic framework, partial participation, shared control, or bot substitution | **Retained** |

## 9. Fail-closed invariants

1. Resume SHALL validate and restore the exact canonical gameplay state and
   saved player/principal binding without principal mutation or rebinding.
2. Every participating endpoint and every saved human-controlled side SHALL
   appear exactly once in the complete pre-publication assignment.
3. The host SHALL explicitly commit the assignments; host/client role and
   other incidental session facts SHALL NOT derive them.
4. Missing, ambiguous, duplicate, incomplete, or competing assignments SHALL
   fail without partial live publication, hidden-information leakage,
   player-originated input, or canonical mutation.
5. At most one active association SHALL exist for each saved HUMAN principal/
   player side. Reassignment requires confirmed loss of the incumbent
   association and SHALL NOT evict an active controller.
6. A session association SHALL remain distinct from canonical identity,
   gameplay legality, and presentation.
7. Reconnect SHALL restore the correctly filtered current state before command
   admission and SHALL NOT reload or progress canonical gameplay.
8. Same-live-match load, Hot-Seat, replay, and AUTOMATED-principal semantics
   SHALL remain unchanged.
9. Removing credential requirements SHALL NOT be treated as authorization for
   save portability, a generic controller framework, bots, spectators, absent
   players, shared control, or active-controller takeover.

## 10. Consequences and trade-offs

Positive consequences:

- fresh resume no longer burdens users with credential custody, transfer, or
  recovery for a product requirement that does not need physical-person
  continuity;
- either connected human may control either saved side through an explicit
  pre-publication choice;
- host/client transport roles stay decoupled from gameplay-side authority;
- canonical gameplay identity, filtering, command provenance, replay, and
  decision recovery remain stable; and
- the change can reuse the existing narrow association and staged-publication
  seams without creating a generic framework.

Trade-offs:

- the authoritative host can choose the resumed side assignment for the
  current session;
- the system does not prove that a resumed controller is the prior physical
  human;
- all saved human-controlled sides still need controllers before publication;
- live reassignment remains blocked until incumbent association loss is
  confirmed; and
- portable saves remain a separate unresolved product capability.

## 11. Exclusions and next decision boundary

This ADR does not define or authorize:

- UI layout or consent flow for side selection;
- RPC/API design, protocol version, class/file layout, or save-format changes;
- production implementation, tests, or repair of MATCH-002;
- cross-installation/new-host save portability;
- active-controller eviction or host takeover during a live association;
- absent-player progression, partial live resume, shared control, spectators,
  or late join unrelated to reconnecting an unoccupied side;
- bot substitution, bot execution, principal-kind mutation, or a generic
  controller framework; or
- global accounts, identity providers, matchmaking, invites, or social state.

No additional Owner decision is required to draft a replacement implementation
workbook for this narrow model. Stop for Owner direction if implementation
would require any excluded capability. In particular, save portability remains
a separate Owner decision; it is not implied by this amendment.
