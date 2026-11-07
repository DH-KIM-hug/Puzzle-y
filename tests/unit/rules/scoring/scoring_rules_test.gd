## scoring AC-S01, S04, S06, S07, S13 (validation) — purity, KEEP cells, tally, crew-agnostic.
extends GdUnitTestSuite


func test_score_is_pure_and_repeatable() -> void:
	# AC-S01
	var events := EventFixture.domino_golden()
	var before := var_to_str(events.map(func(e: ChainEvent) -> Dictionary: return e.to_dict()))
	var rules := ScoringRules.new()
	var a := ScoreCalculator.score_placement(events, rules)
	var b := ScoreCalculator.score_placement(events, rules)
	assert_str(var_to_str(a.to_dict())).is_equal(var_to_str(b.to_dict()))
	assert_str(var_to_str(events.map(func(e: ChainEvent) -> Dictionary: return e.to_dict()))).is_equal(before)
	assert_int(rules.cell_points).is_equal(10)


func test_scoring_sources_contain_no_fractional_arithmetic() -> void:
	# AC-S01 AND (static check, comments excluded).
	var re := RegEx.create_from_string("\\d\\.\\d|\\bfloat\\b")
	for name: String in ["score_calculator.gd", "scoring_rules.gd", "score_breakdown.gd", "stage_score_tally.gd"]:
		var text := FileAccess.get_file_as_string("res://src/core/rules/scoring/" + name)
		assert_str(text).is_not_empty()
		for line: String in text.split("\n"):
			var code := line.strip_edges()
			if code.begins_with("#"):
				continue
			assert_object(re.search(code)).override_failure_message("%s: %s" % [name, code]).is_null()


func test_kept_cells_are_not_scored() -> void:
	# AC-S04: 6 cleared + 2 kept vs 8 cleared → exactly 2 cells' worth lower.
	var with_kept := EventFixture.new().placed(1).wave(0, 1, 0).cleared(0, 6, 0, 0, 2).end()
	var without := EventFixture.new().placed(1).wave(0, 1, 0).cleared(0, 8).end()
	var rules := ScoringRules.new()
	var diff := ScoreCalculator.score_placement(without, rules).total - ScoreCalculator.score_placement(with_kept, rules).total
	assert_int(diff).is_equal(2 * rules.cell_points)


func test_stage_tally_accumulates_and_resets() -> void:
	# AC-S06
	var t := StageScoreTally.started()
	var seen := []
	for total: int in [4, 85, 356]:
		t = StageScoreTally.committed(t, total)
		seen.append(t.stage_score)
	assert_array(seen).is_equal([4, 89, 445])
	assert_int(t.best_placement).is_equal(356)
	var retry := StageScoreTally.started()
	assert_int(retry.stage_score).is_equal(0)
	assert_int(retry.best_placement).is_equal(0)


func test_crew_identity_does_not_change_score() -> void:
	# AC-S07
	var a := EventFixture.new().crew(&"nyangi").placed(1).wave(0, 1, 0).cleared(0, 8).activated(0, 1).end()
	var b := EventFixture.new().crew(&"gomgom").placed(1).wave(0, 1, 0).cleared(0, 8).activated(0, 1).end()
	var rules := ScoringRules.new()
	assert_int(ScoreCalculator.score_placement(a, rules).total).is_equal(ScoreCalculator.score_placement(b, rules).total)


func test_invalid_rules_rejected_with_knob_name_and_value() -> void:
	# AC-S13 AND
	var r := ScoringRules.new()
	r.cell_points = 0
	assert_str(" ".join(r.validate())).contains("cell_points").contains("0")
	var r2 := ScoringRules.new()
	r2.depth_mult_max_pct = 50
	assert_str(" ".join(r2.validate())).contains("depth_mult_max_pct").contains("50")
	assert_array(Array(ScoringRules.new().validate())).is_empty()


func test_real_scoring_rules_file_loads_start_values() -> void:
	var r: ScoringRules = load("res://assets/data/rules/scoring_rules.tres")
	assert_array(Array(r.validate())).is_empty()
	assert_int(r.cell_points).is_equal(10)
	assert_int(r.depth_step_pct).is_equal(50)
	assert_int(r.activation_points_base).is_equal(20)


func test_schema_violation_scores_placement_only() -> void:
	# Edge Cases: CELLS_CLEARED without WAVE_BEGIN.
	var events := EventFixture.new().placed(3).cleared(0, 8).end()
	var holder := {}
	await assert_error(func() -> void:
		holder.s = ScoreCalculator.score_placement(events, ScoringRules.new())
	).is_push_error(ScoreCalculator.ERR_SCHEMA)
	var s: ScoreBreakdown = holder.s
	assert_int(s.total).is_equal(3)
	assert_str(s.error).is_not_empty()


func test_resolver_domino_events_score_end_to_end() -> void:
	# Integration cross-check: the resolver's AC-03 fixture. Its column 5 keeps one
	# empty cell (a stable board cannot hold a complete column), so wave 1 clears 6
	# ability cells, not AC-S09's 7: 1 + 80 + 20 + 90 + 30 + 120 = 341.
	var res := ChainFixture.resolve_single(ChainFixture.DOMINO_NG, Vector2i(7, 3))
	var s := ScoreCalculator.score_placement(res.events, ScoringRules.new())
	assert_array(s.waves.map(func(w: Dictionary) -> int: return w[ScoreBreakdown.K_CLEAR_POINTS])).is_equal([80, 90, 120])
	assert_int(s.total).is_equal(341)
