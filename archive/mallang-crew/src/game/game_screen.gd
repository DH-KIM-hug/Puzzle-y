## Play screen: wires Rules Core (via [RoundFlow]) to the input controller, the
## chain preview, the chain player, the HUD and the result panel. Two modes:
## a catalog stage ([member stage] set — goals / pieces / stars HUD, obstacles,
## clear/fail result with "한 판 더" / "다음 스테이지" / "팀 바꾸기" / "스테이지 선택")
## or the endless T0 free-play round ([member stage] null — "연습").
## Owns no rules: legality, chains, scores, tray and no_moves all come from
## src/core through [RoundFlow] (ADR-0001).
##
## Flow: READY → drag (preview on each valid anchor change) → valid drop →
## [method RoundFlow.commit] (independent resolve) → [ChainPlayer] replays the
## events → refill + no_moves → READY or the result panel ("한 판 더" = retry).
##
## Polish (chain-presentation D15–D18): [ChainFx] juice layer, camera punch +
## shake on the board layers, score roll-up with pop / gold milestone flash,
## idle life (face breathe / blink / twinkle, background sparkle dust, tray bob).
## Reduced motion = tuning flag OR OS "reduce animation" OR [code]-- --reduced-motion[/code].
##
## Tray display (round-flow cross-ref "논리적 재충전은 커밋, 표시는 연출 후"): the
## flow refills at commit; this screen keeps showing the pre-commit tray (minus the
## placed piece) until the chain playback ends, then shows the refilled tray.
## Presentation only — rules unchanged.
##
## Debug: [code]-- --seed=N[/code] sets the free-play base seed. Autoplay is
## attached by [App].
class_name GameScreen
extends Node2D

## Fallback team when none is given (냥이, 곰곰, 삐약).
const TEAM: Array[StringName] = [&"nyangi", &"gomgom", &"piyak"]
const INPUT_TUNING_PATH := "res://assets/data/presentation/placement_input.tres"
const PRESENTATION_TUNING_PATH := "res://assets/data/presentation/presentation_tuning.tres"
const DEFAULT_SEED := 1201
## HUD strip height in stage mode (score row, goal chips, star bar).
const STAGE_HUD_H := 190.0

## Emitted after every committed placement's playback (autoplay / tests hook).
signal placement_settled(phase: RoundFlow.Phase)
## An attempt ended CLEARED or FAILED (fixed at the deciding commit; persistence hook).
signal round_ended(result: RoundResult)
## "스테이지 선택" / pause "나가기".
signal exit_requested
## "다음 스테이지".
signal next_requested
## "팀 바꾸기".
signal team_change_requested

## Owning app (null = standalone practice screen).
var app: App
## Stage played (null = endless free play).
var stage: StageDef
## Team in slot order.
var team: Array[StringName] = []
## Stage environment.
var env: StageEnv
## Result of the last ended attempt.
var last_result: RoundResult

## Round flow (rules owner).
var flow: RoundFlow
## Input state machine.
var drag: DragController
## Chain player.
var player: ChainPlayer
## Preview renderer.
var preview: PreviewView
## Layout.
var layout: BoardLayout
## Look table.
var visuals: CrewVisuals
## Tunings.
var input_tuning: PlacementInputTuning
var tuning: PresentationTuning
## UI font (system font with Hangul fallback).
var font: Font
## Score shown in the HUD (counts up with wave beats).
var shown_score: int = 0
## Placements committed this attempt.
var placements: int = 0
## Real-time effects layer.
var fx: ChainFx
## SFX (design/gdd/audio.md); listens only.
var audio: GameAudio
## Effective reduced-motion flag.
var reduced: bool = false
## Score value currently rendered by the HUD (rolls toward [member shown_score]).
var score_rolled: float = 0.0

var _preview_settings := PreviewSettings.new()
var _cache: Dictionary = {}
var _cache_order: Array = []
var _cache_version: int = -1
var _last_preview: PreviewModel
var _last_preview_key: Array = []
var _lift_t: float = 1.0
var _last_drag_pos: Vector2 = Vector2.ZERO
var _ret: Dictionary = {}
var _layers: Dictionary = {}
var _hud_score: Label
var _hud_attempt: Label
var _result: Control
var _result_score: Label
var _score_pop: float = 0.0
var _score_gold: float = 0.0
var _time: float = 0.0
var _placeable: Array[bool] = []
var _placeable_key: String = ""
var _tray_view: Array = []
var _tray_hold: bool = false
var _shown_goals: Array[Dictionary] = []
var _shown_done: Dictionary = {}
var _prev_best_stars: int = 0
var _hud_stage: Label
var _hud_pieces: Label
var _pause: Control
var _result_card: PanelContainer
var _result_buttons: Array[Button] = []
var _result_token: int = 0


func _ready() -> void:
	font = app.font if app != null else _make_font()
	ThemeDB.fallback_font = font
	TranslationServer.set_locale("ko")
	env = app.env if app != null else StageEnv.load_default()
	var registry := env.registry
	if team.is_empty():
		team = TEAM.duplicate()
	input_tuning = load(INPUT_TUNING_PATH)
	tuning = load(PRESENTATION_TUNING_PATH)
	reduced = tuning.reduced_motion or "--reduced-motion" in OS.get_cmdline_user_args()
	if tuning.follow_os_reduced_motion and DisplayServer.accessibility_should_reduce_animation() == 1:
		reduced = true
	visuals = app.visuals if app != null else CrewVisuals.from_registry(registry)
	var cfg := registry.board_config
	var hud_h := STAGE_HUD_H if stage != null else BoardLayout.HUD_H
	layout = BoardLayout.make(get_viewport_rect().size, cfg.board_height, cfg.board_width, env.tray_rules.tray_size, hud_h)
	if stage == null:
		flow = RoundFlow.create(registry, env.chain_rules, env.scoring_rules, env.tray_rules, team, _arg_int("seed", DEFAULT_SEED))
	else:
		flow = RoundFlow.for_stage(env, stage, team)
	flow.placement_committed.connect(_on_committed)
	flow.attempt_ended.connect(_on_attempt_ended)
	var start_errors := flow.start_attempt()
	if not start_errors.is_empty():
		push_error("GameScreen: start failed: %s" % ", ".join(start_errors))
	_preview_settings = flow.preview_settings()
	_sync_goals()
	_prev_best_stars = app.progress.stars_of(stage.id) if app != null and stage != null else 0
	drag = DragController.new(input_tuning, flow.can_place)
	drag.board_origin = layout.board_origin
	drag.cell_size = layout.s
	drag.canvas_width = layout.canvas.x
	drag.board_cells = layout.cells
	drag.anchor_changed.connect(_on_anchor_changed)
	drag.placement_requested.connect(_on_placement_requested)
	drag.drag_ended.connect(_on_drag_ended)
	preview = PreviewView.new()
	preview.layout = layout
	preview.tuning = tuning
	preview.font = font
	fx = ChainFx.new()
	fx.tuning = tuning
	fx.layout = layout
	fx.font = font
	fx.reduced = reduced
	add_child(fx)
	fx.fly_arrived.connect(func(_t: String) -> void: _score_pop = 1.0)
	player = ChainPlayer.new()
	player.fx = fx
	player.reduced = reduced
	player.tuning = tuning
	player.visuals = visuals
	player.layout = layout
	player.font = font
	add_child(player)
	player.wave_presented.connect(_on_wave_presented)
	player.playback_finished.connect(_on_playback_finished)
	player.redraw_requested.connect(_redraw)
	audio = GameAudio.create(load(GameAudio.TUNING_PATH), tuning)
	add_child(audio)
	audio.attach(player)
	_build_layers()
	_build_hud()
	drag.set_enabled(flow.state == RoundFlow.State.READY)
	_refresh_hud()


func _process(delta: float) -> void:
	_time += delta
	preview.tick(delta)
	_tick_score(delta)
	if _lift_t < 1.0:
		_lift_t = minf(1.0, _lift_t + delta / maxf(input_tuning.lift_anim_s, 0.001))
	if not _ret.is_empty():
		_ret[&"t"] = float(_ret[&"t"]) + delta
		if float(_ret[&"t"]) >= float(_ret[&"dur"]):
			_ret = {}
	# Camera punch (scale about the firing face) + shake, board layers only.
	var off := player.shake_offset
	var z := player.zoom
	for k: StringName in [&"board", &"overlay"]:
		var l := _layers[k] as Node2D
		l.scale = Vector2(z, z)
		l.position = player.zoom_focus * (1.0 - z) + off
	_redraw()


# --- input (placement-input rules 3, 5, 16, 18, 19; chain-presentation rule 22) ---

func _input(event: InputEvent) -> void:
	if audio != null:
		audio.on_input(event)
	if flow == null or _result.visible or _pause.visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if player.is_playing():
				player.tap()
				audio.ui_tap()
				return
			var slot := layout.slot_at(t.position)
			var p := _tray_piece(slot)
			if p == null:
				return
			_ret = {}
			if drag.press(slot, Vector2i(p.shape.width(), p.shape.height()), t.position, t.index):
				_lift_t = 0.0 if input_tuning.lift_anim_s > 0.0 else 1.0
				audio.pick_up()
		else:
			drag.release(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		drag.move(d.position, d.index)


func _notification(what: int) -> void:
	if drag == null:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		drag.cancel()


# --- preview (chain-preview rules 1, 6–11) --------------------------------------

func _on_anchor_changed(slot: int, anchor: Variant) -> void:
	if anchor == null:
		preview.clear()
		return
	var piece := flow.piece_at(slot)
	var ctx := flow.context_for_next_placement()
	if _cache_version != flow.core.board_version:
		_cache.clear()
		_cache_order.clear()
		_cache_version = flow.core.board_version
	var a: Vector2i = anchor
	var key := "%d|%d|%d,%d|%d" % [flow.core.board_version, piece.instance_id, a.x, a.y, ctx.rng_seed]
	var model: PreviewModel = _cache.get(key)
	if model == null:
		model = PreviewModel.preview(flow.board(), piece, a, ctx, _preview_settings)
		if tuning.preview_cache_size > 0:
			_cache[key] = model
			_cache_order.append(key)
			while _cache_order.size() > tuning.preview_cache_size:
				_cache.erase(_cache_order.pop_front())
	else:
		_cache_order.erase(key)
		_cache_order.append(key)
	_last_preview = model
	_last_preview_key = [slot, a]
	preview.show_model(model)
	if stage != null:
		var predicted := flow.stage_score() + model.predicted_score if model.has_predicted_score else -1
		preview.goals = flow.goal_preview(model.result, predicted)


func _on_drag_ended(slot: int, reason: DragController.EndReason, on_board: bool) -> void:
	if reason == DragController.EndReason.COMMITTED:
		return
	preview.clear()
	var p := flow.piece_at(slot)
	if p == null:
		return
	# Return to the tray slot (rule 16), wiggle when the invalid drop was over the board.
	audio.invalid_return(on_board)
	_ret = {&"slot": slot, &"from": _last_drag_pos, &"t": 0.0,
			&"dur": input_tuning.return_anim_s + (input_tuning.invalid_wiggle_s if on_board else 0.0),
			&"wiggle": input_tuning.invalid_wiggle_s if on_board else 0.0}


func _on_placement_requested(slot: int, anchor: Vector2i) -> void:
	var before: Array = []
	for i: int in flow.slot_count():
		before.append(flow.piece_at(i))
	var commit := flow.commit(slot, anchor)
	if commit == null:
		drag.refuse()
		preview.clear()
		return
	# Keep showing the pre-commit tray until the playback ends (refill shows after).
	before[slot] = null
	_tray_view = before
	_tray_hold = true
	# chain-preview rule 9: debug comparison of the shown preview vs the commit.
	if _last_preview != null and _last_preview_key == [slot, anchor]:
		var shown: int = _last_preview.result.summary[ChainEvent.K_BOARD_HASH]
		var real: int = commit.result.summary[ChainEvent.K_BOARD_HASH]
		if shown != real:
			push_error("PREVIEW_MISMATCH: preview board_hash %d != commit %d" % [shown, real])
	preview.clear()
	placements += 1
	player.play(flow.last_pre_board, commit, flow.last_placement_id())


func _on_wave_presented(_wave: int, points: int) -> void:
	shown_score += points
	_score_pop = maxf(_score_pop, 0.6)


func _on_playback_finished(_was_skipped: bool) -> void:
	shown_score = flow.stage_score()
	_tray_hold = false
	_tray_view = []
	_sync_goals()
	var phase := flow.finish_placement()
	_refresh_hud()
	if phase == RoundFlow.Phase.NO_MOVES:
		drag.set_enabled(false)
		var token := _result_token
		get_tree().create_timer(tuning.result_reveal_delay_s).timeout.connect(func() -> void:
			if token == _result_token and is_inside_tree():
				_show_result())
	else:
		drag.set_enabled(true)
	placement_settled.emit(phase)


func _on_committed(_index: int, _result: ChainResult, _breakdown: ScoreBreakdown, _goal_progress: Array[Dictionary]) -> void:
	pass  # HUD goal counters follow the playback: see _sync_goals() at playback end.


func _on_attempt_ended(r: RoundResult) -> void:
	last_result = r
	if r.outcome == RoundResult.Outcome.CLEARED or r.outcome == RoundResult.Outcome.FAILED:
		round_ended.emit(r)


## HUD goal snapshot + displayed target-cell completions (updated after playback).
func _sync_goals() -> void:
	if flow.goals == null:
		return
	_shown_goals = flow.goals.snapshot()
	_shown_done = flow.goals.done.duplicate()


## Tray piece shown in [param slot] (the held pre-commit tray during playback).
func _tray_piece(slot: int) -> PieceInstance:
	if _tray_hold:
		return _tray_view[slot] if slot >= 0 and slot < _tray_view.size() else null
	return flow.piece_at(slot)


func _tray_slots() -> int:
	return _tray_view.size() if _tray_hold else flow.slot_count()


## "한 판 더" (one tap): next attempt, same team, fresh board and tray (team-composition rule 13).
func retry() -> void:
	audio.ui_tap()
	_result_token += 1
	flow.retry()
	shown_score = 0
	placements = 0
	preview.clear()
	_ret = {}
	score_rolled = 0.0
	fx.clear()
	_tray_hold = false
	_tray_view = []
	_sync_goals()
	if app != null and stage != null:
		_prev_best_stars = app.progress.stars_of(stage.id)
	_result.visible = false
	_pause.visible = false
	drag.set_enabled(flow.state == RoundFlow.State.READY)
	_refresh_hud()


## Pause overlay (round-flow rule 17; only between placements).
func open_pause() -> void:
	if _result.visible or player.is_playing() or not flow.pause():
		return
	audio.ui_tap()
	drag.cancel()
	preview.clear()
	drag.set_enabled(false)
	_pause.visible = true


func _resume() -> void:
	audio.ui_tap()
	_pause.visible = false
	flow.resume()
	drag.set_enabled(flow.state == RoundFlow.State.READY)


func _exit_to_stages() -> void:
	audio.ui_tap()
	_result_token += 1
	flow.abandon()
	exit_requested.emit()


# --- HUD / result --------------------------------------------------------------

func _build_hud() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 28
	var root := Control.new()
	root.theme = theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var pause_btn := UiKit.button("II", UiKit.Kind.SECONDARY, Vector2(64, 64), 26)
	pause_btn.name = "PauseButton"
	pause_btn.position = Vector2(16, 12)
	pause_btn.pressed.connect(open_pause)
	root.add_child(pause_btn)
	_hud_score = _label(root, Rect2(Vector2(96, 10), Vector2(400, 52)), 40, HORIZONTAL_ALIGNMENT_LEFT)
	_hud_score.add_theme_constant_override(&"outline_size", 8)
	_hud_score.add_theme_color_override(&"font_outline_color", Palette.STICKER_WHITE)
	_hud_score.pivot_offset = Vector2(0, 26)
	fx.score_target = _hud_score.position + Vector2(150, 26)
	if stage != null:
		_hud_stage = _label(root, Rect2(Vector2(98, 56), Vector2(390, 28)), 20, HORIZONTAL_ALIGNMENT_LEFT)
		_hud_stage.add_theme_color_override(&"font_color", Palette.INK_LIGHT)
		_hud_stage.text = "%s  %s" % [stage.id, tr(stage.name_key)]
		_hud_pieces = _label(root, Rect2(Vector2(layout.canvas.x - 222, 16), Vector2(200, 56)), 26, HORIZONTAL_ALIGNMENT_CENTER)
		_hud_pieces.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_hud_pieces.pivot_offset = Vector2(100, 28)
	_hud_attempt = _label(root, Rect2(Vector2(layout.canvas.x - 324, 30), Vector2(300, 40)), 24, HORIZONTAL_ALIGNMENT_RIGHT)
	_hud_attempt.add_theme_color_override(&"font_color", Palette.INK_LIGHT)
	_hud_attempt.visible = stage == null
	_result = Control.new()
	_result.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result.visible = false
	root.add_child(_result)
	var dim := ColorRect.new()
	# Failure never darkens (art-bible §2): a warm paper veil, not an ink dim.
	dim.color = Color(Palette.KRAFT, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result.add_child(center)
	_result_card = PanelContainer.new()
	_result_card.add_theme_stylebox_override(&"panel", UiKit.card_style(28, 32))
	_result_card.custom_minimum_size = Vector2(layout.canvas.x - 96, 0)
	center.add_child(_result_card)
	_pause = _build_pause(root)


func _build_pause(root: Control) -> Control:
	var p := Control.new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.visible = false
	root.add_child(p)
	var dim := ColorRect.new()
	dim.color = Color(Palette.KRAFT, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override(&"panel", UiKit.card_style(28, 36))
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 20)
	card.add_child(col)
	col.add_child(UiKit.label(tr("UI_PAUSE_TITLE"), 38, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var resume := UiKit.button(tr("UI_PAUSE_RESUME"), UiKit.Kind.PRIMARY, Vector2(420, 96), 36)
	resume.name = "ResumeButton"
	resume.pressed.connect(_resume)
	col.add_child(resume)
	var again := UiKit.button(tr("UI_PAUSE_RETRY"), UiKit.Kind.SECONDARY, Vector2(420, 80), 30)
	again.name = "PauseRetryButton"
	again.pressed.connect(retry)
	col.add_child(again)
	var out := UiKit.button(tr("UI_TO_STAGES"), UiKit.Kind.SECONDARY, Vector2(420, 80), 30)
	out.name = "PauseExitButton"
	out.pressed.connect(_exit_to_stages)
	col.add_child(out)
	return p


func _label(parent: Control, rect: Rect2, size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", Palette.INK)
	if rect.size != Vector2.ZERO:
		l.position = rect.position
		l.size = rect.size
	parent.add_child(l)
	return l


func _refresh_hud() -> void:
	_hud_score.text = tr("UI_SCORE_VALUE") % int(roundf(score_rolled))
	_hud_attempt.text = tr("UI_ATTEMPT") % (flow.attempt + 1)
	if _hud_pieces != null:
		var left := flow.pieces_left()
		_hud_pieces.text = tr("UI_PIECES_LEFT") % maxi(left, 0)
		# pieces_left ≤ 3: a gentle bounce, no colour change (stage-goals Game Feel).
		var k := 1.0
		if left <= 3 and left > 0 and not reduced:
			k = 1.0 + 0.06 * absf(sin(_time * 3.0))
		_hud_pieces.scale = Vector2(k, k)


## Score HUD roll-up toward [member shown_score] with a bounce pop and a gold
## outline flash when a [member PresentationTuning.score_milestone] is crossed.
func _tick_score(delta: float) -> void:
	var target := float(shown_score)
	if target < score_rolled:
		score_rolled = target
	elif score_rolled < target:
		var before := int(roundf(score_rolled))
		var k := 1.0 - exp(-delta / maxf(tuning.score_roll_s * 0.3, 0.01))
		score_rolled = minf(target, score_rolled + maxf((target - score_rolled) * k, 1.0))
		var after := int(roundf(score_rolled))
		if after != before:
			audio.score_tick()
		if score_rolled >= target:
			audio.score_roll_done()
		var m := maxi(tuning.score_milestone, 1)
		if after / m > before / m:
			_score_gold = 1.0
			fx.sparkle_burst(fx.score_target, 10, 90.0, Palette.GOLD)
		_score_pop = maxf(_score_pop, 0.35)
	_score_pop = maxf(0.0, _score_pop - delta * 3.5)
	_score_gold = maxf(0.0, _score_gold - delta * 1.4)
	var e := _score_pop * _score_pop
	var sc := 1.0 + tuning.score_pop_scale * e * (1.0 if not reduced else 0.0)
	_hud_score.scale = Vector2(sc, sc)
	_hud_score.add_theme_color_override(&"font_outline_color", Palette.STICKER_WHITE.lerp(Palette.GOLD, minf(1.0, _score_gold * 1.5 + e * 0.6)))
	_hud_score.add_theme_constant_override(&"outline_size", int(8 + 6 * _score_gold))
	_refresh_hud()


func _show_result() -> void:
	for c: Node in _result_card.get_children():
		c.queue_free()
	_result_buttons.clear()
	flow.reveal_result()
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 12)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_card.add_child(col)
	var r := last_result if last_result != null else flow.result
	if stage == null or r == null:
		_result_practice(col)
	else:
		_result_stage(col, r)
	var retry_btn := UiKit.button(tr("UI_RETRY"), UiKit.Kind.PRIMARY, Vector2(440, 100), 40)
	retry_btn.name = "RetryButton"
	retry_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	retry_btn.pressed.connect(retry)
	col.add_child(_spacer(6))
	col.add_child(retry_btn)
	_result_buttons.append(retry_btn)
	if stage != null and r != null and r.outcome == RoundResult.Outcome.CLEARED and app != null and app.has_next(app.stage_index):
		var next := UiKit.button(tr("UI_NEXT_STAGE"), UiKit.Kind.SECONDARY, Vector2(440, 80), 30)
		next.name = "NextButton"
		next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		next.pressed.connect(func() -> void:
			audio.ui_tap()
			next_requested.emit())
		col.add_child(next)
		_result_buttons.append(next)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 16)
	col.add_child(row)
	if stage != null:
		var change := UiKit.button(tr("UI_CHANGE_TEAM"), UiKit.Kind.SECONDARY, Vector2(212, 76), 26)
		change.name = "ChangeTeamButton"
		change.disabled = stage.effective_team_rule().is_fixed()
		change.pressed.connect(func() -> void:
			audio.ui_tap()
			team_change_requested.emit())
		row.add_child(change)
		_result_buttons.append(change)
	var out := UiKit.button(tr("UI_TO_STAGES"), UiKit.Kind.SECONDARY, Vector2(212, 76), 26)
	out.name = "StagesButton"
	out.pressed.connect(_exit_to_stages)
	row.add_child(out)
	_result_buttons.append(out)
	# Input guard (round-flow UI): ignore taps for a moment after the card opens.
	var enabled := {}
	for b: Button in _result_buttons:
		enabled[b] = not b.disabled
		b.disabled = true
	get_tree().create_timer(tuning.result_input_guard_s).timeout.connect(func() -> void:
		for b: Button in _result_buttons:
			if is_instance_valid(b):
				b.disabled = not bool(enabled.get(b, true)))
	_result.visible = true
	audio.result()


func _result_practice(col: VBoxContainer) -> void:
	col.add_child(UiKit.label(tr("UI_RESULT_TITLE"), 36, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UiKit.label(tr("UI_RESULT_SCORE"), 24, Palette.INK_LIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	_result_score = UiKit.label(str(flow.stage_score()), 72, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_result_score)
	col.add_child(UiKit.label(tr("UI_RESULT_BEST") % flow.best_placement(), 26, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UiKit.label(tr("UI_RESULT_PLACEMENTS") % placements, 22, Palette.INK_LIGHT, HORIZONTAL_ALIGNMENT_CENTER))


func _result_stage(col: VBoxContainer, r: RoundResult) -> void:
	var cleared := r.outcome == RoundResult.Outcome.CLEARED
	var title := tr("UI_RESULT_CLEAR")
	if not cleared:
		title = tr("UI_RESULT_FAIL_OUT") if r.fail_reason == RoundResult.FailReason.OUT_OF_PIECES else tr("UI_RESULT_FAIL_NO_MOVES")
	col.add_child(UiKit.label("%s  %s" % [stage.id, tr(stage.name_key)], 22, Palette.INK_LIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UiKit.label(title, 44, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var stars := Control.new()
	stars.custom_minimum_size = Vector2(0, 92)
	var n := r.stars
	stars.draw.connect(func() -> void:
		var cx := stars.size.x * 0.5
		for k: int in 3:
			var big := 40.0 if k == 1 else 34.0
			UiKit.star(stars, Vector2(cx + (k - 1) * 96.0, 50.0 - (8.0 if k == 1 else 0.0)), big, k < n))
	col.add_child(stars)
	if cleared:
		col.add_child(UiKit.label(tr("UI_RESULT_STAGE_SCORE") % r.stage_score, 28, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER))
		if r.leftover_bonus > 0:
			col.add_child(UiKit.label(tr("UI_RESULT_BONUS") % [r.pieces_left, r.leftover_bonus], 24, Palette.INK_LIGHT, HORIZONTAL_ALIGNMENT_CENTER))
		var fin := UiKit.label(tr("UI_RESULT_FINAL") % r.final_score, 56, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER)
		col.add_child(fin)
		if r.stars > _prev_best_stars:
			var nb := UiKit.label(tr("UI_RESULT_NEW_BEST"), 26, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER)
			nb.add_theme_constant_override(&"outline_size", 10)
			nb.add_theme_color_override(&"font_outline_color", Palette.GOLD)
			col.add_child(nb)
	else:
		# Progress snapshot so a near miss reads as "one more try" (stage-goals Game Feel).
		for g: int in r.goal_snapshot.size():
			col.add_child(UiKit.label(_goal_text(g, r.goal_snapshot[g], float(r.stage_score)), 28, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER))
		col.add_child(UiKit.label(tr("UI_RESULT_STAGE_SCORE") % r.stage_score, 24, Palette.INK_LIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UiKit.label(tr("UI_RESULT_EXTRA") % [r.best_placement, r.max_chain_depth], 22, Palette.INK_LIGHT, HORIZONTAL_ALIGNMENT_CENTER))


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## HUD / result text of goal [param g] from a snapshot entry. SCORE uses
## [param score] (the rolled HUD score while playing).
func _goal_text(g: int, snap: Dictionary, score: float) -> String:
	var req := int(snap[GoalTracker.S_REQUIRED])
	var prog := int(snap[GoalTracker.S_PROGRESS])
	match int(snap[GoalTracker.S_TYPE]):
		GoalDef.Type.SCORE:
			return tr("UI_GOAL_SCORE") % [int(roundf(score)), req]
		GoalDef.Type.CLEAR_CELLS:
			return tr("UI_GOAL_CELLS") % maxi(0, req - prog)
		GoalDef.Type.CLEAR_OBSTACLES:
			return tr("UI_GOAL_ICE") % maxi(0, req - prog)
		GoalDef.Type.CHAIN:
			return tr("UI_GOAL_CHAIN") % [stage.goals[g].depth, mini(prog, req), req]
	return ""


## Retry button (autoplay presses it with a real touch).
func retry_button() -> Button:
	return _result.find_child("RetryButton", true, false)


## True while the result panel is up.
func is_result_visible() -> bool:
	return _result.visible


## A result-card button by node name (autoplay), or null.
func result_button(button_name: String) -> Button:
	return _result.find_child(button_name, true, false)


# --- drawing -------------------------------------------------------------------

func _build_layers() -> void:
	# chain-preview rule 18: paper → stickers → outlines → ghost → dragged piece → eggs → badges → banner.
	for spec: Array in [[&"bg", _draw_bg], [&"hud", _draw_hud], [&"board", _draw_board], [&"tray", _draw_tray], [&"drag", _draw_drag],
			[&"overlay", _draw_overlay], [&"banner", _draw_banner], [&"screen", _draw_screen]]:
		var l := DrawLayer.new()
		l.painter = spec[1]
		add_child(l)
		_layers[spec[0]] = l


func _redraw() -> void:
	for l: Node2D in _layers.values():
		l.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, layout.canvas), Palette.KRAFT)
	# Low-contrast paper fibres (background, no white margin, art-bible §3).
	for i: int in 26:
		var y := fmod(i * 97.0, layout.canvas.y)
		draw_line(Vector2(0, y), Vector2(layout.canvas.x, y + 14.0), Color(Palette.KRAFT_SHADE, 0.35), 2.0, true)
	var br := layout.board_rect().grow(10)
	StickerPainter.rounded(self, Rect2(br.position + Vector2(0, 6), br.size), Palette.KRAFT_SHADE.darkened(0.08), 26)
	StickerPainter.rounded(self, br, Palette.KRAFT_SHADE, 26)
	var tr_rect := layout.tray_rect
	StickerPainter.rounded(self, tr_rect, Color(Palette.KRAFT_SHADE, 0.55), 26)


func _board_shown() -> BoardState:
	return player.display if player.is_playing() else flow.board()


func _draw_board(ci: CanvasItem) -> void:
	var s := layout.s
	for r: int in layout.cells.x:
		for c: int in layout.cells.y:
			var rect := layout.cell_rect(Vector2i(r, c)).grow(-2)
			StickerPainter.rounded(ci, rect, Palette.BOARD_PAPER, s * 0.18)
			ci.draw_line(rect.position + Vector2(6, 1), Vector2(rect.end.x - 6, rect.position.y + 1), Color(Palette.INK, 0.12), 1.5)
	var b := _board_shown()
	var items: Array[Dictionary] = []
	for i: int in b.cell_count():
		if b.kind[i] == CellKind.STONE:
			# Stones sit IN the paper: drawn under the stickers, no shadow, no white margin.
			ObstaclePainter.stone(ci, layout.cell_rect(b.cell_of(i)).grow(-2))
			continue
		if not b.blocks_placement(i):
			continue
		var cell := b.cell_of(i)
		var rect := layout.cell_rect(cell)
		var k := player.cell_scale(cell)
		if k != Vector2.ONE:
			# Landing squash / egg bounce: scale about the cell's bottom centre.
			var bc := Vector2(rect.get_center().x, rect.end.y)
			rect = Rect2(bc - Vector2(rect.size.x * k.x * 0.5, rect.size.y * k.y), rect.size * k)
		var it := {&"rect": rect, &"look": visuals.look(b.crew_at(i)), &"face": b.is_face(i),
				&"egg": b.origin(i) == BoardState.ORIGIN_EGG}
		if it[&"face"]:
			_idle_face(it, i)
		items.append(it)
	StickerPainter.draw_board_cells(ci, items)
	# Ice over tiles / frozen faces (hatch direction count = layers).
	for idx: Variant in b.modifiers.keys():
		var layers := ObstacleRules.ice_in(b.modifiers_at(int(idx)))
		if layers > 0:
			ObstaclePainter.ice(ci, layout.cell_rect(b.cell_of(int(idx))), layers, b.is_face(int(idx)))
	# Target-cell rings: an overlay independent of the cell content (stage-goals Visual).
	if flow.goals != null:
		for cell: Vector2i in flow.goals.targets.keys():
			if not _shown_done.has(cell):
				ObstaclePainter.target_ring(ci, layout.cell_rect(cell), 0.0, false)
	preview.draw_outlines(ci)
	# Ghost (placement-input rule 12): only at a valid anchor, 35 %.
	if drag.state == DragController.State.DRAGGING and drag.has_anchor and drag.anchor_valid:
		var p := flow.piece_at(drag.slot)
		var look := visuals.look(p.crew_id)
		for k: int in p.shape.offsets.size():
			var o: Vector2i = p.shape.offsets[k]
			var rect := layout.cell_rect(drag.anchor + o).grow(-3)
			StickerPainter.rounded(ci, rect, Color(look[CrewVisuals.K_BASE], 0.35), s * 0.2)
			if k == p.face_index:
				ci.draw_circle(rect.get_center(), s * 0.32, Color(Palette.FACE_CREAM, 0.6), true, -1.0, true)


## Idle life for one board face: slow breathe, staggered blink, highlight twinkle
## (art-bible §2 "얼굴 칸의 느린 반짝, 약 3초 간격, 칸마다 엇갈림").
func _idle_face(it: Dictionary, i: int) -> void:
	if reduced:
		return
	var ph := float((i * 37) % 97) / 97.0
	it[&"breath"] = 1.0 + tuning.idle_breathe_amp * sin((_time / tuning.idle_breathe_period_s + ph) * TAU)
	var bt := fmod(_time + ph * tuning.idle_blink_every_s, tuning.idle_blink_every_s)
	it[&"blink"] = bt < tuning.idle_blink_s
	var tw := fmod(_time / 3.0 + ph, 1.0)
	it[&"twinkle"] = sin(tw / 0.12 * PI) if tw < 0.12 else 0.0


## Cached per board version: which tray slots have at least one legal anchor.
func _slot_placeable(i: int) -> bool:
	var key := "%d|%d|%d" % [flow.core.board_version, flow.attempt, placements]
	if key != _placeable_key or _placeable.size() != flow.slot_count():
		_placeable_key = key
		_placeable.clear()
		for slot: int in flow.slot_count():
			var ok := false
			if flow.piece_at(slot) != null:
				for r: int in layout.cells.x:
					for c: int in layout.cells.y:
						if flow.can_place(slot, Vector2i(r, c)):
							ok = true
							break
					if ok:
						break
			_placeable.append(ok)
	return _placeable[i]


func _piece_rects(p: PieceInstance, top_left: Vector2, cs: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for o: Vector2i in p.shape.offsets:
		out.append(Rect2(top_left + Vector2(o.y, o.x) * cs, Vector2(cs, cs)))
	return out


func _tray_top_left(slot: int, p: PieceInstance) -> Array:
	var size := Vector2i(p.shape.width(), p.shape.height())
	var margin := input_tuning.tray_slot_margin_px * layout.canvas.x / 1080.0
	var cs := layout.tray_cell(size, input_tuning.tray_piece_scale, margin)
	var sr := layout.slot_rect(slot)
	return [sr.get_center() - Vector2(size) * cs * 0.5, cs]


func _draw_tray(ci: CanvasItem) -> void:
	var dragging := drag.state == DragController.State.PRESSED or drag.state == DragController.State.DRAGGING
	for i: int in _tray_slots():
		var sr := layout.slot_rect(i).grow(-8)
		StickerPainter.rounded(ci, sr, Color(Palette.BOARD_PAPER, 0.45), 20)
		var p := _tray_piece(i)
		if p == null:
			continue
		var tl: Array = _tray_top_left(i, p)
		var rects := _piece_rects(p, tl[0], tl[1])
		if (dragging and drag.slot == i) or (not _ret.is_empty() and int(_ret[&"slot"]) == i):
			# Empty "sticker spot" left behind (rule 6).
			for r: Rect2 in rects:
				StickerPainter.dashed_rect(ci, r.grow(-2), Color(Palette.INK, 0.25), 2.0, 6.0)
			if _ret.is_empty() or int(_ret[&"slot"]) != i:
				continue
			var q := clampf((float(_ret[&"t"]) - float(_ret[&"wiggle"])) / maxf(input_tuning.return_anim_s, 0.001), 0.0, 1.0)
			var e := 1.0 - pow(1.0 - q, 3.0)
			var from: Vector2 = _ret[&"from"]
			var wig := 0.0
			if float(_ret[&"t"]) < float(_ret[&"wiggle"]):
				wig = sin(float(_ret[&"t"]) / float(_ret[&"wiggle"]) * TAU * 2.0) * 8.0
			var cs := lerpf(layout.s, tl[1], e)
			rects = _piece_rects(p, from.lerp(tl[0], e) + Vector2(wig, 0), cs)
		var bob := 0.0
		if not reduced and _ret.is_empty() and not player.is_playing() and not _tray_hold and _slot_placeable(i):
			bob = sin((_time / tuning.tray_bob_period_s + i * 0.33) * TAU) * tuning.tray_bob_px * layout.canvas.x / 1080.0
			for k: int in rects.size():
				rects[k].position.y += bob
		StickerPainter.draw_piece(ci, rects, p.face_index, visuals.look(p.crew_id), {StickerPainter.O_SHADOW: 3.0 - bob * 0.4})


func _draw_drag(ci: CanvasItem) -> void:
	if drag.state != DragController.State.PRESSED and drag.state != DragController.State.DRAGGING:
		return
	var p := flow.piece_at(drag.slot)
	if p == null:
		return
	var rect := drag.piece_rect()
	var tl: Array = _tray_top_left(drag.slot, p)
	var e := 1.0 - pow(1.0 - _lift_t, 2.0)
	var cs := lerpf(tl[1], layout.s, e)
	var pos: Vector2 = (tl[0] as Vector2).lerp(rect.position, e)
	_last_drag_pos = pos
	var grey := drag.state == DragController.State.DRAGGING and drag.has_anchor and not drag.anchor_valid
	StickerPainter.draw_piece(ci, _piece_rects(p, pos, cs), p.face_index, visuals.look(p.crew_id),
			{StickerPainter.O_SHADOW: drag.ref_px(input_tuning.drag_shadow_px), StickerPainter.O_GREY: grey})


## Stage HUD art: pieces chip, goal chips (icon + text, ✓ when met), star bar.
func _draw_hud(ci: CanvasItem) -> void:
	if stage == null:
		return
	var w := layout.canvas.x
	var chip := Rect2(Vector2(w - 222, 16), Vector2(200, 56))
	UiKit.sticker_rect(ci, chip, Palette.STICKER_WHITE, 26, 4.0)
	# Goal chips (row B).
	var n := maxi(_shown_goals.size(), 1)
	var gap := 12.0
	var cw := (w - 32.0 - gap * (n - 1)) / n
	for g: int in _shown_goals.size():
		var snap: Dictionary = _shown_goals[g]
		var r := Rect2(Vector2(16 + g * (cw + gap), 86), Vector2(cw, 50))
		UiKit.sticker_rect(ci, r, Palette.STICKER_WHITE, 22, 4.0)
		var icon := Rect2(r.position + Vector2(10, 7), Vector2(36, 36))
		match int(snap[GoalTracker.S_TYPE]):
			GoalDef.Type.CLEAR_CELLS:
				StickerPainter.rounded(ci, icon, Palette.BOARD_PAPER, 6)
				ObstaclePainter.target_ring(ci, icon.grow(4), 0.0, true)
			GoalDef.Type.CLEAR_OBSTACLES:
				ObstaclePainter.ice_icon(ci, icon)
			GoalDef.Type.CHAIN:
				StickerPainter.badge(ci, icon.get_center(), 30.0, str(stage.goals[g].depth), font)
			_:
				UiKit.star(ci, icon.get_center(), 16.0, false)
		var met := bool(snap[GoalTracker.S_MET]) or (int(snap[GoalTracker.S_TYPE]) == GoalDef.Type.SCORE and score_rolled >= float(snap[GoalTracker.S_REQUIRED]))
		var text := _goal_text(g, snap, score_rolled)
		ci.draw_string(font, r.position + Vector2(54, 35), text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - (100 if met else 62), 26, Palette.INK)
		if met:
			UiKit.check(ci, Vector2(r.end.x - 26, r.get_center().y), 16.0)
	# Star bar (row C): stage_score vs ★2 / ★3 marks (pts_eff).
	if stage.star_points.size() >= 2:
		var cp := env.scoring_rules.cell_points
		var ref := env.stage_rules.cell_points_ref
		var s2 := StageScoring.pts_eff(stage.star_points[0], cp, ref)
		var s3 := StageScoring.pts_eff(stage.star_points[1], cp, ref)
		var top := float(s3) * 1.1
		var bar := Rect2(Vector2(28, 160), Vector2(w - 56, 16))
		StickerPainter.rounded(ci, bar.grow(3), Palette.STICKER_WHITE, 11)
		StickerPainter.rounded(ci, bar, Palette.KRAFT_SHADE, 8)
		var f := clampf(score_rolled / top, 0.0, 1.0)
		if f > 0.0:
			StickerPainter.rounded(ci, Rect2(bar.position, Vector2(maxf(bar.size.x * f, 16.0), bar.size.y)), Palette.INK_LIGHT, 8)
		ci.draw_string(font, Vector2(28, 152), tr("UI_STAR_BONUS_NOTE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Palette.INK_LIGHT)
		for k: int in 2:
			var th := s2 if k == 0 else s3
			var x := bar.position.x + bar.size.x * float(th) / top
			ci.draw_line(Vector2(x, bar.position.y - 2), Vector2(x, bar.end.y + 2), Palette.INK, 2.0, true)
			UiKit.star(ci, Vector2(x, bar.get_center().y), 15.0, score_rolled >= float(th))
			var num := str(th)
			var nw := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			ci.draw_string(font, Vector2(x - nw - 18, 152), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.INK_LIGHT)


func _draw_bg(ci: CanvasItem) -> void:
	fx.draw_back(ci)


func _draw_overlay(ci: CanvasItem) -> void:
	preview.draw_top(ci)
	player.draw_overlay(ci)
	fx.draw_front(ci)
	player.draw_texts(ci)


func _draw_screen(ci: CanvasItem) -> void:
	fx.draw_screen(ci)


func _draw_banner(ci: CanvasItem) -> void:
	fx.draw_flies(ci)
	if player.is_playing():
		player.draw_banner(ci)
	else:
		preview.draw_banner(ci)


# --- helpers -------------------------------------------------------------------

## Bundled Korean face (Jua, SIL OFL — assets/fonts/OFL.txt) so web/mobile builds
## render Hangul without system fonts; SystemFont stays as the fallback chain.
const BUNDLED_FONT_PATH := "res://assets/fonts/Jua-Regular.ttf"


static func _make_font() -> Font:
	var system := _make_system_font()
	if ResourceLoader.exists(BUNDLED_FONT_PATH):
		var bundled: FontFile = load(BUNDLED_FONT_PATH)
		bundled.fallbacks = [system]
		return bundled
	return system


static func _make_system_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Noto Sans CJK KR", "Noto Sans KR", "Apple SD Gothic Neo", "Malgun Gothic", "WenQuanYi Zen Hei", "sans-serif"])
	f.font_weight = 700
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return f


static func _arg_int(name: String, fallback: int) -> int:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return int(a.get_slice("=", 1))
	return fallback
