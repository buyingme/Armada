# BUG-039 — Ship destruction during its own activation stalls gameplay

Severity: High
Area: Ship activation / unit destruction / damage-card effects
Layer: Gameplay continuation

## Expected

If a ship is destroyed while resolving an effect during its own activation, destruction must terminate any interaction state that can no longer legally continue and gameplay must converge to the next valid recoverable state.

The destroyed ship must not remain the subject of an active Ship Activation interaction.

If no further ship activation is available and the rules require phase progression, gameplay must continue through the existing authoritative transition to the appropriate next phase.

No obsolete activation modal or interaction state may block continuation.

## Actual

A ship can be destroyed by a damage-card effect during its own activation, after which gameplay stalls.

The ship is authoritatively marked as destroyed, but Ship Activation interaction/presentation state remains active. The activation modal remains open or the game otherwise remains waiting on the destroyed ship, and gameplay does not advance.

The issue has been reproduced through more than one damage-card effect.

### Ruptured Engine case

A CR90 with **Ruptured Engine** executed a speed-2 maneuver.

Ruptured Engine caused the ship to suffer the final damage required for destruction.

The CR90 became destroyed, but its Ship Activation remained represented by the interaction flow and the game stalled instead of completing/converging from the destroyed activation.

### Crew Panic case

A separate reproduction occurred when the CR90 suffered lethal damage from **Crew Panic** during its activation.

The ship became destroyed, but gameplay again failed to progress.

This indicates that the defect is not specific to Ruptured Engine or Crew Panic. The common boundary is **destruction of the currently activating ship while that activation is still in progress**.

## Reproduction

### Reproduction A — Ruptured Engine

1. Have a ship with **Ruptured Engine** faceup and only enough remaining hull to be destroyed by its effect.
2. Activate the ship.
3. Execute a maneuver at speed greater than 1.
4. Allow Ruptured Engine to inflict its damage.
5. Observe the ship being destroyed.
6. Observe Ship Activation continuation.

### Actual

The ship is destroyed, but the activation does not correctly terminate/converge and gameplay stalls.

### Reproduction B — Crew Panic

1. Have a ship with **Crew Panic** faceup and only enough remaining hull to be destroyed by suffering its damage.
2. Begin that ship's activation.
3. Resolve Crew Panic by suffering the damage.
4. Observe the ship being destroyed.
5. Observe Ship Activation continuation.

### Actual

The same class of stall occurs.

## Evidence

Evidence includes:

- `annotation_20260830_074916_001.json`
  - Records destruction of the CR90 from the Ruptured Engine effect during maneuver execution and the resulting stalled activation.
  - The captured canonical state marks the CR90 `destroyed: true` while Ship Activation interaction state still references the destroyed ship and activation.

- Replay from the Ruptured Engine/Crew Panic test run
  - Preserves authoritative damage, destruction, and activation commands surrounding the failure.

- `annotation_20260830_080731_001.json`
  - Records an independent reproduction in which Crew Panic destroys the CR90 and gameplay fails to advance.

- Associated gameplay/network logs
  - Should be retained with the annotations and replay for root-cause analysis.

The two independent damage-card triggers provide evidence that the defect belongs to destruction/activation continuation rather than to the implementation of either individual card.

## Resolution

Root cause: TBD.

### Current diagnostic hypothesis

The evidence suggests a lifecycle/convergence defect at the boundary between:

- damage/effect resolution;
- authoritative unit destruction; and
- Ship Activation continuation.

A destroyed active ship must no longer require ordinary remaining activation decisions or presentation.

The captured state indicates that canonical destruction succeeds while enclosing Ship Activation interaction state is not fully reconciled with that destruction.

This is a diagnostic hypothesis only. The authoritative destruction, Ship Activation, interaction-flow, and continuation paths must be inspected before selecting the repair.

The fix must preserve the existing purpose-specific ownership model. It must not introduce a generic continuation owner, generic interaction stack, or presentation-side state mutation.

Fix: TBD.

## Verification

BUG-039 may be accepted as resolved when:

1. A ship destroyed by Crew Panic during its own activation is removed/marked destroyed authoritatively and gameplay continues correctly.
2. A ship destroyed by Ruptured Engine after executing its maneuver likewise terminates/converges its activation correctly.
3. No stale activation modal or interaction state remains associated with the destroyed ship.
4. The destroyed ship cannot receive further activation decisions or commands that require a live activating ship.
5. If another legal ship activation exists, the correct next player/ship decision becomes recoverable.
6. If no further Ship Phase activation remains, the existing authoritative phase progression occurs correctly.
7. Hot-Seat and Network behavior are both verified.
8. Save/load/replay do not restore an obsolete activation for the destroyed ship.
9. Focused automated coverage includes destruction at more than one point within an active Ship Activation lifecycle.
10. Full regression verification confirms that ordinary destruction outside this case and ordinary non-lethal damage-card effects remain correct.

## Relationship to other issues

BUG-039 was discovered while re-verifying BUG-032 after completion of DBG-001.

It is a separate defect from BUG-032:

- **BUG-032** now concerns the remaining Hot-Seat UI refresh/projection problem after Injured Crew resolution.
- **BUG-039** concerns authoritative gameplay continuation when the currently activating ship is destroyed.

Resolving BUG-032 must not be used to close BUG-039, and vice versa.
