## Chain playback timeline (design/gdd/chain-presentation.md rule 5, F1–F5).
##
## [method build] is a pure function of the resolver events, the score breakdown
## and the tuning: no time, frame or global state is read, so the same input
## always yields the same cue list. It only lays out WHEN to show what the events
## already say — it never judges lines, ranges or order (rule 3).
## [method apply_cue] applies a cue to a display-only [BoardState] copy (rule 4);
## replaying every cue on the pre-board must reproduce [code]final_board[/code].
## [codeblock]
## var tl := ChainTimeline.build(commit.result.events, commit.breakdown, tuning)
## for cue in tl.cues: ChainTimeline.apply_cue(display, cue, placement_id)
## [/codeblock]
class_name ChainTimeline
extends RefCounted

## Cue kinds.
enum Kind { PLACE, LINE_FLASH, PEEL, LABEL, BANNER, EFFECT, EGG, FIZZLE, POPUP, SHAKE, CAP_BANNER, MODIFY, END }

const K_T := &"t"
const K_DUR := &"dur"
const K_KIND := &"kind"
const K_SEQ := &"seq"
const K_WAVE := &"wave"
const K_CELL := &"cell"
const K_CELLS := &"cells"
const K_CREW := &"crew"
const K_FACE := &"face"
const K_ORIGIN := &"origin"
const K_ACTIVATED := &"activated"
const K_STAGE := &"stage"
const K_POINTS := &"points"
const K_MULT_PCT := &"mult_pct"
const K_LEVEL := &"level"
const K_EFFECT_KIND := &"effect_kind"
const K_MODIFIERS := &"modifiers"

## Cues sorted by start time (ties keep event order).
var cues: Array[Dictionary] = []
## Total playback length after compression and speed preference (F4 T_play).
var total: float = 0.0
## Uncompressed length (F4 T_raw).
var raw_total: float = 0.0
## Compression factor c (F4).
var compression: float = 1.0
## Number of waves.
var waves: int = 0
## Deepest stage reached (chain_depth).
var chain_depth: int = 0


## Pure: timeline for one placement.
static func build(events: Array[ChainEvent], breakdown: ScoreBreakdown, tuning: PresentationTuning) -> ChainTimeline:
	var tl := ChainTimeline.new()
	var raw: Array[Dictionary] = []
	var placed: Array = []
	var face_cell_by_order := {}
	var crew_by_order := {}
	var by_wave := {}
	var cap := false
	for e: ChainEvent in events:
		match e.type:
			ChainEvent.Type.PLACED:
				placed = e.data[ChainEvent.K_CELLS]
				raw.append({K_T: 0.0, K_DUR: tuning.place_dur, K_KIND: Kind.PLACE, K_SEQ: e.seq, K_CELLS: placed,
						K_CREW: e.data[ChainEvent.K_CREW_ID], K_CELL: e.data[ChainEvent.K_FACE_CELL]})
				if breakdown != null and breakdown.placement_points > 0:
					raw.append({K_T: 0.0, K_DUR: tuning.popup_dur, K_KIND: Kind.POPUP, K_SEQ: e.seq, K_WAVE: -1,
							K_CELL: _centroid(placed), K_POINTS: breakdown.placement_points, K_MULT_PCT: 100})
			ChainEvent.Type.CHAIN_END:
				cap = e.data[ChainEvent.K_CAP_REACHED]
				tl.chain_depth = e.data[ChainEvent.K_CHAIN_DEPTH]
			_:
				if e.wave >= 0:
					if not by_wave.has(e.wave):
						by_wave[e.wave] = []
					(by_wave[e.wave] as Array).append(e)
				if e.type == ChainEvent.Type.FACE_ACTIVATED:
					face_cell_by_order[e.data[ChainEvent.K_ORDER_INDEX]] = e.data[ChainEvent.K_CELL]
					crew_by_order[e.data[ChainEvent.K_ORDER_INDEX]] = e.data[ChainEvent.K_CREW_ID]
	var wave_ids: Array = by_wave.keys()
	wave_ids.sort()
	tl.waves = wave_ids.size()
	var t := tuning.place_dur
	var prev_eggs: Array = []
	for wi: int in wave_ids.size():
		var k: int = wave_ids[wi]
		var evs: Array = by_wave[k]
		var tempo := tuning.tempo(k)
		var level := 0 if k == 0 else mini(k, tuning.level_cap)
		var has_next := wi + 1 < wave_ids.size()
		var activations: Array = []
		var effects: Array = []
		for e: ChainEvent in evs:
			if e.type == ChainEvent.Type.FACE_ACTIVATED:
				activations.append(e)
			elif e.type == ChainEvent.Type.ABILITY_EFFECT:
				effects.append(e)
		var whiff := not activations.is_empty()
		for e: ChainEvent in effects:
			if e.data[ChainEvent.K_KIND] == ChainEvent.KIND_FILL or not (e.data[ChainEvent.K_CELLS] as Array).is_empty():
				whiff = false
		var face_start := {}  # order_index -> t
		for i: int in activations.size():
			var a: ChainEvent = activations[i]
			face_start[a.data[ChainEvent.K_ORDER_INDEX]] = t + minf(tuning.face_gap * i, tuning.face_stagger_cap) * tempo
		var activated_cells := {}
		for a: ChainEvent in activations:
			activated_cells[a.data[ChainEvent.K_CELL]] = a.data[ChainEvent.K_ORDER_INDEX]
		var spread := ((tuning.peel_dur + tuning.gap_dur) * tempo - tuning.face_lead - tuning.arrive_hold) if has_next else tuning.whiff_dur
		var wave_eggs: Array = []
		for e: ChainEvent in evs:
			match e.type:
				ChainEvent.Type.WAVE_BEGIN:
					if level >= 1:
						raw.append({K_T: t, K_DUR: tuning.shake_dur, K_KIND: Kind.SHAKE, K_SEQ: e.seq, K_WAVE: k, K_LEVEL: level})
				ChainEvent.Type.CELL_MODIFIED:
					raw.append({K_T: t, K_DUR: 0.12, K_KIND: Kind.MODIFY, K_SEQ: e.seq, K_WAVE: k,
							K_CELL: e.data[ChainEvent.K_CELL], K_MODIFIERS: e.data[ChainEvent.K_MODIFIERS_AFTER]})
				ChainEvent.Type.CELLS_CLEARED:
					var line_cells: Array = []
					var cleared_cells: Array = []
					for c: Dictionary in e.data[ChainEvent.K_CELLS]:
						var cell := Vector2i(c[ChainEvent.K_R], c[ChainEvent.K_C])
						cleared_cells.append(cell)
						var by: StringName = c[ChainEvent.K_BY]
						if by != ChainEvent.BY_ABILITY:
							line_cells.append(cell)
						var ref := ChainEvent.NO_CELL
						if by != ChainEvent.BY_LINE and face_cell_by_order.has(c[ChainEvent.K_SOURCE_ORDER]):
							ref = face_cell_by_order[c[ChainEvent.K_SOURCE_ORDER]]
						else:
							ref = _nearest(cell, placed if k == 0 else prev_eggs)
						var d := 0 if ref == ChainEvent.NO_CELL else maxi(absi(cell.x - ref.x), absi(cell.y - ref.y))
						var start := t + minf(tuning.stagger_step * d, tuning.stagger_cap) * tempo
						var dur := tuning.cell_lift_dur
						var act := activated_cells.has(cell)
						if act:
							start = face_start[activated_cells[cell]]
							dur = tuning.face_lead + tuning.cell_lift_dur
						raw.append({K_T: start, K_DUR: dur, K_KIND: Kind.PEEL, K_SEQ: e.seq, K_WAVE: k, K_CELL: cell,
								K_CREW: c[ChainEvent.K_CREW_ID], K_FACE: c[ChainEvent.K_IS_FACE], K_ORIGIN: c[ChainEvent.K_ORIGIN],
								K_ACTIVATED: act, K_LEVEL: level})
					if not line_cells.is_empty():
						raw.append({K_T: t, K_DUR: 0.06, K_KIND: Kind.LINE_FLASH, K_SEQ: e.seq, K_WAVE: k, K_CELLS: line_cells})
					if breakdown != null:
						var w := breakdown.wave(k)
						if not w.is_empty():
							raw.append({K_T: t, K_DUR: tuning.popup_dur, K_KIND: Kind.POPUP, K_SEQ: e.seq, K_WAVE: k,
									K_CELL: _centroid(cleared_cells), K_LEVEL: level,
									K_POINTS: int(w[ScoreBreakdown.K_CLEAR_POINTS]) + int(w[ScoreBreakdown.K_ACTIVATION_POINTS]),
									K_MULT_PCT: int(w[ScoreBreakdown.K_DEPTH_MULT_PCT])})
				ChainEvent.Type.FACE_ACTIVATED:
					var oi: int = e.data[ChainEvent.K_ORDER_INDEX]
					var stage: int = e.data[ChainEvent.K_STAGE]
					if stage == 1:
						raw.append({K_T: face_start[oi], K_DUR: tuning.label_dur, K_KIND: Kind.LABEL, K_SEQ: e.seq, K_WAVE: k,
								K_CELL: e.data[ChainEvent.K_CELL], K_CREW: e.data[ChainEvent.K_CREW_ID], K_STAGE: stage})
					elif activations[0] == e:
						raw.append({K_T: t, K_DUR: tuning.banner_dur, K_KIND: Kind.BANNER, K_SEQ: e.seq, K_WAVE: k,
								K_CREW: e.data[ChainEvent.K_CREW_ID], K_STAGE: stage, K_LEVEL: level})
				ChainEvent.Type.ABILITY_EFFECT:
					var oi: int = e.data[ChainEvent.K_ORDER_INDEX]
					var t_eff: float = face_start.get(oi, t) + tuning.face_lead
					var cells: Array = e.data[ChainEvent.K_CELLS]
					var is_fill: bool = e.data[ChainEvent.K_KIND] == ChainEvent.KIND_FILL
					raw.append({K_T: t_eff, K_DUR: spread, K_KIND: Kind.EFFECT, K_SEQ: e.seq, K_WAVE: k,
							K_CELL: face_cell_by_order.get(oi, ChainEvent.NO_CELL), K_CELLS: cells, K_CREW: crew_by_order.get(oi, &""),
							K_EFFECT_KIND: e.data[ChainEvent.K_KIND]})
					if is_fill:
						for j: int in cells.size():
							var te := t_eff + minf(tuning.egg_gap * j, maxf(spread - tuning.egg_pop_dur, 0.0))
							raw.append({K_T: te, K_DUR: tuning.egg_pop_dur, K_KIND: Kind.EGG, K_SEQ: e.seq, K_WAVE: k,
									K_CELL: cells[j], K_CREW: crew_by_order.get(oi, &"")})
							wave_eggs.append(cells[j])
				ChainEvent.Type.FACE_FIZZLED:
					raw.append({K_T: t, K_DUR: tuning.peel_dur * tempo, K_KIND: Kind.FIZZLE, K_SEQ: e.seq, K_WAVE: k,
							K_CELL: e.data[ChainEvent.K_CELL], K_CREW: e.data[ChainEvent.K_CREW_ID]})
				ChainEvent.Type.DEPTH_CAP_REACHED:
					pass
		prev_eggs = wave_eggs
		var gap := tuning.gap_dur * tempo if has_next else (tuning.whiff_dur if whiff else 0.0)
		var stagger := minf(tuning.face_gap * (activations.size() - 1), tuning.face_stagger_cap) * tempo if activations.size() > 1 else 0.0
		t += tuning.peel_dur * tempo + gap + stagger
	if cap:
		raw.append({K_T: t, K_DUR: tuning.banner_dur, K_KIND: Kind.CAP_BANNER, K_SEQ: events.size(), K_WAVE: -1})
		t += tuning.cap_hold
	if tl.waves > 0:
		t += tuning.settle_dur
	tl.raw_total = t
	tl.compression = maxf(tuning.c_min, minf(1.0, tuning.t_budget / t)) if t > 0.0 else 1.0
	var scale := tl.compression / maxf(tuning.speed_pref, 0.01)
	for c: Dictionary in raw:
		c[K_T] = float(c[K_T]) * scale
		c[K_DUR] = float(c[K_DUR]) * scale
	tl.total = t * scale
	raw.append({K_T: tl.total, K_DUR: 0.0, K_KIND: Kind.END, K_SEQ: events.size()})
	# Stable sort by start time.
	var idx: Array = range(raw.size())
	idx.sort_custom(func(a: int, b: int) -> bool:
		var ta: float = raw[a][K_T]
		var tb: float = raw[b][K_T]
		return ta < tb or (is_equal_approx(ta, tb) and a < b))
	for i: int in idx:
		tl.cues.append(raw[i])
	return tl


## Applies [param cue] to the display-only [param board] (rule 4). Only PLACE,
## PEEL, EGG and MODIFY change cells.
static func apply_cue(board: BoardState, cue: Dictionary, placement_id: int) -> void:
	match int(cue[K_KIND]):
		Kind.PLACE:
			var face: Vector2i = cue[K_CELL]
			for cell: Vector2i in cue[K_CELLS]:
				board.set_tile(board.index_of_cell(cell), cue[K_CREW], cell == face, BoardState.ORIGIN_PIECE, placement_id)
		Kind.PEEL:
			board.set_empty(board.index_of_cell(cue[K_CELL]))
		Kind.EGG:
			board.set_tile(board.index_of_cell(cue[K_CELL]), cue[K_CREW], false, BoardState.ORIGIN_EGG, placement_id)
		Kind.MODIFY:
			board.set_modifiers(board.index_of_cell(cue[K_CELL]), cue[K_MODIFIERS])


## Earliest cue start per event seq (rule 7 check helper).
func event_start_times() -> Dictionary:
	var out := {}
	for c: Dictionary in cues:
		var s: int = c[K_SEQ]
		if not out.has(s) or float(c[K_T]) < float(out[s]):
			out[s] = c[K_T]
	return out


static func _centroid(cells: Array) -> Vector2:
	if cells.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for c: Vector2i in cells:
		sum += Vector2(c)
	return sum / cells.size()


static func _nearest(cell: Vector2i, refs: Array) -> Vector2i:
	var best := ChainEvent.NO_CELL
	var best_d := 1 << 30
	for r: Vector2i in refs:
		var d := maxi(absi(cell.x - r.x), absi(cell.y - r.y))
		if d < best_d:
			best_d = d
			best = r
	return best
