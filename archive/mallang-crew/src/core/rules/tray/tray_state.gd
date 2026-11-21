## Tray supply state for one round (ADR-0001 Decision 6). A value object:
## [TraySupplyRules] never mutates a state it receives — it returns a new one.
## The round flow keeps the current state. Pieces in [member slots] are shared
## between states and must be treated as immutable (rule 4: a shown piece never changes).
class_name TrayState
extends RefCounted

## Slot-content states (GDD States and Transitions).
enum Status { AWAITING_REFILL, FULL, PARTIAL, EXHAUSTED }

## Team crew ids in team-slot order (rule 7).
var team: Array[StringName] = []
## Stage tray configuration (read-only).
var cfg: TrayRules
## Crew data source (read-only).
var registry: CrewRegistry
## Round seed (F3).
var stage_seed: int = 0
## One entry per slot: a [PieceInstance] or null (empty slot).
var slots: Array = []
## Slot-content state.
var status: Status = Status.AWAITING_REFILL
## Refills done so far ([code]r[/code] in F3).
var refill_index: int = 0
## Pieces put into the tray so far ([code]i[/code] in F3; rescue swaps do not count).
var piece_index: int = 0
## Remaining crew-bag tokens, draw order front to back.
var crew_bag: Array[StringName] = []
## Next crew bag number ([code]j[/code] in F3).
var crew_bag_index: int = 0
## crew_id -> remaining shape-entry indices (draw order front to back).
var shape_bags: Dictionary = {}
## crew_id -> next shape cycle number ([code]q[/code] in F3).
var shape_cycles: Dictionary = {}
## Load errors (rule 22, Edge Cases). Non-empty = the stage must not start.
var errors: PackedStringArray = PackedStringArray()
## Lint warnings (rule 22, Edge Cases).
var warnings: PackedStringArray = PackedStringArray()


## True when there were no load errors.
func is_valid() -> bool:
	return errors.is_empty()


## Independent copy (slot pieces are shared — they are immutable).
func copy() -> TrayState:
	var s := TrayState.new()
	s.team = team.duplicate()
	s.cfg = cfg
	s.registry = registry
	s.stage_seed = stage_seed
	s.slots = slots.duplicate()
	s.status = status
	s.refill_index = refill_index
	s.piece_index = piece_index
	s.crew_bag = crew_bag.duplicate()
	s.crew_bag_index = crew_bag_index
	s.shape_bags = shape_bags.duplicate(true)
	s.shape_cycles = shape_cycles.duplicate()
	s.errors = errors.duplicate()
	s.warnings = warnings.duplicate()
	return s


## The slots as shown (PieceInstance or null per slot; a new array).
func snapshot() -> Array:
	return slots.duplicate()


## Non-empty slots' pieces, slot order (for [method BoardRules.no_moves]).
func pieces() -> Array[PieceInstance]:
	var out: Array[PieceInstance] = []
	for p: Variant in slots:
		if p != null:
			out.append(p)
	return out


## True when every slot is empty.
func is_empty() -> bool:
	for p: Variant in slots:
		if p != null:
			return false
	return true
