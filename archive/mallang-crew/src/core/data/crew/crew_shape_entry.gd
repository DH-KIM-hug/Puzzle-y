## One shape in a crew's pool (crew-definition rule 2). Data only.
class_name CrewShapeEntry
extends Resource

## Catalog shape.
@export var shape: PieceShape
## Relative draw weight inside the crew (>= 1, F1).
@export var weight: int = 1
## Fixed face cell index, or -1 = chosen by the tray (MVP: always -1).
@export var face_cell: int = -1
