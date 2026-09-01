# ADR-012: Live Network RNG Authority and Result Application

Status: Accepted

ADR-ID: ADR-012

Title: Live Network RNG Authority and Result Application

Accepted by: Project Owner

Accepted date: 2026-09-01

Decision owner: Project Owner

Binding decision input:

- Project Owner direction for BUG-042, 2026-09-01

Primary evidence:

- `docs/qa/bugs/open/BUG-042/issue-Network-resume-loses-deterministic-RNG-required-by-mirrored-RollDiceCommand.md`
- `docs/qa/bugs/open/BUG-042/BUG-042-network-rng-authority-architecture-investigation.md`

Related:

- BUG-042
- ADR-001 / CON-001
- ADR-003 / CON-003
- ADR-008
- ADR-011
- MATCH-003

Supersedes:

- Only the BUG-011 normal-live implication and steps identified in Section 4;
  compatible BUG-011 replay-bootstrap requirements remain in force

Superseded by:
None

## Draft note

The Project Owner has selected authority-only RNG for live Network play. This
ADR records that settled direction and does not reopen the rejected
shared-resumable-RNG alternative.

This document remains Draft until accepted by the Project Owner. It authorizes
no implementation by itself and does not create an implementation workbook.

## 1. Context and scope

`GameState.rng` contains both an initial seed and resumable generator state.
Authority save/load preserves that state, while `StateFilter` intentionally
removes it from passive client views. Live Network mirroring nevertheless
currently re-executes RNG-dependent commands as though the passive mirror had
the authority's RNG. After filtered reconstruction, that assumption is false
and the next RNG-dependent command cannot be applied.

The defect exposes a cross-context authority ambiguity, not a defect specific
to dice rolling. This ADR decides only RNG ownership and result application
across live Network execution, filtered live reconstruction, authority
save/load, and replay.

It does not redesign replay, `StateFilter`, save-game ownership, Network
principal or assignment architecture, attack ownership, general command
architecture, or the transport protocol beyond the result semantics required
by this decision.

## 2. Decision

### 2.1 Execution contexts

RNG ownership, visibility, and advancement SHALL depend on execution context:

| Execution context | RNG ownership and visibility | RNG advancement and random outcome application |
| --- | --- | --- |
| Local authoritative play, including Hot-Seat | The authoritative `GameState` owns the complete RNG seed and current state. | Authoritative commands and accepted authoritative setup/resolver paths advance that RNG. |
| Live Network authority | The authoritative host/server `GameState` alone owns and may access the complete live RNG seed and current state. | The authority alone advances live RNG. An RNG-dependent command resolves its outcome and commits it through its normal atomic command transaction. |
| Passive live Network mirror, whether freshly bootstrapped, resumed, or reconnected | The passive peer SHALL NOT receive, retain, reconstruct, or synthesize the live seed or resumable RNG state. Its filtered `GameState` may intentionally have no RNG execution capability. | The mirror SHALL NOT generate or reproduce the random calculation and SHALL NOT advance RNG. It validates and applies the authority-resolved outcome through the command-owned mirror transaction. |
| Authority save/load | The authoritative save contains the full RNG seed and current state. Load restores that exact state before later authoritative RNG consumption. | Continued authoritative execution advances the restored stream exactly as uninterrupted authoritative execution would. |
| Replay reconstruction | The accepted replay seed and semantic command history reconstruct the replay RNG context. | Replay re-executes RNG-dependent commands deterministically in authoritative history order and advances the reconstructed RNG. It does not consume persisted live result history. |

This context distinction is intentional. A passive live mirror is a
synchronized, filtered representation of accepted authority; it is not an
independent random-outcome authority and need not possess every hidden input
used by the live authority.

### 2.2 Classification of live RNG consumers

Every live Network consumer of `GameState.rng` SHALL execute only on the live
authority.

When that consumer is a semantic command, its realized outcome SHALL reach a
passive mirror through the command-owned authoritative-result application
mechanism defined in Section 2.3.

An RNG consumer in an accepted non-command setup, bootstrap, or resolver path
SHALL NOT automatically use that command-result mechanism. Its realized
effects SHALL reach passive peers only through its already accepted,
appropriately filtered publication or synchronization surface.

This classification creates neither a generic result framework nor a generic
alternate mutation path.

### 2.3 Authority-resolved result application

Every RNG-dependent command used in live Network play SHALL define an explicit
authoritative-result application contract. That contract SHALL define the
viewer-authorized realized facts required by each passive peer to validate and
apply the outcome to this exact semantic transaction. Different filtered peers
MAY receive different authorized result fields under accepted visibility
rules.

A transported authoritative RNG result SHALL NOT expose:

- the live RNG seed;
- resumable or current RNG state;
- unrealized future-stream information;
- hidden ordering; or
- unrelated RNG-coupled secrets.

On the live authority, the command SHALL generate the outcome from
`GameState.rng` and commit the resulting canonical mutation atomically.

Passive result validation SHALL use only:

- the command;
- authoritative sequence and order;
- the peer's accepted filtered pre-state; and
- result fields authorized for that peer.

A passive mirror SHALL NOT require hidden authority-only inputs merely to
reproduce authority-side validation. Within that boundary, the same semantic
command transaction on the passive live mirror SHALL:

1. validate authoritative sequence and command identity;
2. validate every applicable lifecycle identity, target identity, filtered
   current pre-state condition, and authorized result field;
3. establish that the result is structurally complete, semantically valid,
   and applicable to that command in the current mirror state;
4. apply the realized outcome through the command's accepted canonical
   mutation surface; and
5. record the accepted semantic command and advance command ordering exactly
   once only after the complete transaction succeeds.

Consuming an authority-resolved result is an execution mode of the command
transaction. It SHALL NOT create a generic result-owned mutation path or move
canonical mutation into transport, `GameManager`, projection, scene, modal, or
UI code.

The realized outcome may become canonical gameplay state because the command
commits it. The transported result remains a transient application input; it
is not a second canonical owner.

### 2.4 Failure and ordering

A missing, malformed, stale, duplicated, out-of-order, inconsistent, or
otherwise inapplicable authoritative random result SHALL fail closed.

Before the result's authoritative sequence becomes applicable, ordering
infrastructure MAY buffer it under existing ordered-delivery responsibilities.
It SHALL NOT apply it early. A stale or duplicated result SHALL NOT mutate
canonical state a second time.

Failure of result validation or application SHALL leave the rejecting passive
mirror's canonical state, command history, command cursor, follow-up
generation, and presentation-success effects unchanged for that transaction.
This passive rejection does not imply rollback of an authority transaction
that may already have been accepted and committed. Implementations SHALL NOT
generate a replacement result, seed a fallback RNG, guess omitted facts,
partially apply the outcome, or skip the failed sequence and apply later
results as though it succeeded.

### 2.5 History and replay

Command history SHALL remain semantic command and authoritative order history.
Transient live Network result payloads SHALL NOT be persisted as live result
history, replay decisions, or an alternate replay input.

Replay SHALL continue deterministic seed-plus-command-history re-execution.
RNG-dependent replay commands reproduce their calculations from the accepted
replay seed and ordered command history. This ADR does not change replay file
ownership, replay seed authority, or `CON-001-REPLAY-004`.

### 2.6 Save, resume, reconnect, and fresh bootstrap

Authority save/load SHALL serialize and restore the full current RNG state.
The authority SHALL reject continuation when the RNG state required by the
next authoritative execution cannot be restored validly.

Filtered resume and reconnect SHALL preserve the existing RNG visibility
boundary: passive peers receive no seed or resumable RNG state and SHALL NOT
reconstruct either. Their ability to continue live mirroring derives from
validated command-owned application of later authority-resolved outcomes.

Fresh live Network bootstrap SHALL obey the same boundary. It SHALL establish
the authority's RNG and distribute only the appropriately filtered canonical
view needed by the passive peer. It SHALL NOT initialize a passive peer with a
shared live seed, equivalent RNG stream, or hidden draw order merely because
the match is fresh.

These requirements refine reconstruction completeness: a passive live mirror
must contain the visible canonical pre-state and result-application capability
needed for the next accepted command, not hidden authority-only calculation
state that the mirror is prohibited from executing.

## 3. Architectural invariants

1. Exactly one RNG authority advances randomness during live Network play.
2. Passive live peers possess no seed or resumable state for that live RNG.
3. Transported results expose only viewer-authorized realized facts and no
   live RNG or unrelated hidden information.
4. An authority-resolved random outcome is applied only inside the applicable
   semantic command transaction.
5. Semantic and canonical mutation remains command-owned.
6. Result validation precedes mutation, history recording, cursor advancement,
   follow-up generation, and success presentation.
7. Invalid or inapplicable results leave the rejecting passive mirror
   unchanged without implying rollback of accepted authority state.
8. Live result payloads are transient and do not become persisted command or
   replay history.
9. Replay remains deterministic seed-plus-command-history re-execution.
10. Authority save/load restores complete RNG state; filtered passive
   reconstruction does not.
11. Fresh, resumed, and reconnected passive live peers obey the same RNG
    visibility and execution rules.
12. Every future live-Network RNG-consuming command defines and verifies an
    explicit authoritative-result application contract before integration.
13. Non-command RNG consumers remain on their accepted filtered publication or
    synchronization surfaces and do not create a generic result mechanism.

## 4. Relationship to existing authority

| Existing source | Normative relationship |
| --- | --- |
| ADR-001 and CON-001 | Preserved. Replayable commands still own semantic attack mutation and atomicity. “Mirrored command application” is clarified to permit validated application of an authority-resolved outcome inside the command transaction without passive RNG execution. |
| ADR-003 and CON-003 | Preserved. A rule capability that consumes RNG must trace its authoritative-result application and Network/replay evidence across the same accepted rule surfaces. |
| ADR-008 | Preserved. The host/server `GameState` remains the writable Network authority; a filtered client mirror does not become an independent owner. |
| ADR-011 | Preserved. Correctly filtered resume/reconnect remains required. Absence of RNG on the passive mirror is now an accepted execution-context boundary rather than missing client authority. No principal, assignment, or save-ownership decision changes. |
| MATCH-003 | Retained within its accepted scope. BUG-042 is a later independent architecture scope that preserves MATCH-003's assignment, filtering, publication, and admission obligations while defining the RNG-result semantics that MATCH-003 did not decide. |
| `StateFilter` RNG removal | Confirmed and clarified. Live RNG seed/state remains authority-only for fresh bootstrap, resume, and reconnect. This ADR does not redesign general filtering. |
| BUG-011 network replay RNG repair | Compatible material remains in force, including replay bootstrap and deterministic replay re-execution. ADR-012 overrides only Section 5's implication that the distributed/shared seed remains applicable to passive peers in normal live Network play; Section 6.1 steps 2-3; and Section 6.1's statement that this shared-seed live behavior remains unchanged. |
| Historical G4 Network plan | Historical evidence only, not normative authority. ADR-012 aligns with the server-only direction in G4 Section 1.4 and rejects the conflicting historical shared-seed guidance in G4.6.5. |

Where older text states or implies that live Network mirrors reproduce the same
random calculation from a shared seed, that guidance is superseded. Statements
that host and mirror reproduce the same semantics or converge on shared
canonical facts are clarified: convergence requires the same accepted realized
outcome, but passive live mirrors apply that outcome rather than reproduce its
hidden random generation.

## 5. Consequences

- `StateFilter` continues to remove RNG from passive client views.
- Live result payloads become validated semantic inputs for the applicable
  command mirror transaction, without becoming durable history or a mutation
  owner, and expose only viewer-authorized realized facts.
- Non-command setup, bootstrap, and resolver RNG effects continue through
  their accepted, appropriately filtered publication or synchronization
  surfaces rather than a generic result mechanism.
- Fresh live Network bootstrap must stop constructing an equivalent RNG on the
  passive peer.
- Existing and future RNG-consuming commands require explicit, fail-closed
  authoritative-result application contracts.
- Replay, authority save/load, attack ownership, command ownership, Network
  principal assignment, and save-game ownership retain their accepted models.

## 6. Explicit non-goals

This ADR does not define:

- concrete result field names, serialization layouts, RPCs, packet formats,
  retries, or protocol-version mechanics;
- a generic alternate mutation or event-application framework;
- a replay result log, replay format redesign, or replay seed-policy change;
- broader `StateFilter` rules beyond the accepted RNG boundary;
- save-game ownership or portability;
- Network principal, assignment, association, or admission architecture;
- attack lifecycle or attack-state ownership;
- the complete general command architecture;
- presentation handling of successful results; or
- implementation order, an implementation workbook, production code, or test
  changes.

## 7. Acceptance boundary

Acceptance of this ADR establishes the normative model but does not establish
implementation conformance or close BUG-042. Implementation shall require a
separately accepted execution specification and evidence covering every current
RNG-consuming command and every applicable fresh, resume, reconnect, save/load,
ordering, failure, security, and replay path.

## 8. Related documents

- `docs/architecture/DOCUMENT_AUTHORITY.md`
- `docs/architecture/adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md`
- `docs/architecture/contracts/CON-001-current-attack-state-and-semantic-transition-contract.md`
- `docs/architecture/adr/ADR-003-rule-and-validation-surfaces.md`
- `docs/architecture/contracts/CON-003-rule-capability-contract.md`
- `docs/architecture/adr/ADR-008-durable-match-lifetime-player-principal-binding.md`
- `docs/architecture/adr/ADR-011-network-match-resume-and-principal-entitlement.md`
- `docs/architecture/implementation_workbooks/MATCH-003-network-match-resume-explicit-side-assignment-implementation-workbook.md`
- `docs/qa/bugs/closed/BUG-011/issue-network-replay-rng-bootstrap-repair-plan.md`
- `docs/qa/bugs/open/BUG-042/issue-Network-resume-loses-deterministic-RNG-required-by-mirrored-RollDiceCommand.md`
- `docs/qa/bugs/open/BUG-042/BUG-042-network-rng-authority-architecture-investigation.md`
