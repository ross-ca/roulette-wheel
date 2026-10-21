class_name RoundStep
extends RunStep
## A round: a few spins to reach `target_score`. Losing a round ends the run.

@export var target_score: int = 300
@export var reward: int = 3
## Boss rules, and any other modifiers active only during this round.
@export var modifiers: Array[Modifier] = []


func _init() -> void:
	# load(), not preload(): play.gd refers back to this class.
	phase_scene = load("res://scenes/play/play.tscn")


func on_finished(run: RunState, result: Variant) -> void:
	if result.won:
		run.money += reward
	else:
		run.is_over = true
