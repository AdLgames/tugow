@tool
class_name ModalTheme
extends RefCounted

## The panel's chrome: a late-90s pro-audio front panel.
##
## Every colour here is taken from the design. They are not arbitrary — the
## palette is two greys (the panel casting and its bevel), one near-black with
## a green cast (the recessed display glass), amber for anything the machine is
## telling you, and a dull red for anything it refused. Nothing else. Adding a
## sixth colour is how this stops looking like a machine and starts looking
## like a web page.

# --- casting and bevel -------------------------------------------------------
const PANEL_TOP := Color("#2b2a26")
const PANEL_BOTTOM := Color("#232220")
const PANEL_BORDER := Color("#3a3833")
const PANEL_BEVEL := Color("#4b4841")      ## the lit top edge
const RULE := Color("#34322d")             ## hairline dividers inside a panel

# --- recessed glass ----------------------------------------------------------
const GLASS := Color("#0f1210")            ## small readouts
const GLASS_DEEP := Color("#0a0d0a")       ## the plot wells
const GLASS_BORDER := Color("#1d211c")

# --- ink ---------------------------------------------------------------------
const AMBER := Color("#e8b23a")            ## the machine's own voice
const INK := Color("#cfd8bd")              ## traces on glass
const TEXT := Color("#e6e1d6")             ## headline text on casting
const TEXT_DIM := Color("#a09887")         ## values
const LABEL := Color("#8d8578")            ## field labels
const LABEL_FAINT := Color("#77705f")
const MUTED := Color("#6f6a5e")            ## captions
const FOOTNOTE := Color("#5c574d")
const RED := Color("#b8604f")              ## rejections, the difference trace

# --- plot furniture ----------------------------------------------------------
const GRID := Color("#1c2119")
const GRID_DIM := Color("#4a5340")         ## axis numerals
const TRACE_OFF := Color("#5c6a4c")        ## a mode that is soloed out
const ZERO_LINE := Color("#3c4a33")
const STRIKE_GRID := Color("#1d2419")
const STRIKE_FRAME := Color("#2a3324")
const STRIKE_IDLE := Color("#5c6a4c")
const STRIKE_AXIS := Color("#3d4634")

# --- controls ----------------------------------------------------------------
const BUTTON_FILL := Color("#26251f")
const BUTTON_ON_TOP := Color("#4a4840")
const BUTTON_ON_BOTTOM := Color("#3a3832")
const BUTTON_ON_BORDER := Color("#5d5a50")
const ROW_FILL := Color("#25241f")
const ROW_FILL_OFF := Color("#1e1d19")
const ROW_SELECTED := Color("#31302a")
const ACTION_TOP := Color("#41403a")
const ACTION_BOTTOM := Color("#2f2e2a")
const ACTION_BORDER := Color("#4c4a43")
const ACTION_HOVER_TOP := Color("#4a4942")
const ACTION_HOVER_BOTTOM := Color("#37362f")

## The window ground. A radial wash, lighter at the top, so the panels read as
## lit from above by something just off-screen.
const BACKDROP_INNER := Color("#242320")
const BACKDROP_MID := Color("#131312")
const BACKDROP_OUTER := Color("#0d0d0c")


# --- type --------------------------------------------------------------------
#
# The design sets everything in Space Mono, with Helvetica for the small
# letterspaced labels. Neither ships with Godot and neither can be vendored
# here without a licence decision, so both resolve through `SystemFont`: if the
# machine has them the panel looks exactly as drawn, and if not it falls back
# along a chain that keeps the character — a grotesque for labels, a typewriter
# monospace for everything the machine says.
#
# To pin it exactly, drop SpaceMono-Regular.ttf and SpaceMono-Bold.ttf into
# gui/fonts/ and they are picked up ahead of the system chain. See gui/README.md.

const MONO_FILE := "res://fonts/SpaceMono-Regular.ttf"
const MONO_BOLD_FILE := "res://fonts/SpaceMono-Bold.ttf"

static var _mono: Font
static var _mono_bold: Font
static var _sans: Font


static func mono() -> Font:
	if _mono == null:
		_mono = _load_font(MONO_FILE, PackedStringArray([
			"Space Mono", "IBM Plex Mono", "DejaVu Sans Mono", "Menlo", "Consolas", "monospace",
		]), false)
	return _mono


static func mono_bold() -> Font:
	if _mono_bold == null:
		_mono_bold = _load_font(MONO_BOLD_FILE, PackedStringArray([
			"Space Mono", "IBM Plex Mono", "DejaVu Sans Mono", "Menlo", "Consolas", "monospace",
		]), true)
	return _mono_bold


static func sans() -> Font:
	if _sans == null:
		_sans = _load_font("", PackedStringArray([
			"Helvetica Neue", "Helvetica", "Arial", "DejaVu Sans", "sans-serif",
		]), false)
	return _sans


static func _load_font(path: String, names: PackedStringArray, bold: bool) -> Font:
	if not path.is_empty() and ResourceLoader.exists(path):
		var file: Variant = load(path)
		if file is Font:
			return file
	var system := SystemFont.new()
	system.font_names = names
	system.font_weight = 700 if bold else 400
	# The design is drawn with antialiased, subpixel-positioned type at 8 and
	# 9 px. Without subpixel positioning the letterspacing visibly stutters at
	# those sizes.
	system.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_ONE_QUARTER
	return system


# --- boxes -------------------------------------------------------------------

## A stage button or a mode row.
static func button_box(active: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = BUTTON_ON_TOP.lerp(BUTTON_ON_BOTTOM, 0.5) if active else BUTTON_FILL
	box.set_border_width_all(1)
	box.border_color = BUTTON_ON_BORDER if active else PANEL_BORDER
	box.set_corner_radius_all(3)
	box.content_margin_left = 11
	box.content_margin_right = 11
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


## The primary action — Write .modal.
static func action_box(hover := false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = (ACTION_HOVER_TOP.lerp(ACTION_HOVER_BOTTOM, 0.5) if hover
			else ACTION_TOP.lerp(ACTION_BOTTOM, 0.5))
	box.set_border_width_all(1)
	box.border_color = ACTION_BORDER
	box.set_corner_radius_all(3)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


## A mode row in the table: three states, all of them quiet.
static func row_box(selected: bool, dimmed: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	if selected:
		box.bg_color = ROW_SELECTED
		box.set_border_width_all(1)
		box.border_color = BUTTON_ON_BORDER
	else:
		box.bg_color = ROW_FILL_OFF if dimmed else ROW_FILL
		box.set_border_width_all(1)
		box.border_color = Color(0, 0, 0, 0)
	box.set_corner_radius_all(3)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 7
	box.content_margin_bottom = 6
	return box


static func empty_box() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()
