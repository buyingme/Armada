# BUG-031 — Skipping squadron activation during Squadron command stalls ship activation

Severity: High
Area: Squadron command / ship activation
Layer: Command Flow

> [!IMPORTANT]
> ## Current Status — 2026-09-06
>
> **VERIFY / IMPLEMENTED AND VERIFIED, AWAITING OWNER ACCEPTANCE.**
>
> The historical sections below describe the original BUG-031 reproduction and
> its investigation state. They remain preserved for traceability.
>
> The 2026-09-05 two-human Network reproduction proves the BUG-031 failure
> mechanism on the post-Attack branch: presentation locally completes and
> exposes the next commanded squadron while a legal Move remains and the
> authority correctly rejects completion.
>
> The Project Owner has accepted explicit canonical Squadron Move decline and
> authoritative activation/completion presentation gating. The binding repair
> specification is the accepted
> [BUG-031 implementation workbook](../../../../architecture/implementation_workbooks/BUG-031-squadron-move-decline-and-network-activation-gating-implementation-workbook.md).
>
> The accepted repair is implemented with the combined save 6, replay 9, and
> protocol 6 compatibility cutover. Focused unit and integration coverage,
> real two-process Network decline and activation-gating acceptance, the full
> suite, and replay baselines pass on the current worktree.
>
> BUG-035 action-order recovery and CON-007 composed return remain preserved.
> Historical range-message evidence remains outside the accepted repair unless
> independently reproduced against current code.

### Historical Investigation Cross-Reference — 2026-08-31

A new Network stall during a ship-commanded Squadron Activation has been
recorded under BUG-035.

The new reproduction is not currently classified as a BUG-031 recurrence:
the observed failure follows completion and acknowledgement of a commanded
Squadron Attack, whereas BUG-031 originally concerns incorrect completion /
continuation behavior around Squadron Activation availability and Skip.

However, both issues touch the authoritative boundary that determines whether
a Squadron Activation has a legal remaining action and whether it may complete.

The planned BUG-035 forensic investigation should therefore compare the
canonical Squadron Activation completion predicates involved in BUG-031 and
the new BUG-035 reproduction.

The historical BUG-031 range-message evidence is not part of this new
investigation unless current repository evidence shows that the same range
legality inconsistency still exists.

Do not merge or reclassify the issues unless current implementation evidence
proves a shared root cause.

BUG-031 remains VERIFY pending that comparison.

## Expected

During a Squadron command, the player can skip an available squadron activation or end the Squadron command early. The Squadron command should then finish cleanly and the commanding ship should continue to the next activation step.

## Actual

During network play, the Nebulon-B used a Squadron command. After one squadron activation, the next squadron activation was skipped.

The game did not continue correctly. The squadron activation modal became unavailable and the ship activation stalled.

Evidence shows that complete_squadron_activation was rejected with:

Squadron still has an available action.

The UI nevertheless continued as if that command activation had completed. After the player ended the Squadron command early, the subsequent advance_activation_step command was rejected with:

Declaration-adjacent state is invalid.

The game could no longer progress.

## Reproduction

Sometimes

1. Start a network game.
2. Activate a ship with a Squadron command capable of activating multiple squadrons.
3. Activate a squadron normally.
4. During the next Squadron-command activation opportunity, use Skip.
5. End the Squadron command early if prompted.
6. Observe whether the ship activation advances normally.

Observed once in Round 3 with the Nebulon-B Escort Frigate.

## Evidence

- annotation_20260816_092548_001.json
- replay_20260816_092616.json
- host_20260816_091352.log
- client_20260816_091352.log
- game_20260816_091333.log

Relevant log sequence:

- Skip pressed for X-wing Squadron
- Command rejected [complete_squadron_activation]: Squadron still has an available action.
- UI reports Command activation 1 of 2 — ready for next.
- Player selects Done to end the Squadron command early.
- Squadron command finalizes with 1 / 2 activations used.
- Ship activation attempts to advance to REPAIR.
- Command rejected [advance_activation_step]: Declaration-adjacent state is invalid.
- No further gameplay progression occurs.

## Resolution

Root cause: current presentation maps a post-Attack Skip with legal Move
remaining to local activation completion. It exposes later Squadron-command
choices even though authoritative completion correctly rejects the still-
available action. The canonical model also lacks the explicit Move-decline
disposition and command now selected by the Project Owner.

Implemented repair: the bounded canonical decline and presentation gating
specified by the accepted BUG-031 implementation workbook linked above. The
implementation preserves terminal completion validation and does not encode
decline as movement.

Verification: the workbook's real two-process regressions pass for post-Attack
Move decline through authoritative completion and for non-actionable client
selection pending authoritative activation acceptance. Focused regressions
also preserve recovery of the same squadron after Attack when Move becomes
legal. BUG-031 remains VERIFY pending Owner acceptance.
