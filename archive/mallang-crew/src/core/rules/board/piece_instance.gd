## A tray piece: shape + crew + face cell (board-rules rule 5).
## [code]face_index = -1[/code] means "no face" (tutorial-only faceless piece).
class_name PieceInstance
extends RefCounted

## Sentinel for "no face" / "no crew".
const NO_FACE := -1

## The shape (read-only data).
var shape: PieceShape
## Owning crew; [code]&""[/code] = null (faceless piece).
var crew_id: StringName = &""
## Index into [member PieceShape.offsets] of the face cell, or [constant NO_FACE].
var face_index: int = NO_FACE
## Stable id for preview caching (chain-preview cache key).
var instance_id: int = 0


## Creates a piece instance.
static func make(p_shape: PieceShape, p_crew_id: StringName, p_face_index: int, p_instance_id: int = 0) -> PieceInstance:
	var piece := PieceInstance.new()
	piece.shape = p_shape
	piece.crew_id = p_crew_id
	piece.face_index = p_face_index
	piece.instance_id = p_instance_id
	return piece


## True when the piece has a face cell.
func has_face() -> bool:
	return face_index != NO_FACE
