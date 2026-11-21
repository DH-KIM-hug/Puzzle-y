## A flat [Button] whose whole face is drawn by a callback — used for sticker
## tiles that need custom art (stage tiles, crew cards, team pockets) while
## keeping real Button input (touch emulation, pressed state, disabled).
## [codeblock]
## var b := PaintButton.make(Vector2(330, 150), func(ci: Control, pressed: bool) -> void: ...)
## b.pressed.connect(_on_tile)
## [/codeblock]
class_name PaintButton
extends Button

## painter(ci: PaintButton, pressed: bool) draws the face in local coordinates.
var painter: Callable


## A painted button of [param size] (≥ 64 px touch target).
static func make(p_size: Vector2, p_painter: Callable) -> PaintButton:
	var b := PaintButton.new()
	b.custom_minimum_size = Vector2(maxf(p_size.x, UiKit.MIN_TOUCH), maxf(p_size.y, UiKit.MIN_TOUCH))
	b.size = b.custom_minimum_size
	b.painter = p_painter
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	var empty := StyleBoxEmpty.new()
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled", &"hover_pressed"]:
		b.add_theme_stylebox_override(state, empty)
	return b


func _draw() -> void:
	if painter.is_valid():
		painter.call(self, get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED)
