## crew_id → greybox look (colour slot, species silhouette, body pattern, name keys)
## read from the validated [CrewRegistry] (chain-presentation rule 1 "crew_visuals").
## No crew-specific branching on ids: everything comes from [CrewDef] data.
## [codeblock]
## var visuals := CrewVisuals.from_registry(registry)
## var look := visuals.look(&"nyangi")   # {base, shade, species, pattern, feature, name_key, ability_name_key}
## [/codeblock]
class_name CrewVisuals
extends RefCounted

const K_BASE := &"base"
const K_SHADE := &"shade"
const K_SPECIES := &"species"
const K_PATTERN := &"pattern"
const K_FEATURE := &"feature"
const K_NAME_KEY := &"name_key"
const K_ABILITY_NAME_KEY := &"ability_name_key"

var _looks: Dictionary = {}
var _fallback: Dictionary = {K_BASE: Palette.INK_LIGHT, K_SHADE: Palette.INK, K_SPECIES: &"", K_PATTERN: &"", K_FEATURE: &"",
		K_NAME_KEY: "", K_ABILITY_NAME_KEY: ""}


## Builds the table from every crew in [param registry].
static func from_registry(registry: CrewRegistry) -> CrewVisuals:
	var v := CrewVisuals.new()
	for c: CrewDef in registry.crews:
		v._looks[c.id] = {
			K_BASE: Palette.base(c.colour_slot), K_SHADE: Palette.shade(c.colour_slot),
			K_SPECIES: c.species, K_PATTERN: c.body_pattern, K_FEATURE: c.silhouette_feature,
			K_NAME_KEY: c.name_key, K_ABILITY_NAME_KEY: c.ability_name_key,
		}
	return v


## Look of [param crew_id] (a neutral look for faceless / unknown crews).
func look(crew_id: StringName) -> Dictionary:
	return _looks.get(crew_id, _fallback)
