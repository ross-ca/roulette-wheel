extends TextureRect
## A card that tilts in 3D towards the cursor while hovered, using card_tilt.gdshader.
## Instance card.tscn and set `texture`; leave scale/position to the parent scene.

## Tilt in degrees when the cursor is at the edge of the card.
@export_range(0.0, 60.0, 0.5) var max_tilt: float = 6.0
## How quickly the tilt follows the cursor and relaxes back to flat. Higher is snappier.
@export var tilt_smoothing: float = 14.0

## Scale multiplier while hovered, applied on top of `base_scale` about the card's centre.
@export_range(1.0, 1.5, 0.01) var hover_scale: float = 1.06
## How quickly the scale springs to and from the hover scale (the spring's angular
## frequency, rad/s). Higher is snappier.
@export var hover_scale_speed: float = 14.0
## Damping of that spring. Below 1 the scale overshoots and settles back, lower is bouncier;
## 1 or more settles with no overshoot.
@export_range(0.05, 2.0, 0.01) var hover_scale_damping: float = 0.45

## Played through the Audio autoload when the cursor enters the card. Leave empty for silence.
@export var hover_sound: AudioStream = preload("res://assets/audio/sfx/bubble_pop.wav")
@export_range(-40.0, 6.0, 0.5) var hover_sound_volume_db: float = -8.0
## Each play is pitched randomly within this fraction of normal, so repeats don't sound identical.
@export_range(0.0, 0.3, 0.005) var hover_sound_pitch_variance: float = 0.05

## Tilt in degrees of the slow circular drift while not hovered. 0 turns it off.
@export_range(0.0, 20.0, 0.1) var idle_tilt: float = 2.0
## Revolutions per second of the idle drift.
@export_range(0.0, 2.0, 0.01) var idle_speed: float = 0.25

## The card's resting scale. Set this instead of `scale`, which the hover pop overwrites.
## Normally set by CardContainer.
var base_scale := Vector2.ONE:
	set(value):
		base_scale = value
		_apply_scale()

## Phase shift in radians of the idle drift, so neighbouring cards needn't tilt in sync.
## Normally set by CardContainer.
var idle_phase_offset := 0.0

var _hovered := false
var _idle_phase := 0.0 # radians; frozen while hovered so the drift resumes where it stopped
var _hover_amount := 0.0 # sprung towards 1 while hovered; overshoots 0..1 when underdamped
var _hover_velocity := 0.0
var _tilt := Vector2.ZERO # (x_rot, y_rot) in degrees, as passed to the shader


func _ready() -> void:
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	resized.connect(_update_pivot)
	_update_pivot()


func _process(delta: float) -> void:
	var target := Vector2.ZERO
	if not _hovered:
		_idle_phase = fposmod(_idle_phase + delta * idle_speed * TAU, TAU)
		target = Vector2(sin(_idle_phase + idle_phase_offset), cos(_idle_phase + idle_phase_offset)) * idle_tilt
	else:
		# Cursor offset from the card centre in -1..1, in the card's own (scaled) space.
		var half := size / 2.0
		var offset := ((get_local_mouse_position() - half) / half).clamp(-Vector2.ONE, Vector2.ONE)
		# Cursor below centre tilts about x, cursor left of centre tilts about y.
		target = Vector2(offset.y, -offset.x) * max_tilt

	_tilt = _tilt.lerp(target, 1.0 - exp(-tilt_smoothing * delta))
	_step_hover_spring(minf(delta, 1.0 / 30.0)) # capped so a frame hitch can't blow the spring up
	_apply_scale()

	var tilt_material := material as ShaderMaterial
	tilt_material.set_shader_parameter("x_rot", _tilt.x)
	tilt_material.set_shader_parameter("y_rot", _tilt.y)


func _step_hover_spring(delta: float) -> void:
	var stiffness := hover_scale_speed * hover_scale_speed
	var damping := 2.0 * hover_scale_damping * hover_scale_speed
	var target := 1.0 if _hovered else 0.0
	_hover_velocity += (stiffness * (target - _hover_amount) - damping * _hover_velocity) * delta
	_hover_amount += _hover_velocity * delta


func _apply_scale() -> void:
	scale = base_scale * lerpf(1.0, hover_scale, _hover_amount)


func _set_hovered(hovered: bool) -> void:
	_hovered = hovered
	if hovered and hover_sound:
		var pitch := 1.0 + randf_range(-hover_sound_pitch_variance, hover_sound_pitch_variance)
		Audio.play_sfx(hover_sound, hover_sound_volume_db, pitch)


# Scale (e.g. a future hover pop) should happen about the card's centre.
func _update_pivot() -> void:
	pivot_offset = size / 2.0
