extends Control
## The game's entry scene: start a new run, continue a saved one, or quit.

const RUN := "res://scenes/run/run.tscn"


func _ready() -> void:
	%ContinueButton.disabled = not Game.has_save()
	%ResultLabel.text = Game.last_result
	%ResultLabel.visible = not Game.last_result.is_empty()
	%NewRunButton.grab_focus()


func _on_new_run_button_pressed() -> void:
	Game.new_run()
	get_tree().change_scene_to_file(RUN)


func _on_continue_button_pressed() -> void:
	if Game.load_run():
		get_tree().change_scene_to_file(RUN)
	else:
		%ContinueButton.disabled = true


func _on_quit_button_pressed() -> void:
	get_tree().quit()
