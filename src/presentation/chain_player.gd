## Chain presentation player (design/gdd/chain-presentation.md rules 1–7, 15,
## 21–22). Replays a [ChainTimeline] built from the committed [ChainResult]
## events on a display-only board copy — it never judges anything (rule 3).
## The game screen draws [member display] and calls [method draw_overlay] on its
## top layer; [method tap] is fast-forward then skip.
##
## States: IDLE → PLAYING → (FAST →) (FLUSHING →) IDLE, emitting
## [signal playback_finished] exactly once per [method play].
## [codeblock]
## player.play(flow.last_pre_board, commit, flow.last_placement_id())
## await player.playback_finished
## [/codeblock]
class_name ChainPlayer
extends Node

## Player states (States and Transitions table; BUILDING is synchronous inside play()).
enum State { IDLE, PLAYING, FAST, FLUSHING }

## HUD beat: points shown for one wave (or the placement points, wave -1).
signal wave_presented(wave: int, points: int)
## Playback done; the round flow re-enables input.
signal playback_finished(was_skipped: bool)
## Something visual changed; owners redraw.
signal redraw_requested

## Tuning (timings).
var tuning: PresentationTuning
## crew_id → look.
var visuals: CrewVisuals
## Layout for drawing.
var layout: BoardLayout
## Font for popups/labels.
var font: Font

## Current state.
var state: State = State.IDLE
## Display-only board (rule 4).
var display: BoardState
## Timeline being played.
var timeline: ChainTimeline
## Timeline clock (s).
var clock: float = 0.0
## Real time since play() (skip guard).
var real_time: float = 0.0
## Screen-shake offset for the board layers (canvas px).
var shake_offset: Vector2 = Vector2.ZERO

var _final_board: BoardState
var _placement_id: int = 0
var _next: int = 0
var _flying: Array[Dictionary] = []
var _popups: Array[Dictionary] = []
var _labels: Array[Dictionary] = []
var _effects: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _fizzles: Array[Dictionary] = []
var _banner: Dictionary = {}
var _shake: Dictionary = {}
var _presented: int = 0
var _total_points: int = 0
var _flush_left: float = 0.0
var _skipped: bool = false


## Starts replaying [param commit] from [param pre_board] (rule 1).
func play(pre_board: BoardState, commit: RoundCommit, placement_id: int) -> void:
	if state != State.IDLE:
		_flush(false)
		_finish()
	display = pre_board.copy()
	_final_board = commit.result.final_board
	_placement_id = placement_id
	timeline = ChainTimeline.build(commit.result.events, commit.breakdown, tuning)
	_total_points = commit.breakdown.total
	_presented = 0
	clock = 0.0
	real_time = 0.0
	_next = 0
	_skipped = false
	_clear_transients()
	state = State.PLAYING
	_advance(0.0)


## True while a playback is running.
func is_playing() -> bool:
	return state != State.IDLE


## New touch-down during playback (rule 22): 1st = fast-forward, 2nd = skip.
func tap() -> void:
	if real_time < tuning.skip_guard:
		return
	match state:
		State.PLAYING:
			state = State.FAST
		State.FAST:
			_flush(true)


## Ability label text for a crew (localised key from the crew data).
func ability_label(crew: StringName) -> String:
	var key: String = visuals.look(crew)[CrewVisuals.K_ABILITY_NAME_KEY]
	return tr(key) + "!" if key != "" else tr("UI_ABILITY_GENERIC")


func _process(delta: float) -> void:
	if state == State.IDLE:
		return
	real_time += delta
	if state == State.FLUSHING:
		_flush_left -= delta
		_age(delta)
		if _flush_left <= 0.0:
			_finish()
		redraw_requested.emit()
		return
	var speed := tuning.ff_speed if state == State.FAST else 1.0
	_advance(delta * speed)
	redraw_requested.emit()


func _advance(dt: float) -> void:
	clock += dt
	_age(dt)
	while _next < timeline.cues.size() and float(timeline.cues[_next][ChainTimeline.K_T]) <= clock:
		_fire(timeline.cues[_next])
		_next += 1
	_update_shake()
	if _next >= timeline.cues.size() and _effects_done():
		_finish()


func _fire(cue: Dictionary) -> void:
	ChainTimeline.apply_cue(display, cue, _placement_id)
	var t0: float = cue[ChainTimeline.K_T]
	var dur: float = cue[ChainTimeline.K_DUR]
	match int(cue[ChainTimeline.K_KIND]):
		ChainTimeline.Kind.PEEL:
			_flying.append({&"t0": t0, &"dur": maxf(dur, 0.01), &"cell": cue[ChainTimeline.K_CELL], &"crew": cue[ChainTimeline.K_CREW],
					&"face": cue[ChainTimeline.K_FACE], &"egg": int(cue[ChainTimeline.K_ORIGIN]) == BoardState.ORIGIN_EGG,
					&"activated": cue[ChainTimeline.K_ACTIVATED], &"seed": (cue[ChainTimeline.K_CELL] as Vector2i).x * 7 + (cue[ChainTimeline.K_CELL] as Vector2i).y * 3})
		ChainTimeline.Kind.POPUP:
			var pts: int = cue[ChainTimeline.K_POINTS]
			var mult: int = cue[ChainTimeline.K_MULT_PCT]
			var text := "+%d" % pts
			if int(cue[ChainTimeline.K_WAVE]) >= 1 and mult > 100:
				text += "  ×%s" % _pct(mult)
			_popups.append({&"t0": t0, &"dur": dur, &"pos": _popup_pos(cue[ChainTimeline.K_CELL]), &"text": text,
					&"big": int(cue[ChainTimeline.K_WAVE]) >= 1})
			_presented += pts
			wave_presented.emit(int(cue[ChainTimeline.K_WAVE]), pts)
		ChainTimeline.Kind.LABEL:
			_labels.append({&"t0": t0, &"dur": dur, &"cell": cue[ChainTimeline.K_CELL], &"text": ability_label(cue[ChainTimeline.K_CREW])})
		ChainTimeline.Kind.BANNER:
			_banner = {&"t0": t0, &"dur": dur, &"text": tr("UI_CHAIN_N") % int(cue[ChainTimeline.K_STAGE]),
					&"sub": tr(visuals.look(cue[ChainTimeline.K_CREW])[CrewVisuals.K_NAME_KEY]), &"crew": cue[ChainTimeline.K_CREW],
					&"level": int(cue[ChainTimeline.K_LEVEL]), &"gold": false}
		ChainTimeline.Kind.CAP_BANNER:
			_banner = {&"t0": t0, &"dur": dur, &"text": tr("UI_CHAIN_MAX"), &"sub": "", &"crew": &"", &"level": tuning.level_cap, &"gold": true}
		ChainTimeline.Kind.EFFECT:
			_effects.append({&"t0": t0, &"dur": maxf(dur, 0.05), &"from": cue[ChainTimeline.K_CELL], &"cells": cue[ChainTimeline.K_CELLS],
					&"crew": cue[ChainTimeline.K_CREW], &"fill": cue[ChainTimeline.K_EFFECT_KIND] == ChainEvent.KIND_FILL})
		ChainTimeline.Kind.EGG:
			_flashes.append({&"t0": t0, &"dur": maxf(dur, 0.05), &"cells": [cue[ChainTimeline.K_CELL]], &"egg": true})
		ChainTimeline.Kind.LINE_FLASH:
			_flashes.append({&"t0": t0, &"dur": maxf(dur, 0.05), &"cells": cue[ChainTimeline.K_CELLS], &"egg": false})
		ChainTimeline.Kind.FIZZLE:
			_fizzles.append({&"t0": t0, &"dur": maxf(dur, 0.1) + 0.3, &"cell": cue[ChainTimeline.K_CELL], &"crew": cue[ChainTimeline.K_CREW]})
		ChainTimeline.Kind.SHAKE:
			if not tuning.reduced_motion:
				_shake = {&"t0": t0, &"dur": tuning.shake_dur, &"px": _shake_px(int(cue[ChainTimeline.K_LEVEL]))}


## Rule 22 second tap / rule 24: apply everything now, one "+sum" popup.
func _flush(show: bool) -> void:
	while _next < timeline.cues.size():
		var cue: Dictionary = timeline.cues[_next]
		ChainTimeline.apply_cue(display, cue, _placement_id)
		_next += 1
	_clear_transients()
	var rest := _total_points - _presented
	if rest > 0:
		wave_presented.emit(-2, rest)
		_presented = _total_points
		if show:
			_popups.append({&"t0": clock, &"dur": tuning.skip_flush_dur + 0.3, &"pos": layout.board_rect().get_center(),
					&"text": "+%d" % rest, &"big": true})
	if show and timeline.chain_depth >= 2:
		_banner = {&"t0": clock, &"dur": tuning.skip_flush_dur + 0.3, &"text": tr("UI_CHAIN_N") % timeline.chain_depth,
				&"sub": "", &"crew": &"", &"level": 1, &"gold": false}
	_skipped = true
	state = State.FLUSHING
	_flush_left = tuning.skip_flush_dur if show else 0.0
	shake_offset = Vector2.ZERO


func _finish() -> void:
	if not display.equals(_final_board):
		# Rule 4: truth is always final_board.
		push_error("ChainPlayer: display board != final_board after replay; redrawing from final_board")
		display = _final_board.copy()
	state = State.IDLE
	shake_offset = Vector2.ZERO
	_clear_transients()
	redraw_requested.emit()
	playback_finished.emit(_skipped)


func _effects_done() -> bool:
	return clock >= timeline.total


func _age(_dt: float) -> void:
	for arr: Array[Dictionary] in [_flying, _popups, _labels, _effects, _flashes, _fizzles]:
		var i := arr.size() - 1
		while i >= 0:
			if clock > float(arr[i][&"t0"]) + float(arr[i][&"dur"]) + 0.05:
				arr.remove_at(i)
			i -= 1
	if not _banner.is_empty() and clock > float(_banner[&"t0"]) + float(_banner[&"dur"]):
		_banner = {}


func _clear_transients() -> void:
	_flying.clear()
	_popups.clear()
	_labels.clear()
	_effects.clear()
	_flashes.clear()
	_fizzles.clear()
	_banner = {}
	_shake = {}


func _update_shake() -> void:
	shake_offset = Vector2.ZERO
	if _shake.is_empty():
		return
	var p := (clock - float(_shake[&"t0"])) / float(_shake[&"dur"])
	if p >= 1.0 or p < 0.0:
		_shake = {} if p >= 1.0 else _shake
		return
	var amp: float = float(_shake[&"px"]) * (1.0 - p)
	shake_offset = Vector2(sin(clock * 90.0), cos(clock * 70.0)) * amp


func _shake_px(level: int) -> float:
	if level <= 0:
		return 0.0
	var px := minf(tuning.shake_max_px, tuning.shake_base_px + tuning.shake_step_px * (level - 1))
	return px * layout.canvas.x / 1080.0


## Popup anchor: half a cell above the cleared group's centre, kept inside the board
## so the "+N ×M" text is never clipped by the screen edge.
func _popup_pos(cell: Vector2) -> Vector2:
	var c := layout.cell_center(cell) - Vector2(0, layout.s * 0.5)
	var br := layout.board_rect()
	return Vector2(clampf(c.x, br.position.x + 120.0, br.end.x - 120.0), clampf(c.y, br.position.y + 20.0, br.end.y - 20.0))


static func _pct(p: int) -> String:
	return ("%.1f" % (p / 100.0)).trim_suffix(".0")


# --- drawing ---------------------------------------------------------------------

## Draws everything transient that sits above the board stickers
## (flying peel stickers, effects, eggs pop, popups, labels).
func draw_overlay(ci: CanvasItem) -> void:
	if state == State.IDLE:
		return
	var s := layout.s
	for f: Dictionary in _flashes:
		var a := 1.0 - _progress(f)
		for cell: Vector2i in f[&"cells"]:
			var r := layout.cell_rect(cell)
			if f[&"egg"]:
				ci.draw_arc(r.get_center(), s * (0.3 + 0.3 * (1.0 - a)), 0, TAU, 24, Color(Palette.STICKER_WHITE, a), 3.0, true)
			else:
				StickerPainter.rounded(ci, r.grow(-2), Color(Palette.STICKER_WHITE, 0.55 * a), s * 0.2)
	for e: Dictionary in _effects:
		if e[&"fill"]:
			continue
		var p := clampf(_progress(e) * 1.6, 0.0, 1.0)
		var from := layout.cell_center(Vector2(e[&"from"]))
		var col: Color = visuals.look(e[&"crew"])[CrewVisuals.K_BASE]
		for cell: Vector2i in e[&"cells"]:
			var to := layout.cell_center(Vector2(cell))
			ci.draw_line(from, from.lerp(to, p), Color(Palette.STICKER_WHITE, 0.9), 9.0, true)
			ci.draw_line(from, from.lerp(to, p), col, 5.0, true)
			if p >= 1.0:
				ci.draw_circle(to, s * 0.12, Color(col, 0.8), true, -1.0, true)
	for f: Dictionary in _flying:
		_draw_flying(ci, f)
	for z: Dictionary in _fizzles:
		var p := _progress(z)
		var c := layout.cell_center(Vector2(z[&"cell"])) - Vector2(0, s * 0.2 * p)
		StickerPainter.draw_face(ci, c, s, visuals.look(z[&"crew"]), StickerPainter.Expr.SLEEPY, 1.0 - p * 0.7)
		StickerPainter.label(ci, c + Vector2(s * 0.4, -s * 0.45), "Z", font, int(s * 0.35), Palette.INK, 4)
	for l: Dictionary in _labels:
		var p := _progress(l)
		var c := layout.cell_center(Vector2(l[&"cell"])) + Vector2(0, -s * (0.9 + 0.3 * p))
		c.x = clampf(c.x, layout.board_origin.x + 110, layout.board_rect().end.x - 110)
		_sticker_text(ci, c, l[&"text"], 26, Palette.INK, 1.0 if p < 0.8 else (1.0 - p) * 5.0)
	for pp: Dictionary in _popups:
		var p := _progress(pp)
		var c: Vector2 = pp[&"pos"] + Vector2(0, -60.0 * p)
		var a := 1.0 if p < 0.7 else (1.0 - p) / 0.3
		var size := 40 if pp[&"big"] else 30
		StickerPainter.label(ci, c, pp[&"text"], font, size, Color(Palette.INK, a), 8, Color(Palette.GOLD if pp[&"big"] else Palette.STICKER_WHITE, a))


## Draws the cut-in banner inside the banner band (rule 14).
func draw_banner(ci: CanvasItem) -> void:
	if state == State.IDLE or _banner.is_empty():
		return
	var p := _progress(_banner)
	var rect := layout.banner_rect
	var c := rect.get_center()
	var sc := 1.0
	var rot := 0.0
	if not tuning.reduced_motion:
		if p < 0.15:
			var q := p / 0.15
			sc = lerpf(0.4, 1.12, q)
			rot = deg_to_rad(lerpf(-25.0, 4.0, q))
		elif p < 0.3:
			var q := (p - 0.15) / 0.15
			sc = lerpf(1.12, 1.0, q)
			rot = deg_to_rad(lerpf(4.0, -4.0, q))
		else:
			rot = deg_to_rad(-4.0)
	var a := 1.0 if p < 0.8 else (1.0 - p) / 0.2
	if p >= 0.8 and not tuning.reduced_motion:
		c.y -= 30.0 * (p - 0.8) / 0.2
	sc *= 1.0 + 0.05 * (maxi(int(_banner[&"level"]), 1) - 1)
	ci.draw_set_transform(c, rot, Vector2(sc, sc))
	var sub: String = _banner[&"sub"]
	var w := 360.0
	var h := 96.0 if sub != "" else 74.0
	var border: Color = Palette.GOLD if _banner[&"gold"] else visuals.look(_banner[&"crew"])[CrewVisuals.K_BASE]
	StickerPainter.rounded(ci, Rect2(-w * 0.5 + 3, -h * 0.5 + 6, w, h), Color(Palette.INK, 0.3 * a), 22)
	StickerPainter.rounded(ci, Rect2(-w * 0.5 - 6, -h * 0.5 - 6, w + 12, h + 12), Color(border, a), 26)
	StickerPainter.rounded(ci, Rect2(-w * 0.5, -h * 0.5, w, h), Color(Palette.STICKER_WHITE, a), 20)
	StickerPainter.label(ci, Vector2(0, -12 if sub != "" else 0), _banner[&"text"], font, 40, Color(Palette.INK, a), 0)
	if sub != "":
		StickerPainter.label(ci, Vector2(0, 30), sub, font, 20, Color(Palette.INK_LIGHT, a), 0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_flying(ci: CanvasItem, f: Dictionary) -> void:
	var p := _progress(f)
	var s := layout.s
	var cell: Vector2i = f[&"cell"]
	var r := layout.cell_rect(cell)
	var look := visuals.look(f[&"crew"])
	var act: bool = f[&"activated"]
	var lift_end := 0.55 if act else 0.4
	var sc := 1.0
	var rot := 0.0
	var off := Vector2.ZERO
	var a := 1.0
	var dir := 1.0 if int(f[&"seed"]) % 2 == 0 else -1.0
	if p < lift_end:
		var q := p / lift_end
		sc = lerpf(1.0, 1.15 if act else 1.08, q)
		rot = deg_to_rad(6.0 * q * dir)
	else:
		var q := (p - lift_end) / (1.0 - lift_end)
		sc = 1.15 if act else 1.08
		rot = deg_to_rad(6.0 * dir + 30.0 * q * dir)
		off = Vector2(dir * s * 0.4 * q, -s * 1.2 * q)
		a = 1.0 - q
	if tuning.reduced_motion:
		rot = 0.0
		sc = minf(sc, 1.03)
	var shadow := lerpf(1.5, 10.0 if act else 8.0, minf(p / lift_end, 1.0))
	var c := r.get_center() + off
	ci.draw_set_transform(c, rot, Vector2(sc, sc))
	var local := Rect2(-r.size * 0.5, r.size)
	var rects: Array[Rect2] = [local]
	if f[&"egg"]:
		StickerPainter.rounded(ci, Rect2(local.position + Vector2(0, shadow), local.size).grow(4), Color(Palette.INK, 0.3 * a), s * 0.25)
		StickerPainter.rounded(ci, local.grow(4), Color(Palette.STICKER_WHITE, a), s * 0.25)
		StickerPainter.draw_egg_cell(ci, local, look, a)
	else:
		StickerPainter.draw_piece(ci, rects, 0 if f[&"face"] else -1, look,
				{StickerPainter.O_ALPHA: a, StickerPainter.O_SHADOW: shadow,
				StickerPainter.O_EXPR: StickerPainter.Expr.ACTIVE if act else StickerPainter.Expr.NORMAL})
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _sticker_text(ci: CanvasItem, c: Vector2, text: String, size: int, color: Color, a: float) -> void:
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var r := Rect2(c - Vector2(sz.x * 0.5 + 14, size * 0.5 + 8), Vector2(sz.x + 28, size + 16))
	StickerPainter.rounded(ci, Rect2(r.position + Vector2(2, 4), r.size), Color(Palette.INK, 0.3 * a), 14)
	StickerPainter.rounded(ci, r, Color(Palette.STICKER_WHITE, a), 14)
	StickerPainter.label(ci, c, text, font, size, Color(color, a), 0)


func _progress(item: Dictionary) -> float:
	return clampf((clock - float(item[&"t0"])) / float(item[&"dur"]), 0.0, 1.0)
