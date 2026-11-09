## Round flow (design/gdd/round-flow.md; ADR-0001 Decision 9 "RoundFlow").
##
## Owns one attempt: the [StageDef] (read-only), the team, the live [RoundCore]
## (board, placement counter, score tally), the [TrayState], the [GoalTracker],
## the piece counters and the round state machine. It is the only object that
## hands out a [ResolveContext] ([method context_for_next_placement]) — the
## preview and the commit both use it. It judges nothing itself: every rule is a
## Rules Core call; this class decides call order, timing and end priority.
## Kept as a [RefCounted] (no Node) so whole rounds run in integration tests
## without a scene tree; the game scene wraps one and forwards notifications.
## [codeblock]
## var flow := RoundFlow.for_stage(StageEnv.load_default(), stage, team)
## flow.start_attempt()                          # SETUP → READY (attempt_started)
## var ctx := flow.context_for_next_placement()  # preview
## var commit := flow.commit(slot, anchor)       # RESOLVING → PRESENTING; result fixed now
## flow.playback_finished(false)                 # SETTLING → READY / RESULT_PENDING
## flow.reveal_result()                          # RESULT_PENDING → RESULT
## flow.retry()                                  # one tap: same team, FIXED seed → same first tray
## [/codeblock]
## T0 compatibility: [method create] builds a free-play stage (empty board, no
## goals, unlimited pieces, PER_ATTEMPT seed) — the endless greybox round —
## and [method finish_placement] / [member phase] keep their old meaning.
##
## There is no undo (round-flow rule 21): no API takes a placement back.
##
## Spec ambiguities resolved here (logged per task brief):
## [br]- The flow validates only the team's *format* (1–3 known, distinct crews,
##   size = team_size); ownership / locks are team-composition's job (Edge Cases).
## [br]- A refused re-check (rule 7.2) and a commit outside READY/DRAGGING return
##   null with a warning instead of a hard assert, so release-like tests stay green.
## [br]- Backgrounding while PAUSED over a playback flushes it and resumes into
##   SETTLING (Edge Cases "일시정지 중 백그라운드").
class_name RoundFlow
extends RefCounted

## attempt_started(stage_id, team, attempt_index, stage_seed) — rule 22.
signal attempt_started(stage_id: StringName, team: Array[StringName], attempt_index: int, stage_seed: int)
## placement_committed(placement_index, result, breakdown, goal_progress) — after 7.5/7.6, before playback.
signal placement_committed(placement_index: int, result: ChainResult, breakdown: ScoreBreakdown, goal_progress: Array[Dictionary])
## round_state_changed(from, to).
signal round_state_changed(from: State, to: State)
## attempt_ended(result) — exactly once per attempt, at the deciding commit or on abandon.
signal attempt_ended(result: RoundResult)
## retry_requested(from_outcome).
signal retry_requested(from_outcome: RoundResult.Outcome)
## The presentation must snap to the end of its playback now (rule 19).
signal playback_flush_requested
## The input layer must cancel an active drag (rules 17, 19).
signal drag_cancel_requested

## T0 phase (kept for the greybox screen): PLAYING until the attempt ends.
enum Phase { PLAYING, NO_MOVES }
## Round states (round-flow States and Transitions).
enum State { IDLE, SETUP, READY, DRAGGING, RESOLVING, PRESENTING, SETTLING, RESULT_PENDING, RESULT, PAUSED }

## Shared data (registry, rules).
var env: StageEnv
## Current stage (read-only).
var stage: StageDef
## Team crew ids, slot order (read-only during the attempt).
var team: Array[StringName] = []
## 0-based attempt index (+1 per retry).
var attempt: int = 0
## Live round core (board, tally, placement index).
var core: RoundCore
## Live tray (logical — refilled at commit, rule 7.7).
var tray: TrayState
## Goal progress (stage-goals rule 3).
var goals: GoalTracker
## Current state.
var state: State = State.IDLE
## State to return to from PAUSED.
var resume_to: State = State.READY
## Pieces put into the tray this attempt (F2).
var pieces_dealt: int = 0
## Committed placements this attempt (F1).
var placements_used: int = 0
## Highest chain depth this attempt.
var max_chain_depth: int = 0
## Outcome decided so far (CONTINUE while playing).
var outcome: RoundResult.Outcome = RoundResult.Outcome.CONTINUE
## Result of the attempt once ended (null while CONTINUE).
var result: RoundResult
## Board as it was before the last commit (read-only copy for the replay).
var last_pre_board: BoardState
## Last SETUP load errors.
var load_errors: PackedStringArray = PackedStringArray()
## T0 phase mirror.
var phase: Phase = Phase.PLAYING

# T0 compatibility mirrors.
## Validated crew registry.
var registry: CrewRegistry
## Chain rules.
var chain_rules: ChainRules
## Scoring rules (preview and commit share it).
var scoring_rules: ScoringRules
## Global tray rules.
var tray_rules: TrayRules
## Free-play base seed (T0).
var base_seed: int = 0

var _ended_emitted: bool = false


## A flow for [param p_stage] played by [param p_team] (slot order). Call
## [method start_attempt] before use.
static func for_stage(p_env: StageEnv, p_stage: StageDef, p_team: Array[StringName]) -> RoundFlow:
	var f := RoundFlow.new()
	f.env = p_env
	f.stage = p_stage
	f.team = p_team.duplicate()
	f.registry = p_env.registry
	f.chain_rules = p_env.chain_rules
	f.scoring_rules = p_env.scoring_rules
	f.tray_rules = p_env.tray_rules
	return f


## T0 greybox flow: a free-play stage (round-flow rule 24 (a)) with default
## stage / obstacle values. Call [method start_attempt] before use.
static func create(p_registry: CrewRegistry, p_chain_rules: ChainRules, p_scoring_rules: ScoringRules,
		p_tray_rules: TrayRules, p_team: Array[StringName], p_base_seed: int) -> RoundFlow:
	var e := StageEnv.make(p_registry, p_chain_rules, p_scoring_rules, p_tray_rules, StageRules.new(), ObstacleConfig.new())
	var cfg := p_registry.board_config
	var f := for_stage(e, StageDef.free_play(p_base_seed, cfg.board_width, cfg.board_height), p_team)
	f.base_seed = p_base_seed
	return f


## Stage seed of the current attempt (FIXED → stage_seed; PER_ATTEMPT → derived).
func stage_seed() -> int:
	return stage.seed_for_attempt(attempt)


## Rule 5 SETUP for the current attempt index. Returns load errors (empty = ok);
## on error the flow stays IDLE.
func start_attempt() -> PackedStringArray:
	_set_state(State.SETUP)
	load_errors = _team_format_errors()
	var loaded := StageLoader.load_stage(stage, env)
	load_errors.append_array(loaded.errors)
	if not load_errors.is_empty():
		_set_state(State.IDLE)
		return load_errors
	var seed_value := stage_seed()
	core = RoundCore.start(loaded.board, env.registry.abilities(), env.chain_rules, env.scoring_rules, seed_value, 0, ObstacleRules.hooks())
	goals = GoalTracker.start(stage, loaded.board, env.scoring_rules.cell_points, env.stage_rules.cell_points_ref)
	tray = TraySupplyRules.init_state(team, stage.tray_rules(env.tray_rules), seed_value, env.registry)
	if not tray.is_valid():
		load_errors = tray.errors
		_set_state(State.IDLE)
		return load_errors
	pieces_dealt = 0
	placements_used = 0
	max_chain_depth = 0
	outcome = RoundResult.Outcome.CONTINUE
	result = null
	last_pre_board = null
	_ended_emitted = false
	phase = Phase.PLAYING
	_refill_if_empty()
	attempt_started.emit(stage.id, team.duplicate(), attempt, seed_value)
	if BoardRules.no_moves(core.board, tray.pieces()):
		# Rule 5.6: a blocked start board is stage-data error; release path = FAILED(NO_MOVES).
		push_warning("RoundFlow: start board of %s has no moves" % stage.id)
		_end(RoundResult.Outcome.FAILED, RoundResult.FailReason.NO_MOVES)
		_set_state(State.RESULT_PENDING)
		return load_errors
	_set_state(State.READY)
	return load_errors


## Rule 13 "한 판 더" (one tap): same stage, same team, attempt + 1, rebuilt in
## place. An attempt still in progress is first recorded as ABANDONED (once).
func retry() -> PackedStringArray:
	if state != State.IDLE and not _ended_emitted:
		_end(RoundResult.Outcome.ABANDONED, RoundResult.FailReason.ABANDONED)
	retry_requested.emit(outcome)
	attempt += 1
	return start_attempt()


## Pause menu "나가기": ends an unfinished attempt as ABANDONED, back to IDLE.
func abandon() -> void:
	if state != State.IDLE and not _ended_emitted:
		_end(RoundResult.Outcome.ABANDONED, RoundResult.FailReason.ABANDONED)
	_set_state(State.IDLE)


## The context the next placement will use (preview and commit alike).
func context_for_next_placement() -> ResolveContext:
	return core.context_for_next_placement()


## Live stable board (read-only for callers).
func board() -> BoardState:
	return core.board


## Piece in [param slot], or null.
func piece_at(slot: int) -> PieceInstance:
	if tray == null or slot < 0 or slot >= tray.slots.size():
		return null
	return tray.slots[slot]


## Tray slot count.
func slot_count() -> int:
	return tray.slots.size() if tray != null else 0


## Board-rules legality of placing [param slot]'s piece at [param anchor].
func can_place(slot: int, anchor: Vector2i) -> bool:
	var p := piece_at(slot)
	return p != null and BoardRules.can_place(core.board, p, anchor)


## READY → DRAGGING (a tray piece was picked up). False in any other state.
func begin_drag() -> bool:
	if state != State.READY:
		return false
	_set_state(State.DRAGGING)
	return true


## DRAGGING → READY (drag cancelled or invalid drop).
func cancel_drag() -> void:
	if state == State.DRAGGING:
		_set_state(State.READY)


## Rule 7 commit pipeline, all in this call: re-check → resolve → apply → score →
## goals → consume/refill → end check → PRESENTING. Returns null when refused
## (nothing changes).
func commit(slot: int, anchor: Vector2i) -> RoundCommit:
	if state != State.READY and state != State.DRAGGING:
		push_warning("RoundFlow.commit ignored in state %s (rule 8)" % State.keys()[state])
		return null
	if not can_place(slot, anchor):
		cancel_drag()
		return null
	_set_state(State.RESOLVING)
	last_pre_board = core.board.copy()
	var out := core.commit(piece_at(slot), anchor)  # resolve, apply, score (7.3–7.5)
	if out.error != "":
		_set_state(State.READY)
		return null
	placements_used += 1
	max_chain_depth = maxi(max_chain_depth, int(out.result.summary[ChainEvent.K_CHAIN_DEPTH]))
	goals.apply(out.result, out.breakdown, core.tally.stage_score)  # 7.6
	tray = TraySupplyRules.consume(tray, slot)  # 7.7
	_refill_if_empty()
	_judge_end()  # 7.8
	placement_committed.emit(core.placement_index, out.result, out.breakdown, goals.snapshot())
	_set_state(State.PRESENTING)  # 7.9
	return out


## Rule 11: playback done → SETTLING → READY (CONTINUE) or RESULT_PENDING.
func playback_finished(_was_skipped: bool = false) -> Phase:
	if state == State.PRESENTING:
		_set_state(State.SETTLING)
		_settle()
	return phase


## T0 name for [method playback_finished].
func finish_placement() -> Phase:
	return playback_finished(false)


## RESULT_PENDING → RESULT (delay elapsed, tap, or background).
func reveal_result() -> void:
	if state == State.RESULT_PENDING:
		_set_state(State.RESULT)


## Rule 17: opens the pause overlay from READY / DRAGGING / PRESENTING / SETTLING.
func pause() -> bool:
	if not [State.READY, State.DRAGGING, State.PRESENTING, State.SETTLING].has(state):
		return false
	if state == State.DRAGGING:
		drag_cancel_requested.emit()
		resume_to = State.READY
	else:
		resume_to = state
	_set_state(State.PAUSED)
	return true


## "계속": back to the remembered state (SETTLING is processed immediately).
func resume() -> void:
	if state != State.PAUSED:
		return
	_set_state(resume_to)
	if state == State.SETTLING:
		_settle()


## Rule 19 background hook: cancel a drag, flush a playback, skip the result delay.
## No auto-pause on return (D9).
func app_backgrounded() -> void:
	match state:
		State.DRAGGING:
			drag_cancel_requested.emit()
			_set_state(State.READY)
		State.PRESENTING:
			playback_flush_requested.emit()
			playback_finished(true)
		State.PAUSED:
			if resume_to == State.PRESENTING:
				playback_flush_requested.emit()
				resume_to = State.SETTLING
	if state == State.RESULT_PENDING:
		reveal_result()


## Placement id the last commit used (display-board replay writes it).
func last_placement_id() -> int:
	return core.placement_index


## F1: pieces left ([constant StageDef.UNLIMITED] for free play).
func pieces_left() -> int:
	return StageScoring.pieces_left(stage.piece_limit, placements_used)


## F2: refill budget ([constant TraySupplyRules.BUDGET_UNLIMITED] for free play).
func refill_budget() -> int:
	if stage.is_free_play():
		return TraySupplyRules.BUDGET_UNLIMITED
	return maxi(0, stage.piece_limit - pieces_dealt)


## Running stage score.
func stage_score() -> int:
	return core.tally.stage_score


## Best single placement this attempt.
func best_placement() -> int:
	return core.tally.best_placement


## Preview settings of this stage, scored by the commit's scoring rules.
func preview_settings() -> PreviewSettings:
	return stage.preview_settings(env.scoring_rules)


## Goal markers for a previewed result (stage-goals rule 14); empty when the stage
## turns markers off.
func goal_preview(preview_result: ChainResult, predicted_stage_score: int = -1) -> GoalPreview:
	if not stage.goal_markers:
		return GoalPreview.new()
	return goals.preview(preview_result, predicted_stage_score)


## True once the attempt has an outcome other than CONTINUE.
func is_ended() -> bool:
	return outcome != RoundResult.Outcome.CONTINUE


func _refill_if_empty() -> void:
	if tray.is_empty() and tray.status != TrayState.Status.EXHAUSTED:
		var r := TraySupplyRules.refill(tray, core.board, refill_budget())
		if r.error == "":
			tray = r.state
			pieces_dealt += r.pieces.size()


## Rule 9 priority: CLEARED > FAILED(OUT_OF_PIECES) > FAILED(NO_MOVES) > CONTINUE.
func _judge_end() -> void:
	if goals.is_met():
		_end(RoundResult.Outcome.CLEARED, RoundResult.FailReason.NONE)
	elif goals.pieces_out(pieces_left()):
		_end(RoundResult.Outcome.FAILED, RoundResult.FailReason.OUT_OF_PIECES)
	elif BoardRules.no_moves(core.board, tray.pieces()):
		_end(RoundResult.Outcome.FAILED, RoundResult.FailReason.NO_MOVES)


func _end(p_outcome: RoundResult.Outcome, reason: RoundResult.FailReason) -> void:
	if _ended_emitted:
		return
	outcome = p_outcome
	phase = Phase.NO_MOVES
	var r := RoundResult.new()
	r.stage_id = stage.id
	r.team = team.duplicate()
	r.attempt_index = attempt
	r.outcome = p_outcome
	r.fail_reason = reason
	r.stage_score = core.tally.stage_score if core != null else 0
	r.best_placement = core.tally.best_placement if core != null else 0
	r.placements_used = placements_used
	r.pieces_left = pieces_left()
	r.max_chain_depth = max_chain_depth
	r.goal_snapshot = goals.snapshot() if goals != null else []
	var cleared := p_outcome == RoundResult.Outcome.CLEARED
	var cp := env.scoring_rules.cell_points
	var ref := env.stage_rules.cell_points_ref
	r.leftover_bonus = StageScoring.leftover_bonus(cleared, r.pieces_left, env.stage_rules.leftover_piece_points, cp, ref)
	r.final_score = StageScoring.final_score(r.stage_score, r.leftover_bonus)
	r.stars = StageScoring.stars(cleared, r.final_score, stage.star_points, cp, ref)
	result = r
	_ended_emitted = true
	attempt_ended.emit(r)


func _settle() -> void:
	if outcome == RoundResult.Outcome.CONTINUE:
		_set_state(State.READY)
	else:
		_set_state(State.RESULT_PENDING)


func _set_state(to: State) -> void:
	if to == state:
		return
	var from := state
	state = to
	round_state_changed.emit(from, to)


func _team_format_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var size := stage.effective_team_rule().team_size
	if team.size() != size:
		errors.append("team: %d crews, stage needs %d" % [team.size(), size])
	var seen := {}
	for c: StringName in team:
		if seen.has(c):
			errors.append("team: duplicate crew %s" % c)
		seen[c] = true
		if env.registry.get_crew(c) == null:
			errors.append("team: unknown crew %s" % c)
	return errors
