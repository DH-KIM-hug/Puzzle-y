## Obstacle data values (design/gdd/obstacles.md section F). Loaded from
## [code]assets/data/rules/obstacle_rules.tres[/code]; read-only at runtime.
## [codeblock]
## var cfg: ObstacleConfig = load("res://assets/data/rules/obstacle_rules.tres")
## var errors := ObstacleRules.validate_obstacles(board, cfg, registry_ids)
## [/codeblock]
class_name ObstacleConfig
extends Resource

## Maximum ice layers on a plain tile (safe range 1–3).
@export var ice_max_layers: int = 2
## Ice layers on a frozen face (MVP fixed 1).
@export var frozen_face_layers: int = 1
## Stones allowed per row / column (safe range 0 – board_width - 2). V1 also caps at len - 1.
@export var max_stones_per_line: int = 3


## Validation errors for the config itself (empty = valid).
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if ice_max_layers < 1:
		errors.append("ObstacleConfig.ice_max_layers must be >= 1 (%d)" % ice_max_layers)
	if frozen_face_layers < 1 or frozen_face_layers > ice_max_layers:
		errors.append("ObstacleConfig.frozen_face_layers must be in 1..ice_max_layers (%d)" % frozen_face_layers)
	if max_stones_per_line < 0:
		errors.append("ObstacleConfig.max_stones_per_line must be >= 0 (%d)" % max_stones_per_line)
	return errors
