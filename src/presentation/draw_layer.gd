## A Node2D whose [code]_draw()[/code] delegates to [member painter]
## ([code](layer: CanvasItem) -> void[/code]). Lets one owner draw several
## z-ordered layers (chain-preview rule 18 layer order).
class_name DrawLayer
extends Node2D

## Draw callback.
var painter: Callable


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
