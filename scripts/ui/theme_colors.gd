class_name ThemeColors
extends RefCounted
## One palette, used everywhere. Ink on bone, with the card states colour-coded.

const BACKGROUND := Color("14121a")
const PANEL := Color("1d1a25")
const PANEL_EDGE := Color("2e2a3a")
const INK := Color("e8dcc0")
const INK_DIM := Color("9a9184")
const OPEN := Color("e8dcc0")
const PLAYER := Color("6fae7c")
const ADVERSARY := Color("c8452f")
const BURNED := Color("55505e")
const LOCKED := Color("d9a441")
const BITTER := Color("9d6bd6")
const DECLARED := Color("e0703c")


# --- The saloon scene --------------------------------------------------------
## Deliberately outside the thirteen: a physical table needs wood and felt.
## Everything else in the scene comes from the palette above.
## Source: docs/design-system/BUILD_BRIEF_table_scene.md, "The one colour rule".
const WOOD_HI := Color("4a3524")
const WOOD_MID := Color("31231a")
const WOOD_LO := Color("1b130e")
const RAIL_PAD := Color("241811")
const RAIL_EDGE := Color("0d0908")
const FELT_HI := Color("2d3d2f")
const FELT_MID := Color("22301f")
const FELT_LO := Color("16201a")
const FELT_EDGE := Color("101711")

## Paper, pencil and ink — the Ledger is a physical sheet, not a panel.
const PAPER_HI := Color("e6dabe")
const PAPER_MID := Color("d3c4a2")
const PAPER_LO := Color("c2b28f")
const PENCIL := Color("3c3b42")
const HIS_INK := Color("101c26")
const SCRATCH_RED := Color("8e2f22")
const SCORCH := Color("3a2213")

## Lamplight. Warmth is yours.
const LAMP_CORE := Color("fff0cf")
const LAMP_WARM := Color("ffd28f")
const LAMP_AMBER := Color("e0a04d")
const LAMP_DEEP := Color("a8641c")

## The adversary is the only cold thing in frame.
const COLD_RIM := Color("a3b6c8")
const COLD_SHADE := Color("7d8b9c")
const COLD_BODY := Color("101419")
const ROOM_WALL := Color("1d1410")
const ROOM_DARK := Color("07060a")


static func for_state(state: int) -> Color:
	match state:
		Scorecard.State.PLAYER:
			return PLAYER
		Scorecard.State.ADVERSARY:
			return ADVERSARY
		Scorecard.State.BURNED:
			return BURNED
	return OPEN


static func panel_style(edge: Color = PANEL_EDGE) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = edge
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb
