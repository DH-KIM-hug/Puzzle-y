## One stage goal (design/gdd/stage-goals.md rule 1 `GoalDef`, rules 4–7).
## Data only; [GoalTracker] owns how progress is counted (from events only).
class_name GoalDef
extends Resource

## Goal types (rule 1, D3).
enum Type { SCORE, CLEAR_CELLS, CLEAR_OBSTACLES, CHAIN }

## Goal type.
@export var type: Type = Type.SCORE
## Threshold: score at the reference scale (SCORE, converted by F1), cells, freed
## ice cells, or number of qualifying placements (CHAIN). Must be >= 1.
@export var required: int = 1
## CLEAR_OBSTACLES only: modifier kinds counted (MVP [code][&"ice"][/code]).
@export var keys: Array[StringName] = []
## CHAIN only: minimum chain depth N (1..depth_cap).
@export var depth: int = 0


## Convenience constructor (tests, generators).
static func make(p_type: Type, p_required: int, p_keys: Array[StringName] = [], p_depth: int = 0) -> GoalDef:
	var g := GoalDef.new()
	g.type = p_type
	g.required = p_required
	g.keys = p_keys.duplicate()
	g.depth = p_depth
	return g


## Type name for messages / snapshots.
func type_name() -> String:
	return Type.keys()[type]
