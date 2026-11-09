## Crew facts for the team-select screen (team-composition rule 19, crew-definition
## UI Requirements): the ability diagram (5×5 mini grid, face in the centre,
## target cells computed by running the crew's REAL primitives through
## [PrimitiveLibrary] — no hand-drawn per-crew tables) and the piece shapes with
## "자주 / 가끔" (weight = the crew's top weight → 자주).
## [codeblock]
## var cells := CrewCardPainter.ability_cells(def)   # {clear: [...], fill: [...]}
## CrewCardPainter.diagram(ci, Rect2(250, 14, 70, 70), def, look)
## [/codeblock]
class_name CrewCardPainter
extends RefCounted

## Diagram grid size (odd; face at the centre).
const GRID := 5
const K_CLEAR := &"clear"
const K_FILL := &"fill"

static var _cache: Dictionary = {}


## Cells (Vector2i row, col on the GRID×GRID board) the ability clears / fills when
## the face sits in the centre. Cached per crew id.
static func ability_cells(def: CrewDef) -> Dictionary:
	if _cache.has(def.id):
		return _cache[def.id]
	var clear: Array[Vector2i] = []
	var fill: Array[Vector2i] = []
	var mid := GRID / 2
	if def.ability != null:
		for step: AbilityStep in def.ability.steps:
			var kind := PrimitiveLibrary.kind_of(step.primitive)
			var b := BoardState.create(GRID, GRID, ObstacleRules.kind_table())
			if kind == PrimitiveLibrary.KIND_CLEAR:
				for i: int in b.cell_count():
					b.set_tile(i, &"x", false, BoardState.ORIGIN_PIECE, 1)
			b.set_tile(b.index_of(mid, mid), def.id, true, BoardState.ORIGIN_PIECE, 1)
			var out := PrimitiveLibrary.execute(step.primitive, step.params, b, b.index_of(mid, mid), null)
			for idx: int in out:
				var cell := b.cell_of(idx)
				if kind == PrimitiveLibrary.KIND_FILL:
					if not fill.has(cell):
						fill.append(cell)
				elif not clear.has(cell):
					clear.append(cell)
	var res := {K_CLEAR: clear, K_FILL: fill}
	_cache[def.id] = res
	return res


## Ability diagram inside [param r] (square): paper grid, ink "X" on cleared cells,
## cream eggs on filled cells, the crew-colour face cell in the centre.
static func diagram(ci: CanvasItem, r: Rect2, def: CrewDef, look: Dictionary) -> void:
	var cs := r.size.x / GRID
	var cells := ability_cells(def)
	StickerPainter.rounded(ci, r.grow(3), Palette.KRAFT_SHADE, 6)
	var mid := GRID / 2
	for row: int in GRID:
		for col: int in GRID:
			var cr := Rect2(r.position + Vector2(col, row) * cs, Vector2(cs, cs)).grow(-1)
			StickerPainter.rounded(ci, cr, Palette.BOARD_PAPER, 3)
	for cell: Vector2i in cells[K_CLEAR]:
		if cell == Vector2i(mid, mid):
			continue
		var cr := Rect2(r.position + Vector2(cell.y, cell.x) * cs, Vector2(cs, cs)).grow(-cs * 0.2)
		ci.draw_line(cr.position, cr.end, Palette.INK, maxf(1.5, cs * 0.16), true)
		ci.draw_line(Vector2(cr.end.x, cr.position.y), Vector2(cr.position.x, cr.end.y), Palette.INK, maxf(1.5, cs * 0.16), true)
	for cell: Vector2i in cells[K_FILL]:
		var c := r.position + (Vector2(cell.y, cell.x) + Vector2(0.5, 0.5)) * cs
		StickerPainter.ellipse(ci, c, Vector2(cs * 0.3, cs * 0.38), Palette.FACE_CREAM)
		StickerPainter.ellipse_outline(ci, c, Vector2(cs * 0.3, cs * 0.38), Palette.INK, maxf(1.2, cs * 0.08))
	var fc := Rect2(r.position + Vector2(mid, mid) * cs, Vector2(cs, cs)).grow(-1)
	StickerPainter.rounded(ci, fc, look[CrewVisuals.K_BASE], 3)
	ci.draw_circle(fc.get_center(), cs * 0.24, Palette.FACE_CREAM, true, -1.0, true)


## Piece shapes row: each shape fits a [param box]² cell, a fixed face cell is marked
## with a cream dot (random-face shapes have none), "자주 / 가끔" under it. Returns the drawn width.
static func shapes(ci: CanvasItem, origin: Vector2, box: float, gap: float, def: CrewDef, look: Dictionary, font: Font, font_size: int) -> float:
	var top := 0
	for e: CrewShapeEntry in def.shapes:
		top = maxi(top, e.weight)
	var x := 0.0
	for e: CrewShapeEntry in def.shapes:
		if e.shape == null:
			continue
		var w := e.shape.width()
		var h := e.shape.height()
		var cs := floorf(box / maxf(3.0, float(maxi(w, h))))
		var tl := origin + Vector2(x, 0) + (Vector2(box, box) - Vector2(w, h) * cs) * 0.5
		for k: int in e.shape.offsets.size():
			var o: Vector2i = e.shape.offsets[k]
			var cr := Rect2(tl + Vector2(o.y, o.x) * cs, Vector2(cs, cs))
			StickerPainter.rounded(ci, cr.grow(1.5), Palette.STICKER_WHITE, cs * 0.3)
		for k: int in e.shape.offsets.size():
			var o: Vector2i = e.shape.offsets[k]
			var cr := Rect2(tl + Vector2(o.y, o.x) * cs, Vector2(cs, cs)).grow(-1)
			StickerPainter.rounded(ci, cr, look[CrewVisuals.K_BASE], cs * 0.25)
			# face_cell -1 = random face per piece: no fixed face dot.
			if k == e.face_cell:
				ci.draw_circle(cr.get_center(), cs * 0.26, Palette.FACE_CREAM, true, -1.0, true)
				ci.draw_circle(cr.get_center(), cs * 0.1, Palette.INK_DARK, true, -1.0, true)
		var tag := ci.tr("UI_TEAM_FREQ_OFTEN") if e.weight >= top else ci.tr("UI_TEAM_FREQ_SOMETIMES")
		var tw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		ci.draw_string(font, origin + Vector2(x + (box - tw) * 0.5, box + font_size + 2), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				Palette.INK if e.weight >= top else Palette.INK_LIGHT)
		x += box + gap
	return x
