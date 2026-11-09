## Global stage values (design/gdd/stage-goals.md section H). Loaded from
## [code]assets/data/rules/stage_rules.tres[/code]; read-only at runtime.
class_name StageRules
extends Resource

## Bonus per unused piece on clear, reference scale (F5). Safe range 0–300.
@export var leftover_piece_points: int = 100
## Reference cell_points the stage data is written at (F1). Constant 10.
@export var cell_points_ref: int = 10
## Goals per stage (rule 2). Safe range 1–3.
@export var max_goals_per_stage: int = 2
## Piece limit range (rule 1); -1 = unlimited, free-play only.
@export var piece_limit_min: int = 3
## Upper piece limit (rule 1).
@export var piece_limit_max: int = 40
## Typo guard for SCORE goals and star points (rule 2).
@export var score_target_max: int = 20000
