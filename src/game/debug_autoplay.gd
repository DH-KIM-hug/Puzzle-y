## Debug-only scripted play for run-and-observe (.claude/docs/run-and-observe.md).
## Attached by [GameScreen] when launched with [code]-- --autoplay[/code].
## Drives the REAL input path with synthetic touch events
## ([method Input.parse_input_event]) and captures screenshots of: start state,
## a drag with the chain preview visible, a chain mid-playback, the result
## panel, and the board after one-tap "한 판 더". Move choice reads the preview
## model (Rules Core) — it is a test bot, not game logic.
## Options: [code]--shots=<res:// or abs dir>[/code], [code]--seed=N[/code],
## [code]--min-depth=N[/code] (hunt a chain of at least N before the chain shots, default 2),
## [code]--burst[/code] (also save a frame series t0-03-burst-NN through the whole chain).
class_name DebugAutoplay
extends Node

const DEFAULT_SHOTS := "res://production/qa/evidence/t0-greybox"
const MAX_PLACEMENTS := 120
const DRAG_STEPS := 14

## Screen under test.
var screen: GameScreen

var _dir: String
var _settled: bool = false
var _min_depth: int = 2
var _burst: bool = false


func _ready() -> void:
	_dir = DEFAULT_SHOTS
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_dir = a.get_slice("=", 1)
		elif a.begins_with("--min-depth="):
			_min_depth = int(a.get_slice("=", 1))
		elif a == "--burst":
			_burst = true
	if _dir.begins_with("res://"):
		_dir = ProjectSettings.globalize_path(_dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	screen.placement_settled.connect(func(_p: RoundFlow.Phase) -> void: _settled = true)
	_run.call_deferred()


func _run() -> void:
	await _frames(45)
	await _shot("t0-01-start")
	var preview_done := false
	var chain_done := false
	var n := 0
	while not screen.is_result_visible() and n < MAX_PLACEMENTS:
		var move := _choose(not chain_done)
		if move.is_empty():
			break
		var depth: int = move[&"depth"]
		var want_shots := not chain_done and (depth >= _min_depth or (n >= 40 and depth >= 1))
		await _drag_to(move[&"slot"], move[&"anchor"], want_shots and not preview_done)
		if want_shots:
			preview_done = true
		_settled = false
		_touch(Vector2.ZERO, false, true)
		if want_shots and _burst:
			var k := 0
			while not screen.player.is_playing():
				await get_tree().process_frame
			while screen.player.is_playing() and k < 40:
				await _frames(3)
				await _shot("t0-03-burst-%02d" % k)
				print("AUTOPLAY burst %02d clock=%.2f" % [k, screen.player.clock])
				k += 1
			chain_done = true
			print("AUTOPLAY chain shot: depth=%d placement=%d" % [depth, n + 1])
		elif want_shots:
			await _wait_mid_chain()
			await _shot("t0-03-chain-midplay")
			chain_done = true
			print("AUTOPLAY chain shot: depth=%d placement=%d" % [depth, n + 1])
		elif chain_done:
			# Exercise fast-forward + skip (chain-presentation rule 22) after the shots.
			await _frames(12)
			if screen.player.is_playing():
				_tap_board()
				await _frames(2)
				_tap_board()
		while not _settled:
			await get_tree().process_frame
		n += 1
	print("AUTOPLAY placements=%d score=%d best=%d result=%s" % [n, screen.flow.stage_score(), screen.flow.best_placement(), screen.is_result_visible()])
	if screen.is_result_visible():
		await _frames(30)
		await _shot("t0-04-result")
		var btn := screen.retry_button()
		var c := btn.get_global_rect().get_center()
		_touch(c, true, false)
		await _frames(3)
		_touch(c, false, false)
		await _frames(30)
		print("AUTOPLAY retry: attempt=%d score=%d result=%s" % [screen.flow.attempt + 1, screen.flow.stage_score(), screen.is_result_visible()])
		await _shot("t0-05-retry")
	if screen.audio != null:
		print("AUTOPLAY audio: state=%s voices_started=%d" % [SfxPlayer.State.keys()[screen.audio.sfx.state], screen.audio.sfx.started_count])
	get_tree().quit(0 if screen.flow.attempt >= 1 else 1)


## Best (greedy) move while hunting a chain; afterwards the move that clears least,
## so the board jams and the result panel is reached.
func _choose(hunt: bool) -> Dictionary:
	var flow := screen.flow
	var best := {}
	var best_score := -INF
	for slot: int in flow.slot_count():
		var p := flow.piece_at(slot)
		if p == null:
			continue
		for r: int in flow.board().height:
			for c: int in flow.board().width:
				var a := Vector2i(r, c)
				if not flow.can_place(slot, a):
					continue
				var m := PreviewModel.preview(flow.board(), p, a, flow.context_for_next_placement())
				var depth: int = m.result.summary[ChainEvent.K_CHAIN_DEPTH]
				var cleared := m.clear_waves.size()
				var v: float
				if hunt:
					v = depth * 1000.0 + cleared * 10.0 + _neighbours(p, a) - r * 0.01
				else:
					v = -cleared * 100.0 - _neighbours(p, a) * 3.0 + float((r * 7 + c * 3 + slot) % 5)
				if v > best_score:
					best_score = v
					best = {&"slot": slot, &"anchor": a, &"depth": depth}
	return best


func _neighbours(p: PieceInstance, a: Vector2i) -> float:
	var b := screen.flow.board()
	var n := 0.0
	for o: Vector2i in p.shape.offsets:
		var cell := a + o
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := cell + d
			if not b.in_bounds(q.x, q.y) or b.blocks_placement(b.index_of_cell(q)):
				n += 1.0
	return n


## Press the slot, drag the finger so the F1/F2 anchor lands on [param anchor].
func _drag_to(slot: int, anchor: Vector2i, shot: bool) -> void:
	var lay := screen.layout
	var p := screen.flow.piece_at(slot)
	var size := Vector2(p.shape.width(), p.shape.height())
	var start := lay.slot_rect(slot).get_center()
	var tl := lay.board_origin + Vector2(anchor.y, anchor.x) * lay.s
	var target := Vector2(tl.x + size.x * lay.s * 0.5, tl.y + size.y * lay.s + screen.input_tuning.lift_offset_cells * lay.s)
	_touch(start, true, false)
	await _frames(3)
	var prev := start
	for i: int in range(1, DRAG_STEPS + 1):
		var t := float(i) / DRAG_STEPS
		var pos := start.lerp(target, t * t * (3.0 - 2.0 * t))
		_drag(pos, pos - prev)
		prev = pos
		await get_tree().process_frame
	await _frames(4)
	if shot:
		await _frames(16)
		await _shot("t0-02-drag-preview")
		print("AUTOPLAY preview shot: banner=%d n=%d anchor=%s" % [screen.preview.model.banner if screen.preview.model else -1,
				screen.preview.model.banner_n if screen.preview.model else -1, anchor])
	_last_pos = target


var _last_pos: Vector2 = Vector2.ZERO


func _wait_mid_chain() -> void:
	var player := screen.player
	while not player.is_playing():
		await get_tree().process_frame
	# Aim at the stage-2 cut-in (wave 1) if any, else the first peel, mid-lift.
	var target := player.timeline.total * 0.4
	var first_peel := -1.0
	for c: Dictionary in player.timeline.cues:
		var kind := int(c[ChainTimeline.K_KIND])
		if kind == ChainTimeline.Kind.BANNER:
			target = float(c[ChainTimeline.K_T]) + 0.12
			first_peel = -2.0
			break
		if kind == ChainTimeline.Kind.PEEL and first_peel == -1.0:
			first_peel = float(c[ChainTimeline.K_T])
	if first_peel >= 0.0:
		target = first_peel + 0.1
	while player.is_playing() and player.clock < target:
		await get_tree().process_frame


func _tap_board() -> void:
	var c := screen.layout.board_rect().get_center()
	_touch(c, true, false)
	_touch(c, false, false)


func _touch(pos: Vector2, pressed: bool, use_last: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = _last_pos if use_last else pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = pos
	e.relative = rel
	Input.parse_input_event(e)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _dir.path_join(name + ".png")
	var err := img.save_png(path)
	print("AUTOPLAY shot %s -> %s (%s)" % [name, path, error_string(err)])
