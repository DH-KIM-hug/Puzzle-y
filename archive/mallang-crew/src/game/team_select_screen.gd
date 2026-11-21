## Team select (design/gdd/team-composition.md rules 2, 7–8, 12, 14–19, UI
## Requirements I1–I7). Opens pre-filled with the F2 default team so "시작!" is
## one tap; the rules come from [TeamRules] — this screen only edits a draft.
## Shows: stage summary (goals, pieces, star thresholds, best stars, team limits),
## N team pockets (lock / guest marks), the crew roster with piece shapes
## ("자주/가끔") and the ability diagram, and a 궁합 노트 stub (F4/F5 come later).
## No synergy table, no team score (rule 20).
class_name TeamSelectScreen
extends Control

## "시작!" with a valid team (slot order).
signal confirmed(team: Array[StringName])
## Back to stage select (draft discarded, memory unchanged — rule 11).
signal back_requested

const SLOT_SIZE := Vector2(200, 158)
const CARD_SIZE := Vector2(336, 180)
const SUMMARY_TOP := 92.0
const SLOTS_TOP := 282.0
const ROSTER_TOP := 524.0

## Owning app.
var app: App
## Stage being prepared.
var stage: StageDef
## Draft team (slot order; [constant TeamRules.EMPTY_SLOT] = empty).
var draft: Array[StringName] = []
## Slot the player picked to fill next (-1 = none).
var selected_slot: int = -1
## Start button.
var start_button: Button
## Roster cards in registry order.
var cards: Array[PaintButton] = []
## Team pockets.
var slots: Array[PaintButton] = []

var _rule: TeamRule
var _owned: OwnedCrews
var _hint: String = ""
var _flash_slot: int = -1
var _flash_t: float = 0.0
var _reason_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = app.theme
	var reg := app.env.registry
	_rule = stage.effective_team_rule()
	_owned = app.progress.owned_crews(reg)
	draft = TeamRules.resolve_default_team(_rule, reg, _owned, app.progress.memory, stage.id)
	var w := get_viewport_rect().size.x
	var back := UiKit.button("<", UiKit.Kind.SECONDARY, Vector2(64, 64), 34)
	back.name = "BackButton"
	back.position = Vector2(16, 14)
	back.pressed.connect(func() -> void: back_requested.emit())
	add_child(back)
	var n := _rule.team_size
	var slots_w := n * SLOT_SIZE.x + (n - 1) * 20.0
	for i: int in n:
		var idx := i
		var b := PaintButton.make(SLOT_SIZE, func(ci: PaintButton, pressed: bool) -> void: _paint_slot(ci, idx, pressed))
		b.name = "Slot_%d" % i
		b.position = Vector2((w - slots_w) * 0.5 + i * (SLOT_SIZE.x + 20.0), SLOTS_TOP)
		b.pressed.connect(func() -> void: _on_slot(idx))
		add_child(b)
		slots.append(b)
	var left := (w - CARD_SIZE.x * 2.0 - 16.0) * 0.5
	var crews := reg.all()
	for i: int in crews.size():
		var def := crews[i]
		var b := PaintButton.make(CARD_SIZE, func(ci: PaintButton, pressed: bool) -> void: _paint_card(ci, def, pressed))
		b.name = "Card_%s" % def.id
		b.position = Vector2(left + (i % 2) * (CARD_SIZE.x + 16.0), ROSTER_TOP + (i / 2) * (CARD_SIZE.y + 12.0))
		b.pressed.connect(func() -> void: _on_card(def.id))
		add_child(b)
		cards.append(b)
	_reason_label = UiKit.label("", 24, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER)
	_reason_label.position = Vector2(16, SLOTS_TOP + SLOT_SIZE.y + 2)
	_reason_label.size = Vector2(w - 32, 36)
	add_child(_reason_label)
	start_button = UiKit.button(tr("UI_START"), UiKit.Kind.PRIMARY, Vector2(420, 92), 40)
	start_button.name = "StartButton"
	start_button.position = Vector2((w - 420) * 0.5, get_viewport_rect().size.y - 108)
	start_button.pressed.connect(_on_start)
	add_child(start_button)
	_refresh()


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - delta)
		for s: PaintButton in slots:
			s.queue_redraw()


## F1 result of the current draft.
func reason() -> TeamRules.Reason:
	return TeamRules.check_team(draft, _rule, app.env.registry, _owned)


func _on_start() -> void:
	if reason() == TeamRules.Reason.OK:
		confirmed.emit(draft.duplicate())


func _on_slot(i: int) -> void:
	if _rule.locked_at(i) != &"":
		_hint = tr("UI_TEAM_LIMIT_FIXED")
		_flash(i)
	elif draft[i] != TeamRules.EMPTY_SLOT:
		draft[i] = TeamRules.EMPTY_SLOT  # rule 16: tap a pocket = take the crew out
		selected_slot = i
		_hint = ""
	else:
		selected_slot = i
	_refresh()


func _on_card(id: StringName) -> void:
	var at := draft.find(id)
	if at >= 0:
		_flash(at)  # rule 17: already in the team → highlight its pocket
		_refresh()
		return
	if not _owned.is_owned(id):
		_hint = tr("UI_TEAM_NOT_OWNED")
	elif _rule.banned.has(id):
		_hint = tr("UI_TEAM_BANNED")
	else:
		var target := -1
		if selected_slot >= 0 and selected_slot < draft.size() and draft[selected_slot] == TeamRules.EMPTY_SLOT:
			target = selected_slot
		else:
			target = draft.find(TeamRules.EMPTY_SLOT)  # rule 15: first empty slot
		if target < 0:
			_hint = tr("UI_TEAM_LIMIT_FIXED") if _rule.is_fixed() else tr("UI_TEAM_HINT_FULL")
		else:
			draft[target] = id
			selected_slot = -1
			_hint = ""
			_flash(target)
	_refresh()


func _flash(i: int) -> void:
	_flash_slot = i
	_flash_t = 0.35


func _refresh() -> void:
	var r := reason()
	start_button.disabled = r != TeamRules.Reason.OK
	var text := _hint
	if text == "":
		match r:
			TeamRules.Reason.OK:
				text = tr("UI_TEAM_LIMIT_FIXED") if _rule.is_fixed() else tr("UI_TEAM_READY")
			TeamRules.Reason.INCOMPLETE:
				text = tr("UI_TEAM_REASON_INCOMPLETE")
			TeamRules.Reason.DUPLICATE:
				text = tr("UI_TEAM_REASON_DUPLICATE")
			TeamRules.Reason.NOT_OWNED:
				text = tr("UI_TEAM_REASON_NOT_OWNED")
			TeamRules.Reason.BANNED:
				text = tr("UI_TEAM_REASON_BANNED")
			TeamRules.Reason.LOCK_MISMATCH:
				text = tr("UI_TEAM_REASON_LOCK")
			TeamRules.Reason.COLOUR_CLASH:
				text = tr("UI_TEAM_REASON_COLOUR")
			_:
				text = tr("UI_TEAM_REASON_OTHER")
	_reason_label.text = text
	_reason_label.add_theme_color_override(&"font_color", Palette.INK if r == TeamRules.Reason.OK else Palette.INK_LIGHT)
	for s: PaintButton in slots:
		s.queue_redraw()
	for c: PaintButton in cards:
		c.queue_redraw()
	queue_redraw()


# --- drawing -------------------------------------------------------------------

func _draw() -> void:
	var sz := get_viewport_rect().size
	# Album page (art-bible §2 "팀 편성 / 앨범": cream page, low contrast).
	draw_rect(Rect2(Vector2.ZERO, sz), Palette.KRAFT)
	StickerPainter.rounded(self, Rect2(Vector2(8, 84), sz - Vector2(16, 92)), Color(Palette.BOARD_PAPER, 0.75), 26)
	draw_string(app.font, Vector2(96, 60), tr("UI_TEAM_TITLE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Palette.INK)
	# Stage summary card (I3, I4).
	var card := Rect2(Vector2(24, SUMMARY_TOP + 8), Vector2(sz.x - 48, 166))
	UiKit.sticker_rect(self, card, Palette.STICKER_WHITE, 20, 5)
	StickerPainter.rounded(self, Rect2(Vector2(card.get_center().x - 60, card.position.y - 12), Vector2(120, 26)), Color(Palette.KRAFT_SHADE, 0.85), 4)
	var x := card.position.x + 24
	draw_string(app.font, Vector2(x, card.position.y + 50), "%s  %s" % [stage.id, tr(stage.name_key)], HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 190, 32, Palette.INK)
	draw_string(app.font, Vector2(x, card.position.y + 92), "%s: %s" % [tr("UI_STAGE_GOALS"), UiKit.goal_summary(self, stage)],
			HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 48, 24, Palette.INK)
	var line := tr("UI_STAGE_PIECES") % stage.piece_limit
	if stage.star_points.size() >= 2:
		line += "  ·  " + tr("UI_STAR_LINE") % [stage.star_points[0], stage.star_points[1]]
	draw_string(app.font, Vector2(x, card.position.y + 128), line, HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 48, 22, Palette.INK_LIGHT)
	var best := app.progress.stars_of(stage.id)
	for k: int in 3:
		UiKit.star(self, Vector2(card.end.x - 132 + k * 42, card.position.y + 38), 17.0, k < best)
	# Roster heading + 궁합 노트 stub (I7, F4/F5 not implemented yet).
	if not _rule.is_fixed():
		draw_string(app.font, Vector2(32, ROSTER_TOP - 10), tr("UI_TEAM_HINT_PICK"), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.INK_LIGHT)
	var note_y := ROSTER_TOP + 3 * (CARD_SIZE.y + 12.0) + 2
	var note := Rect2(Vector2(40, note_y), Vector2(sz.x - 80, 52))
	StickerPainter.rounded(self, Rect2(note.position + Vector2(2, 4), note.size), Color(Palette.INK, 0.18), 8)
	StickerPainter.rounded(self, note, Palette.FACE_CREAM, 8)
	draw_string(app.font, note.position + Vector2(16, 34), "%s · %s" % [tr("UI_LINK_NOTE_TITLE"), tr("UI_LINK_NOTE_STUB")],
			HORIZONTAL_ALIGNMENT_LEFT, note.size.x - 28, 19, Palette.INK_LIGHT)


func _paint_slot(ci: PaintButton, i: int, pressed: bool) -> void:
	var r := Rect2(Vector2(4, 4), ci.size - Vector2(8, 12))
	if pressed:
		r.position.y += 3
	var id := draft[i]
	var locked := _rule.locked_at(i) != &""
	# Vinyl pocket: translucent shade + white top lip.
	StickerPainter.rounded(ci, r, Color(Palette.KRAFT_SHADE, 0.55), 18)
	ci.draw_line(r.position + Vector2(14, 6), Vector2(r.end.x - 14, r.position.y + 6), Color(Palette.STICKER_WHITE, 0.9), 3.0, true)
	if i == selected_slot and id == TeamRules.EMPTY_SLOT:
		StickerPainter.dashed_rect(ci, r.grow(-6), Palette.INK, 3.0, 9.0)
	if _flash_slot == i and _flash_t > 0.0:
		StickerPainter.rounded(ci, r.grow(2), Color(Palette.STICKER_WHITE, _flash_t * 1.6), 20)
	if id == TeamRules.EMPTY_SLOT:
		StickerPainter.dashed_rect(ci, r.grow(-16), Color(Palette.INK, 0.35), 2.0, 8.0)
		StickerPainter.label(ci, r.get_center(), tr("UI_TEAM_SLOT_EMPTY"), app.font, 24, Palette.INK_LIGHT, 0)
		return
	var look := app.visuals.look(id)
	StickerPainter.draw_face(ci, r.get_center() + Vector2(0, -14), 76.0, look, StickerPainter.Expr.ACTIVE if _flash_slot == i and _flash_t > 0.0 else StickerPainter.Expr.NORMAL, 1.0)
	StickerPainter.label(ci, Vector2(r.get_center().x, r.end.y - 22), tr(look[CrewVisuals.K_NAME_KEY]), app.font, 26, Palette.INK, 6)
	StickerPainter.badge(ci, r.position + Vector2(22, 22), 30.0, str(i + 1), app.font)
	if locked:
		UiKit.padlock(ci, Vector2(r.end.x - 26, r.position.y + 28), 30.0)
	if not TeamRules.guests(draft, _rule, _owned).is_empty() and TeamRules.guests(draft, _rule, _owned).has(id):
		# Guest: masking-tape strip + ink word (rule 7).
		var tape := Rect2(Vector2(r.get_center().x - 46, r.position.y - 4), Vector2(92, 26))
		StickerPainter.rounded(ci, tape, Color(Palette.KRAFT_SHADE, 0.95), 3)
		StickerPainter.label(ci, tape.get_center(), tr("UI_TEAM_GUEST"), app.font, 18, Palette.INK, 0)


func _paint_card(ci: PaintButton, def: CrewDef, pressed: bool) -> void:
	var r := Rect2(Vector2(4, 4), ci.size - Vector2(8, 12))
	if pressed:
		r.position.y += 3
	var look := app.visuals.look(def.id)
	var owned := _owned.is_owned(def.id)
	var banned := _rule.banned.has(def.id)
	var in_team := draft.has(def.id)
	UiKit.sticker_rect(ci, r, Palette.STICKER_WHITE if owned else Color(Palette.KRAFT_SHADE, 0.6), 18, 0.0 if pressed else 5.0)
	# Crew-colour edge band (colour = crew name tag; pattern/silhouette are the backups).
	StickerPainter.rounded(ci, Rect2(r.position + Vector2(4, 4), Vector2(10, r.size.y - 8)), look[CrewVisuals.K_BASE] if owned else Palette.GREY_TONE, 4)
	var face_c := r.position + Vector2(60, 58)
	if owned:
		StickerPainter.draw_face(ci, face_c, 60.0, look, StickerPainter.Expr.SLEEPY if banned else StickerPainter.Expr.NORMAL, 1.0, banned)
	else:
		StickerPainter.draw_face(ci, face_c, 60.0, look, StickerPainter.Expr.NORMAL, 0.55, true)
	ci.draw_string(app.font, r.position + Vector2(108, 44), tr(look[CrewVisuals.K_NAME_KEY]), HORIZONTAL_ALIGNMENT_LEFT, 120, 28, Palette.INK)
	ci.draw_string(app.font, r.position + Vector2(108, 76), tr(def.ability_name_key), HORIZONTAL_ALIGNMENT_LEFT, 128, 19, Palette.INK_LIGHT)
	CrewCardPainter.diagram(ci, Rect2(Vector2(r.end.x - 86, r.position.y + 14), Vector2(72, 72)), def, look)
	if owned:
		CrewCardPainter.shapes(ci, r.position + Vector2(22, 100), 40.0, 9.0, def, look, app.font, 15)
	else:
		ci.draw_string(app.font, r.position + Vector2(22, 136), tr("UI_TEAM_NOT_OWNED"), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36, 20, Palette.INK_LIGHT)
	if banned:
		ci.draw_string(app.font, r.position + Vector2(108, 98), tr("UI_TEAM_BANNED"), HORIZONTAL_ALIGNMENT_LEFT, 140, 16, Palette.INK)
	if in_team:
		var at := draft.find(def.id)
		var rim := StyleBoxFlat.new()
		rim.draw_center = false
		rim.border_color = Palette.INK
		rim.set_border_width_all(4)
		rim.set_corner_radius_all(16)
		ci.draw_style_box(rim, r.grow(-1))
		StickerPainter.badge(ci, r.position + Vector2(18, 18), 30.0, str(at + 1), app.font)
