## Swarm Keyword
##
## Static projection hook for the Swarm squadron keyword.
## Rules Reference: RRG "Squadron Keywords" — "While attacking a squadron
## engaged with another squadron, you may reroll 1 die."
class_name SwarmKeyword
extends RefCounted


const RULE_ID: String = "squadron_keyword.swarm"
const PAYLOAD_AVAILABLE: String = "swarm_reroll_available"
const PAYLOAD_CONTROLLER_PLAYER: String = "swarm_controller_player"
const PAYLOAD_DIE_INDICES: String = "swarm_die_indices"
const PROMPT: String = "Swarm"

static var _rule_instance: SwarmKeyword = null


## Registers the Swarm reroll projection affordance hook.
static func register() -> void:
	if _rule_instance == null:
		_rule_instance = SwarmKeyword.new()
	RuleRegistry.register_rule(RULE_ID, [
		FlowHook.enabler(RULE_ID,
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_MODIFY,
				RuleSurface.TARGET_ATTACK_MODIFIER_AFFORDANCE,
				Callable(_rule_instance, "project_swarm_affordance")),
	])


## Projects the optional Swarm reroll choice to the attacking player.
func project_swarm_affordance(_state: GameState,
		flow: InteractionFlow,
		viewer_player: int) -> Dictionary:
	if flow == null or not bool(flow.payload.get(PAYLOAD_AVAILABLE, false)):
		return {}
	var controller: int = int(flow.payload.get(PAYLOAD_CONTROLLER_PLAYER, -1))
	if viewer_player >= 0 and viewer_player != controller:
		return {}
	var indices: Array[int] = []
	for raw_index: Variant in flow.payload.get(PAYLOAD_DIE_INDICES, []):
		indices.append(int(raw_index))
	return SquadronKeywordRuleHelper.make_optional_modifier_affordance(
			RULE_ID, controller, indices, PROMPT)
