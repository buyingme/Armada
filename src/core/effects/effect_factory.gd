## EffectFactory
##
## Creates and registers [GameEffect] instances for all game entities
## that carry rule-modifying effects (squadron keywords, upgrade cards, etc.).
##
## Called during setup and after load to populate or rebuild the transient
## [EffectRegistry] on [GameState] from authoritative entity state.
##
## Rules Reference: "Effect Use and Timing", RRG p.5; ET-001–004.
class_name EffectFactory
extends RefCounted


## Rebuilds every transient runtime effect hook from serialized state.
## [EffectRegistry] is intentionally not serialized; loaded saves must
## recreate hooks from authoritative ship, squadron, upgrade, and damage-card
## state before play resumes.
## Returns the number of registered effects.
static func rebuild_runtime_effects(
		game_state: GameState,
		initiative_player: int) -> int:
	if game_state == null:
		return 0
	if game_state.effect_registry == null:
		game_state.effect_registry = EffectRegistry.new()
	else:
		game_state.effect_registry.clear()
	var count: int = register_squadron_keywords(
			game_state, initiative_player)
	count += register_faceup_damage_effects(game_state, initiative_player)
	return count


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


## Registers persistent effects for all faceup damage cards already present
## in [param game_state].  Used after save/load because the card state is
## serialized but the transient [EffectRegistry] is rebuilt fresh.
## Returns the number of persistent damage-card effects registered.
static func register_faceup_damage_effects(
		game_state: GameState,
		initiative_player: int) -> int:
	if game_state == null or game_state.effect_registry == null:
		return 0
	var count: int = 0
	for player_idx: int in range(Constants.PLAYER_COUNT):
		var ps: PlayerState = game_state.get_player_state(player_idx)
		if ps == null:
			continue
		for ship_var: Variant in ps.ships:
			if ship_var is ShipInstance:
				count += _register_faceup_damage_for_ship(
						game_state.effect_registry,
						ship_var as ShipInstance,
						initiative_player)
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


## Registers persistent faceup damage effects attached to [param ship].
static func _register_faceup_damage_for_ship(
		registry: EffectRegistry,
		ship: ShipInstance,
		initiative_player: int) -> int:
	var count: int = 0
	for card_var: Variant in ship.faceup_damage:
		if not card_var is DamageCard:
			continue
		var card: DamageCard = card_var as DamageCard
		var effect: DamageCardEffect = DamageCardEffectFactory.register_effect(
				card, ship, registry, initiative_player)
		if effect != null:
			count += 1
	return count


## Maps a keyword name string to its concrete [GameEffect] subclass.
## Returns null for keywords that do not yet have an effect implementation.
static func _create_keyword_effect(keyword_name: String) -> GameEffect:
	match keyword_name.to_lower():
		"escort":
			return EscortEffect.new()
		"swarm":
			return SwarmEffect.new()
		_:
			# Keyword not yet implemented (e.g. Heavy, Counter, Intel).
			return null
