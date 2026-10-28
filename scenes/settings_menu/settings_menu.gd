extends Control
## The settings screen, opened from the main menu and the pause menu. Display only: it shows the
## values in `Settings` and hands every change straight back to it. The owner hides its own
## buttons while this is open and shows them again on `closed`.

signal closed

const WINDOW_MODES := [
	["Windowed", Window.MODE_WINDOWED],
	["Fullscreen windowed", Window.MODE_FULLSCREEN],
	["Fullscreen", Window.MODE_EXCLUSIVE_FULLSCREEN],
]
const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

# The sizes offered in the window size list, in item order.
var _sizes: Array[Vector2i] = []


func _ready() -> void:
	hide()
	for mode in WINDOW_MODES:
		%WindowModeOption.add_item(mode[0])


## Esc closes this before the pause menu (its parent) would see it and unpause.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	_refresh()
	show()
	%MasterSlider.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _refresh() -> void:
	%MasterSlider.set_value_no_signal(Settings.get_value("audio", "master"))
	%MusicSlider.set_value_no_signal(Settings.get_value("audio", "music"))
	%SfxSlider.set_value_no_signal(Settings.get_value("audio", "sfx"))
	%VsyncCheck.set_pressed_no_signal(Settings.get_value("display", "vsync"))
	# The slider's notches are indexes into ANIMATION_SPEEDS; an unknown saved speed shows as the first.
	var speed_index := maxi(Settings.ANIMATION_SPEEDS.find(Settings.animation_speed()), 0)
	%AnimationSpeedSlider.set_value_no_signal(speed_index)
	_show_animation_speed(speed_index)

	var mode: int = Settings.get_value("display", "window_mode")
	for i in WINDOW_MODES.size():
		if WINDOW_MODES[i][1] == mode:
			%WindowModeOption.select(i)

	# Only sizes that fit the screen, plus the saved one so the list can always show it.
	var screen := DisplayServer.screen_get_size()
	var current: Vector2i = Settings.get_value("display", "window_size")
	_sizes.assign(WINDOW_SIZES.filter(func(window_size: Vector2i) -> bool:
		return window_size.x <= screen.x and window_size.y <= screen.y))
	if current not in _sizes:
		_sizes.append(current)
		_sizes.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	%WindowSizeOption.clear()
	for window_size in _sizes:
		%WindowSizeOption.add_item("%d x %d" % [window_size.x, window_size.y])
	%WindowSizeOption.select(_sizes.find(current))
	%WindowSizeOption.disabled = mode != Window.MODE_WINDOWED


func _on_master_slider_value_changed(value: float) -> void:
	Settings.set_value("audio", "master", value)


func _on_music_slider_value_changed(value: float) -> void:
	Settings.set_value("audio", "music", value)


func _on_sfx_slider_value_changed(value: float) -> void:
	Settings.set_value("audio", "sfx", value)


func _on_window_mode_option_item_selected(index: int) -> void:
	Settings.set_value("display", "window_mode", WINDOW_MODES[index][1])
	%WindowSizeOption.disabled = WINDOW_MODES[index][1] != Window.MODE_WINDOWED


func _on_window_size_option_item_selected(index: int) -> void:
	Settings.set_value("display", "window_size", _sizes[index])


func _on_vsync_check_toggled(toggled_on: bool) -> void:
	Settings.set_value("display", "vsync", toggled_on)


func _on_animation_speed_slider_value_changed(value: float) -> void:
	Settings.set_value("gameplay", "animation_speed", Settings.ANIMATION_SPEEDS[int(value)])
	_show_animation_speed(int(value))


func _show_animation_speed(index: int) -> void:
	%AnimationSpeedValue.text = "%dx" % Settings.ANIMATION_SPEEDS[index]


func _on_back_button_pressed() -> void:
	close()
