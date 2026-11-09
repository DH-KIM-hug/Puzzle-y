## One locked team slot (design/gdd/team-composition.md rule 5 `locked` entry).
class_name TeamLock
extends Resource

## Team slot index (0..team_size-1).
@export var slot: int = 0
## Crew forced into that slot (a guest when not owned — rule 7).
@export var crew_id: StringName = &""


## Convenience constructor.
static func make(p_slot: int, p_crew_id: StringName) -> TeamLock:
	var l := TeamLock.new()
	l.slot = p_slot
	l.crew_id = p_crew_id
	return l
