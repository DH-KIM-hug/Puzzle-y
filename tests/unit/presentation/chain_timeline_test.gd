## chain-presentation rules 4, 5, 7, F4: the playback timeline is a pure function
## of the events, replaying it on the pre-board reproduces final_board, cue start
## times never run against event order, and the total stays within the budget.
## Uses the committed parity cases (tests/fixtures/parity/cases.json).
extends GdUnitTestSuite

const TUNING_PATH := "res://assets/data/presentation/presentation_tuning.tres"

var _cases: Array = []
var _registry: CrewRegistry
var _shapes: Dictionary
var _scoring: ScoringRules
var _tuning: PresentationTuning


func before() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ParityFixture.CASES_PATH))
	_cases = data["cases"]
	_registry = ParityFixture.registry()
	_shapes = ParityFixture.catalog(_registry)
	_scoring = load(ParityFixture.SCORING_PATH)
	_tuning = load(TUNING_PATH)


## Calls [param check] (pre_board, commit, placement_id) for every case × piece × legal anchor.
func _each_commit(check: Callable) -> int:
	var n := 0
	for c: Dictionary in _cases:
		var board := BoardFixture.board(c["board"])
		var rules := ParityFixture.chain_rules(int(c["depth_cap"]))
		for i: int in (c["pieces"] as Array).size():
			var p := ParityFixture.piece(c["pieces"][i], _shapes, i + 1)
			for a: Vector2i in ParityFixture.legal_anchors(board, p):
				var rc := RoundCore.start(board, _registry.abilities(), rules, _scoring, int(c["stage_seed"]), int(c["placement_index"]))
				var pid := rc.placement_index + 1
				var commit := rc.commit(p, a)
				check.call(board, commit, pid, "%s/%d/%s" % [c["id"], i, a])
				n += 1
	return n


func test_replay_of_every_cue_reproduces_final_board() -> void:
	# Arrange
	var failures: Array[String] = []
	# Act
	var n := _each_commit(func(pre: BoardState, commit: RoundCommit, pid: int, label: String) -> void:
		var display := pre.copy()
		var tl := ChainTimeline.build(commit.result.events, commit.breakdown, _tuning)
		for cue: Dictionary in tl.cues:
			ChainTimeline.apply_cue(display, cue, pid)
		if not display.equals(commit.result.final_board):
			failures.append(label))
	# Assert
	assert_int(n).is_greater(100)
	assert_array(failures).is_empty()


func test_event_start_times_follow_event_order_and_total_within_budget() -> void:
	# Arrange
	var failures: Array[String] = []
	# Act
	_each_commit(func(_pre: BoardState, commit: RoundCommit, _pid: int, label: String) -> void:
		var tl := ChainTimeline.build(commit.result.events, commit.breakdown, _tuning)
		var starts := tl.event_start_times()
		var seqs: Array = starts.keys()
		seqs.sort()
		var last := -1.0
		var face_start := -1.0
		for s: int in seqs:
			var e: ChainEvent = commit.result.events[s] if s < commit.result.events.size() else null
			if e != null and e.type == ChainEvent.Type.ABILITY_EFFECT:
				# Rule 11/F2: an effect starts face_lead after ITS face; the next face of the
				# same wave lifts face_gap after this one, i.e. before this effect. Effects are
				# therefore checked against their own face only (see GDD finding in the log).
				if float(starts[s]) < face_start - 0.0001:
					failures.append("%s: effect seq %d starts before its face" % [label, s])
				continue
			if e != null and e.type == ChainEvent.Type.FACE_ACTIVATED:
				face_start = float(starts[s])
			if float(starts[s]) < last - 0.0001:
				failures.append("%s: seq %d starts before an earlier event" % [label, s])
				break
			last = float(starts[s])
		if tl.total > _tuning.t_budget + 0.0001:
			failures.append("%s: total %.3f > budget" % [label, tl.total]))
	# Assert
	assert_array(failures).is_empty()


func test_build_twice_gives_identical_cues() -> void:
	# Arrange
	var c: Dictionary = _cases[2]  # prototype_domino
	var board := BoardFixture.board(c["board"])
	var p := ParityFixture.piece(c["pieces"][0], _shapes, 1)
	var a: Vector2i = ParityFixture.legal_anchors(board, p)[0]
	var rc := RoundCore.start(board, _registry.abilities(), ParityFixture.chain_rules(int(c["depth_cap"])), _scoring, int(c["stage_seed"]))
	var commit := rc.commit(p, a)
	# Act
	var t1 := ChainTimeline.build(commit.result.events, commit.breakdown, _tuning)
	var t2 := ChainTimeline.build(commit.result.events, commit.breakdown, _tuning)
	# Assert
	assert_str(var_to_str(t1.cues)).is_equal(var_to_str(t2.cues))
	assert_float(t1.total).is_equal(t2.total)


func test_no_line_placement_is_landing_only() -> void:
	# Arrange — F4 "줄 없음" row: T_play = place_dur.
	var board := BoardFixture.board(["........", "........", "........", "........", "........", "........", "........", "........"])
	var p := ParityFixture.piece({"shape": "I3_H", "crew": "nyangi", "face": 1}, _shapes, 1)
	var rc := RoundCore.start(board, _registry.abilities(), ParityFixture.chain_rules(6), _scoring, 1201)
	var commit := rc.commit(p, Vector2i(3, 2))
	# Act
	var tl := ChainTimeline.build(commit.result.events, commit.breakdown, _tuning)
	# Assert
	assert_int(tl.waves).is_equal(0)
	assert_float(tl.total).is_equal_approx(_tuning.place_dur, 0.0001)
