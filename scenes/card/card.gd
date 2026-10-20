extends TextureRect
## A card that tilts in 3D towards the cursor while hovered, using card_tilt.gdshader.
## Instance card.tscn and set `texture`; leave scale/position to the parent scene.

## Tilt in degrees when the cursor is at the edge of the card.
@export_range(0.0, 60.0, 0.5) var max_tilt: float = 6.0
## How quickly the tilt follows the cursor and relaxes back to flat. Higher is snappier.
@export var tilt_smoothing: float = 14.0

const _SETTLED_DEGREES := 0.01

var _hovered := false
var _tilt := Vector2.ZERO # (x_rot, y_rot) in degrees, as passed to the shader


func _ready() -> void:
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	resized.connect(_update_pivot)
	_update_pivot()
	set_process(false)


func _process(delta: float) -> void:
	var target := Vector2.ZERO
	if _hovered:
		# Cursor offset from the card centre in -1..1, in the card's own (scaled) space.
		var half := size / 2.0
		var offset := ((get_local_mouse_position() - half) / half).clamp(-Vector2.ONE, Vector2.ONE)
		# Cursor below centre tilts about x, cursor left of centre tilts about y.
		target = Vector2(offset.y, -offset.x) * max_tilt

	_tilt = _tilt.lerp(target, 1.0 - exp(-tilt_smoothing * delta))
	if not _hovered and _tilt.length() < _SETTLED_DEGREES:
		_tilt = Vector2.ZERO
		set_process(false)

	var tilt_material := material as ShaderMaterial
	tilt_material.set_shader_parameter("x_rot", _tilt.x)
	tilt_material.set_shader_parameter("y_rot", _tilt.y)


func _set_hovered(hovered: bool) -> void:
	_hovered = hovered
	set_process(true)


# Scale (e.g. a future hover pop) should happen about the card's centre.
func _update_pivot() -> void:
	pivot_offset = size / 2.0
