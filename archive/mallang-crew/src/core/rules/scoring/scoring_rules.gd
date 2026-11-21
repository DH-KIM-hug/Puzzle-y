## Scoring tuning knobs (design/gdd/scoring.md Tuning Knobs). Loaded from
## [code]assets/data/rules/scoring_rules.tres[/code]; integer percentages only.
class_name ScoringRules
extends Resource

## Points per placed cell (F1). Safe range 0–5.
@export var place_points_per_cell: int = 1
## Base points per cleared cell (F4). Safe range 1–50.
@export var cell_points: int = 10
## Depth multiplier step per wave, percent (F2). Safe range 25–100.
@export var depth_step_pct: int = 50
## Depth multiplier cap, percent (F2). Safe range 200–600.
@export var depth_mult_max_pct: int = 400
## Extra percent per line beyond the first (F3). Safe range 0–150.
@export var multi_line_step_pct: int = 100
## Base points per face activation (F4). Safe range 0–100.
@export var activation_points_base: int = 20
## Points per fizzled face (F5). Safe range 0–100.
@export var fizzle_points: int = 0


## Load-time validation (scoring Edge Cases "튜닝 값이 범위를 벗어나면"): hard
## limits only — cell_points >= 1, depth_step_pct >= 0, depth_mult_max_pct >= 100,
## no negative points. Safe ranges are tuning guidance, not load errors.
## Messages name the knob and the value.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if cell_points < 1:
		errors.append("ScoringRules.cell_points must be >= 1 (got %d)" % cell_points)
	if depth_step_pct < 0:
		errors.append("ScoringRules.depth_step_pct must be >= 0 (got %d)" % depth_step_pct)
	if depth_mult_max_pct < 100:
		errors.append("ScoringRules.depth_mult_max_pct must be >= 100 (got %d)" % depth_mult_max_pct)
	if place_points_per_cell < 0:
		errors.append("ScoringRules.place_points_per_cell must be >= 0 (got %d)" % place_points_per_cell)
	if multi_line_step_pct < 0:
		errors.append("ScoringRules.multi_line_step_pct must be >= 0 (got %d)" % multi_line_step_pct)
	if activation_points_base < 0:
		errors.append("ScoringRules.activation_points_base must be >= 0 (got %d)" % activation_points_base)
	if fizzle_points < 0:
		errors.append("ScoringRules.fizzle_points must be >= 0 (got %d)" % fizzle_points)
	return errors
