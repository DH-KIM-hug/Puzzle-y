## One ability step: a primitive id + its parameters (crew-definition rule 3).
## Data only; meaning and validation belong to [PrimitiveLibrary].
class_name AbilityStep
extends Resource

## Primitive id from chain-resolver rule 14.
@export var primitive: StringName = &""
## Primitive parameters (keys stored as StringName; int values must be TYPE_INT).
@export var params: Dictionary = {}
