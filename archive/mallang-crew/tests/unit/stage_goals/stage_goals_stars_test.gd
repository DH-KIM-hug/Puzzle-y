## design/gdd/stage-goals.md AC-SG13 (F5–F7) and F1, F2.
extends GdUnitTestSuite

const STARS := [1700, 2400]


func test_final_score_and_stars_table() -> void:
	# AC-SG13: (stage_score, pieces_left, cleared) → final / stars.
	var cases := [[1240, 5, true, 1740, 2], [1900, 6, true, 2500, 3], [1500, 1, true, 1600, 1], [3000, 0, false, 3000, 0]]
	for c: Array in cases:
		var bonus := StageScoring.leftover_bonus(c[2], c[1], 100, 10, 10)
		var final := StageScoring.final_score(c[0], bonus)
		assert_int(final).is_equal(c[3])
		assert_int(StageScoring.stars(c[2], final, PackedInt32Array(STARS), 10, 10)).is_equal(c[4])


func test_pts_eff_scales_with_cell_points() -> void:
	# F1 example: [600, 750] at cell_points 15 → 900, 1125.
	assert_int(StageScoring.pts_eff(600, 15, 10)).is_equal(900)
	assert_int(StageScoring.pts_eff(750, 15, 10)).is_equal(1125)
	assert_int(StageScoring.pts_eff(160, 10, 10)).is_equal(160)


func test_pieces_left_and_unlimited() -> void:
	# F2
	assert_int(StageScoring.pieces_left(16, 11)).is_equal(5)
	assert_int(StageScoring.pieces_left(StageDef.UNLIMITED, 30)).is_equal(StageDef.UNLIMITED)
	assert_int(StageScoring.leftover_bonus(true, StageDef.UNLIMITED, 100, 10, 10)).is_equal(0)
