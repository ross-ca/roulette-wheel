class_name ColourFlipConsumable
extends Consumable
## Flips one pocket between red and black. Green pockets can't be flipped.


func get_description() -> String:
	return "Pick a number on the table. Its pocket turns black if it's red, and red if it's black."


func can_target(_run: RunState, pocket: Pocket, _picked: Array[Pocket]) -> bool:
	return pocket.colour == "red" or pocket.colour == "black"


func use(_run: RunState, pockets: Array[Pocket]) -> void:
	var pocket := pockets[0]
	pocket.colour = "black" if pocket.colour == "red" else "red"
