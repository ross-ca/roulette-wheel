class_name GreenFlipConsumable
extends Consumable
## Flips one pocket between green and black. Red pockets can't be flipped.


func get_description() -> String:
    return "Pick a number on the table. Set it's colour to green."


func can_target(_run: RunState, pocket: Pocket) -> bool:
    return pocket.colour == "red" or pocket.colour == "black"


func use(_run: RunState, pocket: Pocket) -> void:
    pocket.colour = "green"