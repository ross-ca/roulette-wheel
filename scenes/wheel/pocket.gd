@tool
class_name Pocket
extends Resource
## One pocket on the wheel. Pockets belong to the run (`RunState.pockets`); the wheel draws whatever
## it's given and redraws when a pocket emits `changed`.

## Pocket numbers in European wheel order, clockwise from the top.
const EUROPEAN_ORDER: Array[int] = [
	0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10,
	5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26,
]

# Properties the wheel draws emit `changed` so it can redraw.
@export var number: int = 0:
	set(value):
		number = value
		emit_changed()
## A key into the wheel's COLOURS.
@export_enum("green", "red", "black") var colour: String = "red":
	set(value):
		colour = value
		emit_changed()
## Relative chance of being the winning pocket. 0 means it can never win.
@export var weight: float = 1.0


## A fresh set of the 37 European pockets. Each call returns new objects, so callers can mutate them.
static func european_layout() -> Array[Pocket]:
	var pockets: Array[Pocket] = []
	for i in EUROPEAN_ORDER.size():
		var pocket := Pocket.new()
		pocket.number = EUROPEAN_ORDER[i]
		# Zero is green, then the wheel alternates red and black.
		pocket.colour = "green" if i == 0 else ("red" if i % 2 == 1 else "black")
		pockets.append(pocket)
	return pockets
