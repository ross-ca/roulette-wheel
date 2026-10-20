extends Node2D

## Emitted once the ball has settled. `index` is the position in the wheel's segments array.
signal spin_finished(index: int, segment: Dictionary)

@export var spin_duration: float = 6.0
## Distance from the centre while the ball circles the rim.
@export var ball_track_radius: float = 246.0
## Distance from the centre where the ball rests, at the bottom (hub end) of the pocket.
@export var ball_rest_radius: float = 115.0
## When the ball leaves the rim and falls into the pockets, in seconds from the start.
@export var ball_drop_time: float = 3.2
@export var ball_drop_duration: float = 1.6

var is_spinning: bool = false

# The ball lives in the wheel's rotating frame, so once it settles it rides with the wheel for free.
var _ball_angle: float = 0.0 # radians, relative to the wheel
var _ball_radius: float = 0.0

@onready var _wheel: Node2D = $WheelVisual
@onready var _ball: Sprite2D = $Ball


func _ready() -> void:
	position = get_viewport_rect().size / 2
	_ball_radius = ball_rest_radius
	_ball_angle = _pocket_angle(0)
	_update_ball()


func _process(_delta: float) -> void:
	_update_ball()


func spin_wheel() -> void:
	if is_spinning or _wheel.segments.is_empty():
		return

	is_spinning = true

	# The winner is chosen up front (so it can honour per-segment weights from
	# wheel mutations) and the ball is animated to land on it.
	var winner: int = pick_winning_index()

	var wheel_turns: int = randi_range(3, 6)
	var target_rotation: float = _wheel.rotation + wheel_turns * TAU + randf_range(0.0, TAU)

	# The ball runs against the wheel. Adding a few extra turns over the wheel's
	# keeps it moving the opposite way in world space for the whole spin.
	var ball_turns: int = wheel_turns + randi_range(3, 5)
	var pocket_angle: float = _pocket_angle(winner)
	var turns_to_pocket: float = fposmod(_ball_angle - pocket_angle, TAU) + ball_turns * TAU
	var target_ball_angle: float = _ball_angle - turns_to_pocket

	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(_wheel, "rotation", target_rotation, spin_duration) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_ball_angle", target_ball_angle, spin_duration) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	# Launch onto the rim, wait for the ball to slow, then drop and bounce off the hub.
	var radius_tween: Tween = create_tween()
	radius_tween.tween_property(self, "_ball_radius", ball_track_radius, 0.4)
	radius_tween.tween_interval(maxf(ball_drop_time - 0.4, 0.0))
	radius_tween.tween_property(self, "_ball_radius", ball_rest_radius, ball_drop_duration) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	await tween.finished
	if radius_tween.is_running():
		await radius_tween.finished
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


func _update_ball() -> void:
	_ball.position = Vector2.from_angle(_wheel.rotation + _ball_angle) * _ball_radius
