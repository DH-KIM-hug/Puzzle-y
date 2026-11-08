## Chain preview renderer (design/gdd/chain-preview.md rules 10, 18–23, F1, F4).
## Draws a [PreviewModel] only — every element comes from the model, which
## comes from resolver events (rules 3–4). Ink dashes, never crew colour (rule 19);
## no score unless the model carries one (rule 13).
## [codeblock]
## view.show_model(model)        # same frame as the anchor change (rule 7)
## view.draw_outlines(layer)     # below the ghost
## view.draw_top(layer)          # eggs + badges, above the dragged piece
## view.draw_banner(layer)       # banner band
## [/codeblock]
class_name PreviewView
extends RefCounted

## Displayed model (null = nothing shown).
var model: PreviewModel
## Time since the model was shown (F4 t).
var t: float = 0.0
## Layout.
var layout: BoardLayout
## Tuning (badge size, pulse).
var tuning: PresentationTuning
## Font.
var font: Font


## Shows [param m] (replaces the previous one in the same frame, rule 10).
func show_model(m: PreviewModel) -> void:
	model = m
	t = 0.0


## Clears immediately (rule 11).
func clear() -> void:
	model = null


## Advances the pulse clock.
func tick(delta: float) -> void:
	if model != null:
		t += delta


## F4 lift shadow of wave [param k].
func lift_px(k: int) -> float:
	var amp := 0.0 if tuning.reduced_motion else tuning.lift_amp_px
	var period := tuning.wave_pulse_period_s
	var ph := (t - k * tuning.wave_pulse_stagger_s) / period
	return tuning.lift_base_px + amp * 0.5 * (1.0 - cos(TAU * ph))


## Outlines of the cells that will clear (layer below the ghost). A cell cleared in
## two or more waves (egg refill) gets one ring per wave.
func draw_outlines(ci: CanvasItem) -> void:
	if model == null:
		return
	var s := layout.s
	for cell: Vector2i in model.clear_waves:
		var waves: Array = model.clear_waves[cell]
		var k: int = waves[0]
		var lift := lift_px(k)
		var r := layout.cell_rect(cell)
		# "들썩" shadow band under the cell's bottom edge (never over the sticker),
		# then an ink dashed outline raised by the lift.
		var band := Rect2(Vector2(r.position.x + 6, r.end.y - 3.0), Vector2(r.size.x - 12, lift + 2.0))
		StickerPainter.rounded(ci, band, Color(Palette.INK, 0.35), 3.0)
		var raised := Rect2(r.position - Vector2(0, lift), r.size).grow(-4)
		StickerPainter.dashed_rect(ci, raised, Palette.INK, 3.0, 7.0)
		for extra: int in range(1, waves.size()):
			StickerPainter.dashed_rect(ci, raised.grow(-6.0 * extra), Palette.INK, 2.0, 5.0)
	for cell: Vector2i in model.modified:
		var r := layout.cell_rect(cell)
		ci.draw_line(r.position + Vector2(s * 0.3, s * 0.2), r.get_center(), Palette.INK, 2.0, true)


## Predicted eggs and badges (above the dragged piece, rule 18).
func draw_top(ci: CanvasItem) -> void:
	if model == null:
		return
	var s := layout.s
	for cell: Vector2i in model.eggs:
		var c := layout.cell_rect(cell).get_center()
		var r := Vector2(s * 0.26, s * 0.32)
		if model.clear_waves.has(cell):
			# Egg refills a cell that clears first: draw it small in the bottom-left
			# corner so the sticker (often a face) and its top-right badge stay visible.
			c += Vector2(-0.24, 0.2) * s
			r *= 0.55
		StickerPainter.ellipse(ci, c, r, Color(Palette.FACE_CREAM, 0.95))
		StickerPainter.ellipse_outline(ci, c, r, Palette.INK, 2.5)
	var d := badge_diameter()
	for b: Dictionary in model.badges:
		var cell: Vector2i = b[PreviewModel.K_CELL]
		var text := ""
		match int(b[PreviewModel.K_KIND]):
			PreviewModel.BadgeKind.STAGE:
				text = str(int(b[PreviewModel.K_STAGE]))
			PreviewModel.BadgeKind.SLEEP:
				text = "z"
			PreviewModel.BadgeKind.FROZEN:
				text = "*"
			_:
				text = "…"
		StickerPainter.badge(ci, badge_center(cell, d), d, text, font)


## Banner in the banner band (rule 23, F3 wording). Score line only when shown (rule 13).
func draw_banner(ci: CanvasItem) -> void:
	if model == null:
		return
	var text := ""
	match model.banner:
		PreviewModel.Banner.ABILITY:
			text = ci.tr("UI_PREVIEW_ABILITY")
		PreviewModel.Banner.CHAIN:
			text = ci.tr("UI_PREVIEW_CHAIN") % model.banner_n
		PreviewModel.Banner.CHAIN_MAX:
			text = ci.tr("UI_PREVIEW_CHAIN_MAX") % model.banner_n
	if model.has_predicted_score:
		text += ("  " if text != "" else "") + "+%d" % model.predicted_score
	if text == "":
		return
	var c := layout.banner_rect.get_center()
	var size := 34
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var r := Rect2(c - Vector2(sz.x * 0.5 + 22, 32), Vector2(sz.x + 44, 64))
	StickerPainter.rounded(ci, Rect2(r.position + Vector2(2, 5), r.size), Color(Palette.INK, 0.3), 24)
	StickerPainter.rounded(ci, r.grow(4), Palette.STICKER_WHITE, 28)
	StickerPainter.rounded(ci, r, Palette.INK, 24)
	StickerPainter.label(ci, c, text, font, size, Palette.STICKER_WHITE, 0)


## F1 badge diameter.
func badge_diameter() -> float:
	return maxf(tuning.badge_scale * layout.s, tuning.badge_min_px * layout.canvas.x / 1080.0)


## F1 badge centre: cell centre + (0.32s, −0.32s), clamped inside the cell.
func badge_center(cell: Vector2i, d: float) -> Vector2:
	var r := layout.cell_rect(cell)
	var c := r.get_center() + Vector2(0.32, -0.32) * layout.s
	var inner := r.grow(-d * 0.5)
	return Vector2(clampf(c.x, inner.position.x, inner.end.x), clampf(c.y, inner.position.y, inner.end.y))
