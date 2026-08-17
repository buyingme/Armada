# MATCH-001 Player–Principal Binding — Project Owner Decisions

Status: Owner Decisions
Date: 2026-08-15

## Purpose

This document records binding Project Owner decisions for the architecture
governing durable match-lifetime bindings between gameplay players and their
controlling principals/controllers.

It was triggered by the UX-005 Entry Gate A failure.

It is decision input for architecture drafting.

It is not itself an ADR, contract, or implementation specification.

## Decisions

### MP-OD-001 — Match-lifetime binding authority

Armada shall have one authoritative match-lifetime binding between gameplay
players and their controlling principals/controllers.

The binding must remain stable for the lifetime of the match.

### MP-OD-002 — Gameplay player and principal are distinct concepts

Gameplay player identity and controlling-principal identity are separate
concepts.

A gameplay player slot must not itself be treated as proof of which human or
automated controller occupies that slot.

### MP-OD-003 — One human may control multiple gameplay players

One human principal may control more than one gameplay player.

Hot-Seat therefore maps both gameplay players to the same human principal.

### MP-OD-004 — Two-human Network uses distinct human principals

In two-human Network play, the two gameplay players are controlled by two
distinct human principals.

### MP-OD-005 — Automated controllers are permitted

The architecture shall permit non-human / automated controllers.

A match may structurally contain:

- one human principal and one automated principal; or
- multiple automated principals, including one automated principal controlling
  each gameplay player.

The architecture must not require at least one human principal to exist.

This decision does not define bot behavior, planning, decision logic, AI-vs-AI
product support, or how automated controllers make gameplay decisions.

### MP-OD-006 — Automated controllers do not require human-style acknowledgement

Automated controllers do not require human-style result acknowledgements unless
a later explicit design decision introduces such a requirement.

If a match contains no HUMAN principals relevant to a human-inspection
requirement, no synthetic human acknowledgement may be introduced merely to
satisfy that requirement.

### MP-OD-007 — Binding survives transport changes

Player-to-principal/controller bindings remain stable across disconnect and
reconnect.

Transport peer identity is not itself match participant identity.

Connectivity changes must not redefine who controls a gameplay player.

### MP-OD-008 — Invalid durable identity sources

The following are not sufficient by themselves as durable principal identity:

- network peer ID;
- display name;
- UI/controller state;
- current connected-peer membership;
- gameplay player index.

### MP-OD-009 — Human principal identity scope

Human principal identity should be match-scoped unless repository evidence
proves an existing accepted durable identity with equivalent semantics.

Do not introduce global account identity merely to satisfy this requirement.

### MP-OD-010 — Persistence and reconstruction

The binding must survive or be deterministically reconstructable across the
durability/distribution boundaries where authoritative behavior depends on it,
including:

- save/load;
- reconnect;
- replay.

The exact serialization and compatibility design is deferred to implementation
planning.

### MP-OD-011 — Ownership boundary

Do not introduce general session state into GameState merely to solve
participant identity.

The architecture must establish a narrow authoritative owner for the
match-lifetime player-to-principal/controller binding.

The concrete owner should be selected from repository evidence during ADR
drafting/audit rather than assumed here.

### MP-OD-012 — Explicit non-goals

This decision does not define:

- bot decision logic;
- generic decision routing;
- networking transport;
- matchmaking;
- account identity;
- a general multiplayer/session framework;
- a general controller FSM.

It establishes only the durable match-level relationship between gameplay
players and their controlling principals/controllers.
