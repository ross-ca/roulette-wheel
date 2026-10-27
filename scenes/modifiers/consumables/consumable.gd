class_name Consumable
extends Modifier
## A one-use item the player holds in `RunState.consumables`. It extends Modifier so a Card and its
## tooltip can show it like a ticket, but it isn't in `Modifiers.active()`: it does nothing until the
## player picks it, then a target, in the play phase. Using one removes it from the run.
##
## Consumables change the wheel, so the target is a pocket (picked by clicking its number on the
## table). A consumable that needs more than one pocket will want a second selection step added.

## Stable name used to look the consumable up.
@export var id: StringName = &""
@export var price: int = 3


func get_kind_name() -> String:
	return "Consumable"


## Whether `pocket` is a valid target right now.
func can_target(_run: RunState, _pocket: Pocket) -> bool:
	return false


## Applies the effect to `pocket`. Only called when `can_target` is true. Changing the pocket is
## enough for the table and wheel to update: the wheel redraws on `changed`, and the play phase
## refreshes the table.
func use(_run: RunState, _pocket: Pocket) -> void:
	pass
