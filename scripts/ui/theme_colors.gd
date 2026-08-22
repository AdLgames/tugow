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
