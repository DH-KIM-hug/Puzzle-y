## scoring AC-S02, S03, S05, S05b, S08, S09, S10, S11, S15, S16 — formulas F1–F5.
extends GdUnitTestSuite


func _rules() -> ScoringRules:
	# Test-only copy of the GDD start values (Tuning Knobs table).
	return ScoringRules.new()


func test_domino_golden_total_is_356() -> void:
	# Arrange (AC-S09)
	var events := EventFixture.domino_golden()
	# Act
	var s := ScoreCalculator.score_placement(events, _rules())
	# Assert
	var clear := s.waves.map(func(w: Dictionary) -> int: return w[ScoreBreakdown.K_CLEAR_POINTS])
	var act := s.waves.map(func(w: Dictionary) -> int: return w[ScoreBreakdown.K_ACTIVATION_POINTS])
	assert_array(clear).is_equal([80, 105, 120])
	assert_array(act).is_equal([20, 30, 0])
	assert_int(s.placement_points).is_equal(1)
	assert_int(s.total).is_equal(356)


func test_depth_step_from_data_changes_golden_to_461() -> void:
	# AC-S15: only depth_step_pct changes.
	var rules := _rules()
	rules.depth_step_pct = 100
	var s := ScoreCalculator.score_placement(EventFixture.domino_golden(), rules)
	assert_array(s.waves.map(func(w: Dictionary) -> int: return w[ScoreBreakdown.K_CLEAR_POINTS])).is_equal([80, 140, 180])
	assert_array(s.waves.map(func(w: Dictionary) -> int: return w[ScoreBreakdown.K_ACTIVATION_POINTS])).is_equal([20, 40, 0])
	assert_int(s.total).is_equal(461)


func test_placement_without_lines_scores_cells_only() -> void:
	# AC-S02
	var s := ScoreCalculator.score_placement(EventFixture.new().placed(4).end(), _rules())
	assert_int(s.total).is_equal(4)
	assert_array(s.waves).is_empty()


func test_line_ability_and_both_cells_are_split() -> void:
	# AC-S03: LINE 8 + BOTH 1 = 9 line cells, ABILITY 3, wave 1 with one row.
	var events := EventFixture.new().placed(1).wave(1, 1, 0).cleared(1, 8, 3, 1).end()
	var w := ScoreCalculator.score_placement(events, _rules()).wave(1)
	assert_int(w[ScoreBreakdown.K_LINE_CELLS]).is_equal(9)
	assert_int(w[ScoreBreakdown.K_ABILITY_CELLS]).is_equal(3)
	assert_int(w[ScoreBreakdown.K_CLEAR_POINTS]).is_equal(180)


func test_activation_and_fizzle_points() -> void:
	# AC-S05
	var events := EventFixture.new().placed(1).wave(0, 1, 0).cleared(0, 8).activated(0, 2) \
		.wave(6, 0, 0).cleared(6, 0, 1).fizzled(6, 1).cap(6).end()
	var rules := _rules()
	var s := ScoreCalculator.score_placement(events, rules)
	assert_int(s.wave(0)[ScoreBreakdown.K_ACTIVATION_POINTS]).is_equal(40)
	assert_int(s.wave(6)[ScoreBreakdown.K_ACTIVATION_POINTS]).is_equal(0)
	assert_int(s.fizzle_total).is_equal(0)
	rules.fizzle_points = 5
	var s5 := ScoreCalculator.score_placement(events, rules)
	assert_int(s5.total - s.total).is_equal(5)


func test_simultaneous_activations_each_scored() -> void:
	# AC-S05b: 3 × ⌊20 × 150 / 100⌋ = 90
	var events := EventFixture.new().placed(1).wave(1, 0, 0).cleared(1, 0, 3).activated(1, 3).end()
	assert_int(ScoreCalculator.score_placement(events, _rules()).wave(1)[ScoreBreakdown.K_ACTIVATION_POINTS]).is_equal(90)


func test_formula_tables_f1_f2_f3() -> void:
	# AC-S08
	var rules := _rules()
	assert_int(ScoreCalculator.placement_points(6, rules)).is_equal(6)
	var depth := []
	for k: int in 7:
		depth.append(ScoreCalculator.depth_mult_pct(k, rules))
	assert_array(depth).is_equal([100, 150, 200, 250, 300, 350, 400])
	var lines := []
	for l: int in [0, 1, 2, 3, 7]:
		lines.append(ScoreCalculator.line_mult_pct(l, rules))
	assert_array(lines).is_equal([100, 100, 200, 300, 700])
	assert_int(ScoreCalculator.depth_mult_pct(8, rules)).is_equal(400)


func test_prototype_parity_values() -> void:
	# AC-S10: row + column (15 cells, L = 2) → 300; wave 2 ABILITY 9 → 180.
	var a := EventFixture.new().placed(1).wave(0, 1, 1).cleared(0, 15).end()
	assert_int(ScoreCalculator.score_placement(a, _rules()).wave(0)[ScoreBreakdown.K_CLEAR_POINTS]).is_equal(300)
	var b := EventFixture.new().placed(1).wave(2, 0, 0).cleared(2, 0, 9).end()
	assert_int(ScoreCalculator.score_placement(b, _rules()).wave(2)[ScoreBreakdown.K_CLEAR_POINTS]).is_equal(180)


func test_floor_happens_once_per_wave() -> void:
	# AC-S11: ⌊5 × 100 × 7 × 133 / 10000⌋ = 46 (per-cell flooring would give 45).
	var rules := _rules()
	rules.cell_points = 7
	rules.depth_step_pct = 33
	var events := EventFixture.new().placed(1).wave(1, 1, 0).cleared(1, 5).end()
	assert_int(ScoreCalculator.score_placement(events, rules).wave(1)[ScoreBreakdown.K_CLEAR_POINTS]).is_equal(46)


func test_cap_reaching_placement() -> void:
	# AC-S16
	var f := EventFixture.new().placed(1).wave(0, 1, 0).cleared(0, 8).activated(0, 1)
	for k: int in range(1, 6):
		f.wave(k, 0, 0).cleared(k, 0, 1).activated(k, 1)
	var events := f.wave(6, 0, 0).cleared(6, 0, 9).fizzled(6, 2).cap(6).end()
	var s := ScoreCalculator.score_placement(events, _rules())
	var w6 := s.wave(6)
	assert_int(w6[ScoreBreakdown.K_DEPTH_MULT_PCT]).is_equal(400)
	assert_int(w6[ScoreBreakdown.K_CLEAR_POINTS]).is_equal(360)
	assert_int(w6[ScoreBreakdown.K_ACTIVATION_POINTS]).is_equal(0)
	assert_int(s.fizzled).is_equal(2)
	assert_int(s.fizzle_total).is_equal(0)


func test_upper_bound_wave_has_no_overflow() -> void:
	# AC-S13: 64 LINE cells, L = 16, k = 6 → positive and ≤ F6 total_max.
	var events := EventFixture.new().placed(6).wave(6, 8, 8).cleared(6, 64).end()
	var rules := _rules()
	var s := ScoreCalculator.score_placement(events, rules)
	var total_max := 6 * rules.place_points_per_cell \
		+ 128 * rules.cell_points * ScoreCalculator.line_mult_pct(16, rules) * rules.depth_mult_max_pct / 10000 \
		+ 64 * rules.activation_points_base * rules.depth_mult_max_pct / 100
	assert_int(s.total).is_greater(0)
	assert_int(s.total).is_less_equal(total_max)
