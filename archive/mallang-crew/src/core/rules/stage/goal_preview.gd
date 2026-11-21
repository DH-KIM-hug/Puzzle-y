## Goal markers for one hypothetical placement (design/gdd/stage-goals.md rule 14).
## Facts only — no recommendation, no comparison between anchors.
class_name GoalPreview
extends RefCounted

## Unfinished target cells this placement would clear (row-major order of events).
var target_cells_hit: Array[Vector2i] = []
## Cells this placement would free from their last counted obstacle layer.
var obstacles_freed: Array[Vector2i] = []
## Indices (into [member StageDef.goals]) of CHAIN goals this placement advances.
var chain_goal_hit: Array[int] = []
## True when this placement would meet every goal.
var completes_stage: bool = false


## True when there is nothing to mark.
func is_empty() -> bool:
	return target_cells_hit.is_empty() and obstacles_freed.is_empty() and chain_goal_hit.is_empty() and not completes_stage
