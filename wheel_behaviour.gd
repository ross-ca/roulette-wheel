extends Node2D

var is_spinning: bool = false


func _ready() -> void:
	position = get_viewport_rect().size / 2


func spin_wheel() -> void:
	if is_spinning:
		return

	is_spinning = true

	var start_rotation: float = $WheelVisual.rotation
	var extra_rotations: float = randi_range(3, 6) * TAU
	var random_offset: float = randf_range(0.0, TAU)

	var target_rotation = start_rotation + extra_rotations + random_offset

	var tween: Tween = create_tween()
	tween.tween_property($WheelVisual, "rotation", target_rotation, 6.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func(): is_spinning = false)
