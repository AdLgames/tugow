class_name Palette
extends RefCounted
## A cozy palette with the wrong things in it. The greens and woods are
## pastoral; the meat tones and the altar are not. Nothing here is bright
## except money.

const NIGHT := Color("0b0c10")
const GRASS := Color("3e5a3a")
const GRASS_ALT := Color("47643f")
const DIRT := Color("4a3f31")
const WOOD := Color("6b4f34")
## The floor is darker than anything standing on it, or nothing reads.
const FLOOR_WOOD := Color("4b3826")
const FLOOR_IRON := Color("2f343d")
const WOOD_TOP := Color("8a6942")
const WOOD_DARK := Color("3f2d1d")
const WALL := Color("2b2f36")
## Walls are always the darkest standing thing, so a room reads as a room.
const WALL_WOOD := Color("2e2115")
const WALL_WOOD_TOP := Color("46331f")
const WALL_TOP := Color("3d434c")
const IRON := Color("434a55")
const IRON_TOP := Color("5b6472")
const STONE := Color("57545e")
const STONE_TOP := Color("6e6a76")
const ALTAR_STAIN := Color("6a2230")

const INK := Color("e8e2d4")
const INK_DIM := Color("9a9384")
const OBOL := Color("d9b44a")
const SAP := Color("8e2f3a")
const ROT := Color("6f7d3a")
const FLESH := Color("a05a5f")
const EYE := Color("8fd07a")
const VOID := Color("7d6bd6")

## The four goods, so a table reads at a glance.
const GOOD_COLOURS := {
	0: Color("d8cfb8"),   ## Shattered Bone
	1: Color("8e5fa8"),   ## Fey-Touched Berries
	2: Color("c9d8e8"),   ## Fresh Screams
	3: Color("a0455a"),   ## Pulsing Biomass
}


static func good_colour(id: int) -> Color:
	return GOOD_COLOURS.get(id, INK)


## Corruption bleeds into the floor. Nothing subtle about it.
static func floor_tint(corruption: float) -> Color:
	var f := clampf(corruption / Balance.corruption_cap, 0.0, 1.0)
	return Color(0, 0, 0, 0).lerp(Color(ROT.r, ROT.g, ROT.b, 0.35), f)
