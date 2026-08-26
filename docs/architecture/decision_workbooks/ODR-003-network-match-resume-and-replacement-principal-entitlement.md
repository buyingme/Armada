# ODR-003: Network Match Resume and Replacement-Principal Entitlement

**Status:** Accepted

Accepted by: Project Owner
Accepted date: 2026-08-26

**ODR ID:** ODR-003

**Date:** 2026-08-25

**Decision owner:** Project Owner

**Decisions recorded:** 2026-08-25

**Implementation authorization:** None

**Implementation workbook:** Not created; these decisions authorize no
implementation by themselves

**Desired capability:** Resume a saved Network match in a new Network session
while preserving durable player-principal authority.

**Affected architecture areas:** BC-006, BC-007, BC-008

**Applicable reality gaps:** RG-007, RG-013, RG-016

**Related architecture tasks:** AT-006, AT-008, AT-009

**Primary accepted authority:** ADR-008, ADR-010, accepted MATCH-001

## 1. Purpose and decision boundary

This workbook records the Project Owner's resolved architecture decisions for
the smallest policy set required before implementation architecture can be
specified for fresh-session Network resume.

The current restriction is not treated as a defect. Historical Phase J7
behavior allowed a ready fresh lobby to load a Network save, but MATCH-001
deliberately replaced that behavior with a fail-closed gate after durable
player-principal binding became authoritative. A saved match now identifies
the durable principals controlling its gameplay players, while a new Network
session has no accepted proof that any newly connected peer is entitled to
assume one of those principals.

The problem is therefore not how to deserialize or broadcast a saved
`GameState`. Those paths already exist. The architecture question resolved by
this workbook is:

> How may a new transient Network peer become authoritatively associated with
> an existing saved HUMAN match principal without deriving authority from the
> peer, lobby slot, display name, profile, principal identifier, or possession
> of public canonical state?

This workbook selects the architecture-level entitlement, participation, and
association policies in Section 6. It does not select an implementation,
credential format, cryptographic mechanism, storage design, RPC sequence,
class design, or file plan. Those remain downstream work and receive no
implementation authorization from this record.

## 2. Authority and evidence posture

### 2.1 Accepted authority

1. **ADR-008 — Durable Match-Lifetime Player-to-Principal Binding**
   establishes one immutable `GameState`-owned binding, distinguishes gameplay
   players, match principals, and transport peers, and requires replacement or
   reconnect entitlement to fail closed until a separate accepted authority
   defines proof, validator, and failure behavior.
2. **ADR-010 — Gameplay Interaction Decision-Equivalent Recovery** requires
   equivalent authoritative gameplay situations to yield equivalent
   actionable decision semantics after save/load and reconnect. It does not
   authorize synthetic progression or make presentation authoritative.
3. **Accepted MATCH-001** implements ADR-008's current boundary. It permits an
   in-session Network load only when the loaded binding exactly matches the
   live binding and all existing transient associations remain valid. It
   explicitly blocks fresh-lobby Network load, disconnected-peer
   reassociation, replacement, takeover, and rebinding pending the downstream
   proof, validator, and failure decisions now recorded in Section 6. The
   current implementation block remains until applicable normative architecture
   and authorized implementation replace it.
4. **Document authority and workflow** keep accepted ADRs above workbooks,
   current code as implementation evidence, and historical plans as
   non-normative context.

Before these Owner decisions, no accepted authority defined a Network-session
credential, replacement policy, takeover policy, or cross-host
save-portability promise. This workbook records Owner direction for later
normative architecture; it does not amend ADR-008, ADR-010, or MATCH-001 by
itself.

### 2.2 Current implementation evidence

- `GameState` serializes, deserializes, and validates the canonical
  `match_player_control_binding` before live installation.
- `NetworkManager` stores host and peer principal associations only in
  transient runtime state. Remote command authorization resolves the current
  peer to that host-held association and then asks the canonical binding
  whether the principal controls the command's gameplay player.
- Disconnect removes the peer record and therefore its transient association;
  it does not mutate the canonical principal binding.
- `LobbyManager.host_load_save()` currently requires
  `NetworkManager.can_install_loaded_binding()`. That gate requires an
  `IN_GAME` session, the exact current saved binding, and still-valid host and
  peer associations. A ready fresh lobby is therefore insufficient.
- `SaveGameManager` verifies the save envelope with an installation-local HMAC
  key. That signature detects accidental or unauthorized save editing within
  the current trust boundary; it neither authenticates a peer nor currently
  makes a save portable to a different installation.
- `StateFilter` can reconstruct a filtered client mirror while preserving the
  non-secret principal binding. `UIProjector` re-derives presentation from
  reconstructed state. No production reconnect/snapshot transport currently
  performs the complete reconnect flow.

### 2.3 Historical evidence only

The Phase J7 record in `docs/implementation_plan.md` and the related current UI
seams show that lobby-originated Network load and host-to-client loaded-state
broadcast previously worked. They are useful evidence that the state-load and
scene-rebuild seams exist. They do not answer principal entitlement and cannot
override ADR-008 or accepted MATCH-001.

The archived G4 Network plan describes planned reconnect snapshots, session
tokens, and late join. Those proposals are likewise non-normative and must not
be treated as an accepted credential or reconnect design.

## 3. Required conceptual separation

The resolved architecture and any later implementation must preserve these six
distinct concepts:

| Concept | Meaning and lifetime | Authority | Must not be confused with |
| --- | --- | --- | --- |
| Durable gameplay principal identity | The match-scoped HUMAN or AUTOMATED controller identity that remains bound to one or more gameplay players for the match lifetime | Canonical `GameState` binding under ADR-008 | A human account, a peer, a lobby seat, or an entitlement credential |
| Entitlement to assume a saved principal | Possession of the accepted match-scoped capability for an already-existing HUMAN principal | Validated by the authoritative resume host under OD-1 before it establishes a transient association | Principal ID visibility, save possession, display name, player index, or gameplay legality |
| Transient peer/session identity | A current endpoint and its live session membership and association | Authoritative Network host for the current session only | Durable gameplay identity or proof that survives session loss |
| Canonical saved state | The durable gameplay facts needed to reconstruct the match, including the immutable principal binding and decision-relevant state | `GameState` plus the accepted save envelope and reconstruction cursor | Credentials, current connections, lobby readiness, modal instances, or peer associations |
| Reconstructed Network/session state | Newly established host/peer roles, validated peer-to-principal associations, transport ordering state, and other runtime services needed around the restored canonical state | Rebuilt for the new session; never a second gameplay-state owner | Saved gameplay state or an opportunity to rebind principals |
| Re-derived presentation | Viewer-specific UI intent, camera, modals, waiting state, and other presentation derived after reconstruction | Non-authoritative projection under ADR-010 and existing owners | Entitlement, gameplay legality, or canonical progression |

The saved principal is never replaced by this capability. Under OD-2, a human
who deliberately receives the accepted capability may assume the same existing
principal. This transfer changes neither principal identity nor the canonical
gameplay-player-to-principal mapping.

## 4. Non-negotiable architecture constraints

The resolved Owner decisions operate within these boundaries. Later work may
not relax them without an explicit superseding Owner decision and the
applicable normative architecture process.

1. The canonical `match_player_control_binding` is restored exactly and remains
   immutable. Resume never creates, deletes, or rebinds a principal.
2. A `principal_id` is an identifier, not a secret or proof.
3. ENet peer ID, assigned player index, lobby slot, readiness, display name,
   connected membership, `PlayerProfile.client_id`, lobby password, UI state,
   and current presentation/controller state are not sufficient entitlement
   proof, individually or in combination.
4. The save's integrity signature proves only what its accepted save authority
   defines. It does not prove that a connecting peer controls a saved
   principal.
5. The authoritative host validates entitlement and establishes the transient
   association before accepting player-originated commands for that principal.
   A client assertion cannot authorize itself.
6. Invalid, missing, ambiguous, duplicated, or competing claims fail closed.
   A valid capability does not evict an active association. Failure cannot
   manufacture a principal, silently assign a vacant slot, or change the saved
   mapping.
7. Host authority over the session does not automatically grant the host
   authority over the other saved HUMAN principal.
8. Canonical gameplay state and the reconstruction cursor are validated before
   live publication. Session reconstruction cannot repair invalid gameplay
   state by synthetic commands or inferred progression.
9. A recovered live gameplay decision is derived from accepted canonical
   owners. Presentation may be rebuilt, but it cannot invent, consume,
   complete, or make the decision legal.
10. Credentials or bearer proofs must not enter public canonical state,
    filtered client snapshots, replay payloads, display labels, or logs merely
    because principal identifiers are present there.

## 5. Capability success boundary

A deliberate fresh-session resume is architecturally successful only when this
ordering can be satisfied without bypass:

```text
Authenticated/validated save artifact
        -> exact canonical gameplay reconstruction
        -> immutable saved principal binding preserved
        -> accepted entitlement validation for every saved HUMAN principal
        -> new transient peer-to-existing-principal associations
        -> reconstructed Network/session runtime state
        -> canonical state published as live
        -> next legal gameplay decision or accepted stable state recovered
        -> viewer-specific presentation re-derived
```

The order is conceptual, not an RPC specification. Preparation may stage state
and claims before publication, but no principal-dependent gameplay input may be
accepted until all applicable gates succeed.

Decision-equivalent recovery requires restoration of the accepted command
sequence/reconstruction cursor and every canonical fact needed to determine
the next legal decision. Reopening a modal, replaying a UI callback, advancing
the phase to escape an unrecoverable point, or submitting a synthetic command
only to recreate presentation is not equivalent recovery.

## 6. Smallest coherent Owner decision set

The questions in the request collapse into three resolved decisions.
Credential syntax, cryptographic primitives, RPC payloads, UI steps, and file
layout follow only after these policy decisions.

### OD-1 — Entitlement proof, trust boundary, scope, and portability tier

**Owner question**

What category of evidence proves that a peer may assume an existing saved HUMAN
principal, what is its scope, which authority validates it, what persistence
boundaries constrain it, and what portability tier must the MVP support?

These axes were evaluated together because persistence boundaries and
validation authority depend on whether entitlement must survive multiple
saves, host restart, or host migration.

#### Alternatives

| Alternative | Description | Benefits | Costs and risks | Assessment |
| --- | --- | --- | --- | --- |
| A. Match-scoped principal capability | Each HUMAN principal has distinct proof material valid for the saved match across its checkpoints/saves. A claimant presents proof; the authoritative host validates it against protected resume material separate from canonical gameplay state. | Matches ADR-008's match-scoped principal lifetime; unifies ordinary reconnect and fresh-session resume; avoids accounts; does not make peer identity durable | Requires secure issuance, retention, validation, loss behavior, and a portability choice; bearer-style proof may be transferable | **Selected by Owner** |
| B. Save-scoped capability | Every save/checkpoint creates new proof tied only to that artifact | Natural artifact boundary; revocation by choosing a later save may be possible | Multiple saves create multiple entitlement sets; ordinary reconnect and deliberate resume diverge; stale saves complicate claims; easy to conflate save possession with authority | Not selected |
| C. Installation/profile identity | Treat `PlayerProfile.client_id` or a derived installation identifier as proof | Small apparent implementation cost | Explicitly disallowed as sufficient proof by ADR-008/MATCH-001; client supplied; device replacement and portability semantics are wrong | Rejected by accepted authority |
| D. Lobby/host assertion | A ready slot, display name, lobby password, or host choice establishes entitlement | Simple UX | Recreates the vulnerability the fail-closed boundary prevents; host can silently seize the remote principal | Rejected for proof |
| E. Global account identity | Bind match principals to authenticated accounts | Strong non-transferable person-level continuity is possible | Becomes an account/authentication system, introduces cross-match identity, and exceeds repository evidence and this scope | Deferred/out of scope unless separately authorized |

#### Resolved Owner decision and rationale

The Project Owner selects **A: one match-scoped entitlement capability per
HUMAN principal**, validated by the authoritative resume host before it
establishes a transient peer-to-existing-principal association. Proof material
remains separate from the public canonical `GameState` and from transient
peer/session identifiers. Scope it to the match, not to one save file, so the
same accepted entitlement concept can serve deliberate resume and ordinary
reconnect.

The MVP portability tier is **the original host installation**. This
fits the current installation-local save-integrity trust boundary and avoids
making host-key export, cross-device trust transfer, or a portable
self-verifying entitlement part of the first implementation. Cross-host and
cross-install resume remain explicitly deferred.

Match scope aligns the entitlement lifetime with ADR-008's match-scoped
principals and avoids separate proof semantics for each checkpoint or save.
Limiting the MVP to the original host installation avoids prematurely
designing cross-host trust transfer. This decision does not determine whether
the capability is a code, token, key pair, challenge-response proof, or another
construction.

#### Persistence safety boundary for this decision

- The canonical save may continue to persist non-secret principal IDs, kinds,
  and gameplay-player mapping.
- A non-secret credential identifier or verifier may be persisted only in a
  protected, explicitly defined resume-metadata boundary if the accepted
  mechanism requires it. It is not canonical gameplay state.
- A reusable bearer secret must not be placed in the public `GameState`,
  distributed client snapshots, replay headers, logs, or display metadata.
- Any future cross-host portability decision must define how the new host
  obtains trustworthy validator material without turning public save
  possession into unintended entitlement.

**Owner selection:** A — Match-scoped principal capability; original host
installation MVP.

### OD-2 — Participation, absence, delegation, and host replacement policy

**Owner question**

Which saved HUMAN principals must have an entitled claimant before the resumed
match becomes live, and may entitlement be delegated or newly granted to a
replacement human when an original claimant is absent?

This consolidates “must original players return,” absent-player behavior,
replacement humans, and host-authorized takeover. They are one participation
policy: each changes who may exercise an unchanged saved principal.

#### Alternatives

| Alternative | Description | Benefits | Costs and risks | Assessment |
| --- | --- | --- | --- | --- |
| A. Full entitled participation, no host override | Every saved HUMAN principal must have one validly entitled claimant before live publication. The host cannot grant the other principal or bypass proof. | Smallest fail-closed MVP; clear atomic start gate; no paused live session or takeover semantics | Lost proof or absent claimant blocks resume; does not support host-mediated substitution | **Selected with B** |
| B. Capability-holder substitution | Any person holding a principal's accepted proof may assume it, including a replacement human to whom the proof was deliberately transferred | Supports replacement without accounts or rebinding; proof remains the authority | A bearer capability cannot prove the same physical human returned; transfer/loss and social handling need clear UX | **Selected with A** |
| C. Host-authorized replacement/takeover | The host may issue or replace entitlement for an absent principal | Flexible recovery when a player is unavailable | Gives one player power over another principal; requires explicit consent, audit, revocation, and competing-claim rules; host identity alone is insufficient proof under ADR-008 | Deferred |
| D. Partial live resume | Start with one or more HUMAN principals absent; gameplay waits whenever an absent principal owns the next decision | Allows observation and staged arrival | Requires an absent/waiting lifecycle, late association, quit/forfeit policy, and UI behavior; can strand the session | Defer for MVP |
| E. Account-bound original-person return | Only the same globally authenticated people may return | Strongest interpretation of “original principals return” | Requires account identity and recovery policy; outside this workbook | Out of scope |

#### Resolved Owner decision and rationale

The Project Owner selects **A+B**. Every saved HUMAN principal must have exactly
one validly entitled claimant before the restored match is published live. The
host must prove entitlement for its own saved principal and cannot grant,
manufacture, or bypass entitlement for another HUMAN principal merely by
hosting.

Possession of the accepted principal capability establishes entitlement, not
physical-person identity. Its current holder may deliberately transfer it to
another human, allowing that person to assume the same existing principal.
The system therefore does not claim that the same physical human returned.
Deliberate transfer neither rebinds the canonical gameplay-player-to-principal
mapping nor gives the host a power to manufacture or award entitlement.

Requiring one entitled claimant for every HUMAN principal before publication
keeps the MVP fail closed and avoids introducing an absent-player lifecycle.
Host-mediated takeover, partial resume, absent-player progression, forfeit,
and bot substitution remain deferred.

**Owner selection:** A+B — Full entitled participation with deliberate
capability-holder substitution and no host override.

### OD-3 — Exclusive association, competing claims, and continuity semantics

**Owner question**

May more than one live peer be associated with a HUMAN principal, how are
competing valid-looking claims handled, and should ordinary reconnect and
fresh-session resume use the same entitlement-to-association rule?

#### Alternatives

| Alternative | Description | Benefits | Costs and risks | Assessment |
| --- | --- | --- | --- | --- |
| A. One active association; reject competition | At most one current peer is associated with each HUMAN principal. A competing claim fails closed while that association is active. After confirmed disconnect/session loss, the same proof may establish a new association. | Preserves clear command provenance; no silent eviction or takeover; same rule works for reconnect and resume | Needs precise active/stale session boundaries and retry UX | **Selected by Owner** |
| B. Proof-based incumbent eviction | A new valid claim automatically replaces the current association | Helps a genuine player recover from a stale connection | A copied/stolen proof can evict the incumbent; ordering and race semantics become security policy | Defer |
| C. Host arbitrates competing claimants | Host selects which claimant controls the principal | Simple operational fallback | Makes host discretion a second authority and enables takeover without stronger evidence | Not selected |
| D. Multiple peers share one principal | Multiple current peers may submit for the same HUMAN principal | Cooperative control | Changes command provenance, acknowledgement cardinality assumptions, UX, and abuse surface; not required for resume | Out of scope |

#### Resolved Owner decision and rationale

The Project Owner selects **A**. Each HUMAN principal may have at most one
active peer association. Use one entitlement-validation and association
standard for:

- a peer reconnecting to a still-running authoritative host;
- peers joining a newly created session that is staging a saved match; and
- a replacement endpoint presenting already-accepted entitlement for the same
  existing principal.

The flows may differ in bootstrap ordering, but they use the same proof
standard. A session identifier or old peer ID may correlate a retry; it never
becomes durable gameplay identity or replaces the accepted proof.

While an association is active, a competing claim fails closed even if it
presents a valid copy of the capability. The host does not arbitrate between
claimants, and the new claimant does not evict the incumbent. After confirmed
disconnect or session loss, accepted entitlement may establish a new transient
association to the same principal. This preserves command provenance and
prevents copied proof from becoming an automatic takeover mechanism.

Exact stale-connection detection, retry timing, credential rotation, and proof-
loss recovery remain deferred implementation or later-policy questions.

**Owner selection:** A — One active association; competing claims fail closed;
reconnect and fresh-session resume share one entitlement standard.

## 7. Decision dependency and next workflow sequence

The Project Owner resolved the decisions in this dependency order:

1. **OD-1 — proof, trust, scope, and portability.** This determines what
   evidence persists across session loss and what the resume host validates.
2. **OD-2 — participation and substitution.** Given capability possession as
   proof, this decides who must present it and permits deliberate transfer
   without host-granted takeover.
3. **OD-3 — exclusivity and arbitration.** Given eligible claimants, this
   decides how current associations and competing claims behave.
4. Next, draft the normative ADR or other accepted normative artifact required
   by the repository authority model from these Owner decisions.
5. Only after that normative architecture is accepted may an implementation
   workbook specify storage, protocol, UI, migration, tests, and rollout.

The resulting language intentionally refers to an entitled capability holder,
not “the original physical player,” because OD-1 proves capability possession
rather than physical-person identity.

## 8. Cross-capability dependencies and consequences

| Concern | Consequence of the resolved decisions |
| --- | --- |
| Deliberate save/resume | The save restores the exact canonical binding and gameplay state; a new session establishes fresh associations only after validating the match-scoped proof. Saving must not silently rotate or invalidate match-scoped entitlement. |
| Ordinary reconnect | Uses the same proof-to-existing-principal rule as fresh-session resume. The live host may already hold canonical state, but prior peer ID or freed slot remains insufficient. |
| Replacement peers | A new endpoint may replace a disconnected endpoint only by proving entitlement to the same saved principal. Endpoint replacement never means principal replacement. |
| Replacement humans | Deliberate transfer of the accepted capability lets another human assume the same existing principal. Capability possession, not physical-person identity, establishes entitlement; canonical binding does not change. |
| Competing claims/takeover | Must fail closed without rebinding or eviction. One active association remains authoritative; a second claimant cannot evict it and the host cannot choose between claimants. |
| Absent players | Any saved HUMAN principal without one entitled claimant blocks live publication. Partial resume and absent-player progression are deferred. |
| Host authority | The host validates proof and owns transient associations and authoritative command admission. Hosting does not entitle the host to the remote principal, alter canonical binding, or bypass gameplay legality. |
| Save portability | The MVP supports only the original host installation. Cross-install or new-host resume remains deferred and would require explicit trust transfer or independently verifiable resume material; it cannot be inferred from copying the save file. |
| Decision-equivalent recovery | Restore the command cursor and canonical lifecycle facts, then derive the same next legal gameplay decision or stable state. Presentation is rebuilt; gameplay is not advanced merely to make reconstruction easier. |
| Automated principals | No human peer entitlement proof is required merely because an AUTOMATED principal exists. Bot execution and substitution remain separate architecture/product decisions. |
| Save/replay separation | Entitlement is a live admission concern. Replays may preserve principal labels for historical semantics but must not carry reusable live resume secrets or fabricate live human associations. |

## 9. MVP boundary and safe deferrals

### 9.1 Accepted MVP requirements

The resolved decisions require the smallest coherent MVP to preserve all of
the following:

1. Resume only current-format Network saves that already contain the valid
   canonical principal binding and whatever separately accepted entitlement
   metadata the future mechanism requires.
2. Support the original save-owning host installation only.
3. Use one match-scoped proof per saved HUMAN principal.
4. Require every saved HUMAN principal to have exactly one entitled claimant
   before live publication.
5. Require the host to prove its local principal entitlement as well as
   validating remote claimants.
6. Permit at most one active peer association per HUMAN principal.
7. Reject missing, invalid, ambiguous, duplicate, and competing claims without
   state mutation or partial live installation.
8. Apply the same proof standard to fresh-session resume and ordinary reconnect.
9. Preserve the saved canonical binding exactly and reconstruct session state
   around it.
10. Recover the next legal gameplay decision or stable state without synthetic
    progression and re-derive presentation from authoritative state.
11. Permit deliberate transfer of a principal capability to another human
    without treating that transfer as principal rebinding or host-granted
    takeover.

### 9.2 Capabilities safe to defer

- loading saves created before entitlement material exists;
- cross-install, cross-device, cloud, or new-host save portability;
- global accounts, federated identity, passwords, email, or account recovery;
- host-mediated entitlement grant, unilateral takeover, or entitlement
  revocation;
- partial resume with absent HUMAN principals;
- multiple peers sharing one principal;
- spectators and late join unrelated to taking a saved principal;
- credential rotation, expiry, recovery after loss, and administrative audit;
- bot substitution, automated decision execution, or human/automated kind
  changes;
- seamless UX, invite systems, matchmaking, and general session management;
- legacy save migration when no equivalent entitlement evidence exists.

Deferral means fail closed or remain unsupported. It must not produce a weaker
fallback such as assigning by lobby slot, name, profile, or host choice.

## 10. Non-goals

This workbook does not design or authorize:

- a general account, authentication, identity-provider, or matchmaking system;
- a general participant, multiplayer-session, lobby, invite, or social graph
  framework;
- a replacement or rebinding API for the canonical player-principal mapping;
- changes to gameplay legality, turns, initiative, activation, timing windows,
  attack ownership, acknowledgement, or continuation rules;
- a credential format, cryptographic algorithm, key-management system, RPC,
  protocol version, command payload, database, sidecar file, or class layout;
- save-format allocation, compatibility migration, rollout sequencing, or
  implementation tests;
- replay authentication or treating replay execution as live principal control;
- production reconnect transport, spectators, late join, disconnect timers,
  forfeit, or bot takeover; or
- production code, test changes, or an implementation workbook.

## 11. Stop conditions for later architecture and implementation work

Stop and return to the Project Owner if a proposed direction would require any
of the following without an explicit accepted decision:

1. deriving entitlement from principal ID, player index, peer ID, session ID,
   lobby slot, readiness, display name, profile/client ID, lobby password,
   connected membership, UI state, save possession, or save signature alone;
2. storing reusable proof secrets in canonical `GameState`, shared snapshots,
   replay artifacts, logs, or presentation payloads;
3. changing the saved principal records or gameplay-player mapping;
4. allowing the host to grant, manufacture, bypass, replace, or revoke
   entitlement for another HUMAN principal by discretion;
5. permitting a competing claimant to evict an active association;
6. publishing a partially validated restored state as live;
7. advancing canonical gameplay synthetically to reach an easier resume point;
8. introducing a global account or general session framework;
9. expanding `GameManager` with a new responsibility category before BC-006 /
   RG-007 authority is resolved or an accepted narrow architecture assigns the
   work elsewhere;
10. treating historical J7 or G4 plans as current authority; or
11. claiming implementation readiness without explicit entitlement,
    network-load, save/load, reconnect, competing-claim, and
    decision-equivalent recovery verification obligations.

## 12. Evidence gaps that remain after this workbook

These implementation-evidence and downstream-design gaps do not reopen the
three resolved Owner decisions, but they must be closed before implementation
architecture or acceptance gates are finalized:

1. No production reconnect/snapshot flow currently proves end-to-end session
   reconstruction. Existing tests prove filtered state reconstruction and
   projection, not transport reauthentication or principal reassociation.
2. The repository has no implementation design for secure credential issuance,
   storage, validation, or redaction within the selected match-scoped model.
3. Cross-host and cross-install trust transfer remains deliberately deferred.
   Current save verification is installation-local, consistent with the MVP.
4. Stale-connection detection, retry timing, credential rotation, proof-loss
   recovery, and any future revocation mechanism remain unspecified. Their
   implementation must preserve fail-closed claims and exclusive association.
5. Current user-facing Network setup documentation still describes lobby load
   of a previous Network save, while accepted MATCH-001 and current load gates
   intentionally reject a fresh-session load. This is a documentation drift
   item under RG-016, not evidence that the restriction should be relaxed.
6. Test coverage exists for the fail-closed restriction and reconstruction
   components, but RG-013 remains applicable until a later test strategy maps
   the accepted entitlement and resume invariants end to end.

## 13. Resolved Owner decision record

The Project Owner records these selections:

| Decision | Owner selection | Resulting architecture policy |
| --- | --- | --- |
| OD-1 — proof/trust/scope/portability | **A** | One match-scoped capability per HUMAN principal; authoritative resume-host validation; original-host-installation MVP; cross-host/cross-install portability deferred |
| OD-2 — participation/substitution | **A+B** | Exactly one entitled claimant per saved HUMAN principal before live publication; deliberate capability transfer may authorize a replacement human; no host-granted entitlement, rebinding, partial resume, absent-player progression, forfeit, or bot substitution |
| OD-3 — exclusivity/arbitration/continuity | **A** | At most one active peer association per HUMAN principal; competing claims fail closed without eviction or host arbitration; reconnect and fresh-session resume share the same entitlement standard |

All architecture-level Owner decisions in this workbook are resolved.
Credential format, cryptographic mechanism, storage implementation, RPC design,
stale-connection detection, retry timing, credential rotation, proof-loss
recovery, and cross-host portability remain downstream implementation or
explicitly deferred capability questions; they must not be treated as license
to redesign OD-1, OD-2, or OD-3.

## 14. Authority and evidence consulted

### Governance

- `AGENTS.md`
- `docs/architecture/CODEX_WORKFLOW.md`
- `docs/architecture/DOCUMENT_AUTHORITY.md`
- `docs/architecture/ARCHITECTURE_ROADMAP.md`
- `docs/ARCHITECTURE_BOUNDARY_CANDIDATES.md`
- `docs/ARCHITECTURE_DECISION_TRIAGE.md`
- `docs/REALITY_GAP_REGISTER.md`
- `docs/development/decisions/DA-002-development-documents-in-agent-startup-reading.md`

### Accepted architecture and decision input

- `docs/architecture/adr/ADR-008-durable-match-lifetime-player-principal-binding.md`
- `docs/architecture/adr/ADR-010-gameplay-interaction-decision-equivalent-recovery.md`
- `docs/architecture/implementation_workbooks/MATCH-001-player-principal-binding-owner-decisions.md`
- `docs/architecture/implementation_workbooks/MATCH-001-player-principal-binding-implementation-workbook.md`

### Current implementation and focused tests

- `src/core/state/game_state.gd`
- `src/autoload/network_manager.gd`
- `src/autoload/lobby_manager.gd`
- `src/autoload/save_game_manager.gd`
- `src/core/state/save_game_metadata.gd`
- `src/autoload/game_manager.gd`
- `src/core/network/state_filter.gd`
- `src/core/network/ui_projector.gd`
- `src/autoload/player_profile.gd`
- `tests/unit/test_lobby_manager_load.gd`
- `tests/unit/test_save_game_manager.gd`
- `tests/integration/test_reconnection_mid_attack.gd`

### Historical/non-normative evidence

- `docs/implementation_plan.md`, especially Phase J7
- `docs/old/g4_network_plan.md`
- `docs/qa/bugs/closed/BUG-001/issue_network-save-load-session-bootstrap.md`
- `docs/setup_network_game.md` as current user-facing evidence, not entitlement
  authority
