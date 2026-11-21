## Stage result math (design/gdd/stage-goals.md F1, F2, F5–F7). Integer only.
## [codeblock]
## var bonus := StageScoring.leftover_bonus(true, 5, 100, 10, 10)        # 500
## var stars := StageScoring.stars(true, 1740, PackedInt32Array([1700, 2400]), 10, 10)  # 2
## [/codeblock]
class_name StageScoring
extends RefCounted


## F1: [code]⌊x × cell_points / cell_points_ref⌋[/code].
static func pts_eff(x: int, cell_points: int, cell_points_ref: int) -> int:
	if cell_points_ref <= 0:
		return x
	return (x * cell_points) / cell_points_ref


## F2: pieces left; [constant StageDef.UNLIMITED] stays unlimited.
static func pieces_left(piece_limit: int, pieces_placed: int) -> int:
	if piece_limit == StageDef.UNLIMITED:
		return StageDef.UNLIMITED
	return maxi(0, piece_limit - pieces_placed)


## F5: [code]cleared ? pieces_left × pts_eff(leftover_piece_points) : 0[/code]
## (unlimited stages get no bonus).
static func leftover_bonus(cleared: bool, p_pieces_left: int, leftover_piece_points: int, cell_points: int, cell_points_ref: int) -> int:
	if not cleared or p_pieces_left <= 0:
		return 0
	return p_pieces_left * pts_eff(leftover_piece_points, cell_points, cell_points_ref)


## F6: [code]stage_score + leftover_bonus[/code].
static func final_score(stage_score: int, bonus: int) -> int:
	return stage_score + bonus


## F7: [code]cleared ? 1 + [final ≥ pts_eff(S2)] + [final ≥ pts_eff(S3)] : 0[/code].
static func stars(cleared: bool, p_final_score: int, star_points: PackedInt32Array, cell_points: int, cell_points_ref: int) -> int:
	if not cleared:
		return 0
	var n := 1
	if star_points.size() >= 1 and p_final_score >= pts_eff(star_points[0], cell_points, cell_points_ref):
		n += 1
	if star_points.size() >= 2 and p_final_score >= pts_eff(star_points[1], cell_points, cell_points_ref):
		n += 1
	return n
