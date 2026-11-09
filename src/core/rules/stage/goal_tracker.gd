## Goal progress for one stage attempt (design/gdd/stage-goals.md rules 3–8,
## 14, F3, F4). Progress is counted ONLY from [ChainResult] events (ADR-0001
## Decision 3) — never by re-reading the board or re-running the resolver. The
## one exception is the start board, read once in [method start] for the ice
## ledger (rule 3). Deterministic and integer-only; progress never decreases.
## [codeblock]
## var goals := GoalTracker.start(stage, start_board, scoring.cell_points, stage_rules.cell_points_ref)
## goals.apply(commit.result, commit.breakdown, tally.stage_score)
## if goals.is_met(): ...
## var markers := goals.preview(preview_model.result)   # never mutates
## [/codeblock]
##
## Spec ambiguity resolved: [method preview] cannot know the score without a
## predicted total, so SCORE goals count as met in [member GoalPreview.completes_stage]
## only when the caller passes [param predicted_stage_score] (shown only with
## [code]show_predicted_score[/code] — AC-SG18).
class_name GoalTracker
extends RefCounted

## Snapshot entry keys.
const S_TYPE := &"type"
const S_PROGRESS := &"progress"
const S_REQUIRED := &"required"
const S_MET := &"met"

## Goal definitions (read-only).
var goals: Array[GoalDef] = []
## Target cells T (Vector2i → true).
var targets: Dictionary = {}
## Cleared target cells ⊆ T (Vector2i → true).
var done: Dictionary = {}
## Obstacle ledger from the start board: Vector2i → {modifier id → layers}.
var ledger: Dictionary = {}
## Freed obstacle cells per CLEAR_OBSTACLES goal index (F3c).
var obstacles_freed: Dictionary = {}
## Placements whose chain depth met each CHAIN goal (goal index → count).
var chain_hits: Dictionary = {}
## Latest committed stage score (F3a).
var stage_score: int = 0
## Scoring cell_points (F1).
var cell_points: int = 10
## Reference scale (F1).
var cell_points_ref: int = 10


## Rule 3 start: zero progress, ice ledger from [param start_board].
static func start(stage: StageDef, start_board: BoardState, p_cell_points: int, p_cell_points_ref: int) -> GoalTracker:
	var t := GoalTracker.new()
	t.goals = stage.goals.duplicate()
	for c: Vector2i in stage.target_cells:
		t.targets[c] = true
	for idx: int in start_board.modifiers:
		var mods: PackedInt32Array = start_board.modifiers[idx]
		var entry := {}
		var i := 0
		while i + 1 < mods.size():
			entry[mods[i]] = mods[i + 1]
			i += 2
		if not entry.is_empty():
			t.ledger[start_board.cell_of(idx)] = entry
	for g: int in t.goals.size():
		t.obstacles_freed[g] = 0
		t.chain_hits[g] = 0
	t.cell_points = p_cell_points
	t.cell_points_ref = p_cell_points_ref
	return t


## Independent copy.
func copy() -> GoalTracker:
	var t := GoalTracker.new()
	t.goals = goals
	t.targets = targets
	t.done = done.duplicate()
	t.ledger = ledger.duplicate(true)
	t.obstacles_freed = obstacles_freed.duplicate()
	t.chain_hits = chain_hits.duplicate()
	t.stage_score = stage_score
	t.cell_points = cell_points
	t.cell_points_ref = cell_points_ref
	return t


## Rule 3 apply: one committed placement. [param breakdown] is accepted for the
## contract (round-flow 7.6) but no MVP goal reads it.
func apply(result: ChainResult, _breakdown: ScoreBreakdown, p_stage_score: int) -> void:
	if result == null or not result.is_valid():
		return
	stage_score = maxi(stage_score, p_stage_score)
	for cell: Vector2i in _cleared_targets(result):
		done[cell] = true
	for e: ChainEvent in result.events_of(ChainEvent.Type.CELL_MODIFIED):
		var cell: Vector2i = e.data[ChainEvent.K_CELL]
		var before: PackedInt32Array = e.data[ChainEvent.K_MODIFIERS_BEFORE]
		var after: PackedInt32Array = e.data[ChainEvent.K_MODIFIERS_AFTER]
		for g: int in goals.size():
			if goals[g].type == GoalDef.Type.CLEAR_OBSTACLES and _frees_key(goals[g], before, after):
				obstacles_freed[g] = int(obstacles_freed[g]) + 1
		ledger[cell] = _mods_dict(after)
	var depth := int(result.summary.get(ChainEvent.K_CHAIN_DEPTH, 0))
	for g: int in goals.size():
		if goals[g].type == GoalDef.Type.CHAIN and depth >= goals[g].depth:
			chain_hits[g] = int(chain_hits[g]) + 1


## F3 progress of goal [param g].
func progress(g: int) -> int:
	match goals[g].type:
		GoalDef.Type.SCORE:
			return stage_score
		GoalDef.Type.CLEAR_CELLS:
			return done.size()
		GoalDef.Type.CLEAR_OBSTACLES:
			return int(obstacles_freed[g])
		GoalDef.Type.CHAIN:
			return int(chain_hits[g])
	return 0


## F4 effective requirement of goal [param g] (SCORE converted by F1).
func required(g: int) -> int:
	if goals[g].type == GoalDef.Type.SCORE:
		return StageScoring.pts_eff(goals[g].required, cell_points, cell_points_ref)
	return goals[g].required


## True when goal [param g] is met.
func goal_met(g: int) -> bool:
	return progress(g) >= required(g)


## F4: every goal met (false when there are no goals — free play).
func is_met() -> bool:
	if goals.is_empty():
		return false
	for g: int in goals.size():
		if not goal_met(g):
			return false
	return true


## Rule 9.2: out of pieces (pieces_left = 0) with goals unmet. Unlimited → false.
func pieces_out(pieces_left: int) -> bool:
	return pieces_left == 0 and not is_met()


## Per-goal progress for HUD / result screens.
func snapshot() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g: int in goals.size():
		out.append({S_TYPE: goals[g].type, S_PROGRESS: progress(g), S_REQUIRED: required(g), S_MET: goal_met(g)})
	return out


## Rule 14: markers for a hypothetical [param result]; same counting code as
## [method apply], tracker state untouched. [param predicted_stage_score] = -1
## when no predicted total is shown.
func preview(result: ChainResult, predicted_stage_score: int = -1) -> GoalPreview:
	var p := GoalPreview.new()
	if result == null or not result.is_valid():
		return p
	for cell: Vector2i in _cleared_targets(result):
		if not done.has(cell) and not p.target_cells_hit.has(cell):
			p.target_cells_hit.append(cell)
	for e: ChainEvent in result.events_of(ChainEvent.Type.CELL_MODIFIED):
		for g: int in goals.size():
			if goals[g].type == GoalDef.Type.CLEAR_OBSTACLES and _frees_key(goals[g], e.data[ChainEvent.K_MODIFIERS_BEFORE], e.data[ChainEvent.K_MODIFIERS_AFTER]):
				var cell: Vector2i = e.data[ChainEvent.K_CELL]
				if not p.obstacles_freed.has(cell):
					p.obstacles_freed.append(cell)
	var depth := int(result.summary.get(ChainEvent.K_CHAIN_DEPTH, 0))
	for g: int in goals.size():
		if goals[g].type == GoalDef.Type.CHAIN and depth >= goals[g].depth and not goal_met(g):
			p.chain_goal_hit.append(g)
	var sim := copy()
	sim.apply(result, null, predicted_stage_score if predicted_stage_score >= 0 else stage_score)
	p.completes_stage = not is_met() and sim.is_met()
	return p


func _cleared_targets(result: ChainResult) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if targets.is_empty():
		return out
	for e: ChainEvent in result.events_of(ChainEvent.Type.CELLS_CLEARED):
		for c: Dictionary in e.data[ChainEvent.K_CELLS]:
			var cell := Vector2i(c[ChainEvent.K_R], c[ChainEvent.K_C])
			if targets.has(cell):
				out.append(cell)
	return out


static func _frees_key(goal: GoalDef, before: PackedInt32Array, after: PackedInt32Array) -> bool:
	for key: StringName in goal.keys:
		var mod_id: int = ObstacleRules.MODIFIER_IDS.get(key, -1)
		if mod_id >= 0 and ObstacleRules.has_modifier(before, mod_id) and not ObstacleRules.has_modifier(after, mod_id):
			return true
	return false


static func _mods_dict(mods: PackedInt32Array) -> Dictionary:
	var d := {}
	var i := 0
	while i + 1 < mods.size():
		d[mods[i]] = mods[i + 1]
		i += 2
	return d
