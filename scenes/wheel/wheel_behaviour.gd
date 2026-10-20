extends Node2D

## Emitted each time the ball enters a pocket during a spin, including the one it lands in.
signal pocket_passed(index: int, segment: Dictionary)
## Emitted once the ball has settled. `index` is the position in the wheel's segments array.
signal spin_finished(index: int, segment: Dictionary)

@export var spin_duration: float = 6.0
## Whole turns the wheel makes each spin, picked randomly between min and max.
@export_range(0, 20) var wheel_turns_min: int = 3
@export_range(0, 20) var wheel_turns_max: int = 6
## Whole turns the ball makes over and above the wheel's, picked randomly between min and max.
## Keep this above 0 so the ball runs against the wheel for the whole spin.
@export_range(0, 20) var ball_extra_turns_min: int = 3
@export_range(0, 20) var ball_extra_turns_max: int = 5
## Distance from the centre while the ball circles the rim.
@export var ball_track_radius: float = 246.0
## Distance from the centre where the ball rests, at the bottom (hub end) of the pocket.
@export var ball_rest_radius: float = 115.0
## When the ball leaves the rim and falls into the pockets, in seconds from the start.
@export var ball_drop_time: float = 3.2
@export var ball_drop_duration: float = 1.6
## How far the wheel winds back against the spin before it is released, and how long that takes.
@export_range(0.0, 90.0, 0.5, "radians_as_degrees") var windup_angle: float = deg_to_rad(12.0)
@export var windup_duration: float = 0.4
## How sharply the wheel decelerates: 2 = quad, 3 = cubic, 5 = quint. Higher values start faster and
## spend longer creeping the last few degrees, which reads as the wheel having stopped before it
## eases back from its overshoot.
@export_range(2.0, 6.0, 0.1) var wheel_ease_power: float = 2.0
## How far past its final angle the wheel runs before easing back onto it, and how long the return takes.
## The wheel finishes moving when the ball stops bouncing.
@export_range(0.0, 30.0, 0.5, "radians_as_degrees") var overshoot_angle: float = deg_to_rad(4.0)
@export var overshoot_settle_duration: float = 0.3
## Debug: keep the wheel still during a spin so only the ball moves.
@export var debug_freeze_wheel: bool = false

var is_spinning: bool = false

# The ball lives in the wheel's rotating frame, so once it settles it rides with the wheel for free.
var _ball_angle: float = 0.0 # radians, relative to the wheel
var _ball_radius: float = 0.0
var _last_step: int = 0 # pockets travelled, unwrapped so it keeps counting across laps

@onready var _wheel: Node2D = $WheelVisual
@onready var _ball: Sprite2D = $Ball


func _ready() -> void:
	position = get_viewport_rect().size / 2
	_ball_radius = ball_rest_radius
	_ball_angle = _pocket_angle(0)
	_update_ball()


func _process(_delta: float) -> void:
	_update_ball()
	if is_spinning:
		_emit_passed_pockets()


func spin_wheel() -> void:
	if is_spinning or _wheel.segments.is_empty():
		return

	is_spinning = true
	_last_step = _ball_step()

	# The winner is chosen up front (so it can honour per-segment weights from
	# wheel mutations) and the ball is animated to land on it.
	var winner: int = pick_winning_index()

	var wheel_turns: int = randi_range(wheel_turns_min, maxi(wheel_turns_min, wheel_turns_max))
	var target_rotation: float = _wheel.rotation + wheel_turns * TAU + randf_range(0.0, TAU)

	# The ball runs against the wheel. Adding a few extra turns over the wheel's
	# keeps it moving the opposite way in world space for the whole spin.
	var ball_turns: int = wheel_turns \
		+ randi_range(ball_extra_turns_min, maxi(ball_extra_turns_min, ball_extra_turns_max))
	var pocket_angle: float = _pocket_angle(winner)
	var turns_to_pocket: float = fposmod(_ball_angle - pocket_angle, TAU) + ball_turns * TAU
	var target_ball_angle: float = _ball_angle - turns_to_pocket

	# Wheel: pull back against the spin, then whip forward to the target in one continuous
	# curve that includes the overshoot (see _set_wheel_spin).
	# The ball is launched after the pull back, so it rides back with the wheel first.
	var wheel_tween: Tween = null
	if not debug_freeze_wheel:
		var spin_from: float = _wheel.rotation - windup_angle
		wheel_tween = create_tween()
		wheel_tween.tween_property(_wheel, "rotation", spin_from, windup_duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		wheel_tween.tween_method(_set_wheel_spin.bind(spin_from, target_rotation), 0.0, _wheel_spin_time(), _wheel_spin_time())

	var ball_tween: Tween = create_tween()
	ball_tween.tween_property(self, "_ball_angle", target_ball_angle, spin_duration) \
		.set_delay(windup_duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	# Launch onto the rim, wait for the ball to slow, then drop and bounce off the hub.
	var radius_tween: Tween = create_tween()
	radius_tween.tween_interval(windup_duration)
	radius_tween.tween_property(self, "_ball_radius", ball_track_radius, 0.4)
	radius_tween.tween_interval(maxf(ball_drop_time - 0.4, 0.0))
	radius_tween.tween_property(self, "_ball_radius", ball_rest_radius, ball_drop_duration) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	await ball_tween.finished
	for other in [wheel_tween, radius_tween]:
		if other and other.is_running():
			await other.finished
	# The tween's final angle may be applied after this frame's _process, so make
	# sure the landing pocket has been reported before finishing.
	_emit_passed_pockets()
	is_spinning = false
	spin_finished.emit(winner, _wheel.segments[winner])


## Random segment index, weighted by each segment's optional "weight" (default 1.0).
func pick_winning_index() -> int:
	var segments: Array[Dictionary] = _wheel.segments
	var total: float = 0.0
	for segment in segments:
		total += maxf(float(segment.get("weight", 1.0)), 0.0)
	if total <= 0.0:
		return randi_range(0, segments.size() - 1)

	var roll: float = randf() * total
	for i in segments.size():
		roll -= maxf(float(segments[i].get("weight", 1.0)), 0.0)
		if roll < 0.0:
			return i
	return segments.size() - 1


# Centre of a segment, in the wheel's local frame (segments are drawn clockwise from the top).
func _pocket_angle(index: int) -> float:
	var segment_angle: float = TAU / _wheel.segments.size()
	return -PI / 2.0 + (index + 0.5) * segment_angle


# Pockets travelled by the ball, as a whole number that keeps counting past full laps.
func _ball_step() -> int:
	var segment_angle: float = TAU / _wheel.segments.size()
	return floori((_ball_angle + PI / 2.0) / segment_angle)


# The ball can cross several pockets in one frame early in the spin, so step through each.
func _emit_passed_pockets() -> void:
	var step: int = _ball_step()
	while _last_step != step:
		_last_step += signi(step - _last_step)
		var index: int = posmod(_last_step, _wheel.segments.size())
		pocket_passed.emit(index, _wheel.segments[index])


# The wheel's spin as one continuous curve. It decelerates (quint ease-out) to a point just past
# `to_angle`, comes to rest there, then eases back onto `to_angle`, finishing when the ball stops
# bouncing. The ease-out ends with zero velocity, which is exactly where the return starts, so
# the two halves join with no seam. `time` is seconds since the wheel was released.
func _set_wheel_spin(time: float, from_angle: float, to_angle: float) -> void:
	var settle: float = minf(overshoot_settle_duration, _wheel_spin_time())
	var peak_time: float = _wheel_spin_time() - settle

	if time < peak_time:
		var p: float = time / peak_time
		_wheel.rotation = lerpf(from_angle, to_angle + overshoot_angle, 1.0 - pow(1.0 - p, wheel_ease_power))
	else:
		var q: float = clampf((time - peak_time) / maxf(settle, 0.001), 0.0, 1.0)
		var back: float = 0.5 - 0.5 * cos(PI * q) # sine in-out
		_wheel.rotation = to_angle + overshoot_angle * (1.0 - back)


# The wheel finishes moving when the ball stops bouncing.
func _wheel_spin_time() -> float:
	return ball_drop_time + ball_drop_duration


func _update_ball() -> void:
	_ball.position = Vector2.from_angle(_wheel.rotation + _ball_angle) * _ball_radius
