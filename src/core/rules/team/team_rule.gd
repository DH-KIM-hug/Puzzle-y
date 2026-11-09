## A stage's team rule (design/gdd/team-composition.md rule 5; held by
## [StageDef.team_rule], stage-goals rule 13). Data only — [TeamRules] interprets it.
class_name TeamRule
extends Resource

## Required team size N (1–3, default 3).
@export var team_size: int = 3
## Locked slots ({slot, crew_id}); all slots locked = fixed team (tutorials).
@export var locked: Array[TeamLock] = []
## Crews that may not be picked on this stage.
@export var banned: Array[StringName] = []


## Convenience constructor. [param locked_ids] fills slots 0.. in order.
static func make(p_team_size: int = 3, locked_ids: Array[StringName] = [], p_banned: Array[StringName] = []) -> TeamRule:
	var r := TeamRule.new()
	r.team_size = p_team_size
	for i: int in locked_ids.size():
		r.locked.append(TeamLock.make(i, locked_ids[i]))
	r.banned = p_banned.duplicate()
	return r


## Crew locked into [param slot], or [code]&""[/code].
func locked_at(slot: int) -> StringName:
	for l: TeamLock in locked:
		if l != null and l.slot == slot:
			return l.crew_id
	return &""


## True when [param crew_id] is locked into some slot.
func is_locked_crew(crew_id: StringName) -> bool:
	for l: TeamLock in locked:
		if l != null and l.crew_id == crew_id:
			return true
	return false


## True when every slot is locked (fixed team — tray-supply "팀 고정").
func is_fixed() -> bool:
	for s: int in team_size:
		if locked_at(s) == &"":
			return false
	return true


## The locked team in slot order (only meaningful when [method is_fixed]).
func fixed_team() -> Array[StringName]:
	var out: Array[StringName] = []
	for s: int in team_size:
		out.append(locked_at(s))
	return out
