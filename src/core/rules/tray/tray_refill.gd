## Result of [method TraySupplyRules.refill] (ADR-0001 Decision 6).
class_name TrayRefill
extends RefCounted

## TRAY_RESCUED log keys (rule 14).
const K_REFILL_INDEX := &"refill_index"
const K_SLOT := &"slot"
const K_FROM_SHAPE := &"from_shape"
const K_TO_SHAPE := &"to_shape"

## The new tray state (the input state on error).
var state: TrayState
## Pieces put into the tray by this refill, slot order (empty on error / budget 0).
var pieces: Array[PieceInstance] = []
## TRAY_RESCUED records ({refill_index, slot, from_shape, to_shape}); at most one.
var rescued: Array[Dictionary] = []
## Non-empty when the refill was refused (tray not empty, invalid state).
var error: String = ""
## True when this refill came from [member TrayRules.tray_script].
var scripted: bool = false
