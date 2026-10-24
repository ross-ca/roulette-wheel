class_name PlacedBet
extends Resource
## Chips staked on one bet for the next spin. The round keeps these in `RoundState.bets`, so bets
## placed before a save are still on the table after loading it.

@export var bet: Bet
@export var chips: int = 0


static func of(placed: Bet, amount: int) -> PlacedBet:
	var result := PlacedBet.new()
	result.bet = placed
	result.chips = amount
	return result
