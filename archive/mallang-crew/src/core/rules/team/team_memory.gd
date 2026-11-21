## Team memories (design/gdd/team-composition.md rule 10): the last team started
## per stage and the last 3-crew guest-free team. A value object — update it with
## [method TeamRules.remember]; the save system persists it (format: save GDD).
class_name TeamMemory
extends RefCounted

## stage_id → Array[StringName] (slot order, guests included).
var by_stage: Dictionary = {}
## Last global team (3 crews, no guests); empty when none.
var last_global: Array[StringName] = []


## The remembered team of [param stage_id] (empty when none).
func stage_team(stage_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if by_stage.has(stage_id):
		out.assign(by_stage[stage_id])
	return out


## Independent copy.
func copy() -> TeamMemory:
	var m := TeamMemory.new()
	m.by_stage = by_stage.duplicate(true)
	m.last_global = last_global.duplicate()
	return m
