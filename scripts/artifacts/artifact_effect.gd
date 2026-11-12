class_name ArtifactEffect
extends Resource
## Base class of everything an artifact can do. Override only the hooks the
## effect uses; each returns true when it took effect (the card then flashes).
##
## Per-copy hooks get `art` = the owned Dictionary (counter "m", slot order).
## Per-type hooks get `count` = how many copies the player holds.
##
## Hook            | when                                   | kind
## ----------------+----------------------------------------+---------
## round_start     | a new enemy starts (after the shop)    | per copy
## chaos_used      | a Chaos card was used                  | per copy
## card_played     | a Gem was placed from the hand        | per copy
## pre_walk        | right before the fireball walks        | per copy
## land            | the walk lands on a Gem                | per type
## attack_early    | final attack, before every other card  | per copy
## attack          | final attack, in slot order (draft)    | per copy
## victory         | the enemy died (counters)              | per copy
## reward          | the enemy died: coins to add           | per type
## stone_upgrade   | a Stone formula was bought in the shop | per copy
## grants(rule)    | rule switches read by the game code    | query
##
## Rules in use: walk_back, helper_odd, helper_even, totem, equal_groups,
## free_discard, full_sell.


func round_start(_ctx: ArtifactContext, _art: Dictionary) -> bool: return false
func chaos_used(_ctx: ArtifactContext, _art: Dictionary) -> bool: return false
func card_played(_ctx: ArtifactContext, _art: Dictionary) -> bool: return false
func pre_walk(_ctx: ArtifactContext, _art: Dictionary) -> bool: return false
func land(_ctx: ArtifactContext, _count: int) -> bool: return false
func attack_early(_ctx: ArtifactContext, _art: Dictionary) -> bool: return false
func attack(_ctx: ArtifactContext, _art: Dictionary) -> bool: return false
func victory(_ctx: ArtifactContext, _art: Dictionary) -> bool: return false
func reward(_ctx: ArtifactContext, _count: int) -> int: return 0
func stone_upgrade(_ctx: ArtifactContext, _art: Dictionary) -> bool: return false
func grants(_rule: StringName) -> bool: return false
