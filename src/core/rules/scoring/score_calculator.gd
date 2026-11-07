## Placement scoring (design/gdd/scoring.md). Pure: reads only the resolver
## events and [ScoringRules]; integer arithmetic, one floor per wave (F4).
## Preview and commit call the same function on the same events (rule 3).
class_name ScoreCalculator
extends RefCounted

## push_error text when the event list violates the schema.
const ERR_SCHEMA := "ScoreCalculator.score_placement: event schema violation"


## F1: [code]n_placed × place_points_per_cell[/code].
static func placement_points(n_placed: int, rules: ScoringRules) -> int:
	return n_placed * rules.place_points_per_cell


## F2: [code]min(100 + depth_step_pct × k, depth_mult_max_pct)[/code].
static func depth_mult_pct(k: int, rules: ScoringRules) -> int:
	return mini(100 + rules.depth_step_pct * k, rules.depth_mult_max_pct)


## F3: [code]100 + multi_line_step_pct × max(0, L − 1)[/code].
static func line_mult_pct(line_count: int, rules: ScoringRules) -> int:
	return 100 + rules.multi_line_step_pct * maxi(0, line_count - 1)


## F4 clear points of one wave (single floor).
static func clear_points(n_line: int, n_ability: int, line_count: int, k: int, rules: ScoringRules) -> int:
	return (n_line * line_mult_pct(line_count, rules) + n_ability * 100) * rules.cell_points * depth_mult_pct(k, rules) / 10000


## Scores one placement's events (F5). Schema violations (CELLS_CLEARED or
## FACE_ACTIVATED without a WAVE_BEGIN of the same wave, or a wave going
## backwards) are reported with [constant ERR_SCHEMA] and the placement is scored
## with placement points only.
static func score_placement(events: Array[ChainEvent], rules: ScoringRules) -> ScoreBreakdown:
	var out := ScoreBreakdown.new()
	var current := -1
	var by_wave := {}
	var order: Array[int] = []
	for e: ChainEvent in events:
		match e.type:
			ChainEvent.Type.PLACED:
				out.placement_points = placement_points((e.data[ChainEvent.K_CELLS] as Array).size(), rules)
			ChainEvent.Type.WAVE_BEGIN:
				if e.wave <= current:
					return _schema_error(out)
				current = e.wave
				var w := {
					ScoreBreakdown.K_WAVE: e.wave,
					ScoreBreakdown.K_LINE_COUNT: (e.data[ChainEvent.K_ROWS] as Array).size() + (e.data[ChainEvent.K_COLS] as Array).size(),
					ScoreBreakdown.K_LINE_CELLS: 0,
					ScoreBreakdown.K_ABILITY_CELLS: 0,
					ScoreBreakdown.K_DEPTH_MULT_PCT: depth_mult_pct(e.wave, rules),
					ScoreBreakdown.K_LINE_MULT_PCT: 100,
					ScoreBreakdown.K_CLEAR_POINTS: 0,
					ScoreBreakdown.K_ACTIVATION_POINTS: 0,
				}
				w[ScoreBreakdown.K_LINE_MULT_PCT] = line_mult_pct(w[ScoreBreakdown.K_LINE_COUNT], rules)
				by_wave[e.wave] = w
				order.append(e.wave)
			ChainEvent.Type.CELLS_CLEARED:
				if e.wave != current:
					return _schema_error(out)
				var w: Dictionary = by_wave[current]
				for cell: Dictionary in e.data[ChainEvent.K_CELLS]:
					if cell[ChainEvent.K_BY] == ChainEvent.BY_ABILITY:
						w[ScoreBreakdown.K_ABILITY_CELLS] += 1
					else:
						w[ScoreBreakdown.K_LINE_CELLS] += 1
			ChainEvent.Type.FACE_ACTIVATED:
				if e.wave != current:
					return _schema_error(out)
				var w: Dictionary = by_wave[current]
				w[ScoreBreakdown.K_ACTIVATION_POINTS] += rules.activation_points_base * depth_mult_pct(current, rules) / 100
			ChainEvent.Type.FACE_FIZZLED:
				out.fizzled += 1
			_:
				pass
	var total := out.placement_points
	for k: int in order:
		var w: Dictionary = by_wave[k]
		w[ScoreBreakdown.K_CLEAR_POINTS] = clear_points(w[ScoreBreakdown.K_LINE_CELLS], w[ScoreBreakdown.K_ABILITY_CELLS], w[ScoreBreakdown.K_LINE_COUNT], k, rules)
		total += w[ScoreBreakdown.K_CLEAR_POINTS] + w[ScoreBreakdown.K_ACTIVATION_POINTS]
		w.make_read_only()
		out.waves.append(w)
	out.fizzle_total = rules.fizzle_points * out.fizzled
	out.total = total + out.fizzle_total
	return out


static func _schema_error(out: ScoreBreakdown) -> ScoreBreakdown:
	push_error(ERR_SCHEMA)
	var safe := ScoreBreakdown.new()
	safe.placement_points = out.placement_points
	safe.total = out.placement_points
	safe.error = ERR_SCHEMA
	return safe
