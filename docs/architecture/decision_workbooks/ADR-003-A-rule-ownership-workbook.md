# ADR-003-A: Rule Ownership Model Workbook

Status: Owner direction recorded  
Decision topic: Rule Ownership Model  
Supports: ADR-003 Rule and Validation Surface Decision  
Primary evidence: CP-001 Game Component Rule Extension Context Pack, Baseline Evidence  
Related tasks: AT-003, AT-004  
Related boundaries: BC-005, BC-005A, BC-011, BC-012  
Related gaps: RG-005, RG-006, RG-011, RG-013, RG-015

This workbook is not an ADR. It evaluates options for owner decision.

## Owner Direction

Owner direction is to adopt a modified Option C/D.

The controlling model is a rule capability package or contract. `RuleRegistry`/`RuleSurface` is a preferred implementation surface for suitable component-origin predicates, modifiers, enablers, and registered hooks where accepted call sites exist.

`RuleRegistry` is not the default owner of all component behavior. Commands, resolvers, setup/fleet validators, state classes, `InteractionFlow` payloads, `UIProjector`, `StateFilter`, and visibility filtering remain valid owners when the rule affects mutation, validation, lifecycle, projection, hidden information, serialization, replay, or network behavior.

"Component rule" describes source/origin, not architectural ownership. "Core mechanic" describes base lifecycle/procedure ownership. "Mixed rule" describes component-origin behavior that crosses one or more core surfaces.

Future ADR-003-B should define what "integrated" means based on this capability-package model.

## Refined Definitions

Component rule:
Behavior whose existence is caused by imported or selectable game content, such as an upgrade, objective, obstacle, damage card, ship ability, squadron ability, or keyword. A component rule is inactive unless the relevant component is present in setup or serialized runtime state. The term describes source/origin, not the owning implementation surface.

Core mechanic:
A base game procedure required independent of optional component content, such as attack resolution, defense token timing, movement, command dial/token lifecycle, damage resolution, setup deployment, save/load, replay, network filtering, and hidden-information handling. Core mechanics may expose extension points for component-origin behavior.

Mixed rule:
Component-origin behavior that crosses one or more core surfaces because it mutates durable state, changes command legality, affects resolver math, changes setup/runtime lifecycle, affects projection, or touches hidden information, serialization, replay, or network behavior.

Rule capability package:
A contract or checklist record for behavior-changing rule integration. It identifies the rule source, active state owner, validation owner, mutation or resolver owner, registry or hook surface if applicable, projection responsibility, serialization requirements, replay/network requirements, visibility requirements, and tests.

## Consequences For ADR-003-B

"Integrated" cannot mean only that a `RuleRegistry` hook exists. Integration must be checklist/capability based.

ADR-003-B should define integration evidence for active state, validation, projection, serialization, replay/network behavior, and tests where applicable. It should also define how command-owned, resolver-owned, setup-owned, projection-owned, and visibility-owned rule behavior can satisfy integration without being forced into `RuleRegistry`.

Metadata status fields should not be treated as proof of integration unless backed by the capability package or checklist. Static catalog metadata can describe intent or linkage, but integration requires observed executable behavior and appropriate test coverage.

## Decision Question

Should future behavior-changing component rules use `RuleRegistry` as the primary extension mechanism, or should the current hybrid model of commands, resolvers, `RuleRegistry`, validators, and UI projection be formalized?

## Evidence Baseline

CP-001 is treated as Baseline Evidence. The current implementation is sufficiently understood for ADR analysis:

- Static component JSON is broad and schema-backed, but metadata is not executable behavior by itself.
- Active behavior exists only when static data is connected to runtime state, commands, resolvers, `RuleRegistry` hooks, projection, serialization, replay, network, and tests.
- Current rule behavior is hybrid: `RuleRegistry`, `RuleSurface`, command validation/execution, resolver-owned rules, setup/fleet validators, `InteractionFlow.payload`, `UIProjector`, and UI previews all participate.
- `RuleRegistry` is active mainly for ship damage-card persistent rules and generic squadron keyword rules.
- Damage-card behavior is split: persistent effects mostly use registered rule scripts, while immediate effects use `ResolveImmediateEffectCommand`.
- Upgrades, objectives, obstacles, tokens, and special ship/squadron rules do not yet have a single accepted expansion path.
- Rule behavior must remain deterministic across save/load, replay, network sync, reconnect, and hidden-information filtering.

## Option A: RuleRegistry-Centric Architecture

### Concept

Make `RuleRegistry` the primary extension mechanism for behavior-changing component rules. New component rules would generally be implemented as registered hooks, and commands/resolvers/UI projection would invoke `RuleSurface` consistently at accepted extension points.

### What Remains Unchanged

- Static JSON and typed data models remain the catalog source.
- Runtime state still lives on serialized entities or `GameState`, not inside `RuleRegistry`.
- Commands remain the durable mutation path.
- Save/load, replay, and network still depend on serialized state and deterministic command history.
- Existing registered damage-card and squadron keyword rules remain conceptually aligned.

### Required Migration

- Define accepted hook surfaces for each major phase and component category.
- Move or wrap some resolver-owned and command-owned rule predicates behind registered hooks.
- Add missing call sites where a registered hook would otherwise never execute.
- Decide how immediate damage effects and setup/objective effects interact with registry hooks.
- Add tests that prove hook registration, invocation, save/load, replay, network, and projection behavior.

### Evaluation

| Concern | Evaluation |
| --- | --- |
| Rule discoverability | Strong if all behavior-changing component rules register hook ids and static metadata maps to those ids. Weak during migration because existing rules remain split. |
| Runtime state ownership | Clear only if ADR states that registry owns definitions while active state remains on serialized entities or `GameState`. Registry itself should not own durable state. |
| Command validation | Can be centralized through `CommandProcessor` validators and `RuleSurface` blockers, but commands still need local payload validation and mutation logic. |
| UI projection | Works when projection invokes enablers consistently. Risk remains if UI affordances need rule-specific payloads that commands do not validate. |
| Save/load impact | Moderate. Registered rules are not serialized, so active state must already be serialized and hook bootstrap must be deterministic. |
| Replay impact | Moderate-high risk during migration. Replay only works if commands and hook invocation order are deterministic and observer followups are protected. |
| Network impact | Moderate-high risk. Hook outputs that affect `InteractionFlow.payload` must respect `StateFilter` and hidden-information rules. |
| Testability | Good for hook-level tests; integration tests still needed for command/resolver/projection call sites. |
| Codex safety | Good once surfaces are contract-defined. Risky before then because Codex may add a hook without a call site. |
| Long-term maintainability | Potentially strong for component-rule discoverability. Risk of overfitting every rule shape into hooks. |
| Migration risk | High. Large surface migration can break working command/resolver behavior. |

### Scores

| Criterion | Score |
| --- | ---: |
| Maintainability | 7 |
| Extensibility | 8 |
| Migration safety | 3 |
| Codex friendliness | 7 |
| Replay/network safety | 6 |

## Option B: Formalized Hybrid Rule Architecture

### Concept

Accept the current hybrid model as first-class architecture. Rules may live in `RuleRegistry`, commands, resolvers, setup/fleet validators, projection, or UI preview paths, but each surface has explicit ownership rules and test obligations.

### What Remains Unchanged

- Existing command-owned immediate damage effects remain command-owned.
- Existing resolver-owned core rules remain in resolvers.
- Existing `RuleRegistry` damage-card and squadron keyword hooks remain registered hooks.
- Existing setup/fleet validation remains separate from runtime rule execution.
- Existing projection and `InteractionFlow.payload` paths remain part of the rule surface.

### Required Migration

- Document which surface owns which kind of rule.
- Add a contract that defines required coverage for each behavior-changing rule: active state, command validation, resolver/hook invocation, projection, serialization, replay/network, and tests.
- Add traceability from static component metadata to the owning runtime surfaces.
- Add guardrails so UI-only predicates and static JSON are not mistaken for active behavior.
- Add test strategies for high-risk surfaces.

### Evaluation

| Concern | Evaluation |
| --- | --- |
| Rule discoverability | Medium unless backed by metadata and evidence maps. Hybrid ownership can be hard to find without a rule index or manifest. |
| Runtime state ownership | Can match current implementation accurately, but ownership must be explicit per rule category. |
| Command validation | Strong for command-owned and validator-owned behavior. Risk is duplicated predicates between commands, resolvers, and UI. |
| UI projection | Honest about current reality; projection remains first-class for affordances. Needs contract language to prevent UI-only authority. |
| Save/load impact | Good if every rule category has explicit durable-state requirements. |
| Replay impact | Good when commands remain mutation authority and observer followups are tested. |
| Network impact | Good if visibility filtering and projection obligations are included in contracts. |
| Testability | Strong at integration level, weaker for uniform unit-level rule tests because surfaces differ. |
| Codex safety | Medium. Explicit rules help, but multiple valid destinations increase placement mistakes. |
| Long-term maintainability | Medium-high if well indexed. Can become messy if hybrid means "anything goes." |
| Migration risk | Low-medium. Aligns with current implementation and avoids broad rewrites. |

### Scores

| Criterion | Score |
| --- | ---: |
| Maintainability | 7 |
| Extensibility | 7 |
| Migration safety | 8 |
| Codex friendliness | 6 |
| Replay/network safety | 7 |

## Option C: RuleRegistry For Component Rules, Commands/Resolvers For Core Mechanics

### Concept

Define a split ownership model:

- Behavior-changing component rules use `RuleRegistry`/`RuleSurface` as the preferred extension mechanism.
- Core game mechanics remain owned by commands, resolvers, setup/fleet validators, and state classes.
- Some component rules may still require command-owned mutations or resolver-owned calculations, but they should be exposed through a registered component-rule entry point when practical.

### What Remains Unchanged

- Core commands remain the authoritative mutation path.
- Core resolvers continue to own base attack, defense, movement, repair, setup, and token mechanics.
- Existing registered damage-card and squadron keyword rules remain aligned.
- Immediate damage-card effects may remain command-owned if classified as command-required component effects.
- Static JSON and `FleetCatalog` remain metadata/catalog surfaces.

### Required Migration

- Define "component rule" versus "core mechanic" in ADR-003.
- Identify accepted `RuleSurface` call sites for component-rule extension.
- Create a component-rule integration contract that requires:
  - static metadata linkage,
  - active serialized state,
  - command validation,
  - projection behavior,
  - save/load,
  - replay,
  - network filtering,
  - tests.
- Migrate new component-rule work to this model first; migrate existing hybrid rules only when touched or when risk justifies it.

### Evaluation

| Concern | Evaluation |
| --- | --- |
| Rule discoverability | Stronger than full hybrid because component rules have a preferred home. Core mechanics remain discoverable in existing command/resolver locations. |
| Runtime state ownership | Requires explicit state-owner rule: registry owns definitions/hooks; active state remains serialized on entities, `GameState`, setup package state, or commands. |
| Command validation | Balanced. Commands keep core validation; component hooks can add blockers/validators where applicable. |
| UI projection | Component affordances can use registry enablers, while core projection stays in `UIProjector`/flow specs. Requires clear projection contract. |
| Save/load impact | Manageable. Component rules must declare durable state requirements, but migration can be incremental. |
| Replay impact | Good if commands remain mutation authority and hooks are deterministic. |
| Network impact | Good if component-rule payloads are JSON-safe and visibility-filtered. |
| Testability | Strong. Component-rule tests can follow a standard checklist while core mechanics keep existing test patterns. |
| Codex safety | Stronger than broad hybrid because new component behavior has a default path. Less risky than registry-only because core mechanics are not force-migrated. |
| Long-term maintainability | Strong if "component rule" is defined clearly and exceptions are documented. |
| Migration risk | Medium-low. New work can use the split model without rewriting all existing mechanics. |

### Scores

| Criterion | Score |
| --- | ---: |
| Maintainability | 8 |
| Extensibility | 8 |
| Migration safety | 8 |
| Codex friendliness | 8 |
| Replay/network safety | 8 |

## Option D: Rule Capability Package Model

### Concept

Define each behavior-changing component rule as a "rule capability package" rather than assigning ownership to one mechanism. A package records the rule id, static metadata linkage, active state owner, validation surface, mutation surface, resolver/hook surface, projection surface, serialization requirements, network/replay requirements, and tests.

The implementation may use `RuleRegistry`, commands, resolvers, validators, and projection as needed, but every rule must have a complete package record and test coverage. This is a more structured version of hybrid ownership.

### What Remains Unchanged

- Existing `RuleRegistry` rules can become packages with registry surfaces.
- Existing immediate damage effects can become packages with command-owned mutation.
- Existing resolver-owned mechanics can remain in resolvers if package metadata identifies the resolver as the owning execution surface.
- Static JSON remains static; package records link metadata to active behavior.
- Commands remain mutation authority for durable game-state changes.

### Required Migration

- Define the rule package schema or contract.
- Create package records for existing damage-card persistent rules, immediate effects, and squadron keywords.
- Add tests that fail when a package lacks required paths.
- Update static catalog status rules to reference package completeness.
- Introduce package records incrementally for new component rules first.

### Evaluation

| Concern | Evaluation |
| --- | --- |
| Rule discoverability | Very strong if package records are enforced. A rule's implementation surfaces are explicit even when hybrid. |
| Runtime state ownership | Strong because every package must name durable state ownership. |
| Command validation | Strong because each package must identify validation ownership. |
| UI projection | Strong because projection obligations become explicit per rule package. |
| Save/load impact | Strong if package completeness requires serialized state and round-trip tests. |
| Replay impact | Strong if package completeness includes command history and deterministic hook/order tests. |
| Network impact | Strong if package completeness includes visibility/filtering obligations. |
| Testability | Strong but more upfront process. Package completeness can drive test strategy. |
| Codex safety | Strong after package template/contract exists; moderate before then because it introduces a new governance artifact. |
| Long-term maintainability | High for rule expansion. Risk is process overhead for simple rules. |
| Migration risk | Medium. Does not require rewriting behavior, but does require new tracking/contracts and possible metadata/test changes. |

### Scores

| Criterion | Score |
| --- | ---: |
| Maintainability | 9 |
| Extensibility | 9 |
| Migration safety | 7 |
| Codex friendliness | 8 |
| Replay/network safety | 9 |

## Comparative Summary

| Option | Maintainability | Extensibility | Migration safety | Codex friendliness | Replay/network safety |
| --- | ---: | ---: | ---: | ---: | ---: |
| A. RuleRegistry-centric architecture | 7 | 8 | 3 | 7 | 6 |
| B. Formalized hybrid rule architecture | 7 | 7 | 8 | 6 | 7 |
| C. RuleRegistry for component rules, commands/resolvers for core mechanics | 8 | 8 | 8 | 8 | 8 |
| D. Rule Capability Package Model | 9 | 9 | 7 | 8 | 9 |

## Recommended Option

Recommended for owner consideration: Option C, with Option D as a likely follow-up contract shape.

Rationale:

- Option C gives Codex and future feature work a clear default: new behavior-changing component rules should prefer a component-rule extension path.
- It avoids the high migration risk of forcing all current command/resolver behavior into `RuleRegistry`.
- It preserves current working core mechanics while creating a stronger expansion model for upgrades, objectives, obstacles, tokens, and special ship/squadron rules.
- It aligns with CP-001 evidence that `RuleRegistry` is already useful for component-like rules, while commands/resolvers remain essential for durable mutation, immediate effects, and core mechanics.
- Option D should be considered as the contract/test implementation of Option C: every component rule should have an explicit capability package or checklist once ADR-003 accepts the ownership split.

This recommendation is analysis only. It is not an accepted ADR.

## Strongest Argument Against The Recommendation

The boundary between "component rule" and "core mechanic" may be hard to define. If that line is ambiguous, Option C can degrade into an undocumented hybrid model with extra terminology. Immediate damage-card effects already show that some component-originated behavior needs command-owned mutation, so the ADR would need clear exception rules and traceability requirements.

## Minimal Migration Strategy

1. Define "component rule" and "core mechanic" in ADR-003-A before changing code.
2. Leave existing working rules in place unless they are touched by feature work or contract/test work.
3. Create a small rule integration contract for one next component category, preferably a low-scope squadron keyword or damage-card extension.
4. Require every new behavior-changing component rule to identify:
   - static metadata,
   - active state owner,
   - command validation path,
   - resolver or registry invocation path,
   - UI projection/affordance path,
   - save/load behavior,
   - replay behavior,
   - network/visibility behavior,
   - tests.
5. Add tests before migrating existing behavior.
6. Migrate existing hybrid paths only when there is a concrete feature, bug, or contract need.

## Owner Questions

- Should ADR-003-A decide only the default ownership model, or also define exceptions for immediate effects and setup/objective behavior?
- What is the accepted definition of "component rule" versus "core mechanic"?
- Should new upgrade, objective, obstacle, token, and special ship/squadron rules all use the same ownership default?
- Should existing damage-card immediate effects remain command-owned under an explicit exception?
- Should static `rules_integration.status` become tied to a contract/test checklist?
- Should a rule capability package/checklist be created as CON-003 after ADR-003-A?
- Which component category should be the first migration/validation slice?
- What level of replay/network test coverage is required before a rule can be marked integrated?
- Should `UIProjector` enablers be considered part of the rule ownership model or only presentation projection?
- Should ADR-003-A explicitly prohibit UI-only behavior predicates for behavior-changing rules?
