class_name ParityBet
extends Bet
## Bet on the landed number being even or odd. Either covers 18 numbers, so it pays ×2. Zero is
## neither, so it loses both.

@export var even: bool = true


## A bet on even numbers when `bet_even`, otherwise on odd ones.
static func of(bet_even: bool) -> ParityBet:
	var bet := ParityBet.new()
	bet.even = bet_even
	bet.display_name = "Even" if bet_even else "Odd"
	return bet


func _init() -> void:
	base_mult = 2.0


func wins(pocket: Pocket) -> bool:
	return pocket.number != 0 and (pocket.number % 2 == 0) == even


func key() -> String:
	return "parity:%s" % ("even" if even else "odd")
