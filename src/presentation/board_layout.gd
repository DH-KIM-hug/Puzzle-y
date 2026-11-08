## Portrait screen layout for the T0 greybox (720×1280 canvas): HUD strip,
## banner band (chain-preview rule 23), 8×8 board, tray of N slots.
## Pure geometry; the game screen and the input controller both read it.
## [codeblock]
## var lay := BoardLayout.make(Vector2(720, 1280), 8, 8, 3)
## var r := lay.cell_rect(Vector2i(2, 3))
## [/codeblock]
class_name BoardLayout
extends RefCounted

## Canvas size.
var canvas: Vector2
## Board top-left.
var board_origin: Vector2
## Cell size.
var s: float
## Board size (rows, cols).
var cells: Vector2i
## HUD strip.
var hud_rect: Rect2
## Banner band between HUD and board.
var banner_rect: Rect2
## Whole tray.
var tray_rect: Rect2
## Tray slot count.
var slots: int = 3

## Side gutter (canvas px).
const SIDE := 16.0
const HUD_H := 120.0
const BANNER_H := 96.0
const TRAY_GAP := 34.0


## Layout for [param p_canvas].
static func make(p_canvas: Vector2, rows: int, cols: int, p_slots: int) -> BoardLayout:
	var l := BoardLayout.new()
	l.canvas = p_canvas
	l.cells = Vector2i(rows, cols)
	l.slots = p_slots
	l.s = floorf((p_canvas.x - SIDE * 2.0) / cols)
	var board_w := l.s * cols
	l.hud_rect = Rect2(0, 0, p_canvas.x, HUD_H)
	l.banner_rect = Rect2(SIDE, HUD_H, p_canvas.x - SIDE * 2.0, BANNER_H)
	l.board_origin = Vector2((p_canvas.x - board_w) * 0.5, HUD_H + BANNER_H + 8.0)
	var tray_top := l.board_origin.y + l.s * rows + TRAY_GAP
	l.tray_rect = Rect2(SIDE, tray_top, p_canvas.x - SIDE * 2.0, p_canvas.y - tray_top - SIDE)
	return l


## Canvas rect of board cell (row, col).
func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(board_origin + Vector2(cell.y, cell.x) * s, Vector2(s, s))


## Canvas centre of a (fractional) cell coordinate (row, col).
func cell_center(cell: Vector2) -> Vector2:
	return board_origin + Vector2(cell.y + 0.5, cell.x + 0.5) * s


## Board rect.
func board_rect() -> Rect2:
	return Rect2(board_origin, Vector2(cells.y, cells.x) * s)


## Hit rect of tray slot [param i] (placement-input rule 4: the whole slot).
func slot_rect(i: int) -> Rect2:
	var w := tray_rect.size.x / slots
	return Rect2(tray_rect.position + Vector2(w * i, 0), Vector2(w, tray_rect.size.y))


## Tray slot index under [param p], or -1.
func slot_at(p: Vector2) -> int:
	for i: int in slots:
		if slot_rect(i).has_point(p):
			return i
	return -1


## F6: tray cell size for a (w, h) piece: tray_piece_scale × s, shrunk to fit the slot.
func tray_cell(size: Vector2i, scale: float, margin: float) -> float:
	var r := slot_rect(0)
	var cs := scale * s
	cs = minf(cs, (r.size.x - 2.0 * margin) / size.x)
	cs = minf(cs, (r.size.y - 2.0 * margin) / size.y)
	return cs
