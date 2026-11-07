## Fixed stream tags for [method SeedHash.hash32] seed derivation (ADR-0001).
## Changing any value invalidates every FIXED stage and golden test.
class_name SeedStreams
extends RefCounted

const RESOLVER := 0x5245534F        # "RESO"
const TRAY_CREW := 0x54435257       # "TCRW"
const TRAY_SHAPE := 0x54534850      # "TSHP"
const TRAY_FACE := 0x54464143       # "TFAC"
const TRAY_RESCUE := 0x54525343     # "TRSC"
const TRAY_FACELESS := 0x54464C53   # "TFLS"
const ATTEMPT := 0x41545450         # "ATTP"
const GACHA := 0x47414348           # "GACH"


## chain-resolver F7: [code]rng_seed = hash32(stage_seed, STREAM_RESOLVER, placement_index)[/code].
static func resolver_seed(stage_seed: int, placement_index: int) -> int:
	var parts: Array[int] = [stage_seed, RESOLVER, placement_index]
	return SeedHash.hash32(parts)
