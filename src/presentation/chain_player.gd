## Chain presentation player (design/gdd/chain-presentation.md rules 1–7, 15,
## 21–22). Replays a [ChainTimeline] built from the committed [ChainResult]
## events on a display-only board copy — it never judges anything (rule 3).
## The game screen draws [member display] and calls [method draw_overlay] on its
## top layer; [method tap] is fast-forward then skip.
##
## Polish pass (decision log D15–D18): each chain wave starts with a short
## hit-stop (the playback clock freezes; real time only, capped per playback by
## [member PresentationTuning.hitstop_total_cap_s]), a camera punch-in toward the
## firing face ([member zoom] / [member zoom_focus]) and a release shake; line
## clears get a paper sweep + confetti; faces peel up and fly to the cut-in band;
## each crew species draws its own ability effect; the banner slams in.
## Real-time juice (particles, rings, finisher) lives in [ChainFx].
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
## Audio hook (design/gdd/audio.md): a cue fired. [param kind] = [enum ChainTimeline.Kind]
## (-1 = the "대연쇄!!" finisher), [param level] = chain level, [param index] = order
## inside its burst (line cascade / egg sequence) or the wave number (SHAKE, PEEL),
## [param species] = crew species of the cue (EFFECT / EGG / PEEL / FIZZLE), else empty.
signal cue_fired(kind: int, level: int, index: int, species: StringName)

## Tuning (timings).
var tuning: PresentationTuning
## crew_id → look.
var visuals: CrewVisuals
## Layout for drawing.
var layout: BoardLayout
## Font for popups/labels.
var font: Font
## Real-time effects layer (optional; null = no juice, e.g. in tests).
var fx: ChainFx
## Effective reduced-motion flag (tuning OR OS accessibility; set by the owner).
var reduced: bool = false

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
## Camera punch zoom for the board layers (1 = none) and its focus (canvas px).
var zoom: float = 1.0
var zoom_focus: Vector2 = Vector2.ZERO

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
var _pending_shake: float = 0.0
var _presented: int = 0
var _total_points: int = 0
var _flush_left: float = 0.0
var _skipped: bool = false
var _hitstop_left: float = 0.0
var _hitstop_used: float = 0.0
var _punch: Dictionary = {}
var _landing: Dictionary = {}
var _pops: Dictionary = {}
var _wave_face: Dictionary = {}
var _finisher_t: float = -1.0
var _finisher_sub: String = ""
var _crew_cols: Array = []
var _max_level: int = 0


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
	_hitstop_left = 0.0
	_hitstop_used = 0.0
	_clear_transients()
	_scan_timeline()
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
			_hitstop_left = 0.0
		State.FAST:
			_flush(true)


## Ability label text for a crew (localised key from the crew data).
func ability_label(crew: StringName) -> String:
	var key: String = visuals.look(crew)[CrewVisuals.K_ABILITY_NAME_KEY]
	return tr(key) + "!" if key != "" else tr("UI_ABILITY_GENERIC")


## Display scale of a board cell right now (landing squash, egg bounce); ONE when idle.
func cell_scale(cell: Vector2i) -> Vector2:
	if state == State.IDLE:
		return Vector2.ONE
	if _pops.has(cell):
		var pp: Dictionary = _pops[cell]
		var q := clampf((clock - float(pp[&"t0"])) / float(pp[&"dur"]), 0.0, 1.0)
		if q < 1.0:
			var e := maxf(_elastic(q), 0.2)
			return Vector2(e, e)
	if not _landing.is_empty() and (_landing[&"cells"] as Array).has(cell):
		var q := clampf((clock - float(_landing[&"t0"])) / float(_landing[&"dur"]), 0.0, 1.0)
		if q < 1.0 and not reduced:
			var k := sin(q * PI) * tuning.land_squash * (1.0 - q * 0.4)
			return Vector2(1.0 + k, 1.0 - k)
	return Vector2.ONE


func _process(delta: float) -> void:
	if state == State.IDLE:
		return
	real_time += delta
	_update_punch(delta)
	if state == State.FLUSHING:
		_flush_left -= delta
		_age(delta)
		if _flush_left <= 0.0:
			_finish()
		redraw_requested.emit()
		return
	if _hitstop_left > 0.0:
		_hitstop_left -= delta
		if _hitstop_left <= 0.0:
			_release_shake()
		_update_shake()
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
		if _hitstop_left > 0.0:
			break  # freeze right on the wave-start beat; remaining same-time cues fire after release
	if _finisher_t >= 0.0 and clock >= _finisher_t:
		_finisher_t = -1.0
		if fx != null:
			fx.finisher(tr("UI_CHAIN_FINISH"), _finisher_sub, _crew_cols)
		cue_fired.emit(-1, _max_level, 0, &"")
	_update_shake()
	if _next >= timeline.cues.size() and _effects_done():
		_finish()


## Pre-scan: firing face per wave (punch focus), finisher trigger, crew colours.
func _scan_timeline() -> void:
	_wave_face.clear()
	_crew_cols.clear()
	_finisher_t = -1.0
	_finisher_sub = ""
	_max_level = 0
	var last_banner := -1.0
	for c: Dictionary in timeline.cues:
		var kind := int(c[ChainTimeline.K_KIND])
		if kind == ChainTimeline.Kind.PEEL and c[ChainTimeline.K_ACTIVATED]:
			var w := int(c[ChainTimeline.K_WAVE])
			if not _wave_face.has(w):
				_wave_face[w] = c[ChainTimeline.K_CELL]
			var col: Color = visuals.look(c[ChainTimeline.K_CREW])[CrewVisuals.K_BASE]
			if not _crew_cols.has(col):
				_crew_cols.append(col)
		elif kind == ChainTimeline.Kind.BANNER or kind == ChainTimeline.Kind.CAP_BANNER:
			last_banner = float(c[ChainTimeline.K_T])
		elif kind == ChainTimeline.Kind.LINE_FLASH and _finisher_t < 0.0:
			var n := _lines(c[ChainTimeline.K_CELLS]).size()
			if n >= tuning.finisher_lines:
				_finisher_t = float(c[ChainTimeline.K_T]) + tuning.sweep_cascade_s * n
				_finisher_sub = tr("UI_LINES_N") % n
		if c.has(ChainTimeline.K_LEVEL):
			_max_level = maxi(_max_level, int(c[ChainTimeline.K_LEVEL]))
	if timeline.chain_depth >= tuning.finisher_depth and last_banner >= 0.0:
		_finisher_t = minf(last_banner + 0.3, maxf(timeline.total - 0.5, last_banner))
		_finisher_sub = tr("UI_CHAIN_N") % timeline.chain_depth
	if _crew_cols.is_empty():
		_crew_cols = [Palette.GOLD]


func _fire(cue: Dictionary) -> void:
	ChainTimeline.apply_cue(display, cue, _placement_id)
	var t0: float = cue[ChainTimeline.K_T]
	var dur: float = cue[ChainTimeline.K_DUR]
	var kind := int(cue[ChainTimeline.K_KIND])
	var level: int = int(cue.get(ChainTimeline.K_LEVEL, 0))
	var s := layout.s
	match kind:
		ChainTimeline.Kind.PLACE:
			var cells: Array = cue[ChainTimeline.K_CELLS]
			_landing = {&"t0": t0, &"dur": maxf(dur * 1.6, 0.12), &"cells": cells}
			if fx != null and not cells.is_empty():
				var lo := -INF
				var minx := INF
				var maxx := -INF
				for c: Vector2i in cells:
					var r := layout.cell_rect(c)
					lo = maxf(lo, r.end.y)
					minx = minf(minx, r.position.x)
					maxx = maxf(maxx, r.end.x)
				fx.dust(Vector2((minx + maxx) * 0.5, lo), tuning.land_dust, (maxx - minx) * 0.45)
			cue_fired.emit(kind, 0, 0, &"")
		ChainTimeline.Kind.PEEL:
			var cell: Vector2i = cue[ChainTimeline.K_CELL]
			var act: bool = cue[ChainTimeline.K_ACTIVATED]
			_flying.append({&"t0": t0, &"dur": maxf(dur, 0.01), &"cell": cell, &"crew": cue[ChainTimeline.K_CREW],
					&"face": cue[ChainTimeline.K_FACE], &"egg": int(cue[ChainTimeline.K_ORIGIN]) == BoardState.ORIGIN_EGG,
					&"activated": act, &"seed": cell.x * 7 + cell.y * 3, &"level": level})
			if fx != null:
				var look := visuals.look(cue[ChainTimeline.K_CREW])
				var n := tuning.confetti_line_per_cell if level == 0 else tuning.confetti_chain_per_cell + tuning.confetti_chain_step * level
				fx.confetti(layout.cell_center(Vector2(cell)), [look[CrewVisuals.K_BASE], look[CrewVisuals.K_SHADE]], n, 0.8 + 0.15 * level)
				if act:
					fx.sparkle_burst(layout.cell_center(Vector2(cell)), 6, s * 1.1, Palette.GOLD)
			cue_fired.emit(kind, level, int(cue[ChainTimeline.K_WAVE]), _species(cue[ChainTimeline.K_CREW]))
		ChainTimeline.Kind.POPUP:
			var pts: int = cue[ChainTimeline.K_POINTS]
			var mult: int = cue[ChainTimeline.K_MULT_PCT]
			var text := "+%d" % pts
			var base := text
			var wave := int(cue[ChainTimeline.K_WAVE])
			if wave >= 1 and mult > 100:
				text += "  ×%s" % _pct(mult)
			var pos := _free_spot(_popup_pos(cue[ChainTimeline.K_CELL]), Vector2(230, 52))
			var half := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40 + 5 * level).x * 0.5 + 12.0
			var br := layout.board_rect()
			pos.x = clampf(pos.x, br.position.x + half, maxf(br.end.x - half, br.position.x + half))
			var fly_at := -1.0
			if fx != null and wave >= 1 and mult > 100:
				# The "×M" part leaves the popup and flies to the score HUD.
				var fly_delay := 0.35
				fly_at = t0 + fly_delay
				var full_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40 + 5 * level).x
				var base_w := font.get_string_size(base + "  ", HORIZONTAL_ALIGNMENT_LEFT, -1, 40 + 5 * level).x
				fx.fly("×%s" % _pct(mult), pos + Vector2(base_w - full_w * 0.5 + (full_w - base_w) * 0.5, -60.0 * fly_delay / maxf(dur, 0.01)), fly_delay)
			_popups.append({&"t0": t0, &"dur": dur, &"pos": pos, &"text": text, &"base": base, &"fly_at": fly_at,
					&"big": wave >= 1, &"level": level})
			_presented += pts
			wave_presented.emit(wave, pts)
		ChainTimeline.Kind.LABEL:
			_labels.append({&"t0": t0, &"dur": dur, &"pos": _label_pos(cue[ChainTimeline.K_CELL]), &"text": ability_label(cue[ChainTimeline.K_CREW])})
		ChainTimeline.Kind.BANNER:
			var stage := int(cue[ChainTimeline.K_STAGE])
			_banner = {&"t0": t0, &"dur": dur, &"text": _chain_text(stage),
					&"sub": tr(visuals.look(cue[ChainTimeline.K_CREW])[CrewVisuals.K_NAME_KEY]), &"crew": cue[ChainTimeline.K_CREW],
					&"level": level, &"gold": false, &"stage": stage, &"burst": false}
			cue_fired.emit(kind, level, stage, &"")
		ChainTimeline.Kind.CAP_BANNER:
			_banner = {&"t0": t0, &"dur": dur, &"text": tr("UI_CHAIN_MAX"), &"sub": "", &"crew": &"", &"level": tuning.level_cap,
					&"gold": true, &"stage": timeline.chain_depth, &"burst": false}
			cue_fired.emit(kind, tuning.level_cap, 0, &"")
		ChainTimeline.Kind.EFFECT:
			var crew: StringName = cue[ChainTimeline.K_CREW]
			var look := visuals.look(crew)
			_effects.append({&"t0": t0, &"dur": maxf(dur, 0.05), &"from": cue[ChainTimeline.K_CELL], &"cells": cue[ChainTimeline.K_CELLS],
					&"crew": crew, &"fill": cue[ChainTimeline.K_EFFECT_KIND] == ChainEvent.KIND_FILL, &"species": look[CrewVisuals.K_SPECIES]})
			if fx != null and cue[ChainTimeline.K_CELL] != ChainEvent.NO_CELL:
				var fp := layout.cell_center(Vector2(cue[ChainTimeline.K_CELL] as Vector2i))
				var col: Color = look[CrewVisuals.K_BASE]
				fx.ring(fp, col, s * (2.2 + 0.5 * level), 0.42, 0.0, 10.0)
				if level >= 1:
					fx.ring(fp, Palette.GOLD, layout.canvas.x * (0.55 + 0.1 * level), 0.6, 0.05, 6.0)
			cue_fired.emit(kind, level, 0, look[CrewVisuals.K_SPECIES])
		ChainTimeline.Kind.EGG:
			var cell: Vector2i = cue[ChainTimeline.K_CELL]
			_pops[cell] = {&"t0": t0, &"dur": maxf(dur * 2.0, 0.2)}
			_flashes.append({&"t0": t0, &"dur": maxf(dur, 0.05), &"cells": [cell], &"egg": true})
			if fx != null:
				var look := visuals.look(cue[ChainTimeline.K_CREW])
				var c := layout.cell_center(Vector2(cell))
				if look[CrewVisuals.K_SPECIES] == &"sheep":
					fx.dust(c + Vector2(0, s * 0.3), 6, s * 0.3)
				fx.sparkle_burst(c, 4, s * 0.7, Palette.FACE_CREAM if look[CrewVisuals.K_SPECIES] == &"sheep" else Palette.GOLD)
			cue_fired.emit(kind, level, _pops.size(), _species(cue[ChainTimeline.K_CREW]))
		ChainTimeline.Kind.LINE_FLASH:
			var cells: Array = cue[ChainTimeline.K_CELLS]
			_flashes.append({&"t0": t0, &"dur": maxf(dur, 0.05), &"cells": cells, &"egg": false})
			var lines := _lines(cells)
			for i: int in lines.size():
				var ln: Array = lines[i]
				if fx != null:
					fx.sweep(layout.cell_center(Vector2(ln[0] as Vector2i)), layout.cell_center(Vector2(ln[1] as Vector2i)),
							Palette.GOLD if level == 0 else _level_colour(level), tuning.sweep_cascade_s * i)
				cue_fired.emit(kind, level, i, &"")
			if lines.size() >= 2:
				_labels.append({&"t0": t0, &"dur": tuning.label_dur, &"pos": _label_pos(ChainTimeline._centroid(cells)),
						&"text": tr("UI_LINES_N") % lines.size(), &"gold": true})
		ChainTimeline.Kind.FIZZLE:
			_fizzles.append({&"t0": t0, &"dur": maxf(dur, 0.1) + 0.3, &"cell": cue[ChainTimeline.K_CELL], &"crew": cue[ChainTimeline.K_CREW]})
			cue_fired.emit(kind, level, 0, _species(cue[ChainTimeline.K_CREW]))
		ChainTimeline.Kind.SHAKE:
			_wave_start(int(cue[ChainTimeline.K_WAVE]), level)


## Crew species of a cue's crew id (empty when unknown).
func _species(crew: Variant) -> StringName:
	if crew == null or visuals == null:
		return &""
	return StringName(visuals.look(crew).get(CrewVisuals.K_SPECIES, &""))


## A chain wave begins: hit-stop, punch-in toward the firing face, flash, then a
## release shake when the freeze ends (D15).
func _wave_start(wave: int, level: int) -> void:
	if level <= 0:
		return
	var hs := minf(tuning.hitstop_base_s + tuning.hitstop_step_s * (level - 1), tuning.hitstop_max_s)
	hs = minf(hs, maxf(tuning.hitstop_total_cap_s - _hitstop_used, 0.0))
	if state == State.FAST:
		hs = 0.0
	_hitstop_used += hs
	_hitstop_left = hs
	_pending_shake = 0.0 if reduced else _shake_px(level)
	if fx != null:
		fx.freeze_left = hs
		fx.flash(tuning.flash_base_alpha + tuning.flash_step_alpha * level)
		if level >= tuning.deep_level:
			fx.deep_target = 1.0
	if not reduced:
		var focus := layout.board_rect().get_center()
		if _wave_face.has(wave):
			focus = layout.cell_center(Vector2(_wave_face[wave] as Vector2i))
		_punch = {&"t": 0.0, &"z": minf(tuning.punch_zoom_step * level, tuning.punch_zoom_max), &"focus": focus,
				&"hold": hs}
	if hs <= 0.0:
		_release_shake()
	cue_fired.emit(ChainTimeline.Kind.SHAKE, level, wave, &"")


func _release_shake() -> void:
	if _pending_shake > 0.0:
		_shake = {&"t0": clock, &"dur": tuning.shake_dur, &"px": _pending_shake}
	_pending_shake = 0.0


func _update_punch(delta: float) -> void:
	zoom = 1.0
	if _punch.is_empty():
		return
	_punch[&"t"] = float(_punch[&"t"]) + delta
	var t: float = _punch[&"t"]
	var hold: float = maxf(float(_punch[&"hold"]), 0.05)
	var z: float = _punch[&"z"]
	var env := 0.0
	if t < hold:
		env = 1.0 - pow(1.0 - t / hold, 3.0)
	else:
		var q := (t - hold) / maxf(tuning.punch_release_s, 0.01)
		if q >= 1.0:
			_punch = {}
			return
		env = pow(1.0 - q, 2.0)
	zoom = 1.0 + z * env
	zoom_focus = _punch[&"focus"]


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
					&"text": "+%d" % rest, &"big": true, &"level": 1})
	if show and timeline.chain_depth >= 2:
		_banner = {&"t0": clock, &"dur": tuning.skip_flush_dur + 0.3, &"text": _chain_text(timeline.chain_depth),
				&"sub": "", &"crew": &"", &"level": 1, &"gold": false, &"stage": timeline.chain_depth, &"burst": true}
	_skipped = true
	state = State.FLUSHING
	_flush_left = tuning.skip_flush_dur if show else 0.0
	_end_camera()


func _finish() -> void:
	if not display.equals(_final_board):
		# Rule 4: truth is always final_board.
		push_error("ChainPlayer: display board != final_board after replay; redrawing from final_board")
		display = _final_board.copy()
	state = State.IDLE
	_end_camera()
	_clear_transients()
	redraw_requested.emit()
	playback_finished.emit(_skipped)


func _end_camera() -> void:
	shake_offset = Vector2.ZERO
	zoom = 1.0
	_punch = {}
	_hitstop_left = 0.0
	_pending_shake = 0.0
	_finisher_t = -1.0
	if fx != null:
		fx.deep_target = 0.0
		fx.freeze_left = 0.0


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
	_pops.clear()
	_landing = {}
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
	var amp: float = float(_shake[&"px"]) * pow(1.0 - p, 1.6)
	shake_offset = Vector2(sin(real_time * 61.0), cos(real_time * 47.0)) * amp


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


## Ability / "N줄 동시!" label anchor: above the cell, inside the board, not on another live label.
func _label_pos(cell: Vector2) -> Vector2:
	var c := layout.cell_center(cell) + Vector2(0, -layout.s * 0.9)
	c.x = clampf(c.x, layout.board_origin.x + 110, layout.board_rect().end.x - 110)
	c.y = maxf(c.y, layout.board_origin.y + 30)
	return _free_spot(c, Vector2(200, 46))


## First of c, c∓step, c∓2·step (vertical) not overlapping a live label / popup.
func _free_spot(c: Vector2, box: Vector2) -> Vector2:
	var br := layout.board_rect()
	for k: int in [0, -1, 1, -2, 2, -3]:
		var q := c + Vector2(0, box.y * k)
		if q.y < br.position.y + 20.0 or q.y > br.end.y - 20.0:
			continue
		var free := true
		for it: Dictionary in _labels + _popups:
			if clock > float(it[&"t0"]) + float(it[&"dur"]) * 0.75:
				continue
			var o: Vector2 = it[&"pos"]
			if absf(o.x - q.x) < box.x and absf(o.y - q.y) < box.y:
				free = false
				break
		if free:
			return q
	return c


## Full rows / columns inside [param cells] as [first_cell, last_cell] pairs (rows first).
func _lines(cells: Array) -> Array:
	var rows := {}
	var cols := {}
	for c: Vector2i in cells:
		rows[c.x] = int(rows.get(c.x, 0)) + 1
		cols[c.y] = int(cols.get(c.y, 0)) + 1
	var out: Array = []
	var keys: Array = rows.keys()
	keys.sort()
	for r: int in keys:
		if int(rows[r]) >= layout.cells.y:
			out.append([Vector2i(r, 0), Vector2i(r, layout.cells.y - 1)])
	keys = cols.keys()
	keys.sort()
	for c: int in keys:
		if int(cols[c]) >= layout.cells.x:
			out.append([Vector2i(0, c), Vector2i(layout.cells.x - 1, c)])
	return out


## "연쇄 N!" with one more "!" per stage from 3 (max 3 marks).
func _chain_text(stage: int) -> String:
	return tr("UI_CHAIN_N") % stage + "!".repeat(clampi(stage - 2, 0, 2))


## Escalating accent colour per chain level (UI accents only; crews keep their colours).
static func _level_colour(level: int) -> Color:
	match level:
		1: return Palette.STICKER_WHITE
		2: return Palette.GOLD
		3: return Palette.BEAK
		_: return Palette.CREW_SLOTS[6][0]


static func _pct(p: int) -> String:
	return ("%.1f" % (p / 100.0)).trim_suffix(".0")


static func _elastic(q: float) -> float:
	if q <= 0.0:
		return 0.0
	if q >= 1.0:
		return 1.0
	return pow(2.0, -9.0 * q) * sin((q * 8.0 - 0.75) * TAU / 3.0) + 1.0


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
				ci.draw_arc(r.get_center(), s * (0.3 + 0.45 * (1.0 - a)), 0, TAU, 24, Color(Palette.STICKER_WHITE, a), 5.0, true)
			else:
				StickerPainter.rounded(ci, r.grow(-2), Color(Palette.STICKER_WHITE, 0.7 * a), s * 0.2)
	for e: Dictionary in _effects:
		if not e[&"fill"]:
			_draw_effect(ci, e)
	for f: Dictionary in _flying:
		_draw_flying(ci, f)
	for z: Dictionary in _fizzles:
		var p := _progress(z)
		var c := layout.cell_center(Vector2(z[&"cell"])) - Vector2(0, s * 0.2 * p)
		StickerPainter.draw_face(ci, c, s, visuals.look(z[&"crew"]), StickerPainter.Expr.SLEEPY, 1.0 - p * 0.7)
		StickerPainter.label(ci, c + Vector2(s * 0.4, -s * 0.45), "Z", font, int(s * 0.35), Palette.INK, 4)


## Text stickers (ability labels, "N줄 동시!", score popups) — drawn after the
## [ChainFx] front layer so rings and confetti never cover the numbers.
func draw_texts(ci: CanvasItem) -> void:
	if state == State.IDLE:
		return
	var s := layout.s
	for l: Dictionary in _labels:
		var p := _progress(l)
		var c: Vector2 = l[&"pos"] + Vector2(0, -s * 0.3 * p)
		var sc := 1.0 if reduced else _back_out(minf(p / 0.18, 1.0))
		_sticker_text(ci, c, l[&"text"], int(26 * sc) if sc > 0.2 else 6, Palette.INK, 1.0 if p < 0.8 else (1.0 - p) * 5.0, l.get(&"gold", false))
	for pp: Dictionary in _popups:
		var p := _progress(pp)
		var c: Vector2 = pp[&"pos"] + Vector2(0, -60.0 * p)
		var a := 1.0 if p < 0.7 else (1.0 - p) / 0.3
		var lv: int = pp.get(&"level", 0)
		var size := (40 + 5 * lv) if pp[&"big"] else 32
		var sc := 1.0 if reduced else _back_out(minf(p / 0.16, 1.0))
		size = maxi(int(size * sc), 8)
		var txt: String = pp[&"text"]
		if float(pp.get(&"fly_at", -1.0)) >= 0.0 and clock >= float(pp[&"fly_at"]):
			txt = pp[&"base"]
		StickerPainter.label(ci, c, txt, font, size, Color(Palette.INK, a), 9, Color(Palette.GOLD if pp[&"big"] else Palette.STICKER_WHITE, a))


## Per-species ability effect drawn over its target cells (art-bible principle 2:
## the shape of the range must read). Species comes from crew data, not ids.
func _draw_effect(ci: CanvasItem, e: Dictionary) -> void:
	var s := layout.s
	var p := clampf(_progress(e) * 1.6, 0.0, 1.0)
	var fade := 1.0 - clampf((_progress(e) - 0.75) / 0.25, 0.0, 1.0)
	var fcell: Vector2i = e[&"from"]
	var from := layout.cell_center(Vector2(fcell))
	var look := visuals.look(e[&"crew"])
	var col: Color = look[CrewVisuals.K_BASE]
	var shade: Color = look[CrewVisuals.K_SHADE]
	var white := Color(Palette.STICKER_WHITE, 0.95 * fade)
	var species: StringName = e[&"species"]
	var cells: Array = e[&"cells"]
	var maxd := 1.0
	for cell: Vector2i in cells:
		maxd = maxf(maxd, float(maxi(absi(cell.x - fcell.x), absi(cell.y - fcell.y))))
	match species:
		&"bear":
			for k: int in 2:
				var q := clampf(p * 1.2 - k * 0.25, 0.0, 1.0)
				if q <= 0.0:
					continue
				var rad := lerpf(s * 0.4, s * 1.75, 1.0 - pow(1.0 - q, 3.0))
				ci.draw_arc(from, rad, 0, TAU, 40, Color(Palette.STICKER_WHITE, (1.0 - q * 0.6) * fade), 18.0 - k * 6.0, true)
				ci.draw_arc(from, rad, 0, TAU, 40, Color(col, (1.0 - q * 0.5) * fade), 10.0 - k * 4.0, true)
		&"rabbit":
			for cell: Vector2i in cells:
				var to := layout.cell_center(Vector2(cell))
				var pts := PackedVector2Array()
				var steps := 12
				for j: int in steps + 1:
					var q := float(j) / steps * p
					pts.append(from.lerp(to, q) + Vector2(0, -sin(q * PI) * s * 1.3))
				ci.draw_polyline(pts, white, 9.0, true)
				ci.draw_polyline(pts, Color(col, fade), 5.0, true)
				if p >= 1.0:
					ci.draw_arc(to, s * 0.42, 0, TAU, 20, Color(col, fade), 5.0, true)
	if species != &"bear" and species != &"rabbit":
		for cell: Vector2i in cells:
			var to := layout.cell_center(Vector2(cell))
			ci.draw_line(from, from.lerp(to, p), white, 13.0, true)
			ci.draw_line(from, from.lerp(to, p), Color(col, fade), 7.0, true)
	for cell: Vector2i in cells:
		var d := float(maxi(absi(cell.x - fcell.x), absi(cell.y - fcell.y)))
		var hit := clampf((p - d / maxd * 0.85) / 0.3, 0.0, 1.0)
		if hit <= 0.0:
			continue
		var c := layout.cell_center(Vector2(cell))
		match species:
			&"cat":
				for j: int in 3:
					var a0 := c + Vector2((-0.32 + 0.22 * j) * s, -0.36 * s)
					var a1 := c + Vector2((-0.08 + 0.22 * j) * s, 0.36 * s)
					ci.draw_line(a0, a0.lerp(a1, hit), white, 10.0, true)
					ci.draw_line(a0, a0.lerp(a1, hit), Color(shade, fade), 5.0, true)
			&"frog":
				ci.draw_arc(c, s * (0.2 + 0.35 * hit), 0, TAU, 20, Color(col, fade * (1.0 - hit * 0.5)), 5.0, true)
				ci.draw_arc(c, s * (0.1 + 0.2 * hit), 0, TAU, 16, white, 3.0, true)
			&"bear":
				ci.draw_circle(c, s * 0.16 * hit, Color(col, 0.85 * fade), true, -1.0, true)
			&"rabbit":
				pass
			_:
				ci.draw_circle(c, s * 0.14 * hit, Color(col, 0.85 * fade), true, -1.0, true)


## Draws the cut-in banner inside the banner band (rule 14): stamped-sticker slam
## with overshoot, radial rays behind from level 1, escalating size / colour /
## wobble per level, holo letters from level 3 (UI only, art-bible §4).
func draw_banner(ci: CanvasItem) -> void:
	if state == State.IDLE or _banner.is_empty():
		return
	var p := _progress(_banner)
	var rect := layout.banner_rect
	var c := rect.get_center()
	var level := maxi(int(_banner[&"level"]), 1)
	var sc := 1.0
	var rot := deg_to_rad(-4.0)
	var t := clock - float(_banner[&"t0"])
	if not reduced:
		if p < 0.12:
			var q := p / 0.12
			sc = lerpf(1.75, 0.88, q * q)
			rot = deg_to_rad(lerpf(-14.0, 3.0, q))
		elif p < 0.22:
			sc = lerpf(0.88, 1.07, (p - 0.12) / 0.1)
			rot = deg_to_rad(lerpf(3.0, -4.0, (p - 0.12) / 0.1))
		elif p < 0.32:
			sc = lerpf(1.07, 1.0, (p - 0.22) / 0.1)
		if p >= 0.22 and level >= 2:
			rot += deg_to_rad(sin(t * TAU * tuning.banner_wobble_hz) * tuning.banner_wobble_deg)
		if p >= 0.12 and not bool(_banner[&"burst"]):
			_banner[&"burst"] = true
			if fx != null:
				fx.sparkle_burst(c, 8 + 3 * level, 150.0 + 30.0 * level, Palette.GOLD)
				fx.confetti(c + Vector2(-170, 0), _crew_cols, 4 + 2 * level, 0.9)
				fx.confetti(c + Vector2(170, 0), _crew_cols, 4 + 2 * level, 0.9)
	var a := 1.0 if p < 0.8 else (1.0 - p) / 0.2
	if p >= 0.8 and not reduced:
		c.y -= 30.0 * (p - 0.8) / 0.2
	sc *= minf(1.0 + tuning.banner_scale_step * (level - 1), 1.3)
	# Radial rays behind (sticker-cut triangles), from chain level 1.
	if level >= 1 and p >= 0.08:
		var rays := 12
		var spin := 0.0 if reduced else t * 1.2
		var R := (150.0 + 28.0 * level) * minf(sc, 1.3)
		for i: int in rays:
			var a0 := spin + TAU * i / rays
			var a1 := a0 + TAU / rays * 0.45
			var col := Color(Palette.GOLD if i % 2 == 0 else Palette.STICKER_WHITE, 0.5 * a)
			ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0) * 0.55) * R, c + Vector2(cos(a1), sin(a1) * 0.55) * R]), col)
	ci.draw_set_transform(c, rot, Vector2(sc, sc))
	var sub: String = _banner[&"sub"]
	var w := 340.0
	var h := 84.0 if sub != "" else 66.0
	var border: Color = Palette.GOLD if (_banner[&"gold"] or level >= 2) else visuals.look(_banner[&"crew"])[CrewVisuals.K_BASE]
	if level >= 2 and _banner[&"crew"] != &"":
		# Double border: crew colour outside, gold inside.
		StickerPainter.rounded(ci, Rect2(-w * 0.5 - 12, -h * 0.5 - 12, w + 24, h + 24), Color(visuals.look(_banner[&"crew"])[CrewVisuals.K_BASE], a), 30)
	StickerPainter.rounded(ci, Rect2(-w * 0.5 + 3, -h * 0.5 + 8, w, h), Color(Palette.INK, 0.3 * a), 22)
	StickerPainter.rounded(ci, Rect2(-w * 0.5 - 6, -h * 0.5 - 6, w + 12, h + 12), Color(border, a), 26)
	StickerPainter.rounded(ci, Rect2(-w * 0.5, -h * 0.5, w, h), Color(Palette.STICKER_WHITE, a), 20)
	# masking-tape corner
	ci.draw_set_transform(c + Vector2(-w * 0.5 + 18, -h * 0.5).rotated(rot) * sc, rot - deg_to_rad(35), Vector2(sc, sc))
	StickerPainter.rounded(ci, Rect2(-26, -10, 52, 20), Color(Palette.FACE_CREAM.darkened(0.06), 0.9 * a), 3)
	ci.draw_set_transform(c, rot, Vector2(sc, sc))
	var ty := -12.0 if sub != "" else 0.0
	if level >= 3 and fx != null:
		fx.holo_text(ci, Vector2(0, ty), _banner[&"text"], 42, a, real_time)
	elif level >= 2:
		StickerPainter.label(ci, Vector2(0, ty), _banner[&"text"], font, 42, Color(Palette.INK, a), 10, Color(Palette.GOLD, a))
	else:
		StickerPainter.label(ci, Vector2(0, ty), _banner[&"text"], font, 40, Color(Palette.INK, a), 0)
	if sub != "":
		StickerPainter.label(ci, Vector2(0, 28), sub, font, 20, Color(Palette.INK_LIGHT, a), 0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if level >= 2 and not reduced:
		# Sparkle trail orbiting the banner (≤ 3 twinkles/s per star).
		for i: int in 2 + level:
			var ang := t * 2.2 + TAU * i / (2.0 + level)
			var sp := c + Vector2(cos(ang) * w * 0.62 * sc, sin(ang) * h * 0.85 * sc)
			ChainFx._star(ci, sp, 9.0 + 3.0 * sin(t * 9.0 + i), Color(Palette.GOLD, a))


func _draw_flying(ci: CanvasItem, f: Dictionary) -> void:
	var p := _progress(f)
	var s := layout.s
	var cell: Vector2i = f[&"cell"]
	var r := layout.cell_rect(cell)
	var look := visuals.look(f[&"crew"])
	var act: bool = f[&"activated"]
	var lift_end := 0.6 if act else 0.35
	var sx := 1.0
	var sy := 1.0
	var rot := 0.0
	var off := Vector2.ZERO
	var a := 1.0
	var dir := 1.0 if int(f[&"seed"]) % 2 == 0 else -1.0
	var shadow := 1.5
	if act:
		# Face peel: lift up off the board, tilt, shadow grows (art-bible principle 3: 10 px).
		if p < lift_end:
			var q := _back_out(p / lift_end)
			sx = lerpf(1.0, 1.22, q)
			sy = sx
			rot = deg_to_rad(-12.0 * q * dir)
			off = Vector2(0, -s * 0.32 * q)
			shadow = lerpf(1.5, 14.0, minf(p / lift_end, 1.0))
		else:
			# Fly to the cut-in band and re-stick there ("착", D6).
			var q := (p - lift_end) / (1.0 - lift_end)
			var e := q * q * (3.0 - 2.0 * q)
			var target := Vector2(layout.banner_rect.position.x + 54.0, layout.banner_rect.get_center().y) - r.get_center()
			off = Vector2(0, -s * 0.32).lerp(target, e) + Vector2(0, -sin(e * PI) * s * 0.8)
			sx = lerpf(1.22, 0.75, e)
			sy = sx
			rot = deg_to_rad(lerpf(-12.0 * dir, 8.0, e))
			shadow = lerpf(14.0, 2.0, e)
			a = 1.0 if q < 0.85 else (1.0 - q) / 0.15
	else:
		# Body pop: squash → stretch pop → spin away.
		if p < lift_end:
			var q := p / lift_end
			var k := sin(q * PI)
			sx = 1.0 + 0.2 * k
			sy = 1.0 - 0.18 * k
			if q > 0.6:
				var u := (q - 0.6) / 0.4
				sx = lerpf(sx, 1.18, u)
				sy = lerpf(sy, 1.18, u)
			shadow = lerpf(1.5, 8.0, q)
		else:
			var q := (p - lift_end) / (1.0 - lift_end)
			sx = lerpf(1.18, 0.4, q)
			sy = sx
			rot = deg_to_rad(6.0 * dir + 70.0 * q * dir)
			off = Vector2(dir * s * 0.5 * q, -s * 1.3 * q + s * 0.9 * q * q)
			shadow = 8.0
			a = 1.0 - q * q
	if reduced:
		rot = 0.0
		sx = minf(sx, 1.03)
		sy = minf(sy, 1.03)
		off = Vector2.ZERO if not act else off
	var c := r.get_center() + off
	ci.draw_set_transform(c, rot, Vector2(sx, sy))
	var local := Rect2(-r.size * 0.5, r.size)
	var rects: Array[Rect2] = [local]
	if f[&"egg"]:
		StickerPainter.rounded(ci, Rect2(local.position + Vector2(0, shadow), local.size).grow(4), Color(Palette.INK, 0.3 * a), s * 0.25)
		StickerPainter.rounded(ci, local.grow(4), Color(Palette.STICKER_WHITE, a), s * 0.25)
		StickerPainter.draw_egg_cell(ci, local, look, a)
	elif act and p < lift_end:
		StickerPainter.draw_piece(ci, rects, 0, look,
				{StickerPainter.O_ALPHA: a, StickerPainter.O_SHADOW: shadow, StickerPainter.O_EXPR: StickerPainter.Expr.ACTIVE})
	elif act:
		# In flight only the face sticker travels to the cut-in band.
		ci.draw_circle(Vector2(shadow * 0.4, shadow), s * 0.62, Color(Palette.INK, 0.28 * a), true, -1.0, true)
		StickerPainter.draw_face(ci, Vector2.ZERO, s, look, StickerPainter.Expr.ACTIVE, a)
	else:
		StickerPainter.draw_piece(ci, rects, 0 if f[&"face"] else -1, look,
				{StickerPainter.O_ALPHA: a, StickerPainter.O_SHADOW: shadow, StickerPainter.O_EXPR: StickerPainter.Expr.NORMAL})
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _sticker_text(ci: CanvasItem, c: Vector2, text: String, size: int, color: Color, a: float, gold: bool = false) -> void:
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var r := Rect2(c - Vector2(sz.x * 0.5 + 14, size * 0.5 + 8), Vector2(sz.x + 28, size + 16))
	StickerPainter.rounded(ci, Rect2(r.position + Vector2(2, 4), r.size), Color(Palette.INK, 0.3 * a), 14)
	if gold:
		StickerPainter.rounded(ci, r.grow(5), Color(Palette.GOLD, a), 18)
	StickerPainter.rounded(ci, r, Color(Palette.STICKER_WHITE, a), 14)
	StickerPainter.label(ci, c, text, font, size, Color(color, a), 0)


func _progress(item: Dictionary) -> float:
	return clampf((clock - float(item[&"t0"])) / float(item[&"dur"]), 0.0, 1.0)


static func _back_out(q: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var x := q - 1.0
	return 1.0 + c3 * x * x * x + c1 * x * x
