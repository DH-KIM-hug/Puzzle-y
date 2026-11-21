## Ordered stage list (design/gdd/stage-goals.md rule 1). Loaded once at game
## start and validated with [method StageLoader.load_catalog]; read-only after.
class_name StageCatalog
extends Resource

## Stages in play order.
@export var stages: Array[StageDef] = []


## The stage with [param id], or null.
func find(id: StringName) -> StageDef:
	for s: StageDef in stages:
		if s != null and s.id == id:
			return s
	return null
