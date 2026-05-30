## Scoring Calculator
##
## Pure-logic helper that computes fleet-point scores and determines the winner
## at game end.  Operates exclusively on [GameState] / [PlayerState] data —
## no scene-tree dependency.
##
## Rules Reference: "Scoring", RRG p.15; "Winning and Losing", RRG p.21;
## WN-001–004, GO-004.
class_name ScoringCalculator
extends RefCounted


## Result dictionary keys returned by [method determine_winner].
## [codeblock]
## {
##   "winner_index": int,          # 0 or 1
##   "reason":       String,       # "elimination" | "round_6" | "mutual_destruction"
##   "scores":       Array[int],   # [player_0_score, player_1_score]
## }
## [/codeblock]


## Calculates the score for [param scorer_index] by summing the fleet-point
## cost of every destroyed enemy ship and squadron.
## Rules Reference: "Scoring", RRG p.15 — "A player's score is the total
## fleet point cost of destroyed enemy ships and squadrons."
## WN-003.
func calculate_score(scorer_index: int, state: GameState) -> int:
	var opponent_index: int = 1 - scorer_index
	var opponent: PlayerState = state.get_player_state(opponent_index)
	if opponent == null:
		return 0

	var total: int = 0
	for ship: Variant in opponent.ships:
		if ship is ShipInstance and ship.is_destroyed():
			total += _ship_score_value(ship as ShipInstance)
	for squad: Variant in opponent.squadrons:
		if squad is SquadronInstance and squad.is_destroyed():
			total += _squadron_score_value(squad as SquadronInstance)
	return total


func _ship_score_value(ship: ShipInstance) -> int:
	if ship.fleet_points > 0:
		return ship.fleet_points
	if ship.ship_data == null:
		return 0
	return ship.ship_data.point_cost


func _squadron_score_value(squadron: SquadronInstance) -> int:
	if squadron.fleet_points > 0:
		return squadron.fleet_points
	if squadron.squadron_data == null:
		return 0
	return squadron.squadron_data.point_cost


## Returns true when every ship owned by [param player_index] is destroyed.
## Squadrons alone do not prevent elimination.
## Rules Reference: "Winning and Losing", RRG p.21 — "If all ships in a
## fleet are destroyed, ignoring squadrons, the game immediately ends."
## GO-004, GF-004.
func is_fleet_eliminated(player_index: int, state: GameState) -> bool:
	var ps: PlayerState = state.get_player_state(player_index)
	if ps == null:
		return false
	if ps.ships.is_empty():
		return false
	for ship: Variant in ps.ships:
		if ship is ShipInstance and not ship.is_destroyed():
			return false
	return true


## Determines the game winner and returns a details dictionary.
##
## [param reason] — the trigger that caused the game to end:
##   "elimination", "round_6", or "mutual_destruction".
## [param eliminated_player] — if [param reason] is "elimination", the index
##   of the player whose fleet was wiped out.  Ignored for other reasons.
##
## Rules Reference:
## - Elimination (WN-001): opponent of the eliminated player wins.
## - Mutual destruction (RRG p.21): "If the last remaining ships in both
##   fleets are destroyed at the same time, the player with the highest
##   score wins. If both players have the same score, the second player wins."
## - Round 6 (WN-002 / WN-004): highest score wins; tie → second player wins.
func determine_winner(
		state: GameState,
		reason: String,
		eliminated_player: int = -1) -> Dictionary:
	var scores: Array[int] = [
		calculate_score(0, state),
		calculate_score(1, state),
	]
	var second_player: int = 1 - state.initiative_player
	var winner: int = -1

	match reason:
		"elimination":
			winner = 1 - eliminated_player
		"mutual_destruction", "round_6":
			if scores[0] > scores[1]:
				winner = 0
			elif scores[1] > scores[0]:
				winner = 1
			else:
				# Tiebreaker — second player wins.
				# Rules Reference: WN-004 — "the second player wins."
				winner = second_player
		_:
			push_error("ScoringCalculator: unknown reason '%s'" % reason)
			winner = second_player

	return {
		"winner_index": winner,
		"reason": reason,
		"scores": scores,
	}
