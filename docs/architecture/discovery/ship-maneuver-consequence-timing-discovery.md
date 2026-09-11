# Ship Maneuver Consequence Timing Discovery

**Status:** Discovery / non-normative
**Context:** Follow-up to Ship Maneuver prerequisite impact analysis
**Purpose:** Verify displacement fallback rules and establish rules evidence for
Maneuver consequence timing and ordering before final Owner decisions and
normative refinement.

This document records repository/rules evidence and identified implementation
mismatches. It does not establish new normative architecture or Owner decisions.

Where this document identifies unresolved questions, later Owner decisions and
accepted normative documents take precedence.

Read-only analysis completed. No files were modified, no tests were run, and no normative document or BUG-043 was updated.

## 1. Unplaceable-squadron rule verification

**Status: NOT CONFIRMED.**

The repository-held RRG contains two related but distinct rules:

- During ship-overlap displacement, squadrons “cannot” be placed outside the play area. [RRG Overlapping](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:856)
- Independently, a ship or squadron whose base is actually partly outside the play area is destroyed. This is an automatic state consequence; the rules assign no player a choice to destroy it. [RRG Destroyed Ships and Squadrons](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:329), [RRG Play Area](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:891)

Neither the RRG, its incorporated FAQ/errata, nor Learn to Play says that a displaced squadron is destroyed merely because no legal displacement position can be found. Learn to Play instead says the opposing player places **all** overlapped squadrons touching the ship. [Learn to Play](/Users/Katharina/godot/Armada/Resources/SWM01-ARMADA-LEARN-TO-PLAY/SWM01-ARMADA-LEARN-TO-PLAY.md:879)

The general out-of-bounds destruction rule does not supply a fallback:

- Placing a squadron off-board would first violate the specific displacement instruction.
- “No legal position exists” is not the same trigger as “a base is outside the play area.”
- The opposing player is not granted authority to choose destruction instead of placement.

The repository FAQ confirms that a player must rearrange placements to maximize direct contact and cannot rely on a deliberately inefficient submitted arrangement. It then directs non-touching squadrons into the second ring, but provides no terminal instruction if even that is impossible. [RRG FAQ](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:2396)

Implications for the validator:

- “Cannot touch the ship” means no direct-touch position exists within a legal complete arrangement—not merely no opening remains after the player’s chosen order.
- Placement order cannot establish impossibility; the complete final batch is controlling.
- The maximum direct-touch calculation must include board containment, all ship/squadron exclusions, and feasible second-ring placement for every remainder.
- Authority must not omit or destroy an affected squadron based on the unverified quotation.
- If no complete legal arrangement exists at all, the repository rules reach an unresolved condition. The validator cannot invent an off-board/destruction fallback.

If a squadron somehow does acquire an authoritative out-of-bounds position, destruction is mandatory and authority-executed, not a placement-player choice. That does not resolve the no-placement case.

## 2. Maneuver timing matrix

| Consequence | Trigger/timing | Decision owner | Ordering authority and interactions |
|---|---|---|---|
| **Thruster Fissure** | “When you change your speed by 1 or more.” Navigate changes speed during **Determine Course**. A “when” effect occurs at that moment. [card text](/Users/Katharina/godot/Armada/Resources/Game_Components/damage_cards.json:172), [Navigate timing](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:229), [timing rule](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:356) | Mandatory card effect. Ship owner chooses the hull zone for the suffered damage because none is specified. | Resolves before Move Ship and therefore before every listed overlap consequence. Temporary speed reduction from collision is not a speed-dial change and does not trigger it. [temporary speed rule](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:1229), [Konstantine FAQ](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:2903) |
| **Damaged Controls** | “When you overlap a ship or obstacle”; FAQ fixes resolution **during Move Ship while executing a maneuver**. [card text](/Users/Katharina/godot/Armada/Resources/Game_Components/damage_cards.json:36), [FAQ timing](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:2571) | Mandatory; directly deals a facedown card, so there is no hull-zone choice. Same-timing ordering among multiple owned effects belongs to that player. | Before the executed-maneuver event, Squadron displacement, obstacle effects, and Ruptured Engine. Exact ordering against ordinary ship-overlap reduction/damage, and trigger multiplicity for several overlapped components/attempts, is not expressly resolved. |
| **Ordinary Squadron displacement** | Final ship position overlaps squadrons; move them aside, finish the ship’s maneuver, **then** the non-moving player places them. [RRG](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:858) | Non-moving player controls all placements. | Damaged Controls occurs earlier during Move Ship. Relative order against obstacle effects is not explicit in the RRG and is already settled as displacement first. Relative order against Ruptured Engine remains unstated. |
| **Asteroid field** | A ship overlapping it **after executing a maneuver** is dealt one faceup damage card. [RRG Obstacles](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:730) | No obstacle-level choice. A drawn immediate card may create its own decision. | After Damaged Controls and, by settled interpretation, after displacement. Multiple obstacle effects may occur in any order. Relative order against Ruptured Engine is not expressly determined. |
| **Debris field** | After executing the maneuver, the ship suffers two damage on one hull zone. | Ship owner chooses one hull zone; both damage points apply there, one point at a time. [damage rules](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:275) | Same post-execution relationships as asteroid. |
| **Station** | After executing the maneuver, the ship **can** discard one faceup or facedown damage card. | Optional affected-ship decision: whether to discard and which card. | Same post-execution relationships. The FAQ proves that a ship destroyed by prior ship-overlap damage does not receive the station effect. [movement FAQ](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:2331) |
| **Ruptured Engine** | “After you execute a maneuver,” if the speed dial is greater than one, suffer one damage. [card text](/Users/Katharina/godot/Armada/Resources/Game_Components/damage_cards.json:132) | Mandatory; ship owner chooses the unspecified suffering hull zone. | Clearly after the executed-maneuver event and Damaged Controls. Its relative order against displacement and post-execution obstacle effects is not expressly determined by the repository rules. |

### General timing rules

The RRG establishes:

- “When” occurs at the specified moment; “after” occurs immediately after the event.
- Each non-upgrade card effect is mandatory unless stated otherwise.
- A player may choose the order of two or more of that player’s effects with the same timing.
- When both players have effects at the same timing, the first player resolves all of theirs first. [RRG timing](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:356)

For the listed baseline cards, the effects normally belong to the moving ship’s player. The first-player tie rule therefore does not normally alter these seven consequences. It also does not clearly order a player-owned damage-card effect against a core obstacle or displacement procedure.

Each faceup copy is a separate card effect. Consequently, multiple copies must not be collapsed merely because they share an `effect_id`; their mandatory effects resolve individually, with same-timing order controlled under the general timing rule.

### Destruction during resolution

Rules and accepted project authority establish:

- Damage is resolved one point at a time, and a ship is immediately destroyed at its hull threshold. [RRG Damage](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:275)
- Destroyed units leave play and their cards become inactive. [RRG destruction](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:331)
- Accepted SMI-066 requires survival and applicability to be re-evaluated after each consequence; later ship-dependent consequences are not fabricated after destruction. Independently applicable consequences retain their own authority. [SMI-066](/Users/Katharina/godot/Armada/docs/requirements/gameplay_interactions/ship_maneuver_interaction.md:601)

Thus:

- Thruster Fissure destruction during Determine Course prevents Move Ship and all resulting overlap consequences.
- Destruction before the station effect prevents using the station.
- A later Ruptured Engine or obstacle effect does not execute against a ship already removed from play.
- A consequence independently owed to another unit—such as ordinary collision damage already owed to the other ship—does not automatically disappear merely because the moving ship was destroyed. Its exact interaction with Damaged Controls’ unresolved internal ordering needs normative clarification.

## 3. Current production mismatches

1. **Thruster Fissure is late.** `SetSpeedCommand` mutates canonical speed during tool interaction, but Thruster Fissure observes only the later `execute_maneuver` result. A ship can therefore proceed through Move Ship before its “when you change speed” damage resolves. [SetSpeedCommand](/Users/Katharina/godot/Armada/src/core/commands/set_speed_command.gd:52), [Thruster Fissure hook](/Users/Katharina/godot/Armada/src/core/effects/rules/damage_cards/ship/thruster_fissure.gd:17)

2. **Ruptured Engine and Thruster Fissure use the wrong damage primitive.** Both say “suffer 1 damage,” which must use owner-selected hull-zone shields before dealing a facedown card. Production sends both through `PersistentEffectDamageCommand`, which directly adds a facedown card. Damaged Controls is the only one of the three for which that primitive matches the card text. [damage command](/Users/Katharina/godot/Armada/src/core/commands/persistent_effect_damage_command.gd:87)

3. **All three card timings are collapsed after `ExecuteManeuverCommand`.** Production does not preserve Determine Course, Move Ship, and after-execution timing distinctions. [registered hook inventory](/Users/Katharina/godot/Armada/src/core/effects/rules/README.md:33)

4. **Ship-overlap damage precedes authoritative Maneuver submission in scene code.** It is applied while resolving the local transform, while Damaged Controls is deferred until after `ExecuteManeuverCommand`. This does not establish the required rules ordering or survival boundary. [ShipActivationController](/Users/Katharina/godot/Armada/src/scenes/game_board/ship_activation_controller.gd:1788)

5. **Damaged Controls lacks obstacle evidence.** Its input is one `did_overlap` Boolean currently derived from ship collision/stayed-in-place state, not authoritative per-ship/per-obstacle overlap identities. [current overlap source](/Users/Katharina/godot/Armada/src/scenes/game_board/ship_activation_controller.gd:1790)

6. **Duplicate cards are collapsed.** Each script tests only whether at least one matching faceup card exists and emits one damage command. [Damaged Controls](/Users/Katharina/godot/Armada/src/core/effects/rules/damage_cards/ship/damaged_controls.gd:61), [Ruptured Engine](/Users/Katharina/godot/Armada/src/core/effects/rules/damage_cards/ship/ruptured_engine.gd:60), [Thruster Fissure](/Users/Katharina/godot/Armada/src/core/effects/rules/damage_cards/ship/thruster_fissure.gd:61)

7. **Production ordering is internally inconsistent.** Bootstrap registration lists Damaged Controls before Ruptured Engine and Thruster Fissure, while preview resolution lists Ruptured Engine before Damaged Controls and appends Thruster Fissure later. Neither sequence is rules authority. [RuleBootstrap](/Users/Katharina/godot/Armada/src/autoload/rule_bootstrap.gd:9), [ManeuverRuleResolver](/Users/Katharina/godot/Armada/src/core/movement/maneuver_rule_resolver.gd:55)

8. **Obstacle effects remain absent**, so asteroid, debris, station, multiple-obstacle ordering, decisions, and post-effect survival re-evaluation have no production implementation.

9. **Displacement validation remains incomplete**: no full-batch geometry validation, global maximum proof, second ring, or unplaceable-state handling. [CommitDisplacementCommand](/Users/Katharina/godot/Armada/src/core/commands/commit_displacement_command.gd:37)

## 4. Rules-determined conclusions requiring no Owner decision

- The repository does not establish an “unplaceable displaced squadron is destroyed” rule.
- Actual out-of-bounds placement destroys a squadron, but displacement expressly prohibits that placement.
- Maximum direct touching must be assessed globally rather than against a deliberately inefficient submitted order.
- Every non-direct squadron must touch a direct-touch squadron.
- Thruster Fissure resolves when the Navigate speed change occurs during Determine Course, not after movement.
- Collision-based temporary speed reduction does not trigger Thruster Fissure.
- Damaged Controls resolves during Move Ship, before post-execution obstacle effects.
- Asteroid, debris, station, and Ruptured Engine occur after the executed-maneuver event.
- “Suffer damage” uses hull-zone shields and owner choice; “deal a faceup/facedown card” bypasses that damage process.
- Every faceup copy supplies its own mandatory effect.
- Multiple core obstacle effects may resolve in any order.
- Same-player same-timing card effects are ordered by that player; different-player same-timing effects use first-player precedence.
- Destruction requires immediate survival/applicability re-evaluation.

## 5. Already-settled Owner interpretations

- Complete-batch authoritative displacement validation and maximum-touch proof.
- Assistance/guidance after invalid placement; no retry counter or random fallback.
- Player-controlled placement with transient tentative state.
- Equal fixed squadron bases and simplified rectangular ship geometry.
- Displacement before obstacle effects where the RRG does not decide.
- Moving ship controller chooses multiple-obstacle order where no other rule assigns the choice.
- Accurate canonical obstacle contours derived once from official assets.
- Purpose-specific continuation allocation with no generic continuation mechanism.
- Accepted SMI-066’s survival/re-evaluation model prevents later ship-dependent work from being fabricated after destruction.

## 6. Remaining genuine Owner questions

1. **No complete legal displacement arrangement:** because the quoted destruction fallback is not verified, what project rule applies when even global direct/second-ring search finds no legal complete placement?

2. **Damaged Controls trigger multiplicity:** does one card resolve once for the entire Maneuver, once for each distinct overlapped ship/obstacle, or once for each separate collision attempt during reduced-speed resolution? Repository text fixes the phase but not the event granularity.

3. **Damaged Controls versus ordinary ship-overlap procedure:** within Move Ship, does Damaged Controls resolve immediately when the collision is established, before reduction/reposition and ordinary collision damage, or after some/all of that core procedure? The result matters if damage destroys the moving ship.

4. **Post-execution cross-category order:** what orders:

   - Squadron displacement versus Ruptured Engine; and
   - Ruptured Engine versus asteroid/debris/station effects?

   All occupy the finish/after-execution boundary, but the RRG only supplies explicit ordering within multiple obstacle effects and within same-player same-timing effects. It does not clearly classify core displacement/obstacle procedures as that player’s effects.

These are the only remaining rules questions found in the requested scope.

## 7. Recommended minimum normative work before BUG-043 revision

Without drafting it yet, eventual normative refinement must establish:

- **Displacement:** preserve full-batch/global-maximum/second-ring rules; explicitly record that repository authority supplies no unplaceable-destruction fallback; incorporate the Owner’s answer for the genuinely impossible case.
- **Asteroid slice:** authoritative post-execution detection, faceup-card dealing, immediate-card integration, multiple-obstacle ordering, and survival re-evaluation.
- **Debris slice:** post-execution two-point damage on one owner-selected hull zone, point-by-point damage semantics, ordering, and destruction.
- **Station slice:** post-execution optional discard, deciding player, card selection/visibility, ordering, and loss of applicability after destruction.
- **Thruster Fissure package:** exact Determine Course speed-change event, non-temporary change qualification, one effect per faceup copy, hull-zone damage semantics, and pre-Move-Ship destruction.
- **Damaged Controls package:** Move Ship timing, ship-and-obstacle coverage, one effect per faceup copy, and the Owner-approved trigger granularity/internal collision ordering.
- **Ruptured Engine package:** after-execution timing, speed-**dial** condition, one effect per faceup copy, hull-zone damage semantics, and the Owner-approved cross-category order.
- **Shared Maneuver ordering requirements:** encode the resulting chronological boundary and survival checks through existing purpose-specific owners, without introducing a generic effect owner, manager, stack, queue, or FSM.
