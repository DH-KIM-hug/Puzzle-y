## The crew registry: every [CrewDef], validated once at start-up and read-only
## afterwards (crew-definition rules 11–13, ADR-0001 Decision 8). Lives at
## [code]assets/data/crew/crew_registry.tres[/code].
##
## Spec ambiguities resolved here:
## [br]- Rule 12 "E safe range 2.0–5.0" is held as integer hundredths (200–500)
##   because the Rules Core uses no fractional numbers (ADR-0001 guidelines).
## [br]- Rule 7 "size parameters only differ" is detected as: same primitive id
##   sequence and equal shape parameters ([constant PrimitiveLibrary.SHAPE_PARAMS])
##   in every step. Identical abilities fall under the same rule.
## [br]- Rule 4 signature shapes are compared by catalog shape id.
class_name CrewRegistry
extends Resource

## All crews (order is not significant; lookups are by id).
@export var crews: Array[CrewDef] = []
## Board data used for shape validation (board-rules rule 3).
@export var board_config: BoardConfig
## Palette rows available for [member CrewDef.colour_slot] (MVP 6).
@export var palette_slot_count: int = 6
## Maximum shapes per crew (rule 12).
@export var max_shapes_per_crew: int = 8
## Lint: shapes no other crew uses (rule 4).
@export var min_signature_shapes: int = 2
## Lint: expected piece size E × 100, lower bound (F2).
@export var expected_cells_lint_min_x100: int = 200
## Lint: expected piece size E × 100, upper bound (F2).
@export var expected_cells_lint_max_x100: int = 500

var _warnings: PackedStringArray = PackedStringArray()
var _table: AbilityTable
var _by_id: Dictionary = {}
var _validated: bool = false

const _ID_PATTERN := "^[a-z][a-z0-9_]*$"


## Validates the whole registry (rule 12). Returns load errors (empty = OK).
## Lint warnings are available from [method warnings]. On success the read-only
## [AbilityTable] for the whole registry becomes available from [method abilities].
func load_and_validate() -> PackedStringArray:
	var errors := PackedStringArray()
	_warnings = PackedStringArray()
	_by_id = {}
	_table = null
	_validated = false
	var config: BoardConfig = board_config if board_config != null else BoardConfig.new()
	var id_re := RegEx.create_from_string(_ID_PATTERN)
	var seen_ids := {}
	var seen_ability_ids := {}
	var seen_colour := {}
	var seen_silhouette := {}
	var seen_pattern := {}
	var shape_users := {}  # shape id -> {crew id: true}

	for crew: CrewDef in crews:
		if crew == null:
			errors.append("crew <null>: entry is null")
			continue
		var cid := String(crew.id)
		var tag := "crew %s" % cid
		if id_re.search(cid) == null:
			errors.append("%s: id: must be lower snake case" % tag)
		if seen_ids.has(crew.id):
			errors.append("%s: id: duplicate id" % tag)
		seen_ids[crew.id] = true
		if crew.colour_slot < 1 or crew.colour_slot > palette_slot_count:
			errors.append("%s: colour_slot: %d out of range 1..%d" % [tag, crew.colour_slot, palette_slot_count])
		_check_unique(errors, seen_colour, crew.colour_slot, tag, "colour_slot")
		_check_unique(errors, seen_silhouette, crew.silhouette_feature, tag, "silhouette_feature")
		_check_unique(errors, seen_pattern, crew.body_pattern, tag, "body_pattern")

		# shapes
		if crew.shapes.is_empty() or crew.shapes.size() > max_shapes_per_crew:
			errors.append("%s: shapes: count %d out of range 1..%d" % [tag, crew.shapes.size(), max_shapes_per_crew])
		var own_shapes := {}
		var own_offsets := {}
		for entry: CrewShapeEntry in crew.shapes:
			if entry == null or entry.shape == null:
				errors.append("%s: shapes: null entry" % tag)
				continue
			for e: String in BoardRules.validate_shape(entry.shape, config):
				errors.append("%s: shapes: %s" % [tag, e])
			if entry.weight < 1:
				errors.append("%s: shapes: weight %d < 1 (shape %s)" % [tag, entry.weight, entry.shape.id])
			var n := entry.shape.cell_count()
			if entry.face_cell != -1 and (entry.face_cell < 0 or entry.face_cell >= n):
				errors.append("%s: shapes: face_cell %d out of range (shape %s)" % [tag, entry.face_cell, entry.shape.id])
			var okey := _offsets_key(entry.shape)
			if own_shapes.has(entry.shape.id) or own_offsets.has(okey):
				errors.append("%s: shapes: duplicate shape %s" % [tag, entry.shape.id])
			own_shapes[entry.shape.id] = true
			own_offsets[okey] = true
			if not shape_users.has(entry.shape.id):
				shape_users[entry.shape.id] = {}
			shape_users[entry.shape.id][crew.id] = true

		# ability
		if crew.ability == null or crew.ability.steps.is_empty():
			errors.append("%s: ability.steps: empty ability" % tag)
		else:
			if seen_ability_ids.has(crew.ability.ability_id) or crew.ability.ability_id == &"":
				errors.append("%s: ability.ability_id: missing or duplicate '%s'" % [tag, crew.ability.ability_id])
			seen_ability_ids[crew.ability.ability_id] = true
			var has_fill := false
			for step: AbilityStep in crew.ability.steps:
				if step == null:
					errors.append("%s: ability.steps: null step" % tag)
					continue
				for e: String in PrimitiveLibrary.validate(step.primitive, step.params):
					errors.append("%s: ability.steps.primitive: %s" % [tag, e])
				if PrimitiveLibrary.kind_of(step.primitive) == PrimitiveLibrary.KIND_FILL:
					has_fill = true
			if has_fill and crew.fill_visual == &"":
				errors.append("%s: fill_visual: required for a FILL primitive" % tag)

		# lint: expected piece size
		var e_x100 := expected_cells_x100(crew)
		if e_x100 < expected_cells_lint_min_x100 or e_x100 > expected_cells_lint_max_x100:
			_warnings.append("%s: expected piece size E x100 = %d outside %d..%d" % [tag, e_x100, expected_cells_lint_min_x100, expected_cells_lint_max_x100])

	# lint: signature shapes (rule 4)
	for crew: CrewDef in crews:
		if crew == null:
			continue
		var signature := 0
		for entry: CrewShapeEntry in crew.shapes:
			if entry != null and entry.shape != null and (shape_users.get(entry.shape.id, {}) as Dictionary).size() == 1:
				signature += 1
		if signature < min_signature_shapes:
			_warnings.append("crew %s: signature shapes < %d (%d)" % [crew.id, min_signature_shapes, signature])

	# rule 7 / 10: "same ability, only size differs"
	for i: int in crews.size():
		for j: int in range(i + 1, crews.size()):
			var a := crews[i]
			var b := crews[j]
			if a == null or b == null or not _same_shape_ability(a.ability, b.ability):
				continue
			if a.rarity != b.rarity:
				errors.append("crew %s: ability: differs from crew %s only in size parameters across rarities" % [b.id, a.id])
			else:
				_warnings.append("crew %s: ability: differs from crew %s only in size parameters" % [b.id, a.id])

	if errors.is_empty():
		_build_table()
		_validated = true
	return errors


## Lint warnings from the last [method load_and_validate].
func warnings() -> PackedStringArray:
	return _warnings


## Read-only resolver ability table for the whole registry (rule 8); null until
## [method load_and_validate] succeeded.
func abilities() -> AbilityTable:
	return _table


## The crew with [param crew_id], or null. (Named get_crew: [code]get[/code] is an
## [Object] method.)
func get_crew(crew_id: StringName) -> CrewDef:
	return _by_id.get(crew_id, null)


## Every crew, registry order.
func all() -> Array[CrewDef]:
	return crews.duplicate()


## Ids of crews with [member CrewDef.starter], sorted.
func starter_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for c: CrewDef in crews:
		if c != null and c.starter:
			out.append(c.id)
	out.sort_custom(AbilityTable.by_text)
	return out


## Ids of crews with [member CrewDef.obtainable], sorted.
func obtainable_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for c: CrewDef in crews:
		if c != null and c.obtainable:
			out.append(c.id)
	out.sort_custom(AbilityTable.by_text)
	return out


## crew-definition F2: expected piece size × 100 (integer division).
static func expected_cells_x100(crew: CrewDef) -> int:
	var total_w := 0
	var sum := 0
	for entry: CrewShapeEntry in crew.shapes:
		if entry == null or entry.shape == null:
			continue
		total_w += entry.weight
		sum += entry.weight * entry.shape.cell_count()
	if total_w <= 0:
		return 0
	return sum * 100 / total_w


func _build_table() -> void:
	var spec := {}
	for crew: CrewDef in crews:
		var steps: Array = []
		for step: AbilityStep in crew.ability.steps:
			steps.append({AbilityTable.K_PRIMITIVE: step.primitive, AbilityTable.K_PARAMS: step.params})
		spec[crew.id] = {&"ability_id": crew.ability.ability_id, &"steps": steps}
		_by_id[crew.id] = crew
	_table = AbilityTable.create(spec)


static func _check_unique(errors: PackedStringArray, seen: Dictionary, value: Variant, tag: String, field: String) -> void:
	if seen.has(value):
		errors.append("%s: %s: duplicate value '%s' (also crew %s)" % [tag, field, value, seen[value]])
	else:
		seen[value] = tag.trim_prefix("crew ")


static func _offsets_key(shape: PieceShape) -> String:
	var parts: Array[String] = []
	for o: Vector2i in shape.offsets:
		parts.append("%d,%d" % [o.x, o.y])
	parts.sort()
	return ";".join(parts)


static func _same_shape_ability(a: CrewAbility, b: CrewAbility) -> bool:
	if a == null or b == null or a.steps.size() != b.steps.size():
		return false
	for i: int in a.steps.size():
		var sa := a.steps[i]
		var sb := b.steps[i]
		if sa == null or sb == null or sa.primitive != sb.primitive:
			return false
		for key: StringName in PrimitiveLibrary.SHAPE_PARAMS:
			if _param(sa.params, key) != _param(sb.params, key):
				return false
	return true


static func _param(params: Dictionary, key: StringName) -> Variant:
	if params.has(key):
		return params[key]
	return params.get(String(key), null)
