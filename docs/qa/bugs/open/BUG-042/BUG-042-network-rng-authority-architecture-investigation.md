Conclusion: BUG-042 is a general reconstruction invariant failure affecting every command that consumes `GameState.rng`, not just `RollDiceCommand`. I recommend Model B for live Network play: the authority alone owns and advances RNG; passive peers apply validated, authority-resolved outcomes inside the replayable command transaction. Existing seed-and-command-history replay semantics should remain unchanged.

Repository facts are marked Proven/Normative; conclusions are marked Inference.

1. Current effective RNG architecture

- Proven: `GameState` structurally owns `GameRng`; it serializes both initial seed and current PRNG state. That state is sufficient to clone and continue the stream. [game_rng.gd](/Users/Katharina/godot/Armada/src/core/state/game_rng.gd:14), [game_state.gd](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:643)
- Proven: the host/server `GameState` is the writable Network authority. Fresh Network bootstrap nevertheless distributes one seed and constructs equivalent local RNGs on both peers.
- Proven: setup advances the stream while shuffling the damage deck. Each RNG-dependent command then advances its local stream; the commands restore the previous RNG state if their canonical mutation fails.
- Proven: save/load is host-only in Network mode and persists/restores the full current RNG state. [save_game_manager.gd](/Users/Katharina/godot/Armada/src/autoload/save_game_manager.gd:125)
- Proven: filtered resume/reconnect removes RNG. Deserialization accepts the missing field and leaves `rng == null`; live-installation validation does not require RNG. [state_filter.gd](/Users/Katharina/godot/Armada/src/core/network/state_filter.gd:1), [game_state.gd](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:673), [game_state.gd](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:417)
- Proven: `submit_mirror()` still performs sequence/preflight/command validation, calls the normal `execute()`, records the command, increments the cursor, and suppresses passive observer-generated follow-ups. It does not consume, validate, or compare the transported authoritative result. [command_processor.gd](/Users/Katharina/godot/Armada/src/autoload/command_processor.gd:192)
- Proven: command transport carries the serialized command and a separate result dictionary. History and replay persist only serialized commands, not results. [network_manager.gd](/Users/Katharina/godot/Armada/src/autoload/network_manager.gd:1549), [command_processor.gd](/Users/Katharina/godot/Armada/src/autoload/command_processor.gd:458)
- Proven: ordered client application invokes `submit_mirror(cmd)` before using the result for presentation. A failed mirror leaves the cursor unchanged and stops queue draining. [game_manager.gd](/Users/Katharina/godot/Armada/src/autoload/game_manager.gd:2696)

2. Normative architecture and evidence

The task correctly routes as Uncertain/High-Risk Architecture. Repository authority requires Owner guidance when accepted sources do not resolve a conflict. [CODEX_WORKFLOW.md](/Users/Katharina/godot/Armada/docs/architecture/CODEX_WORKFLOW.md:15), [DOCUMENT_AUTHORITY.md](/Users/Katharina/godot/Armada/docs/architecture/DOCUMENT_AUTHORITY.md:10)

Normative facts:

- ADR-008 makes the host/server `GameState` the writable Network authority; client mirrors reproduce semantics without becoming independent owners. [ADR-008](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-008-durable-match-lifetime-player-principal-binding.md:94)
- ADR-001 and CON-001 require semantic attack mutation to remain command-owned and atomic. History records accepted decisions/order rather than calculation outcomes. Replay re-executes deterministic calculations from the same initial authoritative state. [ADR-001](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md:74), [CON-001](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-001-current-attack-state-and-semantic-transition-contract.md:301)
- CON-001 requires ordered mirrored commands, host/mirror agreement on shared attack facts, and permits differences only under accepted visibility filtering. It does not explicitly decide whether mirror application recalculates randomness or consumes an authority-resolved result. [CON-001](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-001-current-attack-state-and-semantic-transition-contract.md:511)
- ADR-011 requires resume/reconnect to install only the correctly filtered current state and restore every canonical fact needed for the next legal decision before command admission. [ADR-011](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-011-network-match-resume-and-principal-entitlement.md:172)
- The accepted MATCH-003 implementation workbook explicitly preserves `StateFilter`, `GameState`, command ownership, and save/replay schemas. Changing these is an Owner stop gate in that scope. [MATCH-003](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/MATCH-003-network-match-resume-explicit-side-assignment-implementation-workbook.md:98), [MATCH-003 stop gates](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/MATCH-003-network-match-resume-explicit-side-assignment-implementation-workbook.md:812)
- The accepted BUG-011 repair established identical seed-based reconstruction on both peers for Network replay and preserved the same-seed fresh Network setup. It was explicitly bounded away from normal save/resume and command-result semantics. [BUG-011 repair](/Users/Katharina/godot/Armada/docs/qa/bugs/closed/BUG-011/issue-network-replay-rng-bootstrap-repair-plan.md:120)

Inference: no accepted ADR or contract currently resolves RNG ownership consistently across fresh live Network play, filtered reconstruction, and passive mirror execution.

3. StateFilter rationale

- Proven: the filter describes RNG and damage-deck order as secrets and unconditionally removes RNG. Unit tests require removal for both players. This is deliberate behavior, not an accidental omission. [state_filter.gd](/Users/Katharina/godot/Armada/src/core/network/state_filter.gd:1), [test_state_filter.gd](/Users/Katharina/godot/Armada/tests/unit/test_state_filter.gd:104)
- Historical evidence: the approved but now historical G4 plan explicitly chose server-only RNG, never transmitted during play, with clients receiving realized results only. [g4_network_plan.md](/Users/Katharina/godot/Armada/docs/old/g4_network_plan.md:111)
- The same historical plan later added shared-seed client initialization, creating an internal contradiction that the current implementation inherited. [g4_network_plan.md](/Users/Katharina/godot/Armada/docs/old/g4_network_plan.md:438)
- Normative qualification: no current accepted ADR explicitly names RNG state as secret. However, ADR-011 and MATCH-003 require correctly filtered views and preserve the existing filter unchanged.

Classification: an explicit information-hiding requirement with historical authority, current implementation/tests, and indirect accepted resume authority—not merely legacy behavior, but also not yet a complete current RNG authority decision.

4. Exact architectural contradiction

The production chain is:

1. The host’s full save contains the current RNG state.
2. Fresh resume or reconnect sends `StateFilter.filter_for_player(...)`. [network_manager.gd](/Users/Katharina/godot/Armada/src/autoload/network_manager.gd:530)
3. Client deserialization produces `rng == null`.
4. The state passes staging/live-installation validation and is installed at the current accepted cursor.
5. The next authority result is handled by `submit_mirror()`.
6. An RNG-dependent command executes against `null`, before it can be recorded or advance the cursor.
7. The result entry remains pending; later ordered results cannot drain.

This simultaneously violates reconstruction completeness and host/mirror convergence, but accepted authority does not choose whether the missing prerequisite should be RNG state or an authority-resolved application mechanism.

The supplied log confirms host success through sequences 599–602, including `roll_dice`; it does not contain the client exception or stalled cursor. The issue record and current code independently establish that client path. [BUG-042 record](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-042/issue-Network-resume-loses-deterministic-RNG-required-by-mirrored-RollDiceCommand.md:49)

5. Affected RNG-dependent command scope

Four current gameplay commands directly consume `GameState.rng`:

- `RollDiceCommand`: complete attack pool. [roll_dice_command.gd](/Users/Katharina/godot/Armada/src/core/commands/roll_dice_command.gd:58)
- `RerollAttackDieCommand`: one attack die. [reroll_attack_die_command.gd](/Users/Katharina/godot/Armada/src/core/commands/reroll_attack_die_command.gd:66)
- `UseConcentrateFireTokenRerollCommand`: die reroll plus token/resolution mutation. [use_concentrate_fire_token_reroll_command.gd](/Users/Katharina/godot/Armada/src/core/commands/use_concentrate_fire_token_reroll_command.gd:52)
- `SelectEvadeDieCommand`: medium/close reroll; it also dereferences RNG at long range even though that branch removes rather than rerolls the die. [select_evade_die_command.gd](/Users/Katharina/godot/Armada/src/core/commands/select_evade_die_command.gd:84)

Their current results contain resolved dice outcomes and relevant identity/index data, but no RNG seed or post-command RNG state.

Inference: BUG-042 exposes a general invariant for every present or future command using `GameState.rng` after filtered reconstruction. RollDice is merely the first common trigger.

6. Model A — synchronized deterministic RNG

| Concern | Assessment |
|---|---|
| Command/replay compatibility | Strong: preserves current `submit_mirror()` re-execution and command-only history. |
| Convergence | Works if every peer starts from the exact current RNG state and consumes it identically. Any mode-dependent consumption can silently diverge because results are not compared. |
| Save/resume/replay | Straightforward: transmit resumable RNG state; replay remains seed plus history. |
| StateFilter | Requires removing or overriding its RNG secrecy rule and accepted MATCH-003 preservation. |
| Security | Unacceptable without explicit Owner acceptance. Current state can be cloned to predict future random outputs; it may also expose future reshuffle behavior. |
| Transport | No random-result application change, but filtered snapshots disclose seed/state. |
| Migration | Small code change, large authority/security change. |
| Future risk | High: every new RNG consumer must advance every peer identically despite filtered state differences. |

Fresh seed distribution already weakens the claimed secrecy boundary. That is evidence of existing inconsistency, not evidence that exposing current resumable PRNG state is harmless.

Model A is technically viable only if the Owner explicitly accepts predictable future random information and supersedes the server-only filtering boundary. Not recommended.

7. Model B — authority-only RNG

| Concern | Assessment |
|---|---|
| Authority | Host/server alone owns and advances live RNG. Passive live mirrors have no RNG execution capability. |
| Command architecture | Compatible only if result application remains inside the replayable command transaction. `GameManager`, UI, or projection must not become canonical mutators. |
| Result transport | Existing results already carry realized outcomes. Their schemas must become validated semantic inputs for passive application. No RNG state is transported. |
| Convergence | Strong: clients install the exact accepted outcome instead of independently generating one. |
| StateFilter/security | Preserves current filtering and reveals an outcome only after authority accepts it. |
| Save/load/reconnect | Authority saves/restores full RNG; reconnecting clients receive only their filtered state and continue through results. |
| History | Remains semantic commands/order only. Live results stay transient and do not become replay decisions. |
| Replay | Authority/local replay continues seed-plus-history re-execution. Existing replay-specific seed distribution is already repository-defined, not an invented hybrid. |
| Migration | Moderate: result-aware mirror transaction, four command implementations, fresh Network bootstrap/privacy correction, protocol/schema tests. |
| Future risk | Lower if every RNG command is required to define and test an authoritative-result application contract. |

There is a narrow precedent: filtered dial reveal hydrates newly public state from the authoritative result. That proves result hydration is possible, but it is not a generic RNG mechanism and currently occurs outside the core RNG commands.

Recommended interpretation: Model B governs live Network execution. Replay remains the separately proven reconstruction context where a recorded seed and command history reproduce calculations.

8. Model C — existing mechanism

Not proven.

The repository transports authoritative results, but RNG command results are used only for presentation after local re-execution. `submit_mirror()` never receives them. Interaction-state broadcasts and reveal-dial hydration do not resolve canonical random-command mutation generally.

The historical intended mechanism was effectively Model B, but it was incompletely and contradictorily implemented. That is evidence supporting B, not an already functioning Model C.

9. Recommended authority model

Adopt Model B for live Network play:

- Only the live authority possesses and advances `GameState.rng`.
- Fresh, resumed, and reconnected passive live peers receive no seed or RNG state.
- An accepted Network result supplies the resolved random outcome to the same semantic command transaction.
- That transaction validates sequence, identity, current pre-state, result shape, and outcome applicability, then performs the same atomic canonical mutation and history/cursor progression.
- Missing, malformed, stale, duplicated, or inconsistent results fail closed without partial mutation or cursor advancement.
- Replay continues re-executing commands from its recorded seed; save/load authorities restore current RNG state.

This is the smallest architecture-preserving solution because it retains the accepted hidden-information boundary, command ownership, command-only history, and replay determinism. It is larger than the smallest patch because fresh shared-seed Network bootstrap must also be reconciled.

10. BUG-042 classification

D — combination.

Specifically:

- B: the cross-context RNG authority/result-application decision is missing.
- C: existing accepted/current directions are contradictory and require refinement.
- Consequent implementation violation: a filtered state that cannot satisfy the current mirror executor is installed and admitted.

It cannot safely be classified as A alone because no single current normative source unambiguously selects synchronized RNG or authority-resolved application.

11. Smallest required architecture/document change

Before implementation, accept one narrow RNG authority ADR defining:

- live authority, passive live mirror, save/load authority, and replay reconstruction contexts;
- RNG ownership, visibility, and advancement in each;
- authoritative-result application as part of the replayable command transaction;
- command-history versus result-payload semantics;
- failure and ordering behavior;
- explicit supersession of normal live shared-seed behavior from the bounded BUG-011 repair, while preserving replay reconstruction.

A small CON-001 amendment should then clarify that “apply mirrored command” may consume a validated authoritative result without locally reproducing random generation, while `REPLAY-004` remains unchanged. MATCH-003 and `StateFilter` need no semantic change under Model B.

12. Expected implementation scope

- Add a trusted, result-aware mirror submission/execution mode.
- Keep sequence, preflight, lifecycle, atomicity, history, cursor, and signal ownership in `CommandProcessor`/command infrastructure.
- Add authority-result application to all four RNG-dependent commands.
- Make their result schemas explicit and fail-closed.
- Pass results into mirror execution before cursor progression; emit presentation only after successful canonical application.
- Correct fresh live Network bootstrap so clients do not receive/install the live seed or hidden deck order; supply an appropriately filtered initial canonical view instead.
- Preserve authority save/load RNG serialization and `StateFilter` RNG removal.
- Preserve replay file seed plus command history and deterministic re-execution.
- Add context-specific installation capability checks: authority/replay execution contexts require RNG; passive result-application contexts intentionally do not.
- Review protocol versioning because fresh bootstrap and result semantics change, even if the outer command/result envelope remains unchanged.

13. Minimum production-path regression matrix

| Path | Minimum proof |
|---|---|
| Fresh two-process Network | Client receives no live seed/state; authority executes RollDice followed by a reroll; client applies both resolved outcomes; public attack state, history order, and cursor converge. |
| Fresh-session filtered resume | Save after prior RNG consumption; install the real filtered resume snapshot with `rng == null`; execute two sequential RNG-dependent commands; no fallback RNG, result queue drains, cursor advances exactly twice. |
| Confirmed reconnect | Reconnect through the production assignment/snapshot/ACK/admission path; host state/cursor are not reloaded; first and second post-reconnect random results apply and converge. |
| Ordered-result behavior | Deliver prerequisite/random/later results out of order plus a duplicate; buffer until contiguous, mutate exactly once, and leave no pending entry after success. Malformed random results fail without partial state or cursor movement. |
| Save/load continuity | Compare uninterrupted authority with a save/load fork across at least two later RNG commands; outcomes and final authority RNG state must match. A filtered client applies the fork’s results without RNG. |
| Replay | Persist seed plus command history containing at least two RNG commands; replay without recorded results; reproduce outcomes, final canonical authority state, history, and cursor exactly. |
| Command scope | Contract/integration coverage for RollDice, ordinary reroll, Concentrate Fire token reroll, and Select Evade at reroll and long-range branches. |
| Security | Assert seed/current RNG state and hidden draw order are absent from fresh client bootstrap, filtered snapshots, command envelopes, and result payloads; results expose only realized outcomes. |
| Convergence comparison | Compare accepted public/filtered canonical state, not full host/client serialization, because intentional secrets differ. |

At least the fresh, resume, and reconnect cases should exercise real production Network APIs; existing tests that clone full unfiltered state are insufficient.

14. Owner decision required

Smallest decision question:

> In live Network play, may passive clients possess resumable `GameRng` state—and therefore predict future random outputs—or must the server alone own RNG while passive mirrors apply validated authoritative outcomes through the replayable command transaction?

Recommendation: choose server-only RNG with command-owned authoritative-result application, preserving seed-plus-history re-execution for replay. This preserves hidden-information authority, avoids future-stream disclosure, and removes the requirement that filtered peers duplicate every RNG consumption perfectly.

15. Stop conditions and unresolved evidence

Stop before implementation if:

- the Owner has not accepted the live RNG disclosure/authority decision;
- result application would move canonical mutation into `GameManager`, UI, projection, or transport;
- any of the four commands lacks sufficient result/pre-state data for atomic application—expand and decide its result contract instead;
- fresh client bootstrap cannot remove seed/deck disclosure without changing an additional accepted owner or protocol boundary;
- replay seed disclosure is proposed for change; that is a separate accepted reconstruction boundary;
- implementation would introduce a fallback RNG, synthetic outcome, or nondeterministic path.

Evidence caveats:

- The supplied log is the host trace and shows successful authority execution, not the client exception or stalled queue.
- The BUG record header still says `BUG-0XX`, although its directory and requested identity are BUG-042.
- No repository files were changed and no tests were run. The pre-existing modified/untracked worktree state remains untouched.
