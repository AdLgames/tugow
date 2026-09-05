class_name Names
extends RefCounted
## Names and reasons for entry. Plain, regional, unremarkable — the point is
## that nothing on the tag ever tells you anything.

const FIRST := [
	"Elise", "Tomas", "Marta", "Iven", "Dena", "Halloran", "Wren", "Osk",
	"Petra", "Calder", "Sabine", "Rook", "Nell", "Ambrose", "Ida", "Verity",
	"Joss", "Maren", "Casp", "Lowry",
]

const LAST := [
	"Ashfield", "Dray", "Vance", "Molloy", "Kerr", "Stannard", "Pell",
	"Ibsen", "Ordway", "Frame", "Quill", "Salter", "Ness", "Bramwell",
]

const REASONS := [
	"Sister inside. Went through in the spring.",
	"Work placement. Sanitation, third district.",
	"Nothing left on my side of the river.",
	"Medical. There is a doctor in there who knows me.",
	"My son went with the second convoy.",
	"I was told to come. I do not know by whom.",
	"Returning. I have papers somewhere. Had.",
	"The road behind me is not passable any more.",
	"To find someone. I will know them when I see them.",
	"I walked from Marren. That is the whole of it.",
]


static func pick(rng: RandomNumberGenerator) -> String:
	return "%s %s" % [FIRST[rng.randi_range(0, FIRST.size() - 1)],
		LAST[rng.randi_range(0, LAST.size() - 1)]]


static func reason(rng: RandomNumberGenerator) -> String:
	return String(REASONS[rng.randi_range(0, REASONS.size() - 1)])
