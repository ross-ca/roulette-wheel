extends CanvasLayer
## Pause menu for a run, toggled with Esc (ui_cancel). Its Process Mode is Always (set in the scene)
## so it can hear Esc while the game is running. The rest of the run is Pausable and freezes,
## including the wheel's tweens mid-spin.

const MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"


func _ready() -> void:
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	visible = paused
	if paused:
		%ResumeButton.grab_focus()


func _on_resume_button_pressed() -> void:
	_set_paused(false)


## SettingsMenu inherits Always from this, and takes Esc first to close itself.
func _on_settings_button_pressed() -> void:
	$Root/Center.hide()
	%SettingsMenu.open()


func _on_settings_menu_closed() -> void:
	$Root/Center.show()
	%SettingsButton.grab_focus()


## The run was saved after the last spin that settled, so Continue picks up from there.
func _on_quit_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)
