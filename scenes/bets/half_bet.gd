class_name HalfBet
extends Bet
## Bet on the low half of the numbers (1-18) or the high half (19-36). Either covers 18 numbers, so
## it pays ×2. Zero is in neither half, so it loses both.

## False for 1-18, true for 19-36.
@export var high: bool = false


## A bet on 19-36 when `bet_high`, otherwise on 1-18.
static func of(bet_high: bool) -> HalfBet:
	var bet := HalfBet.new()
	bet.high = bet_high
	bet.display_name = "19-36" if bet_high else "1-18"
	return bet


func _init() -> void:
	base_mult = 2.0


func wins(pocket: Pocket) -> bool:
	var low := 19 if high else 1
	return pocket.number >= low and pocket.number <= low + 17


func key() -> String:
	return "half:%s" % ("high" if high else "low")
