# ADR-003-C: Authority Boundaries Workbook

Status: Draft decision analysis  
Decision topic: Authority Boundaries Within Rule Capability Packages  
Supports: ADR-003 Rule and Validation Surface Decision  
Primary inputs: ADR-003 Direction Summary, ADR-003-A, ADR-003-B, CP-001 Game Component Rule Extension Context Pack  
Related tasks: AT-003, AT-004  
Related boundaries: BC-005, BC-005A, BC-011, BC-012  
Related gaps: RG-005, RG-006, RG-011, RG-013, RG-015

This workbook is not an ADR. It does not create CON-003. It analyzes authority boundaries inside the already-locked capability-package model.

## Locked Decisions

The following decisions are treated as fixed inputs:

- Capability Package is the governing model.
- `RuleRegistry` is not the architecture.
- `RuleRegistry` is one implementation surface.
- Mixed rules are expected.
- Integration is capability-based.
- Metadata is not proof of integration.
- ADR-003-A and ADR-003-B are not reopened here.

## Decision Question

Within the capability-package model, which surfaces are authoritative for different responsibilities?

## 1. Current Authority Landscape

| Surface | Current role | Observed authority | Strengths | Weaknesses |
| --- | --- | --- | --- | --- |
| `RuleRegistry` | Static catalogue of validators, modifiers, blockers, observers, and enablers keyed by FlowSpec surfaces | Owns registered hook declarations and hook ordering; does not own active rule state or durable mutation | Good for discoverable hook-shaped behavior; deterministic hook sorting; useful for damage-card and squadron keyword rules | Not serialized; hooks do nothing without call sites; cannot prove integration alone |
| `RuleSurface` | Shared target names and runners for matching `RuleRegistry` hooks | Owns hook execution helper behavior for accepted targets | Centralizes common targets and callback execution; keeps registry callers consistent | Only authoritative where callers opt into it; does not decide state, validation, projection, or persistence |
| Commands | Validate, execute, record, and broadcast game-mutating actions through `CommandProcessor` | Own command-specific payload validation, durable mutation, command history, observer follow-up routing, replay/network command path | Strong mutation authority; replay and network paths already depend on commands; catches invalid submissions | Can duplicate resolver or UI predicates; not every behavior is naturally command-local |
| Resolvers | Calculate legality, derived values, and effects for attack, defense, movement, repair, damage, setup, and related flows | Own core calculations and some direct rule logic; may invoke `RuleSurface` where accepted | Natural home for mechanic-specific calculations; keeps command code smaller | Rule behavior can be hidden inside helpers unless capability packages point to it |
| Setup validators | Validate setup-package readiness, deployment, placement, and setup flow facts | Own setup lifecycle validation and setup-state transitions where setup commands use them | Correct lifecycle owner for objective/obstacle/setup effects | Setup authority can overlap with objective runtime behavior and projection |
| Fleet validators | Validate fleet construction using static catalog facts | Own pre-game legality for rosters, upgrades, objectives, restrictions, points, and slot constraints | Correct owner for build-time restrictions and roster integrity | Not runtime authority; can be mistaken for gameplay rule implementation |
| State classes | Hold durable runtime facts on `GameState`, `PlayerState`, `ShipInstance`, `SquadronInstance`, damage deck, and `InteractionFlow` | Own serialized source of truth for mutable state; static templates resolved by keys | Strong save/load, replay, and reconnect basis; clear place for durable facts | State objects should not absorb arbitrary rule algorithms without ownership traceability |
| `InteractionFlow` | Stores active flow, step, controller, visibility, prompt, and JSON-safe payload | Owns durable transient interaction payload shape when serialized in `GameState` | Good for active modal/choice state and reconnectable transient data | Payload schema can become implicit; payloads are not rule authority unless validated by commands/resolvers |
| `UIProjector` | Projects filtered `GameState` into viewer-specific `UIIntent`, actions, prompts, payloads, and affordances | Owns deterministic presentation projection and some rule affordance display | Central place for reconnect projection and viewer-local UI intent | Not authoritative for behavior by itself; projection-only predicates can create false affordances |
| `StateFilter` | Filters serialized snapshots for hidden information before delivery/reconnect projection | Owns network snapshot visibility filtering for RNG, damage deck, opponent facedown damage, hidden command dials, and owner-only payloads | Strong hidden-information boundary; explicit network/reconnect role | Only sees serialized snapshot shape; new private rule fields must be classified intentionally |
| Serialization | `serialize()`/`deserialize()` on game state, player state, unit state, flows, rosters, packages, command history | Owns durable data shape for save/load, replay inputs, and network snapshots | Concrete persistence boundary; visible in tests | Derived/static behavior can be missed if no field records active source state |
| Replay | Command history and `GameReplay` replay serialized commands against deterministic state and bootstrap | Owns deterministic command-order reproduction and history evidence | Central to rule determinism; catches command/state coupling errors | Hooks or UI-only behavior outside command/state paths can evade replay |
| Networking | Lobby/setup payloads, command sync, snapshots, reconnect projection, and filtering | Owns cross-peer delivery of commands/state and viewer-specific snapshots | Forces JSON-safe payloads and hidden-info handling | Live behavior can diverge if static catalog versions, hooks, or state filtering differ |

Observed evidence:

- `RuleRegistry` comments describe static hooks whose active state is derived from serialized entities.
- `RuleSurface` comments describe callback runners for already-registered hooks.
- `CommandProcessor` comments describe validation, execution, history, replay, observer follow-ups, and future host authority.
- `StateFilter` comments define server-side hidden-information filtering.
- `UIProjector` comments define deterministic projection from filtered `GameState` to `UIIntent`.
- CP-001 and the Current State Architecture Map describe the current hybrid implementation and confirm that no single surface owns all rule behavior.

## 2. Authority Models

### Option A: Single-Owner Authority

Concept:
Every behavior-changing rule has one authoritative implementation owner. Other surfaces are adapters.

| Concern | Evaluation |
| --- | --- |
| Clarity | High in theory. Developers know one owner per rule. |
| Maintainability | Low-medium. Mixed rules would require forced ownership even when behavior spans mutation, projection, visibility, and persistence. |
| Codex safety | Medium. Codex gets a simple answer, but may put behavior in the wrong single owner. |
| Migration effort | High. Existing command/resolver/registry/setup/projection behavior would need broad normalization or wrapper layers. |
| Suitability for mixed rules | Poor. Mixed rules are common and expected; single-owner authority hides secondary responsibilities. |

Fit:
Not recommended inside the locked capability-package model. It reintroduces the false assumption that one surface can prove integration.

### Option B: Surface-Specific Authority

Concept:
Each responsibility has a preferred authoritative surface. Rules may span surfaces, but each surface owns one kind of decision.

| Concern | Evaluation |
| --- | --- |
| Clarity | High for responsibilities such as mutation, projection, filtering, and serialization. |
| Maintainability | Medium-high if boundaries are documented and tests exist. |
| Codex safety | Medium-high. Codex can ask "which responsibility am I touching?" rather than "which rule category is this?" |
| Migration effort | Medium. Existing implementation already follows this pattern informally. |
| Suitability for mixed rules | Good, but only if there is a coordinating artifact for traceability. |

Fit:
Strong as a responsibility matrix, but incomplete without capability packages to link surfaces for one rule.

### Option C: Capability-Package Authority With Delegated Ownership

Concept:
The capability package is authoritative for traceability and completeness. Each implementation surface remains authoritative for its own responsibility: state owns durable facts, commands own mutations, resolvers own calculations, projectors own presentation intent, filters own hidden snapshots, and so on.

| Concern | Evaluation |
| --- | --- |
| Clarity | High once the package lists applicable surfaces and their owners. |
| Maintainability | High. It preserves current working boundaries while making mixed-rule ownership explicit. |
| Codex safety | High. Codex must identify the surfaces affected by a task before implementing behavior. |
| Migration effort | Medium. Existing behavior can be backfilled incrementally without immediate rewrite. |
| Suitability for mixed rules | Strong. Mixed rules are first-class and must declare delegated ownership. |

Fit:
Recommended for owner consideration. It matches the ADR-003 direction summary and avoids reopening ADR-003-A/B.

### Option D: Phase/Flow-Centric Authority

Concept:
Authority is assigned by game phase or interaction flow. For example, attack flow owns attack-related rules, setup flow owns setup-related rules, and status phase owns cleanup-related rules.

| Concern | Evaluation |
| --- | --- |
| Clarity | Medium. Clear when a rule affects exactly one phase/flow. |
| Maintainability | Medium. Phase-based grouping helps navigation but can bury cross-phase state and persistence obligations. |
| Codex safety | Medium. Codex may implement behavior in the active flow and miss save/load, network, projection, or out-of-flow effects. |
| Migration effort | Medium-high. Existing authority is split by commands, resolvers, state, and projection, not only by flow. |
| Suitability for mixed rules | Medium. Useful as a secondary index, not as primary authority. |

Fit:
Viable as an organizing view inside a capability package, but not sufficient as the main authority model.

## 3. Responsibility Matrix

| Responsibility | Preferred authority | Allowed secondary owners | Notes |
| --- | --- | --- | --- |
| Active state | State classes: `GameState`, `PlayerState`, `ShipInstance`, `SquadronInstance`, `InteractionFlow`, setup state, damage deck | Commands, setup bootstrap, roster/setup package handoff | Active state must be serialized or explicitly derived from serialized/static facts. `RuleRegistry` does not own active state. |
| Command legality | `CommandProcessor.preflight()`, `CommandApplicability`, concrete command `validate()` | `RuleRegistry` validators, resolver guards, setup/fleet validators | Commands are the authoritative submission gate for game-mutating actions. |
| Rule execution | Owning command, resolver, setup flow, or accepted `RuleSurface` call site | `RuleRegistry` hooks, state methods, feature-specific helpers | Execution authority depends on behavior type; package must name the active execution path. |
| Resolver calculations | Mechanic-specific resolvers | `RuleSurface` modifiers/blockers, command payload validators | Resolvers own core calculations and may delegate hook-shaped component modifiers. |
| Setup lifecycle | Setup package builder, setup validators, setup commands, setup interaction-flow resolver | Objective/obstacle static metadata, `InteractionFlow`, `UIProjector` | Objective/obstacle setup effects should identify setup-state ownership separately from later runtime behavior. |
| UI affordances | `UIProjector` for projected intent and affordances | `RuleRegistry` enablers, `InteractionFlow.payload`, UI controllers | UI affordance is not behavior authority unless command/resolver validation agrees. |
| Hidden information | `StateFilter` and `InteractionFlow.visible_to` | Commands constructing payloads, state serialization, network manager | New private fields or payloads need visibility classification before network/reconnect use. |
| Projection | `UIProjector` | `InteractionFlow.payload`, scene/UI controllers, `RuleRegistry` enablers | Projection should be deterministic from filtered state. Scene-local previews remain non-authoritative. |
| Serialization | `serialize()`/`deserialize()` methods and JSON-safe command/package payloads | Setup package/roster serializers, save/load manager, replay serializer | Durable rule inputs must round-trip or be explicitly derived. |
| Replay determinism | `CommandProcessor` history and `GameReplay` | Commands, deterministic resolvers, deterministic hook bootstrap/order | Rule execution must be reproducible from serialized commands plus deterministic state/static catalog. |
| Network synchronization | Host/server command authority, network command/snapshot paths | `StateFilter`, `UIProjector`, lobby/setup package serialization | Network-safe means authoritative command/state paths plus viewer-specific filtering/projection. |
| Integration status | Capability package evidence | Static metadata/status fields, tests, catalog UI | Metadata may report status only when traceable to capability evidence. |

## 4. Mixed Rule Analysis

| Rule category | Ownership surfaces involved | Authority conflicts | Recommended ownership pattern |
| --- | --- | --- | --- |
| Upgrades | Static upgrade JSON, fleet roster assignment, fleet validator, possible runtime state, commands, resolvers, `RuleSurface`, `UIProjector`, save/load, replay/network | Upgrade source is static/roster data, but gameplay effects often alter command legality or resolver calculations. No generic active upgrade state is currently observed on `ShipInstance`. | Capability package must first name active state owner. Fleet validator owns build legality. Commands/resolvers own gameplay effects. `RuleRegistry` may own hook-shaped modifiers/enablers where accepted call sites exist. |
| Damage cards | `damage_cards.json`, damage deck/state, `ShipInstance.faceup_damage`, `RuleRegistry`, `RuleSurface`, `ResolveImmediateEffectCommand`, resolvers, save/load, visibility filtering | Persistent and immediate effects use different surfaces. Some effects are registered hooks; immediate effects mutate through commands. | Faceup/facedown damage state remains state-owned. Persistent hook-shaped effects may use `RuleRegistry`. Immediate effects remain command-owned. Package must trace both when one card has both forms. |
| Objectives | Objective JSON, roster selection, setup package, `GameState.objectives`, setup validators/commands, `InteractionFlow`, `UIProjector`, future scoring/runtime commands | Objective setup state is active, but generalized objective scoring/special runtime behavior is not established. Setup ownership can be confused with runtime scoring authority. | Setup effects are setup-owned. Runtime scoring/special effects need explicit state and command/resolver owners. Projection and network filtering must be named when objective state is visible or hidden. |
| Obstacles | Obstacle JSON, setup package, setup validators/commands, board tokens, movement/overlap resolvers, projection, serialization | Placement and gameplay effects may require different owners. Static shape/setup metadata is not active effect authority. | Setup placement is setup-owned. Movement/overlap effects are resolver/command-owned. Obstacle-specific component effects may use hooks only where movement/overlap call sites exist. |
| Named ship abilities | Ship JSON, `ShipInstance`, commands, resolvers, `RuleSurface`, `UIProjector`, save/load/replay/network | No generalized named ship ability state/path is currently observed beyond ship state and damage-card paths. | Package must classify whether the ability is passive modifier, command validation rule, resolver calculation, UI affordance, or stateful effect. Active state likely belongs to `ShipInstance` or derived ship data key unless additional state is required. |
| Named squadron abilities | Squadron JSON, `SquadronInstance`, squadron keywords, `RuleRegistry`, movement/attack/engagement resolvers, commands, projection | Generic keyword rules exist, but named/ace-specific ability path is not generalized. | Generic keyword behavior may use registered hooks where call sites exist. Named behavior needs package traceability across squadron state, resolver/command execution, projection, save/load, replay/network. |

## 5. Codex Safety Analysis

| Future task | Authority decisions Codex must identify | Likely failure modes | Required guardrails |
| --- | --- | --- | --- |
| Add upgrade | Active upgrade state owner; fleet legality versus runtime effect; command/resolver/hook surface; projection; serialization/replay/network | Adding static JSON only; adding hook with no call site; assuming roster assignment is active runtime state; missing save/load/replay tests | Check capability package; do not mark integrated without active state and execution path; require command/resolver/projection/test mapping |
| Add objective | Setup-state owner; runtime scoring owner; objective token/ship state; setup commands; projection; network visibility | Treating setup scaffolding as scoring implementation; storing private/public objective data without filtering; missing setup replay/reconnect coverage | Split setup lifecycle from runtime scoring; identify `GameState.objectives` fields; require setup and runtime tests where applicable |
| Add damage card | Faceup/facedown state; persistent hook versus immediate command; resolver/command impact; hidden damage visibility; save/load/replay | Registering a hook but not invoking it; adding immediate behavior outside command history; leaking facedown card data | Use damage-card package pattern; command-owned mutations for immediate effects; registry hooks only for persistent hook-shaped behavior; check `StateFilter` |
| Add ship ability | Whether ability is derived from ship data or needs mutable state; command legality; resolver effect; UI affordance; serialization | Implementing only UI preview; embedding behavior in resolver without catalog traceability; missing activation/attack/movement tests | Classify as component-origin mixed rule; name state/validation/execution/projection owners; require tests for affected flow |
| Add squadron ability | Keyword versus named ability; static squadron data source; movement/attack/engagement command/resolver impact; projection | Assuming generic keyword infrastructure covers named ability; missing engagement or squadron movement call sites | Package must identify whether existing keyword hooks apply; otherwise name command/resolver owners and tests |

Codex must not infer authority from component category alone. It must identify the responsibilities touched by the behavior and map each to an authoritative surface.

## 6. Recommendation

Recommended authority model:
Capability-package authority with delegated surface ownership.

In this model, the capability package is authoritative for traceability, completeness, and integration claims. Implementation authority remains with the surface that owns the relevant responsibility:

- State classes own durable active state.
- Commands own submitted mutation and command-specific validation.
- Resolvers own mechanic calculations.
- Setup/fleet validators own setup and fleet legality in their lifecycle.
- `RuleRegistry`/`RuleSurface` owns registered hook definitions and hook execution where accepted call sites exist.
- `InteractionFlow` owns durable transient interaction payload shape.
- `UIProjector` owns deterministic projection and affordances.
- `StateFilter` owns hidden-information filtering for serialized snapshots.
- Serialization, replay, and networking paths own their durability/synchronization obligations.

Strongest argument against:
The model can become too procedural. If every small passive rule requires a large package, the process may slow feature work and encourage mechanical checklist completion rather than real authority clarity.

Required refinements:

- Define conditional package fields so simple rules can mark surfaces not applicable with rationale.
- Define how to resolve conflicts when validation, resolver execution, and projection disagree.
- Define review ownership for packages that span multiple subsystems.
- Define minimum tests per responsibility surface.
- Define how existing damage-card and squadron keyword rules are backfilled without broad rewrites.

Owner questions:

- Should one surface be named as the "primary execution authority" for every mixed rule, or is the capability package itself the only primary authority record?
- Who approves a capability package that spans command, resolver, projection, and network/visibility surfaces?
- Should command validation always be the final legality authority for submitted mutations, even when resolver or registry logic also blocks behavior?
- Should `UIProjector` be allowed to expose rule affordances that are not generated by the same surface used for command validation?
- Should hidden-information classification be mandatory for all rules or only for rules that add private state/payloads?
- Which existing category should be used to validate the authority model first: damage cards, squadron keywords, upgrades, objectives, or obstacles?

## 7. Consequences For ADR-003-D

The authority model constrains metadata semantics in these ways:

- Metadata should represent evidence and routing, not ownership by itself.
- Metadata may identify the capability package id, component source, rule id, applicable surfaces, status, and evidence links.
- Metadata should not claim that static content is active unless capability evidence confirms the runtime path.
- Metadata should not treat `RuleRegistry` registration as full integration.
- Metadata statuses should reflect the capability package's surface evidence and should distinguish partial states such as Static, Loaded, Runtime Active, Tested, Save Safe, Replay Safe, Network Safe, and Integrated.
- Metadata fields that mention `rule_surfaces` should distinguish intended/declared surfaces from implemented/verified surfaces.
- Metadata fields that mention `runtime_state_requirements` should not imply that runtime state exists unless the package names the owning state and serialization evidence.
- Metadata fields that mention `implemented_rule_ids` should link to executable behavior evidence, not only rules-reference records or printed text.

Fields likely to represent authority-related evidence:

- Capability package id.
- Active state owner.
- Validation owner.
- Execution owner.
- Projection owner.
- Visibility owner.
- Serialization/replay/network evidence references.
- Test evidence references.

Fields likely to remain descriptive:

- Printed rules text.
- Rules-reference ids.
- Ability/effect/setup/scoring text.
- Static `rule_surfaces` declarations before verification.
- Static `runtime_state_requirements` before owner/evidence linkage.
- Catalog display status when not derived from capability evidence.

ADR-003-D should decide metadata semantics inside this delegated-authority model. It should not reopen whether metadata alone proves integration or whether `RuleRegistry` is the architecture.

## Readiness For ADR-003-D

Ready for ADR-003-D: Yes.

ADR-003-C narrows the remaining metadata question: ADR-003-D should define how metadata records capability evidence, status, and routing without becoming the owner of behavior.

Confidence score: 8/10.

Unresolved risks:

- Capability packages may become too heavy if applicability rules are not scoped by rule type.
- Authority conflicts between command validation, resolver calculations, and UI projection still need explicit conflict-resolution rules.
- Existing rules will need incremental backfill strategy, or metadata/status claims may remain inconsistent during migration.
- Hidden-information ownership must be made explicit before network-sensitive rules expand.
- Test obligations per surface remain undefined until CON-003 or a test strategy is drafted.
