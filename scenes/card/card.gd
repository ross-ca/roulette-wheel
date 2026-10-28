class_name Card
extends TextureRect
## The face of something the player holds or can buy: a ticket now, consumables and the like later.
## A card is only a view. The `Modifier` it shows owns the data and behaviour and lives in the run;
## the card can be thrown away and rebuilt from it at any time, and holds nothing worth saving. It
## doesn't branch on what kind of thing it shows: it asks the item for its icon (and the tooltip asks
## for its name, description and kind).
##
## Rule of thumb: if it changes the run, it doesn't go in Card. The card shows itself, tilts towards
## the cursor (card_tilt.gdshader), pops on hover, pulses when its item triggers and shows the
## `Tooltip` while hovered. What interacting with it means (drag to reorder, click to buy or use)
## belongs to whatever holds the card: a CardContainer, the shop and so on.
##
## Instance card.tscn and call `setup`; leave scale/position to the parent scene.

## The thing this card shows.
var item: Modifier

## The noise `dissolve` eats the card away along (card_tilt.gdshader's `dissolve_noise`).
@export var dissolve_noise: Texture2D = preload("res://scenes/card/perlin.tres")

## True once `dissolve` has started: the card is on its way out, so it ignores the mouse.
var leaving := false

## Tilt in degrees when the cursor is at the edge of the card.
@export_range(0.0, 60.0, 0.5) var max_tilt: float = 6.0
## How quickly the tilt follows the cursor and relaxes back to flat. Higher is snappier.
@export var tilt_smoothing: float = 14.0

## Scale multiplier while hovered, applied on top of `base_scale` about the card's centre.
@export_range(1.0, 1.5, 0.01) var hover_scale: float = 1.06
## How quickly the scale springs to and from the hover scale (the spring's angular
## frequency, rad/s). Higher is snappier.
@export var hover_scale_speed: float = 50.0
## Damping of that spring. Below 1 the scale overshoots and settles back, lower is bouncier;
## 1 or more settles with no overshoot.
@export_range(0.05, 2.0, 0.01) var hover_scale_damping: float = 0.3

## Played through the Audio autoload when the cursor enters the card. Leave empty for silence.
@export var hover_sound: AudioStream = preload("res://assets/audio/sfx/paper_shuffle.wav")
@export_range(-40.0, 6.0, 0.5) var hover_sound_volume_db: float = -8.0
## Each play is pitched randomly within this fraction of normal, so repeats don't sound identical.
@export_range(0.0, 0.3, 0.005) var hover_sound_pitch_variance: float = 0.05

## Tilt in degrees of the slow circular drift while not hovered. 0 turns it off.
@export_range(0.0, 20.0, 0.1) var idle_tilt: float = 2.0
## Revolutions per second of the idle drift.
@export_range(0.0, 2.0, 0.01) var idle_speed: float = 0.25
## Toggles playing of a sound on card hover.
@export var mute_hover_sound: bool = false;

## The card's resting scale. Set this instead of `scale`, which the hover pop overwrites.
## Normally set by CardContainer.
var base_scale := Vector2.ONE:
	set(value):
		base_scale = value
		_apply_scale()

## Phase shift in radians of the idle drift, so neighbouring cards needn't tilt in sync.
## Normally set by CardContainer.
var idle_phase_offset := 0.0

## True while the player is dragging the card, which hides its tooltip. Normally set by CardContainer.
var held := false:
	set(value):
		held = value
		_update_tooltip()

## True while whatever holds the card has it picked, e.g. a consumable waiting for its target. It
## stays popped up as if hovered.
var selected := false

## Scale multiplier at the start of `pulse`.
@export_range(1.0, 1.5, 0.01) var pulse_peak: float = 1.2

var _pulse_scale := 1.0
var _pulse_tween: Tween
var _hovered := false
var _idle_phase := 0.0 # radians; frozen while hovered so the drift resumes where it stopped
var _hover_amount := 0.0 # sprung towards 1 while hovered; overshoots 0..1 when underdamped
var _hover_velocity := 0.0
var _tilt := Vector2.ZERO # (x_rot, y_rot) in degrees, as passed to the shader


## Shows `new_item`. Call before the card enters the tree, or again to show a different item. The
## tooltip reads the item's description live, so changed values need no refresh.
func setup(new_item: Modifier) -> void:
	if item and item.triggered.is_connected(pulse):
		item.triggered.disconnect(pulse)
	item = new_item
	texture = item.icon
	item.triggered.connect(pulse)


## A brief pop, e.g. when the item triggers. Retriggering restarts it.
func pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	_pulse_scale = pulse_peak
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "_pulse_scale", 1.0, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Dissolves the card away and returns once it's fully gone. It doesn't free the card: whatever
## holds it decides when to remove it.
func dissolve(duration := 0.6) -> void:
	if leaving:
		return
	leaving = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Tooltip.hide_for(self)
	var tween := create_tween()
	tween.tween_property(material, "shader_parameter/dissolve_amount", 1.0, duration)
	await tween.finished


func _ready() -> void:
	(material as ShaderMaterial).set_shader_parameter("dissolve_noise", dissolve_noise)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	resized.connect(_update_pivot)
	_update_pivot()


func _exit_tree() -> void:
	Tooltip.hide_for(self) # freed or moved while hovered, so mouse_exited never comes


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
	var target := 1.0 if _hovered or selected else 0.0
	_hover_velocity += (stiffness * (target - _hover_amount) - damping * _hover_velocity) * delta
	_hover_amount += _hover_velocity * delta


func _apply_scale() -> void:
	scale = base_scale * lerpf(1.0, hover_scale, _hover_amount) * _pulse_scale


## The card's rect on screen at `base_scale`, ignoring the hover pop and pulse, so the tooltip can
## anchor to it without wobbling.
func get_resting_screen_rect() -> Rect2:
	var parent_xform := get_global_transform_with_canvas() * get_transform().affine_inverse()
	var centre := position + pivot_offset
	return parent_xform * Rect2(centre - pivot_offset * base_scale, size * base_scale)


func _set_hovered(hovered: bool) -> void:
	_hovered = hovered
	_update_tooltip()
	if hovered and hover_sound and !mute_hover_sound:
		var pitch := 1.0 + randf_range(-hover_sound_pitch_variance, hover_sound_pitch_variance)
		Audio.play_sfx(hover_sound, hover_sound_volume_db, pitch)


func _update_tooltip() -> void:
	if _hovered and not held and item:
		Tooltip.show_for(self)
	else:
		Tooltip.hide_for(self)


# Scale (the hover pop and pulse) should happen about the card's centre.
func _update_pivot() -> void:
	pivot_offset = size / 2.0
