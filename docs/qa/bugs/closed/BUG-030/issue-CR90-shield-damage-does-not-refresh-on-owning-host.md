# BUG-030 — CR90 shield damage does not refresh on owning host

Severity: Medium
Area: Ship Damage / Network Presentation
Layer: Presentation / Projection

## Expected

When a ship suffers shield damage, the updated shield values must be presented
consistently on all relevant peers after the authoritative damage result has
been accepted.

In particular, the player owning the damaged ship must immediately see the
updated shield values on their own host presentation.

Hot-Seat, network host, and network client presentation should all derive the
displayed shield state from the accepted canonical ShipInstance state.

## Actual

During network play, shield damage to the Rebel CR90 was displayed correctly
on the Imperial player's client but was not displayed correctly on the Rebel
player's host.

The two peers therefore presented different shield state for the same
canonically damaged ship.

## Reproduction

Observed once during network play.

1. Rebel player is the network host and owns the CR90 Corvette A.
2. Imperial player is the network client.
3. The CR90 suffers damage affecting its shields.
4. Observe the CR90 shield presentation on both peers.

Result:

- Imperial/client presentation shows the shield damage correctly.
- Rebel/host presentation does not show the corresponding shield damage.
- Canonical game state contains the reduced shield values.

## Evidence

- `annotation_20260815_151129_001.json`

Annotation:

`I realize another UI BUG. toe damage on the CR-90 Shields are not displayed
on the rebel player (host). They are displayed on the imperial players screen
(client) correctly.`

The captured canonical state shows the Rebel CR90 with:

- `current_hull = 4`
- `FRONT = 2`
- `LEFT = 0`
- `REAR = 1`
- `RIGHT = 0`
- `destroyed = false`

The game is in Round 3 Ship Phase.

This is strong evidence that the observed problem is not simply missing
canonical damage mutation: the canonical ShipInstance already contains the
reduced shield values while the owning host presentation is reported as stale.

## Initial Assessment

This appears to be a presentation/projection defect rather than a damage-rule
or canonical-state defect.

The asymmetric result is particularly relevant:

- the passive Imperial/client presentation receives and displays the changed
  shield state correctly;
- the Rebel/network-host presentation remains stale;
- canonical state already contains the reduced shields.

Investigation should therefore compare the accepted local/host damage-result
projection path with the mirrored network-client projection path.

Likely investigation areas include:

- accepted ship-damage result handling on the authoritative host;
- shield/hull refresh events emitted after local accepted damage commands;
- mirrored-result refresh handling that may already work correctly;
- ship-card and/or board-token shield presentation refresh;
- whether the local authoritative route incorrectly assumes that canonical
  mutation automatically refreshes presentation.

The repair should project already-accepted canonical ShipInstance state into
the local presentation. It should not introduce duplicate damage mutation,
network-specific canonical state, or presentation-owned shield state.

## Relationship to Earlier Presentation Bugs

BUG-030 may be related to the accepted-result presentation/projection gaps
previously found in BUG-019 and BUG-027.

Those repairs should be inspected for an established projection pattern before
introducing another refresh mechanism.

Do not merge BUG-030 with an earlier issue unless investigation proves that
the same remaining root cause and repair actually cover this case.

## Architecture Constraint

`ShipInstance` remains authoritative for shield and hull state.

The fix must not:

- mutate shield values from presentation code;
- introduce a second shield-state owner;
- synchronize presentation-only state through GameState;
- duplicate damage resolution;
- weaken command authority.

The desired flow is:

accepted authoritative damage
→ canonical ShipInstance mutation
→ accepted-result projection
→ local host and remote client presentation refresh

Both peers should ultimately render the same accepted canonical state.

## Resolution

Root cause:

The captured asymmetry was specifically the defender-owned Redirect shield
path, not a general failure of canonical damage resolution. The accepted
`SelectRedirectZoneCommand` correctly reduced the host-owned defender's
canonical shields. The server's accepted-result handler then skipped ordinary
host-local commands because their semantic mutation had already executed
inline. That assumption was incorrect for presentation: the inline Redirect
path intentionally performs no UI work, while the mirrored client result calls
`_handle_remote_select_redirect_zone()` and emits
`EventBus.ship_shields_changed`. The client refreshed; the defender-host did
not.

Exact failing path:

`SelectRedirectZoneCommand.execute()` mutates the host defender's
`ShipInstance` → accepted result is broadcast →
`GameManager._on_network_command_result()` sees a host-local player index and
skips result projection → no local shield refresh signal → host card/token
presentation remains stale. The client takes the mirrored handler and refreshes
correctly.

Fix:

The existing server accepted-result gate now routes
`select_redirect_zone` through the existing remote-effect projector even when
the defender is the local host. That projector only resolves the already
canonical ship reference and emits `ship_shields_changed` with the accepted
result value. It performs no shield mutation.

The repair is deliberately command-specific rather than a new refresh layer.
`ShipInstance` remains the shield owner; `SelectRedirectZoneCommand` remains the
only mutation; the event remains a one-way board/card presentation refresh. No
network state, replay entry, prediction, compatibility bridge, or serialized
field was added.

## Verification

After repair, verify:

- shield damage immediately refreshes on the damaged ship owner's network-host
  presentation;
- the remote client continues to display the same damage correctly;
- hull damage refreshes consistently as well;
- damage to ships owned by either host or client behaves equivalently;
- ship-card and board-token presentation agree with canonical ShipInstance
  state;
- rejected or pending commands do not optimistically change displayed damage;
- Hot-Seat behavior remains correct;
- replay/save/reconnect reconstruction displays canonical shield state;
- existing BUG-019 and BUG-027 regression behavior remains intact.

Implemented regression evidence models the production host boundary after the
command-owned shield mutation and proves:

- the accepted host-local Redirect result emits exactly one shield refresh for
  the canonical defender instance;
- projection does not reduce shields again and creates no command/replay
  history;
- a rejected result does not optimistically emit another refresh;
- existing client mirrored-result, Repair, collision/damage, board-token, and
  ship-card refresh suites remain green.

Verification on 2026-08-15:

- `test_network_command_result_ordering.gd`: 9/9 passed;
- `test_attack_commands.gd`: 64/64 passed;
- `test_current_attack_shared_protocol.gd`: 25/25 passed;
- full suite: 237 scripts, 4064/4064 tests, 13645 assertions passed;
- Phase-K architecture lint: 0 violations, with 4 existing allow-listed
  branches;
- `git diff --check`: passed.

Status: repaired and moved to verification; Project Owner manual Network
verification with the Rebel host as Redirecting defender remains required.
