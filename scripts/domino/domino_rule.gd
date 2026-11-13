extends Resource
## One rule of a Domino artifact: when `trigger` fires and every key of `cond`
## matches, run verb `effect` with `args`. Data only (docs/domino/phase-3.md).

@export var trigger: StringName = &""
@export var cond: Dictionary = {}
@export var effect: StringName = &""
@export var args: Dictionary = {}
## "" = unlimited, "walk" = once per walk, "fight" = once per fight.
@export var once: StringName = &""
