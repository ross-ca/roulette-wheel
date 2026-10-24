class_name NumberBet
extends Bet
## Bet on one exact number, zero included. It covers a single pocket, so it pays ×36.

@export_range(0, 36) var number: int = 0


## A bet on `bet_number`.
static func of(bet_number: int) -> NumberBet:
	var bet := NumberBet.new()
	bet.number = bet_number
	bet.display_name = str(bet_number)
	return bet


func _init() -> void:
	base_mult = 36.0


func wins(pocket: Pocket) -> bool:
	return pocket.number == number


func key() -> String:
	return "number:%d" % number
