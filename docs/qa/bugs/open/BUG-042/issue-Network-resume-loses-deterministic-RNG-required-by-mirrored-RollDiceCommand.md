# BUG-042 — Network resume loses deterministic RNG required by mirrored RollDiceCommand

Severity: High
Area: Network save/resume / reconnect / deterministic command application
Layer: Canonical state / Network command replay

## Current Status — 2026-09-06 Implemented and Verified, Awaiting Owner Acceptance

The accepted BUG-042 workbook has been implemented through its automated
verification boundary. Live Network RNG and hidden damage-deck authority now
remain host-only. Passive peers install a validated public/passive projection
and apply authoritative command results rather than re-executing RNG or hidden
deck behavior.

The combined BUG-042/BUG-031 cutover supports save format 6, protocol 6, and
replay format 9. Fresh resume, same-live load, reconnect, save/load, result
ordering, deterministic replay, and BUG-035 focused regressions pass automated
production-path coverage. Fresh format-9 canonical replay baselines were
Owner-recorded and promoted through the repository baseline workflow; prior
formats remain compatibility/rejection evidence and are not migrated.

The issue remains open until the two-Mac packaged-build manual acceptance in
`docs/qa/BUG-042-network-rng-authority-manual-acceptance.md` is completed and
reviewed by the Owner.

## Implementation and Verification Evidence — 2026-09-06

- A strict passive damage ledger carries public damage counts without damage
  card identities or deck order.
- Full-authority and passive-state schemas are independently validated; passive
  state rejects RNG state and hidden damage identities.
- RNG and hidden-information commands publish exact, versioned application
  contracts. Passive application validates and consumes those results without
  invoking RNG or drawing from a damage deck.
- Authority-first publication stages, installs, acknowledges, and only then
  admits or releases Network play for fresh resume and reconnect.
- Converted command history remains semantic input only; authoritative result
  payloads are not serialized into replay command history.
- Automated unit and integration verification, real-ENet focused acceptance,
  replay baselines, architecture lint, and repository checks pass in the
  combined BUG-042/BUG-031 worktree.

The original investigation and defect record follow for audit history.

## Prior Status — 2026-09-01 Architecture Investigation

BUG-042 is confirmed as a general Network reconstruction invariant failure,
not a RollDice-specific defect.

Filtered Network resume/reconnect intentionally removes `GameState.rng`, while
passive Network command application currently re-executes RNG-dependent
commands through `CommandProcessor.submit_mirror()`.

Four current gameplay commands directly consume `GameState.rng`:

- `RollDiceCommand`
- `RerollAttackDieCommand`
- `UseConcentrateFireTokenRerollCommand`
- `SelectEvadeDieCommand`

The repository does not currently contain a complete accepted architecture
decision resolving RNG authority across live Network play, filtered
resume/reconnect, and passive mirror execution.

The architecture investigation recommends:

- live Network RNG remains authority/server-only;
- passive peers do not possess resumable RNG state;
- accepted random outcomes are applied through the semantic command transaction
  using validated authoritative command results;
- replay continues its existing seed-plus-command-history deterministic
  re-execution model;
- authority save/load continues to persist current RNG state.

No implementation is authorized until the RNG authority decision is accepted.

BUG-042 remains independent from BUG-035.


## Expected

A Network game resumed or reconstructed from saved canonical state must remain
able to apply subsequent authoritative commands deterministically on all peers.

If passive peers re-execute deterministic gameplay commands such as
`RollDiceCommand`, every dependency required for deterministic execution must be
available and synchronized after resume/reconnect.

Alternatively, passive peers must consume an authoritative result representation
that does not require unavailable server-only random state.

The resumed game must produce the same public authoritative gameplay state as a
fresh uninterrupted Network session.

## Actual

After loading/resuming a previously saved Network game, the client can apply:

- `BeginAttackCommand`;
- Attack-flow publication commands;

but fails when applying the next authoritative `RollDiceCommand`.

Observed failure:

`Invalid call. Nonexistent function 'get_state' in base 'Nil'.`

at:

`RollDiceCommand.execute`

The missing object is:

`game_state.rng`

`RollDiceCommand` expects canonical `GameRng`, but the resumed client's
`GameState` contains no RNG.

The failed Network result then prevents the ordered result stream from
advancing. Subsequent commands accumulate as pending.

## Proven Root Cause

Fresh Network setup installs the shared seeded `GameRng` on both peers.

The save/resume/reconnect state path applies `StateFilter`, which removes RNG
because the current filtering contract treats RNG as server-only.

`GameState.deserialize()` therefore reconstructs a state with `rng == null`,
and `GameManager.start_new_game_from_state()` installs that state without
rejecting or reconstructing the missing RNG dependency.

Network mirror application later uses `CommandProcessor.submit_mirror()` to
re-execute `RollDiceCommand`.

`RollDiceCommand` requires `game_state.rng`.

This creates a contract conflict:

- resumed passive peers do not receive RNG state;
- mirrored random commands require RNG state for deterministic execution.

`BeginAttackCommand` and Attack-flow publication succeed because they do not
access RNG. `RollDiceCommand` is the first command that exposes the missing
dependency.

## Evidence

Observed production sequence after Network resume:

`BeginAttackCommand`
→ Attack-flow publication
→ `RollDiceCommand`
→ mirror execution attempts `game_state.rng.get_state()`
→ runtime failure
→ authoritative Network result rejected locally
→ ordered result cursor does not advance
→ later command submissions accumulate.

The defect was discovered during BUG-035 manual QA but has been forensically
proven independent from BUG-035.

The current BUG-035 `modal_router.gd` repair does not execute at this active
Attack boundary and does not touch RNG, save/load state, Network ordering, or
command execution.

## Missing Regression

Add production-path Network resume/reconnect coverage that:

1. starts or restores a real Network game from the supported resumed-state path;
2. verifies the resumed client contains the required deterministic command
   dependencies;
3. starts a real Attack after resume;
4. executes:
   - BeginAttack;
   - Attack-flow publication;
   - RollDice;
5. proves the client successfully applies the authoritative roll result;
6. proves the ordered result cursor advances normally;
7. proves host and client converge on the same authoritative public Attack
   state;
8. proves no new RNG stream, seed, or nondeterministic fallback is introduced.

Existing tests using full unfiltered state are insufficient evidence for this
resume path.

## Architecture Decision Required

Do not implement a local RNG fallback or create an independently seeded RNG on
the resumed client.

The architecture must first define how deterministic random commands are applied
after Network save/resume/reconnect.

The accepted solution must preserve:

- deterministic replay;
- Network host/client convergence;
- canonical command semantics;
- save/load/reconnect equivalence;
- no presentation-owned random state;
- no silent divergence between host and passive peers.

The required architecture decision should determine whether:

1. deterministic RNG state is part of the resumable canonical state required by
   any peer that re-executes random commands; or
2. passive Network application must consume authoritative random outcomes
   without re-running RNG-dependent command logic; or
3. another already-supported deterministic synchronization mechanism owns this
   boundary.

Do not implement until that contract is explicit.

## Relationship to BUG-035

Independent.

BUG-035 remains responsible for post-completed-Attack decision recovery.

This issue concerns deterministic random-command execution after Network
save/resume/reconnect and must not be folded into the BUG-035 implementation
workbook.
