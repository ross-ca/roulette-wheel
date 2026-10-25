class_name DozenBet
extends Bet
## Bet on one dozen of the numbers: 1-12, 13-24 or 25-36. It covers 12 numbers, so it pays ×3.
## Zero is in no dozen, so it loses every dozen bet.

## Which dozen, from 0 (1-12) to 2 (25-36).
@export_range(0, 2) var dozen: int = 0


## A bet on `bet_dozen`, from 0 (1-12) to 2 (25-36).
static func of(bet_dozen: int) -> DozenBet:
	var bet := DozenBet.new()
	bet.dozen = bet_dozen
	bet.display_name = "%d-%d" % [bet_dozen * 12 + 1, bet_dozen * 12 + 12]
	return bet


func _init() -> void:
	base_mult = 3.0


func wins(pocket: Pocket) -> bool:
	return pocket.number >= dozen * 12 + 1 and pocket.number <= dozen * 12 + 12


func key() -> String:
	return "dozen:%d" % dozen
