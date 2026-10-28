class_name Consumable
extends Modifier
## A one-use item the player holds in `RunState.consumables`. It extends Modifier so a Card and its
## tooltip can show it like a ticket, but it isn't in `Modifiers.active()`: it does nothing until the
## player picks it, then its targets, in the play phase. Using one removes it from the run.
##
## Consumables change the wheel, so the targets are pockets (picked by clicking their numbers on the
## table, in order). Most need one; `target_count` says how many.

## Stable name used to look the consumable up.
@export var id: StringName = &""
@export var price: int = 3


func get_kind_name() -> String:
	return "Consumable"


## How many pockets the player picks before `use` runs.
func target_count() -> int:
	return 1


## Whether `pocket` is a valid next pick right now, given the pockets already `picked` for this use.
func can_target(_run: RunState, _pocket: Pocket, _picked: Array[Pocket]) -> bool:
	return false


## Applies the effect to `pockets`, in the order they were picked. Only called once `target_count`
## pockets have been accepted by `can_target`. Changing a pocket is enough for the table and wheel to
## update: the wheel redraws on `changed`, and the play phase refreshes the table.
func use(_run: RunState, _pockets: Array[Pocket]) -> void:
	pass
