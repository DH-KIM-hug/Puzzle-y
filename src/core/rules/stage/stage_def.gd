## One stage (design/gdd/stage-goals.md rule 1, D2): a logic-free data resource.
## The initial board is a text grid ([member board_rows]) whose characters map to
## cell specs through [member cell_legend]. [StageLoader] validates it (rule 2)
## and builds the [BoardState]; [GoalTracker] counts its goals from events.
## [codeblock]
## var stage: StageDef = load("res://assets/data/stages/stage_1_3.tres")
## var loaded := StageLoader.load_stage(stage, env)
## if loaded.is_valid(): flow.start(stage, team)
## [/codeblock]
##
## [b]Cell legend schema[/b] (resolves stage-goals Q8 for [code].tres[/code]: a plain
## Dictionary, validated with TYPE checks at load — ADR-0001 int enforcement):
## [code]"g": {"type": &"TILE", "crew_id": &"gomgom", "is_face": false,
## "origin": &"PIECE", "modifiers": [{"kind": &"ice", "layers": 2}]}[/code].
## Missing keys default to TILE / no crew / not a face / PIECE / no modifiers.
## [code]"."[/code] is always EMPTY and may not be redefined.
class_name StageDef
extends Resource

## Legend spec keys.
const L_TYPE := &"type"
const L_CREW := &"crew_id"
const L_FACE := &"is_face"
const L_ORIGIN := &"origin"
const L_MODIFIERS := &"modifiers"
const M_KIND := &"kind"
const M_LAYERS := &"layers"
## Origin names.
const ORIGIN_PIECE := &"PIECE"
const ORIGIN_EGG := &"EGG"
## [member piece_limit] value of an unlimited (free-play) stage.
const UNLIMITED := -1
## [member stage_seed] value meaning "not set".
const NO_SEED := -1

## Stable id ("1-1"), save key.
@export var id: StringName = &""
## Data migration version.
@export var schema_version: int = 1
## Localisation key of the stage name.
@export var name_key: String = ""
## Start board text, one string per row (board_height rows × board_width chars).
@export var board_rows: PackedStringArray = PackedStringArray(["........", "........", "........", "........", "........", "........", "........", "........"])
## Character → cell spec (see class docs). "." is reserved for EMPTY.
@export var cell_legend: Dictionary = {}
## Target-cell overlay coordinates (row, col) for CLEAR_CELLS (rule 5).
@export var target_cells: Array[Vector2i] = []
## 1..max_goals_per_stage goals, all required (rule 8). Empty only for free play.
@export var goals: Array[GoalDef] = []
## Pieces supplied this round (3–40), or [constant UNLIMITED] for free play.
@export var piece_limit: int = 0
## [S2, S3] star thresholds at the reference scale (F7). Empty only for free play.
@export var star_points: PackedInt32Array = PackedInt32Array()
## Team rule (team-composition rule 5). Null = 3 crews, no restriction.
@export var team_rule: TeamRule
## Display-only recommendation.
@export var recommended_team: Array[StringName] = []
## Round seed for FIXED mode (0 – 2^31-1); [constant NO_SEED] = not set.
@export var stage_seed: int = NO_SEED
## Tray seed policy (tray-supply rule 18).
@export var tray_seed_mode: TrayRules.SeedMode = TrayRules.SeedMode.FIXED
## PER_ATTEMPT base seed (tray-supply F3).
@export var stage_base_seed: int = 0
## Hand-written tray order (tray-supply rule 19; same spec format as [member TrayRules.tray_script]).
@export var tray_script: Array = []
## What follows the script (tray-supply rule 20).
@export var after_script: TrayRules.AfterScript = TrayRules.AfterScript.GENERATE
## Minimal rescue (tray-supply rule 13).
@export var rescue_enabled: bool = true
## Faceless pieces allowed (board-rules rule 5).
@export var allow_faceless_pieces: bool = false
## Generated faceless share, per mille (GDD `faceless_share` 0.0–1.0 × 1000 — integer
## rules core, ADR-0001).
@export_range(0, 1000) var faceless_share_permille: int = 0
## Preview information level (chain-preview rule 17).
@export var preview_detail: PreviewSettings.Detail = PreviewSettings.Detail.FULL
## Show the predicted total line (chain-preview rule 13).
@export var show_predicted_score: bool = false
## Preview goal markers (rule 14).
@export var goal_markers: bool = true


## True for a free-play stage (no goals, unlimited pieces — round-flow rule 24).
func is_free_play() -> bool:
	return piece_limit == UNLIMITED


## Effective team rule (default 3, no locks/bans when unset).
func effective_team_rule() -> TeamRule:
	return team_rule if team_rule != null else TeamRule.make()


## Tray configuration for this stage: global [param base] values (tray_size,
## crew_bag_copies, alert line) + this stage's tray fields.
func tray_rules(base: TrayRules) -> TrayRules:
	var t := TrayRules.new()
	if base != null:
		t.tray_size = base.tray_size
		t.crew_bag_copies = base.crew_bag_copies
		t.rescue_rate_alert_permille = base.rescue_rate_alert_permille
		t.extra_shapes = base.extra_shapes.duplicate()
	t.rescue_enabled = rescue_enabled
	t.allow_faceless_pieces = allow_faceless_pieces
	t.faceless_share_permille = faceless_share_permille
	t.tray_seed_mode = tray_seed_mode
	t.tray_script = tray_script.duplicate(true)
	t.after_script = after_script
	t.team_fixed = effective_team_rule().is_fixed()
	return t


## Stage seed for attempt [param attempt_index] (round-flow rule 5.1, tray-supply F3).
func seed_for_attempt(attempt_index: int) -> int:
	if tray_seed_mode == TrayRules.SeedMode.FIXED:
		return stage_seed
	return TraySupplyRules.stage_seed_for(TrayRules.SeedMode.PER_ATTEMPT, stage_base_seed, attempt_index)


## Preview settings for this stage (scored by [param scoring]).
func preview_settings(scoring: ScoringRules) -> PreviewSettings:
	var s := PreviewSettings.new()
	s.show_predicted_score = show_predicted_score
	s.preview_detail = preview_detail
	s.scoring_rules = scoring
	return s


## The free-play stage of the T0 greybox (round-flow rule 24 (a)): empty
## [param width]×[param height] board, no goals, unlimited pieces, PER_ATTEMPT seed.
static func free_play(base_seed: int, width: int = 8, height: int = 8) -> StageDef:
	var s := StageDef.new()
	s.id = &"free_play"
	var rows := PackedStringArray()
	for r: int in height:
		rows.append(".".repeat(width))
	s.board_rows = rows
	s.piece_limit = UNLIMITED
	s.tray_seed_mode = TrayRules.SeedMode.PER_ATTEMPT
	s.stage_base_seed = base_seed
	s.team_rule = TeamRule.make()
	return s
