## Counter-based deterministic PRNG (ADR-0001 Decision 7).
##
## One draw site = one [code]DetRng.new(SeedHash.hash32([stage_seed, STREAM, index]))[/code].
## [method next_u32] is [code]hash32([seed, counter])[/code]; nothing depends on
## the engine's built-in generators, so sequences are stable across versions.
class_name DetRng
extends RefCounted

var _seed: int
var _counter: int = 0


## Creates a stream from [param p_seed] (masked to 32 bits). The parameter is not
## called [code]seed[/code] because that shadows a global function.
func _init(p_seed: int) -> void:
	_seed = p_seed & SeedHash.MASK32


## Returns the stream seed (0 .. 2^32 - 1).
func get_seed() -> int:
	return _seed


## Returns the number of values drawn so far.
func get_counter() -> int:
	return _counter


## Next value in 0 .. 2^32 - 1.
func next_u32() -> int:
	var parts: Array[int] = [_seed, _counter]
	_counter += 1
	return SeedHash.hash32(parts)


## Uniform-ish value in 0 .. n - 1 via [code](next_u32() * n) >> 32[/code].
## Requires 1 <= n < 2^31; returns 0 and reports an error otherwise.
func below(n: int) -> int:
	if n < 1 or n >= 0x80000000:
		push_error("DetRng.below: n out of range: %d" % n)
		return 0
	return (next_u32() * n) >> 32


## Fisher-Yates shuffle of a copy of [param items] seeded by [param p_seed].
## The input array is never modified.
static func shuffle(items: Array, p_seed: int) -> Array:
	var out := items.duplicate()
	var rng := DetRng.new(p_seed)
	var i := out.size() - 1
	while i > 0:
		var j := rng.below(i + 1)
		var tmp: Variant = out[i]
		out[i] = out[j]
		out[j] = tmp
		i -= 1
	return out
