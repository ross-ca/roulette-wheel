class_name PlacedBet
extends Resource
## The chips on one bet for the next spin. The round keeps these in `RoundState.bets`, so bets
## placed before a save are still on the table after loading it.

@export var bet: Bet
## In the order they were dropped.
@export var chips: Array[PlacedChip] = []


static func of(placed: Bet) -> PlacedBet:
	var result := PlacedBet.new()
	result.bet = placed
	return result


## What the bet stakes: the value of all its chips.
func total() -> int:
	var sum := 0
	for chip in chips:
		sum += chip.value
	return sum
