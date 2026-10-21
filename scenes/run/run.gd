extends Node
## One run: plays the run's steps one at a time until it ends. The runner doesn't know what kind of
## step it's playing. Each step's phase scene follows the same contract: `setup(run, step)` before
## it enters the tree, then `signal finished(result)` when it's done.

const MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"

@onready var _phase: Node = $Phase


func _ready() -> void:
	# Running this scene on its own (F6) has no run yet.
	if Game.run == null:
		Game.new_run(randi(), false)
	_run_loop()


func _run_loop() -> void:
	var run := Game.run
	var won := false
	while not run.is_over:
		# A loaded save may be part-way through a step: resume it instead of taking a new one.
		if run.current_step == null:
			if run.steps.is_empty():
				run.steps = RunGenerator.next_table(run)
				if run.steps.is_empty():
					won = true
					break
			run.current_step = run.steps.pop_front()
			Modifiers.notify(run, &"step_started", [run.current_step])
		var step := run.current_step
		var result: Variant = await _play(step)
		step.on_finished(run, result)
		Modifiers.notify(run, &"step_finished", [step, result])
		run.current_step = null
		run.current_round = null
		Game.save_run()
	_end_run(won)


func _play(step: RunStep) -> Variant:
	var phase := step.phase_scene.instantiate()
	phase.setup(Game.run, step)
	_phase.add_child(phase)
	var result: Variant = await phase.finished
	phase.queue_free()
	return result


func _end_run(won: bool) -> void:
	Game.end_run(won)
	get_tree().change_scene_to_file(MAIN_MENU)
