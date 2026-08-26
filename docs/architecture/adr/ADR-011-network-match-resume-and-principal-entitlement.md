# ADR-011: Network Match Resume and Principal Entitlement

Status: Accepted

ADR-ID: ADR-011
Title: Network Match Resume and Principal Entitlement

Accepted by: Project Owner
Accepted date: 2026-08-26


Decision owner: Project Owner

Binding decision source:

- `docs/architecture/decision_workbooks/ODR-003-network-match-resume-and-replacement-principal-entitlement.md`

Supersedes:
None

Superseded by:
None

Related:

- ADR-008
- ADR-010
- MATCH-001
- AT-006
- AT-008
- AT-009
- BC-006
- BC-007
- BC-008
- RG-007
- RG-013
- RG-016

## Acceptance Note

This ADR translates the accepted Project Owner decisions in ODR-003 into
durable normative architecture. ODR-003 is binding Owner decision evidence and
its settled decisions are not reopened by this accepted ADR.

This ADR was accepted by the Project Owner on 2026-08-26. It authorizes no
implementation by itself and does not create or accept an implementation
workbook or contract. Accepted MATCH-001 behavior remains the implemented
fail-closed boundary until separately authorized implementation replaces the
applicable restriction.

## 1. Context and scope

ADR-008 establishes the immutable match-lifetime binding between gameplay
players and durable match principals. It deliberately separates those
principals from transient Network peers and requires replacement or reconnect
entitlement to fail closed until accepted architecture defines the proof,
validator, and failure policy.

MATCH-001 implements that boundary. A Network save may be loaded in-session
only while the loaded binding exactly matches the live binding and all existing
transient associations remain valid. A fresh Network session cannot infer
authority over the saved HUMAN principals from its newly connected peers or
lobby arrangement.

This ADR decides the narrow architecture required to resume a saved Network
match in a new Network session, or to reassociate a disconnected endpoint with
an existing HUMAN principal. It defines entitlement, participation,
association, portability, and fail-closed invariants. It does not design the
credential or the transport, persistence, or user-interface mechanisms that
implement them.

## 2. Conceptual and ownership boundaries

The architecture SHALL preserve these distinct concepts and lifetimes:

1. **Durable principal identity.** The canonical ADR-008 match principal is the
   match-scoped HUMAN or AUTOMATED controller identity. It remains bound to the
   same gameplay players for the match lifetime.
2. **Principal entitlement.** Entitlement is authority to assume an already
   existing HUMAN principal. It is established by accepted match-scoped proof;
   it is not the principal identity and does not alter the canonical binding.
3. **Transient peer/session association.** A current Network endpoint may be
   associated with an existing principal only for the current authoritative
   session. The association is runtime Network state, not durable gameplay
   identity.
4. **Canonical gameplay state.** `GameState` remains the canonical owner of the
   saved gameplay facts, including the immutable match-player-control binding
   and every fact needed to reconstruct the next legal gameplay decision or
   accepted stable state.
5. **Reconstructed session state.** Host and peer roles, validated
   peer-to-principal associations, transport ordering, and related Network
   runtime state are rebuilt around the restored canonical state. They SHALL
   NOT become a second gameplay-state owner or a principal-rebinding surface.
6. **Re-derived presentation.** Viewer-specific UI intent, modals, camera,
   waiting state, and other presentation are transient projections rebuilt
   after reconstruction. They do not establish entitlement, gameplay
   legality, canonical progression, or session association.

The authoritative host for the current session SHALL validate entitlement,
own the transient peer-to-principal associations, and enforce those
associations at player-originated command admission. Existing canonical owners
and gameplay validators continue to own gameplay facts and legality. A valid
association never makes an otherwise illegal gameplay action legal.

This ADR introduces no general participant, session, account, identity, or
controller aggregate. It assigns no new responsibility category to
`GameManager`.

## 3. Entitlement decision

Each HUMAN match principal SHALL have a distinct, match-scoped entitlement
capability. The capability is valid for that existing principal across saves
and checkpoints of the match. The authoritative host SHALL validate accepted
proof of the capability before establishing a transient association or
accepting player-originated commands for that principal.

Entitlement SHALL NOT be derived, individually or in combination, from:

- a principal identifier or visibility of the canonical binding;
- a gameplay player index;
- a peer or session identifier;
- lobby membership, slot, readiness, or password;
- display name or side label;
- `PlayerProfile.client_id` or another installation/profile identifier;
- connected membership, UI state, or presentation/controller state;
- possession of a save or public canonical state; or
- the save-integrity signature alone.

The host's session authority does not entitle it to another saved HUMAN
principal. The host SHALL prove entitlement to its own saved HUMAN principal
under the same standard that applies to remote claimants and SHALL NOT grant,
manufacture, bypass, replace, or revoke entitlement for another HUMAN
principal by discretion.

Capability possession establishes entitlement, not the return of the same
physical person. A capability holder may deliberately transfer it to another
human. The recipient may then assume the same existing principal. Such a
transfer SHALL NOT create or replace a principal, change principal kind, or
rebind any gameplay player, and it does not create host-mediated takeover
authority.

AUTOMATED principals do not require human-peer entitlement proof merely
because they exist. Their execution, substitution, and kind-change policies
remain outside this decision.

## 4. Participation and exclusive association

Before a restored match is published as live, every saved HUMAN principal
SHALL have exactly one validly entitled claimant and exactly one established
current association. Missing, invalid, ambiguous, duplicated, or competing
claims SHALL block live publication. The MVP has no partially resumed live
state and no absent-HUMAN-principal lifecycle.

At most one active peer association SHALL exist for a HUMAN principal. While
an association is active, a competing claimant SHALL fail closed even when it
presents another valid copy of the capability. A competing claimant SHALL NOT
evict the incumbent, and the host SHALL NOT arbitrate between claimants.

After confirmed disconnect or session loss invalidates the transient
association, accepted entitlement may establish a new association with the
same existing principal. Loss of a peer or association SHALL NOT mutate the
principal, its kind, or the canonical gameplay-player mapping.

## 5. Fresh-session resume and reconnect

Fresh-session resume and ordinary reconnect SHALL use the same
entitlement-to-existing-principal standard. Their bootstrap ordering may
differ, but neither an old peer/session identifier nor a newly available lobby
slot substitutes for accepted entitlement proof.

A successful fresh-session resume SHALL preserve this conceptual boundary:

```text
validated save artifact
  -> exact canonical gameplay reconstruction
  -> immutable saved principal binding preserved
  -> accepted entitlement validation for every saved HUMAN principal
  -> exclusive transient associations established
  -> Network/session runtime reconstructed
  -> canonical state published as live
  -> next legal gameplay decision or accepted stable state recovered
  -> viewer-specific presentation re-derived
```

Preparation may stage candidate state and claims before publication, but all
applicable validation and association gates SHALL succeed atomically from the
perspective of live gameplay. No partially validated restored state may be
published, and no principal-dependent player input may be accepted before the
applicable gates succeed.

Canonical reconstruction SHALL restore the accepted command sequence or
reconstruction cursor and every canonical fact required to determine the next
legal gameplay decision or accepted stable state. Session reconstruction SHALL
NOT repair invalid or incomplete gameplay state by inferred progression,
synthetic gameplay commands, or presentation callbacks.

Under ADR-010, presentation may be rebuilt from the reconstructed authorities,
but presentation SHALL NOT invent, consume, complete, legalize, or advance a
gameplay decision.

## 6. MVP portability and persistence boundary

The MVP SHALL support fresh-session resume only on the original save-owning
host installation. Copying a save to another host or installation does not
transfer trust or entitlement. Cross-host, cross-installation, cross-device,
cloud, and new-host resume remain unsupported unless later accepted
architecture defines trustworthy validator transfer or independently
verifiable resume material.

The canonical save may persist the non-secret principal identifiers, kinds,
and gameplay-player mapping required by ADR-008. Entitlement proof and
transient associations are not canonical gameplay state.

If a later implementation of this ADR requires non-secret credential
identifiers or verifier material, that material may exist only in a protected,
explicitly defined resume-metadata boundary separate from canonical gameplay
state. This permission does not select its owner, representation, storage
medium, or mechanism.

Reusable proof secrets SHALL NOT enter public canonical `GameState`, filtered
client snapshots, replay payloads, display labels, presentation payloads, or
logs. Saving a checkpoint SHALL NOT silently change or invalidate the
match-scoped entitlement semantics.

## 7. Fail-closed invariants

1. Resume SHALL restore and validate the saved canonical gameplay state and
   exact immutable principal binding; it SHALL NOT create, delete, replace, or
   rebind a principal.
2. The authoritative host SHALL validate entitlement before creating an
   association or admitting player-originated commands for that principal. A
   claimant cannot authorize itself.
3. Every saved HUMAN principal SHALL be entitled and exclusively associated
   before live publication.
4. Missing, invalid, ambiguous, duplicate, or competing claims SHALL fail
   without canonical mutation, partial live installation, vacant-slot
   assignment, incumbent eviction, or host arbitration.
5. Session-host authority, save possession, save integrity, or public identity
   information SHALL NOT be elevated into principal entitlement.
6. Disconnect or endpoint replacement SHALL change only transient association
   state; the durable principal and canonical mapping remain unchanged.
7. Entitlement and association SHALL remain separate from gameplay legality
   and canonical state ownership.
8. Reconstruction SHALL NOT use synthetic progression or presentation history
   to manufacture a valid gameplay state or decision.
9. Proof secrets SHALL remain outside public gameplay, snapshot, replay,
   presentation, and logging surfaces.
10. Deferred capabilities SHALL remain unsupported or fail closed; they SHALL
    NOT fall back to peer, slot, name, profile, host choice, or another weaker
    authority.

## 8. Relationship to existing authority

| Existing authority | Relationship to ADR-011 |
| --- | --- |
| ADR-008 | ADR-008 remains the authority for durable principal identity, `GameState` ownership, immutable gameplay-player binding, and the separation of gameplay player, principal, and peer. ADR-011 supplies the downstream entitlement, validation, exclusivity, and failure policy required by ADR-008's reconnect stop without permitting rebinding. |
| ADR-010 | ADR-010 remains the authority for decision-equivalent recovery and non-authoritative presentation. ADR-011 requires resumed canonical state to recover the same next legal decision or accepted stable state and requires presentation to be re-derived without synthetic progression. |
| MATCH-001 | MATCH-001 remains the accepted implementation authority for the current binding cutover and its fail-closed Network-load behavior. ADR-011 defines the normative architecture needed for later fresh-session resume and reassociation work; it does not itself remove MATCH-001's implemented gate or authorize implementation. |
| Save/replay and gameplay authorities | Existing canonical owners, semantic mutation surfaces, save-integrity authority, replay ordering, and gameplay legality remain unchanged. ADR-011 adds no second gameplay owner and allocates no format or protocol. |

No existing accepted authority is amended or reopened by this ADR.

## 9. Consequences and trade-offs

Positive consequences:

- a saved HUMAN principal can be resumed or reassociated without confusing an
  endpoint, person, lobby seat, or public identifier with durable gameplay
  identity;
- deliberate human substitution is possible without canonical rebinding;
- fresh-session resume and reconnect share one entitlement boundary;
- exclusive association preserves clear player-originated command provenance;
- session reconstruction remains subordinate to canonical gameplay state; and
- the MVP fits the current original-installation save trust boundary.

Trade-offs:

- every saved HUMAN principal must have an entitled claimant before resume can
  become live;
- absent players or lost proof can block MVP resume;
- a transferable capability establishes possession, not physical-person
  continuity;
- valid competing proof cannot displace an active association; and
- cross-host portability and recovery conveniences require later explicit
  decisions.

## 10. Exclusions and deferred boundaries

This ADR does not define or authorize:

- credential syntax or format;
- cryptographic primitive, challenge-response, key management, or other proof
  mechanism;
- credential issuance, storage implementation, transport, or user-interface
  flow;
- RPC/API design, command payloads, protocol versions, or class/file layout;
- save-format allocation, legacy-save migration, or support for saves created
  before entitlement material exists;
- stale-connection detection or active-association timeout semantics;
- retry timing or retry policy;
- credential expiry, rotation, revocation, administrative audit, or proof-loss
  recovery;
- cross-host, cross-installation, cross-device, cloud, or new-host portability;
- host-mediated entitlement grant, takeover, or claimant arbitration;
- partial resume, absent-player progression, forfeit, or bot substitution;
- multiple peers sharing one principal;
- global accounts, identity providers, matchmaking, invites, spectators, late
  join, or a general participant/session framework;
- principal rebinding, replacement, creation, deletion, or kind mutation;
- replay authentication or reuse of live entitlement proof in replay; or
- production implementation, tests, a contract, or an implementation
  workbook.

Deferral means fail closed or remain unsupported. Later work SHALL stop for
Owner direction if it cannot preserve the decisions and invariants in this
ADR without selecting a deferred policy.

## 11. Owner-decision traceability

| ODR-003 decision | ADR result |
| --- | --- |
| OD-1 — entitlement proof, trust, scope, and portability | Sections 2, 3, and 6 establish one distinct match-scoped capability per HUMAN principal, authoritative-host validation, separation from canonical gameplay state, and the original-host-installation MVP. |
| OD-2 — participation, absence, delegation, and host replacement | Sections 3 and 4 require every saved HUMAN principal to have exactly one entitled claimant before live publication, permit deliberate capability-holder substitution without rebinding, and prohibit host override or partial resume. |
| OD-3 — exclusive association, competing claims, and continuity | Sections 4 and 5 require at most one active association, fail closed on competition without eviction or arbitration, and apply one entitlement standard to reconnect and fresh-session resume. |
