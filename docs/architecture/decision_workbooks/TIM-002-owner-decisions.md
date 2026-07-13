# TIM-002 Owner Decision Memo

*Date: 2026-07-11*

This memo captures the Project Owner decisions made during the TIM-002
review.

## Decision 1 -- TimingWindowState Serialization (Accepted)

**Principle:** Serialize only authoritative lifecycle semantics.
Re-derive everything else.

Serialize only: - Timing-window identity - Timing-point /
lifecycle-stage identity - Active lifecycle state - Controlling player
or priority owner (where applicable) - Continuation context sufficient
to resume the lifecycle - Shared lifecycle state owned by the timing
window

Do **not** serialize: - Opportunities or opportunity queues -
Projection/UI/modal state - Participant lists - Derived legality or
visibility - RuleRegistry data - Rule-specific mutable state - Rule
effects

Derived information is reconstructed from authoritative runtime state
after replay, save/load, or reconnect.

------------------------------------------------------------------------

## Decision 2 -- Continuation Representation (Accepted)

**Selected option:** Derive continuation from the timing-window
definition.

-   Continuation is derived from timing-window identity, authoritative
    lifecycle context, and current authoritative game state.
-   TimingWindowState does not serialize continuation commands,
    payloads, or descriptors.
-   The timing-window definition may define the canonical continuation
    mapping but is never authoritative for legality or completion.
-   The orchestrator always re-derives opportunities before
    continuation.
-   Multiple rules may participate in the same timing window.
-   Continuation belongs to the timing window, not to any participating
    rule.
-   Continuation commands always pass normal applicability and
    validation.

Future continuation descriptors remain deferred until concrete evidence
requires them.

------------------------------------------------------------------------

## Decision 3 -- Participant Discovery (Accepted)

**Selected option:** RuleRegistry-only Version 1 with evidence-driven
extension.

**Principle:** Use one discovery path until concrete evidence proves
that a second path is necessary.

-   RuleRegistry is the only participant-candidate source in Version 1.
-   RuleRegistry supplies candidates only.
-   RuleRegistry never determines legality, ordering, continuation,
    completion, or mutation.
-   The TimingWindowOrchestrator queries RuleRegistry and derives legal
    opportunities from authoritative runtime state.

Version 1 explicitly excludes local participant lists, provider
abstractions, discovery strategy layers, and speculative extension
interfaces.

------------------------------------------------------------------------

## Decision 4 -- Canonical Opportunity Record (Accepted)

**Selected option:** Canonical derived opportunity record with canonical
command intents.

Each interactive opportunity follows one canonical semantic shape
containing:

-   Capability identity
-   Source-owner kind
-   Authoritative runtime-source identity
-   Stable semantic opportunity key
-   Controlling player identity
-   Resolution kind (`OPTIONAL` or `REQUIRED_CHOICE`)
-   Use command intent
-   Optional decline command intent
-   Blocking status

Command intents contain only:

-   Registered replayable command type
-   Minimum stable authoritative identity context

Opportunity records are derived, never authoritative, and contain no
cached legality, ordering, visibility, UI state, continuation state,
mutable rule state, or effect results.

Passive automatic effects are not interactive opportunities.

------------------------------------------------------------------------

## Decision 5 -- Explicit Decline Protocol (Accepted)

**Principle:** Every blocking player choice produces an explicit
replayable outcome.

Every optional blocking opportunity provides:

-   Replayable **Use** command
-   Replayable **Decline** command

No implicit decline semantics are permitted.

This creates one deterministic interaction protocol for replay,
networking, save/load, reconnect, TEST-003 verification, and Codex
implementation.

The requirement applies only to optional blocking opportunities.

------------------------------------------------------------------------

## Decision 6 -- Window Control Policy (Accepted)

**Selected option:** One current controller with a window-defined
control policy.

### Principle

One player controls the timing window at any moment; the timing-window
lifecycle determines who that player is.

### Decision

Each active timing window has exactly one authoritative current
controller.

Each timing-window type declares a narrow control policy that determines
the current controller from authoritative lifecycle state.

Version 1 supports:

-   Fixed-controller windows.
-   Lifecycle-stage-derived controller windows where sequential player
    control is required.

### Authority boundaries

The control policy may determine:

-   the current controller;
-   explicit controller changes driven by lifecycle transitions.

It shall not determine:

-   rule legality;
-   opportunity existence;
-   ordering;
-   continuation;
-   mutation;
-   visibility.

Individual CAPs, rule commands, UI, and opportunity records do not
define controller policy.

### Serialization

Serialize the authoritative lifecycle stage and the current controller
when not uniquely derivable.

Do not serialize:

-   priority queues;
-   pass history;
-   arbitrary controller callbacks.

### Explicit exclusions

Version 1 excludes:

-   alternating-priority systems;
-   pass-based priority protocols;
-   simultaneous multi-player control;
-   rule-specific controller callbacks;
-   generic priority engines.

Future richer priority models require concrete evidence and a focused
CON-005 revision.

# TIM-002 Owner Decision Memo

_Date: 2026-07-11_

## Decision 7 – Nested Timing Windows (Accepted)

**Selected option:** One active timing window with explicit lifecycle transitions.

**Principle:** One active timing window at a time. Dynamic game flow is expressed through explicit lifecycle transitions rather than nested timing-window hierarchies.

### Decision

CON-005 Version 1 shall prohibit multiple simultaneously active timing windows.

A new timing window may begin only after the current timing window has been explicitly:
- completed,
- cancelled,
- replaced,
- or closed.

### Supported transitions

- Close → open next window
- Cancel → replacement window
- Replacement of the active window

### Explicitly excluded

- Parent/child timing-window hierarchies
- Recursive timing-window stacks
- Multiple concurrently active timing windows

### Rationale

This preserves:
- deterministic replay,
- simple serialization,
- straightforward cleanup,
- predictable networking,
- one authoritative lifecycle,
- high Codex implementation consistency.

Future nested timing-window support requires concrete gameplay evidence and an explicit CON-005 revision.

---

## Decision 8 – Cleanup Ownership Boundary (Accepted)

**Selected option:** Explicit command-owned cleanup with strict ownership boundaries.

### Principle

Every owner cleans only its own state, and every cleanup mutation has an explicit authoritative command path.

### Decision

The `TimingWindowOrchestrator` shall clean only the shared timing-window lifecycle state that it authoritatively owns.

Rule-specific mutable or temporary state shall be cleaned only through an explicit authoritative and replayable command path owned by the applicable rule or enclosing game-flow lifecycle.

Preferred cleanup paths are:

- the rule's replayable **Use** command;
- the rule's replayable **Decline** command;
- a rule-owned replayable follow-up command;
- the existing replayable phase, attack, round, action, cancellation, replacement, or other authoritative lifecycle command that owns the relevant boundary.

A dedicated cleanup command may be introduced only when no existing authoritative command can safely own the cleanup.

### Explicitly prohibited

CON-005 Version 1 shall not rely on:

- implicit lifecycle observers;
- arbitrary callback-based cleanup;
- orchestrator-owned capability-specific cleanup logic;
- generic cleanup frameworks that mutate rule-owned state.

### Capability obligations

Every capability that creates temporary rule-owned state shall identify:

- how that state is created;
- which authoritative command mutates it;
- which authoritative command or lifecycle boundary clears it;
- how abnormal termination (cancellation/replacement) clears it;
- replay, save/load, and reconnect behavior.

### Completion invariant

A timing window shall not complete while rule-owned temporary state remains that the capability contract requires to be cleared at that lifecycle boundary.

### Rationale

This preserves strict ownership boundaries established by ADR-004 and ADR-005, avoids architecture drift toward callback-driven cleanup, keeps every state mutation replayable and auditable, and gives Codex one deterministic implementation rule: **every cleanup mutation must have a single authoritative command owner.**

---

## Decision 9 – Network Protocol Ownership (Accepted)

**Selected option:** CON-005 defines protocol invariants only; implementation details belong to a separate networking contract.

### Principle

**CON-005 owns what networking must preserve, not how networking works.**

### Decision

CON-005 shall define only the network-independent timing-window protocol invariants required for deterministic multiplayer behavior.

### Required protocol invariants

- One authoritative command stream.
- Opportunity derivation is performed from authoritative game state.
- Controller validation is authoritative.
- Continuation is authoritative.
- Replay order matches authoritative execution order.
- Reconnect reconstructs timing-window state from authoritative state.
- Clients never authorize opportunities or timing-window progression.
- No network path may bypass normal command applicability or validation.

### Explicitly outside CON-005

The following belong in a dedicated networking contract or implementation:

- Transport protocols.
- RPC mechanisms.
- Packet ordering and delivery strategies.
- Reliability and retransmission.
- Serialization formats.
- Latency handling.
- Networking APIs and engine-specific implementation details.

### Rationale

This preserves a clean architectural boundary between timing-window semantics and networking mechanisms. CON-005 specifies the invariants that every networking implementation must uphold, while future networking contracts define how those guarantees are achieved. This minimizes architecture drift, keeps CON-005 implementation-independent, and gives Codex a deterministic boundary between protocol obligations and networking implementation.

---

## Decision 10 – Serialized Compatibility And Versioning (Accepted)

**Selected option:** Use the repository's existing authoritative serialization-compatibility/versioning mechanism; do not create a timing-window-specific versioning subsystem without evidence.

### Principle

Require deterministic compatibility handling, but do not introduce a second versioning architecture unless the existing repository mechanism is proven insufficient.

### Decision

CON-005 shall require serialized `TimingWindowState` to participate in the repository's existing authoritative mechanism for save-state, game-state, replay-initialization, and reconnect compatibility.

CON-005 Version 1 shall not require a dedicated `TimingWindowState` version field or a timing-window-specific migration subsystem by default.

Before implementation, Codex shall identify and cite the repository path and symbol that currently owns serialized-state compatibility or versioning.

If no authoritative compatibility/versioning mechanism exists, Codex shall not invent one silently. It shall report the gap for explicit architectural resolution before adding serialized `TimingWindowState`.

### Deterministic implementation rule

For every incompatible change to serialized timing-window semantics, the implementation must select exactly one documented behavior:

1. **Migrate** through the existing authoritative compatibility/versioning path.
2. **Reconstruct** deterministically from older authoritative serialized state when no migration is required.
3. **Reject fail-closed** when the serialized state cannot be interpreted safely.

Silent reinterpretation, best-effort guessing, and implicit fallback are prohibited.

### Required consistency

The same compatibility decision shall apply consistently to:

- Save/load
- Replay initialization
- Network reconnect
- Any authoritative game-state reconstruction path

A save that is accepted through one reconstruction path shall not be interpreted differently by another path.

### Contract obligations

CON-005 shall require implementations to document:

- the authoritative repository compatibility/versioning owner;
- the serialized timing-window semantics affected;
- the selected behavior: migrate, reconstruct, or reject;
- the tests proving that behavior;
- the failure mode for unsupported state.

Concrete field names, version numbers, migration code, file formats, and transport details remain implementation concerns unless an accepted architecture document assigns them elsewhere.

### When a local version field is allowed

A dedicated timing-window version field may be introduced only when repository evidence demonstrates that the existing authoritative mechanism cannot safely distinguish or migrate timing-window schema changes.

Such a field requires explicit justification and must not create an independent, competing version authority.

### Rationale

This wording is actionable for Codex because it gives a fixed decision sequence:

1. Find the existing serialization-compatibility/versioning authority.
2. Reuse it.
3. Choose one explicit compatibility behavior.
4. Test the same behavior across save/load, replay initialization, and reconnect.
5. Escalate if no authoritative mechanism exists.

It avoids assuming that a specific "save version" or "game-state version" field already exists while still requiring deterministic compatibility behavior.

---

## Decision 11 – Shared Protocol Evidence And CAP-Specific Evidence (Accepted)

**Selected option:** Shared protocol suites may be referenced, but every CAP must still prove its own rule-specific correctness.

### Principle

**Share protocol verification. Never share rule correctness.**

### Decision

CON-005 shall distinguish between:

1. **Shared timing-window protocol evidence**, which may be referenced from accepted shared suites; and
2. **Capability-specific evidence**, which every CAP must provide for its own behavior.

A CAP may reference shared protocol evidence only when the referenced suite:

- is accepted and current;
- covers the same timing-window protocol obligations;
- is applicable to the CAP's window type and control policy;
- has passing evidence;
- is identified by exact document/test reference.

A generic statement such as "TEST-003 passed" is not sufficient.

### Evidence that may be shared

Shared suites may cover common timing-window protocol behavior such as:

- lifecycle opening and closure;
- orchestrator ownership;
- opportunity re-derivation protocol;
- explicit use/decline command sequencing;
- continuation gating;
- replay ordering;
- save/load reconstruction protocol;
- reconnect reconstruction protocol;
- network-authority invariants;
- shared cleanup lifecycle behavior;
- shared controller-policy mechanics;
- shared projection/router construction paths where genuinely identical.

### Evidence that must remain unique to every CAP

Every CAP shall provide rule-specific evidence for:

- why the capability participates in the timing window;
- opportunity derivation from the capability's authoritative runtime state;
- capability-specific legality and validation;
- command-intent construction and stable identity context;
- the exact authoritative mutation performed;
- rule-owned temporary state creation and cleanup;
- capability-specific projection and interaction behavior;
- capability-specific visibility and filtering behavior;
- rule-specific failure and rejection paths;
- repeated-use and repeated-decline guards where applicable;
- interaction with at least one other opportunity when coexistence is possible;
- capability-specific invariants, costs, limits, and effect boundaries;
- any deviation from the shared protocol assumptions;
- runtime smoke evidence for the actual live path where required by TEST-003.

### Deterministic CAP structure

Each timing-window CAP shall contain or reference two explicit sections:

#### Shared protocol evidence

For every referenced shared suite, identify:

- the exact suite/document/test reference;
- the TEST-003 matrix categories it satisfies;
- why the suite is applicable to this capability;
- any categories that remain not covered.

#### Unique capability evidence

List the capability-specific tests and traces that prove the mandatory unique evidence above.

### No double counting

The same test may support both shared and capability-specific evidence only when the CAP explicitly states which assertions prove which obligations.

Passing a shared protocol suite shall not be treated as evidence for:

- rule legality;
- rule mutation;
- rule-specific cleanup;
- rule-specific visibility;
- rule interaction;
- capability-specific invariants.

### Failure and waiver handling

If a shared suite does not apply fully, the CAP shall:

- identify the uncovered obligations;
- provide capability-specific evidence for them; or
- record an explicitly approved TEST-003 waiver.

Codex may identify or recommend a waiver but may not approve one.

### Codex implementation rule

For every timing-window CAP, Codex shall:

1. Map every applicable TEST-003 matrix category to either shared or unique evidence.
2. Cite the exact evidence source.
3. Prove all rule-specific obligations with capability-specific tests.
4. Report any unmapped category as incomplete.
5. Never mark a CAP ready for integration solely because a shared suite passes.

### Rationale

This structure minimizes repeated protocol testing and prompt tokens while preserving rule correctness. It gives Codex a fixed evidence-mapping procedure, prevents vague references to shared tests, avoids duplicated evidence, and keeps architecture protocol failures separate from capability-specific implementation failures.

---

## Decision 12 – Static Timing-Window Definitions (Accepted)

**Selected option:** One immutable static definition table owned by the shared timing-window module.

### Principle

Use one immutable static definition table, not a new architecture layer.

### Decision

CON-005 Version 1 shall require one canonical immutable static definition for each timing-window type.

These definitions are owned by the shared timing-window module and are consumed directly by the `TimingWindowOrchestrator`.

Version 1 shall implement them using the smallest repository-consistent static mapping.

### Definition contents

Each timing-window definition may contain only static policy equivalent to:

- timing-window identity;
- supported lifecycle stages;
- control-policy kind;
- RuleRegistry participant-index key;
- canonical continuation mapping;
- permitted completion;
- permitted cancellation;
- permitted replacement;
- permitted close-and-open transitions.

### Explicitly prohibited

CON-005 shall not require:

- a catalog service;
- a provider interface;
- a strategy hierarchy;
- dependency injection;
- a plugin system;
- a registry distinct from the existing RuleRegistry;
- runtime definition objects;
- any additional abstraction layer.

The definition shall never contain:

- runtime legality;
- derived opportunities;
- player choices;
- rule-specific mutation;
- rule-specific cleanup;
- mutable state;
- visibility results;
- runtime completion decisions;
- arbitrary callbacks;
- extension payloads.

### Authority boundaries

Runtime legality, opportunity existence, controller resolution, continuation eligibility, and completion continue to be derived from authoritative runtime state by the `TimingWindowOrchestrator`.

`FlowSpec`, `RuleRegistry`, CAPs, and rule implementations shall not define competing timing-window lifecycle policy.

If future evidence proves that the static mapping is insufficient, any additional abstraction requires an explicit architectural revision.

### Deterministic implementation rule

Codex shall:

1. Locate the shared timing-window module.
2. Update the immutable static timing-window definition.
3. Never invent another ownership location for static timing-window policy.

### Rationale

This resolves the remaining static-policy ownership ambiguity without adding a new architecture layer. It preserves the accepted boundaries that `RuleRegistry` remains non-authoritative, `TimingWindowState` owns lifecycle only, the `TimingWindowOrchestrator` owns runtime lifecycle execution, opportunities remain derived, and CAPs never own timing-window lifecycle policy.
