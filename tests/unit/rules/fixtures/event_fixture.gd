## Hand-written resolver event lists for scoring tests (scoring AC preamble:
## scoring fixtures do not run the resolver). Builder style:
## [codeblock]
## var ev := EventFixture.new().placed(1).wave(0, 1, 0).cleared(0, 8).activated(0, 1).end()
## [/codeblock]
class_name EventFixture
extends RefCounted

var _events: Array[ChainEvent] = []
var _crew: StringName = &"nyangi"


## Crew id written into subsequent cleared cells / activations.
func crew(crew_id: StringName) -> EventFixture:
	_crew = crew_id
	return self


## PLACED with [param n] cells.
func placed(n: int) -> EventFixture:
	var cells := []
	for i: int in n:
		cells.append(Vector2i(0, i))
	return _add(ChainEvent.Type.PLACED, -1, {ChainEvent.K_CREW_ID: _crew, ChainEvent.K_ANCHOR: Vector2i(0, 0), ChainEvent.K_CELLS: cells, ChainEvent.K_FACE_CELL: ChainEvent.NO_CELL})


## WAVE_BEGIN with [param rows] rows and [param cols] columns.
func wave(k: int, rows: int, cols: int) -> EventFixture:
	var r := []
	var c := []
	for i: int in rows:
		r.append(i)
	for i: int in cols:
		c.append(i)
	var causes := []
	if rows + cols > 0:
		causes.append(ChainEvent.CAUSE_LINE)
	return _add(ChainEvent.Type.WAVE_BEGIN, k, {ChainEvent.K_WAVE: k, ChainEvent.K_CAUSES: causes, ChainEvent.K_ROWS: r, ChainEvent.K_COLS: c})


## CELLS_CLEARED with the given counts per [code]by[/code] and [param kept] kept cells.
func cleared(k: int, line: int, ability: int = 0, both: int = 0, kept: int = 0) -> EventFixture:
	var cells := []
	var n := 0
	for spec: Array in [[line, ChainEvent.BY_LINE], [ability, ChainEvent.BY_ABILITY], [both, ChainEvent.BY_BOTH]]:
		for i: int in spec[0]:
			cells.append({ChainEvent.K_R: n / 8, ChainEvent.K_C: n % 8, ChainEvent.K_CREW_ID: _crew, ChainEvent.K_IS_FACE: false,
				ChainEvent.K_ORIGIN: BoardState.ORIGIN_PIECE, ChainEvent.K_BY: spec[1], ChainEvent.K_SOURCE_ORDER: -1})
			n += 1
	var kept_cells := []
	for i: int in kept:
		kept_cells.append(Vector2i(7, i))
		_add(ChainEvent.Type.CELL_MODIFIED, k, {ChainEvent.K_CELL: Vector2i(7, i), ChainEvent.K_MODIFIERS_BEFORE: PackedInt32Array([1]), ChainEvent.K_MODIFIERS_AFTER: PackedInt32Array()})
	return _add(ChainEvent.Type.CELLS_CLEARED, k, {ChainEvent.K_WAVE: k, ChainEvent.K_CELLS: cells,
		ChainEvent.K_LINE_CELL_COUNT: line + both, ChainEvent.K_ABILITY_CELL_COUNT: ability, ChainEvent.K_KEPT: kept_cells})


## [param n] FACE_ACTIVATED events in wave [param k].
func activated(k: int, n: int) -> EventFixture:
	for i: int in n:
		_add(ChainEvent.Type.FACE_ACTIVATED, k, {ChainEvent.K_ORDER_INDEX: _events.size(), ChainEvent.K_CELL: Vector2i(k, i),
			ChainEvent.K_CREW_ID: _crew, ChainEvent.K_ABILITY_ID: &"test", ChainEvent.K_STAGE: k + 1})
	return self


## [param n] FACE_FIZZLED events in wave [param k].
func fizzled(k: int, n: int, reason: StringName = ChainEvent.REASON_DEPTH_CAP) -> EventFixture:
	for i: int in n:
		_add(ChainEvent.Type.FACE_FIZZLED, k, {ChainEvent.K_CELL: Vector2i(k, i), ChainEvent.K_CREW_ID: _crew, ChainEvent.K_REASON: reason})
	return self


## DEPTH_CAP_REACHED in wave [param k].
func cap(k: int) -> EventFixture:
	return _add(ChainEvent.Type.DEPTH_CAP_REACHED, k, {ChainEvent.K_WAVE: k})


## Appends CHAIN_END (summary values are not read by scoring).
func end() -> Array[ChainEvent]:
	_add(ChainEvent.Type.CHAIN_END, -1, {})
	return _events


func _add(t: ChainEvent.Type, k: int, data: Dictionary) -> EventFixture:
	_events.append(ChainEvent.make(_events.size(), t, k, data))
	return self


## AC-S09 domino golden: 1-cell placement; wave 0 row 8 LINE + nyangi; wave 1
## ABILITY 7 + gomgom; wave 2 ABILITY 6.
static func domino_golden() -> Array[ChainEvent]:
	return EventFixture.new().placed(1) \
		.wave(0, 1, 0).cleared(0, 8).activated(0, 1) \
		.wave(1, 0, 0).cleared(1, 0, 7).activated(1, 1) \
		.wave(2, 0, 0).cleared(2, 0, 6).end()
