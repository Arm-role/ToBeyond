class_name RuleEffect
extends ArtifactEffect
## Turns on a rule the game code asks for with ArtifactSystem.has_rule().
## Rules: walk_back, helper_odd, helper_even, totem, equal_groups,
## free_discard, full_sell.

@export var rule: StringName = &""


func grants(r: StringName) -> bool:
	return r == rule
