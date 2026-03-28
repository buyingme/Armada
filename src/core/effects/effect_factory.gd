## EffectFactory
##
## Creates and registers [GameEffect] instances for all game entities
## that carry rule-modifying effects (squadron keywords, upgrade cards, etc.).
##
## Called once during game setup after fleets are deployed to populate
## the [EffectRegistry] on [GameState].
##
## Rules Reference: "Effect Use and Timing", RRG p.5; ET-001–004.
class_name EffectFactory
extends RefCounted


## Scans all squadrons in [param game_state] for keywords and registers
## the corresponding effects in the game state's [EffectRegistry].
## [param initiative_player] — index (0 or 1) of the first player; used
## to set [member GameEffect.player_priority] so effects resolve in the
## correct order (ET-002).
## Returns the number of effects registered.
static func register_squadron_keywords(
		game_state: GameState,
		initiative_player: int) -> int:
	if game_state == null or game_state.effect_registry == null:
		return 0
	var count: int = 0
	for player_idx: int in range(Constants.PLAYER_COUNT):
		var ps: PlayerState = game_state.get_player_state(player_idx)
		if ps == null:
			continue
		var priority: int = 0 if player_idx == initiative_player else 1
		for sq: Variant in ps.squadrons:
			if not sq is SquadronInstance:
				continue
			var inst: SquadronInstance = sq as SquadronInstance
			if inst.squadron_data == null:
				continue
			count += _register_keywords_for_squadron(
					game_state.effect_registry, inst, priority)
	return count


## Creates and registers effects for every keyword on [param squadron].
static func _register_keywords_for_squadron(
		registry: EffectRegistry,
		squadron: SquadronInstance,
		priority: int) -> int:
	var count: int = 0
	var keywords: Array = squadron.squadron_data.keywords
	for kw: Variant in keywords:
		if not kw is Dictionary:
			continue
		var kw_name: String = (kw as Dictionary).get("name", "") as String
		var effect: GameEffect = _create_keyword_effect(kw_name)
		if effect == null:
			continue
		effect.owner = squadron
		effect.player_priority = priority
		registry.register(effect)
		count += 1
	return count


## Maps a keyword name string to its concrete [GameEffect] subclass.
## Returns null for keywords that do not yet have an effect implementation.
static func _create_keyword_effect(keyword_name: String) -> GameEffect:
	match keyword_name.to_lower():
		"bomber":
			return BomberEffect.new()
		"escort":
			return EscortEffect.new()
		"swarm":
			return SwarmEffect.new()
		_:
			# Keyword not yet implemented (e.g. Heavy, Counter, Intel).
			return null
