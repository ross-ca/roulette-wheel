class_name RoundState
extends Resource
## Progress through one round. Lives in `RunState.current_round` rather than in the play scene, so
## saving the run saves the round part-way through.

@export var spins_left: int = 0
## Net winnings from settled spins: what they paid minus what was staked on them.
@export var spin_profit: int = 0
## Money paid by effects outside the bets (pass tickets). Counts as profit too.
@export var money_earned: int = 0
## Bets on the table for the next spin. The spin uses them up.
@export var bets: Array[PlacedBet] = []


## The round's profit, which is what has to reach the step's required profit. Money carried in
## from earlier rounds doesn't count, only what this round has made.
func profit() -> int:
	return spin_profit + money_earned
