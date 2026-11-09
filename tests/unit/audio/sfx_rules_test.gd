## design/gdd/audio.md F1–F6 and Core Rules D–E: pitch ladders, voice
## admission, fast-forward filter and the cue → sound mapping (AC-A02–A08, A10).
extends GdUnitTestSuite

const TUNING_PATH := "res://assets/data/audio/audio_tuning.tres"
const EPS := 0.001

var _t: AudioTuning


func before() -> void:
	_t = load(TUNING_PATH)


func _ids(reqs: Array[Dictionary]) -> Array:
	var out := []
	for r: Dictionary in reqs:
		out.append(r[SfxRules.R_ID])
	return out


func test_chain_pitch_rises_whole_tone_per_depth_and_caps_at_6() -> void:
	var expected := [1.0, 1.0, 1.122, 1.260, 1.414, 1.587, 1.782, 1.782]
	for d: int in expected.size():
		assert_float(SfxRules.chain_pitch(d, _t)).is_equal_approx(expected[d], EPS)


func test_cascade_pitch_line_order_rises_and_caps() -> void:
	assert_float(SfxRules.cascade_pitch(0, 0, _t)).is_equal_approx(1.0, EPS)
	assert_float(SfxRules.cascade_pitch(1, 0, _t)).is_equal_approx(1.122, EPS)
	assert_float(SfxRules.cascade_pitch(2, 0, _t)).is_equal_approx(1.260, EPS)
	assert_float(SfxRules.cascade_pitch(9, 0, _t)).is_equal_approx(SfxRules.cascade_pitch(4, 0, _t), EPS)


func test_line_flash_three_lines_pitch_and_delay_follow_cascade() -> void:
	var pitches := [1.0, 1.122, 1.260]
	for i: int in 3:
		var r := SfxRules.cue_requests(ChainTimeline.Kind.LINE_FLASH, 0, i, &"", false, _t, 0.05)
		assert_array(_ids(r)).contains_exactly([&"line_sweep"])
		assert_float(r[0][SfxRules.R_PITCH]).is_equal_approx(pitches[i], EPS)
		assert_float(r[0][SfxRules.R_DELAY]).is_equal_approx(0.05 * i, EPS)


func test_shake_uses_wave_depth_for_chain_hit() -> void:
	var r := SfxRules.cue_requests(ChainTimeline.Kind.SHAKE, 4, 6, &"", false, _t, 0.05)
	assert_array(_ids(r)).contains_exactly([&"chain_hit"])
	assert_float(r[0][SfxRules.R_PITCH]).is_equal_approx(1.782, EPS)


func test_effect_maps_each_species_and_unknown_falls_back() -> void:
	var expected := {&"cat": &"ab_cat_claw", &"bear": &"ab_bear_thump", &"chick": &"ab_chick_pop",
			&"sheep": &"ab_sheep_pop", &"frog": &"ab_frog_splash", &"rabbit": &"ab_rabbit_hop", &"dragon": &"cell_pop"}
	for sp: StringName in expected:
		var r := SfxRules.cue_requests(ChainTimeline.Kind.EFFECT, 1, 0, sp, false, _t, 0.05)
		assert_array(_ids(r)).contains_exactly([expected[sp]])


func test_peel_sticker_sound_only_on_first_peel_of_wave() -> void:
	var first := SfxRules.cue_requests(ChainTimeline.Kind.PEEL, 1, 1, &"cat", true, _t, 0.05)
	var later := SfxRules.cue_requests(ChainTimeline.Kind.PEEL, 1, 1, &"cat", false, _t, 0.05)
	assert_array(_ids(first)).contains_exactly([&"sticker_peel", &"cell_pop"])
	assert_array(_ids(later)).contains_exactly([&"cell_pop"])


func test_finisher_plays_fanfare_and_confetti() -> void:
	var r := SfxRules.cue_requests(SfxRules.KIND_FINISHER, 4, 0, &"", false, _t, 0.05)
	assert_array(_ids(r)).contains_exactly([&"finisher_fanfare", &"confetti_burst"])


func test_silent_cues_request_nothing() -> void:
	for k: int in [ChainTimeline.Kind.LABEL, ChainTimeline.Kind.POPUP, ChainTimeline.Kind.MODIFY, ChainTimeline.Kind.END]:
		assert_int(SfxRules.cue_requests(k, 1, 0, &"cat", false, _t, 0.05).size()).is_equal(0)


func test_fast_forward_drops_low_priority_and_attenuates() -> void:
	assert_bool(SfxRules.admit_fast(&"cell_pop", true, _t)).is_false()
	assert_bool(SfxRules.admit_fast(&"line_sweep", true, _t)).is_false()
	assert_bool(SfxRules.admit_fast(&"chain_hit", true, _t)).is_true()
	assert_bool(SfxRules.admit_fast(&"cell_pop", false, _t)).is_true()
	assert_float(SfxRules.voice_db(&"chain_hit", true, _t)).is_equal_approx(_t.gain_db(&"chain_hit") - 6.0, EPS)


func test_repeat_gap_blocks_same_frame_and_allows_after_gap() -> void:
	assert_bool(SfxRules.admit_repeat(1.0, 1.0, 0.035)).is_false()
	assert_bool(SfxRules.admit_repeat(1.035, 1.0, 0.035)).is_true()
	assert_bool(SfxRules.admit_repeat(0.0, -INF, 0.035)).is_true()


func test_pick_voice_prefers_free_then_oldest_lowest_priority() -> void:
	var busy: Array[bool] = [true, false, true]
	var prios: Array[int] = [0, 0, 0]
	var starts: Array[float] = [0.0, 0.0, 0.0]
	assert_int(SfxRules.pick_voice(busy, prios, starts, 0)).is_equal(1)
	var full: Array[bool] = [true, true, true]
	var mixed: Array[int] = [2, 0, 0]
	var t: Array[float] = [0.0, 0.5, 0.2]
	assert_int(SfxRules.pick_voice(full, mixed, t, 2)).is_equal(2)


func test_pick_voice_drops_when_pool_holds_only_higher_priority() -> void:
	var full: Array[bool] = [true, true]
	var prios: Array[int] = [3, 3]
	var starts: Array[float] = [0.0, 0.1]
	assert_int(SfxRules.pick_voice(full, prios, starts, 0)).is_equal(-1)
	assert_int(SfxRules.pick_voice(full, prios, starts, 3)).is_equal(0)


func test_tick_pitch_rises_half_semitone_and_caps() -> void:
	assert_float(SfxRules.tick_pitch(0, _t)).is_equal_approx(1.0, EPS)
	assert_float(SfxRules.tick_pitch(11, _t)).is_equal_approx(pow(2.0, 5.5 / 12.0), EPS)
	assert_float(SfxRules.tick_pitch(40, _t)).is_equal_approx(pow(2.0, 7.0 / 12.0), EPS)


func test_jitter_stays_within_cents() -> void:
	assert_float(SfxRules.jitter(1.0, 25.0)).is_equal_approx(pow(2.0, 25.0 / 1200.0), EPS)
	assert_float(SfxRules.jitter(-1.0, 25.0)).is_equal_approx(pow(2.0, -25.0 / 1200.0), EPS)
	assert_float(SfxRules.jitter(0.7, 0.0)).is_equal(1.0)


func test_bus_db_half_volume_is_minus_6_and_zero_mutes() -> void:
	assert_float(SfxRules.bus_db(0.5)).is_equal_approx(-6.0206, 0.01)
	assert_bool(is_inf(SfxRules.bus_db(0.0))).is_true()
	assert_float(SfxRules.bus_db(1.0)).is_equal_approx(0.0, EPS)
