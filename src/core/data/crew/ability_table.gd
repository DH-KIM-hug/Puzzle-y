## Read-only resolver view of crew abilities (ADR-0001 Decision 8, crew-definition
## rule 8): crew_id -> ability id + ordered steps [code]{primitive, params}[/code],
## for the whole registry, plus the cached [method SeedHash.str32] crew keys used by
## [method BoardState.board_hash]. The resolver reads this, never [Resource]s.
class_name AbilityTable
extends RefCounted

const K_PRIMITIVE := &"primitive"
const K_PARAMS := &"params"

var _steps: Dictionary = {}
var _ability_ids: Dictionary = {}
var _crew_keys: Dictionary = {}


## Builds a frozen table from
## [code]{crew_id: {"ability_id": StringName, "steps": [{"primitive": StringName, "params": Dictionary}, …]}}[/code].
## Input is deep-copied; the caller's data is never retained.
static func create(spec: Dictionary) -> AbilityTable:
	var t := AbilityTable.new()
	var ids: Array = spec.keys()
	ids.sort_custom(by_text)
	for crew_id: StringName in ids:
		var entry: Dictionary = spec[crew_id]
		var steps: Array = []
		for raw: Dictionary in entry.get(&"steps", []):
			var params: Dictionary = (raw.get(K_PARAMS, {}) as Dictionary).duplicate(true)
			_freeze(params)
			var step := {K_PRIMITIVE: StringName(raw.get(K_PRIMITIVE, &"")), K_PARAMS: params}
			step.make_read_only()
			steps.append(step)
		steps.make_read_only()
		t._steps[crew_id] = steps
		t._ability_ids[crew_id] = StringName(entry.get(&"ability_id", &""))
		t._crew_keys[crew_id] = SeedHash.str32(String(crew_id))
	t._steps.make_read_only()
	t._ability_ids.make_read_only()
	t._crew_keys.make_read_only()
	return t


## True when the crew has an ability entry.
func has_crew(crew_id: StringName) -> bool:
	return _steps.has(crew_id)


## Ordered read-only steps of the crew (empty when unknown).
func steps_for(crew_id: StringName) -> Array:
	return _steps.get(crew_id, [])


## Ability id of the crew ([code]&""[/code] when unknown).
func ability_id_for(crew_id: StringName) -> StringName:
	return _ability_ids.get(crew_id, &"")


## Every crew id in the table, sorted.
func crew_ids() -> Array:
	var ids: Array = _steps.keys()
	ids.sort_custom(by_text)
	return ids


## crew_id -> cached crew key (read-only), for [method BoardState.board_hash].
func crew_keys() -> Dictionary:
	return _crew_keys


## Lexicographic order for StringName ids. A plain sort() on StringNames is not
## alphabetical (it is not guaranteed stable across runs), so ids are compared as text.
static func by_text(a: Variant, b: Variant) -> bool:
	return String(a) < String(b)


static func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for v: Variant in (value as Dictionary).values():
			_freeze(v)
		(value as Dictionary).make_read_only()
	elif value is Array:
		for v: Variant in (value as Array):
			_freeze(v)
		(value as Array).make_read_only()
