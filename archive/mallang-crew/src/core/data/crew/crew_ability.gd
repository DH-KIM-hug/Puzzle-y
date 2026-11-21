## A crew's ability: id + ordered steps (crew-definition rule 3). Data only.
class_name CrewAbility
extends Resource

## Registry-unique ability id, e.g. [code]&"nyangi_cross_scratch"[/code].
@export var ability_id: StringName = &""
## Steps in execution order (at least one).
@export var steps: Array[AbilityStep] = []
