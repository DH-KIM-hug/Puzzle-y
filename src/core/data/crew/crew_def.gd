## One crew = one resource file (crew-definition rule 1, ADR-0001 Decision 8).
## Data only — no logic. Lives at [code]assets/data/crew/<id>.tres[/code].
class_name CrewDef
extends Resource

## Rarity tiers (rule 10) — cosmetic / gacha band only, never numeric power.
enum Rarity { COMMON, RARE, SPECIAL }

## Permanent registry-unique id (lower snake case).
@export var id: StringName = &""
## Data schema version (MVP 1).
@export var schema_version: int = 1
## Localisation key of the display name.
@export var name_key: String = ""
## Free-form species tag (art / album only).
@export var species: StringName = &""
## Palette row 1 .. palette_slot_count (hex lives in the palette resource).
@export var colour_slot: int = 1
## Rarity tier.
@export var rarity: Rarity = Rarity.COMMON
## Shape pool (1 .. max_shapes_per_crew entries).
@export var shapes: Array[CrewShapeEntry] = []
## Ability run when this crew's face is cleared.
@export var ability: CrewAbility
## Localisation key of the ability name.
@export var ability_name_key: String = ""
## Localisation key of the ability description.
@export var ability_desc_key: String = ""
## Silhouette protrusion tag (registry-unique).
@export var silhouette_feature: StringName = &""
## Body pattern tag (registry-unique).
@export var body_pattern: StringName = &""
## Art for cells this crew FILLs; [code]&""[/code] = none (required with a FILL step).
@export var fill_visual: StringName = &""
## Owned by a new save.
@export var starter: bool = false
## In the gacha pool.
@export var obtainable: bool = true
