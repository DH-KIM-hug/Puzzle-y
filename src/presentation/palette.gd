## Greybox palette from design/art/art-bible.md section 4 (Color System).
## Visual constants only — no gameplay values.
class_name Palette
extends RefCounted

const KRAFT := Color("#e8d9bd")
const KRAFT_SHADE := Color("#d6c29f")
const BOARD_PAPER := Color("#f3e8d3")
const STICKER_WHITE := Color("#fffdf8")
const INK := Color("#3b2f25")
const INK_DARK := Color("#2b211a")
const INK_LIGHT := Color("#7a6553")
const FACE_CREAM := Color("#fbf1d6")
const GOLD := Color("#ffe278")
const BEAK := Color("#e8873a")
const GREY_TONE := Color("#b9b2a8")

## colour_slot (1-based, crew-definition) → [base, shade] (art-bible crew table).
const CREW_SLOTS := {
	1: [Color("#e8574a"), Color("#b83a30")],
	2: [Color("#2e6bc6"), Color("#1f4b8f")],
	3: [Color("#f2c230"), Color("#c99a10")],
	4: [Color("#2a7a45"), Color("#1c5530")],
	5: [Color("#9a72d4"), Color("#7150a8")],
	6: [Color("#f29cc0"), Color("#c56f95")],
}


## Base colour of a colour slot (ink-light when unknown).
static func base(slot: int) -> Color:
	return CREW_SLOTS[slot][0] if CREW_SLOTS.has(slot) else INK_LIGHT


## Shade colour of a colour slot.
static func shade(slot: int) -> Color:
	return CREW_SLOTS[slot][1] if CREW_SLOTS.has(slot) else INK


## Ink with alpha [param a].
static func ink(a: float) -> Color:
	return Color(INK, a)
