class_name ConvertPocketConsumable
extends Consumable
## Picks two pockets and turns the first into a copy of the second. The first number leaves the
## wheel (bets on it can no longer win) and the second now appears twice.


func get_description() -> String:
	return "Pick two numbers on the table. The first becomes a copy of the second."


func target_count() -> int:
	return 2


func can_target(_run: RunState, pocket: Pocket, picked: Array[Pocket]) -> bool:
	# The second pick has to differ from the first, or there'd be nothing to convert.
	return picked.is_empty() or pocket.number != picked[0].number


func use(_run: RunState, pockets: Array[Pocket]) -> void:
	var from := pockets[0]
	var to := pockets[1]
	from.weight = to.weight
	from.colour = to.colour
	from.number = to.number
