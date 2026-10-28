extends Node
## Autoload ("Settings"): the player's preferences, saved to user://settings.cfg and applied at
## startup and whenever one changes. Preferences only: anything that changes how a run plays
## belongs in RunState, so a save plays the same on any machine.

signal changed(section: String, key: String)

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"audio": {
		"master": 1.0,
		"music": 0.8,
		"sfx": 0.8,
	},
	"display": {
		"window_mode": Window.MODE_WINDOWED,
		"window_size": Vector2i(1920, 1080),
		"vsync": true,
	},
	"gameplay": {
		"animation_speed": 1.0,
	},
}
## The animation speeds offered, in slider order.
const ANIMATION_SPEEDS: Array[float] = [1.0, 2.0, 4.0]
## The audio bus each volume setting controls (see default_bus_layout.tres).
const BUSES := {"master": &"Master", "music": &"Music", "sfx": &"SFX"}

var _config := ConfigFile.new()


func _ready() -> void:
	# A missing or unreadable file just leaves every setting at its default.
	_config.load(PATH)
	for section in DEFAULTS:
		for key in DEFAULTS[section]:
			_apply(section, key)


func get_value(section: String, key: String) -> Variant:
	return _config.get_value(section, key, DEFAULTS[section][key])


func set_value(section: String, key: String, value: Variant) -> void:
	_config.set_value(section, key, value)
	_config.save(PATH)
	_apply(section, key)
	changed.emit(section, key)


## How many times faster game animations play. Applied by each animation as it starts (a tween's
## `set_speed_scale`, or a wait divided by it), so a change takes effect from the next one. Only
## animations that hold up play use it: UI motion such as view slides stays at normal speed.
func animation_speed() -> float:
	return get_value("gameplay", "animation_speed")


func _apply(section: String, key: String) -> void:
	var value: Variant = get_value(section, key)
	match [section, key]:
		["audio", _]:
			var bus := AudioServer.get_bus_index(BUSES[key])
			AudioServer.set_bus_volume_db(bus, linear_to_db(value))
			AudioServer.set_bus_mute(bus, value <= 0.0)
		["display", "window_mode"]:
			get_window().mode = value
			# Leaving fullscreen restores the window size from before it, so put the setting back.
			if value == Window.MODE_WINDOWED:
				_apply("display", "window_size")
		["display", "window_size"]:
			if get_window().mode == Window.MODE_WINDOWED:
				get_window().size = value
				get_window().move_to_center()
		["display", "vsync"]:
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED)
