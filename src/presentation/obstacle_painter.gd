## Obstacle and goal-mark drawing (design/gdd/obstacles.md Visual/Audio + UI
## Requirements, art-bible §4 "방해물", stage-goals "목표 칸 표식").
## Readable without colour: stone = pebble silhouette + stipple, ice = crystal
## facet + ink hatching whose DIRECTION COUNT = layers (1 = "/", 2 = "/" + "\"),
## frozen face = the face shows through a thinner facet. No white cut-out margin
## on obstacles (white = touchable) and no ground shadow on stones (embedded).
## [codeblock]
## ObstaclePainter.stone(ci, rect)
## ObstaclePainter.ice(ci, rect, 2, false)
## ObstaclePainter.target_ring(ci, rect, 0.0, false)
## [/codeblock]
class_name ObstaclePainter
extends RefCounted


## Stone: a rounded pebble a little smaller than the cell, stippled, no shadow.
static func stone(ci: CanvasItem, r: Rect2) -> void:
	var s := r.size.x
	var c := r.get_center()
	var pts := PackedVector2Array()
	for i: int in 14:
		var a := TAU * i / 14.0
		# Slightly irregular "cut" outline (deterministic per vertex).
		var k := 0.40 + 0.035 * sin(a * 3.0 + 0.7) + 0.02 * cos(a * 5.0)
		pts.append(c + Vector2(cos(a) * s * k * 1.04, sin(a) * s * k * 0.94))
	ci.draw_colored_polygon(pts, Palette.STONE.darkened(0.18))
	var top := PackedVector2Array()
	for p: Vector2 in pts:
		top.append(c + (p - c) * 0.94 + Vector2(-s * 0.012, -s * 0.03))
	ci.draw_colored_polygon(top, Palette.STONE)
	var dot := Color(Palette.INK, 0.35)
	for i: int in 9:
		var q := Vector2(fmod(i * 0.381, 1.0) - 0.5, fmod(i * 0.617 + 0.2, 1.0) - 0.5) * s * 0.5
		ci.draw_circle(c + q + Vector2(0, -s * 0.02), s * 0.022, dot, true, -1.0, true)
	ci.draw_arc(c + Vector2(-s * 0.1, -s * 0.12), s * 0.16, PI * 1.05, PI * 1.45, 6, Color(Palette.BOARD_PAPER, 0.55), s * 0.03, true)


## Ice over a cell: [param layers] ≥ 1. [param over_face] makes the facet thinner so
## the frozen face shows through ("얼굴이 갇혀 있다").
static func ice(ci: CanvasItem, r: Rect2, layers: int, over_face: bool) -> void:
	if layers <= 0:
		return
	var s := r.size.x
	var g := r.grow(s * 0.04)
	var cut := s * 0.16
	var facet := PackedVector2Array([
		g.position + Vector2(cut, 0), Vector2(g.end.x - cut * 0.6, g.position.y), Vector2(g.end.x, g.position.y + cut),
		Vector2(g.end.x, g.end.y - cut * 0.7), Vector2(g.end.x - cut, g.end.y), Vector2(g.position.x + cut * 0.5, g.end.y),
		Vector2(g.position.x, g.end.y - cut), g.position + Vector2(0, cut * 0.8)])
	var a := 0.58 if over_face else 0.92
	ci.draw_colored_polygon(facet, Color(Palette.ICE, a))
	# Inner facet planes (lighter / darker), still achromatic.
	var c := r.get_center()
	ci.draw_colored_polygon(PackedVector2Array([facet[0], facet[1], c + Vector2(s * 0.08, -s * 0.06)]), Color(Palette.ICE.lightened(0.25), a * 0.7))
	ci.draw_colored_polygon(PackedVector2Array([facet[4], facet[5], c + Vector2(-s * 0.04, s * 0.1)]), Color(Palette.ICE.darkened(0.12), a * 0.6))
	var outline := facet.duplicate()
	outline.append(facet[0])
	ci.draw_polyline(outline, Color(Palette.INK, 0.45), maxf(1.5, s * 0.025), true)
	# Hatching: one direction per layer.
	var ink := Color(Palette.INK, 0.62 if not over_face else 0.5)
	var w := maxf(1.5, s * 0.03)
	var inner := r.grow(-s * 0.16)
	for k: int in 4:
		var t := (k + 0.5) / 4.0
		var p0 := Vector2(inner.position.x, inner.position.y + inner.size.y * t)
		var p1 := Vector2(inner.position.x + inner.size.x * t, inner.position.y)
		var q0 := Vector2(inner.position.x + inner.size.x * t, inner.end.y)
		var q1 := Vector2(inner.end.x, inner.position.y + inner.size.y * t)
		# "/" direction.
		ci.draw_line(p0, p1, ink, w, true)
		ci.draw_line(q0, q1, ink, w, true)
		if layers >= 2:
			# "\" direction.
			var m0 := Vector2(inner.end.x - inner.size.x * t, inner.position.y)
			var m1 := Vector2(inner.end.x, inner.position.y + inner.size.y * t)
			var n0 := Vector2(inner.position.x, inner.end.y - inner.size.y * t)
			var n1 := Vector2(inner.position.x + inner.size.x * t, inner.end.y)
			ci.draw_line(m0, m1, ink, w, true)
			ci.draw_line(n0, n1, ink, w, true)
	if layers == 1:
		# Corner hairline crack (1 layer left).
		var k0 := Vector2(g.end.x - s * 0.06, g.end.y - s * 0.3)
		ci.draw_polyline(PackedVector2Array([k0, k0 + Vector2(-s * 0.08, s * 0.06), k0 + Vector2(-s * 0.04, s * 0.14), k0 + Vector2(-s * 0.13, s * 0.22)]),
				Color(Palette.INK_DARK, 0.6), maxf(1.2, s * 0.018), true)


## Target-cell mark: an ink dashed ring (shape, not colour). [param pulse] 0..1
## thickens it (preview: "this placement clears it").
static func target_ring(ci: CanvasItem, r: Rect2, pulse: float, strong: bool) -> void:
	var c := r.get_center()
	var rad := r.size.x * (0.36 + 0.03 * pulse)
	var w := maxf(2.0, r.size.x * (0.035 + (0.03 if strong else 0.0)))
	var n := 16
	# White under-stroke so the ring reads on dark stickers too (ring = shape cue).
	ci.draw_arc(c, rad, 0.0, TAU, 32, Color(Palette.STICKER_WHITE, 0.7), w + maxf(2.0, r.size.x * 0.03), true)
	for i: int in n:
		if i % 2 == 1:
			continue
		var a0 := TAU * i / n
		ci.draw_arc(c, rad, a0, a0 + TAU / n, 4, Color(Palette.INK, 0.8 if not strong else 1.0), w, true)


## Preview "금" overlay: an ink zigzag crack across the cell.
static func crack(ci: CanvasItem, r: Rect2) -> void:
	var s := r.size.x
	var p := r.position
	var pts := PackedVector2Array([p + Vector2(s * 0.18, s * 0.12), p + Vector2(s * 0.42, s * 0.38), p + Vector2(s * 0.3, s * 0.52),
			p + Vector2(s * 0.6, s * 0.7), p + Vector2(s * 0.52, s * 0.8), p + Vector2(s * 0.84, s * 0.9)])
	ci.draw_polyline(pts, Palette.STICKER_WHITE, maxf(3.0, s * 0.07), true)
	ci.draw_polyline(pts, Palette.INK_DARK, maxf(2.0, s * 0.04), true)
	ci.draw_line(pts[2], pts[2] + Vector2(-s * 0.14, s * 0.06), Palette.INK_DARK, maxf(1.5, s * 0.025), true)


## Small water drop ("녹음" — a frozen face will thaw).
static func drop(ci: CanvasItem, c: Vector2, size: float) -> void:
	var pts := PackedVector2Array()
	pts.append(c + Vector2(0, -size * 0.6))
	for i: int in 13:
		var a := PI * 0.15 + PI * 0.7 * i / 12.0
		pts.append(c + Vector2(cos(a + PI * 0.5 - PI * 0.35) * size * 0.38, sin(a + PI * 0.5 - PI * 0.35) * size * 0.38 + size * 0.12))
	var ring := Color(Palette.INK, 1.0)
	ci.draw_circle(c + Vector2(0, size * 0.12), size * 0.46, Palette.STICKER_WHITE, true, -1.0, true)
	ci.draw_colored_polygon(pts, Palette.ICE.darkened(0.25))
	ci.draw_circle(c + Vector2(0, size * 0.12), size * 0.46, ring, false, maxf(1.5, size * 0.08), true)


## Small 4-point sparkle in sticker white with an ink rim ("풀려남").
static func sparkle(ci: CanvasItem, c: Vector2, size: float) -> void:
	var k := size * 0.22
	var pts := PackedVector2Array([c + Vector2(0, -size), c + Vector2(k, -k), c + Vector2(size, 0), c + Vector2(k, k),
			c + Vector2(0, size), c + Vector2(-k, k), c + Vector2(-size, 0), c + Vector2(-k, -k)])
	var rim := pts.duplicate()
	rim.append(pts[0])
	ci.draw_colored_polygon(pts, Palette.STICKER_WHITE)
	ci.draw_polyline(rim, Palette.INK, maxf(1.5, size * 0.12), true)


## HUD icon: a mini ice tile (facet + one hatch) inside [param r].
static func ice_icon(ci: CanvasItem, r: Rect2) -> void:
	ice(ci, r.grow(-r.size.x * 0.06), 1, false)
