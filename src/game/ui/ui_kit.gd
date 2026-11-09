## Sticker-book UI helpers for the meta screens and play overlays (art-bible §3
## "UI 형태 문법", §4 UI palette): buttons are rounded stickers with a white
## cut-out margin and a ground shadow that drops to 0 when pressed; the primary
## action is ink-brown with sticker-white text; panels are paper cards. Touch
## targets ≥ 64 px at 1080 width (≈ 43 px on the 720 canvas — we use ≥ 64 px).
## [codeblock]
## var b := UiKit.button("한 판 더", UiKit.Kind.PRIMARY, Vector2(400, 100), 36)
## UiKit.star(self, Vector2(40, 40), 24.0, true)
## [/codeblock]
class_name UiKit
extends RefCounted

## Button kinds.
enum Kind { PRIMARY, SECONDARY }

## Minimum touch target on the 720-wide canvas.
const MIN_TOUCH := 64.0


## A sticker button. [param kind] PRIMARY = ink, SECONDARY = sticker white.
static func button(text: String, kind: Kind, min_size: Vector2, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(maxf(min_size.x, MIN_TOUCH), maxf(min_size.y, MIN_TOUCH))
	b.add_theme_font_size_override(&"font_size", font_size)
	b.focus_mode = Control.FOCUS_NONE
	var bg := Palette.INK if kind == Kind.PRIMARY else Palette.STICKER_WHITE
	var fg := Palette.STICKER_WHITE if kind == Kind.PRIMARY else Palette.INK
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg if state != &"disabled" else Palette.GREY_TONE
		sb.set_corner_radius_all(int(minf(b.custom_minimum_size.y * 0.5, 40.0)))
		sb.border_color = Palette.STICKER_WHITE if kind == Kind.PRIMARY else Palette.KRAFT_SHADE
		sb.set_border_width_all(5 if kind == Kind.PRIMARY else 3)
		sb.shadow_color = Color(Palette.INK, 0.35)
		sb.shadow_size = 1
		sb.shadow_offset = Vector2(0, 0 if state == &"pressed" or state == &"disabled" else 6)
		sb.set_content_margin_all(10)
		sb.anti_aliasing = true
		b.add_theme_stylebox_override(state, sb)
	for c: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_hover_pressed_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override(&"font_disabled_color", Palette.STICKER_WHITE)
	return b


## A label with the ink colour.
static func label(text: String, font_size: int, color: Color = Palette.INK, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Paper card style (sticker white, ink ground shadow).
static func card_style(radius: int = 24, margin: float = 24.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.STICKER_WHITE
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(Palette.INK, 0.3)
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(0, 6)
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = true
	return sb


## Sticker card behind [param r] (shadow + white margin + fill).
static func sticker_rect(ci: CanvasItem, r: Rect2, fill: Color, radius: float, shadow: float = 5.0) -> void:
	StickerPainter.rounded(ci, Rect2(r.position + Vector2(shadow * 0.4, shadow), r.size), Color(Palette.INK, 0.28), radius)
	StickerPainter.rounded(ci, r, Palette.STICKER_WHITE, radius)
	StickerPainter.rounded(ci, r.grow(-4), fill, maxf(radius - 4, 2))


## A five-point star sticker. Filled = gold with ink rim (reward colour, art-bible
## §4); empty = kraft-shade hole with a dashed-looking ink rim.
static func star(ci: CanvasItem, c: Vector2, r: float, filled: bool) -> void:
	var pts := PackedVector2Array()
	for i: int in 10:
		var a := -PI * 0.5 + PI * i / 5.0
		var rr := r if i % 2 == 0 else r * 0.48
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	var rim := pts.duplicate()
	rim.append(pts[0])
	if filled:
		var sh := PackedVector2Array()
		for p: Vector2 in pts:
			sh.append(p + Vector2(r * 0.06, r * 0.12))
		ci.draw_colored_polygon(sh, Color(Palette.INK, 0.3))
		ci.draw_polyline(rim, Palette.STICKER_WHITE, maxf(3.0, r * 0.22), true)
		ci.draw_colored_polygon(pts, Palette.GOLD)
		ci.draw_polyline(rim, Palette.INK, maxf(1.5, r * 0.09), true)
	else:
		ci.draw_colored_polygon(pts, Color(Palette.KRAFT_SHADE, 0.8))
		ci.draw_polyline(rim, Color(Palette.INK, 0.45), maxf(1.2, r * 0.07), true)


## Padlock glyph (locked slots / stages), ink.
static func padlock(ci: CanvasItem, c: Vector2, size: float) -> void:
	var body := Rect2(c + Vector2(-size * 0.42, -size * 0.05), Vector2(size * 0.84, size * 0.62))
	ci.draw_arc(c + Vector2(0, -size * 0.08), size * 0.27, PI, TAU, 12, Palette.INK, maxf(2.0, size * 0.12), true)
	StickerPainter.rounded(ci, body, Palette.INK, size * 0.12)
	ci.draw_circle(body.get_center() + Vector2(0, -size * 0.04), size * 0.08, Palette.STICKER_WHITE, true, -1.0, true)


## Ink check mark in a white circle (goal met).
static func check(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r, Palette.STICKER_WHITE, true, -1.0, true)
	ci.draw_circle(c, r * 0.82, Palette.INK, true, -1.0, true)
	ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.4, 0), c + Vector2(-r * 0.1, r * 0.32), c + Vector2(r * 0.45, -r * 0.35)]),
			Palette.STICKER_WHITE, maxf(2.0, r * 0.2), true)


## Goal summary line for a stage (team-select / stage cards), localised.
static func goal_summary(ci: Object, stage: StageDef) -> String:
	var parts := PackedStringArray()
	for g: GoalDef in stage.goals:
		match g.type:
			GoalDef.Type.SCORE:
				parts.append(ci.tr("UI_GOAL_SCORE_SHORT") % g.required)
			GoalDef.Type.CLEAR_CELLS:
				parts.append(ci.tr("UI_GOAL_CELLS_SHORT") % g.required)
			GoalDef.Type.CLEAR_OBSTACLES:
				parts.append(ci.tr("UI_GOAL_ICE_SHORT") % g.required)
			GoalDef.Type.CHAIN:
				parts.append(ci.tr("UI_GOAL_CHAIN_SHORT") % [g.depth, g.required])
	return " · ".join(parts)
