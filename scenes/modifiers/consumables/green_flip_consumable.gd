class_name GreenFlipConsumable
extends Consumable
## Turns one red or black pocket green.


func get_description() -> String:
	return "Pick a number on the table. Set it's colour to green."


func can_target(_run: RunState, pocket: Pocket, _picked: Array[Pocket]) -> bool:
	return pocket.colour == "red" or pocket.colour == "black"


func use(_run: RunState, pockets: Array[Pocket]) -> void:
	pockets[0].colour = "green"
