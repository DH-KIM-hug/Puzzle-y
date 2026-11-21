## Minimal local progress for the T1 stage loop (task brief "persistence for this
## step"; the full save system GDD comes later): best stars / best final score
## per stage, owned crews and the team memories (team-composition rule 10).
## Unlock rule: stage 0 is always open; stage i opens once stage i-1 has ≥ 1 star
## (= was cleared, stage-goals F7).
##
## Pure data + JSON (de)serialisation; the only file I/O is [method load_file] /
## [method save_file], which never throw: a missing file is a new save, a corrupt
## or wrong-version file is reported in [member load_warning] and replaced by a
## new save (the bad file is kept beside it as [code]*.corrupt[/code]).
## [codeblock]
## var p := PlayerProgress.load_file("user://progress.json", registry)
## if p.is_unlocked(catalog, 3): ...
## p.record_result(&"1-1", 2, 731)
## p.save_file("user://progress.json")
## [/codeblock]
class_name PlayerProgress
extends RefCounted

## Save format version (bump + migrate when the shape changes).
const VERSION := 1
## Default save path.
const DEFAULT_PATH := "user://progress.json"

## stage_id (String) → best stars 0–3.
var best_stars: Dictionary = {}
## stage_id (String) → best final score.
var best_score: Dictionary = {}
## Owned crew ids (registry order is restored by [OwnedCrews]).
var owned: Array[StringName] = []
## Team memories (team-composition rule 10).
var memory: TeamMemory = TeamMemory.new()
## Non-empty when the last [method load_file] fell back to a new save.
var load_warning: String = ""


## A new save: the registry's starter crews owned, nothing cleared.
static func fresh(registry: CrewRegistry) -> PlayerProgress:
	var p := PlayerProgress.new()
	if registry != null:
		p.owned = TeamRules.starters_in_registry_order(registry)
	return p


## Stars of [param stage_id] (0 when never cleared).
func stars_of(stage_id: StringName) -> int:
	return int(best_stars.get(String(stage_id), 0))


## Best final score of [param stage_id] (0 when none).
func score_of(stage_id: StringName) -> int:
	return int(best_score.get(String(stage_id), 0))


## True when stage [param index] of [param catalog] can be played.
func is_unlocked(catalog: StageCatalog, index: int) -> bool:
	if index <= 0:
		return true
	if catalog == null or index >= catalog.stages.size():
		return false
	return stars_of(catalog.stages[index - 1].id) > 0


## Keeps the best stars and best score independently. Returns true when either improved.
func record_result(stage_id: StringName, stars: int, final_score: int) -> bool:
	var key := String(stage_id)
	var improved := false
	if stars > stars_of(stage_id):
		best_stars[key] = clampi(stars, 0, 3)
		improved = true
	if stars > 0 and final_score > score_of(stage_id):
		best_score[key] = final_score
		improved = true
	return improved


## Owned crews as the team-composition provider.
func owned_crews(registry: CrewRegistry) -> OwnedCrews:
	return OwnedCrews.of(owned, registry)


## Plain JSON-safe form.
func to_dict() -> Dictionary:
	var by_stage := {}
	for k: Variant in memory.by_stage.keys():
		by_stage[String(k)] = _strings(memory.by_stage[k])
	return {
		"version": VERSION,
		"best_stars": best_stars.duplicate(),
		"best_score": best_score.duplicate(),
		"owned": _strings(owned),
		"last_team_by_stage": by_stage,
		"last_team_global": _strings(memory.last_global),
	}


## Parses [param text]. Returns null when it is not a valid save of this version
## (the caller decides the fallback). Unknown crew ids are dropped when
## [param registry] is given; out-of-range values are clamped.
static func from_json(text: String, registry: CrewRegistry) -> PlayerProgress:
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary):
		return null
	var d := data as Dictionary
	if int(d.get("version", -1)) != VERSION:
		return null
	var p := PlayerProgress.new()
	var stars: Variant = d.get("best_stars", {})
	var scores: Variant = d.get("best_score", {})
	if not (stars is Dictionary) or not (scores is Dictionary):
		return null
	for k: Variant in (stars as Dictionary).keys():
		var v: Variant = stars[k]
		if v is float or v is int:
			p.best_stars[String(k)] = clampi(int(v), 0, 3)
	for k: Variant in (scores as Dictionary).keys():
		var v: Variant = scores[k]
		if v is float or v is int:
			p.best_score[String(k)] = maxi(0, int(v))
	p.owned = _ids(d.get("owned", []), registry)
	if p.owned.is_empty() and registry != null:
		p.owned = TeamRules.starters_in_registry_order(registry)
	var by_stage: Variant = d.get("last_team_by_stage", {})
	if by_stage is Dictionary:
		for k: Variant in (by_stage as Dictionary).keys():
			var team := _ids(by_stage[k], registry)
			if not team.is_empty():
				p.memory.by_stage[StringName(String(k))] = team
	p.memory.last_global = _ids(d.get("last_team_global", []), registry)
	return p


## Loads [param path]; never fails (see class docs).
static func load_file(path: String, registry: CrewRegistry) -> PlayerProgress:
	if not FileAccess.file_exists(path):
		return fresh(registry)
	var text := FileAccess.get_file_as_string(path)
	var p := from_json(text, registry)
	if p == null:
		var fallback := fresh(registry)
		fallback.load_warning = "progress file unreadable, started a new save: %s" % path
		push_warning("PlayerProgress: " + fallback.load_warning)
		var bad := FileAccess.open(path + ".corrupt", FileAccess.WRITE)
		if bad != null:
			bad.store_string(text)
		return fallback
	return p


## Writes the save (temp file + rename so a crash never leaves half a file).
## Returns the error code (OK on success).
func save_file(path: String) -> Error:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("PlayerProgress: cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return ERR_CANT_OPEN
	return dir.rename(tmp.get_file(), path.get_file())


static func _strings(list: Array) -> Array:
	var out := []
	for v: Variant in list:
		out.append(String(v))
	return out


static func _ids(raw: Variant, registry: CrewRegistry) -> Array[StringName]:
	var out: Array[StringName] = []
	if not (raw is Array):
		return out
	for v: Variant in (raw as Array):
		if not (v is String or v is StringName):
			continue
		var id := StringName(String(v))
		if registry != null and registry.get_crew(id) == null:
			continue
		if not out.has(id):
			out.append(id)
	return out
