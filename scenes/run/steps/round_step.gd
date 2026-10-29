class_name RoundStep
extends RunStep
## A round: a few spins to make `required_profit` in profit. Losing a round ends the run. Winning pays
## `VOUCHERS_PER_SPIN_LEFT` vouchers for every spin the player didn't need.

const VOUCHERS_PER_SPIN_LEFT := 2

## The profit the round has to make (winnings minus stakes), not the money the player ends with.
@export var required_profit: int = 300
## Boss rules, and any other modifiers active only during this round.
@export var modifiers: Array[Modifier] = []


func _init() -> void:
	# load(), not preload(): play.gd refers back to this class.
	phase_scene = load("res://scenes/play/play.tscn")


func on_finished(run: RunState, result: Variant) -> void:
	if result.won:
		run.vouchers += result.spins_left * VOUCHERS_PER_SPIN_LEFT
	else:
		run.is_over = true
