## Ability primitive vocabulary (chain-resolver rule 14, ADR-0001 Decision 8).
##
## Each primitive id maps to a static executor and a parameter validator. All
## coordinates are relative to the activating face (fr, fc); off-board cells are
## dropped. CLEAR executors return the raw geometric target cells on the snapshot
## (row-major, face cell included) — the resolver keeps only filled cells and
## applies [code]target_filter[/code]. FILL executors return egg cells in lay order,
## empty cells only. No MVP primitive uses randomness (rule 24).
class_name PrimitiveLibrary
extends RefCounted

## Primitive kind: target cells are cleared next wave.
const KIND_CLEAR := 0
## Primitive kind: cells are filled immediately with eggs.
const KIND_FILL := 1
## Unknown primitive id.
const KIND_UNKNOWN := -1

const CLEAR_CROSS := &"clear_cross"
const CLEAR_LINE := &"clear_line"
const CLEAR_AREA := &"clear_area"
const CLEAR_DIAGONALS := &"clear_diagonals"
const CLEAR_PATTERN := &"clear_pattern"
const LAY_EGGS_IN_OWN_LINE := &"lay_eggs_in_own_line"
const LAY_EGGS_PATTERN := &"lay_eggs_pattern"

const P_REACH := &"reach"
const P_AXIS := &"axis"
const P_RADIUS := &"radius"
const P_OFFSETS := &"offsets"
const P_COUNT := &"count"
const P_PREFER := &"prefer"
const P_ORDER := &"order"

## Rule 14 defaults (tuning values live in crew data; these apply when a key is absent).
const DEFAULT_REACH := -1
const DEFAULT_RADIUS := 1
const DEFAULT_COUNT := 3
const DEFAULT_PREFER := &"fuller"
const DEFAULT_ORDER := &"nearest"

const _AXES: Array[StringName] = [&"row", &"col"]
const _PREFERS: Array[StringName] = [&"fuller", &"emptier", &"row", &"col"]
const _ORDERS: Array[StringName] = [&"nearest", &"row_major"]

## id -> {kind, allowed param keys, required param keys}.
const _SPECS := {
	&"clear_cross": {&"kind": KIND_CLEAR, &"allowed": [&"reach"], &"required": []},
	&"clear_line": {&"kind": KIND_CLEAR, &"allowed": [&"axis", &"reach"], &"required": [&"axis"]},
	&"clear_area": {&"kind": KIND_CLEAR, &"allowed": [&"radius"], &"required": []},
	&"clear_diagonals": {&"kind": KIND_CLEAR, &"allowed": [&"reach"], &"required": []},
	&"clear_pattern": {&"kind": KIND_CLEAR, &"allowed": [&"offsets"], &"required": [&"offsets"]},
	&"lay_eggs_in_own_line": {&"kind": KIND_FILL, &"allowed": [&"count", &"prefer", &"order"], &"required": []},
	&"lay_eggs_pattern": {&"kind": KIND_FILL, &"allowed": [&"offsets"], &"required": [&"offsets"]},
}

## Parameters that change an ability's *shape* (crew-definition rule 7(b)); the
## rest ([code]reach[/code], [code]radius[/code], [code]count[/code]) are size parameters.
const SHAPE_PARAMS: Array[StringName] = [&"axis", &"offsets", &"prefer", &"order"]


## All primitive ids, in rule 14 table order.
static func ids() -> Array[StringName]:
	return [CLEAR_CROSS, CLEAR_LINE, CLEAR_AREA, CLEAR_DIAGONALS, CLEAR_PATTERN, LAY_EGGS_IN_OWN_LINE, LAY_EGGS_PATTERN]


## [constant KIND_CLEAR], [constant KIND_FILL] or [constant KIND_UNKNOWN].
static func kind_of(primitive: StringName) -> int:
	if not _SPECS.has(primitive):
		return KIND_UNKNOWN
	return _SPECS[primitive][&"kind"]


## Rule 18 load-time validation of one step (empty = valid).
static func validate(primitive: StringName, params: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not _SPECS.has(primitive):
		errors.append("unknown primitive '%s'" % primitive)
		return errors
	var spec: Dictionary = _SPECS[primitive]
	var allowed: Array = spec[&"allowed"]
	for key: Variant in params.keys():
		if not allowed.has(StringName(key)):
			errors.append("%s: unknown param '%s'" % [primitive, key])
	for key: StringName in spec[&"required"]:
		if not _param_has(params, key):
			errors.append("%s: missing param '%s'" % [primitive, key])
	if _param_has(params, P_REACH):
		var v: Variant = _param_get(params, P_REACH, null)
		if typeof(v) != TYPE_INT or int(v) < -1:
			errors.append("%s: reach must be an int >= -1 (got %s)" % [primitive, v])
	if _param_has(params, P_RADIUS):
		var v: Variant = _param_get(params, P_RADIUS, null)
		if typeof(v) != TYPE_INT or int(v) < 0:
			errors.append("%s: radius must be an int >= 0 (got %s)" % [primitive, v])
	if _param_has(params, P_COUNT):
		var v: Variant = _param_get(params, P_COUNT, null)
		if typeof(v) != TYPE_INT or int(v) < 1:
			errors.append("%s: count must be an int >= 1 (got %s)" % [primitive, v])
	if _param_has(params, P_OFFSETS):
		var v: Variant = _param_get(params, P_OFFSETS, null)
		if not (v is Array) or (v as Array).is_empty():
			errors.append("%s: offsets must be a non-empty array" % primitive)
		else:
			for o: Variant in (v as Array):
				if typeof(o) != TYPE_VECTOR2I:
					errors.append("%s: offsets entries must be Vector2i (got %s)" % [primitive, o])
					break
	_check_enum(errors, primitive, params, P_AXIS, _AXES)
	_check_enum(errors, primitive, params, P_PREFER, _PREFERS)
	_check_enum(errors, primitive, params, P_ORDER, _ORDERS)
	return errors


## Runs a primitive for the face at [param face_cell] (cell index) on
## [param snapshot]. See the class description for CLEAR/FILL semantics.
## [param ctx] is accepted for the rule 17 contract (rng stream); MVP ignores it.
@warning_ignore("unused_parameter")
static func execute(primitive: StringName, params: Dictionary, snapshot: BoardState, face_cell: int, ctx: ResolveContext) -> PackedInt32Array:
	var face := snapshot.cell_of(face_cell)
	match primitive:
		CLEAR_CROSS:
			return _cross(snapshot, face, int(_param_get(params, P_REACH, DEFAULT_REACH)))
		CLEAR_LINE:
			return _line(snapshot, face, StringName(_param_get(params, P_AXIS, &"row")), int(_param_get(params, P_REACH, DEFAULT_REACH)))
		CLEAR_AREA:
			return _area(snapshot, face, int(_param_get(params, P_RADIUS, DEFAULT_RADIUS)))
		CLEAR_DIAGONALS:
			return _diagonals(snapshot, face, int(_param_get(params, P_REACH, DEFAULT_REACH)))
		CLEAR_PATTERN:
			return _pattern(snapshot, face, _param_get(params, P_OFFSETS, []), false)
		LAY_EGGS_IN_OWN_LINE:
			return _eggs_in_own_line(snapshot, face, int(_param_get(params, P_COUNT, DEFAULT_COUNT)),
					StringName(_param_get(params, P_PREFER, DEFAULT_PREFER)), StringName(_param_get(params, P_ORDER, DEFAULT_ORDER)))
		LAY_EGGS_PATTERN:
			return _pattern(snapshot, face, _param_get(params, P_OFFSETS, []), true)
	push_error("PrimitiveLibrary.execute: unknown primitive '%s'" % primitive)
	return PackedInt32Array()


# --- CLEAR executors -----------------------------------------------------------

static func _within(dist: int, reach: int) -> bool:
	return reach < 0 or dist <= reach


static func _cross(b: BoardState, f: Vector2i, reach: int) -> PackedInt32Array:
	var mark := _blank(b)
	for c: int in b.width:
		if _within(absi(c - f.y), reach):
			mark[b.index_of(f.x, c)] = 1
	for r: int in b.height:
		if _within(absi(r - f.x), reach):
			mark[b.index_of(r, f.y)] = 1
	return _collect(mark)


static func _line(b: BoardState, f: Vector2i, axis: StringName, reach: int) -> PackedInt32Array:
	var mark := _blank(b)
	if axis == &"col":
		for r: int in b.height:
			if _within(absi(r - f.x), reach):
				mark[b.index_of(r, f.y)] = 1
	else:
		for c: int in b.width:
			if _within(absi(c - f.y), reach):
				mark[b.index_of(f.x, c)] = 1
	return _collect(mark)


static func _area(b: BoardState, f: Vector2i, radius: int) -> PackedInt32Array:
	var mark := _blank(b)
	for r: int in range(f.x - radius, f.x + radius + 1):
		for c: int in range(f.y - radius, f.y + radius + 1):
			if b.in_bounds(r, c):
				mark[b.index_of(r, c)] = 1
	return _collect(mark)


static func _diagonals(b: BoardState, f: Vector2i, reach: int) -> PackedInt32Array:
	var mark := _blank(b)
	for r: int in b.height:
		var d := absi(r - f.x)
		if not _within(d, reach):
			continue
		for c: int in [f.y - d, f.y + d]:
			if b.in_bounds(r, c):
				mark[b.index_of(r, c)] = 1
	return _collect(mark)


## CLEAR: offsets → in-bounds cells row-major. FILL: offsets in list order, empty
## cells only (crew-definition rule 14 note: lay order = offsets order).
static func _pattern(b: BoardState, f: Vector2i, offsets: Variant, fill: bool) -> PackedInt32Array:
	var out := PackedInt32Array()
	if not (offsets is Array):
		return out
	if fill:
		var seen := {}
		for o: Vector2i in (offsets as Array):
			var p := f + o
			if not b.in_bounds(p.x, p.y):
				continue
			var idx := b.index_of(p.x, p.y)
			if b.blocks_placement(idx) or seen.has(idx):
				continue
			seen[idx] = true
			out.append(idx)
		return out
	var mark := _blank(b)
	for o: Vector2i in (offsets as Array):
		var p := f + o
		if b.in_bounds(p.x, p.y):
			mark[b.index_of(p.x, p.y)] = 1
	return _collect(mark)


# --- FILL executors ------------------------------------------------------------

## chain-resolver F5. [param b] is the current board (earlier FILLs of the same
## wave already applied — rule 16).
static func _eggs_in_own_line(b: BoardState, f: Vector2i, count: int, prefer: StringName, order: StringName) -> PackedInt32Array:
	var e_row := BoardRules.empty_cells_in_line(b, BoardRules.AXIS_ROW, f.x)
	var e_col := BoardRules.empty_cells_in_line(b, BoardRules.AXIS_COL, f.y)
	var use_col := false
	match prefer:
		&"fuller":
			use_col = e_col.size() < e_row.size()
		&"emptier":
			use_col = e_col.size() > e_row.size()
		&"col":
			use_col = true
		_:
			use_col = false
	var chosen := e_col if use_col else e_row
	if chosen.is_empty():
		chosen = e_row if use_col else e_col
	var cells: Array = Array(chosen)
	if order == &"nearest":
		var w := b.width
		cells.sort_custom(func(a: int, bb: int) -> bool:
			var da := absi(a / w - f.x) + absi(a % w - f.y)
			var db := absi(bb / w - f.x) + absi(bb % w - f.y)
			if da != db:
				return da < db
			return a < bb)
	var out := PackedInt32Array()
	for i: int in mini(count, cells.size()):
		out.append(cells[i])
	return out


# --- helpers -------------------------------------------------------------------

static func _blank(b: BoardState) -> PackedByteArray:
	var mark := PackedByteArray()
	mark.resize(b.cell_count())
	mark.fill(0)
	return mark


static func _collect(mark: PackedByteArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i: int in mark.size():
		if mark[i] != 0:
			out.append(i)
	return out


## Params may use StringName or String keys (ADR-0001 Risks: both look up the same).
static func _param_has(params: Dictionary, key: StringName) -> bool:
	return params.has(key) or params.has(String(key))


static func _param_get(params: Dictionary, key: StringName, fallback: Variant) -> Variant:
	if params.has(key):
		return params[key]
	if params.has(String(key)):
		return params[String(key)]
	return fallback


static func _check_enum(errors: PackedStringArray, primitive: StringName, params: Dictionary, key: StringName, allowed: Array[StringName]) -> void:
	if not _param_has(params, key):
		return
	var v: Variant = _param_get(params, key, null)
	if not (v is StringName or v is String) or not allowed.has(StringName(v)):
		errors.append("%s: %s must be one of %s (got %s)" % [primitive, key, allowed, v])
