## Debug-only scripted play for run-and-observe (.claude/docs/run-and-observe.md).
## Attached by [App] when launched with [code]-- --autoplay[/code]. Drives the REAL
## input path with synthetic touch events ([method Input.parse_input_event]) through
## the whole T1 loop and captures screenshots. Moves come from the committed stage
## solutions ([code]tests/fixtures/stages/solutions.json[/code], the same list the
## stage tests replay) — it is a test bot, not game logic.
## Scenarios ([code]--scenario=[/code]):
## [br]- [code]main[/code] (default; use with [code]--fresh-save[/code]): stage select → team
##   select 1-1 → play 1-1 to clear (tray-held-during-chain shot) → result → 다음 스테이지
##   → team select 1-2 → play → result → 한 판 더 → pause → 스테이지 선택 → 연습.
## [br]- [code]obstacles[/code] (use with [code]--fresh-save --unlock-all[/code]): team select 1-10
##   (slot edit) → play 1-10 (stones, ice, target cells, obstacle preview) → result →
##   1-9 start (frozen faces) + preview.
## Options: [code]--shots=<res:// or abs dir>[/code].
class_name DebugAutoplay
extends Node

const DEFAULT_SHOTS := "res://production/qa/evidence/t1-stages"
const SOLUTIONS_PATH := "res://tests/fixtures/stages/solutions.json"
const DRAG_STEPS := 14

## App under test.
var app: App

var _dir: String
var _settled: bool = false
var _solutions: Dictionary = {}
var _fails: PackedStringArray = PackedStringArray()
var _last_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	_dir = DEFAULT_SHOTS
	var scenario := "main"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_dir = a.get_slice("=", 1)
		elif a.begins_with("--scenario="):
			scenario = a.get_slice("=", 1)
	if _dir.begins_with("res://"):
		_dir = ProjectSettings.globalize_path(_dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOLUTIONS_PATH))
	if data is Dictionary:
		for s: Dictionary in data["stages"]:
			_solutions[s["id"]] = s["moves"]
	if scenario == "obstacles":
		_obstacles.call_deferred()
	else:
		_main.call_deferred()


# --- scenarios -----------------------------------------------------------------

func _main() -> void:
	await _frames(40)
	await _shot("01-stage-select-fresh")
	_check(app.is_unlocked(0) and not app.is_unlocked(1), "fresh save: only 1-1 open")
	await _tap_node(_select().tiles[0])
	await _wait_screen(TeamSelectScreen)
	await _frames(20)
	await _shot("02-team-select-1-1")
	await _tap_node((app.current as TeamSelectScreen).start_button)
	await _wait_screen(GameScreen)
	await _frames(30)
	await _shot("03-play-1-1-start")
	await _play_solution("1-1", "04-play-1-1")
	await _wait_result()
	await _shot("06-result-1-1-clear")
	_check(_game().last_result != null and _game().last_result.outcome == RoundResult.Outcome.CLEARED, "1-1 cleared")
	_check(app.progress.stars_of(&"1-1") >= 1 and app.is_unlocked(1), "1-1 stars saved, 1-2 unlocked")
	await _tap_node(_game().result_button("NextButton"))
	await _wait_screen(TeamSelectScreen)
	await _frames(20)
	await _shot("07-team-select-1-2")
	await _tap_node((app.current as TeamSelectScreen).start_button)
	await _wait_screen(GameScreen)
	await _frames(20)
	await _play_solution("1-2", "08-play-1-2")
	await _wait_result()
	await _shot("09-result-1-2-clear")
	_check(app.progress.stars_of(&"1-2") >= 1, "1-2 stars saved")
	var before_attempt := _game().flow.attempt
	await _tap_node(_game().result_button("RetryButton"))
	await _frames(30)
	_check(_game().flow.attempt == before_attempt + 1 and _game().team.size() == 1 and _game().team[0] == &"nyangi", "한 판 더: same team, next attempt")
	await _shot("10-retry-1-2")
	await _tap_node(_game().find_child("PauseButton", true, false))
	await _frames(15)
	await _shot("11-pause")
	await _tap_node(_game().find_child("PauseExitButton", true, false))
	await _wait_screen(StageSelectScreen)
	await _frames(20)
	await _shot("12-stage-select-progress")
	_check(app.is_unlocked(2) and not app.is_unlocked(3), "after 1-2: 1-3 open, 1-4 locked")
	await _tap_node(_select().practice_button)
	await _wait_screen(GameScreen)
	await _frames(30)
	await _shot("13-practice")
	_finish()


func _obstacles() -> void:
	await _frames(40)
	await _shot("20-stage-select-unlocked")
	await _tap_node(_select().tiles[9])
	await _wait_screen(TeamSelectScreen)
	await _frames(20)
	await _shot("21-team-select-1-10")
	var ts := app.current as TeamSelectScreen
	await _tap_node(ts.slots[2])
	await _frames(10)
	await _shot("22-team-select-slot-emptied")
	_check(ts.start_button.disabled, "empty slot disables start")
	await _tap_node(ts.cards[2])
	await _frames(10)
	_check(not ts.start_button.disabled and ",".join(ts.draft) == "nyangi,gomgom,piyak", "card refills the slot")
	await _tap_node(ts.start_button)
	await _wait_screen(GameScreen)
	await _frames(30)
	await _shot("23-play-1-10-start")
	await _play_solution("1-10", "24-play-1-10")
	await _wait_result()
	await _shot("26-result-1-10")
	await _tap_node(_game().result_button("StagesButton"))
	await _wait_screen(StageSelectScreen)
	await _frames(10)
	await _tap_node(_select().tiles[8])
	await _wait_screen(TeamSelectScreen)
	await _frames(10)
	await _tap_node((app.current as TeamSelectScreen).start_button)
	await _wait_screen(GameScreen)
	await _frames(30)
	await _shot("27-play-1-9-frozen-faces")
	var moves: Array = _solutions.get("1-9", [])
	if not moves.is_empty():
		var m: Array = moves[0]
		await _drag_to(int(m[0]), Vector2i(int(m[1]), int(m[2])))
		await _frames(20)
		await _shot("28-play-1-9-preview")
	_finish()


# --- play ----------------------------------------------------------------------

## Replays a committed solution with real drags. Shots: one drag preview (the first
## move with obstacle / goal markers, else the first move), the tray while a chain
## plays right after a tray-emptying commit, and the refilled tray after it.
func _play_solution(id: String, prefix: String) -> void:
	var moves: Array = _solutions.get(id, [])
	_check(not moves.is_empty(), "solution for %s" % id)
	var preview_done := false
	var held_done := false
	for i: int in moves.size():
		var g := _game()
		if g.is_result_visible() or g.flow.is_ended():
			break
		var m: Array = moves[i]
		var slot := int(m[0])
		var anchor := Vector2i(int(m[1]), int(m[2]))
		if not g.flow.can_place(slot, anchor):
			_fails.append("%s move %d not placeable" % [id, i])
			break
		var pieces_before := 0
		for k: int in g.flow.slot_count():
			if g.flow.piece_at(k) != null:
				pieces_before += 1
		await _drag_to(slot, anchor)
		var pm := g.preview.model
		var interesting := pm != null and (not pm.cracked.is_empty() or not pm.freed.is_empty() or not pm.thawed.is_empty()
				or (g.preview.goals != null and not g.preview.goals.target_cells_hit.is_empty()) or pm.banner != PreviewModel.Banner.NONE)
		if not preview_done and (interesting or i == moves.size() - 1 or (id == "1-1" and i == 0)):
			await _frames(16)
			await _shot("%s-preview" % prefix)
			preview_done = true
		_settled = false
		g.placement_settled.connect(_on_settled, CONNECT_ONE_SHOT)
		_touch(_last_pos, false)
		if not held_done and pieces_before == 1 and i < moves.size() - 1:
			await get_tree().process_frame
			_check(g._tray_hold and g.player.is_playing(), "%s: tray display held during playback" % id)
			await _shot("%s-tray-held-during-chain" % prefix)
			while not _settled:
				await get_tree().process_frame
			await _frames(6)
			await _shot("%s-tray-refilled-after-chain" % prefix)
			held_done = true
		while not _settled:
			await get_tree().process_frame
	print("AUTOPLAY %s placements=%d score=%d ended=%s" % [id, _game().flow.placements_used, _game().flow.stage_score(), _game().flow.is_ended()])


func _on_settled(_p: RoundFlow.Phase) -> void:
	_settled = true


## Press the slot, drag so the F1/F2 anchor lands on [param anchor] (finger stays down).
func _drag_to(slot: int, anchor: Vector2i) -> void:
	var g := _game()
	var lay := g.layout
	var p := g.flow.piece_at(slot)
	var size := Vector2(p.shape.width(), p.shape.height())
	var start := lay.slot_rect(slot).get_center()
	var tl := lay.board_origin + Vector2(anchor.y, anchor.x) * lay.s
	var target := Vector2(tl.x + size.x * lay.s * 0.5, tl.y + size.y * lay.s + g.input_tuning.lift_offset_cells * lay.s)
	_touch(start, true)
	await _frames(3)
	var prev := start
	for i: int in range(1, DRAG_STEPS + 1):
		var t := float(i) / DRAG_STEPS
		var pos := start.lerp(target, t * t * (3.0 - 2.0 * t))
		_drag(pos, pos - prev)
		prev = pos
		await get_tree().process_frame
	await _frames(4)
	_last_pos = target


# --- helpers -------------------------------------------------------------------

func _game() -> GameScreen:
	return app.current as GameScreen


func _select() -> StageSelectScreen:
	return app.current as StageSelectScreen


func _wait_screen(type: Variant) -> void:
	var n := 0
	while not is_instance_of(app.current, type) and n < 300:
		await get_tree().process_frame
		n += 1
	_check(is_instance_of(app.current, type), "screen switch")
	await _frames(2)


func _wait_result() -> void:
	var n := 0
	while not _game().is_result_visible() and n < 600:
		await get_tree().process_frame
		n += 1
	_check(_game().is_result_visible(), "result visible")
	await _frames(40)


func _tap_node(c: Control) -> void:
	if c == null:
		_fails.append("missing control to tap")
		return
	var pos := c.get_global_rect().get_center()
	_touch(pos, true)
	await _frames(3)
	_touch(pos, false)
	await _frames(3)


func _touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
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


func _check(ok: bool, what: String) -> void:
	print("AUTOPLAY check %s: %s" % ["OK" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _finish() -> void:
	print("AUTOPLAY done fails=%d %s" % [_fails.size(), ", ".join(_fails)])
	get_tree().quit(0 if _fails.is_empty() else 1)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _dir.path_join(shot_name + ".png")
	var err := img.save_png(path)
	print("AUTOPLAY shot %s -> %s (%s)" % [shot_name, path, error_string(err)])
