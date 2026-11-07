## Deterministic 32-bit hashing for the Rules Core (ADR-0001 Decision 7).
##
## [method hash32] is MurmurHash3_x86_32 with seed 0 over a sequence of 32-bit
## little-endian words (one word per part, no tail). Every intermediate value is
## kept below 2^63 so the signed 64-bit GDScript int never overflows, which keeps
## the result identical on every platform and engine version.
## [method str32] is FNV-1a 32 over UTF-8 bytes (the GDD's [code]crew_key[/code]).
class_name SeedHash
extends RefCounted

## Mask for the low 32 bits.
const MASK32 := 0xFFFFFFFF

const _C1 := 0xcc9e2d51
const _C2 := 0x1b873593
const _N := 0xe6546b64
const _F1 := 0x85ebca6b
const _F2 := 0xc2b2ae35
const _FNV_OFFSET := 0x811c9dc5
const _FNV_PRIME := 0x01000193


## Returns MurmurHash3_x86_32(seed 0) of [param parts], each masked to 32 bits.
## Result range: 0 .. 2^32 - 1. Negative parts hash as their two's-complement
## low 32 bits. Reference: [code]hash32([0]) == 593689054[/code].
static func hash32(parts: Array[int]) -> int:
	var h := 0
	for part: int in parts:
		var k := part & MASK32
		k = mul32(k, _C1)
		k = rotl32(k, 15)
		k = mul32(k, _C2)
		h = h ^ k
		h = rotl32(h, 13)
		h = (mul32(h, 5) + _N) & MASK32
	h = h ^ ((4 * parts.size()) & MASK32)
	return fmix32(h)


## MurmurHash3 finaliser. [param h] must be in 0 .. 2^32 - 1.
static func fmix32(h: int) -> int:
	var x := h & MASK32
	x = x ^ (x >> 16)
	x = mul32(x, _F1)
	x = x ^ (x >> 13)
	x = mul32(x, _F2)
	x = x ^ (x >> 16)
	return x


## Returns (a * b) mod 2^32 for a, b in 0 .. 2^32 - 1 without any product
## exceeding 2^49 (16-bit split multiply).
static func mul32(a: int, b: int) -> int:
	var x := a & MASK32
	var y := b & MASK32
	return (x * (y & 0xFFFF) + (((x * (y >> 16)) & 0xFFFF) << 16)) & MASK32


## 32-bit rotate left. [param x] in 0 .. 2^32 - 1, [param r] in 1 .. 31.
static func rotl32(x: int, r: int) -> int:
	var v := x & MASK32
	return ((v << r) | (v >> (32 - r))) & MASK32


## FNV-1a 32 over [code]text.to_utf8_buffer()[/code]. Used as the stable
## per-crew key in [code]board_hash[/code]; never use [code]String.hash()[/code].
static func str32(text: String) -> int:
	var h := _FNV_OFFSET
	for b: int in text.to_utf8_buffer():
		h = h ^ b
		h = mul32(h, _FNV_PRIME)
	return h
