# Attack Sequence — Requirements

> **Scope:** Ship attack pipeline (Steps 1–6), attack UI modal,
> dice rolling/display, Concentrate Fire command integration,
> defense token spending, damage resolution, hull zone selection,
> and the two-attack-per-activation constraint.
>
> This document covers ship-to-ship and ship-to-squadron attacks
> during the Attack sub-step of a Ship Activation.

---

## 0. Rules Compliance Audit

This section compares the user-provided UI requirements
(`temp_attack_sequence.txt`) against the official Rules Reference Guide (RRG)
attack sequence (pp. 2–3) to identify **gaps**, **ambiguities**, and
**discrepancies** that must be resolved before implementation.

### 0.1 Summary of Official Attack Steps (RRG pp. 2–3)

| Step | Name | Key Rules |
|------|------|-----------|
| 1 | Declare Target | Attacker declares defending hull zone or squadron; measure LOS; determine obstruction |
| 2 | Roll Attack Dice | Gather dice by range; if obstructed, remove 1 die before rolling; if 0 dice, cancel attack |
| 3 | Resolve Attack Effects | Attacker modifies dice (card effects, Concentrate Fire command); attacker spends accuracy icons to lock defender's defense tokens |
| 4 | Spend Defense Tokens | Defender spends defense tokens (Evade, Brace, Redirect, Scatter, Contain, Salvo) |
| 5 | Resolve Damage | Resolve one critical effect; total damage = hits + crits (ship) or hits only (squadron); damage applied to shields then hull, one point at a time |
| 6 | Declare Additional Squadron Target | If defender was a squadron, attacker may declare another squadron from the same hull zone and repeat Steps 2–6 |

### 0.2 Gaps in User Requirements

These rules-mandated features are **missing or underspecified** in the user
requirements and must be added:

| # | Gap | RRG Reference | Severity |
|---|-----|---------------|----------|
| G-1 | **Obstruction handling** — When attack is obstructed, attacker must choose and remove 1 die from pool *before* rolling. User requirements mention LOS line but not obstruction removal. | "Obstructed", p. 13 | High |
| G-2 | **Accuracy spending (Step 3)** — Attacker may spend accuracy icons to lock defender's defense tokens. Not mentioned in user requirements. | "Attack", Step 3; "Dice Icons" | High |
| G-3 | **Defense token spending (Step 4)** — Defender may spend defense tokens (Evade, Brace, Redirect, Scatter, Contain, Salvo). Not mentioned. This is a full sub-flow with its own UI. | "Attack", Step 4; "Defense Tokens" | Critical |
| G-4 | **Damage resolution (Step 5)** — Critical effects, damage totalling, shield absorption, damage cards. User says "confirm lets the player execute the next attack" — skips the entire damage step. | "Attack", Step 5; "Damage"; "Critical Effects" | Critical |
| G-5 | **Evade token** mechanics depend on attack range (cancel at long, reroll at medium/close). Attack range must be tracked and displayed. | "Defense Tokens" — Evade | Medium |
| G-6 | **Scatter** cancels all dice. **Brace** halves total damage rounded up. These modify the outcome before damage is applied. | "Defense Tokens" — Scatter, Brace | Medium |
| G-7 | **Redirect** lets defender shift damage to an adjacent hull zone. Requires UI for defender to pick adjacent zone. | "Defense Tokens" — Redirect | Medium |
| G-8 | **Speed-0 restriction** — Defender at speed 0 cannot spend defense tokens. | "Defense Tokens", bullet 7 | Low |
| G-9 | **Standard critical effect** — "If defender is dealt at least 1 damage card, deal the first faceup." Must be resolved at start of Step 5. Contain token prevents this. | "Attack", Step 5; "Critical Effects"; "Defense Tokens" — Contain | Medium |
| G-10 | **Anti-squadron armament** — When attacking squadrons, use anti-squadron armament (not battery). User spec doesn't distinguish. | "Attack", Step 2 | Medium |
| G-11 | **Squadrons cannot suffer critical effects** unless otherwise specified. Damage vs squadrons = sum of hit icons only (no crits counted). | "Attack", Step 5; "Critical Effects" | Medium |
| G-12 | **Destroyed ships/squadrons** — Immediate removal when hull threshold reached. May happen mid-attack sequence. | "Destroyed Ships and Squadrons" | Medium |

### 0.3 Ambiguities in User Requirements

| # | Ambiguity | Proposed Resolution |
|---|-----------|-------------------|
| A-1 | "command dial active — spend dial to add dice" — Concentrate Fire dial adds **1 die of a colour already in the pool**, not any die. Does the player choose the colour? | Yes. Show only colours that exist in the current pool as options. RRG "Concentrate Fire" — Dial. |
| A-2 | "reroll option through extra rule or command token" — This is the Concentrate Fire **token** (reroll 1 die). When does this resolve? | During Step 3 (Resolve Attack Effects), per RRG. Player picks which die to reroll. |
| A-3 | "confirm button lets the player execute the next attack" — What exactly does "confirm" do? | It should trigger **Steps 3–5 resolution** (attack effects → defense tokens → damage), not skip them. The original intent seems to be advancing past the dice-rolling screen. We need sub-states within the attack. |
| A-4 | "highlight range overlay of attacking ship" — Does this mean always-on during the entire attack, or just during target selection? | Propose: show range overlay during target selection (Step 1), hide after target is locked. |
| A-5 | "info modal below the attacking ship" — Where exactly? Ships may be near board edges. | Propose: floating panel anchored near the attacking ship, with screen-edge clamping to keep it visible. Falls back to screen-centred if no room. |
| A-6 | "for each squadron being attacked from the attacking hull zone (the attacking hull zone is pre-selected)" — Does step 6 automatically queue all in-arc squadrons or does the player pick one at a time? | RRG says player **declares** the next squadron target (Step 6). So: after resolving damage on the first squadron, prompt "Select next squadron target" with the hull zone locked. Player may also decline (skip remaining targets). |
| A-7 | "second hull zone to attack with" — The user implies exactly **two** hull zones. What if a ship has only 1 valid hull zone, or the player wants to attack 0 or 1 times? | RRG: "A ship can perform **up to** two attacks." Propose: After the first attack, offer "Select second attacking hull zone" or "Skip second attack". If no valid targets from any remaining hull zone, auto-skip. |
| A-8 | Where does the Concentrate Fire **dial vs token** decision happen? User says "spend dial" for extra die but also mentions the token for reroll as a separate step. | RRG: "A ship must decide whether it is spending the dial, the token, or both before resolving that command's effects." Propose: Before Step 3 resolution, show a single prompt: "Spend Concentrate Fire Dial (add die) / Token (reroll) / Both / Neither". |
| A-9 | "yellow line that represents the line of sight check" — How long is this line shown? | Propose: Show the LOS line during the entire attack (Steps 1–5). Dismiss with the attack info panel. |
| A-10 | What happens when an attack is **cancelled** (0 dice after obstruction removal or no dice at range)? | RRG: "the attack is canceled." Propose: show a brief notification "Attack cancelled — no dice at range" and return to hull zone selection (or skip to next phase if second attack). |

### 0.4 Discrepancies

| # | User Requirement | Correct Rule | Fix |
|---|-----------------|-------------|-----|
| D-1 | "press button to roll dice, then optionally reroll" | Concentrate Fire dial (add die) happens **before** roll. Token (reroll) happens **after** roll but during Step 3. Ordering matters. | Restructure into: pre-roll (dial prompt) → roll → post-roll (token reroll + accuracy spend + defense tokens). |
| D-2 | User says "add a dice" if command dial is active | Only **Concentrate Fire** command dial adds a die — not any command dial. Must check revealed dial type. | Gate the UI option behind `revealed_command == CONCENTRATE_FIRE`. |
| D-3 | Implied single "confirm" closes the attack | 3 distinct interactive sub-steps remain after roll (Steps 3, 4, 5). | Implement proper Step 3/4/5 sub-flows with UI for each. |

---

## 1. Overview

The **attack sequence** resolves when a ship performs the Attack sub-step of
its activation (between Repair and Execute Maneuver). The ship may perform
**up to two attacks** from **different hull zones**, following the 6-step
procedure for each.

The UI workflow:
1. Player presses "Execute Attack ►" in the activation modal.
2. Activation modal closes; the board enters **attack mode**.
3. Player selects attacking hull zone → target → reviews dice pool →
   resolves attack effects → defender spends tokens → damage is resolved.
4. Repeat for the optional second attack.
5. Attack mode ends; activation modal re-opens with Attack step marked done.

---

## 2. Glossary

| Term | Definition | Source |
|------|-----------|--------|
| Battery armament | Dice printed on the ship card per hull zone, used when attacking ships. | RRG "Attack", Step 2 |
| Anti-squadron armament | Dice printed on the ship card (single pool), used when attacking squadrons. | RRG "Attack", Step 2 |
| Attack pool | All dice currently part of this attack — gathered + added + after modifications. | RRG "Attack Pool" |
| Concentrate Fire (P) | Command that adds 1 die (dial) or rerolls 1 die (token) during Step 3. | RRG "Commands" — P |
| Obstruction | LOS passes through an obstacle or non-participant ship → remove 1 die before rolling. | RRG "Obstructed" |
| Standard critical effect | "If defender is dealt ≥1 damage card by this attack, deal the first faceup." | RRG "Critical Effects" |
| Salvo | Counter-attack triggered by spending the Salvo (e) defense token. Out of scope for this phase — stub only. | RRG "Defense Tokens" — Salvo |

---

## 3. Attack Flow — Core Logic

### ATK-FLOW-001 — Attack entry point

When the activation modal's Attack step becomes active, the player may press
**"Execute Attack ►"**. This closes the modal and enters attack mode.

- If the ship has **no valid targets** from any hull zone, auto-skip the
  Attack step with a brief notification: *"No valid targets — skipping attack."*
- Rules Reference: RRG "Ship Activation" — "Attack: Perform up to two attacks."

### ATK-FLOW-002 — Two-attack-per-activation constraint

A ship may perform **up to two** attacks during its activation, from
**different** hull zones. Track which hull zones have been used.

- After the first attack concludes, offer hull zone selection for the second
  attack. The previously-used hull zone is blocked.
- If no remaining hull zone has valid targets, auto-skip the second attack.
- Rules Reference: RRG "Attack" — "A ship can perform two attacks during its
  activation, but it cannot attack from the same hull zone more than once."

### ATK-FLOW-003 — Attack cancellation

An attack is **cancelled** (aborted with no effect) when:
- The attacker gathers 0 dice appropriate for the attack range (Step 2).
- Rules Reference: RRG "Attack", Step 2.

When cancelled, show a notification and advance to the next attack or end
attack mode.

---

## 4. Step 1 — Declare Target

### ATK-S1-001 — Select attacking hull zone

The player left-clicks a hull zone on their own ship to select it as the
attacking hull zone.

- Show a **yellow translucent circle (6 px diameter)** on the hull zone's
  LOS marker to indicate selection.
- Show the **range overlay** for the attacking ship while in hull zone
  selection mode.
- A previously-used hull zone (from attack #1) is blocked: show a **red
  translucent circle (6 px diameter)** on its LOS marker and reject clicks.
- Rules Reference: RRG "Attack", Step 1.

### ATK-S1-002 — Select target

After the attacking hull zone is selected, the player left-clicks an enemy
hull zone (ship target) or an enemy squadron (squadron target).

- The target **must be** inside the attacking hull zone's firing arc and at
  attack range.
- For ship targets: show a yellow circle on the defending hull zone's LOS
  marker.
- For squadron targets: show a yellow circle on the squadron token.
- The system draws a **yellow LOS line** between the attacking hull zone's
  targeting point and the defending hull zone's targeting point (or closest
  point on the squadron base).
- Display LOS check result: **clear** or **obstructed** (and by what).
- Rules Reference: RRG "Attack", Step 1; "Line of Sight".

### ATK-S1-003 — Target deselection

- **Click on the target again** → deselects the target; attacking hull zone
  remains selected. Player may pick a new target.
- **Click on the attacking hull zone again** → deselects both the hull zone
  and any target. Player returns to hull zone selection.
- Rules Reference: N/A (UI convenience).

### ATK-S1-004 — Dice pool preview

Once both attacker and defender are selected, the **attack info panel** shows:
- The dice pool that will be gathered (colours and count), based on:
  - Battery armament (ship target) or anti-squadron armament (squadron target).
  - Filtered by attack range (only colours valid at this range).
  - Obstruction: note if 1 die will be removed.
- This is a preview — the actual pool is locked in Step 2.
- Rules Reference: RRG "Attack", Step 2; "Attack Range"; "Obstructed".

### ATK-S1-005 — Valid target filtering

Only targets that satisfy all of the following are eligible:
1. Inside the attacking hull zone's firing arc.
2. At attack range of the attacking hull zone.
3. LOS is not completely blocked (LOS must exist, even if obstructed).
4. Not a friendly ship or squadron.
5. The attacker can gather ≥ 1 die at the measured range (after obstruction
   removal the pool may become 0 — this cancels in Step 2, not here).

- Rules Reference: RRG "Attack", Step 1; "Attack Range"; "Line of Sight".

---

## 5. Step 2 — Roll Attack Dice

### ATK-S2-001 — Gather dice pool

Gather attack dice based on the armament and range:
- **Ship target:** Use the attacking hull zone's battery armament.
- **Squadron target:** Use the ship's anti-squadron armament.
- Filter by range: black dice only at close; blue at close+medium;
  red at close+medium+long.
- Rules Reference: RRG "Attack", Step 2; "Attack Range".

### ATK-S2-002 — Obstruction removal

If the attack is **obstructed**, the attacker **must** choose and remove 1 die
from the gathered pool before rolling.

- If only 1 die colour is present and only 1 die, auto-remove and notify.
- If multiple dice, show a prompt: *"Attack is obstructed — choose 1 die to remove."*
  Display each die in the pool; player clicks one to remove it.
- If removing the die leaves 0 dice, the attack is cancelled (ATK-FLOW-003).
- Rules Reference: RRG "Obstructed".

### ATK-S2-003 — Concentrate Fire dial — add die (pre-roll)

If the attacking ship's revealed command dial is **Concentrate Fire (P)** and
the command has not been resolved this activation:

- Prompt: *"Spend Concentrate Fire dial to add 1 die?"*
- Show buttons for each die colour **already in the current pool**.
- Player may click a colour to add that die, or "Skip" to decline.
- If spent, mark the P command as resolved for this activation.
- Rules Reference: RRG "Commands" — P Dial; "Modifying Dice" — Add.

### ATK-S2-004 — Roll dice

After optional dial spend and obstruction removal:
- Display a **"Roll Dice"** button in the attack info panel.
- On press: roll the pool using `Dice.roll_pool()`.
- Display the rolled results as **die face graphics** (PNGs from
  `Resources/Game_Components/dice/`), grouped by colour.
- Rules Reference: RRG "Attack", Step 2.

---

## 6. Step 3 — Resolve Attack Effects

### ATK-S3-001 — Concentrate Fire token — reroll (post-roll)

If the ship has a **Concentrate Fire command token** (and it has not been
resolved this activation):

- Show a **"Reroll Die"** button.
- Player clicks a die in the pool to select it, then confirms the reroll.
- The selected die is rerolled (pick up and roll again).
- The token is spent (removed from the ship's command token manager).
- Player may have already spent the dial (ATK-S2-003). Both can be spent
  together in the same attack per RRG.
- Rules Reference: RRG "Commands" — P Token; "Modifying Dice" — Reroll.

### ATK-S3-002 — Spend accuracy icons

After dice modification, the attacker may spend one or more **accuracy (G)**
icons to lock the defender's defense tokens:

- For each accuracy die face in the pool: show the defender's available
  (non-discarded) defense tokens.
- Player clicks a defense token to lock it — that token **cannot be spent**
  during this attack.
- Player clicks the accuracy die to "spend" it (it is removed from the pool).
- Multiple accuracies can lock multiple different tokens.
- Rules Reference: RRG "Attack", Step 3; "Dice Icons" — Accuracy.

### ATK-S3-003 — Advance to Step 4

Once the attacker is done modifying dice, show a **"Done — Defender's Turn"**
button. Pressing it advances to Step 4 (defender's defense token spending).

---

## 7. Step 4 — Spend Defense Tokens

### ATK-S4-001 — Defender token spending

The **defender** (opponent) may now spend defense tokens. Each token can be
spent at most once per attack; at most one of each type per attack.

- Display the defender's available defense tokens (excluding locked and
  discarded ones).
- For each token, show current state (ready / exhausted).
- Ready tokens are flipped to exhausted when spent.
- Exhausted tokens are discarded when spent.
- Rules Reference: RRG "Defense Tokens"; "Attack", Step 4.

### ATK-S4-002 — Evade (D)

- **Long range:** Cancel 1 attack die of defender's choice.
- **Medium/close range:** Reroll 1 attack die of defender's choice.
- **Extreme range (beyond):** Cancel 1 die + cancel 1 additional die.
- UI: Defender clicks a die in the pool to cancel or reroll it.
- Rules Reference: RRG "Defense Tokens" — Evade.

### ATK-S4-003 — Brace (C)

- When damage is totalled in Step 5, total is **halved, rounded up**.
- This is a deferred effect — mark "brace active" and apply during Step 5.
- Rules Reference: RRG "Defense Tokens" — Brace.

### ATK-S4-004 — Scatter (A)

- **Cancel all** attack dice. The attack effectively deals 0 damage.
- Immediately clear the pool and skip to Step 5 (which resolves 0 damage).
- Rules Reference: RRG "Defense Tokens" — Scatter.

### ATK-S4-005 — Redirect (B)

- Defender chooses **one hull zone adjacent** to the defending hull zone.
- During damage resolution, defender may assign up to that zone's remaining
  shields in damage to the chosen zone before the rest hits the defending zone.
- UI: Prompt defender to pick an adjacent hull zone for redirect.
- Rules Reference: RRG "Defense Tokens" — Redirect.

### ATK-S4-006 — Contain (&)

- Prevents the attacker from resolving the **standard critical effect**.
- Mark "contain active" — checked during Step 5 critical resolution.
- Rules Reference: RRG "Defense Tokens" — Contain.

### ATK-S4-007 — Salvo (e) — stub

- If defender is a ship, it performs a counter-attack after Step 5.
- **Out of scope for initial implementation.** Show the token but disable
  spending it, with tooltip: *"Salvo — not yet implemented."*
- Rules Reference: RRG "Defense Tokens" — Salvo.

### ATK-S4-008 — Speed-0 restriction

- If the defender's current speed is **0**, it **cannot spend** any defense
  tokens. All tokens are greyed out.
- Rules Reference: RRG "Defense Tokens", bullet 7.

### ATK-S4-009 — Advance to Step 5

Once the defender is done (or declines to spend tokens), show
**"Done — Resolve Damage"**. Pressing it advances to Step 5.

---

## 8. Step 5 — Resolve Damage

### ATK-S5-001 — Critical effect resolution

At the **start** of Step 5, resolve one critical effect if:
- The pool contains at least one critical (E) icon, **and**
- Contain token was **not** spent, **and**
- The defender is a **ship** (squadrons cannot suffer critical effects).

Standard critical: *"If the defender is dealt ≥ 1 damage card by this attack,
deal the first damage card faceup."*

- For the initial implementation, only the standard critical effect is
  supported. Upgrade card critical effects are out of scope.
- Rules Reference: RRG "Critical Effects"; "Attack", Step 5.

### ATK-S5-002 — Damage totalling

Calculate total damage:
- **Ship vs ship:** Sum of all hit (F) and critical (E) icons remaining.
- **Ship vs squadron:** Sum of all hit (F) icons only.
- If **Brace** was spent: halve the total, rounded up.
- Display the final damage number in the attack info panel.
- Rules Reference: RRG "Attack", Step 5; "Dice Icons".

### ATK-S5-003 — Damage application (ship defender)

Apply damage to the defending hull zone, one point at a time:
1. Reduce shields in the defending hull zone by 1.
2. If shields are 0, deal a facedown damage card instead.
3. Repeat for each point of damage.

If **Redirect** was spent:
- Defender may assign up to N points of damage to the chosen adjacent hull
  zone's shields (where N = that zone's current shields) before the rest
  is applied to the defending zone.
- UI: Show redirect split prompt if applicable.

If standard critical applies and ≥ 1 damage card was dealt: the **first**
damage card dealt is dealt **faceup** instead of facedown.

- Rules Reference: RRG "Damage"; "Attack", Step 5.

### ATK-S5-004 — Damage application (squadron defender)

Apply total damage to the squadron's hull points. Reduce hull by the damage
total (not one-at-a-time for squadrons — just reduce the value).

- If hull reaches 0, the squadron is destroyed and removed.
- Rules Reference: RRG "Damage"; "Destroyed Ships and Squadrons".

### ATK-S5-005 — Destruction check

After damage is fully applied:
- If a **ship** has damage cards ≥ hull value → destroyed. Remove from play.
- If a **squadron** has 0 hull points → destroyed. Remove from play.
- Emit `EventBus.ship_destroyed` or `EventBus.squadron_destroyed`.
- Rules Reference: RRG "Destroyed Ships and Squadrons".

### ATK-S5-006 — Damage summary display

Show a summary in the attack info panel:
- Total damage dealt.
- Shields lost per hull zone.
- Damage cards dealt (facedown count, faceup if standard crit triggered).
- Whether the defender was destroyed.

---

## 9. Step 6 — Additional Squadron Target

### ATK-S6-001 — Offer additional target

If the defender was a **squadron**, after Step 5, the attacker may declare
**another** enemy squadron as a new defender:
- Must be inside the same attacking hull zone's firing arc and at attack range.
- Must have LOS.
- Each squadron can only be targeted **once** per attack.
- The attacking hull zone is **locked** (cannot be changed).

Prompt: *"Select next squadron target (or Skip)."*

- Rules Reference: RRG "Attack", Step 6.

### ATK-S6-002 — Repeat Steps 2–6

If a new squadron target is declared, repeat Steps 2–6 with the new defender.
Each repetition is treated as a **new attack** for card effect purposes.

- Rules Reference: RRG "Attack", Step 6.

### ATK-S6-003 — End of attack

When the player declines to pick another squadron target, or no valid
squadron targets remain, this attack is complete.

---

## 10. Attack Info Panel — UI

### ATK-UI-001 — Panel layout

A floating **attack info panel** displayed near the attacking ship
(screen-edge clamped). Contains:
- Header: attacker name, hull zone, "→" defender name (hull zone or squadron).
- Dice pool display: die face graphics, grouped by colour.
- Prompt text: context-sensitive instructions for the current sub-step.
- Action buttons: "Roll Dice", "Reroll", "Skip", "Done", "Confirm".
- Damage summary (after Step 5).

### ATK-UI-002 — Dice display

Show each die in the pool as its **PNG graphic** from
`Resources/Game_Components/dice/`.
- Dice are arranged in a row, grouped by colour (red → blue → black).
- Removed/cancelled dice are visually struck through or faded.
- Spent accuracy dice are removed from display.

### ATK-UI-003 — "Execute Attack" button in activation modal

Add an **"Execute Attack ►"** button to the Attack step row (index 3) in
`ActivationModal`, identical in style to the "Execute Maneuver ►" button.
- Visible only when the current step is ATTACK.
- Pressing it closes the modal and enters attack mode.

### ATK-UI-004 — Attack completion in activation modal

When both attacks are complete (or skipped), re-open the activation modal
with the Attack step marked **done** (✓ checkmark, green tint) — same
pattern as other completed steps.

### ATK-UI-005 — Hull zone highlights

During attack mode:
- **Selected attacking hull zone:** Yellow translucent circle, 6 px diameter,
  on the LOS marker.
- **Used hull zone (already fired):** Red translucent circle, 6 px diameter,
  on the LOS marker.
- **Selected defending hull zone / squadron:** Yellow translucent circle,
  6 px diameter.

### ATK-UI-006 — LOS line

When both attacker and defender are selected, draw a **yellow line** between
the LOS points. Line remains visible until the attack is over or target is
deselected.

### ATK-UI-007 — Range overlay

Show the attacking ship's range overlay during hull zone and target selection
(Steps 1). Hide after target is confirmed and dice are rolled.

---

## 11. Concentrate Fire Integration

### ATK-CF-001 — Dial availability check

Before showing the "add die" prompt (ATK-S2-003), verify:
1. The ship's revealed command dial is `Constants.CommandType.CONCENTRATE_FIRE`.
2. The Concentrate Fire command has not already been resolved this activation
   (`ShipActivationState.is_command_resolved(CONCENTRATE_FIRE)` is false).

### ATK-CF-002 — Token availability check

Before showing the "reroll die" prompt (ATK-S3-001), verify:
1. The ship has a Concentrate Fire command token
   (`command_tokens.has_token(Constants.CommandType.CONCENTRATE_FIRE)`).
2. Optionally: the player may spend both dial and token in the same attack.
   The system must allow this combination.

### ATK-CF-003 — Dial + token combined spend

Per RRG: "A ship must decide whether it is spending the dial, the token, or
both before resolving that command's effects."

- Prompt once: "Spend Concentrate Fire — Dial (add die) / Token (reroll) /
  Both / Skip".
- If "Both": add the die first (before rolling), then allow reroll after
  rolling.
- Mark the command as resolved after the player chooses.

---

## 12. Two-Attack Constraint

### ATK-2A-001 — Hull zone usage tracking

Track which hull zones have been used for attacks during this activation.
Store in `ShipActivationState` (new field: `_used_attack_zones: Array[Constants.HullZone]`).

### ATK-2A-002 — Block reuse

During hull zone selection for the second attack, the previously-used hull
zone is not selectable. Show its LOS marker with a red circle.

### ATK-2A-003 — Auto-skip when no targets

If no remaining (unused) hull zone has any valid target, skip the second
attack automatically. Show notification: *"No valid targets from remaining
hull zones."*

---

## 13. State Machine

The attack sequence is modelled as a state machine within the activation flow:

```
IDLE
  │
  ├─► HULL_ZONE_SELECT ◄──────────────────┐
  │       │                                 │
  │       ▼                                 │
  │   TARGET_SELECT                         │
  │       │                                 │
  │       ▼                                 │
  │   DICE_POOL_PREVIEW                     │
  │       │ (CF dial prompt, obstruction)   │
  │       ▼                                 │
  │   ROLL_DICE                             │
  │       │                                 │
  │       ▼                                 │
  │   ATTACK_EFFECTS (CF token, accuracy)   │
  │       │                                 │
  │       ▼                                 │
  │   DEFENSE_TOKENS (defender spending)    │
  │       │                                 │
  │       ▼                                 │
  │   RESOLVE_DAMAGE                        │
  │       │                                 │
  │       ├─► ADDITIONAL_SQUAD_TARGET ──────┘ (back to TARGET_SELECT
  │       │     (if defender was squadron)      with locked hull zone)
  │       │
  │       ▼
  │   ATTACK_COMPLETE
  │       │
  │       ├─► HULL_ZONE_SELECT (2nd attack)
  │       │
  │       ▼
  │   ALL_ATTACKS_DONE
  │       │
  │       ▼
  │   (re-open activation modal, mark ATTACK done)
```

### ATK-SM-001 — State enum

```gdscript
enum AttackState {
    IDLE,
    HULL_ZONE_SELECT,
    TARGET_SELECT,
    DICE_POOL_PREVIEW,
    ROLL_DICE,
    ATTACK_EFFECTS,
    DEFENSE_TOKENS,
    RESOLVE_DAMAGE,
    ADDITIONAL_SQUAD_TARGET,
    ATTACK_COMPLETE,
    ALL_ATTACKS_DONE,
}
```

---

## 14. EventBus Signals

The following existing signals will be used:
- `attack_declared(attacker, defender)` — emitted at end of Step 1.
- `dice_rolled(attacker, dice_results)` — emitted in Step 2.
- `defense_token_spent(ship, token_type)` — emitted in Step 4.
- `damage_resolved(target, total_damage)` — emitted at end of Step 5.

New signals needed:
- `attack_step_entered()` — emitted when player presses "Execute Attack".
- `attack_completed()` — emitted when one full attack (Steps 1–6) finishes.
- `all_attacks_completed()` — emitted when both attacks are done/skipped.
- `attack_cancelled()` — emitted when an attack is cancelled (0 dice).

---

## 15. Implementation Sub-Phases

The attack sequence is too large for a single phase. Proposed sub-phases:

### Phase 6a — Attack Pipeline Core + Steps 1–2

| Task | Layer | Deliverables |
|------|-------|-------------|
| `AttackSequenceState` state machine | Core | `src/core/attack_sequence_state.gd` |
| Step 1: Target declaration logic | Core | Reuse `TargetingListBuilder` data |
| Step 2: Dice pool gathering (range filter, obstruction) | Core | `src/core/attack_dice_pool.gd` |
| Step 2: Dice rolling | Core | Reuse `Dice.roll_pool()` |
| `ActivationModal` — "Execute Attack" button | Presentation | Modify `activation_modal.gd` |
| Hull zone selection + target selection UI | Presentation | `src/scenes/attack_mode_controller.gd` |
| Attack info panel — Steps 1–2 | Presentation | `src/ui/attack_info_panel.gd` |
| LOS line + hull zone highlights | Presentation | Visual overlays |
| Tests: ~25 | — | State machine, dice pool, filtering, UI wiring |

### Phase 6b — Steps 3–5 (Attack Effects, Defense Tokens, Damage)

| Task | Layer | Deliverables |
|------|-------|-------------|
| Concentrate Fire integration (dial + token) | Core | Extend `attack_sequence_state.gd` |
| Accuracy spending logic | Core | Lock tokens in pool state |
| Defense token resolution (Evade, Brace, Scatter, Redirect, Contain) | Core | `src/core/defense_token_resolver.gd` |
| Damage resolution (shields → hull → damage cards) | Core | `src/core/damage_resolver.gd` |
| Standard critical effect | Core | In damage resolver |
| Defense token spending UI | Presentation | Extend attack info panel |
| Damage summary display | Presentation | Extend attack info panel |
| Tests: ~30 | — | Each defense token, damage paths, critical effects |

### Phase 6c — Step 6 + Two-Attack Flow + Polish

| Task | Layer | Deliverables |
|------|-------|-------------|
| Step 6: Additional squadron target | Core | State machine loop |
| Two-attack tracking and hull zone blocking | Core | Extend `ShipActivationState` |
| Auto-skip when no valid targets | Core | Logic in state machine |
| Re-open activation modal after attacks | Presentation | Wire up signals |
| End-to-end integration testing | — | Full attack sequence tests |
| Tests: ~15 | — | Step 6 loops, two-attack constraint, edge cases |

**Total estimated tests: ~70** (higher than Phase 6 original estimate of ~45
due to defense token combinations and sub-step coverage).

---

## 16. Out of Scope (Deferred)

- Salvo counter-attacks (future — requires recursive `AttackPipeline`).
- Upgrade card effects (card-specific dice modifications, critical effects).
- Squadron-initiated attacks (Phase 7).
- Extreme range Evade bonus (no current way to reach extreme range in
  Learning Scenario — stub the rule, implement when range is extended).
- Evade bonus for defending against a larger ship (discard to cancel/reroll
  additional die) — implement when multiple ship size classes are in play.
- Damage deck UI (faceup card display, effects) — Phase 9.

---

## 17. Rules References

| Rule | Page | Sections |
|------|------|----------|
| Attack (6 steps) | pp. 2–3 | ATK-FLOW, ATK-S1–S6 |
| Attack Pool | p. 3 | ATK-S2 |
| Attack Range | p. 3 | ATK-S1, ATK-S2 |
| Commands — Concentrate Fire | p. 3 | ATK-CF |
| Critical Effects | p. 4 | ATK-S5 |
| Damage | p. 5 | ATK-S5 |
| Defense Tokens | pp. 4–5 | ATK-S4 |
| Destroyed Ships and Squadrons | p. 5 | ATK-S5 |
| Dice Icons | p. 5 | ATK-S3, ATK-S5 |
| Modifying Dice | p. 11 | ATK-S3 |
| Obstructed | p. 13 | ATK-S2 |
| Ship Activation | p. 16 | ATK-FLOW |
