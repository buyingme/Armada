# ADR-008 Architecture Audit

Status: Audit Evidence
Date: 2026-08-15

## Purpose

This document preserves the independent architecture audit of Draft ADR-008.

It is supporting architecture evidence only.

It is not an ADR, contract, implementation specification, or accepted
architecture authority.

The audit disposition was:

**SUBSTANTIAL REFINEMENT**

The selected GameState-owned match player/principal binding architecture was
accepted in principle. The required refinement primarily concerns ADR/workbook
separation, removal of unauthorized compatibility decisions, and document
reduction.

# 1. Startup documents read

Before beginning the audit, I read these required startup documents in full:

1. [AGENTS.md](/Users/Katharina/godot/Armada/AGENTS.md)
2. [ARCHITECTURE.md](/Users/Katharina/godot/Armada/ARCHITECTURE.md)
3. [AI_DEVELOPMENT_PRINCIPLES.md](/Users/Katharina/godot/Armada/docs/development/AI_DEVELOPMENT_PRINCIPLES.md)
4. [AI_DEVELOPMENT_PROCESS.md](/Users/Katharina/godot/Armada/docs/development/AI_DEVELOPMENT_PROCESS.md)
5. [AI_STARTUP_GUARDRAILS.md](/Users/Katharina/godot/Armada/.ai/instructions/AI_STARTUP_GUARDRAILS.md)
6. [DOCUMENT_AUTHORITY.md](/Users/Katharina/godot/Armada/docs/architecture/DOCUMENT_AUTHORITY.md)
7. [ARCHITECTURE_ROADMAP.md](/Users/Katharina/godot/Armada/docs/architecture/ARCHITECTURE_ROADMAP.md)
8. [CODEX_WORKFLOW.md](/Users/Katharina/godot/Armada/docs/architecture/CODEX_WORKFLOW.md)

I then read both primary audit inputs in full, the listed accepted ADRs/contracts/workbooks/test strategy, the complete current UX-005 issue and relevant history, setup/replay compatibility authority, and the requested implementation and test surfaces.

# 2. Overall audit disposition

**SUBSTANTIAL REFINEMENT**

The central architecture is sound: one narrow immutable GameState-owned binding is the smallest credible ownership model supported by the repository.

The Draft is not ready for Project Owner acceptance because it materially crosses the ADR/workbook boundary and makes normative save/replay compatibility decisions that MP-OD-010 explicitly deferred. These defects can be corrected without reopening the core ownership decision and without a new Owner decision for ADR-008 itself.

# 3. Ratings

| Area | Rating |
|---|---:|
| Architecture correctness | 8/10 |
| Owner-decision fidelity | 8/10 |
| Ownership clarity | 8/10 |
| Scope discipline | 5/10 |
| ADR/workbook separation | 4/10 |
| Hot-Seat/Network correctness | 9/10 |
| Future automated-control compatibility | 9/10 |
| Implementation readiness | 7/10 |
| Document efficiency | 4/10 |
| Confidence | **High** |

# 4. MP-OD-001–MP-OD-012 fidelity

| Decision | Result | Assessment |
|---|---|---|
| MP-OD-001 | PASS | Establishes one authoritative, immutable, match-lifetime binding. |
| MP-OD-002 | PASS | Cleanly separates gameplay player from controlling principal. |
| MP-OD-003 | PASS | Represents one Hot-Seat human controlling both gameplay players directly. |
| MP-OD-004 | PASS | Requires two distinct human principals in two-human Network play. |
| MP-OD-005 | PASS | Permits `AUTOMATED` principals without defining bot behavior. |
| MP-OD-006 | PASS | Excludes automated principals from human acknowledgement requirements absent a later decision. |
| MP-OD-007 | PASS | Keeps the binding stable across disconnect/reconnect and separates it from peer identity. The authentication stop does not weaken this decision. |
| MP-OD-008 | PASS | Correctly rejects peer ID, display name, UI/controller state, connected membership, and player index as sufficient identity. |
| MP-OD-009 | PASS | Uses match-scoped identity and avoids turning `PlayerProfile.client_id` into an account identity. |
| MP-OD-010 | **PARTIAL** | The durability obligation is faithful, but mandatory legacy-save reconstruction and mandatory replay rerecord/cutover policy strengthen the decision despite its explicit compatibility deferral at [MATCH-001 owner decisions:84](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/MATCH-001-player-principal-binding-owner-decisions.md:84). |
| MP-OD-011 | PASS | Selects a narrow GameState-owned value without adding general session state. “Semantic owner” wording should be simplified, but the model itself is faithful. |
| MP-OD-012 | PASS | Does not introduce bot logic, generic routing, accounts, matchmaking, a session framework, or controller FSM. |

# 5. Architecture findings by severity

| Severity | Finding |
|---|---|
| **BLOCKING** | The Draft makes Owner-deferred compatibility decisions. Section 8 requires otherwise-valid legacy saves to be accepted and reconstructed from `game_mode`; Section 9 requires legacy replays to be rerecorded rather than converted. MP-OD-010 defers exact serialization and compatibility, and ADR-007 assigns accept/migrate/reject and replay cutover to the implementation workbook. |
| **BLOCKING** | The ADR/workbook boundary is materially violated. Candidate inventories, exact bootstrap seams, detailed compatibility behavior, state-filter mechanics, twelve implementation gate items, test organization, and cutover sequencing occupy a large part of the 917-line Draft. This must be reduced before acceptance under the requested audit standard. |
| **HIGH** | Sections 8 and 9 turn reasonable implementation options into architecture obligations. The mode-cardinality semantics are architectural; the legacy acceptance, resave, failure branches, carrier placement, format cutover, and rerecord procedure are not. |
| **MEDIUM** | The Draft says GameState owns the value while the value is the “sole semantic owner” at [ADR-008:147](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-008-durable-match-lifetime-player-principal-binding.md:147). This creates avoidable two-level ownership language. GameState should be the canonical owner; the value should encapsulate the facts and invariants. |
| **MEDIUM** | The reconnect stop correctly requires proof of entitlement, but the mandatory future-decision scope extends unnecessarily into privacy, expiry, rotation, and replacement policy at [ADR-008:599](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-008-durable-match-lifetime-player-principal-binding.md:599). Those concerns belong only if the later mechanism actually needs them. |
| **MEDIUM** | “Public between participating humans” and exact state-filter pass-through are stronger than required here. The architectural rule is that principal IDs are not authentication proof and credentials must not enter the public binding. Exact projection belongs in MATCH-001. |
| **LOW** | Accepted ADR/contract content and Owner decisions are restated repeatedly across context, relationships, invariants, non-goals, alternatives, mapping, consequences, and implementation obligations. |
| **NOTE** | No contradiction was found with ADR-001/CON-001, ADR-005/CON-005, ADR-006/CON-006, ADR-007, TWI-003, or TEST-003. No amendment is required merely to mention ADR-008. |

# 6. Ownership assessment

The selected ownership model is the narrowest sound model.

`GameState` is the only existing canonical object with the required match lifetime and established save, authoritative synchronization, reconnect-state, and replay reconstruction boundaries. A separate `SessionState` would create a second lifetime and synchronization seam without evidence. `PlayerState` cannot own the relation because Hot-Seat is many gameplay players to one principal.

The minimal conceptual content is justified:

- a match-scoped principal identifier;
- a `HUMAN` or `AUTOMATED` kind;
- a total gameplay-player-to-principal mapping.

The distinctions are correct:

- gameplay player: rule-side identity;
- principal: durable identity of who or what controls a side;
- peer: current transport endpoint;
- UI/controller: transient presentation/input state.

Recommended wording:

> GameState is the single canonical owner of one immutable match-player-control binding value. The value encapsulates the principal records, mapping, and their validation invariants.

That removes “semantic owner” as a second ownership layer.

# 7. GameState boundary assessment

The proposed value does not become a disguised `SessionState` or `MultiplayerState`. Its exclusions are sound.

It must not contain:

- connection status or peer association;
- lobby membership, slots, readiness, or spectators;
- display names;
- credentials or authentication proof;
- `PlayerProfile.client_id`;
- controller nodes or UI state;
- active player, initiative, timing-window controller, or turn state;
- bot decision state;
- generic acknowledgement, continuation, participant, or FSM state.

Current implementation evidence supports this boundary:

- [GameState](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:6) already owns canonical match gameplay state and serialization.
- [PlayerState](/Users/Katharina/godot/Armada/src/core/state/player_state.gd:5) is per-gameplay-side state.
- [FleetSetupPackage](/Users/Katharina/godot/Armada/src/core/setup/fleet_setup_package.gd:6) is consumed setup input.
- [PlayMode](/Users/Katharina/godot/Armada/src/autoload/play_mode.gd:13) is process-level mode selection, not durable participant identity.
- [PlayerProfile](/Users/Katharina/godot/Armada/src/autoload/player_profile.gd:4) is installation-local profile identity.

# 8. Hot-Seat assessment

Hot-Seat is correctly first-class:

```text
one HUMAN principal
    → gameplay player 0
    → gameplay player 1
```

The Draft correctly preserves existing gameplay semantics:

- commands still identify a gameplay player;
- player-index validation remains;
- active-player and turn rules remain;
- timing-window authority remains;
- one principal controlling both sides does not authorize simultaneous action.

The two setup display names required by setup authority remain side labels. They do not imply two humans or two principals.

# 9. Network assessment

The Network model is correct:

```text
HUMAN principal A → gameplay player 0
HUMAN principal B → gameplay player 1
```

Neither principal is a peer ID, lobby slot, display name, current connection, UI object, or `PlayerProfile.client_id`.

Current implementation confirms why the separation is necessary:

- [NetworkManager](/Users/Katharina/godot/Armada/src/autoload/network_manager.gd:420) accepts a client-supplied profile ID during handshake.
- It assigns the first available player slot at [NetworkManager:907](/Users/Katharina/godot/Armada/src/autoload/network_manager.gd:907).
- Command authorization currently compares the command player index with the transient peer slot at [NetworkManager:608](/Users/Katharina/godot/Armada/src/autoload/network_manager.gd:608).
- Disconnect removes transient peer state.
- Lobby rows are similarly current-connectivity/setup records, not durable principals.

The Draft does not accidentally assume a stable existing peer association; it explicitly identifies that association as missing.

# 10. Automated-controller assessment

The Draft does exactly enough conceptually:

```text
HUMAN principal       → gameplay player
AUTOMATED principal   → gameplay player
```

`AUTOMATED` is a classification needed for human acknowledgement cardinality. It does not define how automated choices are produced.

No bot planning, difficulty, decision enumeration, scheduling, simulation, generic routing, or bot lifecycle should remain beyond explicit non-goals. The present core model is future-compatible without becoming a controller framework.

# 11. Reconnect-authentication dependency assessment

**Classification: B — ADR-008 can be accepted with reconnect authentication as an explicit downstream architecture stop.**

The unresolved proof question does not block the ownership decision and does not show the GameState model is unworkable. Durable principal identity and transport authentication are cleanly separable:

1. ADR-008 defines what the principal means and who owns the binding.
2. Match creation establishes the principal.
3. A later decision defines how a replacement peer proves entitlement to that already-existing principal.

The minimum stop is:

> A reconnecting or replacement peer must not act for an existing principal until an accepted authority has validated its entitlement. Failure must not create or rebind a principal.

ADR-008 should not require a credential type, expiry model, rotation model, account system, or persistence mechanism.

A narrow reconnect-authentication ADR is required before replacement-peer entitlement is implemented because no accepted document currently owns that architectural proof/validator boundary. It is not required before refined ADR-008 acceptance or before implementing non-reconnect binding semantics.

# 12. Save/load assessment

The architecture obligations that belong in ADR-008 are:

- new saves preserve the canonical binding with its GameState owner;
- load restores and validates it before the match becomes live;
- restored identity must not depend on current peers, UI, names, or current `PlayMode`;
- any supported reconstruction must produce Hot-Seat one-human/two-player semantics or Network two-distinct-human semantics.

The Draft goes too far at [ADR-008:477](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-008-durable-match-lifetime-player-principal-binding.md:477) by requiring all otherwise-valid pre-MATCH saves to be accepted through `game_mode` reconstruction and resaved.

That reconstruction is an evidence-supported implementation possibility because signed save metadata already contains `game_mode`. It is not forced by accepted architecture. Current save loading rejects non-current versions at [SaveGameManager:213](/Users/Katharina/godot/Armada/src/autoload/save_game_manager.gd:213), and ADR-007 explicitly assigns accept/equivalent/migrate/reject to the implementation workbook at [ADR-007:589](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-007-purpose-specific-completed-attack-result-inspection-lifecycle.md:589).

The exact version, algorithm, branches, resave behavior, and reject rules must move to MATCH-001.

# 13. Replay assessment

The sound architecture requirement is:

- replay input must reconstruct the same semantic binding before principal-dependent behavior;
- replay must not simulate live peers merely to construct principals;
- recorded identity must not change according to whether the runner uses one process or the network harness.

The Draft overreaches by requiring the complete table in a particular initial carrier and by mandating that old replays be rerecorded at [ADR-008:523](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-008-durable-match-lifetime-player-principal-binding.md:523).

Current `GameReplay` lacks play mode and binding data and accepts only its exact current format at [game_replay.gd:32](/Users/Katharina/godot/Armada/src/core/commands/game_replay.gd:32). Therefore compatibility work is genuinely required. But the [Replay Baseline Workflow](/Users/Katharina/godot/Armada/docs/development/REPLAY_BASELINE_WORKFLOW.md:1) explicitly says it does not define replay semantics or format policy. Its rerecord procedure applies after an owning compatibility decision; it does not itself make that decision.

Carrier placement, format allocation, old-replay disposition, and fixture rerecording belong in MATCH-001.

# 14. Bootstrap-path assessment

All supported paths were covered:

- normal Hot-Seat setup;
- normal Network setup;
- setup-package bootstrap;
- fixed scenarios;
- learning/debug scenarios;
- loaded-state installation;
- replay bootstrap;
- reconnect snapshots.

The correct ADR-level requirement is:

> Every supported live-match creation or reconstruction path must establish and validate the complete binding before publishing a live match or accepting gameplay commands.

The current Draft’s exact `GameManager`, `FleetSetupBootstrapper`, board, replay, and scenario-path inventories are useful evidence and workbook material. They need not remain normative ADR prose.

# 15. ADR-007 / UX-005 consequence

ADR-008 provides the missing authority conceptually:

- Hot-Seat: distinct `HUMAN` set cardinality is one.
- Two-human Network: distinct `HUMAN` set cardinality is two.
- Human plus automated: only the human principal enters the human acknowledgement set.

This directly addresses the Entry Gate A failure described at [ADR-007:504](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-007-purpose-specific-completed-attack-result-inspection-lifecycle.md:504) and the UX-005 failure where transient local acknowledgement allowed automatic continuation at [UX-005 issue:246](/Users/Katharina/godot/Armada/docs/qa/ux/verify/UX-005/issue-Allow-player-to-inspect-anti-squadron-attack-result-before-continuing.md:246).

A design pre-check can occur after ADR-008 acceptance, but the formal Entry Gate A pass should be rerun only after MATCH-001 implementation provides the actual authoritative source and mode derivation. Reconnect acknowledgement remains subject to the separate entitlement stop.

# 16. ADR/workbook boundary assessment

| Topic | Classification | Disposition |
|---|---|---|
| GameState ownership and immutable binding | A — required architecture | Keep |
| Gameplay player/principal/peer separation | A | Keep |
| Match-scoped identity | A | Keep |
| Stable persistence across durability boundaries | A | Keep |
| Exact restoration of new-format binding | B — necessary consequence | Keep concisely |
| Legacy-save Hot-Seat/Network cardinality if reconstruction is supported | B | Keep as a conditional semantic constraint |
| Mandatory acceptance of legacy saves | E — unauthorized additional decision | Remove from ADR; decide in MATCH-001 |
| Resave and exact legacy failure branches | D — workbook material | Move |
| Replay reconstruction without live peers | A/B | Keep |
| Exact replay header fields/carrier | D | Move |
| Mandatory old-replay rerecord policy | E | Remove from ADR; decide under replay compatibility authority |
| Disconnect preserves principal | A | Keep |
| Reconnecting peer needs validated entitlement | B | Keep as stop |
| Credential type/lifecycle/expiry/rotation | E at this stage | Remove from ADR |
| Every live bootstrap path has a valid binding | A | Keep |
| Function/file/path bootstrap inventory | D | Move |
| Principal ID is not authentication proof | B | Keep |
| Exact public filtering/pass-through mechanics | D | Move |
| Automated principal kind | A | Keep |
| Bot examples and non-goals | C — useful rationale | Retain briefly |
| Command/network adaptation details | D | Move, retaining the authorization invariant |
| Detailed test matrix and implementation sequencing | D | Move |

# 17. Section-by-section reduction classification

| Draft section | Classification | Required treatment |
|---|---|---|
| Front matter/references | KEEP | Keep status, inputs, decision scope, and authoritative relationships. |
| Draft Note | CONDENSE | One short authority/implementation disclaimer. |
| §1 Context and gap | CONDENSE | Retain UX-005/ADR-007 gap and repository conclusion; remove the long evidence catalog. |
| §1.2 Candidate verification | CONDENSE | Keep the decisive owner comparison; move detailed path evidence or remove where duplicated by §17. |
| §2 Decision and owner | KEEP | Preserve substantially; clarify that GameState is the owner and the value encapsulates semantics. |
| §3 Conceptual model | KEEP | This is core architecture. |
| §4 Minimal canonical state | CONDENSE | Keep minimal facts and validation invariants; move exact visibility/carrier mechanics. |
| §5 Establishment paths | CONDENSE | Retain Hot-Seat, Network, and universal bootstrap requirement. Move detailed path inventory to MATCH-001. |
| §6 Command authority/Hot-Seat | KEEP | Short, important separation of control authorization and gameplay legality. |
| §7 Network/reconnect boundary | CONDENSE | Keep durable-versus-live relation and stop; move current function-level evidence. |
| §8 Save/load | CONDENSE | Keep architecture durability obligations. Move compatibility allocation and remove mandatory legacy acceptance. |
| §9 Replay | CONDENSE | Keep semantic reconstruction. Move carrier, cutover, format, and fixture policy. |
| §10 Automated controllers | KEEP | Already appropriately narrow; minor prose trimming only. |
| §11 Visibility/projection | CONDENSE | Keep identity-is-not-proof and credential exclusion. Move state-filter implementation. |
| §12 Reconnect stop | CONDENSE | Keep minimum proof/validator/fail-closed question. Remove speculative credential lifecycle requirements. |
| §13 Existing architecture relationships | CONDENSE | Replace repeated summaries with a compact non-contradiction/ownership table. |
| §14 ADR-007 consequence | KEEP | Core reason the architecture is needed. |
| §15 Invariants | CONDENSE | Preserve all substantive invariants but merge duplicates from earlier sections. |
| §16 Non-goals | CONDENSE | Retain generalization stops; remove repeated variants. |
| §17 Alternatives | CONDENSE | Keep GameState versus PlayerState/lobby/session alternatives; collapse the rest. |
| §18 Owner-decision mapping | KEEP | Compact and useful for traceability. Correct MP-OD-010 mapping after refinement. |
| §19 Consequences | KEEP | Retain concise positive consequences and tradeoffs. |
| §20 Implementation obligations | **MOVE TO MATCH-001 WORKBOOK** | Leave only a short architecture-conformance entry obligation: no bypass, one owner, fail closed, reconnect stop honored. |
| §21 Deferrals/decisions | CONDENSE | Move file/API/version/test deferrals to MATCH-001; retain only the reconnect architecture stop. |

# 18. Recommended target shape and approximate size

Current size: **917 lines / approximately 6,459 words**.

It is materially oversized for the narrow decision, principally because it combines:

- architecture decision;
- implementation evidence inventory;
- implementation workbook;
- compatibility plan;
- test-entry gate;
- repeated traceability summaries.

A document in the requested **300–500-line range is feasible without weakening authority**. A reasonable target is approximately **400–500 lines**, probably around 450 lines.

Recommended shape:

1. Context and ADR-007 gap.
2. Decision and GameState ownership rationale.
3. Conceptual model and minimal canonical facts.
4. Core invariants and GameState exclusions.
5. Hot-Seat, Network, and minimal automated semantics.
6. Universal creation/reconstruction requirement.
7. Save/replay durability obligations.
8. Durable-principal versus live-peer boundary and reconnect stop.
9. Accepted-architecture relationships.
10. Consequences, non-goals, alternatives, and Owner mapping.
11. Short implementation handoff to MATCH-001.

Sections 2, 3, 6, 10, 14, 18, and 19 should remain substantially intact. Sections 1, 4, 5, 7–9, 11–13, 15–17, and 21 should be condensed. Most of §20 should move.

Shortening is required before Project Owner acceptance because the problem is authority separation, not aesthetics.

# 19. Required refinement

The smallest sufficient changes are:

1. Make GameState unambiguously the single canonical owner; describe the dedicated value as an encapsulated immutable value, not a second “semantic owner.”
2. Replace mandatory legacy-save reconstruction with a conditional architecture constraint: if legacy reconstruction is accepted, Hot-Seat and Network cardinalities must be preserved exactly.
3. Remove mandatory old-replay rerecord/cutover policy; retain only semantic reconstruction and peer independence.
4. Narrow the reconnect stop to authoritative proof, validation authority, and fail-closed reassociation.
5. Collapse all bootstrap inventories into one no-bypass invariant and move concrete path mapping to MATCH-001.
6. Move compatibility allocation, serialization shape, network integration, test matrix, and sequencing from §20/§21 into MATCH-001.
7. Remove repeated restatements across relationships, invariants, non-goals, alternatives, mapping, and consequences.
8. Correct the MP-OD-010 mapping so it does not claim Owner authority for the removed compatibility choices.

No rewrite of the architecture model is required.

# 20. Smallest follow-up artifact chain

1. Refine and accept ADR-008.
2. Create and accept the actual MATCH-001 implementation workbook. The current `MATCH-001-player-principal-binding-owner-decisions.md` is Owner input, not the implementation workbook requested by the repository process.
3. Put concrete representation, bootstrap mapping, persistence, version allocation, network integration, compatibility disposition, test matrix, and cutover sequencing in that workbook.
4. Implement the core binding and supported creation/reconstruction paths.
5. Rerun ADR-007 Entry Gate A after that implementation.
6. Before implementing replacement-peer entitlement, accept a narrow reconnect-authentication ADR and then complete that network slice.

Answers to the specific governance questions:

1. **Can ADR-008 be accepted with reconnect authentication as a separate stop?** Yes, after the identified refinements.
2. **Is another ADR required for reconnect authentication?** Yes, before that behavior is implemented; not before ADR-008 acceptance.
3. **Is a new MATCH-001 contract required?** No. The ADR can contain the stable architecture invariants, while the workbook contains execution detail. A contract would currently duplicate authority.
4. **Is a MATCH-001 implementation workbook required?** Yes.
5. **When should ADR-007 Entry Gate A be rerun?** Only after MATCH-001 implementation for a definitive pass; an earlier architecture pre-check is not the final gate.
6. **Does any accepted ADR/contract require amendment?** No.
7. **Does Draft material belong in MATCH-001?** Yes—substantial bootstrap, persistence, replay cutover, compatibility, network-integration, testing, and sequencing material.

# 21. Project Owner decisions required

No additional Owner decision is required to refine or accept ADR-008’s ownership model.

One separate future decision is required before reconnect entitlement is implemented:

> What accepted match-scoped proof allows a replacement peer to be associated with an existing human match principal, which authority validates it, and how do invalid or competing claims fail closed without creating or rebinding a principal?

MP-OD-001–MP-OD-012 intentionally do not answer that question. They define durable identity independently of transport authentication, which is sufficient for ADR-008.

No additional Owner decision is currently needed for legacy save or replay disposition: those choices were expressly deferred to implementation planning under existing compatibility authority.

# 22. Final recommendation

**SUBSTANTIAL REFINEMENT**

Keep the selected GameState-owned immutable binding architecture. Remove the unauthorized save/replay compatibility commitments, narrow the reconnect stop, and move the detailed implementation plan into the future MATCH-001 workbook. After those changes, the ADR should be a sound candidate for Project Owner acceptance.

The audit remained read-only: no file was modified, staged, or committed, and no tests were executed.
