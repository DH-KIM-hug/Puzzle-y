## design/gdd/audio.md rules 4, 6, 8 and AC-A01, A04, A09, A10: the pooled
## player stays silent until armed, limits repeats / voices, every listed sound
## has a small mono WAV, and settings map onto the buses.
extends GdUnitTestSuite

const TUNING_PATH := "res://assets/data/audio/audio_tuning.tres"

var _t: AudioTuning


func before() -> void:
	_t = load(TUNING_PATH)


func _player() -> SfxPlayer:
	var p: SfxPlayer = auto_free(SfxPlayer.new())
	p.tuning = _t
	add_child(p)
	p.set_process(false)
	p.set_process_input(false)
	return p


func test_requests_before_first_press_are_dropped() -> void:
	var p := _player()
	assert_bool(p.play(&"ui_tap")).is_false()
	assert_int(p.started_count).is_equal(0)
	p.arm()
	assert_bool(p.play(&"ui_tap")).is_true()
	assert_int(p.started_count).is_equal(1)


func test_suspended_drops_requests_until_resume() -> void:
	var p := _player()
	p.arm()
	p.suspend()
	assert_bool(p.play(&"ui_tap")).is_false()
	p.resume()
	assert_bool(p.play(&"ui_tap")).is_true()


func test_same_sound_same_frame_plays_once_then_after_gap() -> void:
	var p := _player()
	p.arm()
	assert_bool(p.play(&"cell_pop")).is_true()
	assert_bool(p.play(&"cell_pop")).is_false()
	p.now += _t.min_repeat_gap_s
	assert_bool(p.play(&"cell_pop")).is_true()


func test_unknown_sound_is_ignored() -> void:
	var p := _player()
	p.arm()
	assert_bool(p.play(&"no_such_sound")).is_false()


func test_is_press_accepts_touch_click_key_presses_only() -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	var release := InputEventScreenTouch.new()
	var drag := InputEventScreenDrag.new()
	var key := InputEventKey.new()
	key.pressed = true
	assert_bool(SfxPlayer.is_press(touch)).is_true()
	assert_bool(SfxPlayer.is_press(release)).is_false()
	assert_bool(SfxPlayer.is_press(drag)).is_false()
	assert_bool(SfxPlayer.is_press(key)).is_true()


func test_every_listed_sound_has_small_mono_wav() -> void:
	assert_int(_t.sounds.size()).is_equal(21)
	var total := 0
	for id: StringName in _t.sounds:
		var path := _t.sfx_dir + String(id) + ".wav"
		assert_bool(ResourceLoader.exists(path)).override_failure_message("missing " + path).is_true()
		var s: AudioStreamWAV = load(path)
		assert_bool(s.mix_rate == 22050 or s.mix_rate == 44100).is_true()
		assert_bool(s.stereo).is_false()
		total += FileAccess.get_file_as_bytes(path).size()
	assert_int(total).is_less(2 * 1024 * 1024)


func test_species_map_covers_all_mvp_species() -> void:
	for sp: StringName in [&"cat", &"bear", &"chick", &"sheep", &"frog", &"rabbit"]:
		assert_bool(_t.sounds.has(_t.ability_sound(sp))).is_true()


func test_settings_round_trip_and_clamp_through_config() -> void:
	var s := AudioBuses.Settings.from_tuning(_t)
	s.sfx_volume = 0.5
	s.muted = true
	var cfg := ConfigFile.new()
	s.write(cfg)
	cfg.set_value("audio", "master_volume", 3.0)
	var back := AudioBuses.Settings.from_tuning(_t)
	back.read(cfg)
	assert_float(back.sfx_volume).is_equal(0.5)
	assert_bool(back.muted).is_true()
	assert_float(back.master_volume).is_equal(1.0)


func test_settings_apply_sets_sfx_bus_and_mute() -> void:
	var s := AudioBuses.Settings.from_tuning(_t)
	s.sfx_volume = 0.5
	s.music_volume = 0.0
	s.apply()
	var sfx := AudioServer.get_bus_index(AudioBuses.SFX)
	var music := AudioServer.get_bus_index(AudioBuses.MUSIC)
	var master := AudioServer.get_bus_index(AudioBuses.MASTER)
	assert_float(AudioServer.get_bus_volume_db(sfx)).is_equal_approx(-6.02, 0.01)
	assert_bool(AudioServer.is_bus_mute(music)).is_true()
	assert_bool(AudioServer.is_bus_mute(master)).is_false()
	s.muted = true
	s.apply()
	assert_bool(AudioServer.is_bus_mute(master)).is_true()
	# restore defaults for other suites
	AudioBuses.Settings.from_tuning(_t).apply()
	AudioServer.set_bus_mute(music, false)
	AudioServer.set_bus_mute(master, false)
