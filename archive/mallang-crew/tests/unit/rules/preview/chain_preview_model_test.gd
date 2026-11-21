## chain-preview AC-P06 … AC-P09, AC-P11 — the pure display model (rules 3–5, 13, 17, F3).
extends GdUnitTestSuite


func _model(rows: Array, anchor: Vector2i, settings: PreviewSettings = null, depth_cap: int = 6) -> PreviewModel:
	return PreviewModel.build_preview_model(ChainFixture.resolve_single(rows, anchor, ChainFixture.ctx(depth_cap)), settings)


func _badge_at(m: PreviewModel, cell: Vector2i) -> Dictionary:
	for b: Dictionary in m.badges:
		if b[PreviewModel.K_CELL] == cell:
			return b
	return {}


func test_domino_badges_show_stage_and_banner_chain_two() -> void:
	# Arrange / Act (AC-P06)
	var m := _model(ChainFixture.DOMINO_NG, Vector2i(7, 3))
	# Assert
	assert_int(_badge_at(m, Vector2i(7, 5))[PreviewModel.K_STAGE]).is_equal(1)
	assert_int(_badge_at(m, Vector2i(4, 5))[PreviewModel.K_STAGE]).is_equal(2)
	assert_int(m.banner).is_equal(PreviewModel.Banner.CHAIN)
	assert_int(m.banner_n).is_equal(2)


func test_banner_tiers_follow_f3() -> void:
	# AC-P07
	assert_int(PreviewModel.banner_for(0, false)).is_equal(PreviewModel.Banner.NONE)
	assert_int(PreviewModel.banner_for(1, false)).is_equal(PreviewModel.Banner.ABILITY)
	assert_int(PreviewModel.banner_for(3, false)).is_equal(PreviewModel.Banner.CHAIN)
	assert_int(PreviewModel.banner_for(6, true)).is_equal(PreviewModel.Banner.CHAIN_MAX)
	assert_int(PreviewModel.banner_for(0, true)).is_equal(PreviewModel.Banner.NONE)
	assert_int(_model(ChainFixture.DEPTH_CHAIN, Vector2i(7, 7), null, 0).banner).is_equal(PreviewModel.Banner.NONE)
	var no_banner := PreviewSettings.new()
	no_banner.preview_detail = PreviewSettings.Detail.NO_BANNER
	assert_int(_model(ChainFixture.DOMINO_NG, Vector2i(7, 3), no_banner).banner).is_equal(PreviewModel.Banner.NONE)


func test_depth_cap_face_gets_sleep_badge_and_max_number_is_six() -> void:
	# AC-P08
	var m := _model(ChainFixture.DEPTH_CHAIN, Vector2i(7, 7))
	var max_stage := 0
	var sleepers := 0
	for b: Dictionary in m.badges:
		if b[PreviewModel.K_KIND] == PreviewModel.BadgeKind.STAGE:
			max_stage = maxi(max_stage, b[PreviewModel.K_STAGE])
		elif b[PreviewModel.K_KIND] == PreviewModel.BadgeKind.SLEEP:
			sleepers += 1
	assert_int(max_stage).is_equal(6)
	assert_int(sleepers).is_equal(1)
	assert_int(m.banner).is_equal(PreviewModel.Banner.CHAIN_MAX)


func test_default_settings_carry_no_score() -> void:
	# AC-P09
	var m := _model(ChainFixture.DOMINO_NG, Vector2i(7, 3))
	assert_bool(m.to_dict().has(&"predicted_score")).is_false()
	assert_object(m.breakdown).is_null()
	var shown := _model(ChainFixture.DOMINO_NG, Vector2i(7, 3), PreviewSettings.with_score(ScoringRules.new()))
	assert_int(shown.to_dict()[&"predicted_score"]).is_equal(341)


func test_first_stage_only_hides_later_stages_and_says_so() -> void:
	# AC-P11
	var s := PreviewSettings.new()
	s.preview_detail = PreviewSettings.Detail.FIRST_STAGE_ONLY
	var m := _model(ChainFixture.DOMINO_NG, Vector2i(7, 3), s)
	assert_int(_badge_at(m, Vector2i(7, 5))[PreviewModel.K_STAGE]).is_equal(1)
	assert_int(_badge_at(m, Vector2i(4, 5))[PreviewModel.K_KIND]).is_equal(PreviewModel.BadgeKind.HIDDEN)
	for waves: Array in m.clear_waves.values():
		assert_array(waves).is_equal([0])
	assert_int(m.banner).is_equal(PreviewModel.Banner.ABILITY)
