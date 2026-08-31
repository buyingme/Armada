# BUG-031 — Skipping squadron activation during Squadron command stalls ship activation

Severity: High
Area: Squadron command / ship activation
Layer: Command Flow

> [!IMPORTANT]
> ## Current Status — 2026-08-31
>
> **VERIFY / RELATED INVESTIGATION PENDING.**
>
> The historical sections below describe the original BUG-031 reproduction and
> its investigation state. They remain preserved for traceability.
>
> The 2026-08-31 BUG-035 reproduction does **not** currently reproduce BUG-031
> directly.
>
> BUG-031 is relevant to the current forensic investigation only because both
> issues may depend on the authoritative predicate that determines whether a
> Squadron Activation still has a legal remaining action and may complete.
>
> Do not merge BUG-031 with BUG-035 or treat them as the same defect unless
> current implementation evidence proves a shared root cause.
>
> Historical range-message evidence associated with older BUG-031 logs should
> not be treated as current behavior unless reproduced against the present code.

### Investigation Cross-Reference — 2026-08-31

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

Root cause: TBD. Evidence indicates that the Skip path leaves authoritative squadron-activation/declaration state inconsistent while presentation proceeds as though the activation was completed.

Fix: TBD.

Verification: Reproduce and verify the Squadron-command Skip / early-end path in network play. Confirm that skipping does not leave an active squadron activation or declaration-adjacent state and that the commanding ship proceeds normally to the next activation step.
