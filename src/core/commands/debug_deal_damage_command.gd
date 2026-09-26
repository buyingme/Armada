## Compatibility name for the authoritative BUG-043 debug damage command.
##
## All behavior is inherited from [CandidateDebugDealDamageCommand]. Keeping
## this historical class name does not retain a second mutation path.
class_name DebugDealDamageCommand
extends CandidateDebugDealDamageCommand


static func register() -> void:
	GameCommand.register_type("debug_deal_damage",
			func(player: int, payload: Dictionary) -> GameCommand:
				return DebugDealDamageCommand.new(player, payload))
