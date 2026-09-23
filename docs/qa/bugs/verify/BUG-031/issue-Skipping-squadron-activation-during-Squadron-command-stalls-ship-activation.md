# BUG-031 — Skipping squadron activation during Squadron command stalls ship activation

Severity: High
Area: Squadron command / ship activation
Layer: Command Flow

> [!IMPORTANT]
> ## Current Status — 2026-09-23
>
> **RESOLVED / OWNER ACCEPTED.**
>
> The accepted BUG-031 repair is implemented and verified.
>
> The original repair introduced explicit canonical Squadron Move decline and
> authoritative activation/completion presentation gating as specified by the
> accepted BUG-031 implementation workbook.
>
> During later BUG-043 convergence, the BUG-031 real-ENet acceptance harness was
> found not to satisfy the workbook's Section 8B requirement: the
> `commanded_squadron` scenario pre-installed an active commanded Squadron
> Activation instead of entering through the production selection and
> `ActivateSquadronCommand` Network path.
>
> The acceptance harness has now been corrected. The commanded-squadron scenario
> begins uncommitted, traverses the production controller/ENet activation path,
> and requires exactly one accepted `activate_squadron`.
>
> This corrected acceptance path also exposed a separate presentation-owned
> serialized engagement-cache convergence defect. That defect is preserved
> separately as BUG-047 and was repaired without changing BUG-031 semantics.
>
> Final verification after the harness and BUG-047 repairs:
>
> - focused commanded-squadron real-ENet acceptance: PASS;
> - complete Network-resume real-ENet acceptance gate: PASS;
> - full repository suite: 4,300 / 4,300 PASS, 16,882 assertions;
> - Hot-Seat and Network replay verification: PASS;
> - architecture lint: clean;
> - `git diff --check`: clean.
>
> Current repository compatibility has subsequently advanced to save 7,
> replay 10, and protocol 7 through later accepted work. The BUG-031 workbook's
> save 6 / replay 9 / protocol 6 cutover remains the historical compatibility
> boundary specified and implemented by BUG-031 and is not amended here.
>
> BUG-031 is accepted as resolved. Historical reproduction and investigation
> material below remains preserved for traceability.

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

Final verification: the workbook's required real two-process regressions now
exercise the production paths directly. Post-Attack Move decline proceeds
through authoritative completion, and commanded-squadron selection remains
non-actionable until authoritative `ActivateSquadronCommand` acceptance.

A later verification audit found that the original commanded-squadron
acceptance harness had pre-installed the active Squadron Activation and
therefore did not satisfy Section 8B of the accepted workbook. The harness was
corrected to begin uncommitted and traverse the real production controller/ENet
activation boundary. The corrected path records exactly one accepted
`activate_squadron`.

The corrected acceptance path exposed a separate serialized engagement-cache
convergence defect, preserved as BUG-047. After that independent defect was
repaired, the focused commanded-squadron real-ENet gate and complete
Network-resume real-ENet gate both passed.

Final convergence also passed the full repository suite (4,300 / 4,300 tests,
16,882 assertions), Hot-Seat and Network replay verification, architecture
lint, and `git diff --check`.

BUG-031 is Owner accepted and resolved.
