class_name Palette
extends RefCounted
## One lamp, one window, and the dark. Everything warm is inside the booth;
## everything cold is out there or behind you.

const NIGHT := Color("07070a")
const BOOTH := Color("14110d")
const DESK := Color("241c12")
const DESK_EDGE := Color("0d0a07")
const LAMP := Color("f0c98a")
const LAMP_DIM := Color("8a6f45")
const INK := Color("e6ddcb")
const INK_DIM := Color("8f8878")
const GLASS := Color("2a3138")
const WINDOW_LIT := Color("d8b26a")
const WINDOW_DARK := Color("15161a")
## The only cold thing that gets to be bright.
const WRONG := Color("9fb4c4")
const BLOOD := Color("8e2f22")
const APPROVE := Color("6f8f52")
const DENY := Color("8e5a2f")


static func lamp_falloff(distance: float) -> Color:
	return LAMP.lerp(NIGHT, clampf(distance, 0.0, 1.0))
