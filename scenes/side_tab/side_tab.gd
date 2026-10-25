@tool
class_name SideTab
extends Button
## A tab stuck to the left or right edge of the screen, for switching views, like WHEEL on the
## betting view. Rounded on the side facing the middle of the screen and flat against the edge, with
## a stroke on every side but the edge's. Its title runs up the tab, turned a quarter turn.
## The title's font and shadow are in side_tab.tscn; the box is built here so it can mirror.

enum Side { LEFT, RIGHT }

## The screen edge the tab is stuck to.
@export var side := Side.RIGHT:
	set(value):
		side = value
		_refresh()
@export var title := "WHEEL":
	set(value):
		title = value
		_refresh()
@export var fill := Color("232222"):
	set(value):
		fill = value
		_refresh()
@export var hover_fill := Color("2f2d2d"):
	set(value):
		hover_fill = value
		_refresh()
@export var stroke := Color("f9d684"):
	set(value):
		stroke = value
		_refresh()
## Drawn inside the tab, on every side but the screen edge's.
@export var stroke_width := 8:
	set(value):
		stroke_width = value
		_refresh()
## Rounding of the two corners facing the middle of the screen.
@export var corner_radius := 52:
	set(value):
		corner_radius = value
		_refresh()

## How far the title sits from the middle of the tab, towards the screen edge.
@export var title_shift := 10:
	set(value):
		title_shift = value
		_refresh()

@onready var _title: Label = $Title


func _ready() -> void:
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place_title()


func _refresh() -> void:
	if not is_node_ready():
		return
	add_theme_stylebox_override("normal", _box(fill))
	add_theme_stylebox_override("disabled", _box(fill))
	add_theme_stylebox_override("hover", _box(hover_fill))
	add_theme_stylebox_override("pressed", _box(hover_fill))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_title.text = title
	_place_title()


func _box(colour: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.border_color = stroke
	box.set_border_width_all(stroke_width)
	box.set_corner_radius_all(corner_radius)
	if side == Side.RIGHT:
		box.border_width_right = 0
		box.corner_radius_top_right = 0
		box.corner_radius_bottom_right = 0
	else:
		box.border_width_left = 0
		box.corner_radius_top_left = 0
		box.corner_radius_bottom_left = 0
	return box


# Turned a quarter turn anticlockwise, the title's width runs up the tab and its height across it.
func _place_title() -> void:
	if not is_node_ready():
		return
	_title.reset_size()
	_title.rotation = -PI / 2
	_title.position = ((size + Vector2(-_title.size.y, _title.size.x)) / 2).round()
	_title.position.x += title_shift if side == Side.RIGHT else -title_shift
