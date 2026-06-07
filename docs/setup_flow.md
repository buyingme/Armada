# Setup Flow Contract

> Status: Accepted by user
> Owner: Alex
> Last updated: 2026-06-04
> Scope: setup-phase user experience from New Game / network lobby through the
> start of the first Command Phase.

This document is the mandatory contract for setup-phase UI work. No setup UI
implementation may start unless the affected flow section below is complete,
unambiguous, and explicitly approved by the owner. If a prompt asks for setup UI
changes without updating this contract first, stop and ask for the missing
contract details before editing UI code.

## 1. Contract Validity Gate

A setup UI section is valid only when all items are answered:

| Field | Requirement |
|---|---|
| Status | `Accepted` for the exact step being implemented. `Draft` means design discussion only. |
| Trigger | How the player reaches the screen in hot-seat and network. |
| Controller | Which player may act, including lower-points, first player, second player, active placer, or host-only ownership. |
| Visibility | What the non-controller sees in hot-seat and network. |
| Required Information | Exact labels/data shown: player names, factions, fleet names, points, objective names, obstacle list, deployment list, prompts, disabled states. |
| Actions | Buttons, list selections, drag/rotate interactions, confirmation actions, cancel/back behavior, and invalid-action feedback. |
| State Contract | Serialized fields or command payloads that persist the choice. Use JSON-safe data only. |
| Validation | Legal/illegal conditions, where validation runs, and what message is shown. |
| Transition | Exact next step after success, including both-player confirmations where required. |
| Tests | Unit/integration/manual tests required before completion. |

If any field is missing or ambiguous, implementation must not proceed.

## 2. Global Setup Principles

- The lobby is not a setup decision screen. It selects match type and fleets
  only. Initiative, objectives, obstacles, and deployment happen after the game
  starts the setup flow.
- Hot-seat and network follow the same logical sequence. Hot-seat may rotate
  the view between players; network must use projected waiting/active states and
  must not rotate the passive player's view.
- Every durable setup choice must be serializable and replay-safe. Positions use
  normalized `pos_x`, `pos_y`, and `rotation_deg` values.
- Preview interactions are transient. A fleet, first-player choice, objective,
  obstacle, ship, squadron, speed, or rotation becomes durable only through the
  contracted serialized state or command-backed mutation.
- The passive player must be able to see public setup choices after they are
  committed, including obstacle and deployment placements.
- Visible UI labels must use player display names, not `Player 1` or
  `Player 2`. Hot-seat collects both player names during fleet selection;
  network setup uses the names already established in the lobby.
- UI layout, screen text, and interaction style are part of this contract. A
  technically correct state transition is not enough if the screen contract is
  unclear or unapproved.

## 3. Ordered Flow

| Step | Status | Summary |
|---|---|---|
| Match Type Selection | Accepted | Local New Game or network host chooses Standard 400, Intermediate 300, Core Set 180, Learning Scenario, or Debug Scenario. |
| Fleet Selection | Accepted | For 400/300/180 setup matches, each player selects one fleet from the fleet manager and each player has a display name. Factions must differ. |
| Initiative | Accepted | After fleet selection and game start, the lower-points player chooses first player. If fleet points are tied, a random tie-break chooser is selected and that player chooses first player. Both players confirm the screen. |
| Objective Choice | Accepted | After initiative confirmations, first player chooses one of the second player's three objectives. The chosen objective is locked, visually highlighted, and acknowledged before obstacle placement. |
| Obstacle Placement | Accepted | Starting with the second player, players alternate placing one obstacle until six are placed. |
| Deployment | Accepted | Players alternate deployment picks with legal deployment-zone, distance, speed, batch, and rotation constraints. |
| Setup Review | Accepted | After deployment, both players may inspect the finished setup state before round one begins. |
| Command Phase Start | Accepted | After setup review completion, setup ends and round one Command Phase starts. |

## 4. Match Type Selection

| Field | Contract |
|---|---|
| Trigger | Local: Main Menu -> New Game. Network: host-only lobby New Game control. |
| Controller | Local hot-seat user, or network host. Client cannot change match type. |
| Visibility | Network client sees the selected match type as a compact read-only lobby status row. |
| Required Information | Five options: Standard 400, Intermediate 300, Core Set 180, Learning Scenario, Debug Scenario. |
| Actions | Select one option. Learning Scenario and Debug Scenario start fixed deployed scenarios. Standard/Intermediate/Core Set enter fleet selection. Changing match type clears any previous fleet selections.  |
| State Contract | `LobbyState.scenario` for network lobby choices; local handoff through `GameManager.set_next_setup_match_type()` or fixed scenario id. |
| Validation | Host-only changes in network; invalid ids normalize to the learning scenario fallback; changing match type clears fleet-selection state before the next step is entered. |
| Transition | Fixed scenario -> board. Setup match -> fleet selection. |
| Tests | New Game option list, lobby host-only selection, compact client read-only status row, fixed scenario path, setup-match path, fleet-reset on match-type change. |

## 5. Fleet Selection

| Field | Contract |
|---|---|
| Trigger | Setup match selected locally, or setup match selected in network lobby. |
| Controller | Hot-seat user enters both player display names and selects both fleets locally. Network host/client each submit their own fleet; network display names come from the lobby. |
| Visibility | Both network players see selected fleet summaries after submission; only local fleet library ids remain local before embedded roster submission. |
| Required Information | Match type, point limit, both player display names, hot-seat name entry fields, local selectable fleet list, submitted local fleet summary, submitted opponent fleet summary, validation status. |
| Actions | Choose a saved fleet matching the selected point format; in hot-seat, enter both player display names before continuing; in network, Ready remains separate from fleet validity and locks the current fleet selection. |
| State Contract | Serialized `FleetSetupPackage` draft with embedded `players[].display_name`, `players[].roster`, player indices, point format, map, and setup-state validation. |
| Validation | Both player names are present, player names must differ, both rosters are present and valid, both rosters match the selected point format, objectives/maps are legal, and factions differ. Blank-name validation message: `Player names must not be blank`. Duplicate-name validation message: `Player names must be different`. Same-faction validation message: `Invalid fleet selection. Fleets must have different factions.` |
| Transition | Network lobby Start becomes available only when both players are Ready and the fleet draft is valid. Start transitions to the initiative screen. |
| Tests | Hot-seat blank-name rejection, duplicate-name rejection, valid fleet-ready gate, invalid same-faction rejection, point-format filtering, roster embedding, Ready-lock behavior, and lobby contains no initiative/objective controls. |

## 6. Initiative

| Field | Contract |
|---|---|
| Trigger | Setup match starts after valid fleet selection. |
| Controller | Lower-points player chooses first player. If points are tied, a random tie-break chooser is selected and that chooser chooses first player. |
| Visibility | Both players see display names, factions, fleet names, fleet point values, resolved first player, and whether the choice came from the lower-point rule or a random tie-break chooser. UI labels use player names only. |
| Required Information | Both player display names, factions, fleet names, fleet points, chooser/tie-break explanation, first-player result, segmented first-player choice control, and per-player confirmation state. |
| Actions | The eligible chooser selects one player name in a segmented control, then both players press `confirm choice` after reviewing the initiative result. |
| State Contract | Setup-state fields: `resolved_first_player`, `initiative_chooser`, `initiative_tied`, `initiative_tie_break_chooser`, `initiative_confirmations`, and `player_points`. |
| Validation | Only the lower-points player may choose when points differ; only the random tie-break chooser may choose when points are tied; confirmations only count for valid player indices. |
| Transition | After both confirmations, objective choice appears. |
| Tests | Lower-points chooser, tied random chooser, wrong-player rejection, both-confirm gate, hot-seat handoff projection, network projection, and name-only labels. |

## 7. Objective Choice

| Field | Contract |
|---|---|
| Trigger | Both players confirmed initiative. |
| Controller | First player chooses one objective from the second player's objectives. |
| Visibility | Both players see the three objective cards side by side; only the controller can lock a choice. The current selection is clearly highlighted before confirmation. After lock, the chosen objective remains highlighted, unchosen objectives are greyed out, and both players see acknowledgement state. |
| Required Information | First player name/faction, second player name/faction, objective owner, objective category/name/card preview, selected objective highlight, locked objective state, and per-player confirmation state. |
| Actions | First player selects and confirms one objective. The first player's lock counts as that player's acknowledgement. The other player explicitly acknowledges the locked choice. There is no Back action to initiative from this screen. |
| State Contract | Setup-state fields: `objective_candidates`, `selected_objective_key`, `objective_choice_locked`, `objective_confirmations`, `objective_owner_player`, and `objective_chosen_by_player`; final setup package `selected_objective`. |
| Validation | Objective key must be one of the second player's three objectives; wrong-player selection is rejected. |
| Transition | After the objective is locked and the second player acknowledges it, obstacle placement begins. |
| Tests | Candidate list from second-player roster, wrong-player rejection, selected-objective highlight, locked objective greying, acknowledgement gate, and package hash stability. |

## 8. Obstacle Placement

| Field | Contract |
|---|---|
| Trigger | Objective choice complete. |
| Controller | Second player places first; players alternate one obstacle at a time until six obstacles are placed. |
| Visibility | Both players see placed obstacles and remaining obstacles. Hot-seat rotates between placements; network uses active/waiting projection. Passive network peers see committed obstacle placements only, not live drag previews. |
| Required Information | Active placer banner using the active player's display name, remaining obstacle list in a lower-middle modal, selected obstacle preview, legal setup area, deployment-zone exclusion, distance feedback, illegal-preview highlighting matching existing overlap-style feedback, and rotation affordance using the debug-equivalent rotation input. |
| Actions | Select one remaining obstacle from the modal, click once on the board to drop the live preview at the cursor, move or rotate the preview using the debug-equivalent rotation input, click the preview again to resume moving it, press an explicit `confirm placement` button in the modal to commit, or cancel the current preview. The board click that drops or reselects the preview must not commit the obstacle. |
| State Contract | Command-backed obstacle payload with `data_key`, normalized `pos_x`, `pos_y`, `rotation_deg`, placing player, and placement order. |
| Validation | One of each obstacle; exactly six total; footprint inside setup area; always outside deployment zones; beyond distance 3 of play-area edges for 3x6 setup area; beyond distance 1 of other obstacles; confirm is rejected without a selected obstacle. Live preview movement may highlight invalid states, but illegal positions must also be blocked or rejected before commit. |
| Transition | After six legal placements, deployment starts with the correct player/order. |
| Tests | Placement order, duplicate rejection, geometry legality, deployment-zone exclusion on 3x3 and 3x6, live preview drop/reselect flow, explicit confirm button commit, illegal-preview highlight, rotation persistence, lower-middle modal presentation, and hot-seat/network visibility. |

## 9. Deployment

| Field | Contract |
|---|---|
| Trigger | Six obstacles placed. |
| Controller | Players alternate deployment picks according to setup rules. Active player sees only deployable units from their own roster. |
| Visibility | Both players see committed deployments. Passive network players see committed placements only, not live drag previews. |
| Required Information | Active deployment banner using the active player's display name, deployable ship/squadron list, deployment zones, selected unit preview, speed selector for ships with explicit speed buttons, placement legality feedback matching existing overlap-style feedback, and rotation controls. |
| Actions | Select one ship or an eligible squadron pick from the active player's list, drag to legal position, rotate through the debug-equivalent input path, choose ship speed through explicit speed buttons, confirm deployment, or cancel the current preview. |
| State Contract | Command-backed deployment payload with player index, unit type, roster entry id, normalized position, rotation, and ship speed where applicable. |
| Validation | The first deployment pick must be a ship. Players alternate after each deployment pick. A legal pick may be one ship or two squadrons when setup rules allow it. Ships must be inside the owning deployment zone with legal speed. Squadrons must be within distance 1-2 of a friendly ship and inside the play area. One remaining squadron cannot be deployed before all ships if the player would otherwise deploy two squadrons; if one player has no legal placement options left, the other player places the remaining assets. |
| Transition | Once all ships and squadrons are deployed, setup review appears. |
| Tests | First-pick ship requirement, ship zone legality, speed legality, squadron distance legality, two-squadron pick handling, single-squadron restriction, alternating order, exhausted-player continuation, rotation persistence, and network mirrors. |

## 10. Setup Review

| Field | Contract |
|---|---|
| Trigger | All ships and squadrons are legally deployed. |
| Controller | Both players may inspect the finished setup state before the first Command Phase. |
| Visibility | Both players see the full deployed board state, selected objective, and both fleets/cards before round one begins. |
| Required Information | Setup-complete status, first player for round one, both fleet names, both player display names, visible fleet/card information, and a `ready to start` control. |
| Actions | Review the setup state and press `ready to start`. |
| State Contract | Setup-review readiness state must be serialized in JSON-safe form before the Command Phase transition. |
| Validation | Setup review cannot begin until deployment is complete. Both players must press `ready to start` before the first Command Phase begins. |
| Transition | Once both players have pressed `ready to start`, round one Command Phase starts. |
| Tests | Review-step projection, setup-complete gating, both-player ready gate, ready-control visibility, and transition into round one. |

## 11. Acceptance Notes

- No unresolved setup-behavior questions remain in this contract revision.
- Manual-test screenshots or sketches are not required for contract validity.
  Written manual test steps and expected results are sufficient when a section
  is marked `Accepted`.
