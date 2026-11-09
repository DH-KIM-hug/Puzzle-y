## T1 minimal local progress (src/meta/player_progress.gd): unlock rule, best
## stars/score, JSON round-trip and graceful fallback on corrupt / foreign data.
## Pure string (de)serialisation only — no file I/O (test-standards).
extends GdUnitTestSuite

var _reg: CrewRegistry
var _catalog: StageCatalog


func before() -> void:
	_reg = load("res://assets/data/crew/crew_registry.tres")
	_reg.load_and_validate()
	_catalog = load("res://assets/data/stages/catalog.tres")


func test_fresh_save_owns_starters_and_unlocks_only_first_stage() -> void:
	var p := PlayerProgress.fresh(_reg)
	assert_array(p.owned).is_equal([&"nyangi", &"gomgom", &"piyak"])
	assert_bool(p.is_unlocked(_catalog, 0)).is_true()
	assert_bool(p.is_unlocked(_catalog, 1)).is_false()


func test_clearing_a_stage_unlocks_the_next_only() -> void:
	var p := PlayerProgress.fresh(_reg)
	p.record_result(&"1-1", 1, 568)
	assert_bool(p.is_unlocked(_catalog, 1)).is_true()
	assert_bool(p.is_unlocked(_catalog, 2)).is_false()


func test_record_result_keeps_best_stars_and_score_independently() -> void:
	var p := PlayerProgress.fresh(_reg)
	assert_bool(p.record_result(&"1-2", 2, 700)).is_true()
	assert_bool(p.record_result(&"1-2", 1, 650)).is_false()
	assert_bool(p.record_result(&"1-2", 1, 900)).is_true()
	assert_int(p.stars_of(&"1-2")).is_equal(2)
	assert_int(p.score_of(&"1-2")).is_equal(900)


func test_failed_result_records_nothing() -> void:
	var p := PlayerProgress.fresh(_reg)
	assert_bool(p.record_result(&"1-1", 0, 300)).is_false()
	assert_int(p.score_of(&"1-1")).is_equal(0)


func test_json_round_trip_preserves_progress_and_team_memory() -> void:
	var p := PlayerProgress.fresh(_reg)
	p.record_result(&"1-1", 3, 800)
	var team: Array[StringName] = [&"piyak", &"nyangi", &"gomgom"]
	p.memory = TeamRules.remember(p.memory, &"1-5", team, TeamRule.make(), p.owned_crews(_reg))
	var q := PlayerProgress.from_json(JSON.stringify(p.to_dict()), _reg)
	assert_object(q).is_not_null()
	assert_int(q.stars_of(&"1-1")).is_equal(3)
	assert_int(q.score_of(&"1-1")).is_equal(800)
	assert_array(q.memory.stage_team(&"1-5")).is_equal(team)
	assert_array(q.memory.last_global).is_equal(team)


func test_corrupt_text_returns_null() -> void:
	assert_object(PlayerProgress.from_json("{not json", _reg)).is_null()
	assert_object(PlayerProgress.from_json("[1, 2]", _reg)).is_null()
	assert_object(PlayerProgress.from_json("", _reg)).is_null()


func test_wrong_version_returns_null() -> void:
	assert_object(PlayerProgress.from_json("{\"version\": 99}", _reg)).is_null()


func test_bad_values_are_clamped_and_unknown_crews_dropped() -> void:
	var text := "{\"version\": 1, \"best_stars\": {\"1-1\": 9, \"1-2\": \"x\"}, \"best_score\": {\"1-1\": -5}," \
			+ " \"owned\": [\"nyangi\", \"nobody\", 3], \"last_team_global\": [\"nobody\"]}"
	var p := PlayerProgress.from_json(text, _reg)
	assert_object(p).is_not_null()
	assert_int(p.stars_of(&"1-1")).is_equal(3)
	assert_int(p.stars_of(&"1-2")).is_equal(0)
	assert_int(p.score_of(&"1-1")).is_equal(0)
	assert_array(p.owned).is_equal([&"nyangi"])
	assert_array(p.memory.last_global).is_empty()
