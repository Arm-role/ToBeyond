class_name ArtifactContext
extends RefCounted
## Everything an effect may read or change during one hook call.
## Game state is read through `main`; the helpers below name the values
## conditions use most, so new effects don't need to know main.gd.

var main: Node

# Attack hooks: the running ATK / multiplier.
var atk: float = 0.0
var mult: float = 1.0
var calc: Dictionary = {}          # main.calculate_groups() for this attack (groups always empty)

# Land hook.
var tile_idx: int = -1
var card: Dictionary = {}
var gain: int = 0                  # ATK the landing tile gave
var extra: int = 0                 # bonus ATK shown in the tile popup
var helper_pass: bool = false      # the helper star, not the fireball
var coin_won: bool = false

# Set by effects that want a message line.
var msg: String = ""


func _init(main_node: Node) -> void:
	main = main_node


# --- Board -------------------------------------------------------------------
func empty_tiles() -> int:
	return main.N_TILES - main.placed_cards.size() - main.chaos_crystals.size()

func dir_count(direction: String) -> int:
	return main.tile_direction_count(direction)

func dir_run(direction: String) -> int:
	return main.tile_direction_run(direction)

func special_tiles() -> int:
	return main.passive_chaos_tile_count()

## Gems of `color` and `direction` on tiles of that direction.
func matching_cards(direction: String, color: String) -> int:
	return main.matching_card_count(direction, color)

func has_gem(idx: int) -> bool:
	return main.placed_cards.has(idx)

# --- Resources and collections ----------------------------------------------
func chaos_held() -> int:
	var n := 0
	for c in main.chaos:
		if c != null:
			n += 1
	return n

func artifacts_owned() -> int:
	return main.artifact_count_any()

func gems_in_deck() -> int:
	return main.deck.size() + main.hand.size() + main.placed_cards.size()

func walks_left() -> int:
	return main.walks_left

func discards_left() -> int:
	return main.discards_left


## Named numbers for data-only effects (StatEffect.source, CounterEffect.source, RewardEffect.source).
func source(key: String, art: Dictionary = {}, fallback: float = 0.0, direction: String = "", color: String = "") -> float:
	match key:
		"one": return 1.0
		"counter": return float(art.get("m", fallback))
		"empty_tiles": return empty_tiles()
		"chaos_held": return chaos_held()
		"special_tiles": return special_tiles()
		"discards_left": return discards_left()
		"walks_left": return walks_left()
		"artifacts_owned": return artifacts_owned()
		"gems_per_10": return int(gems_in_deck() / 10.0)
		"matching_cards": return matching_cards(direction, color)
	push_error("ArtifactContext: unknown source '%s'" % key)
	return 0.0
