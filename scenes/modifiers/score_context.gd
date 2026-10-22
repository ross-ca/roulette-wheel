class_name ScoreContext
extends RefCounted
## One spin's score as it passes through the modifiers. Placeholder: the formula will probably be
## points × mult with per-pocket bonuses, but isn't designed yet. Only this class and the play phase
## should need to change when it is.

var pocket: Pocket
var bet: Bet
## Whether the landed pocket satisfied the bet. A lost spin scores nothing.
var won := false
## Starts as the chips the player submitted for the spin.
var points: int = 0
## Starts as the bet's base mult.
var mult: float = 1.0
## What each modifier did, in order, for the UI to play back: {"source": Modifier, "text": String}.
var trace: Array[Dictionary] = []


func _init(landed: Pocket, chips: int, placed: Bet) -> void:
	pocket = landed
	bet = placed
	points = chips
	won = placed.wins(landed)
	mult = placed.base_mult


func add_trace(source: Modifier, text: String) -> void:
	trace.append({"source": source, "text": text})


func total() -> int:
	return int(points * mult) if won else 0
