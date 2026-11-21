## Greybox sticker drawing helpers (art-bible sections 3–4): one white cut-out
## margin around the whole piece, a ground shadow, crew-colour body with a shade
## band and a low-contrast pattern, and an over-sized face (≈110 %) with one
## silhouette feature per crew, a cream muzzle and ink features.
## Static helpers that draw on any [CanvasItem] inside its [code]_draw()[/code].
## [codeblock]
## StickerPainter.draw_piece(self, rects, face_i, look, {&"shadow": 4.0})
## [/codeblock]
class_name StickerPainter
extends RefCounted

## Face expressions (art-bible: basic / activated / sheepish).
enum Expr { NORMAL, ACTIVE, SLEEPY }

const O_ALPHA := &"alpha"
const O_SHADOW := &"shadow"
const O_GREY := &"grey"
const O_EXPR := &"expr"
const O_LIFT := &"lift"

## Corner radius as a fraction of the cell (art-bible "≈22 %").
const CORNER := 0.22
## White cut-out margin as a fraction of the cell.
const MARGIN := 0.075

static var _boxes: Dictionary = {}


## Rounded rectangle.
static func rounded(ci: CanvasItem, rect: Rect2, color: Color, radius: float) -> void:
	var key := "%s|%d" % [color.to_html(true), int(radius)]
	var sb: StyleBoxFlat = _boxes.get(key)
	if sb == null:
		sb = StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(int(radius))
		sb.anti_aliasing = true
		sb.anti_aliasing_size = 0.8
		_boxes[key] = sb
	ci.draw_style_box(sb, rect)


## Ellipse centred at [param c] with radii [param r].
static func ellipse(ci: CanvasItem, c: Vector2, r: Vector2, color: Color) -> void:
	if r.x < 0.5 or r.y < 0.5:
		return
	# Polygon, not draw_set_transform: callers may already be inside a transform.
	var pts := PackedVector2Array()
	pts.resize(24)
	for i: int in 24:
		var a := TAU * i / 24.0
		pts[i] = c + Vector2(cos(a) * r.x, sin(a) * r.y)
	ci.draw_colored_polygon(pts, color)


## Ellipse outline (polyline), transform-safe like [method ellipse].
static func ellipse_outline(ci: CanvasItem, c: Vector2, r: Vector2, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i: int in 33:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_polyline(pts, color, width, true)


## Draws a whole piece. [param rects] are the cell rects (canvas), [param face_i]
## the face cell index in [param rects] (-1 = faceless), [param look] a
## [CrewVisuals] look. Options: alpha, shadow (px), grey (bool), expr, lift (face extra px).
static func draw_piece(ci: CanvasItem, rects: Array[Rect2], face_i: int, look: Dictionary, opts: Dictionary = {}) -> void:
	if rects.is_empty():
		return
	var a: float = opts.get(O_ALPHA, 1.0)
	var shadow: float = opts.get(O_SHADOW, 2.0)
	var grey: bool = opts.get(O_GREY, false)
	var s := rects[0].size.x
	var m := s * MARGIN
	var rad := s * CORNER
	# 1. ground shadow (ink 35 %), 2. white margin — both as unions of grown rects.
	for r: Rect2 in rects:
		# Opaque pre-blended shadow: per-cell alpha would double-darken where cells overlap.
		rounded(ci, Rect2(r.position + Vector2(shadow * 0.5, shadow), r.size).grow(m), Color(Palette.BOARD_PAPER.lerp(Palette.INK, 0.35), a), rad + m)
	for r: Rect2 in rects:
		rounded(ci, r.grow(m), Color(Palette.STICKER_WHITE, a), rad + m)
	# 3. body cells.
	var base: Color = Palette.GREY_TONE if grey else look[CrewVisuals.K_BASE]
	var shade: Color = Palette.GREY_TONE.darkened(0.2) if grey else look[CrewVisuals.K_SHADE]
	for i: int in rects.size():
		draw_body_cell(ci, rects[i], base, shade, look[CrewVisuals.K_PATTERN], a)
	# 4. face on top (overflows its cell, art-bible principle 2).
	if face_i >= 0 and face_i < rects.size():
		var fr := rects[face_i]
		var lift: float = opts.get(O_LIFT, 0.0)
		draw_face(ci, fr.get_center() - Vector2(0, lift), s, look, opts.get(O_EXPR, Expr.NORMAL), a, grey)


## Board stickers in passes (all shadows, all margins, all bodies, all faces) so a
## neighbour's margin never covers a body. [param items]: {rect, look, face: bool,
## egg: bool, shadow: float}. Faces draw last so they may overflow (≈110 %).
static func draw_board_cells(ci: CanvasItem, items: Array[Dictionary]) -> void:
	if items.is_empty():
		return
	var s: float = (items[0][&"rect"] as Rect2).size.x
	var m := s * MARGIN * 0.6
	var rad := s * CORNER
	var shadow_col := Palette.BOARD_PAPER.lerp(Palette.INK, 0.35)
	for it: Dictionary in items:
		var r: Rect2 = it[&"rect"]
		var sh: float = it.get(&"shadow", 1.5)
		rounded(ci, Rect2(r.position + Vector2(sh * 0.5, sh), r.size).grow(m), shadow_col, rad + m)
	for it: Dictionary in items:
		rounded(ci, (it[&"rect"] as Rect2).grow(m), Palette.STICKER_WHITE, rad + m)
	for it: Dictionary in items:
		var look: Dictionary = it[&"look"]
		if it.get(&"egg", false):
			draw_egg_cell(ci, it[&"rect"], look)
		else:
			draw_body_cell(ci, it[&"rect"], look[CrewVisuals.K_BASE], look[CrewVisuals.K_SHADE], look[CrewVisuals.K_PATTERN], 1.0)
	for it: Dictionary in items:
		if it.get(&"face", false):
			# Optional idle life: &"breath" (size factor), &"blink" (eyelids closed), &"twinkle" (0..1 highlight).
			var fs: float = (it[&"rect"] as Rect2).size.x * float(it.get(&"breath", 1.0))
			draw_face(ci, (it[&"rect"] as Rect2).get_center(), fs, it[&"look"], it.get(&"expr", Expr.NORMAL), 1.0, false,
					it.get(&"blink", false), float(it.get(&"twinkle", 0.0)))


## One body cell: crew colour, shade band (lower quarter), low-contrast pattern.
static func draw_body_cell(ci: CanvasItem, r: Rect2, base: Color, shade: Color, pattern: StringName, a: float) -> void:
	var s := r.size.x
	var inner := r.grow(-s * 0.03)
	rounded(ci, inner, Color(shade, a), s * CORNER * 0.8)
	rounded(ci, Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.78)), Color(base, a), s * CORNER * 0.8)
	var pc := Color(base.lightened(0.14), a)
	var c := inner.get_center()
	match pattern:
		&"stripes":
			for k: int in 3:
				var y := inner.position.y + inner.size.y * (0.22 + 0.2 * k)
				ci.draw_line(Vector2(inner.position.x + s * 0.18, y), Vector2(inner.end.x - s * 0.18, y - s * 0.08), pc, s * 0.07, true)
		&"spot":
			ci.draw_circle(c + Vector2(s * 0.12, -s * 0.1), s * 0.14, pc, true, -1.0, true)
		&"dots":
			for p: Vector2 in [Vector2(-0.2, -0.18), Vector2(0.18, -0.05), Vector2(-0.05, 0.12)]:
				ci.draw_circle(c + p * s, s * 0.06, pc, true, -1.0, true)
		&"waves":
			for k: int in 2:
				var y := inner.position.y + inner.size.y * (0.3 + 0.28 * k)
				var pts := PackedVector2Array()
				for j: int in 7:
					pts.append(Vector2(inner.position.x + s * (0.15 + 0.12 * j), y + sin(j * 1.6) * s * 0.04))
				ci.draw_polyline(pts, pc, s * 0.05, true)
		&"checks":
			for p: Vector2 in [Vector2(-0.16, -0.16), Vector2(0.08, 0.08)]:
				ci.draw_rect(Rect2(c + p * s, Vector2(s, s) * 0.16), pc)
		&"curls":
			for p: Vector2 in [Vector2(-0.16, -0.12), Vector2(0.14, 0.04)]:
				ci.draw_arc(c + p * s, s * 0.09, 0.0, TAU * 0.8, 10, pc, s * 0.045, true)


## Face head (crew colour) + silhouette feature + cream muzzle + ink features.
## [param blink] closes the eyes for one idle blink frame (not an expression);
## [param twinkle] 0..1 grows the white highlight into a small star (idle sparkle).
static func draw_face(ci: CanvasItem, c: Vector2, s: float, look: Dictionary, expr: int, a: float, grey: bool = false,
		blink: bool = false, twinkle: float = 0.0) -> void:
	var base: Color = Palette.GREY_TONE if grey else look[CrewVisuals.K_BASE]
	var shade: Color = Palette.GREY_TONE.darkened(0.2) if grey else look[CrewVisuals.K_SHADE]
	var r := s * 0.55
	var white := Color(Palette.STICKER_WHITE, a)
	var feature: StringName = look[CrewVisuals.K_FEATURE]
	# Feature behind the head, with the white cut-out margin.
	_feature(ci, feature, c, r, s, base, shade, a, true)
	ci.draw_circle(c + Vector2(0, s * 0.05), r + s * 0.08, Color(Palette.INK, 0.3 * a), true, -1.0, true)
	ci.draw_circle(c, r + s * 0.07, white, true, -1.0, true)
	_feature(ci, feature, c, r, s, base, shade, a, false)
	ci.draw_circle(c, r, Color(base, a), true, -1.0, true)
	# Muzzle / cheeks.
	ellipse(ci, c + Vector2(0, r * 0.32), Vector2(r * 0.62, r * 0.42), Color(Palette.FACE_CREAM, a))
	var ink := Color(Palette.INK_DARK, a)
	var eye_y := c.y - r * 0.12
	var ex := r * 0.38
	match expr:
		Expr.ACTIVE:
			for sx: float in [-1.0, 1.0]:
				ci.draw_arc(Vector2(c.x + sx * ex, eye_y + r * 0.06), r * 0.13, PI * 1.1, PI * 1.9, 8, ink, s * 0.045, true)
			ellipse(ci, c + Vector2(0, r * 0.38), Vector2(r * 0.16, r * 0.18), ink)
		Expr.SLEEPY:
			for sx: float in [-1.0, 1.0]:
				ci.draw_line(Vector2(c.x + sx * ex - r * 0.12, eye_y), Vector2(c.x + sx * ex + r * 0.12, eye_y), ink, s * 0.045, true)
			ci.draw_line(c + Vector2(-r * 0.12, r * 0.4), c + Vector2(r * 0.12, r * 0.4), ink, s * 0.04, true)
		_ when blink:
			for sx: float in [-1.0, 1.0]:
				ci.draw_arc(Vector2(c.x + sx * ex, eye_y - r * 0.04), r * 0.11, PI * 0.1, PI * 0.9, 6, ink, s * 0.045, true)
			ci.draw_arc(c + Vector2(0, r * 0.26), r * 0.16, PI * 0.15, PI * 0.85, 8, ink, s * 0.04, true)
		_:
			for sx: float in [-1.0, 1.0]:
				ci.draw_circle(Vector2(c.x + sx * ex, eye_y), r * 0.11, ink, true, -1.0, true)
				ci.draw_circle(Vector2(c.x + sx * ex - r * 0.03, eye_y - r * 0.04), r * 0.035, white, true, -1.0, true)
			ci.draw_arc(c + Vector2(0, r * 0.26), r * 0.16, PI * 0.15, PI * 0.85, 8, ink, s * 0.04, true)
	if feature == &"feather_tuft":
		# Beak (orange is a face-only detail, art-bible).
		var b := c + Vector2(0, r * 0.2)
		ci.draw_colored_polygon(PackedVector2Array([b + Vector2(-r * 0.16, 0), b + Vector2(r * 0.16, 0), b + Vector2(0, r * 0.2)]), Color(Palette.BEAK, a))
	# Sparkle (sticker white = "touch me").
	ci.draw_circle(c + Vector2(r * 0.55, -r * 0.55), r * 0.1, white, true, -1.0, true)
	if twinkle > 0.01:
		var sc := c + Vector2(r * 0.55, -r * 0.55)
		var R := r * (0.12 + 0.28 * twinkle)
		var k := R * 0.25
		ci.draw_colored_polygon(PackedVector2Array([sc + Vector2(0, -R), sc + Vector2(k, -k), sc + Vector2(R, 0), sc + Vector2(k, k),
				sc + Vector2(0, R), sc + Vector2(-k, k), sc + Vector2(-R, 0), sc + Vector2(-k, -k)]), white)


static func _feature(ci: CanvasItem, feature: StringName, c: Vector2, r: float, s: float, base: Color, shade: Color, a: float, outline: bool) -> void:
	var grow := s * 0.07 if outline else 0.0
	var col := Color(Palette.STICKER_WHITE, a) if outline else Color(base, a)
	match feature:
		&"tri_ears":
			for sx: float in [-1.0, 1.0]:
				var b := c + Vector2(sx * r * 0.55, -r * 0.55)
				var pts := PackedVector2Array([b + Vector2(-sx * r * 0.5, r * 0.15), b + Vector2(sx * r * 0.25, -r * 0.62), b + Vector2(sx * r * 0.4, r * 0.35)])
				if outline:
					pts = _grow_poly(pts, grow)
				ci.draw_colored_polygon(pts, col)
		&"round_ears":
			for sx: float in [-1.0, 1.0]:
				var ec := c + Vector2(sx * r * 0.82, -r * 0.62)
				ci.draw_circle(ec, r * 0.3 + grow, col, true, -1.0, true)
				if not outline:
					ci.draw_circle(ec, r * 0.15, Color(shade, a), true, -1.0, true)
		&"feather_tuft":
			for k: int in 3:
				var fc := c + Vector2((k - 1) * r * 0.22, -r * 1.0 - (0.08 if k == 1 else 0.0) * r)
				ellipse(ci, fc, Vector2(r * 0.12 + grow, r * 0.28 + grow), col)
		&"long_ears":
			for sx: float in [-1.0, 1.0]:
				ellipse(ci, c + Vector2(sx * r * 0.42, -r * 1.05), Vector2(r * 0.2 + grow, r * 0.55 + grow), col)
		&"lily_pad":
			for sx: float in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(sx * r * 0.5, -r * 0.82), r * 0.3 + grow, col, true, -1.0, true)
		&"wool_curl":
			for k: int in 5:
				var ang := PI + PI * (k + 0.5) / 5.0
				ci.draw_circle(c + Vector2(cos(ang), sin(ang)) * r * 0.95, r * 0.26 + grow, col if outline else Color(Palette.STICKER_WHITE.darkened(0.04), a), true, -1.0, true)


static func _grow_poly(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var res := Geometry2D.offset_polygon(pts, d, Geometry2D.JOIN_ROUND)
	return res[0] if not res.is_empty() else pts


## Egg sticker on a board cell (origin EGG): crew body + cream egg.
static func draw_egg_cell(ci: CanvasItem, r: Rect2, look: Dictionary, a: float = 1.0) -> void:
	var s := r.size.x
	draw_body_cell(ci, r, look[CrewVisuals.K_BASE], look[CrewVisuals.K_SHADE], &"", a)
	ellipse(ci, r.get_center(), Vector2(s * 0.24, s * 0.3), Color(Palette.FACE_CREAM, a))
	ci.draw_arc(r.get_center(), s * 0.27, 0, TAU, 20, Color(Palette.INK, 0.25 * a), 1.5, true)


## Dashed rectangle outline (preview cells: ink dashes, never crew colour — rule 19).
static func dashed_rect(ci: CanvasItem, r: Rect2, color: Color, width: float, dash: float) -> void:
	var p := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i: int in 4:
		ci.draw_dashed_line(p[i], p[(i + 1) % 4], color, width, dash, true, true)


## Ink badge with a sticker-white numeral or glyph (chain-preview rule 19).
static func badge(ci: CanvasItem, c: Vector2, d: float, text: String, font: Font) -> void:
	ci.draw_circle(c + Vector2(0, 2), d * 0.5 + 2, Color(Palette.INK, 0.3), true, -1.0, true)
	ci.draw_circle(c, d * 0.5 + 2.5, Palette.STICKER_WHITE, true, -1.0, true)
	ci.draw_circle(c, d * 0.5, Palette.INK, true, -1.0, true)
	var fs := int(d * 0.7)
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	ci.draw_string(font, c + Vector2(-sz.x * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.STICKER_WHITE)


## Centred text with a sticker-white outline.
static func label(ci: CanvasItem, c: Vector2, text: String, font: Font, size: int, color: Color, outline: int = 6, outline_color: Color = Palette.STICKER_WHITE) -> void:
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var pos := c + Vector2(-sz.x * 0.5, size * 0.35)
	if outline > 0:
		ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, outline_color)
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
