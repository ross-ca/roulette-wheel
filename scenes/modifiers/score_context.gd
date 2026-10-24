class_name ScoreContext
extends RefCounted
## One bet's score in a spin as it passes through the modifiers. A spin holds one per bet in its
## SpinContext. Placeholder: the formula will probably be points × mult with per-pocket bonuses, but
## isn't designed yet. Only this class, SpinContext and the play phase should need to change when it is.

var pocket: Pocket
var bet: Bet
## Whether the landed pocket satisfied the bet. A lost bet scores nothing.
var won := false
## Starts as the chips placed on the bet.
var points: int = 0
## Starts as the bet's base mult.
var mult: float = 1.0
## What each modifier did, in order, for the UI to play back: {"source": Modifier, "text": String}.
var trace: Array[Dictionary] = []


## Created by SpinContext when the spin starts, before the pocket is known, so `mult` can build up
## live as the ball passes pockets. `land` is called once it settles.
func _init(chips: int, placed: Bet) -> void:
	bet = placed
	points = chips
	mult = placed.base_mult


func land(landed: Pocket) -> void:
	pocket = landed
	won = bet.wins(landed)


func add_trace(source: Modifier, text: String) -> void:
	trace.append({"source": source, "text": text})


func total() -> int:
	return int(points * mult) if won else 0
