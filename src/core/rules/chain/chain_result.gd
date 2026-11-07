## Output of [method ChainResolver.resolve] (chain-resolver rule 1).
## Consumers must treat everything here as read-only; [member final_board]
## must be [method BoardState.copy]-ed before modification.
class_name ChainResult
extends RefCounted

## Ordered events, seq 0..n-1 (read-only).
var events: Array[ChainEvent] = []
## Board after the chain.
var final_board: BoardState
## CHAIN_END payload (read-only); empty when the placement was invalid.
var summary: Dictionary = {}
## Non-empty when resolve refused the input (invalid placement).
var error: String = ""


## True when the placement was resolved.
func is_valid() -> bool:
	return error.is_empty()


## Events as plain dictionaries — stable golden/parity comparison.
func events_as_dicts() -> Array:
	var out := []
	for e: ChainEvent in events:
		out.append(e.to_dict())
	return out


## All events of one type, in order.
func events_of(t: ChainEvent.Type) -> Array[ChainEvent]:
	var out: Array[ChainEvent] = []
	for e: ChainEvent in events:
		if e.type == t:
			out.append(e)
	return out
