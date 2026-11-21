## Chain preview display model (design/gdd/chain-preview.md rules 1–5, 13, 17, F3).
##
## [method build_preview_model] is a pure function of a [ChainResult]: every element
## comes from an event (rule 4 table) — nothing is judged here. [method preview] is
## the public preview entry point: it resolves on a copy of the stable board with
## the round flow's context and builds the model, so preview and commit share one
## resolver call shape (rule 1, ADR-0001 Decision 9).
## [codeblock]
## var ctx := round.context_for_next_placement()
## var model := PreviewModel.preview(round.board, piece, anchor, ctx, settings)
## [/codeblock]
class_name PreviewModel
extends RefCounted

## Badge kinds (rule 4): stage number, sleepy (DEPTH_CAP fizzle), frozen
## (SUPPRESSED fizzle), hidden "…" (rule 17 FIRST_STAGE_ONLY).
enum BadgeKind { STAGE, SLEEP, FROZEN, HIDDEN }
## Banner tiers (F3).
enum Banner { NONE, ABILITY, CHAIN, CHAIN_MAX }

const K_CELL := &"cell"
const K_KIND := &"kind"
const K_STAGE := &"stage"

## Source result (not part of the compared model).
var result: ChainResult
## Cell (Vector2i) → ascending waves in which it is cleared (outline + pulse
## phase). Usually one wave; two or more when an egg refills a cleared cell that a
## later wave clears again.
var clear_waves: Dictionary = {}
## Badges in event order: {cell, kind: BadgeKind, stage (0 unless STAGE)}.
var badges: Array[Dictionary] = []
## Predicted egg / wool cells in lay order.
var eggs: Array[Vector2i] = []
## Modified ("cracked") cells in event order.
var modified: Array[Vector2i] = []
## Obstacles (design/gdd/obstacles.md rule 14), all from [code]CELL_MODIFIED[/code]
## payloads — never a second prediction path. Ice cracks but stays ("금"), in event order.
var cracked: Array[Vector2i] = []
## Plain ice tiles freed from their last layer, in event order.
var freed: Array[Vector2i] = []
## Frozen faces that thaw ("녹음"), in event order. A thawed face that fires in the
## same chain also gets its STAGE badge from [code]FACE_ACTIVATED[/code].
var thawed: Array[Vector2i] = []
## Banner tier (F3).
var banner: Banner = Banner.NONE
## Banner number N (chain depth) for CHAIN / CHAIN_MAX, else 0.
var banner_n: int = 0
## True when the predicted total is shown (rule 13).
var has_predicted_score: bool = false
## Predicted placement total (valid when [member has_predicted_score]).
var predicted_score: int = 0
## The breakdown behind [member predicted_score] (null when not shown).
var breakdown: ScoreBreakdown


## Pure: model from [param res] under [param settings] (null = defaults).
## Scores only when [member PreviewSettings.show_predicted_score] (AC-P09).
static func build_preview_model(res: ChainResult, settings: PreviewSettings = null) -> PreviewModel:
	var cfg := settings if settings != null else PreviewSettings.new()
	var first_only := cfg.preview_detail == PreviewSettings.Detail.FIRST_STAGE_ONLY
	var m := PreviewModel.new()
	m.result = res
	if res == null or not res.is_valid():
		return m
	var depth := 0
	var cap := false
	for e: ChainEvent in res.events:
		match e.type:
			ChainEvent.Type.CELLS_CLEARED:
				if first_only and e.wave > 0:
					continue
				for c: Dictionary in e.data[ChainEvent.K_CELLS]:
					var cell := Vector2i(c[ChainEvent.K_R], c[ChainEvent.K_C])
					if not m.clear_waves.has(cell):
						m.clear_waves[cell] = []
					(m.clear_waves[cell] as Array).append(e.wave)
			ChainEvent.Type.FACE_ACTIVATED:
				var stage: int = e.data[ChainEvent.K_STAGE]
				if first_only and stage > 1:
					m.badges.append({K_CELL: e.data[ChainEvent.K_CELL], K_KIND: BadgeKind.HIDDEN, K_STAGE: 0})
				else:
					m.badges.append({K_CELL: e.data[ChainEvent.K_CELL], K_KIND: BadgeKind.STAGE, K_STAGE: stage})
			ChainEvent.Type.FACE_FIZZLED:
				var kind := BadgeKind.SLEEP if e.data[ChainEvent.K_REASON] == ChainEvent.REASON_DEPTH_CAP else BadgeKind.FROZEN
				if first_only and e.wave > 0:
					kind = BadgeKind.HIDDEN
				m.badges.append({K_CELL: e.data[ChainEvent.K_CELL], K_KIND: kind, K_STAGE: 0})
			ChainEvent.Type.ABILITY_EFFECT:
				if e.data[ChainEvent.K_KIND] != ChainEvent.KIND_FILL or (first_only and e.wave > 0):
					continue
				for cell: Vector2i in e.data[ChainEvent.K_CELLS]:
					m.eggs.append(cell)
			ChainEvent.Type.CELL_MODIFIED:
				if first_only and e.wave > 0:
					continue
				var mcell: Vector2i = e.data[ChainEvent.K_CELL]
				m.modified.append(mcell)
				if ObstacleRules.ice_in(e.data[ChainEvent.K_MODIFIERS_AFTER]) > 0:
					m.cracked.append(mcell)
				elif ObstacleRules.ice_in(e.data[ChainEvent.K_MODIFIERS_BEFORE]) > 0:
					if bool(e.data.get(ChainEvent.K_IS_FACE, false)):
						m.thawed.append(mcell)
					else:
						m.freed.append(mcell)
			ChainEvent.Type.CHAIN_END:
				depth = e.data[ChainEvent.K_CHAIN_DEPTH]
				cap = e.data[ChainEvent.K_CAP_REACHED]
	if first_only:
		cap = cap and depth <= 1
		depth = mini(depth, 1)
	if cfg.preview_detail != PreviewSettings.Detail.NO_BANNER:
		m.banner = banner_for(depth, cap)
		m.banner_n = depth if m.banner == Banner.CHAIN or m.banner == Banner.CHAIN_MAX else 0
	if cfg.show_predicted_score:
		m.breakdown = ScoreCalculator.score_placement(res.events, cfg.scoring_rules if cfg.scoring_rules != null else ScoringRules.new())
		m.has_predicted_score = true
		m.predicted_score = m.breakdown.total
	return m


## F3 banner tier: NONE if depth 0 · CHAIN_MAX if capped · ABILITY if depth 1 · CHAIN otherwise.
static func banner_for(chain_depth: int, cap_reached: bool) -> Banner:
	if chain_depth <= 0:
		return Banner.NONE
	if cap_reached:
		return Banner.CHAIN_MAX
	if chain_depth == 1:
		return Banner.ABILITY
	return Banner.CHAIN


## Public preview entry point (rule 1): resolves on a copy of [param board] with
## the round flow's [param ctx] — never builds or edits a context itself.
static func preview(board: BoardState, piece: PieceInstance, anchor: Vector2i, ctx: ResolveContext, settings: PreviewSettings = null) -> PreviewModel:
	return build_preview_model(ChainResolver.resolve(board.copy(), piece, anchor, ctx), settings)


## Every outlined cell (all waves).
func outlined_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in clear_waves:
		out.append(c)
	return out


## Plain comparable form (AC-P02 (2)); the score key is present only when shown (AC-P09).
func to_dict() -> Dictionary:
	var d := {
		&"clear_waves": clear_waves, &"badges": badges, &"eggs": eggs, &"modified": modified,
		&"banner": banner, &"banner_n": banner_n,
	}
	if has_predicted_score:
		d[&"predicted_score"] = predicted_score
	# Present only when an obstacle effect is predicted, so obstacle-free models
	# (and the committed parity digests) are unchanged.
	if not (cracked.is_empty() and freed.is_empty() and thawed.is_empty()):
		d[&"obstacles"] = {&"cracked": cracked, &"freed": freed, &"thawed": thawed}
	return d
