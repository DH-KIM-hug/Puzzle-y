## Real-time "juice" layer for the chain presentation (chain-presentation
## Visual/Audio + Game Feel, decision log D15–D18): paper-sticker confetti,
## line sweeps, shockwave rings, screen flash, sparkles, the multiplier
## fly-to-score text, the "대연쇄!!" finisher card, the deep-chain mood
## (background veil + board glow) and the idle background sparkle dust.
##
## Display only: it never reads or changes a board. Everything ages in REAL
## time (not the playback clock), so particles keep falling after a playback
## ends; [member freeze_left] pauses aging during a hit-stop. Particles are
## drawn CPU-side as white-edged paper quads/triangles (sticker look) and capped
## by [member PresentationTuning.particle_cap] for low-end mobile / web.
## [codeblock]
## fx.confetti(pos, [crew_colour], 6, 1.0)
## fx.draw_front(overlay_layer)   # in the overlay layer's _draw
## [/codeblock]
class_name ChainFx
extends Node

## A multiplier fly-text reached the score HUD.
signal fly_arrived(text: String)

## Tuning.
var tuning: PresentationTuning
## Layout.
var layout: BoardLayout
## Font.
var font: Font
## Canvas position the multiplier texts fly to (HUD score).
var score_target: Vector2 = Vector2(120, 50)
## Hit-stop: aging is paused while > 0 (real seconds).
var freeze_left: float = 0.0
## Deep-chain mood target 0..1 (eased into [member deep]).
var deep_target: float = 0.0
## Current deep-chain mood 0..1.
var deep: float = 0.0
## Real time since start (idle animation phase).
var time: float = 0.0
## Effective reduced-motion flag (tuning or OS).
var reduced: bool = false

var _parts: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _sweeps: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _flies: Array[Dictionary] = []
var _finisher: Dictionary = {}
var _flash: float = 0.0
var _flash_peak: float = 0.0
var _last_flash: float = -10.0
var _dust: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7  # presentation-only randomness, fixed for reproducible screenshots
	if layout != null:
		for i: int in tuning.idle_dust_count:
			_dust.append({&"p": Vector2(_rng.randf() * layout.canvas.x, _rng.randf() * layout.canvas.y),
					&"ph": _rng.randf() * TAU, &"sz": _rng.randf_range(3.0, 7.0), &"v": _rng.randf_range(6.0, 16.0)})


## True while something transient is still visible (owners keep redrawing).
func busy() -> bool:
	return not (_parts.is_empty() and _rings.is_empty() and _sweeps.is_empty() and _sparks.is_empty()
			and _flies.is_empty() and _finisher.is_empty()) or _flash > 0.0 or absf(deep - deep_target) > 0.001


func _process(delta: float) -> void:
	time += delta
	for d: Dictionary in _dust:
		if not reduced:
			d[&"p"] = Vector2(d[&"p"]) + Vector2(sin(time * 0.3 + float(d[&"ph"])) * 4.0, -float(d[&"v"])) * delta
			if (d[&"p"] as Vector2).y < -10.0:
				d[&"p"] = Vector2(_rng.randf() * layout.canvas.x, layout.canvas.y + 10.0)
	deep = move_toward(deep, deep_target, delta * 2.5)
	if freeze_left > 0.0:
		freeze_left -= delta
		return
	_flash = maxf(0.0, _flash - delta / maxf(tuning.flash_dur_s, 0.01))
	var g := 1100.0 * layout.canvas.x / 720.0
	var i := _parts.size() - 1
	while i >= 0:
		var p := _parts[i]
		p[&"age"] = float(p[&"age"]) + delta
		if float(p[&"age"]) >= float(p[&"life"]):
			_parts.remove_at(i)
		else:
			var v: Vector2 = p[&"v"]
			v.y += g * delta * float(p[&"grav"])
			v *= pow(0.12, delta)  # paper drag
			p[&"v"] = v
			p[&"p"] = Vector2(p[&"p"]) + (v + Vector2(sin(float(p[&"age"]) * 9.0 + float(p[&"ph"])) * 40.0, 0.0)) * delta
			p[&"r"] = float(p[&"r"]) + float(p[&"rv"]) * delta
		i -= 1
	for arr: Array[Dictionary] in [_rings, _sweeps, _sparks]:
		var j := arr.size() - 1
		while j >= 0:
			arr[j][&"t"] = float(arr[j][&"t"]) + delta
			if float(arr[j][&"t"]) >= float(arr[j][&"delay"]) + float(arr[j][&"dur"]):
				arr.remove_at(j)
			j -= 1
	var k := _flies.size() - 1
	while k >= 0:
		_flies[k][&"t"] = float(_flies[k][&"t"]) + delta
		if float(_flies[k][&"t"]) >= float(_flies[k][&"delay"]) + float(_flies[k][&"dur"]):
			fly_arrived.emit(_flies[k][&"text"])
			_flies.remove_at(k)
		k -= 1
	if not _finisher.is_empty():
		_finisher[&"t"] = float(_finisher[&"t"]) + delta
		if float(_finisher[&"t"]) >= float(_finisher[&"dur"]):
			_finisher = {}


# --- spawners --------------------------------------------------------------------

## Paper confetti burst at [param pos]: [param n] pieces in [param colours] + white.
func confetti(pos: Vector2, colours: Array, n: int, power: float, up_bias: float = 1.0) -> void:
	if reduced:
		n = maxi(1, n / 3)
		power *= 0.5
	var sc := layout.canvas.x / 720.0
	for i: int in n:
		var ang := -PI * 0.5 + _rng.randf_range(-1.25, 1.25) / maxf(up_bias, 0.3)
		var spd := _rng.randf_range(220.0, 520.0) * power * sc
		var col: Color = Palette.STICKER_WHITE if (i % 3 == 2 or colours.is_empty()) else colours[i % colours.size()]
		_add_part({&"p": pos, &"v": Vector2(cos(ang), sin(ang)) * spd, &"r": _rng.randf() * TAU,
				&"rv": _rng.randf_range(-9.0, 9.0) * (0.2 if reduced else 1.0), &"sz": _rng.randf_range(6.0, 11.0) * sc,
				&"col": col, &"tri": _rng.randf() < 0.35, &"life": _rng.randf_range(0.8, 1.3), &"age": 0.0,
				&"grav": 1.0, &"ph": _rng.randf() * TAU})


## Confetti cannons from both bottom screen edges (finisher).
func cannons(colours: Array) -> void:
	var c := layout.canvas
	var n := tuning.cannon_per_side if not reduced else tuning.cannon_per_side / 4
	var sc := c.x / 720.0
	for side: float in [-1.0, 1.0]:
		var origin := Vector2(0.0 if side < 0.0 else c.x, c.y * 0.72)
		for i: int in n:
			var ang := deg_to_rad(-90.0 + side * _rng.randf_range(-70.0, -10.0))
			var spd := _rng.randf_range(500.0, 1500.0) * sc
			var col: Color = Palette.STICKER_WHITE if i % 3 == 2 else (Palette.GOLD if colours.is_empty() else colours[i % colours.size()])
			_add_part({&"p": origin, &"v": Vector2(cos(ang), sin(ang)) * spd, &"r": _rng.randf() * TAU,
					&"rv": _rng.randf_range(-10.0, 10.0), &"sz": _rng.randf_range(8.0, 13.0) * sc, &"col": col,
					&"tri": _rng.randf() < 0.4, &"life": _rng.randf_range(1.1, 1.7), &"age": 0.0, &"grav": 0.8, &"ph": _rng.randf() * TAU})


## Small cream dust puff along a landing piece's bottom edge.
func dust(pos: Vector2, n: int, spread: float) -> void:
	var sc := layout.canvas.x / 720.0
	for i: int in n:
		var dir := -1.0 if i % 2 == 0 else 1.0
		_add_part({&"p": pos + Vector2(_rng.randf_range(-spread, spread), 0), &"v": Vector2(dir * _rng.randf_range(60, 170), -_rng.randf_range(20, 90)) * sc,
				&"r": 0.0, &"rv": 0.0, &"sz": _rng.randf_range(5.0, 9.0) * sc, &"col": Palette.FACE_CREAM, &"puff": true,
				&"life": _rng.randf_range(0.3, 0.45), &"age": 0.0, &"grav": 0.15, &"ph": 0.0})


## Shockwave ring from [param pos] to radius [param radius].
func ring(pos: Vector2, colour: Color, radius: float, dur: float, delay: float = 0.0, width: float = 10.0) -> void:
	_rings.append({&"p": pos, &"col": colour, &"rad": radius, &"dur": dur, &"delay": delay, &"t": 0.0, &"w": width})


## Paper-white sweep travelling along one cleared line ([param from] → [param to] cell centres).
func sweep(from: Vector2, to: Vector2, colour: Color, delay: float) -> void:
	_sweeps.append({&"a": from, &"b": to, &"col": colour, &"dur": tuning.sweep_dur_s, &"delay": delay, &"t": 0.0})


## Four-point sparkles around [param pos].
func sparkle_burst(pos: Vector2, n: int, radius: float, colour: Color = Palette.GOLD, delay: float = 0.0) -> void:
	for i: int in n:
		var ang := TAU * i / maxf(n, 1) + _rng.randf() * 0.4
		_sparks.append({&"p": pos, &"d": Vector2(cos(ang), sin(ang)) * radius * _rng.randf_range(0.6, 1.0),
				&"col": colour, &"sz": _rng.randf_range(8.0, 15.0), &"dur": _rng.randf_range(0.35, 0.55), &"delay": delay + i * 0.012, &"t": 0.0})


## Screen flash (sticker white, alpha capped, pulse-gated ≤ 3/s, off when flash_off / reduced).
func flash(alpha: float) -> void:
	if tuning.flash_off or reduced:
		return
	if time - _last_flash < tuning.flash_min_gap_s:
		return
	_last_flash = time
	_flash_peak = minf(alpha, tuning.flash_max_alpha)
	_flash = 1.0


## Multiplier text that flies from [param from] to the score HUD.
func fly(text: String, from: Vector2, delay: float) -> void:
	_flies.append({&"text": text, &"a": from, &"t": 0.0, &"delay": delay, &"dur": 0.5})


## "대연쇄!!" finisher card (+ edge cannons).
func finisher(text: String, sub: String, colours: Array) -> void:
	_finisher = {&"text": text, &"sub": sub, &"t": 0.0, &"dur": tuning.finisher_dur_s, &"cols": colours}
	cannons(colours)
	sparkle_burst(layout.board_rect().get_center(), 14, 260.0, Palette.GOLD)


## Drops all transients (new attempt).
func clear() -> void:
	_parts.clear()
	_rings.clear()
	_sweeps.clear()
	_sparks.clear()
	_flies.clear()
	_finisher = {}
	_flash = 0.0
	deep_target = 0.0
	freeze_left = 0.0


func _add_part(p: Dictionary) -> void:
	if _parts.size() >= tuning.particle_cap:
		_parts.remove_at(0)
	_parts.append(p)


# --- drawing ---------------------------------------------------------------------

## Behind the board: idle sparkle dust, deep-chain veil and board glow.
func draw_back(ci: CanvasItem) -> void:
	for d: Dictionary in _dust:
		var tw := 0.5 + 0.5 * sin(time * TAU / 3.0 + float(d[&"ph"]))
		_star(ci, d[&"p"], float(d[&"sz"]) * (0.6 + 0.4 * tw), Color(Palette.STICKER_WHITE, 0.25 + 0.4 * tw))
	if deep <= 0.001:
		return
	ci.draw_rect(Rect2(Vector2.ZERO, layout.canvas), Color(Palette.INK_DARK, tuning.deep_veil_alpha * deep))
	var pulse := 0.5 + 0.5 * sin(time * TAU * (0.0 if reduced else tuning.deep_glow_hz))
	var br := layout.board_rect()
	var a := tuning.deep_glow_alpha * deep * (0.65 + 0.35 * pulse)
	StickerPainter.rounded(ci, br.grow(26.0 + 6.0 * pulse), Color(Palette.GOLD, a * 0.45), 36)
	StickerPainter.rounded(ci, br.grow(18.0), Color(Palette.GOLD, a), 30)
	StickerPainter.rounded(ci, br.grow(10.0), Palette.KRAFT_SHADE, 26)


## Over the board stickers: sweeps, rings, paper particles, sparkles.
func draw_front(ci: CanvasItem) -> void:
	var s := layout.s
	for w: Dictionary in _sweeps:
		var q := (float(w[&"t"]) - float(w[&"delay"])) / float(w[&"dur"])
		if q < 0.0:
			continue
		var a: Vector2 = w[&"a"]
		var b: Vector2 = w[&"b"]
		var dir := (b - a).normalized()
		var head := a.lerp(b, minf(q * 1.25, 1.0)) if not reduced else b
		var fade := 1.0 - maxf(0.0, q - 0.6) / 0.4
		# trail band (paper white), then a fat head sticker with a crew-colour core.
		var perp := Vector2(-dir.y, dir.x) * s * 0.42
		var tail := a - dir * s * 0.45
		var poly := PackedVector2Array([tail + perp, head + perp, head - perp, tail - perp])
		ci.draw_colored_polygon(poly, Color(Palette.STICKER_WHITE, 0.55 * fade))
		if not reduced and q < 0.85:
			ci.draw_circle(head, s * 0.48, Color(Palette.STICKER_WHITE, 0.95 * fade), true, -1.0, true)
			ci.draw_circle(head, s * 0.28, Color(w[&"col"], 0.9 * fade), true, -1.0, true)
			_star(ci, head - perp * 0.9, s * 0.22, Color(Palette.GOLD, fade))
			_star(ci, head + perp * 1.1 - dir * s * 0.6, s * 0.16, Color(Palette.STICKER_WHITE, fade))
	for r: Dictionary in _rings:
		var q := (float(r[&"t"]) - float(r[&"delay"])) / float(r[&"dur"])
		if q < 0.0:
			continue
		var e := 1.0 - pow(1.0 - q, 3.0)
		var rad := float(r[&"rad"]) * e
		var al := 1.0 - q
		var wdt := float(r[&"w"]) * (1.0 - q * 0.6)
		ci.draw_arc(r[&"p"], rad, 0, TAU, 48, Color(Palette.STICKER_WHITE, 0.9 * al), wdt + 6.0, true)
		ci.draw_arc(r[&"p"], rad, 0, TAU, 48, Color(r[&"col"], 0.85 * al), wdt, true)
	for p: Dictionary in _parts:
		_draw_part(ci, p)
	for k: Dictionary in _sparks:
		var q := (float(k[&"t"]) - float(k[&"delay"])) / float(k[&"dur"])
		if q < 0.0:
			continue
		var pos: Vector2 = Vector2(k[&"p"]) + Vector2(k[&"d"]) * (1.0 - pow(1.0 - q, 2.0))
		_star(ci, pos, float(k[&"sz"]) * sin(q * PI), Color(k[&"col"], 1.0))


## Screen space, above the banner: flash, finisher card, fly-texts.
func draw_screen(ci: CanvasItem) -> void:
	if _flash > 0.0:
		ci.draw_rect(Rect2(Vector2.ZERO, layout.canvas), Color(Palette.STICKER_WHITE, _flash_peak * _flash))
	if not _finisher.is_empty():
		_draw_finisher(ci)


## Multiplier fly-texts (drawn under the banner so they never cover its numeral).
func draw_flies(ci: CanvasItem) -> void:
	for f: Dictionary in _flies:
		var q := clampf((float(f[&"t"]) - float(f[&"delay"])) / float(f[&"dur"]), 0.0, 1.0)
		if float(f[&"t"]) < float(f[&"delay"]):
			continue
		var e := q * q * (3.0 - 2.0 * q)
		var a: Vector2 = f[&"a"]
		var ctrl := Vector2(a.x, score_target.y + 90.0)
		var pos := a.lerp(ctrl, e).lerp(ctrl.lerp(score_target, e), e)
		var size := int(lerpf(36.0, 24.0, e))
		StickerPainter.label(ci, pos, f[&"text"], font, size, Palette.INK, 8, Palette.GOLD)


func _draw_finisher(ci: CanvasItem) -> void:
	var p := float(_finisher[&"t"]) / float(_finisher[&"dur"])
	var c := layout.board_rect().get_center() + Vector2(0, -layout.s * 0.6)
	var sc := 1.0
	var rot := deg_to_rad(-6.0)
	if not reduced:
		if p < 0.12:
			sc = lerpf(1.8, 0.9, p / 0.12)
		elif p < 0.22:
			sc = lerpf(0.9, 1.08, (p - 0.12) / 0.1)
		elif p < 0.3:
			sc = lerpf(1.08, 1.0, (p - 0.22) / 0.08)
		rot += deg_to_rad(sin(time * TAU * 1.5) * 2.0)
	var a := 1.0
	if p > 0.72:
		var q := (p - 0.72) / 0.28
		a = 1.0 - q
		sc *= lerpf(1.0, 0.55, q)
		c = c.lerp(layout.banner_rect.get_center(), q)
	# radial rays (sticker-cut, alternating gold / white)
	var rays := 14
	var spin := 0.0 if reduced else time * 0.8
	for i: int in rays:
		var a0 := spin + TAU * i / rays
		var a1 := a0 + TAU / rays * 0.5
		var R := 330.0 * sc
		var col := Color(Palette.GOLD if i % 2 == 0 else Palette.STICKER_WHITE, 0.55 * a)
		ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * R, c + Vector2(cos(a1), sin(a1)) * R]), col)
	ci.draw_set_transform(c, rot, Vector2(sc, sc))
	var w := 470.0
	var h := 170.0
	StickerPainter.rounded(ci, Rect2(-w * 0.5 + 4, -h * 0.5 + 10, w, h), Color(Palette.INK, 0.35 * a), 34)
	StickerPainter.rounded(ci, Rect2(-w * 0.5 - 10, -h * 0.5 - 10, w + 20, h + 20), Color(Palette.GOLD, a), 40)
	StickerPainter.rounded(ci, Rect2(-w * 0.5, -h * 0.5, w, h), Color(Palette.STICKER_WHITE, a), 32)
	# masking tape strips
	for sx: float in [-1.0, 1.0]:
		ci.draw_set_transform(c + Vector2(sx * w * 0.42, -h * 0.5).rotated(rot) * sc, rot + sx * deg_to_rad(30), Vector2(sc, sc))
		StickerPainter.rounded(ci, Rect2(-36, -14, 72, 28), Color(Palette.FACE_CREAM.darkened(0.06), 0.9 * a), 4)
	ci.draw_set_transform(c, rot, Vector2(sc, sc))
	holo_text(ci, Vector2(0, -16), _finisher[&"text"], 76, a, time)
	if String(_finisher[&"sub"]) != "":
		StickerPainter.label(ci, Vector2(0, 52), _finisher[&"sub"], font, 26, Color(Palette.INK_LIGHT, a), 0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Per-letter holo shimmer text (UI only, art-bible §4), ink outline, centred at [param c].
func holo_text(ci: CanvasItem, c: Vector2, text: String, size: int, a: float, t: float) -> void:
	var total := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := c.x - total * 0.5
	var y := c.y + size * 0.35
	for i: int in text.length():
		var ch := text.substr(i, 1)
		var cw := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var hue := fmod(0.0 if reduced else t * 0.35, 1.0) + i * 0.13
		var col := Color.from_hsv(fmod(hue, 1.0), 0.55, 1.0, a)
		var bob := 0.0 if reduced else sin(t * 6.0 + i * 0.9) * size * 0.05
		ci.draw_string_outline(font, Vector2(x, y + bob), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 14, Color(Palette.INK, a))
		ci.draw_string(font, Vector2(x, y + bob), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		x += cw


func _draw_part(ci: CanvasItem, p: Dictionary) -> void:
	var life_q := float(p[&"age"]) / float(p[&"life"])
	var a := 1.0 if life_q < 0.7 else (1.0 - life_q) / 0.3
	var pos: Vector2 = p[&"p"]
	var sz: float = p[&"sz"]
	if p.get(&"puff", false):
		ci.draw_circle(pos, sz * (0.6 + life_q), Color(Palette.STICKER_WHITE, 0.8 * a), true, -1.0, true)
		ci.draw_circle(pos, sz * (0.4 + life_q * 0.8), Color(p[&"col"], 0.9 * a), true, -1.0, true)
		return
	var r: float = p[&"r"]
	# paper flutter: the piece's width flips with its spin (cheap 3D-ish turn)
	var squash := absf(cos(r * 1.7))
	var ax := Vector2(cos(r), sin(r)) * sz * maxf(squash, 0.25)
	var ay := Vector2(-sin(r), cos(r)) * sz * 0.7
	var pts: PackedVector2Array
	if p[&"tri"]:
		pts = PackedVector2Array([pos - ay * 1.1, pos + ax + ay * 0.8, pos - ax + ay * 0.8])
	else:
		pts = PackedVector2Array([pos - ax - ay, pos + ax - ay, pos + ax + ay, pos - ax + ay])
	var col: Color = p[&"col"]
	if col != Palette.STICKER_WHITE:
		var outer := PackedVector2Array()
		for q: Vector2 in pts:
			outer.append(pos + (q - pos) * 1.35)
		ci.draw_colored_polygon(outer, Color(Palette.STICKER_WHITE, a))
	else:
		var outer := PackedVector2Array()
		for q: Vector2 in pts:
			outer.append(pos + (q - pos) * 1.3)
		ci.draw_colored_polygon(outer, Color(Palette.INK_LIGHT, 0.35 * a))
	ci.draw_colored_polygon(pts, Color(col, a))


## Four-point sparkle star.
static func _star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	if r <= 0.5:
		return
	var k := r * 0.28
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(k, -k), c + Vector2(r, 0), c + Vector2(k, k),
			c + Vector2(0, r), c + Vector2(-k, k), c + Vector2(-r, 0), c + Vector2(-k, -k)]), col)
