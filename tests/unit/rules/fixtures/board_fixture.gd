## Board-string fixture factory shared by rules tests (board-rules / chain-resolver
## AC preamble). One string per row:
##   [code].[/code] empty · [code]#[/code] tile (no crew) · [code]E[/code] egg (piyak)
##   [code]N[/code]/[code]G[/code]/[code]P[/code] face of nyangi / gomgom / piyak
##   [code]n[/code]/[code]g[/code]/[code]p[/code] non-face tile of that crew
##   [code]X[/code]/[code]K[/code]/[code]M[/code] face of gaegul / kkangchong / mongsil
##   [code]x[/code]/[code]k[/code]/[code]m[/code] non-face tile of that crew · [code]W[/code] wool puff (mongsil egg)
##   [code]F[/code] face of the generic test crew [code]&"crew_f"[/code]
##   [code]S[/code] TEST_STONE kind (see [method stone_table]).
class_name BoardFixture
extends RefCounted

const NYANGI := &"nyangi"
const GOMGOM := &"gomgom"
const PIYAK := &"piyak"
const GAEGUL := &"gaegul"
const KKANGCHONG := &"kkangchong"
const MONGSIL := &"mongsil"
const CREW_F := &"crew_f"
## Kind id of the test-only stone (blocks, counts, not removable).
const TEST_STONE := 2

const _FACE_CREWS := {"N": NYANGI, "G": GOMGOM, "P": PIYAK, "X": GAEGUL, "K": KKANGCHONG, "M": MONGSIL, "F": CREW_F}
const _TILE_CREWS := {"n": NYANGI, "g": GOMGOM, "p": PIYAK, "x": GAEGUL, "k": KKANGCHONG, "m": MONGSIL}


## Kind table with TEST_STONE registered purely as data (board-rules AC-12).
static func stone_table() -> PackedByteArray:
	return CellKind.with_kind(CellKind.default_table(), TEST_STONE,
			CellKind.BLOCKS_PLACEMENT | CellKind.COUNTS_FOR_LINE)


## Builds a board from row strings. All rows must have the same length.
static func board(rows: Array, table: PackedByteArray = PackedByteArray()) -> BoardState:
	var h := rows.size()
	var w := String(rows[0]).length()
	var t := table if not table.is_empty() else stone_table()
	var b := BoardState.create(w, h, t)
	for r: int in h:
		var line := String(rows[r])
		if line.length() != w:
			push_error("fixture row %d has wrong length" % r)
		for c: int in w:
			var ch := line[c]
			var idx := b.index_of(r, c)
			if ch == ".":
				continue
			elif ch == "#":
				b.set_tile(idx, &"", false, BoardState.ORIGIN_PIECE, 0)
			elif ch == "E":
				b.set_tile(idx, PIYAK, false, BoardState.ORIGIN_EGG, 0)
			elif ch == "W":
				b.set_tile(idx, MONGSIL, false, BoardState.ORIGIN_EGG, 0)
			elif ch == "S":
				b.set_tile(idx, &"", false, BoardState.ORIGIN_PIECE, 0, TEST_STONE)
			elif _FACE_CREWS.has(ch):
				b.set_tile(idx, _FACE_CREWS[ch], true, BoardState.ORIGIN_PIECE, 0)
			elif _TILE_CREWS.has(ch):
				b.set_tile(idx, _TILE_CREWS[ch], false, BoardState.ORIGIN_PIECE, 0)
			else:
				push_error("unknown fixture char " + ch)
	return b


## Reads a committed board file ([code]tests/fixtures/boards/*.txt[/code]): one row
## string per line; lines starting with [code]"# "[/code] and blank lines are comments.
static func rows_from_file(path: String) -> Array:
	var rows := []
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var t := line.strip_edges()
		if t.is_empty() or t.begins_with("# "):
			continue
		rows.append(t)
	return rows


## Board from a committed board file (see [method rows_from_file]).
static func board_file(path: String, table: PackedByteArray = PackedByteArray()) -> BoardState:
	return board(rows_from_file(path), table)


## Empty board of the given size.
static func empty(w: int = 8, h: int = 8) -> BoardState:
	return BoardState.create(w, h, stone_table())


## Renders a board back to row strings (debug / golden comparison).
static func render(b: BoardState) -> Array[String]:
	var out: Array[String] = []
	for r: int in b.height:
		var s := ""
		for c: int in b.width:
			var idx := b.index_of(r, c)
			if b.kind[idx] == CellKind.EMPTY:
				s += "."
			elif b.kind[idx] == TEST_STONE:
				s += "S"
			elif b.origin(idx) == BoardState.ORIGIN_EGG:
				s += "W" if b.crew_at(idx) == MONGSIL else "E"
			elif b.is_face(idx):
				s += _letter(b.crew_at(idx), true)
			else:
				s += _letter(b.crew_at(idx), false)
		out.append(s)
	return out


## A piece from offsets [code][Vector2i(dr, dc), …][/code].
static func piece(offsets: Array, crew_id: StringName = &"", face_index: int = PieceInstance.NO_FACE, shape_id: StringName = &"T") -> PieceInstance:
	return PieceInstance.make(PieceShape.make(shape_id, offsets), crew_id, face_index)


## A faceless 1-cell piece.
static func single() -> PieceInstance:
	return piece([Vector2i(0, 0)])


static func _letter(crew_id: StringName, face: bool) -> String:
	var map := {NYANGI: "n", GOMGOM: "g", PIYAK: "p", GAEGUL: "x", KKANGCHONG: "k", MONGSIL: "m", CREW_F: "f"}
	if crew_id == &"":
		return "#"
	var l: String = map.get(crew_id, "x")
	return l.to_upper() if face else l
