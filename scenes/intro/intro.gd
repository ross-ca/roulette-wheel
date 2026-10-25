extends Control
## The game's entry scene: plays the intro video, then moves on to the main
## menu, which loads in the background meanwhile. Any key, click or button
## skips it.
##
## The video is Ogg Theora (.ogv), the only format Godot plays out of the box.
## It keeps its aspect ratio and is letterboxed with the background colour.

const NEXT := "res://scenes/main_menu/main_menu.tscn"

var _leaving := false

@onready var _frame: AspectRatioContainer = $Frame
@onready var _video: VideoStreamPlayer = $Frame/Video


func _ready() -> void:
	ResourceLoader.load_threaded_request(NEXT)
	if _video.stream == null:
		push_warning("Intro has no video, skipping it")
		_leave.call_deferred()
		return
	_video.finished.connect(_leave)
	_video.play()
	var video_size := _video.get_video_texture().get_size()
	if video_size.y > 0:
		_frame.ratio = video_size.x / video_size.y


func _input(event: InputEvent) -> void:
	var skip := event is InputEventKey or event is InputEventMouseButton \
			or event is InputEventJoypadButton
	if skip and event.is_pressed() and not event.is_echo():
		get_viewport().set_input_as_handled()
		_leave()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(NEXT))
