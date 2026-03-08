## LearningScenarioSetup
##
## Provides fixed placement data for the Learning Scenario initial board state.
## Returns ship and squadron positions as normalised coordinates (0.0–1.0)
## relative to the play area, allowing the Presentation layer to place tokens
## at the correct pixel positions regardless of screen resolution.
##
## Positions are derived from the Learning Scenario Setup Diagram in the
## Learn to Play booklet (SWM01-ARMADA-LEARN-TO-PLAY, p.5–6).
##
## Rules Reference: "Learning Scenario Setup", steps 4 and 9, p.5–6.
class_name LearningScenarioSetup
extends RefCounted


## Returns the complete list of token placements for the Learning Scenario.
## Imperial tokens occupy the top deployment zone (pos_y < 0.40);
## Rebel tokens occupy the bottom zone (pos_y > 0.60).
##
## Rules Reference: "Learning Scenario Setup", step 9; diagram p.6.
func get_all_placements() -> Array[TokenPlacement]:
	var placements: Array[TokenPlacement] = []
	placements.append(_make_victory_ii())
	placements.append(_make_tie_fighter())
	placements.append(_make_cr90_a())
	placements.append(_make_nebulon_b())
	placements.append(_make_x_wing())
	return placements


## Returns only ship token placements (is_ship == true).
func get_ship_placements() -> Array[TokenPlacement]:
	var result: Array[TokenPlacement] = []
	for p: TokenPlacement in get_all_placements():
		if p.is_ship:
			result.append(p)
	return result


## Returns only squadron token placements (is_ship == false).
func get_squadron_placements() -> Array[TokenPlacement]:
	var result: Array[TokenPlacement] = []
	for p: TokenPlacement in get_all_placements():
		if not p.is_ship:
			result.append(p)
	return result


## Returns the total number of tokens placed in the Learning Scenario.
func get_token_count() -> int:
	return get_all_placements().size()


# ---------------------------------------------------------------------------
# Private placement factories — one per token.
# All positions derived from the Setup Diagram, p.6.
# ---------------------------------------------------------------------------

## Victory II-class Star Destroyer: top-centre, facing south toward Rebels.
## Rules Reference: Setup Diagram, p.6.
func _make_victory_ii() -> TokenPlacement:
	return TokenPlacement.new(
			"victory_ii_class_star_destroyer",
			true,
			Constants.Faction.GALACTIC_EMPIRE,
			0.50, 0.22,
			PI,
			_load_ship_size("victory_ii_class_star_destroyer")
	)


## TIE Fighter Squadron: upper area, left of Victory II.
## Rules Reference: Setup Diagram, p.6.
func _make_tie_fighter() -> TokenPlacement:
	return TokenPlacement.new(
			"tie_fighter_squadron",
			false,
			Constants.Faction.GALACTIC_EMPIRE,
			0.35, 0.15,
			PI
	)


## CR90 Corvette A: lower area, left-of-centre, facing north toward Imperials.
## Rules Reference: Setup Diagram, p.6.
func _make_cr90_a() -> TokenPlacement:
	return TokenPlacement.new(
			"cr90_corvette_a",
			true,
			Constants.Faction.REBEL_ALLIANCE,
			0.38, 0.80,
			0.0,
			_load_ship_size("cr90_corvette_a")
	)


## Nebulon-B Escort Frigate: lower area, right-of-centre, facing north.
## Rules Reference: Setup Diagram, p.6.
func _make_nebulon_b() -> TokenPlacement:
	return TokenPlacement.new(
			"nebulon_b_escort_frigate",
			true,
			Constants.Faction.REBEL_ALLIANCE,
			0.65, 0.80,
			0.0,
			_load_ship_size("nebulon_b_escort_frigate")
	)


## Loads ship_size from the JSON data file for the given ship key.
## Falls back to SMALL with a push_error if the file is missing.
## Rules Reference: Resources/Game_Components/card_data_schema.json
func _load_ship_size(key: String) -> Constants.ShipSize:
	var ship_data: ShipData = AssetLoader.load_ship_data(key)
	if ship_data == null:
		push_error("LearningScenarioSetup: missing ship data for '%s'" % key)
		return Constants.ShipSize.SMALL
	return ship_data.ship_size


## X-wing Squadron: between the two Rebel ships, slightly ahead of them.
## Rules Reference: Setup Diagram, p.6.
func _make_x_wing() -> TokenPlacement:
	return TokenPlacement.new(
			"x_wing_squadron",
			false,
			Constants.Faction.REBEL_ALLIANCE,
			0.52, 0.68,
			0.0
	)
