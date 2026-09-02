# ADR-013: Passive Network Damage-State Representation

Status: Accepted

ADR-ID: ADR-013

Title: Passive Network Damage-State Representation

Accepted by: Project Owner

Accepted date: 2026-09-02

Decision owner: Project Owner

Binding decision input:

- Project Owner direction for the BUG-042 passive damage-state boundary,
  2026-09-02

Primary evidence:

- `docs/qa/bugs/open/BUG-042/BUG-042-network-rng-authority-architecture-investigation.md`
- `docs/qa/bugs/open/BUG-042/BUG-042-implementation-workbook-direction-audit.md`

Supporting decision evidence:

- the BUG-042 simplification study recommending a filtered damage ledger,
  preserved as non-repository Owner evidence supplied during the decision

Related:

- BUG-042
- ADR-008
- ADR-011
- ADR-012
- CON-001
- `StateFilter`

Supersedes:
None

Superseded by:
None

## Acceptance note

The Project Owner has selected a damage-specific filtered ledger for passive
live Network state. This ADR records that settled decision and does not reopen
full-deck mirroring, shared hidden-deck reconstruction, or a generic
hidden-state framework.

This decision authorizes no implementation by itself and does not change the
BUG-042 implementation workbook.

## 1. Context and scope

ADR-012 makes randomness authority-only in live Network play and requires
passive peers to apply viewer-authorized authoritative results through the
owning command transaction. The preserved BUG-042 evidence shows that the
current filtered damage representation cannot be reconstructed into a usable
passive `DamageDeck`: filtered draw and facedown counts are discarded during
deserialization, while damage commands still expect local hidden cards.

This ADR decides only how passive live Network `GameState` canonically
represents damage-deck and ship-damage facts. It does not change damage rules,
general command ownership, replay, authoritative save contents, or filtering
for unrelated hidden information.

## 2. Decision

### 2.1 Authority-only hidden damage facts

During live Network play, the authority alone SHALL own, receive, store, and
use:

- the complete damage-deck order; and
- the identity of every facedown damage card, wherever that card is located.

A facedown damage-card identity is hidden from both players for the entire
time that the card remains facedown. Ownership of the damaged ship does not
grant visibility of that identity.

### 2.2 Passive canonical representation

A passive live Network `GameState` SHALL use a damage-specific filtered ledger
as its viewer-authorized canonical damage representation. The ledger is
canonical state for that passive execution context; it is not a presentation
cache, projection, or independently reconstructed `DamageDeck`.

The ledger SHALL contain only these hidden/public aggregate damage facts:

1. the count of cards remaining in the hidden draw pile;
2. the identities of cards in the public discard pile; and
3. the count of facedown damage cards on each ship.

Faceup damage cards SHALL remain normal canonical `DamageCard` objects in the
passive state because their identities are public and may carry gameplay
effects. A card that becomes faceup enters that public representation; a card
that becomes facedown leaves it and contributes only to the applicable
facedown count.

The passive representation SHALL NOT contain placeholders, opaque identifiers,
encrypted identities, derived identities, or any other value from which a
facedown identity or hidden deck order can be recovered.

After every accepted command sequence, the passive viewer-authorized damage
state SHALL be semantically equivalent to filtering the authority's full
post-state for that viewer. Equivalence requires the same authorized ledger
facts and public `DamageCard` objects; it does not require possession of
authority-only deck order or facedown identities.

### 2.3 Authoritative transitions and application

The authority SHALL resolve hidden draws and every transition among hidden
draw pile, facedown ship damage, faceup ship damage, discard, repair, and ship
destruction using its full authoritative damage state.

After passive state installation, every live gameplay mutation involving
damage draw, placement, flip, repair, discard, destruction, deck exhaustion,
or reshuffle SHALL occur through its owning command transaction. The owning
command SHALL define an explicit authoritative-result contract containing only
the realized facts authorized for the receiving viewer. The passive peer SHALL
validate and apply the result atomically through that same command-owned
canonical transaction. Canonical damage mutation SHALL NOT move into
`GameManager`, network transport, `StateFilter`, projection, scene, modal, or
UI code.

Setup/bootstrap initialization is the narrow exception: before passive command
admission, its realized damage state MAY reach the peer through the accepted
filtered publication and installation surface. This exception does not permit
post-installation gameplay mutation outside an owning command transaction.

A passive peer SHALL NOT require a hidden card identity or hidden deck order
to validate or apply a result. An invalid, incomplete, stale, duplicated,
out-of-order, or inapplicable result SHALL fail closed under the ordering and
atomicity rules of ADR-012 and CON-001.

Command intent and envelopes, command history exposed to passive peers,
authoritative-result payloads, logs, and diagnostics SHALL NOT disclose the
identity of any card that remains facedown after the applicable authoritative
transition. A card identity MAY enter passive state only when that same
transition makes the identity public, including as faceup damage or a public
discard.

### 2.4 Installation and reconstruction

Fresh Network play, resume, and reconnect SHALL install the same filtered
canonical damage representation before passive command admission. None of
those paths may seed, copy, shuffle, infer, or reconstruct a passive hidden
damage deck.

`StateFilter` SHALL preserve the visibility boundary when deriving a passive
snapshot from authoritative state. Deserialization and installation SHALL
preserve every ledger fact and every public faceup `DamageCard` required for
the next legal passive application. Presentation SHALL be derived afterward
and SHALL NOT repair missing canonical damage facts.

### 2.5 Unchanged full representations

The following contexts retain the existing full `DamageDeck` and full
authoritative damage-card identities:

- live Network authority;
- Hot-Seat and other local authoritative play;
- authoritative save/load; and
- replay reconstruction.

Authority saves SHALL continue to serialize and restore the complete damage
state. A Network authority restored from a save SHALL derive the same filtered
passive representation before publishing it to a resumed peer.

Replay SHALL remain deterministic seed-plus-command-history re-execution using
the reconstructed full authoritative damage state. It SHALL NOT depend on,
persist, or reconstruct from transient live Network result payloads or the
passive filtered ledger.

## 3. Architectural invariants

1. Full damage-deck order and all facedown identities are authority-only facts
   during live Network play.
2. Facedown identity is hidden from both players while the card remains
   facedown.
3. Passive live Network state canonically stores the hidden draw-pile count,
   public discard identities, and facedown count per ship in a damage-specific
   filtered ledger.
4. Public faceup damage remains represented by canonical `DamageCard` objects.
5. After every accepted command sequence, passive viewer-authorized damage
   state is semantically equivalent to the filtered authoritative post-state.
6. The authority resolves hidden damage transitions; after installation, every
   live gameplay damage mutation and viewer-authorized result application is
   atomic within its owning command transaction. Setup/bootstrap initialization
   remains limited to filtered publication and installation before command
   admission.
7. Passive command surfaces, exposed history, results, logs, and diagnostics
   do not disclose identities that remain facedown; identity enters passive
   state only through the transition that makes it public.
8. Passive peers never draw, shuffle, or reconstruct the hidden damage deck
   and never require a facedown identity for validation.
9. Passive canonical damage state is never mutated by `GameManager`, UI, or
   projection.
10. Fresh, resumed, and reconnected passive peers install the same canonical
   representation and visibility boundary.
11. Authority, Hot-Seat, authoritative save/load, and replay retain full damage
   representations.
12. The filtered ledger is damage-specific and SHALL NOT establish generic
    hidden-state infrastructure.

## 4. Relationship to existing architecture

| Existing source | Normative relationship |
| --- | --- |
| ADR-008 | Preserved. The authoritative host/server `GameState` remains the writable Network authority. Its requirement that mirrors reproduce the same semantics does not require identical authority-only hidden representations; the passive ledger is the viewer-authorized canonical representation for that execution context. |
| ADR-011 | Preserved. Resume/reconnect still restores exact authoritative gameplay state and publishes only correctly filtered state after assignment and before command admission. This ADR defines the damage portion of that passive state and changes no principal, assignment, or save-ownership rule. |
| ADR-012 | Extended narrowly. Hidden deck order remains authority-only random state, and passive peers apply viewer-authorized realized outcomes without RNG or hidden inputs. Damage commands use explicit command-owned result contracts; live results remain transient and replay remains seed-plus-history re-execution. |
| CON-001 | Preserved. Applicable semantic command transactions retain validation, atomic mutation, history, cursor, ordering, and fail-closed ownership. Filtered pre-state validation cannot require authority-only damage identity. |
| `StateFilter` | Clarified. Filtering must produce the damage-specific canonical ledger and public faceup cards for fresh, resume, and reconnect installation. The ledger is not a projection cache and does not broaden filtering into a generic hidden-state model. |
| Save/load | Preserved. Authoritative saves and loads retain the complete deck and identities; a restored Network authority filters that full state for each passive installation. |
| Replay | Preserved. Replay reconstructs and re-executes the full authoritative model from seed and semantic command history, independent of live result payloads and passive ledgers. |
| Preserved BUG-042 evidence | The investigation and direction audit remain implementation evidence. Their identified filtered-damage stop gate is resolved architecturally by this decision, but implementation readiness and workbook conformance remain separate gates. |

## 5. Explicit non-goals

This ADR does not define:

- concrete ledger types, field names, serialization layouts, result schemas,
  RPCs, or protocol versions;
- a generic hidden-state, redaction, secret-object, placeholder-card, or
  encrypted-identity framework;
- damage rules, card effects, or presentation design;
- new save or replay formats;
- implementation scope, sequencing, tests, or acceptance of the BUG-042
  workbook; or
- production code changes.

## 6. Acceptance boundary

Acceptance establishes the passive damage-state model but does not establish
implementation conformance, make the current BUG-042 workbook
implementation-ready, or close BUG-042. The workbook requires a separate
direction update and independent audit before implementation authorization.

## 7. Related documents

- `docs/architecture/DOCUMENT_AUTHORITY.md`
- `docs/architecture/adr/ADR-008-durable-match-lifetime-player-principal-binding.md`
- `docs/architecture/adr/ADR-011-network-match-resume-and-principal-entitlement.md`
- `docs/architecture/adr/ADR-012-live-network-rng-authority-and-result-application.md`
- `docs/architecture/contracts/CON-001-current-attack-state-and-semantic-transition-contract.md`
- `docs/qa/bugs/open/BUG-042/BUG-042-network-rng-authority-architecture-investigation.md`
- `docs/qa/bugs/open/BUG-042/BUG-042-implementation-workbook-direction-audit.md`
- `docs/architecture/implementation_workbooks/BUG-042-network-rng-authority-result-application-implementation-workbook.md`
