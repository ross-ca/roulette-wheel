class_name RoundState
extends Resource
## Progress through one round. Lives in `RunState.current_round` rather than in the play scene, so
## saving the run saves the round part-way through.

@export var spins_left: int = 0
@export var score: int = 0
@export var money_earned: int = 0
## Bets on the table for the next spin. The spin uses them up.
@export var bets: Array[PlacedBet] = []
