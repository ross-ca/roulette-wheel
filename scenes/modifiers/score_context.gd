class_name ScoreContext
extends RefCounted
## One spin's score as it passes through the modifiers. Placeholder: the formula will probably be
## points × mult with per-pocket bonuses, but isn't designed yet. Only this class and the play phase
## should need to change when it is.

var pocket: Pocket
var points: int = 0
var mult: float = 1.0
## What each modifier did, in order, for the UI to play back: {"source": Modifier, "text": String}.
var trace: Array[Dictionary] = []


func _init(landed: Pocket) -> void:
	pocket = landed
	points = landed.base_points


func add_trace(source: Modifier, text: String) -> void:
	trace.append({"source": source, "text": text})


func total() -> int:
	return int(points * mult)
