## Title + stage select (task T1 screen 1): the 10 MVP stages as sticker tiles
## (locked until the previous stage is cleared, best stars shown) and the
## "연습" button for the endless free-play round. Art: art-bible §2 "메뉴 / 월드맵"
## (kraft paper, big sticker buttons, diary layout).
class_name StageSelectScreen
extends Control

## A stage tile was tapped (index into the catalog; only unlocked stages emit).
signal stage_chosen(index: int)
## "연습" was tapped.
signal practice_chosen

const TILE := Vector2(330, 150)
const GRID_TOP := 236.0
const GRID_GAP := Vector2(20, 16)

## Owning app (data source).
var app: App
## Stage tiles in catalog order.
var tiles: Array[PaintButton] = []
## Practice button.
var practice_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = app.theme
	var w := get_viewport_rect().size.x
	var left := (w - TILE.x * 2.0 - GRID_GAP.x) * 0.5
	for i: int in app.catalog.stages.size():
		var idx := i
		var b := PaintButton.make(TILE, func(ci: PaintButton, pressed: bool) -> void: _paint_tile(ci, idx, pressed))
		b.name = "Stage_%s" % String(app.catalog.stages[i].id)
		b.position = Vector2(left + (i % 2) * (TILE.x + GRID_GAP.x), GRID_TOP + (i / 2) * (TILE.y + GRID_GAP.y))
		b.disabled = not app.is_unlocked(i)
		b.pressed.connect(func() -> void: stage_chosen.emit(idx))
		add_child(b)
		tiles.append(b)
	practice_button = UiKit.button(tr("UI_PRACTICE"), UiKit.Kind.SECONDARY, Vector2(420, 88), 30)
	practice_button.name = "PracticeButton"
	add_child(practice_button)
	var last_y := GRID_TOP + ceili(app.catalog.stages.size() / 2.0) * (TILE.y + GRID_GAP.y)
	practice_button.position = Vector2((w - 420) * 0.5, last_y + 24)
	practice_button.pressed.connect(func() -> void: practice_chosen.emit())


func _draw() -> void:
	var size_v := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size_v), Palette.KRAFT)
	for i: int in 26:
		var y := fmod(i * 97.0, size_v.y)
		draw_line(Vector2(0, y), Vector2(size_v.x, y + 14.0), Color(Palette.KRAFT_SHADE, 0.35), 2.0, true)
	# Masking-tape strip + title sticker.
	var title_r := Rect2(Vector2(size_v.x * 0.5 - 230, 48), Vector2(460, 112))
	draw_set_transform(title_r.get_center(), deg_to_rad(-1.5))
	var local := Rect2(-title_r.size * 0.5, title_r.size)
	UiKit.sticker_rect(self, local, Palette.STICKER_WHITE, 30, 7)
	StickerPainter.rounded(self, Rect2(Vector2(-70, local.position.y - 16), Vector2(140, 30)), Color(Palette.KRAFT_SHADE, 0.85), 4)
	StickerPainter.label(self, Vector2(0, -12), tr("UI_GAME_TITLE"), app.font, 56, Palette.INK, 0)
	StickerPainter.label(self, Vector2(0, 34), tr("UI_STAGE_SELECT_SUB"), app.font, 24, Palette.INK_LIGHT, 0)
	draw_set_transform(Vector2.ZERO)
	# Face stickers flanking the title (decoration, not touchable: no extra margin).
	var ids: Array[StringName] = [&"nyangi", &"gomgom", &"piyak"]
	StickerPainter.draw_face(self, Vector2(70, 120), 72.0, app.visuals.look(ids[0]), StickerPainter.Expr.NORMAL, 1.0)
	StickerPainter.draw_face(self, Vector2(size_v.x - 70, 112), 72.0, app.visuals.look(ids[1]), StickerPainter.Expr.ACTIVE, 1.0)
	StickerPainter.label(self, Vector2(size_v.x * 0.5, GRID_TOP - 30), tr("UI_STAGE_SELECT"), app.font, 28, Palette.INK, 6)


func _paint_tile(ci: PaintButton, i: int, pressed: bool) -> void:
	var stage := app.catalog.stages[i]
	var unlocked := app.is_unlocked(i)
	var stars := app.progress.stars_of(stage.id)
	var r := Rect2(Vector2(6, 6), ci.size - Vector2(12, 16))
	var off := Vector2(0, 4) if pressed else Vector2.ZERO
	r.position += off
	if unlocked:
		UiKit.sticker_rect(ci, r, Palette.STICKER_WHITE, 22, 0.0 if pressed else 6.0)
		var next_up := stars == 0
		if next_up:
			# "Play this next": thick ink rim (no colour meaning borrowed).
			ci.draw_style_box(_rim(), r.grow(-2))
		ci.draw_string(app.font, r.position + Vector2(20, 52), String(stage.id), HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Palette.INK)
		ci.draw_string(app.font, r.position + Vector2(20, 90), tr(stage.name_key), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 34, 22, Palette.INK_LIGHT)
		for k: int in 3:
			UiKit.star(ci, r.position + Vector2(r.size.x - 104 + k * 38, r.size.y - 22), 16.0, k < stars)
		if stage.goals.size() > 0:
			var face_crew := stage.recommended_team[0] if not stage.recommended_team.is_empty() else &"nyangi"
			StickerPainter.draw_face(ci, r.position + Vector2(r.size.x - 44, 44), 44.0, app.visuals.look(face_crew), StickerPainter.Expr.NORMAL, 1.0)
	else:
		StickerPainter.rounded(ci, r, Color(Palette.KRAFT_SHADE, 0.9), 22)
		StickerPainter.dashed_rect(ci, r.grow(-8), Color(Palette.INK, 0.3), 2.0, 8.0)
		ci.draw_string(app.font, r.position + Vector2(20, 52), String(stage.id), HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(Palette.INK, 0.45))
		ci.draw_string(app.font, r.position + Vector2(20, 90), tr("UI_LOCKED"), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(Palette.INK, 0.5))
		UiKit.padlock(ci, r.position + Vector2(r.size.x - 50, r.size.y * 0.5), 44.0)


var _rim_box: StyleBoxFlat


func _rim() -> StyleBoxFlat:
	if _rim_box == null:
		_rim_box = StyleBoxFlat.new()
		_rim_box.draw_center = false
		_rim_box.border_color = Palette.INK
		_rim_box.set_border_width_all(4)
		_rim_box.set_corner_radius_all(20)
		_rim_box.anti_aliasing = true
	return _rim_box
