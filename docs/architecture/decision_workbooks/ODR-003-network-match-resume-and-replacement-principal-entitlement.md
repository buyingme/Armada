# ODR-003: Network Match Resume and Session-Local Controller Assignment

**Status:** Accepted

Accepted by: Project Owner

Original accepted date: 2026-08-26

Amended by Project Owner: 2026-08-27

**ODR ID:** ODR-003

**Decision owner:** Project Owner

**Implementation authorization:** None

**Desired capability:** Resume a saved Network match in a fresh Network
session by explicitly assigning the connected humans to the saved canonical
player sides before the restored match becomes live.

**Affected architecture areas:** BC-006, BC-007, BC-008

**Applicable reality gaps:** RG-007, RG-013, RG-016

**Related architecture tasks:** AT-006, AT-008, AT-009

**Primary accepted authority:** ADR-008, ADR-010, accepted MATCH-001, and
ADR-011 as amended from this record

## 1. Amendment purpose and decision boundary

The Project Owner has replaced the persistent-human-entitlement requirement
recorded in the original ODR-003 decision with explicit session-local
controller assignment for fresh-session Network resume.

The credential workflow proved disproportionately complex from the user's
perspective. Persistent proof that a resumed human is the original human is not
a current product requirement. A different human may control a saved canonical
player side. The canonical side identity and its saved match-principal binding
still matter and SHALL NOT be rewritten merely to describe that different
human.

This amendment decides the smallest policy change required for fresh-session
Network resume and same-live-session reconnect. It does not create a generic
controller, participant, bot, account, identity, or session framework. It does
not authorize implementation.

The original RSA capability/verifier/credential direction, later elaborated in
MATCH-002, is superseded as a product requirement. MATCH-002 is superseded as
an executable implementation workbook and remains useful only as historical
implementation and seam evidence. A separately accepted replacement workbook
must define any future implementation; MATCH-002 SHALL NOT be amended or
re-refined into that replacement. Its implemented mechanism does not preserve
a requirement that the Owner has removed.

## 2. Authority retained from ADR-008 and MATCH-001

This refinement retains the following accepted architecture:

1. `GameState` owns one complete, immutable, match-lifetime
   player-to-principal binding.
2. Gameplay player identity, match-principal identity, current human
   controller, and transport endpoint are distinct concepts.
3. Loading restores the saved principal records and gameplay-player mapping
   exactly. Fresh resume does not create, delete, replace, reclassify, or rebind
   a canonical principal.
4. A Network peer, lobby slot, host/client role, display name, profile ID,
   readiness flag, or UI state is not durable canonical gameplay identity.
5. Transient Network association and command admission remain host-authoritative
   session concerns. Gameplay legality remains with existing canonical
   validators.
6. Invalid or incomplete canonical state and incomplete or conflicting live
   associations fail closed before publication or principal-dependent input.
7. Hot-Seat keeps one HUMAN principal controlling both gameplay players;
   two-human Network keeps two distinct saved HUMAN principals. Structural
   AUTOMATED support remains unchanged and does not authorize bot behavior.
8. Replay reconstructs historical canonical identity without fabricating live
   peers or live controller assignments.

For fresh-session resume, a saved HUMAN principal is a durable, match-scoped
canonical control identity. Its `HUMAN` classification does not assert that the
same physical person must control it in every later session. The session-local
assignment says which connected human currently exercises that unchanged
canonical authority.

## 3. Supersession of the original ODR-003 decisions

### OD-1 — Persistent entitlement proof, trust, scope, and portability

**Superseded:**

- one match-scoped capability per HUMAN principal;
- claimant proof of capability possession;
- host validation of a credential, verifier, or equivalent persistent-human
  entitlement before assignment;
- credential secrecy, issuance, transfer, storage, recovery, or cryptographic
  mechanism as a fresh-resume product requirement; and
- using the same persistent proof standard for fresh resume and reconnect.

**Retained:**

- canonical principal identity is not inferred from current peer or UI facts;
- the authoritative host owns current-session associations and command
  admission;
- transient associations and any session bootstrap metadata remain outside
  canonical gameplay state; and
- save integrity remains distinct from controller assignment.

**Portability disposition:** the original-host-installation restriction is no
longer required to validate human continuity or controller entitlement.
However, this refinement does not make save artifacts portable. Current
installation-local save-integrity and file-access constraints remain the
supported boundary until a separate Owner decision authorizes and defines
cross-installation or new-host save portability.

### OD-2 — Participation, absence, substitution, and host authority

**Superseded:**

- requiring an entitled capability holder for every saved HUMAN principal;
- capability transfer as the means by which a different human may control a
  saved side; and
- the prohibition on host assignment of another saved HUMAN principal.

**Retained and refined:**

- every saved human-controlled Network side must have exactly one connected
  human controller before live publication;
- partial fresh resume and absent-human progression remain outside this narrow
  decision;
- a different human may be assigned without canonical rebinding; and
- the authoritative session host is the sole authority that establishes the
  complete current-session assignment. The host must explicitly assign its own
  endpoint too; hosting does not automatically select a gameplay side.

### OD-3 — Exclusivity, competing assignment, and reconnect

**Retained:**

- at most one active session association per saved HUMAN principal/player side;
- competing or duplicate assignment fails closed;
- an active controller is not silently evicted by another endpoint; and
- disconnect changes transient association only, never canonical identity.

**Superseded and refined:**

- reconnect no longer requires the fresh-resume credential standard;
- after confirmed loss of an association, the authoritative host may
  explicitly assign the now-unoccupied saved side to a connected endpoint;
- the returning human may be the prior human or a different human; and
- host/client role, the freed lobby slot, or a reused peer/profile/name value
  never performs that assignment automatically.

## 4. Fresh-session authority model

### 4.1 Canonical saved authority

The validated save supplies the exact canonical gameplay state, including the
saved gameplay players, match principals, principal kinds, and immutable
player-to-principal mapping. Those facts remain authoritative for gameplay,
save/load, replay, filtering, acknowledgement cardinality, and command
authorization.

Resume SHALL NOT rewrite a saved principal ID or mapping because the human
assigned to a side differs from the human who controlled it when the save was
created.

### 4.2 Session-local controller assignment

A session-local controller assignment represents only this proposition:

> For this authoritative Network session, this connected human endpoint may
> submit player-originated input for this saved canonical player side, through
> the unchanged saved principal bound to that side.

It does not represent durable human identity, return of the original person,
ownership of the save, a global account, a principal replacement, a principal
kind change, or gameplay legality.

The association is transient host-held Network state. It may be staged during
resume, becomes authoritative for the resumed session only at the successful
pre-publication assignment commit, and ends when the session or applicable
endpoint association ends.

### 4.3 Assignment authority and ordering

The authoritative session host SHALL:

1. validate the save and reconstruct the complete canonical candidate without
   publishing it;
2. identify the saved human-controlled canonical player sides from that
   candidate;
3. explicitly assign each participating connected human endpoint to one saved
   side, including an explicit assignment for the host endpoint;
4. validate the complete assignment set for completeness and exclusivity;
5. establish the corresponding transient endpoint-to-existing-principal
   associations as one pre-publication commit;
6. distribute only the filtered state authorized by those assignments and
   complete the required installation/readiness handshake; and
7. publish the restored match and enable player-originated command admission
   only after every publication gate succeeds.

The host may choose either saved side for itself. Client arrival order, lobby
slot, readiness order, player index, display name, profile identity, and
host/client role SHALL NOT select a side automatically. UI selection and
confirmation mechanics remain implementation design.

### 4.4 Completeness, exclusivity, and failure

For the current two-human Network shape, the pre-publication assignment is a
one-to-one mapping between the two participating connected human endpoints and
the two saved human-controlled canonical player sides:

- every saved human-controlled side has exactly one assigned endpoint;
- every participating endpoint is assigned to exactly one saved side;
- no endpoint or side appears twice; and
- no unassigned, ambiguous, duplicated, or competing assignment is published.

Any failure discards or keeps the candidate staged without changing the live
canonical state. No partial board, player-originated input, or side-specific
hidden information may be published through an incomplete or conflicting
assignment.

This is deliberately not generalized to other participant cardinalities,
shared Network control, spectators, absent players, or bots.

## 5. Reconnect after publication

When an endpoint disconnects from the live resumed session:

1. the host removes or invalidates only its transient association;
2. canonical gameplay state, saved principal records, and player mapping remain
   unchanged;
3. command input for the unoccupied side remains closed;
4. while an incumbent association is still active or disconnect is not
   confirmed, a competing assignment fails without eviction; and
5. after confirmed association loss, the host may explicitly assign that
   unoccupied side to a connected endpoint and restore its correctly filtered
   current state before reopening command admission for the side.

Reconnect is therefore continuity of a session-local side association, not
proof of continuity of a person. It does not reload or republish the host's
canonical match.

## 6. Cross-capability consequences

| Concern | Decision consequence |
| --- | --- |
| Hot-Seat | Unchanged. Hot-Seat has one canonical HUMAN principal controlling both sides and needs no Network fresh-resume assignment protocol. |
| Same-live-match Network load | Unchanged. An earlier save may load only under the accepted exact-binding/current-association gate. It is not fresh-session assignment and does not reshuffle controllers. |
| Replay | Unchanged. Replay restores the saved binding as historical authority and uses replay submission provenance; it creates no live human assignment or credential. |
| Hidden information | The complete staged assignment determines which filtered view each endpoint may receive. No endpoint receives another side's hidden information because of host/client role, lobby order, or an incomplete assignment. |
| Command authorization | The host resolves the submitting endpoint through the committed session association, then uses the unchanged canonical binding to verify control of `command.player_index`, then applies existing gameplay legality. |
| Decision-equivalent recovery | Canonical cursor and gameplay facts restore the same next decision or accepted stable state. Assignment and presentation do not synthesize gameplay progression. |
| Automated principals | No change. This decision neither assigns humans to AUTOMATED principals nor defines bot execution, substitution, kind mutation, or a generic controller framework. |
| Eventual controller independence | Preserving canonical player/principal identity separately from a transient human association remains compatible with later bot/controller decisions, but creates none. |
| Original host installation | Not required by human-controller policy. It remains the current supported save trust/file boundary only; portability is a separate decision. |

## 7. Explicit non-goals

This decision does not define or authorize:

- a generic controller, participant, account, identity, lobby, or session
  framework;
- bot behavior, bot substitution, human/automated kind changes, or AI-vs-AI
  product support;
- spectators, late join unrelated to replacing a disconnected controller,
  shared control, absent-player progression, forfeit, or takeover;
- host eviction of an actively associated controller;
- cross-host, cross-installation, cross-device, cloud, or copied-save
  portability;
- save-format migration, save-integrity redesign, RPC/API shape, protocol
  version, UI layout, class/file ownership, or test design; or
- production code, tests, or repair of MATCH-002.

## 8. Implementation evidence disposition

MATCH-002 may be mined for evidence about:

- staged candidate reconstruction and atomic publication seams;
- host-held transient associations and command-admission closure;
- filtered client installation and acknowledgement;
- same-live-match load separation;
- reconnect snapshot delivery;
- decision-equivalent recovery; and
- verification scenarios for completeness, competition, hidden information,
  exact-once publication, replay, and Hot-Seat regression.

Its RSA keys, capability vault, verifier registry, challenge-response protocol,
credential import/export UX, proof-loss behavior, and credential-driven
compatibility requirements are superseded implementation choices and SHALL NOT
be carried forward merely because they exist in the working tree.

## 9. Resolved Owner decision record

| Decision | Amended Owner selection | Resulting policy |
| --- | --- | --- |
| OD-1 — human continuity and proof | **Persistent human continuity not required** | No credential/capability proof requirement for fresh resume or reconnect; canonical saved identity remains exact. |
| OD-2 — assignment and participation | **Explicit host-authoritative pre-publication assignment** | Every connected participant is explicitly assigned to exactly one saved human-controlled side; every such side is assigned before publication; host/client role does not choose. |
| OD-3 — exclusivity and reconnect | **One active session association per side** | Duplicate/competing assignment fails closed; after confirmed loss, the host may explicitly assign the unoccupied side without canonical rebinding. |
| OD-4 — original installation and portability | **Separate from controller policy** | The controller policy does not require the original installation, but this amendment does not authorize portable saves; the current supported save-trust boundary remains until separately decided. |

No additional Owner decision is required for this narrow decision-layer
refinement. A separate Owner decision is required only if a later step intends
to add cross-installation/new-host save portability, active-controller
eviction, absent-player progression, shared control, or bot substitution.

## 10. Rationale preserved

- The credential workflow proved disproportionately complex for users and for
  implementation.
- Persistent proof that the resumed human is the original human is not a
  current product requirement.
- Canonical game-side and match-principal identity remain necessary for
  gameplay authority, durability, replay, filtering, and command provenance.
- Explicit assignment is preferred over host-to-Player-0/client-to-Player-1
  coupling.
- The selected model simplifies UX and implementation without moving canonical
  gameplay authority into the lobby, peer, or presentation layer.

## 11. Authority and evidence consulted

- `AGENTS.md`
- `docs/architecture/CODEX_WORKFLOW.md`
- `docs/architecture/DOCUMENT_AUTHORITY.md`
- `docs/architecture/adr/ADR-008-durable-match-lifetime-player-principal-binding.md`
- `docs/architecture/adr/ADR-010-gameplay-interaction-decision-equivalent-recovery.md`
- `docs/architecture/adr/ADR-011-network-match-resume-and-principal-entitlement.md`
- `docs/architecture/implementation_workbooks/MATCH-001-player-principal-binding-owner-decisions.md`
- `docs/architecture/implementation_workbooks/MATCH-001-player-principal-binding-implementation-workbook.md`
- `docs/architecture/implementation_workbooks/MATCH-002-network-match-resume-and-principal-reassociation-implementation-workbook.md`
- `docs/setup_network_game.md`
