# BUG-042: Live Network RNG Authority And Result Application Implementation Workbook

Status: Accepted

Accepted by: Project Owner
Accepted date: 2026-09-04

Purpose: implement accepted ADR-012, accepted ADR-013, and the accepted
CON-001 RNG amendment against the current production topology. This workbook
replaces the stopped filtered-bootstrap direction in the earlier Draft and
incorporates every mandatory correction from the preserved post-ADR-013 audit.
It does not redesign the accepted architecture and authorizes no production
code while its status remains Draft.

## 1. Classification, Authority, And Entry Disposition

Classification: **Uncertain/High-Risk Architecture during evidence repair,
then Bounded Architecture for the specification below.** The work crosses RNG,
command atomicity, hidden damage state, fresh bootstrap, resume/reconnect,
save/load, replay, and protocol boundaries. Accepted ADR-012 and ADR-013 now
resolve the earlier architectural uncertainty. No remaining conflict was found
in the current production trace.

Binding authority, in precedence order:

1. accepted [CON-001](../contracts/CON-001-current-attack-state-and-semantic-transition-contract.md),
   including NET-001--011, FAIL-001--002, REPLAY-001--007, and TEST-001--012;
2. accepted [ADR-012](../adr/ADR-012-live-network-rng-authority-and-result-application.md);
3. accepted [ADR-013](../adr/ADR-013-passive-network-damage-state-representation.md);
4. accepted ADR-001 command ownership and semantic-attack atomicity;
5. accepted ADR-008 and ADR-011 Network authority, filtering,
   reconstruction, admission, and reconnect requirements;
6. accepted MATCH-003 assignment, staging, installation-acknowledgement, and
   admission implementation boundaries; and
7. current production code plus the preserved BUG-042 issue, architecture
   investigation, direction audit, and filtered-damage-ledger simplification
   findings as implementation evidence only.

The mandatory corrective evidence for this revision is
[`BUG-042-post-ADR-013-workbook-audit.md`](BUG-042-post-ADR-013-workbook-audit.md),
especially its Sections 15--19. The Project Owner has resolved its sole open
decision: BUG-042 advances `GameReplay.FORMAT_VERSION` from 7 to 8, rejects
format 7 at the version boundary, and provides no migration, normalization, or
reinterpretation path.

The stale “Draft”/“Pending ADR-012 acceptance” template text inside the
otherwise accepted ADR-012/CON-001 documents is an administrative
documentation inconsistency. Their status metadata, acceptance dates, and the
Owner direction supplied for this workbook establish the amendment as binding.
Correcting those source documents is outside this workbook.

### 1.1 Entry disposition

| Gate | Disposition |
| --- | --- |
| Live RNG ownership | Settled: authority-only under ADR-012. |
| Passive damage representation | Settled: damage-specific filtered ledger under ADR-013. |
| Command mutation ownership | Settled: the owning command transaction validates and applies the result. |
| Fresh/resume/reconnect filtering | Settled: all three install the same passive representation, with neither RNG nor hidden damage identities/order. |
| Save/load and replay | Settled: full authority save; format-8 seed-plus-corrected-semantic-history replay; format 7 rejects at the version boundary; no live result persistence or replay compatibility adapter. |
| Protocol compatibility | This workbook requires a hard protocol cutover from version 4 to version 5. No mixed live compatibility is permitted. |
| Audit replay decision | Resolved by the Owner: replay format 7 -> 8, hard rejection of format 7, genuine regeneration/review of format-8 fixtures. |
| Remaining Owner decision | None known after the replay-format decision. A Section 13 stop gate applies if new implementation evidence contradicts this corrected specification. |

## 2. Corrected Production Reality And Scope Drivers

The stopped Draft was correct about the four direct command consumers of
`GameState.rng` and the result-blind mirror seam, but wrong to treat damage as
an unchanged filtered-publication concern after bootstrap. The current code
requires the following complete consequences.

### 2.1 Result and ordering seam

- `NetworkManager` currently transports a serialized command and a result
  dictionary. It adds `__remote_authored` to that result even though the field
  is routing metadata rather than semantic outcome.
- `GameManager` buffers by command sequence, calls
  `CommandProcessor.submit_mirror(command)` without the result, and invokes
  presentation handlers only after cursor advancement.
- `CommandProcessor.submit_mirror()` already owns sequence validation,
  preflight, command validation, execution, history, cursor, success signals,
  and suppression of passive observer follow-ups.
- `GameCommand` has no narrow result-application operation. Omitting it from
  scope would force a processor allowlist or untyped probing.

The implementation SHALL extend this exact seam. It SHALL NOT create a
transport-owned, manager-owned, projection-owned, or generic result mutation
path.

### 2.2 Audited live RNG consumer classification

Current semantic commands that directly consume `GameState.rng`:

1. `RollDiceCommand`;
2. `RerollAttackDieCommand`;
3. `UseConcentrateFireTokenRerollCommand`; and
4. `SelectEvadeDieCommand` at medium/close range. Its long-range branch does
   not roll and SHALL stop dereferencing RNG.

Current non-command consumers or holders:

- `FleetSetupBootstrapper` constructs an authoritative RNG and passes it to
  damage-deck initialization;
- `LearningScenarioPreparer`/`LearningScenarioSetup` constructs and shuffles
  the authoritative damage deck from `GameState.rng`;
- `GameBoard` currently performs Learning Scenario deck construction after
  scene entry;
- `DamageDeck` retains the RNG reference used for initial shuffle and
  discard-pile reshuffle; and
- replay bootstrap, replay capture, and authority save/load read, install, or
  serialize RNG without becoming live passive consumers.

Negative-space classification required by the audit:

- `DefenseTokenResolver.apply_evade_reroll()` calls `Dice.roll_die()` without a
  `GameState.rng`, but the helper has no reachable production caller. It is
  legacy/dead evidence, not a fifth live command consumer; implementation SHALL
  not route new work through it.
- Lobby initiative tie-break and fleet/setup fallback `randi_range()` calls are
  pre-game setup-choice generation, not live `GameState.rng` command
  consumption. BUG-042 does not migrate those choices.
- Profile identifiers, lobby codes, save identifiers, and music shuffling are
  non-gameplay randomness and remain outside scope.
- `DamageDeck.deserialize()` and `ResolveDamageCommand`'s replacement-deck
  restore are state-replacement sites that currently lose the deck's
  authoritative RNG binding. Section 11 makes their narrow repair explicit.

Only the four commands use the dice result contracts in Section 5. Setup and
deck initialization remain authoritative construction. Damage commands use the
damage-specific contracts in Section 7 because the hidden draw and any
reshuffle are authority-only.

### 2.3 Audited production damage mutation inventory

| Current surface | Current behavior that must be migrated |
| --- | --- |
| `ResolveDamageCommand` | Draws one or more cards in the command, serializes every identity in `damage_cards`, and mirrors those identities. |
| `OverlapDamageCommand` plus `ShipActivationController` | Scene pre-draws two cards and places both hidden identities in the command payload/history. |
| `PersistentEffectDamageCommand` plus `GameBoard` | Supports command-owned draw, but the scene path still pre-draws and serializes `card_data`; rule follow-ups use `draw_from_deck`. |
| `ResolveImmediateEffectCommand` | Structural Damage draws an extra facedown card; five immediate effects may move a public faceup card to facedown. The payload/result repeats `effect_id`. |
| `RepairActionCommand`, `RepairResolver`, and `RepairPanel` | Select and remove a concrete facedown `DamageCard`, then disclose its title in the result after moving it to public discard. |
| `DestroyUnitCommand` | Clears concrete faceup/facedown objects and adds them to discard. Current generation is presentation-owned through `EventBus.ship_destroyed`; both authority and passive presentation can submit it, and repeat cleanup currently validates. It SHALL become one authority-only deterministic follow-up under Section 7. |
| `DebugDealDamageCommand` and `DebugController` | The host debug modal queries hidden draw-pile membership and a named-card rejection is also an oracle. ADR-013 permits no Network debug exception. `DebugDealDamageCommand` SHALL be unavailable in live Network before any deck query and remains local/Hot-Seat full-authority behavior only. It has no live result contract. |
| `DamageDeck` | Owns full draw order, public discard identities, ordinary draw, debug take, deck exhaustion, and discard reshuffle. |
| `StateFilter` | Preserves draw count/discard but exposes the owning player's facedown identities and removes only the opponent's; deserializers discard `draw_count` and `facedown_count`. |
| `ShipInstance`, damage displays, repair UI, and remote presentation handlers | Assume facedown cards are concrete objects and count them through `facedown_damage.size()`. Some remote handlers deserialize or search identities that must no longer exist passively. |
| `AttackExecutor`, `GameBoard`, and `ShipActivationController` | Retain pre-draw helpers and identity-bearing facedown logs/presentation inputs. |
| `CommandSubmitter.submit_authoritative()` and destruction presentation emitters | Passive `submit_authoritative()` delegates to ordinary Network submission. `AttackExecutor`, `ShipActivationController`, and `CommandRouterAdapter` currently emit the destruction trigger from presentation. Those paths SHALL no longer create or submit cleanup. After accepted authoritative cleanup, they may retain presentation notification and GameManager's existing elimination/scoring/game-end handling. |
| `GameReplay` format owner and current fixtures | Format 7 contains the identity-bearing overlap/persistent command model removed by BUG-042. Format 8 owns the corrected semantic model; format 7 rejects before any command application. |

`ImmediateEffectResolver.resolve()` is not a second production mutation owner;
current production uses it for classification and choice construction while
`ResolveImmediateEffectCommand` owns mutation. Tests SHALL keep that boundary
explicit.

`AttackExecutor`'s remaining pre-draw helper and
`DefenseTokenResolver.apply_evade_reroll()` are unreachable legacy helpers.
Their classification is part of the executable inventory; neither may be used
as a fallback when the live paths are converted.

## 3. Target Execution Model And Invariants

| Context | RNG and full damage representation | Result application |
| --- | --- | --- |
| Hot-Seat/local authority | Full RNG, `DamageDeck`, and all card identities. | Normal command execution; no transported result. |
| Live Network authority | Sole live RNG and full `DamageDeck`; sole owner of hidden order and facedown identities. | Command generates/uses randomness and commits once. |
| Passive Network peer: fresh, resumed, or reconnected | `rng == null`, `damage_deck == null`, no hidden order, no facedown identity; canonical passive ledger installed. | Same command validates and applies its strict viewer result without RNG or hidden identity. |
| Authority save/load | Full RNG state, full deck order, and all card identities. | Restored authority continues the exact stream. |
| Replay format 8 | Full reconstructed RNG and `DamageDeck` from replay seed and corrected semantic history. | Normal replay execution; no live result input or passive ledger. Format 7 rejects before command application. |

The implementation SHALL preserve these invariants:

1. One live RNG authority advances randomness.
2. Neither player receives or stores the identity of a card while it remains
   facedown, including damage on that player's own ship.
3. A passive peer stores exactly one damage-specific canonical filtered
   representation and never creates a placeholder card or `DamageDeck`.
4. Every result is bound to one serialized command, authoritative sequence,
   result-contract version, and assigned viewer before command validation.
5. Semantic result payloads contain only contract fields. Transport/routing
   metadata is never accepted as semantic result data.
6. The owning command validates the filtered pre-state and complete result
   before any mutation. Mutation, history, cursor advancement, continuation,
   success signaling, and presentation occur exactly once and in that order.
7. Rejection leaves passive canonical state, history, cursor, pending result,
   follow-up queue, success signals, and presentation unchanged.
8. Passive damage draws and reshuffles mutate only aggregate ledger facts;
   they never invoke RNG or infer hidden identity/order.
9. A card identity enters passive state only in the same accepted transition
   that makes it faceup or places it in public discard.
10. After every accepted command sequence, filtering the authority post-state
    for a viewer is semantically equivalent to that viewer's passive state.
11. Command history remains semantic command/order history. Live result
    payloads and transport metadata are transient and never enter saves or
    replay history.
12. Fresh start, resume, and reconnect use the same passive state schema,
    deserializer, installation validation, cursor restore, and admission gate.
13. Protocol-5 live command intent uses exact per-command allowed-field schemas.
    Unknown or removed identity-bearing fields reject before execution, logging,
    or history.
14. Lethal damage creates exactly one authority-only `DestroyUnitCommand`
    follow-up per newly destroyed ship. Presentation never creates or submits
    semantic cleanup.
15. Every full authority `DamageDeck` created by deserialization or rollback
    replacement is rebound to that authority `GameState.rng` before it can draw
    or reshuffle.

## 4. Exact Result Transaction And Transport Boundary

### 4.1 Protocol-5 envelope

Each live result delivery SHALL have these four separate logical parts:

```text
transport metadata:
  protocol_version = 5
  application_contract = <command-specific contract id below, or "none">
  application_contract_version = 1 when a contract is present
  viewer_player = assigned gameplay player for this endpoint
  host-local routing facts, if any (never copied into either result payload)

semantic command:
  the existing canonical GameCommand serialization, including sequence

application_result:
  an exact dictionary matching the selected contract; unknown fields reject

presentation_result:
  viewer-authorized transient data used only after command success; never an
  input to canonical mutation, history, cursor, validation, or continuation
```

`__remote_authored` SHALL be removed from result dictionaries. Host-side
presentation may retain an equivalent host-local routing fact outside the wire
result payloads. The receiver SHALL derive endpoint/principal authorization
from the accepted session association and SHALL reject a claimed
`viewer_player` that does not match it.

The server SHALL build viewer-authorized application and presentation results
for each assigned endpoint and send them with targeted delivery. It SHALL NOT
broadcast one authority-internal result and rely on clients to ignore hidden
fields. The host projection SHALL receive the same filtered payloads permitted
for the host's assigned player. Authority-internal temporary values used during
execution SHALL not be signaled, logged, or transported.

Only commands in Sections 5 and 7 set an application contract and pass an
`application_result` into canonical execution. Existing non-converted commands
retain their current deterministic mirror execution and may carry their
existing data as `presentation_result`; that data remains non-authoritative and
must be viewer-authorized. This workbook does not create application contracts
for the rest of the command catalog or legitimize any pre-existing
presentation-owned mutation.

For converted commands, the concrete authority/passive execution may return a
viewer-safe local command result after commit for existing success signals and
presentation (for example, hull or shield values). That local return is not the
transported application input. Converted commands SHALL normally omit
`presentation_result` from transport and derive presentation on each peer from
the command transaction and committed canonical state. Dice application facts
may be reused locally for presentation because they are already public.

Missing application result and present empty application result are distinct.
Several damage contracts legitimately have a zero-field `{}` application
result; envelope presence and the contract ID prove that the accepted result
was supplied.

### 4.2 Narrow command API

`GameCommand` SHALL expose a narrow passive-authoritative-result operation (API
name implementation-local) with these semantics:

- base/default behavior rejects result-driven execution;
- only commands listed in Sections 5 and 7 opt in;
- each opted-in command declares its contract ID/version and projects the
  strict viewer application result from its successful authority transaction;
- command `validate()` and processor preflight still execute against the
  accepted filtered pre-state;
- the concrete command validates its exact result schema and performs its own
  canonical mutation; and
- normal authority and replay continue to call normal `execute()`.

This hook is an execution mode of the command transaction, not a generic
result-event API. The processor SHALL NOT contain command-type mutation logic.
Damage commands may share the damage-specific ledger's count/draw validation
operations; they SHALL NOT acquire a generic snapshot-mutation abstraction.

### 4.3 Processor and ordered receiver behavior

1. `GameManager` buffers the complete envelope by command sequence.
2. A contiguous entry is passed once to result-aware `submit_mirror`.
3. `CommandProcessor` validates sequence, envelope/contract binding,
   applicability, rules, command intent, filtered pre-state, and result.
4. The command commits atomically.
5. Processor records the semantic command, advances the cursor once, and emits
   the success signal with only viewer-authorized application/presentation
   data.
6. Passive observer/continuation synthesis remains disabled.
7. Only after processor success may `GameManager`/scene/UI project the new
   canonical state and clear the local submission wait.

Malformed, missing, stale, duplicate, out-of-order, wrong-contract,
wrong-viewer, wrong-command, wrong-lifecycle, or inapplicable results fail
closed. A rejected contiguous entry remains the blocking pending sequence;
later entries do not bypass it. Duplicate/stale entries never reapply.

### 4.4 Exact live semantic-command schemas

Protocol-5 live command admission SHALL reject unknown, missing, conditionally
inapplicable, or removed payload fields before command execution, diagnostics,
or history. Correct constructors alone are not evidence. `GameCommand`
canonicalization may share exact-field validation, but SHALL NOT introduce a
generic compatibility layer or retain rejected fields. Replay format 8 uses
the same corrected semantic schemas. Format 7 is rejected before its commands
reach this boundary.

| Command | Exact allowed payload fields |
| --- | --- |
| `roll_dice` | `attack_id` |
| `reroll_attack_die` | `attack_id`, `die_index`, `expected_color`, `expected_face`, `source_rule_id` |
| `use_concentrate_fire_token_reroll` | `timing_window_id`, `lifecycle_id`, `attack_id`, `attacking_ship_id`, `source_owner_kind`, `runtime_source_id`, `semantic_key`, `die_index`, `expected_color`, `expected_face` |
| `select_evade_die` | `attack_id`, `defender_kind`, `defender_index`, `token_index`, `die_index`, `expected_color`, `expected_face`; remove the redundant legacy `ship_index` alias |
| `resolve_damage` | `attack_id` |
| `overlap_damage` | `ship_index`, `other_owner`, `other_ship_index` |
| `persistent_effect_damage` | `owner_player`, `ship_index`, public triggering `effect_id` |
| `resolve_immediate_effect` | `owner_player`, `ship_index`, public `card_index`, `choice`; `choice` SHALL match the exact recursively validated effect-specific schema below; `effect_id` is derived from the public pre-state card and is not admitted |
| `repair_action` | Common: `action_type`, `owner_player`, `ship_index`. `move_shields`: add only `from_zone`, `to_zone`. `recover_shields`: add only `zone`. Faceup `repair_hull`: add `damage_face = "faceup"`, `card_index`. Facedown `repair_hull`: add `damage_face = "facedown"`, `facedown_ordinal`. |
| `destroy_unit` | `owner_player`, `ship_index`; this command is authority-generated only in live Network play |

Removed `moving_card`, `other_card`, `card_data`, `draw_from_deck`, immediate
`effect_id`, facedown card objects/titles, the Evade `ship_index` alias, and any
other unknown field SHALL fail live admission. Rejection is redacted and SHALL
not echo a rejected hidden value into logs or diagnostics.

For `resolve_immediate_effect`, the public faceup card at `card_index` determines
which one of these exact nested `choice` schemas applies. The `choice` value
SHALL be a Dictionary, SHALL contain exactly the fields shown, and SHALL be
validated recursively before diagnostics, command execution, or history:

| Derived public effect | Exact `choice` dictionary | Pre-state/content validation |
| --- | --- | --- |
| `structural_damage` | `{}` | No choice is permitted. |
| `life_support_failure` | `{}` | No choice is permitted. |
| `projector_misaligned` | `{}` when the maximum-shield zone is unique or no zone has shields; otherwise `{ "id": String }` | The non-empty ID is exactly `"zone_<zone>"`, where `<zone>` is a canonical hull-zone key tied for the positive maximum shield value in the target ship's pre-state. An empty dictionary rejects when that pre-state requires the tied-zone choice. |
| `injured_crew` | `{ "id": String }` | The ID is exactly `"discard_defense_<index>"`; `<index>` is the canonical decimal index of an existing, non-discarded defense token in the target ship's pre-state. |
| `shield_failure` | `{ "zones": Array[String] }` | `zones` contains zero, one, or two distinct canonical hull-zone keys present on the target ship. Non-String entries, unknown zones, duplicates, or more than two entries reject. The empty selection is represented as `{ "zones": [] }`, not `{}`. |
| `comm_noise` | `{ "id": String }` | The ID is exactly `"reduce_speed"` when the target's pre-state speed is positive, or `"change_dial_<command_type>"` when a hidden top dial exists and `<command_type>` is the canonical decimal value of one of `NAVIGATE`, `SQUADRON`, `CONCENTRATE_FIRE`, or `REPAIR`. |

No nested schema admits `effect_id`, `card_data`, `card_title`, a `DamageCard`,
or any other identity-bearing, obsolete, or unknown field. Invalid nested keys,
types, prefixes, suffixes, indices, enum values, zones, cardinalities, or
pre-state-inapplicable alternatives reject rather than being ignored or
stripped. Format-8 replay records the same minimal semantic `choice` dictionary,
which is sufficient to reproduce each existing player choice deterministically.

## 5. Direct `GameState.rng` Command Result Contracts

All numeric enum fields SHALL be exact canonical integers after transport
canonicalization. Dice faces SHALL be legal for the pre-state die color. The
result schemas below admit no additional fields.

| Contract ID | Command | Exact application result | Passive validation and command-owned mutation |
| --- | --- | --- | --- |
| `roll_dice` | `RollDiceCommand` | `{ "dice_results": Array[Dictionary{color:int, face:int}] }` | Validate active `attack_id`, PRE_ROLL stage, player, timing/obstruction/CF conditions, result count and colors against the canonical dice pool, and every face. Atomically install the complete results, enter ATTACK_MODIFY, and perform existing deterministic ship-target recording. |
| `reroll_attack_die` | `RerollAttackDieCommand` | `{ "new_face": int }` | Validate attack/stage/player, die index, expected color/face, source rule, and Swarm legality from filtered canonical state; validate the face for the selected color. Replace only that die. `old_result`, source, index, and full array are command/pre-state facts and SHALL NOT be duplicated in the result. |
| `concentrate_fire_token_reroll` | `UseConcentrateFireTokenRerollCommand` | `{ "new_face": int }` | Validate the complete existing CF resolution context, runtime source/semantic key, selected die, expected value, and spendable token. Atomically replace the die, mark CF resolution used, and spend the token; rollback every touched owner on failure. |
| `select_evade_die` | `SelectEvadeDieCommand` | Long range: `{ "operation": "remove" }`; medium/close: `{ "operation": "reroll", "new_face": int }` | Derive the required branch from canonical range. Validate defender/token/pending-effect identity and expected die. Long range removes without ever reading RNG; medium/close validates a legal face for the existing color. Atomically update dice, pending Evade, resolved effects, and defense stage. |

Authority and replay execute the same semantic mutations with their local RNG.
Authority RNG state is restored if a later part of an atomic command fails.
Passive execution never reads, seeds, advances, or restores RNG.

Any future live command that reads `GameState.rng` requires a new explicit
contract, viewer authorization review, passive filtered-state proof, and the
full fresh/resume/reconnect/replay evidence before integration. This rule does
not authorize a framework abstraction.

## 6. Passive Damage Ledger Installation And API Boundary

### 6.1 Exact filtered snapshot representation

`StateFilter.filter_for_player()` SHALL remove authority `rng` and
`damage_deck`, remove `facedown_damage` from **every** ship regardless of
viewer ownership, preserve every public `faceup_damage` object, and emit one
damage-specific record:

```text
passive_damage_ledger:
  schema_version: 1
  draw_count: non-negative int
  discard_pile: Array[DamageCard.serialize()]       # public identities
  facedown_counts: Dictionary[String, non-negative int]

ship key = "<owner_player>:<roster_entry_id>"
```

Every live ship SHALL have exactly one entry, including zero. Empty or
duplicate `roster_entry_id`, unknown/missing ship keys, negative/non-integral
counts, malformed/public-card data, simultaneous `damage_deck` and
`passive_damage_ledger`, or any remaining `facedown_damage` field SHALL reject
passive installation.

`StateFilter.filter_for_player()` accepts a validated full-authority
representation only. Input already containing `passive_damage_ledger`, lacking
the full authority deck representation, or otherwise marked passive SHALL
reject; passive re-filtering SHALL NOT be mistaken for authority filtering.
Tests that need normalization compare a passive serialization directly through
a damage-specific test normalizer and do not call `StateFilter` on it.

The Network passive installer SHALL extract, validate, and retain
`passive_damage_ledger`, all per-ship `facedown_count` facts, and public faceup
objects before invoking ordinary full-state field reconstruction that currently
ignores filtered-only fields. Installation is one purpose-specific parse and
commit; presentation may not repair a lost ledger afterward.

Authority/local/replay `GameState` retains `damage_deck` and has no passive
ledger. Passive `GameState` has `damage_deck == null` and a validated
`PassiveDamageLedger`; it has no RNG. `GameState` SHALL provide distinct
authority/replay and passive-Network installation validation rather than
weakening the full-state validator.

The ledger is the sole passive owner of draw count, discard identities, and
per-ship facedown counts. `ShipInstance` may hold a non-serializing binding to
the ledger solely so existing hull/destruction queries can read the count. It
SHALL NOT cache or duplicate the count. Add a count query (for example,
`get_facedown_damage_count()`) and make total-damage, remaining-hull,
destruction, health, displays, repair affordances, and summaries use it.
Authority-only concrete-card mutators SHALL reject use on a ledger-bound ship.

### 6.2 Damage-specific ledger operations

The ledger SHALL expose only damage-specific validated operations needed by
the commands below:

- consume `N` hidden draws;
- increment/decrement a named ship's facedown count;
- add/remove a public faceup card through the owning ship command surface;
- append one or more newly public discard cards;
- remove a known public faceup card to discard or facedown; and
- clear a destroyed ship's facedown count while appending the identities made
  public by that same result.

`consume N hidden draws` is deterministic over aggregate facts:

1. consume from `draw_count`;
2. when another draw is required at zero, require a non-empty public discard,
   move its entire count into hidden draw count, clear public discard, and
   consume the draw; and
3. reject before mutation when draw plus discard counts cannot satisfy `N`.

The reshuffled order and RNG are never represented. A command that makes a
drawn card faceup supplies that card under its result contract. If that draw
occurs after aggregate discard reshuffle, the passive command additionally
validates the public card against the pre-reshuffle discard multiset; it still
does not learn the shuffled order.

After each transaction, numeric card conservation SHALL hold across hidden
draw count, public discard count, all facedown counts, and all public faceup
cards. This check SHALL not enumerate or infer hidden identities.

## 7. Six Live Damage Command And Result Contracts

All card dictionaries below SHALL match the existing canonical
`DamageCard.serialize()` schema, have the required public face state, and be
accepted only in the transition that makes the identity public. Unknown
application-result fields reject. Presentation-only hull, shield, title,
owner, index, and destruction values SHALL be derived from the committed
canonical post-state and command; they SHALL not be added to application
results merely for UI use.

| Contract ID / command | Semantic command correction | Exact application result | Passive application boundary |
| --- | --- | --- | --- |
| `resolve_damage` / `ResolveDamageCommand` | Keep only `attack_id` intent. Authority draws inside the command. Remove stale documentation/normalization implying payload damage cards. | Squadron or zero hull draw: `{}`. Ship draw: `{ "faceup_draws": Array[Dictionary{ordinal:int, card:Dictionary}] }`. | Derive damage/shield/hull-card count and critical-faceup ordinal from current attack and filtered ship. Validate zero or one permitted faceup entry at the exact ordinal and public card schema. Consume the aggregate draws, add supplied public faceup objects, add the remaining count facedown, update shields/current attack/destruction atomically. No facedown identity is returned. |
| `overlap_damage` / `OverlapDamageCommand` | Command contains only the two ship identities. Delete `moving_card`/`other_card` from payload/history and remove scene pre-draw. Authority snapshots the deck, draws both, and commits both or neither. | `{}` | Validate both ships and two available aggregate draws; consume two and increment each ship count once. No identity is transported or logged. |
| `persistent_effect_damage` / `PersistentEffectDamageCommand` | Keep target and public triggering `effect_id`; remove `card_data` and `draw_from_deck` alternatives. Authority always draws inside the command. Remove `GameBoard` pre-draw. | `{}` | Validate the public persistent source and one available aggregate draw; consume one, increment facedown count, and apply destruction/activation-boundary effects atomically. Remove `card_title`/`card_data` from results and diagnostics. |
| `resolve_immediate_effect` / `ResolveImmediateEffectCommand` | Payload identifies ship, public faceup `card_index`, and choice. Remove `effect_id`; command derives and validates it from the pre-state card. | `{}` | Deterministic effects apply from command/pre-state. Effects that flip the card remove the public object and increment facedown count. Structural Damage additionally consumes one aggregate draw, increments facedown count, and marks newly lethal ship damage for authority cleanup. No result/history/log repeats an identity that is facedown after commit. Life Support Failure leaves its public faceup object unchanged. |
| `repair_action` / `RepairActionCommand` | Shield actions unchanged. Faceup repair selects public index. Facedown repair selects only a count ordinal; UI presents generic facedown choices and never passes a card object/identity. | Non-hull or faceup hull repair: `{}`. Facedown hull repair: `{ "discarded_card": Dictionary }`. | Validate engineering context and count/index. Faceup repair moves the known public object to discard. Facedown repair decrements count and appends the authority-supplied identity, which becomes public in this transition. Validate post-state/card conservation before commit. |
| `destroy_unit` / `DestroyUnitCommand` | Ship target identity unchanged. | `{ "facedown_discards": Array[Dictionary] }`, including an empty array when the ship has zero facedown damage. | Require result length equal to the pre-state facedown count. Clear that count, move known faceup objects plus newly public result cards to discard, and preserve existing destruction cleanup atomically. These identities are now public; they were not exposed earlier. |

`DebugDealDamageCommand` is deliberately absent from this catalog. It remains
available only in local/Hot-Seat full-authority contexts. Live Network UI,
submission, host submitter exception, and transport admission SHALL reject it
before `DebugController` queries `DamageDeck` membership. No success or
rejection path may expose named hidden-card availability.

### 7.1 Authority-only destruction cleanup ordering

Each successful live-authority ship-damage command that newly marks one or more
ships destroyed--ship-target `ResolveDamageCommand`, `OverlapDamageCommand`,
`PersistentEffectDamageCommand`, or lethal Structural Damage through
`ResolveImmediateEffectCommand`--SHALL derive exactly one `DestroyUnitCommand`
follow-up per newly destroyed ship from the committed canonical post-state.
Squadron destruction has no damage-card cleanup and does not create this
follow-up. This is a bounded use of
the existing `CommandProcessor` deferred-follow-up queue, not a new continuation
framework or command hook:

1. only `MODE_LIVE_AUTHORITY` derives cleanup; Network mirrors and replay do
   not synthesize it;
2. the triggering damage command is recorded and broadcast first;
3. cleanup commands are queued in deterministic owner/index order immediately
   before the triggering command's existing current-attack, timing, commanded-
   squadron, or ship-phase progression continuation;
4. existing rule-observer order before this bounded post-success derivation is
   preserved;
5. each cleanup is executed, recorded, and broadcast through the existing
   authority follow-up drain; replay later executes the recorded cleanup command
   and does not derive a duplicate; and
6. only after accepted cleanup may presentation emit fade and public-discard
   visuals. `EventBus.ship_destroyed` presentation/listener paths SHALL NOT
   create or submit semantic `DestroyUnitCommand` cleanup. `GameManager` retains
   its existing elimination, scoring, and game-end responsibilities, invoked
   from or after the accepted authoritative cleanup as appropriate; BUG-042
   changes cleanup-command ownership, not those unrelated semantics.

`DestroyUnitCommand.validate()` SHALL require an existing ship that is already
canonically destroyed and still has damage awaiting cleanup. A ship with no
remaining faceup objects and zero facedown count is already cleaned; a stale or
duplicate cleanup rejects without history, cursor, result, or presentation.
Overlap may produce two cleanup follow-ups, one for each newly destroyed ship;
each target appears exactly once and deterministic target ordering is tested.

This ordering preserves BUG-035: cleanup follows the accepted damage result but
precedes `CompleteAttackCommand` or other progression derived from that damage.
It also precedes the existing persistent-damage ship-phase termination
continuation. No BUG-035 legality, acknowledgement, or recovery rule changes.

All authority damage paths SHALL snapshot or prevalidate every touched owner so
draw/reshuffle, ship, current attack, interaction flow, token/dial state, and
destruction changes either commit together or fully restore. Passive commands
SHALL prevalidate the complete ledger delta and public card payload before
mutation so their commit is non-fallible.

The following identity-bearing legacy behavior SHALL be removed, not retained
as compatibility:

- `OverlapDamageCommand.moving_card` / `other_card`;
- `PersistentEffectDamageCommand.card_data` and scene pre-draw;
- facedown entries in `ResolveDamageCommand.damage_cards` results;
- `effect_id` duplication for an immediate card that becomes facedown;
- facedown card titles/data in persistent/repair results before the public
  discard transition; and
- remote presentation code that searches/deserializes passive facedown cards;
- live Network `DebugDealDamageCommand`, its host-principal bypass, and every
  debug availability/rejection oracle; and
- presentation-owned submission of `DestroyUnitCommand`.

## 8. Authorized Production, Test, And Document Scope

### 8.1 Production changes authorized after workbook acceptance

| Scope | Authorized change |
| --- | --- |
| `src/core/commands/game_command.gd` | Narrow default-rejecting passive result hook; canonicalization updates for changed semantic command fields. |
| `src/autoload/command_processor.gd` | Result-aware mirror mode retaining all existing transaction ownership and failure ordering; exact live-command schema gate; bounded authority-only destruction cleanup derivation placed before existing progression continuations. No generic continuation hook or command allowlist mutation. |
| `src/autoload/game_manager.gd` | Pass the strict result/envelope into the processor; derive presentation after success from command plus canonical post-state; install/reset/restore the passive ledger and cursor; remove identity-dependent remote damage presentation. |
| `src/autoload/network_manager.gd` | Protocol 5 envelope, targeted per-viewer results, metadata separation, strict handshake cutover, and purpose-specific fresh-start staging/commit/install ACK/admission/release. Preserve resume/reconnect assignment ownership. |
| `src/autoload/lobby_manager.gd` | Authority-first fresh construction and release ordering; keep replay bootstrap separate. |
| `src/core/commands/command_submitter.gd`, `network_host_command_submitter.gd`, `network_command_submitter.gd`, `src/core/network/command_sync_gate.gd` | Carry/build/wait for the complete protocol-5 envelope without mixing metadata, application results, or presentation data; preserve held-dial ordering and local synchronous return behavior; prevent passive `submit_authoritative()` from originating destruction cleanup; remove the live Network debug bypass. |
| `src/core/network/state_filter.gd` | Emit the exact passive ledger, hide facedown identities from both players, and reject non-authority/passive input. RNG removal remains unchanged. |
| `src/core/state/game_state.gd`, `src/core/state/ship_instance.gd`, and a damage-specific passive-ledger file under `src/core/damage/` | Install, validate, serialize for filtered comparison, bind count queries, and distinguish full versus passive representations. No generic hidden-state facility. |
| `src/core/damage/damage_deck.gd` | Preserve full authority behavior; expose only command-needed snapshot/restore or aggregate evidence; require explicit authority RNG rebinding after deserialization/replacement. Never instantiate it passively. |
| Four Section 5 command files | Exact dice result validation/application and unchanged authority/replay execution. |
| Six Section 7 live command files | Exact ledger/result contracts, removal of pre-drawn identity payloads, atomic authority/passive variants, and stale/duplicate destruction-cleanup rejection. `DebugDealDamageCommand` remains unconverted local/Hot-Seat behavior and is rejected in live Network. |
| `src/core/setup/fleet_setup_bootstrapper.gd`, `src/core/setup/learning_scenario_preparer.gd`, `src/core/state/learning_scenario_setup.gd`, `src/scenes/game_board/game_board.gd` | Construct the complete fresh authority before publication; board consumes an installed state instead of independently constructing a passive deck. Replay remains full-state construction. |
| `src/scenes/game_board/ship_activation_controller.gd`, `src/scenes/game_board/attack_executor.gd`, `src/scenes/game_board/command_router_adapter.gd` | Delete overlap/attack pre-draw helpers, identity-bearing facedown logs, presentation dependence on facedown result objects, and presentation-owned semantic destruction submission. Destruction presentation/fade paths occur only from/after accepted cleanup and never submit cleanup; GameManager's existing elimination/scoring/game-end listener responsibilities remain at that post-cleanup point. |
| `src/core/effects/rules/damage_cards/ship/ruptured_engine.gd`, `damaged_controls.gd`, `thruster_fissure.gd` | Submit the single command-owned draw intent without legacy `draw_from_deck`/card payload alternatives; preserve each accepted rule trigger. |
| `src/core/damage/repair_resolver.gd`, `src/ui/commands/repair_panel.gd`, `src/ui/ship/damage_card_display.gd`, `src/scenes/game_board/ui_panel_manager.gd`, `src/ui/ship/ship_card_panel.gd` | Use count/public-card APIs; show generic facedown repair choices; retain public faceup behavior. |
| `src/core/damage/immediate_effect_signals.gd`, `src/scenes/game_board/damage_card_immediate_effect_controller.gd`, `attack_panel_mirror.gd`, `command_router_adapter.gd` | Derive visuals/routing from committed public state and generic facedown counts; do not recreate identity or mutate ledger. |
| `src/scenes/game_board/debug_controller.gd` | Disable damage-card debug selection in live Network before any `DamageDeck` availability query; retain local/Hot-Seat full-authority behavior. |
| `src/core/commands/game_replay.gd`, replay tests, replay fixtures, and baseline provenance | Advance format 7 -> 8; reject format 7 before command application; genuinely regenerate and review format-8 replay/baseline fixtures under `docs/development/REPLAY_BASELINE_WORKFLOW.md`. No field migration or compatibility mode. |

Narrow caller/support changes directly required by these files are authorized
when traced in the implementation diff. An unlisted new authority or mutation
owner triggers Section 13.

### 8.2 Test scope

Authorized tests include focused unit tests adjacent to the changed classes;
current command, damage, filter, save, replay, setup, and Network transport
suites; production-path current-attack/resume/reconnect suites; and the
process-isolated Network acceptance harness. Synthetic full-state mirrors may
support unit tests but do not satisfy live acceptance.

Format-8 fixture and canonical baseline regeneration is authorized only through
the existing replay-baseline governance. Editing a format-7 header or payload
in place is not authorized evidence.

### 8.3 Document scope

After implementation, update this workbook's evidence/status, the BUG-042 issue
record, `docs/setup_network_game.md`, and QA/manual-acceptance material required
to describe protocol 5 and the new bootstrap. Do not rewrite ADR-012, ADR-013,
CON-001, Arc42, BUG-035, or unrelated architecture documents in this scope.

## 9. Implementation Slices And Mandatory Migration Order

No intermediate slice is deployable. Protocol 5 is enabled only when every
slice and gate passes; the repository may carry reviewable intermediate code
on the implementation branch.

### Slice 1 — Characterization and secrecy canaries

Lock current full authority save/replay behavior, enumerate all direct RNG and
damage paths above (including negative-space/dead-path classifications), add
canaries proving current leaks are rejected by the new target schemas, and add
projection-equivalence helpers. Characterize both deck/RNG binding-loss sites,
presentation-owned destruction submission, live debug availability, and
format-7 rejection. Do not change runtime behavior yet.

Exit: inventories are executable; tests fail for the known old seed,
own-facedown, pre-draw, result, and bootstrap behavior for the expected reason.

### Slice 2 — Passive ledger model and filtered round trip

Implement the damage-specific ledger, full/passive installation validators,
ship count query binding, all-player facedown filtering, filtered
serialization/deserialization, projection/UI count reads, aggregate draw and
reshuffle operations, and conservation checks.

Exit: an authority snapshot filters and round-trips to the exact passive
representation with no RNG/deck/order/facedown identities; no live path uses
it yet.

### Slice 3 — Result-aware command transaction and protocol envelope

Implement the base command hook, processor execution mode, ordered receiver,
strict metadata/result separation, per-viewer result projection, and failure
atomicity. Preserve all non-result commands and replay execution.

Exit: missing versus empty result, wrong schema/version/viewer/command,
unknown fields, malformed values, rejection atomicity, exact-once
history/cursor, and no-success-presentation tests pass.

### Slice 4 — Four direct RNG commands

Implement Section 5 one command at a time, including long-range Evade's
no-RNG path. Preserve authority rollback and replay reproduction.

Exit: each command converges authority to a no-RNG passive mirror and the same
semantic command replays from seed without a live result.

### Slice 5 — Six live damage commands, cleanup ownership, and deck binding

Implement Section 7 in this order: `ResolveDamageCommand`, overlap,
persistent damage, immediate effects, repair, and destruction. Remove scene
pre-draw and identity-bearing payload/result/log paths as each owner converts.
Make destruction cleanup one authority-only deterministic follow-up ordered
before existing progression, remove semantic cleanup from presentation, reject
stale/duplicate cleanup, and disable damage debug in live Network. Rebind every
full replacement deck to its authority RNG. Update count-based presentation and
repair selection.

Exit: every draw, pre-draw, faceup/facedown placement, flip-to-facedown,
repair, discard, destruction cleanup, deck exhaustion, and reshuffle path works
against full authority and passive ledger representations with projection
equivalence and secrecy; exactly one authority cleanup occurs per destroyed
ship; save/load and rollback replacement preserve reshuffle RNG binding; live
Network debug cannot query or submit damage selection.

### Slice 6 — Fresh authority-first bootstrap

Move ordinary fresh construction before scene release, stage the filtered
snapshot/cursor/binding, install and acknowledge it, open admission, then
release scenes. Keep Network replay's accepted seed bootstrap separate.

Exit: fresh, resume, and reconnect use the same passive schema/installer and
all can execute subsequent dice and damage commands without passive RNG/deck.

### Slice 7 — Protocol-5/replay-8 cutover and full regression

Set `NetworkManager.PROTOCOL_VERSION` to 5, update handshake tests and process
harnesses, reject version 4, remove obsolete version-4 live message paths, and
set `GameReplay.FORMAT_VERSION` and its signed alias to 8, reject replay format
7 before command application, genuinely regenerate/review format-8 fixtures,
and run Sections 11--12.

Exit: no protocol downgrade or replay migration/normalization exists; all
evidence is recorded under the applicable Network and replay-baseline gates.

### Non-deployable boundaries

The following combinations SHALL never ship:

- passive RNG removed before strict result application covers all four direct
  consumers;
- a passive ledger installed while any listed damage command still expects
  local hidden card objects or `DamageDeck`;
- `StateFilter` hiding both players' facedown identities before count-based
  hull, destruction, repair, and presentation paths are complete;
- scene pre-draw removed before the owning authority command draws atomically;
- fresh shared seed removed before authority construction and filtered
  install/ACK/admission/release are complete;
- protocol 5 accepting a version-4 peer or version 4 accepting new envelopes;
- replay format 8 accepting, normalizing, or silently reinterpreting a format-7
  command history;
- live Network damage debug enabled or destruction cleanup still submitted by
  presentation; or
- a partially converted result catalog behind runtime command-name fallback.

## 10. Fresh Bootstrap, Resume, Reconnect, And Cutover

### 10.1 Required fresh-start order

Ordinary fresh Network start SHALL execute exactly this order:

1. validate lobby, binding, setup/scenario input, and close host/client
   player-command admission and game-scene input;
2. authority selects the private live seed and constructs the complete
   detached authoritative `GameState`, RNG, shuffled damage deck,
   ships/squadrons, setup facts, binding, and initial lifecycle facts using
   existing scene-independent setup owners. This candidate is not assigned to
   `GameManager.current_game_state`, emits no `game_started`, changes no live
   cursor/history, and executes no start/progression command;
3. authority validates the detached candidate and captures the fresh initial
   cursor that will be installed at commit;
4. authority derives one `StateFilter` snapshot for each assigned viewer from
   that exact detached candidate;
5. protocol 5 stages snapshot, binding/principal assignment, viewer, scenario
   metadata, attempt identity, and captured cursor while admission stays shut;
6. client deserializes and validates the passive ledger/no-RNG representation,
   stable identities, assignment, lifecycle state, and cursor, then returns a
   staging acknowledgement without making it live;
7. authority revalidates the same candidate fingerprint/cursor/association and
   reaches the sole publication linearization point: association commit remains
   admission-closed, authority installs the detached full state/cursor exactly
   once through `GameManager`, and client commit atomically installs its already
   validated passive state/cursor without rebuilding a scene;
8. client returns installation acknowledgement containing the accepted
   attempt and cursor;
9. only after every required installation acknowledgement does authority open
   command admission for both endpoints; and
10. authority releases the game-board scene. Each peer spawns/projections from
    its already-installed state. No client setup code constructs RNG, deck, or
    hidden cards after release. Existing authority start/progression commands
    begin only after this release through normal `CommandProcessor` submission;
    a peer whose board is still entering the scene applies any accepted command
    to its already-installed canonical state and projects that post-state when
    the board becomes ready.

Timeout, disconnect, fingerprint/cursor drift, deserialization failure, or
negative ACK fails closed. Before step 7 publication, `LobbyManager` and
`NetworkManager` discard only the detached candidate/staged attempt and return
to the unchanged lobby: there is no `GameManager` state, cursor, history,
`game_started`, or scene mutation to roll back. After step 7 linearization the
authority is never rolled back; a failed endpoint remains unassigned and
non-admitted and must use reconnect. No gameplay command may race ahead of
canonical installation or the captured cursor.

The staging ACK and installation ACK have distinct bounded purposes and reuse
the accepted MATCH-003 attempt machinery. The staging ACK proves that the full
passive schema, stable identities, assignment, fingerprint, and cursor are
valid before irreversible host publication. The installation ACK proves that
the same staged attempt/cursor is live before admission and scene release. This
does not create a generic bootstrap state machine, generic snapshot service, or
second publication owner.

### 10.2 Resume and reconnect equivalence

Existing MATCH-003 assignment rules remain. Both fresh-session resume and
confirmed reconnect SHALL call the same filter, passive deserializer,
installation validator, ledger binder, cursor restore, install ACK, admission,
and scene/projection release used by fresh start. Reconnect SHALL not reload or
rewind the authority. Fresh, resumed, and reconnected snapshots SHALL be
schema- and projection-equivalent when derived from the same authority state
for the same viewer.

### 10.3 Protocol cutover

- Protocol version changes from 4 to **5**.
- Handshake equality remains strict; version 4 is rejected, never negotiated
  or downgraded.
- Protocol 5 requires the new result envelope, targeted viewer result,
  authority-first fresh bootstrap, and passive ledger schema as one atomic
  compatibility boundary.
- Existing live version-4 sessions are not resumable/reconnectable with a
  version-5 peer. Both processes must update together.
- No adapter may seed a passive peer, restore identity-bearing payloads, or
  translate old results to new contracts.
- The same release advances replay format 7 to 8 as the corrected semantic
  command-model boundary. Protocol and replay versions remain separate owners,
  but neither partial cutover is deployable.

## 11. Save/Load, Replay, History, And Determinism

### 11.1 Authority save/load

Authority saves remain full `GameState.serialize()` payloads containing exact
RNG seed/current state, full draw order, public discard, faceup and facedown
identities, binding, and canonical lifecycle state. The passive ledger is
never written to a user save or checkpoint. Network clients remain unable to
save.

Loading SHALL restore full RNG/deck state before any later command. Compare an
uninterrupted authority with a save/load fork across:

- at least two dice RNG commands;
- ordinary hidden damage draws;
- a draw that exhausts the pile and reshuffles public discard; and
- later repair/destruction discard transitions.

Outcomes, authoritative canonical state, final RNG state, command order, and
cursor SHALL match. The restored authority then filters a new passive ledger;
it does not restore a previously stored passive ledger.

The audit-proven RNG-rebinding defect is **within BUG-042 scope**, not deferred.
`GameState.deserialize()` currently reconstructs `DamageDeck` and `GameRng`
independently, and `ResolveDamageCommand` currently replaces a rolled-back deck
through `DamageDeck.deserialize()`. Every such full-authority replacement SHALL
call `DamageDeck.set_rng(game_state.rng)` after both objects exist and before any
draw/reshuffle. A passive state never performs this binding because it never
owns a `DamageDeck` or RNG. Future replacement-deck sites found in the scoped
diff require the same binding or trigger the inventory stop gate.

In addition to the save/load fork, force a late `ResolveDamageCommand` failure
after a deck snapshot, verify complete state rollback, then exhaust the restored
deck into discard reshuffle. Its drawn identities, final deck order, final RNG
state, history, and cursor SHALL match an uninterrupted control. This catches a
replacement that restores cards but silently falls back to global shuffle.

The authority save schema/version SHALL not change merely for transient live
results or the passive-only snapshot schema. If implementation requires an
authority save-format change, stop under Section 13.

### 11.2 Replay format 8 and history

Replay format 8 remains accepted seed plus corrected semantic command history.
It reconstructs a full authority model and executes normal command `execute()`
in sequence. It never receives result envelopes, per-viewer results, transport
metadata, or a passive ledger.

History SHALL contain the corrected semantic intent only. In particular it
shall not contain overlap/persistent pre-drawn card data, immediate-effect
identity duplicated after flip, live dice outcomes, facedown damage outcomes,
or protocol metadata. A replay containing every Section 5 command and every
Section 7 transition SHALL reproduce the authority state exactly without live
results.

`GameReplay.FORMAT_VERSION` advances from 7 to **8** and
`SIGNED_FORMAT_VERSION` remains its alias. The existing exact version check
rejects every format-7 artifact before canonicalizing or applying any command.
There is no format-7 payload normalization, field stripping, migration,
header-only edit, or silent reinterpretation. Format-8 replay fixtures and any
affected canonical baselines SHALL be genuinely re-recorded from the corrected
semantic command model, reviewed for provenance and command history, and
promoted only under `docs/development/REPLAY_BASELINE_WORKFLOW.md`. Historical
format-7 fixtures remain in version control as historical evidence and rejection
fixtures where useful; they are not rewritten into format 8.

## 12. Required Verification And Acceptance Evidence

### 12.1 Focused contract evidence

| Area | Minimum automated proof |
| --- | --- |
| Result transaction | Default command rejection; exact result and live semantic-command schemas, including recursive `resolve_immediate_effect.choice` validation; unknown/missing/malformed/removed top-level or nested payload fields; missing vs empty result; contract/command/viewer/version mismatch; preflight/validation before mutation; exact-once history/cursor/signal; failed entry blocks later sequence; no passive follow-up or success presentation. Identity-bearing rejected values never enter diagnostics/logs/history. |
| Four RNG commands | All Section 5 branches, stale intent, illegal face/color, wrong lifecycle/source/token, authority RNG rollback, passive no-RNG application, and replay regeneration. |
| Ledger filter/install | Both viewers receive identical damage secrecy: no facedown identities for own or opponent ships; stable complete counts, public faceup/discard objects, no RNG/deck; malformed/dual representation rejects. |
| Aggregate draw/reshuffle | Draw within pile, exact exhaustion, draw across exhaustion into discard reshuffle, insufficient total, faceup draw before/after reshuffle, count/card conservation, and no RNG/order on passive. |
| Six live damage commands | Every Section 7 authority/passive contract, zero-field results, faceup-public transition, facedown count transition, faceup-to-facedown removal, repair-to-public-discard, destruction-to-public-discard, rollback, and strict identity non-disclosure. |
| Destruction ownership/order | Both attacker/defender ownership directions, host- and client-authored lethal damage, overlap destroying zero/one/two ships, exactly one authority-generated cleanup per target, triggering damage broadcast first, cleanup before existing attack/timing/phase continuation, passive presentation submits none, and stale/duplicate cleanup rejects without state/history/cursor/presentation. |
| Debug exclusion | Live Network UI cannot open/query named damage-card availability; host and client submission reject before deck access; no availability or rejection oracle. Local/Hot-Seat debug behavior remains full-authority. |
| Authority deck binding | Full deserialize and every rollback replacement bind the restored deck to `GameState.rng`; save/load-then-reshuffle and forced-failure-rollback-then-reshuffle match uninterrupted control. |
| Replay 8 boundary | New format-8 corrected histories replay deterministically; representative format-7 fixtures reject before command canonicalization/application; no header edit, payload normalization, migration, or live result dependency. |
| UI/projection | Hull/destruction, ship panels, summaries, generic facedown repair choices, immediate-effect visuals, and remote presentation read counts/public cards without creating/mutating identities. |

Focused tests SHALL extend or add siblings to:

- `tests/unit/test_network_command_result_ordering.gd`;
- `tests/unit/test_attack_commands.gd`;
- `tests/unit/test_concentrate_fire_timing_window.gd` and Swarm rule tests;
- `tests/unit/test_state_filter.gd`;
- `tests/unit/test_damage_deck.gd` plus passive-ledger tests;
- a new focused damage-command result suite plus existing
  `test_repair_resolver.gd` and `test_destruction_cleanup.gd`;
- production-seam destruction ownership tests spanning `CommandProcessor`,
  `NetworkManager`, `GameManager`, and the three current presentation emitters;
- `DebugController`/Network submission exclusion tests;
- replay-format boundary tests using genuine format-7 rejection fixtures and
  newly generated/reviewed format-8 fixtures;
- setup/bootstrap tests for Learning Scenario and fleet packages; and
- affected damage display/repair/presentation tests.

### 12.2 Production-path matrix

| Path | Required evidence |
| --- | --- |
| Fresh two-process Network | Real lobby start through Section 10 ordering, including a staging failure proving no tentative authority publication and an installation failure proving post-linearization reconnect behavior. Client has no seed/RNG/deck/facedown identity. Roll, reroll, ordinary facedown damage, faceup damage, repair, and a reshuffle-capable fixture all apply; cursor/history and filtered projection converge. Board entry consumes installed state and never constructs a second deck/RNG. |
| Fresh-session resume | Save after RNG and damage consumption; real assignment/stage/install/ACK/admission/scene path; execute two dice commands and damage/repair afterward with no queue stall or fallback. |
| Confirmed reconnect | Keep host state/cursor live; stage the same filtered schema; after ACK/admission execute dice and damage transitions exactly once. |
| Ordered result failure | Out-of-order prerequisite/random/damage/later envelopes plus duplicate; buffer until contiguous. Exercise every failure category without partial state or later bypass. |
| Projection equivalence | After every accepted sequence prefix, compute `StateFilter.filter_for_player(authority.serialize(), viewer)` and compare its normalized passive representation to the peer's serialized passive state. Obtain real-process evidence for both viewers by running the two-human harness twice with host/client player assignments swapped, or by an equivalent dual-endpoint harness that exercises both actual install/result/presentation paths. In-memory dual filtering alone does not satisfy acceptance. Cover fresh, resume, reconnect, dice, damage, flip, repair, destruction, exhaustion, and reshuffle. |
| Authority save/load | Uninterrupted versus loaded fork equivalence described in Section 11.1, including final RNG/deck state, plus forced ResolveDamage rollback/replacement followed by reshuffle. |
| Replay | Format 8 seed plus corrected semantic history only; full deterministic reproduction; no result/ledger/transport input. Format 7 rejects before commands. Genuine format-8 fixture/baseline provenance is reviewed. |
| Protocol cutover | Version 5 peers connect; 4↔5 in both directions reject at handshake; no downgrade/adapter; old result/bootstrap message shapes reject. |

Use `tests/integration/test_current_attack_shared_protocol.gd`,
`test_current_attack_production_resume.gd`,
`test_reconnection_mid_attack.gd`, `test_network_transport.gd`, save/replay
suites, and `tests/acceptance/network_resume/*`/the process-isolated runner as
the established production seams. New focused files may be added where
separation improves defect detection.

### 12.3 Information-secrecy gate

Inspect both viewers' raw and decoded:

- fresh configuration/staged snapshot;
- resume and reconnect snapshots;
- command envelopes and exposed command history;
- application results, presentation results, and transport metadata;
- authority-to-host local projection result;
- client canonical state and presentation model; and
- normal, rejection, assertion, payload, trace, and diagnostic logs.

The inspection SHALL prove absence of live seed/current RNG/future stream,
hidden deck order, placeholder/derived hidden identity, and every identity that
remains facedown. Canary effect IDs placed in authority facedown cards SHALL
not occur anywhere on either player's surfaces. Public faceup/discard
transitions SHALL reveal only the cards made public by that transition.
Secret values SHALL be asserted by presence/absence checks without printing
them into acceptance logs.

The gate SHALL open the production debug UI in live Network mode and prove that
damage selection is disabled before its availability helper can query the deck.
It SHALL also submit serialized protocol-5 commands containing each removed
identity field at both top level and inside `resolve_immediate_effect.choice`,
plus unknown nested choice fields, and prove rejection before diagnostics,
execution, history, and logging.

### 12.4 BUG-035 focused regression protection

Because this workbook changes `CommandProcessor`, ordered result handling,
`ResolveDamageCommand`, completed-attack presentation timing, and damage
projection, implementation SHALL rerun the accepted BUG-035 focused branches:

1. processor-owned `resolve_damage` follow-up executes exactly once; a
   synchronous presentation reaction does not submit a duplicate, and an
   explicit duplicate/stale `resolve_damage` sent through the real
   transport/processor seam rejects without mutation, history, cursor,
   follow-up, or presentation;
2. lethal ship damage records/broadcasts the triggering damage command, then
   exactly one authority-derived `DestroyUnitCommand`, then the unchanged
   existing attack/progression continuation; passive presentation submits no
   cleanup and a duplicate cleanup is rejected;
3. two-human Network, client-authored ship-commanded squadron Attack destroys
   the last live non-Heavy engager; after both accepted acknowledgements the
   same squadron's newly legal Move is recovered, no completion is synthesized,
   and later Move consumes/releases through the accepted path;
4. paired non-lethal/continued-engagement control produces exactly one
   `CompleteSquadronActivationCommand` where Move remains illegal;
5. completed-result acknowledgement presentation still takes precedence over
   stale Attack flow on host and passive peer; and
6. normal Squadron Phase Move→Attack and Attack→Move/terminal branch coverage
   from the 2026-09-01 BUG-035 amendment remains green.

These are regressions only. BUG-042 SHALL NOT change BUG-035 continuation,
inspection, action-legality, modal-recovery, or composed-return semantics. The
separate `squadron_destroyed` event payload-type defect is not absorbed into
BUG-042 unless a changed line cannot preserve current behavior without an
Owner-approved scope change.

### 12.5 Repository and manual gates

Run all focused suites above, the separate-process Network acceptance runner,
relevant rule/timing/current-attack/setup/filter/damage/save/replay suites,
`./scripts/run_tests.sh`, `./scripts/run_baseline_traces.sh --all`,
`./scripts/lint_phase_k.sh`, `./scripts/quality_check.sh`, and
`git diff --check`.

Manual QA SHALL use isolated host/client user roots and record build, protocol
5, assigned sides, attempt/cursor transitions, accepted command sequences,
projection-equivalence hashes, and redacted secrecy observations. It SHALL
exercise fresh, saved resume, confirmed reconnect, all four dice contracts,
ordinary/critical/overlap/persistent/Structural damage, faceup/facedown repair,
authority-only destruction cleanup, live debug exclusion, deck
exhaustion/reshuffle, authority save/load and rollback replacement, replay-7
rejection, and genuine replay-8 export/rebuild.

### 12.6 Acceptance evidence package

Implementation is complete only when the handoff contains:

- exact current RNG and damage consumer inventories with diff traceability;
- one test/result reference for every contract row in Sections 5 and 7;
- fresh/resume/reconnect attempt traces proving install ACK precedes admission
  and scene release;
- both-viewer projection-equivalence evidence after every tested sequence;
- protocol 4 rejection and protocol 5 success evidence;
- replay format-7 rejection and reviewed format-8 fixture/baseline provenance;
- authority save/load and rollback-replacement RNG/deck comparison plus
  format-8 seed-plus-history replay proof;
- redacted command/history/result/log secrecy report;
- BUG-035 focused regression results; and
- final test, quality, baseline, `git diff --check`, scoped diff, and worktree
  review results.

## 13. Stop Gates And Exclusions

Stop and request Project Owner direction rather than improvise if implementation
requires any of the following:

- passive possession, reconstruction, prediction, or fallback creation of live
  RNG, hidden deck order, facedown identity, placeholder identity, or encrypted
  identity;
- a result required for correct passive application that cannot be validated
  from command, order, filtered pre-state, and viewer-authorized facts without
  exposing information still hidden after the transition;
- canonical mutation in `NetworkManager`, `GameManager`, `StateFilter`, scene,
  projection, modal, UI, logger, or a generic result/snapshot-mutation service;
- a second owner or duplicate cache for passive ledger facts;
- changed RNG/deck/damage rules, generic hidden-state infrastructure, generic
  continuation infrastructure, or generic snapshot mutation infrastructure;
- replay results, a replay format other than the Owner-approved format 8,
  changed replay seed policy, replay-7 migration/normalization,
  passive-ledger replay, or persistence of live results/metadata;
- an authority save-format/version or save-ownership change;
- a new principal/assignment/admission owner, reconnect authority change,
  spectator policy, retry protocol, or live version compatibility layer;
- result application that cannot be atomic across every touched accepted owner;
- a need to change accepted BUG-035/CON-007 recovery semantics or fold the
  separately tracked `squadron_destroyed` payload-type defect into this repair;
  authority ownership of ship destruction cleanup required by Sections 7 and
  12 remains in scope; or
- materially broader production scope than Section 8.

Explicit exclusions:

- redesigning ADR-012 or ADR-013;
- generic redaction/secret-object/placeholder systems;
- generic command-result/event application architecture;
- generic continuation or snapshot infrastructure;
- gameplay damage-rule, card-effect, attack-lifecycle, principal, assignment,
  save-ownership, or replay redesign beyond the Owner-approved format-8 hard
  cutover;
- spectator support or backward-compatible protocol negotiation;
- BUG-035 production repair; and
- production implementation or commits during this workbook revision.

Current stop-gate status: **clear for fresh targeted independent re-audit.**
The audit's replay decision is resolved by the Owner as a format-8 hard cutover.
No additional Owner decision or accepted-architecture conflict is known after
the corrections reconciled in Section 15.

## 14. Workbook Acceptance Criteria And Consistency Result

This workbook may become the single implementation specification only after an
independent audit confirms:

1. every current direct RNG and damage transition is present in Sections 2,
   5, 7, and 8;
2. strict command intent and results contain no unknown/removed fields,
   transport metadata, redundant UI-only data, or identity that remains
   facedown;
3. the passive ledger and both-player filtering exactly implement ADR-013;
4. fresh/resume/reconnect ordering and protocol-5 cutover are complete and do
   not reopen MATCH-003 authority;
5. authority save/load and replay format 8 remain the full deterministic
   contexts, every replacement deck is RNG-bound, and format 7 rejects cleanly;
6. slices have no deployable partial boundary;
7. projection equivalence, secrecy, exact-once, and BUG-035 overlap regressions
   are mandatory acceptance gates; and
8. no stop gate is silently converted into implementation discretion.

Targeted drafting consistency result:

| Authority/evidence | Result |
| --- | --- |
| ADR-012 authority-only RNG and command-owned result application | Consistent. |
| ADR-013 full authority damage plus passive filtered ledger | Consistent; old filtered-bootstrap stop gate is resolved, not defended. |
| CON-001 order, atomicity, mirror failure, and replay | Consistent. |
| ADR-008/ADR-011/MATCH-003 authority, filtering, cursor, ACK, and admission | Preserved; fresh start reuses the same bounded responsibilities without changing principal policy. |
| Current four direct RNG consumers | Complete as traced. |
| Audited damage surfaces | All seven currently reachable command classes are classified; six have live Network contracts, while debug damage is local/Hot-Seat only. Scene pre-draw, flip, repair, discard, authority-only destruction cleanup, exhaustion, reshuffle, and dead helper boundaries are explicit. |
| Save/load/replay/history | Preserved with explicit deck/RNG rebinding, format-8 corrected semantic history, format-7 pre-application rejection, and non-persistence of live result/ledger data. |
| Information secrecy | Covers payloads, exposed history, results, state, projection, logs, and diagnostics for both viewers. |
| Fresh publication | Detached candidate and staging do not mutate live authority; step 7 is the sole publication linearization point; two ACKs reuse MATCH-003 for distinct validation/install proofs. |
| Destruction ownership | Exactly one live-authority cleanup follow-up per newly destroyed ship precedes existing progression; presentation/listener paths submit no cleanup, while existing GameManager elimination/scoring/game-end responsibilities remain after accepted cleanup. |
| BUG-035 overlap | Protected by focused production-path regression including cleanup ordering; semantic repair remains excluded. |

Draft disposition: **ready for fresh targeted independent re-audit; not yet
implementation-authorizing.** Owner acceptance after that audit may change only
the status/acceptance metadata without requiring a second implementation
specification, unless the audit finds a Section 13 conflict.

## 15. Post-Audit Corrective Reconciliation

The preserved audit's four blockers and all 17 Section-19 corrections are
mandatory gates for this candidate.

### 15.1 Four blocker dispositions

| Audit blocker | Disposition | Corrected workbook evidence |
| --- | --- | --- |
| Live debug secrecy conflict | **RESOLVED** | Sections 2.3, 7, 8, 9, and 12 remove debug damage from live Network, remove the host bypass, require rejection before deck query, and add production UI/submission secrecy evidence. |
| Presentation-owned/duplicate destruction cleanup | **RESOLVED** | Sections 3, 7.1, 8, 9, and 12 define one authority-only deterministic cleanup per newly destroyed ship, exact ordering before existing progression, passive suppression, and stale/duplicate rejection. |
| Replacement deck loses RNG | **RESOLVED** | Sections 2.2, 3, 8, 9, 11.1, and 12 require rebinding after full deserialize and rollback replacement plus both continuation regressions. |
| Replay compatibility unresolved | **RESOLVED** | Sections 1, 8, 9, 10.3, 11.2, 12, and 13 implement the Owner decision: format 8, format-7 pre-command rejection, no migration/normalization, genuine governed fixture regeneration. |

### 15.2 Section-19 item disposition

| Audit item | Workbook section(s) | Status | Concise evidence |
| --- | --- | --- | --- |
| 1. Remove live `DebugDealDamageCommand` contract | 2.3, 7 | **RESOLVED** | Section 7 contains six live contracts; debug is local/Hot-Seat only. |
| 2. Add `DebugController`; reject before hidden-deck query | 2.3, 8.1, 12.1--12.3 | **RESOLVED** | Scope and tests disable live debug before availability lookup and cover the oracle. |
| 3. One authority-owned destruction follow-up | 3, 7.1 | **RESOLVED** | Live authority derives exactly one cleanup per newly destroyed ship through the existing deferred queue; presentation submits none. |
| 4. Specify cleanup ordering | 7.1, 12.4 | **RESOLVED** | Damage broadcasts first, cleanup next, then unchanged attack/timing/phase continuation; BUG-035 regression is explicit. |
| 5. Reject stale/duplicate `DestroyUnitCommand` | 7.1, 12.1 | **RESOLVED** | Validation requires destroyed state with damage still awaiting cleanup; repeat cleanup has no effects/history/cursor. |
| 6. Exact changed live command schemas | 3, 4.4, 12.1--12.3 | **RESOLVED** | Exact top-level fields and every effect-specific nested `resolve_immediate_effect.choice` shape are enumerated; recursive validation rejects unknown, removed, identity-bearing, malformed, or pre-state-inapplicable fields before diagnostics, execution, logs, and history. |
| 7. Rebind RNG after full deserialize/replacement | 2.2, 3, 8.1, 11.1 | **RESOLVED** | Every authority replacement deck calls `set_rng(game_state.rng)` before draw/reshuffle. |
| 8. Rollback-then-reshuffle regression | 11.1, 12.1--12.2 | **RESOLVED** | Forced late ResolveDamage failure is compared with uninterrupted control through reshuffle. |
| 9. Explicit RNG-defect disposition | 11.1 | **RESOLVED** | Defect is expressly within BUG-042 scope, not silently deferred. |
| 10. Resolve replay decision/scope/tests | 1, 8.1, 9, 11.2, 12 | **RESOLVED** | Owner-selected format 8; format 7 rejects; governed genuine fixtures replace compatibility. |
| 11. One fresh publication linearization point | 10.1 | **RESOLVED** | Detached candidate/stage changes no live owner; step 7 is the sole irreversible publication. |
| 12. Justify two ACKs; no generic bootstrap FSM | 10.1 | **RESOLVED** | Staging ACK proves pre-publication validity; installation ACK gates admission/scene; existing MATCH-003 attempt machinery is reused. |
| 13. Consume ledger before ordinary deserialize; authority-only filter | 6.1, 8.1 | **RESOLVED** | Passive installer captures filtered-only fields first; `StateFilter` rejects passive/non-authority input. |
| 14. Expand negative-space inventory | 2.2--2.3 | **RESOLVED** | Debug controller, passive authoritative submission, dead Evade/helper paths, setup randomness, replay fixtures, and both deck replacement sites are classified. |
| 15. Real-process both-viewer equivalence | 12.2 | **RESOLVED** | Swapped host/client assignment runs or equivalent dual-endpoint production harness are mandatory; in-memory filtering alone is insufficient. |
| 16. Add production-seam regressions | 12.1--12.4 | **RESOLVED** | Unknown fields, debug exclusion, destruction exact-once/order, duplicate ResolveDamage, deck binding, and replay-7 rejection are explicit. |
| 17. Remove obsolete claims | 1, 2, 7, 10--15 | **RESOLVED** | No seven-live-contract, live-debug, replay-7, unresolved-replay, tentative-publication rollback, or presentation-owned-cleanup direction remains. |
