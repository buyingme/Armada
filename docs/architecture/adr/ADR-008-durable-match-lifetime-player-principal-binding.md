# ADR-008: Durable Match-Lifetime Player-to-Principal Binding

Status: Draft

ADR-ID: ADR-008
Title: Durable Match-Lifetime Player-to-Principal Binding

Decision owner: Project Owner

Binding decision input:

- `docs/architecture/implementation_workbooks/MATCH-001-player-principal-binding-owner-decisions.md`

Supporting evidence only:

- `docs/architecture/implementation_workbooks/ADR-008-architecture-audit.md`

Supersedes:
None

Superseded by:
None

Related:

- MATCH-001
- UX-005
- ADR-001 / CON-001
- ADR-005 / CON-005
- ADR-006 / CON-006
- ADR-007
- TWI-003
- TEST-003
- BC-001
- BC-004
- BC-006
- BC-007
- BC-008
- BC-009
- RG-001
- RG-002
- RG-007
- RG-013

## Draft Note

This ADR translates MP-OD-001 through MP-OD-012 into a stable architecture
decision. The MATCH-001 Owner-decision document is binding Project Owner input.
The architecture audit is supporting evidence only and does not establish
normative architecture.

This ADR remains Draft until accepted by the Project Owner. It authorizes no
implementation by itself and does not create the MATCH-001 implementation
workbook.

## 1. Context And Scope

Armada has a durable gameplay-side identity: commands, rules, initiative,
activation, fleets, and `PlayerState` use gameplay player identity. The
repository also has live transport peers, installation-local profiles, lobby
rows, setup display names, and transient presentation/controller state. None of
those concepts alone answers:

> Which human or automated match principal controls each gameplay player for
> the lifetime of this match?

The missing answer became blocking at ADR-007 Entry Gate A. ADR-007 requires an
authoritative source from which to derive the distinct HUMAN principals whose
acknowledgements are required for completed-attack result inspection. It cannot
derive that set from gameplay player indices, current peers, display names, or
visible controls.

This ADR decides only the durable match-level relationship between gameplay
players and their controlling principals. It does not create an
acknowledgement-specific identity or implement ADR-007 or UX-005.

## 2. Decision And Ownership

### 2.1 Canonical Owner

GameState is the single canonical owner of one immutable match-player-control
binding value. The value encapsulates the principal records, mapping, and their
validation invariants.

The value exists for every started match and remains stable for that match's
lifetime. It is established as a complete value; its principal records, kinds,
and player mappings are not individually rebound, replaced, added, or removed
after the match becomes live.

In authoritative Network play, the authoritative server or host `GameState` is
the writable authority. Serialized state, replay reconstruction input,
snapshots, and client mirrors carry or reproduce the same semantics; they do
not become separate writable owners.

### 2.2 Why GameState

`GameState` has the required match lifetime and is already the canonical
aggregate across authoritative gameplay, save/load, network reconstruction,
and replay reconstruction. A narrow child value adds the missing relation
without introducing a second aggregate lifetime.

`PlayerState` cannot own the relationship because one principal may control
multiple gameplay players. Storing a shared Hot-Seat principal independently
on each `PlayerState` would duplicate a cross-player fact and permit
inconsistent copies.

Lobby and transport state cannot own the relationship because their membership
and peer associations change with connectivity. A principal remains part of a
match while disconnected.

No `SessionState`, `MultiplayerState`, participant framework, or other aggregate
owner is introduced. If later accepted architecture establishes a broader
aggregate, moving this value would require an explicit migration that preserves
one canonical owner.

## 3. Conceptual Model

### 3.1 Gameplay Player

A gameplay player is the rule-side identity used by commands, turns,
initiative, activation, fleets, ships, squadrons, and `PlayerState`. It answers
which gameplay side owns or may perform an action.

A gameplay player identity does not prove which human or automated principal
controls that side.

### 3.2 Match Principal

A match principal is the durable, match-scoped identity of the human or
automated controller responsible for one or more gameplay players.

Each principal has exactly one classification at this architecture level:

- `HUMAN`; or
- `AUTOMATED`.

Principal identity is unique within its match. This ADR introduces no global
account, cross-match user identity, installation identity, or bot identity
system. In particular, `PlayerProfile.client_id` does not silently become an
account or match-principal authority.

“Controller” describes the principal's relationship to a gameplay player. It
is not a second identity hierarchy, controller object, or lifecycle framework.

### 3.3 Transport Peer

A transport peer is a current network endpoint. A peer may have a transient,
authoritatively accepted association with an existing match principal, but the
peer is not the principal.

Disconnecting a peer removes or invalidates only that live association. It does
not delete or replace the principal or change the player/principal mapping.

### 3.4 UI And Controller State

UI/controller state includes local perspective, input focus, enabled controls,
scene nodes, modals, routes, and the principal currently presented by a local
process. It is transient and derived. It neither creates principal identity nor
grants gameplay authority.

## 4. Minimal Canonical Value And Invariants

### 4.1 Canonical Content

The immutable match-player-control binding value contains only:

1. match-scoped principal records, each containing:
   - a stable `principal_id`; and
   - principal kind `HUMAN` or `AUTOMATED`; and
2. a total mapping from every gameplay player in the match to exactly one
   `principal_id` in those records.

The principal records contain exactly the principals referenced by the
mapping. They are not a general participant list.

The exact type name, file, API, field names, enum representation, principal-ID
encoding, and serialized shape are implementation decisions for MATCH-001.

### 4.2 Structural Invariants

A valid value satisfies all of these invariants:

1. Every gameplay player in the match appears exactly once as a mapping key.
2. Every mapping target resolves to exactly one principal record.
3. Every principal record is referenced by at least one gameplay player.
4. Principal IDs are non-empty and unique within the match.
5. Each principal kind is supported by this decision.
6. Duplicate player entries, dangling references, conflicting principal
   records, and incomplete mappings are invalid.
7. The complete value is JSON-safe and independent of transport and scene-tree
   objects.
8. The complete value is immutable after the match becomes live.

Invalid or incomplete binding state fails closed before the match is published
as live or principal-dependent gameplay commands are accepted.

### 4.3 Boundary Exclusions

The canonical value does not contain:

- connection status or peer association;
- lobby membership, lobby slots, readiness, or spectators;
- display names;
- credentials or authentication proof;
- `PlayerProfile.client_id` as account or principal identity;
- UI/controller nodes or state;
- active player, initiative, timing-window controller, or turn state;
- bot decision state;
- generic acknowledgement or continuation state; or
- a generic participant, session, controller, or current-step FSM.

## 5. Mode And Controller Semantics

The model structurally represents all of these configurations:

| Configuration | Required principal structure | Player mapping |
| --- | --- | --- |
| Hot-Seat | One `HUMAN` principal | Both gameplay players map to that one principal. |
| Two-human Network | Two distinct `HUMAN` principals | Each gameplay player maps to the human controlling that side. |
| Human versus automated | One `HUMAN` and one `AUTOMATED` principal | Each gameplay player maps to its applicable principal. |
| Automated versus automated | Multiple `AUTOMATED` principals are permitted, including two distinct automated principals | Each of the two gameplay players may map to its own automated principal; the match contains zero HUMAN principals. |

The architecture does not require at least one HUMAN principal. It does not
create synthetic human principals for automated-only matches.

`AUTOMATED` is only a principal classification here. Structural support for an
automated-versus-automated mapping does not claim that AI-vs-AI gameplay is
implemented or approved as a product mode.

### 5.1 Control Authorization And Gameplay Legality

Gameplay commands continue to identify the gameplay player whose side is
acting. Existing rule, turn, initiative, activation, current-attack, and
timing-window authorities continue to decide whether that gameplay player may
act now.

The binding answers a separate question: whether the submitting local
controller or peer is authoritatively associated with the principal bound to
that gameplay player. A valid association never makes an otherwise illegal
gameplay command legal.

In Hot-Seat, the one HUMAN principal may submit for both gameplay players, but
existing gameplay state still determines which player may act at each point.

## 6. Creation And Reconstruction Invariant

Every supported path that creates or reconstructs a live match must establish
and validate the complete match-player-control binding before the match is
published as live or principal-dependent gameplay commands are accepted.

This applies conceptually to normal setup, supported scenarios, load, replay,
reconnect reconstruction, and any other supported bootstrap or reconstruction
path. Creation inputs such as play mode, accepted setup configuration, or
lobby assignments may help construct the value, but they cease to be authority
once the canonical value is installed.

No consumer may lazily create or infer principals when networking, UI,
ADR-007, or a gameplay command first asks for them.

## 7. Save And Load Durability

New authoritative state must preserve the canonical binding across save/load
where authoritative behavior depends on it.

Loading must restore or validly reconstruct and validate the binding before
principal-dependent gameplay becomes live. Restoration must not derive
principal identity from current peers, display names, UI state, or current
connected-peer membership.

This ADR does not require acceptance or reconstruction of legacy saves. If a
later compatibility decision supports legacy reconstruction, the reconstructed
semantics must preserve the applicable principal cardinality and
gameplay-player mapping semantics, including shared Hot-Seat control and
distinct two-human Network control where applicable.

MATCH-001 must decide the exact serialized fields, version allocation,
compatibility disposition, reconstruction algorithm, rejection behavior, and
resave policy under the repository's existing save compatibility authority.

## 8. Replay Durability

Replay reconstruction must establish the same semantic match-player-control
binding before principal-dependent behavior occurs.

Replay must not fabricate live peers merely to construct principals. The
binding must not change according to whether replay executes in one process,
through Hot-Seat presentation, or through a network harness.

This ADR does not decide replay carrier or header fields, format versions,
legacy replay conversion, rerecording, fixture replacement, or cutover
sequencing. MATCH-001 must make those implementation and compatibility choices
under the existing replay compatibility authority.

## 9. Transport Changes And Reconnect Stop

The principal records and gameplay-player mapping survive transport changes.
Disconnecting a peer must not delete, replace, or redefine a principal.
Reconnect reconstruction preserves or restores the same binding wherever
authoritative behavior depends on it.

A reconnecting or replacement peer must not act for an existing principal
until an accepted authority validates that peer's entitlement to that
principal. An invalid, ambiguous, or competing claim must fail closed; failure
must not create a new principal or silently rebind a gameplay player.

The accepted proof, validating authority, and failure protocol are a separate
downstream architecture decision required before replacement-peer entitlement
is implemented. That decision should be no broader than necessary to answer:

> What accepted match-scoped proof allows a reconnecting or replacement peer
> to be associated with an existing human match principal, which authority
> validates that entitlement, and how do invalid or competing claims fail
> closed without creating or rebinding a principal?

This ADR does not choose a credential type, account system, expiry, rotation,
replacement policy, privacy model, token persistence, or detailed reconnect
protocol. The downstream stop does not block acceptance of this ADR or
implementation of non-replacement binding semantics.

## 10. Visibility And Security Boundary

A principal ID identifies a match principal; it is not authentication proof.
Visibility of a principal record or mapping never authorizes a peer, local
controller, or command.

Authentication credentials or proof are not part of the public canonical
binding merely because principal identity is canonical. Exact state-filter,
projection, and transport mechanics belong in MATCH-001 and, where applicable,
the downstream reconnect-authentication decision.

Display names and side labels remain presentation/setup information. They do
not become identity or authority.

## 11. Relationship To Existing Authority

| Existing authority | Relationship to ADR-008 |
| --- | --- |
| ADR-001 / CON-001 | `CurrentAttackState` ownership and semantic attack mutation remain unchanged. Attacker, defender, and submitting-player indices remain gameplay identities. Principal authorization does not move or duplicate attack state. |
| ADR-005 / CON-005 | Timing-window controller values remain gameplay-player identities. Timing lifecycle, opportunity derivation, and continuation stay with their accepted owners. |
| ADR-006 / CON-006 | Ship-activation and attack-declaration ownership, legality, and controller-independent command paths remain unchanged. The binding determines who may act for a gameplay player, not whether the gameplay action is legal. |
| ADR-007 | ADR-008 supplies the authoritative source from which ADR-007 can eventually derive distinct HUMAN acknowledgement principals. ADR-007 retains all inspection, acknowledgement, and continuation authority. |
| TWI-003 | Its accepted declaration migration and player-index semantics remain gameplay-side concerns. TWI-003 gains no participant, session, peer, or principal ownership. |
| TEST-003 | Its timing-window verification categories remain unchanged. Future MATCH-001 verification must preserve those boundaries where principal authorization meets timing-window commands. |
| Setup Flow Contract | Required player display names remain side labels and setup presentation data, not principal identity. |
| Save/replay compatibility authority | Existing compatibility owners and document authority remain in force. ADR-008 allocates no format version and makes no legacy-artifact disposition. |

No contradiction with these accepted authorities is introduced, and this ADR
does not amend them.

## 12. ADR-007 And UX-005 Consequence

After MATCH-001 implementation provides the authoritative source, ADR-007 can
derive the required acknowledgement set as the distinct `principal_id` values
with kind `HUMAN` that are referenced by the gameplay-player mapping:

- Hot-Seat: one HUMAN principal produces one required human acknowledgement;
- two-human Network: two distinct HUMAN principals produce two required human
  acknowledgements;
- human versus automated: only the HUMAN principal participates in human-style
  acknowledgement; and
- automated versus automated or another zero-HUMAN configuration: no HUMAN
  principal participates, and no synthetic human acknowledgement is created.

AUTOMATED principals do not require human-style acknowledgement under this
decision. A different requirement would need a later explicit Project Owner
decision.

This consequence does not implement ADR-007 or UX-005 and does not mean
ADR-007 Entry Gate A has passed. The formal gate must be rerun after MATCH-001
implementation provides the actual authoritative source and derivation.

## 13. Consequences And Tradeoffs

Positive consequences:

- every supported match can answer who or what controls each gameplay player
  from one stable source;
- Hot-Seat directly represents one human controlling both sides;
- two-human Network and zero-human automated structures remain distinct;
- transport changes do not redefine match identity;
- save/load and replay can reconstruct principal-dependent behavior without UI
  or peer identity; and
- ADR-007 can derive human acknowledgement cardinality without becoming a
  participant authority.

Tradeoffs:

- `GameState` gains one narrow immutable child value;
- every supported creation and reconstruction path must establish it;
- command submission must distinguish principal association from gameplay
  legality;
- save and replay integration require explicit downstream compatibility
  planning; and
- replacement-peer entitlement remains blocked on its separate architecture
  decision.

## 14. Alternatives Considered

| Alternative | Disposition |
| --- | --- |
| Treat gameplay player index as principal identity | Rejected. It cannot distinguish one Hot-Seat human controlling two players from two Network humans. |
| Store principal facts on each `PlayerState` | Rejected. It duplicates a shared many-to-one relation and permits inconsistent copies. |
| Use peer, lobby, display-name, or `PlayerProfile.client_id` identity | Rejected. Those facts have the wrong lifetime or authority and do not cover all configurations. |
| Add a separate generic session or participant aggregate | Rejected. Repository evidence supports `GameState` as the existing match-lifetime aggregate; another owner adds an unnecessary synchronization seam. |
| Derive principals at each point of use | Rejected. Mode-, peer-, name-, or UI-based inference creates multiple authorities and changes with transport or presentation state. |

## 15. Non-Goals

This ADR does not define or authorize:

- bot behavior, planning, decision enumeration, difficulty, or scheduling;
- generic decision routing or a bot lifecycle/controller framework;
- AI-vs-AI gameplay or product-mode behavior;
- a generic acknowledgement or continuation framework;
- a generic session, participant, multiplayer, or controller framework;
- matchmaking, lobby redesign, spectators, or social presence;
- transport protocols, account identity, or login architecture;
- principal rebinding, handoff, takeover, or kind mutation during a match;
- concrete implementation, migration, tests, fixtures, or baseline updates; or
- implementation of ADR-007 or UX-005.

## 16. Owner-Decision Traceability

| Owner decision | Result | ADR mapping |
| --- | --- | --- |
| MP-OD-001 | PASS | Sections 2 and 4 establish one immutable authoritative match-lifetime binding. |
| MP-OD-002 | PASS | Section 3 separates gameplay player from controlling principal. |
| MP-OD-003 | PASS | Section 5 represents one HUMAN principal controlling both Hot-Seat gameplay players. |
| MP-OD-004 | PASS | Section 5 requires two distinct HUMAN principals for two-human Network play. |
| MP-OD-005 | PASS | Sections 3 and 5 permit HUMAN plus AUTOMATED, multiple AUTOMATED principals, two distinct AUTOMATED principals for the two players, and zero HUMAN principals without defining bot behavior. |
| MP-OD-006 | PASS | Section 12 excludes AUTOMATED principals from human-style acknowledgement and prohibits synthetic human acknowledgement in zero-HUMAN configurations. |
| MP-OD-007 | PASS | Sections 3 and 9 preserve the principal and mapping across disconnect/reconnect independently of peer identity. |
| MP-OD-008 | PASS | Sections 3, 7, and 10 reject player index, peer ID, display name, connected-peer membership, and UI/controller state as sufficient principal identity. |
| MP-OD-009 | PASS | Section 3 makes identity match-scoped and rejects implicit account semantics for `PlayerProfile.client_id`. |
| MP-OD-010 | PASS | Sections 6 through 9 require durability or valid reconstruction where authoritative behavior depends on the binding while deferring exact serialization and compatibility to MATCH-001. |
| MP-OD-011 | PASS | Sections 2 and 4 select `GameState` as the single narrow canonical owner; the value is not a second owner and excludes general session state. |
| MP-OD-012 | PASS | Sections 1 and 15 keep bot logic, generic routing, transport, matchmaking, accounts, session frameworks, and controller FSMs out of scope. |

## 17. Implementation Handoff To MATCH-001

The future MATCH-001 implementation workbook must translate this decision into
execution detail. It owns, at minimum:

- concrete value representation, APIs, principal-ID encoding, and validation
  integration;
- the exact creation/reconstruction seam inventory and no-bypass proof;
- setup and scenario carrier mechanics;
- command-submission and transient peer-to-principal association mechanics;
- serialization shape, save version allocation, and legacy-save compatibility
  disposition;
- replay carrier, format allocation, legacy-replay disposition, and any
  fixture rerecord or replacement plan;
- state-filter, projection, and transport integration mechanics;
- the detailed test matrix, test-file organization, and evidence plan;
- migration order, semantic cutover, rollback posture, and implementation
  entry/exit gates; and
- explicit enforcement of the reconnect-authentication stop for any
  replacement-peer slice.

MATCH-001 may choose among conforming implementation options. It may not change
the single-owner model, binding immutability, mode/cardinality semantics,
zero-HUMAN support, conceptual identity distinctions, or downstream reconnect
stop without a new accepted architecture decision.
