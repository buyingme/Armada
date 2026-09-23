# BUG-047 — Client Presentation Mutates Serialized Squadron Engagement Cache

## Status

Resolved

## Summary

A real-ENet commanded-squadron acceptance path exposed canonical host/client state divergence in the serialized `SquadronInstance.is_engaged` field.

After a commanded Squadron Activation involving lethal destruction of an engaged defender:

- Host: destroyed defender `is_engaged == false`
- Client: destroyed defender `is_engaged == true`

Both peers had otherwise accepted and applied the same authoritative command stream.

The divergence was caused by presentation/controller code mutating the serialized engagement cache locally on the client.

Gameplay engagement legality itself was not incorrect. Production command validation and legality checks already derive engagement from canonical board facts through `EngagementResolver`.

## Discovery

BUG-047 was discovered while repairing and rerunning the BUG-031 real-ENet commanded-squadron acceptance path during BUG-043 convergence work.

The repaired acceptance scenario:

1. began from an uncommitted Squadron Command selection state;
2. traversed the production controller/ENet `ActivateSquadronCommand` path;
3. successfully recorded exactly one commanded activation;
4. completed attack, movement, and Squadron Activation;
5. then failed final host/client canonical-state convergence.

The divergence was:

- Host destroyed defender: `is_engaged == false`
- Client destroyed defender: `is_engaged == true`

This was a genuine production convergence defect exposed by the improved acceptance harness, not a BUG-043 Maneuver defect.

## Root Cause

`SquadronInstance.is_engaged` is a serialized legacy cache. It is not the authoritative source for engagement legality.

Canonical engagement legality is derived from canonical board facts, including:

- squadron positions;
- destruction state;
- obstruction geometry;

using `EngagementResolver`.

However, `SquadronPhaseController` contained three presentation-owned mutations of `SquadronInstance.is_engaged`:

- `begin_activation_flow()`;
- `_on_squadron_selected_in_modal()`;
- `_complete_accepted_move()`.

The client-side squadron-selection callback recalculated and mutated the serialized engagement cache as part of presentation processing.

The host did not execute the equivalent presentation callback.

After the engaged defender was destroyed, it was excluded from subsequent position construction. Its client-side cached `is_engaged` value therefore remained stale at `true`, while the host retained `false`.

This produced different serialized canonical state despite both peers processing the same accepted gameplay command history.

## Authority Finding

`SquadronInstance.is_engaged` must not be mutated by UI/controller/presentation paths.

Engagement legality is derived read-only from canonical board state through `EngagementResolver` when required by gameplay or presentation.

Relevant consumers already derive engagement rather than relying on the serialized cache, including command validation and targeting/legality paths.

No new canonical engagement transaction, owner, or synchronization mechanism is required.

The serialized `is_engaged` field remains present for compatibility but is intentionally inert. Removing the field is a separate compatibility/migration concern.

## Resolution

Removed all three `SquadronPhaseController` mutations of `SquadronInstance.is_engaged`.

At the existing selection and post-move presentation seams, engagement is now derived read-only through `EngagementResolver` and supplied to transient modal/availability/Skip presentation state.

No new gameplay authority or canonical mutation path was introduced.

The existing serialized field was retained unchanged for compatibility.

The commanded-squadron real-ENet acceptance scenario was also corrected to traverse the production activation path rather than pre-installing commanded activation state.

## Regression Coverage

Regression coverage now verifies:

- Squadron selection does not mutate the serialized engagement cache;
- accepted Squadron movement does not mutate the serialized engagement cache;
- gameplay legality is independent of stale cached `is_engaged` values;
- lethal destruction converges between Network host and client;
- accepted movement converges between Network host and client;
- commanded Squadron Activation traverses the real production ENet path exactly once.

## Verification

After the repair:

- Focused engagement tests: **25/25 passed**
- Squadron modal tests: **39/39 passed**
- Production-resume integration tests: **79/79 passed**
- Focused commanded-squadron real-ENet acceptance: **passed**
- Complete Network-resume real-ENet gate: **passed**
- Full repository suite: **4,300/4,300 passed**
- Assertions: **16,882**
- Hot-Seat replay verification: **passed**
- Network replay verification: **passed**
- Phase-K architecture lint: **clean**
- `git diff --check`: **clean**

## Relationship to Existing Work

### BUG-031

BUG-031 acceptance work exposed BUG-047.

The repaired BUG-031 acceptance scenario correctly traverses the production commanded-Squadron activation boundary. BUG-047 is not itself the BUG-031 activation-gating defect.

### BUG-035

BUG-047 overlaps the lethal-last-engager gameplay scenario covered by BUG-035, but BUG-035 does not own serialized engagement-cache convergence or presentation-owned mutation authority.

### BUG-043

BUG-047 was discovered during the broader BUG-043 convergence process.

It is not a BUG-043 Maneuver defect and does not change BUG-043 semantics, RCP status, replay format, or accepted Maneuver architecture.

## Architectural Lesson

Serialized gameplay state must not be mutated as a side effect of controller or presentation projection when the underlying gameplay fact is already derivable from canonical state.

In particular, a derived legacy cache must not become an implicit second authority merely because presentation code finds it convenient to refresh it.

Network execution exposed this defect because presentation callbacks were not symmetric between host and client even though the authoritative command history was symmetric.

## Disposition

Resolved.

Keep `SquadronInstance.is_engaged` serialized and compatibility-stable but inert until a separately authorized compatibility migration removes or replaces the legacy field.

Do not restore controller-owned engagement-cache mutation as a synchronization mechanism.
