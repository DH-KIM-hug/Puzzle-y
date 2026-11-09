## T0 greybox play screen: wires Rules Core (via [RoundFlow]) to the input
## controller, the chain preview, the chain player, the HUD and the result panel.
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
## Debug: launch with [code]-- --autoplay[/code] to attach [DebugAutoplay]
## (scripted touches + screenshots). [code]-- --seed=N[/code] sets the base seed.
class_name GameScreen
extends Node2D

## Fixed T0 starter team (냥이, 곰곰, 삐약).
const TEAM: Array[StringName] = [&"nyangi", &"gomgom", &"piyak"]
const REGISTRY_PATH := "res://assets/data/crew/crew_registry.tres"
const CHAIN_RULES_PATH := "res://assets/data/rules/chain_rules.tres"
const SCORING_RULES_PATH := "res://assets/data/rules/scoring_rules.tres"
const TRAY_RULES_PATH := "res://assets/data/rules/tray_rules.tres"
const INPUT_TUNING_PATH := "res://assets/data/presentation/placement_input.tres"
const PRESENTATION_TUNING_PATH := "res://assets/data/presentation/presentation_tuning.tres"
const DEFAULT_SEED := 1201

## Emitted after every committed placement's playback (autoplay / tests hook).
signal placement_settled(phase: RoundFlow.Phase)

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
var _result_best: Label
var _result_count: Label
var _score_pop: float = 0.0
var _score_gold: float = 0.0
var _time: float = 0.0
var _placeable: Array[bool] = []
var _placeable_key: String = ""


func _ready() -> void:
	font = _make_font()
	ThemeDB.fallback_font = font
	TranslationServer.set_locale("ko")
	var registry: CrewRegistry = load(REGISTRY_PATH)
	var errors := registry.load_and_validate()
	if not errors.is_empty():
		push_error("GameScreen: registry invalid: %s" % ", ".join(errors))
		return
	input_tuning = load(INPUT_TUNING_PATH)
	tuning = load(PRESENTATION_TUNING_PATH)
	reduced = tuning.reduced_motion or "--reduced-motion" in OS.get_cmdline_user_args()
	if tuning.follow_os_reduced_motion and DisplayServer.accessibility_should_reduce_animation() == 1:
		reduced = true
	visuals = CrewVisuals.from_registry(registry)
	var cfg := registry.board_config
	var tray_rules: TrayRules = load(TRAY_RULES_PATH)
	layout = BoardLayout.make(get_viewport_rect().size, cfg.board_height, cfg.board_width, tray_rules.tray_size)
	flow = RoundFlow.create(registry, load(CHAIN_RULES_PATH), load(SCORING_RULES_PATH), tray_rules, TEAM, _arg_int("seed", DEFAULT_SEED))
	var start_errors := flow.start_attempt()
	if not start_errors.is_empty():
		push_error("GameScreen: tray invalid: %s" % ", ".join(start_errors))
	_preview_settings.scoring_rules = flow.scoring_rules
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
	drag.set_enabled(true)
	_refresh_hud()
	if "--autoplay" in OS.get_cmdline_user_args():
		var bot := DebugAutoplay.new()
		bot.screen = self
		add_child(bot)


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
	if flow == null or _result.visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if player.is_playing():
				player.tap()
				audio.ui_tap()
				return
			var slot := layout.slot_at(t.position)
			var p := flow.piece_at(slot)
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
	var commit := flow.commit(slot, anchor)
	if commit == null:
		drag.refuse()
		preview.clear()
		return
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
	var phase := flow.finish_placement()
	_refresh_hud()
	if phase == RoundFlow.Phase.NO_MOVES:
		_show_result()
	else:
		drag.set_enabled(true)
	placement_settled.emit(phase)


## "한 판 더" (one tap): next attempt, fresh board and tray.
func retry() -> void:
	audio.ui_tap()
	flow.retry()
	shown_score = 0
	placements = 0
	preview.clear()
	_ret = {}
	score_rolled = 0.0
	fx.clear()
	_result.visible = false
	drag.set_enabled(true)
	_refresh_hud()


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
	_hud_score = _label(root, Rect2(layout.hud_rect.position + Vector2(24, 18), Vector2(420, 60)), 44, HORIZONTAL_ALIGNMENT_LEFT)
	_hud_score.add_theme_constant_override(&"outline_size", 8)
	_hud_score.add_theme_color_override(&"font_outline_color", Palette.STICKER_WHITE)
	_hud_score.pivot_offset = Vector2(0, 30)
	fx.score_target = _hud_score.position + Vector2(150, 30)
	_hud_attempt = _label(root, Rect2(Vector2(layout.canvas.x - 324, 30), Vector2(300, 40)), 24, HORIZONTAL_ALIGNMENT_RIGHT)
	_hud_attempt.add_theme_color_override(&"font_color", Palette.INK_LIGHT)
	_result = Control.new()
	_result.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result.visible = false
	root.add_child(_result)
	var dim := ColorRect.new()
	# Failure never darkens (art-bible §2): a warm paper veil, not an ink dim.
	dim.color = Color(Palette.KRAFT, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result.add_child(dim)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.STICKER_WHITE
	sb.set_corner_radius_all(28)
	sb.shadow_color = Color(Palette.INK, 0.35)
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(0, 8)
	sb.set_content_margin_all(36)
	card.add_theme_stylebox_override(&"panel", sb)
	card.position = Vector2(80, 380)
	card.size = Vector2(layout.canvas.x - 160, 480)
	card.rotation = deg_to_rad(-1.5)
	_result.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 18)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)
	var title := _label(col, Rect2(), 36, HORIZONTAL_ALIGNMENT_CENTER)
	title.text = tr("UI_RESULT_TITLE")
	var sub := _label(col, Rect2(), 24, HORIZONTAL_ALIGNMENT_CENTER)
	sub.text = tr("UI_RESULT_SCORE")
	sub.add_theme_color_override(&"font_color", Palette.INK_LIGHT)
	_result_score = _label(col, Rect2(), 72, HORIZONTAL_ALIGNMENT_CENTER)
	_result_best = _label(col, Rect2(), 26, HORIZONTAL_ALIGNMENT_CENTER)
	_result_count = _label(col, Rect2(), 22, HORIZONTAL_ALIGNMENT_CENTER)
	_result_count.add_theme_color_override(&"font_color", Palette.INK_LIGHT)
	var btn := Button.new()
	btn.name = "RetryButton"
	btn.text = tr("UI_RETRY")
	btn.custom_minimum_size = Vector2(320, 96)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override(&"font_size", 36)
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		var b := StyleBoxFlat.new()
		b.bg_color = Palette.INK
		b.set_corner_radius_all(48)
		b.border_color = Palette.STICKER_WHITE
		b.set_border_width_all(6)
		b.shadow_color = Color(Palette.INK, 0.35)
		b.shadow_size = 1
		b.shadow_offset = Vector2(0, 0 if state == &"pressed" else 6)
		btn.add_theme_stylebox_override(state, b)
	for c: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		btn.add_theme_color_override(c, Palette.STICKER_WHITE)
	btn.pressed.connect(retry)
	col.add_child(btn)


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
	_result_score.text = str(flow.stage_score())
	_result_best.text = tr("UI_RESULT_BEST") % flow.best_placement()
	_result_count.text = tr("UI_RESULT_PLACEMENTS") % placements
	_result.visible = true
	audio.result()


## Retry button (autoplay presses it with a real touch).
func retry_button() -> Button:
	return _result.find_child("RetryButton", true, false)


## True while the result panel is up.
func is_result_visible() -> bool:
	return _result.visible


# --- drawing -------------------------------------------------------------------

func _build_layers() -> void:
	# chain-preview rule 18: paper → stickers → outlines → ghost → dragged piece → eggs → badges → banner.
	for spec: Array in [[&"bg", _draw_bg], [&"board", _draw_board], [&"tray", _draw_tray], [&"drag", _draw_drag],
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
	for i: int in flow.slot_count():
		var sr := layout.slot_rect(i).grow(-8)
		StickerPainter.rounded(ci, sr, Color(Palette.BOARD_PAPER, 0.45), 20)
		var p := flow.piece_at(i)
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
		if not reduced and _ret.is_empty() and not player.is_playing() and _slot_placeable(i):
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
