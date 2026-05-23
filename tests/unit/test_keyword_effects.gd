## Test: Legacy Keyword Effects (Escort, Swarm)
##
## Unit tests for the remaining core-set squadron keyword GameEffect subclasses.
## Rules Reference: "Squadron Keywords", RRG p.12; SM-030–032.
extends GutTest


var _registry: EffectRegistry = null


func before_each() -> void:
	_registry = EffectRegistry.new()


# --- Helpers ---

## Creates a SquadronInstance with the given keywords.
func _make_squadron(keywords: Array[String],
		player: int = 0) -> SquadronInstance:
	var data: SquadronData = SquadronData.new()
	data.squadron_name = "Test Squad"
	data.hull = 3
	data.speed = 3
	data.defense_tokens = []
	var kw_array: Array[Dictionary] = []
	for kw: String in keywords:
		kw_array.append({"name": kw})
	data.keywords = kw_array
	return SquadronInstance.create_from_data("test", data, player)


func _make_ship_instance() -> ShipInstance:
	var sd: ShipData = ShipData.new()
	sd.ship_name = "TestShip"
	sd.hull = 5
	sd.shields = {"front": 3, "rear": 1, "left": 2, "right": 2}
	sd.defense_tokens = []
	sd.command_value = 2
	sd.squadron_value = 2
	sd.engineering_value = 3
	sd.navigation_chart = [[1], [1, 1], [1, 1, 1]]
	var si: ShipInstance = ShipInstance.create_from_data("test_ship", sd, 0, 0)
	return si


# ===========================================================================
# EscortEffect
# ===========================================================================

func test_escort_get_hooks() -> void:
	var e: EscortEffect = EscortEffect.new()
	var hooks: Array[StringName] = e.get_hooks()
	assert_eq(hooks[0], &"SQUADRON_MUST_ATTACK_ENGAGED",
			"Escort hook should be SQUADRON_MUST_ATTACK_ENGAGED")


func test_escort_does_not_trigger_when_targeting_itself() -> void:
	var escort_sq: SquadronInstance = _make_squadron(["Escort"])
	var e: EscortEffect = EscortEffect.new()
	e.owner = escort_sq
	var ctx: EffectContext = EffectContext.new()
	ctx.defender = escort_sq
	assert_false(e.should_trigger(ctx),
			"Escort should not trigger when itself is the target")


func test_escort_does_not_trigger_when_targeting_another_escort() -> void:
	var escort_a: SquadronInstance = _make_squadron(["Escort"])
	var escort_b: SquadronInstance = _make_squadron(["Escort"])
	var e: EscortEffect = EscortEffect.new()
	e.owner = escort_a
	var ctx: EffectContext = EffectContext.new()
	ctx.defender = escort_b
	assert_false(e.should_trigger(ctx),
			"Escort should not trigger when another Escort is the target")


func test_escort_triggers_when_targeting_non_escort() -> void:
	var escort_sq: SquadronInstance = _make_squadron(["Escort"])
	var plain_sq: SquadronInstance = _make_squadron([])
	var e: EscortEffect = EscortEffect.new()
	e.owner = escort_sq
	var ctx: EffectContext = EffectContext.new()
	ctx.defender = plain_sq
	assert_true(e.should_trigger(ctx),
			"Escort should trigger when non-Escort is the target")


func test_escort_resolve_cancels_target() -> void:
	var escort_sq: SquadronInstance = _make_squadron(["Escort"])
	var plain_sq: SquadronInstance = _make_squadron([])
	var e: EscortEffect = EscortEffect.new()
	e.owner = escort_sq
	var ctx: EffectContext = EffectContext.new()
	ctx.defender = plain_sq
	e.resolve(ctx)
	assert_true(ctx.cancelled,
			"Escort resolve should cancel non-Escort target selection (SM-031)")


# ===========================================================================
# SwarmEffect
# ===========================================================================

func test_swarm_get_hooks() -> void:
	var e: SwarmEffect = SwarmEffect.new()
	var hooks: Array[StringName] = e.get_hooks()
	assert_eq(hooks[0], &"ATTACK_MODIFY_DICE_ATTACKER",
			"Swarm hook should be ATTACK_MODIFY_DICE_ATTACKER")


func test_swarm_does_not_trigger_vs_ship() -> void:
	var swarm_sq: SquadronInstance = _make_squadron(["Swarm"])
	var ship: ShipInstance = _make_ship_instance()
	var e: SwarmEffect = SwarmEffect.new()
	e.owner = swarm_sq
	var ctx: EffectContext = EffectContext.new()
	ctx.attacker = swarm_sq
	ctx.defender = ship
	ctx.set_meta_value("swarm_eligible", true)
	assert_false(e.should_trigger(ctx),
			"Swarm should not trigger against a ship")


func test_swarm_does_not_trigger_without_eligibility() -> void:
	var swarm_sq: SquadronInstance = _make_squadron(["Swarm"])
	var target: SquadronInstance = _make_squadron([])
	var e: SwarmEffect = SwarmEffect.new()
	e.owner = swarm_sq
	var ctx: EffectContext = EffectContext.new()
	ctx.attacker = swarm_sq
	ctx.defender = target
	ctx.set_meta_value("swarm_eligible", false)
	assert_false(e.should_trigger(ctx),
			"Swarm should not trigger when swarm_eligible is false")


func test_swarm_triggers_when_eligible() -> void:
	var swarm_sq: SquadronInstance = _make_squadron(["Swarm"])
	var target: SquadronInstance = _make_squadron([])
	var e: SwarmEffect = SwarmEffect.new()
	e.owner = swarm_sq
	var ctx: EffectContext = EffectContext.new()
	ctx.attacker = swarm_sq
	ctx.defender = target
	ctx.set_meta_value("swarm_eligible", true)
	assert_true(e.should_trigger(ctx),
			"Swarm should trigger when eligible vs squadron")


func test_swarm_resolve_changes_a_die() -> void:
	var swarm_sq: SquadronInstance = _make_squadron(["Swarm"])
	var target: SquadronInstance = _make_squadron([])
	var e: SwarmEffect = SwarmEffect.new()
	e.owner = swarm_sq
	var ctx: EffectContext = EffectContext.new()
	ctx.attacker = swarm_sq
	ctx.defender = target
	# Single BLANK die — guaranteed to be "worst"
	ctx.dice_results = [
		{"color": Constants.DiceColor.BLUE, "face": Constants.DiceFace.BLANK},
	]
	ctx.set_meta_value("swarm_eligible", true)
	# Resolve — the die might stay BLANK or change to something else.
	# We can only verify the function runs without error; exact face is random.
	e.resolve(ctx)
	assert_eq(ctx.dice_results.size(), 1,
			"Swarm reroll should not change pool size")
	# The face is re-rolled randomly, so we just check it's a valid face.
	var face: Constants.DiceFace = ctx.dice_results[0]["face"] as Constants.DiceFace
	assert_true(face >= 0 and face <= 10,
			"Rerolled face should be a valid DiceFace enum value")


func test_swarm_resolve_empty_pool_no_crash() -> void:
	var swarm_sq: SquadronInstance = _make_squadron(["Swarm"])
	var e: SwarmEffect = SwarmEffect.new()
	e.owner = swarm_sq
	var ctx: EffectContext = EffectContext.new()
	ctx.dice_results = []
	e.resolve(ctx)
	assert_eq(ctx.dice_results.size(), 0,
			"Empty pool should remain empty without crash")
