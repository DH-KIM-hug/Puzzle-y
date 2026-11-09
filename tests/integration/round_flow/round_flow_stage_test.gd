## design/gdd/round-flow.md AC-R01–R14 and stage-goals AC-SG11/12/14/15: the
## stage-driven round state machine, commit ordering, end priority, one-tap
## retry with the same team and FIXED seed, pause / background hooks, no undo.
extends GdUnitTestSuite

const TEAM: Array[StringName] = [&"nyangi", &"gomgom", &"piyak"]
const UNREACHABLE := 20000

var _env: StageEnv


func before() -> void:
	_env = StageEnv.load_default()


func _stage(goal: GoalDef, limit: int, seed_value: int = 4242) -> StageDef:
	var s := StageDef.new()
	s.id = &"rf-test"
	s.goals = [goal]
	s.piece_limit = limit
	s.star_points = PackedInt32Array([UNREACHABLE - 1, UNREACHABLE])
	s.stage_seed = seed_value
	s.team_rule = TeamRule.make()
	return s


func _flow(stage: StageDef) -> RoundFlow:
	var f := RoundFlow.for_stage(_env, stage, TEAM)
	assert_array(f.start_attempt()).is_empty()
	return f


## First legal (slot, anchor) row-major, or [] when none.
func _first_move(f: RoundFlow) -> Array:
	for slot: int in f.slot_count():
		if f.piece_at(slot) == null:
			continue
		for r: int in f.board().height:
			for c: int in f.board().width:
				if f.can_place(slot, Vector2i(r, c)):
					return [slot, Vector2i(r, c)]
	return []


func _play_first(f: RoundFlow) -> RoundCommit:
	var m := _first_move(f)
	var out := f.commit(m[0], m[1])
	f.playback_finished()
	return out


func _tray_text(f: RoundFlow) -> String:
	var parts := []
	for p: Variant in f.tray.slots:
		parts.append("-" if p == null else "%s/%s/%d" % [(p as PieceInstance).shape.id, (p as PieceInstance).crew_id, (p as PieceInstance).face_index])
	return ",".join(parts)


func test_setup_reaches_ready_with_a_full_tray() -> void:
	# AC-R01
	var f := RoundFlow.for_stage(_env, _stage(GoalDef.make(GoalDef.Type.SCORE, UNREACHABLE), 20), TEAM)
	var started := []
	f.attempt_started.connect(func(id: StringName, _t: Array[StringName], a: int, s: int) -> void: started.append([id, a, s]))
	f.start_attempt()
	assert_int(f.state).is_equal(RoundFlow.State.READY)
	assert_int(f.stage_score()).is_equal(0)
	assert_int(f.core.placement_index).is_equal(0)
	assert_int(f.tray.pieces().size()).is_equal(3)
	assert_int(f.pieces_dealt).is_equal(3)
	assert_array(started).is_equal([[&"rf-test", 0, 4242]])


func test_commit_pipeline_order_and_counters() -> void:
	# AC-R02 / rule 7: everything is fixed inside commit(), placement_committed before PRESENTING.
	var f := _flow(_stage(GoalDef.make(GoalDef.Type.SCORE, UNREACHABLE), 20))
	var log := []
	var state_box := [RoundFlow.State.IDLE]
	f.placement_committed.connect(func(i: int, _r: ChainResult, b: ScoreBreakdown, g: Array[Dictionary]) -> void:
		log.append(["committed", i, b.total, g[0][GoalTracker.S_PROGRESS], state_box[0]]))
	f.round_state_changed.connect(func(_from: RoundFlow.State, to: RoundFlow.State) -> void: state_box[0] = to)
	f.round_state_changed.connect(func(_from: RoundFlow.State, to: RoundFlow.State) -> void: log.append(["state", to]))
	var m := _first_move(f)
	var version := f.core.board_version
	var out := f.commit(m[0], m[1])
	assert_bool(f.board().equals(out.result.final_board)).is_true()
	assert_int(f.core.placement_index).is_equal(1)
	assert_int(f.core.board_version).is_equal(version + 1)
	assert_int(f.placements_used).is_equal(1)
	assert_int(f.stage_score()).is_equal(out.breakdown.total)
	assert_object(f.piece_at(m[0])).is_null()
	assert_int(f.state).is_equal(RoundFlow.State.PRESENTING)
	# RESOLVING → committed (goal progress already includes this placement) → PRESENTING
	assert_array(log).is_equal([["state", RoundFlow.State.RESOLVING], ["committed", 1, out.breakdown.total, out.breakdown.total, RoundFlow.State.RESOLVING],
			["state", RoundFlow.State.PRESENTING]])
	f.playback_finished()
	assert_int(f.state).is_equal(RoundFlow.State.READY)


func test_preview_context_equals_commit() -> void:
	# AC-R03 on a stage flow (obstacle hooks included).
	var f := _flow(_stage(GoalDef.make(GoalDef.Type.SCORE, UNREACHABLE), 20))
	var m := _first_move(f)
	var model := PreviewModel.preview(f.board(), f.piece_at(m[0]), m[1], f.context_for_next_placement())
	var out := f.commit(m[0], m[1])
	assert_int(out.result.summary[ChainEvent.K_BOARD_HASH]).is_equal(model.result.summary[ChainEvent.K_BOARD_HASH])


func test_out_of_pieces_after_limit_with_partial_refill() -> void:
	# AC-R06 / AC-SG12
	var f := _flow(_stage(GoalDef.make(GoalDef.Type.SCORE, UNREACHABLE), 4))
	var ended := []
	f.attempt_ended.connect(func(r: RoundResult) -> void: ended.append(r))
	for i: int in 3:
		_play_first(f)
	assert_int(f.tray.status).is_equal(TrayState.Status.PARTIAL)
	assert_int(f.tray.pieces().size()).is_equal(1)
	_play_first(f)
	assert_int(f.outcome).is_equal(RoundResult.Outcome.FAILED)
	assert_int(f.result.fail_reason).is_equal(RoundResult.FailReason.OUT_OF_PIECES)
	assert_int(f.result.pieces_left).is_equal(0)
	assert_int(f.pieces_dealt).is_equal(4)
	assert_int(f.result.stars).is_equal(0)
	assert_int(ended.size()).is_equal(1)
	assert_int(f.state).is_equal(RoundFlow.State.RESULT_PENDING)


func test_clear_on_the_last_piece_beats_out_of_pieces() -> void:
	# AC-R05 / AC-SG11 (CLEARED > OUT_OF_PIECES): the goal is the score the 4th piece reaches.
	var dry := _flow(_stage(GoalDef.make(GoalDef.Type.SCORE, UNREACHABLE), 4))
	for i: int in 3:
		_play_first(dry)
	var s3 := dry.stage_score()
	_play_first(dry)
	var s4 := dry.stage_score()
	assert_int(s4).is_greater(s3)
	var f := _flow(_stage(GoalDef.make(GoalDef.Type.SCORE, s4), 4))
	for i: int in 3:
		_play_first(f)
		assert_int(f.outcome).is_equal(RoundResult.Outcome.CONTINUE)
	_play_first(f)
	assert_int(f.outcome).is_equal(RoundResult.Outcome.CLEARED)
	assert_int(f.result.fail_reason).is_equal(RoundResult.FailReason.NONE)
	assert_int(f.result.pieces_left).is_equal(0)
	assert_int(f.result.leftover_bonus).is_equal(0)
	assert_int(f.result.stars).is_equal(1)


func test_clear_is_immediate_and_bonus_is_separate() -> void:
	# AC-SG14: clear after 2 placements with limit 12 → 10 left, bonus 1000, no 3rd commit.
	var dry := _flow(_stage(GoalDef.make(GoalDef.Type.SCORE, UNREACHABLE), 12))
	_play_first(dry)
	var s1 := dry.stage_score()
	_play_first(dry)
	var f := _flow(_stage(GoalDef.make(GoalDef.Type.SCORE, dry.stage_score()), 12))
	_play_first(f)
	assert_int(f.stage_score()).is_equal(s1)
	var m := _first_move(f)
	f.commit(m[0], m[1])
	var r := f.result
	assert_int(r.outcome).is_equal(RoundResult.Outcome.CLEARED)
	assert_int(r.pieces_left).is_equal(10)
	assert_int(r.stage_score).is_equal(f.stage_score())
	assert_int(r.leftover_bonus).is_equal(1000)
	assert_int(r.final_score).is_equal(r.stage_score + 1000)
	f.playback_finished()
	var m2 := _first_move(f)
	assert_object(f.commit(m2[0], m2[1])).is_null()
	assert_int(f.placements_used).is_equal(2)


func test_free_play_ends_only_by_no_moves() -> void:
	# AC-R07 / AC-R20 on the stage path: free play, first legal move until the end.
	var stage := StageDef.free_play(77)
	var f := _flow(stage)
	var n := 0
	while not f.is_ended() and n < 300:
		_play_first(f)
		n += 1
	assert_int(f.result.outcome).is_equal(RoundResult.Outcome.FAILED)
	assert_int(f.result.fail_reason).is_equal(RoundResult.FailReason.NO_MOVES)
	assert_bool(BoardRules.no_moves(f.board(), f.tray.pieces())).is_true()
	assert_int(f.result.pieces_left).is_equal(StageDef.UNLIMITED)


func test_result_is_fixed_at_commit_before_playback() -> void:
	# AC-R08 / AC-R14: result at commit == after flush-by-background; RESULT reached directly.
	var f := _flow(_stage(GoalDef.make(GoalDef.Type.SCORE, UNREACHABLE), 3))
	_play_first(f)
	_play_first(f)
	var flushes := []
	f.playback_flush_requested.connect(func() -> void: flushes.append(1))
	var m := _first_move(f)
	f.commit(m[0], m[1])
	var at_commit := var_to_str(f.result.to_dict())
	assert_int(f.state).is_equal(RoundFlow.State.PRESENTING)
	f.app_backgrounded()
	assert_int(flushes.size()).is_equal(1)
	assert_int(f.state).is_equal(RoundFlow.State.RESULT)
	assert_str(var_to_str(f.result.to_dict())).is_equal(at_commit)


func test_fixed_seed_retry_keeps_team_and_first_tray() -> void:
	# AC-R09 / AC-SG15: three retries, same first tray, attempt 1..3, fresh state.
	var f := _flow(_stage(GoalDef.make(GoalDef.Type.SCORE, UNREACHABLE), 20))
	var first := _tray_text(f)
	var start_hash := f.board().board_hash()
	for a: int in [1, 2, 3]:
		_play_first(f)
		_play_first(f)
		f.retry()
		assert_int(f.attempt).is_equal(a)
		assert_array(f.team).is_equal(TEAM)
		assert_str(_tray_text(f)).is_equal(first)
		assert_int(f.stage_score()).is_equal(0)
		assert_int(f.placements_used).is_equal(0)
		assert_int(f.board().board_hash()).is_equal(start_hash)
		assert_int(f.goals.progress(0)).is_equal(0)
		assert_int(f.state).is_equal(RoundFlow.State.READY)


func test_same_moves_are_deterministic() -> void:
	# AC-R10
	var a := _flow(_stage(GoalDef.make(GoalDef.Type.SCORE, UNREACHABLE), 6))
	var b := _flow(_stage(GoalDef.make(GoalDef.Type.SCORE, UNREACHABLE), 6))
	while not a.is_ended():
		_play_first(a)
		_play_first(b)
		assert_int(a.board().board_hash()).is_equal(b.board().board_hash())
	assert_str(var_to_str(a.result.to_dict())).is_equal(var_to_str(b.result.to_dict()))


func test_commit_during_presenting_is_ignored() -> void:
	# AC-R11
	var f := _flow(_stage(GoalDef.make(GoalDef.Type.SCORE, UNREACHABLE), 20))
	var m := _first_move(f)
	f.commit(m[0], m[1])
	var m2 := _first_move(f)
	var hash_before := f.board().board_hash()
	assert_object(f.commit(m2[0], m2[1])).is_null()
	assert_int(f.board().board_hash()).is_equal(hash_before)
	assert_int(f.placements_used).is_equal(1)


func test_pause_and_resume_change_no_rule_state() -> void:
	# AC-R12
	var f := _flow(_stage(GoalDef.make(GoalDef.Type.SCORE, UNREACHABLE), 20))
	var m := _first_move(f)
	f.commit(m[0], m[1])
	var version := f.core.board_version
	assert_bool(f.pause()).is_true()
	assert_int(f.state).is_equal(RoundFlow.State.PAUSED)
	f.resume()
	assert_int(f.state).is_equal(RoundFlow.State.PRESENTING)
	assert_int(f.core.board_version).is_equal(version)
	f.playback_finished()
	assert_int(f.state).is_equal(RoundFlow.State.READY)
	var cancels := []
	f.drag_cancel_requested.connect(func() -> void: cancels.append(1))
	assert_bool(f.begin_drag()).is_true()
	f.pause()
	f.resume()
	assert_int(cancels.size()).is_equal(1)
	assert_int(f.state).is_equal(RoundFlow.State.READY)


func test_retry_mid_round_records_abandoned_once() -> void:
	# AC-R13
	var f := _flow(_stage(GoalDef.make(GoalDef.Type.SCORE, UNREACHABLE), 3))
	var ended: Array[RoundResult] = []
	f.attempt_ended.connect(func(r: RoundResult) -> void: ended.append(r))
	_play_first(f)
	f.pause()
	f.retry()
	assert_int(ended.size()).is_equal(1)
	assert_int(ended[0].outcome).is_equal(RoundResult.Outcome.ABANDONED)
	assert_int(f.attempt).is_equal(1)
	assert_int(f.state).is_equal(RoundFlow.State.READY)
	for i: int in 3:
		_play_first(f)
	assert_int(ended.size()).is_equal(2)
	f.retry()
	assert_int(ended.size()).is_equal(2)


func test_background_cancels_drag_without_auto_pause() -> void:
	# Rule 19 / D9
	var f := _flow(_stage(GoalDef.make(GoalDef.Type.SCORE, UNREACHABLE), 20))
	f.begin_drag()
	f.app_backgrounded()
	assert_int(f.state).is_equal(RoundFlow.State.READY)


func test_round_has_no_undo() -> void:
	# Rule 21
	var f := _flow(_stage(GoalDef.make(GoalDef.Type.SCORE, UNREACHABLE), 20))
	for name: String in ["undo", "rollback", "take_back"]:
		assert_bool(f.has_method(name)).is_false()


func test_invalid_team_or_stage_keeps_flow_idle() -> void:
	# Edge Cases: team format, FIXED stage without seed.
	var two: Array[StringName] = [&"nyangi", &"nyangi", &"piyak"]
	var f := RoundFlow.for_stage(_env, _stage(GoalDef.make(GoalDef.Type.SCORE, 100), 20), two)
	assert_array(f.start_attempt()).is_not_empty()
	assert_int(f.state).is_equal(RoundFlow.State.IDLE)
	var s := _stage(GoalDef.make(GoalDef.Type.SCORE, 100), 20)
	s.stage_seed = StageDef.NO_SEED
	var g := RoundFlow.for_stage(_env, s, TEAM)
	assert_str(" ".join(g.start_attempt())).contains("stage_seed")
