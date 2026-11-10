class_name RewardEffect
extends ArtifactEffect
## Data-only victory coins: copies × amount × source. `row` names the line in
## the reward summary ("arti", "fate", "walk"; new rows need render_reward_summary).

@export var amount: float = 1.0
@export var source: String = "artifacts_owned"
@export var row: String = ""


func reward(ctx: ArtifactContext, count: int) -> int:
	return int(count * amount * ctx.source(source))
