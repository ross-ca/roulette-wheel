class_name RunStep
extends Resource
## One step of a run: a round, a shop, an event... The runner instances `phase_scene`, calls its
## `setup(run, step)`, waits for its `finished(result)` signal, then calls `on_finished`.
##
## Steps defined in .tres files are shared by Godot's resource cache, so duplicate(true) them before
## putting them in a run's queue.

@export var phase_scene: PackedScene


## This step's own consequences once its phase finishes.
func on_finished(_run: RunState, _result: Variant) -> void:
	pass
