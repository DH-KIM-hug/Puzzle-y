## Minimal owned-crew provider (design/gdd/team-composition.md "보유 크루" row,
## provisional contract): [method owned_crew_ids] in registry order and
## [method is_owned]. A data value, not an interface to override — the crew
## ownership system (save data) builds one of these; tests and debug builds use
## [method starter] / [method all_of].
## [codeblock]
## var owned := OwnedCrews.starter(registry)        # new save: nyangi, gomgom, piyak
## var debug := OwnedCrews.all_of(registry)         # debug: all 6
## TeamRules.check_team(team, rule, registry, owned)
## [/codeblock]
class_name OwnedCrews
extends RefCounted

var _ids: Array[StringName] = []
var _set: Dictionary = {}


## Owned = the given ids, kept in registry order (unknown ids dropped).
static func of(ids: Array[StringName], registry: CrewRegistry) -> OwnedCrews:
	var o := OwnedCrews.new()
	var wanted := {}
	for id: StringName in ids:
		wanted[id] = true
	for c: CrewDef in registry.crews:
		if c != null and wanted.has(c.id):
			o._ids.append(c.id)
			o._set[c.id] = true
	return o


## A new save: the registry's starter crews (crew-definition rule 10).
static func starter(registry: CrewRegistry) -> OwnedCrews:
	return of(TeamRules.starters_in_registry_order(registry), registry)


## Debug provider: every registry crew owned.
static func all_of(registry: CrewRegistry) -> OwnedCrews:
	var ids: Array[StringName] = []
	for c: CrewDef in registry.crews:
		if c != null:
			ids.append(c.id)
	return of(ids, registry)


## Owned crew ids, registry order (a copy).
func owned_crew_ids() -> Array[StringName]:
	return _ids.duplicate()


## True when [param crew_id] is owned.
func is_owned(crew_id: StringName) -> bool:
	return _set.has(crew_id)
